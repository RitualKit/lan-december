extends Node
## Online play for the browser build, over the claude.ai artifact "room".
##
## Lobby: every open page is in the shared room; a host advertises a game there and the
## game itself lives in a named room ("ld-<code>"). Only presence is used (anyone may
## set it), so players need no special share rights.
##
## Matches run in lockstep: every page simulates the same deterministic game and only
## player inputs travel. Each page records its players' input DELAY ticks ahead and
## publishes a window of recent ticks in its presence; a tick runs once every human's
## input for it has arrived, otherwise the game pauses for that frame.

signal changed
signal match_aborted(reason: String)

const VERSION := "ld1"
const DELAY := 10 ## Input delay in physics ticks (~167 ms): hides network latency.
const WINDOW := 40 ## Ticks of input history in each presence update (survives drops).
const AXIS := "ABCDEFGHIJKLMNOPQRSTU" ## 21 steps per stick axis.
const CHECK_EVERY := 60 ## Ticks between desync checksums.
const PEER_TIMEOUT := 6.0
const START_GRACE := 30.0 ## Seconds a page may take to load into a match.
const SYNC_EVERY := 6 ## Ticks between the host's character snapshots.
const UNITS := 1024.0 ## Snapshot fixed-point scale (matches PlayerCharacter.SNAP).

var available := false ## The page offers a room (web build inside claude.ai).
## Why online is (un)available: "", "outside", "connecting", "unavailable", "denied:<code>", "ready".
var status := ""
var connected := false
var me := ""
var lobby: Array = [] ## [{peer, me, p}] everyone with the page open
var game: Array = [] ## [{peer, me, p}] everyone in my game room
var game_code := ""
var game_state := "" ## "", "joining", "joined", "error"
var is_host := false
var in_match := false ## Game.players currently holds the shared online roster.
var lockstep := false
var tick := 0 ## The tick being simulated this frame.
var round_key := ""
var match_info := {}
var ready_key := ""
var desync := false
var stalled := 0.0 ## Seconds the current tick has been waiting for someone.
var current_game: Minigame
var corrections := 0 ## Snapshots that nudged a character back in line this round.

## Tests: run lockstep without a network. `test_input(slot, tick)` gives every human's
## input; `test_stall(frame)` returns true to make a frame wait.
var loopback := false
var test_input: Callable
var test_stall: Callable
## Tests: the host's snapshots to feed this page as if they had arrived (tick -> state).
var test_snaps := {}

var _local_players: Array[PlayerSlot] = []
var _next := 0
var _rec := 0
var _frame := 0
var _inputs := {} ## slot id -> {tick: "xyb"}
var _seen_match := ""
var _host_go := ""
var _host_match := {}
var _missing := {} ## peer -> seconds missing during a match
var _checks := {} ## tick -> my checksum
var _last_lobby := ""
var _last_game := ""
var _watch_t := 0.0
var _arrived := {} ## peers seen playing the current match
var _aborted := false
var _trailing := false ## Round over here: keep sending input until the others finish too.
var _host_res := [] ## Host: [round key, [[slot ids], ...]] the agreed result of a round.
var _hist := {} ## tick -> every character's state after that tick (see state_of)
var _snaps := {} ## tick -> the host's state for that tick, not yet applied
var _host_snap := []
var _last_snap := -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_physics_priority = -50
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.LDNet && LDNet.init()", true)


# --- JS bridge ----------------------------------------------------------------------

func _js(expr: String) -> Variant:
	if not OS.has_feature("web"):
		return null
	return JavaScriptBridge.eval(expr, true)


func _poll() -> void:
	var raw = _js("window.LDNet ? LDNet.poll() : ''")
	if typeof(raw) != TYPE_STRING or raw == "":
		return
	var s = JSON.parse_string(raw)
	if typeof(s) != TYPE_DICTIONARY:
		return
	var was := [available, connected, lobby.size(), game.size(), game_state]
	available = s.get("ready", false)
	status = str(s.get("status", ""))
	connected = s.get("connected", false)
	me = s.get("me", "")
	lobby = s.get("lobby", [])
	game = s.get("game", [])
	game_state = s.get("state", "")
	for cmd in s.get("test", []):
		_test_command(str(cmd))
	if was != [available, connected, lobby.size(), game.size(), game_state]:
		changed.emit()


## Browser tests drive online play through window.__ldTest (see tools/online_test.js).
func _test_command(cmd: String) -> void:
	match cmd:
		"host": host_game()
		"join":
			var open := open_games().filter(func(g): return g.open)
			if not open.is_empty():
				join_game(open[0].code)
		"start": host_start_match()


func _set_presence(which: String, data: Dictionary) -> void:
	var text := JSON.stringify(data)
	if which == "lobby":
		if text == _last_lobby:
			return
		_last_lobby = text
	else:
		if text == _last_game:
			return
		_last_game = text
	_js("LDNet.presence(%s, %s)" % [JSON.stringify(which), JSON.stringify(text)])


# --- Lobby: hosting and joining -----------------------------------------------------

## Open games advertised in the shared room: [{code, players, open}].
func open_games() -> Array:
	var out := []
	for peer in lobby:
		var adv = peer.p.get("adv")
		if peer.me or typeof(adv) != TYPE_DICTIONARY or peer.p.get("v") != VERSION:
			continue
		if typeof(adv.get("code")) == TYPE_STRING and adv.code.length() == 4:
			out.append({"code": adv.code, "players": int(adv.get("n", 0)), "open": bool(adv.get("open", true))})
	return out


func host_game() -> void:
	const LETTERS := "ABCDEFGHJKLMNPQRSTUVWXYZ"
	var code := ""
	for i in 4:
		code += LETTERS[randi() % LETTERS.length()]
	is_host = true
	_join(code)


func join_game(code: String) -> void:
	is_host = false
	_join(code)


func _join(code: String) -> void:
	game_code = code
	game_state = "joining"
	_js("LDNet.join(%s)" % JSON.stringify("ld-" + code.to_lower()))
	changed.emit()


func leave_game() -> void:
	_js("LDNet.leave()")
	game_code = ""
	game_state = ""
	is_host = false
	_last_game = ""
	changed.emit()


func in_game() -> bool:
	return game_code != "" and game_state == "joined"


func _host_peer() -> Dictionary:
	for peer in game:
		if typeof(peer.p.get("h")) == TYPE_DICTIONARY:
			return peer
	return {}


func host_settings() -> Dictionary:
	var h := _host_peer()
	return h.p.h if not h.is_empty() else {}


## Everyone in my game: [{label, players, host, me}].
func roster() -> Array:
	var out := []
	for peer in game:
		var pl = peer.p.get("pl", [])
		var n: int = pl.size() if typeof(pl) == TYPE_ARRAY else 0
		var host := typeof(peer.p.get("h")) == TYPE_DICTIONARY
		if host:
			n += int(peer.p.h.get("bots", 0))
		out.append({"players": n, "host": host, "me": peer.me, "bots": int(peer.p.h.get("bots", 0)) if host else 0})
	return out


func total_players() -> int:
	var n := 0
	for r in roster():
		n += r.players
	return n


# --- Match --------------------------------------------------------------------------

## Host: freeze the roster from everyone's presence and announce the match.
func host_start_match() -> void:
	if not is_host or not in_game():
		return
	var entries := []
	var mine := Game.players.filter(func(p): return not p.is_bot)
	for p in mine:
		entries.append([me, p.device, 0, p.character, 0])
	for peer in game:
		if peer.me:
			continue
		var pl = peer.p.get("pl", [])
		if typeof(pl) != TYPE_ARRAY:
			continue
		for item in pl.slice(0, 8):
			if typeof(item) == TYPE_ARRAY and item.size() >= 2:
				entries.append([peer.peer, str(item[0]).left(12), 0, int(item[1]), 0])
	for p in Game.players.filter(func(p): return p.is_bot):
		entries.append(["", "", 1, p.character, int(p.skill * 100)])
	entries = entries.slice(0, Game.MAX_PLAYERS)
	# Everyone gets a different character.
	var used := {}
	for e in entries:
		var c: int = posmod(e[3], Art.CHARACTERS.size())
		while used.has(c):
			c = posmod(c + 1, Art.CHARACTERS.size())
		used[c] = true
		e[3] = c
	Game.plan_rounds()
	var plan := []
	for path in Game.round_plan:
		plan.append(Game.MINIGAMES.find(path))
	var themes := []
	for i in Game.rounds_total:
		themes.append(Game.next_theme())
	_host_match = {
		"id": str(randi() % 1000000), "seed": randi() % 2000000000 + 1, "rounds": Game.rounds_total,
		"plan": plan, "themes": themes, "players": entries,
	}
	_host_go = ""


func _maybe_start_match() -> void:
	var h := host_settings()
	var m = h.get("match")
	if typeof(m) != TYPE_DICTIONARY or str(m.get("id", "")) == _seen_match or in_match:
		return
	_seen_match = str(m.id)
	var entries = m.get("players", [])
	if typeof(entries) != TYPE_ARRAY or not entries.any(func(e): return typeof(e) == TYPE_ARRAY and e.size() >= 5 and e[0] == me):
		return # Not part of this match (joined late).
	_local_players = Game.players.duplicate()
	var slots: Array[PlayerSlot] = []
	for i in entries.size():
		var e: Array = entries[i]
		var bot := int(e[2]) == 1
		var slot := PlayerSlot.new(i, "", bot)
		slot.owner = str(e[0])
		slot.device = str(e[1]) if slot.owner == me else ("" if bot else "net")
		slot.character = int(e[3])
		slot.skill = clampf(int(e[4]) / 100.0, 0.3, 1.0) if bot else 0.75
		slots.append(slot)
	Game.players = slots
	Game.rounds_total = clampi(int(m.get("rounds", 10)), 1, 30)
	Game.round_plan.clear()
	for idx in m.get("plan", []):
		Game.round_plan.append(Game.MINIGAMES[clampi(int(idx), 0, Game.MINIGAMES.size() - 1)])
	Game.theme_plan.assign(m.get("themes", []).map(func(t): return str(t)))
	match_info = m
	_arrived.clear()
	_missing.clear()
	_aborted = false
	in_match = true
	desync = false
	Game.reset_scores()
	Game.main.goto_match()


## Seed for a round of this match: the same on every page.
func round_seed(round_no: int) -> int:
	return hash([int(match_info.get("seed", 1)), round_no]) & 0x7fffffff | 1


func set_ready(round_no: int) -> void:
	ready_key = "%s:%d" % [match_info.get("id", ""), round_no]


## Host's go-ahead for a round (everyone ready, or the host gave up waiting).
func go_for(round_no: int) -> bool:
	return str(host_settings().get("go", "")) == "%s:%d" % [match_info.get("id", ""), round_no]


## Host: let the round start once everyone in the match has readied (or after a wait).
func host_release(round_no: int, waited: float) -> void:
	var key := "%s:%d" % [match_info.get("id", ""), round_no]
	var owners := {}
	for p in Game.players:
		if p.owner != "":
			owners[p.owner] = true
	var all_ready := true
	for peer in game:
		if owners.has(peer.peer) and str(peer.p.get("rd", "")) != key:
			all_ready = false
	if all_ready or waited > 20.0:
		_host_go = key


func end_match() -> void:
	in_match = false
	lockstep = false
	_trailing = false
	_host_res = []
	_host_match = {}
	_host_go = ""
	round_key = ""
	get_tree().paused = false
	if not _local_players.is_empty():
		Game.players = _local_players.duplicate()
		_local_players.clear()
	Game.theme_plan.clear()


# --- Lockstep -----------------------------------------------------------------------

func start_round(round_no: int, game_node: Minigame) -> void:
	round_key = "%s:%d" % [match_info.get("id", "t"), round_no]
	current_game = game_node
	_inputs.clear()
	for p in Game.players:
		if not p.is_bot:
			_inputs[p.id] = {}
	_next = 0
	tick = 0
	_rec = DELAY
	_frame = 0
	_checks.clear()
	stalled = 0.0
	lockstep = true
	_trailing = false
	_hist.clear()
	_snaps.clear()
	_host_snap = []
	_last_snap = -1
	corrections = 0


func end_round() -> void:
	lockstep = false
	_trailing = in_match and not loopback
	current_game = null
	get_tree().paused = false


## Host: publish this round's result. Physics can drift by a hair between browsers, so
## everyone scores the host's result and the standings always agree.
func share_result(round_no: int, ranking: Array) -> void:
	var groups := []
	for group in ranking:
		groups.append(group.map(func(s): return s.id))
	_host_res = ["%s:%d" % [match_info.get("id", ""), round_no], groups]


## The host's result for a round as groups of PlayerSlots, or [] until it arrives.
func result_for(round_no: int) -> Array:
	var r = host_settings().get("res")
	if typeof(r) != TYPE_ARRAY or r.size() != 2 or str(r[0]) != "%s:%d" % [match_info.get("id", ""), round_no]:
		return []
	if typeof(r[1]) != TYPE_ARRAY:
		return []
	var out := []
	var seen := {}
	for group in r[1]:
		if typeof(group) != TYPE_ARRAY:
			return []
		var slots := []
		for sid in group:
			var slot := _slot(int(sid))
			if slot == null or seen.has(slot):
				return []
			seen[slot] = true
			slots.append(slot)
		out.append(slots)
	return out


func _physics_process(delta: float) -> void:
	_poll()
	if lockstep:
		_step(delta)
	elif _trailing:
		_trail()
	if in_match:
		_watch_peers()
	else:
		_watch_t = 0.0
	_publish()


func _step(delta: float) -> void:
	_frame += 1
	if current_game and _next > 0 and not _hist.has(tick):
		_after_tick()
	while _rec < _next + DELAY:
		_record(_rec)
		_rec += 1
	var stall_now: bool = test_stall.is_valid() and test_stall.call(_frame)
	if not stall_now and _have_all(_next):
		tick = _next
		_next += 1
		stalled = 0.0
		get_tree().paused = false
		if tick % CHECK_EVERY == 0 and tick > 0 and current_game:
			_checks[tick] = checksum(current_game)
			_compare_checks()
	else:
		stalled += delta
		get_tree().paused = true


# --- Snapshots: physics can differ in the last float bits between browsers, so the host
# shares where everyone is every few ticks and the other pages move to match.

## Runs once per simulated tick, after the game has simulated it.
func _after_tick() -> void:
	_hist[tick] = state_of(current_game)
	_hist.erase(tick - 180)
	if is_host and tick % SYNC_EVERY == 0:
		_host_snap = [round_key, tick, Array(_hist[tick])]
	if loopback:
		var due := tick - 3 # pretend snapshots take a few ticks to arrive
		if test_snaps.has(due):
			_snaps[due] = test_snaps[due]
	for t in _snaps.keys():
		if t <= tick:
			_apply_snap(t, _snaps[t])
			_snaps.erase(t)


## Every character's position, velocity and knockback in fixed point, plus alive.
static func state_of(mg: Minigame) -> PackedInt32Array:
	var out := PackedInt32Array()
	for ch in mg.chars:
		for v in [ch.global_position, ch.velocity, ch.knock]:
			out.append(roundi(v.x * UNITS))
			out.append(roundi(v.y * UNITS))
			out.append(roundi(v.z * UNITS))
		out.append(int(ch.alive))
	return out


## Shift each character by how far its state at tick t was from the host's.
func _apply_snap(t: int, theirs: PackedInt32Array) -> void:
	var mine: PackedInt32Array = _hist.get(t, PackedInt32Array())
	if mine.size() != theirs.size() or mine.size() != current_game.chars.size() * 10 or mine == theirs:
		return
	for i in current_game.chars.size():
		var ch: PlayerCharacter = current_game.chars[i]
		var o := i * 10
		if mine[o + 9] != theirs[o + 9] or not ch.alive:
			continue # fell on one page only: nothing sensible to nudge
		var d := []
		for k in 9:
			d.append((theirs[o + k] - mine[o + k]) / UNITS)
		ch.global_position += Vector3(d[0], d[1], d[2])
		ch.velocity += Vector3(d[3], d[4], d[5])
		ch.knock += Vector3(d[6], d[7], d[8])
	corrections += 1
	_hist[tick] = state_of(current_game)


## Round over on this page: keep supplying input, at the pace of the slowest page,
## until everyone has finished it too.
func _trail() -> void:
	while _rec < _next + DELAY:
		_record(_rec)
		_rec += 1
	if _have_all(_next):
		_next += 1


func _record(t: int) -> void:
	for p in Game.players:
		if p.is_bot:
			continue
		var inp := {}
		if loopback and test_input.is_valid():
			inp = test_input.call(p, t)
		elif p.owner == me:
			inp = {
				"move": Controls.move(p.device),
				"action": Controls.just_pressed(p.device, "action"),
				"hold": Controls.pressed(p.device, "action"),
				"item": Controls.just_pressed(p.device, "item"),
			}
		else:
			continue
		_inputs[p.id][t] = encode(inp)


func _have_all(t: int) -> bool:
	if t < DELAY:
		return true
	for sid in _inputs:
		if not _inputs[sid].has(t):
			return false
	return true


func input_for(slot: PlayerSlot) -> Dictionary:
	if tick < DELAY:
		return {"move": Vector2.ZERO, "action": false, "hold": false, "item": false}
	return decode(_inputs.get(slot.id, {}).get(tick, "KK0"))


static func encode(inp: Dictionary) -> String:
	var m: Vector2 = inp.get("move", Vector2.ZERO)
	var x := clampi(roundi(m.x * 10.0), -10, 10) + 10
	var y := clampi(roundi(m.y * 10.0), -10, 10) + 10
	var b := int(inp.get("action", false)) | int(inp.get("hold", false)) << 1 | int(inp.get("item", false)) << 2
	return AXIS[x] + AXIS[y] + str(b)


static func decode(code: String) -> Dictionary:
	var x := AXIS.find(code[0]) - 10
	var y := AXIS.find(code[1]) - 10
	var b := int(code[2])
	return {"move": Vector2(x, y) / 10.0, "action": b & 1 != 0, "hold": b & 2 != 0, "item": b & 4 != 0}


## Read other pages' input windows from their presence (only for players they own).
func _absorb_inputs() -> void:
	if not lockstep and not _trailing:
		return
	for peer in game:
		if peer.me:
			continue
		var sn = peer.p.get("sn")
		if not is_host and typeof(peer.p.get("h")) == TYPE_DICTIONARY and typeof(sn) == TYPE_ARRAY and sn.size() == 3 \
				and str(sn[0]) == round_key and int(sn[1]) > _last_snap and typeof(sn[2]) == TYPE_ARRAY:
			_last_snap = int(sn[1])
			_snaps[_last_snap] = PackedInt32Array(sn[2])
		var inp = peer.p.get("in")
		if typeof(inp) != TYPE_DICTIONARY or str(inp.get("r", "")) != round_key:
			continue
		var t0 := int(inp.get("t", 0))
		var s = inp.get("s", {})
		if typeof(s) != TYPE_DICTIONARY:
			continue
		for sid_text in s:
			var sid := int(sid_text)
			var slot := _slot(sid)
			if slot == null or slot.owner != peer.peer or slot.is_bot:
				continue
			var codes := str(s[sid_text])
			for i in codes.length() / 3:
				var t := t0 + i
				if t >= _next and not _inputs[sid].has(t):
					var c := codes.substr(i * 3, 3)
					if AXIS.find(c[0]) >= 0 and AXIS.find(c[1]) >= 0 and c[2] in "01234567":
						_inputs[sid][t] = c


func _slot(sid: int) -> PlayerSlot:
	for p in Game.players:
		if p.id == sid:
			return p
	return null


func _publish() -> void:
	if not OS.has_feature("web") or not available:
		return
	var lob := {"v": VERSION}
	if is_host and in_game():
		lob.adv = {"code": game_code, "n": total_players(), "open": not in_match}
	_set_presence("lobby", lob)
	if not in_game():
		return
	_absorb_inputs()
	var g := {"v": VERSION}
	if in_match:
		g.m = str(match_info.get("id", ""))
	else:
		var pl := []
		for p in Game.players:
			if not p.is_bot:
				pl.append([p.device, p.character])
		g.pl = pl
	if is_host:
		var h := {"rounds": Game.rounds_total, "bots": Game.players.filter(func(p): return p.is_bot).size() if not in_match else 0}
		if not _host_match.is_empty():
			h.match = _host_match
		if _host_go != "":
			h.go = _host_go
		if not _host_res.is_empty():
			h.res = _host_res
		g.h = h
	if ready_key != "":
		g.rd = ready_key
	if lockstep or _trailing:
		var s := {}
		var t0 := maxi(DELAY, _rec - WINDOW)
		for p in Game.players:
			if p.owner == me and not p.is_bot:
				var codes := ""
				for t in range(t0, _rec):
					codes += _inputs[p.id].get(t, "KK0")
				s[str(p.id)] = codes
		g["in"] = {"r": round_key, "t": t0, "s": s}
		if is_host and not _host_snap.is_empty():
			g.sn = _host_snap
		var last: int = _checks.keys().max() if not _checks.is_empty() else -1
		if last >= 0:
			g.ck = [round_key, last, _checks[last]]
	_set_presence("game", g)
	if not in_match:
		_maybe_start_match()


## Simulation fingerprint: positions, who's alive and the scores.
static func checksum(mg: Minigame) -> int:
	var parts := []
	for ch in mg.chars:
		parts.append([snappedf(ch.global_position.x, 0.01), snappedf(ch.global_position.y, 0.01), snappedf(ch.global_position.z, 0.01), ch.alive])
	for p in mg.players:
		parts.append(mg.status_text(p))
	return hash(parts)


func _compare_checks() -> void:
	for peer in game:
		if peer.me:
			continue
		var ck = peer.p.get("ck")
		if typeof(ck) == TYPE_ARRAY and ck.size() == 3 and str(ck[0]) == round_key and _checks.has(int(ck[1])):
			if int(_checks[int(ck[1])]) != int(ck[2]) and not desync:
				desync = true
				push_warning("Net: out of sync at tick %d" % int(ck[1]))


## A player's page closed mid-match: nobody can keep simulating without their input.
func _watch_peers() -> void:
	if loopback:
		return
	# Wall-clock time: a struggling page may run its physics slower than real time.
	var now := Time.get_ticks_msec() / 1000.0
	var delta := minf(now - _watch_t, 1.0) if _watch_t > 0.0 else 0.0
	_watch_t = now
	if _aborted:
		return
	# Gone = closed the page, or went back to the lobby after being in this match. Pages
	# that haven't loaded the match yet get a longer grace (slow phones).
	var in_room := {}
	var playing := {}
	var id := str(match_info.get("id", ""))
	for peer in game:
		in_room[peer.peer] = true
		if str(peer.p.get("m", "")) == id:
			playing[peer.peer] = true
			_arrived[peer.peer] = true
	var owners := {}
	for p in Game.players:
		if p.owner != "" and p.owner != me:
			owners[p.owner] = true
	for o in owners:
		if playing.has(o):
			_missing.erase(o)
			continue
		_missing[o] = _missing.get(o, 0.0) + delta
		var limit := PEER_TIMEOUT if _arrived.has(o) or not in_room.has(o) else START_GRACE
		if _missing[o] > limit:
			_aborted = true
			print("Net: match aborted, %s left" % o)
			match_aborted.emit("A player left the game.")
			return

class_name Minigame
extends Node3D
## Base class for every minigame. A subclass sets its info in _init(), builds the
## arena in build(), runs its rules in tick(), and decides placements in rank().
##
## Lifecycle (driven by MatchHost): setup() -> [intro + countdown] -> begin() -> finished(ranking)

signal finished(ranking: Array)

# --- Info shown on the intro card ---
var title := "Minigame"
var tagline := ""
var rules: Array[String] = []
var action_name := "Dash"
var accent := Color("f4a6c8")

# --- Rules ---
var time_limit := 45.0 ## 0 = no timer.
var last_standing := false ## Ends when one (or no) player is left.
var bumps_enabled := true
var bump_radius := 0.62
var bump_power := 9.5

var players: Array[PlayerSlot] = []
var chars: Array[PlayerCharacter] = []
var arena: Arena
var running := false
var ended := false
var time_left := 0.0
var elapsed := 0.0
var rng := RandomNumberGenerator.new()
var bot_mem := {} ## PlayerCharacter -> Dictionary scratch space for CPU brains.

var _out_order: Array = [] ## Groups of PlayerSlots, in the order they were knocked out.
var _out_tick := -1
var _tick := 0
var _hud: CanvasLayer
var _timer_label: Label
var _timer_panel: Control
var _status_labels := {}


func setup(p_players: Array[PlayerSlot]) -> void:
	players = p_players
	rng.randomize()
	arena = Arena.new()
	add_child(arena)
	build()
	_build_hud()


# --- Virtuals ---------------------------------------------------------------------

func build() -> void:
	pass


func on_begin() -> void:
	pass


func tick(_delta: float) -> void:
	pass


## Best group first. Default: survivors, then by how long each player lasted.
func rank() -> Array:
	return survival_ranking()


func bot_input(ch: PlayerCharacter) -> Dictionary:
	return {"move": bot_wander(ch), "action": false, "hold": false}


func status_text(slot: PlayerSlot) -> String:
	var ch := char_of(slot)
	return "" if ch == null or ch.alive else "OUT"


func on_out(_ch: PlayerCharacter) -> void:
	pass


func on_dash_hit(_attacker: PlayerCharacter, _victim: PlayerCharacter) -> void:
	pass


# --- Flow -------------------------------------------------------------------------

func spawn_characters(points: Array[Vector3]) -> void:
	for i in players.size():
		var ch := PlayerCharacter.new(players[i])
		arena.add_child(ch)
		ch.global_position = points[i % points.size()]
		ch.facing = Vector3(0, 0, 1)
		ch.input_provider = _input_for
		ch.fell.connect(_on_out)
		chars.append(ch)


func begin() -> void:
	running = true
	time_left = time_limit
	for ch in chars:
		ch.frozen = false
	on_begin()


func finish() -> void:
	if ended:
		return
	ended = true
	running = false
	for ch in chars:
		ch.frozen = true
	finished.emit(rank())


func _physics_process(delta: float) -> void:
	if not running:
		return
	_tick += 1
	elapsed += delta
	if time_limit > 0.0:
		var before := time_left
		time_left = maxf(0.0, time_left - delta)
		if time_left <= 5.0 and int(ceil(before)) != int(ceil(time_left)) and time_left > 0.0:
			Sfx.play("tick")
		if time_left <= 0.0:
			Sfx.play("whistle")
			finish()
			return
	tick(delta)
	if bumps_enabled:
		_resolve_bumps()
	if last_standing and running:
		var alive := alive_chars().size()
		if alive == 0 or (alive == 1 and players.size() > 1):
			finish()


func _process(_delta: float) -> void:
	if _timer_label:
		_timer_panel.visible = time_limit > 0.0
		_timer_label.text = str(int(ceil(time_left))) if running or ended else str(int(time_limit))
		_timer_label.add_theme_color_override("font_color", Color("ff6a5a") if running and time_left <= 5.0 else Color.WHITE)
	for slot in _status_labels:
		_status_labels[slot].text = status_text(slot)


# --- Helpers ----------------------------------------------------------------------

func char_of(slot: PlayerSlot) -> PlayerCharacter:
	for ch in chars:
		if ch.slot == slot:
			return ch
	return null


func alive_chars() -> Array[PlayerCharacter]:
	var out: Array[PlayerCharacter] = []
	for ch in chars:
		if ch.alive:
			out.append(ch)
	return out


func survival_ranking() -> Array:
	var out := []
	var survivors := []
	for ch in chars:
		if ch.alive:
			survivors.append(ch.slot)
	if not survivors.is_empty():
		out.append(survivors)
	for i in range(_out_order.size() - 1, -1, -1):
		out.append(_out_order[i])
	return out


func score_ranking(scores: Dictionary) -> Array:
	return Game.group_by_score(players, scores)


func _on_out(ch: PlayerCharacter) -> void:
	if _out_tick == _tick and not _out_order.is_empty():
		_out_order[-1].append(ch.slot)
	else:
		_out_order.append([ch.slot])
	_out_tick = _tick
	if arena:
		arena.shake(0.3)
	on_out(ch)


func _input_for(ch: PlayerCharacter) -> Dictionary:
	if ch.slot.is_bot:
		var inp := bot_input(ch)
		if inp.action and ch.can_dash:
			var dir := Vector3(inp.move.x, 0, inp.move.y)
			if not bot_dash_ok(ch, dir.normalized() if dir.length() > 0.1 else ch.facing):
				inp.action = false
		return inp
	var dev := ch.slot.device
	return {
		"move": Controls.move(dev),
		"action": Controls.just_pressed(dev, "action"),
		"hold": Controls.pressed(dev, "action"),
	}


func _resolve_bumps() -> void:
	for i in chars.size():
		var a := chars[i]
		if not a.alive:
			continue
		for j in range(i + 1, chars.size()):
			var b := chars[j]
			if not b.alive:
				continue
			var d := b.global_position - a.global_position
			if absf(d.y) > 0.8:
				continue
			d.y = 0.0
			var dist := d.length()
			if dist >= bump_radius:
				continue
			var n := d / dist if dist > 0.001 else Vector3.RIGHT
			var overlap := bump_radius - dist
			a.global_position -= n * overlap * 0.5
			b.global_position += n * overlap * 0.5
			var ad := a.is_dashing()
			var bd := b.is_dashing()
			if ad and not bd:
				_dash_hit(a, b, n)
			elif bd and not ad:
				_dash_hit(b, a, -n)
			elif ad and bd:
				a.hit(-n * bump_power * 0.6)
				b.hit(n * bump_power * 0.6)
				Sfx.play_varied("hit")
			on_touch(a, b)


## Called whenever two players touch (with or without dashing).
func on_touch(_a: PlayerCharacter, _b: PlayerCharacter) -> void:
	pass


func _dash_hit(attacker: PlayerCharacter, victim: PlayerCharacter, n: Vector3) -> void:
	if victim.invulnerable > 0.0:
		return
	victim.hit(n * bump_power, 0.3)
	attacker.end_dash()
	Sfx.play_varied("hit")
	Fx.burst(arena, victim.global_position + Vector3.UP * 0.5, Color.WHITE, 10, 3.0)
	arena.shake(0.2)
	on_dash_hit(attacker, victim)


# --- CPU helpers ------------------------------------------------------------------

func mem(ch: PlayerCharacter) -> Dictionary:
	if not bot_mem.has(ch):
		bot_mem[ch] = {"wander": ch.global_position, "wander_t": 0.0, "think": 0.0, "dir": Vector2.ZERO}
	return bot_mem[ch]


## Head towards `target` while steering around holes and edges.
func bot_go(ch: PlayerCharacter, target: Vector3, safe_margin := 0.9) -> Vector2:
	var d := target - ch.global_position
	d.y = 0.0
	if d.length() < 0.15:
		return Vector2.ZERO
	return bot_steer(ch, d.normalized(), safe_margin)


func bot_steer(ch: PlayerCharacter, dir: Vector3, safe_margin := 0.9) -> Vector2:
	var pos := ch.global_position
	for ang in [0.0, 0.5, -0.5, 1.0, -1.0, 1.6, -1.6, 2.3, -2.3, PI]:
		var d := dir.rotated(Vector3.UP, ang)
		if arena.is_safe(pos + d * safe_margin) and arena.is_safe(pos + d * safe_margin * 0.5):
			return Vector2(d.x, d.z)
	# Nothing safe ahead: head for the middle of the island.
	var home := arena.focus - pos
	home.y = 0.0
	return Vector2(home.x, home.z).normalized()


## Roam between random safe spots.
func bot_wander(ch: PlayerCharacter) -> Vector2:
	var m := mem(ch)
	m.wander_t -= get_physics_process_delta_time()
	if m.wander_t <= 0.0 or ch.global_position.distance_to(m.wander) < 0.6:
		var tiles := arena.solid_tiles()
		if not tiles.is_empty():
			var t: ArenaTile = tiles[rng.randi() % tiles.size()]
			m.wander = t.global_position + Vector3(0, t.top_y, 0)
		m.wander_t = rng.randf_range(1.0, 3.0)
	return bot_go(ch, m.wander)


func nearest(ch: PlayerCharacter, among: Array = []) -> PlayerCharacter:
	var pool: Array = among if not among.is_empty() else chars
	var best: PlayerCharacter = null
	var best_d := INF
	for o in pool:
		if o == ch or not o.alive:
			continue
		var d := ch.global_position.distance_squared_to(o.global_position)
		if d < best_d:
			best_d = d
			best = o
	return best


## Would a dash in `dir` stay on solid ground? Careless CPUs sometimes don't check.
func bot_dash_ok(ch: PlayerCharacter, dir: Vector3) -> bool:
	for d in [0.8, 1.6, 2.6]:
		if not arena.is_safe(ch.global_position + dir * d):
			return rng.randf() < 0.12 * (1.0 - ch.slot.skill)
	return true


## Per-tick chance scaled by CPU skill; `per_second` is the rate for a perfect bot.
func bot_roll(ch: PlayerCharacter, per_second: float) -> bool:
	return rng.randf() < per_second * ch.slot.skill * get_physics_process_delta_time()


## Is `target` roughly in front of `ch`, within `dist`?
func bot_lined_up(ch: PlayerCharacter, target: Vector3, dist := 2.6) -> bool:
	var d := target - ch.global_position
	d.y = 0.0
	return d.length() < dist and d.normalized().dot(ch.facing) > 0.8


# --- HUD --------------------------------------------------------------------------

func _build_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.layer = 1
	add_child(_hud)
	var root := Ui.full_rect(Control.new())
	_hud.add_child(root)

	var top := Ui.panel(Color(0.11, 0.09, 0.16, 0.75), Art.OUTLINE, 8)
	top.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	top.position.y = 10
	root.add_child(top)
	_timer_panel = top
	_timer_label = Ui.label(str(int(time_limit)), 40)
	_timer_label.custom_minimum_size = Vector2(90, 0)
	top.add_child(_timer_label)
	top.resized.connect(func(): top.position.x = (root.size.x - top.size.x) * 0.5)

	var name_tag := Ui.label(title.to_upper(), 22, accent)
	name_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_tag.position = Vector2(20, 16)
	root.add_child(name_tag)

	var bar := HBoxContainer.new()
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 10)
	bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_top = -64
	bar.offset_bottom = -12
	root.add_child(bar)
	for slot in players:
		var chip := Ui.panel(Color(0.11, 0.09, 0.16, 0.75), slot.color.darkened(0.2), 6)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		h.add_child(Ui.label(slot.display_name, 20, slot.color.lightened(0.3), 6))
		var status := Ui.label("", 20, Color.WHITE, 6)
		status.custom_minimum_size = Vector2(36, 0)
		h.add_child(status)
		chip.add_child(h)
		bar.add_child(chip)
		_status_labels[slot] = status

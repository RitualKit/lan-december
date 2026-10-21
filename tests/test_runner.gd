extends Node
## Headless test suite. Run with tools/run_tests.sh.
## 1. Unit checks for art templates, scoring and round planning.
## 2. Every minigame played to the end by CPUs with 2, 4 and 8 players.
## 3. A full match from first round to podium.

var failures := 0
var checks := 0


func _ready() -> void:
	var only := OS.get_environment("ONLY")
	if only == "" or only == "unit":
		_unit()
	if only == "" or only == "powerups":
		await _powerups()
	if only == "" or only == "lockstep":
		await _lockstep()
	if only == "" or only == "minigames":
		await _minigames()
	if only == "" or only == "match":
		await _full_match()
	print("\n%d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)


func check(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		failures += 1
		printerr("FAIL: ", what)


func _unit() -> void:
	print("== unit")
	for i in Art.CHARACTERS.size():
		var sheet := Art.character_texture(i)
		check(sheet != null and sheet.get_width() == 64 and sheet.get_height() == 112, "character %d sheet is 4x7 frames of 16x16" % Art.CHARACTERS[i])
	for item in Powerups.ITEMS:
		check(Powerups.icon_of(item) != null, "power-up icon for %s" % item)
	for fx in ["fx/1", "fx/2", "fx/4", "fx/7", "fx/12", "fx/15", "fx/18"]:
		check(Art.pack(fx) != null and Art.pack(fx).get_height() == 32, "effect strip %s" % fx)
	for sound in Sfx.FILES:
		check(Sfx.get_stream(sound) != null, "pack sound %s" % sound)
	for icon_name in Art.ICONS:
		var rows: Array = Art.ICONS[icon_name]
		check(rows.all(func(r): return r.length() == rows[0].length()), "icon '%s' rows equal width" % icon_name)
	Game.players.clear()
	for i in 4:
		Game.add_player("", true)
	var looks := {}
	for p in Game.players:
		looks[p.character] = true
	check(looks.size() == 4, "every player gets a different character")
	check(not looks.has(Game.next_free_character(Game.players[0].character)), "NEW LOOK picks an unused character")
	Game.players.clear()
	for t in ["grass", "cliff", "cliff_top", "path", "bark", "blossom", "leaves", "rock", "wood", "cloth", "paint_ff0000"]:
		check(Art.texture(t).get_width() == 16, "texture %s generated" % t)

	# Scoring: ties share the better placement, next group skips places.
	var a := PlayerSlot.new(0, "", true)
	var b := PlayerSlot.new(1, "", true)
	var c := PlayerSlot.new(2, "", true)
	var d := PlayerSlot.new(3, "", true)
	var pts := Game.award([[a, b], [c], [d]], 1)
	check(pts[a] == 10 and pts[b] == 10, "tied winners both get 1st place points")
	check(pts[c] == Game.PLACEMENT_POINTS[2], "after a 2-way tie the next player is 3rd")
	check(pts[d] == Game.PLACEMENT_POINTS[3], "4th place points")
	check(a.round_wins == 1 and c.round_wins == 0, "round wins counted")
	var groups := Game.group_by_score([a, b, c, d], {a: 3, b: 7, c: 3, d: 0})
	check(groups.size() == 3 and groups[0] == [b] and groups[1].size() == 2 and groups[2] == [d], "group_by_score groups ties")

	Game.rounds_total = 10
	check(Game.multiplier(8) == 1 and Game.multiplier(9) == 2 and Game.multiplier(10) == 2, "last two rounds are double points")
	for trial in 20:
		Game.rounds_total = [5, 10, 15][trial % 3]
		Game.plan_rounds()
		check(Game.round_plan.size() == Game.rounds_total, "plan has one game per round")
		var ok := true
		for i in range(1, Game.round_plan.size()):
			if Game.round_plan[i] == Game.round_plan[i - 1]:
				ok = false
		check(ok, "no minigame twice in a row")
		var first := Game.round_plan.slice(0, mini(Game.MINIGAMES.size(), Game.rounds_total))
		var unique := {}
		for p in first:
			unique[p] = true
		check(unique.size() == first.size(), "every minigame plays before any repeats")
	Game.rounds_total = 10


func _bots(n: int) -> Array[PlayerSlot]:
	var out: Array[PlayerSlot] = []
	for i in n:
		var s := PlayerSlot.new(i, "", true)
		s.skill = 0.55 + 0.4 * i / maxf(1.0, n - 1)
		out.append(s)
	return out


func _minigames() -> void:
	print("== minigames")
	var only_game := OS.get_environment("GAME")
	for path in Game.MINIGAMES.filter(func(p): return only_game == "" or p.contains(only_game)):
		for n in [2, 4, 8]:
			Game.look_3d = n == 4 # Exercise the 3D look too.
			var players := _bots(n)
			var mg: Minigame = load(path).new()
			add_child(mg)
			mg.setup(players)
			check(mg.chars.size() == n, "%s spawns %d characters" % [path.get_file(), n])
			var result := {"ranking": null}
			mg.finished.connect(func(r): result.ranking = r)
			mg.begin()
			var frames := 0
			while result.ranking == null and frames < 60 * 150:
				await get_tree().physics_frame
				frames += 1
			var ranking = result.ranking
			check(ranking != null, "%s with %d players finishes (%d frames)" % [path.get_file(), n, frames])
			if ranking != null:
				var seen := []
				for group in ranking:
					check(not group.is_empty(), "%s: no empty placement groups" % path.get_file())
					seen.append_array(group)
				check(seen.size() == n, "%s with %d: every player ranked once (got %d)" % [path.get_file(), n, seen.size()])
				for p in players:
					check(seen.has(p), "%s: %s is ranked" % [path.get_file(), p.display_name])
				print("  %-22s %d players: %5.1fs, winner group %s" % [path.get_file(), n, frames / 60.0, ranking[0].map(func(s): return s.display_name)])
			mg.queue_free()
			await get_tree().process_frame


## Online play depends on every page simulating identically. Play each minigame twice
## with the same seed and scripted inputs; the second run stalls at random frames (a
## slow connection) and uses the 3D look. Checksums every 60 ticks must match.
func _lockstep() -> void:
	print("== lockstep")
	process_mode = Node.PROCESS_MODE_ALWAYS
	var only_game := OS.get_environment("GAME")
	for path in Game.MINIGAMES.filter(func(p): return only_game == "" or p.contains(only_game)):
		var runs := []
		var snaps := {}
		for run in 2:
			Game.players.clear()
			for i in 4:
				var slot := PlayerSlot.new(i, "" if i >= 2 else "net", i >= 2)
				slot.owner = "" if i >= 2 else "peer%d" % i
				slot.skill = 0.6 + 0.1 * i
				Game.players.append(slot)
			Game.look_3d = run == 1 and OS.get_environment("SAME_LOOK") == ""
			Net.loopback = true
			Net.in_match = true
			Net.match_info = {"id": "test", "seed": 4242}
			Net.test_input = func(slot: PlayerSlot, t: int) -> Dictionary:
				var phase := (t / 40 + slot.id * 3) % 8
				var a := TAU * phase / 8.0
				return {"move": Vector2(cos(a), sin(a)), "action": (t + slot.id * 7) % 50 == 0,
					"hold": (t / 25) % 2 == 0, "item": (t + slot.id) % 90 == 0}
			var stall_rng := RandomNumberGenerator.new()
			stall_rng.seed = 99
			Net.test_stall = (func(_f: int) -> bool: return stall_rng.randf() < 0.3) if run == 1 and OS.get_environment("NO_STALL") == "" else Callable()
			var mg: Minigame = load(path).new()
			mg.seed_value = Net.round_seed(1)
			mg.process_mode = Node.PROCESS_MODE_PAUSABLE # as under MatchHost in the game
			add_child(mg)
			mg.setup(Game.players)
			for f in 30:
				await get_tree().physics_frame # an "intro" of different length per run
			if run == 1:
				for f in 17:
					await get_tree().physics_frame
			# Run 1 plays the guest: it gets run 0's snapshots, as if from the host.
			Net.test_snaps = snaps if run == 1 and OS.get_environment("NO_SNAPS") == "" else {}
			Net.start_round(1, mg)
			mg.begin()
			var done := {"v": false}
			mg.finished.connect(func(_r): done.v = true)
			var frames := 0
			var trace := {}
			while not done.v and Net.tick < 1500 and frames < 6000:
				await get_tree().physics_frame
				frames += 1
				if run == 0:
					for st in Net._hist:
						if st % Net.SYNC_EVERY == 0:
							snaps[st] = Net._hist[st]
				if OS.get_environment("TRACE") != "" and not trace.has(Net.tick):
					trace[Net.tick] = str(mg.chars.map(func(c): return [c.global_position, c.velocity, c.facing, c.alive, c.stun, c.invulnerable])) + str(mg.players.map(func(p): return mg.status_text(p)))
			if OS.get_environment("TRACE") != "":
				if run == 0:
					set_meta("trace", trace)
				else:
					var t0: Dictionary = get_meta("trace")
					for t in range(0, 1500):
						if t0.get(t) != trace.get(t):
							print("    trace diverges at tick ", t, "\n      A ", t0.get(t), "\n      B ", trace.get(t), "\n    previous\n      A ", t0.get(t - 1), "\n      B ", trace.get(t - 1))
							break
			runs.append({"checks": Net._checks.duplicate(), "end": Net.tick, "final": Net.checksum(mg), "fixes": Net.corrections})
			Net.end_round()
			mg.queue_free()
			await get_tree().process_frame
		# Checkpoints may differ for a moment before a snapshot lands; the ending may not.
		var same: bool = runs[0].end == runs[1].end and runs[0].final == runs[1].final
		var off := 0
		for t in runs[0].checks:
			if runs[1].checks.get(t) != runs[0].checks[t]:
				off += 1
		check(same, "%s ends identically with stalls, either look and the host's snapshots (ended at tick %d vs %d)" % [path.get_file(), runs[0].end, runs[1].end])
		print("  %-22s %s  (%d ticks, %d/%d checkpoints differed, %d snapshot fixes)" % [path.get_file(), "same" if same else "DIFFERENT", runs[0].end, off, runs[0].checks.size(), runs[1].fixes])
	Net.loopback = false
	Net.in_match = false
	Net.test_input = Callable()
	Net.test_stall = Callable()
	Net.test_snaps = {}
	Game.look_3d = false
	Game.players.clear()


## Fire every item at a standing target and check it does something.
func _powerups() -> void:
	print("== powerups")
	var flip := false
	for item in Powerups.ITEMS:
		flip = not flip
		Game.look_3d = flip
		var mg: Minigame = load("res://minigames/petal_push.gd").new()
		add_child(mg)
		mg.setup(_bots(3))
		mg.begin()
		var user := mg.chars[0]
		var target := mg.chars[1]
		var bystander := mg.chars[2]
		for ch in mg.chars:
			ch.input_provider = Callable() # stand still
		user.global_position = Vector3(-2, 0.05, 0)
		user.facing = Vector3.RIGHT
		target.global_position = Vector3(-2 + (4.5 if item == "bomb" else 1.5), 0.05, 0)
		bystander.global_position = Vector3(-2, 0.05, -3.5)
		await get_tree().physics_frame
		var start := target.global_position
		mg.powerups.give(user, item)
		check(mg.powerups.held.get(user) == item, "%s: picked up" % item)
		check(mg.powerups.use(user), "%s: used" % item)
		check(not mg.powerups.held.has(user), "%s: used up" % item)
		var affected := false
		for f in 90:
			await get_tree().physics_frame
			if target.stun > 0.0 or target.has_status("frozen") or not target.alive or target.global_position.distance_to(start) > 0.3:
				affected = true
		match item:
			"giant", "speed", "shield":
				check(user.has_status(item), "%s: buff active on user" % item)
			_:
				check(affected, "%s: hits the target" % item)
		print("  %-10s ok" % item)
		mg.queue_free()
		await get_tree().process_frame

	# A shield blocks a dash hit.
	var mg2: Minigame = load("res://minigames/petal_push.gd").new()
	add_child(mg2)
	mg2.setup(_bots(2))
	mg2.begin()
	var shielded := mg2.chars[1]
	shielded.add_status("shield", 5.0)
	check(not shielded.hit(Vector3.RIGHT * 10.0, 0.3), "shield blocks knockback")
	check(shielded.knock.length() == 0.0, "shielded player isn't moved")
	mg2.queue_free()
	await get_tree().process_frame


func _full_match() -> void:
	print("== full match")
	Game.players.clear()
	for i in 4:
		Game.add_player("", true)
	Game.rounds_total = 10
	var main: Node = load("res://main/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	Game.start_match()
	var frames := 0
	var podium := false
	while frames < 60 * 60 * 20:
		await get_tree().physics_frame
		frames += 1
		if main.current and main.current.get_script() == main.Podium:
			podium = true
			break
	check(podium, "full match reaches the podium (%d frames, round %d)" % [frames, Game.round_number])
	check(Game.round_number == 10, "played all 10 rounds")
	var total := 0
	for p in Game.players:
		total += p.score
	check(total > 0, "points were awarded")
	print("  standings: ", Game.standings().map(func(p): return "%s %d" % [p.display_name, p.score]))
	main.queue_free()

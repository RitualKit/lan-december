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
	for path in Game.MINIGAMES:
		for n in [2, 4, 8]:
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


## Fire every item at a standing target and check it does something.
func _powerups() -> void:
	print("== powerups")
	for item in Powerups.ITEMS:
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

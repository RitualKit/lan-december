extends Node
## Runs the rounds: intro card -> countdown -> minigame -> results, then the podium.

const INTRO_TIMEOUT := 14.0
const RESULTS_TIMEOUT := 9.0
const ORDINALS := ["1st", "2nd", "3rd", "4th", "5th", "6th", "7th", "8th"]

var minigame: Minigame
var _layer: CanvasLayer
var _root: Control


func _ready() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 5
	add_child(_layer)
	_root = Ui.full_rect(Control.new())
	_layer.add_child(_root)
	_run.call_deferred()


func _run() -> void:
	while Game.round_number < Game.rounds_total:
		Game.round_number += 1
		await _play_round(Game.round_plan[Game.round_number - 1])
		if not is_inside_tree():
			return
	Game.main.goto_podium()


func _play_round(path: String) -> void:
	minigame = load(path).new()
	add_child(minigame)
	minigame.setup(Game.players)

	await _intro()
	await _countdown()
	minigame.begin()
	var ranking: Array = await minigame.finished

	Sfx.play("whistle")
	Ui.banner(_root, "FINISH!", Ui.GOLD, 110, 0.9)
	Engine.time_scale = 0.3
	await get_tree().create_timer(0.45, true, false, true).timeout
	Engine.time_scale = 1.0
	await get_tree().create_timer(0.9).timeout

	var mult := Game.multiplier()
	var points := Game.award(ranking, mult)
	await _results(ranking, points, mult)
	minigame.queue_free()
	minigame = null


# --- Intro card ---------------------------------------------------------------------

func _intro() -> void:
	var card := _card()
	var v: VBoxContainer = card.get_child(0)
	v.add_child(Ui.label("ROUND %d / %d" % [Game.round_number, Game.rounds_total], 24, Color("b8b0c8"), 6))
	if Game.multiplier() > 1:
		var badge := Ui.label(">> DOUBLE POINTS <<", 30, Ui.GOLD, 8)
		v.add_child(badge)
		var tw := badge.create_tween().set_loops()
		tw.tween_property(badge, "modulate", Color(1.4, 1.2, 0.6), 0.4)
		tw.tween_property(badge, "modulate", Color.WHITE, 0.4)
	v.add_child(Ui.title(minigame.title.to_upper(), 56, minigame.accent, 14))
	v.add_child(Ui.body(minigame.tagline, 26, Color("fff2c0")))
	v.add_child(_spacer(6))
	for line in minigame.rules:
		var l := Ui.body("> " + line, 21)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		v.add_child(l)
	v.add_child(_spacer(6))
	v.add_child(Ui.label("SPACE · ENTER · (A)  =  %s" % minigame.action_name.to_upper(), 22, Ui.GOLD, 6))
	v.add_child(_spacer(4))

	var ready_row := HBoxContainer.new()
	ready_row.alignment = BoxContainer.ALIGNMENT_CENTER
	ready_row.add_theme_constant_override("separation", 10)
	v.add_child(ready_row)
	var ready := {}
	var chips := {}
	for slot in Game.players:
		var chip := Ui.label(slot.display_name, 20, slot.color.lightened(0.3), 6)
		chip.modulate = Color(1, 1, 1, 0.35)
		ready_row.add_child(chip)
		chips[slot] = chip
		if slot.is_bot:
			ready[slot] = true
			chip.modulate = Color.WHITE
	var hint := Ui.body("Press action when ready", 18, Color("b8b0c8"))
	v.add_child(hint)
	_pop_in(card)

	var t := 0.0
	var humans := Game.players.filter(func(p): return not p.is_bot)
	var min_time := 0.6 if humans.is_empty() else 1.0
	while t < INTRO_TIMEOUT:
		await get_tree().physics_frame
		if get_tree().paused:
			continue
		t += get_physics_process_delta_time()
		for slot in humans:
			if not ready.has(slot) and Controls.just_pressed(slot.device, "action"):
				ready[slot] = true
				chips[slot].modulate = Color.WHITE
				chips[slot].text = slot.display_name + " OK!"
				Sfx.play("blip", 1.3)
		if t > min_time and ready.size() == Game.players.size():
			break
		if humans.is_empty() and t > 1.5:
			break
	await _pop_out(card)


func _countdown() -> void:
	for n in ["3", "2", "1"]:
		Sfx.play("blip")
		Ui.banner(_root, n, Color.WHITE, 130, 0.35)
		await get_tree().create_timer(0.6).timeout
	Sfx.play("go")
	Ui.banner(_root, "GO!", Color("7cff8a"), 140, 0.3)


# --- Results ------------------------------------------------------------------------

func _results(ranking: Array, points: Dictionary, mult: int) -> void:
	var card := _card(980)
	var v: VBoxContainer = card.get_child(0)
	var winners: Array = ranking[0] if not ranking.is_empty() else []
	var head := "DRAW!" if winners.size() > 1 else ("%s WINS!" % winners[0].display_name if winners.size() == 1 else "NO WINNER")
	var head_color: Color = winners[0].color.lightened(0.3) if winners.size() == 1 else Ui.GOLD
	v.add_child(Ui.title(head, 48, head_color, 12))
	if mult > 1:
		v.add_child(Ui.label("double points!", 22, Ui.GOLD, 6))

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 48)
	cols.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(cols)

	var left := VBoxContainer.new()
	left.add_child(Ui.label("THIS ROUND", 22, Color("b8b0c8"), 6))
	var place := 0
	for group in ranking:
		for slot in group:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 12)
			var ord := Ui.label(ORDINALS[mini(place, 7)], 24, Ui.GOLD if place == 0 else Color.WHITE, 6)
			ord.custom_minimum_size = Vector2(60, 0)
			row.add_child(ord)
			row.add_child(Ui.player_tag(slot, "", 24))
			var pts := Ui.label("+%d" % points.get(slot, 0), 24, Color("7cff8a"), 6)
			pts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			pts.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			row.add_child(pts)
			row.custom_minimum_size = Vector2(340, 0)
			left.add_child(row)
		place += group.size()
	cols.add_child(left)

	var right := VBoxContainer.new()
	right.add_child(Ui.label("STANDINGS", 22, Color("b8b0c8"), 6))
	var standings := Game.standings()
	var rows := {}
	for i in standings.size():
		var slot := standings[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var crown := Ui.label(str(i + 1), 24, Ui.GOLD if i == 0 else Color("b8b0c8"), 6)
		crown.custom_minimum_size = Vector2(28, 0)
		row.add_child(crown)
		row.add_child(Ui.player_tag(slot, "", 24))
		var total := Ui.label(str(slot.score - slot.last_points), 24, Color.WHITE, 6)
		total.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		total.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(total)
		row.custom_minimum_size = Vector2(320, 0)
		right.add_child(row)
		rows[slot] = total
	cols.add_child(right)

	v.add_child(_spacer(8))
	var next_text := "Final results next!"
	if Game.round_number < Game.rounds_total:
		var nxt: Minigame = load(Game.round_plan[Game.round_number]).new()
		next_text = "Next up: %s%s" % [nxt.title, "  (double points!)" if Game.multiplier(Game.round_number + 1) > 1 else ""]
		nxt.free()
	v.add_child(Ui.body(next_text, 20, Color("fff2c0")))
	_pop_in(card)
	if winners.size() == 1:
		Sfx.play("win")

	# Count the new points up into the totals.
	await get_tree().create_timer(0.8).timeout
	for slot in rows:
		var label: Label = rows[slot]
		var from: int = slot.score - slot.last_points
		var tw := label.create_tween()
		tw.tween_method(func(x: float): label.text = str(int(x)), float(from), float(slot.score), 0.7)
	Sfx.play("point")

	var t := 0.0
	var humans := Game.players.filter(func(p): return not p.is_bot)
	while t < RESULTS_TIMEOUT:
		await get_tree().physics_frame
		if get_tree().paused:
			continue
		t += get_physics_process_delta_time()
		if t > 1.6 and humans.any(func(p): return Controls.just_pressed(p.device, "action")):
			break
		if humans.is_empty() and t > 2.0:
			break
	await _pop_out(card)


# --- Helpers ------------------------------------------------------------------------

func _card(width := 760) -> PanelContainer:
	var card := Ui.panel(Color(0.11, 0.09, 0.16, 0.92), Art.OUTLINE, 24)
	card.custom_minimum_size = Vector2(width, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(v)
	var center := Ui.full_rect(CenterContainer.new())
	center.add_child(card)
	_root.add_child(center)
	card.resized.connect(func(): card.pivot_offset = card.size * 0.5)
	return card


func _spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


func _pop_in(c: Control) -> void:
	c.scale = Vector2(0.85, 0.85)
	c.modulate.a = 0.0
	var tw := c.create_tween().set_parallel()
	tw.tween_property(c, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "modulate:a", 1.0, 0.15)


func _pop_out(c: Control) -> void:
	var tw := c.create_tween().set_parallel()
	tw.tween_property(c, "scale", Vector2(0.9, 0.9), 0.15)
	tw.tween_property(c, "modulate:a", 0.0, 0.15)
	await tw.finished
	c.get_parent().queue_free()

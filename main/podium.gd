extends Node3D
## Final results: top three on a podium, confetti, full standings.

var arena: Arena
var chars: Array[PlayerCharacter] = []
var _t := 0.0
var _hint: Label
var _confetti_t := 0.0


func _ready() -> void:
	arena = Arena.new()
	add_child(arena)
	var cells := Arena.disc(4.2)
	cells[Vector2i(0, -1)] = 3
	cells[Vector2i(-1, -1)] = 2
	cells[Vector2i(1, -1)] = 1
	arena.build(cells)
	arena.setup_view(Vector3(0, 2.2, 0.2), 15.0, 30.0)
	arena.decorate(21, 4.2, 8)

	var standings := Game.standings()
	var spots := [Vector3(0, 3.2, -1), Vector3(-1, 2.2, -1), Vector3(1, 1.2, -1)]
	var front := 0
	for i in standings.size():
		var ch := PlayerCharacter.new(standings[i])
		arena.add_child(ch)
		if i < 3:
			ch.position = spots[i]
		else:
			ch.position = Vector3(-2.5 + front * 1.0, 0.2, 1.4 + (front % 2) * 0.5)
			front += 1
		ch.frozen = true
		chars.append(ch)
	_build_ui(standings)
	Sfx.play("fanfare")


func _build_ui(standings: Array[PlayerSlot]) -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Ui.full_rect(Control.new())
	layer.add_child(root)
	var winner := standings[0]
	var tied := standings.size() > 1 and standings[1].score == winner.score and standings[1].round_wins == winner.round_wins
	var title := Ui.title("IT'S A TIE!" if tied else "%s IS THE CHAMPION!" % winner.display_name, 64, Ui.GOLD if tied else winner.color.lightened(0.35), 14)
	title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 20
	title.offset_bottom = 100
	root.add_child(title)

	var table := Ui.panel(Color(0.11, 0.09, 0.16, 0.85), Art.OUTLINE, 14)
	table.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	table.offset_left = -330
	table.offset_right = -24
	table.offset_top = -180
	table.offset_bottom = 180
	var v := VBoxContainer.new()
	v.add_child(Ui.label("FINAL STANDINGS", 22, Color("b8b0c8"), 6))
	for i in standings.size():
		var s := standings[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var n := Ui.label(str(i + 1), 24, Ui.GOLD if i == 0 else Color.WHITE, 6)
		n.custom_minimum_size = Vector2(26, 0)
		row.add_child(n)
		row.add_child(Ui.player_tag(s, "", 24))
		var pts := Ui.label("%d pts" % s.score, 22, Color.WHITE, 6)
		pts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pts.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(pts)
		v.add_child(row)
		v.add_child(Ui.body("%d round win%s" % [s.round_wins, "" if s.round_wins == 1 else "s"], 14, Color("8a82a0")))
	table.add_child(v)
	root.add_child(table)

	_hint = Ui.label("", 26, Color.WHITE, 8)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_hint.offset_top = -60
	_hint.offset_bottom = -16
	root.add_child(_hint)


func _physics_process(delta: float) -> void:
	_t += delta
	_confetti_t -= delta
	if _confetti_t <= 0.0 and _t < 20.0:
		_confetti_t = 1.4
		var colors: Array[Color] = [Ui.GOLD, Color("f4a6c8"), Color("7ab0ff"), Color("7cff8a")]
		Fx.confetti(arena, Vector3(randf_range(-3, 3), 0.5, randf_range(-2, 0)), colors)
	# Winner hops for joy.
	if chars.size() > 0 and chars[0].is_on_floor() and fmod(_t, 0.9) < delta:
		chars[0].velocity.y = 5.0
	if _t > 3.0:
		_hint.text = "Press action to return to the lobby"
		if Controls.any_just_pressed("action"):
			Game.main.goto_lobby()
	if _t > 6.0 and Game.human_count() == 0:
		Game.main.goto_lobby()

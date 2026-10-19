extends Minigame
## Join screen. Everyone runs around a little island; press action to join,
## step on the pads to add/remove CPUs, change your character or the round count,
## and stand on START together to begin.

const START_HOLD := 3.0
const ISLAND_RADIUS := 5.2

var pads := {} ## name -> {"pos": Vector3, "radius": float, "label": Label3D, "mesh": MeshInstance3D, "armed": bool}
var _start_t := 0.0
var _on_swap := {} ## Characters standing on the NEW LOOK pad (each swaps once per visit).
var _hint: Label
var _count_label: Label


func _init() -> void:
	title = "Lobby"
	time_limit = 0.0
	bump_power = 8.0


func _ready() -> void:
	setup(Game.players)


func build() -> void:
	var cells := Arena.disc(ISLAND_RADIUS)
	for c in [Vector2i(-4, -2), Vector2i(-4, -1), Vector2i(-3, -3), Vector2i(4, -1), Vector2i(4, 0)]:
		cells[c] = 1
	arena.build(cells)
	arena.setup_view(Vector3(0, 0, 0.8), 18.5, 54.0)
	arena.decorate(7, ISLAND_RADIUS, 8)
	var r := RandomNumberGenerator.new()
	r.seed = 11
	var tree := Props.blossom_tree(r)
	tree.position = Vector3(-4, 1, -2)
	arena.add_child(tree)

	_add_pad("start", Vector3(0, 0, -2.6), 1.1, Color("ffd45a"), "START")
	_add_pad("bot_add", Vector3(-3.0, 0, 1.6), 0.7, Color("6ad06a"), "+ CPU")
	_add_pad("bot_remove", Vector3(-1.4, 0, 3.4), 0.7, Color("e8645a"), "- CPU")
	_add_pad("rounds", Vector3(3.0, 0, 1.8), 0.7, Color("7ab0ff"), "")
	_add_pad("swap", Vector3(1.4, 0, 3.4), 0.7, Color("c88cff"), "NEW LOOK")
	_update_pad_labels()

	for slot in players:
		_spawn(slot)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Ui.full_rect(Control.new())
	layer.add_child(root)

	var logo := Ui.title("LAN DECEMBER", 76, Color("ffd6e8"), 18)
	logo.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	logo.offset_top = 14
	logo.offset_bottom = 110
	root.add_child(logo)
	var sub := Ui.label("a blossom island party game", 24, Color("fff2c0"), 8)
	sub.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	sub.offset_top = 98
	sub.offset_bottom = 130
	root.add_child(sub)
	var bob := logo.create_tween().set_loops()
	bob.tween_property(logo, "offset_top", 20.0, 1.2).set_trans(Tween.TRANS_SINE)
	bob.tween_property(logo, "offset_top", 14.0, 1.2).set_trans(Tween.TRANS_SINE)

	var help := Ui.panel(Color(0.11, 0.09, 0.16, 0.8), Art.OUTLINE, 12)
	help.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	help.offset_left = 16
	help.offset_bottom = -16
	help.grow_vertical = Control.GROW_DIRECTION_BEGIN
	help.custom_minimum_size = Vector2(330, 0)
	var v := VBoxContainer.new()
	v.add_child(Ui.label("JOIN", 22, Ui.GOLD, 6))
	v.add_child(Ui.body("SPACE  ·  ENTER  ·  (A)", 18))
	v.add_child(Ui.label("MOVE / DASH", 22, Ui.GOLD, 6))
	v.add_child(Ui.body("WASD  ·  Arrows  ·  Stick, then action", 18))
	v.add_child(Ui.label("USE ITEM", 22, Ui.GOLD, 6))
	v.add_child(Ui.body("E  ·  Right Shift  ·  (X)", 18))
	v.add_child(Ui.body("Leave: E · Backspace · (B)", 16, Color("b8b0c8")))
	help.add_child(v)
	root.add_child(help)

	_hint = Ui.label("", 30, Color.WHITE, 10)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_hint.offset_top = -64
	_hint.offset_bottom = -20
	root.add_child(_hint)

	_count_label = Ui.label("", 22, Color("e8e2f0"), 6)
	_count_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_count_label.offset_left = -260
	_count_label.offset_top = -60
	_count_label.offset_right = -20
	_count_label.offset_bottom = -20
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(_count_label)
	running = true


func _add_pad(pad_name: String, pos: Vector3, radius: float, color: Color, text: String) -> void:
	var mesh := Art.zone_decal(color, radius, 0.45)
	mesh.position = pos
	arena.add_child(mesh)
	var label := Label3D.new()
	label.text = text
	label.font = Art.font(true)
	label.font_size = 64
	label.outline_size = 16
	label.outline_modulate = Art.OUTLINE
	label.modulate = color.lightened(0.4)
	label.pixel_size = 0.006
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.layers = 2
	label.position = pos + Vector3(0, 0.75, 0)
	arena.add_child(label)
	pads[pad_name] = {"pos": pos, "radius": radius, "label": label, "decal": mesh, "armed": true, "color": color}


func _update_pad_labels() -> void:
	pads["rounds"].label.text = "%d ROUNDS" % Game.rounds_total


func _spawn(slot: PlayerSlot) -> PlayerCharacter:
	var ch := PlayerCharacter.new(slot)
	arena.add_child(ch)
	var tiles := arena.solid_tiles()
	var t: ArenaTile = tiles[rng.randi() % tiles.size()]
	ch.global_position = Vector3(t.cell.x, t.top_y + 6.0, t.cell.y)
	ch.input_provider = _input_for
	ch.fell.connect(_on_fell)
	ch.frozen = false
	chars.append(ch)
	return ch


func _on_fell(ch: PlayerCharacter) -> void:
	# No elimination in the lobby: drop back in from the sky.
	await get_tree().create_timer(0.8).timeout
	if is_instance_valid(ch) and chars.has(ch):
		ch.revive_at(Vector3(rng.randf_range(-2, 2), 7.0, rng.randf_range(-1, 2)))


func _join(device: String, bot := false) -> void:
	var slot := Game.add_player(device, bot)
	if slot == null:
		return
	players = Game.players
	var ch := _spawn(slot)
	Sfx.play("join")
	Fx.burst(arena, ch.global_position - Vector3(0, 5.5, 0), slot.color, 20, 5.0)


func _leave(slot: PlayerSlot) -> void:
	var ch := char_of(slot)
	if ch:
		Fx.burst(arena, ch.global_position + Vector3.UP * 0.5, slot.color, 20, 4.0)
		chars.erase(ch)
		ch.queue_free()
	Game.remove_player(slot)
	players = Game.players
	Sfx.play("leave")


func tick(delta: float) -> void:
	for dev in Controls.devices():
		var slot := Game.player_for_device(dev)
		if slot == null and Controls.just_pressed(dev, "action"):
			_join(dev)
		elif slot and Controls.just_pressed(dev, "back"):
			_leave(slot)
	if Controls.any_just_pressed("bot_add"):
		_add_bot()
	if Controls.any_just_pressed("bot_remove"):
		_remove_bot()

	var humans := chars.filter(func(c): return not c.slot.is_bot)
	for pad_name in pads:
		var pad: Dictionary = pads[pad_name]
		var on := humans.filter(func(c): return _on_pad(c, pad))
		pad.decal.emission_energy = 2.5 if not on.is_empty() else 0.5
		if pad_name == "start":
			continue
		if pad_name == "swap":
			_swap_looks(on)
			continue
		if on.is_empty():
			pad.armed = true
		elif pad.armed:
			pad.armed = false
			match pad_name:
				"bot_add": _add_bot()
				"bot_remove": _remove_bot()
				"rounds": _cycle_rounds()

	var on_start := humans.filter(func(c): return _on_pad(c, pads["start"]))
	var ready := not humans.is_empty() and on_start.size() == humans.size() and players.size() >= 2
	if ready:
		var before := _start_t
		_start_t += delta
		if int(before) != int(_start_t):
			Sfx.play("blip", 1.0 + _start_t * 0.2)
		pads["start"].label.text = str(int(ceil(START_HOLD - _start_t)))
		if _start_t >= START_HOLD:
			running = false
			Sfx.play("go")
			Game.start_match()
			return
	else:
		_start_t = 0.0
		pads["start"].label.text = "START"

	if humans.is_empty():
		_hint.text = "Press SPACE, ENTER or (A) to join!"
	elif players.size() < 2:
		_hint.text = "Need 2+ players. Grab a friend or step on + CPU"
	elif not ready:
		_hint.text = "Everyone stand on START to begin  (%d/%d)" % [on_start.size(), humans.size()]
	else:
		_hint.text = "Starting..."
	_count_label.text = "%d / %d players" % [players.size(), Game.MAX_PLAYERS]


func _on_pad(ch: PlayerCharacter, pad: Dictionary) -> bool:
	var d: Vector3 = ch.global_position - pad.pos
	return ch.alive and ch.is_on_floor() and Vector2(d.x, d.z).length() < pad.radius


func _swap_looks(on: Array) -> void:
	for ch in on:
		if not _on_swap.has(ch):
			var slot: PlayerSlot = ch.slot
			slot.character = Game.next_free_character(slot.character)
			ch.sprite.texture = Art.character_texture(slot.character)
			Sfx.play("powerup", 1.2, -4.0)
			Fx.anim(arena, ch.global_position + Vector3.UP * 0.5, "fx/18", 1.4)
	_on_swap.clear()
	for ch in on:
		_on_swap[ch] = true


func _add_bot() -> void:
	if players.size() < Game.MAX_PLAYERS:
		_join("", true)


func _remove_bot() -> void:
	for i in range(players.size() - 1, -1, -1):
		if players[i].is_bot:
			_leave(players[i])
			return


func _cycle_rounds() -> void:
	var i := Game.ROUND_CHOICES.find(Game.rounds_total)
	Game.rounds_total = Game.ROUND_CHOICES[(i + 1) % Game.ROUND_CHOICES.size()]
	_update_pad_labels()
	Sfx.play("point")


func bot_input(ch: PlayerCharacter) -> Dictionary:
	# CPUs mill about, but keep off the pads so they don't trigger anything.
	var move := bot_wander(ch)
	var probe := ch.global_position + Vector3(move.x, 0, move.y) * 0.8
	for pad in pads.values():
		var d: Vector3 = probe - pad.pos
		if Vector2(d.x, d.z).length() < pad.radius + 0.3:
			move = Vector2(-move.y, move.x)
	var target := nearest(ch)
	var dash := target != null and bot_lined_up(ch, target.global_position, 1.8) and bot_roll(ch, 0.4)
	return {"move": move * 0.6, "action": dash, "hold": false}

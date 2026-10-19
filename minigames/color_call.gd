extends Minigame
## A colour is called. Get onto a tile of that colour before every other tile drops.
## The calls come faster each round. Last one standing wins.

const COLORS := {
	"RED": Color("e8433f"), "BLUE": Color("3f7fe8"), "YELLOW": Color("f2c230"), "GREEN": Color("4cc256"),
	"PURPLE": Color("a65be0"),
}
const MAX_CALLS := 12

enum Phase { CALL, DROP, RESET }

var phase := Phase.RESET
var called := ""
var call_no := 0
var tile_color := {} ## ArenaTile -> colour name
var _t := 0.0
var _call_time := 4.0
var _call_label: Label
var size := 9


func _init() -> void:
	title = "Color Call"
	tagline = "Stand on the colour that's called!"
	rules = [
		"A colour is called out. Get onto a tile of that colour.",
		"When time's up, every other tile drops into the sea.",
		"Calls come faster each round. Last one standing wins.",
	]
	action_name = "Dash"
	accent = Color("f2c230")
	time_limit = 0.0
	last_standing = true
	bump_power = 7.0


func build() -> void:
	size = 9 if players.size() <= 4 else 11
	arena.build(Arena.rect(size, size))
	arena.setup_view(Vector3.ZERO, 16.0 + size * 0.75)
	arena.decorate(rng.randi(), size * 0.6)
	spawn_characters(arena.spawn_ring(players.size(), size * 0.3))
	_paint_floor()


func _build_hud() -> void:
	super()
	_call_label = Ui.title("", 64, Color.WHITE, 16)
	_call_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_call_label.offset_top = 70
	_call_label.offset_left = -400
	_call_label.offset_right = 400
	_call_label.offset_bottom = 150
	_hud.add_child(_call_label)


func _paint_floor() -> void:
	# Early calls: four colours in 2x2 patches. Later: five colours, single tiles.
	var names := COLORS.keys()
	if call_no < 5:
		names.erase("PURPLE")
	var cell_size := 2.0 if call_no < 6 else 1.0
	var patch := {}
	for t in arena.tiles.values():
		var key := Vector2i(floori(t.cell.x / cell_size), floori(t.cell.y / cell_size))
		if not patch.has(key):
			patch[key] = names[rng.randi() % names.size()]
		var cname: String = patch[key]
		# Sprinkle a few odd tiles in so the pattern isn't too blocky.
		if rng.randf() < 0.15:
			cname = names[rng.randi() % names.size()]
		tile_color[t] = cname
		var tex: String = "paint_" + (COLORS[cname] as Color).to_html(false)
		if t.state == ArenaTile.State.GONE:
			t.restore(tex)
		else:
			t.set_top(tex)


func on_begin() -> void:
	_next_call()


func _next_call() -> void:
	call_no += 1
	phase = Phase.CALL
	_t = 0.0
	_call_time = maxf(1.1, 3.8 - call_no * 0.3)
	var present := {}
	for t in tile_color:
		present[tile_color[t]] = true
	var options := present.keys()
	called = options[rng.randi() % options.size()]
	_call_label.text = called + "!"
	_call_label.add_theme_color_override("font_color", COLORS[called].lightened(0.2))
	Sfx.play("whistle", 1.2)


func tick(delta: float) -> void:
	_t += delta
	match phase:
		Phase.CALL:
			var left := _call_time - _t
			_call_label.text = "%s!  %.1f" % [called, maxf(0.0, left)]
			if int(left * 4.0) != int((left + delta) * 4.0) and left < 1.2:
				Sfx.play("tick")
			if left <= 0.0:
				_drop()
		Phase.DROP:
			if _t > 2.0:
				if alive_chars().size() <= 1 or call_no >= MAX_CALLS:
					finish()
					return
				phase = Phase.RESET
				_t = 0.0
				_paint_floor()
				_call_label.text = ""
		Phase.RESET:
			if _t > 0.9:
				_next_call()


func _drop() -> void:
	phase = Phase.DROP
	_t = 0.0
	_call_label.text = ""
	Sfx.play("crack")
	arena.shake(0.3)
	for t in tile_color:
		if tile_color[t] != called:
			t.crack(0.25)


func status_text(slot: PlayerSlot) -> String:
	var ch := char_of(slot)
	return "" if ch == null or ch.alive else "OUT"


func bot_input(ch: PlayerCharacter) -> Dictionary:
	var m := mem(ch)
	if phase != Phase.CALL:
		m.erase("goal")
		return {"move": Vector2.ZERO, "action": false, "hold": false}
	if _t < lerpf(1.4, 0.45, ch.slot.skill):
		return {"move": Vector2.ZERO, "action": false, "hold": false}
	if not m.has("goal"):
		# Now and then a CPU mixes up the colours, like people do.
		var wanted := called
		if rng.randf() < 0.3 * (1.0 - ch.slot.skill) + 0.02 * call_no:
			var names := COLORS.keys()
			wanted = names[rng.randi() % names.size()]
		var best: Vector3 = ch.global_position
		var best_d := INF
		for t in tile_color:
			if tile_color[t] != wanted:
				continue
			var p := Vector3(t.cell.x, 0, t.cell.y)
			var d := ch.global_position.distance_to(p) + rng.randf() * (1.0 - ch.slot.skill) * 2.0
			if d < best_d:
				best_d = d
				best = p
		m.goal = best
	var goal: Vector3 = m.goal
	var to := goal - ch.global_position
	to.y = 0.0
	var move := Vector2(to.x, to.z).normalized() if to.length() > 0.2 else Vector2.ZERO
	return {"move": move, "action": false, "hold": false}

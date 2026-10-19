extends CanvasLayer
## On-screen controls for phones and tablets: a floating stick on the left half of the
## screen, A (action) and ITEM buttons on the right, and a pause button. Shows up on
## mobile browsers or after the first touch, and acts as the input device "touch".

const STICK_RADIUS := 95.0
const DEADZONE := 0.2

var active := false
var show_pause := true ## Off in the lobby, where there is nothing to pause.
var _stick_id := -1
var _stick_origin := Vector2.ZERO
var _stick_vec := Vector2.ZERO
var _buttons := {} ## name -> {center, radius, label, color, touch, tapped}
var _canvas: Control


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_canvas = Control.new()
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_controls)
	add_child(_canvas)
	for b in [["action", "A", Color("7cd67c")], ["item", "ITEM", Color("f4a6c8")], ["pause", "II", Color("b8b0c8")], ["back", "LOBBY", Color("ff8a7a")]]:
		_buttons[b[0]] = {"center": Vector2.ZERO, "radius": 40.0, "label": b[1], "color": b[2], "touch": -1, "tapped": false}
	get_viewport().size_changed.connect(_layout)
	_layout()
	if is_mobile():
		activate()


static func is_mobile() -> bool:
	return OS.has_feature("web_android") or OS.has_feature("web_ios") or OS.has_feature("mobile")


func activate() -> void:
	if active:
		return
	active = true
	visible = true
	_layout()


func _layout() -> void:
	var s := get_viewport().get_visible_rect().size
	var unit := clampf(minf(s.x, s.y) / 720.0, 0.8, 1.6)
	_buttons.action.center = s - Vector2(150, 160) * unit
	_buttons.action.radius = 78.0 * unit
	_buttons.item.center = s - Vector2(330, 105) * unit
	_buttons.item.radius = 56.0 * unit
	_buttons.pause.center = Vector2(s.x - 56 * unit, 120 * unit)
	_buttons.pause.radius = 34.0 * unit
	_buttons.back.center = Vector2(s.x * 0.5, s.y * 0.78)
	_buttons.back.radius = 70.0 * unit
	_canvas.queue_redraw()


func _visible_buttons() -> Array:
	if get_tree().paused:
		return ["pause", "back"]
	return ["action", "item", "pause"] if show_pause else ["action", "item"]


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		activate()
		if event.pressed:
			var hit := _button_at(event.position)
			if hit != "":
				_buttons[hit].touch = event.index
				_buttons[hit].tapped = true
			elif event.position.x < get_viewport().get_visible_rect().size.x * 0.5 and _stick_id == -1:
				_stick_id = event.index
				_stick_origin = event.position
				_stick_vec = Vector2.ZERO
		else:
			if event.index == _stick_id:
				_stick_id = -1
				_stick_vec = Vector2.ZERO
			for b in _buttons.values():
				if b.touch == event.index:
					b.touch = -1
		_canvas.queue_redraw()
	elif event is InputEventScreenDrag and event.index == _stick_id:
		var d: Vector2 = event.position - _stick_origin
		if d.length() > STICK_RADIUS:
			# The stick base follows the thumb so it never runs out of room.
			_stick_origin += d.normalized() * (d.length() - STICK_RADIUS)
			d = d.limit_length(STICK_RADIUS)
		_stick_vec = d / STICK_RADIUS
		_canvas.queue_redraw()


func _button_at(p: Vector2) -> String:
	for name in _visible_buttons():
		var b: Dictionary = _buttons[name]
		if p.distance_to(b.center) <= b.radius * 1.15:
			return name
	return ""


## Current state for Controls. A tap shorter than one physics tick still counts once.
func take_state() -> Dictionary:
	var move := _stick_vec if _stick_vec.length() > DEADZONE else Vector2.ZERO
	var s := {"move": move.limit_length(1.0), "bot_add": false, "bot_remove": false}
	for name in ["action", "item", "pause", "back"]:
		var b: Dictionary = _buttons[name]
		s[name] = b.touch != -1 or b.tapped
		b.tapped = false
	return s


func _draw_controls() -> void:
	var font := Art.font(true)
	# Stick: where the thumb is, or a faint hint of where to put it.
	var base := _stick_origin if _stick_id != -1 else Vector2(170, get_viewport().get_visible_rect().size.y - 170)
	var alpha := 0.9 if _stick_id != -1 else 0.35
	_canvas.draw_circle(base, STICK_RADIUS, Color(0.1, 0.08, 0.15, 0.35 * alpha))
	_canvas.draw_arc(base, STICK_RADIUS, 0, TAU, 48, Color(1, 1, 1, 0.5 * alpha), 4.0)
	_canvas.draw_circle(base + _stick_vec * STICK_RADIUS, 42.0, Color(1, 1, 1, 0.55 * alpha))
	if _stick_id == -1:
		_canvas.draw_string(font, base + Vector2(-60, STICK_RADIUS + 34), "MOVE", HORIZONTAL_ALIGNMENT_CENTER, 120, 26, Color(1, 1, 1, 0.5))
	for name in _visible_buttons():
		var b: Dictionary = _buttons[name]
		var down: bool = b.touch != -1
		var c: Color = b.color
		_canvas.draw_circle(b.center, b.radius, Color(c, 0.85 if down else 0.5))
		_canvas.draw_arc(b.center, b.radius, 0, TAU, 48, Color(Art.OUTLINE, 0.9), 5.0)
		var size := int(b.radius * (0.7 if String(b.label).length() <= 2 else 0.42))
		_canvas.draw_string_outline(font, b.center + Vector2(-b.radius, size * 0.35), b.label, HORIZONTAL_ALIGNMENT_CENTER, b.radius * 2.0, size, 8, Art.OUTLINE)
		_canvas.draw_string(font, b.center + Vector2(-b.radius, size * 0.35), b.label, HORIZONTAL_ALIGNMENT_CENTER, b.radius * 2.0, size, Color.WHITE)


func _process(_delta: float) -> void:
	if active:
		_canvas.queue_redraw()

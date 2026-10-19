extends Node
## Per-device input for local multiplayer. Each player owns one device:
##   "kb0"  WASD + Space (action) + E/Q (item) + E (back)
##   "kb1"  Arrows + Enter (action) + Right Shift or / (item) + Backspace (back)
##   "padN" Left stick / D-pad + A (action) + X/B (item) + B (back) + Start (pause)
##   "touch" On-screen stick and buttons on phones/tablets (see Touch)
## States are polled once per physics tick (this autoload runs before the scene).

const DEADZONE := 0.3
const BUTTONS := ["action", "item", "back", "pause", "bot_add", "bot_remove"]

var _state := {}
var _prev := {}
## Tests and tools can force a device's state: device -> {move, action, ...}
var injected := {}
var _right_shift := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_physics_priority = -100


func _input(event: InputEvent) -> void:
	# Polling can't tell left from right Shift, so track the right one from events.
	if event is InputEventKey and event.keycode == KEY_SHIFT and event.location == KEY_LOCATION_RIGHT:
		_right_shift = event.pressed


func devices() -> Array[String]:
	var out: Array[String] = ["kb0", "kb1"]
	for id in Input.get_connected_joypads():
		out.append("pad%d" % id)
	if Touch.active:
		out.append("touch")
	return out


func device_label(device: String) -> String:
	if device == "kb0":
		return "Keys WASD"
	if device == "kb1":
		return "Keys Arrows"
	if device.begins_with("pad"):
		return "Pad %d" % (int(device.substr(3)) + 1)
	if device == "touch":
		return "Touch"
	return "CPU"


func item_hint(device: String) -> String:
	match device:
		"kb0": return "E"
		"kb1": return "R-SHIFT"
	return "X"


func action_hint(device: String) -> String:
	match device:
		"kb0": return "SPACE"
		"kb1": return "ENTER"
	return "A"


func _physics_process(_delta: float) -> void:
	_prev = _state
	_state = {}
	for dev in devices():
		_state[dev] = _poll(dev)
	for dev in injected:
		_state[dev] = _fill(injected[dev])


func move(device: String) -> Vector2:
	if _state.has(device):
		return _state[device]["move"]
	return Vector2.ZERO


func pressed(device: String, button: String) -> bool:
	return _state.has(device) and _state[device][button]


func just_pressed(device: String, button: String) -> bool:
	return pressed(device, button) and not (_prev.has(device) and _prev[device][button])


func any_just_pressed(button: String) -> bool:
	for dev in _state:
		if just_pressed(dev, button):
			return true
	return false


func _fill(s: Dictionary) -> Dictionary:
	var out := {"move": s.get("move", Vector2.ZERO)}
	for b in BUTTONS:
		out[b] = s.get(b, false)
	return out


func _poll(device: String) -> Dictionary:
	if device == "touch":
		return Touch.take_state()
	var s := {}
	if device == "kb0":
		s.move = _keys(KEY_A, KEY_D, KEY_W, KEY_S)
		s.action = Input.is_physical_key_pressed(KEY_SPACE)
		s.item = Input.is_physical_key_pressed(KEY_E) or Input.is_physical_key_pressed(KEY_Q)
		s.back = Input.is_physical_key_pressed(KEY_E)
		s.pause = Input.is_physical_key_pressed(KEY_ESCAPE)
		s.bot_add = Input.is_physical_key_pressed(KEY_EQUAL) or Input.is_physical_key_pressed(KEY_KP_ADD)
		s.bot_remove = Input.is_physical_key_pressed(KEY_MINUS) or Input.is_physical_key_pressed(KEY_KP_SUBTRACT)
	elif device == "kb1":
		s.move = _keys(KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN)
		s.action = Input.is_physical_key_pressed(KEY_ENTER) or Input.is_physical_key_pressed(KEY_KP_ENTER)
		s.item = _right_shift or Input.is_physical_key_pressed(KEY_SLASH)
		s.back = Input.is_physical_key_pressed(KEY_BACKSPACE)
		s.pause = false
		s.bot_add = false
		s.bot_remove = false
	else:
		var id := int(device.substr(3))
		var v := Vector2(Input.get_joy_axis(id, JOY_AXIS_LEFT_X), Input.get_joy_axis(id, JOY_AXIS_LEFT_Y))
		if v.length() < DEADZONE:
			v = Vector2.ZERO
		v += Vector2(
			float(Input.is_joy_button_pressed(id, JOY_BUTTON_DPAD_RIGHT)) - float(Input.is_joy_button_pressed(id, JOY_BUTTON_DPAD_LEFT)),
			float(Input.is_joy_button_pressed(id, JOY_BUTTON_DPAD_DOWN)) - float(Input.is_joy_button_pressed(id, JOY_BUTTON_DPAD_UP)))
		s.move = v.limit_length(1.0)
		s.action = Input.is_joy_button_pressed(id, JOY_BUTTON_A)
		s.item = Input.is_joy_button_pressed(id, JOY_BUTTON_X) or Input.is_joy_button_pressed(id, JOY_BUTTON_B)
		s.back = Input.is_joy_button_pressed(id, JOY_BUTTON_B)
		s.pause = Input.is_joy_button_pressed(id, JOY_BUTTON_START)
		s.bot_add = Input.is_joy_button_pressed(id, JOY_BUTTON_RIGHT_SHOULDER)
		s.bot_remove = Input.is_joy_button_pressed(id, JOY_BUTTON_LEFT_SHOULDER)
	return s


func _keys(left: Key, right: Key, up: Key, down: Key) -> Vector2:
	var v := Vector2(
		float(Input.is_physical_key_pressed(right)) - float(Input.is_physical_key_pressed(left)),
		float(Input.is_physical_key_pressed(down)) - float(Input.is_physical_key_pressed(up)))
	return v.normalized()

class_name OnlinePanel
extends Control
## The lobby's ONLINE menu: host a game, join one that's open, or leave. Driven by any
## local player's stick/keys while open. When closed and in a game it shows a compact
## status box with who is in.

signal closed

var is_open := false
var _sel := 0
var _items: Array = [] ## [{text, call}]
var _box: PanelContainer
var _list: VBoxContainer
var _status_box: PanelContainer
var _status: VBoxContainer
var _prev_y := {}
var _refresh_t := 0.0
var _no_host_t := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box = Ui.panel(Color(0.11, 0.09, 0.16, 0.94), Art.OUTLINE, 18)
	_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_box.custom_minimum_size = Vector2(460, 0)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	_box.add_child(_list)
	var center := Ui.full_rect(CenterContainer.new())
	center.add_child(_box)
	add_child(center)
	_box.hide()

	_status_box = Ui.panel(Color(0.11, 0.09, 0.16, 0.85), Art.OUTLINE, 10)
	_status_box.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_status_box.offset_left = -300
	_status_box.offset_right = -16
	_status_box.offset_top = 140
	_status = VBoxContainer.new()
	_status_box.add_child(_status)
	add_child(_status_box)
	_status_box.hide()


func open() -> void:
	is_open = true
	_sel = 0
	_prev_y.clear()
	Sfx.play("blip", 1.2)
	_rebuild()


func close() -> void:
	is_open = false
	_box.hide()
	closed.emit()


func _process(delta: float) -> void:
	_refresh_t -= delta
	if _refresh_t <= 0.0:
		_refresh_t = 0.3
		if is_open:
			_rebuild()
		_update_status()
	# A joined game whose host vanished: give up after a few seconds.
	if Net.in_game() and not Net.is_host and not Net.in_match and Net.host_settings().is_empty():
		_no_host_t += delta
		if _no_host_t > 6.0:
			Net.leave_game()
			_no_host_t = 0.0
	else:
		_no_host_t = 0.0


func _physics_process(_delta: float) -> void:
	if not is_open:
		return
	for dev in Controls.devices():
		var y := Controls.move(dev).y
		var was: float = _prev_y.get(dev, 0.0)
		_prev_y[dev] = y
		if y > 0.6 and was <= 0.6:
			_move(1)
		elif y < -0.6 and was >= -0.6:
			_move(-1)
		if Controls.just_pressed(dev, "action") and not _items.is_empty():
			Sfx.play("go")
			_items[_sel].call.call()
			return
		if Controls.just_pressed(dev, "back"):
			close()
			return


func _move(step: int) -> void:
	if _items.is_empty():
		return
	_sel = posmod(_sel + step, _items.size())
	Sfx.play("tick")
	_rebuild()


func _rebuild() -> void:
	_items.clear()
	for c in _list.get_children():
		c.queue_free()
	_list.add_child(Ui.title("ONLINE", 40, Ui.GOLD, 10))
	if not Net.available or Net.status.begins_with("denied"):
		_list.add_child(Ui.body(_unavailable_reason(), 18))
		_items.append({"text": "CLOSE", "call": close})
	elif Net.game_state == "joining":
		_list.add_child(Ui.body("Connecting to game %s..." % Net.game_code, 20))
		_items.append({"text": "CANCEL", "call": _leave})
	elif Net.in_game():
		var role := "You're hosting" if Net.is_host else "You joined"
		_list.add_child(Ui.body("%s game %s" % [role, Net.game_code], 20, Color("fff2c0")))
		# CLOSE first, so a stray dash press right after stepping on the pad is harmless.
		_items.append({"text": "CLOSE", "call": close})
		_items.append({"text": "LEAVE GAME", "call": _leave})
	else:
		if Net.game_state == "error":
			_list.add_child(Ui.body("Couldn't join that game. Try another.", 18, Color("ff8a7a")))
		_items.append({"text": "HOST A GAME", "call": _host})
		for g in Net.open_games():
			var code: String = g.code
			if g.open:
				_items.append({"text": "JOIN %s  (%d player%s)" % [code, g.players, "" if g.players == 1 else "s"], "call": _join.bind(code)})
			else:
				_items.append({"text": "%s  (match in progress)" % code, "call": func(): pass})
		if Net.open_games().is_empty():
			_list.add_child(Ui.body("No open games yet. Host one, or wait for a friend to host.", 18, Color("b8b0c8")))
		_items.append({"text": "CLOSE", "call": close})
	_sel = clampi(_sel, 0, maxi(0, _items.size() - 1))
	for i in _items.size():
		var selected := i == _sel
		var row := Ui.label(("> " if selected else "  ") + _items[i].text, 24, Ui.GOLD if selected else Color.WHITE, 6)
		row.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_list.add_child(row)
	_list.add_child(Ui.body("Up/Down to choose · action to select · back to close", 15, Color("8a82a0")))
	_box.show()


func _unavailable_reason() -> String:
	match Net.status:
		"connecting":
			return "Connecting to claude.ai... Try again in a few seconds."
		"outside":
			return "Online play only works when this page is opened on claude.ai."
		"unavailable":
			return "claude.ai didn't let this page go online for you. Make sure you're signed in to claude.ai, that the page was shared with your account from its Share menu (a public link isn't enough), and open it inside claude.ai."
		"":
			return "Online play works in the browser version on claude.ai, for people the page is shared with."
	return "claude.ai refused the online connection (%s). Make sure you're signed in and the page is shared with your account, then reload." % Net.status.trim_prefix("denied:")


func _host() -> void:
	Net.host_game()
	_sel = 0


func _join(code: String) -> void:
	Net.join_game(code)
	_sel = 0


func _leave() -> void:
	Net.leave_game()
	_sel = 0


func _update_status() -> void:
	for c in _status.get_children():
		c.queue_free()
	if not Net.in_game() or is_open:
		_status_box.hide()
		return
	_status_box.show()
	_status.add_child(Ui.label("ONLINE · GAME %s" % Net.game_code, 20, Ui.GOLD, 6))
	var r := Net.roster()
	for entry in r:
		var who := "You" if entry.me else ("Host" if entry.host else "Friend")
		var extra := " + %d CPU" % entry.bots if entry.bots > 0 else ""
		var line := Ui.body("%s: %d player%s%s" % [who, entry.players - entry.bots, "" if entry.players - entry.bots == 1 else "s", extra], 17)
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_status.add_child(line)
	var hint := "Stand on START to begin" if Net.is_host else "The host starts the match"
	_status.add_child(Ui.body(hint, 15, Color("b8b0c8")))

extends Node
## Root of the game: swaps between lobby, match and podium, and handles pause.

const Lobby := preload("res://main/lobby.gd")
const MatchHost := preload("res://main/match_host.gd")
const Podium := preload("res://main/podium.gd")

var current: Node
var _pause_layer: CanvasLayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Game.main = self
	_build_pause()
	get_window().size_changed.connect(_fit_screen)
	_fit_screen()
	if Touch.is_mobile():
		# Phones: render 3D at a lower resolution (crisp pixel upscale) and skip shadows.
		get_viewport().scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
		get_viewport().scaling_3d_scale = 0.6
		get_viewport().msaa_3d = Viewport.MSAA_DISABLED
	goto_lobby()


## Landscape uses a 1280x720 layout; a portrait phone gets a narrower, taller one so
## text stays readable.
func _fit_screen() -> void:
	var s := get_window().size
	get_tree().root.content_scale_size = Vector2i(760, 1280) if s.x < s.y else Vector2i(1280, 720)


func goto_lobby() -> void:
	if Net.in_match:
		Net.end_match()
	Game.reset_scores()
	_swap(Lobby.new())


func goto_match() -> void:
	_swap(MatchHost.new())


func goto_podium() -> void:
	_swap(Podium.new())


func _swap(node: Node) -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	_pause_layer.visible = false
	if current:
		current.queue_free()
	current = node
	current.process_mode = Node.PROCESS_MODE_PAUSABLE
	Touch.show_pause = not (node is Lobby)
	add_child(current)


func _physics_process(_delta: float) -> void:
	if not (current is Node3D) or current is Lobby or Net.in_match:
		return
	if Controls.any_just_pressed("pause"):
		_set_paused(not get_tree().paused)
	elif get_tree().paused and Controls.any_just_pressed("back"):
		goto_lobby()


func _set_paused(on: bool) -> void:
	get_tree().paused = on
	_pause_layer.visible = on
	Sfx.play("blip")


func _build_pause() -> void:
	_pause_layer = CanvasLayer.new()
	_pause_layer.layer = 20
	_pause_layer.visible = false
	add_child(_pause_layer)
	var dim := Ui.full_rect(ColorRect.new())
	dim.color = Color(0.05, 0.03, 0.1, 0.6)
	_pause_layer.add_child(dim)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	Ui.full_rect(box)
	box.add_child(Ui.label("PAUSED", 80, Ui.GOLD, 14))
	box.add_child(Ui.body("Esc / Start: resume", 26))
	box.add_child(Ui.body("E / Backspace / (B): quit to lobby", 26))
	box.add_child(Ui.body("On touch: II resumes, LOBBY quits", 26))
	_pause_layer.add_child(box)

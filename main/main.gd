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
	goto_lobby()


func goto_lobby() -> void:
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
	add_child(current)


func _physics_process(_delta: float) -> void:
	if not (current is Node3D) or current is Lobby:
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
	_pause_layer.add_child(box)

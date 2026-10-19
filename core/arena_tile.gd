class_name ArenaTile
extends StaticBody3D
## One 1x1 column of island: grass on top, stone cliff down into the water.

signal dropped(tile: ArenaTile)

enum State { SOLID, CRACKING, GONE }

const BOTTOM := -3.0

var cell: Vector2i
var level := 0
var top_y := 0.0
var top_texture := "grass"
var state := State.SOLID
var painted_by: PlayerSlot
var mesh_instance: MeshInstance3D
var _shape: CollisionShape3D


func _init(p_cell: Vector2i, p_level := 0, p_top := "grass") -> void:
	cell = p_cell
	level = p_level
	top_y = float(level)
	top_texture = p_top
	position = Vector3(cell.x, 0, cell.y)
	collision_layer = 1
	collision_mask = 0
	_shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1, top_y - BOTTOM, 1)
	_shape.shape = box
	_shape.position.y = (top_y + BOTTOM) * 0.5
	add_child(_shape)
	mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = Art.tile_mesh(top_y, BOTTOM, top_texture)
	add_child(mesh_instance)


func is_solid() -> bool:
	return state != State.GONE


func set_top(tex_name: String) -> void:
	top_texture = tex_name
	mesh_instance.mesh = Art.tile_mesh(top_y, BOTTOM, tex_name)


## Wobble for `delay` seconds, then drop into the sea.
func crack(delay := 0.6) -> void:
	if state != State.SOLID:
		return
	state = State.CRACKING
	set_top("cliff")
	var tw := create_tween()
	var steps := maxi(2, int(delay / 0.05))
	for i in steps:
		var off := Vector3(0.05 if i % 2 == 0 else -0.05, 0, 0.03 if i % 3 == 0 else -0.03)
		tw.tween_property(mesh_instance, "position", off, delay / steps)
	tw.tween_callback(drop)


func drop() -> void:
	if state == State.GONE:
		return
	state = State.GONE
	_shape.set_deferred("disabled", true)
	dropped.emit(self)
	var tw := create_tween()
	tw.tween_property(mesh_instance, "position:y", -7.0, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(mesh_instance.hide)

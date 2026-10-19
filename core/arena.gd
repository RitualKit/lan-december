class_name Arena
extends Node3D
## A floating island made of tiles, plus water, light, camera and scenery.

const WATER_Y := -1.0
const WATER_SHADER := preload("res://core/water.gdshader")

var tiles := {} ## Vector2i -> ArenaTile
var camera: Camera3D
var sun: DirectionalLight3D
var focus := Vector3.ZERO
var _shake := 0.0
var _cam_origin := Vector3.ZERO


static func disc(radius: float, level := 0) -> Dictionary:
	var out := {}
	var r := int(ceil(radius))
	for x in range(-r, r + 1):
		for z in range(-r, r + 1):
			if Vector2(x, z).length() <= radius + 0.01:
				out[Vector2i(x, z)] = level
	return out


static func rect(w: int, h: int, level := 0) -> Dictionary:
	var out := {}
	for x in w:
		for z in h:
			out[Vector2i(x - w / 2, z - h / 2)] = level
	return out


func build(cells: Dictionary, top_tex := "grass") -> void:
	for c in cells:
		add_tile(c, cells[c], top_tex)


func add_tile(cell: Vector2i, level := 0, top_tex := "grass") -> ArenaTile:
	var t := ArenaTile.new(cell, level, top_tex)
	tiles[cell] = t
	add_child(t)
	return t


func tile_at(pos: Vector3) -> ArenaTile:
	return tiles.get(Vector2i(roundi(pos.x), roundi(pos.z)))


func is_safe(pos: Vector3) -> bool:
	var t := tile_at(pos)
	return t != null and t.state == ArenaTile.State.SOLID


func solid_tiles() -> Array:
	return tiles.values().filter(func(t): return t.state == ArenaTile.State.SOLID)


## Evenly spread start positions on a ring.
func spawn_ring(count: int, radius: float, height := 0.6) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for i in count:
		var a := TAU * i / maxi(count, 1) + PI * 0.5
		out.append(focus + Vector3(cos(a) * radius, height, sin(a) * radius))
	return out


## Camera, light, sky, water and scenery around `p_focus`.
func setup_view(p_focus: Vector3, distance := 20.0, pitch_deg := 52.0) -> void:
	focus = p_focus
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("6fa4bb")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("b4c8e8")
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.ssao_enabled = true
	env.ssao_radius = 1.0
	env.ssao_intensity = 1.6
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.04
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.0
	if not GroundMark.use_decals:
		# Compatibility renderer (web): no SSAO/DoF, and it renders brighter.
		env.tonemap_exposure = 0.8
		env.ambient_light_energy = 0.45
		env.glow_intensity = 0.3
	var world := WorldEnvironment.new()
	world.environment = env
	var attrs := CameraAttributesPractical.new()
	attrs.dof_blur_far_enabled = GroundMark.use_decals
	attrs.dof_blur_far_distance = distance + 7.0
	attrs.dof_blur_far_transition = 9.0
	attrs.dof_blur_near_enabled = GroundMark.use_decals
	attrs.dof_blur_near_distance = distance - 8.0
	attrs.dof_blur_near_transition = 4.0
	attrs.dof_blur_amount = 0.06
	world.camera_attributes = attrs
	add_child(world)

	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -38, 0)
	sun.light_color = Color("fff0d8")
	sun.light_energy = 1.15 if GroundMark.use_decals else 0.95
	sun.shadow_enabled = not Touch.is_mobile()
	sun.shadow_blur = 1.5
	sun.directional_shadow_max_distance = distance + 25.0
	add_child(sun)

	var water := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(200, 200)
	water.mesh = plane
	var wm := ShaderMaterial.new()
	wm.shader = WATER_SHADER
	water.material_override = wm
	water.position = Vector3(focus.x, WATER_Y, focus.z)
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)

	camera = Camera3D.new()
	camera.fov = 32.0
	var pitch := deg_to_rad(pitch_deg)
	_cam_origin = focus + Vector3(0, sin(pitch) * distance, cos(pitch) * distance)
	add_child(camera)
	camera.look_at_from_position(_cam_origin, focus)
	camera.current = true

	Fx.petal_weather(self, focus, distance * 0.7)


## Small islands with trees, rocks and lamps scattered behind and beside the arena.
func decorate(seed_value: int, inner_radius: float, count := 7) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var placed: Array[Vector2] = []
	var tries := 0
	while placed.size() < count and tries < 200:
		tries += 1
		var a := rng.randf_range(deg_to_rad(175), deg_to_rad(365))
		var d := inner_radius + rng.randf_range(4.5, 10.0)
		var p := Vector2(cos(a), sin(a)) * d + Vector2(focus.x, focus.z)
		if placed.any(func(q): return q.distance_to(p) < 4.5):
			continue
		placed.append(p)
		_islet(rng, Vector2i(roundi(p.x), roundi(p.y)))


func _islet(rng: RandomNumberGenerator, center: Vector2i) -> void:
	var cells := {}
	var r := rng.randf_range(1.0, 2.3)
	var level := 0
	for c in disc(r, level):
		cells[c + center] = level
	var raised := rng.randf() < 0.35
	if raised:
		cells[center] = level + 1
	add_child(Props.islet(cells))
	var top := Vector3(center.x, cells[center], center.y)
	var roll := rng.randf()
	if roll < 0.62:
		var tree := Props.blossom_tree(rng, "blossom" if rng.randf() < 0.8 else "leaves")
		tree.position = top
		add_child(tree)
	elif roll < 0.78:
		var tent := Props.tent()
		tent.position += top
		tent.rotation.y = rng.randf_range(-0.6, 0.6)
		add_child(tent)
	else:
		var lamp := Props.lamp()
		lamp.position = top
		add_child(lamp)
	var keys := cells.keys()
	for i in rng.randi_range(1, 3):
		var c: Vector2i = keys[rng.randi() % keys.size()]
		if c == center:
			continue
		var prop := Props.rock(rng) if rng.randf() < 0.5 else Props.bush(rng)
		prop.position += Vector3(c.x + rng.randf_range(-0.2, 0.2), cells[c], c.y + rng.randf_range(-0.2, 0.2))
		add_child(prop)


func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func _process(delta: float) -> void:
	if camera == null:
		return
	var vs := get_viewport().get_visible_rect().size
	if vs.x < vs.y:
		# Portrait: keep the island's width in view (same width as a 16:9 screen).
		camera.keep_aspect = Camera3D.KEEP_WIDTH
		camera.fov = 54.0
	else:
		camera.keep_aspect = Camera3D.KEEP_HEIGHT
		camera.fov = 32.0
	if _shake > 0.001:
		_shake = move_toward(_shake, 0.0, delta * 1.8)
		var off := Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * _shake * 0.35
		camera.global_position = _cam_origin + camera.global_basis * off
	else:
		camera.global_position = _cam_origin

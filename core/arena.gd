class_name Arena
extends Node3D
## A floating island made of tiles, plus water, light, camera and scenery, dressed in
## one of the Themes (set `theme` before build()).

const WATER_Y := -1.0
const WATER_SHADER := preload("res://core/water.gdshader")

var tiles := {} ## Vector2i -> ArenaTile
var camera: Camera3D
var sun: DirectionalLight3D
var focus := Vector3.ZERO
var theme: Dictionary = Themes.get_theme("blossom")
var scenery: Scenery
var _islets: Array[Vector2] = []
var _pending_flames: Array[Node3D] = []
var _pending_beams: Array[Node3D] = []
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


## Builds tiles; `top_tex` "" means the theme's ground.
func build(cells: Dictionary, top_tex := "") -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(cells.size())
	for c in cells:
		var t := add_tile(c, cells[c], top_tex)
		if top_tex == "" and rng.randf() < 0.14:
			_add_detail(t.mesh_instance, Vector3(rng.randf_range(-0.3, 0.3), t.top_y, rng.randf_range(-0.3, 0.3)), rng)


func add_tile(cell: Vector2i, level := 0, top_tex := "") -> ArenaTile:
	var t := ArenaTile.new(cell, level, top_tex if top_tex != "" else theme.ground, theme.lip, theme.side)
	tiles[cell] = t
	add_child(t)
	return t


## A little ground sprite (grass tuft, flower, shell...) that rides along with its tile.
func _add_detail(parent: Node3D, pos: Vector3, rng: RandomNumberGenerator) -> void:
	var details: Array = theme.details
	var pick: Array = details[rng.randi() % details.size()]
	var s := Art.icon_sprite(pick[0], Color(pick[1]), Color("ffe066"), Art.PIXEL_SIZE)
	s.offset.y = s.texture.get_height() * 0.5
	s.position = pos + Vector3.UP * 0.01
	parent.add_child(s)


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
	env.background_color = Color(theme.bg)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(theme.ambient)
	env.ambient_light_energy = theme.ambient_energy
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
		env.ambient_light_energy = theme.ambient_energy * 0.75
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
	sun.rotation_degrees = theme.sun_rot
	sun.light_color = Color(theme.sun)
	sun.light_energy = theme.sun_energy * (1.0 if GroundMark.use_decals else 0.83)
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
	wm.set_shader_parameter("shallow_color", theme.shallow)
	wm.set_shader_parameter("deep_color", theme.deep)
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

	if theme.weather != "":
		Fx.weather(self, focus, distance * 0.7, theme.weather)


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
	_islets = placed
	scenery = Scenery.new(self, inner_radius, rng.randi())
	scenery.flames = _pending_flames
	scenery.beams = _pending_beams
	add_child(scenery)


func islet_near(p: Vector2, margin: float) -> bool:
	return _islets.any(func(q): return q.distance_to(p) < margin)


func _islet(rng: RandomNumberGenerator, center: Vector2i) -> void:
	var cells := {}
	var r := rng.randf_range(1.0, 2.3)
	var level := 0
	for c in disc(r, level):
		cells[c + center] = level
	var raised := rng.randf() < 0.35
	if raised:
		cells[center] = level + 1
	var land := Props.islet(cells, theme)
	add_child(land)
	var top := Vector3(center.x, cells[center], center.y)
	var trees: Array = theme.trees
	var main: Node3D
	if rng.randf() < 0.65:
		main = Props.tree(trees[rng.randi() % trees.size()], rng)
	else:
		main = _prop(theme.props[rng.randi() % theme.props.size()], rng)
	main.position += top
	add_child(main)
	var keys := cells.keys()
	for i in rng.randi_range(1, 4):
		var c: Vector2i = keys[rng.randi() % keys.size()]
		if c == center:
			continue
		var spot := Vector3(c.x + rng.randf_range(-0.2, 0.2), cells[c], c.y + rng.randf_range(-0.2, 0.2))
		var roll := rng.randf()
		var prop: Node3D
		if roll < 0.35:
			prop = Props.tree(trees[rng.randi() % trees.size()], rng)
			prop.scale = Vector3.ONE * rng.randf_range(0.6, 0.85)
		elif roll < 0.6:
			_add_detail(land, spot, rng)
			continue
		else:
			var small: Array = theme.props.filter(func(n): return n in ["rock", "bush", "pumpkin", "snowman"])
			prop = _prop(small[rng.randi() % small.size()] if not small.is_empty() else "rock", rng)
		prop.position += spot
		add_child(prop)


func _prop(prop_name: String, rng: RandomNumberGenerator) -> Node3D:
	match prop_name:
		"tent":
			var t := Props.tent()
			t.rotation.y = rng.randf_range(-0.6, 0.6)
			return t
		"lamp": return Props.lamp()
		"bush": return Props.bush(rng)
		"snowman": return Props.snowman(rng)
		"pumpkin": return Props.pumpkin(rng)
		"campfire":
			var f := Props.campfire()
			if scenery == null:
				_pending_flames.append(f)
			return f
		"lighthouse":
			var l := Props.lighthouse()
			_pending_beams.append(l)
			return l
	return Props.rock(rng)


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

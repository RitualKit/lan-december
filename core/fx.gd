class_name Fx
extends RefCounted
## One-shot visual effects built from tiny pixel cubes.

static var _cube_mesh: BoxMesh


static func _cube(size := 0.09) -> BoxMesh:
	if _cube_mesh == null:
		_cube_mesh = BoxMesh.new()
		_cube_mesh.size = Vector3.ONE * size
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_cube_mesh.material = m
	return _cube_mesh


static func _particles(parent: Node, pos: Vector3, count: int, color: Color, lifetime: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.mesh = _cube()
	p.amount = count
	p.lifetime = lifetime
	p.one_shot = true
	p.explosiveness = 0.95
	p.color = color
	p.finished.connect(p.queue_free)
	parent.add_child(p)
	p.global_position = pos
	return p


static func splash(parent: Node, pos: Vector3) -> void:
	if parent == null:
		return
	var p := _particles(parent, pos, 40, Color("e8f6ff"), 0.9)
	p.direction = Vector3.UP
	p.spread = 25.0
	p.initial_velocity_min = 4.0
	p.initial_velocity_max = 7.5
	p.gravity = Vector3(0, -18, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	p.emitting = true


static func burst(parent: Node, pos: Vector3, color: Color, count := 24, power := 4.0) -> void:
	if parent == null:
		return
	var p := _particles(parent, pos, count, color, 0.6)
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = power * 0.5
	p.initial_velocity_max = power
	p.gravity = Vector3(0, -12, 0)
	p.damping_min = 2.0
	p.damping_max = 4.0
	p.emitting = true


static func explosion(parent: Node, pos: Vector3) -> void:
	burst(parent, pos, Color("ffd36b"), 40, 9.0)
	burst(parent, pos, Color("ff6a3a"), 30, 6.0)
	burst(parent, pos, Color("4a4a55"), 24, 4.0)


## Ambient particles over the whole scene: "petals", "leaves", "snow" or "fireflies".
static func weather(parent: Node, center: Vector3, extent: float, kind := "petals") -> CPUParticles3D:
	var quad := QuadMesh.new()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var p := CPUParticles3D.new()
	p.amount = 60
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(extent, 0.5, extent)
	p.direction = Vector3(1, -0.4, 0.3)
	p.spread = 30.0
	p.initial_velocity_min = 0.4
	p.initial_velocity_max = 1.0
	p.gravity = Vector3(0, -0.35, 0)
	p.angle_min = -180.0
	p.angle_max = 180.0
	p.angular_velocity_min = -90.0
	p.angular_velocity_max = 90.0
	var height := 7.0
	match kind:
		"petals":
			quad.size = Vector2(0.12, 0.09)
			m.albedo_color = Color("ffc2dc")
		"leaves":
			quad.size = Vector2(0.14, 0.1)
			m.albedo_color = Color("f09040")
			p.amount = 45
			p.gravity = Vector3(0, -0.5, 0)
		"snow":
			quad.size = Vector2(0.08, 0.08)
			m.albedo_color = Color("ffffff")
			p.amount = 140
			p.direction = Vector3(0.2, -1, 0.1)
			p.initial_velocity_min = 0.6
			p.initial_velocity_max = 1.2
			p.gravity = Vector3(0, -0.4, 0)
			p.lifetime = 7.0
			p.preprocess = 7.0
		"fireflies":
			quad.size = Vector2(0.07, 0.07)
			m.albedo_color = Color("fff08a")
			m.emission_enabled = true
			m.emission = Color("ffe060")
			m.emission_energy_multiplier = 4.0
			p.amount = 50
			p.direction = Vector3(0, 1, 0)
			p.spread = 180.0
			p.initial_velocity_min = 0.1
			p.initial_velocity_max = 0.4
			p.gravity = Vector3.ZERO
			p.angular_velocity_min = 0.0
			p.angular_velocity_max = 0.0
			p.emission_box_extents = Vector3(extent, 1.2, extent)
			height = 1.0
	quad.material = m
	p.mesh = quad
	parent.add_child(p)
	p.global_position = center + Vector3(-2 if kind != "fireflies" else 0, height, 0)
	return p


static func confetti(parent: Node, pos: Vector3, colors: Array[Color]) -> void:
	for c in colors:
		var p := _particles(parent, pos, 30, c, 2.5)
		p.explosiveness = 0.7
		p.direction = Vector3.UP
		p.spread = 50.0
		p.initial_velocity_min = 6.0
		p.initial_velocity_max = 11.0
		p.gravity = Vector3(0, -7, 0)
		p.damping_min = 1.0
		p.damping_max = 2.0
		p.emitting = true


## Plays a Ninja Adventure effect strip (32x32 frames) once, e.g. anim(arena, p, "fx/18").
static func anim(parent: Node, pos: Vector3, path: String, scale := 1.0, fps := 14.0) -> Sprite3D:
	if parent == null or not parent.is_inside_tree():
		return null
	var tex := Art.pack(path)
	var frames := maxi(1, tex.get_width() / 32)
	var s := Art.pack_sprite(path, frames, Art.PIXEL_SIZE * scale)
	s.no_depth_test = true
	s.render_priority = 1
	parent.add_child(s)
	s.global_position = pos
	var tw := s.create_tween()
	tw.tween_property(s, "frame", frames - 1, frames / fps).from(0)
	tw.tween_interval(1.0 / fps)
	tw.tween_callback(s.queue_free)
	return s


static func explosion_big(parent: Node, pos: Vector3, radius: float) -> void:
	anim(parent, pos + Vector3.UP * 0.5, "fx/12", radius * 1.4, 12.0)
	anim(parent, pos + Vector3.UP * 0.6, "fx/18", radius * 0.9, 12.0)
	burst(parent, pos + Vector3.UP * 0.3, Color("ffd36b"), 30, 8.0)


## Floating text such as "+1" that rises and fades.
static func popup(parent: Node, pos: Vector3, text: String, color := Color.WHITE, size := 48) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var l := Label3D.new()
	l.text = text
	l.font = Art.font(true)
	l.font_size = size
	l.outline_size = 12
	l.modulate = color
	l.outline_modulate = Art.OUTLINE
	l.pixel_size = 0.009
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.layers = 2
	parent.add_child(l)
	l.global_position = pos
	var tw := l.create_tween()
	tw.set_parallel()
	tw.tween_property(l, "position:y", l.position.y + 1.2, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.8).set_delay(0.3)
	tw.chain().tween_callback(l.queue_free)

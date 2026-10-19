class_name Scenery
extends Node3D
## Moving background life around an arena, chosen by the theme's "extras": sailing boats,
## circling birds, lily pads, jumping fish, drifting ice and rising sky lanterns. Also
## spins lighthouse beams and flickers campfires placed on the islets.

var arena: Arena
var inner := 6.0
var rng := RandomNumberGenerator.new()
var flames: Array[Node3D] = []
var beams: Array[Node3D] = []

var _boats: Array[Dictionary] = []
var _birds: Array[Dictionary] = []
var _floaters: Array[Dictionary] = [] ## lily pads and ice floes: {node, base, phase, drift}
var _lanterns: Array[Dictionary] = []
var _fish_t := 3.0
var _fish := false
var _t := 0.0


func _init(p_arena: Arena, inner_radius: float, seed_value: int) -> void:
	arena = p_arena
	inner = inner_radius
	rng.seed = seed_value


func _ready() -> void:
	var extras: Array = arena.theme.extras
	var boats := extras.count("boats")
	for i in boats * 2:
		_add_boat(i)
	if "birds" in extras:
		for i in rng.randi_range(3, 5):
			_add_bird()
	if "lily_pads" in extras:
		_scatter(14, inner + 0.8, inner + 3.5, Props.lily_pad.bind(rng))
	if "ice_floes" in extras:
		_scatter(7, inner + 1.5, inner + 7.0, Props.ice_floe.bind(rng))
	if "sky_lanterns" in extras:
		for i in 14:
			_add_lantern(true)
	_fish = "fish" in extras


## Water spots in the open sea in front of the island (the side without islets).
func _sea_spot(r_min: float, r_max: float) -> Vector3:
	for attempt in 20:
		var a := rng.randf_range(-0.15, PI + 0.15)
		var d := rng.randf_range(r_min, r_max)
		var p := Vector2(cos(a), sin(a)) * d + Vector2(arena.focus.x, arena.focus.z)
		if not arena.islet_near(p, 3.0):
			return Vector3(p.x, Arena.WATER_Y, p.y)
	return Vector3(arena.focus.x, Arena.WATER_Y, arena.focus.z + r_max)


func _scatter(count: int, r_min: float, r_max: float, make: Callable) -> void:
	for i in count:
		var node: Node3D = make.call()
		var pos := _sea_spot(r_min, r_max)
		add_child(node)
		node.global_position = pos + Vector3.UP * 0.02
		_floaters.append({"node": node, "base": node.global_position, "phase": rng.randf() * TAU, "drift": rng.randf_range(-0.15, 0.15)})


func _add_boat(i: int) -> void:
	var b := Props.boat(rng)
	add_child(b)
	var lane := arena.focus.z + inner + rng.randf_range(2.5, 6.0) + i * 0.8
	var x := rng.randf_range(-14.0, 14.0)
	var speed := rng.randf_range(0.6, 1.1) * (1.0 if rng.randf() < 0.5 else -1.0)
	_boats.append({"node": b, "lane": lane, "x": x, "speed": speed, "phase": rng.randf() * TAU})


func _add_bird() -> void:
	var b := Props.bird()
	add_child(b)
	_birds.append({"node": b, "radius": rng.randf_range(inner + 1.0, inner + 8.0), "height": rng.randf_range(5.0, 8.0),
		"speed": rng.randf_range(0.25, 0.45) * (1.0 if rng.randf() < 0.5 else -1.0), "angle": rng.randf() * TAU, "flap": rng.randf() * TAU})


func _add_lantern(anywhere: bool) -> void:
	var l := Props.sky_lantern()
	add_child(l)
	var a := rng.randf() * TAU
	var d := rng.randf_range(2.0, inner + 9.0)
	var y := rng.randf_range(-0.5, 10.0) if anywhere else -0.5
	l.global_position = arena.focus + Vector3(cos(a) * d, y, sin(a) * d)
	_lanterns.append({"node": l, "speed": rng.randf_range(0.35, 0.6), "phase": rng.randf() * TAU})


func _process(delta: float) -> void:
	_t += delta
	for b in _boats:
		var node: Node3D = b.node
		b.x += b.speed * delta
		if absf(b.x) > 16.0:
			b.speed = -b.speed
			b.x = clampf(b.x, -16.0, 16.0)
		node.global_position = Vector3(arena.focus.x + b.x, Arena.WATER_Y + 0.08 + sin(_t * 1.6 + b.phase) * 0.05, b.lane)
		node.rotation = Vector3(sin(_t * 1.3 + b.phase) * 0.06, PI * 0.5 if b.speed > 0 else -PI * 0.5, sin(_t * 1.1 + b.phase) * 0.08)
	for b in _birds:
		var node: Node3D = b.node
		b.angle += b.speed * delta
		var pos := arena.focus + Vector3(cos(b.angle) * b.radius, b.height + sin(_t + b.angle) * 0.3, sin(b.angle) * b.radius)
		node.look_at_from_position(pos, pos + Vector3(-sin(b.angle), 0, cos(b.angle)) * signf(b.speed))
		var flap := sin(_t * 9.0 + b.flap) * 0.6
		node.get_node("WingL").rotation.z = -flap
		node.get_node("WingR").rotation.z = flap
	for f in _floaters:
		var node: Node3D = f.node
		node.global_position = f.base + Vector3(sin(_t * 0.3 + f.phase) * 0.2 + _t * f.drift * 0.1, sin(_t * 1.5 + f.phase) * 0.02, cos(_t * 0.25 + f.phase) * 0.2)
		node.rotation.y += delta * f.drift
	for l in _lanterns:
		var node: Node3D = l.node
		node.global_position += Vector3(sin(_t * 0.7 + l.phase) * 0.2, l.speed, 0.0) * delta
		if node.global_position.y > 12.0:
			node.global_position.y = -0.5
	for beam in beams:
		if is_instance_valid(beam):
			beam.get_node("Beam").rotation.y += delta * 1.2
	for flame in flames:
		if is_instance_valid(flame):
			var f: Node3D = flame.get_node("Flame")
			f.scale = Vector3(1.0, 0.8 + 0.3 * absf(sin(_t * 11.0 + flame.position.x)), 1.0)
	if _fish:
		_fish_t -= delta
		if _fish_t <= 0.0:
			_fish_t = rng.randf_range(2.5, 6.0)
			_jump_fish()


func _jump_fish() -> void:
	var from := _sea_spot(inner + 1.5, inner + 6.0)
	var dir := Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized()
	var to := from + dir * 1.6
	var fish := Art.icon_sprite("fish", Color("ff8a3a"), Color.WHITE, 0.05)
	add_child(fish)
	fish.global_position = from
	Fx.splash(self, from)
	var tw := fish.create_tween()
	tw.tween_method(func(k: float):
		fish.global_position = from.lerp(to, k) + Vector3.UP * sin(k * PI) * 1.2, 0.0, 1.0, 0.8)
	tw.tween_callback(func():
		Fx.splash(self, to)
		fish.queue_free())

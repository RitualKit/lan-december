extends Minigame
## Sumo on a crumbling island: dash into rivals to knock them into the sea.

var radius := 5.0
var _erode_t := 0.0


func _init() -> void:
	title = "Petal Push"
	tagline = "Shove everyone into the sea!"
	rules = [
		"Dash into rivals to send them flying.",
		"After a few seconds the island crumbles from the edge.",
		"Last one standing wins.",
	]
	action_name = "Dash"
	accent = Color("f4a6c8")
	time_limit = 70.0
	last_standing = true
	bump_power = 11.5


func build() -> void:
	radius = 4.6 + 0.15 * players.size()
	arena.build(Arena.disc(radius))
	arena.setup_view(Vector3.ZERO, 18.0 + radius)
	arena.decorate(rng.randi(), radius)
	spawn_characters(arena.spawn_ring(players.size(), radius * 0.62))


func tick(delta: float) -> void:
	# Erode the island from the outside in, one tile at a time.
	_erode_t += delta
	var rate := 0.45 if elapsed < 30.0 else 0.25
	if elapsed > 8.0 and _erode_t > rate:
		_erode_t = 0.0
		var solid := arena.solid_tiles()
		if solid.size() > 6:
			solid.sort_custom(func(a, b): return a.position.length() > b.position.length())
			var pick: ArenaTile = solid[rng.randi() % mini(6, solid.size())]
			pick.crack(1.2)
			Sfx.play_varied("crack", 0.2, -10.0)


func bot_input(ch: PlayerCharacter) -> Dictionary:
	var m := mem(ch)
	var target := nearest(ch)
	var move := Vector2.ZERO
	var dash := false
	var to_center := arena.focus - ch.global_position
	to_center.y = 0
	if not arena.is_safe(ch.global_position + Vector3(ch.velocity.x, 0, ch.velocity.z) * 0.25) and to_center.length() > 1.0:
		move = Vector2(to_center.x, to_center.z).normalized()
	elif target:
		# Approach from the side facing the centre, so the push sends them outward.
		var inward := arena.focus - target.global_position
		inward.y = 0.0
		var aim := target.global_position + inward.normalized() * 0.9
		move = bot_go(ch, aim if ch.global_position.distance_to(target.global_position) > 1.6 else target.global_position)
		dash = bot_lined_up(ch, target.global_position, 2.4) and bot_roll(ch, 6.0)
	# Some CPUs hesitate now and then.
	m.think -= get_physics_process_delta_time()
	if m.think <= 0.0:
		m.think = rng.randf_range(0.6, 1.6)
		m.lazy = rng.randf() > ch.slot.skill
	if m.get("lazy", false):
		move *= 0.5
	return {"move": move, "action": dash, "hold": false}

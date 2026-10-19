extends Minigame
## Boulders rain from the sky. Watch the shadows and don't get squashed.

const FALL_HEIGHT := 14.0

var drops: Array[Dictionary] = [] ## {pos, radius, warn, t, decal, rock}
var _spawn_t := 2.0
var radius := 5.0


func _init() -> void:
	title = "Rockfall"
	tagline = "Dodge the falling boulders!"
	rules = [
		"Red circles show where boulders will land.",
		"Get squashed or fall in the sea and you're out.",
		"It gets wilder over time. Survive to win!",
	]
	action_name = "Dash"
	accent = Color("ff7a6a")
	time_limit = 50.0
	last_standing = true
	bump_power = 5.0


func build() -> void:
	radius = 4.8 + 0.15 * players.size()
	arena.build(Arena.disc(radius))
	arena.setup_view(Vector3.ZERO, 18.0 + radius)
	arena.decorate(rng.randi(), radius)
	spawn_characters(arena.spawn_ring(players.size(), radius * 0.55))


func tick(delta: float) -> void:
	var intensity := clampf(elapsed / 40.0, 0.0, 1.0)
	_spawn_t -= delta
	if _spawn_t <= 0.0:
		_spawn_t = lerpf(0.9, 0.22, intensity) / sqrt(maxf(1.0, players.size() / 3.0))
		var big := rng.randf() < 0.1 + intensity * 0.2
		var pos: Vector3
		var alive := alive_chars()
		if elapsed > 6.0 and rng.randf() < 0.45 and not alive.is_empty():
			# Aim at someone, with a little lead.
			var target: PlayerCharacter = alive[rng.randi() % alive.size()]
			pos = target.global_position + Vector3(target.velocity.x, 0, target.velocity.z) * 0.5
		else:
			var a := rng.randf() * TAU
			pos = Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.0, radius)
		pos.y = 0.0
		if elapsed < 6.0:
			big = false
		_add_drop(pos, 1.5 if big else 0.8, 1.7 if big else lerpf(1.5, 0.9, intensity))

	for i in range(drops.size() - 1, -1, -1):
		var d := drops[i]
		d.t -= delta
		var k: float = 1.0 - d.t / d.warn
		var decal: Decal = d.decal
		decal.size = Vector3.ONE * d.radius * 2.0 * lerpf(0.3, 1.0, minf(1.0, k * 1.5))
		decal.size.y = 6.0
		var rock: Node3D = d.rock
		rock.position.y = lerpf(FALL_HEIGHT, 0.4, clampf((k - 0.7) / 0.3, 0.0, 1.0))
		if d.t <= 0.0:
			_impact(d)
			drops.remove_at(i)


func _add_drop(pos: Vector3, r: float, warn: float) -> void:
	var decal := Art.zone_decal(Color("ff4a3a"), r, 0.35)
	decal.position = pos
	arena.add_child(decal)
	var rock := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = r * 0.75
	s.height = r * 1.3
	s.radial_segments = 8
	s.rings = 4
	rock.mesh = s
	rock.material_override = Art.material("rock", 1.0)
	rock.position = Vector3(pos.x, FALL_HEIGHT, pos.z)
	rock.rotation = Vector3(rng.randf(), rng.randf(), rng.randf()) * TAU
	arena.add_child(rock)
	drops.append({"pos": pos, "radius": r, "warn": warn, "t": warn, "decal": decal, "rock": rock})


func _impact(d: Dictionary) -> void:
	var pos: Vector3 = d.pos
	d.decal.queue_free()
	var on_land := arena.is_safe(pos)
	if on_land:
		Sfx.play_varied("boom", 0.2, -8.0 if d.radius < 1.0 else -2.0)
		arena.shake(0.35 if d.radius < 1.0 else 0.8)
		Fx.burst(arena, pos + Vector3.UP * 0.3, Color("9a9ea8"), 18, 5.0)
	else:
		Fx.splash(arena, Vector3(pos.x, Arena.WATER_Y, pos.z))
		Sfx.play_varied("splash", 0.2, -6.0)
	for ch in alive_chars():
		var off := ch.global_position - pos
		off.y = 0.0
		if off.length() < d.radius * 0.95 and ch.invulnerable <= 0.0:
			Fx.burst(arena, ch.global_position + Vector3.UP * 0.5, ch.slot.color, 24, 6.0)
			ch.eliminate()
		elif off.length() < d.radius + 1.2:
			ch.hit(off.normalized() * 5.0, 0.15)
	var rock: Node3D = d.rock
	var tw := rock.create_tween()
	tw.tween_interval(0.5)
	tw.tween_property(rock, "scale", Vector3.ZERO, 0.3)
	tw.tween_callback(rock.queue_free)


func bot_input(ch: PlayerCharacter) -> Dictionary:
	var pos := ch.global_position
	var threat := Vector3.ZERO
	var urgent := false
	for d in drops:
		var off: Vector3 = pos - d.pos
		off.y = 0.0
		var danger: float = d.radius + 0.7
		if off.length() < danger:
			var w: float = (danger - off.length()) / danger
			threat += (off.normalized() if off.length() > 0.01 else Vector3.RIGHT) * w
			if d.t < 0.45:
				urgent = true
	# Slow reactions for sleepy CPUs.
	var m := mem(ch)
	m.think -= get_physics_process_delta_time()
	if m.think <= 0.0:
		m.think = lerpf(0.35, 0.05, ch.slot.skill)
		m.threat = threat
	threat = m.threat
	if threat.length() > 0.05:
		var move := bot_steer(ch, threat.normalized(), 0.9)
		return {"move": move, "action": urgent and bot_roll(ch, 8.0), "hold": false}
	var home := arena.focus - pos
	home.y = 0.0
	if home.length() > radius * 0.5:
		return {"move": bot_go(ch, arena.focus), "action": false, "hold": false}
	return {"move": bot_wander(ch) * 0.5, "action": false, "hold": false}

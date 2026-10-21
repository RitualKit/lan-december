extends Minigame
## Snowball fight on a winter island. Every hit scores a point. Snow walls give cover.

const THROW_COOLDOWN := 0.5
const BALL_SPEED := 12.0
const BALL_RANGE := 9.0

var scores := {}
var _balls: Array[Dictionary] = [] ## {node, owner, vel, travelled}
var _cooldown := {}
var radius := 5.5


func _init() -> void:
	title = "Snowball Fight"
	tagline = "Pelt everyone with snowballs!"
	rules = [
		"Press action to throw a snowball the way you're facing.",
		"Every hit is a point. Hide behind the snow walls.",
		"Most hits when time runs out wins.",
	]
	action_name = "Throw"
	accent = Color("bfe4ff")
	theme_name = "winter"
	time_limit = 45.0
	bump_power = 6.0


func build() -> void:
	radius = 5.0 + 0.15 * players.size()
	var cells := Arena.disc(radius)
	# Snow forts: short walls dotted around the middle.
	for wall in [[Vector2i(-2, -2), Vector2i(-1, -2)], [Vector2i(2, 1), Vector2i(2, 2)], [Vector2i(-3, 2)], [Vector2i(1, -3)], [Vector2i(3, -1)]]:
		for c in wall:
			cells[c] = 1
	arena.build(cells)
	arena.setup_view(Vector3.ZERO, 18.0 + radius)
	arena.decorate(rng.randi(), radius)
	spawn_characters(arena.spawn_ring(players.size(), radius * 0.7))
	for ch in chars:
		ch.can_dash = false
		ch.acted.connect(_throw)
		scores[ch.slot] = 0
		_cooldown[ch] = 0.0


func _throw(ch: PlayerCharacter) -> void:
	if _cooldown[ch] > 0.0 or not running:
		return
	_cooldown[ch] = THROW_COOLDOWN
	var dir: Vector3 = mem(ch).get("aim", ch.facing) if ch.slot.is_bot else ch.facing
	var ball := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.14
	s.height = 0.28
	s.radial_segments = 8
	s.rings = 4
	ball.mesh = s
	ball.material_override = Art.material("snow", 2.0)
	arena.add_child(ball)
	ball.global_position = ch.global_position + Vector3.UP * 0.75 + dir * 0.4
	_balls.append({"node": ball, "owner": ch, "vel": dir * BALL_SPEED, "travelled": 0.0})
	Sfx.play_varied("throw", 0.1, -6.0)


func tick(delta: float) -> void:
	for ch in _cooldown:
		_cooldown[ch] = maxf(0.0, _cooldown[ch] - delta)
	for i in range(_balls.size() - 1, -1, -1):
		var b := _balls[i]
		var node: MeshInstance3D = b.node
		var step: Vector3 = b.vel * delta
		node.global_position += step
		b.travelled += step.length()
		# A little arc so it reads as a throw.
		var k: float = b.travelled / BALL_RANGE
		node.global_position.y = (b.owner as PlayerCharacter).global_position.y + 0.75 + sin(k * PI) * 0.6 - k * 0.4
		var done: bool = b.travelled > BALL_RANGE
		var tile := arena.tile_at(node.global_position)
		if tile and tile.level > 0 and node.global_position.y < tile.top_y + 0.2:
			done = true
		if not done:
			for c in alive_chars():
				if c == b.owner:
					continue
				var d := c.global_position + Vector3.UP * 0.5 - node.global_position
				if Vector2(d.x, d.z).length() < 0.5 and absf(d.y) < 0.9:
					_hit(b.owner, c, (b.vel as Vector3).normalized())
					done = true
					break
		if done:
			Fx.burst(arena, node.global_position, Color.WHITE, 10, 2.5)
			node.queue_free()
			_balls.remove_at(i)
	for ch in chars:
		if not ch.alive and not mem(ch).get("respawning", false):
			_respawn(ch)


func _hit(thrower: PlayerCharacter, victim: PlayerCharacter, dir: Vector3) -> void:
	if victim.invulnerable > 0.0:
		return
	victim.hit(dir * 6.0, 0.45)
	scores[thrower.slot] += 1
	Sfx.play_varied("hit")
	Fx.popup(arena, thrower.global_position + Vector3.UP * 1.8, "+1", thrower.slot.color.lightened(0.3), 40)
	arena.shake(0.15)


func _respawn(ch: PlayerCharacter) -> void:
	mem(ch).respawning = true
	scores[ch.slot] = maxi(0, scores[ch.slot] - 1)
	Fx.popup(arena, Vector3(ch.global_position.x, 0.5, ch.global_position.z), "-1", Color("ff8a7a"), 40)
	await get_tree().create_timer(1.2, false, true).timeout
	if not is_instance_valid(ch) or ended:
		return
	var a := rng.randf() * TAU
	ch.revive_at(Vector3(cos(a), 0, sin(a)) * (radius - 1.5) + Vector3.UP * 4.0)
	ch.invulnerable = 1.2
	mem(ch).respawning = false


func rank() -> Array:
	return score_ranking(scores)


func status_text(slot: PlayerSlot) -> String:
	return str(scores.get(slot, 0))


func bot_input(ch: PlayerCharacter) -> Dictionary:
	var m := mem(ch)
	var target := nearest(ch)
	if target == null:
		return {"move": bot_wander(ch), "action": false, "hold": false}
	var to := target.global_position - ch.global_position
	to.y = 0.0
	var dist := to.length()
	if not m.has("strafe"):
		m.strafe = 1.0 if rng.randf() < 0.5 else -1.0
	m.think -= get_physics_process_delta_time()
	if m.think <= 0.0:
		m.think = rng.randf_range(0.8, 2.0)
		m.strafe = -m.strafe
	var dir := to.normalized()
	var move: Vector3
	if dist > 6.0:
		move = dir
	elif dist < 3.0:
		move = -dir * 0.6 + dir.cross(Vector3.UP) * m.strafe * 0.6
	else:
		move = dir.cross(Vector3.UP) * m.strafe * 0.8
	# Aim with a lead and a skill-based wobble.
	var lead := target.velocity * (dist / BALL_SPEED) * ch.slot.skill
	var aim := (target.global_position + Vector3(lead.x, 0, lead.z) - ch.global_position)
	aim.y = 0.0
	m.aim = aim.normalized().rotated(Vector3.UP, rng.randf_range(-0.3, 0.3) * (1.0 - ch.slot.skill))
	var throw := dist < BALL_RANGE - 1.0 and bot_roll(ch, 3.0)
	return {"move": bot_steer(ch, move.normalized(), 1.0), "action": throw, "hold": false}

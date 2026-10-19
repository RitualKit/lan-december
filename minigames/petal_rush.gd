extends Minigame
## Grab as many blossoms as you can. Dashing into someone makes them drop some.

const PICK_RADIUS := 0.6
const GOLD_VALUE := 5

var scores := {}
var pickups: Array[Dictionary] = [] ## {node, value, pos, age}
var _gold_t := 6.0
var radius := 5.5


func _init() -> void:
	title = "Petal Rush"
	tagline = "Collect the most blossoms!"
	rules = [
		"Pink blossoms are worth 1, golden ones are worth 5.",
		"Dash into a rival to knock blossoms out of their hands.",
		"Most blossoms when time runs out wins.",
	]
	action_name = "Dash"
	powerups_enabled = true
	accent = Color("ffb3d6")
	time_limit = 40.0
	bump_power = 8.0


func build() -> void:
	radius = 5.0 + 0.15 * players.size()
	var cells := Arena.disc(radius)
	for i in 4:
		var a := TAU * i / 4.0 + PI / 4.0
		cells[Vector2i(roundi(cos(a) * radius * 0.55), roundi(sin(a) * radius * 0.55))] = 1
	arena.build(cells)
	arena.setup_view(Vector3.ZERO, 18.0 + radius)
	arena.decorate(rng.randi(), radius)
	spawn_characters(arena.spawn_ring(players.size(), radius * 0.35))
	for p in players:
		scores[p] = 0
	for i in 6 + players.size():
		_spawn_pickup(1)


func tick(delta: float) -> void:
	var wanted := 5 + players.size() * 2
	if pickups.filter(func(p): return p.value == 1).size() < wanted and rng.randf() < delta * 4.0:
		_spawn_pickup(1)
	_gold_t -= delta
	if _gold_t <= 0.0:
		_gold_t = rng.randf_range(5.0, 8.0)
		_spawn_pickup(GOLD_VALUE)

	for i in range(pickups.size() - 1, -1, -1):
		var p := pickups[i]
		p.age += delta
		var node: Node3D = p.node
		if p.age < 0.4:
			continue
		node.position.y = p.pos.y + 0.35 + sin(p.age * 4.0) * 0.08
		for ch in chars:
			if not ch.alive:
				continue
			var d := ch.global_position - node.global_position
			if Vector2(d.x, d.z).length() < PICK_RADIUS and absf(d.y + 0.35) < 1.0:
				scores[ch.slot] += p.value
				Sfx.play_varied("gold" if p.value > 1 else "coin", 0.06, -4.0)
				Fx.popup(arena, node.global_position + Vector3.UP * 0.4, "+%d" % p.value, Ui.GOLD if p.value > 1 else Color("ffd6e8"))
				node.queue_free()
				pickups.remove_at(i)
				break


func on_dash_hit(_attacker: PlayerCharacter, victim: PlayerCharacter) -> void:
	var lose := mini(scores[victim.slot], maxi(2, int(ceil(scores[victim.slot] * 0.25))))
	if lose <= 0:
		return
	scores[victim.slot] -= lose
	Fx.popup(arena, victim.global_position + Vector3.UP * 1.6, "-%d" % lose, Color("ff8a7a"))
	for i in lose:
		var a := rng.randf() * TAU
		var dist := rng.randf_range(1.0, 2.2)
		var pos := victim.global_position + Vector3(cos(a), 0, sin(a)) * dist
		if arena.is_safe(pos):
			_add_pickup(1, Vector3(pos.x, arena.tile_at(pos).top_y, pos.z), victim.global_position)


func _spawn_pickup(value: int) -> void:
	var tiles := arena.solid_tiles()
	for attempt in 10:
		var t: ArenaTile = tiles[rng.randi() % tiles.size()]
		var pos := Vector3(t.cell.x, t.top_y, t.cell.y)
		if pickups.any(func(p): return p.pos.distance_to(pos) < 0.9):
			continue
		_add_pickup(value, pos, pos + Vector3.UP * 4.0)
		return


func _add_pickup(value: int, pos: Vector3, from: Vector3) -> void:
	var gold := value > 1
	var s := Art.icon_sprite("flower", Color("ffd45a") if gold else Color("f7a8cc"), Color("fff6c0") if gold else Color("ffe066"), 0.09 if gold else 0.07)
	arena.add_child(s)
	s.global_position = from
	var tw := s.create_tween()
	tw.tween_property(s, "global_position", pos + Vector3.UP * 0.35, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	pickups.append({"node": s, "value": value, "pos": pos, "age": 0.0})
	if gold:
		Sfx.play("point", 1.4, -6.0)


func rank() -> Array:
	return score_ranking(scores)


func status_text(slot: PlayerSlot) -> String:
	return str(scores.get(slot, 0))


func bot_input(ch: PlayerCharacter) -> Dictionary:
	var m := mem(ch)
	m.think -= get_physics_process_delta_time()
	if m.think <= 0.0 or not is_instance_valid(m.get("goal")):
		m.think = rng.randf_range(0.25, 0.6)
		var best: Node3D = null
		var best_cost := INF
		for p in pickups:
			var cost: float = ch.global_position.distance_to(p.node.global_position) / (3.0 if p.value > 1 else 1.0)
			cost += rng.randf() * 1.5 * (1.0 - ch.slot.skill)
			if cost < best_cost:
				best_cost = cost
				best = p.node
		m.goal = best
	var move := Vector2.ZERO
	if is_instance_valid(m.get("goal")):
		move = bot_go(ch, m.goal.global_position)
	else:
		move = bot_wander(ch)
	var dash := false
	var victim := nearest(ch)
	if victim and scores[victim.slot] >= 3 and bot_lined_up(ch, victim.global_position, 2.2):
		dash = bot_roll(ch, 5.0)
	return {"move": move, "action": dash, "hold": false}

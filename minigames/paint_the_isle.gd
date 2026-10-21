extends Minigame
## Run over tiles to paint them your colour. Most tiles at the end wins.

const BOMB_RADIUS := 2.2

var counts := {}
var _bombs: Array[Dictionary] = [] ## {node, pos}
var _bomb_t := 5.0


func _init() -> void:
	title = "Paint the Isle"
	tagline = "Cover the island in your colour!"
	rules = [
		"Every tile you run over turns your colour.",
		"Grab paint bombs to splash a big area.",
		"Most tiles when time runs out wins.",
	]
	action_name = "Dash"
	powerups_enabled = true
	accent = Color("7ab0ff")
	time_limit = 40.0
	bump_power = 9.0


func build() -> void:
	var w := 11 + (2 if players.size() > 4 else 0)
	var h := 9 + (2 if players.size() > 4 else 0)
	var cells := Arena.rect(w, h)
	# Round off the corners so it looks like an island.
	for c in cells.keys():
		if absi(c.x) == w / 2 and absi(c.y) == h / 2:
			cells.erase(c)
	arena.build(cells)
	arena.setup_view(Vector3.ZERO, 16.0 + w * 0.7)
	arena.decorate(rng.randi(), w * 0.55)
	spawn_characters(arena.spawn_ring(players.size(), minf(w, h) * 0.32))
	for p in players:
		counts[p] = 0


func tick(delta: float) -> void:
	for ch in chars:
		if ch.alive and ch.is_on_floor():
			_paint(arena.tile_at(ch.global_position), ch.slot)
	_bomb_t -= delta
	if _bomb_t <= 0.0:
		_bomb_t = rng.randf_range(4.0, 7.0)
		_spawn_bomb()
	for i in range(_bombs.size() - 1, -1, -1):
		var b := _bombs[i]
		var node: Node3D = b.node
		node.position.y = 0.45 + sin(elapsed * 5.0 + i) * 0.08
		for ch in chars:
			if ch.alive and Vector2(ch.global_position.x - b.pos.x, ch.global_position.z - b.pos.z).length() < 0.6:
				_explode(b.pos, ch.slot)
				node.queue_free()
				_bombs.remove_at(i)
				break
	for ch in chars:
		if not ch.alive and not mem(ch).get("respawning", false):
			_respawn(ch)


func _paint(t: ArenaTile, slot: PlayerSlot) -> void:
	if t == null or t.painted_by == slot:
		return
	if t.painted_by:
		counts[t.painted_by] -= 1
	t.painted_by = slot
	counts[slot] += 1
	t.set_top("paint_" + slot.color.to_html(false))
	if rng.randf() < 0.3:
		Sfx.play_varied("paint", 0.2, -10.0)


func _spawn_bomb() -> void:
	var tiles := arena.solid_tiles()
	var t: ArenaTile = tiles[rng.randi() % tiles.size()]
	var s: Node3D = Props.bomb(Color("3f7fe8")) if Game.look_3d else Art.icon_sprite("bomb", Color("7ab0ff"), Color("ffe066"), 0.08)
	arena.add_child(s)
	s.position = Vector3(t.cell.x, 0.45, t.cell.y)
	_bombs.append({"node": s, "pos": s.position})
	Sfx.play("point", 1.2, -6.0)


func _explode(pos: Vector3, slot: PlayerSlot) -> void:
	Sfx.play("boom", 1.6, -6.0)
	Fx.burst(arena, pos + Vector3.UP * 0.3, slot.color, 40, 7.0)
	arena.shake(0.3)
	for t in arena.tiles.values():
		if Vector2(t.cell.x - pos.x, t.cell.y - pos.z).length() <= BOMB_RADIUS:
			_paint(t, slot)


func _respawn(ch: PlayerCharacter) -> void:
	mem(ch).respawning = true
	await get_tree().create_timer(1.2, false, true).timeout
	if not is_instance_valid(ch) or ended:
		return
	ch.revive_at(Vector3(rng.randf_range(-2, 2), 5.0, rng.randf_range(-2, 2)))
	ch.invulnerable = 1.2
	mem(ch).respawning = false


func rank() -> Array:
	return score_ranking(counts)


func status_text(slot: PlayerSlot) -> String:
	return str(counts.get(slot, 0))


func bot_input(ch: PlayerCharacter) -> Dictionary:
	var m := mem(ch)
	m.think -= get_physics_process_delta_time()
	if m.think <= 0.0 or not m.has("goal") or ch.global_position.distance_to(m.goal) < 0.4:
		m.think = rng.randf_range(0.3, 0.8)
		var best := ch.global_position
		var best_cost := INF
		for b in _bombs:
			var c: float = ch.global_position.distance_to(b.pos) * 0.35
			if c < best_cost:
				best_cost = c
				best = b.pos
		for i in 14:
			var t: ArenaTile = arena.tiles.values()[rng.randi() % arena.tiles.size()]
			if t.painted_by == ch.slot:
				continue
			var p := Vector3(t.cell.x, 0, t.cell.y)
			var c := ch.global_position.distance_to(p) - (1.0 if t.painted_by else 0.0)
			if c < best_cost:
				best_cost = c
				best = p
		m.goal = best
	var move := bot_go(ch, m.goal)
	var rival := nearest(ch)
	var dash := rival != null and bot_lined_up(ch, rival.global_position, 2.0) and bot_roll(ch, 2.0)
	return {"move": move, "action": dash, "hold": false}

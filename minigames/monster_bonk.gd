extends Minigame
## Whack-a-mole: monsters pop out of the ground for a moment. Dash into them to bonk
## them for points. Golden ones are worth 3. Don't bonk the fire spirits!

const KINDS := {
	"slime": {"sheet": "monsters/3", "points": 1, "weight": 4},
	"blob": {"sheet": "monsters/18", "points": 1, "weight": 4},
	"ghost": {"sheet": "monsters/7", "points": 1, "weight": 3},
	"gold": {"sheet": "monsters/10", "points": 3, "weight": 1},
	"fire": {"sheet": "monsters/2", "points": -2, "weight": 2},
}
const BONK_RADIUS := 0.7

var scores := {}
var monsters: Array[Dictionary] = [] ## {node, hole, pos, kind, life, max_life}
var _spawn_t := 0.5
var radius := 5.5


func _init() -> void:
	title = "Monster Bonk"
	tagline = "Bonk the monsters as they pop up!"
	rules = [
		"Monsters pop out of holes for a moment. Dash into one to bonk it.",
		"Gold monsters are worth 3 points.",
		"Bonk a fire spirit and you get burnt: minus 2!",
	]
	action_name = "Dash"
	accent = Color("8ad86a")
	time_limit = 40.0
	bump_power = 7.0


func build() -> void:
	radius = 5.0 + 0.15 * players.size()
	arena.build(Arena.disc(radius))
	arena.setup_view(Vector3.ZERO, 18.0 + radius)
	arena.decorate(rng.randi(), radius)
	spawn_characters(arena.spawn_ring(players.size(), radius * 0.45))
	for p in players:
		scores[p] = 0


func tick(delta: float) -> void:
	_spawn_t -= delta
	var cap := 3 + players.size()
	if _spawn_t <= 0.0 and monsters.size() < cap:
		_spawn_t = lerpf(0.9, 0.35, elapsed / time_limit) * 4.0 / maxf(players.size(), 2.0)
		_spawn()
	for i in range(monsters.size() - 1, -1, -1):
		var mo := monsters[i]
		mo.life -= delta
		var node: Sprite3D = mo.node
		# Pop up, wobble, sink back down.
		var age: float = mo.max_life - mo.life
		var up := clampf(age / 0.15, 0.0, 1.0) * clampf(mo.life / 0.2, 0.0, 1.0)
		node.offset.y = lerpf(-8.0, 8.0, up)
		node.frame = int(age * 6.0) % 4 * 4
		if mo.life <= 0.0:
			_remove(i)
			continue
		if up < 0.6:
			continue
		for ch in alive_chars():
			if not ch.is_dashing():
				continue
			var d: Vector3 = ch.global_position - mo.pos
			if Vector2(d.x, d.z).length() < BONK_RADIUS:
				_bonk(ch, mo)
				ch.end_dash()
				_remove(i)
				break
	for ch in chars:
		if not ch.alive and not mem(ch).get("respawning", false):
			_respawn(ch)


func _spawn() -> void:
	var tiles := arena.solid_tiles()
	for attempt in 12:
		var t: ArenaTile = tiles[rng.randi() % tiles.size()]
		var pos := Vector3(t.cell.x, t.top_y, t.cell.y)
		if monsters.any(func(m): return m.pos.distance_to(pos) < 1.2):
			continue
		if alive_chars().any(func(c): return c.global_position.distance_to(pos) < 0.8):
			continue
		var kind := _roll()
		var sprite := Art.pack_sprite(KINDS[kind].sheet, 4, Art.PIXEL_SIZE * 1.3)
		sprite.vframes = 4
		arena.add_child(sprite)
		sprite.global_position = pos + Vector3.UP * 0.05
		var hole := GroundMark.new(Art.marker_texture(Color("3a2a20")), Vector3(1.0, 2.0, 1.0))
		arena.add_child(hole)
		hole.global_position = pos + (Vector3.DOWN * 0.2 if GroundMark.use_decals else Vector3.ZERO)
		var life := rng.randf_range(1.3, 2.2)
		monsters.append({"node": sprite, "hole": hole, "pos": pos, "kind": kind, "life": life, "max_life": life})
		return


func _roll() -> String:
	var total := 0
	for k in KINDS:
		total += KINDS[k].weight
	var r := rng.randi_range(1, total)
	for k in KINDS:
		r -= KINDS[k].weight
		if r <= 0:
			return k
	return "slime"


func _remove(i: int) -> void:
	var mo := monsters[i]
	mo.node.queue_free()
	mo.hole.queue_free()
	monsters.remove_at(i)


func _bonk(ch: PlayerCharacter, mo: Dictionary) -> void:
	var pts: int = KINDS[mo.kind].points
	scores[ch.slot] = maxi(0, scores[ch.slot] + pts)
	var pos: Vector3 = mo.pos + Vector3.UP * 0.6
	if pts < 0:
		Fx.anim(arena, pos, "fx/12", 1.6)
		Sfx.play("boom", 1.4, -4.0)
		ch.hit(Vector3.ZERO, 1.0)
		Fx.popup(arena, pos + Vector3.UP, "%d BURNT!" % pts, Color("ff6a3a"), 40)
	else:
		Fx.anim(arena, pos, "fx/7", 1.6, 18.0)
		Sfx.play("gold" if pts > 1 else "coin")
		Fx.popup(arena, pos + Vector3.UP, "+%d" % pts, Ui.GOLD if pts > 1 else Color.WHITE, 44)
	arena.shake(0.15)


func _respawn(ch: PlayerCharacter) -> void:
	mem(ch).respawning = true
	await get_tree().create_timer(1.2, false, true).timeout
	if not is_instance_valid(ch) or ended:
		return
	ch.revive_at(Vector3(rng.randf_range(-2, 2), 4.0, rng.randf_range(-2, 2)))
	ch.invulnerable = 1.0
	mem(ch).respawning = false


func rank() -> Array:
	return score_ranking(scores)


func status_text(slot: PlayerSlot) -> String:
	return str(scores.get(slot, 0))


func bot_input(ch: PlayerCharacter) -> Dictionary:
	var best: Dictionary = {}
	var best_cost := INF
	for mo in monsters:
		if mo.kind == "fire" and rng.randf() < 0.97:
			continue
		var d: float = ch.global_position.distance_to(mo.pos)
		var pts: int = KINDS[mo.kind].points
		var cost: float = d / pts if pts > 0 else d + 8.0
		if d / ch.speed > mo.life + 0.2:
			continue
		if cost < best_cost:
			best_cost = cost
			best = mo
	if best.is_empty():
		return {"move": bot_wander(ch) * 0.6, "action": false, "hold": false}
	var move := bot_go(ch, best.pos)
	var to: Vector3 = best.pos - ch.global_position
	to.y = 0.0
	var dash := to.length() < 2.2 and to.length() > 0.3 and to.normalized().dot(ch.facing) > 0.85 and bot_roll(ch, 8.0)
	return {"move": move, "action": dash, "hold": false}

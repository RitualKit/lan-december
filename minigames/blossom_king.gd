extends Minigame
## King of the hill: stand in the glowing circle alone to score. It keeps moving.

const ZONE_RADIUS := 1.5
const MOVE_EVERY := 8.0
const WARN_TIME := 2.0

var scores := {}
var zone_pos := Vector3.ZERO
var next_pos := Vector3.ZERO
var _zone: Decal
var _next: Decal
var _move_t := MOVE_EVERY
var _ding := {}
var radius := 5.5
var contested := false
var _since := {} ## PlayerCharacter -> time they stepped into the circle


func _init() -> void:
	title = "Blossom King"
	tagline = "Hold the golden circle!"
	rules = [
		"Stand inside the golden circle to earn points.",
		"Crowded? Only whoever has held it longest scores, at half speed.",
		"The circle hops somewhere new every few seconds.",
	]
	action_name = "Dash"
	powerups_enabled = true
	accent = Ui.GOLD
	time_limit = 45.0
	bump_power = 10.0


func build() -> void:
	radius = 5.0 + 0.15 * players.size()
	arena.build(Arena.disc(radius))
	arena.setup_view(Vector3.ZERO, 18.0 + radius)
	arena.decorate(rng.randi(), radius)
	spawn_characters(arena.spawn_ring(players.size(), radius * 0.7))
	for p in players:
		scores[p] = 0.0
		_ding[p] = 0
	_zone = Art.zone_decal(Ui.GOLD, ZONE_RADIUS, 0.35)
	arena.add_child(_zone)
	_next = Art.zone_decal(Color("fff2c0"), ZONE_RADIUS, 0.08)
	_next.visible = false
	arena.add_child(_next)
	zone_pos = Vector3.ZERO
	_zone.position = zone_pos


func tick(delta: float) -> void:
	_move_t -= delta
	if _move_t <= WARN_TIME and not _next.visible:
		next_pos = _pick_spot()
		_next.position = next_pos
		_next.visible = true
	if _move_t <= 0.0:
		_move_t = MOVE_EVERY
		zone_pos = next_pos
		_next.visible = false
		Sfx.play("point", 0.8)
		var tw := _zone.create_tween()
		tw.tween_property(_zone, "position", zone_pos, 0.25).set_trans(Tween.TRANS_QUAD)
	_zone.modulate = Color(1, 1, 1, 0.6 + 0.4 * sin(elapsed * 6.0)) if contested else Color.WHITE

	var king: PlayerCharacter = null
	var inside := 0
	for ch in chars:
		if ch.alive and _in_zone(ch.global_position):
			inside += 1
			if not _since.has(ch):
				_since[ch] = elapsed
			if king == null or _since[ch] < _since[king]:
				king = ch
		else:
			_since.erase(ch)
	contested = inside > 1
	if king:
		var slot := king.slot
		scores[slot] += delta * (0.5 if contested else 1.0)
		if int(scores[slot]) > _ding[slot]:
			_ding[slot] = int(scores[slot])
			Sfx.play("coin", 1.0, -8.0)
			Fx.popup(arena, king.global_position + Vector3.UP * 1.7, "+1", Ui.GOLD, 36)
	# Players who fall in come back after a short swim.
	for ch in chars:
		if not ch.alive and not mem(ch).get("respawning", false):
			_respawn(ch)


func _in_zone(p: Vector3) -> bool:
	return Vector2(p.x - _zone.position.x, p.z - _zone.position.z).length() < ZONE_RADIUS


func _pick_spot() -> Vector3:
	for attempt in 20:
		var a := rng.randf() * TAU
		var r := rng.randf_range(0.0, radius - ZONE_RADIUS - 0.3)
		var p := Vector3(cos(a) * r, 0, sin(a) * r)
		if p.distance_to(zone_pos) > 3.0:
			return p
	return -zone_pos


func _respawn(ch: PlayerCharacter) -> void:
	mem(ch).respawning = true
	await get_tree().create_timer(1.5).timeout
	if not is_instance_valid(ch) or ended:
		return
	var a := rng.randf() * TAU
	ch.revive_at(Vector3(cos(a), 0, sin(a)) * (radius - 1.0) + Vector3.UP * 5.0)
	ch.invulnerable = 1.5
	mem(ch).respawning = false


func rank() -> Array:
	var whole := {}
	for p in scores:
		whole[p] = int(scores[p])
	return score_ranking(whole)


func status_text(slot: PlayerSlot) -> String:
	return str(int(scores.get(slot, 0.0)))


func bot_input(ch: PlayerCharacter) -> Dictionary:
	var target := zone_pos
	if _next.visible and _move_t < 1.0 + (1.0 - ch.slot.skill):
		target = next_pos
	var m := mem(ch)
	if not m.has("offset"):
		m.offset = Vector3(rng.randf_range(-0.6, 0.6), 0, rng.randf_range(-0.6, 0.6))
	var move := bot_go(ch, target + m.offset)
	var dash := false
	var rival := nearest(ch)
	if rival and _in_zone(rival.global_position) and bot_lined_up(ch, rival.global_position, 2.3):
		dash = bot_roll(ch, 4.0)
	return {"move": move, "action": dash, "hold": false}

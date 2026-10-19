extends Minigame
## Musical chairs: wander while the music plays. When it stops, stumps pop up, one
## fewer than there are players. Grab one or you're out.

const CLAIM_RADIUS := 0.55
const SCRAMBLE_LIMIT := 6.0
const TUNE := [1.0, 1.26, 1.5, 1.26, 1.0, 1.5, 1.68, 1.5, 1.26, 1.12, 1.0, 0.84]

enum Phase { MUSIC, SCRAMBLE, RESULT }

var phase := Phase.MUSIC
var stumps: Array[Dictionary] = [] ## {node, pos, owner: PlayerCharacter}
var radius := 5.0
var _t := 0.0
var _note_t := 0.0
var _note := 0
var _music_len := 4.0


func _init() -> void:
	title = "Stump Scramble"
	tagline = "When the music stops, grab a stump!"
	rules = [
		"Keep moving while the music plays.",
		"When it stops, stumps pop up: one fewer than players left.",
		"No stump? You're out. Dash rivals away before they sit!",
	]
	action_name = "Dash"
	accent = Color("c8a070")
	time_limit = 0.0
	last_standing = true
	bump_power = 9.0


func build() -> void:
	radius = 4.4 + 0.2 * players.size()
	arena.build(Arena.disc(radius))
	arena.setup_view(Vector3.ZERO, 18.0 + radius)
	arena.decorate(rng.randi(), radius)
	spawn_characters(arena.spawn_ring(players.size(), radius * 0.5))


func on_begin() -> void:
	_start_music()


func _start_music() -> void:
	phase = Phase.MUSIC
	_music_len = rng.randf_range(2.5, 5.0)
	_t = 0.0
	for s in stumps:
		var node: Node3D = s.node
		node.create_tween().tween_property(node, "scale", Vector3(1, 0.01, 1), 0.25)
		node.get_tree().create_timer(0.3).timeout.connect(node.queue_free)
	stumps.clear()
	for ch in alive_chars():
		ch.frozen = false
		ch.cheering = false
		ch.clear_status()
	Ui.banner(_hud, "~ MUSIC ~", Color("ffd6e8"), 64, 0.6)


func tick(delta: float) -> void:
	_t += delta
	match phase:
		Phase.MUSIC:
			_note_t -= delta
			if _note_t <= 0.0:
				_note_t = 0.22
				Sfx.play("blip", TUNE[_note % TUNE.size()], -8.0)
				_note += 1
			if _t >= _music_len:
				_spawn_stumps()
		Phase.SCRAMBLE:
			_claim()
			var open := stumps.filter(func(s): return s.owner == null)
			if open.is_empty() or _t > SCRAMBLE_LIMIT:
				_resolve()
		Phase.RESULT:
			if _t > 1.4 and alive_chars().size() > 1:
				_start_music()


func _spawn_stumps() -> void:
	phase = Phase.SCRAMBLE
	_t = 0.0
	Sfx.play("whistle")
	Ui.banner(_hud, "SIT!", Ui.GOLD, 120, 0.4)
	var count := alive_chars().size() - 1
	var spots: Array[Vector3] = []
	for attempt in 200:
		if spots.size() >= count:
			break
		var a := rng.randf() * TAU
		var d := sqrt(rng.randf()) * (radius - 1.2)
		var p := Vector3(cos(a) * d, 0, sin(a) * d)
		if spots.any(func(q): return q.distance_to(p) < 1.6):
			continue
		spots.append(p)
	for p in spots:
		var node := _make_stump()
		arena.add_child(node)
		node.global_position = p
		node.scale = Vector3(1, 0.01, 1)
		node.create_tween().tween_property(node, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK)
		stumps.append({"node": node, "pos": p, "owner": null})
		Fx.burst(arena, p + Vector3.UP * 0.3, Color("c8a070"), 8, 3.0)


func _make_stump() -> Node3D:
	var root := Node3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.42
	cyl.bottom_radius = 0.48
	cyl.height = 0.3
	cyl.radial_segments = 10
	var m := MeshInstance3D.new()
	m.mesh = cyl
	m.material_override = Art.material("bark", 1.0)
	m.position.y = 0.15
	root.add_child(m)
	var top := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.38
	disc.bottom_radius = 0.38
	disc.height = 0.02
	disc.radial_segments = 10
	top.mesh = disc
	top.material_override = Art.material("wood", 1.0)
	top.position.y = 0.31
	root.add_child(top)
	return root


func _claim() -> void:
	for ch in alive_chars():
		if ch.frozen:
			continue
		for s in stumps:
			if s.owner != null:
				continue
			var d: Vector3 = ch.global_position - s.pos
			if Vector2(d.x, d.z).length() < CLAIM_RADIUS and ch.is_on_floor():
				s.owner = ch
				ch.frozen = true
				ch.global_position = s.pos + Vector3.UP * 0.32
				ch.velocity = Vector3.ZERO
				ch.cheering = true
				ch.add_status("seated", 30.0) # Seated players can't be knocked off.
				Sfx.play("coin")
				Fx.popup(arena, s.pos + Vector3.UP * 1.8, "SAFE!", ch.slot.color.lightened(0.3), 40)
				break


func _resolve() -> void:
	phase = Phase.RESULT
	_t = 0.0
	var safe := stumps.map(func(s): return s.owner)
	for ch in alive_chars():
		if not safe.has(ch):
			Fx.anim(arena, ch.global_position + Vector3.UP * 0.6, "fx/18", 1.6)
			Sfx.play("ko")
			ch.eliminate()


func status_text(slot: PlayerSlot) -> String:
	var ch := char_of(slot)
	if ch == null or not ch.alive:
		return "OUT"
	return "SAFE" if ch.frozen and phase != Phase.MUSIC else ""


func bot_input(ch: PlayerCharacter) -> Dictionary:
	var m := mem(ch)
	if phase == Phase.MUSIC:
		m.erase("goal")
		m.reaction = rng.randf_range(0.1, 0.55) * (1.3 - ch.slot.skill)
		return {"move": bot_wander(ch) * 0.7, "action": false, "hold": false}
	if phase != Phase.SCRAMBLE:
		return {"move": Vector2.ZERO, "action": false, "hold": false}
	if _t < m.get("reaction", 0.2):
		return {"move": Vector2.ZERO, "action": false, "hold": false}
	# Head for the closest free stump that nobody is clearly closer to.
	var best: Dictionary = {}
	var best_cost := INF
	for s in stumps:
		if s.owner != null:
			continue
		var mine := ch.global_position.distance_to(s.pos)
		var rival := INF
		for o in alive_chars():
			if o != ch and not o.frozen:
				rival = minf(rival, o.global_position.distance_to(s.pos))
		var cost := mine + (2.0 if rival < mine - 0.5 else 0.0)
		if cost < best_cost:
			best_cost = cost
			best = s
	if best.is_empty():
		return {"move": Vector2.ZERO, "action": false, "hold": false}
	var move := bot_go(ch, best.pos, 0.6)
	var dash := false
	var rival_ch := nearest(ch)
	if rival_ch and not rival_ch.frozen and rival_ch.global_position.distance_to(best.pos) < 1.0:
		dash = bot_lined_up(ch, rival_ch.global_position, 2.0) and bot_roll(ch, 4.0)
	return {"move": move, "action": dash, "hold": false}

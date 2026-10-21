extends Minigame
## Frogger-style race: cross the river on drifting logs three times (there, back, there).
## Falling in sends you back to the bank you came from.

const HALF_WIDTH := 7
const START_Z := 6
const FINISH_Z := -6
## Log lanes (z) and their speeds; rows in between are land.
const LANES := {4: 1.6, 3: -2.2, 2: 1.2, -1: -1.4, -2: 2.4, -3: -1.8, -4: 1.5}
const SWEPT_X := 8.0
const CROSSINGS := 3

var lanes: Array[Dictionary] = [] ## {z, speed, logs: [{body, length}]}
var arrived: Array[PlayerSlot] = []
var crossings := {} ## PlayerSlot -> banks reached so far
var heading := {} ## PlayerSlot -> -1 (to the far bank) or +1 (back to the start bank)
var progress := {} ## PlayerSlot -> best rows crossed in total, for ranking unfinished players
var _respawning := {}


func _init() -> void:
	title = "River Run"
	tagline = "Cross the river three times!"
	rules = [
		"Walk or hop from log to log: over, back, and over again.",
		"Fall in and you swim back to the bank you left from.",
		"The first three to finish score big. Shove rivals in!",
	]
	action_name = "Hop"
	accent = Color("6ac4e0")
	time_limit = 60.0
	bump_power = 4.0


func build() -> void:
	var cells := {}
	for x in range(-HALF_WIDTH, HALF_WIDTH + 1):
		for z in [START_Z, START_Z - 1, 1, 0, FINISH_Z, FINISH_Z + 1]:
			cells[Vector2i(x, z)] = 0
	arena.build(cells)
	arena.setup_view(Vector3(0, 0, 0.3), 23.0, 56.0)
	arena.decorate(rng.randi(), 8.0, 6)
	for z in LANES:
		_make_lane(z, LANES[z])
	var points: Array[Vector3] = []
	for i in players.size():
		var x := lerpf(-5.0, 5.0, (i + 0.5) / players.size())
		points.append(Vector3(x, 0.6, START_Z - 0.3))
	spawn_characters(points)
	for ch in chars:
		ch.can_dash = false
		ch.can_jump = true
		ch.speed = 4.4
		ch.facing = Vector3.FORWARD
		crossings[ch.slot] = 0
		heading[ch.slot] = -1
		progress[ch.slot] = 0
	_add_flag()


func _make_lane(z: int, speed: float) -> void:
	var lane := {"z": z, "speed": speed, "logs": []}
	var x := -SWEPT_X - 2.0 + rng.randf() * 2.0
	while x < SWEPT_X + 2.0:
		var length := rng.randf_range(1.8, 3.2)
		var body := AnimatableBody3D.new()
		body.sync_to_physics = false
		# Riders get carried by the platform's reported velocity.
		body.constant_linear_velocity = Vector3(speed, 0, 0)
		body.collision_layer = 1
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(length, 0.6, 0.9)
		shape.shape = box
		shape.position.y = -0.3
		body.add_child(shape)
		var mesh := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.42
		cyl.bottom_radius = 0.42
		cyl.height = length
		cyl.radial_segments = 8
		mesh.mesh = cyl
		mesh.material_override = Art.material("bark", 1.0)
		mesh.rotation.z = PI * 0.5
		mesh.position.y = -0.38
		body.add_child(mesh)
		body.position = Vector3(x + length * 0.5, 0, z)
		arena.add_child(body)
		lane.logs.append({"body": body, "length": length})
		x += length + rng.randf_range(2.2, 4.0)
	lanes.append(lane)


func _add_flag() -> void:
	for side in [-1, 1]:
		var post := Props.lamp()
		post.position = Vector3(side * (HALF_WIDTH - 0.5), 0, FINISH_Z + 0.5)
		arena.add_child(post)
	var line := Art.zone_decal(Ui.GOLD, 0.5, 0.5)
	line.size = Vector3(HALF_WIDTH * 2.0 + 1.0, 4.0, 0.5)
	line.position = Vector3(0, 0, FINISH_Z + 1.3)
	arena.add_child(line)


func tick(delta: float) -> void:
	var width := (SWEPT_X + 2.0) * 2.0
	for lane in lanes:
		for l in lane.logs:
			var body: AnimatableBody3D = l.body
			var p := body.global_position
			p.x += lane.speed * delta
			# Wrap around once well out of the river (no one can ride that far).
			if p.x > SWEPT_X + 2.0 + l.length * 0.5:
				p.x -= width + l.length
			elif p.x < -SWEPT_X - 2.0 - l.length * 0.5:
				p.x += width + l.length
			body.global_position = p
	for ch in chars:
		if not ch.alive or arrived.has(ch.slot):
			continue
		var z := ch.global_position.z
		var dir: int = heading[ch.slot]
		var from_bank := START_Z if dir < 0 else FINISH_Z
		progress[ch.slot] = maxi(progress[ch.slot], crossings[ch.slot] * 12 + int(absf(z - from_bank)))
		if absf(ch.global_position.x) > SWEPT_X and ch.global_position.y < 0.6:
			Fx.splash(arena, Vector3(ch.global_position.x, Arena.WATER_Y, z))
			Sfx.play_varied("splash")
			ch.eliminate()
		elif ch.is_on_floor() and ((dir < 0 and z < FINISH_Z + 1.4) or (dir > 0 and z > START_Z - 1.4)):
			crossings[ch.slot] += 1
			heading[ch.slot] = -dir
			mem(ch).erase("target_z")
			if crossings[ch.slot] >= CROSSINGS:
				_finish(ch)
			else:
				Sfx.play("point")
				Fx.popup(arena, ch.global_position + Vector3.UP * 2.0, "%d / %d" % [crossings[ch.slot], CROSSINGS], Ui.GOLD, 44)
	if arrived.size() >= mini(3, players.size()) or arrived.size() == players.size():
		finish()


func _finish(ch: PlayerCharacter) -> void:
	arrived.append(ch.slot)
	ch.frozen = true
	ch.cheering = true
	var place := arrived.size()
	Sfx.play("win" if place == 1 else "point")
	Fx.confetti(arena, ch.global_position + Vector3.UP, [ch.slot.color, Ui.GOLD])
	Fx.popup(arena, ch.global_position + Vector3.UP * 2.0, ["1ST!", "2ND!", "3RD!"][mini(place - 1, 2)], Ui.GOLD, 56)


func on_out(ch: PlayerCharacter) -> void:
	# Swim back to the start.
	await get_tree().create_timer(1.0, false, true).timeout
	if ended or not is_instance_valid(ch):
		return
	var dir: int = heading[ch.slot]
	var bank := START_Z - 0.3 if dir < 0 else FINISH_Z + 0.3
	ch.revive_at(Vector3(rng.randf_range(-5.0, 5.0), 3.0, bank))
	ch.invulnerable = 1.0
	ch.facing = Vector3(0, 0, dir)
	mem(ch).erase("target_z")


func rank() -> Array:
	var out := []
	for slot in arrived:
		out.append([slot])
	var rest := players.filter(func(p): return not arrived.has(p))
	# Unfinished players ranked by how far they got, in whole rows.
	out.append_array(Game.group_by_score(rest, progress))
	return out


func status_text(slot: PlayerSlot) -> String:
	var i := arrived.find(slot)
	if i >= 0:
		return ["1ST", "2ND", "3RD"][mini(i, 2)]
	var ch := char_of(slot)
	if ch and not ch.alive:
		return "SWIM"
	return "%d/%d" % [crossings.get(slot, 0), CROSSINGS]


## Is there log under (x, lane z) now and still in `ahead` seconds?
func _log_at(z: int, x: float, ahead: float, margin := 0.5) -> bool:
	for lane in lanes:
		if lane.z != z:
			continue
		for l in lane.logs:
			var cx: float = l.body.global_position.x + lane.speed * ahead
			if absf(x - cx) < l.length * 0.5 - margin:
				return true
	return false


func _land_row(z: int) -> bool:
	return z in [START_Z, START_Z - 1, 1, 0, FINISH_Z, FINISH_Z + 1]


## CPUs step one row at a time, only when the next row is land or a log will be there,
## and walk against the current so their log doesn't carry them off.
func bot_input(ch: PlayerCharacter) -> Dictionary:
	var pos := ch.global_position
	var m := mem(ch)
	var dir: int = heading[ch.slot]
	m.think -= get_physics_process_delta_time()
	var move := Vector2.ZERO
	if m.has("target_z") and absf(pos.z - m.target_z) > 0.12:
		move.y = signf(m.target_z - pos.z)
	else:
		var row := roundi(pos.z)
		var next := row + dir
		var sloppy := 0.2 * (1.0 - ch.slot.skill)
		var can_go := _land_row(next) or _log_at(next, pos.x, 0.3, 0.45 - sloppy)
		if can_go and m.think <= 0.0:
			m.think = lerpf(0.4, 0.06, ch.slot.skill) * rng.randf_range(0.6, 1.4)
			m.target_z = float(next)
			move.y = dir
	# Sideways: keep away from the river's edges, and on land line up with the next log.
	var target_x := clampf(pos.x, -4.5, 4.5)
	var row_now := roundi(pos.z)
	if _land_row(row_now) and not _land_row(row_now + dir):
		for lane in lanes:
			if lane.z == row_now + dir:
				var best := INF
				for l in lane.logs:
					var arrive: float = l.body.global_position.x + lane.speed * 0.5
					if absf(arrive) < 5.0 and absf(arrive - pos.x) < absf(best - pos.x):
						best = arrive
				if best != INF:
					target_x = best
	elif not _land_row(row_now):
		for lane in lanes:
			if lane.z == row_now:
				target_x -= lane.speed * 0.25
	if absf(target_x - pos.x) > 0.25:
		move.x = clampf((target_x - pos.x) * 0.8, -0.9, 0.9)
	return {"move": move.limit_length(1.0), "action": false, "hold": false}

extends Minigame
## Hot potato: the lantern is about to burst. Tag someone to pass it on!

const PASS_COOLDOWN := 0.5

var holder: PlayerCharacter
var fuse := 0.0
var fuse_total := 1.0
var _pass_cd := 0.0
var _gap := 0.0
var _lantern: Node3D
var _glow: MeshInstance3D
var _light: OmniLight3D
var _tick_t := 0.0
var radius := 4.5


func _init() -> void:
	title = "Hot Lantern"
	tagline = "Don't be holding it when it bursts!"
	rules = [
		"One player carries a fizzing lantern.",
		"Touch someone to hand it over. You can't pass it straight back.",
		"When it bursts, its holder is out. Last one standing wins.",
	]
	action_name = "Dash"
	accent = Color("ff9a4a")
	time_limit = 0.0
	last_standing = true
	bump_power = 3.5


func build() -> void:
	radius = 3.8 + 0.25 * players.size()
	arena.build(Arena.disc(radius))
	arena.setup_view(Vector3.ZERO, 17.0 + radius)
	arena.decorate(rng.randi(), radius)
	spawn_characters(arena.spawn_ring(players.size(), radius * 0.6))
	_lantern = Node3D.new()
	_glow = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.5, 0.6, 0.5)
	_glow.mesh = box
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("ff7a3a")
	m.emission_enabled = true
	m.emission = Color("ff9a4a")
	m.emission_energy_multiplier = 2.0
	_glow.material_override = m
	_lantern.add_child(_glow)
	var cap := MeshInstance3D.new()
	var cap_box := BoxMesh.new()
	cap_box.size = Vector3(0.6, 0.1, 0.6)
	cap.mesh = cap_box
	cap.material_override = Art.color_material(Color("3a3440"))
	cap.position.y = 0.35
	_lantern.add_child(cap)
	_light = OmniLight3D.new()
	_light.light_color = Color("ff9a4a")
	_light.omni_range = 4.0
	_lantern.add_child(_light)
	_lantern.visible = false
	arena.add_child(_lantern)


func on_begin() -> void:
	_new_fuse()


func _new_fuse() -> void:
	var alive := alive_chars()
	if alive.size() < 2:
		return
	fuse_total = rng.randf_range(6.0, 11.0) if alive.size() > 3 else rng.randf_range(5.0, 8.0)
	fuse = fuse_total
	_give(alive[rng.randi() % alive.size()])
	_lantern.visible = true


func _give(ch: PlayerCharacter) -> void:
	if holder:
		holder.speed = 5.2
	holder = ch
	holder.speed = 5.9
	_pass_cd = PASS_COOLDOWN
	Sfx.play("blip", 1.6)
	Fx.burst(arena, ch.global_position + Vector3.UP * 1.3, Color("ffb36b"), 12, 3.0)


func tick(delta: float) -> void:
	if holder == null or not holder.alive:
		_lantern.visible = false
		if _gap > 0.0:
			_gap -= delta
			if _gap <= 0.0:
				_new_fuse()
		return
	_pass_cd -= delta
	fuse -= delta
	var urgency := 1.0 - fuse / fuse_total
	_lantern.global_position = holder.carry_anchor.global_position + Vector3(0, 0.1 + sin(elapsed * 20.0) * 0.03 * urgency, 0)
	var pulse := 0.5 + 0.5 * sin(elapsed * lerpf(6.0, 40.0, urgency))
	_glow.material_override.emission_energy_multiplier = 1.5 + pulse * 3.0 * urgency
	_glow.scale = Vector3.ONE * (1.0 + pulse * 0.25 * urgency)
	_light.light_energy = 1.0 + pulse * 2.0
	_tick_t -= delta
	if _tick_t <= 0.0:
		_tick_t = lerpf(0.6, 0.12, urgency)
		Sfx.play("tick", 1.0 + urgency * 0.5, -4.0)
	if fuse <= 0.0:
		_burst()


func _burst() -> void:
	var pos := holder.global_position
	Fx.explosion(arena, pos + Vector3.UP * 1.0)
	Sfx.play("boom")
	arena.shake(1.0)
	for ch in alive_chars():
		if ch == holder:
			continue
		var d := ch.global_position - pos
		d.y = 0.0
		if d.length() < 2.5:
			ch.hit(d.normalized() * (10.0 - d.length() * 2.0), 0.3)
	var victim := holder
	holder.speed = 5.2
	holder = null
	_lantern.visible = false
	victim.eliminate()
	_gap = 1.5


func on_out(ch: PlayerCharacter) -> void:
	if ch == holder:
		# Fell in the sea while holding it: the lantern fizzles out, a new one lights.
		holder.speed = 5.2
		holder = null
		_lantern.visible = false
		_gap = 1.0


func on_touch(a: PlayerCharacter, b: PlayerCharacter) -> void:
	if holder == null or _pass_cd > 0.0:
		return
	if a == holder:
		_give(b)
	elif b == holder:
		_give(a)


func status_text(slot: PlayerSlot) -> String:
	var ch := char_of(slot)
	if ch == null or not ch.alive:
		return "OUT"
	return "HOT!" if ch == holder else ""


func bot_input(ch: PlayerCharacter) -> Dictionary:
	if holder == null:
		return {"move": bot_wander(ch) * 0.5, "action": false, "hold": false}
	if ch == holder:
		var target := nearest(ch)
		if target == null:
			return {"move": Vector2.ZERO, "action": false, "hold": false}
		var dash := bot_lined_up(ch, target.global_position, 2.2) and bot_roll(ch, 5.0)
		return {"move": bot_go(ch, target.global_position), "action": dash, "hold": false}
	# Run away from the holder, sliding sideways along the coast instead of into the sea.
	var away := ch.global_position - holder.global_position
	away.y = 0.0
	var dist := away.length()
	var m := mem(ch)
	if not m.has("side"):
		m.side = 1.0 if rng.randf() < 0.5 else -1.0
	var dir: Vector3 = away.normalized() + away.normalized().cross(Vector3.UP) * m.side * 0.8
	if dist > 4.0:
		return {"move": bot_wander(ch) * 0.6, "action": false, "hold": false}
	var move := bot_steer(ch, dir.normalized(), 1.2)
	var dash := dist < 1.6 and bot_roll(ch, 3.0)
	return {"move": move, "action": dash, "hold": false}

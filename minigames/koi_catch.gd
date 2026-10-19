extends Minigame
## Reaction duel: wait for the koi to bite, then be the first to strike.
## Pressing too early locks you out of that cast.

const CASTS := 5
const BITE_WINDOW := 2.0
const POND_RADIUS := 2.4

enum Phase { WAIT, BITE, PAUSE }

var catches := {}
var cast_no := 0
var phase := Phase.PAUSE
var _t := 1.0
var _fake_at := -1.0
var _locked := {}
var _bot_react := {}
var _fish: Sprite3D
var _fish_angle := 0.0
var _alert: Sprite3D


func _init() -> void:
	title = "Koi Catch"
	tagline = "Strike the moment the koi bites!"
	rules = [
		"Wait for the big '!' and the splash, then press action first.",
		"Press too early and you're out for that cast. Beware fake ripples!",
		"Most koi after %d casts wins." % CASTS,
	]
	action_name = "Strike"
	accent = Color("ff9a5a")
	time_limit = 0.0
	bumps_enabled = false


func build() -> void:
	var cells := Arena.disc(5.2)
	for c in Arena.disc(POND_RADIUS):
		cells.erase(c)
	arena.build(cells)
	arena.setup_view(Vector3.ZERO, 20.0)
	arena.decorate(rng.randi(), 5.2)
	var points: Array[Vector3] = []
	var n := players.size()
	for i in n:
		var a := TAU * i / n + PI * 0.5
		points.append(Vector3(cos(a), 0.3, sin(a)) * 3.7)
	spawn_characters(points)
	for ch in chars:
		var to_pond := -ch.global_position
		to_pond.y = 0.0
		ch.facing = to_pond.normalized()
		_add_rod(ch)
		catches[ch.slot] = 0

	_fish = Art.icon_sprite("fish", Color("ff8a3a"), Color.WHITE, 0.1)
	_fish.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	_fish.rotation_degrees.x = -90.0
	arena.add_child(_fish)
	_fish.position = Vector3(1.2, Arena.WATER_Y + 0.05, 0)

	_alert = Art.icon_sprite("alert", Color("ff5a4a"), Color.WHITE, 0.16)
	_alert.position = Vector3(0, 2.2, 0)
	_alert.visible = false
	arena.add_child(_alert)


func _add_rod(ch: PlayerCharacter) -> void:
	var rod := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.05, 0.05, 1.5)
	rod.mesh = box
	rod.material_override = Art.color_material(Color("8a5e3a"))
	ch.add_child(rod)
	rod.position = Vector3(0, 0.75, 0) + ch.facing * 0.7
	rod.look_at(ch.global_position + ch.facing * 3.0 + Vector3.UP * 1.6)


func on_begin() -> void:
	for ch in chars:
		ch.frozen = true # Nobody walks; we read the strike button ourselves.
	_t = 0.8


func tick(delta: float) -> void:
	_fish_angle += delta * (0.8 if phase != Phase.BITE else 4.0)
	if phase != Phase.BITE:
		_fish.position = Vector3(cos(_fish_angle) * 1.2, Arena.WATER_Y + 0.05, sin(_fish_angle) * 1.2)
		_fish.rotation.y = -_fish_angle

	var strikers := _strikers()
	match phase:
		Phase.PAUSE:
			_t -= delta
			if _t <= 0.0:
				if cast_no >= CASTS:
					finish()
					return
				_start_cast()
		Phase.WAIT:
			_t -= delta
			for ch in strikers:
				_too_early(ch)
			if _fake_at > 0.0 and _t <= _fake_at:
				_fake_at = -1.0
				Fx.splash(arena, Vector3(rng.randf_range(-1, 1), Arena.WATER_Y, rng.randf_range(-1, 1)))
				Sfx.play("splash", 1.6, -8.0)
				_bot_maybe_fooled()
			if _t <= 0.0:
				_bite()
		Phase.BITE:
			_t += delta
			for ch in strikers:
				_catch(ch)
				return
			if _t > BITE_WINDOW:
				Ui.banner(_hud, "IT GOT AWAY...", Color("b8b0c8"), 56, 0.6)
				_end_cast()


func _start_cast() -> void:
	cast_no += 1
	phase = Phase.WAIT
	_t = rng.randf_range(1.6, 4.5)
	_fake_at = rng.randf_range(0.6, _t - 0.5) if rng.randf() < 0.5 and _t > 1.4 else -1.0
	_locked.clear()
	_bot_react.clear()
	Ui.banner(_hud, "CAST %d / %d" % [cast_no, CASTS], Color.WHITE, 48, 0.5)
	for ch in chars:
		ch.tint = Color.WHITE


func _bite() -> void:
	phase = Phase.BITE
	_t = 0.0
	_alert.visible = true
	_alert.scale = Vector3.ONE * 0.3
	_alert.create_tween().tween_property(_alert, "scale", Vector3.ONE, 0.12).set_trans(Tween.TRANS_BACK)
	Fx.splash(arena, Vector3(_fish.position.x, Arena.WATER_Y, _fish.position.z))
	Sfx.play("whistle", 1.3)
	for ch in chars:
		if ch.slot.is_bot and not _locked.has(ch):
			var skill := ch.slot.skill
			_bot_react[ch] = lerpf(0.55, 0.2, skill) + rng.randf_range(0.0, 0.18)


func _catch(ch: PlayerCharacter) -> void:
	catches[ch.slot] += 1
	Sfx.play("win")
	Fx.popup(arena, ch.global_position + Vector3.UP * 1.8, "CATCH!", Ui.GOLD, 56)
	Fx.burst(arena, ch.global_position + Vector3.UP * 1.0, Color("ff9a5a"), 20, 4.0)
	ch.velocity.y = 6.0
	# The koi leaps to the winner.
	var tw := _fish.create_tween()
	tw.tween_property(_fish, "position", ch.global_position + Vector3.UP * 1.4, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(_fish, "position", Vector3(0, Arena.WATER_Y + 0.05, 0), 0.01).set_delay(0.6)
	_end_cast()


func _end_cast() -> void:
	phase = Phase.PAUSE
	_t = 1.6
	_alert.visible = false


func _too_early(ch: PlayerCharacter) -> void:
	if _locked.has(ch):
		return
	_locked[ch] = true
	Sfx.play("fault")
	Fx.popup(arena, ch.global_position + Vector3.UP * 1.8, "TOO EARLY!", Color("ff6a5a"), 40)
	ch.tint = Color(0.45, 0.45, 0.55)


## Players who pressed strike this tick and aren't locked out.
func _strikers() -> Array[PlayerCharacter]:
	var out: Array[PlayerCharacter] = []
	var order := chars.duplicate()
	order.shuffle()
	for ch in order:
		if _locked.has(ch):
			continue
		if ch.slot.is_bot:
			if phase == Phase.BITE and _bot_react.has(ch) and _t >= _bot_react[ch]:
				out.append(ch)
			elif phase == Phase.WAIT and rng.randf() < 0.002 * (1.0 - ch.slot.skill):
				out.append(ch)
		elif Controls.just_pressed(ch.slot.device, "action"):
			out.append(ch)
	return out


func _bot_maybe_fooled() -> void:
	for ch in chars:
		if ch.slot.is_bot and rng.randf() < 0.35 * (1.0 - ch.slot.skill):
			_too_early(ch)


func rank() -> Array:
	return score_ranking(catches)


func status_text(slot: PlayerSlot) -> String:
	return str(catches.get(slot, 0))

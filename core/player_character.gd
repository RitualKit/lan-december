class_name PlayerCharacter
extends CharacterBody3D
## A pixel-sprite character in the 3D world. Input comes from `input_provider`, a
## Callable returning {"move": Vector2, "action": bool (just pressed), "hold": bool,
## "item": bool (just pressed)}.

signal fell(ch: PlayerCharacter)
signal dashed(ch: PlayerCharacter)
## Action pressed in a game where it neither dashes nor hops (e.g. throwing).
signal acted(ch: PlayerCharacter)

const GRAVITY := 28.0
const FALL_LIMIT := -1.4

var slot: PlayerSlot
var input_provider: Callable

var speed := 5.2
var accel := 45.0
var can_dash := true
var dash_speed := 15.0
var dash_duration := 0.16
var dash_cooldown := 0.9
var can_jump := false
var jump_velocity := 8.5
var frozen := true ## No control (before GO, after finish).
var alive := true
var invulnerable := 0.0
var tint := Color.WHITE ## Base sprite colour; flashes are applied on top.
var cheering := false ## Arms-up pose (wins, catches).
## Timed effects: "speed", "shield", "giant", "frozen", "seated" (can't be knocked) -> seconds left.
var status := {}

var facing := Vector3(0, 0, 1)
var knock := Vector3.ZERO
var stun := 0.0
var _dash_left := 0.0
var _dash_cd := 0.0
var _anim_t := 0.0
var _dir := 0
var _flash := 0.0
var _item_icon: Sprite3D
var _bubble: MeshInstance3D
var _ice: MeshInstance3D

var sprite: Sprite3D
var marker: GroundMark
var label: Label3D
var carry_anchor: Node3D


func _init(p_slot: PlayerSlot) -> void:
	slot = p_slot
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 0.25
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 0.9
	shape.shape = capsule
	shape.position.y = 0.45
	add_child(shape)

	sprite = Sprite3D.new()
	sprite.texture = Art.character_texture(slot.character)
	sprite.hframes = 4
	sprite.vframes = 7
	sprite.pixel_size = Art.PIXEL_SIZE
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.layers = 2
	sprite.shaded = false
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.offset = Vector2(0, 8)
	sprite.position.y = 0.02
	add_child(sprite)

	marker = GroundMark.new(Art.marker_texture(slot.color), Vector3(1.1, 2.5, 1.1))
	marker.position.y = -0.2 if GroundMark.use_decals else 0.0
	add_child(marker)

	label = Label3D.new()
	label.text = slot.display_name
	label.font = Art.font(true)
	label.font_size = 40
	label.outline_size = 12
	label.modulate = slot.color.lightened(0.25)
	label.outline_modulate = Art.OUTLINE
	label.pixel_size = 0.0075
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.layers = 2
	label.position.y = 1.4
	add_child(label)

	_item_icon = Sprite3D.new()
	_item_icon.pixel_size = 0.035
	_item_icon.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_item_icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_item_icon.shaded = false
	_item_icon.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	_item_icon.no_depth_test = true
	_item_icon.layers = 2
	_item_icon.position.y = 1.95
	_item_icon.visible = false
	add_child(_item_icon)

	carry_anchor = Node3D.new()
	carry_anchor.position.y = 1.35
	add_child(carry_anchor)


func _physics_process(delta: float) -> void:
	if not alive:
		return
	_tick_status(delta)
	var inp := _read_input()
	var move := Vector3(inp.move.x, 0, inp.move.y)
	if stun > 0.0 or has_status("frozen"):
		stun = maxf(0.0, stun - delta)
		move = Vector3.ZERO
		inp.action = false
	if move.length() > 0.1:
		facing = move.normalized()

	_dash_cd = maxf(0.0, _dash_cd - delta)
	invulnerable = maxf(0.0, invulnerable - delta)
	if inp.action and stun <= 0.0:
		if can_dash and _dash_cd <= 0.0:
			_dash_left = dash_duration
			_dash_cd = dash_cooldown
			Sfx.play_varied("dash", 0.15, -6.0)
			dashed.emit(self)
		elif can_jump and is_on_floor():
			velocity.y = jump_velocity
			Sfx.play_varied("jump", 0.1, -4.0)
		elif not can_dash and not can_jump:
			acted.emit(self)

	var target := move * speed * (1.45 if has_status("speed") else 1.0)
	if _dash_left > 0.0:
		_dash_left -= delta
		target = facing * dash_speed
		velocity.x = target.x
		velocity.z = target.z
	else:
		var control := 1.0 / (1.0 + knock.length() * 0.6)
		velocity.x = move_toward(velocity.x, target.x, accel * control * delta)
		velocity.z = move_toward(velocity.z, target.z, accel * control * delta)

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	var base_velocity := velocity
	velocity += knock
	move_and_slide()
	velocity = Vector3(base_velocity.x, velocity.y, base_velocity.z)
	knock = knock.move_toward(Vector3.ZERO, 22.0 * delta)

	if global_position.y < FALL_LIMIT:
		_drown()
	_animate(delta, move)


func _read_input() -> Dictionary:
	if frozen or not input_provider.is_valid():
		return {"move": Vector2.ZERO, "action": false, "hold": false, "item": false}
	return input_provider.call(self)


# --- Power-up effects -------------------------------------------------------------

func add_status(status_name: String, seconds: float) -> void:
	status[status_name] = maxf(status.get(status_name, 0.0), seconds)
	_update_status_visuals()


func has_status(status_name: String) -> bool:
	return status.get(status_name, 0.0) > 0.0


func clear_status() -> void:
	status.clear()
	_update_status_visuals()


## Multiplier on knockback this character receives.
func knock_taken() -> float:
	return 0.35 if has_status("giant") else 1.0


## Multiplier on knockback this character deals.
func knock_dealt() -> float:
	return 1.8 if has_status("giant") else 1.0


func size_scale() -> float:
	return 1.6 if has_status("giant") else 1.0


func show_item(icon: Texture2D) -> void:
	_item_icon.texture = icon
	_item_icon.visible = icon != null


func _tick_status(delta: float) -> void:
	if status.is_empty():
		return
	var changed := false
	for k in status.keys():
		status[k] -= delta
		if status[k] <= 0.0:
			status.erase(k)
			changed = true
	if changed:
		_update_status_visuals()
	if _item_icon.visible:
		_item_icon.position.y = 1.95 + sin(Time.get_ticks_msec() * 0.006) * 0.05


func _update_status_visuals() -> void:
	var giant := has_status("giant")
	var s := size_scale()
	sprite.pixel_size = Art.PIXEL_SIZE * s
	marker.size = Vector3(1.1 * s, 2.5, 1.1 * s)
	label.position.y = 1.4 * (1.45 if giant else 1.0)
	_item_icon.position.y = label.position.y + 0.55
	if has_status("shield") and _bubble == null:
		_bubble = MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.65
		sphere.height = 1.3
		sphere.radial_segments = 12
		sphere.rings = 6
		_bubble.mesh = sphere
		_bubble.material_override = Art.color_material(Color(1.0, 0.9, 0.4, 0.3), 1.2)
		_bubble.position.y = 0.55
		add_child(_bubble)
	elif not has_status("shield") and _bubble:
		_bubble.queue_free()
		_bubble = null
	if has_status("frozen") and _ice == null:
		_ice = MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.9, 1.1, 0.9)
		_ice.mesh = box
		_ice.material_override = Art.color_material(Color(0.6, 0.9, 1.0, 0.45), 0.6)
		_ice.position.y = 0.55
		add_child(_ice)
	elif not has_status("frozen") and _ice:
		_ice.queue_free()
		_ice = null


func is_dashing() -> bool:
	return _dash_left > 0.0


func end_dash() -> void:
	_dash_left = 0.0


func reset_dash_cooldown() -> void:
	_dash_cd = 0.0


## Knock the character with a horizontal impulse. Returns false if it was blocked.
func hit(impulse: Vector3, stun_time := 0.2) -> bool:
	if not alive or invulnerable > 0.0:
		return false
	if has_status("shield") or has_status("seated"):
		_flash = 0.1
		return false
	impulse.y = 0
	knock += impulse * knock_taken()
	velocity.y = maxf(velocity.y, 2.5)
	stun = maxf(stun, stun_time)
	_dash_left = 0.0
	_flash = 0.15
	return true


## Take the character out of play (fell, exploded, squashed...).
func eliminate() -> void:
	if not alive:
		return
	alive = false
	visible = false
	clear_status()
	process_mode = Node.PROCESS_MODE_DISABLED
	fell.emit(self)


func revive_at(pos: Vector3) -> void:
	global_position = pos
	velocity = Vector3.ZERO
	knock = Vector3.ZERO
	alive = true
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT


func _drown() -> void:
	Fx.splash(get_parent(), Vector3(global_position.x, -1.0, global_position.z))
	Sfx.play_varied("splash")
	eliminate()


func _animate(delta: float, move: Vector3) -> void:
	# Sheet columns: 0 down, 1 up, 2 left, 3 right.
	if absf(facing.x) > absf(facing.z) * 1.2:
		_dir = 2 if facing.x < 0 else 3
	elif move.length() > 0.1 or _dir < 2:
		_dir = 1 if facing.z < 0 else 0
	var row := 0
	var col := _dir
	var moving := Vector2(velocity.x, velocity.z).length() > 0.5 and is_on_floor()
	if cheering:
		row = 6
		col = 1
	elif stun > 0.0 or has_status("frozen"):
		row = 6
		col = 0
	elif _dash_left > 0.0:
		row = 4
	elif not is_on_floor():
		row = 5
	elif moving:
		_anim_t += delta * 9.0
		row = int(_anim_t) % 4
	else:
		_anim_t = 0.0
	sprite.frame = row * 4 + col

	var squash := Vector3.ONE
	if _dash_left > 0.0:
		squash = Vector3(1.25, 0.8, 1.0)
	elif not is_on_floor():
		squash = Vector3(0.9, 1.1, 1.0)
	sprite.scale = sprite.scale.lerp(squash, minf(1.0, delta * 18.0))
	_flash = maxf(0.0, _flash - delta)
	var c := tint
	if has_status("frozen"):
		c = Color(0.6, 0.85, 1.2)
	if _flash > 0.0:
		c = Color(3, 3, 3)
	elif invulnerable > 0.0 and int(invulnerable * 12.0) % 2 == 0:
		c = Color(tint, 0.4)
	sprite.modulate = c

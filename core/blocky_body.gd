class_name BlockyBody
extends Node3D
## A chunky 3D character built from boxes with pixel textures, to match the tile islands:
## cube head with a pixel face, a body in the player's colour, swinging arms and legs,
## and a hat. Used instead of the sprite when Game.look_3d is on.

const SKINS: Array[Color] = [Color("f2c29b"), Color("d99a76"), Color("a8704e"), Color("7a4e34"), Color("ffe0c4")]
const HAIRS: Array[Color] = [Color("5a3a22"), Color("e0803a"), Color("2b2033"), Color("e8c860"), Color("b04a3a"), Color("8a8aa0"), Color("f4a6c8")]
const PANTS: Array[Color] = [Color("3b4a7a"), Color("4a3a2a"), Color("3a5a3a"), Color("5a4a6a")]
const SCALE := 1.25
const HATS: Array[String] = ["cap", "beanie", "straw", "none", "bandana", "crown", "bow", "pot"]

static var _tex := {}

var look := {}
var color := Color.WHITE
var _head: Node3D
var _body: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _meshes_list: Array[MeshInstance3D] = []
var _walk := 0.0
var _yaw := 0.0


## A stable look for character index `i` (the same index the sprite sheets use).
static func look_for(i: int) -> Dictionary:
	return {
		"skin": SKINS[i % SKINS.size()],
		"hair": HAIRS[(i * 3 + 1) % HAIRS.size()],
		"hat": HATS[(i * 5 + 2) % HATS.size()],
		"pants": PANTS[(i * 7) % PANTS.size()],
		"long_hair": i % 3 == 1,
	}


func setup(p_look: Dictionary, p_color: Color) -> void:
	look = p_look
	color = p_color
	for c in get_children():
		c.queue_free()
	_meshes_list.clear()
	_build()


func _build() -> void:
	var skin: Color = look.skin
	var shirt := color
	var key := "%s:%s:%s:%s" % [skin.to_html(), (look.hair as Color).to_html(), shirt.to_html(), look.long_hair]

	_leg_l = _limb(Vector3(-0.1, 0.3, 0), Vector3(0.15, 0.3, 0.17), _faces("leg:" + (look.pants as Color).to_html(), _leg_tex.bind(look.pants)))
	_leg_r = _limb(Vector3(0.1, 0.3, 0), Vector3(0.15, 0.3, 0.17), _faces("leg:" + (look.pants as Color).to_html(), _leg_tex.bind(look.pants)))
	_body = Node3D.new()
	add_child(_body)
	_body.position.y = 0.3
	_add_box(_body, Vector3(0, 0.17, 0), Vector3(0.42, 0.34, 0.26), _faces("body:" + shirt.to_html(), _body_tex.bind(shirt)))
	_arm_l = _limb(Vector3(-0.28, 0.32, 0), Vector3(0.12, 0.3, 0.14), _faces("arm:" + shirt.to_html() + skin.to_html(), _arm_tex.bind(shirt, skin)), _body)
	_arm_r = _limb(Vector3(0.28, 0.32, 0), Vector3(0.12, 0.3, 0.14), _faces("arm:" + shirt.to_html() + skin.to_html(), _arm_tex.bind(shirt, skin)), _body)
	_head = Node3D.new()
	_body.add_child(_head)
	_head.position.y = 0.34
	var head_faces := {
		"front": _tex_named("face:" + key, _face_tex.bind(skin, look.hair, false)),
		"back": _tex_named("hairback:" + key, _face_tex.bind(skin, look.hair, true)),
		"left": _tex_named("side:" + key, _side_tex.bind(skin, look.hair, look.long_hair)),
		"right": _tex_named("side:" + key, _side_tex.bind(skin, look.hair, look.long_hair)),
		"top": _tex_named("hairtop:" + (look.hair as Color).to_html(), _fill_tex.bind(look.hair, 0.12)),
		"bottom": _tex_named("skin:" + skin.to_html(), _fill_tex.bind(skin, 0.05)),
	}
	_add_box(_head, Vector3(0, 0.22, 0), Vector3(0.48, 0.44, 0.44), head_faces)
	_add_hat(look.hat, shirt)


func _limb(pivot: Vector3, size: Vector3, faces: Dictionary, parent: Node3D = null) -> Node3D:
	var joint := Node3D.new()
	joint.position = pivot
	(parent if parent else self).add_child(joint)
	_add_box(joint, Vector3(0, -size.y * 0.5, 0), size, faces)
	return joint


func _add_box(parent: Node3D, center: Vector3, size: Vector3, faces: Dictionary) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = Art.box_mesh(size, faces)
	m.position = center
	parent.add_child(m)
	_meshes_list.append(m)
	return m


func _add_hat(hat: String, shirt: Color) -> void:
	var hat_color := shirt.darkened(0.1)
	var t := _tex_named("hat:" + hat_color.to_html(), _fill_tex.bind(hat_color, 0.12))
	var faces := {"front": t, "back": t, "left": t, "right": t, "top": t, "bottom": t}
	match hat:
		"cap":
			_add_box(_head, Vector3(0, 0.47, -0.01), Vector3(0.5, 0.1, 0.46), faces)
			_add_box(_head, Vector3(0, 0.44, 0.3), Vector3(0.44, 0.04, 0.2), faces)
		"beanie":
			_add_box(_head, Vector3(0, 0.48, 0), Vector3(0.52, 0.14, 0.48), faces)
			var pom := _tex_named("hat:ffffff", _fill_tex.bind(Color.WHITE, 0.08))
			_add_box(_head, Vector3(0, 0.6, 0), Vector3(0.12, 0.1, 0.12), {"front": pom, "back": pom, "left": pom, "right": pom, "top": pom, "bottom": pom})
		"straw":
			var straw := _tex_named("straw", _fill_tex.bind(Color("e8c870"), 0.15))
			var sf := {"front": straw, "back": straw, "left": straw, "right": straw, "top": straw, "bottom": straw}
			_add_box(_head, Vector3(0, 0.45, 0), Vector3(0.66, 0.04, 0.64), sf)
			_add_box(_head, Vector3(0, 0.52, 0), Vector3(0.42, 0.12, 0.4), sf)
			_add_box(_head, Vector3(0, 0.47, 0), Vector3(0.44, 0.04, 0.42), faces)
		"bandana":
			_add_box(_head, Vector3(0, 0.36, 0), Vector3(0.5, 0.08, 0.46), faces)
			_add_box(_head, Vector3(0, 0.32, -0.26), Vector3(0.12, 0.14, 0.06), faces)
		"crown":
			var gold := _tex_named("gold", _fill_tex.bind(Color("ffd45a"), 0.15))
			var gf := {"front": gold, "back": gold, "left": gold, "right": gold, "top": gold, "bottom": gold}
			_add_box(_head, Vector3(0, 0.48, 0), Vector3(0.4, 0.1, 0.36), gf)
			for x in [-0.15, 0.0, 0.15]:
				_add_box(_head, Vector3(x, 0.57, 0.15), Vector3(0.07, 0.08, 0.06), gf)
		"bow":
			_add_box(_head, Vector3(-0.1, 0.48, 0.05), Vector3(0.16, 0.12, 0.08), faces)
			_add_box(_head, Vector3(0.1, 0.48, 0.05), Vector3(0.16, 0.12, 0.08), faces)
			_add_box(_head, Vector3(0, 0.48, 0.05), Vector3(0.06, 0.08, 0.1), faces)
		"pot":
			var pot := _tex_named("pot", _fill_tex.bind(Color("8a8aa0"), 0.15))
			var pf := {"front": pot, "back": pot, "left": pot, "right": pot, "top": pot, "bottom": pot}
			_add_box(_head, Vector3(0, 0.5, 0), Vector3(0.5, 0.16, 0.46), pf)
			_add_box(_head, Vector3(0.36, 0.48, 0), Vector3(0.22, 0.04, 0.06), pf)


func _faces(tex_key: String, maker: Callable) -> Dictionary:
	var t := _tex_named(tex_key, maker)
	return {"front": t, "back": t, "left": t, "right": t, "top": t, "bottom": t}


func _tex_named(key: String, maker: Callable) -> Texture2D:
	if not _tex.has(key):
		_tex[key] = ImageTexture.create_from_image(maker.call())
	return _tex[key]


# --- Pixel textures (8x8 per face; chunkier than the 16px tiles on purpose) -------------

static func _img() -> Image:
	return Image.create_empty(8, 8, false, Image.FORMAT_RGBA8)


static func _fill_tex(c: Color, noise: float) -> Image:
	var img := _img()
	for y in 8:
		for x in 8:
			var n := Art.hash01(x, y, 41) - 0.5
			img.set_pixel(x, y, c.lightened(n * noise) if n > 0 else c.darkened(-n * noise))
	return img


static func _face_tex(skin: Color, hair: Color, back: bool) -> Image:
	var img := _img()
	var dark := Color("2b2033")
	for y in 8:
		for x in 8:
			var c := skin
			if back or y < 2 or (y == 2 and (x < 2 or x > 5)):
				c = hair if (x + y) % 5 != 0 else hair.lightened(0.12)
			img.set_pixel(x, y, c)
	if not back:
		for p in [Vector2i(2, 4), Vector2i(5, 4), Vector2i(2, 3), Vector2i(5, 3)]:
			img.set_pixel(p.x, p.y, dark)
		img.set_pixel(1, 5, Color("f08a8a"))
		img.set_pixel(6, 5, Color("f08a8a"))
		img.set_pixel(3, 6, skin.darkened(0.35))
		img.set_pixel(4, 6, skin.darkened(0.35))
	return img


static func _side_tex(skin: Color, hair: Color, long_hair: bool) -> Image:
	var img := _img()
	for y in 8:
		for x in 8:
			var c := skin
			if y < 3 or x < 3 or (long_hair and x < 5):
				c = hair if (x + y) % 5 != 0 else hair.lightened(0.12)
			img.set_pixel(x, y, c)
	img.set_pixel(5, 4, skin.darkened(0.2)) # ear
	return img


static func _body_tex(shirt: Color) -> Image:
	var img := _img()
	for y in 8:
		for x in 8:
			var c := shirt
			if y == 0:
				c = shirt.lightened(0.25)
			elif y >= 6:
				c = shirt.darkened(0.22)
			if y == 5:
				c = Color("4a3328")
			img.set_pixel(x, y, c)
	img.set_pixel(3, 5, Color("ffd45a"))
	img.set_pixel(4, 5, Color("ffd45a"))
	return img


static func _arm_tex(shirt: Color, skin: Color) -> Image:
	var img := _img()
	for y in 8:
		for x in 8:
			img.set_pixel(x, y, skin if y >= 6 else (shirt.darkened(0.08) if y >= 4 else shirt))
	return img


static func _leg_tex(pants: Color) -> Image:
	var img := _img()
	for y in 8:
		for x in 8:
			img.set_pixel(x, y, Color("4a3328") if y >= 6 else pants.darkened(0.1 if x % 4 == 0 else 0.0))
	return img


# --- Animation ----------------------------------------------------------------------

## state: {facing: Vector3, moving: bool, on_floor: bool, dashing: bool, stunned: bool, cheering: bool}
func animate(delta: float, state: Dictionary) -> void:
	var facing: Vector3 = state.facing
	if facing.length() > 0.1:
		var target := atan2(facing.x, facing.z)
		_yaw = lerp_angle(_yaw, target, minf(1.0, delta * 14.0))
	rotation.y = _yaw
	var swing := 0.0
	if state.moving:
		_walk += delta * 12.0
		swing = sin(_walk) * 0.7
	else:
		_walk = 0.0
	var arm_l := -swing
	var arm_r := swing
	var leg_l := swing
	var leg_r := -swing
	var lean := 0.0
	var bob := absf(sin(_walk)) * 0.04 if state.moving else 0.0
	var tilt := 0.0
	if state.cheering:
		arm_l = -2.8
		arm_r = -2.8
		bob = absf(sin(Time.get_ticks_msec() * 0.008)) * 0.12
	elif state.stunned:
		tilt = sin(Time.get_ticks_msec() * 0.03) * 0.25
		arm_l = -0.6
		arm_r = -0.6
	elif state.dashing:
		lean = 0.45
		arm_l = 1.2
		arm_r = 1.2
		leg_l = -0.6
		leg_r = 0.6
	elif not state.on_floor:
		arm_l = -2.2
		arm_r = -2.2
		leg_l = 0.4
		leg_r = -0.2
	var k := minf(1.0, delta * 16.0)
	_arm_l.rotation.x = lerpf(_arm_l.rotation.x, arm_l, k)
	_arm_r.rotation.x = lerpf(_arm_r.rotation.x, arm_r, k)
	_leg_l.rotation.x = lerpf(_leg_l.rotation.x, leg_l, k)
	_leg_r.rotation.x = lerpf(_leg_r.rotation.x, leg_r, k)
	_body.rotation.x = lerpf(_body.rotation.x, lean, k)
	_body.rotation.z = lerpf(_body.rotation.z, tilt, k)
	_body.position.y = 0.3 + bob


## Flash, freeze tint or fade: a colour overlay on every part (null clears it).
func set_overlay(mat: Material) -> void:
	for m in _meshes_list:
		if is_instance_valid(m):
			m.material_overlay = mat


func set_fade(alpha: float) -> void:
	for m in _meshes_list:
		if is_instance_valid(m):
			m.transparency = 1.0 - alpha

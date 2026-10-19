extends Node
## Pixel art: character sheets and effects from the Ninja Adventure pack (CC0), plus
## procedural textures, materials and tile meshes for the islands.
##
## Every environment texture can be replaced by an artist: drop a PNG with the same
## name into res://assets/textures/ (e.g. grass.png, 16x16) and it is used instead
## of the generated one.

const PX := 16
const PIXEL_SIZE := 1.0 / 16.0
const OUTLINE := Color("2b2033")

const PLAYER_COLORS: Array[Color] = [
	Color("e8433f"), Color("3f7fe8"), Color("4cc256"), Color("f2c230"),
	Color("a65be0"), Color("f0842c"), Color("35c9c9"), Color("f06aa8"),
]
## Ninja Adventure character sheets (assets/ninja_adventure/characters/<n>.png), in the
## order they are handed out. Each sheet is 4 columns (down, up, left, right) by 7 rows
## (rows 0-3 walk cycle, 4 attack, 5 jump, 6 hurt/cheer) of 16x16 frames.
const CHARACTERS: Array[int] = [6, 19, 1, 20, 24, 22, 16, 23, 14, 15, 25, 9, 11, 5, 10, 13, 17, 21, 12, 18, 3, 7, 2]
const NINJA := "res://assets/ninja_adventure/"

var _tex := {}
var _mat := {}
var _mesh := {}
var _fonts := {}


func texture(tex_name: String) -> Texture2D:
	if _tex.has(tex_name):
		return _tex[tex_name]
	var path := "res://assets/textures/%s.png" % tex_name
	var t: Texture2D
	if ResourceLoader.exists(path):
		t = load(path)
	else:
		t = ImageTexture.create_from_image(generate(tex_name))
	_tex[tex_name] = t
	return t


## Opaque, nearest-filtered material. triplanar > 0 maps the texture in world space
## with that many texture repeats per unit (used for organic props like tree canopies).
func material(tex_name: String, triplanar := 0.0) -> StandardMaterial3D:
	var key := "%s:%s" % [tex_name, triplanar]
	if _mat.has(key):
		return _mat[key]
	var m := StandardMaterial3D.new()
	m.albedo_texture = texture(tex_name)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.roughness = 1.0
	if triplanar > 0.0:
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_scale = Vector3.ONE * triplanar
	_mat[key] = m
	return m


func color_material(c: Color, emission := 0.0) -> StandardMaterial3D:
	var key := "col:%s:%s" % [c.to_html(), emission]
	if _mat.has(key):
		return _mat[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 1.0
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emission
	if c.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat[key] = m
	return m


## Text font. Ligatures are off: they turn "fi" into odd glyphs in pixel fonts.
func font(_bold := true) -> Font:
	return _font("res://assets/fonts/Tiny5-Regular.ttf")


## Chunky all-caps font for titles and banners.
func title_font() -> Font:
	return _font("res://assets/fonts/Silkscreen-Bold.ttf")


func _font(path: String) -> Font:
	if not _fonts.has(path):
		var f := FontVariation.new()
		f.base_font = load(path)
		var ts := TextServerManager.get_primary_interface()
		f.opentype_features = {ts.name_to_tag("liga"): 0, ts.name_to_tag("calt"): 0}
		_fonts[path] = f
	return _fonts[path]


# --- Tile meshes ----------------------------------------------------------------

## A 1x1 column from y=top down to y=bottom: grass top, a cliff band with a grass lip,
## then plain cliff. Shared between all tiles with the same heights.
func tile_mesh(top: float, bottom: float, top_tex := "grass") -> ArrayMesh:
	var key := "%s:%s:%s" % [top, bottom, top_tex]
	if _mesh.has(key):
		return _mesh[key]
	var mesh := ArrayMesh.new()
	var lip_bottom := maxf(top - 1.0, bottom)
	_add_surface(mesh, [_top_quad(top)], material(top_tex))
	_add_surface(mesh, _side_quads(top, lip_bottom, 0.0), material("cliff_top"))
	if lip_bottom > bottom:
		_add_surface(mesh, _side_quads(lip_bottom, bottom, 0.0), material("cliff"))
	_mesh[key] = mesh
	return mesh


func _top_quad(y: float) -> Array:
	return [
		Vector3(-0.5, y, -0.5), Vector3(0.5, y, -0.5), Vector3(0.5, y, 0.5), Vector3(-0.5, y, 0.5),
		Vector3.UP, 1.0,
	]


func _side_quads(top: float, bottom: float, _v0: float) -> Array:
	var h := top - bottom
	var out := []
	# Each entry: top-left, top-right, bottom-right, bottom-left as seen from outside.
	out.append([Vector3(-0.5, top, 0.5), Vector3(0.5, top, 0.5), Vector3(0.5, bottom, 0.5), Vector3(-0.5, bottom, 0.5), Vector3.BACK, h])
	out.append([Vector3(0.5, top, -0.5), Vector3(-0.5, top, -0.5), Vector3(-0.5, bottom, -0.5), Vector3(0.5, bottom, -0.5), Vector3.FORWARD, h])
	out.append([Vector3(0.5, top, 0.5), Vector3(0.5, top, -0.5), Vector3(0.5, bottom, -0.5), Vector3(0.5, bottom, 0.5), Vector3.RIGHT, h])
	out.append([Vector3(-0.5, top, -0.5), Vector3(-0.5, top, 0.5), Vector3(-0.5, bottom, 0.5), Vector3(-0.5, bottom, -0.5), Vector3.LEFT, h])
	return out


func _add_surface(mesh: ArrayMesh, quads: Array, mat: Material) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for q in quads:
		var v: float = q[5]
		var uvs := [Vector2(0, 0), Vector2(1, 0), Vector2(1, v), Vector2(0, v)]
		for i in [0, 1, 2, 0, 2, 3]:
			st.set_normal(q[4])
			st.set_uv(uvs[i])
			st.add_vertex(q[i])
	st.set_material(mat)
	st.commit(mesh)


# --- Characters & pack sprites -------------------------------------------------------

func character_texture(index: int) -> Texture2D:
	var n: int = CHARACTERS[posmod(index, CHARACTERS.size())]
	return load("%scharacters/%d.png" % [NINJA, n])


## A sprite from the Ninja Adventure pack, e.g. pack("items/shuriken").
func pack(path: String) -> Texture2D:
	return load("%s%s.png" % [NINJA, path])


## Billboarded pixel sprite of a pack image. `frames` > 1 splits it into a horizontal strip.
func pack_sprite(path: String, frames := 1, px_size := PIXEL_SIZE) -> Sprite3D:
	var s := Sprite3D.new()
	s.texture = pack(path)
	s.hframes = frames
	s.pixel_size = px_size
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.shaded = false
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.layers = 2
	return s


func _blit(img: Image, rows: Array, pal: Dictionary, ox: int, oy: int) -> void:
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			var ch := row[x]
			if pal.has(ch):
				img.set_pixel(ox + x, oy + y, pal[ch])


const ICONS := {
	"flower": [
		"...oo...", "..oPPo..", ".ooPPoo.", "oPPyyPPo",
		"oPPyyPPo", ".ooPPoo.", "..oPPo..", "...oo...",
	],
	"bomb": [
		".....yy.", "....y...", "...ooo..", "..oPPPo.",
		".oPLPPPo", ".oPPPPPo", ".oPPPPPo", "..oPPPo.", "...ooo..",
	],
	"fish": [
		"..oooo.....", ".oPPPPo..oo", "oPePPPPooPo", "oPPPPPPPPPo",
		".oLLLLo.oPo", "..oooo...oo",
	],
	"alert": ["oo", "Po", "Po", "Po", "oo", "..", "oo", "Po", "oo"],
}


## Small pixel icon for pickups. P = main colour, L = light, y = accent.
func icon(icon_name: String, main: Color, accent := Color("ffe066")) -> Texture2D:
	var key := "icon:%s:%s:%s" % [icon_name, main.to_html(), accent.to_html()]
	if _tex.has(key):
		return _tex[key]
	var rows: Array = ICONS[icon_name]
	var w: int = rows[0].length()
	var img := Image.create_empty(w, rows.size(), false, Image.FORMAT_RGBA8)
	var pal := {"o": main.darkened(0.55), "P": main, "L": main.lightened(0.45), "y": accent, "e": OUTLINE}
	_blit(img, rows, pal, 0, 0)
	var t := ImageTexture.create_from_image(img)
	_tex[key] = t
	return t


## Billboarded sprite of an icon, `px_size` world units per pixel.
func icon_sprite(icon_name: String, main: Color, accent := Color("ffe066"), px_size := 0.07) -> Sprite3D:
	var s := Sprite3D.new()
	s.texture = icon(icon_name, main, accent)
	s.pixel_size = px_size
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.shaded = false
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.layers = 2
	return s


## Ring in the player's colour around a soft dark blob; shown under the feet.
func marker_texture(color: Color) -> Texture2D:
	var key := "marker:%s" % color.to_html()
	if _tex.has(key):
		return _tex[key]
	var img := Image.create_empty(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var d := Vector2(x - 15.5, y - 15.5).length()
			if d >= 12.5 and d < 15.0:
				img.set_pixel(x, y, Color(color, 0.95))
			elif d < 10.0:
				img.set_pixel(x, y, Color(0, 0, 0, 0.45))
	var t := ImageTexture.create_from_image(img)
	_tex[key] = t
	return t


## Pixel circle for zones and warnings: solid rim plus a translucent fill.
func zone_texture(color: Color, fill_alpha := 0.3) -> Texture2D:
	var key := "zone:%s:%s" % [color.to_html(), fill_alpha]
	if _tex.has(key):
		return _tex[key]
	var img := Image.create_empty(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var d := Vector2(x - 15.5, y - 15.5).length()
			if d >= 13.5 and d < 16.0:
				img.set_pixel(x, y, Color(color, 1.0))
			elif d < 13.5:
				var stripe := ((x + y) / 3) % 2 == 0
				img.set_pixel(x, y, Color(color, fill_alpha * (1.3 if stripe else 0.8)))
	var t := ImageTexture.create_from_image(img)
	_tex[key] = t
	return t


func zone_decal(color: Color, radius: float, fill_alpha := 0.3) -> GroundMark:
	return GroundMark.new(zone_texture(color, fill_alpha), Vector3(radius * 2.0, 4.0, radius * 2.0), 0.6)


# --- Procedural textures ------------------------------------------------------------

static func hash01(x: int, y: int, s: int) -> float:
	var n := (x * 374761393 + y * 668265263 + s * 982451653) & 0x7fffffff
	n = ((n ^ (n >> 13)) * 1274126177) & 0x7fffffff
	n = n ^ (n >> 16)
	return float(n & 0xffff) / 65535.0


## Tileable value noise over a 16px period with the given cell size.
static func vnoise(x: int, y: int, cell: int, s: int) -> float:
	var p := PX / cell
	var cx := x / cell
	var cy := y / cell
	var fx := float(x % cell) / cell
	var fy := float(y % cell) / cell
	var a := hash01(cx % p, cy % p, s)
	var b := hash01((cx + 1) % p, cy % p, s)
	var c := hash01(cx % p, (cy + 1) % p, s)
	var d := hash01((cx + 1) % p, (cy + 1) % p, s)
	return lerpf(lerpf(a, b, fx), lerpf(c, d, fx), fy)


func generate(tex_name: String) -> Image:
	if tex_name.begins_with("paint_"):
		return _paint(Color(tex_name.substr(6)))
	match tex_name:
		"grass": return _grass(Color("5e9a45"), Color("4b8238"), Color("74b052"), 1)
		"grass_dark": return _grass(Color("4f8f45"), Color("3f7a3a"), Color("67a956"), 5)
		"cliff": return _cliff(false)
		"cliff_top": return _cliff(true)
		"path": return _speckle(Color("d9c08c"), Color("c4a874"), Color("ead6a8"), 3)
		"path_cracked": return _cracked(_speckle(Color("cdb27c"), Color("b89c68"), Color("dcc69a"), 3))
		"sand": return _speckle(Color("ecd9a0"), Color("d8c286"), Color("f8ecc4"), 4)
		"bark": return _bark()
		"blossom": return _foliage(Color("f4a6c8"), Color("dc7aa8"), Color("ffd6e8"), 7)
		"leaves": return _foliage(Color("5aa04a"), Color("3f7f3a"), Color("84c45e"), 8)
		"rock": return _speckle(Color("9a9ea8"), Color("7c808c"), Color("b8bcc6"), 9)
		"wood": return _planks()
		"cloth": return _cloth(Color("c8463c"), Color("a33a32"))
		"pad": return _speckle(Color("e9e2d0"), Color("d6cdb6"), Color("fbf7ec"), 11)
		"snow": return _speckle(Color("eef4fa"), Color("d6e2ee"), Color("ffffff"), 12)
	push_warning("Art: unknown texture '%s'" % tex_name)
	return _speckle(Color.MAGENTA, Color.BLACK, Color.WHITE, 0)


func _grass(base: Color, dark: Color, light: Color, s: int) -> Image:
	var img := Image.create_empty(PX, PX, false, Image.FORMAT_RGBA8)
	for y in PX:
		for x in PX:
			var n := vnoise(x, y, 4, s) * 0.65 + hash01(x, y, s + 1) * 0.35
			var c := base
			if n > 0.7:
				c = light
			elif n < 0.3:
				c = dark
			img.set_pixel(x, y, c)
	# Little grass blades: a dark pixel with a light tip above it.
	for i in 6:
		var bx := int(hash01(i, 1, s + 2) * PX)
		var by := 1 + int(hash01(i, 2, s + 2) * (PX - 1))
		img.set_pixel(bx, by, dark.darkened(0.15))
		img.set_pixel(bx, by - 1, light)
	return img


func _paint(color: Color) -> Image:
	var img := _grass(Color("5e9a45"), Color("4b8238"), Color("74b052"), 1)
	for y in PX:
		for x in PX:
			var g := img.get_pixel(x, y)
			var lum := (g.r + g.g + g.b) / 3.0
			img.set_pixel(x, y, color.lerp(color.lightened(0.35), clampf((lum - 0.45) * 3.0, 0.0, 1.0)).lerp(g, 0.12))
	return img


func _cliff(lip: bool) -> Image:
	var img := Image.create_empty(PX, PX, false, Image.FORMAT_RGBA8)
	var seams := [0, 5, 11]
	var base := Color("8d919e")
	var dark := Color("5f6372")
	var light := Color("adb1bd")
	for y in PX:
		for x in PX:
			var slab := 0
			for i in seams.size():
				if x >= seams[i]:
					slab = i
			var hseam := 7 if slab == 1 else (12 if slab == 2 else 3)
			var c := base.lerp(dark, hash01(slab, 0, 3) * 0.25)
			if x in seams or y == hseam:
				c = dark
			elif x - 1 in seams or y == hseam + 1:
				c = light
			elif hash01(x, y, 4) > 0.88:
				c = c.darkened(0.12)
			img.set_pixel(x, y, c)
	if lip:
		for x in PX:
			var depth := 2 + int(hash01(x / 2, 0, 9) * 3.0)
			for y in depth:
				img.set_pixel(x, y, Color("74b052") if y == 0 else Color("5e9a45"))
			img.set_pixel(x, depth, Color("36612e"))
	return img


func _speckle(base: Color, dark: Color, light: Color, s: int) -> Image:
	var img := Image.create_empty(PX, PX, false, Image.FORMAT_RGBA8)
	for y in PX:
		for x in PX:
			var n := vnoise(x, y, 4, s) * 0.5 + hash01(x, y, s) * 0.5
			img.set_pixel(x, y, light if n > 0.74 else (dark if n < 0.28 else base))
	return img


func _cracked(img: Image) -> Image:
	var line := Color("5a4632")
	for p in [Vector2i(2, 3), Vector2i(3, 4), Vector2i(4, 4), Vector2i(5, 5), Vector2i(6, 6), Vector2i(6, 7),
			Vector2i(7, 8), Vector2i(8, 8), Vector2i(9, 9), Vector2i(10, 9), Vector2i(11, 10), Vector2i(12, 12),
			Vector2i(6, 8), Vector2i(5, 9), Vector2i(5, 10), Vector2i(4, 11), Vector2i(10, 4), Vector2i(10, 5),
			Vector2i(9, 6), Vector2i(9, 7), Vector2i(13, 2), Vector2i(12, 3), Vector2i(11, 4)]:
		img.set_pixel(p.x, p.y, line)
	return img


func _bark() -> Image:
	var img := Image.create_empty(PX, PX, false, Image.FORMAT_RGBA8)
	for y in PX:
		for x in PX:
			var stripe := hash01(x, 0, 21)
			var c := Color("6b4a3a")
			if stripe > 0.7:
				c = Color("53382c")
			elif stripe < 0.2:
				c = Color("85604a")
			if hash01(x, y, 22) > 0.93:
				c = c.darkened(0.25)
			img.set_pixel(x, y, c)
	return img


func _foliage(base: Color, dark: Color, light: Color, s: int) -> Image:
	var img := Image.create_empty(PX, PX, false, Image.FORMAT_RGBA8)
	for y in PX:
		for x in PX:
			var n := vnoise(x, y, 4, s)
			var c := base
			if n > 0.6:
				c = light
			elif n < 0.36:
				c = dark
			if hash01(x, y, s + 3) > 0.94:
				c = light.lightened(0.4)
			img.set_pixel(x, y, c)
	return img


func _planks() -> Image:
	var img := Image.create_empty(PX, PX, false, Image.FORMAT_RGBA8)
	for y in PX:
		for x in PX:
			var c := Color("b07a4a")
			if y % 4 == 3:
				c = Color("7a5232")
			elif (x + (y / 4) * 7) % 16 == 0:
				c = Color("8a5e3a")
			elif hash01(x, y, 31) > 0.9:
				c = Color("c08a5a")
			img.set_pixel(x, y, c)
	return img


func _cloth(base: Color, dark: Color) -> Image:
	var img := Image.create_empty(PX, PX, false, Image.FORMAT_RGBA8)
	for y in PX:
		for x in PX:
			img.set_pixel(x, y, dark if x % 4 == 0 else base)
	return img

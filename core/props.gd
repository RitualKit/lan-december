class_name Props
extends RefCounted
## Decorative scenery: trees, rocks, lamps, tents, snowmen, boats and other props.


static func blossom_tree(rng: RandomNumberGenerator, foliage := "blossom") -> Node3D:
	var root := Node3D.new()
	var height := rng.randf_range(1.1, 1.7)
	var trunk := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.11
	cyl.bottom_radius = 0.17
	cyl.height = height
	cyl.radial_segments = 6
	cyl.rings = 1
	trunk.mesh = cyl
	trunk.material_override = Art.material("bark", 1.0)
	trunk.position.y = height * 0.5
	root.add_child(trunk)
	var canopy_y := height + 0.35
	var blobs := rng.randi_range(4, 6)
	for i in blobs:
		var blob := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		var r := rng.randf_range(0.5, 0.8) if i > 0 else 0.85
		sphere.radius = r
		sphere.height = r * 1.7
		sphere.radial_segments = 9
		sphere.rings = 5
		blob.mesh = sphere
		blob.material_override = Art.material(foliage, 1.0)
		var a := rng.randf() * TAU
		var d := 0.0 if i == 0 else rng.randf_range(0.45, 0.75)
		blob.position = Vector3(cos(a) * d, canopy_y + rng.randf_range(-0.2, 0.35), sin(a) * d)
		root.add_child(blob)
	return root


static func rock(rng: RandomNumberGenerator) -> Node3D:
	var m := MeshInstance3D.new()
	var s := SphereMesh.new()
	var r := rng.randf_range(0.25, 0.45)
	s.radius = r
	s.height = r * 1.2
	s.radial_segments = 7
	s.rings = 3
	m.mesh = s
	m.material_override = Art.material("rock", 1.0)
	m.position.y = r * 0.3
	m.rotation.y = rng.randf() * TAU
	return m


static func bush(rng: RandomNumberGenerator) -> Node3D:
	var m := MeshInstance3D.new()
	var s := SphereMesh.new()
	var r := rng.randf_range(0.3, 0.45)
	s.radius = r
	s.height = r * 1.5
	s.radial_segments = 8
	s.rings = 4
	m.mesh = s
	m.material_override = Art.material("leaves", 1.0)
	m.position.y = r * 0.6
	return m


static func lamp() -> Node3D:
	var root := Node3D.new()
	var post := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.1, 1.5, 0.1)
	post.mesh = box
	post.material_override = Art.color_material(Color("3a3440"))
	post.position.y = 0.75
	root.add_child(post)
	var glass := MeshInstance3D.new()
	var gbox := BoxMesh.new()
	gbox.size = Vector3(0.24, 0.3, 0.24)
	glass.mesh = gbox
	glass.material_override = Art.color_material(Color("ffd98a"), 2.5)
	glass.position.y = 1.6
	root.add_child(glass)
	var light := OmniLight3D.new()
	light.light_color = Color("ffc870")
	light.light_energy = 1.2
	light.omni_range = 3.5
	light.position.y = 1.6
	root.add_child(light)
	return root


static func tent() -> Node3D:
	var m := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(1.6, 1.3, 1.8)
	m.mesh = prism
	m.material_override = Art.material("cloth")
	m.position.y = 0.65
	return m


## Visual-only island chunk (no collision, so it can't be used to escape the arena).
static func islet(cells: Dictionary, theme: Dictionary) -> Node3D:
	var root := Node3D.new()
	for c in cells:
		var m := MeshInstance3D.new()
		var top := float(cells[c])
		m.mesh = Art.tile_mesh(top, ArenaTile.BOTTOM, theme.ground, theme.lip, theme.side)
		m.position = Vector3(c.x, 0, c.y)
		root.add_child(m)
	return root


## A tree from a theme spec such as "round:maple", "pine:pine_snow" or "palm:palm".
static func tree(spec: String, rng: RandomNumberGenerator) -> Node3D:
	var parts := spec.split(":")
	match parts[0]:
		"pine": return pine_tree(rng, parts[1])
		"palm": return palm_tree(rng)
	return blossom_tree(rng, parts[1])


static func _mesh(mesh: Mesh, mat: Material, pos := Vector3.ZERO) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	m.position = pos
	return m


static func _cyl(top: float, bottom: float, height: float, segments := 6) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = height
	c.radial_segments = segments
	c.rings = 1
	return c


static func _sphere(r: float, squash := 1.0, segments := 8) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0 * squash
	s.radial_segments = segments
	s.rings = 5
	return s


static func pine_tree(rng: RandomNumberGenerator, foliage := "pine") -> Node3D:
	var root := Node3D.new()
	root.add_child(_mesh(_cyl(0.1, 0.14, 0.6), Art.material("bark", 1.0), Vector3(0, 0.3, 0)))
	var tiers := rng.randi_range(3, 4)
	var y := 0.5
	for i in tiers:
		var r := lerpf(0.85, 0.35, float(i) / tiers) * rng.randf_range(0.9, 1.1)
		var h := 0.9
		root.add_child(_mesh(_cyl(0.0, r, h, 8), Art.material(foliage, 1.0), Vector3(0, y + h * 0.5, 0)))
		y += h * 0.55
	root.rotation.y = rng.randf() * TAU
	return root


static func palm_tree(rng: RandomNumberGenerator) -> Node3D:
	var root := Node3D.new()
	var lean := Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized() * 0.12
	var pos := Vector3.ZERO
	var segments := 6
	for i in segments:
		var seg := _mesh(_cyl(0.09, 0.12, 0.42), Art.material("bark", 1.0), pos + Vector3.UP * 0.2)
		root.add_child(seg)
		pos += Vector3.UP * 0.38 + lean * (i * 0.6)
	var crown := Node3D.new()
	crown.position = pos + Vector3.UP * 0.15
	root.add_child(crown)
	var fronds := rng.randi_range(6, 8)
	for i in fronds:
		var frond := Node3D.new()
		frond.rotation = Vector3(0, TAU * i / fronds + rng.randf() * 0.3, 0)
		var leaf := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.32, 0.05, 1.2)
		leaf.mesh = box
		leaf.material_override = Art.material("palm", 1.0)
		leaf.position = Vector3(0, -0.15, 0.55)
		leaf.rotation.x = 0.45
		frond.add_child(leaf)
		crown.add_child(frond)
	for i in 3:
		var a := TAU * i / 3.0
		crown.add_child(_mesh(_sphere(0.09), Art.color_material(Color("6b4a2a")), Vector3(cos(a) * 0.12, -0.15, sin(a) * 0.12)))
	return root


static func snowman(rng: RandomNumberGenerator) -> Node3D:
	var root := Node3D.new()
	var snow := Art.material("snow", 1.0)
	root.add_child(_mesh(_sphere(0.34), snow, Vector3(0, 0.3, 0)))
	root.add_child(_mesh(_sphere(0.25), snow, Vector3(0, 0.78, 0)))
	root.add_child(_mesh(_sphere(0.18), snow, Vector3(0, 1.15, 0)))
	var nose := _mesh(_cyl(0.0, 0.05, 0.22), Art.color_material(Color("f0842c")), Vector3(0, 1.15, 0.24))
	nose.rotation.x = PI * 0.5
	root.add_child(nose)
	root.add_child(_mesh(_cyl(0.13, 0.13, 0.18, 8), Art.color_material(Color("2b2033")), Vector3(0, 1.38, 0)))
	root.add_child(_mesh(_cyl(0.2, 0.2, 0.03, 8), Art.color_material(Color("2b2033")), Vector3(0, 1.29, 0)))
	root.rotation.y = rng.randf_range(-0.6, 0.6)
	return root


static func pumpkin(rng: RandomNumberGenerator) -> Node3D:
	var root := Node3D.new()
	var r := rng.randf_range(0.2, 0.32)
	root.add_child(_mesh(_sphere(r, 0.75, 10), Art.material("pumpkin", 1.0), Vector3(0, r * 0.7, 0)))
	root.add_child(_mesh(_cyl(0.03, 0.04, 0.14), Art.color_material(Color("4a7a3a")), Vector3(0, r * 1.4 + 0.05, 0)))
	return root


static func campfire() -> Node3D:
	var root := Node3D.new()
	for i in 3:
		var stick := _mesh(_cyl(0.06, 0.06, 0.6), Art.material("bark", 1.0), Vector3(0, 0.08, 0))
		stick.rotation = Vector3(PI * 0.5, TAU * i / 3.0, 0)
		root.add_child(stick)
	var flame := _mesh(_cyl(0.0, 0.18, 0.4, 6), Art.color_material(Color("ffb040"), 3.0), Vector3(0, 0.3, 0))
	flame.name = "Flame"
	root.add_child(flame)
	var light := OmniLight3D.new()
	light.light_color = Color("ff9a4a")
	light.light_energy = 2.0
	light.omni_range = 4.5
	light.position.y = 0.6
	root.add_child(light)
	return root


static func lighthouse() -> Node3D:
	var root := Node3D.new()
	for i in 4:
		var c := Color("f2f2f2") if i % 2 == 0 else Color("d8463c")
		root.add_child(_mesh(_cyl(0.42 - i * 0.05, 0.47 - i * 0.05, 0.75, 10), Art.color_material(c), Vector3(0, 0.375 + i * 0.75, 0)))
	root.add_child(_mesh(_cyl(0.3, 0.3, 0.4, 8), Art.color_material(Color("ffe9a0"), 3.0), Vector3(0, 3.2, 0)))
	root.add_child(_mesh(_cyl(0.0, 0.38, 0.35, 8), Art.color_material(Color("2b2033")), Vector3(0, 3.57, 0)))
	var beam := Node3D.new()
	beam.name = "Beam"
	beam.position.y = 3.2
	var ray := _mesh(_cyl(0.05, 0.6, 7.0, 8), Art.color_material(Color(1.0, 0.95, 0.7, 0.18), 1.5), Vector3(0, 0, 3.6))
	ray.rotation.x = PI * 0.5
	ray.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beam.add_child(ray)
	root.add_child(beam)
	var light := OmniLight3D.new()
	light.light_color = Color("ffe9a0")
	light.omni_range = 5.0
	light.position.y = 3.2
	root.add_child(light)
	return root


static func boat(rng: RandomNumberGenerator) -> Node3D:
	var root := Node3D.new()
	var hull := BoxMesh.new()
	hull.size = Vector3(0.55, 0.28, 1.3)
	root.add_child(_mesh(hull, Art.material("wood", 1.0), Vector3(0, 0.05, 0)))
	var bow := PrismMesh.new()
	bow.size = Vector3(0.55, 0.4, 0.28)
	var b := _mesh(bow, Art.material("wood", 1.0), Vector3(0, 0.05, 0.78))
	b.rotation = Vector3(PI * 0.5, 0, 0)
	root.add_child(b)
	root.add_child(_mesh(_cyl(0.03, 0.03, 1.3), Art.color_material(Color("6b4a2a")), Vector3(0, 0.8, 0)))
	var sail := PrismMesh.new()
	sail.size = Vector3(0.05, 1.0, 0.8)
	var sail_color: Color = [Color("f4f0e8"), Color("f4a6c8"), Color("7ab0ff"), Color("ffd45a")][rng.randi() % 4]
	root.add_child(_mesh(sail, Art.color_material(sail_color), Vector3(0, 0.95, -0.25)))
	return root


static func bird() -> Node3D:
	var root := Node3D.new()
	var body := BoxMesh.new()
	body.size = Vector3(0.1, 0.08, 0.3)
	root.add_child(_mesh(body, Art.color_material(Color("f4f4f4"))))
	for side in [-1, 1]:
		var wing := Node3D.new()
		wing.name = "WingL" if side < 0 else "WingR"
		var wm := BoxMesh.new()
		wm.size = Vector3(0.4, 0.02, 0.14)
		wing.add_child(_mesh(wm, Art.color_material(Color("e8e8f0")), Vector3(0.2 * side, 0, 0)))
		root.add_child(wing)
	return root


static func lily_pad(rng: RandomNumberGenerator) -> Node3D:
	var root := Node3D.new()
	root.add_child(_mesh(_cyl(0.32, 0.32, 0.03, 10), Art.color_material(Color("4f9a4a"))))
	if rng.randf() < 0.4:
		root.add_child(_mesh(_sphere(0.09, 0.8), Art.color_material(Color("ffb3d6")), Vector3(0.08, 0.06, 0.05)))
	root.rotation.y = rng.randf() * TAU
	return root


static func ice_floe(rng: RandomNumberGenerator) -> Node3D:
	var root := Node3D.new()
	for i in rng.randi_range(2, 4):
		var box := BoxMesh.new()
		box.size = Vector3(rng.randf_range(0.4, 0.9), 0.15, rng.randf_range(0.4, 0.9))
		root.add_child(_mesh(box, Art.material("ice", 1.0), Vector3(rng.randf_range(-0.4, 0.4), 0, rng.randf_range(-0.4, 0.4))))
	return root


static func sky_lantern() -> Node3D:
	var root := Node3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.22, 0.3, 0.22)
	root.add_child(_mesh(box, Art.color_material(Color("ffb860"), 2.5)))
	return root


# --- 3D pickups (Game.look_3d) --------------------------------------------------------

## A little five-petal blossom. Gold ones are bigger and shinier.
static func flower(gold: bool) -> Node3D:
	var root := Node3D.new()
	var petal_color := Color("ffd45a") if gold else Color("f7a8cc")
	var petal := Art.color_material(petal_color, 0.6 if gold else 0.0)
	var s := 2.2 if gold else 1.7
	for i in 5:
		var a := TAU * i / 5.0
		var p := _mesh(_sphere(0.11 * s, 0.45, 8), petal, Vector3(cos(a), 0, sin(a)) * 0.13 * s)
		p.rotation.y = -a
		p.scale = Vector3(1.0, 1.0, 0.7)
		root.add_child(p)
	root.add_child(_mesh(_sphere(0.07 * s, 0.7), Art.color_material(Color("fff6c0") if gold else Color("ffd45a")), Vector3(0, 0.03, 0)))
	root.rotation.x = -0.5
	var holder := Node3D.new()
	holder.add_child(root)
	return holder


static func chest() -> Node3D:
	var root := Node3D.new()
	var wood := Art.material("wood", 2.0)
	var gold := Art.color_material(Color("ffd45a"), 0.3)
	var base := BoxMesh.new()
	base.size = Vector3(0.62, 0.36, 0.44)
	root.add_child(_mesh(base, wood, Vector3(0, 0.18, 0)))
	var band := BoxMesh.new()
	band.size = Vector3(0.64, 0.06, 0.46)
	root.add_child(_mesh(band, gold, Vector3(0, 0.3, 0)))
	var lid := Node3D.new()
	lid.name = "Lid"
	lid.position = Vector3(0, 0.36, -0.22)
	var top := BoxMesh.new()
	top.size = Vector3(0.62, 0.16, 0.44)
	lid.add_child(_mesh(top, wood, Vector3(0, 0.08, 0.22)))
	var lock := BoxMesh.new()
	lock.size = Vector3(0.1, 0.12, 0.04)
	lid.add_child(_mesh(lock, gold, Vector3(0, 0.0, 0.45)))
	root.add_child(lid)
	root.scale = Vector3.ONE * 1.35
	return root


static func bomb(body_color := Color("3a3448")) -> Node3D:
	var root := Node3D.new()
	root.add_child(_mesh(_sphere(0.22, 1.0, 10), Art.color_material(body_color), Vector3(0, 0.22, 0)))
	root.add_child(_mesh(_cyl(0.07, 0.07, 0.08), Art.color_material(Color("8a8aa0")), Vector3(0, 0.45, 0)))
	var fuse := _mesh(_cyl(0.02, 0.02, 0.16), Art.color_material(Color("c8a070")), Vector3(0.04, 0.55, 0))
	fuse.rotation.z = -0.4
	root.add_child(fuse)
	root.add_child(_mesh(_sphere(0.05), Art.color_material(Color("ffb040"), 4.0), Vector3(0.08, 0.63, 0)))
	return root


static func shuriken() -> Node3D:
	var root := Node3D.new()
	var steel := Art.color_material(Color("c8d0dc"))
	for i in 4:
		var blade := BoxMesh.new()
		blade.size = Vector3(0.1, 0.03, 0.32)
		var b := _mesh(blade, steel)
		b.rotation.y = TAU * i / 4.0 + PI / 4.0
		b.position = Vector3(sin(b.rotation.y), 0, cos(b.rotation.y)) * 0.12
		root.add_child(b)
	root.add_child(_mesh(_cyl(0.06, 0.06, 0.05, 8), Art.color_material(Color("5a6070"))))
	return root

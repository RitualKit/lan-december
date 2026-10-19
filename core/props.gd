class_name Props
extends RefCounted
## Decorative scenery: cherry blossom trees, rocks, lamps, tents.


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
static func islet(cells: Dictionary) -> Node3D:
	var root := Node3D.new()
	for c in cells:
		var m := MeshInstance3D.new()
		var top := float(cells[c])
		m.mesh = Art.tile_mesh(top, ArenaTile.BOTTOM)
		m.position = Vector3(c.x, 0, c.y)
		root.add_child(m)
	return root

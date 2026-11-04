class_name Props
extends RefCounted
## Procedural low-poly props for the 2.5D world. Everything is built from primitive meshes
## so the game has depth and lighting before real art is dropped in.

static func mat(c: Color, emissive: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 1.0
	if emissive > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emissive
	return m

static func add(parent: Node3D, mesh: Mesh, c: Color, pos: Vector3, emissive: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat(c, emissive)
	mi.position = pos
	parent.add_child(mi)
	return mi

static func cyl(top: float, bottom: float, h: float, seg: int = 7) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = h
	m.radial_segments = seg
	m.rings = 1
	return m

static func sphere(r: float, squash: float = 1.0, seg: int = 8) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0 * squash
	m.radial_segments = seg
	m.rings = maxi(seg / 2, 3)
	return m

static func box(s: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = s
	return m

static func slab(parent: Node3D, x0: float, x1: float, c: Color, z0: float = -45.0, z1: float = 10.0, y: float = 0.0, thick: float = 0.4) -> void:
	add(parent, box(Vector3(x1 - x0, thick, z1 - z0)), c, Vector3((x0 + x1) / 2.0, y - thick / 2.0, (z0 + z1) / 2.0))

static func tree(parent: Node3D, pos: Vector3, s: float, leaf: Color, fruit: Color = Color(0, 0, 0, 0)) -> Node3D:
	var t := Node3D.new()
	t.position = pos
	t.scale = Vector3.ONE * s
	parent.add_child(t)
	add(t, cyl(0.18, 0.28, 2.2), Color(0.38, 0.27, 0.17), Vector3(0, 1.1, 0))
	add(t, sphere(1.3, 0.9), leaf, Vector3(0, 3.0, 0))
	add(t, sphere(0.95, 0.9), leaf.lightened(0.08), Vector3(0.7, 3.6, 0.2))
	add(t, sphere(0.9, 0.9), leaf.darkened(0.08), Vector3(-0.7, 3.4, -0.2))
	if fruit.a > 0.0:
		for p in [Vector3(0.9, 2.7, 0.8), Vector3(-0.8, 3.2, 0.9), Vector3(0.1, 3.9, 0.9)]:
			add(t, sphere(0.17), fruit, p)
	return t

static func rock(parent: Node3D, pos: Vector3, s: float, c: Color = Color(0.5, 0.48, 0.45)) -> void:
	var r := add(parent, sphere(0.6, 0.6, 5), c, pos)
	r.scale = Vector3.ONE * s
	r.rotation.y = pos.x

static func grass(parent: Node3D, pos: Vector3, c: Color) -> void:
	for i in 3:
		var m := add(parent, cyl(0.0, 0.08, 0.6 + 0.2 * i, 4), c.lightened(0.05 * i), pos + Vector3(0.12 * i - 0.12, 0.3, 0.05 * i))
		m.rotation.z = (i - 1) * 0.25

static func flower(parent: Node3D, pos: Vector3, c: Color) -> void:
	add(parent, cyl(0.02, 0.02, 0.5, 4), Color(0.2, 0.5, 0.2), pos + Vector3(0, 0.25, 0))
	add(parent, sphere(0.1, 0.6, 6), c, pos + Vector3(0, 0.52, 0))

static func animal(parent: Node3D, pos: Vector3, body: Color, size: float = 1.0, tall_neck: bool = false) -> Node3D:
	var a := Node3D.new()
	a.position = pos
	a.scale = Vector3.ONE * size
	parent.add_child(a)
	add(a, box(Vector3(1.0, 0.55, 0.45)), body, Vector3(0, 0.75, 0))
	for lx in [-0.35, 0.35]:
		for lz in [-0.14, 0.14]:
			add(a, cyl(0.06, 0.05, 0.5, 5), body.darkened(0.2), Vector3(lx, 0.25, lz))
	if tall_neck:
		add(a, cyl(0.08, 0.12, 1.0, 5), body, Vector3(0.5, 1.3, 0))
		add(a, box(Vector3(0.3, 0.18, 0.18)), body, Vector3(0.65, 1.85, 0))
	else:
		add(a, box(Vector3(0.3, 0.3, 0.3)), body.lightened(0.05), Vector3(0.6, 0.95, 0))
	add(a, box(Vector3(0.1, 0.1, 0.1)), body.darkened(0.3), Vector3(-0.55, 0.85, 0))
	return a

static func bird(parent: Node3D, pos: Vector3, c: Color) -> void:
	var b := Node3D.new()
	b.position = pos
	parent.add_child(b)
	add(b, sphere(0.12, 0.8, 6), c, Vector3.ZERO)
	for s in [-1.0, 1.0]:
		var w := add(b, box(Vector3(0.05, 0.02, 0.4)), c.darkened(0.1), Vector3(0, 0.04, 0.22 * s))
		w.rotation.x = 0.4 * s

static func person(parent: Node3D, pos: Vector3, female: bool, faces_left: bool = false) -> Node3D:
	var p := Node3D.new()
	p.position = pos
	p.rotation.y = PI if faces_left else 0.0
	parent.add_child(p)
	var skin := Color(0.8, 0.6, 0.45)
	var cloth := Color(0.65, 0.5, 0.3)
	add(p, cyl(0.2, 0.3, 0.9, 8), cloth, Vector3(0, 0.7, 0))
	add(p, sphere(0.19), skin, Vector3(0, 1.4, 0))
	var hair := Color(0.2, 0.12, 0.08)
	add(p, sphere(0.2, 0.7), hair, Vector3(0, 1.45, -0.02))
	if female:
		add(p, cyl(0.12, 0.07, 0.55, 6), hair, Vector3(0, 1.15, -0.15))
	for lx in [-0.1, 0.1]:
		add(p, cyl(0.07, 0.07, 0.4, 6), skin, Vector3(lx, 0.2, 0))
	return p

static func serpent(parent: Node3D, pos: Vector3) -> void:
	var c := Color(0.25, 0.55, 0.25)
	var s := Node3D.new()
	s.position = pos
	parent.add_child(s)
	for i in 8:
		add(s, sphere(0.14 - i * 0.008, 1.0, 6), c.lightened(0.02 * i), Vector3(sin(i * 0.9) * 0.25, 0.1 + i * 0.22, cos(i * 0.9) * 0.1))
	add(s, sphere(0.13, 0.8, 6), c.lightened(0.1), Vector3(0.1, 1.95, 0.05))

static func flame(parent: Node3D, pos: Vector3) -> void:
	var f := Node3D.new()
	f.position = pos
	parent.add_child(f)
	add(f, cyl(0.0, 0.35, 1.8, 6), Color(1.0, 0.55, 0.15), Vector3(0, 0.9, 0), 2.5)
	add(f, cyl(0.0, 0.18, 1.2, 6), Color(1.0, 0.9, 0.4), Vector3(0, 0.6, 0), 3.0)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.6, 0.25)
	l.light_energy = 3.0
	l.omni_range = 9.0
	l.position = Vector3(0, 1.2, 0.5)
	f.add_child(l)

static func cherub(parent: Node3D, pos: Vector3) -> void:
	var p := person(parent, pos, false)
	p.scale = Vector3.ONE * 1.5
	for s in [-1.0, 1.0]:
		var w := add(p, box(Vector3(0.05, 1.0, 0.6)), Color(0.95, 0.9, 0.75), Vector3(0, 1.1, 0.35 * s), 0.6)
		w.rotation.x = 0.35 * s

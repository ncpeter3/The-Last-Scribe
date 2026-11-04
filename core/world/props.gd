class_name Props
extends RefCounted
## Props for the top-down 3D world. Real models (CC0 Quaternius art in res://shared_assets) are
## used when present; each helper falls back to simple primitive shapes if a model is missing.

const NATURE := "res://shared_assets/nature/"
const ANIMALS := "res://shared_assets/animals/"
const FAR := 48.0  # props farther than this from the camera are not drawn (saves phone GPU time)
const TREES := ["tree_1", "tree_2", "tree_3", "tree_4", "tree_5"]
const ROCKS := ["rock_1", "rock_2", "rock_3"]
const GRASS := ["grass_short", "grass_short", "clover", "fern"]
const FLOWERS := ["flowers_1", "flowers_2", "bush_flowers"]

static var _cache: Dictionary = {}

## Load a scene once and reuse it. Returns null when the file isn't there.
static func scene(path: String) -> PackedScene:
	if not _cache.has(path):
		_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _cache[path]

## Place a model from shared_assets. `name` is a file in nature/ (.gltf) or animals/ (.glb).
static func model(parent: Node3D, path: String, pos: Vector3, s: float = 1.0, yaw: float = 0.0) -> Node3D:
	var ps := scene(path)
	if ps == null:
		return null
	var n: Node3D = ps.instantiate()
	n.position = pos
	n.rotation.y = yaw
	n.scale = Vector3.ONE * s
	parent.add_child(n)
	for g in n.find_children("*", "GeometryInstance3D", true, false):
		(g as GeometryInstance3D).visibility_range_end = FAR
	return n

static func nature(parent: Node3D, id: String, pos: Vector3, s: float = 1.0) -> Node3D:
	return model(parent, NATURE + id + ".gltf", pos, s, _yaw(pos))

static func _pick(list: Array, pos: Vector3) -> String:
	return list[absi(int(pos.x * 7.3 + pos.z * 13.1)) % list.size()]

static func _yaw(pos: Vector3) -> float:
	return fmod(pos.x * 1.7 + pos.z * 2.3, TAU)

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

static func tree(parent: Node3D, pos: Vector3, s: float, leaf: Color, fruit: Color = Color(0, 0, 0, 0), kind: String = "") -> Node3D:
	if kind == "":
		kind = _pick(TREES, pos)
	var m := nature(parent, kind, pos, s * 0.5)
	if m != null:
		if fruit.a > 0.0:
			_fruit_on(parent, m, fruit, 7)
		return m
	return tree_placeholder(parent, pos, s, leaf, fruit)

## Hang fruit around the outside of a tree's leafy crown (the upper part of its bounding box).
static func _fruit_on(parent: Node3D, tree_node: Node3D, fruit: Color, count: int) -> void:
	var box := AABB()
	var first := true
	for g in tree_node.find_children("*", "VisualInstance3D", true, false):
		var vi := g as VisualInstance3D
		var b := vi.global_transform * vi.get_aabb() if vi.is_inside_tree() else _local_aabb(tree_node, vi)
		box = b if first else box.merge(b)
		first = false
	if first:
		return
	var c := box.get_center()
	var h := box.size.y
	var center := Vector3(c.x, box.position.y + h * 0.68, c.z)
	var radius := Vector3(box.size.x * 0.38, h * 0.22, box.size.z * 0.38)
	for i in count:
		var ang := float(i) / count * TAU + tree_node.position.x
		var up := 0.25 + 0.5 * float(i % 3) / 2.0
		var d := Vector3(cos(ang) * (1.0 - up * 0.4), up - 0.3, sin(ang) * (1.0 - up * 0.4))
		var f := add(parent, sphere(0.17), fruit, center + d * radius, 0.3)
		f.visibility_range_end = FAR

static func _local_aabb(root: Node3D, vi: VisualInstance3D) -> AABB:
	var t := Transform3D.IDENTITY
	var n: Node = vi
	while n != null and n != root.get_parent():
		if n is Node3D:
			t = (n as Node3D).transform * t
		n = n.get_parent()
	return t * vi.get_aabb()

static func tree_placeholder(parent: Node3D, pos: Vector3, s: float, leaf: Color, fruit: Color = Color(0, 0, 0, 0)) -> Node3D:
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
	if nature(parent, _pick(ROCKS, pos), pos, s * 0.35) != null:
		return
	var r := add(parent, sphere(0.6, 0.6, 5), c, pos)
	r.scale = Vector3.ONE * s
	r.rotation.y = pos.x

static func grass(parent: Node3D, pos: Vector3, c: Color) -> void:
	if nature(parent, _pick(GRASS, pos), pos, 0.45) != null:
		return
	for i in 3:
		var m := add(parent, cyl(0.0, 0.08, 0.6 + 0.2 * i, 4), c.lightened(0.05 * i), pos + Vector3(0.12 * i - 0.12, 0.3, 0.05 * i))
		m.rotation.z = (i - 1) * 0.25

static func flower(parent: Node3D, pos: Vector3, c: Color) -> void:
	if nature(parent, _pick(FLOWERS, pos), pos, 0.3) != null:
		return
	add(parent, cyl(0.02, 0.02, 0.5, 4), Color(0.2, 0.5, 0.2), pos + Vector3(0, 0.25, 0))
	add(parent, sphere(0.1, 0.6, 6), c, pos + Vector3(0, 0.52, 0))

## A real animal model by id (cow, horse, sheep, ...), idling. Falls back to a block animal.
static func creature(parent: Node3D, id: String, pos: Vector3, s: float = 1.0) -> Node3D:
	var ps := scene(ANIMALS + id + ".glb")
	if ps == null:
		return animal(parent, pos, Color(0.7, 0.55, 0.4), s, id in ["llama", "horse", "zebra"])
	var holder := Node3D.new()
	holder.position = pos
	holder.rotation.y = _yaw(pos)
	holder.scale = Vector3.ONE * s
	parent.add_child(holder)
	holder.add_child(ps.instantiate())
	var anim := CharacterFactory.animator(holder)
	if anim:
		CharacterFactory.play(holder, "Idle" if anim.has_animation("Idle") else "Walk", absf(pos.x + pos.z))
	return holder

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
	if scene(ANIMALS + "bird.glb") != null:
		creature(parent, "bird", pos, 1.4)
		return
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
	CharacterFactory.make("serpent", parent, pos, true)

static func serpent_placeholder(parent: Node3D, pos: Vector3) -> Node3D:
	var c := Color(0.25, 0.55, 0.25)
	var s := Node3D.new()
	s.position = pos
	parent.add_child(s)
	for i in 8:
		add(s, sphere(0.14 - i * 0.008, 1.0, 6), c.lightened(0.02 * i), Vector3(sin(i * 0.9) * 0.25, 0.1 + i * 0.22, cos(i * 0.9) * 0.1))
	add(s, sphere(0.13, 0.8, 6), c.lightened(0.1), Vector3(0.1, 1.95, 0.05))
	return s

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
	CharacterFactory.make("cherub", parent, pos, true)

static func cherub_placeholder(parent: Node3D, pos: Vector3) -> Node3D:
	var p := person(parent, pos, false)
	p.scale = Vector3.ONE * 1.5
	for s in [-1.0, 1.0]:
		var w := add(p, box(Vector3(0.05, 1.0, 0.6)), Color(0.95, 0.9, 0.75), Vector3(0, 1.1, 0.35 * s), 0.6)
		w.rotation.x = 0.35 * s
	return p

class_name Props
extends RefCounted
## Props for the top-down 3D world, all in the game's low-poly style (core/lowpoly): trees, rocks,
## grass, flowers, water, flames and living creatures. Shapes repeat a lot, so each kind of plant or
## rock is built a few ways once and the meshes are shared.
## Water areas are remembered (water_rects) so the ground can dip under them, fish stay inside them
## and land animals stay out of them. Call reset() when a new world is built.

const L := preload("res://core/lowpoly/low_poly.gd")
const FAR := 48.0  # props farther than this from the camera are not drawn (saves phone GPU time)
const SURFACE := 0.06  # height of every water surface

## Every pool, river and sea made so far, as rectangles on the ground (x, z).
static var water_rects: Array[Rect2] = []
static var _meshes: Dictionary = {}
static var _flat: Dictionary = {}

static func reset() -> void:
	water_rects.clear()

static func in_water(p: Vector3, margin: float = 0.3) -> bool:
	for r in water_rects:
		if r.grow(margin).has_point(Vector2(p.x, p.z)):
			return true
	return false

static func water_at(p: Vector3) -> Rect2:
	for r in water_rects:
		if r.has_point(Vector2(p.x, p.z)):
			return r
	return Rect2()

static func _variant(pos: Vector3, n: int) -> int:
	return absi(int(pos.x * 7.3 + pos.z * 13.1)) % n

static func _yaw(pos: Vector3) -> float:
	return fmod(pos.x * 1.7 + pos.z * 2.3, TAU)

## Put a shared low-poly mesh in the world.
static func _place(parent: Node3D, mesh: Mesh, pos: Vector3, s: float = 1.0, yaw: float = 0.0, faded: bool = false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation.y = yaw
	mi.scale = Vector3.ONE * s
	mi.visibility_range_end = FAR
	if faded:
		mi.material_override = L.material_faded()
	parent.add_child(mi)
	return mi

static func _cached(key: String, build: Callable) -> Mesh:
	if not _meshes.has(key):
		var b := L.new()
		build.call(b)
		_meshes[key] = b.mesh()
	return _meshes[key]

# ---------- simple shapes ----------

## A flat-lit color material for simple shapes (see core/lowpoly/flat_color.gdshader).
## A color with alpha below 1 is see-through.
static func mat(c: Color, emissive: float = 0.0) -> ShaderMaterial:
	var key := "%s_%s" % [c.to_html(), emissive]
	if not _flat.has(key):
		var m := ShaderMaterial.new()
		m.shader = preload("res://core/lowpoly/flat_color_clear.gdshader") if c.a < 0.99 else preload("res://core/lowpoly/flat_color.gdshader")
		m.set_shader_parameter("color", c)
		m.set_shader_parameter("glow", emissive)
		_flat[key] = m
	return _flat[key]

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
	m.radial_segments = mini(seg, 8)
	m.rings = maxi(mini(seg, 8) / 2, 3)
	return m

static func box(s: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = s
	return m

# ---------- water ----------

## A pool, river or sea from x0..x1 and z0..z1: a low-poly surface of gently moving facets. The ground
## dips beneath it (see water_rects), so fish can swim under the surface.
static func water(parent: Node3D, x0: float, x1: float, z0: float, z1: float, _y: float = SURFACE, deep: Color = Color(0.1, 0.34, 0.52)) -> MeshInstance3D:
	water_rects.append(Rect2(x0, z0, x1 - x0, z1 - z0))
	var pm := PlaneMesh.new()
	pm.size = Vector2(x1 - x0, z1 - z0)
	pm.subdivide_width = clampi(int((x1 - x0) / 1.2), 1, 60)
	pm.subdivide_depth = clampi(int((z1 - z0) / 1.2), 1, 60)
	var mi := MeshInstance3D.new()
	mi.mesh = pm
	var m := ShaderMaterial.new()
	m.shader = preload("res://core/lowpoly/water.gdshader")
	m.set_shader_parameter("deep", deep)
	mi.material_override = m
	mi.position = Vector3((x0 + x1) / 2.0, SURFACE, (z0 + z1) / 2.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

# ---------- plants and rocks ----------

## A tree. kind: "" (a round leafy tree or a pine, picked by position), "round", "pine", "tree_2" (the
## tree of life: tall, with golden fruit), "twisted_tree" (the tree of knowledge), "dead_tree".
## Fruit hangs as separate pieces (tagged with meta "fruit") so it can be picked.
static func tree(parent: Node3D, pos: Vector3, s: float, leaf: Color, fruit: Color = Color(0, 0, 0, 0), kind: String = "") -> Node3D:
	if kind == "" or kind.begins_with("tree_") and kind != "tree_2":
		kind = ["round", "round", "pine", "round", "birch"][_variant(pos, 5)]
	var leaf_key := Color(snappedf(leaf.r, 0.05), snappedf(leaf.g, 0.05), snappedf(leaf.b, 0.05))
	var v := _variant(pos, 3)
	var mesh := _cached("tree_%s_%s_%d" % [kind, leaf_key.to_html(), v], func(b: LowPoly): _build_tree(b, kind, leaf_key, v))
	var size := s * (1.4 if kind == "tree_2" else 1.0)
	var t := _place(parent, mesh, pos, size, _yaw(pos), true)
	if fruit.a > 0.0:
		var crown := _crown(kind)
		for i in 7:
			var a := float(i) / 7.0 * TAU + pos.x
			var up := 0.25 + 0.5 * float(i % 3) / 2.0
			var d := Vector3(cos(a) * (1.0 - up * 0.4), up - 0.3, sin(a) * (1.0 - up * 0.4))
			var fb := L.new()
			fb.ball(Vector3.ZERO, 0.16, L.glow(fruit, 0.25) if kind == "tree_2" else fruit, 0)
			var f := fb.instance(false)
			f.position = pos + (crown[0] + d * crown[1]) * size
			f.set_meta("fruit", true)
			f.visibility_range_end = FAR
			parent.add_child(f)
	return t

## Center and size of each tree kind's leafy crown (for hanging fruit), at scale 1.
static func _crown(kind: String) -> Array:
	match kind:
		"pine":
			return [Vector3(0, 2.2, 0), Vector3(1.0, 0.9, 1.0)]
		"twisted_tree":
			return [Vector3(0, 2.6, 0), Vector3(1.5, 0.8, 1.5)]
		"tree_2":
			return [Vector3(0, 3.1, 0), Vector3(1.6, 1.0, 1.6)]
	return [Vector3(0, 2.6, 0), Vector3(1.3, 0.9, 1.3)]

static func _build_tree(b: LowPoly, kind: String, leaf: Color, v: int) -> void:
	var bark := L.WOOD_DARK
	match kind:
		"pine":
			b.prism(Vector3(0, -0.1, 0), 0.16, 0.1, 1.1, 6, bark)
			for i in 3:
				b.prism(Vector3(0, 0.8 + i * 0.75, 0), 1.25 - i * 0.3, 0.0, 1.3, 7, L.shade(leaf, -0.12 + i * 0.07), Color(), Vector2.ONE, i * 0.45 + v)
		"birch":
			b.prism(Vector3(0, -0.1, 0), 0.13, 0.08, 2.6, 6, L.CLOUD)
			for i in 4:
				b.box(Vector3(0, 0.4 + i * 0.55, 0.0), Vector3(0.27, 0.06, 0.27), L.INK)
			b.ball(Vector3(0, 2.7, 0), 0.85, L.shade(leaf, 0.12), 1, Vector3(0.9, 1.25, 0.9))
			b.ball(Vector3(0.35, 2.2, 0.2), 0.5, L.shade(leaf, 0.05), 0)
		"twisted_tree":
			# A gnarled trunk that turns as it rises, with a wide, dark crown.
			for i in 6:
				var a := i * 0.7
				b.prism(Vector3(sin(a) * 0.18, i * 0.35 - 0.1, cos(a) * 0.12), 0.3 - i * 0.03, 0.26 - i * 0.03, 0.42, 6, L.shade(bark, -0.05 * (i % 2)), Color(), Vector2.ONE, a)
			for k in 3:
				var a := TAU * k / 3.0 + 0.4
				b.with(Transform3D(Basis(Vector3(cos(a), 0, sin(a)).cross(Vector3.UP).normalized(), 0.8), Vector3(0, 1.9, 0)), func():
					b.prism(Vector3.ZERO, 0.1, 0.05, 0.9, 5, bark))
			b.ball(Vector3(0, 2.7, 0), 1.25, leaf, 1, Vector3(1.3, 0.75, 1.3))
			b.ball(Vector3(0.7, 2.95, 0.3), 0.75, L.shade(leaf, 0.08), 1)
			b.ball(Vector3(-0.7, 2.85, -0.3), 0.7, L.shade(leaf, -0.08), 1)
		"dead_tree":
			b.prism(Vector3(0, -0.1, 0), 0.2, 0.08, 2.6, 6, L.shade(bark, 0.1))
			for k in 4:
				var a := TAU * k / 4.0 + v
				b.with(Transform3D(Basis(Vector3(cos(a), 0, sin(a)).cross(Vector3.UP).normalized(), 0.9), Vector3(0, 1.2 + k * 0.35, 0)), func():
					b.prism(Vector3.ZERO, 0.07, 0.02, 0.9 - k * 0.1, 4, L.shade(bark, 0.1)))
		_:  # round leafy tree, and the tree of life
			b.prism(Vector3(0, -0.1, 0), 0.24, 0.15, 1.9, 6, bark)
			b.with(Transform3D(Basis(Vector3.FORWARD, 0.6), Vector3(0, 1.3, 0)), func():
				b.prism(Vector3.ZERO, 0.08, 0.05, 0.7, 5, bark))
			b.ball(Vector3(0, 2.5, 0), 1.15, leaf, 1, Vector3(1.0, 0.9, 1.0))
			b.ball(Vector3(0.6, 2.95 + v * 0.1, 0.2), 0.75, L.shade(leaf, 0.1), 1)
			b.ball(Vector3(-0.55, 2.8, -0.25), 0.7, L.shade(leaf, -0.07), 1)
			if kind == "tree_2":  # the tree of life: golden blossoms in its crown
				for i in 9:
					var a := i * 2.4
					b.ball(Vector3(cos(a) * 0.9, 2.4 + (i % 3) * 0.35, sin(a) * 0.9), 0.12, L.glow(L.SUN, 0.35), 0)

static func rock(parent: Node3D, pos: Vector3, s: float, c: Color = Color(0.5, 0.48, 0.45)) -> void:
	var v := _variant(pos, 3)
	var key := Color(snappedf(c.r, 0.05), snappedf(c.g, 0.05), snappedf(c.b, 0.05))
	var mesh := _cached("rock_%s_%d" % [key.to_html(), v], func(b: LowPoly):
		b.ball(Vector3(0, 0.15, 0), 0.6, key, 0, [Vector3(1.2, 0.7, 1.0), Vector3(0.9, 1.0, 0.8), Vector3(1.3, 0.55, 1.1)][v])
		b.ball(Vector3(0.45, 0.08, 0.2), 0.3, L.shade(key, 0.08), 0, Vector3(1.0, 0.8, 1.0)))
	_place(parent, mesh, pos, s * 0.6, _yaw(pos))

static func grass(parent: Node3D, pos: Vector3, c: Color) -> void:
	var v := _variant(pos, 3)
	var mesh := _cached("grass_%d" % v, func(b: LowPoly):
		for i in 5 + v:
			var a := i * 2.4 + v
			var p := Vector3(cos(a) * 0.15 * (i % 3), 0, sin(a) * 0.15 * (i % 3))
			b.with(Transform3D(Basis(Vector3(cos(a), 0, sin(a)), 0.25), p), func():
				b.prism(Vector3(0, -0.02, 0), 0.06, 0.0, 0.35 + 0.1 * (i % 3), 3, L.shade(L.GRASS, -0.08 + 0.05 * (i % 3)))))
	_place(parent, mesh, pos, 1.0, _yaw(pos))

static func flower(parent: Node3D, pos: Vector3, c: Color) -> void:
	var key := Color(snappedf(c.r, 0.1), snappedf(c.g, 0.1), snappedf(c.b, 0.1))
	var mesh := _cached("flower_%s" % key.to_html(), func(b: LowPoly):
		for k in 3:
			var o := Vector3([0.0, 0.18, -0.15][k], 0, [0.0, 0.12, 0.14][k])
			var h: float = [0.42, 0.3, 0.34][k]
			b.prism(o, 0.02, 0.02, h, 3, L.LEAF_DARK)
			for i in 5:
				var a := TAU * i / 5.0
				b.box(o + Vector3(cos(a) * 0.07, h, sin(a) * 0.07), Vector3(0.08, 0.03, 0.08), key)
			b.ball(o + Vector3(0, h + 0.02, 0), 0.04, L.SUN, 0)
		b.box(Vector3(0.05, 0.04, 0.0), Vector3(0.25, 0.04, 0.08), L.LEAF))
	_place(parent, mesh, pos, 1.0, _yaw(pos))

## Bushes and other plants by name: "bush", "bush_flowers", "plant".
static func nature(parent: Node3D, id: String, pos: Vector3, s: float = 1.0) -> Node3D:
	var v := _variant(pos, 2)
	var mesh := _cached("nature_%s_%d" % [id, v], func(b: LowPoly):
		var leaf := L.LEAF_DARK if id == "bush" else L.LEAF
		b.ball(Vector3(0, 0.45, 0), 0.6, leaf, 1, Vector3(1.2, 0.8, 1.0))
		b.ball(Vector3(0.45, 0.35, 0.15), 0.42, L.shade(leaf, 0.08), 0)
		b.ball(Vector3(-0.4, 0.38 + v * 0.05, -0.1), 0.45, L.shade(leaf, -0.05), 1)
		if id == "bush_flowers":
			for i in 7:
				var a := i * 2.1
				b.ball(Vector3(cos(a) * 0.5, 0.55 + (i % 3) * 0.12, sin(a) * 0.45), 0.08, [L.ROSE, L.SUN, L.CLOUD][i % 3], 0))
	return _place(parent, mesh, pos, s, _yaw(pos))

# ---------- creatures ----------

## A living animal by id (cow, horse, sheep, fish, bird, eagle, whale, ...). Land animals wander near
## where they're put (never into water); fish and whales swim inside the water they're put in; birds
## fly in loops when put up in the air, or stand perched when put on the ground or a rock.
static func creature(parent: Node3D, id: String, pos: Vector3, s: float = 1.0) -> Node3D:
	var a := LowPolyAnimal.create(id, int(pos.x * 31.0 + pos.z * 7.0))
	a.position = pos
	a.home = pos
	a.rotation.y = _yaw(pos)
	a.scale = Vector3.ONE * s
	a.speed = 1.0 / maxf(0.5, s) if id in ["fish"] else 1.0
	match id:
		"fish", "whale":
			var r := water_at(pos)
			if r.size == Vector2.ZERO and not water_rects.is_empty():
				r = water_rects[-1]
			a.water = r
		"bird", "eagle":
			if pos.y < 1.5:
				a.mode = "perch"
			else:
				# Circle behind the path, so birds never fly right up into the camera.
				a.home.z = minf(a.home.z, 0.0) - 3.0
				a.radius = 3.0 + absf(fmod(pos.x, 3.0))
		_:
			a.avoid = func(p: Vector3) -> bool: return in_water(p)
	parent.add_child(a)
	return a

static func bird(parent: Node3D, pos: Vector3, _c: Color) -> void:
	creature(parent, "bird", pos, 1.0)

static func serpent(parent: Node3D, pos: Vector3) -> void:
	CharacterFactory.make("serpent", parent, pos, true)

static func cherub(parent: Node3D, pos: Vector3) -> void:
	CharacterFactory.make("cherub", parent, pos, true)

## The flaming sword which turned every way (Genesis 3:24): a faceted flame that flickers and turns.
static func flame(parent: Node3D, pos: Vector3) -> void:
	var f := Node3D.new()
	f.position = pos
	parent.add_child(f)
	var b := L.new()
	b.prism(Vector3.ZERO, 0.4, 0.0, 1.9, 6, L.glow(L.TERRACOTTA, 0.7))
	b.prism(Vector3(0, 0, 0), 0.24, 0.0, 1.35, 5, L.glow(L.SUN, 0.9), Color(), Vector2.ONE, 0.5)
	b.box(Vector3(0, 0.95, 0), Vector3(0.06, 1.6, 0.06), L.glow(L.CLOUD, 0.8))
	b.box(Vector3(0, 0.3, 0), Vector3(0.4, 0.07, 0.07), L.GOLD)
	var mi := b.instance(false)
	f.add_child(mi)
	var tw := mi.create_tween().set_loops()
	tw.tween_property(mi, "scale", Vector3(1.08, 1.12, 1.08), 0.18)
	tw.tween_property(mi, "scale", Vector3(0.95, 0.92, 0.95), 0.22)
	var spin := f.create_tween().set_loops()
	spin.tween_property(mi, "rotation:y", TAU, 3.0).from(0.0)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.6, 0.25)
	l.light_energy = 3.0
	l.omni_range = 9.0
	l.position = Vector3(0, 1.2, 0.5)
	f.add_child(l)

extends RefCounted
## Chapter 2's own low-poly props, built in code like the rest of the game (core/lowpoly):
## the family's tent of skins and cooking fire, Cain's crops and fences, Abel's sheepfold, the two
## offering stones, tall grain for the field, and the tents, houses and forge of Cain's city.

const L := preload("res://core/lowpoly/low_poly.gd")

static func _mesh(parent: Node3D, b: LowPoly, pos: Vector3, yaw: float = 0.0, shadows: bool = true) -> MeshInstance3D:
	var mi := b.instance(shadows)
	mi.position = pos
	mi.rotation.y = yaw
	mi.visibility_range_end = Props.FAR
	parent.add_child(mi)
	return mi

## A round tent of animal skins over a frame of poles, its door facing the path (+Z).
static func tent(parent: Node3D, pos: Vector3, s: float = 1.0, skin_c: Color = Color("a87a4a")) -> void:
	var b := L.new()
	b.prism(Vector3.ZERO, 1.5 * s, 0.12 * s, 2.1 * s, 7, skin_c)
	b.prism(Vector3(0, 0.55 * s, 0), 1.12 * s, 1.08 * s, 0.1 * s, 7, L.shade(skin_c, -0.18))
	for k in 4:
		var a := TAU * k / 4.0 + 0.4
		b.prism(Vector3(cos(a) * 0.05, 2.0 * s, sin(a) * 0.05), 0.03, 0.02, 0.45 * s, 4, L.WOOD_DARK)
	b.box(Vector3(0, 0.45 * s, 1.15 * s), Vector3(0.6 * s, 0.9 * s, 0.25 * s), Color("3a2a20"))
	_mesh(parent, b, pos)

## A cooking fire in a ring of stones, with a flickering flame and warm light.
static func campfire(parent: Node3D, pos: Vector3) -> void:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	var b := L.new()
	for k in 8:
		var a := TAU * k / 8.0
		b.ball(Vector3(cos(a) * 0.5, 0.06, sin(a) * 0.5), 0.13, L.STONE, 0, Vector3(1.2, 0.7, 1.0))
	for k in 3:
		var a := TAU * k / 3.0
		b.with(Transform3D(Basis(Vector3(cos(a), 0, sin(a)).cross(Vector3.UP).normalized(), 1.2), Vector3(0, 0.08, 0)), func():
			b.prism(Vector3(0, -0.3, 0), 0.05, 0.05, 0.6, 5, L.WOOD_DARK))
	n.add_child(b.instance())
	var f := L.new()
	f.prism(Vector3(0, 0.05, 0), 0.26, 0.0, 0.7, 5, L.glow(L.TERRACOTTA, 0.8))
	f.prism(Vector3(0, 0.05, 0), 0.15, 0.0, 0.5, 5, L.glow(L.SUN, 0.9), Color(), Vector2.ONE, 0.6)
	var flame := f.instance(false)
	n.add_child(flame)
	var tw := flame.create_tween().set_loops()
	tw.tween_property(flame, "scale", Vector3(1.1, 1.2, 1.1), 0.2)
	tw.tween_property(flame, "scale", Vector3(0.92, 0.85, 0.92), 0.25)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.65, 0.3)
	l.light_energy = 1.6
	l.omni_range = 5.0
	l.position = Vector3(0, 0.8, 0)
	n.add_child(l)

## A pile of split wood beside the tent.
static func woodpile(parent: Node3D, pos: Vector3) -> void:
	var b := L.new()
	for row in 3:
		for k in 4 - row:
			b.with(Transform3D(Basis(Vector3.FORWARD, PI / 2.0), Vector3(0, 0.1 + row * 0.17, (k - (3 - row) / 2.0) * 0.18)), func():
				b.prism(Vector3(0, -0.4, 0), 0.08, 0.08, 0.8, 6, L.shade(L.WOOD, -0.05 * k), L.WOOD_LIGHT))
	_mesh(parent, b, pos)

## A clay water jar.
static func jar(parent: Node3D, pos: Vector3) -> void:
	var b := L.new()
	b.ball(Vector3(0, 0.25, 0), 0.22, L.TERRACOTTA, 0, Vector3(1, 1.2, 1))
	b.prism(Vector3(0, 0.45, 0), 0.09, 0.11, 0.14, 6, L.shade(L.TERRACOTTA, -0.08))
	_mesh(parent, b, pos)

## A low wooden fence along x0..x1 at depth z.
static func fence(parent: Node3D, x0: float, x1: float, z: float) -> void:
	var b := L.new()
	var x := x0
	while x <= x1 + 0.01:
		b.box(Vector3(x - x0, 0.35, 0), Vector3(0.1, 0.7, 0.1), L.WOOD_DARK)
		x += 1.5
	for y in [0.28, 0.55]:
		b.box(Vector3((x1 - x0) / 2.0, y, 0), Vector3(x1 - x0, 0.06, 0.05), L.WOOD)
	_mesh(parent, b, Vector3(x0, 0, z))

## A crop plant in Cain's field: "wheat" (a clump of ripe grain), "gourd" (a vine with a gourd),
## "melon", or "sprout" (young green shoots). Returns the node, so it can be harvested.
static func crop(parent: Node3D, pos: Vector3, kind: String) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	var b := L.new()
	var v := absi(int(pos.x * 7.3 + pos.z * 13.1)) % 3
	match kind:
		"wheat":
			for k in 9:
				var a := TAU * k / 9.0 + v
				var r := 0.12 + 0.06 * (k % 3)
				var h := 0.75 + 0.1 * ((k + v) % 3)
				b.prism(Vector3(cos(a) * r, 0, sin(a) * r), 0.018, 0.012, h, 3, Color("b8963c"))
				b.ball(Vector3(cos(a) * r, h + 0.06, sin(a) * r), 0.045, Color("e3c25a"), 0, Vector3(1, 2.4, 1))
		"gourd", "melon":
			for k in 4:
				var a := TAU * k / 4.0 + v
				b.box(Vector3(cos(a) * 0.3, 0.05, sin(a) * 0.3), Vector3(0.28, 0.04, 0.2), L.LEAF)
			var c := Color("e0b83c") if kind == "gourd" else Color("5e9a3e")
			b.ball(Vector3(0.05, 0.17, 0), 0.19 if kind == "gourd" else 0.24, c, 1, Vector3(1.3, 0.9, 1.0) if kind == "melon" else Vector3(1.0, 1.3, 1.0))
			if kind == "melon":
				for k in 4:
					b.box(Vector3(0.05 + (k - 1.5) * 0.12, 0.2, 0.0), Vector3(0.03, 0.36, 0.48), Color("3f7a32"))
		_:
			for k in 5:
				var a := TAU * k / 5.0 + v
				b.with(Transform3D(Basis(Vector3(cos(a), 0, sin(a)).cross(Vector3.UP).normalized(), 0.4), Vector3.ZERO), func():
					b.box(Vector3(0, 0.12, 0), Vector3(0.07, 0.24, 0.02), L.shade(L.LEAF, 0.12)))
	var mi := b.instance()
	mi.visibility_range_end = Props.FAR
	n.add_child(mi)
	return n

## Abel's sheepfold: a round wall of piled stones with a gap toward the path (+Z).
static func sheepfold(parent: Node3D, center: Vector3, r: float) -> void:
	var b := L.new()
	var n := 22
	for k in n:
		var a := TAU * k / n
		if absf(wrapf(a - PI / 2.0, -PI, PI)) < 0.42:
			continue  # the gate
		var p := Vector3(cos(a) * r, 0, sin(a) * r)
		b.ball(p + Vector3(0, 0.18, 0), 0.26, L.shade(L.STONE, 0.04 * ((k * 7) % 3 - 1)), 0, Vector3(1.2, 0.75, 1.0))
		b.ball(p + Vector3(0, 0.42, 0), 0.2, L.shade(L.STONE, 0.08), 0, Vector3(1.1, 0.7, 1.0))
	_mesh(parent, b, center)

## A broad flat stone where an offering is laid.
static func offering_stone(parent: Node3D, pos: Vector3) -> void:
	var b := L.new()
	b.prism(Vector3.ZERO, 0.85, 0.75, 0.42, 7, L.STONE, L.shade(L.STONE, 0.12))
	b.ball(Vector3(0.7, 0.1, 0.4), 0.2, L.shade(L.STONE, -0.05), 0)
	_mesh(parent, b, pos)

## Cain's offering of the fruit of the ground: grain and gourds heaped on his stone.
static func produce_heap(parent: Node3D, pos: Vector3) -> void:
	var b := L.new()
	b.ball(Vector3(0.15, 0.12, 0.1), 0.17, Color("e0b83c"), 0, Vector3(1, 1.3, 1))
	b.ball(Vector3(-0.2, 0.12, -0.05), 0.2, Color("5e9a3e"), 0, Vector3(1.3, 0.9, 1))
	b.ball(Vector3(0.0, 0.1, -0.25), 0.12, Color("c8694a"), 0)
	for k in 5:
		b.with(Transform3D(Basis(Vector3.FORWARD, 1.3), Vector3(-0.05 + k * 0.05, 0.2, 0.22)), func():
			b.prism(Vector3(0, -0.3, 0), 0.015, 0.012, 0.6, 3, Color("c9a646")))
	_mesh(parent, b, pos)

## Soft smoke rising (puffs that float up, grow and fade, over and over).
static func smoke(parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	for k in 5:
		var p := Props.add(n, Props.sphere(0.22, 1.0, 6), Color(0.92, 0.92, 0.9, 0.35), Vector3.ZERO)
		var tw := p.create_tween().set_loops()
		tw.tween_interval(k * 0.6)
		tw.tween_property(p, "position", Vector3(0.15 * (k % 2 * 2 - 1), 2.6, -0.2), 3.0).from(Vector3(0, 0.1, 0))
		tw.parallel().tween_property(p, "scale", Vector3.ONE * 2.2, 3.0).from(Vector3.ONE * 0.6)
	return n

## A shaft of soft golden light from the sky: the LORD "had respect unto Abel and to his offering".
static func light_shaft(parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	Props.add(n, Props.cyl(0.55, 0.75, 30.0, 10), Color(1.0, 0.92, 0.6, 0.1), Vector3(0, 15.0, 0), 0.8)
	Props.add(n, Props.cyl(0.25, 0.35, 30.0, 8), Color(1.0, 0.95, 0.7, 0.14), Vector3(0, 15.0, 0), 1.2)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.9, 0.55)
	l.light_energy = 2.2
	l.omni_range = 5.0
	l.position = Vector3(0, 1.4, 0)
	n.add_child(l)
	return n

## A clump of tall grass or wild grain, about shoulder high, for the field.
static func tall_grass(parent: Node3D, pos: Vector3, c: Color = Color("b8a24e")) -> void:
	var b := L.new()
	var v := absi(int(pos.x * 7.3 + pos.z * 13.1)) % 3
	for k in 7:
		var a := TAU * k / 7.0 + v
		var r := 0.1 + 0.08 * (k % 3)
		b.with(Transform3D(Basis(Vector3(cos(a), 0, sin(a)).cross(Vector3.UP).normalized(), 0.12), Vector3(cos(a) * r, 0, sin(a) * r)), func():
			b.prism(Vector3.ZERO, 0.04, 0.0, 1.3 + 0.2 * ((k + v) % 3), 3, L.shade(c, -0.06 + 0.05 * (k % 3))))
	_mesh(parent, b, pos, 0.0, false)

## A cracked, dry patch of ground: a few dark flat shards.
static func cracks(parent: Node3D, pos: Vector3) -> void:
	var b := L.new()
	for k in 4:
		var a := TAU * k / 4.0 + pos.x
		b.with(Transform3D(Basis(Vector3.UP, a), Vector3.ZERO), func():
			b.box(Vector3(0.35, 0.02, 0), Vector3(0.7, 0.02, 0.04), Color("5a4532")))
	_mesh(parent, b, pos, 0.0, false)

## A small flat-roofed house of mud brick, for the city Cain builded (Genesis 4:17).
static func house(parent: Node3D, pos: Vector3, s: float = 1.0) -> void:
	var b := L.new()
	var brick := Color("b58a5e")
	b.box(Vector3(0, 0.8 * s, 0), Vector3(2.2 * s, 1.6 * s, 1.8 * s), brick, L.shade(brick, 0.08))
	b.box(Vector3(0, 1.65 * s, 0), Vector3(2.4 * s, 0.12 * s, 2.0 * s), L.shade(brick, -0.12))
	b.box(Vector3(0.3 * s, 0.5 * s, 0.91 * s), Vector3(0.5 * s, 1.0 * s, 0.04), Color("3a2a20"))
	b.box(Vector3(-0.55 * s, 1.0 * s, 0.91 * s), Vector3(0.35 * s, 0.3 * s, 0.04), Color("3a2a20"))
	_mesh(parent, b, pos)

## Tubalcain's forge: a clay furnace glowing inside, with an anvil stone (Genesis 4:22).
static func forge(parent: Node3D, pos: Vector3) -> void:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	var b := L.new()
	b.prism(Vector3.ZERO, 0.6, 0.35, 1.1, 7, Color("9a6a48"))
	b.box(Vector3(0, 0.35, 0.5), Vector3(0.36, 0.3, 0.1), L.glow(L.TERRACOTTA, 0.9))
	b.prism(Vector3(1.0, 0, 0.2), 0.3, 0.25, 0.45, 6, L.STONE)
	b.box(Vector3(1.0, 0.5, 0.2), Vector3(0.45, 0.1, 0.22), L.CONCRETE)
	n.add_child(b.instance())
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.55, 0.25)
	l.light_energy = 1.8
	l.omni_range = 4.0
	l.position = Vector3(0, 0.6, 0.8)
	n.add_child(l)

## Jubal's harp (Genesis 4:21): a wooden frame with strings, standing on a stone.
static func harp(parent: Node3D, pos: Vector3) -> void:
	var b := L.new()
	b.prism(Vector3.ZERO, 0.3, 0.28, 0.35, 6, L.STONE)
	b.box(Vector3(-0.2, 0.85, 0), Vector3(0.07, 1.0, 0.07), L.WOOD_DARK)
	b.box(Vector3(0.05, 1.32, 0), Vector3(0.55, 0.07, 0.07), L.WOOD_DARK)
	b.box(Vector3(0.05, 0.38, 0), Vector3(0.55, 0.07, 0.07), L.WOOD_DARK)
	for k in 5:
		b.box(Vector3(-0.1 + k * 0.08, 0.85, 0), Vector3(0.012, 0.9, 0.012), L.glow(L.SUN, 0.3))
	_mesh(parent, b, pos)

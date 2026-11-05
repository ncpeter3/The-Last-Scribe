class_name LowPoly
extends RefCounted
## The game's low-poly art kit: flat-shaded, faceted shapes colored from one small palette.
## Everything is built in code (no outside art), so the style stays consistent everywhere.
##
## Use a builder to add many shapes into one mesh (cheap to draw on phones):
##     var b := LowPoly.new()
##     b.box(Vector3(0, 0.5, 0), Vector3(1, 1, 1), LowPoly.WOOD)
##     b.prism(Vector3.ZERO, 0.4, 0.3, 1.0, 6, LowPoly.TEAL)
##     add_child(b.instance())
## Colors are vertex colors. A color's alpha below 1 makes it glow: glow(c, strength) sets that up.
## Shapes are placed with `at` (a Transform3D applied to everything added until it is changed).

# ---------- palette ----------
# A small shared palette keeps every scene and character in one look.
const INK := Color("1f2333")
const NIGHT := Color("2b3150")
const SLATE := Color("56659a")
const SLATE_LIGHT := Color("7684a8")
const CLOUD := Color("e8e4dc")
const BONE := Color("d9d0bf")
const STONE := Color("9a968f")
const CONCRETE := Color("6f7480")
const WOOD_DARK := Color("6b4a35")
const WOOD := Color("a8774f")
const WOOD_LIGHT := Color("d1a878")
const TERRACOTTA := Color("c8694a")
const ROSE := Color("d98a8a")
const BERRY := Color("9b4a6b")
const GOLD := Color("e8b64c")
const SUN := Color("f4d67a")
const LEAF := Color("6fa15a")
const LEAF_DARK := Color("3f7448")
const GRASS := Color("5b8a4c")
const TEAL := Color("3fd6c8")
const TEAL_DARK := Color("1f7f80")
const SKY := Color("8fc4e8")
const LAVENDER := Color("a69ad1")
const SKIN := Color("e0a882")
const SKIN_SHADE := Color("c98b67")
const HAIR_DARK := Color("4a3428")
const HAIR_BROWN := Color("8a5636")
const HAIR_GRAY := Color("d9d6d2")

static var _mat_solid: ShaderMaterial
static var _mat_clear: ShaderMaterial

## A palette color that glows. strength 0..1 (1 = bright neon).
static func glow(c: Color, strength: float = 0.6) -> Color:
	return Color(c.r, c.g, c.b, 1.0 - clampf(strength, 0.02, 1.0))

## Same color, lighter (t > 0) or darker (t < 0).
static func shade(c: Color, t: float) -> Color:
	var out := c.lightened(t) if t > 0.0 else c.darkened(-t)
	out.a = c.a
	return out

## The one material every low-poly mesh shares (transparent = glass and holograms).
static func material(transparent: bool = false) -> ShaderMaterial:
	if transparent:
		if _mat_clear == null:
			_mat_clear = ShaderMaterial.new()
			_mat_clear.shader = preload("res://core/lowpoly/low_poly_clear.gdshader")
		return _mat_clear
	if _mat_solid == null:
		_mat_solid = ShaderMaterial.new()
		_mat_solid.shader = preload("res://core/lowpoly/low_poly.gdshader")
	return _mat_solid

# ---------- builder ----------

var at := Transform3D.IDENTITY  ## applied to every shape added
var jitter := 0.035  ## how much each face's brightness varies, for the hand-cut faceted look
var transparent := false
var _st := SurfaceTool.new()
var _count := 0
var _seed := 0

func _init(clear: bool = false) -> void:
	transparent = clear
	_st.begin(Mesh.PRIMITIVE_TRIANGLES)

func is_empty() -> bool:
	return _count == 0

## Finish and return the mesh. The builder can't be used after this.
func mesh() -> ArrayMesh:
	if _count == 0:
		return null
	var m := _st.commit()
	m.surface_set_material(0, LowPoly.material(transparent))
	return m

## Finish and wrap the mesh in a MeshInstance3D (null if nothing was added).
func instance(shadows: bool = true) -> MeshInstance3D:
	var m := mesh()
	if m == null:
		return null
	var mi := MeshInstance3D.new()
	mi.mesh = m
	if not shadows or transparent:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

## Run `f` with `at` temporarily set to `t` (combined with the current one).
func with(t: Transform3D, f: Callable) -> void:
	var old := at
	at = at * t
	f.call()
	at = old

func tri(a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	a = at * a
	b = at * b
	c = at * c
	# Shapes here list corners counter-clockwise seen from outside; Godot wants clockwise, so the
	# vertices go in as a, c, b.
	var n := (b - a).cross(c - a)
	if n.length_squared() < 1e-12:
		return
	n = n.normalized()
	_seed += 1
	var k := 1.0 + (fmod(float(_seed) * 0.618034, 1.0) - 0.5) * 2.0 * jitter
	var lin := Color(color.r * k, color.g * k, color.b * k).srgb_to_linear()
	lin.a = color.a
	_st.set_color(lin)
	_st.set_normal(n)
	_st.add_vertex(a)
	_st.set_color(lin)
	_st.set_normal(n)
	_st.add_vertex(c)
	_st.set_color(lin)
	_st.set_normal(n)
	_st.add_vertex(b)
	_count += 1

## A four-sided face (corners in order around the edge, counter-clockwise seen from the front).
func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
	tri(a, b, c, color)
	tri(a, c, d, color)

## A box centered at `center`. `top` colors the top face differently (for counters, beds, ...).
## `bevel` cuts the top edges at an angle, which catches the light nicely.
func box(center: Vector3, size: Vector3, color: Color, top: Color = Color(0, 0, 0, 0), bevel: float = 0.0) -> void:
	var h := size / 2.0
	var tc := color if top.a == 0.0 and top.r == 0.0 and top.g == 0.0 and top.b == 0.0 else top
	var bv := minf(bevel, minf(h.x, h.z) * 0.9)
	var x0 := center.x - h.x
	var x1 := center.x + h.x
	var y0 := center.y - h.y
	var y1 := center.y + h.y
	var z0 := center.z - h.z
	var z1 := center.z + h.z
	var yb := y1 - bv
	# Sides (up to the bevel line), bottom.
	quad(Vector3(x0, y0, z1), Vector3(x1, y0, z1), Vector3(x1, yb, z1), Vector3(x0, yb, z1), color)
	quad(Vector3(x1, y0, z0), Vector3(x0, y0, z0), Vector3(x0, yb, z0), Vector3(x1, yb, z0), color)
	quad(Vector3(x1, y0, z1), Vector3(x1, y0, z0), Vector3(x1, yb, z0), Vector3(x1, yb, z1), color)
	quad(Vector3(x0, y0, z0), Vector3(x0, y0, z1), Vector3(x0, yb, z1), Vector3(x0, yb, z0), color)
	quad(Vector3(x0, y0, z0), Vector3(x1, y0, z0), Vector3(x1, y0, z1), Vector3(x0, y0, z1), shade(color, -0.2))
	if bv <= 0.0:
		quad(Vector3(x0, y1, z1), Vector3(x1, y1, z1), Vector3(x1, y1, z0), Vector3(x0, y1, z0), tc)
		return
	# Beveled top: an inset top face with four slanted strips around it.
	var a0 := Vector3(x0 + bv, y1, z1 - bv)
	var a1 := Vector3(x1 - bv, y1, z1 - bv)
	var a2 := Vector3(x1 - bv, y1, z0 + bv)
	var a3 := Vector3(x0 + bv, y1, z0 + bv)
	var e := shade(tc, 0.06)
	quad(a0, a1, a2, a3, tc)
	quad(Vector3(x0, yb, z1), Vector3(x1, yb, z1), a1, a0, e)
	quad(Vector3(x1, yb, z0), Vector3(x0, yb, z0), a3, a2, e)
	quad(Vector3(x1, yb, z1), Vector3(x1, yb, z0), a2, a1, e)
	quad(Vector3(x0, yb, z0), Vector3(x0, yb, z1), a0, a3, e)

## A many-sided column: `sides` 3..12, from radius `r0` at the bottom to `r1` at the top.
## `squash` stretches it along X and Z (Vector2(1, 0.6) makes an oval). `twist` turns it (radians).
func prism(base: Vector3, r0: float, r1: float, height: float, sides: int, color: Color,
		top: Color = Color(0, 0, 0, 0), squash: Vector2 = Vector2.ONE, twist: float = 0.0) -> void:
	var tc := color if top.a == 0.0 and top.r == 0.0 and top.g == 0.0 and top.b == 0.0 else top
	var lo: Array[Vector3] = []
	var hi: Array[Vector3] = []
	for i in sides:
		var a := TAU * i / sides + twist
		var d := Vector3(cos(a) * squash.x, 0, sin(a) * squash.y)
		lo.append(base + d * r0)
		hi.append(base + d * r1 + Vector3(0, height, 0))
	var top_c := base + Vector3(0, height, 0)
	for i in sides:
		var j := (i + 1) % sides
		if r1 <= 0.001:
			tri(lo[j], lo[i], top_c, color)
		else:
			quad(lo[j], lo[i], hi[i], hi[j], color)
			tri(top_c, hi[j], hi[i], tc)
		tri(base, lo[i], lo[j], shade(color, -0.2))

## A faceted ball (an icosphere). detail 0 = 20 faces, 1 = 80 faces. `scale` stretches it.
func ball(center: Vector3, radius: float, color: Color, detail: int = 1, scale: Vector3 = Vector3.ONE) -> void:
	for f in _ico(detail):
		tri(center + f[0] * radius * scale, center + f[1] * radius * scale, center + f[2] * radius * scale, color)

## Half a faceted ball (the top half), for hair caps, domes and bushes.
func dome(center: Vector3, radius: float, color: Color, detail: int = 1, scale: Vector3 = Vector3.ONE, cut: float = 0.0) -> void:
	for f in _ico(detail):
		if f[0].y < cut - 0.01 and f[1].y < cut - 0.01 and f[2].y < cut - 0.01:
			continue
		var a: Vector3 = f[0]
		var b: Vector3 = f[1]
		var c: Vector3 = f[2]
		a.y = maxf(a.y, cut)
		b.y = maxf(b.y, cut)
		c.y = maxf(c.y, cut)
		tri(center + a * radius * scale, center + b * radius * scale, center + c * radius * scale, color)

## A wedge (a ramp): full height at -Z, zero height at +Z.
func wedge(center: Vector3, size: Vector3, color: Color) -> void:
	var h := size / 2.0
	var p := [Vector3(-h.x, -h.y, -h.z), Vector3(h.x, -h.y, -h.z), Vector3(h.x, -h.y, h.z), Vector3(-h.x, -h.y, h.z),
		Vector3(-h.x, h.y, -h.z), Vector3(h.x, h.y, -h.z)]
	for i in p.size():
		p[i] += center
	quad(p[3], p[2], p[5], p[4], color)  # slope
	quad(p[1], p[0], p[4], p[5], color)  # back
	tri(p[0], p[3], p[4], color)
	tri(p[2], p[1], p[5], color)
	quad(p[0], p[1], p[2], p[3], shade(color, -0.2))

## A flat ring of quads lying on the ground (rugs, glowing floor rings).
func ring(center: Vector3, r_in: float, r_out: float, sides: int, color: Color, height: float = 0.02) -> void:
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var p0 := Vector3(cos(a0), 0, sin(a0))
		var p1 := Vector3(cos(a1), 0, sin(a1))
		var up := Vector3(0, height, 0)
		quad(center + p0 * r_in + up, center + p1 * r_in + up, center + p1 * r_out + up, center + p0 * r_out + up, color)
		quad(center + p1 * r_out, center + p0 * r_out, center + p0 * r_out + up, center + p1 * r_out + up, color)

## An upright ring (a torus with few sides), standing in the XY plane around `center`.
func hoop(center: Vector3, radius: float, thick: float, segments: int, color: Color, sides: int = 4) -> void:
	for i in segments:
		var a0 := TAU * i / segments
		var a1 := TAU * (i + 1) / segments
		var c0 := Vector3(cos(a0), sin(a0), 0)
		var c1 := Vector3(cos(a1), sin(a1), 0)
		for k in sides:
			var b0 := TAU * k / sides + PI / sides
			var b1 := TAU * (k + 1) / sides + PI / sides
			var q := func(c: Vector3, b: float) -> Vector3:
				return center + c * (radius + cos(b) * thick) + Vector3(0, 0, sin(b) * thick)
			quad(q.call(c0, b0), q.call(c1, b0), q.call(c1, b1), q.call(c0, b1), color)

# ---------- icosphere ----------

static var _ico_cache: Dictionary = {}

static func _ico(detail: int) -> Array:
	if _ico_cache.has(detail):
		return _ico_cache[detail]
	var t := (1.0 + sqrt(5.0)) / 2.0
	var v := [Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0),
		Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t),
		Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1)]
	var idx := [[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11], [1, 5, 9], [5, 11, 4], [11, 10, 2],
		[10, 7, 6], [7, 1, 8], [3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9], [4, 9, 5], [2, 4, 11],
		[6, 2, 10], [8, 6, 7], [9, 8, 1]]
	var faces := []
	for f in idx:
		faces.append([(v[f[0]] as Vector3).normalized(), (v[f[1]] as Vector3).normalized(), (v[f[2]] as Vector3).normalized()])
	for d in detail:
		var out := []
		for f in faces:
			var a: Vector3 = f[0]
			var b: Vector3 = f[1]
			var c: Vector3 = f[2]
			var ab := ((a + b) / 2.0).normalized()
			var bc := ((b + c) / 2.0).normalized()
			var ca := ((c + a) / 2.0).normalized()
			out.append([a, ab, ca])
			out.append([b, bc, ab])
			out.append([c, ca, bc])
			out.append([ab, bc, ca])
		faces = out
	# Wind every face counter-clockwise seen from outside, like the other shapes.
	for f in faces:
		var a: Vector3 = f[0]
		var b: Vector3 = f[1]
		var c: Vector3 = f[2]
		if (b - a).cross(c - a).dot(a + b + c) < 0.0:
			f[1] = c
			f[2] = b
	_ico_cache[detail] = faces
	return faces

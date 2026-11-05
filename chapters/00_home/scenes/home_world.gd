extends Node3D
## The scribe's home in 2060, built entirely from the low-poly kit (core/lowpoly): a big family house
## with three bedrooms, three bathrooms, a hallway, kitchen, living room and family room, a two-car
## garage full of tools and machine parts with the time machine at the back, the yard, and the city
## skyline behind. home.gd adds the people and the story on top. Distances are in meters; the camera
## looks toward -Z, so every inside wall is kept low ("cutaway") and never hides anyone.
##
## Layout (x left to right, z back to front):
##   back row z -12..-6.5:  your bedroom x -18..-11 | bath 1 x -11..-8 | Sam & Lily's room x -8..-1 |
##                          bath 2 x -1..2 | Mom & Dad's room x 2..7 | their bath x 7..10
##   hallway z -6.5..-4.5, x -18..10
##   front row z -4.5..6:   kitchen x -18..-9 | living room x -9..1 | family room x 1..10
##   garage x 10..20, z -12..6 (time machine at the back, the car and the parts bay in front)

const L := preload("res://core/lowpoly/low_poly.gd")

const HOUSE := Rect2(-18.0, -12.0, 38.0, 18.0)
const TALL := 2.9
const LOW := 1.0
const T := 0.3  # wall thickness
const WALL := Color("ece6da")
const WALL_SHADE := Color("cfc6b6")
const BASE := Color("8d8478")
const TILE := Color("dfe7ea")
const MACHINE := Vector3(15.5, 0, -9.4)
const BACK_ROW := -6.5  # front edge of the bedrooms and bathrooms
const FRONT_ROW := -4.5  # back edge of kitchen, living and family rooms

## Rectangles on the floor (x, z) the scribe can't walk through.
var blockers: Array[Rect2] = []
## 0..1 how hard the time machine is running; home.gd raises it at departure.
var spin := 0.0
var machine_light: OmniLight3D

var _b: LowPoly  # solid geometry for the whole house, drawn as one mesh
var _glass: LowPoly
var _rings: Array[Node3D] = []
var _machine_mat: ShaderMaterial
var _core: MeshInstance3D
var _crystals: Array[Node3D] = []
var _cars: Array[Node3D] = []
var _blinkers: Array[Node3D] = []
var _screen: MeshInstance3D
var _fire: Array[Node3D] = []
var _t := 0.0

func _ready() -> void:
	_b = L.new()
	_glass = L.new(true)
	_ground()
	_floors()
	_walls()
	_my_room()
	_kids_room()
	_parents_room()
	_bathroom(Rect2(-11, -12, 3, 5.5), L.SKY, "tub")
	_bathroom(Rect2(-1, -12, 3, 5.5), L.SUN, "shower")
	_bathroom(Rect2(7, -12, 3, 5.5), L.LAVENDER, "tub")
	_hallway()
	_kitchen()
	_living_room()
	_family_room()
	_garage()
	_yard()
	_city()
	add_child(_b.instance())
	add_child(_glass.instance(false))
	_machine()
	_holo_screen()
	_lights()
	_particles()

func _process(delta: float) -> void:
	_t += delta
	var s := 1.0 + spin * 14.0
	for i in _rings.size():
		_rings[i].rotate_object_local(Vector3.FORWARD if i == 0 else Vector3.UP, delta * (0.35 + 0.25 * i) * s * (1.0 if i % 2 == 0 else -1.0))
	if _machine_mat:
		_machine_mat.set_shader_parameter("glow_power", 4.0 + sin(_t * 2.2) * 1.2 + spin * 10.0)
	if _core:
		var p := 1.0 + sin(_t * 3.0) * 0.04 + spin * 0.25
		_core.scale = Vector3(p, p, 1.0)
	for i in _crystals.size():
		var c := _crystals[i]
		c.position.y = 1.0 + sin(_t * 1.6 + i * 1.3) * 0.12 + spin * 0.8
		c.rotation.y += delta * (0.6 + spin * 6.0)
	if machine_light:
		machine_light.light_energy = 2.2 + sin(_t * 2.2) * 0.4 + spin * 10.0
	for c in _cars:
		c.position.x += delta * float(c.get_meta("speed"))
		if c.position.x > 60.0:
			c.position.x = -60.0
		elif c.position.x < -60.0:
			c.position.x = 60.0
	for i in _blinkers.size():
		_blinkers[i].visible = fmod(_t + i * 0.37, 2.0) < 0.25
	if _screen:
		_screen.position.y = 1.35 + sin(_t * 1.3) * 0.03
	for i in _fire.size():
		var f := _fire[i]
		var k := 1.0 + sin(_t * (6.0 + i * 1.7) + i) * 0.18
		f.scale = Vector3(1.0, k, 1.0)

func _block(r: Rect2) -> void:
	blockers.append(r)

## A box sitting on the floor at (x, z) with its footprint w x d; optionally solid to walking.
func _floor_box(x: float, z: float, w: float, d: float, h: float, c: Color, top: Color = Color(0, 0, 0, 0),
		bevel: float = 0.0, solid: bool = true, y: float = 0.0) -> void:
	_b.box(Vector3(x, y + h / 2.0, z), Vector3(w, h, d), c, top, bevel)
	if solid:
		_block(Rect2(x - w / 2.0, z - d / 2.0, w, d))

# ---------- ground, floors, walls ----------

func _ground() -> void:
	# Evening lawn all around, a little lower than the floors.
	_b.box(Vector3(1, -0.2, -6), Vector3(140, 0.2, 100), L.shade(L.GRASS, -0.35))
	# Foundation the house sits on.
	_b.box(Vector3(1, -0.12, -3), Vector3(38.8, 0.16, 18.8), BASE)

## Wood planks running left to right across a room, each one a slightly different shade.
func _planks(r: Rect2, base: Color) -> void:
	var plank := 0.42
	var z := r.position.y
	var i := 0
	while z < r.end.y - 0.01:
		var d := minf(plank, r.end.y - z)
		var c := L.shade(base, [0.0, -0.05, 0.04, -0.02][i % 4])
		_b.box(Vector3(r.get_center().x, -0.03, z + d / 2.0), Vector3(r.size.x, 0.06, d - 0.015), c)
		z += d
		i += 1

## Square tiles in two colors.
func _tiles(r: Rect2, tile: float, a: Color, b: Color) -> void:
	for ix in range(int(ceil(r.size.x / tile))):
		for iz in range(int(ceil(r.size.y / tile))):
			var x0 := r.position.x + ix * tile
			var z0 := r.position.y + iz * tile
			var w := minf(tile, r.end.x - x0)
			var d := minf(tile, r.end.y - z0)
			if w <= 0.01 or d <= 0.01:
				continue
			_b.box(Vector3(x0 + w / 2.0, -0.03, z0 + d / 2.0), Vector3(w - 0.02, 0.06, d - 0.02), a if (ix + iz) % 2 == 0 else b)

func _floors() -> void:
	_planks(Rect2(-18, -12, 7, 5.5), L.WOOD_LIGHT)  # your room
	_planks(Rect2(-8, -12, 7, 5.5), L.shade(L.WOOD_LIGHT, 0.05))  # Sam and Lily
	_planks(Rect2(2, -12, 5, 5.5), L.WOOD)  # Mom and Dad
	_planks(Rect2(-18, -6.5, 28, 2.0), L.WOOD_DARK)  # hallway
	_planks(Rect2(-9, -4.5, 10, 10.5), L.WOOD)  # living room
	_planks(Rect2(1, -4.5, 9, 10.5), L.shade(L.WOOD, -0.08))  # family room
	for x0 in [-11.0, -1.0, 7.0]:  # bathrooms
		_tiles(Rect2(x0, -12, 3, 5.5), 0.5, TILE, L.shade(TILE, -0.1))
	_tiles(Rect2(-18, -4.5, 9, 10.5), 0.75, L.CLOUD, L.shade(L.STONE, 0.15))  # kitchen
	# Garage: concrete slabs with seams, oil stains, and glowing guide lines to the machine.
	for ix in 5:
		for iz in 6:
			_b.box(Vector3(11.0 + ix * 2.0, -0.03, -10.5 + iz * 3.0), Vector3(1.96, 0.06, 2.96),
				L.shade(L.CONCRETE, [0.0, 0.04, -0.03][(ix + iz) % 3]))
	for p in [Vector3(12.6, 0, 3.4), Vector3(17.8, 0, 2.2), Vector3(14.4, 0, -4.4)]:
		_b.prism(p + Vector3(0, 0.005, 0), 0.5, 0.5, 0.01, 9, L.shade(L.INK, 0.15), Color(), Vector2(1.3, 0.8))
	for x in [MACHINE.x - 0.7, MACHINE.x + 0.7]:
		_b.box(Vector3(x, 0.01, -5.4), Vector3(0.07, 0.02, 4.6), L.glow(L.TEAL, 0.4))
	for i in 6:  # yellow and black safety stripes in front of the platform
		_b.box(Vector3(MACHINE.x - 1.5 + i * 0.6, 0.01, MACHINE.z + 2.4), Vector3(0.3, 0.02, 0.22), L.GOLD if i % 2 == 0 else L.INK)
	# Parking lines for the two bays.
	for x in [10.6, 15.0, 19.4]:
		_b.box(Vector3(x, 0.01, 2.0), Vector3(0.1, 0.02, 5.0), L.SUN)

## A wall from (x0, z0) to (x1, z1) (axis-aligned), `h` high. Low walls get a wooden cap and a glow strip.
func _wall(x0: float, z0: float, x1: float, z1: float, h: float, solid: bool = true) -> void:
	var size := Vector3(x1 - x0, h, z1 - z0)
	var c := Vector3((x0 + x1) / 2.0, h / 2.0, (z0 + z1) / 2.0)
	_b.box(c, size, WALL)
	_b.box(Vector3(c.x, 0.09, c.z), size + Vector3(0.04, 0.18 - h, 0.04), WALL_SHADE)  # skirting
	if h < TALL:
		_b.box(Vector3(c.x, h + 0.03, c.z), size + Vector3(0.08, 0.06 - h, 0.08), L.WOOD_DARK)
		_b.box(Vector3(c.x, h - 0.08, c.z), size + Vector3(0.02, 0.05 - h, 0.02), L.glow(L.TEAL, 0.35))
	else:
		_b.box(Vector3(c.x, h + 0.04, c.z), size + Vector3(0.06, 0.08 - h, 0.06), L.shade(WALL, -0.15))
	if solid:
		_block(Rect2(x0, z0, x1 - x0, z1 - z0))

## A low wall along X at z from x0 to x1, leaving gaps (doorways) given as [from, to] pairs.
func _wall_x(z: float, x0: float, x1: float, gaps: Array, h: float = LOW) -> void:
	var x := x0
	for g in gaps:
		if g[0] > x:
			_wall(x, z - T / 2.0, g[0], z + T / 2.0, h)
		for gx in [g[0], g[1]]:  # door posts
			_b.box(Vector3(gx, 0.6, z), Vector3(0.12, 1.2, 0.36), L.WOOD_DARK)
		x = g[1]
	if x < x1:
		_wall(x, z - T / 2.0, x1, z + T / 2.0, h)

## The same for a low wall along Z at x.
func _wall_z(x: float, z0: float, z1: float, gaps: Array, h: float = LOW) -> void:
	var z := z0
	for g in gaps:
		if g[0] > z:
			_wall(x - T / 2.0, z, x + T / 2.0, g[0], h)
		for gz in [g[0], g[1]]:
			_b.box(Vector3(x, 0.6, gz), Vector3(0.36, 1.2, 0.12), L.WOOD_DARK)
		z = g[1]
	if z < z1:
		_wall(x - T / 2.0, z, x + T / 2.0, z1, h)

func _walls() -> void:
	# Back wall, with windows over each bedroom.
	var back := -12.0 - T
	var spans := [[-18.3, -16.2, false], [-16.2, -13.0, true], [-13.0, -6.2, false], [-6.2, -2.8, true],
		[-2.8, 3.0, false], [3.0, 6.0, true], [6.0, 20.3, false]]
	for s in spans:
		if not s[2]:
			_wall(s[0], back, s[1], -12.0, TALL)
			continue
		_wall(s[0], back, s[1], -12.0, 0.85)
		_b.box(Vector3((s[0] + s[1]) / 2.0, 2.55, -12.15), Vector3(s[1] - s[0], 0.7, T), WALL)
		_b.box(Vector3((s[0] + s[1]) / 2.0, 2.94, -12.15), Vector3(s[1] - s[0] + 0.06, 0.08, T + 0.06), L.shade(WALL, -0.15))
		_window(s[0], s[1])
	# Side walls (tall) and the low front wall, with the front door at x -1..1.
	_wall(-18.3, back, -18.0, 6.3, TALL)
	_wall(20.0, back, 20.3, 6.3, TALL)
	_wall(-18.3, 6.0, -1.0, 6.3, 0.55)
	_wall(1.0, 6.0, 10.0, 6.3, 0.55)
	_b.box(Vector3(0, 0.02, 6.15), Vector3(2.0, 0.04, 0.4), L.WOOD_DARK)  # door sill (the door is locked tonight)
	_block(Rect2(-1.0, 6.0, 2.0, 0.3))
	# The garage front: two wide doors, lowered and shut, with a low wall between them.
	for gx in [12.8, 17.2]:
		_b.box(Vector3(gx, 0.3, 6.15), Vector3(4.0, 0.6, 0.16), L.shade(L.STONE, 0.1))
		for i in 3:
			_b.box(Vector3(gx, 0.12 + i * 0.18, 6.24), Vector3(3.9, 0.03, 0.02), L.shade(L.STONE, -0.2))
		_b.box(Vector3(gx, 0.62, 6.15), Vector3(4.0, 0.05, 0.2), L.glow(L.SUN, 0.4))
	_wall(10.0, 6.0, 10.8, 6.3, 0.55)
	_wall(14.8, 6.0, 15.2, 6.3, 0.55)
	_wall(19.2, 6.0, 20.0, 6.3, 0.55)
	_block(Rect2(10.0, 6.0, 10.0, 0.3))
	# Bedrooms and bathrooms open onto the hallway; Mom and Dad's bath opens off their room.
	_wall_x(BACK_ROW, -18.0, 10.0, [[-14.2, -12.8], [-10.2, -8.8], [-5.2, -3.8], [-0.2, 1.2], [3.8, 5.2]])
	for x in [-11.0, -8.0, -1.0, 2.0]:
		_wall_z(x, -12.0, BACK_ROW - T / 2.0, [])
	_wall_z(7.0, -12.0, BACK_ROW - T / 2.0, [[-9.8, -8.4]])
	# Hallway / front rooms: wide openings into the kitchen, living room and family room.
	_wall_x(FRONT_ROW, -18.0, 10.0, [[-14.6, -12.4], [-6.4, -5.2], [-2.8, -1.6], [3.6, 7.2]])
	# Kitchen / living room and living room / family room, open in the middle.
	_wall_z(-9.0, FRONT_ROW + T / 2.0, 6.0, [[-2.2, 3.4]])
	_wall_z(1.0, FRONT_ROW + T / 2.0, 6.0, [[-2.4, 2.2]])
	# House / garage: a door at the end of the hall and one from the family room.
	_wall_z(10.0, -12.0, 6.0, [[-6.3, -4.7], [-1.6, 0.2]])

func _window(x0: float, x1: float) -> void:
	var cx := (x0 + x1) / 2.0
	var w := x1 - x0
	_glass.box(Vector3(cx, 1.7, -12.15), Vector3(w, 1.7, 0.04), L.glow(L.SKY, 0.15))
	_b.box(Vector3(cx, 0.88, -12.05), Vector3(w + 0.1, 0.07, 0.4), L.WOOD_DARK)  # sill
	_b.box(Vector3(cx, 2.2, -12.15), Vector3(w, 0.08, T + 0.04), L.WOOD_DARK)
	var n := maxi(2, int(w / 1.3))
	for i in n + 1:
		_b.box(Vector3(x0 + w * i / n, 1.55, -12.15), Vector3(0.08, 1.3, T + 0.04), L.WOOD_DARK)
	_b.box(Vector3(cx, 1.55, -12.15), Vector3(w, 0.05, 0.1), L.WOOD_DARK)

# ---------- furniture helpers ----------

func _plant(x: float, z: float, s: float = 1.0, pot: Color = L.TERRACOTTA) -> void:
	_b.prism(Vector3(x, 0, z), 0.2 * s, 0.26 * s, 0.42 * s, 7, pot, L.shade(L.HAIR_BROWN, -0.3))
	_b.ball(Vector3(x, 0.72 * s, z), 0.34 * s, L.LEAF, 1, Vector3(1, 1.2, 1))
	_b.ball(Vector3(x + 0.15 * s, 0.98 * s, z - 0.05), 0.22 * s, L.shade(L.LEAF, 0.1), 0)
	_b.ball(Vector3(x - 0.17 * s, 0.9 * s, z + 0.08), 0.2 * s, L.LEAF_DARK, 0)
	_block(Rect2(x - 0.25 * s, z - 0.25 * s, 0.5 * s, 0.5 * s))

func _rug(c: Vector3, size: Vector2, base: Color, border: Color) -> void:
	_b.box(c + Vector3(0, 0.012, 0), Vector3(size.x, 0.024, size.y), border)
	_b.box(c + Vector3(0, 0.03, 0), Vector3(size.x - 0.3, 0.02, size.y - 0.3), base)

func _chair(x: float, z: float, yaw: float, c: Color) -> void:
	_b.with(Transform3D(Basis(Vector3.UP, yaw), Vector3(x, 0, z)), func():
		for p in [Vector2(-0.18, -0.18), Vector2(0.18, -0.18), Vector2(-0.18, 0.18), Vector2(0.18, 0.18)]:
			_b.box(Vector3(p.x, 0.22, p.y), Vector3(0.05, 0.44, 0.05), L.WOOD_DARK)
		_b.box(Vector3(0, 0.46, 0), Vector3(0.46, 0.06, 0.46), c, Color(), 0.02)
		_b.box(Vector3(-0.21, 0.78, 0), Vector3(0.05, 0.6, 0.44), c))
	_block(Rect2(x - 0.25, z - 0.25, 0.5, 0.5))

func _armchair(c: Vector3, yaw: float) -> void:
	var col := L.shade(L.TERRACOTTA, -0.1)
	_b.with(Transform3D(Basis(Vector3.UP, yaw), c), func():
		_b.box(Vector3(0.05, 0.22, 0), Vector3(0.75, 0.36, 0.78), col, Color(), 0.05)
		_b.box(Vector3(0.12, 0.44, 0), Vector3(0.6, 0.1, 0.6), L.shade(col, 0.15), Color(), 0.04)
		_b.box(Vector3(-0.32, 0.7, 0), Vector3(0.18, 0.95, 0.8), col, Color(), 0.06)
		for z in [-0.36, 0.36]:
			_b.box(Vector3(0.05, 0.5, z), Vector3(0.75, 0.22, 0.12), col, Color(), 0.04)
		_b.box(Vector3(-0.2, 0.62, 0.0), Vector3(0.1, 0.4, 0.5), L.LAVENDER, Color(), 0.04))
	_block(Rect2(c.x - 0.4, c.z - 0.4, 0.8, 0.8))

func _bookshelf(c: Vector3) -> void:
	_floor_box(c.x, c.z + 0.05, 2.0, 0.42, 2.1, L.WOOD_DARK, Color(), 0.02)
	for i in 4:
		_b.box(Vector3(c.x, 0.25 + i * 0.5, c.z + 0.2), Vector3(1.86, 0.04, 0.12), L.WOOD)
	# Photo frames on the shelves...
	var frames := [[-0.6, 0, L.SUN], [0.1, 0, L.SKY], [0.6, 1, L.ROSE], [-0.4, 2, L.LEAF], [0.5, 2, L.LAVENDER], [-0.6, 3, L.CLOUD]]
	for f in frames:
		var y := 0.42 + int(f[1]) * 0.5
		_b.box(Vector3(c.x + f[0], y, c.z + 0.22), Vector3(0.24, 0.3, 0.04), L.GOLD)
		_b.box(Vector3(c.x + f[0], y, c.z + 0.245), Vector3(0.18, 0.23, 0.01), f[2])
	# ...and one empty spot, "saved for the Book", with a soft glow.
	_b.box(Vector3(c.x - 0.05, 0.92, c.z + 0.12), Vector3(0.56, 0.36, 0.02), L.glow(L.SUN, 0.35))
	_b.box(Vector3(c.x - 0.05, 0.76, c.z + 0.24), Vector3(0.3, 0.035, 0.04), L.GOLD)

## A bed against the back wall: frame, headboard, mattress, quilt with a folded band, pillows.
func _bed(x: float, w: float, quilt: Color, frame: Color = L.WOOD, pillows: int = 1) -> void:
	var z := -10.85
	_floor_box(x, z, w, 2.3, 0.32, frame)
	_b.box(Vector3(x, 0.62, -11.95), Vector3(w + 0.1, 1.0, 0.12), L.shade(frame, -0.2), Color(), 0.03)
	_b.box(Vector3(x, 0.42, z), Vector3(w - 0.14, 0.16, 2.12), L.CLOUD)
	_b.box(Vector3(x, 0.53, z + 0.4), Vector3(w - 0.08, 0.08, 1.4), quilt, Color(), 0.03)
	_b.box(Vector3(x, 0.58, z + 0.85), Vector3(w - 0.06, 0.06, 0.5), L.shade(quilt, 0.2))
	for i in pillows:
		var px := x + (0.0 if pillows == 1 else (-0.42 + i * 0.84) * w / 2.0)
		_b.box(Vector3(px, 0.6, -11.55), Vector3(minf(1.1, w / pillows - 0.15), 0.16, 0.42), L.BONE, Color(), 0.06)

func _nightstand(x: float, lamp: Color = L.SUN) -> void:
	_floor_box(x, -11.7, 0.5, 0.45, 0.5, L.WOOD, Color(), 0.03)
	_b.prism(Vector3(x, 0.5, -11.7), 0.08, 0.06, 0.25, 6, L.INK)
	_b.prism(Vector3(x, 0.72, -11.7), 0.18, 0.1, 0.2, 6, L.glow(lamp, 0.5))

func _picture(x: float, z: float, y: float, c: Color, w: float = 0.5, h: float = 0.4) -> void:
	_b.box(Vector3(x, y, z), Vector3(w, h, 0.04), L.GOLD)
	_b.box(Vector3(x, y, z + 0.025), Vector3(w - 0.08, h - 0.08, 0.01), c)

# ---------- rooms ----------

func _my_room() -> void:
	# Your bed, with a teal quilt and a star-patterned throw.
	_bed(-16.7, 1.7, L.TEAL_DARK)
	_nightstand(-15.4)
	# A trunk at the foot of the bed, with your satchel open on top, waiting to be packed.
	_floor_box(-16.7, -9.25, 1.3, 0.55, 0.42, L.WOOD_DARK, L.WOOD, 0.04)
	_b.box(Vector3(-16.7, 0.24, -8.97), Vector3(1.32, 0.05, 0.02), L.GOLD)
	_b.box(Vector3(-17.0, 0.55, -9.25), Vector3(0.42, 0.26, 0.2), L.WOOD, Color(), 0.04)
	_b.box(Vector3(-17.0, 0.7, -9.1), Vector3(0.4, 0.04, 0.24), L.WOOD_DARK)  # open flap
	# Desk by the window, with a tablet projecting a glowing page.
	_floor_box(-12.6, -11.65, 1.8, 0.65, 0.76, L.WOOD_LIGHT, L.WOOD_LIGHT, 0.02)
	_b.box(Vector3(-12.6, 0.38, -11.65), Vector3(1.6, 0.7, 0.55), L.shade(L.WOOD_LIGHT, -0.15))
	_b.box(Vector3(-12.2, 0.78, -11.55), Vector3(0.5, 0.03, 0.36), L.INK)
	_glass.box(Vector3(-12.2, 1.22, -11.62), Vector3(0.72, 0.5, 0.02), L.glow(L.TEAL, 0.8))
	for i in 3:
		_b.box(Vector3(-12.2, 1.36 - i * 0.12, -11.6), Vector3(0.5 - (i % 2) * 0.12, 0.03, 0.01), L.glow(L.CLOUD, 0.6))
	_chair(-12.6, -10.9, PI / 2.0, L.TEAL_DARK)
	# Star maps on the pinboard, a tall bookcase of empty shelves, a beanbag, a rug and plants.
	_b.box(Vector3(-14.4, 1.75, -11.99), Vector3(1.1, 0.8, 0.04), L.WOOD)
	for i in 4:
		_b.box(Vector3(-14.7 + (i % 2) * 0.55, 1.95 - (i / 2) * 0.38, -11.96), Vector3(0.38, 0.28, 0.02), [L.NIGHT, L.CLOUD, L.SUN, L.SKY][i])
	_floor_box(-17.75, -7.6, 0.45, 1.4, 1.8, L.WOOD_DARK, Color(), 0.02)
	for i in 3:
		_b.box(Vector3(-17.55, 0.4 + i * 0.55, -7.6), Vector3(0.06, 0.04, 1.3), L.WOOD)
	_b.box(Vector3(-17.55, 0.55, -7.9), Vector3(0.08, 0.26, 0.18), L.TERRACOTTA)
	_b.ball(Vector3(-12.0, 0.25, -7.6), 0.42, L.SUN, 1, Vector3(1.0, 0.65, 1.0))
	_rug(Vector3(-14.4, 0, -8.8), Vector2(2.8, 2.0), L.LAVENDER, L.shade(L.LAVENDER, -0.25))
	_plant(-11.5, -7.1, 0.9, L.CLOUD)

func _kids_room() -> void:
	# A bunk bed for Sam (top, rocket quilt) and Lily (bottom, flower quilt).
	var x := -6.9
	_floor_box(x, -10.85, 1.6, 2.2, 0.3, L.WOOD)
	for p in [Vector2(-0.75, -1.05), Vector2(0.75, -1.05), Vector2(-0.75, 1.05), Vector2(0.75, 1.05)]:
		_b.box(Vector3(x + p.x, 0.95, -10.85 + p.y), Vector3(0.1, 1.9, 0.1), L.WOOD_DARK)
	_b.box(Vector3(x, 0.4, -10.85), Vector3(1.44, 0.14, 2.06), L.CLOUD)
	_b.box(Vector3(x, 0.5, -10.45), Vector3(1.48, 0.07, 1.3), L.ROSE, Color(), 0.03)
	for i in 4:
		_b.ball(Vector3(x - 0.45 + i * 0.3, 0.55, -10.1 - (i % 2) * 0.5), 0.06, L.SUN, 0, Vector3(1, 0.3, 1))
	_b.box(Vector3(x, 1.35, -10.85), Vector3(1.5, 0.12, 2.12), L.WOOD)
	_b.box(Vector3(x, 1.47, -10.85), Vector3(1.44, 0.12, 2.06), L.CLOUD)
	_b.box(Vector3(x, 1.56, -10.45), Vector3(1.48, 0.07, 1.3), L.SKY, Color(), 0.03)
	_b.box(Vector3(x, 1.75, -9.8), Vector3(1.5, 0.06, 0.06), L.WOOD_DARK)  # top rail
	for i in 4:  # ladder
		_b.box(Vector3(x + 0.88, 0.35 + i * 0.38, -9.95), Vector3(0.05, 0.05, 0.42), L.WOOD_DARK)
	# Little drawing table where Lily works, scattered with drawings and crayons.
	var t := Vector3(-4.0, 0, -9.2)
	_floor_box(t.x, t.z, 1.2, 0.8, 0.45, L.WOOD_LIGHT, L.CLOUD, 0.02)
	for i in 4:
		_b.box(t + Vector3(-0.35 + i * 0.24, 0.47, -0.1 + (i % 2) * 0.18), Vector3(0.22, 0.01, 0.28), [L.CLOUD, L.SUN, L.SKY, L.ROSE][i])
	for i in 5:
		_b.box(t + Vector3(0.3 + i * 0.05, 0.47, 0.25), Vector3(0.025, 0.025, 0.12), [L.TERRACOTTA, L.LEAF, L.SKY, L.BERRY, L.SUN][i])
	# Toy chest, a toy robot, a play tent, posters and a star night-light.
	_floor_box(-2.0, -11.6, 1.0, 0.6, 0.5, L.TERRACOTTA, L.shade(L.TERRACOTTA, 0.15), 0.04)
	_b.box(Vector3(-2.0, 0.3, -11.29), Vector3(0.3, 0.12, 0.02), L.GOLD)
	var r := Vector3(-2.2, 0, -7.6)
	_b.box(r + Vector3(0, 0.18, 0), Vector3(0.26, 0.24, 0.18), L.STONE, Color(), 0.03)
	_b.box(r + Vector3(0, 0.4, 0), Vector3(0.2, 0.18, 0.16), L.shade(L.STONE, 0.15), Color(), 0.03)
	for s in [-1.0, 1.0]:
		_b.box(r + Vector3(0.05 * s, 0.42, 0.085), Vector3(0.04, 0.04, 0.02), L.glow(L.TEAL, 0.9))
		_b.box(r + Vector3(0.17 * s, 0.2, 0), Vector3(0.05, 0.18, 0.06), L.STONE)
	_b.prism(r + Vector3(0, 0.49, 0), 0.01, 0.01, 0.14, 4, L.INK)
	_b.ball(r + Vector3(0, 0.64, 0), 0.03, L.glow(L.TERRACOTTA, 1.0), 0)
	_block(Rect2(r.x - 0.2, r.z - 0.15, 0.4, 0.3))
	_b.prism(Vector3(-2.0, 0, -9.6), 0.75, 0.0, 1.3, 4, L.shade(L.SUN, -0.05), Color(), Vector2.ONE, PI / 4.0)
	_block(Rect2(-2.55, -10.15, 1.1, 1.1))
	_picture(-5.0, -11.98, 1.8, L.SKY, 0.6, 0.8)
	_picture(-3.3, -11.98, 1.7, L.LEAF, 0.7, 0.5)
	_b.ball(Vector3(-7.85, 0.6, -8.0), 0.12, L.glow(L.SUN, 1.0), 0, Vector3(1, 1, 0.4))
	_rug(Vector3(-4.6, 0, -8.4), Vector2(3.0, 2.2), L.shade(L.LEAF, 0.2), L.LEAF_DARK)

func _parents_room() -> void:
	_bed(4.5, 2.2, L.shade(L.BERRY, 0.1), L.WOOD_DARK, 2)
	_nightstand(3.1)
	_nightstand(5.9)
	# Dresser with their wedding photo, a wardrobe, and a reading chair.
	_floor_box(2.65, -7.7, 0.6, 1.4, 0.95, L.WOOD_DARK, L.WOOD, 0.02)
	for i in 3:
		_b.box(Vector3(2.96, 0.2 + i * 0.28, -7.7), Vector3(0.02, 0.2, 1.3), L.shade(L.WOOD_DARK, 0.1))
	_b.box(Vector3(2.7, 1.12, -7.7), Vector3(0.05, 0.3, 0.38), L.GOLD)
	_b.box(Vector3(2.73, 1.12, -7.7), Vector3(0.02, 0.24, 0.3), L.CLOUD)
	_floor_box(6.5, -7.6, 0.8, 1.4, 2.1, L.WOOD, Color(), 0.03)
	_b.box(Vector3(6.09, 1.05, -7.6), Vector3(0.02, 2.0, 0.02), L.WOOD_DARK)
	_rug(Vector3(4.5, 0, -8.4), Vector2(3.0, 1.4), L.BONE, L.shade(L.BERRY, -0.1))

## A bathroom inside r: tub or glass shower at the back, toilet, vanity with a mirror, a towel and a mat.
func _bathroom(r: Rect2, accent: Color, kind: String) -> void:
	var x0 := r.position.x
	var x1 := r.end.x
	if kind == "tub":
		_floor_box(x0 + 1.25, -11.35, 2.3, 1.1, 0.6, L.CLOUD, Color(), 0.08)
		_b.box(Vector3(x0 + 1.25, 0.55, -11.35), Vector3(2.0, 0.08, 0.8), L.glow(L.SKY, 0.35))
		_b.prism(Vector3(x0 + 0.3, 0.6, -11.8), 0.03, 0.03, 0.5, 5, L.STONE)
		for i in 3:  # bubbles
			_b.ball(Vector3(x0 + 1.4 + i * 0.25, 0.62, -11.3 + (i % 2) * 0.15), 0.08, L.CLOUD, 0)
	else:
		_floor_box(x0 + 0.65, -11.25, 1.2, 1.3, 0.08, L.shade(TILE, -0.2))
		_glass.box(Vector3(x0 + 1.25, 1.0, -11.25), Vector3(0.04, 2.0, 1.3), L.glow(L.SKY, 0.1))
		_glass.box(Vector3(x0 + 0.65, 1.0, -10.6), Vector3(1.2, 2.0, 0.04), L.glow(L.SKY, 0.1))
		_b.prism(Vector3(x0 + 0.3, 1.9, -11.8), 0.12, 0.12, 0.04, 8, L.STONE)
	# Toilet on the side wall.
	var tz := -9.7
	var tx := x1 - 0.45
	_b.box(Vector3(tx + 0.2, 0.5, tz), Vector3(0.2, 0.55, 0.45), L.CLOUD, Color(), 0.04)
	_b.prism(Vector3(tx - 0.08, 0, tz), 0.14, 0.2, 0.38, 8, L.CLOUD, Color(), Vector2(1.3, 1.0))
	_b.prism(Vector3(tx - 0.08, 0.38, tz), 0.24, 0.24, 0.04, 8, accent, Color(), Vector2(1.3, 1.0))
	_block(Rect2(tx - 0.4, tz - 0.25, 0.75, 0.5))
	# Vanity and mirror on the other side wall.
	var vz := -8.4
	_floor_box(x0 + 0.35, vz, 0.6, 1.1, 0.85, L.shade(accent, -0.25), L.CLOUD, 0.02)
	_b.prism(Vector3(x0 + 0.35, 0.82, vz), 0.18, 0.15, 0.05, 8, L.shade(L.CLOUD, -0.1))
	_b.prism(Vector3(x0 + 0.12, 0.85, vz), 0.025, 0.025, 0.22, 5, L.STONE)
	_glass.box(Vector3(x0 + 0.05, 1.6, vz), Vector3(0.03, 0.8, 0.9), L.glow(L.SKY, 0.45))
	_b.box(Vector3(x0 + 0.04, 1.6, vz), Vector3(0.03, 0.88, 0.98), L.GOLD)
	_b.prism(Vector3(x0 + 0.45, 0.86, vz + 0.35), 0.05, 0.05, 0.14, 6, accent)  # soap
	# Towel rail, bath mat, plant.
	_b.box(Vector3(x1 - 0.05, 1.2, -11.1), Vector3(0.04, 0.04, 0.7), L.STONE)
	_b.box(Vector3(x1 - 0.08, 0.95, -11.1), Vector3(0.04, 0.5, 0.6), accent)
	_rug(Vector3(x0 + 1.4, 0, -10.0), Vector2(1.0, 0.6), accent, L.shade(accent, -0.2))
	_plant(x0 + 0.35, -7.0, 0.6, L.CLOUD)

func _hallway() -> void:
	_rug(Vector3(-4.0, 0, -5.5), Vector2(20.0, 1.1), L.shade(L.BERRY, 0.05), L.shade(L.BERRY, -0.2))
	# Family photos along the hall wall caps and a little console table with a lamp.
	for i in 6:
		_picture(-16.6 + i * 2.6 + (3.0 if i > 2 else 0.0), -6.33, 0.6, [L.SUN, L.SKY, L.ROSE, L.LEAF, L.LAVENDER, L.CLOUD][i], 0.42, 0.34)
	_floor_box(8.8, -6.0, 1.4, 0.4, 0.8, L.WOOD_DARK, L.WOOD, 0.02)
	_b.prism(Vector3(9.2, 0.8, -6.0), 0.08, 0.06, 0.3, 6, L.INK)
	_b.prism(Vector3(9.2, 1.1, -6.0), 0.2, 0.12, 0.22, 6, L.glow(L.SUN, 0.5))
	# A coat rack with your traveling cloak hanging ready.
	_b.prism(Vector3(-17.5, 0, -5.0), 0.04, 0.04, 1.8, 6, L.WOOD_DARK)
	_b.box(Vector3(-17.5, 1.3, -5.0), Vector3(0.3, 0.7, 0.4), L.SLATE, Color(), 0.06)
	_block(Rect2(-17.75, -5.25, 0.5, 0.5))

func _kitchen() -> void:
	# Counter along the left wall with a sink, a glowing cooktop, and Mom's pot on the boil.
	_floor_box(-17.62, 0.0, 0.76, 7.0, 0.9, L.CLOUD, L.shade(L.STONE, -0.1), 0.0)
	for i in 8:
		_b.box(Vector3(-17.23, 0.45, -3.1 + i * 0.88), Vector3(0.02, 0.7, 0.8), L.shade(L.CLOUD, -0.08))
		_b.box(Vector3(-17.21, 0.78, -3.1 + i * 0.88), Vector3(0.03, 0.03, 0.3), L.STONE)
	_b.box(Vector3(-17.6, 0.9, 2.2), Vector3(0.5, 0.04, 0.7), L.shade(L.STONE, -0.3))
	_b.prism(Vector3(-17.85, 0.9, 2.2), 0.03, 0.03, 0.3, 5, L.STONE)
	for p in [Vector2(-17.7, -0.3), Vector2(-17.7, 0.25), Vector2(-17.45, -0.02)]:
		_b.ring(Vector3(p.x, 0.9, p.y), 0.08, 0.15, 10, L.glow(L.TERRACOTTA, 0.6), 0.012)
	_b.prism(Vector3(-17.6, 0.92, 0.0), 0.2, 0.2, 0.26, 9, L.shade(L.STONE, -0.2), L.shade(L.TERRACOTTA, -0.3))
	_b.box(Vector3(-17.6, 1.2, 0.18), Vector3(0.05, 0.05, 0.25), L.INK)
	for i in 5:
		_b.box(Vector3(-17.82, 1.9, -2.8 + i * 1.3), Vector3(0.36, 0.7, 1.2), L.shade(L.TEAL_DARK, 0.15), Color(), 0.02)
		_b.box(Vector3(-17.63, 1.75, -2.8 + i * 1.3), Vector3(0.02, 0.04, 0.4), L.GOLD)
	# Fridge with a little glowing screen and a drawing from Lily stuck on it.
	_floor_box(-17.55, 5.35, 0.9, 0.9, 2.0, L.CLOUD, Color(), 0.05)
	_b.box(Vector3(-17.08, 1.35, 5.35), Vector3(0.03, 0.4, 0.3), L.glow(L.TEAL, 0.5))
	_b.box(Vector3(-17.08, 0.9, 5.1), Vector3(0.04, 0.6, 0.04), L.STONE)
	_b.box(Vector3(-17.08, 0.9, 5.55), Vector3(0.02, 0.3, 0.24), L.SUN)
	# Pantry shelves by the hallway.
	_floor_box(-15.5, -4.05, 1.6, 0.5, 2.0, L.WOOD, Color(), 0.02)
	for i in 3:
		for k in 4:
			_b.box(Vector3(-16.1 + k * 0.4, 0.5 + i * 0.55, -3.85), Vector3(0.24, 0.3, 0.12), [L.TERRACOTTA, L.SUN, L.LEAF, L.SKY][(i + k) % 4], Color(), 0.03)
	# Dining table set for dinner, for five.
	var t := Vector3(-13.3, 0, 2.6)
	_b.prism(t, 0.12, 0.08, 0.72, 6, L.WOOD_DARK)
	_b.prism(t, 0.35, 0.35, 0.05, 8, L.WOOD_DARK)
	_b.prism(t + Vector3(0, 0.72, 0), 1.05, 1.05, 0.06, 10, L.WOOD, L.WOOD_LIGHT)
	_block(Rect2(t.x - 0.95, t.z - 0.95, 1.9, 1.9))
	for i in 5:
		var a := TAU * i / 5.0 + PI / 2.0
		var d := Vector3(cos(a), 0, sin(a))
		_b.prism(t + d * 0.7 + Vector3(0, 0.78, 0), 0.17, 0.19, 0.02, 10, L.CLOUD)
		_b.ball(t + d * 0.7 + Vector3(0, 0.82, 0), 0.07, [L.TERRACOTTA, L.LEAF, L.SUN, L.ROSE, L.SKY][i], 0, Vector3(1, 0.5, 1))
		_chair(t.x + d.x * 1.4, t.z + d.z * 1.4, atan2(d.z, -d.x) + PI, L.ROSE)
	_b.prism(t + Vector3(0, 0.78, 0), 0.22, 0.28, 0.12, 8, L.BONE)
	for i in 4:
		_b.ball(t + Vector3(cos(i * 1.6) * 0.12, 0.95, sin(i * 1.6) * 0.12), 0.08, [L.TERRACOTTA, L.SUN, L.LEAF, L.BERRY][i], 0)
	# Kitchen island by the opening to the living room, with stools.
	_floor_box(-10.4, 0.6, 0.9, 2.6, 0.95, L.WOOD, L.CLOUD, 0.02)
	for z in [-0.1, 1.3]:
		_b.prism(Vector3(-11.25, 0, z), 0.04, 0.04, 0.7, 5, L.INK)
		_b.prism(Vector3(-11.25, 0.7, z), 0.2, 0.18, 0.08, 8, L.TERRACOTTA)
	_b.prism(Vector3(-10.4, 0.95, 0.1), 0.12, 0.09, 0.2, 7, L.SKY)
	_b.ball(Vector3(-10.4, 1.25, 0.1), 0.14, L.LEAF, 0)
	_b.prism(Vector3(-10.4, 0.95, 1.2), 0.2, 0.2, 0.06, 8, L.WOOD_DARK)  # fruit bowl
	for i in 3:
		_b.ball(Vector3(-10.4 + (i - 1) * 0.1, 1.05, 1.2), 0.07, [L.TERRACOTTA, L.SUN, L.LEAF][i], 0)
	_plant(-9.6, 5.4, 0.8)

func _living_room() -> void:
	_rug(Vector3(-4.0, 0, 0.6), Vector2(4.6, 3.6), L.shade(L.BERRY, 0.15), L.shade(L.BERRY, -0.15))
	# Sofa facing the fireplace on the front-left (its back stays low to the camera).
	var s := Vector3(-4.0, 0, 2.6)
	_b.box(s + Vector3(0, 0.24, 0), Vector3(2.8, 0.36, 0.9), L.shade(L.SLATE, 0.1), Color(), 0.06)
	_b.box(s + Vector3(0, 0.62, 0.36), Vector3(2.8, 0.48, 0.22), L.SLATE, Color(), 0.08)
	for x in [-1.3, 1.3]:
		_b.box(s + Vector3(x, 0.42, 0), Vector3(0.24, 0.5, 0.92), L.SLATE, Color(), 0.08)
	for x in [-0.6, 0.6]:
		_b.box(s + Vector3(x, 0.47, -0.05), Vector3(1.1, 0.14, 0.72), L.shade(L.SLATE, 0.2), Color(), 0.05)
	_b.box(s + Vector3(-0.8, 0.62, 0.12), Vector3(0.4, 0.34, 0.14), L.SUN, Color(), 0.05)
	_block(Rect2(s.x - 1.45, s.z - 0.48, 2.9, 0.96))
	# Low table with a teapot.
	_floor_box(-4.0, 0.6, 1.5, 0.8, 0.38, L.WOOD_DARK, L.WOOD, 0.03)
	_b.prism(Vector3(-4.3, 0.38, 0.6), 0.12, 0.1, 0.16, 8, L.CLOUD)
	_b.prism(Vector3(-3.7, 0.38, 0.55), 0.06, 0.06, 0.1, 8, L.CLOUD)
	# A holo-fireplace on the hallway side, with flickering flames.
	_floor_box(-4.0, -3.95, 2.2, 0.5, 1.1, L.shade(L.STONE, -0.05), L.shade(L.STONE, 0.1), 0.02)
	_b.box(Vector3(-4.0, 0.45, -3.69), Vector3(1.2, 0.6, 0.04), L.INK)
	_armchair(Vector3(-7.4, 0, -1.6), -0.6)
	_armchair(Vector3(-0.6, 0, -1.6), PI + 0.6)
	# The family bookshelf against the kitchen wall: photos, and one spot "saved for the Book".
	_bookshelf(Vector3(-7.4, 0, -4.15))
	_plant(-8.4, 5.4, 1.0)
	_plant(0.4, 5.4, 0.9, L.CLOUD)

func _family_room() -> void:
	# Big corner sofa facing the holo-screen on the garage wall.
	var c := L.shade(L.TEAL_DARK, 0.25)
	_b.box(Vector3(4.6, 0.24, -2.6), Vector3(0.9, 0.36, 3.0), c, Color(), 0.06)
	_b.box(Vector3(4.24, 0.62, -2.6), Vector3(0.22, 0.48, 3.0), L.shade(c, -0.1), Color(), 0.08)
	_b.box(Vector3(5.6, 0.24, -3.65), Vector3(1.4, 0.36, 0.9), c, Color(), 0.06)
	for z in [-3.4, -2.4, -1.4]:
		_b.box(Vector3(4.7, 0.47, z), Vector3(0.72, 0.14, 0.9), L.shade(c, 0.15), Color(), 0.05)
	_b.box(Vector3(4.6, 0.62, -1.6), Vector3(0.14, 0.34, 0.4), L.TERRACOTTA, Color(), 0.05)
	_block(Rect2(4.15, -4.1, 2.75, 0.9))
	_block(Rect2(4.15, -4.1, 0.9, 3.0))
	# Games table with a board game mid-play.
	_floor_box(7.0, -2.0, 1.0, 1.0, 0.5, L.WOOD_DARK, L.WOOD, 0.03)
	_b.box(Vector3(7.0, 0.52, -2.0), Vector3(0.7, 0.02, 0.7), L.CLOUD)
	for i in 4:
		_b.prism(Vector3(6.8 + (i % 2) * 0.4, 0.53, -2.2 + (i / 2) * 0.4), 0.04, 0.03, 0.1, 6, [L.TERRACOTTA, L.SKY, L.SUN, L.LEAF][i])
	# Beanbags, and Sam's play rug with blocks and a toy rocket.
	_b.ball(Vector3(8.6, 0.25, 0.8), 0.45, L.BERRY, 1, Vector3(1.0, 0.6, 1.0))
	_b.ball(Vector3(8.2, 0.25, 2.2), 0.45, L.SUN, 1, Vector3(1.0, 0.6, 1.0))
	_block(Rect2(8.15, 0.35, 0.9, 0.9))
	_block(Rect2(7.75, 1.75, 0.9, 0.9))
	var toys := Vector3(5.0, 0, 3.3)
	_rug(Vector3(5.0, 0, 2.9), Vector2(2.8, 2.4), L.shade(L.SKY, -0.1), L.shade(L.SKY, -0.3))
	for i in 6:
		var p := toys + Vector3(-0.6 + (i % 3) * 0.24, 0.07 + (i / 3) * 0.14, 0.4 + (i % 2) * 0.05)
		_b.box(p, Vector3(0.14, 0.14, 0.14), [L.TERRACOTTA, L.SUN, L.TEAL, L.LEAF, L.ROSE, L.SKY][i])
	_b.prism(toys + Vector3(0.6, 0.03, 0.5), 0.09, 0.09, 0.3, 6, L.CLOUD)
	_b.prism(toys + Vector3(0.6, 0.33, 0.5), 0.09, 0.0, 0.16, 6, L.TERRACOTTA)
	for i in 3:
		var a := TAU * i / 3.0
		_b.box(toys + Vector3(0.6 + cos(a) * 0.1, 0.08, 0.5 + sin(a) * 0.1), Vector3(0.05, 0.12, 0.05), L.TERRACOTTA)
	# Biscuit's bed.
	_b.prism(Vector3(2.4, 0.0, 4.6), 0.5, 0.48, 0.14, 10, L.TERRACOTTA, L.shade(L.BONE, -0.05), Vector2(1.0, 0.8))
	_plant(9.5, 5.4, 1.0)
	_plant(1.6, -3.9, 0.9, L.CLOUD)

func _holo_screen() -> void:
	# A floating holo-screen on the garage wall, gently bobbing, showing a cartoon of stars.
	var g := L.new(true)
	g.box(Vector3.ZERO, Vector3(0.04, 1.1, 1.9), L.glow(L.SKY, 0.5))
	for i in 5:
		g.ball(Vector3(-0.03, -0.3 + (i % 3) * 0.25, -0.7 + i * 0.35), 0.05, L.glow(L.SUN, 1.0), 0)
	_screen = g.instance(false)
	_screen.position = Vector3(9.75, 1.35, -2.6)
	add_child(_screen)
	_floor_box(9.7, -2.6, 0.4, 2.0, 0.4, L.INK, L.shade(L.INK, 0.2), 0.02)

func _garage() -> void:
	# Workbench along the right wall, with tools on a pegboard above it.
	_floor_box(19.55, -2.0, 0.8, 3.6, 0.9, L.WOOD_DARK, L.WOOD, 0.02)
	_b.box(Vector3(19.97, 1.75, -2.0), Vector3(0.04, 1.1, 3.4), L.WOOD_LIGHT)
	for i in 9:
		var z := -3.5 + i * 0.38
		_b.box(Vector3(19.92, 1.55 + (i % 3) * 0.25, z), Vector3(0.05, 0.3 + (i % 2) * 0.15, 0.07), [L.TERRACOTTA, L.INK, L.STONE, L.GOLD][i % 4])
	_b.box(Vector3(19.5, 1.0, -3.2), Vector3(0.3, 0.2, 0.3), L.TERRACOTTA, Color(), 0.03)  # vise
	_b.box(Vector3(19.5, 0.93, -1.6), Vector3(0.5, 0.04, 0.4), L.INK)
	_glass.box(Vector3(19.5, 1.15, -1.6), Vector3(0.02, 0.32, 0.46), L.glow(L.TEAL, 0.8))
	for i in 4:  # loose bolts and nuts
		_b.prism(Vector3(19.4 + (i % 2) * 0.12, 0.9, -2.6 + i * 0.1), 0.03, 0.03, 0.03, 6, L.STONE)
	# A second bench with a welding torch and a gas tank.
	_floor_box(19.55, -6.4, 0.8, 2.2, 0.9, L.STONE, L.shade(L.STONE, 0.15), 0.02)
	_b.prism(Vector3(19.4, 0, -7.9), 0.18, 0.18, 1.2, 8, L.TERRACOTTA, L.STONE)
	_b.ball(Vector3(19.4, 1.25, -7.9), 0.08, L.STONE, 0)
	_block(Rect2(19.15, -8.15, 0.5, 0.5))
	_b.box(Vector3(19.3, 0.95, -6.0), Vector3(0.12, 0.08, 0.35), L.INK)
	# Shelves on the back wall, crammed with boxes and spare parts.
	for sx in [11.8, 19.2]:
		_floor_box(sx, -11.6, 1.8, 0.7, 0.06, L.INK)
		for i in 3:
			_b.box(Vector3(sx, 0.3 + i * 0.75, -11.6), Vector3(1.8, 0.05, 0.7), L.STONE)
			for k in 3:
				_b.box(Vector3(sx - 0.6 + k * 0.6, 0.5 + i * 0.75, -11.6), Vector3(0.48, 0.35, 0.5), [L.SUN, L.TERRACOTTA, L.SKY, L.LEAF][(i + k) % 4], Color(), 0.03)
		for x in [sx - 0.9, sx + 0.9]:
			_b.box(Vector3(x, 1.1, -11.6), Vector3(0.05, 2.2, 0.7), L.INK)
	# The family's hover car, parked in the left bay.
	_b.with(Transform3D(Basis.IDENTITY, Vector3(12.8, 0.3, 2.6)), func():
		_b.ball(Vector3(0, 0.45, 0), 1.0, L.SKY, 1, Vector3(1.1, 0.45, 2.0))
		_b.ball(Vector3(0, 0.82, 0.1), 0.6, L.shade(L.NIGHT, 0.2), 1, Vector3(1.0, 0.5, 1.6))
		_b.box(Vector3(0, -0.12, 0), Vector3(1.4, 0.06, 3.4), L.glow(L.TEAL, 0.6))
		for s in [-1.0, 1.0]:
			_b.box(Vector3(0.6 * s, 0.5, 1.9), Vector3(0.3, 0.12, 0.08), L.glow(L.SUN, 0.9))
			_b.box(Vector3(0.6 * s, 0.5, -1.9), Vector3(0.3, 0.12, 0.08), L.glow(L.TERRACOTTA, 0.9)))
	_block(Rect2(11.6, 0.4, 2.4, 4.4))
	# The right bay: Dad's project space, full of parts. An engine block on a stand...
	var e := Vector3(17.4, 0, 1.2)
	_b.box(e + Vector3(0, 0.3, 0), Vector3(0.9, 0.06, 0.9), L.INK)
	for p in [Vector2(-0.35, -0.35), Vector2(0.35, -0.35), Vector2(-0.35, 0.35), Vector2(0.35, 0.35)]:
		_b.box(e + Vector3(p.x, 0.15, p.y), Vector3(0.06, 0.3, 0.06), L.INK)
	_b.box(e + Vector3(0, 0.62, 0), Vector3(0.8, 0.56, 0.7), L.shade(L.STONE, -0.1), Color(), 0.04)
	for i in 3:
		_b.prism(e + Vector3(-0.25 + i * 0.25, 0.9, 0), 0.09, 0.09, 0.14, 6, L.shade(L.STONE, 0.15))
	_b.ring(e + Vector3(0.42, 0.62, 0), 0.08, 0.22, 10, L.INK, 0.06)
	_block(Rect2(e.x - 0.5, e.z - 0.5, 1.0, 1.0))
	# ...a stack of tires, a rolling red tool chest, oil drums, crates, a robot arm, and gears on the floor.
	for i in 4:
		_b.ring(Vector3(18.9, 0.12 + i * 0.24, 4.6), 0.18, 0.42, 12, L.shade(L.INK, 0.05), 0.22)
	_block(Rect2(18.45, 4.15, 0.9, 0.9))
	_floor_box(16.0, 4.9, 1.2, 0.6, 1.0, L.TERRACOTTA, L.shade(L.TERRACOTTA, 0.1), 0.03)
	for i in 4:
		_b.box(Vector3(16.0, 0.2 + i * 0.22, 5.21), Vector3(1.1, 0.02, 0.02), L.shade(L.TERRACOTTA, -0.3))
		_b.box(Vector3(16.0, 0.27 + i * 0.22, 5.22), Vector3(0.4, 0.03, 0.03), L.STONE)
	for p in [Vector3(19.4, 0, -9.6), Vector3(19.4, 0, -10.5)]:
		_b.prism(p, 0.32, 0.32, 0.9, 10, L.shade(L.SKY, -0.3), L.shade(L.SKY, -0.1))
		_b.ring(p + Vector3(0, 0.3, 0), 0.31, 0.34, 10, L.INK, 0.04)
		_block(Rect2(p.x - 0.35, p.z - 0.35, 0.7, 0.7))
	for p in [Vector3(10.8, 0, -3.2), Vector3(10.8, 0, -2.4), Vector3(10.85, 0.6, -2.8)]:
		_b.box(p + Vector3(0, 0.3, 0), Vector3(0.6, 0.6, 0.6), L.WOOD, Color(), 0.03)
		_b.box(p + Vector3(0, 0.3, 0.305), Vector3(0.5, 0.06, 0.01), L.WOOD_DARK)
	_block(Rect2(10.45, -3.55, 0.7, 1.5))
	var arm := Vector3(17.6, 0, -2.6)
	_b.prism(arm, 0.3, 0.3, 0.15, 8, L.SUN)
	_b.with(Transform3D(Basis(Vector3.FORWARD, 0.35), arm + Vector3(0, 0.15, 0)), func():
		_b.box(Vector3(0, 0.45, 0), Vector3(0.14, 0.9, 0.14), L.SUN)
		_b.ball(Vector3(0, 0.9, 0), 0.1, L.INK, 0)
		_b.with(Transform3D(Basis(Vector3.FORWARD, -1.2), Vector3(0, 0.9, 0)), func():
			_b.box(Vector3(0, 0.3, 0), Vector3(0.1, 0.6, 0.1), L.SUN)
			_b.box(Vector3(0, 0.62, 0), Vector3(0.16, 0.06, 0.16), L.INK)))
	_block(Rect2(arm.x - 0.32, arm.z - 0.32, 0.64, 0.64))
	for i in 9:  # gears, wrenches and bolts on the floor
		var p := Vector3(15.6 + fmod(i * 1.37, 3.6), 0.02, -1.4 + fmod(i * 2.13, 4.0))
		if i % 3 == 0:
			_b.ring(p, 0.05, 0.13, 8, L.STONE, 0.03)
		elif i % 3 == 1:
			_b.with(Transform3D(Basis(Vector3.UP, i * 0.7), p), func():
				_b.box(Vector3(0, 0.01, 0), Vector3(0.36, 0.02, 0.05), L.STONE)
				_b.ring(Vector3(0.2, 0, 0), 0.02, 0.06, 6, L.STONE, 0.02))
		else:
			_b.prism(p, 0.035, 0.035, 0.04, 6, L.GOLD)
	# Dad's old hover bike, the donor for half the machine.
	var bk := Vector3(12.0, 0, -6.2)
	_b.with(Transform3D(Basis(Vector3.UP, 1.4), bk), func():
		_b.box(Vector3(0, 0.08, 0), Vector3(1.6, 0.05, 0.4), L.glow(L.TEAL, 0.25))
		_b.ball(Vector3(0, 0.55, 0), 0.5, L.TERRACOTTA, 1, Vector3(1.8, 0.55, 0.65))
		_b.box(Vector3(-0.1, 0.83, 0), Vector3(0.7, 0.1, 0.36), L.INK, Color(), 0.04)
		_b.prism(Vector3(0.65, 0.7, 0), 0.03, 0.03, 0.35, 5, L.INK)
		_b.box(Vector3(0.65, 1.05, 0), Vector3(0.06, 0.05, 0.6), L.INK)
		_b.ball(Vector3(0.9, 0.6, 0), 0.12, L.glow(L.SUN, 0.7), 0))
	_block(Rect2(bk.x - 0.35, bk.z - 1.0, 0.7, 2.0))
	# Cables from the wall to the machine's console.
	for i in 3:
		_b.box(Vector3(12.9 + i * 0.12, 0.02, -10.9), Vector3(0.05, 0.04, 2.2), [L.INK, L.TERRACOTTA, L.INK][i])

# ---------- outside ----------

func _tree(x: float, z: float, s: float = 1.0, kind: int = 0) -> void:
	_b.prism(Vector3(x, -0.1, z), 0.14 * s, 0.1 * s, 1.4 * s, 6, L.WOOD_DARK)
	if kind == 0:
		_b.ball(Vector3(x, 1.9 * s, z), 0.95 * s, L.LEAF_DARK, 1, Vector3(1, 0.9, 1))
		_b.ball(Vector3(x + 0.45 * s, 2.35 * s, z - 0.2 * s), 0.6 * s, L.shade(L.LEAF, -0.15), 1)
		_b.ball(Vector3(x - 0.4 * s, 2.45 * s, z + 0.15 * s), 0.5 * s, L.shade(L.LEAF, -0.05), 0)
	else:
		for i in 3:
			_b.prism(Vector3(x, 0.9 * s + i * 0.65 * s, z), (1.0 - i * 0.25) * s, 0.0, 1.1 * s, 7, L.shade(L.LEAF_DARK, -0.1 + i * 0.06), Color(), Vector2.ONE, i * 0.4)

func _yard() -> void:
	# Front: a stone path to the front door, hedges, trees, a driveway, street lamps, the street.
	for i in 6:
		_b.prism(Vector3(0.0 + (i % 2) * 0.2, -0.1, 6.9 + i * 0.9), 0.38, 0.36, 0.12, 7, L.shade(L.STONE, 0.1))
	_b.box(Vector3(15.0, -0.08, 9.2), Vector3(9.6, 0.1, 5.8), L.shade(L.CONCRETE, 0.1))
	for x in [-16.5, -13.5, -10.5, -7.5, -4.5, 3.5, 6.5]:
		_b.box(Vector3(x, 0.25, 7.3), Vector3(2.2, 0.7, 0.8), L.LEAF_DARK, L.shade(L.LEAF, -0.1), 0.15)
	_tree(-20.5, 9.0, 1.2)
	_tree(22.5, 9.5, 1.1, 1)
	_tree(-9.0, 10.0, 0.9, 1)
	_b.box(Vector3(0, -0.06, 12.4), Vector3(140, 0.1, 1.6), L.shade(L.STONE, -0.2))
	_b.box(Vector3(0, -0.09, 15.4), Vector3(140, 0.1, 4.4), L.shade(L.INK, 0.05))
	for i in 18:
		_b.box(Vector3(-64.0 + i * 7.5, -0.03, 15.4), Vector3(2.6, 0.02, 0.12), L.glow(L.TEAL, 0.3))
	for x in [-12.0, 6.0]:
		_b.prism(Vector3(x, -0.1, 11.6), 0.06, 0.05, 3.2, 6, L.INK)
		_b.box(Vector3(x + 0.3, 3.1, 11.6), Vector3(0.7, 0.08, 0.2), L.INK)
		_b.prism(Vector3(x + 0.55, 2.9, 11.6), 0.16, 0.06, 0.16, 6, L.glow(L.SUN, 0.8))
	# Back: lawn, trees and a fence, then the city.
	for p in [Vector3(-16.5, 0, -15.0), Vector3(-8.0, 0, -16.5), Vector3(1.0, 0, -15.5), Vector3(9.5, 0, -16.0), Vector3(17.0, 0, -15.2)]:
		_tree(p.x, p.z, 1.0, 0 if int(p.x) % 2 == 0 else 1)
	for i in 36:
		var x := -35.0 + i * 2.0
		_b.box(Vector3(x, 0.45, -19.0), Vector3(0.12, 0.9, 0.12), L.WOOD)
	_b.box(Vector3(0, 0.75, -19.0), Vector3(72, 0.08, 0.06), L.WOOD)
	_b.box(Vector3(0, 0.35, -19.0), Vector3(72, 0.08, 0.06), L.WOOD)
	for p in [Vector3(-21.0, 0, -8.0), Vector3(-22.0, 0, 0.0), Vector3(23.0, 0, -7.0), Vector3(24.5, 0, 1.5)]:
		_tree(p.x, p.z, 1.15, 1 if p.x > 0 else 0)

## The 2060 skyline behind the house: tall towers with glowing windows and sky-lanes of hover cars.
func _city() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2060
	var city := L.new()
	city.jitter = 0.06
	for row in 3:
		var z := -20.0 - row * 9.0
		var x := -48.0
		while x < 48.0:
			var w := rng.randf_range(3.0, 6.5)
			var h := rng.randf_range(6.0, 16.0) + row * 7.0
			var body := L.shade(L.NIGHT, rng.randf_range(-0.1, 0.18) - row * 0.08)
			var d := rng.randf_range(3.0, 6.0)
			city.box(Vector3(x + w / 2.0, h / 2.0 - 0.2, z), Vector3(w - 0.6, h, d), body, L.shade(body, 0.2), 0.3 if rng.randf() < 0.5 else 0.0)
			# Rows of lit windows on the face toward the house.
			var fy := 1.2
			while fy < h - 0.8:
				var fx := x + 0.7
				while fx < x + w - 1.0:
					if rng.randf() < 0.42:
						var lit := L.glow(L.SUN, 0.75) if rng.randf() < 0.7 else L.glow(L.TEAL, 0.8)
						city.box(Vector3(fx, fy, z + d / 2.0 + 0.01), Vector3(0.38, 0.5, 0.04), lit)
					fx += 0.65
				fy += 1.0
			if rng.randf() < 0.4:  # rooftop antennas with a blinking light
				city.prism(Vector3(x + w / 2.0, h - 0.2, z), 0.08, 0.04, 2.4, 5, L.INK)
				var blink := L.new()
				blink.ball(Vector3.ZERO, 0.22, L.glow(L.TERRACOTTA, 1.0), 0)
				var bn := blink.instance(false)
				bn.position = Vector3(x + w / 2.0, h + 2.25, z)
				add_child(bn)
				_blinkers.append(bn)
			x += w + rng.randf_range(0.2, 1.4)
	var ci := city.instance(false)
	add_child(ci)
	# Hover cars gliding along two sky-lanes.
	for i in 8:
		var car := L.new()
		car.ball(Vector3.ZERO, 0.6, L.CLOUD, 0, Vector3(1.6, 0.45, 0.7))
		car.box(Vector3(-0.9, 0, 0), Vector3(0.1, 0.12, 0.5), L.glow(L.TERRACOTTA, 1.0))
		car.box(Vector3(0.9, 0, 0), Vector3(0.1, 0.12, 0.5), L.glow(L.SUN, 1.0))
		var n := car.instance(false)
		var lane := i % 2
		n.position = Vector3(-60.0 + i * 15.0, 9.0 + lane * 4.0, -17.0 - lane * 8.0)
		var sp := (5.0 + i % 3) * (1.0 if lane == 0 else -1.0)
		n.rotation.y = 0.0 if sp > 0.0 else PI
		n.set_meta("speed", sp)
		add_child(n)
		_cars.append(n)

# ---------- the time machine ----------

func _machine() -> void:
	var root := Node3D.new()
	root.name = "TimeMachine"
	root.position = MACHINE
	add_child(root)
	var m := L.new()
	# A stepped, eight-sided platform.
	m.prism(Vector3(0, 0, 0), 1.95, 1.9, 0.14, 8, L.shade(L.INK, 0.15), L.shade(L.INK, 0.25), Vector2.ONE, PI / 8.0)
	m.prism(Vector3(0, 0.14, 0), 1.6, 1.55, 0.14, 8, L.shade(L.CONCRETE, -0.2), L.CONCRETE, Vector2.ONE, PI / 8.0)
	# Two pillars holding the gate, and a console on a stand.
	for s in [-1.0, 1.0]:
		m.prism(Vector3(1.75 * s, 0.0, 0), 0.24, 0.16, 2.6, 6, L.STONE, L.INK)
		m.box(Vector3(1.75 * s, 0.6, 0.0), Vector3(0.34, 0.12, 0.34), L.GOLD)
		m.box(Vector3(1.75 * s, 2.0, 0.0), Vector3(0.3, 0.1, 0.3), L.GOLD)
	m.with(Transform3D(Basis(Vector3.UP, -0.5), Vector3(-2.55, 0, 0.9)), func():
		m.prism(Vector3.ZERO, 0.12, 0.1, 0.9, 6, L.INK)
		m.with(Transform3D(Basis(Vector3.RIGHT, 0.5), Vector3(0, 0.95, 0)), func():
			m.box(Vector3.ZERO, Vector3(0.8, 0.1, 0.5), L.STONE, L.INK)))
	m.with(Transform3D(Basis(Vector3.UP, -0.5), Vector3(-2.55, 0, 0.9)), func():
		m.with(Transform3D(Basis(Vector3.RIGHT, 0.5), Vector3(0, 1.0, 0)), func():
			for i in 3:
				m.box(Vector3(-0.25 + i * 0.25, 0.01, 0.0), Vector3(0.14, 0.03, 0.14), [L.glow(L.TEAL, 0.8), L.glow(L.SUN, 0.8), L.glow(L.TERRACOTTA, 0.8)][i])))
	root.add_child(m.instance())
	_block(Rect2(MACHINE.x - 2.0, MACHINE.z - 1.2, 4.0, 1.6))
	_block(Rect2(MACHINE.x - 2.9, MACHINE.z + 0.6, 0.7, 0.6))
	# Glowing parts get their own material copy so they can pulse.
	_machine_mat = L.material().duplicate()
	var g := L.new()
	g.ring(Vector3(0, 0.28, 0), 1.25, 1.45, 8, L.glow(L.TEAL, 0.6), 0.02)
	for s in [-1.0, 1.0]:
		g.ball(Vector3(1.75 * s, 2.72, 0), 0.2, L.glow(L.TEAL, 0.8), 0)
		for i in 3:
			g.box(Vector3(1.75 * s, 0.95 + i * 0.32, 0.17), Vector3(0.12, 0.12, 0.02), L.glow(L.TEAL, 0.7))
	var gi := g.instance()
	gi.material_override = _machine_mat
	root.add_child(gi)
	# The gate: three rings that turn, faster and faster when it starts.
	var gate := Node3D.new()
	gate.position = Vector3(0, 1.55, 0)
	root.add_child(gate)
	for i in 3:
		var holder := Node3D.new()
		gate.add_child(holder)
		var r := L.new()
		var rad := 1.3 - i * 0.2
		r.hoop(Vector3.ZERO, rad, 0.07 - i * 0.01, 12, L.STONE if i == 0 else L.glow(L.TEAL, 0.5 - i * 0.1), 4)
		if i == 0:
			for k in 6:
				var a := TAU * k / 6.0
				r.box(Vector3(cos(a), sin(a), 0) * rad, Vector3(0.16, 0.16, 0.18), L.GOLD)
		var ri := r.instance()
		if i > 0:
			ri.material_override = _machine_mat
		holder.add_child(ri)
		if i > 0:
			holder.rotation.x = 0.55 * i
		_rings.append(holder)
	# The shimmer inside the gate.
	var core := L.new(true)
	core.prism(Vector3(0, -0.01, 0), 0.95, 0.95, 0.02, 10, L.glow(L.SKY, 0.9))
	_core = core.instance(false)
	_core.rotation.x = PI / 2.0
	gate.add_child(_core)
	_core.rotation.x = PI / 2.0
	# Floating crystals around the platform.
	for i in 4:
		var a := TAU * i / 4.0 + PI / 4.0
		var c := L.new()
		c.ball(Vector3.ZERO, 0.16, L.glow(L.TEAL, 0.6), 0, Vector3(0.6, 1.4, 0.6))
		var cn := c.instance(false)
		cn.position = Vector3(cos(a) * 1.35, 1.0, sin(a) * 0.9 + 0.2)
		root.add_child(cn)
		_crystals.append(cn)
	machine_light = OmniLight3D.new()
	machine_light.position = Vector3(0, 1.6, 1.0)
	machine_light.light_color = Color(0.45, 0.95, 1.0)
	machine_light.omni_range = 6.5
	root.add_child(machine_light)

# ---------- light and air ----------

func _lamp(pos: Vector3, c: Color, energy: float, reach: float, shadow: bool = false) -> void:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = c
	l.light_energy = energy
	l.omni_range = reach
	l.shadow_enabled = shadow
	add_child(l)

func _lights() -> void:
	# Warm lamps in each room, cool ones in the bathrooms and garage, and street lamps outside.
	_lamp(Vector3(-15.4, 1.3, -11.2), Color(1.0, 0.78, 0.5), 1.2, 4.5)
	_lamp(Vector3(-14.5, 2.6, -9.0), Color(1.0, 0.86, 0.68), 1.0, 7.0)
	_lamp(Vector3(-4.5, 2.6, -9.0), Color(1.0, 0.86, 0.7), 1.0, 7.0)
	_lamp(Vector3(4.5, 2.6, -9.0), Color(1.0, 0.82, 0.62), 0.9, 6.0)
	for x in [-9.5, 0.5, 8.5]:
		_lamp(Vector3(x, 2.4, -9.5), Color(0.85, 0.95, 1.0), 0.7, 5.0)
	_lamp(Vector3(-4.0, 2.4, -5.5), Color(1.0, 0.85, 0.66), 0.8, 8.0)
	_lamp(Vector3(-14.0, 2.4, 0.5), Color(1.0, 0.82, 0.6), 1.5, 8.0)
	_lamp(Vector3(-4.0, 1.0, -3.2), Color(1.0, 0.6, 0.3), 1.4, 4.5)  # the fireplace
	_lamp(Vector3(-4.0, 2.8, 1.5), Color(1.0, 0.85, 0.66), 1.0, 8.0)
	_lamp(Vector3(5.5, 2.6, 0.0), Color(0.85, 0.9, 1.0), 1.0, 8.5)
	_lamp(Vector3(15.0, 2.8, -3.0), Color(0.75, 0.9, 1.0), 1.0, 9.0)
	_lamp(Vector3(15.0, 2.8, 3.0), Color(0.75, 0.9, 1.0), 0.8, 7.0)
	_lamp(Vector3(-11.45, 2.8, 11.6), Color(1.0, 0.8, 0.5), 2.0, 8.0)
	_lamp(Vector3(6.55, 2.8, 11.6), Color(1.0, 0.8, 0.5), 2.0, 8.0)

func _particles() -> void:
	# Steam from Mom's pot.
	var p := CPUParticles3D.new()
	p.position = Vector3(-17.6, 1.25, 0.0)
	p.amount = 14
	p.lifetime = 2.2
	p.direction = Vector3(0, 1, 0)
	p.spread = 12.0
	p.gravity = Vector3(0.05, 0.25, 0)
	p.initial_velocity_min = 0.2
	p.initial_velocity_max = 0.4
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.3))
	curve.add_point(Vector2(0.4, 1.0))
	curve.add_point(Vector2(1, 0))
	p.scale_amount_curve = curve
	var q := L.new()
	q.ball(Vector3.ZERO, 0.07, L.glow(L.CLOUD, 0.15), 0)
	p.mesh = q.mesh()
	add_child(p)
	# Holo-flames in the fireplace.
	for i in 3:
		var f := L.new()
		f.prism(Vector3.ZERO, 0.12 - i * 0.02, 0.0, 0.42 - i * 0.06, 5, L.glow([L.TERRACOTTA, L.SUN, L.GOLD][i], 1.0))
		var fn := f.instance(false)
		fn.position = Vector3(-4.35 + i * 0.35, 0.2, -3.62)
		add_child(fn)
		_fire.append(fn)
	# Sparks drifting from the welding bench in the garage.
	var sp := Look.motes(self, Color(1.0, 0.8, 0.4, 0.8), 10)
	sp.position = Vector3(19.0, 1.2, -6.4)
	sp.emission_box_extents = Vector3(0.4, 0.4, 0.8)
	# Dust drifting in the lamp light.
	var dust := Look.motes(self, Color(1.0, 0.9, 0.7, 0.6), 40)
	dust.position = Vector3(-3.0, 1.4, -3.0)
	dust.emission_box_extents = Vector3(15, 1.2, 8)

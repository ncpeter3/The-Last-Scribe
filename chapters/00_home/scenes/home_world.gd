extends Node3D
## The scribe's home in 2060, built entirely from the low-poly kit (core/lowpoly): the house with its
## four rooms, the yard around it, the city skyline behind, and the time machine in the garage.
## home.gd adds the people and the story on top. Distances are in meters; the camera looks toward -Z,
## so walls that run along X inside the house are kept low ("cutaway") and never hide anyone.
##
## Layout (x left to right, z back to front):
##   bedroom  x -12..-4, z -7..-1.5   kitchen x -12..-4, z -1.5..5
##   living room x -4..5, z -7..5     garage x 5..12, z -7..5 (time machine at the back)

const L := preload("res://core/lowpoly/low_poly.gd")

const HOUSE := Rect2(-12.0, -7.0, 24.0, 12.0)
const TALL := 2.9
const LOW := 1.0
const T := 0.3  # wall thickness
const WALL := Color("ece6da")
const WALL_SHADE := Color("cfc6b6")
const BASE := Color("8d8478")
const MACHINE := Vector3(8.6, 0, -4.6)

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
var _t := 0.0

func _ready() -> void:
	_b = L.new()
	_glass = L.new(true)
	_ground()
	_floors()
	_walls()
	_bedroom()
	_kitchen()
	_living_room()
	_garage()
	_yard()
	_city()
	add_child(_b.instance())
	add_child(_glass.instance(false))
	_machine()
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
	_b.box(Vector3(0, -0.2, -6), Vector3(120, 0.2, 90), L.shade(L.GRASS, -0.35))
	# Foundation the house sits on.
	_b.box(Vector3(0, -0.12, -1), Vector3(24.8, 0.16, 12.8), BASE)

func _floors() -> void:
	# Bedroom and living room: wood planks running left to right, each one a slightly different shade.
	var plank := 0.42
	for room in [[Rect2(-12, -7, 8, 5.5), L.WOOD_LIGHT], [Rect2(-4, -7, 9, 12), L.WOOD]]:
		var r: Rect2 = room[0]
		var z := r.position.y
		var i := 0
		while z < r.end.y - 0.01:
			var d := minf(plank, r.end.y - z)
			var c := L.shade(room[1], [0.0, -0.05, 0.04, -0.02][i % 4])
			_b.box(Vector3(r.get_center().x, -0.03, z + d / 2.0), Vector3(r.size.x, 0.06, d - 0.015), c)
			z += d
			i += 1
	# Kitchen: big checker tiles.
	var tile := 0.75
	for ix in range(int(8.0 / tile) + 1):
		for iz in range(int(6.5 / tile) + 1):
			var x0 := -12.0 + ix * tile
			var z0 := -1.5 + iz * tile
			var w := minf(tile, -4.0 - x0)
			var d := minf(tile, 5.0 - z0)
			if w <= 0.01 or d <= 0.01:
				continue
			var c := L.CLOUD if (ix + iz) % 2 == 0 else L.shade(L.STONE, 0.15)
			_b.box(Vector3(x0 + w / 2.0, -0.03, z0 + d / 2.0), Vector3(w - 0.02, 0.06, d - 0.02), c)
	# Garage: concrete slabs with seams, and glowing guide lines to the machine.
	for ix in 4:
		for iz in 4:
			_b.box(Vector3(5.0 + 7.0 / 8.0 + ix * 1.75, -0.03, -7.0 + 1.5 + iz * 3.0), Vector3(1.72, 0.06, 2.96),
				L.shade(L.CONCRETE, [0.0, 0.04, -0.03][(ix + iz) % 3]))
	for x in [MACHINE.x - 0.7, MACHINE.x + 0.7]:
		_b.box(Vector3(x, 0.01, -0.9), Vector3(0.07, 0.02, 3.6), L.glow(L.TEAL, 0.4))
	for i in 6:  # yellow and black safety stripes in front of the platform
		_b.box(Vector3(MACHINE.x - 1.5 + i * 0.6, 0.01, MACHINE.z + 2.4), Vector3(0.3, 0.02, 0.22), L.GOLD if i % 2 == 0 else L.INK)

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

func _walls() -> void:
	# Back wall, with a window over the bedroom and a big one in the living room.
	var back := -7.0 - T
	var spans := [[-12.3, -9.6, false], [-9.6, -7.0, true], [-7.0, 0.0, false], [0.0, 4.4, true], [4.4, 12.3, false]]
	for s in spans:
		if not s[2]:
			_wall(s[0], back, s[1], -7.0, TALL)
			continue
		_wall(s[0], back, s[1], -7.0, 0.85)
		_b.box(Vector3((s[0] + s[1]) / 2.0, 2.55, -7.15), Vector3(s[1] - s[0], 0.7, T), WALL)
		_b.box(Vector3((s[0] + s[1]) / 2.0, 2.94, -7.15), Vector3(s[1] - s[0] + 0.06, 0.08, T + 0.06), L.shade(WALL, -0.15))
		_window(s[0], s[1])
	# Side walls (tall) and the low front wall.
	_wall(-12.3, back, -12.0, 5.3, TALL)
	_wall(12.0, back, 12.3, 5.3, TALL)
	_wall(-12.3, 5.0, 12.3, 5.3, 0.55)
	# Inside: bedroom / kitchen (door at x -8.0..-6.4), bedroom / living room (door at z -4.4..-2.8),
	# living room / garage (door at z -0.6..1.4). The kitchen opens onto the living room.
	_wall(-12.0, -1.65, -8.0, -1.35, LOW)
	_wall(-6.4, -1.65, -4.0, -1.35, LOW)
	_wall(-4.15, -7.0, -3.85, -4.4, LOW)
	_wall(-4.15, -2.8, -3.85, -1.35, LOW)
	_wall(4.85, -7.0, 5.15, -0.6, LOW)
	_wall(4.85, 1.4, 5.15, 5.0, LOW)
	for d in [[-8.0, -1.5], [-6.4, -1.5]]:  # door posts
		_b.box(Vector3(d[0], 0.6, d[1]), Vector3(0.12, 1.2, 0.36), L.WOOD_DARK)
	for z in [-4.4, -2.8]:
		_b.box(Vector3(-4.0, 0.6, z), Vector3(0.36, 1.2, 0.12), L.WOOD_DARK)
	for z in [-0.6, 1.4]:
		_b.box(Vector3(5.0, 0.6, z), Vector3(0.36, 1.2, 0.12), L.WOOD_DARK)

func _window(x0: float, x1: float) -> void:
	var cx := (x0 + x1) / 2.0
	var w := x1 - x0
	_glass.box(Vector3(cx, 1.7, -7.15), Vector3(w, 1.7, 0.04), L.glow(L.SKY, 0.15))
	_b.box(Vector3(cx, 0.88, -7.05), Vector3(w + 0.1, 0.07, 0.4), L.WOOD_DARK)  # sill
	_b.box(Vector3(cx, 2.2, -7.15), Vector3(w, 0.08, T + 0.04), L.WOOD_DARK)
	var n := maxi(2, int(w / 1.3))
	for i in n + 1:
		_b.box(Vector3(x0 + w * i / n, 1.55, -7.15), Vector3(0.08, 1.3, T + 0.04), L.WOOD_DARK)
	_b.box(Vector3(cx, 1.55, -7.15), Vector3(w, 0.05, 0.1), L.WOOD_DARK)

# ---------- rooms ----------

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

func _bedroom() -> void:
	# The scribe's bed against the back wall, with a teal quilt and a star-patterned throw.
	_floor_box(-10.7, -5.85, 1.7, 2.3, 0.32, L.WOOD)
	_b.box(Vector3(-10.7, 0.62, -6.95), Vector3(1.8, 1.0, 0.12), L.WOOD_DARK, Color(), 0.03)
	_b.box(Vector3(-10.7, 0.42, -5.85), Vector3(1.56, 0.16, 2.12), L.CLOUD)
	_b.box(Vector3(-10.7, 0.53, -5.45), Vector3(1.62, 0.08, 1.4), L.TEAL_DARK, Color(), 0.03)
	_b.box(Vector3(-10.7, 0.58, -5.0), Vector3(1.64, 0.06, 0.5), L.shade(L.TEAL_DARK, 0.2))
	_b.box(Vector3(-10.7, 0.6, -6.55), Vector3(1.1, 0.16, 0.42), L.BONE, Color(), 0.06)
	# A trunk at the foot of the bed, with the satchel and scroll packed for the trip.
	_floor_box(-10.7, -4.25, 1.3, 0.55, 0.42, L.WOOD_DARK, L.WOOD, 0.04)
	_b.box(Vector3(-10.7, 0.24, -3.97), Vector3(1.32, 0.05, 0.02), L.GOLD)
	_b.box(Vector3(-11.0, 0.55, -4.25), Vector3(0.42, 0.26, 0.2), L.WOOD, Color(), 0.04)
	_b.box(Vector3(-11.0, 0.62, -4.14), Vector3(0.36, 0.14, 0.02), L.WOOD_DARK)
	_b.with(Transform3D(Basis(Vector3.UP, 0.3), Vector3(-10.35, 0.49, -4.25)), func():
		_b.with(Transform3D(Basis(Vector3.FORWARD, PI / 2.0), Vector3.ZERO), func():
			_b.prism(Vector3(0, -0.22, 0), 0.06, 0.06, 0.44, 7, L.BONE)
			_b.prism(Vector3(0, -0.25, 0), 0.035, 0.035, 0.5, 6, L.WOOD_DARK)))
	# Nightstand with a lamp.
	_floor_box(-9.4, -6.7, 0.5, 0.45, 0.5, L.WOOD, Color(), 0.03)
	_b.prism(Vector3(-9.4, 0.5, -6.7), 0.08, 0.06, 0.25, 6, L.INK)
	_b.prism(Vector3(-9.4, 0.72, -6.7), 0.18, 0.1, 0.2, 6, L.glow(L.SUN, 0.5))
	# Desk under the window side, with a tablet projecting a glowing page.
	_floor_box(-5.5, -6.65, 1.8, 0.65, 0.76, L.WOOD_LIGHT, L.WOOD_LIGHT, 0.02)
	_b.box(Vector3(-5.5, 0.38, -6.65), Vector3(1.6, 0.7, 0.55), L.shade(L.WOOD_LIGHT, -0.15))
	_b.box(Vector3(-5.5, 0.78, -6.55), Vector3(0.5, 0.03, 0.36), L.INK)
	_glass.box(Vector3(-5.5, 1.22, -6.62), Vector3(0.72, 0.5, 0.02), L.glow(L.TEAL, 0.8))
	for i in 3:
		_b.box(Vector3(-5.5, 1.36 - i * 0.12, -6.6), Vector3(0.5 - (i % 2) * 0.12, 0.03, 0.01), L.glow(L.CLOUD, 0.6))
	_chair(-5.5, -5.9, PI / 2.0, L.TEAL_DARK)
	# A pinboard of star maps and a shelf of keepsakes on the back wall.
	_b.box(Vector3(-8.3, 1.75, -6.99), Vector3(1.1, 0.8, 0.04), L.WOOD)
	for i in 4:
		_b.box(Vector3(-8.6 + (i % 2) * 0.55, 1.95 - (i / 2) * 0.38, -6.96), Vector3(0.38, 0.28, 0.02), [L.NIGHT, L.CLOUD, L.SUN, L.SKY][i])
	_rug(Vector3(-7.6, 0, -3.6), Vector2(2.8, 2.0), L.LAVENDER, L.shade(L.LAVENDER, -0.25))
	_plant(-4.6, -2.0, 0.9, L.CLOUD)
	_plant(-11.5, -2.1, 1.0)

func _kitchen() -> void:
	# Counter along the left wall with a sink, a glowing cooktop, and Mom's pot on the boil.
	_floor_box(-11.62, 1.25, 0.76, 5.3, 0.9, L.CLOUD, L.shade(L.STONE, -0.1), 0.0)
	for i in 6:
		_b.box(Vector3(-11.23, 0.45, -1.1 + i * 0.88), Vector3(0.02, 0.7, 0.8), L.shade(L.CLOUD, -0.08))
		_b.box(Vector3(-11.21, 0.78, -1.1 + i * 0.88), Vector3(0.03, 0.03, 0.3), L.STONE)
	_b.box(Vector3(-11.6, 0.9, 3.0), Vector3(0.5, 0.04, 0.7), L.shade(L.STONE, -0.3))
	_b.prism(Vector3(-11.85, 0.9, 3.0), 0.03, 0.03, 0.3, 5, L.STONE)
	for p in [Vector2(-11.7, 0.9), Vector2(-11.7, 1.45), Vector2(-11.45, 1.18)]:
		_b.ring(Vector3(p.x, 0.9, p.y), 0.08, 0.15, 10, L.glow(L.TERRACOTTA, 0.6), 0.012)
	_b.prism(Vector3(-11.6, 0.92, 1.2), 0.2, 0.2, 0.26, 9, L.shade(L.STONE, -0.2), L.shade(L.TERRACOTTA, -0.3))
	_b.box(Vector3(-11.6, 1.2, 1.38), Vector3(0.05, 0.05, 0.25), L.INK)
	# Upper cabinets on the wall.
	for i in 4:
		_b.box(Vector3(-11.82, 1.9, -0.9 + i * 1.3), Vector3(0.36, 0.7, 1.2), L.shade(L.TEAL_DARK, 0.15), Color(), 0.02)
		_b.box(Vector3(-11.63, 1.75, -0.9 + i * 1.3), Vector3(0.02, 0.04, 0.4), L.GOLD)
	# Fridge with a little glowing screen.
	_floor_box(-11.55, 4.45, 0.9, 0.9, 2.0, L.CLOUD, Color(), 0.05)
	_b.box(Vector3(-11.08, 1.35, 4.45), Vector3(0.03, 0.4, 0.3), L.glow(L.TEAL, 0.5))
	_b.box(Vector3(-11.08, 0.9, 4.2), Vector3(0.04, 0.6, 0.04), L.STONE)
	# Dining table set for dinner.
	var t := Vector3(-7.3, 0, 2.5)
	_b.prism(t, 0.12, 0.08, 0.72, 6, L.WOOD_DARK)
	_b.prism(t, 0.35, 0.35, 0.05, 8, L.WOOD_DARK)
	_b.prism(t + Vector3(0, 0.72, 0), 0.95, 0.95, 0.06, 10, L.WOOD, L.WOOD_LIGHT)
	_block(Rect2(t.x - 0.85, t.z - 0.85, 1.7, 1.7))
	for i in 4:
		var a := TAU * i / 4.0 + PI / 4.0
		var d := Vector3(cos(a), 0, sin(a))
		_b.prism(t + d * 0.6 + Vector3(0, 0.78, 0), 0.17, 0.19, 0.02, 10, L.CLOUD)
		_b.ball(t + d * 0.6 + Vector3(0, 0.82, 0), 0.07, [L.TERRACOTTA, L.LEAF, L.SUN, L.ROSE][i], 0, Vector3(1, 0.5, 1))
		_chair(t.x + d.x * 1.3, t.z + d.z * 1.3, atan2(d.z, -d.x) + PI, L.ROSE)
	_b.prism(t + Vector3(0, 0.78, 0), 0.22, 0.28, 0.12, 8, L.BONE)
	for i in 4:
		_b.ball(t + Vector3(cos(i * 1.6) * 0.12, 0.95, sin(i * 1.6) * 0.12), 0.08, [L.TERRACOTTA, L.SUN, L.LEAF, L.BERRY][i], 0)
	# Kitchen island between kitchen and living room, with stools on the living room side.
	_floor_box(-4.4, 1.9, 0.9, 2.6, 0.95, L.WOOD, L.CLOUD, 0.02)
	for z in [1.2, 2.6]:
		_b.prism(Vector3(-3.55, 0, z), 0.04, 0.04, 0.7, 5, L.INK)
		_b.prism(Vector3(-3.55, 0.7, z), 0.2, 0.18, 0.08, 8, L.TERRACOTTA)
	_b.prism(Vector3(-4.4, 0.95, 1.4), 0.12, 0.09, 0.2, 7, L.SKY)
	_b.ball(Vector3(-4.4, 1.25, 1.4), 0.14, L.LEAF, 0)
	_plant(-4.6, 4.5, 0.8)

func _living_room() -> void:
	_rug(Vector3(1.9, 0, -2.9), Vector2(4.2, 3.2), L.shade(L.BERRY, 0.15), L.shade(L.BERRY, -0.15))
	# Sofa facing the big window (its back is to the camera and stays low).
	var s := Vector3(1.9, 0, -1.25)
	_b.box(s + Vector3(0, 0.24, 0), Vector3(2.8, 0.36, 0.9), L.shade(L.SLATE, 0.1), Color(), 0.06)
	_b.box(s + Vector3(0, 0.62, 0.36), Vector3(2.8, 0.48, 0.22), L.SLATE, Color(), 0.08)
	for x in [-1.3, 1.3]:
		_b.box(s + Vector3(x, 0.42, 0), Vector3(0.24, 0.5, 0.92), L.SLATE, Color(), 0.08)
	for x in [-0.6, 0.6]:
		_b.box(s + Vector3(x, 0.47, -0.05), Vector3(1.1, 0.14, 0.72), L.shade(L.SLATE, 0.2), Color(), 0.05)
	_b.box(s + Vector3(-0.8, 0.62, 0.12), Vector3(0.4, 0.34, 0.14), L.SUN, Color(), 0.05)
	_block(Rect2(s.x - 1.45, s.z - 0.48, 2.9, 0.96))
	# Low table with a teapot and a stack of family photo frames.
	_floor_box(1.9, -3.0, 1.5, 0.8, 0.38, L.WOOD_DARK, L.WOOD, 0.03)
	_b.prism(Vector3(1.6, 0.38, -3.0), 0.12, 0.1, 0.16, 8, L.CLOUD)
	_b.prism(Vector3(2.2, 0.38, -3.05), 0.06, 0.06, 0.1, 8, L.CLOUD)
	# Grandma's armchair, a reading lamp, and her bookshelf against the back wall.
	_armchair(Vector3(-2.8, 0, -3.4), -0.87)
	_floor_box(-3.55, -4.45, 0.4, 0.4, 0.05, L.INK)
	_b.prism(Vector3(-3.55, 0, -4.45), 0.03, 0.03, 1.55, 5, L.INK)
	_b.prism(Vector3(-3.55, 1.5, -4.45), 0.28, 0.14, 0.26, 7, L.glow(L.SUN, 0.45))
	_bookshelf(Vector3(-2.6, 0, -6.75))
	# Holo picture frame of the family on the wall by the window, softly glowing.
	_b.box(Vector3(4.75, 1.7, -6.98), Vector3(0.8, 0.6, 0.04), L.WOOD_DARK)
	_glass.box(Vector3(4.75, 1.7, -6.95), Vector3(0.66, 0.46, 0.02), L.glow(L.SUN, 0.4))
	# Toys on the rug where Sam plays: blocks and a little rocket.
	var toys := Vector3(2.9, 0, 3.1)
	_rug(Vector3(2.6, 0, 3.0), Vector2(2.6, 2.4), L.shade(L.SKY, -0.1), L.shade(L.SKY, -0.3))
	for i in 6:
		var p := toys + Vector3(-0.6 + (i % 3) * 0.24, 0.07 + (i / 3) * 0.14, 0.4 + (i % 2) * 0.05)
		_b.box(p, Vector3(0.14, 0.14, 0.14), [L.TERRACOTTA, L.SUN, L.TEAL, L.LEAF, L.ROSE, L.SKY][i])
	_b.prism(toys + Vector3(0.6, 0.03, 0.5), 0.09, 0.09, 0.3, 6, L.CLOUD)
	_b.prism(toys + Vector3(0.6, 0.33, 0.5), 0.09, 0.0, 0.16, 6, L.TERRACOTTA)
	for i in 3:
		var a := TAU * i / 3.0
		_b.box(toys + Vector3(0.6 + cos(a) * 0.1, 0.08, 0.5 + sin(a) * 0.1), Vector3(0.05, 0.12, 0.05), L.TERRACOTTA)
	# Biscuit's bed.
	_b.prism(Vector3(1.4, 0.0, 3.65), 0.5, 0.48, 0.14, 10, L.TERRACOTTA, L.shade(L.BONE, -0.05), Vector2(1.0, 0.8))
	_plant(4.45, -6.45, 1.1)
	_plant(-3.45, 4.45, 0.9, L.CLOUD)
	_plant(4.4, 4.45, 0.9)

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

func _garage() -> void:
	# Workbench along the right wall, with tools on a pegboard above it.
	_floor_box(11.55, 0.4, 0.8, 3.0, 0.9, L.WOOD_DARK, L.WOOD, 0.02)
	_b.box(Vector3(11.97, 1.75, 0.4), Vector3(0.04, 1.1, 2.8), L.WOOD_LIGHT)
	for i in 7:
		var z := -0.8 + i * 0.4
		_b.box(Vector3(11.92, 1.55 + (i % 3) * 0.25, z), Vector3(0.05, 0.3 + (i % 2) * 0.15, 0.07), [L.TERRACOTTA, L.INK, L.STONE, L.GOLD][i % 4])
	_b.box(Vector3(11.5, 1.0, -0.4), Vector3(0.3, 0.2, 0.3), L.TERRACOTTA, Color(), 0.03)
	_b.box(Vector3(11.5, 0.93, 1.0), Vector3(0.5, 0.04, 0.4), L.INK)
	_glass.box(Vector3(11.5, 1.15, 1.0), Vector3(0.02, 0.32, 0.46), L.glow(L.TEAL, 0.8))
	_b.prism(Vector3(11.4, 0.9, 1.6), 0.08, 0.06, 0.16, 6, L.CLOUD)
	# Shelves with storage boxes.
	_floor_box(11.6, -5.4, 0.7, 2.6, 0.06, L.INK)
	for i in 3:
		_b.box(Vector3(11.6, 0.3 + i * 0.75, -5.4), Vector3(0.7, 0.05, 2.6), L.STONE)
		for k in 3:
			_b.box(Vector3(11.6, 0.5 + i * 0.75, -6.2 + k * 0.8), Vector3(0.5, 0.35, 0.6), [L.SUN, L.TERRACOTTA, L.SKY, L.LEAF][(i + k) % 4], Color(), 0.03)
	for z in [-6.65, -4.15]:
		_b.box(Vector3(11.6, 1.1, z), Vector3(0.7, 2.2, 0.05), L.INK)
	# The big garage door on the right wall.
	_b.box(Vector3(11.97, 1.25, 3.6), Vector3(0.06, 2.5, 2.4), L.STONE)
	for i in 5:
		_b.box(Vector3(11.93, 0.3 + i * 0.5, 3.6), Vector3(0.04, 0.05, 2.36), L.shade(L.STONE, -0.2))
	_b.box(Vector3(11.92, 2.55, 3.6), Vector3(0.06, 0.08, 2.5), L.glow(L.SUN, 0.4))
	# Dad's old hover bike, the donor for half the machine.
	var bk := Vector3(7.1, 0, 3.6)
	_b.with(Transform3D(Basis(Vector3.UP, 0.15), bk), func():
		_b.box(Vector3(0, 0.08, 0), Vector3(1.6, 0.05, 0.4), L.glow(L.TEAL, 0.25))
		_b.ball(Vector3(0, 0.55, 0), 0.5, L.TERRACOTTA, 1, Vector3(1.8, 0.55, 0.65))
		_b.box(Vector3(-0.1, 0.83, 0), Vector3(0.7, 0.1, 0.36), L.INK, Color(), 0.04)
		_b.prism(Vector3(0.65, 0.7, 0), 0.03, 0.03, 0.35, 5, L.INK)
		_b.box(Vector3(0.65, 1.05, 0), Vector3(0.06, 0.05, 0.6), L.INK)
		_b.ball(Vector3(0.9, 0.6, 0), 0.12, L.glow(L.SUN, 0.7), 0))
	_block(Rect2(bk.x - 1.0, bk.z - 0.35, 2.0, 0.7))
	# Cables from the wall to the machine's console.
	for i in 3:
		_b.box(Vector3(6.2 + i * 0.12, 0.02, -5.9), Vector3(0.05, 0.04, 2.2), [L.INK, L.TERRACOTTA, L.INK][i])
	_plant(5.5, 4.45, 0.8, L.STONE)

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
	# Front: a stone path to the front step, hedges, trees, a street lamp, the sidewalk and street.
	for i in 6:
		_b.prism(Vector3(1.0 + (i % 2) * 0.2, -0.1, 5.9 + i * 0.9), 0.38, 0.36, 0.12, 7, L.shade(L.STONE, 0.1))
	for x in [-11.0, -8.5, -6.0, -3.5, 4.5, 7.0, 9.5]:
		_b.box(Vector3(x, 0.25, 6.3), Vector3(2.2, 0.7, 0.8), L.LEAF_DARK, L.shade(L.LEAF, -0.1), 0.15)
	_tree(-13.8, 8.0, 1.2)
	_tree(14.0, 9.0, 1.1, 1)
	_tree(-6.5, 9.5, 0.9, 1)
	_b.box(Vector3(0, -0.06, 11.0), Vector3(120, 0.1, 1.6), L.shade(L.STONE, -0.2))
	_b.box(Vector3(0, -0.09, 14.0), Vector3(120, 0.1, 4.4), L.shade(L.INK, 0.05))
	for i in 16:
		_b.box(Vector3(-56.0 + i * 7.5, -0.03, 14.0), Vector3(2.6, 0.02, 0.12), L.glow(L.TEAL, 0.3))
	for x in [-9.0, 6.0]:
		_b.prism(Vector3(x, -0.1, 10.4), 0.06, 0.05, 3.2, 6, L.INK)
		_b.box(Vector3(x + 0.3, 3.1, 10.4), Vector3(0.7, 0.08, 0.2), L.INK)
		_b.prism(Vector3(x + 0.55, 2.9, 10.4), 0.16, 0.06, 0.16, 6, L.glow(L.SUN, 0.8))
	# A parked hover car by the curb.
	_b.with(Transform3D(Basis.IDENTITY, Vector3(-3.0, 0.25, 13.0)), func():
		_b.ball(Vector3(0, 0.45, 0), 1.0, L.SKY, 1, Vector3(1.9, 0.45, 0.85))
		_b.ball(Vector3(-0.1, 0.8, 0), 0.6, L.shade(L.NIGHT, 0.2), 1, Vector3(1.6, 0.5, 0.95))
		_b.box(Vector3(0, -0.05, 0), Vector3(3.0, 0.06, 1.0), L.glow(L.TEAL, 0.6)))
	# Back: lawn, trees and a fence, then the city.
	for p in [Vector3(-10.5, 0, -10.0), Vector3(-4.0, 0, -11.5), Vector3(3.0, 0, -10.5), Vector3(10.5, 0, -11.0)]:
		_tree(p.x, p.z, 1.0, 0 if int(p.x) % 2 == 0 else 1)
	for i in 30:
		var x := -29.0 + i * 2.0
		_b.box(Vector3(x, 0.45, -14.0), Vector3(0.12, 0.9, 0.12), L.WOOD)
	_b.box(Vector3(0, 0.75, -14.0), Vector3(60, 0.08, 0.06), L.WOOD)
	_b.box(Vector3(0, 0.35, -14.0), Vector3(60, 0.08, 0.06), L.WOOD)
	# Sides of the house: more trees so the edges never look empty.
	for p in [Vector3(-15.0, 0, -4.0), Vector3(-16.0, 0, 2.0), Vector3(15.0, 0, -3.0), Vector3(16.5, 0, 3.5)]:
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
	# Warm lamps in each room, a cool teal one in the garage, and street lamps outside.
	_lamp(Vector3(-9.4, 1.3, -6.2), Color(1.0, 0.78, 0.5), 1.2, 4.5)
	_lamp(Vector3(-7.5, 2.6, -3.5), Color(1.0, 0.86, 0.68), 1.0, 7.0)
	_lamp(Vector3(-7.3, 2.4, 2.5), Color(1.0, 0.82, 0.6), 1.5, 6.5)
	_lamp(Vector3(-3.55, 1.6, -4.3), Color(1.0, 0.78, 0.5), 1.4, 4.5)
	_lamp(Vector3(1.9, 2.8, -2.0), Color(1.0, 0.85, 0.66), 1.2, 9.0)
	_lamp(Vector3(2.6, 2.4, 3.0), Color(1.0, 0.85, 0.7), 0.8, 6.0)
	_lamp(Vector3(9.0, 2.8, 1.5), Color(0.75, 0.9, 1.0), 0.9, 8.0)
	_lamp(Vector3(-8.45, 2.8, 10.4), Color(1.0, 0.8, 0.5), 2.0, 8.0)
	_lamp(Vector3(6.55, 2.8, 10.4), Color(1.0, 0.8, 0.5), 2.0, 8.0)

func _particles() -> void:
	# Steam from Mom's pot.
	var p := CPUParticles3D.new()
	p.position = Vector3(-11.6, 1.25, 1.2)
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
	# Dust drifting in the lamp light.
	var dust := Look.motes(self, Color(1.0, 0.9, 0.7, 0.6), 30)
	dust.position = Vector3(-1.0, 1.4, -1.0)
	dust.emission_box_extents = Vector3(10, 1.2, 5)

class_name LowPolyPerson
extends Node3D
## A low-poly person built from faceted parts (no outside model), animated in code.
## Like every character in the game, the front faces +X: turn the node to turn the person.
##
##     var mom := LowPolyPerson.create(LowPolyPerson.MOM)
##     mom.walk_speed = 1.0         # 0 = standing
##     mom.sitting = true           # sits on whatever is under them (seat 0.46 m high)
##     mom.gesture = "talk"         # "", "talk", "wave", "cheer", "hug", "write", "stir", "play"
##
## A look is a Dictionary; every key is optional (see the presets below).

const L := preload("res://core/lowpoly/low_poly.gd")

## The scribe: slate-blue traveling robe, teal sash, leather satchel, scroll in hand.
const SCRIBE_F := {"skin": L.SKIN, "hair": L.HAIR_BROWN, "hair_style": "ponytail", "top": L.SLATE,
	"bottom": L.INK, "robe": true, "trim": L.GOLD, "sash": L.TEAL, "satchel": true, "scroll": true, "lashes": true}
const SCRIBE_M := {"skin": L.SKIN, "hair": L.HAIR_DARK, "hair_style": "short", "top": L.SLATE,
	"bottom": L.INK, "robe": true, "trim": L.GOLD, "sash": L.TEAL, "satchel": true, "scroll": true}
const MOM := {"skin": L.SKIN, "hair": L.HAIR_DARK, "hair_style": "bun", "top": L.ROSE, "bottom": L.NIGHT,
	"apron": L.CLOUD, "lashes": true}
const DAD := {"skin": L.SKIN, "hair": L.HAIR_DARK, "hair_style": "short", "beard": true, "top": L.TEAL_DARK,
	"stripes": L.LEAF_DARK, "bottom": L.SLATE, "glasses": true, "height": 1.06}
const GRANDMA := {"skin": L.SKIN, "hair": L.HAIR_GRAY, "hair_style": "bun", "top": L.LAVENDER, "inner": L.CLOUD,
	"bottom": L.BERRY, "skirt": true, "glasses": true, "height": 0.93, "lashes": true}
const SAM := {"skin": L.SKIN, "hair": L.HAIR_BROWN, "hair_style": "messy", "top": L.SUN, "hood": true,
	"bottom": L.SKY, "kid": true, "cheeks": true}
## Lily, the scribe's younger sister: pigtails, a lavender dress over leggings.
const LILY := {"skin": L.SKIN, "hair": L.HAIR_DARK, "hair_style": "pigtails", "top": L.LAVENDER, "bottom": L.ROSE,
	"skirt": true, "legs": Color("b06f78"), "kid": true, "cheeks": true, "lashes": true, "flower": L.SUN}

# Genesis 1-3. In Eden, simple garments of leaves; at the gate, the coats of skins (Genesis 3:21).
const ADAM := {"skin": L.SKIN_SHADE, "hair": L.HAIR_DARK, "hair_style": "short", "beard": true, "top": L.LEAF,
	"bottom": L.LEAF_DARK, "tunic": true, "legs": L.SKIN_SHADE, "shoes": L.SKIN_SHADE, "height": 1.04}
const EVE := {"skin": L.SKIN_SHADE, "hair": L.HAIR_BROWN, "hair_style": "long", "top": L.LEAF, "bottom": L.LEAF_DARK,
	"tunic": true, "long_tunic": true, "legs": L.SKIN_SHADE, "shoes": L.SKIN_SHADE, "lashes": true, "flower": L.ROSE}
const ADAM_SKINS := {"skin": L.SKIN_SHADE, "hair": L.HAIR_DARK, "hair_style": "short", "beard": true, "top": Color("a87a4a"),
	"stripes": Color("7a5233"), "bottom": Color("8f6438"), "tunic": true, "legs": L.SKIN_SHADE, "shoes": L.WOOD_DARK, "height": 1.04}
const EVE_SKINS := {"skin": L.SKIN_SHADE, "hair": L.HAIR_BROWN, "hair_style": "long", "top": Color("a87a4a"), "stripes": Color("7a5233"),
	"bottom": Color("8f6438"), "tunic": true, "long_tunic": true, "legs": L.SKIN_SHADE, "shoes": L.WOOD_DARK, "lashes": true}
## The cherubim at the east of the garden (Genesis 3:24): tall, white and gold, with wings.
const CHERUB := {"skin": Color("f0d2b0"), "hair": L.GOLD, "hair_style": "short", "top": L.CLOUD, "bottom": L.CLOUD,
	"robe": true, "trim": L.GOLD, "sash": L.GOLD, "wings": true, "height": 1.3}

const HIP := 0.84
const KNEE := 0.44
const SHOULDER := 1.34
const NECK := 1.42
const SEAT := 0.46

var walk_speed := 0.0  ## 0 = still; 1 = normal walking pace
var sitting := false
var gesture := ""  ## "", "talk", "wave", "cheer", "hug", "write", "stir", "play"
var sit_height := SEAT  ## seat height when sitting (0.1 = on the floor)
var look: Dictionary

var _body: Node3D  # everything; faces +Z inside, turned to face +X
var _torso: Node3D
var _head: Node3D
var _arms: Array[Node3D] = []  # right, left
var _thighs: Array[Node3D] = []
var _shins: Array[Node3D] = []
var _wings: Array[Node3D] = []
var _t := 0.0
var _phase := 0.0
var _scale := 1.0

static func create(look_: Dictionary) -> LowPolyPerson:
	var p := LowPolyPerson.new()
	p.look = look_
	p._build()
	return p

func _c(key: String, fallback: Color) -> Color:
	return look.get(key, fallback)

func _build() -> void:
	_t = randf() * 10.0
	var kid: bool = look.get("kid", false)
	_scale = float(look.get("height", 1.0)) * (0.64 if kid else 1.0)
	_body = Node3D.new()
	_body.rotation.y = PI / 2.0
	_body.scale = Vector3.ONE * _scale
	add_child(_body)
	var skin := _c("skin", L.SKIN)
	var top := _c("top", L.SLATE)
	var bottom := _c("bottom", L.INK)
	var shoes := _c("shoes", L.shade(bottom, -0.45))
	var legs := _c("legs", bottom)
	var robe: bool = look.get("robe", false)
	var skirt: bool = look.get("skirt", false)

	# Torso: hips, chest, garments. Pivot at the hips so the body can lean.
	_torso = Node3D.new()
	_torso.position.y = HIP
	_body.add_child(_torso)
	var b := L.new()
	b.prism(Vector3(0, -0.1, 0), 0.15, 0.16, 0.14, 6, bottom, Color(), Vector2(1.15, 0.8))
	b.prism(Vector3(0, 0.02, 0), 0.155, 0.205, SHOULDER - HIP - 0.02, 6, top, Color(), Vector2(1.12, 0.74))
	b.prism(Vector3(0, SHOULDER - HIP, 0), 0.205, 0.09, 0.07, 6, top, Color(), Vector2(1.12, 0.74))
	if look.has("stripes"):
		for i in 3:
			b.box(Vector3(0, 0.12 + i * 0.13, 0.13), Vector3(0.3, 0.035, 0.03), look["stripes"])
	if look.has("inner"):  # an open cardigan over a blouse
		b.box(Vector3(0, 0.27, 0.142), Vector3(0.11, 0.48, 0.03), look["inner"])
		b.box(Vector3(0, 0.46, 0.13), Vector3(0.2, 0.06, 0.05), look["inner"])
	if look.has("apron"):
		b.box(Vector3(0, 0.02, 0.118), Vector3(0.24, 0.42, 0.02), look["apron"])
		b.box(Vector3(0, 0.38, 0.11), Vector3(0.16, 0.14, 0.02), look["apron"])
		b.box(Vector3(0, 0.12, 0.0), Vector3(0.36, 0.035, 0.25), look["apron"])
	if look.get("hood", false):
		b.prism(Vector3(0, SHOULDER - HIP - 0.04, -0.06), 0.13, 0.15, 0.1, 6, L.shade(top, -0.12), Color(), Vector2(1.2, 0.9))
		b.box(Vector3(0, 0.15, 0.135), Vector3(0.18, 0.1, 0.03), L.shade(top, -0.12))
	if look.get("tunic", false):
		# A simple knee-length (or longer) garment over bare legs.
		var low := 0.42 if look.get("long_tunic", false) else 0.3
		b.prism(Vector3(0, -low, 0), 0.22, 0.16, low + 0.05, 7, bottom, Color(), Vector2(1.05, 0.9))
		if look.has("stripes"):
			b.prism(Vector3(0, -low - 0.01, 0), 0.225, 0.215, 0.05, 7, look["stripes"], Color(), Vector2(1.05, 0.9))
	if look.get("wings", false):
		pass  # built below so they can move
	if robe or skirt:
		# A long garment that flares out over the legs.
		var c := top if robe else bottom
		b.prism(Vector3(0, -HIP + 0.12, 0), 0.27, 0.165, HIP - 0.08, 8, c, Color(), Vector2(1.05, 0.9))
		if look.has("trim"):
			b.prism(Vector3(0, -HIP + 0.1, 0), 0.275, 0.268, 0.05, 8, look["trim"], Color(), Vector2(1.05, 0.9))
	if look.has("sash"):
		# Across the chest from the right shoulder to the left hip, with a strap tag that glows.
		var s: Color = look["sash"]
		b.with(Transform3D(Basis(Vector3.FORWARD, -0.75), Vector3(0, 0.26, 0)), func():
			b.box(Vector3(0, 0, 0.13), Vector3(0.07, 0.62, 0.03), s)
			b.box(Vector3(0, 0, -0.13), Vector3(0.07, 0.62, 0.03), s))
		b.box(Vector3(0, 0.0, 0.0), Vector3(0.36, 0.05, 0.28), L.shade(s, -0.25))
		b.box(Vector3(0.0, 0.0, 0.17), Vector3(0.06, 0.06, 0.02), L.glow(s, 0.5))
	if look.get("satchel", false):
		b.box(Vector3(0.24, -0.04, 0.02), Vector3(0.08, 0.22, 0.24), L.WOOD, Color(), 0.02)
		b.box(Vector3(0.285, -0.02, 0.02), Vector3(0.02, 0.12, 0.2), L.WOOD_DARK)
		b.box(Vector3(0.29, 0.0, 0.02), Vector3(0.015, 0.035, 0.04), L.GOLD)
	_torso.add_child(b.instance())

	if look.get("wings", false):
		for side in [-1.0, 1.0]:
			var w := Node3D.new()
			w.position = Vector3(0.1 * side, 0.42, -0.13)
			_torso.add_child(w)
			var wb := L.new()
			# Long feathers fanning out and down from a golden arch.
			for k in 4:
				var ang: float = (0.35 + k * 0.32) * side
				wb.with(Transform3D(Basis(Vector3.FORWARD, ang), Vector3(0.08 * side, 0.2, -0.04 - k * 0.015)), func():
					wb.box(Vector3(0.36 * side, 0, 0), Vector3(0.72 - k * 0.1, 0.1, 0.04), L.shade(L.CLOUD, -0.05 * k)))
			wb.with(Transform3D(Basis(Vector3.FORWARD, 0.35 * side), Vector3(0.08 * side, 0.22, -0.02)), func():
				wb.box(Vector3(0.36 * side, 0.04, 0), Vector3(0.74, 0.05, 0.05), L.GOLD))
			w.add_child(wb.instance())
			_wings.append(w)
	# Head.
	_head = Node3D.new()
	_head.position.y = NECK - HIP
	_torso.add_child(_head)
	_head.add_child(_build_head(skin, kid))

	# Arms (right at -X, left at +X when facing +Z).
	for side in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.position = Vector3(0.235 * side, SHOULDER - HIP - 0.04, 0)
		_torso.add_child(pivot)
		var a := L.new()
		var sleeve := top
		a.ball(Vector3.ZERO, 0.075, sleeve, 0, Vector3(1, 1, 1))
		a.prism(Vector3(0, -0.42, 0), 0.06, 0.07, 0.42, 5, sleeve)
		if robe:  # wide robe sleeves
			a.prism(Vector3(0, -0.46, 0), 0.085, 0.07, 0.14, 6, sleeve)
		a.prism(Vector3(0, -0.5, 0), 0.045, 0.05, 0.08, 5, skin)
		a.ball(Vector3(0, -0.53, 0.0), 0.055, skin, 0)
		if side > 0 and look.get("scroll", false):
			a.with(Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3(0.0, -0.55, 0.02)), func():
				a.prism(Vector3(0, -0.13, 0), 0.04, 0.04, 0.26, 6, L.BONE)
				a.prism(Vector3(0, -0.15, 0), 0.025, 0.025, 0.02, 6, L.WOOD_DARK)
				a.prism(Vector3(0, 0.13, 0), 0.025, 0.025, 0.02, 6, L.WOOD_DARK))
		pivot.add_child(a.instance())
		_arms.append(pivot)

	# Legs: thigh and shin, so people can sit and walk with bent knees.
	for side in [-1.0, 1.0]:
		var hip := Node3D.new()
		hip.position = Vector3(0.085 * side, 0, 0)
		_torso.add_child(hip)
		var th := L.new()
		th.prism(Vector3(0, -(HIP - KNEE) - 0.02, 0), 0.065, 0.08, HIP - KNEE + 0.02, 5, legs)
		hip.add_child(th.instance())
		var knee := Node3D.new()
		knee.position.y = -(HIP - KNEE)
		hip.add_child(knee)
		var sh := L.new()
		sh.prism(Vector3(0, -KNEE + 0.07, 0), 0.055, 0.065, KNEE - 0.06, 5, legs)
		sh.box(Vector3(0, -KNEE + 0.045, 0.035), Vector3(0.1, 0.09, 0.2), shoes, Color(), 0.03)
		knee.add_child(sh.instance())
		_thighs.append(hip)
		_shins.append(knee)

func _build_head(skin: Color, kid: bool) -> MeshInstance3D:
	var h := L.new()
	var hair := _c("hair", L.HAIR_DARK)
	var r := 0.2 if not kid else 0.235
	var c := Vector3(0, 0.06 + r, 0)
	h.prism(Vector3(0, -0.02, 0), 0.06, 0.055, 0.1, 5, skin)
	h.ball(c, r, skin, 1, Vector3(1.0, 1.04, 0.96))
	# Ears.
	for s in [-1.0, 1.0]:
		h.ball(c + Vector3(r * 0.98 * s, -0.01, -0.01), r * 0.2, L.shade(skin, -0.05), 0, Vector3(0.6, 1, 0.9))
	# Face: eyes with a light glint, brows, nose, mouth.
	var fz := c.z + r * 0.9
	for s in [-1.0, 1.0]:
		h.box(c + Vector3(0.075 * s, -0.005, r * 0.9), Vector3(0.05, 0.065, 0.03), L.INK)
		h.box(c + Vector3(0.075 * s + 0.012, 0.012, r * 0.93), Vector3(0.016, 0.016, 0.02), L.CLOUD)
		if look.get("lashes", false):
			h.box(c + Vector3(0.075 * s + 0.024 * s, 0.03, r * 0.9), Vector3(0.02, 0.012, 0.03), L.INK)
		h.box(c + Vector3(0.075 * s, 0.065, r * 0.9), Vector3(0.065, 0.016, 0.03), L.shade(hair, -0.1))
		if look.get("cheeks", false):
			h.box(c + Vector3(0.11 * s, -0.06, r * 0.86), Vector3(0.045, 0.025, 0.02), L.ROSE)
	h.box(c + Vector3(0, -0.045, fz - c.z + 0.012), Vector3(0.035, 0.05, 0.03), L.SKIN_SHADE)
	h.box(c + Vector3(0, -0.105, r * 0.86), Vector3(0.06, 0.016, 0.03), L.shade(L.BERRY, -0.1))
	if look.get("glasses", false):
		for s in [-1.0, 1.0]:
			var g := c + Vector3(0.075 * s, -0.005, r * 0.97)
			h.box(g + Vector3(0, 0.045, 0), Vector3(0.1, 0.014, 0.012), L.INK)
			h.box(g + Vector3(0, -0.045, 0), Vector3(0.1, 0.014, 0.012), L.INK)
			h.box(g + Vector3(0.05, 0, 0), Vector3(0.014, 0.1, 0.012), L.INK)
			h.box(g + Vector3(-0.05, 0, 0), Vector3(0.014, 0.1, 0.012), L.INK)
			h.box(c + Vector3(r * 0.95 * s, 0.03, 0.03), Vector3(0.012, 0.014, r * 1.1), L.INK)
		h.box(c + Vector3(0, 0.0, r * 0.98), Vector3(0.05, 0.012, 0.012), L.INK)
	if look.get("beard", false):
		h.ball(c + Vector3(0, -0.1, r * 0.55), r * 0.62, hair, 1, Vector3(1.15, 0.7, 0.8))
		h.box(c + Vector3(0, -0.07, r * 0.95), Vector3(0.12, 0.03, 0.03), hair)
		h.box(c + Vector3(0, -0.105, r * 0.88), Vector3(0.06, 0.016, 0.06), L.shade(L.BERRY, -0.1))
	# Hair.
	var style := String(look.get("hair_style", "short"))
	h.dome(c + Vector3(0, 0.0, -0.015), r * 1.08, hair, 1, Vector3(1.0, 1.02, 1.04), 0.05)
	h.box(c + Vector3(0, r * 0.62, r * 0.55), Vector3(r * 1.7, r * 0.4, r * 0.55), hair, Color(), 0.03)
	# Side and back hair.
	h.box(c + Vector3(0, -r * 0.05, -r * 0.45), Vector3(r * 2.08, r * 1.0, r * 1.05), hair)
	match style:
		"ponytail":
			h.ball(c + Vector3(0, r * 0.35, -r * 1.05), r * 0.36, hair, 0)
			h.prism(c + Vector3(0, -r * 1.25, -r * 1.12), r * 0.15, r * 0.3, r * 1.5, 5, hair)
			h.box(c + Vector3(0, r * 0.32, -r * 1.0), Vector3(r * 0.4, r * 0.15, r * 0.15), L.TEAL_DARK)
		"bun":
			h.ball(c + Vector3(0, r * 0.75, -r * 0.75), r * 0.46, hair, 1)
		"long":
			h.box(c + Vector3(0, -r * 0.7, -r * 0.6), Vector3(r * 2.0, r * 1.5, r * 0.6), hair)
		"messy":
			for i in 5:
				var a := -0.9 + i * 0.45
				h.with(Transform3D(Basis(Vector3(cos(a), 0.2, sin(a) * 0.4).normalized(), 0.5), c + Vector3(sin(a) * r * 0.6, r * 0.88, -r * 0.1 + cos(a) * 0.04)), func():
					h.prism(Vector3.ZERO, r * 0.22, 0.0, r * 0.45, 4, hair))
		"pigtails":
			for s in [-1.0, 1.0]:
				h.ball(c + Vector3(r * 1.0 * s, r * 0.25, -r * 0.35), r * 0.26, hair, 0)
				h.prism(c + Vector3(r * 1.12 * s, -r * 0.85, -r * 0.4), r * 0.12, r * 0.24, r * 1.05, 5, hair)
				h.box(c + Vector3(r * 1.02 * s, r * 0.22, -r * 0.35), Vector3(r * 0.16, r * 0.2, r * 0.2), L.SUN)
		"short":
			h.box(c + Vector3(0, r * 0.75, -r * 0.1), Vector3(r * 1.6, r * 0.35, r * 1.4), hair, Color(), 0.04)
	if look.has("flower"):
		h.ball(c + Vector3(r * 0.8, r * 0.55, r * 0.2), r * 0.18, look["flower"], 0)
		h.ball(c + Vector3(r * 0.8, r * 0.55, r * 0.2), r * 0.08, L.SUN, 0)
	return h.instance()

# ---------- animation ----------

func _process(delta: float) -> void:
	_t += delta
	var k := minf(1.0, delta * 10.0)
	# Targets for each joint. Arms: x = swing (negative = forward), y = how far out to the side.
	var arm := [Vector2(0.0, 0.07), Vector2(0.0, 0.07)]
	var thigh := [0.0, 0.0]
	var shin := [0.0, 0.0]
	var y := 0.0
	var lean := 0.0
	var head := Vector2.ZERO
	if sitting:
		y = -(HIP - sit_height)
		thigh = [-PI / 2.0 + 0.05, -PI / 2.0 + 0.05]
		var bend := PI / 2.0 - 0.1 if sit_height > 0.3 else 0.15
		shin = [bend, bend]
		arm = [Vector2(-0.55, -0.12), Vector2(-0.55, -0.12)]
		lean = 0.05
	elif walk_speed > 0.05:
		_phase += delta * 7.5 * clampf(walk_speed, 0.5, 1.6)
		var s := sin(_phase)
		thigh = [-s * 0.55, s * 0.55]
		shin = [maxf(0.0, s) * 0.8, maxf(0.0, -s) * 0.8]
		arm = [Vector2(s * 0.5, 0.08), Vector2(-s * 0.5, 0.08)]
		y = absf(cos(_phase)) * 0.04 - 0.02
		lean = 0.06
	else:
		_phase = 0.0
		var breathe := sin(_t * 1.8)
		arm = [Vector2(breathe * 0.03, 0.08 + breathe * 0.02), Vector2(-breathe * 0.03, 0.08 + breathe * 0.02)]
		head = Vector2(sin(_t * 0.7) * 0.04, sin(_t * 0.45) * 0.08)
		y = breathe * 0.005
	match gesture:
		"talk":
			arm[0] = Vector2(-0.75 + sin(_t * 4.0) * 0.18, 0.25 + sin(_t * 2.7) * 0.1)
			head = Vector2(sin(_t * 5.0) * 0.07, sin(_t * 1.3) * 0.1)
		"wave":
			arm[0] = Vector2(-0.2, 2.6 + sin(_t * 11.0) * 0.35)
		"cheer":
			arm = [Vector2(-0.3, 2.7 + sin(_t * 9.0) * 0.15), Vector2(-0.3, 2.7 - sin(_t * 9.0) * 0.15)]
			y += absf(sin(_t * 6.0)) * 0.08
		"hug":
			arm = [Vector2(-1.35, -0.35), Vector2(-1.35, -0.35)]
		"stir":
			arm[0] = Vector2(-0.95 + sin(_t * 4.0) * 0.12, 0.2 + cos(_t * 4.0) * 0.15)
			head = Vector2(0.2, 0.0)
		"play":
			arm[0] = Vector2(-0.9 + sin(_t * 3.0) * 0.3, 0.2)
			arm[1] = Vector2(-0.7 - sin(_t * 2.2) * 0.25, 0.25)
			head = Vector2(0.3, sin(_t * 0.9) * 0.2)
		"write":
			arm[1] = Vector2(-1.0, -0.2)
			arm[0] = Vector2(-0.9 + sin(_t * 9.0) * 0.08, 0.15 + sin(_t * 5.0) * 0.06)
			head = Vector2(0.25, 0.0)
	for i in _wings.size():
		_wings[i].rotation.y = (0.35 + sin(_t * 1.4) * 0.12) * (-1.0 if i == 0 else 1.0)
	_body.position.y = lerpf(_body.position.y, y * _scale, k)
	_torso.rotation.x = lerpf(_torso.rotation.x, lean, k)
	_head.rotation.x = lerpf(_head.rotation.x, head.x, k)
	_head.rotation.y = lerpf(_head.rotation.y, head.y, k)
	for i in 2:
		# The right arm (i 0) is at -X, so moving it outward is a negative turn about Z.
		var a: Vector2 = arm[i]
		_arms[i].rotation.x = lerpf(_arms[i].rotation.x, a.x, k)
		_arms[i].rotation.z = lerpf(_arms[i].rotation.z, a.y * (-1.0 if i == 0 else 1.0), k)
		_thighs[i].rotation.x = lerpf(_thighs[i].rotation.x, thigh[i], k)
		_shins[i].rotation.x = lerpf(_shins[i].rotation.x, shin[i], k)

class_name LowPolyAnimal
extends Node3D
## Low-poly animals, birds and sea creatures, built in code and alive: land animals wander and graze,
## birds fly in loops (or hop about when perched), fish and whales swim, but only inside their water.
## Like everything in the game, the front faces +X.
##
##     var cow := LowPolyAnimal.create("cow")
##     cow.mode = "wander"           # "wander", "fly", "swim", "perch", "still"
##     cow.home = cow.position       # wanders within `radius` of home
##     fish.water = Rect2(x0, z0, w, d)   # swimmers stay inside this rectangle (x, z)
##
## Species: cow, horse, zebra, llama, sheep, pig, wolf, fox, dog, cat, chick, bird, eagle, fish, whale, serpent.

const L := preload("res://core/lowpoly/low_poly.gd")
const LAND := ["cow", "horse", "zebra", "llama", "sheep", "pig", "wolf", "fox", "dog", "cat", "chick"]

var species := "cow"
var mode := "wander"
var home := Vector3.ZERO
var radius := 3.0  ## how far from home a wanderer roams, or a flier circles
var water := Rect2()  ## swimmers stay inside this (x, z)
var depth := -0.14  ## swimming height (the water surface is at about 0.06)
var speed := 1.0
## Return true for spots a walker must not go (water). Set by Props.
var avoid := Callable()
## Walkers stay within these z limits (open ground beside the path).
var z_limit := Vector2(-8.5, 8.5)

var _body: Node3D  # built facing +Z, turned to face +X
var _torso: Node3D
var _head: Node3D
var _tail: Node3D
var _legs: Array[Node3D] = []
var _wings: Array[Node3D] = []
var _target := Vector3.ZERO
var _moving := false
var _run := false
var _wait := 0.0
var _t := 0.0
var _graze := 0.0
var _angle := 0.0
var _rng := RandomNumberGenerator.new()
var _base_y := 0.0
var _flier := false
var _swimmer := false

static func create(id: String, color_seed: int = 0) -> LowPolyAnimal:
	var a := LowPolyAnimal.new()
	a.species = id
	a._rng.seed = color_seed + hash(id)
	a._build()
	match id:
		"bird", "eagle":
			a.mode = "fly"
		"fish", "whale":
			a.mode = "swim"
		"serpent":
			a.mode = "still"
	return a

func _ready() -> void:
	home = position if home == Vector3.ZERO else home
	_t = _rng.randf() * 10.0
	_wait = _rng.randf_range(0.0, 3.0)
	_angle = _rng.randf() * TAU
	_base_y = position.y
	_flier = species in ["bird", "eagle"]
	_swimmer = species in ["fish", "whale"]
	speed *= {"chick": 0.8, "pig": 0.8, "sheep": 0.8, "cow": 0.7, "horse": 1.3, "zebra": 1.3, "wolf": 1.4, "fox": 1.4,
		"dog": 1.3, "cat": 1.1, "llama": 0.9, "bird": 3.0, "eagle": 2.6, "fish": 1.0, "whale": 0.45}.get(species, 1.0)
	if mode == "swim":
		if water.size == Vector2.ZERO:
			water = Rect2(position.x - 2.0, position.z - 2.0, 4.0, 4.0)
		position = _swim_spot()
		if species == "whale":
			depth = -0.3
		position.y = depth

## Go quickly to `p` (startled), then settle there.
func run_to(p: Vector3) -> void:
	home = p
	_target = p
	_moving = true
	_run = true
	_wait = 0.0

## Walk or stop (used by CharacterFactory.play for "Walk"/"Idle").
func set_moving(on: bool) -> void:
	if not on:
		_moving = false
		_wait = 2.0

# ---------- behavior ----------

func _process(delta: float) -> void:
	_t += delta
	match mode:
		"wander":
			_wander(delta)
		"fly":
			_fly(delta)
		"swim":
			_swim(delta)
		"perch":
			_moving = false
	_animate(delta)

func _wander(delta: float) -> void:
	if not _moving:
		_wait -= delta
		if _wait <= 0.0:
			for i in 8:
				var a := _rng.randf() * TAU
				var r := _rng.randf_range(0.6, radius)
				var p := home + Vector3(cos(a) * r, 0, sin(a) * r)
				p.z = clampf(p.z, z_limit.x, z_limit.y)
				if not (avoid.is_valid() and avoid.call(p)):
					_target = p
					_moving = true
					break
			_wait = 1.0
		return
	var to := _target - position
	to.y = 0.0
	var step := speed * (2.6 if _run else 1.0) * delta
	if to.length() <= step:
		position = Vector3(_target.x, position.y, _target.z)
		_moving = false
		_run = false
		_wait = _rng.randf_range(1.5, 5.0)
		_graze = _rng.randf_range(1.0, 2.5) if _rng.randf() < 0.6 else 0.0
		return
	var dir := to.normalized()
	var next := position + dir * step
	if avoid.is_valid() and avoid.call(next):
		_moving = false
		_wait = 0.3
		return
	position = next
	_turn_to(dir, delta)

func _fly(delta: float) -> void:
	# Loop around home in a wobbly circle, rising and dipping.
	var r := radius * (0.8 + 0.25 * sin(_t * 0.3))
	_angle += speed / maxf(r, 0.5) * delta
	var p := home + Vector3(cos(_angle) * r, sin(_t * 0.7) * 0.6, sin(_angle) * r * 0.7)
	var dir := (p - position)
	position = p
	dir.y = 0.0
	if dir.length() > 0.0001:
		rotation.y = atan2(-dir.z, dir.x)
	rotation.z = -0.35 if species == "bird" else -0.25  # bank into the turn

func _swim(delta: float) -> void:
	if not _moving:
		_wait -= delta
		if _wait <= 0.0:
			_target = _swim_spot()
			_moving = true
		return
	var to := _target - position
	to.y = 0.0
	var step := speed * delta
	if to.length() <= step:
		_moving = false
		_wait = _rng.randf_range(0.2, 1.5) if species == "fish" else _rng.randf_range(1.0, 3.0)
		return
	var dir := to.normalized()
	position += dir * step
	position.y = depth + sin(_t * 1.3) * 0.02
	_turn_to(dir, delta)

func _swim_spot() -> Vector3:
	var m := 0.5 if species == "fish" else 1.8
	var x := _rng.randf_range(water.position.x + m, maxf(water.position.x + m, water.end.x - m))
	var z := _rng.randf_range(water.position.y + m, maxf(water.position.y + m, water.end.y - m))
	return Vector3(x, depth, z)

func _turn_to(dir: Vector3, delta: float) -> void:
	rotation.y = lerp_angle(rotation.y, atan2(-dir.z, dir.x), minf(1.0, delta * 5.0))

# ---------- animation ----------

func _animate(delta: float) -> void:
	var k := minf(1.0, delta * 8.0)
	if _flier:
		var flap := sin(_t * (14.0 if species == "bird" else 6.0))
		if mode == "perch":
			flap = -0.9 + sin(_t * 0.5) * 0.05
			if _head:
				_head.rotation.y = sin(_t * 0.9) * 0.6
		elif species == "eagle" and fmod(_t, 6.0) > 3.5:
			flap = 0.15  # glide
		for i in _wings.size():
			_wings[i].rotation.z = flap * 0.8 * (1.0 if i == 0 else -1.0)
		return
	if _swimmer:
		if _tail:
			_tail.rotation.y = sin(_t * (9.0 if species == "fish" else 1.6)) * (0.5 if species == "fish" else 0.25)
		if species == "whale" and _tail:
			_tail.rotation.x = sin(_t * 1.6) * 0.25
		return
	if species == "serpent":
		if _head:
			_head.rotation.y = sin(_t * 0.8) * 0.35
			_head.rotation.x = sin(_t * 1.3) * 0.12
		if _torso:
			_torso.rotation.y = sin(_t * 0.5) * 0.1
		return
	var walking := _moving
	var rate := 10.0 * (1.5 if _run else 1.0) * speed / maxf(0.6, float(_legs.size()) * 0.25)
	if species == "chick":
		_torso.position.y = lerpf(_torso.position.y, absf(sin(_t * 12.0)) * 0.08 if walking else 0.0, k)
	for i in _legs.size():
		var swing := sin(_t * rate + (PI if i in [1, 2] else 0.0)) * 0.6 if walking else 0.0
		_legs[i].rotation.x = lerpf(_legs[i].rotation.x, swing, k)
	if _torso and species != "chick":
		_torso.position.y = lerpf(_torso.position.y, absf(sin(_t * rate)) * 0.03 if walking else 0.0, k)
	if _head:
		var down := 0.0
		if not walking and _graze > 0.0:
			_graze -= delta
			down = 0.9 if species in ["cow", "horse", "zebra", "sheep", "llama", "pig"] else 0.4
		_head.rotation.x = lerpf(_head.rotation.x, down, minf(1.0, delta * 3.0))
		_head.rotation.y = lerpf(_head.rotation.y, 0.0 if walking else sin(_t * 0.6) * 0.3, k)
	if _tail:
		_tail.rotation.y = sin(_t * (6.0 if species in ["dog", "wolf", "fox"] else 2.5)) * 0.35

# ---------- building ----------

func _build() -> void:
	_body = Node3D.new()
	_body.rotation.y = PI / 2.0
	add_child(_body)
	match species:
		"cow":
			_quad({"len": 1.25, "h": 0.72, "girth": 0.34, "body": L.CLOUD, "spots": L.INK, "head": L.CLOUD,
				"muzzle": L.ROSE, "horns": L.BONE, "ears": "side", "tail": "tuft", "udder": L.ROSE})
		"horse":
			_quad({"len": 1.3, "h": 0.9, "girth": 0.3, "body": L.WOOD, "head": L.WOOD, "muzzle": L.WOOD_DARK,
				"neck": 0.55, "mane": L.HAIR_DARK, "ears": "point", "tail": "long", "tail_c": L.HAIR_DARK, "socks": L.CLOUD})
		"zebra":
			_quad({"len": 1.2, "h": 0.85, "girth": 0.28, "body": L.CLOUD, "stripes": L.INK, "head": L.CLOUD, "muzzle": L.INK,
				"neck": 0.5, "mane": L.INK, "ears": "point", "tail": "tuft", "tail_c": L.INK})
		"llama":
			_quad({"len": 0.9, "h": 0.75, "girth": 0.28, "body": L.BONE, "head": L.BONE, "muzzle": L.shade(L.BONE, -0.15),
				"neck": 0.7, "neck_up": 0.2, "ears": "tall", "tail": "stub", "wool": true})
		"sheep":
			_quad({"len": 0.85, "h": 0.5, "girth": 0.3, "body": L.CLOUD, "head": L.INK, "muzzle": L.INK, "legs": L.INK,
				"ears": "side", "tail": "stub", "fluffy": true})
		"pig":
			_quad({"len": 0.85, "h": 0.4, "girth": 0.3, "body": L.ROSE, "head": L.ROSE, "muzzle": L.shade(L.ROSE, 0.15),
				"snout": true, "ears": "point", "tail": "curl"})
		"wolf":
			_quad({"len": 0.95, "h": 0.6, "girth": 0.22, "body": L.STONE, "head": L.STONE, "muzzle": L.CLOUD,
				"chest": L.CLOUD, "ears": "point", "tail": "bushy", "snout_len": 0.2})
		"fox":
			_quad({"len": 0.75, "h": 0.42, "girth": 0.17, "body": L.TERRACOTTA, "head": L.TERRACOTTA, "muzzle": L.CLOUD,
				"chest": L.CLOUD, "ears": "point", "tail": "bushy", "tail_tip": L.CLOUD, "legs": L.INK, "snout_len": 0.18})
		"dog":
			_quad({"len": 0.75, "h": 0.45, "girth": 0.19, "body": Color("d9a25a"), "head": Color("d9a25a"),
				"muzzle": Color("efc98a"), "ears": "floppy", "tail": "bushy"})
		"cat":
			_quad({"len": 0.55, "h": 0.3, "girth": 0.13, "body": L.STONE, "stripes": L.shade(L.STONE, -0.3), "head": L.STONE,
				"muzzle": L.CLOUD, "ears": "point", "tail": "up"})
		"chick":
			_chick()
		"bird", "eagle":
			_bird(species == "eagle")
		"fish":
			_fish()
		"whale":
			_whale()
		"serpent":
			_serpent()

func _limb(parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	return n

## A four-legged animal from a few numbers and colors.
func _quad(p: Dictionary) -> void:
	var length: float = p["len"]
	var h: float = p["h"]
	var g: float = p["girth"]
	var body: Color = p["body"]
	var legs_c: Color = p.get("legs", L.shade(body, -0.1))
	_torso = _limb(_body, Vector3.ZERO)
	var b := L.new()
	var cy := h + g * 0.6
	# Barrel of the body, lying along Z.
	b.with(Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3(0, cy, 0)), func():
		b.prism(Vector3(0, -length / 2.0, 0), g * 0.95, g, length, 7, body, body, Vector2(1.0, 1.1)))
	b.ball(Vector3(0, cy, length / 2.0 - 0.02), g * 1.02, body, 1, Vector3(1.0, 1.05, 0.7))
	b.ball(Vector3(0, cy, -length / 2.0 + 0.02), g * 0.98, body, 1, Vector3(1.0, 1.0, 0.7))
	if p.get("fluffy", false) or p.get("wool", false):
		var wool := body
		for i in 9:
			var a := i * 2.4
			b.ball(Vector3(cos(a) * g * 0.7, cy + absf(sin(a)) * g * 0.55, -length * 0.4 + i * length * 0.1), g * 0.55, L.shade(wool, 0.04 * (i % 2)), 0)
	if p.has("spots"):
		for s in [[-1.0, 0.1, 0.18], [1.0, -0.25, 0.22], [-1.0, -0.3, 0.15], [1.0, 0.25, 0.14]]:
			b.box(Vector3(g * 0.98 * s[0], cy + 0.05, length * s[1]), Vector3(0.03, g * 0.9, s[2] * 1.6), p["spots"])
		b.box(Vector3(0, cy + g * 0.98, -0.1), Vector3(g * 0.9, 0.03, 0.26), p["spots"])
	if p.has("stripes"):
		# Thin bands that follow the body's shape.
		b.with(Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3(0, cy, 0)), func():
			for i in 7:
				b.prism(Vector3(0, -length * 0.42 + i * length * 0.14, 0), g * 1.0, g * 1.03, 0.05, 7, p["stripes"], p["stripes"], Vector2(1.0, 1.1)))
	if p.has("chest"):
		b.ball(Vector3(0, cy - g * 0.2, length / 2.0 + 0.02), g * 0.75, p["chest"], 0, Vector3(1.0, 1.0, 0.7))
	if p.has("udder"):
		b.ball(Vector3(0, cy - g * 0.95, -length * 0.15), g * 0.3, p["udder"], 0)
	if p.has("mane"):
		var nl: float = p.get("neck", 0.0)
		b.box(Vector3(0, cy + g * 0.8 + nl * 0.35, length / 2.0 + nl * 0.25), Vector3(0.05, nl * 0.7 + 0.1, 0.25), p["mane"])
	_torso.add_child(b.instance())
	# Neck and head.
	var neck: float = p.get("neck", 0.0)
	var up: float = p.get("neck_up", 0.7)  # lean of the neck, forward from straight up
	var head_base := Vector3(0, cy + g * 0.2, length / 2.0)
	if neck > 0.0:
		var nb := L.new()
		nb.with(Transform3D(Basis(Vector3.RIGHT, up), head_base), func():
			nb.prism(Vector3(0, -0.05, 0), g * 0.55, g * 0.42, neck + 0.05, 6, body))
		_torso.add_child(nb.instance())
		head_base += Vector3(0, cos(up) * neck, sin(up) * neck)
	_head = _limb(_torso, head_base + Vector3(0, 0.02, 0.04))
	var hd := L.new()
	var hs := g * 0.75 + 0.04
	var head_c: Color = p.get("head", body)
	var snout_len: float = p.get("snout_len", hs * 0.9 if neck > 0.0 else hs * 0.5)
	hd.ball(Vector3(0, 0.02, 0.05), hs, head_c, 1, Vector3(0.95, 0.95, 1.05))
	hd.box(Vector3(0, -0.04, 0.05 + hs * 0.6 + snout_len * 0.5), Vector3(hs * 1.0, hs * 0.85, snout_len + 0.05), p.get("muzzle", head_c), Color(), 0.02)
	var tip := 0.05 + hs * 0.6 + snout_len + 0.03
	hd.box(Vector3(0, -0.01, tip), Vector3(hs * 0.5, hs * 0.3, 0.03), L.INK)
	if p.get("snout", false):
		hd.prism(Vector3(0, -0.05, tip - 0.02), hs * 0.4, hs * 0.4, 0.06, 8, L.shade(L.ROSE, -0.1))
	for s in [-1.0, 1.0]:
		hd.box(Vector3(hs * 0.62 * s, 0.07, 0.05 + hs * 0.55), Vector3(0.05, 0.06, 0.03), L.INK)
		hd.box(Vector3(hs * 0.62 * s + 0.01 * s, 0.085, 0.05 + hs * 0.57), Vector3(0.015, 0.015, 0.02), L.CLOUD)
		match String(p.get("ears", "point")):
			"point":
				hd.with(Transform3D(Basis(Vector3.FORWARD, -0.25 * s), Vector3(hs * 0.55 * s, hs * 0.75, 0.0)), func():
					hd.prism(Vector3.ZERO, hs * 0.3, 0.0, hs * 0.75, 4, L.shade(head_c, -0.15)))
			"tall":
				hd.with(Transform3D(Basis(Vector3.FORWARD, -0.15 * s), Vector3(hs * 0.5 * s, hs * 0.7, -0.02)), func():
					hd.prism(Vector3.ZERO, hs * 0.18, hs * 0.1, hs * 1.2, 5, L.shade(head_c, -0.1)))
			"side":
				hd.box(Vector3(hs * 1.05 * s, hs * 0.3, -0.02), Vector3(hs * 0.6, hs * 0.18, hs * 0.35), L.shade(head_c, -0.15))
			"floppy":
				hd.with(Transform3D(Basis(Vector3.FORWARD, 0.35 * s), Vector3(hs * 0.85 * s, hs * 0.4, 0.0)), func():
					hd.box(Vector3(0, -hs * 0.4, 0), Vector3(hs * 0.3, hs * 0.95, hs * 0.65), L.shade(head_c, -0.2)))
		if p.has("horns"):
			hd.with(Transform3D(Basis(Vector3.FORWARD, -0.9 * s), Vector3(hs * 0.55 * s, hs * 0.75, 0.0)), func():
				hd.prism(Vector3.ZERO, hs * 0.13, 0.0, hs * 0.65, 5, p["horns"]))
	_head.add_child(hd.instance())
	# Legs.
	var lx := g * 0.55
	var lz := length / 2.0 - 0.08
	for c in [Vector2(-lx, lz), Vector2(lx, lz), Vector2(-lx, -lz), Vector2(lx, -lz)]:
		var leg := _limb(_torso, Vector3(c.x, cy - g * 0.3, c.y))
		var lb := L.new()
		var top := cy - g * 0.3
		lb.prism(Vector3(0, -top, 0), g * 0.2, g * 0.27, top, 5, legs_c)
		var sock: Color = p.get("socks", L.shade(legs_c, -0.35))
		lb.prism(Vector3(0, -top, 0), g * 0.22, g * 0.21, 0.07, 5, sock)
		leg.add_child(lb.instance())
		_legs.append(leg)
	# Tail.
	_tail = _limb(_torso, Vector3(0, cy + g * 0.3, -length / 2.0 - g * 0.45))
	var tb := L.new()
	var tc: Color = p.get("tail_c", body)
	match String(p.get("tail", "thin")):
		"tuft", "thin":
			tb.with(Transform3D(Basis(Vector3.RIGHT, -2.7), Vector3.ZERO), func():
				tb.prism(Vector3.ZERO, 0.03, 0.02, h * 0.7, 4, tc))
			tb.ball(Vector3(0, -h * 0.65, -h * 0.3), 0.06, L.shade(tc, -0.4) if p.get("tail", "") == "tuft" else tc, 0)
		"long":
			tb.with(Transform3D(Basis(Vector3.RIGHT, -2.6), Vector3.ZERO), func():
				tb.prism(Vector3.ZERO, 0.09, 0.05, h * 0.75, 5, tc))
		"bushy":
			tb.with(Transform3D(Basis(Vector3.RIGHT, -2.0), Vector3.ZERO), func():
				tb.ball(Vector3(0, g * 0.75, 0), g * 0.45, tc, 0, Vector3(0.8, 2.0, 0.8))
				if p.has("tail_tip"):
					tb.ball(Vector3(0, g * 1.6, 0), g * 0.28, p["tail_tip"], 0))
		"up":
			tb.with(Transform3D(Basis(Vector3.RIGHT, -0.5), Vector3.ZERO), func():
				tb.prism(Vector3.ZERO, 0.03, 0.025, h * 1.2, 4, tc))
		"curl":
			tb.hoop(Vector3(0, 0, -0.06), 0.06, 0.02, 6, tc, 3)
		"stub":
			tb.ball(Vector3.ZERO, g * 0.3, tc, 0)
	_tail.add_child(tb.instance())

func _chick() -> void:
	_torso = _limb(_body, Vector3.ZERO)
	var b := L.new()
	b.ball(Vector3(0, 0.18, 0), 0.14, L.SUN, 1, Vector3(1, 0.95, 1.15))
	b.ball(Vector3(0, 0.36, 0.08), 0.1, L.SUN, 1)
	b.prism(Vector3(0, 0.34, 0.16), 0.035, 0.0, 0.08, 4, L.TERRACOTTA)
	b.with(Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3(0, 0.34, 0.16)), func():
		b.prism(Vector3.ZERO, 0.035, 0.0, 0.07, 4, L.TERRACOTTA))
	for s in [-1.0, 1.0]:
		b.box(Vector3(0.05 * s, 0.39, 0.155), Vector3(0.025, 0.03, 0.02), L.INK)
		b.ball(Vector3(0.13 * s, 0.19, -0.01), 0.07, L.shade(L.SUN, -0.1), 0, Vector3(0.5, 1, 1.2))
	_torso.add_child(b.instance())
	for s in [-1.0, 1.0]:
		var leg := _limb(_torso, Vector3(0.05 * s, 0.08, 0))
		var lb := L.new()
		lb.prism(Vector3(0, -0.08, 0), 0.015, 0.015, 0.08, 4, L.TERRACOTTA)
		lb.box(Vector3(0, -0.075, 0.03), Vector3(0.05, 0.015, 0.06), L.TERRACOTTA)
		leg.add_child(lb.instance())
		_legs.append(leg)

func _bird(eagle: bool) -> void:
	var s := 1.6 if eagle else 0.55
	var c: Color = L.WOOD_DARK if eagle else [L.SKY, L.TERRACOTTA, L.SUN, L.TEAL][_rng.randi() % 4]
	var b := L.new()
	b.ball(Vector3(0, 0, 0), 0.16 * s, c, 1, Vector3(0.9, 0.85, 1.5))
	b.ball(Vector3(0, -0.04 * s, 0.05 * s), 0.12 * s, L.CLOUD if not eagle else L.shade(c, 0.1), 0, Vector3(0.8, 0.8, 1.3))
	b.with(Transform3D(Basis(Vector3.RIGHT, -PI / 2.0 - 0.15), Vector3(0, 0.02 * s, -0.2 * s)), func():
		b.prism(Vector3.ZERO, 0.08 * s, 0.13 * s, 0.18 * s, 4, L.shade(c, -0.15), Color(), Vector2(1.0, 0.3)))
	_torso = _body
	_head = _limb(_body, Vector3(0, 0.08 * s, 0.22 * s))
	var h := L.new()
	h.ball(Vector3.ZERO, 0.11 * s, L.CLOUD if eagle else c, 1)
	h.with(Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3(0, -0.01 * s, 0.09 * s)), func():
		h.prism(Vector3.ZERO, 0.04 * s, 0.0, 0.1 * s, 4, L.GOLD))
	for k in [-1.0, 1.0]:
		h.box(Vector3(0.07 * s * k, 0.03 * s, 0.07 * s), Vector3(0.025 * s, 0.03 * s, 0.02 * s), L.INK)
	_head.add_child(h.instance())
	_body.add_child(b.instance())
	for k in [-1.0, 1.0]:
		var w := _limb(_body, Vector3(0.1 * s * k, 0.04 * s, 0))
		var wb := L.new()
		wb.box(Vector3(0.22 * s * k, 0, -0.02 * s), Vector3(0.42 * s, 0.03 * s, 0.24 * s), L.shade(c, -0.08))
		wb.box(Vector3(0.38 * s * k, 0, -0.06 * s), Vector3(0.18 * s, 0.025 * s, 0.18 * s), L.shade(c, -0.2))
		w.add_child(wb.instance())
		_wings.append(w)

func _fish() -> void:
	var c: Color = [L.TERRACOTTA, L.SUN, L.SKY, L.TEAL, L.ROSE][_rng.randi() % 5]
	var b := L.new()
	b.ball(Vector3.ZERO, 0.13, c, 1, Vector3(0.6, 0.8, 1.6))
	b.with(Transform3D(Basis(Vector3.RIGHT, -0.4), Vector3(0, 0.08, 0.0)), func():
		b.prism(Vector3.ZERO, 0.06, 0.0, 0.1, 3, L.shade(c, -0.2), Color(), Vector2(0.3, 1.5)))
	for s in [-1.0, 1.0]:
		b.box(Vector3(0.07 * s, 0.03, 0.12), Vector3(0.02, 0.03, 0.03), L.INK)
	_body.add_child(b.instance())
	_tail = _limb(_body, Vector3(0, 0, -0.19))
	var t := L.new()
	t.with(Transform3D(Basis(Vector3.RIGHT, -PI / 2.0), Vector3.ZERO), func():
		t.prism(Vector3.ZERO, 0.02, 0.1, 0.12, 3, L.shade(c, 0.1), Color(), Vector2(0.3, 1.6)))
	_tail.add_child(t.instance())

func _whale() -> void:
	var c := L.SLATE
	var b := L.new()
	b.ball(Vector3.ZERO, 0.7, c, 1, Vector3(0.75, 0.6, 1.9))
	b.ball(Vector3(0, -0.12, 0.2), 0.62, L.shade(L.SKY, 0.2), 1, Vector3(0.6, 0.45, 1.6))
	for s in [-1.0, 1.0]:
		b.box(Vector3(0.36 * s, 0.05, 0.75), Vector3(0.05, 0.08, 0.06), L.INK)
		b.with(Transform3D(Basis(Vector3.FORWARD, 0.6 * s), Vector3(0.5 * s, -0.2, 0.35)), func():
			b.box(Vector3(0.2 * s, 0, 0), Vector3(0.45, 0.05, 0.25), L.shade(c, -0.1)))
	_body.add_child(b.instance())
	_tail = _limb(_body, Vector3(0, 0.05, -1.25))
	var t := L.new()
	t.prism(Vector3(0, 0, -0.1), 0.18, 0.1, 0.01, 5, c)
	t.with(Transform3D(Basis(Vector3.RIGHT, -PI / 2.0), Vector3.ZERO), func():
		t.prism(Vector3.ZERO, 0.15, 0.08, 0.45, 5, c, Color(), Vector2(1.0, 0.6)))
	t.box(Vector3(0, 0, -0.5), Vector3(0.95, 0.05, 0.3), L.shade(c, -0.1))
	_tail.add_child(t.instance())

## The serpent coiled at the foot of the tree, head raised and swaying.
func _serpent() -> void:
	var c := L.LEAF
	_torso = _limb(_body, Vector3.ZERO)
	var b := L.new()
	var pts: Array[Vector3] = []
	for i in 26:
		var a := i * 0.55
		var r := 0.42 - i * 0.011
		pts.append(Vector3(cos(a) * r, 0.1 + i * 0.04, sin(a) * r))
	for i in pts.size() - 1:
		var a: Vector3 = pts[i]
		var d: Vector3 = pts[i + 1] - a
		var thick := 0.12 - i * 0.0025
		var basis := Basis(Quaternion(Vector3.UP, d.normalized()))
		b.with(Transform3D(basis, a), func():
			b.prism(Vector3(0, -0.02, 0), thick, thick * 0.95, d.length() + 0.04, 6, L.shade(c, 0.07 if i % 3 == 0 else 0.0)))
	b.ball(pts[0], 0.12, c, 0)
	_torso.add_child(b.instance())
	_head = _limb(_torso, Vector3(0.1, 1.12, 0.05))
	var h := L.new()
	for i in 4:
		h.ball(Vector3(0, -0.12 + i * 0.05, i * 0.06), 0.09, c, 0)
	h.ball(Vector3(0, 0.08, 0.26), 0.12, L.shade(c, 0.1), 1, Vector3(0.85, 0.6, 1.3))
	for s in [-1.0, 1.0]:
		h.box(Vector3(0.07 * s, 0.13, 0.32), Vector3(0.03, 0.03, 0.03), L.SUN)
	h.box(Vector3(0, 0.05, 0.45), Vector3(0.015, 0.01, 0.1), L.TERRACOTTA)
	_head.add_child(h.instance())

class_name LowPolyDog
extends Node3D
## Biscuit, the family dog: a faceted golden retriever pup, animated in code. Front faces +X.
## pose: "lie", "sit", "stand". walk_speed > 0 trots. wag 0..1 sets how happy the tail is.

const L := preload("res://core/lowpoly/low_poly.gd")
const COAT := Color("d9a25a")
const COAT_LIGHT := Color("efc98a")

var pose := "lie"
var walk_speed := 0.0
var wag := 0.3

var _body: Node3D
var _torso: Node3D
var _head: Node3D
var _tail: Node3D
var _legs: Array[Node3D] = []  # front right, front left, back right, back left
var _t := 0.0

func _ready() -> void:
	_t = randf() * 5.0
	_body = Node3D.new()
	_body.rotation.y = PI / 2.0  # built facing +Z
	add_child(_body)
	_torso = Node3D.new()
	_torso.position.y = 0.34
	_body.add_child(_torso)
	var b := L.new()
	b.with(Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3.ZERO), func():
		b.prism(Vector3(0, -0.24, 0.0), 0.12, 0.135, 0.48, 6, COAT))
	b.ball(Vector3(0, -0.02, 0.2), 0.14, COAT_LIGHT, 1, Vector3(0.9, 1.0, 0.9))
	b.prism(Vector3(0, 0.06, 0.19), 0.1, 0.1, 0.05, 7, L.TEAL_DARK)
	b.box(Vector3(0, 0.0, 0.29), Vector3(0.05, 0.05, 0.02), L.glow(L.TEAL, 0.7))
	_torso.add_child(b.instance())
	_head = Node3D.new()
	_head.position = Vector3(0, 0.12, 0.27)
	_torso.add_child(_head)
	var h := L.new()
	h.ball(Vector3(0, 0.08, 0.04), 0.13, COAT, 1, Vector3(1.0, 0.95, 1.0))
	h.box(Vector3(0, 0.03, 0.17), Vector3(0.11, 0.09, 0.12), COAT_LIGHT, Color(), 0.02)
	h.box(Vector3(0, 0.07, 0.235), Vector3(0.05, 0.04, 0.03), L.INK)
	for s in [-1.0, 1.0]:
		h.box(Vector3(0.055 * s, 0.13, 0.15), Vector3(0.035, 0.04, 0.02), L.INK)
		h.box(Vector3(0.055 * s + 0.008, 0.14, 0.16), Vector3(0.012, 0.012, 0.01), L.CLOUD)
		h.with(Transform3D(Basis(Vector3.FORWARD, 0.35 * s), Vector3(0.12 * s, 0.1, 0.0)), func():
			h.box(Vector3(0, -0.06, 0), Vector3(0.05, 0.16, 0.1), L.shade(COAT, -0.2)))
	h.box(Vector3(0, -0.02, 0.2), Vector3(0.04, 0.012, 0.04), L.ROSE)
	_head.add_child(h.instance())
	_tail = Node3D.new()
	_tail.position = Vector3(0, 0.03, -0.25)
	_torso.add_child(_tail)
	var t := L.new()
	t.with(Transform3D(Basis(Vector3.RIGHT, -0.9), Vector3.ZERO), func():
		t.prism(Vector3.ZERO, 0.04, 0.015, 0.24, 5, COAT_LIGHT))
	_tail.add_child(t.instance())
	for p in [Vector3(-0.08, 0, 0.17), Vector3(0.08, 0, 0.17), Vector3(-0.08, 0, -0.18), Vector3(0.08, 0, -0.18)]:
		var leg := Node3D.new()
		leg.position = p + Vector3(0, -0.06, 0)
		_torso.add_child(leg)
		var lb := L.new()
		lb.prism(Vector3(0, -0.27, 0), 0.04, 0.05, 0.27, 5, COAT)
		lb.box(Vector3(0, -0.265, 0.02), Vector3(0.07, 0.04, 0.09), COAT_LIGHT)
		leg.add_child(lb.instance())
		_legs.append(leg)

func _process(delta: float) -> void:
	_t += delta
	var k := minf(1.0, delta * 8.0)
	var y := 0.34
	var tilt := 0.0
	var legs := [0.0, 0.0, 0.0, 0.0]
	var head := Vector2(sin(_t * 0.8) * 0.08, sin(_t * 0.5) * 0.2)
	if walk_speed > 0.05:
		var s := sin(_t * 12.0)
		legs = [s * 0.6, -s * 0.6, -s * 0.6, s * 0.6]
		y += absf(s) * 0.025
	elif pose == "lie":
		y = 0.14
		legs = [-1.4, -1.4, 1.4, 1.4]
		head = Vector2(0.15 + sin(_t * 0.6) * 0.05, 0.25)
	elif pose == "sit":
		y = 0.27
		tilt = -0.5
		legs = [0.5, 0.5, -1.0, -1.0]
	_torso.position.y = lerpf(_torso.position.y, y, k)
	_torso.rotation.x = lerpf(_torso.rotation.x, tilt, k)
	_head.rotation.x = lerpf(_head.rotation.x, head.x - tilt * 0.8, k)
	_head.rotation.y = lerpf(_head.rotation.y, head.y, k)
	for i in 4:
		_legs[i].rotation.x = lerpf(_legs[i].rotation.x, legs[i], k)
	_tail.rotation.y = sin(_t * (6.0 + wag * 14.0)) * (0.25 + wag * 0.5)

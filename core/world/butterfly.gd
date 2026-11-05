extends Node3D
## A low-poly butterfly: two flat wings that flap while it drifts in slow loops around where it
## was put. Made by Props.butterfly().

var color := Color(1.0, 0.7, 0.3)
var _wings: Array[Node3D] = []
var _home := Vector3.ZERO
var _t := 0.0
var _r := 1.2

func _ready() -> void:
	_home = position
	_t = fmod(absf(position.x * 3.1 + position.z * 1.7), TAU)
	_r = 0.8 + fmod(absf(position.x), 1.0)
	for side in [-1.0, 1.0]:
		var pivot := Node3D.new()
		add_child(pivot)
		var w := MeshInstance3D.new()
		w.mesh = Props.box(Vector3(0.16, 0.01, 0.12))
		w.material_override = Props.mat(color, 0.4)
		w.position = Vector3(0, 0, side * 0.08)
		pivot.add_child(w)
		_wings.append(pivot)

func _process(delta: float) -> void:
	_t += delta
	var a := _t * 0.7
	var p := _home + Vector3(cos(a) * _r, 0.6 + sin(_t * 1.9) * 0.25, sin(a * 1.3) * _r * 0.7)
	var dir := p - position
	position = p
	if dir.length() > 0.0001:
		rotation.y = atan2(-dir.z, dir.x)
	var flap := sin(_t * 18.0) * 1.0
	_wings[0].rotation.x = flap
	_wings[1].rotation.x = -flap

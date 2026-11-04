extends Node3D
## The scribe: a simple low-poly figure that walks freely on the ground plane (top-down 3D).
## Move with WASD or the on-screen joystick (move_vec: x = right, y = down the screen / +Z).
## frozen stops movement during dialogue; min_x/max_x and z limits keep the scribe in bounds.

@export var speed := 4.0
var move_vec := Vector2.ZERO  # set by the joystick
var frozen := false
var min_x := -2.0
var max_x := 1e9
var min_z := -14.0
var max_z := 14.0
var female := true

var _visual: Node3D
var _legs: Array[Node3D] = []
var _t := 0.0

func _ready() -> void:
	_visual = Node3D.new()
	add_child(_visual)
	var robe := Color(0.82, 0.74, 0.55)
	var sash := Color(0.55, 0.2, 0.15)
	var skin := Color(0.85, 0.68, 0.52)
	var hair := Color(0.25, 0.15, 0.1) if female else Color(0.18, 0.12, 0.08)
	_mesh(_cyl(0.28, 0.42, 1.0, 8), robe, Vector3(0, 0.75, 0), _visual)
	_mesh(_cyl(0.34, 0.34, 0.1, 8), sash, Vector3(0, 0.82, 0), _visual)
	_mesh(_sphere(0.2), skin, Vector3(0, 1.45, 0), _visual)
	_mesh(_sphere(0.215, 0.7), hair, Vector3(0, 1.5, -0.02), _visual)
	if female:
		_mesh(_cyl(0.13, 0.08, 0.5, 6), hair, Vector3(0, 1.2, -0.17), _visual)
	_mesh(_box(Vector3(0.12, 0.3, 0.4)), Color(0.4, 0.28, 0.16), Vector3(0.25, 0.75, 0), _visual)
	for x in [-0.12, 0.12]:
		var leg := Node3D.new()
		leg.position = Vector3(x, 0.28, 0)
		_visual.add_child(leg)
		_mesh(_cyl(0.07, 0.07, 0.3, 6), Color(0.35, 0.25, 0.15), Vector3(0, -0.14, 0), leg)
		_legs.append(leg)

func _process(delta: float) -> void:
	var v := Vector2(Input.get_axis("move_left", "move_right"), Input.get_axis("move_up", "move_down"))
	if v == Vector2.ZERO:
		v = move_vec
	if frozen:
		v = Vector2.ZERO
	if v.length() > 1.0:
		v = v.normalized()
	position.x = clampf(position.x + v.x * speed * delta, min_x, max_x)
	position.z = clampf(position.z + v.y * speed * delta, min_z, max_z)
	if v.length() > 0.05:
		_t += delta * 9.0
		# Face the direction of travel (the figure's front is +X).
		var target := atan2(-v.y, v.x)
		_visual.rotation.y = lerp_angle(_visual.rotation.y, target, 0.25)
		_visual.position.y = absf(sin(_t)) * 0.07
		_legs[0].rotation.z = sin(_t) * 0.6
		_legs[1].rotation.z = -sin(_t) * 0.6
	else:
		_visual.position.y = lerpf(_visual.position.y, 0.0, 0.2)
		for l in _legs:
			l.rotation.z = lerpf(l.rotation.z, 0.0, 0.2)

static func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 1.0
	return m

static func _mesh(mesh: Mesh, c: Color, pos: Vector3, parent: Node) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(c)
	mi.position = pos
	parent.add_child(mi)
	return mi

static func _cyl(top: float, bottom: float, h: float, seg: int) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = h
	m.radial_segments = seg
	m.rings = 1
	return m

static func _sphere(r: float, hemi: float = 1.0) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0 * hemi
	m.radial_segments = 10
	m.rings = 6
	return m

static func _box(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m

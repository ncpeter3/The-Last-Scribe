extends Node3D
## The scribe: a simple low-poly figure that walks along the X axis (2.5D).
## Keyboard (A/D) or on-screen buttons via move_dir. frozen stops movement during dialogue.

@export var speed := 3.6
var move_dir := 0.0  # set by touch controls
var frozen := false
var min_x := -2.0
var max_x := 1e9
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
	var dir := Input.get_axis("move_left", "move_right")
	if dir == 0.0:
		dir = move_dir
	if frozen:
		dir = 0.0
	position.x = clampf(position.x + dir * speed * delta, min_x, max_x)
	if dir != 0.0:
		_t += delta * 9.0
		_visual.rotation.y = lerp_angle(_visual.rotation.y, 0.0 if dir > 0.0 else PI, 0.25)
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

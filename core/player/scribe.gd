extends Node3D
## The scribe: walks freely on the ground plane (top-down 3D), drawn as a low-poly figure
## (core/lowpoly/low_poly_person.gd) in a slate-blue robe with a teal sash, satchel and scroll.
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
## Kept so scenes can still set it; the scribe is always low-poly now.
var low_poly := true
## Walls and furniture to walk around: rectangles on the ground (x, z). Empty outdoors.
var blockers: Array[Rect2] = []
const RADIUS := 0.3

var _visual: Node3D
var _lp: LowPolyPerson

func _ready() -> void:
	_lp = LowPolyPerson.create(LowPolyPerson.SCRIBE_F if female else LowPolyPerson.SCRIBE_M)
	_visual = _lp
	add_child(_lp)

func _process(delta: float) -> void:
	var v := Vector2(Input.get_axis("move_left", "move_right"), Input.get_axis("move_up", "move_down"))
	if v == Vector2.ZERO:
		v = move_vec
	if frozen:
		v = Vector2.ZERO
	if v.length() > 1.0:
		v = v.normalized()
	var nx := clampf(position.x + v.x * speed * delta, min_x, max_x)
	if not _blocked(nx, position.z):
		position.x = nx
	var nz := clampf(position.z + v.y * speed * delta, min_z, max_z)
	if not _blocked(position.x, nz):
		position.z = nz
	if v.length() > 0.05:
		# Face the direction of travel (the figure's front is +X).
		var target := atan2(-v.y, v.x)
		_visual.rotation.y = lerp_angle(_visual.rotation.y, target, 0.25)
		_lp.walk_speed = v.length()
	else:
		_lp.walk_speed = 0.0

func _blocked(x: float, z: float) -> bool:
	for r in blockers:
		if x > r.position.x - RADIUS and x < r.end.x + RADIUS and z > r.position.y - RADIUS and z < r.end.y + RADIUS:
			return true
	return false

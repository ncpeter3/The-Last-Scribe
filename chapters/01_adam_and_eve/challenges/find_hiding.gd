extends Challenge
## "Adam and his wife hid themselves ... amongst the trees of the garden" (Genesis 3:8-9).
## The garden is dim. Follow the rustling leaves to find where Adam and Eve are hiding.

const FOUND := 2.4
const SPOT := Vector2(11.0, 7.0)  # in the area: x from start, z

var _spot := Vector3.ZERO
var _bush: Node3D
var _people: Array = []
var _time := 0.0
var _d0 := 0.0  # how far away the scribe started

func build() -> void:
	_spot = Vector3(x0 + SPOT.x, 0, SPOT.y)
	_bush = Node3D.new()
	_bush.position = _spot + Vector3(0, 0, 1.0)
	add_child(_bush)
	if Props.nature(_bush, "bush", Vector3.ZERO, 1.1) == null:
		Props.add(_bush, Props.sphere(0.8, 0.8), Color(0.12, 0.3, 0.16), Vector3(0, 0.5, 0))
	for i in 3:
		Props.tree(self, _spot + Vector3(-2.2 + i * 2.2, 0, -1.6 - (i % 2) * 0.6), 1.4, Color(0.1, 0.25, 0.15))
	_people.append(CharacterFactory.make("adam", self, _spot + Vector3(-0.45, 0, 0), true))
	_people.append(CharacterFactory.make("eve", self, _spot + Vector3(0.45, 0, 0), true))
	# They face away, hidden in the trees.
	for p in _people:
		p.rotation.y = PI / 2.0

func update(delta: float) -> void:
	_time += delta
	# The bush in front of them rustles every couple of seconds.
	var shake := maxf(0.0, sin(_time * 3.0)) * sin(_time * 28.0) * 0.12
	_bush.rotation = Vector3(shake, 0, shake * 0.6)
	if flat_dist(_spot) < FOUND:
		for p in _people:
			var to: Vector3 = scribe.position - (p as Node3D).position
			p.rotation.y = atan2(-to.z, to.x)
		finish()

func status() -> String:
	var d := flat_dist(_spot)
	var warmth := "The leaves are still here."
	if d < 5.0:
		warmth = "Very close. Leaves are rustling right nearby!"
	elif d < 9.0:
		warmth = "Closer. You hear leaves rustling."
	return "Where art thou? Find where Adam and Eve hid.   %s" % warmth

func task() -> Dictionary:
	var d := flat_dist(_spot)
	if _d0 <= 0.0:
		_d0 = maxf(d, FOUND + 1.0)
	var hint := "The leaves are still here."
	if d < 5.0:
		hint = "Very close. Leaves are rustling right nearby!"
	elif d < 9.0:
		hint = "Closer. You hear leaves rustling."
	var p := 1.0 if not running else clampf(1.0 - (d - FOUND) / (_d0 - FOUND), 0.0, 0.99)
	return {"title": "Where art thou? Find where Adam and Eve hid", "hint": hint, "progress": p}

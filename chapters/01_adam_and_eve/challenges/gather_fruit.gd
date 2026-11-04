extends Challenge
## "Of every tree of the garden thou mayest freely eat" (Genesis 2:16). Gather fruit from the
## garden's trees. The tree of the knowledge of good and evil stands just ahead and is never gathered from.

const RANGE := 2.4
const TREES := [
	[Vector2(2.5, -3.8), Color(1.0, 0.55, 0.15)], [Vector2(5.0, 4.0), Color(0.55, 0.25, 0.55)],
	[Vector2(7.5, -4.2), Color(1.0, 0.85, 0.25)], [Vector2(10.0, 3.6), Color(0.95, 0.3, 0.45)],
	[Vector2(12.5, -3.4), Color(1.0, 0.6, 0.3)],
]

var _trees: Array = []  # {pos, holder, sparkle, done}
var _near := -1
var _time := 0.0

func build() -> void:
	for t in TREES:
		var off: Vector2 = t[0]
		var pos := Vector3(x0 + off.x, 0, off.y)
		var holder := Node3D.new()
		add_child(holder)
		Props.tree(holder, pos, 1.1, Color(0.22, 0.55, 0.25), t[1])
		var sparkle := Props.add(self, Props.sphere(0.16), Color(1.0, 0.95, 0.5), pos + Vector3(0, 0.9, 0.9), 3.0)
		sparkle.hide()
		_trees.append({"pos": pos, "holder": holder, "sparkle": sparkle, "done": false})

func start() -> void:
	for t in _trees:
		t["sparkle"].show()

func _count() -> int:
	var n := 0
	for t in _trees:
		if t["done"]:
			n += 1
	return n

func update(delta: float) -> void:
	_time += delta
	_near = -1
	for i in _trees.size():
		var t: Dictionary = _trees[i]
		if t["done"]:
			continue
		var s: Node3D = t["sparkle"]
		s.position.y = 0.9 + sin(_time * 3.0 + i) * 0.15
		if flat_dist(t["pos"]) < RANGE:
			_near = i

func action() -> String:
	return "Gather fruit" if _near >= 0 else ""

func act() -> void:
	if _near < 0:
		return
	var t: Dictionary = _trees[_near]
	t["done"] = true
	t["sparkle"].hide()
	# Pick the lowest fruit on the tree: it drops into the scribe's satchel.
	var low: MeshInstance3D = null
	for m in t["holder"].get_children():
		if m is MeshInstance3D and m.mesh is SphereMesh and (low == null or m.position.y < low.position.y):
			low = m
	if low:
		var tw := low.create_tween()
		tw.tween_property(low, "global_position", scribe.global_position + Vector3(0, 1.0, 0), 0.45)
		tw.tween_property(low, "scale", Vector3.ONE * 0.01, 0.15)
		tw.tween_callback(low.queue_free)
	glow_ring(self, t["pos"], 1.0)
	if _count() == _trees.size():
		var w := create_tween()
		w.tween_interval(0.7)
		w.tween_callback(finish)

func status() -> String:
	return "Of every tree thou mayest freely eat: %d/%d fruit gathered." % [_count(), _trees.size()]

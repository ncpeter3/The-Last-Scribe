extends Challenge
## "To dress it and to keep it" (Genesis 2:15). Fill a jar at the river that waters the garden
## (Genesis 2:10) and water the thirsty plants until they bloom.

const JAR_SIZE := 2
const RANGE := 1.8
const RIVER_Z0 := -8.0
const RIVER_Z1 := -4.5

var _plants: Array = []  # {pos, dry: Node3D, done}
var _jar := 0
var _near := -1
var _at_river := false

func build() -> void:
	# The river continues from Eden into this part of the garden.
	Props.water(self, x0, x1, RIVER_Z0, RIVER_Z1, 0.04)
	for i in 6:
		Props.rock(self, Vector3(lerpf(x0 + 1, x1 - 1, i / 5.0), 0, RIVER_Z1 + 0.4), 0.5)
	for i in 4:
		Props.creature(self, "fish", Vector3(lerpf(x0 + 2, x1 - 2, i / 3.0), 0, (RIVER_Z0 + RIVER_Z1) / 2.0), 1.0)
	var spots := [Vector3(2.5, 0, 1.5), Vector3(4.5, 0, -2.0), Vector3(6.5, 0, 3.0), Vector3(8.5, 0, -0.5), Vector3(10.5, 0, 2.0)]
	for s in spots:
		var p: Vector3 = s + Vector3(x0, 0, 0)
		_plants.append({"pos": p, "dry": _dry_plant(p), "done": false})

func _dry_plant(p: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = p
	add_child(n)
	var tan := Color(0.62, 0.52, 0.3)
	Props.add(n, Props.cyl(0.03, 0.05, 0.45, 5), tan.darkened(0.2), Vector3(0, 0.22, 0))
	for k in 4:
		var leaf := Props.add(n, Props.box(Vector3(0.32, 0.03, 0.12)), tan, Vector3(0, 0.35, 0))
		leaf.rotation = Vector3(0, k * PI / 2.0, -0.7)
		leaf.position += Vector3(cos(k * PI / 2.0) * 0.14, -0.05, -sin(k * PI / 2.0) * 0.14)
	# Dry soil patch.
	var soil := Props.add(n, Props.cyl(0.55, 0.55, 0.03, 12), Color(0.45, 0.33, 0.2), Vector3(0, 0.02, 0))
	soil.name = "Soil"
	return n

func _watered() -> int:
	var n := 0
	for p in _plants:
		if p["done"]:
			n += 1
	return n

func update(_delta: float) -> void:
	_at_river = scribe.position.z < RIVER_Z1 + 0.6
	_near = -1
	for i in _plants.size():
		if not _plants[i]["done"] and flat_dist(_plants[i]["pos"]) < RANGE:
			_near = i
			break

func action() -> String:
	if _near >= 0:
		return "Water the plant" if _jar > 0 else "Jar is empty"
	if _at_river and _jar < JAR_SIZE:
		return "Fill jar at the river"
	return ""

func act() -> void:
	if _near >= 0:
		if _jar <= 0:
			host.say([{"speaker": "Scribe", "text": "My jar is empty. The river runs along the top of the garden. I'll fill it there."}], Callable())
			return
		_jar -= 1
		_bloom(_near)
	elif _at_river and _jar < JAR_SIZE:
		_jar = JAR_SIZE

func _bloom(i: int) -> void:
	var p: Dictionary = _plants[i]
	p["done"] = true
	var pos: Vector3 = p["pos"]
	# Water drops fall, then the plant springs up green and flowering.
	for k in 5:
		var d := Props.add(self, Props.sphere(0.06, 1.3, 5), Color(0.5, 0.75, 1.0), pos + Vector3(randf_range(-0.3, 0.3), 1.6, randf_range(-0.3, 0.3)), 1.0)
		var tw := d.create_tween()
		tw.tween_interval(k * 0.08)
		tw.tween_property(d, "position:y", 0.1, 0.4)
		tw.tween_callback(d.queue_free)
	var dry: Node3D = p["dry"]
	var tw := dry.create_tween()
	tw.tween_interval(0.5)
	tw.tween_property(dry, "scale", Vector3(0.01, 0.01, 0.01), 0.25)
	tw.tween_callback(dry.queue_free)
	var holder := Node3D.new()
	holder.position = pos
	holder.scale = Vector3.ONE * 0.01
	add_child(holder)
	if Props.nature(holder, "bush_flowers", Vector3.ZERO, 0.75) == null:
		Props.add(holder, Props.sphere(0.5, 0.8), Color(0.25, 0.6, 0.25), Vector3(0, 0.4, 0))
	for k in 3:
		var a := k * TAU / 3.0 + pos.x
		Props.flower(holder, Vector3(cos(a), 0, sin(a)) * 0.75, [Color(1, 0.5, 0.6), Color(1, 0.9, 0.4), Color(0.7, 0.6, 1.0)][k])
	var g := holder.create_tween()
	g.tween_interval(0.6)
	g.tween_property(holder, "scale", Vector3.ONE, 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if _watered() == _plants.size():
		g.tween_interval(0.5)
		g.tween_callback(finish)

func status() -> String:
	var jar := "Jar: %s" % ("full" if _jar == JAR_SIZE else ("half" if _jar > 0 else "empty"))
	var tip := "   (Fill it at the river, up the screen.)" if _jar == 0 else ""
	return "Dress and keep the garden: %d/%d plants watered.   %s%s" % [_watered(), _plants.size(), jar, tip]

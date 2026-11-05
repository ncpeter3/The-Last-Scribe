extends Challenge
## "Whatsoever Adam called every living creature, that was the name thereof" (Genesis 2:19).
## The scribe records each creature brought to Adam under the groups Genesis 2:20 names:
## cattle, fowl of the air, and beast of the field. First the creature's name, then its group.
## Walk up slowly or the animal startles.

const GROUPS := ["Cattle", "Fowl of the air", "Beast of the field"]
const HINT := "Not quite. In the King James words, cattle are the herd animals that live alongside people, like oxen and sheep. Fowl of the air are birds. Beasts of the field are the other animals that roam free, like horses, zebras, foxes, and wolves."
const NAME_HINT := "Look again. Adam is giving a name to the creature right in front of you."
# [model id, group index, position in the area (x from start, z), scale, name]
const ANIMALS := [
	["cow", 0, Vector2(2.5, -2.5), 1.0, "Ox"], ["sheep", 0, Vector2(5.0, 3.0), 1.0, "Sheep"], ["horse", 2, Vector2(9.0, -3.5), 1.0, "Horse"],
	["bird", 1, Vector2(4.0, -5.0), 1.6, "Dove"], ["eagle", 1, Vector2(11.0, 3.5), 0.9, "Eagle"],
	["fox", 2, Vector2(7.0, 0.5), 1.0, "Fox"], ["wolf", 2, Vector2(12.0, -1.5), 1.0, "Wolf"], ["zebra", 2, Vector2(3.0, 5.5), 1.0, "Zebra"],
]
## Other names offered next to the right one (never the right one twice).
const DECOYS := ["Lion", "Camel", "Goat", "Bear", "Owl", "Ox", "Horse", "Sheep", "Fox", "Eagle", "Raven", "Deer"]
const RANGE := 2.0
const STARTLE := 3.2

var _animals: Array = []  # {node, group, done, rest}
var _near := -1

func build() -> void:
	for a in ANIMALS:
		var off: Vector2 = a[2]
		var pos := Vector3(x0 + off.x, 0, off.y)
		if a[0] == "eagle":
			Props.rock(self, pos, 1.0)
		var n := Props.creature(self, a[0], pos + Vector3(0, 0.45 if a[0] == "eagle" else 0.0, 0), a[3])
		# Animals brought to Adam stay close by so they can be approached, but still move about.
		(n as LowPolyAnimal).radius = 1.4
		_animals.append({"node": n, "group": a[1], "done": false, "rest": 0.0, "name": a[4], "named": false})

func _count() -> int:
	var n := 0
	for a in _animals:
		if a["done"]:
			n += 1
	return n

func update(delta: float) -> void:
	_near = -1
	var best := RANGE
	for i in _animals.size():
		var a: Dictionary = _animals[i]
		var n: Node3D = a["node"]
		a["rest"] = maxf(0.0, a["rest"] - delta)
		var d := flat_dist(n.position)
		if a["done"]:
			continue
		# Rushing up startles an animal; it trots off a little way, then settles so it can be approached.
		if d < STARTLE and scribe_speed > 0.75 and a["rest"] <= 0.0:
			_startle(a)
			continue
		if d < best:
			best = d
			_near = i

func _startle(a: Dictionary) -> void:
	var n: Node3D = a["node"]
	a["rest"] = 2.5
	var away := Vector3(n.position.x - scribe.position.x, 0, n.position.z - scribe.position.z).normalized()
	var target := n.position + away * 2.5
	target.x = clampf(target.x, x0 + 1.0, x1 - 1.0)
	target.z = clampf(target.z, -7.0, 7.0)
	var animal := n as LowPolyAnimal
	if animal.mode == "perch":
		# A startled bird flutters up and lands a little way off.
		var tw := n.create_tween()
		tw.tween_property(n, "position", target + Vector3(0, 1.2, 0), 0.4)
		tw.tween_property(n, "position", Vector3(target.x, n.position.y, target.z), 0.4)
		return
	animal.run_to(target)

func action() -> String:
	return "Write it in the scroll" if _near >= 0 else ""

func act() -> void:
	if _near < 0:
		return
	var i := _near
	var a: Dictionary = _animals[i]
	if not a["named"]:
		var opts := name_options(i)
		host.ask("[b]Adam names this creature.[/b]\nWhat name does the scribe write in the scroll?", opts,
				func(choice: int): _named(i, opts[choice]))
		return
	_ask_group(i)

## The right name and two others, in an order that depends on the animal (so it isn't always first).
func name_options(i: int) -> Array:
	var right: String = _animals[i]["name"]
	var others := []
	for k in DECOYS.size():
		var d: String = DECOYS[(k * 5 + i * 3) % DECOYS.size()]
		if d != right and d not in others:
			others.append(d)
		if others.size() == 2:
			break
	var opts := others.duplicate()
	opts.insert(i % 3, right)
	return opts

func _named(i: int, picked: String) -> void:
	var a: Dictionary = _animals[i]
	if picked != a["name"]:
		host.say([{"speaker": "Codex", "text": NAME_HINT}], Callable())
		return
	a["named"] = true
	_ask_group(i)

func _ask_group(i: int) -> void:
	host.ask("[b]%s[/b]\nWhich group from Genesis 2:20 should the scribe write it under?" % _animals[i]["name"], GROUPS,
			func(choice: int): _answer(i, choice))

func _answer(i: int, choice: int) -> void:
	var a: Dictionary = _animals[i]
	if choice != a["group"]:
		host.say([{"speaker": "Codex", "text": HINT}], Callable())
		return
	a["done"] = true
	var n: Node3D = a["node"]
	glow_ring(self, Vector3(n.position.x, 0, n.position.z), 0.9)
	if _count() == _animals.size():
		finish()

func status() -> String:
	return "Record every living creature: %d/%d written in the scroll.   Walk up slowly." % [_count(), _animals.size()]

func task() -> Dictionary:
	return {"title": "Record every living creature in your scroll", "hint": "Walk up slowly so they don't run off.",
		"done": _count(), "total": _animals.size()}

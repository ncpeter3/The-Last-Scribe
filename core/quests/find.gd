extends SideQuest
## Find things around the area: seeds, stones, river springs, birds to sketch, flowers, herbs...
## Config:
##   items: [{at: [x, z], kind, lines (optional, said when found)}]
##     kind is a Props.treasure kind (gold, onyx, bdellium, seed, herb, flower), or "bird" (a perched
##     bird to sketch, which stays) or "spring" (a bubbling spring, which stays).
##   verb: action text, e.g. "Pick up the seed".
##   deliver (optional): a story character's id, e.g. "eve" (bring them all to that person), or
##   "animals" (give one each to `deliver_count` different land animals). deliver_verb: action text.

const RANGE := 1.6

var _items: Array = []  # {node, pos, found, lines}
var _found := 0
var _delivered := 0
var _near := -1
var _near_animal: Node3D
var _fed: Array = []
var _time := 0.0

func build_props() -> void:
	for it in cfg.get("items", []):
		var at: Array = it["at"]
		var pos := Vector3(float(at[0]), 0, float(at[1]))
		var kind := String(it.get("kind", "seed"))
		var n: Node3D
		match kind:
			"bird":
				Props.rock(self, pos, 0.8, Color(0.55, 0.53, 0.5))
				n = Props.creature(self, String(it.get("species", "bird")), pos + Vector3(0, 0.4, 0), float(it.get("scale", 1.3)))
			"spring":
				n = _spring(pos)
			_:
				n = Props.treasure(self, kind, pos)
		var sparkle := Props.add(self, Props.sphere(0.09, 1.0, 5), Color(0.6, 1.0, 0.95), pos + Vector3(0, 1.3, 0), 3.0)
		sparkle.hide()
		_items.append({"node": n, "pos": pos, "found": false, "lines": it.get("lines", []), "kind": kind, "sparkle": sparkle})

func _spring(pos: Vector3) -> Node3D:
	# A ring of stones where water bubbles up out of the ground.
	var n := Node3D.new()
	n.position = pos
	add_child(n)
	for k in 7:
		var a := TAU * k / 7.0
		Props.rock(n, Vector3(cos(a), 0, sin(a)) * 0.55, 0.3, Color(0.6, 0.58, 0.55))
	var w := Props.add(n, Props.cyl(0.45, 0.45, 0.04, 9), Color(0.3, 0.6, 0.75), Vector3(0, 0.04, 0), 0.4)
	var tw := w.create_tween().set_loops()
	tw.tween_property(w, "scale", Vector3(1.08, 1, 1.08), 0.7)
	tw.tween_property(w, "scale", Vector3.ONE, 0.7)
	return n

func start() -> void:
	for it in _items:
		it["sparkle"].show()

func _delivering() -> bool:
	return _found == _items.size() and cfg.has("deliver")

func update(delta: float) -> void:
	_time += delta
	_near = -1
	_near_animal = null
	for i in _items.size():
		var it: Dictionary = _items[i]
		if it["found"]:
			continue
		var s: Node3D = it["sparkle"]
		var n: Node3D = it["node"]
		s.position = Vector3(n.global_position.x, 1.3 + sin(_time * 3.0 + i) * 0.12, n.global_position.z)
		if flat_dist(n.global_position) < RANGE and _near < 0:
			_near = i
	if _delivering() and cfg["deliver"] == "animals":
		var best := 2.2
		for a in host.find_children("*", "LowPolyAnimal", true, false):
			var an := a as LowPolyAnimal
			if an.mode != "wander" or an in _fed:
				continue
			var d := flat_dist(an.global_position)
			if d < best:
				best = d
				_near_animal = an

func _person_near() -> bool:
	var who: Node3D = host.get_actor(String(cfg["deliver"]))
	return who != null and who.visible and flat_dist(who.global_position) < 2.4

func active_action() -> String:
	if _near >= 0:
		return String(cfg.get("verb", "Pick it up"))
	if _delivering():
		if cfg["deliver"] != "animals" and _person_near():
			return String(cfg.get("deliver_verb", "Give them"))
		if cfg["deliver"] == "animals" and _near_animal:
			return String(cfg.get("deliver_verb", "Give a green herb"))
	return ""

func active_act() -> void:
	if _near >= 0:
		var it: Dictionary = _items[_near]
		it["found"] = true
		it["sparkle"].hide()
		_found += 1
		var n: Node3D = it["node"]
		glow_ring(n.global_position, 0.7)
		if it["kind"] not in ["bird", "spring"]:
			var tw := n.create_tween()
			tw.tween_property(n, "global_position", scribe.global_position + Vector3(0, 1.0, 0), 0.35)
			tw.tween_property(n, "scale", Vector3.ONE * 0.01, 0.15)
			tw.tween_callback(n.hide)
		elif it["kind"] == "bird":
			SideQuest.hop(n)
		var lines: Array = it["lines"]
		if not lines.is_empty():
			host.say(lines, _check_done)
		else:
			_check_done()
		return
	if _delivering():
		if cfg["deliver"] == "animals" and _near_animal:
			_fed.append(_near_animal)
			SideQuest.hop(_near_animal)
			glow_ring(_near_animal.global_position, 0.8)
			_delivered += 1
			_check_done()
		elif cfg["deliver"] != "animals" and _person_near():
			_delivered = int(cfg.get("deliver_count", 1))
			SideQuest.hop(host.get_actor(String(cfg["deliver"])))
			_check_done()

func _check_done() -> void:
	if _found < _items.size():
		return
	if cfg.has("deliver") and _delivered < int(cfg.get("deliver_count", 1)):
		var nudge: Array = cfg.get("deliver_intro", [])
		if not nudge.is_empty() and _delivered == 0 and not get_meta("nudged", false):
			set_meta("nudged", true)
			host.say(nudge)
		return
	complete()

func progress() -> Vector2i:
	var total := _items.size() + (int(cfg.get("deliver_count", 1)) if cfg.has("deliver") else 0)
	return Vector2i(_found + _delivered, total)

func task_text() -> String:
	if _delivering():
		return String(cfg.get("deliver_task", title))
	return String(cfg.get("task", title))

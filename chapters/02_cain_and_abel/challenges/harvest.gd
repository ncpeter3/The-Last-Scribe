extends Challenge
## "But Cain was a tiller of the ground" (Genesis 4:2). Help Cain bring in his harvest: gather the
## ripe crops marked with sparkles, then bring them all to Cain.
## Config: crops: [{at: [dx, z], kind: wheat | gourd | melon}].

const Ch2Props := preload("res://chapters/02_cain_and_abel/scenes/ch2_props.gd")
const RANGE := 1.6
const CAIN_RANGE := 2.4
const VERBS := {"wheat": "Cut the wheat", "gourd": "Pick the gourd", "melon": "Pick the melon"}

var _crops: Array = []  # {node, pos, kind, done, sparkle}
var _near := -1
var _time := 0.0
var _delivered := false

func build() -> void:
	for c in cfg.get("crops", []):
		var at: Array = c["at"]
		var pos := Vector3(x0 + float(at[0]), 0, float(at[1]))
		var kind := String(c.get("kind", "wheat"))
		var n := Ch2Props.crop(self, pos, kind)
		var sparkle := Props.add(self, Props.sphere(0.12), Color(1.0, 0.95, 0.5), pos + Vector3(0, 1.3, 0), 3.0)
		sparkle.hide()
		_crops.append({"node": n, "pos": pos, "kind": kind, "done": false, "sparkle": sparkle})

func start() -> void:
	for c in _crops:
		c["sparkle"].show()

func gathered() -> int:
	var n := 0
	for c in _crops:
		if c["done"]:
			n += 1
	return n

func _cain_near() -> bool:
	var cain: Node3D = host.get_actor("cain")
	return cain != null and cain.visible and flat_dist(cain.global_position) < CAIN_RANGE

func update(delta: float) -> void:
	_time += delta
	_near = -1
	for i in _crops.size():
		var c: Dictionary = _crops[i]
		if c["done"]:
			continue
		var s: Node3D = c["sparkle"]
		s.position.y = 1.3 + sin(_time * 3.0 + i) * 0.12
		if flat_dist(c["pos"]) < RANGE and _near < 0:
			_near = i

func action() -> String:
	if _near >= 0:
		return String(VERBS.get(_crops[_near]["kind"], "Gather it"))
	if gathered() == _crops.size() and not _delivered and _cain_near():
		return "Bring the harvest to Cain"
	return ""

func act() -> void:
	if _near >= 0:
		var c: Dictionary = _crops[_near]
		c["done"] = true
		c["sparkle"].hide()
		var n: Node3D = c["node"]
		glow_ring(self, c["pos"], 0.7)
		var tw := n.create_tween()
		tw.tween_property(n, "global_position", scribe.global_position + Vector3(0, 1.0, 0), 0.35)
		tw.tween_property(n, "scale", Vector3.ONE * 0.01, 0.15)
		tw.tween_callback(n.hide)
		if gathered() == _crops.size():
			host.say(cfg.get("bring", []))
		return
	if gathered() == _crops.size() and _cain_near() and not _delivered:
		_delivered = true
		var cain: Node3D = host.get_actor("cain")
		SideQuest.hop(cain)
		glow_ring(self, cain.global_position, 1.0)
		var w := create_tween()
		w.tween_interval(0.6)
		w.tween_callback(finish)

func status() -> String:
	return "Harvest: %d/%d" % [gathered(), _crops.size()]

func task() -> Dictionary:
	if gathered() == _crops.size():
		return {"title": "Bring the harvest to Cain", "hint": "He's working in his field.", "done": _crops.size() + (1 if _delivered else 0), "total": _crops.size() + 1}
	return {"title": "Help Cain bring in his harvest", "hint": "Gather the ripe crops that sparkle.", "done": gathered(), "total": _crops.size() + 1}

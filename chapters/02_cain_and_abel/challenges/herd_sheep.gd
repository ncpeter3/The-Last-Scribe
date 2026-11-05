extends Challenge
## "And Abel was a keeper of sheep" (Genesis 4:2). Help Abel bring his sheep into the fold: walk up
## to a sheep and call it, and it follows; lead it in through the gap in the stone wall. Several can
## follow at once. Config: fold: [dx, z] (from the station), sheep: [[dx, z], ...].

const Ch2Props := preload("res://chapters/02_cain_and_abel/scenes/ch2_props.gd")
const CALL_RANGE := 2.0
const FOLD_R := 2.2
const FOLLOW := 1.3

var _fold := Vector3.ZERO
var _sheep: Array = []  # {node: LowPolyAnimal, state: "loose" | "following" | "in", sparkle}
var _near := -1
var _repath := 0.0
var _time := 0.0

func build() -> void:
	var f: Array = cfg.get("fold", [7.0, -5.0])
	_fold = Vector3(x0 + float(f[0]), 0, float(f[1]))
	Ch2Props.sheepfold(self, _fold, FOLD_R)
	for s in cfg.get("sheep", []):
		var pos := Vector3(x0 + float(s[0]), 0, float(s[1]))
		var a := Props.creature(self, "sheep", pos, 0.95) as LowPolyAnimal
		a.radius = 1.0
		var sparkle := Props.add(self, Props.sphere(0.12), Color(0.6, 1.0, 0.95), pos + Vector3(0, 1.4, 0), 3.0)
		sparkle.hide()
		_sheep.append({"node": a, "state": "loose", "sparkle": sparkle})

func spot_in_fold(i: int) -> Vector3:
	var a := TAU * i / maxf(1.0, _sheep.size()) + 0.3
	return _fold + Vector3(cos(a), 0, sin(a) * 0.8) * 1.0

func start() -> void:
	for s in _sheep:
		s["sparkle"].show()

func count_in() -> int:
	var n := 0
	for s in _sheep:
		if s["state"] == "in":
			n += 1
	return n

func update(delta: float) -> void:
	_time += delta
	_repath -= delta
	_near = -1
	var follower := 0
	for i in _sheep.size():
		var s: Dictionary = _sheep[i]
		var a: LowPolyAnimal = s["node"]
		var sp: Node3D = s["sparkle"]
		sp.position = Vector3(a.position.x, 1.4 + sin(_time * 3.0 + i) * 0.12, a.position.z)
		match s["state"]:
			"loose":
				if flat_dist(a.position) < CALL_RANGE and _near < 0:
					_near = i
			"following":
				follower += 1
				var to := scribe.position - a.position
				to.y = 0.0
				if _repath <= 0.0 and to.length() > FOLLOW:
					# Trail behind the scribe, each sheep a little to the side of the one before.
					var side := Vector3(-to.z, 0, to.x).normalized() * (0.5 * (follower % 3 - 1))
					a.speed = 1.8
					a.run_to(scribe.position - to.normalized() * FOLLOW * 0.8 + side)
				if Vector2(a.position.x - _fold.x, a.position.z - _fold.z).length() < FOLD_R - 0.3:
					s["state"] = "in"
					sp.hide()
					a.speed = 0.8
					a.radius = 0.6
					a.run_to(spot_in_fold(i))
					glow_ring(self, a.position, 0.8)
					SideQuest.hop(a)
					if count_in() == _sheep.size():
						var w := create_tween()
						w.tween_interval(0.8)
						w.tween_callback(finish)
	if _repath <= 0.0:
		_repath = 0.25

func action() -> String:
	return "Call the sheep" if _near >= 0 else ""

func act() -> void:
	if _near < 0:
		return
	var s: Dictionary = _sheep[_near]
	s["state"] = "following"
	SideQuest.hop(s["node"])

func status() -> String:
	return "Sheep in the fold: %d/%d" % [count_in(), _sheep.size()]

func task() -> Dictionary:
	var following := 0
	for s in _sheep:
		if s["state"] == "following":
			following += 1
	var hint := "Call a sheep, then lead it into the stone fold." if following == 0 else "Lead them in through the gap in the wall."
	return {"title": "Help Abel bring his sheep into the fold", "hint": hint, "done": count_in(), "total": _sheep.size()}

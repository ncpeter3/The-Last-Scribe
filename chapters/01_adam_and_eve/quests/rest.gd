extends SideQuest
## Rest a while, as God rested on the seventh day: sit on the mossy stone and stay a few moments.
## Config: seat: [x, z], seconds.

var _seat := Vector3.ZERO
var _sitting := false
var _t := 0.0
var _secs := 5.0

func build_props() -> void:
	var at: Array = cfg["seat"]
	_seat = Vector3(float(at[0]), 0, float(at[1]))
	_secs = float(cfg.get("seconds", 5.0))
	Props.rock(self, _seat, 1.1, Color(0.5, 0.55, 0.45))
	Props.add(self, Props.cyl(0.5, 0.55, 0.06, 8), Color(0.35, 0.55, 0.3), _seat + Vector3(0, 0.42, 0))
	for k in 6:
		var a := TAU * k / 6.0 + 0.4
		Props.flower(self, _seat + Vector3(cos(a), 0, sin(a)) * 1.3, [Color(1, 0.9, 0.5), Color(1, 1, 1), Color(0.7, 0.6, 1.0)][k % 3])

func update(delta: float) -> void:
	if not _sitting:
		return
	_t += delta
	if _t >= _secs:
		_sitting = false
		var lp: LowPolyPerson = scribe.get("_lp")
		if lp:
			lp.sitting = false
		host.unfreeze()
		complete()

func active_action() -> String:
	if not _sitting and flat_dist(_seat) < 1.8:
		return "Sit and rest"
	return ""

func active_act() -> void:
	if _sitting:
		return
	_sitting = true
	_t = 0.0
	host.freeze()
	scribe.position = _seat + Vector3(0, 0, 0.75)
	var lp: LowPolyPerson = scribe.get("_lp")
	if lp:
		lp.sitting = true
		lp.sit_height = 0.4
		lp.rotation.y = -PI / 2.0

func progress() -> Vector2i:
	return Vector2i(int(_t / _secs * 10.0), 10) if _sitting else Vector2i(0, 10)

func task_text() -> String:
	return "Resting..." if _sitting else title

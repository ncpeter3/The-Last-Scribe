extends SideQuest
## A lamb has wandered away from its flock. Find it, and it follows you; lead it back home.
## Config: lamb: [x, z] (where it's lost), flock: [x, z] (where the flock grazes).

const FOLLOW := 1.4
const HOME_RANGE := 2.6

var _lamb: LowPolyAnimal
var _flock := Vector3.ZERO
var _following := false
var _home := false
var _repath := 0.0

func build_props() -> void:
	var at: Array = cfg["lamb"]
	var fl: Array = cfg["flock"]
	_flock = Vector3(float(fl[0]), 0, float(fl[1]))
	_lamb = Props.creature(self, "sheep", Vector3(float(at[0]), 0, float(at[1])), 0.55) as LowPolyAnimal
	_lamb.radius = 0.8
	for i in 3:
		var a := TAU * i / 3.0
		var s := Props.creature(self, "sheep", _flock + Vector3(cos(a), 0, sin(a)) * 1.3, 1.0) as LowPolyAnimal
		s.radius = 1.2

func update(delta: float) -> void:
	if not _following or _home:
		return
	_repath -= delta
	var to := scribe.position - _lamb.position
	to.y = 0.0
	if _repath <= 0.0 and to.length() > FOLLOW:
		_repath = 0.25
		_lamb.speed = 1.7
		_lamb.run_to(scribe.position - to.normalized() * FOLLOW * 0.8)
	if Vector2(_lamb.position.x - _flock.x, _lamb.position.z - _flock.z).length() < HOME_RANGE:
		_home = true
		_lamb.speed = 1.0
		_lamb.run_to(_flock + Vector3(0.6, 0, 0.6))
		_lamb.radius = 1.2
		glow_ring(_flock, 1.6)
		complete()

func active_action() -> String:
	if not _following and flat_dist(_lamb.position) < 1.8:
		return "Call the lamb"
	return ""

func active_act() -> void:
	if not _following:
		_following = true
		SideQuest.hop(_lamb)
		host.say([{"speaker": "Scribe", "text": "There you are, little one. Come on, follow me back to your flock."}])

func progress() -> Vector2i:
	if _home:
		return Vector2i(2, 2)
	return Vector2i(1 if _following else 0, 2)

func task_text() -> String:
	return "Lead the lamb back to its flock" if _following else "Find the lost lamb"

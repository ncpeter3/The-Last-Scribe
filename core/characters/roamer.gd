class_name Roamer
extends Node
## Lets a story character move about on their own. Add it as a child of the character's node:
## the character wanders near `anchor`, and go_to() sends them walking (or running) somewhere,
## calling `then` when they arrive. Works with LowPolyPerson (walk animation) inside `body`.
## Like everything in the game, a character's front faces +X.

var body: Node3D  ## the node that moves (the character's holder)
var person: LowPolyPerson  ## the figure inside, animated while walking (optional)
var anchor := Vector3.ZERO
var radius := 1.5  ## how far from the anchor they wander; 0 = stand still
var speed := 1.3  ## walking pace in meters per second; running is twice this
var paused := false  ## stand still (used while someone is talking to them)
## Return true for spots the character must not walk to (water).
var avoid := Callable()
## The player. When the character is on an errand and neither they nor the place they're going
## can be seen (both farther than `unseen` from the player), they skip ahead and arrive at once,
## so they're always where the story needs them.
var watcher: Node3D
var unseen := 12.0

var _target := Vector3.ZERO
var _going := false
var _run := false
var _errand := false  # going somewhere on purpose (not just wandering)
var _wait := 0.0
var _then := Callable()
var _rng := RandomNumberGenerator.new()

static func attach(holder: Node3D, figure: LowPolyPerson = null) -> Roamer:
	var r := Roamer.new()
	r.body = holder
	r.person = figure
	r.anchor = holder.position
	r._rng.seed = hash(holder.name)
	r._wait = r._rng.randf_range(0.5, 2.5)
	holder.add_child(r)
	return r

## Walk (or run) to `p`, then call `then`. They keep wandering near `p` afterwards.
func go_to(p: Vector3, run: bool = false, then: Callable = Callable()) -> void:
	anchor = Vector3(p.x, 0, p.z)
	_target = anchor
	_going = true
	_errand = true
	_run = run
	_then = then

## Put them somewhere at once (when nobody is looking).
func place(p: Vector3) -> void:
	anchor = Vector3(p.x, 0, p.z)
	body.position = anchor
	_going = false
	_errand = false
	_then = Callable()

func busy() -> bool:
	return _errand

## Turn to look at a spot.
func face(p: Vector3) -> void:
	var to := p - body.position
	if Vector2(to.x, to.z).length() > 0.01:
		body.rotation.y = atan2(-to.z, to.x)

func _process(delta: float) -> void:
	if paused or not body.visible:
		_set_walk(0.0)
		return
	if not _going:
		_set_walk(0.0)
		if radius <= 0.0:
			return
		_wait -= delta
		if _wait <= 0.0:
			_wait = _rng.randf_range(2.0, 5.0)
			for i in 6:
				var a := _rng.randf() * TAU
				var p := anchor + Vector3(cos(a), 0, sin(a)) * _rng.randf_range(0.3, radius)
				if not (avoid.is_valid() and avoid.call(p)):
					_target = p
					_going = true
					_run = false
					break
		return
	if _errand and watcher and _far(body.position) and _far(_target):
		body.position = Vector3(_target.x, body.position.y, _target.z)
	var to := _target - body.position
	to.y = 0.0
	var step := speed * (2.4 if _run else 1.0) * delta
	if to.length() <= step:
		body.position = Vector3(_target.x, body.position.y, _target.z)
		_going = false
		_run = false
		var cb := _then
		_then = Callable()
		_errand = false
		if cb.is_valid():
			cb.call()
		return
	var dir := to.normalized()
	body.position += dir * step
	body.rotation.y = lerp_angle(body.rotation.y, atan2(-dir.z, dir.x), minf(1.0, delta * 10.0))
	_set_walk(2.0 if _run else 1.0)

func _far(p: Vector3) -> bool:
	return Vector2(p.x - watcher.position.x, p.z - watcher.position.z).length() > unseen

func _set_walk(v: float) -> void:
	if person:
		person.walk_speed = v

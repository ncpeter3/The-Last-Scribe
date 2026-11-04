class_name Challenge
extends Node3D
## Base for a story challenge. A challenge starts right after the verse it teaches is told, and
## the next story beat waits until it is finished, so Scripture is never skipped or reordered.
## No challenge can be failed: wrong answers get a hint and another try.
##
## The chapter (host) provides: get_scribe(), say(lines, callback), ask(question, options, callback).
## Lifecycle: setup() and build() when the world is made (props are visible from the start),
## begin() when the challenge starts, tick() every frame while it runs, finish() when done.

signal completed

var host: Node
var cfg: Dictionary
var x0 := 0.0  # the challenge area runs from x0 (the beat's station) to x1
var x1 := 0.0
var scribe: Node3D
var running := false
var scribe_speed := 0.0  # how fast the scribe is walking, 0..1 of full speed
var _last_pos := Vector3.ZERO

func setup(h: Node, c: Dictionary, start_x: float) -> void:
	host = h
	cfg = c
	x0 = start_x
	x1 = float(c.get("x1", start_x))
	name = String(c.get("type", "challenge"))

## Make the challenge's props. Called once while building the world.
func build() -> void:
	pass

func begin() -> void:
	scribe = host.get_scribe()
	_last_pos = scribe.position
	running = true
	start()

## Override: called when the challenge starts.
func start() -> void:
	pass

func tick(delta: float) -> void:
	if delta > 0.0:
		var moved := Vector2(scribe.position.x - _last_pos.x, scribe.position.z - _last_pos.z).length()
		scribe_speed = lerpf(scribe_speed, moved / delta / scribe.speed, minf(1.0, delta * 10.0))
	_last_pos = scribe.position
	update(delta)

## Override: per-frame logic.
func update(_delta: float) -> void:
	pass

## Override: text for the action button, or "" to hide it.
func action() -> String:
	return ""

## Override: the action button was tapped.
func act() -> void:
	pass

## Override: the goal and progress shown at the top of the screen.
func status() -> String:
	return ""

func finish() -> void:
	running = false
	completed.emit()

func flat_dist(p: Vector3) -> float:
	return Vector2(p.x - scribe.position.x, p.z - scribe.position.z).length()

## A soft glowing ring on the ground, used to mark something finished.
func glow_ring(parent: Node3D, pos: Vector3, radius: float, c: Color = Color(1.0, 0.85, 0.4)) -> MeshInstance3D:
	var t := TorusMesh.new()
	t.inner_radius = radius * 0.85
	t.outer_radius = radius
	t.rings = 24
	t.ring_segments = 6
	var m := Props.add(parent, t, c, pos + Vector3(0, 0.05, 0), 2.0)
	m.scale = Vector3(1, 0.3, 1)
	return m

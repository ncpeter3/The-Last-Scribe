extends Control
## Floating thumb joystick for the lower-left of the screen. Reads touch events directly
## (mouse drags are turned into touch by the project setting, so it also works on desktop).
## `value` is a Vector2 with length 0..1.

var value := Vector2.ZERO
var enabled := true
var _finger := -1
var _origin := Vector2.ZERO
var _knob := Vector2.ZERO
const RADIUS := 110.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _finger == -1 and enabled and _in_zone(event.position):
			_finger = event.index
			_origin = event.position
			_knob = event.position
			value = Vector2.ZERO
			queue_redraw()
		elif not event.pressed and event.index == _finger:
			_release()
	elif event is InputEventScreenDrag and event.index == _finger:
		_knob = event.position
		var d := _knob - _origin
		if d.length() > RADIUS:
			_knob = _origin + d.normalized() * RADIUS
		value = (_knob - _origin) / RADIUS
		queue_redraw()

func _in_zone(p: Vector2) -> bool:
	var s := get_viewport_rect().size
	return p.x < s.x * 0.5 and p.y > s.y * 0.30

func _release() -> void:
	_finger = -1
	value = Vector2.ZERO
	queue_redraw()

func cancel() -> void:
	_release()

func _draw() -> void:
	if _finger == -1:
		return
	draw_circle(_origin, RADIUS, Color(1, 1, 1, 0.12))
	draw_arc(_origin, RADIUS, 0, TAU, 40, Color(1, 1, 1, 0.4), 3.0)
	draw_circle(_knob, 44.0, Color(1, 1, 1, 0.45))

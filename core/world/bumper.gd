class_name Bumper
extends Node
## Bumping into things. Walk into a person and they turn and say something in a speech bubble;
## walk into an animal and it hops and scurries out of the way (with a moo, baa or woof).
##
##     var bumper := Bumper.new()
##     add_child(bumper)
##     bumper.scribe = my_scribe
##     bumper.add_person(adam, ["Peace to thee, friend.", "The garden is wide. Walk where thou wilt."])
##     bumper.add_animal(cow)                # any LowPolyAnimal, or the dog
##     bumper.enabled = not dialogue.active  # keep bumps quiet during conversations
##
## Each person cycles through their lines. A bump only counts when the scribe walks into
## someone; standing still beside them does nothing, and each thing waits a moment between bumps.

signal bumped(node: Node3D)

const COOLDOWN := 2.2
const BUBBLE_TIME := 2.8
const SOUNDS := {"cow": "Moo!", "horse": "Neigh!", "zebra": "Whinny!", "llama": "Hmmm?", "sheep": "Baa!",
	"pig": "Oink!", "wolf": "Yip!", "fox": "Yip yip!", "dog": "Woof!", "cat": "Mew!", "chick": "Cheep!",
	"bird": "Tweet!", "eagle": "Screech!"}

var scribe: Node3D
var enabled := true
## How close (meters, center to center) counts as bumping a person. People are often walk-blockers,
## which keep the scribe about 0.55 m away, so this is a bit more than that.
var reach := 0.8
## How close counts for an animal, before its size is taken into account.
var animal_reach := 0.75

var _things: Array = []  # {node, kind, lines, next, touching, wait}
var _bubbles: CanvasLayer
var _last := Vector3.ZERO
var _speed := 0.0
var _clock := 0.0

func _ready() -> void:
	_bubbles = CanvasLayer.new()
	_bubbles.layer = 4
	add_child(_bubbles)

func add_person(node: Node3D, lines: Array) -> void:
	_things.append({"node": node, "kind": "person", "lines": lines, "next": 0, "touching": false, "wait": 0.0})

func add_animal(node: Node3D, sound: String = "") -> void:
	if sound == "" and node is LowPolyAnimal:
		sound = SOUNDS.get((node as LowPolyAnimal).species, "")
	elif sound == "" and node is LowPolyDog:
		sound = "Woof!"
	_things.append({"node": node, "kind": "animal", "lines": [sound] if sound != "" else [], "next": 0,
		"touching": false, "wait": 0.0})

func remove(node: Node3D) -> void:
	for i in range(_things.size() - 1, -1, -1):
		if _things[i]["node"] == node:
			_things.remove_at(i)

func _process(delta: float) -> void:
	_clock += delta
	if scribe == null or not is_instance_valid(scribe):
		return
	var p := scribe.global_position
	var step := Vector2(p.x - _last.x, p.z - _last.z).length()
	if step > 0.6:
		_speed = 0.0  # moved by the scene (a cutscene or a jump), not walking: no bumps
	elif delta > 0.0:
		_speed = lerpf(_speed, step / delta, minf(1.0, delta * 12.0))
	_last = p
	for t in _things:
		var n: Node3D = t["node"]
		if not is_instance_valid(n) or not n.is_visible_in_tree():
			continue
		var q := n.global_position
		var d := Vector2(q.x - p.x, q.z - p.z).length()
		var r := reach if t["kind"] == "person" else animal_reach * maxf(0.6, n.scale.x)
		if d > r + 0.35:
			t["touching"] = false
			continue
		if d > r or t["touching"]:
			continue
		t["touching"] = true
		if not enabled or _speed < 0.5 or _clock < float(t["wait"]):
			continue
		t["wait"] = _clock + COOLDOWN
		if t["kind"] == "person":
			_bump_person(t)
		else:
			_bump_animal(t)
		bumped.emit(n)

## Make `node` react right now, as if bumped (tests use this too).
func bump(node: Node3D) -> void:
	for t in _things:
		if t["node"] == node:
			if t["kind"] == "person":
				_bump_person(t)
			else:
				_bump_animal(t)
			bumped.emit(node)

func _bump_person(t: Dictionary) -> void:
	var n: Node3D = t["node"]
	var lines: Array = t["lines"]
	if scribe:
		var to := scribe.global_position - n.global_position
		if not (n is LowPolyPerson and (n as LowPolyPerson).sitting):
			var tw := create_tween()
			tw.tween_property(n, "rotation:y", n.rotation.y + angle_difference(n.rotation.y, atan2(-to.z, to.x)), 0.2)
	if n is LowPolyPerson:
		var person := n as LowPolyPerson
		var was := person.gesture
		person.gesture = "talk"
		get_tree().create_timer(1.6).timeout.connect(func():
			if is_instance_valid(person) and person.gesture == "talk":
				person.gesture = was)
	if not lines.is_empty():
		_say(n, String(lines[int(t["next"]) % lines.size()]), 2.2)
		t["next"] = int(t["next"]) + 1

func _bump_animal(t: Dictionary) -> void:
	var n: Node3D = t["node"]
	var away := n.global_position - scribe.global_position
	away.y = 0.0
	away = away.normalized() if away.length() > 0.01 else Vector3.RIGHT
	# A startled little squash-and-hop.
	var base := n.scale
	var tw := create_tween().set_trans(Tween.TRANS_SINE)
	tw.tween_property(n, "scale", base * Vector3(1.12, 0.82, 1.12), 0.07)
	tw.tween_property(n, "scale", base * Vector3(0.94, 1.12, 0.94), 0.1)
	tw.tween_property(n, "scale", base, 0.12)
	if n is LowPolyAnimal:
		var a := n as LowPolyAnimal
		if a.mode == "wander":
			# Scurry out of the way, off to one side of the scribe's path.
			var side := Vector3(-away.z, 0, away.x) * (1.0 if randf() < 0.5 else -1.0)
			var spot := a.position + (away * 2.2 + side * 1.0) * maxf(1.0, a.scale.x)
			spot.z = clampf(spot.z, a.z_limit.x, a.z_limit.y)
			if a.avoid.is_valid() and a.avoid.call(spot):
				spot = a.position + away * 1.4
			a.run_to(spot)
	elif n is LowPolyDog:
		var dog := n as LowPolyDog
		dog.wag = 1.0
	var lines: Array = t["lines"]
	if not lines.is_empty():
		_say(n, String(lines[0]), 1.3)

## A speech bubble that floats over `node` for a few seconds.
func _say(node: Node3D, text: String, height: float) -> void:
	for b in _bubbles.get_children():
		if b.get_meta("node") == node:
			b.queue_free()
	var bubble := Bubble.new()
	bubble.set_meta("node", node)
	bubble.target = node
	bubble.height = height * maxf(0.7, node.scale.y) if not node is LowPolyPerson else height
	bubble.text = text
	_bubbles.add_child(bubble)

## Text currently shown over `node`, or "" (used by tests).
func bubble_text(node: Node3D) -> String:
	for b in _bubbles.get_children():
		if b.get_meta("node") == node and not b.is_queued_for_deletion():
			return (b as Bubble).text
	return ""

class Bubble extends PanelContainer:
	var target: Node3D
	var height := 2.2
	var text := ""
	var _age := 0.0
	var _label: Label

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var s := UiStyle.card(Color(0.98, 0.97, 0.93, 0.96), 18, 0)
		s.content_margin_left = 16
		s.content_margin_right = 16
		s.content_margin_top = 8
		s.content_margin_bottom = 10
		s.border_color = Color(0, 0, 0, 0.12)
		s.shadow_size = 8
		add_theme_stylebox_override("panel", s)
		_label = UiStyle.label(text, 22, Color(0.1, 0.11, 0.16), 750)
		_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_label.custom_minimum_size = Vector2(minf(360.0, 14.0 * text.length() + 10.0), 0)
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(_label)
		modulate.a = 0.0
		scale = Vector2(0.7, 0.7)
		var tw := create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(self, "modulate:a", 1.0, 0.15)
		tw.tween_property(self, "scale", Vector2.ONE, 0.25)
		_place()

	func _process(delta: float) -> void:
		_age += delta
		if _age > BUBBLE_TIME:
			modulate.a -= delta * 4.0
			if modulate.a <= 0.0:
				queue_free()
				return
		_place()

	func _place() -> void:
		if not is_instance_valid(target):
			queue_free()
			return
		var cam := get_viewport().get_camera_3d()
		if cam == null:
			return
		var p := target.global_position + Vector3(0, height, 0)
		visible = not cam.is_position_behind(p)
		var s := cam.unproject_position(p)
		pivot_offset = Vector2(size.x / 2.0, size.y)
		position = s - Vector2(size.x / 2.0, size.y + 6.0)

	func _draw() -> void:
		# The bubble's little tail, pointing down at the speaker.
		var c := Color(0.98, 0.97, 0.93, 0.96)
		var m := Vector2(size.x / 2.0, size.y)
		draw_colored_polygon(PackedVector2Array([m + Vector2(-10, -1), m + Vector2(10, -1), m + Vector2(0, 12)]), c)

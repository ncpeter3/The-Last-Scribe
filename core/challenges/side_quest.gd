class_name SideQuest
extends Node3D
## Base for an optional side quest: something extra to do while exploring, tied to the verses of the
## area. A golden scroll marks where it starts; walk up to it and tap the action button to hear what
## it's about. Side quests never block the story, and the scribe can come back for them later.
##
## The chapter (host) provides: get_scribe(), get_actor(id), say(lines, callback), ask(...),
## freeze() and unfreeze(). Config comes from the chapter's data ("side_quests" in beats.json):
##   id, type, title, marker: [x, z], after (beat id it unlocks at), intro (lines), done (lines), ...
## State: "locked" (not yet in the story) -> "offered" (marker shown) -> "active" -> "done".

signal finished(quest: SideQuest)

const MARKER_RANGE := 1.8

var host: Node
var cfg: Dictionary
var title := ""
var state := "locked"
var scribe: Node3D
var marker_pos := Vector3.ZERO
var _marker: Node3D

func setup(h: Node, c: Dictionary) -> void:
	host = h
	cfg = c
	title = String(c.get("title", "Side quest"))
	name = String(c.get("id", "quest"))
	var m: Array = c.get("marker", [0, 0])
	marker_pos = Vector3(float(m[0]), 0, float(m[1]))

## Make the marker and the quest's props. Called once while building the world.
func build() -> void:
	_marker = Props.quest_marker(self, marker_pos)
	_marker.hide()
	build_props()

## Override: make the quest's own props (hidden until the quest starts, if they should be).
func build_props() -> void:
	pass

## The story has reached the beat this quest belongs to: show its marker.
func unlock() -> void:
	if state != "locked":
		return
	state = "offered"
	_marker.show()

func tick(delta: float) -> void:
	if scribe == null:
		scribe = host.get_scribe()
	if state == "active":
		update(delta)

## Override: per-frame logic while active.
func update(_delta: float) -> void:
	pass

func action() -> String:
	if state == "offered" and flat_dist(marker_pos) < MARKER_RANGE:
		return "Side quest: %s" % title
	if state == "active":
		return active_action()
	return ""

## Override: action button text while active, or "".
func active_action() -> String:
	return ""

func act() -> void:
	if state == "offered":
		state = "active"
		_marker.hide()
		var intro: Array = cfg.get("intro", [])
		host.say(intro, start)
		return
	if state == "active":
		active_act()

## Override: called once the intro has been read.
func start() -> void:
	pass

## Override: the action button was tapped while active.
func active_act() -> void:
	pass

## Override: (done, total) for the progress bar.
func progress() -> Vector2i:
	return Vector2i(0, 1)

## Override: a short line for the task list (defaults to the title).
func task_text() -> String:
	return title

func complete() -> void:
	if state == "done":
		return
	state = "done"
	GameState.complete_side_quest(String(cfg.get("id", name)))
	var lines: Array = cfg.get("done", []).duplicate()
	lines.append({"speaker": "Codex", "text": "Side quest complete: %s." % title})
	host.say(lines, func(): finished.emit(self))

func flat_dist(p: Vector3) -> float:
	return Vector2(p.x - scribe.position.x, p.z - scribe.position.z).length()

func glow_ring(pos: Vector3, radius: float, c: Color = Color(0.4, 0.95, 0.85)) -> void:
	var t := TorusMesh.new()
	t.inner_radius = radius * 0.85
	t.outer_radius = radius
	t.rings = 24
	t.ring_segments = 6
	var m := Props.add(self, t, c, Vector3(pos.x, 0.05, pos.z), 2.0)
	m.scale = Vector3(1, 0.3, 1)
	var tw := m.create_tween()
	tw.tween_interval(1.5)
	tw.tween_property(m, "scale", Vector3(1.6, 0.3, 1.6), 0.6)
	tw.tween_callback(m.queue_free)

## A little hop, to show something noticed you.
static func hop(n: Node3D) -> void:
	var y := n.position.y
	var tw := n.create_tween()
	tw.tween_property(n, "position:y", y + 0.35, 0.15).set_ease(Tween.EASE_OUT)
	tw.tween_property(n, "position:y", y, 0.2).set_ease(Tween.EASE_IN)

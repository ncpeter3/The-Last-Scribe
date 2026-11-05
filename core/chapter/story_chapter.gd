class_name StoryChapter
extends Node3D
## Base for a story chapter: a top-down 3D world (angled bird's-eye camera, free movement) that runs
## left to right. Story beats trigger in order as the scribe reaches each station (the way forward is
## blocked until the current beat is told, so the order of Scripture is kept). Between stations the
## world is open: walk freely and tap "Look" on glowing orbs for Scribe's notes and bonus verses.
## A beat can have a challenge (core/challenges/challenge.gd) that starts right after the beat's
## verses and has its own area of the world; the beat's "after_lines" play when it's done.
## Optional side quests are marked by golden scrolls (data "side_quests", core/challenges/side_quest.gd).
## There is one copy of each story character (_actors): they appear at their beat, walk from scene to
## scene and wander. When the chapter is finished, a time gate opens at the end of the path that leads
## on to the next chapter (data "next").
##
## A chapter extends this and overrides the hooks in the "chapter hooks" section below: its data file,
## challenge and quest scripts, characters, ground colors and the scenery of each region.
## All text lives in the chapter's data JSON. Distances are in meters.

const DialogueBox := preload("res://core/ui/dialogue_box.gd")
const Scribe := preload("res://core/player/scribe.gd")
const Joystick := preload("res://core/ui/joystick.gd")
const ChoicePanel := preload("res://core/ui/choice_panel.gd")
const NOTE_RANGE := 1.4
const PORTAL_RANGE := 2.4

var _scribe: Node3D
var _cam: Camera3D
var _env: Environment
var _sky_mat: ProceduralSkyMaterial
var _sun: DirectionalLight3D
var _dialogue: CanvasLayer
var _data: Dictionary
var _beats: Array = []
var _discoverables: Array = []
var _orbs: Array = []
var _beat_index := 0
var _world_end := 0.0
var _look_button: Button
var _action_button: Button
var _tracker: TaskTracker
var _hint: Label
var _bumper: Bumper
var _choice: CanvasLayer
var _regions: Array = []  # {kind, x0, x1}: the scenery of each stretch of the world, in order
var _challenges: Dictionary = {}  # beat index -> Challenge
var _challenge: Challenge  # the one running now
var _dialogue_cb := Callable()
var _choice_cb := Callable()
var _joystick: Control
var _title_label: Label
var _journal_panel: PanelContainer
var _journal_text: RichTextLabel
var _near: Dictionary = {}
var _mood_tween: Tween
var _mood := Color(0.1, 0.1, 0.18)
var _rng := RandomNumberGenerator.new()
var _time := 0.0
var _world: Node3D
var _fade: ColorRect
## The chapter's story characters, one of each: {id: {node (holder), fig (LowPolyPerson), roam (Roamer)}}.
var _actors: Dictionary = {}
var _told := -1  # the last beat whose verses have started
var _quests: Array = []  # SideQuest
var _action_target: Object  # what the action button does now (a challenge, a side quest, or self)
var _busy := false  # a chapter's own little scene is playing (no buttons, no bumps)
var _side_data: Array = []
var _done_flash: Dictionary = {}  # a just-finished story task, shown full for a moment
var _done_until := 0.0
var _portal: Node3D  # the time gate to the next chapter (once this one is done)
var complete := false
var gone := false  # set once the scribe steps through the time gate
var auto_change_scene := true  # the playtest turns this off

# ---------- chapter hooks (override these) ----------

## The chapter's data file (beats, discoverables, side_quests, next, ...).
func data_path() -> String:
	return ""

## Saved in GameState.completed_chapters when the chapter is finished.
func chapter_id() -> String:
	return ""

## Challenge type -> script.
func challenge_scripts() -> Dictionary:
	return {}

## Side-quest type -> script.
func quest_scripts() -> Dictionary:
	return {}

## The story characters: id -> CharacterFactory look id they start in.
func actor_looks() -> Dictionary:
	return {}

## What each look says when bumped into.
func bump_lines() -> Dictionary:
	return {}

## Where each person stands at a story station, relative to the station.
func station_offsets() -> Dictionary:
	return {}

## Ground color of each scenery kind.
func ground_colors() -> Dictionary:
	return {"void": Color(0.3, 0.5, 0.3)}

## Scenery kinds with flat bare ground (no hills, no path).
func flat_kinds() -> Array:
	return ["void"]

## Build one stretch of scenery.
func _build_section(_root: Node3D, _kind: String, _x0: float, _x1: float) -> void:
	pass

## A beat's verses are about to start: move characters for it.
func _on_beat_actors(_beat: Dictionary) -> void:
	pass

## A beat (and its challenge) has finished.
func _on_beat_finished(_beat: Dictionary) -> void:
	pass

## Should the people in this beat wander about while its challenge runs?
func _roams_in_challenge(_beat: Dictionary) -> bool:
	return true

## A chapter's own action button (when nothing else wants it): label, or "".
func _extra_action() -> String:
	return ""

func _do_extra_action() -> void:
	pass

## Extra build step after the world, scribe and HUD exist.
func _after_ready() -> void:
	pass

# ---------- setup ----------

func _ready() -> void:
	_rng.seed = 1031
	Props.reset()
	_data = JSON.parse_string(FileAccess.get_file_as_string(data_path()))
	_beats = _data["beats"]
	_discoverables = _data["discoverables"]
	_side_data = _data.get("side_quests", [])
	_compute_regions()
	_bumper = Bumper.new()
	add_child(_bumper)
	_build_environment()
	_build_world()
	_build_scribe()
	_bumper.scribe = _scribe
	for a in _actors.values():
		(a["roam"] as Roamer).watcher = _scribe
	_bumper.bumped.connect(_on_bumped)
	_build_hud()
	_dialogue = DialogueBox.new()
	add_child(_dialogue)
	_dialogue.finished.connect(_on_dialogue_finished)
	_choice = ChoicePanel.new()
	add_child(_choice)
	_choice.chosen.connect(_on_choice)
	_apply_mood(Color(_beats[0]["tint"]))
	_update_limit()
	_cam.position = _cam_target()
	_after_ready()

func _cam_target() -> Vector3:
	# Angled bird's-eye view. The scribe sits in the upper half of the screen so the
	# dialogue box at the bottom never covers them.
	return _scribe.position + Look.CAM_OFFSET

func _process(delta: float) -> void:
	_time += delta
	_cam.position = _cam.position.lerp(_cam_target(), minf(1.0, delta * 4.0))
	_scribe.move_vec = _joystick.value
	for i in _orbs.size():
		var o: Node3D = _orbs[i]
		o.position.y = 1.3 + sin(_time * 2.0 + i) * 0.12
	_update_tasks()
	_bumper.enabled = not (_dialogue.active or _choice.active or _busy)
	_hint.visible = not (_dialogue.active or _choice.active)
	if _dialogue.active or _choice.active or _busy or gone:
		_look_button.hide()
		_action_button.hide()
		return
	for q in _quests:
		q.tick(delta)
	var label := ""
	_action_target = null
	if _challenge:
		_challenge.tick(delta)
		if _challenge == null:  # finished during tick
			return
		label = _challenge.action()
		if label != "":
			_action_target = _challenge
	elif _beat_index < _beats.size() and _scribe.position.x >= float(_beats[_beat_index]["x"]) - 0.05:
		_start_beat()
		return
	if label == "":
		for q in _quests:
			var l: String = q.action()
			if l != "":
				label = l
				_action_target = q
				break
	if label == "" and _near_portal():
		label = String(_data["next"].get("verb", "Step into the time gate"))
		_action_target = _portal
	if label == "":
		label = _extra_action()
		if label != "":
			_action_target = self
	_action_button.visible = label != ""
	_action_button.text = label
	_near = {}
	for d in _discoverables:
		if absf(_scribe.position.x - float(d["x"])) < NOTE_RANGE:
			_near = d
			break
	_look_button.visible = not _near.is_empty()
	if not _near.is_empty():
		_look_button.text = "Look: %s" % _near["name"]

# ---------- story flow ----------

func _start_beat() -> void:
	var beat: Dictionary = _beats[_beat_index]
	_title_label.text = "%s  (%d/%d)" % [beat["title"], _beat_index + 1, _beats.size()]
	_apply_mood(Color(beat["tint"]), 2.0)
	_told = _beat_index
	_actors_at_beat_start(beat)
	for q in _quests:
		if String(q.cfg.get("after", "arrive")) == String(beat["id"]):
			q.unlock()
	say(beat["lines"], _after_beat_lines)

func _after_beat_lines() -> void:
	var ch: Challenge = _challenges.get(_beat_index)
	if ch == null:
		_finish_beat()
		return
	_challenge = ch
	ch.completed.connect(_on_challenge_done, CONNECT_ONE_SHOT)
	if _roams_in_challenge(_beats[_beat_index]):
		_actors_roam_challenge(_beats[_beat_index], ch)
	_scribe.max_x = maxf(ch.x1, float(_beats[_beat_index]["x"]))
	var intro: Array = ch.cfg.get("intro", [])
	if intro.is_empty():
		ch.begin()
	else:
		say(intro, ch.begin)

func _on_challenge_done() -> void:
	var ch := _challenge
	_challenge = null
	_action_button.hide()
	# Show the finished task full and green for a moment, then clear it.
	var done := ch.task()
	done.erase("done")
	done.erase("total")
	done.erase("hint")
	done["progress"] = 1.0
	_done_flash = done
	_done_until = _time + 2.0
	var lines: Array = ch.cfg.get("done", []) + _beats[_beat_index].get("after_lines", [])
	if lines.is_empty():
		_finish_beat()
	else:
		say(lines, _finish_beat)

func _finish_beat() -> void:
	_on_beat_finished(_beats[_beat_index])
	_beat_index += 1
	if _beat_index >= _beats.size():
		_complete_chapter()
	else:
		_actors_approach(_beats[_beat_index])
	_update_limit()

func _complete_chapter() -> void:
	complete = true
	GameState.complete_chapter(chapter_id())
	_title_label.text = "Chapter complete: %d verses, %d/%d side quests" % [GameState.unlocked_verses.size(), _quests_done(), _quests.size()]
	var next: Dictionary = _data.get("next", {})
	if next.has("scene"):
		_open_portal()
	elif next.has("lines"):
		say(next["lines"])

func freeze() -> void:
	_freeze()

func unfreeze() -> void:
	_unfreeze()

func _freeze() -> void:
	_scribe.frozen = true
	_scribe.move_vec = Vector2.ZERO
	_joystick.cancel()
	_joystick.enabled = false

func _unfreeze() -> void:
	_scribe.frozen = false
	_joystick.enabled = true

## Play dialogue lines, then call `then` (if valid). Used by beats, notes and challenges.
func say(lines: Array, then: Callable = Callable()) -> void:
	_freeze()
	_dialogue_cb = then
	_dialogue.play(lines)

## Show a question with answer buttons, then call `then` with the index chosen.
func ask(question: String, options: Array, then: Callable) -> void:
	_freeze()
	_choice_cb = then
	_choice.ask(question, options)

## The task cards in the top-left corner: [{title, hint?, done + total or progress 0..1, side?}].
func _set_tasks(list: Array) -> void:
	_tracker.set_tasks(list)

func get_scribe() -> Node3D:
	return _scribe

## One of the chapter's story characters by id, or null.
func get_actor(id: String) -> Node3D:
	return _actors[id]["node"] if _actors.has(id) else null

func _on_dialogue_finished() -> void:
	_unfreeze()
	var cb := _dialogue_cb
	_dialogue_cb = Callable()
	if cb.is_valid():
		cb.call()

func _on_choice(i: int) -> void:
	_unfreeze()
	var cb := _choice_cb
	_choice_cb = Callable()
	if cb.is_valid():
		cb.call(i)

func _update_limit() -> void:
	if _beat_index < _beats.size():
		_scribe.max_x = float(_beats[_beat_index]["x"])
	else:
		_scribe.max_x = _world_end

func _on_look() -> void:
	if _near.is_empty():
		return
	var lines := [{"speaker": _near["name"], "text": _near["note"]}]
	if _near.has("verse"):
		lines[0]["verse"] = _near["verse"]
	say(lines)

func _unhandled_input(event: InputEvent) -> void:
	# E on a keyboard does whatever the on-screen button would.
	if event.is_action_pressed("interact"):
		if _action_button.visible:
			_on_action()
		elif _look_button.visible:
			_on_look()

func _on_action() -> void:
	if _dialogue.active or _choice.active or _busy or gone:
		return
	if _action_target == null:
		return
	if _action_target == self:
		_do_extra_action()
	elif _action_target == _portal:
		_travel()
	elif _action_target == _challenge:
		_challenge.act()
	elif _action_target is SideQuest:
		(_action_target as SideQuest).act()

# ---------- the time gate to the next chapter ----------

func portal_pos() -> Vector3:
	return Vector3(_world_end - 5.0, 0, -1.2)

func _near_portal() -> bool:
	if _portal == null or not _portal.visible:
		return false
	var p := portal_pos()
	return Vector2(_scribe.position.x - p.x, _scribe.position.z - p.z).length() < PORTAL_RANGE

func _open_portal() -> void:
	_portal = Props.time_gate(_world, portal_pos())
	_portal.scale = Vector3.ONE * 0.05
	var tw := _portal.create_tween()
	tw.tween_property(_portal, "scale", Vector3.ONE, 1.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var lines: Array = _data["next"].get("lines", [])
	if not lines.is_empty():
		say(lines)

## Step through the time gate: a flash of light, then the next chapter.
func _travel() -> void:
	gone = true
	_freeze()
	var lp: LowPolyPerson = _scribe.get("_lp")
	var tw := create_tween()
	tw.tween_property(_scribe, "position", portal_pos() + Vector3(0, 0, 0.05), 0.8)
	tw.tween_callback(func():
		if lp:
			lp.walk_speed = 0.0
			lp.gesture = "wave")
	tw.tween_property(_fade, "color", Color(0.85, 1.0, 1.0, 1.0), 0.9)
	tw.tween_callback(func():
		if auto_change_scene:
			get_tree().change_scene_to_file(String(_data["next"]["scene"])))

# ---------- environment and mood ----------

func _build_environment() -> void:
	_sky_mat = ProceduralSkyMaterial.new()
	_sky_mat.sun_angle_max = 20.0
	var sky := Sky.new()
	sky.sky_material = _sky_mat
	_env = Look.environment(sky)
	var we := WorldEnvironment.new()
	we.environment = _env
	add_child(we)
	_sun = Look.sun()
	add_child(_sun)
	_cam = Look.camera()
	add_child(_cam)

func _apply_mood(c: Color, duration: float = 0.0) -> void:
	if _mood_tween:
		_mood_tween.kill()
	if duration <= 0.0:
		_set_mood(c)
		return
	var from := _mood
	_mood_tween = create_tween()
	_mood_tween.tween_method(func(t: float): _set_mood(from.lerp(c, t)), 0.0, 1.0, duration)

func _set_mood(c: Color) -> void:
	# Each beat's tint colors the sky, light and haze, but the sky stays sky-blue overhead in daylight
	# and the ground keeps its own colors, so scenes get a mood without turning one flat color.
	_mood = c
	var lum := c.get_luminance()
	var day := smoothstep(0.12, 0.62, lum)
	var horizon := c.darkened(0.35).lerp(Color(0.8, 0.87, 0.95).lerp(c, 0.45), day)
	_sky_mat.sky_horizon_color = horizon
	_sky_mat.ground_horizon_color = horizon
	_sky_mat.sky_top_color = c.darkened(0.7).lerp(Color(0.24, 0.46, 0.82).lerp(c, 0.2), day)
	_sky_mat.ground_bottom_color = horizon.darkened(0.5)
	_env.fog_light_color = horizon
	_env.ambient_light_color = horizon.lerp(Color(0.55, 0.65, 0.85), 0.5)
	_env.ambient_light_energy = lerpf(0.55, 0.6, day)
	_sun.light_energy = lerpf(0.4, 1.25, day)
	_sun.light_color = Color(1.0, 0.94, 0.82).lerp(c, 0.25)

# ---------- world building ----------

func _compute_regions() -> void:
	# Each beat's scenery leads up to its station; a challenge adds its own area right after it.
	var x0 := -20.0
	for b in _beats:
		var x1 := float(b["x"])
		_regions.append({"kind": String(b["scenery"]), "x0": x0, "x1": x1})
		x0 = x1
		var ch: Dictionary = b.get("challenge", {})
		if float(ch.get("x1", 0.0)) > x1:
			_regions.append({"kind": String(ch.get("scenery", b["scenery"])), "x0": x1, "x1": float(ch["x1"])})
			x0 = float(ch["x1"])
	_world_end = x0 + 14.0
	_regions.append({"kind": String(_data.get("end_scenery", "gate")), "x0": x0, "x1": _world_end + 30.0})

func _build_world() -> void:
	var root := Node3D.new()
	root.name = "World"
	add_child(root)
	_world = root
	var challenges := challenge_scripts()
	# Challenges first, so their rivers and pools are known and the scenery keeps out of them.
	for i in _beats.size():
		var b: Dictionary = _beats[i]
		var x := float(b["x"])
		_marker(root, x)
		if b.has("challenge"):
			var ch: Challenge = challenges[String(b["challenge"]["type"])].new()
			ch.setup(self, b["challenge"], x)
			root.add_child(ch)
			ch.build()
			_challenges[i] = ch
	for r in _regions:
		_build_section(root, String(r["kind"]), float(r["x0"]), float(r["x1"]))
	_build_ground(root)
	for d in _discoverables:
		_orb(root, float(d["x"]))
	_build_actors(root)
	var quests := quest_scripts()
	for qd in _side_data:
		var q: SideQuest = quests[String(qd["type"])].new()
		q.setup(self, qd)
		root.add_child(q)
		q.build()
		_quests.append(q)

func _scenery_at(x: float) -> Dictionary:
	var prev := "void"
	for r in _regions:
		if x < float(r["x1"]):
			return {"kind": r["kind"], "prev": prev, "x0": r["x0"], "x1": r["x1"]}
		prev = r["kind"]
	var last: Dictionary = _regions[-1]
	return {"kind": last["kind"], "prev": prev, "x0": last["x0"], "x1": last["x1"]}

func _ground_color(x: float) -> Color:
	var g := ground_colors()
	var s := _scenery_at(x)
	var t := clampf((x - float(s["x0"])) / 8.0, 0.0, 1.0)
	return Color(g[s["prev"]]).lerp(g[s["kind"]], t * t * (3.0 - 2.0 * t))

## Extra color for one spot of ground (crop rows, cracks...), or the base color unchanged.
func _ground_detail(_p: Vector3, base: Color) -> Color:
	return base

func _build_ground(root: Node3D) -> void:
	# Low-poly ground: a sheet of flat-lit triangles. Colors blend between scenes along the path, a
	# sandy path runs down the middle, gentle hills rise far from the path, and the ground dips under
	# every pool, river and sea (Props.water_rects) so the water has depth and fish swim beneath it.
	var x0 := -20.0
	var x1 := _world_end + 30.0
	var zs: Array[float] = [-40.0, -32.0, -25.0, -20.0, -16.0, -13.0]
	var z := -11.0
	while z <= 11.01:
		zs.append(z)
		z += 1.0 if absf(z) > 3.0 else 0.5
	zs.append_array([13.0, 16.0, 20.0, 25.0, 32.0, 40.0])
	var xs: Array[float] = []
	var x := x0
	while x <= x1 + 0.01:
		xs.append(x)
		x += 1.0
	var noise := FastNoiseLite.new()
	noise.seed = 7
	noise.frequency = 0.07
	var flat := flat_kinds()
	var h := []
	var col := []
	for xi in xs.size():
		var hr := []
		var cr := []
		var gx: float = xs[xi]
		var base := _ground_color(gx)
		var flat_here := String(_scenery_at(gx)["kind"]) in flat
		for zi in zs.size():
			var gz: float = zs[zi]
			var p := Vector3(gx, 0, gz)
			var y := 0.0
			var c := base
			if Props.in_water(p, -0.05):
				y = -0.35
				c = base.lerp(Color(0.75, 0.68, 0.5), 0.6)
			elif not flat_here:
				var hill := smoothstep(9.0, 15.0, absf(gz))
				y = (noise.get_noise_2d(gx, gz) * 0.5 + 0.5) * hill * 1.6 + hill * 0.3
				c = _ground_detail(p, c)
				c = c.lerp(c.darkened(0.12), noise.get_noise_2d(gx * 2.0, gz * 2.0) * 0.5 + 0.5)
				# The worn path down the middle.
				var path := 1.0 - smoothstep(0.7, 1.6, absf(gz + sin(gx * 0.15) * 0.3))
				c = c.lerp(Color(0.72, 0.6, 0.42), path * 0.75)
			hr.append(y)
			cr.append(c)
		h.append(hr)
		col.append(cr)
	var b := LowPoly.new()
	b.jitter = 0.05
	for xi in xs.size() - 1:
		for zi in zs.size() - 1:
			var a := Vector3(xs[xi], h[xi][zi], zs[zi])
			var bb := Vector3(xs[xi + 1], h[xi + 1][zi], zs[zi])
			var c := Vector3(xs[xi + 1], h[xi + 1][zi + 1], zs[zi + 1])
			var d := Vector3(xs[xi], h[xi][zi + 1], zs[zi + 1])
			var c1: Color = (col[xi][zi] + col[xi + 1][zi] + col[xi][zi + 1]) / 3.0
			var c2: Color = (col[xi + 1][zi] + col[xi + 1][zi + 1] + col[xi][zi + 1]) / 3.0
			c1.a = 1.0
			c2.a = 1.0
			# Alternate the diagonal so the facets don't line up in stripes.
			if (xi + zi) % 2 == 0:
				b.tri(a, d, bb, c1)
				b.tri(bb, d, c, c2)
			else:
				b.tri(a, d, c, c1)
				b.tri(a, c, bb, c2)
	var mi := b.instance(false)
	mi.name = "Ground"
	root.add_child(mi)

func _side_z(near: float, far: float) -> float:
	# A random depth on either side of the path, never closer than `near`.
	return _rng.randf_range(near, far) * (1.0 if _rng.randf() < 0.5 else -1.0)

func _scatter_plants(root: Node3D, x0: float, x1: float, density: float, trees: bool) -> void:
	var n := int((x1 - x0) * density)
	for i in n:
		var p := Vector3(_rng.randf_range(x0, x1), 0, _side_z(2.5, 12.0))
		if Props.in_water(p, 0.5):
			continue
		if trees and _rng.randf() < 0.3:
			Props.tree(root, p + Vector3(0, 0, signf(p.z) * _rng.randf_range(0, 5)), _rng.randf_range(0.8, 1.5), Color(0.2, 0.55, 0.25))
		elif _rng.randf() < 0.12:
			Props.nature(root, "bush", p, _rng.randf_range(0.5, 0.8))
		else:
			Props.grass(root, p, Color(0.25, 0.6, 0.25))

func _marker(root: Node3D, x: float) -> void:
	Props.add(root, Props.box(Vector3(0.5, 2.0, 0.5)), Color(0.85, 0.8, 0.65), Vector3(x, 1.0, -1.6))
	Props.add(root, Props.sphere(0.28), Color(1.0, 0.9, 0.5), Vector3(x, 2.3, -1.6), 2.5)

func _orb(root: Node3D, x: float) -> void:
	var o := Node3D.new()
	o.position = Vector3(x, 1.3, -0.4)
	root.add_child(o)
	Props.add(o, Props.sphere(0.2), Color(1.0, 0.95, 0.45), Vector3.ZERO, 3.0)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.9, 0.5)
	l.light_energy = 1.2
	l.omni_range = 4.0
	o.add_child(l)
	_orbs.append(o)

func _build_scribe() -> void:
	_scribe = Scribe.new()
	_scribe.female = GameState.scribe_gender == "female"
	_scribe.position = Vector3(0, 0, 0)
	add_child(_scribe)
	# Pollen and dust drifting in the light around the scribe (stars in the dark at the start).
	Look.motes(_scribe)

# ---------- story characters ----------

func _build_actors(root: Node3D) -> void:
	var looks := actor_looks()
	var lines := bump_lines()
	for id in looks:
		var holder := Node3D.new()
		holder.name = String(id).capitalize()
		root.add_child(holder)
		var fig := CharacterFactory.make(looks[id], holder, Vector3.ZERO) as LowPolyPerson
		var roam := Roamer.attach(holder, fig)
		roam.avoid = func(p: Vector3) -> bool: return Props.in_water(p, 0.4)
		holder.hide()
		_actors[id] = {"node": holder, "fig": fig, "roam": roam}
		_bumper.add_person(holder, lines.get(looks[id], []))

## Someone bumped into stops for a moment to talk, then carries on.
func _on_bumped(n: Node3D) -> void:
	for id in _actors:
		if _actors[id]["node"] == n:
			var r := _roam(id)
			if r.radius <= 0.0 or r.busy():
				return
			r.paused = true
			get_tree().create_timer(2.8).timeout.connect(func():
				if r.radius > 0.0:
					r.paused = false)

func _roam(id: String) -> Roamer:
	return _actors[id]["roam"]

func _station(beat: Dictionary, id: String) -> Vector3:
	return Vector3(float(beat["x"]), 0, 0) + station_offsets().get(id, Vector3(2.0, 0, -1.4))

## Change what someone wears.
func _dress(id: String, look_id: String) -> void:
	var a: Dictionary = _actors[id]
	(a["fig"] as Node3D).queue_free()
	var fig := CharacterFactory.make(look_id, a["node"], Vector3.ZERO) as LowPolyPerson
	a["fig"] = fig
	(a["roam"] as Roamer).person = fig
	_bumper.remove(a["node"])
	_bumper.add_person(a["node"], bump_lines().get(look_id, []))

## Someone appears as Scripture tells of them: they rise out of a swirl of light.
func _appear(id: String, at: Vector3) -> void:
	var n: Node3D = _actors[id]["node"]
	_roam(id).place(at)
	n.rotation.y = PI / 2.0  # facing the camera
	n.show()
	n.scale = Vector3.ONE * 0.05
	var tw := n.create_tween()
	tw.tween_interval(0.4)
	tw.tween_property(n, "scale", Vector3.ONE, 1.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for k in 10:
		var a := TAU * k / 10.0
		var mote := Props.add(_world, Props.sphere(0.07, 1.0, 5), Color(1.0, 0.92, 0.6), at + Vector3(cos(a) * 0.9, 0.1, sin(a) * 0.9), 3.0)
		var mt := mote.create_tween()
		mt.tween_property(mote, "position", at + Vector3(cos(a + 2.0) * 0.2, 1.6, sin(a + 2.0) * 0.2), 1.6)
		mt.tween_callback(mote.queue_free)

## Someone is there from the start of the chapter (no swirl of light).
func _show_actor(id: String, at: Vector3, radius: float = 1.2) -> void:
	var n: Node3D = _actors[id]["node"]
	_roam(id).place(at)
	_roam(id).radius = radius
	n.show()

func _actors_at_beat_start(beat: Dictionary) -> void:
	_on_beat_actors(beat)
	for f in beat.get("figures", []):
		if not _actors.has(f) or not _actors[f]["node"].visible:
			continue
		# Already there, or on the way: if they're still far off, they arrive now.
		var n: Node3D = _actors[f]["node"]
		if _roam(f).radius <= 0.0 and _roam(f).paused:
			continue  # posed by the chapter for this scene
		if n.position.distance_to(_station(beat, f)) > 6.0:
			_roam(f).place(_station(beat, f))
		elif not _roam(f).busy():
			_roam(f).anchor = _station(beat, f)

## While a challenge runs, the people in its scene wander about its area.
func _actors_roam_challenge(beat: Dictionary, ch: Challenge) -> void:
	for f in beat.get("figures", []):
		if not _actors.has(f) or not _actors[f]["node"].visible:
			continue
		var r := _roam(f)
		var mid := Vector3((ch.x0 + maxf(ch.x1, ch.x0 + 6.0)) / 2.0, 0, -1.0 if f == beat["figures"][0] else 1.5)
		r.go_to(mid, true)
		r.radius = 4.0

## When the next scene comes up, the people in it walk there ahead of the scribe.
func _actors_approach(beat: Dictionary) -> void:
	for f in beat.get("figures", []):
		if not _actors.has(f) or not _actors[f]["node"].visible:
			continue
		var r := _roam(f)
		r.paused = false
		r.radius = 1.2
		r.go_to(_station(beat, f), true)

func _beat_index_of(id: String) -> int:
	for i in _beats.size():
		if String(_beats[i]["id"]) == id:
			return i
	return -1

# ---------- side quests and the task list ----------

func _quests_done() -> int:
	var n := 0
	for q in _quests:
		if q.state == "done":
			n += 1
	return n

## The task list at the top left: the story task (while a challenge runs), then each side quest
## that has been started, each with its progress bar.
func _update_tasks() -> void:
	var tasks := []
	if _challenge and _challenge.running:
		tasks.append(_challenge.task())
	elif not _done_flash.is_empty() and _time < _done_until:
		tasks.append(_done_flash)
	for q in _quests:
		if q.state == "active":
			var p: Vector2i = q.progress()
			tasks.append({"title": q.task_text(), "done": p.x, "total": p.y, "side": true})
	_set_tasks(tasks)

# ---------- HUD ----------

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_title_label = Label.new()
	_title_label.position = Vector2(30, 20)
	_title_label.theme_type_variation = &"HeaderLabel"
	_title_label.text = String(_data.get("start_hint", "Follow the path to the right"))
	layer.add_child(_title_label)
	_joystick = Joystick.new()
	_joystick.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_joystick)
	_hint = Label.new()
	var hint := _hint
	hint.text = "Drag on the left side to walk"
	hint.position = Vector2(40, 640)
	hint.add_theme_font_size_override("font_size", 26)
	hint.add_theme_color_override("font_outline_color", Color.BLACK)
	hint.add_theme_constant_override("outline_size", 6)
	layer.add_child(hint)
	_look_button = Button.new()
	_look_button.custom_minimum_size = Vector2(460, 120)
	_look_button.position = Vector2(780, 560)
	_look_button.add_theme_font_size_override("font_size", 30)
	_look_button.pressed.connect(_on_look)
	_look_button.hide()
	layer.add_child(_look_button)
	_action_button = Button.new()
	_action_button.custom_minimum_size = Vector2(460, 120)
	_action_button.position = Vector2(780, 420)
	_action_button.add_theme_font_size_override("font_size", 32)
	var gold := StyleBoxFlat.new()
	gold.bg_color = Color(0.55, 0.42, 0.12, 0.92)
	gold.set_corner_radius_all(16)
	_action_button.add_theme_stylebox_override("normal", gold)
	var gold_hi := gold.duplicate()
	gold_hi.bg_color = Color(0.7, 0.55, 0.18, 0.95)
	_action_button.add_theme_stylebox_override("hover", gold_hi)
	_action_button.add_theme_stylebox_override("pressed", gold_hi)
	_action_button.pressed.connect(_on_action)
	_action_button.hide()
	layer.add_child(_action_button)
	_tracker = TaskTracker.new()
	add_child(_tracker)
	var journal_btn := Button.new()
	journal_btn.text = "Journal"
	journal_btn.position = Vector2(1090, 20)
	journal_btn.custom_minimum_size = Vector2(170, 76)
	journal_btn.add_theme_font_size_override("font_size", 28)
	journal_btn.pressed.connect(_toggle_journal)
	layer.add_child(journal_btn)
	_journal_panel = PanelContainer.new()
	_journal_panel.anchor_left = 0.1
	_journal_panel.anchor_right = 0.9
	_journal_panel.anchor_top = 0.15
	_journal_panel.anchor_bottom = 0.85
	_journal_text = RichTextLabel.new()
	_journal_text.add_theme_font_size_override("normal_font_size", 26)
	_journal_panel.add_child(_journal_text)
	_journal_panel.hide()
	layer.add_child(_journal_panel)
	# A full-screen fade for arriving and leaving through the time gate.
	var top := CanvasLayer.new()
	top.layer = 10
	add_child(top)
	_fade = ColorRect.new()
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.color = Color(0.85, 1.0, 1.0, 0.0)
	top.add_child(_fade)

## Arrive through the time gate: the screen starts white and clears.
func arrive_flash() -> void:
	_fade.color = Color(0.85, 1.0, 1.0, 1.0)
	var tw := create_tween()
	tw.tween_interval(0.2)
	tw.tween_property(_fade, "color:a", 0.0, 1.2)

func _toggle_journal() -> void:
	_journal_panel.visible = not _journal_panel.visible
	if _journal_panel.visible:
		_journal_text.text = "Scroll Journal (%d verses)\n\n%s" % [GameState.unlocked_verses.size(), "\n".join(GameState.unlocked_verses)]

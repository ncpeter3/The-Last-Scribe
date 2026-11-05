extends Node3D
## Chapter 1: Genesis 1-3, as a top-down 3D world (angled bird's-eye camera, free movement).
## Story beats trigger in order as the scribe reaches each station (the way forward is blocked until
## the current beat is told, so the order of Scripture is kept). Between stations the world is open:
## walk freely and tap "Look" on glowing orbs for Scribe's notes and bonus verses.
## A beat can have a challenge (see core/challenges/challenge.gd) that starts right after the
## beat's verses and has its own area of the world; the beat's "after_lines" play when it's done.
## There is one Adam and one Eve (they appear when Scripture tells of them, then walk from scene to
## scene and wander), optional side quests marked by golden scrolls (data "side_quests", see
## core/challenges/side_quest.gd), and the forbidden tree, where Adam stops any scribe who reaches
## for its fruit. All text lives in data/beats.json. Distances are in meters.

const DialogueBox := preload("res://core/ui/dialogue_box.gd")
const Scribe := preload("res://core/player/scribe.gd")
const Joystick := preload("res://core/ui/joystick.gd")
const ChoicePanel := preload("res://core/ui/choice_panel.gd")
const CHALLENGES := {
	"tend_garden": preload("res://chapters/01_adam_and_eve/challenges/tend_garden.gd"),
	"name_animals": preload("res://chapters/01_adam_and_eve/challenges/name_animals.gd"),
	"gather_fruit": preload("res://chapters/01_adam_and_eve/challenges/gather_fruit.gd"),
	"find_hiding": preload("res://chapters/01_adam_and_eve/challenges/find_hiding.gd"),
	"scroll_quiz": preload("res://chapters/01_adam_and_eve/challenges/scroll_quiz.gd"),
}
const QUESTS := {
	"find": preload("res://chapters/01_adam_and_eve/quests/find.gd"),
	"lamb": preload("res://chapters/01_adam_and_eve/quests/lamb.gd"),
	"rest": preload("res://chapters/01_adam_and_eve/quests/rest.gd"),
}
const DATA := "res://chapters/01_adam_and_eve/data/beats.json"
const PLUCK_RANGE := 2.6
## Where each person stands at a story station, relative to the station.
const STATION := {"adam": Vector3(1.8, 0, -1.4), "eve": Vector3(3.0, 0, -1.4)}
const NOTE_RANGE := 1.4
## What Adam and Eve say when the scribe bumps into them (in the garden, and at the gate).
const BUMP_LINES := {
	"adam": ["Peace be with thee, friend.", "Mind the animals. I have given each one a name!", "The LORD God made all of this. Is it not very good?"],
	"eve": ["Hello! Hast thou seen the flowers by the river?", "Walk gently. The garden is full of life.", "Every tree here is a gift."],
	"adam_skins": ["Now I must till the ground.", "Write it down true, scribe. All of it."],
	"eve_skins": ["The LORD made us coats of skins. He has not forgotten us.", "We go out from the garden together."],
}

const GROUND := {
	"void": Color(0.06, 0.06, 0.1), "light": Color(0.8, 0.72, 0.48), "sea": Color(0.16, 0.36, 0.5),
	"sky": Color(0.38, 0.56, 0.3), "animals": Color(0.42, 0.58, 0.3), "rest": Color(0.6, 0.62, 0.36),
	"eden": Color(0.31, 0.55, 0.26), "naming": Color(0.34, 0.57, 0.27), "flowers": Color(0.37, 0.6, 0.31),
	"tree": Color(0.28, 0.47, 0.24), "dark": Color(0.19, 0.27, 0.18), "gate": Color(0.52, 0.4, 0.26),
	"garden": Color(0.32, 0.56, 0.27),
}
# Land animals made on day six and named by Adam: [model id, scale].
const LAND_ANIMALS := [["cow", 1.0], ["horse", 1.0], ["sheep", 1.0], ["pig", 1.0], ["llama", 1.0], ["zebra", 1.0],
	["wolf", 1.0], ["fox", 1.0], ["dog", 1.0], ["cat", 1.0], ["chick", 1.2], ["sheep", 0.9], ["cow", 0.9]]

var _scribe: Node3D
var _cam: Camera3D
var _env: Environment
var _sky_mat: ProceduralSkyMaterial
var _sun: DirectionalLight3D
var _dialogue: CanvasLayer
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
## The chapter's one Adam and one Eve: {id: {node (holder), fig (LowPolyPerson), roam (Roamer)}}.
## They appear when Scripture tells of them, then walk from scene to scene and wander freely.
var _actors: Dictionary = {}
var _told := -1  # the last beat whose verses have started
var _quests: Array = []  # SideQuest
var _action_target: Object  # what the action button does now (a challenge, a side quest, or self)
var _forbidden_pos := Vector3.INF  # the tree of the knowledge of good and evil
var _plucking := false
var _plucks := 0
var _adam_lines: Array = []
var _side_data: Array = []
var _done_flash: Dictionary = {}  # a just-finished story task, shown full for a moment
var _done_until := 0.0

func _ready() -> void:
	_rng.seed = 1031
	Props.reset()
	var data = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	_beats = data["beats"]
	_discoverables = data["discoverables"]
	_side_data = data.get("side_quests", [])
	_adam_lines = data.get("forbidden_fruit", [])
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

func _cam_target() -> Vector3:
	# Angled bird's-eye view. The scribe sits in the upper half of the screen so the
	# dialogue box at the bottom never covers them.
	return _scribe.position + Look.CAM_OFFSET

func _process(delta: float) -> void:
	_time += delta
	# Camera follows the scribe from the side, with a little look-ahead.
	_cam.position = _cam.position.lerp(_cam_target(), minf(1.0, delta * 4.0))
	_scribe.move_vec = _joystick.value
	for i in _orbs.size():
		var o: Node3D = _orbs[i]
		o.position.y = 1.3 + sin(_time * 2.0 + i) * 0.12
	_update_tasks()
	_bumper.enabled = not (_dialogue.active or _choice.active or _plucking)
	_hint.visible = not (_dialogue.active or _choice.active)
	if _dialogue.active or _choice.active or _plucking:
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
	if label == "" and _can_pluck():
		label = "Pluck a fruit"
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
	_beat_index += 1
	if _beat_index >= _beats.size():
		GameState.complete_chapter("01_adam_and_eve")
		_title_label.text = "Chapter complete: %d verses, %d/%d side quests" % [GameState.unlocked_verses.size(), _quests_done(), _quests.size()]
	else:
		_actors_approach(_beats[_beat_index])
	_update_limit()

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

## The chapter's Adam or Eve ("adam", "eve"), or null.
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
	if _dialogue.active or _choice.active or _plucking:
		return
	if _action_target == null:
		return
	if _action_target == self:
		_pluck()
	elif _action_target == _challenge:
		_challenge.act()
	elif _action_target is SideQuest:
		(_action_target as SideQuest).act()

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
	_regions.append({"kind": "gate", "x0": x0, "x1": _world_end + 30.0})

func _build_world() -> void:
	var root := Node3D.new()
	root.name = "World"
	add_child(root)
	_world = root
	# Challenges first, so their rivers and pools are known and the scenery keeps out of them.
	for i in _beats.size():
		var b: Dictionary = _beats[i]
		var x := float(b["x"])
		_marker(root, x)
		if b.has("challenge"):
			var ch: Challenge = CHALLENGES[String(b["challenge"]["type"])].new()
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
	for qd in _side_data:
		var q: SideQuest = QUESTS[String(qd["type"])].new()
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
	var s := _scenery_at(x)
	var c: Color = GROUND[s["kind"]]
	if s["kind"] == "sea" and x > float(s["x0"]) + (float(s["x1"]) - float(s["x0"])) * 0.6:
		c = GROUND["sky"]
	var t := clampf((x - float(s["x0"])) / 8.0, 0.0, 1.0)
	# The sea's stretch ends in dry land, so the next scene blends in from land, not water.
	var prev: Color = GROUND["sky"] if s["prev"] == "sea" else GROUND[s["prev"]]
	return prev.lerp(c, t * t * (3.0 - 2.0 * t))

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
	var h := []
	var col := []
	for xi in xs.size():
		var hr := []
		var cr := []
		var gx: float = xs[xi]
		var base := _ground_color(gx)
		var void_here := String(_scenery_at(gx)["kind"]) == "void"
		for zi in zs.size():
			var gz: float = zs[zi]
			var p := Vector3(gx, 0, gz)
			var y := 0.0
			var c := base
			if Props.in_water(p, -0.05):
				y = -0.35
				c = base.lerp(Color(0.75, 0.68, 0.5), 0.6)
			elif not void_here:
				var hill := smoothstep(9.0, 15.0, absf(gz))
				y = (noise.get_noise_2d(gx, gz) * 0.5 + 0.5) * hill * 1.6 + hill * 0.3
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

func _build_section(root: Node3D, kind: String, x0: float, x1: float) -> void:
	var sea_split := x0 + (x1 - x0) * 0.6
	var len := x1 - x0
	match kind:
		"void":
			for i in int(len * 1.2):
				Props.add(root, Props.sphere(_rng.randf_range(0.05, 0.14), 1.0, 4), Color(1, 1, 0.9), Vector3(_rng.randf_range(x0, x1), _rng.randf_range(0.5, 7), _rng.randf_range(-12, 12)), 3.0)
		"light":
			for i in 5:
				var bx := _rng.randf_range(x0 + 2, x1 - 2)
				Props.add(root, Props.box(Vector3(0.7, 40, 0.7)), Color(1, 0.95, 0.6, 0.22), Vector3(bx, 18, _side_z(3.0, 12.0)), 1.5)
			Props.add(root, Props.sphere(1.6), Color(1, 0.95, 0.7), Vector3((x0 + x1) / 2, 7, -10), 3.0)
		"sea":
			# The gathered waters on both sides, with dry land along the path (Genesis 1:9).
			for side in [[-40.0, -1.7], [1.7, 40.0]]:
				Props.water(root, x0, sea_split, side[0], side[1], 0.03, Color(0.1, 0.33, 0.52))
			for i in int(len * 0.3):
				Props.rock(root, Vector3(_rng.randf_range(x0, sea_split), 0.0, _side_z(3.0, 14.0)), _rng.randf_range(0.6, 1.8), Color(0.45, 0.5, 0.52))
			for i in 8:
				Props.creature(root, "fish", Vector3(_rng.randf_range(x0, sea_split), 0.05, _side_z(2.0, 10.0)), 1.6)
			_scatter_plants(root, sea_split, x1, 0.9, false)
		"sky":
			var mid := (x0 + x1) / 2.0
			Props.water(root, mid + 2, mid + 9, -12, -5)
			_scatter_plants(root, x0, x1, 1.0, true)
			Props.add(root, Props.sphere(1.3), Color(1, 0.9, 0.5), Vector3(mid - 5, 8, -9), 3.0)
			Props.add(root, Props.sphere(1.0), Color(0.9, 0.92, 1.0), Vector3(mid + 5, 8, -9), 1.2)
			for i in 6:
				Props.add(root, Props.sphere(0.1, 1.0, 4), Color(1, 1, 0.9), Vector3(_rng.randf_range(x0, x1), _rng.randf_range(6, 12), _rng.randf_range(-12, -6)), 3.0)
			for i in 7:
				Props.bird(root, Vector3(_rng.randf_range(x0, x1), _rng.randf_range(3, 6), _rng.randf_range(-8, 8)), Color(0.9, 0.9, 0.95))
			for i in 6:
				Props.creature(root, "fish", Vector3(mid + _rng.randf_range(2.5, 8.5), 0.05, _rng.randf_range(-11.5, -5.5)), 1.4)
			Props.creature(root, "whale", Vector3(mid + 5.5, -0.9, -8.5), 0.55)
			Props.creature(root, "eagle", Vector3(mid - 3, 4.5, -6), 1.0)
		"animals":
			_scatter_plants(root, x0, x1, 1.0, true)
			for i in int(len * 0.5):
				_land_animal(root, Vector3(_rng.randf_range(x0, x1), 0, _side_z(2.0, 9.0)))
		"rest":
			_scatter_plants(root, x0, x1, 1.3, true)
			for i in int(len * 0.8):
				Props.flower(root, Vector3(_rng.randf_range(x0, x1), 0, _rng.randf_range(-8, 8)), Color(1, 0.9, 0.5))
		"eden", "naming", "flowers", "tree", "dark", "garden":
			_build_garden(root, kind, x0, x1)
		"gate":
			_scatter_plants(root, x0, x1, 0.5, false)
			for sz in [-3.2, 3.2]:
				Props.flame(root, Vector3(x0 + 3.5, 0, sz))
				Props.cherub(root, Vector3(x0 + 2.2, 0, sz * 1.3))
			for i in int(len * 0.15):
				Props.rock(root, Vector3(_rng.randf_range(x0 + 6, x1), 0, _side_z(3.0, 12.0)), _rng.randf_range(0.6, 1.5), Color(0.5, 0.4, 0.3))

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

const BLOSSOM := [Color(1.0, 0.72, 0.82), Color(0.98, 0.95, 0.97), Color(1.0, 0.82, 0.62), Color(0.86, 0.72, 1.0)]
const FLOWERS := [Color(1, 0.5, 0.6), Color(1, 0.9, 0.4), Color(0.7, 0.6, 1.0), Color(1, 1, 1), Color(1, 0.6, 0.3), Color(0.5, 0.75, 1.0)]
const FRUIT := [Color(1.0, 0.55, 0.15), Color(0.95, 0.3, 0.45), Color(1.0, 0.85, 0.25), Color(0.55, 0.25, 0.55), Color(0.6, 0.85, 0.3)]

## The garden of Eden: lush and full of life. Many kinds of trees (fruit trees, flowering trees,
## palms and tall cypresses), beds of flowers, butterflies, birds, a pond fed by a little stream,
## and the river that waters the garden (Genesis 2:8-10).
func _build_garden(root: Node3D, kind: String, x0: float, x1: float) -> void:
	var len := x1 - x0
	if kind == "dark":
		# After the fall: the same garden, dim and still.
		for i in int(len * 1.3):
			var p := Vector3(_rng.randf_range(x0, x1), 0, _side_z(2.8, 16.0))
			if Props.in_water(p, 0.8):
				continue
			Props.tree(root, p, _rng.randf_range(0.9, 1.7), Color(0.1, 0.25, 0.15).lightened(_rng.randf_range(-0.05, 0.1)), Color(0, 0, 0, 0),
					"dead_tree" if _rng.randf() < 0.35 else "")
		for i in int(len * 0.8):
			Props.flower(root, Vector3(_rng.randf_range(x0, x1), 0, _rng.randf_range(-6, 6)), Color(0.55, 0.5, 0.6))
		return
	if kind == "eden":
		# A spring high in the garden runs down as a little stream into a round pond, and the pond
		# flows on into the river that waters the garden.
		Props.stream(root, [Vector2(x0 + 0.5, -13.5), Vector2(x0 + 1.5, -12.0), Vector2(x0 + 1.0, -10.8), Vector2(x0 + 2.2, -9.6)], 1.0)
		var pond := Props.pond(root, Vector3(x0 + 3.6, 0, -7.6), 2.4)
		Props.stream(root, [Vector2(x0 + 5.9, -7.4), Vector2(x0 + 7.4, -6.9), Vector2(x0 + 9.0, -6.6), Vector2(x0 + 10.4, -6.3)], 1.0)
		for i in 4:
			Props.creature(root, "fish", Vector3(pond.get_center().x + _rng.randf_range(-1, 1), 0, pond.get_center().y + _rng.randf_range(-1, 1)), 0.8)
		Props.add(root, Props.box(Vector3(2.2, 0.08, 0.35)), Color(0.5, 0.36, 0.24), Vector3(x0 + 1.0, 0.05, -5.0))  # a fallen log by the pond
	if kind == "flowers":
		# A lily pond among the flowers, where Eve is brought to Adam.
		var lily := Props.pond(root, Vector3(x0 + 5.0, 0, 6.6), 2.1)
		for i in 3:
			Props.creature(root, "fish", Vector3(lily.get_center().x, 0, lily.get_center().y), 0.7)
		Props.stream(root, [Vector2(x0 + 7.0, 7.4), Vector2(x0 + 8.5, 9.0), Vector2(x0 + 8.0, 10.6), Vector2(x0 + 9.4, 12.5)], 0.9)
	# Challenge areas ("garden") keep trees back so the play space stays open and in view.
	var near := 8.0 if kind == "garden" else 2.8
	for i in int(len * 1.1):
		var p := Vector3(_rng.randf_range(x0, x1), 0, _side_z(near, 16.0))
		if Props.in_water(p, 1.0):
			continue
		_eden_tree(root, p)
	# A back row of tall trees along the hills, so the garden feels enclosed and full.
	for i in int(len * 0.5):
		var p := Vector3(_rng.randf_range(x0, x1), 0, _side_z(13.0, 18.0))
		if not Props.in_water(p, 1.0):
			Props.tree(root, p, _rng.randf_range(1.3, 1.9), Color(0.16, 0.45, 0.2).lightened(_rng.randf_range(-0.05, 0.1)), Color(0, 0, 0, 0), "cypress" if _rng.randf() < 0.4 else "")
	# Beds of flowers: patches of one color, plus single flowers everywhere.
	for i in int(len * 0.45):
		var c: Vector3 = Vector3(_rng.randf_range(x0, x1), 0, _side_z(1.7, 9.0))
		var col: Color = FLOWERS[_rng.randi() % FLOWERS.size()]
		for k in _rng.randi_range(5, 9):
			var p := c + Vector3(_rng.randf_range(-0.9, 0.9), 0, _rng.randf_range(-0.6, 0.6))
			if not Props.in_water(p, 0.2) and absf(p.z) > 1.3:
				Props.flower(root, p, col)
	for i in int(len * 1.2):
		var p := Vector3(_rng.randf_range(x0, x1), 0, _rng.randf_range(-9, 9))
		if Props.in_water(p, 0.2) or absf(p.z) < 1.2:
			continue
		if _rng.randf() < 0.5:
			Props.flower(root, p, FLOWERS[_rng.randi() % FLOWERS.size()])
		elif _rng.randf() < 0.3:
			Props.nature(root, "bush_flowers" if _rng.randf() < 0.6 else "bush", p, _rng.randf_range(0.5, 0.85))
		else:
			Props.grass(root, p, Color(0.25, 0.6, 0.25))
	# Butterflies over the flowers, and birds in the air.
	for i in int(len * 0.35):
		Props.butterfly(root, Vector3(_rng.randf_range(x0, x1), 0, _side_z(1.8, 7.0)), FLOWERS[_rng.randi() % FLOWERS.size()])
	if kind in ["eden", "flowers", "naming"]:
		for i in 3:
			Props.bird(root, Vector3(_rng.randf_range(x0, x1), _rng.randf_range(3.5, 5.5), _rng.randf_range(-6, 6)), Color.WHITE)
	if kind == "eden":
		# The tree of life in the midst of the garden (Genesis 2:9).
		Props.tree(root, Vector3(x1 - 4.0, 0, -3.6), 1.6, Color(0.3, 0.7, 0.3), Color(1.0, 0.85, 0.3), "tree_2")
	if kind == "naming":
		for i in int(len * 0.9):
			_land_animal(root, Vector3(_rng.randf_range(x0, x1), 0, _side_z(1.6, 6.0)))
	if kind == "tree":
		# The tree of the knowledge of good and evil: a twisted tree with red-gold leaves.
		_forbidden_pos = Vector3(x1 - 3.0, 0, -3.4)
		Props.tree(root, _forbidden_pos, 0.55, Color(0.2, 0.5, 0.25), Color(0.85, 0.15, 0.15), "twisted_tree")
		Props.serpent(root, Vector3(x1 - 3.7, 0, -1.8))

## One of Eden's many trees, "pleasant to the sight, and good for food" (Genesis 2:9).
func _eden_tree(root: Node3D, p: Vector3) -> void:
	var roll := _rng.randf()
	var s := _rng.randf_range(0.9, 1.6)
	if roll < 0.28:
		Props.tree(root, p, s, BLOSSOM[_rng.randi() % BLOSSOM.size()], Color(0, 0, 0, 0), "blossom")
	elif roll < 0.38:
		Props.tree(root, p, s * 0.9, Color(0.3, 0.62, 0.25), Color(0, 0, 0, 0), "palm")
	elif roll < 0.48:
		Props.tree(root, p, s, Color(0.15, 0.42, 0.22), Color(0, 0, 0, 0), "cypress")
	elif roll < 0.8:
		Props.tree(root, p, s, Color(0.2, 0.55, 0.24).lightened(_rng.randf_range(-0.05, 0.12)), FRUIT[_rng.randi() % FRUIT.size()], "round")
	else:
		Props.tree(root, p, s, Color(0.18, 0.5, 0.22).lightened(_rng.randf_range(-0.05, 0.1)))

func _land_animal(root: Node3D, pos: Vector3) -> void:
	if Props.in_water(pos, 0.8):
		return
	var a: Array = LAND_ANIMALS[_rng.randi() % LAND_ANIMALS.size()]
	_bumper.add_animal(Props.creature(root, a[0], pos, float(a[1]) * _rng.randf_range(0.9, 1.1)))

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

# ---------- Adam and Eve ----------

func _build_actors(root: Node3D) -> void:
	for id in ["adam", "eve"]:
		var holder := Node3D.new()
		holder.name = id.capitalize()
		root.add_child(holder)
		var fig := CharacterFactory.make(id, holder, Vector3.ZERO) as LowPolyPerson
		var roam := Roamer.attach(holder, fig)
		roam.avoid = func(p: Vector3) -> bool: return Props.in_water(p, 0.4)
		holder.hide()
		_actors[id] = {"node": holder, "fig": fig, "roam": roam}
		_bumper.add_person(holder, BUMP_LINES[id])

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
	return Vector3(float(beat["x"]), 0, 0) + STATION[id]

## Change what someone wears (at the gate they wear the coats of skins, Genesis 3:21).
func _dress(id: String, look_id: String) -> void:
	var a: Dictionary = _actors[id]
	(a["fig"] as Node3D).queue_free()
	var fig := CharacterFactory.make(look_id, a["node"], Vector3.ZERO) as LowPolyPerson
	a["fig"] = fig
	(a["roam"] as Roamer).person = fig
	_bumper.remove(a["node"])
	_bumper.add_person(a["node"], BUMP_LINES.get(look_id, []))

## Someone appears as Scripture tells of them being made: they rise out of a swirl of light.
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

func _actors_at_beat_start(beat: Dictionary) -> void:
	var id := String(beat["id"])
	var figs: Array = beat.get("figures", [])
	match id:
		"adam":
			# "Formed man of the dust of the ground" (Genesis 2:7).
			_appear("adam", _station(beat, "adam"))
			_roam("adam").radius = 1.2
		"eve":
			_appear("eve", _station(beat, "eve"))
			_roam("eve").radius = 1.2
		"gate":
			for a in ["adam", "eve"]:
				_dress(a, a + "_skins")
				_roam(a).paused = false
				_roam(a).place(_station(beat, a))
				_roam(a).radius = 0.8
		"hiding":
			var ch: Challenge = _challenges.get(_beat_index)
			if ch and ch.has_method("spot"):
				hide_actors(ch.spot(), false)
	for f in figs:
		if not _actors.has(f) or not _actors[f]["node"].visible or id == "hiding":
			continue
		# Already there, or on the way: if they're still far off, they arrive now.
		var n: Node3D = _actors[f]["node"]
		if n.position.distance_to(_station(beat, f)) > 6.0:
			_roam(f).place(_station(beat, f))
		elif not _roam(f).busy():
			_roam(f).anchor = _station(beat, f)

## Send Adam and Eve to hide at `spot` (Genesis 3:8). `now` puts them there at once.
func hide_actors(spot: Vector3, now: bool) -> void:
	var offs := {"adam": Vector3(-0.45, 0, 0), "eve": Vector3(0.45, 0, 0)}
	for id in offs:
		var r := _roam(id)
		var n: Node3D = _actors[id]["node"]
		if not n.visible:
			continue
		var at: Vector3 = spot + offs[id]
		r.radius = 0.0
		var crouch := func():
			r.paused = true
			n.rotation.y = PI / 2.0  # facing away, hidden in the trees
		if now:
			if r.busy() or n.position.distance_to(at) > 0.2:
				r.place(at)
			crouch.call()
		else:
			r.go_to(at, true, crouch)

## While a challenge runs, the people in its scene wander about its area.
func _actors_roam_challenge(beat: Dictionary, ch: Challenge) -> void:
	if String(beat["id"]) == "hiding":
		return
	for f in beat.get("figures", []):
		if not _actors.has(f) or not _actors[f]["node"].visible:
			continue
		var r := _roam(f)
		var mid := Vector3((ch.x0 + maxf(ch.x1, ch.x0 + 6.0)) / 2.0, 0, -1.0 if f == "adam" else 1.5)
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

# ---------- the forbidden tree ----------

func _can_pluck() -> bool:
	if _forbidden_pos == Vector3.INF or _challenge != null:
		return false
	# Only before the serpent's scene: after that, the fruit has been eaten (Genesis 3:6).
	var serpent := _beat_index_of("serpent")
	if serpent < 0 or _told >= serpent:
		return false
	return Vector2(_scribe.position.x - _forbidden_pos.x, _scribe.position.z - _forbidden_pos.z).length() < PLUCK_RANGE

func _beat_index_of(id: String) -> int:
	for i in _beats.size():
		if String(_beats[i]["id"]) == id:
			return i
	return -1

## The scribe reaches for the forbidden fruit, and Adam comes running to knock it away. Every time.
var _pluck_fruit: Node3D
var _adam_home := Vector3.ZERO

func _pluck() -> void:
	_plucking = true
	_freeze()
	var hand := _scribe.position + Vector3(0.35, 1.0, 0.25)
	_pluck_fruit = Props.add(_world, Props.sphere(0.14, 1.0, 6), Color(0.85, 0.15, 0.15), _forbidden_pos + Vector3(0, 2.3, 0.6))
	var tw := _pluck_fruit.create_tween()
	tw.tween_property(_pluck_fruit, "position", hand, 0.45).set_ease(Tween.EASE_OUT)
	tw.tween_callback(_adam_runs_over)

func _adam_runs_over() -> void:
	var adam := get_actor("adam")
	if adam == null or not adam.visible:
		_smack()
		return
	var r := _roam("adam")
	_adam_home = r.anchor
	var side := Vector3(0.9, 0, 0.5) if adam.position.x >= _scribe.position.x else Vector3(-0.9, 0, 0.5)
	# If he's far off, he's just out of sight, already on his way.
	var gap := Vector3(adam.position.x - _scribe.position.x, 0, adam.position.z - _scribe.position.z)
	if gap.length() > 7.0:
		r.place(_scribe.position + gap.normalized() * 7.0)
		r.anchor = _adam_home
	r.paused = false
	r.go_to(_scribe.position + side, true, _smack)

func _smack() -> void:
	var adam := get_actor("adam")
	var fig: LowPolyPerson = _actors["adam"]["fig"]
	if adam and adam.visible:
		_roam("adam").face(_scribe.position)
		fig.gesture = "talk"
	# The fruit goes flying out of the scribe's hands and rolls away under the tree.
	var from := adam.position if adam and adam.visible else _scribe.position + Vector3.LEFT
	var away := Vector3(_scribe.position.x - from.x, 0, _scribe.position.z - from.z).normalized()
	var land := _scribe.position + away * 2.2 + Vector3(0, 0.14, 0)
	var fruit := _pluck_fruit
	var tw := fruit.create_tween()
	tw.tween_property(fruit, "position", (fruit.position + land) / 2.0 + Vector3(0, 0.9, 0), 0.22).set_ease(Tween.EASE_OUT)
	tw.tween_property(fruit, "position", land, 0.25).set_ease(Tween.EASE_IN)
	tw.tween_interval(0.6)
	tw.tween_property(fruit, "scale", Vector3.ONE * 0.01, 0.3)
	tw.tween_callback(fruit.queue_free)
	var line: Dictionary = {"speaker": "Adam", "text": "Don't you know you are not to eat from that tree?"}
	if not _adam_lines.is_empty():
		line = _adam_lines[_plucks % _adam_lines.size()]
	_plucks += 1
	_plucking = false
	say([line], _adam_goes_back)

func _adam_goes_back() -> void:
	var fig: LowPolyPerson = _actors["adam"]["fig"]
	fig.gesture = ""
	if not get_actor("adam").visible:
		return
	var r := _roam("adam")
	r.radius = 1.2
	r.go_to(_adam_home)

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
	_title_label.text = "Follow the path to the right"
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

func _toggle_journal() -> void:
	_journal_panel.visible = not _journal_panel.visible
	if _journal_panel.visible:
		_journal_text.text = "Scroll Journal (%d verses)\n\n%s" % [GameState.unlocked_verses.size(), "\n".join(GameState.unlocked_verses)]

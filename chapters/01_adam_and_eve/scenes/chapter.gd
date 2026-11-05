extends Node3D
## Chapter 1: Genesis 1-3, as a top-down 3D world (angled bird's-eye camera, free movement).
## Story beats trigger in order as the scribe reaches each station (the way forward is blocked until
## the current beat is told, so the order of Scripture is kept). Between stations the world is open:
## walk freely and tap "Look" on glowing orbs for Scribe's notes and bonus verses.
## A beat can have a challenge (see core/challenges/challenge.gd) that starts right after the
## beat's verses and has its own area of the world; the beat's "after_lines" play when it's done.
## All text lives in data/beats.json. Distances are in meters.

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
const DATA := "res://chapters/01_adam_and_eve/data/beats.json"
const NOTE_RANGE := 1.4

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
var _status_label: Label
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

func _ready() -> void:
	_rng.seed = 1031
	Props.reset()
	var data = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	_beats = data["beats"]
	_discoverables = data["discoverables"]
	_compute_regions()
	_build_environment()
	_build_world()
	_build_scribe()
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
	if _challenge and _challenge.running:
		_status_label.text = _challenge.status()
	if _dialogue.active or _choice.active:
		_look_button.hide()
		_action_button.hide()
		return
	if _challenge:
		_challenge.tick(delta)
		if _challenge == null:  # finished during tick
			return
		var label := _challenge.action()
		_action_button.visible = label != ""
		_action_button.text = label
	elif _beat_index < _beats.size() and _scribe.position.x >= float(_beats[_beat_index]["x"]) - 0.05:
		_start_beat()
		return
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
	say(beat["lines"], _after_beat_lines)

func _after_beat_lines() -> void:
	var ch: Challenge = _challenges.get(_beat_index)
	if ch == null:
		_finish_beat()
		return
	_challenge = ch
	ch.completed.connect(_on_challenge_done, CONNECT_ONE_SHOT)
	_scribe.max_x = maxf(ch.x1, float(_beats[_beat_index]["x"]))
	_status_label.text = ""
	_status_label.show()
	var intro: Array = ch.cfg.get("intro", [])
	if intro.is_empty():
		ch.begin()
	else:
		say(intro, ch.begin)

func _on_challenge_done() -> void:
	var ch := _challenge
	_challenge = null
	_action_button.hide()
	_status_label.hide()
	var lines: Array = ch.cfg.get("done", []) + _beats[_beat_index].get("after_lines", [])
	if lines.is_empty():
		_finish_beat()
	else:
		say(lines, _finish_beat)

func _finish_beat() -> void:
	_beat_index += 1
	if _beat_index >= _beats.size():
		GameState.complete_chapter("01_adam_and_eve")
		_title_label.text = "Chapter complete: %d verses recorded" % GameState.unlocked_verses.size()
	_update_limit()

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

func get_scribe() -> Node3D:
	return _scribe

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
	if _challenge and not _dialogue.active and not _choice.active:
		_challenge.act()

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
	for r in _regions:
		_build_section(root, String(r["kind"]), float(r["x0"]), float(r["x1"]))
	for i in _beats.size():
		var b: Dictionary = _beats[i]
		var x := float(b["x"])
		_marker(root, x)
		for f in b.get("figures", []):
			_figure(root, String(f), x, String(b["id"]))
		if b.has("challenge"):
			var ch: Challenge = CHALLENGES[String(b["challenge"]["type"])].new()
			ch.setup(self, b["challenge"], x)
			root.add_child(ch)
			ch.build()
			_challenges[i] = ch
	_build_ground(root)
	for d in _discoverables:
		_orb(root, float(d["x"]))

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

func _build_garden(root: Node3D, kind: String, x0: float, x1: float) -> void:
	var leaf := Color(0.18, 0.5, 0.22)
	var dense := 0.9
	if kind == "dark":
		leaf = Color(0.1, 0.25, 0.15)
		dense = 1.3
	var len := x1 - x0
	# Challenge areas ("garden") keep trees back so the play space stays open and in view.
	var near := 8.0 if kind == "garden" else 2.8
	if kind == "eden":
		Props.water(root, x0, x1, -9.5, -6.0)
	for i in int(len * dense):
		var p := Vector3(_rng.randf_range(x0, x1), 0, _side_z(near, 16.0))
		if Props.in_water(p, 0.8):
			continue
		Props.tree(root, p, _rng.randf_range(0.9, 1.7), leaf.lightened(_rng.randf_range(-0.05, 0.1)), Color(0.9, 0.75, 0.2) if _rng.randf() < 0.3 else Color(0, 0, 0, 0),
				"dead_tree" if kind == "dark" and _rng.randf() < 0.35 else "")
	if kind in ["eden", "flowers", "naming"]:
		for i in 3:
			Props.bird(root, Vector3(_rng.randf_range(x0, x1), _rng.randf_range(3.5, 5.5), _rng.randf_range(-6, 6)), Color.WHITE)
	for i in int(len * 1.5):
		Props.flower(root, Vector3(_rng.randf_range(x0, x1), 0, _rng.randf_range(-6, 6)), [Color(1, 0.5, 0.6), Color(1, 0.9, 0.4), Color(0.7, 0.6, 1.0), Color(1, 1, 1)][_rng.randi() % 4])
	if kind == "eden":
		for i in 6:
			Props.creature(root, "fish", Vector3(_rng.randf_range(x0 + 1, x1 - 1), 0, _rng.randf_range(-9.0, -6.5)), 1.0)
		# The tree of life in the midst of the garden (Genesis 2:9).
		Props.tree(root, Vector3(x1 - 4.0, 0, -3.6), 1.6, Color(0.3, 0.7, 0.3), Color(1.0, 0.85, 0.3), "tree_2")
	if kind == "naming":
		for i in int(len * 0.9):
			_land_animal(root, Vector3(_rng.randf_range(x0, x1), 0, _side_z(1.6, 6.0)))
	if kind == "tree":
		# The tree of the knowledge of good and evil: a twisted tree with red-gold leaves.
		Props.tree(root, Vector3(x1 - 3.0, 0, -3.4), 0.55, Color(0.2, 0.5, 0.25), Color(0.85, 0.15, 0.15), "twisted_tree")
		Props.serpent(root, Vector3(x1 - 3.7, 0, -1.8))

func _land_animal(root: Node3D, pos: Vector3) -> void:
	if Props.in_water(pos, 0.8):
		return
	var a: Array = LAND_ANIMALS[_rng.randi() % LAND_ANIMALS.size()]
	Props.creature(root, a[0], pos, float(a[1]) * _rng.randf_range(0.9, 1.1))

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

func _figure(root: Node3D, kind: String, x: float, beat_id: String) -> void:
	# At the gate they wear the coats of skins God made for them (Genesis 3:21).
	var suffix := "_skins" if beat_id == "gate" else ""
	match kind:
		"adam":
			CharacterFactory.make("adam" + suffix, root, Vector3(x + 1.8, 0, -1.4), true)
		"eve":
			CharacterFactory.make("eve" + suffix, root, Vector3(x + 3.0, 0, -1.4), true)
		"serpent":
			pass  # drawn with the tree
		"cherub":
			pass  # drawn at the gate

func _build_scribe() -> void:
	_scribe = Scribe.new()
	_scribe.female = GameState.scribe_gender == "female"
	_scribe.position = Vector3(0, 0, 0)
	add_child(_scribe)
	# Pollen and dust drifting in the light around the scribe (stars in the dark at the start).
	Look.motes(_scribe)

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
	var hint := Label.new()
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
	_status_label = Label.new()
	_status_label.position = Vector2(30, 70)
	_status_label.size = Vector2(1040, 0)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_font_size_override("font_size", 26)
	_status_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.6))
	_status_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_status_label.add_theme_constant_override("outline_size", 7)
	_status_label.hide()
	layer.add_child(_status_label)
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

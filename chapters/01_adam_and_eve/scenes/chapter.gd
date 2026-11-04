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
	"void": Color(0.06, 0.06, 0.1), "light": Color(0.85, 0.75, 0.45), "sea": Color(0.16, 0.4, 0.58),
	"sky": Color(0.4, 0.62, 0.35), "animals": Color(0.45, 0.68, 0.35), "rest": Color(0.68, 0.74, 0.4),
	"eden": Color(0.3, 0.65, 0.3), "naming": Color(0.35, 0.7, 0.32), "flowers": Color(0.38, 0.72, 0.4),
	"tree": Color(0.3, 0.55, 0.28), "dark": Color(0.2, 0.3, 0.2), "gate": Color(0.55, 0.4, 0.25),
	"garden": Color(0.33, 0.67, 0.31),
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
	return _scribe.position + Vector3(1.0, 9.5, 6.5)

func _process(delta: float) -> void:
	_time += delta
	# Camera follows the scribe from the side, with a little look-ahead.
	_cam.position = _cam.position.lerp(_cam_target(), minf(1.0, delta * 4.0))
	_scribe.move_vec = _joystick.value
	for i in _orbs.size():
		var o: Node3D = _orbs[i]
		o.position.y = 1.3 + sin(_time * 2.0 + i) * 0.12
	if _challenge:
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
	var sky := Sky.new()
	sky.sky_material = _sky_mat
	_env = Environment.new()
	_env.background_mode = Environment.BG_SKY
	_env.sky = sky
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	_env.ambient_light_energy = 1.1
	_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_env.fog_enabled = true
	_env.fog_density = 0.012
	var we := WorldEnvironment.new()
	we.environment = _env
	add_child(we)
	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(-58, -30, 0)
	_sun.shadow_enabled = true
	_sun.shadow_opacity = 0.55
	_sun.directional_shadow_max_distance = 40.0
	add_child(_sun)
	_cam = Camera3D.new()
	_cam.fov = 46.0
	_cam.rotation_degrees = Vector3(-58, 0, 0)
	_cam.far = 200.0
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
	_mood = c
	var lum := c.get_luminance()
	_sky_mat.sky_horizon_color = c
	_sky_mat.ground_horizon_color = c
	_sky_mat.sky_top_color = c.lerp(Color(0.2, 0.4, 0.8), 0.55 * lum).darkened(0.25)
	_sky_mat.ground_bottom_color = c.darkened(0.5)
	_env.fog_light_color = c
	_env.ambient_light_energy = lerpf(0.5, 0.9, lum)
	_sun.light_energy = lerpf(0.2, 0.85, lum)
	_sun.light_color = Color(1.0, 0.95, 0.85).lerp(c, 0.2)

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
	return Color(GROUND[s["prev"]]).lerp(c, t * t * (3.0 - 2.0 * t))

func _build_ground(root: Node3D) -> void:
	# Ground in 2 m strips whose color blends smoothly between scenes.
	var x := -20.0
	while x < _world_end + 30.0:
		Props.slab(root, x, x + 2.0, _ground_color(x + 1.0), -40.0, 40.0)
		x += 2.0

func _build_section(root: Node3D, kind: String, x0: float, x1: float) -> void:
	var ground: Color = GROUND[kind]
	var sea_split := x0 + (x1 - x0) * 0.6
	if kind != "void":
		Props.add(root, Props.box(Vector3(x1 - x0, 0.04, 2.4)), ground.lightened(0.1), Vector3((x0 + x1) / 2.0, 0.02, 0.0))
	var len := x1 - x0
	match kind:
		"void":
			for i in int(len * 1.2):
				Props.add(root, Props.sphere(_rng.randf_range(0.05, 0.14), 1.0, 4), Color(1, 1, 0.9), Vector3(_rng.randf_range(x0, x1), _rng.randf_range(0.5, 7), _rng.randf_range(-12, 12)), 3.0)
		"light":
			for i in 5:
				var bx := _rng.randf_range(x0 + 2, x1 - 2)
				var beam := Props.add(root, Props.box(Vector3(0.7, 40, 0.7)), Color(1, 0.95, 0.6, 0.22), Vector3(bx, 18, _side_z(3.0, 12.0)), 1.5)
				beam.material_override.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			Props.add(root, Props.sphere(1.6), Color(1, 0.95, 0.7), Vector3((x0 + x1) / 2, 7, -10), 3.0)
		"sea":
			for i in int(len * 0.3):
				Props.rock(root, Vector3(_rng.randf_range(x0, sea_split), 0.0, _side_z(3.0, 14.0)), _rng.randf_range(0.6, 1.8), Color(0.45, 0.5, 0.52))
			for i in 8:
				Props.creature(root, "fish", Vector3(_rng.randf_range(x0, sea_split), 0.05, _side_z(2.0, 10.0)), 1.6)
			_scatter_plants(root, sea_split, x1, 0.9, false)
		"sky":
			_scatter_plants(root, x0, x1, 1.0, true)
			var mid := (x0 + x1) / 2.0
			Props.add(root, Props.sphere(1.3), Color(1, 0.9, 0.5), Vector3(mid - 5, 8, -9), 3.0)
			Props.add(root, Props.sphere(1.0), Color(0.9, 0.92, 1.0), Vector3(mid + 5, 8, -9), 1.2)
			for i in 6:
				Props.add(root, Props.sphere(0.1, 1.0, 4), Color(1, 1, 0.9), Vector3(_rng.randf_range(x0, x1), _rng.randf_range(6, 12), _rng.randf_range(-12, -6)), 3.0)
			for i in 7:
				Props.bird(root, Vector3(_rng.randf_range(x0, x1), _rng.randf_range(3, 6), _rng.randf_range(-8, 8)), Color(0.9, 0.9, 0.95))
			Props.slab(root, mid + 2, mid + 9, Color(0.2, 0.5, 0.75), -12, -5, 0.03, 0.1)
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
	for i in int(len * dense):
		var p := Vector3(_rng.randf_range(x0, x1), 0, _side_z(near, 16.0))
		Props.tree(root, p, _rng.randf_range(0.9, 1.7), leaf.lightened(_rng.randf_range(-0.05, 0.1)), Color(0.9, 0.75, 0.2) if _rng.randf() < 0.3 else Color(0, 0, 0, 0),
				"dead_tree" if kind == "dark" and _rng.randf() < 0.35 else "")
	for i in int(len * 1.5):
		Props.flower(root, Vector3(_rng.randf_range(x0, x1), 0, _rng.randf_range(-6, 6)), [Color(1, 0.5, 0.6), Color(1, 0.9, 0.4), Color(0.7, 0.6, 1.0), Color(1, 1, 1)][_rng.randi() % 4])
	if kind == "eden":
		Props.slab(root, x0, x1, Color(0.25, 0.55, 0.8), -9.5, -6.0, 0.03, 0.1)
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

# ---------- HUD ----------

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_title_label = Label.new()
	_title_label.position = Vector2(30, 20)
	_title_label.add_theme_font_size_override("font_size", 34)
	_title_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_title_label.add_theme_constant_override("outline_size", 8)
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

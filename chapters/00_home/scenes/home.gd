extends Node3D
## Opening scene: the scribe's home in the year 2060, the night they leave.
## A small top-down 3D house (bedroom, kitchen, living room, garage). The family is home: talking
## to them is optional, and each talk asks the scribe a question. The time machine in the garage
## starts Chapter 1. If the scribe hasn't talked to anyone yet, the garage gently asks first.
## All text lives in data/home.json. Distances are in meters; the camera looks toward -Z.
## Look and feel (materials, lights, environment) is kept in the _build_* functions so it can be
## restyled in one place.

signal departing

const DialogueBox := preload("res://core/ui/dialogue_box.gd")
const ChoicePanel := preload("res://core/ui/choice_panel.gd")
const Scribe := preload("res://core/player/scribe.gd")
const Joystick := preload("res://core/ui/joystick.gd")
const DATA := "res://chapters/00_home/data/home.json"
const CHAPTER_1 := "res://chapters/01_adam_and_eve/scenes/chapter.tscn"
const TALK_RANGE := 1.9
const LOOK_RANGE := 1.5
const MACHINE_RANGE := 2.6

# House outline and walls (x0, z0, x1, z1, height). Back walls are tall; walls nearer the camera
# are low "cutaway" walls so they never hide the scribe.
const HOUSE := Rect2(-11.0, -7.0, 26.0, 12.0)
const WALL_T := 0.3
const TALL := 2.8
const LOW := 1.1
const WALLS := [
	[-11.0, -7.0, 15.0, -6.7, TALL],  # back wall (with windows)
	[-11.0, -7.0, -10.7, 5.0, TALL],  # left wall
	[14.7, -7.0, 15.0, 5.0, TALL],  # right wall (garage)
	[-11.0, 4.7, 15.0, 5.0, 0.45],  # front wall
	[-11.0, -1.15, -8.4, -0.85, LOW],  # bedroom / kitchen (door at x -8.4..-6.6)
	[-6.6, -1.15, -3.0, -0.85, LOW],
	[-3.15, -7.0, -2.85, -4.6, LOW],  # bedroom / living room (door at z -4.6..-2.8)
	[-3.15, -2.8, -2.85, -0.85, LOW],  # kitchen is open to the living room below z -0.85
	[-3.15, 3.6, -2.85, 5.0, LOW],
	[5.85, -7.0, 6.15, 1.2, LOW],  # living room / garage (door at z 1.2..3.4)
	[5.85, 3.4, 6.15, 5.0, LOW],
]

const C_WALL := Color(0.74, 0.76, 0.8)
const C_TRIM := Color(0.25, 0.88, 0.81)  # the teal glow used for 2060 tech, like the scribe's sash
const C_WOOD := Color(0.62, 0.5, 0.4)
const C_TILE := Color(0.58, 0.6, 0.64)
const C_RUG := Color(0.36, 0.42, 0.56)
const C_CONCRETE := Color(0.33, 0.35, 0.39)

var _data: Dictionary
var _scribe: Node3D
var _cam: Camera3D
var _env: Environment
var _dialogue: CanvasLayer
var _choice: CanvasLayer
var _joystick: Control
var _action_button: Button
var _title_label: Label
var _fade: ColorRect
var _hint: Label
var _family: Dictionary = {}  # id -> {cfg, node}
var _talked: Array = []  # ids of family members talked to (any order)
var _targets: Array = []  # {kind, pos, range, label, cfg}
var _near: Dictionary = {}
var _rings: Array[Node3D] = []
var _machine_glow: Array[StandardMaterial3D] = []
var _machine_light: OmniLight3D
var _dialogue_cb := Callable()
var _choice_cb := Callable()
var _time := 0.0
var _spin := 1.0
var gone := false  # set once the time machine has been started
var auto_change_scene := true  # the playtest turns this off

func _ready() -> void:
	_data = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	_build_environment()
	_build_house()
	_build_furniture()
	_build_machine()
	_build_family()
	_build_looks()
	_build_scribe()
	_build_hud()
	_dialogue = DialogueBox.new()
	add_child(_dialogue)
	_dialogue.finished.connect(_on_dialogue_finished)
	_choice = ChoicePanel.new()
	add_child(_choice)
	_choice.chosen.connect(_on_choice)
	_cam.position = _cam_target()
	say(_data["intro"])

func _cam_target() -> Vector3:
	return _scribe.position + Look.CAM_OFFSET

func _process(delta: float) -> void:
	_time += delta
	_cam.position = _cam.position.lerp(_cam_target(), minf(1.0, delta * 4.0))
	_scribe.move_vec = _joystick.value
	_animate_machine(delta)
	_hint.visible = not (_dialogue.active or _choice.active or gone)
	if _dialogue.active or _choice.active or gone:
		_action_button.hide()
		return
	_near = {}
	var best := 1e9
	for t in _targets:
		var p: Vector3 = t["pos"]
		var d := Vector2(_scribe.position.x - p.x, _scribe.position.z - p.z).length()
		if d < float(t["range"]) and d < best:
			best = d
			_near = t
	_action_button.visible = not _near.is_empty()
	if not _near.is_empty():
		_action_button.text = _near["label"]

# ---------- talking and looking ----------

## Fill in words that depend on the chosen scribe ({child}: son/daughter, {big}: big brother/sister).
func _words(lines: Array) -> Array:
	var female := GameState.scribe_gender == "female"
	var out := []
	for l in lines:
		var line: Dictionary = (l as Dictionary).duplicate()
		var text := String(line.get("text", ""))
		text = text.replace("{child}", "girl" if female else "boy")
		text = text.replace("{big}", "big sister" if female else "big brother")
		line["text"] = text
		out.append(line)
	return out

func say(lines: Array, then: Callable = Callable()) -> void:
	_freeze()
	_dialogue_cb = then
	_dialogue.play(_words(lines))

func ask(question: String, options: Array, then: Callable) -> void:
	_freeze()
	_choice_cb = then
	_choice.ask(question, options)

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

func _freeze() -> void:
	_scribe.frozen = true
	_scribe.move_vec = Vector2.ZERO
	_joystick.cancel()
	_joystick.enabled = false

func _unfreeze() -> void:
	if gone:
		return
	_scribe.frozen = false
	_joystick.enabled = true

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and _action_button.visible:
		_on_action()

func _on_action() -> void:
	if _near.is_empty() or _dialogue.active or _choice.active or gone:
		return
	match String(_near["kind"]):
		"talk":
			_talk(String(_near["cfg"]["id"]))
		"look":
			say([{"speaker": _near["cfg"]["name"], "text": _near["cfg"]["note"]}])
		"machine":
			_use_machine()

func _talk(id: String) -> void:
	var f: Dictionary = _family[id]
	var cfg: Dictionary = f["cfg"]
	_face_each_other(f["node"], not cfg.get("sit", false))
	if id in _talked:
		say(cfg["again"])
		return
	say(cfg["talk"], func():
		ask(String(cfg["question"]), cfg["options"], func(i: int):
			var lines: Array = cfg["replies"][i] + cfg["after"]
			say(lines, func():
				_talked.append(id)
				_update_title())))

func _face_each_other(person: Node3D, turn_person: bool = true) -> void:
	var d := _scribe.position - person.position
	if turn_person:
		person.rotation.y = atan2(-d.z, d.x)
	var vis: Node3D = _scribe.get_child(0)
	vis.rotation.y = atan2(d.z, -d.x)

func _update_title() -> void:
	var left := _family.size() - _talked.size()
	if left == 0:
		_title_label.text = "Home, 2060. Everyone knows. The garage is ready."
	else:
		_title_label.text = "Home, 2060. Family to talk to: %d" % left

# ---------- the time machine ----------

func _use_machine() -> void:
	if _talked.is_empty():
		var m: Dictionary = _data["machine"]
		say(m["nobody"], func():
			ask(String(m["nobody_question"]), m["nobody_options"], func(i: int):
				if i == 1:
					_depart()))
		return
	_depart()

func _depart() -> void:
	gone = true
	_freeze()
	var m: Dictionary = _data["machine"]
	# Whoever the scribe talked to comes to the garage door to see them off.
	var spots := [Vector3(8.6, 0, -1.2), Vector3(9.4, 0, -0.4), Vector3(12.6, 0, -0.4), Vector3(13.4, 0, -1.2)]
	var n := 0
	for id in _talked:
		var person: Node3D = _family[id]["node"]
		person.position = spots[n % spots.size()]
		person.rotation.y = atan2(-(-3.2 - person.position.z), 11.0 - person.position.x)
		CharacterFactory.play(person, "Victory")
		n += 1
	_scribe.position = Vector3(11.0, 0, -2.0)
	var lines: Array = m["depart"].duplicate()
	if not _talked.is_empty():
		lines += m["send_off"]
	_spin = 4.0
	_dialogue_cb = _launch
	_dialogue.play(_words(lines))

func _launch() -> void:
	var tw := create_tween()
	tw.tween_property(self, "_spin", 18.0, 1.5)
	tw.parallel().tween_property(_machine_light, "light_energy", 12.0, 1.5)
	tw.tween_property(_fade, "color:a", 1.0, 0.8)
	tw.tween_callback(func():
		departing.emit()
		if auto_change_scene:
			get_tree().change_scene_to_file(CHAPTER_1))

func _animate_machine(delta: float) -> void:
	for i in _rings.size():
		var r := _rings[i]
		if i == 0:
			r.rotate_object_local(Vector3.FORWARD, delta * 0.6 * _spin)
		else:
			r.rotate_object_local(Vector3.UP, delta * 0.9 * _spin * (1 if i % 2 else -1))
	var pulse := 1.6 + sin(_time * 2.4) * 0.5 + _spin * 0.15
	for i in _machine_glow.size():
		_machine_glow[i].emission_energy_multiplier = pulse * (1.0 if i == 0 else 0.35)

# ---------- world ----------

func _build_environment() -> void:
	# The shared look (core/world/look.gd), indoors: no sky, a night-blue backdrop, no fog.
	_env = Look.environment(null, Color(0.03, 0.04, 0.08))
	_env.ambient_light_color = Color(0.62, 0.66, 0.78)
	_env.fog_enabled = false
	_env.glow_hdr_threshold = 1.3
	var we := WorldEnvironment.new()
	we.environment = _env
	add_child(we)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-62, -25, 0)
	key.light_color = Color(1.0, 0.95, 0.88)
	key.light_energy = 0.55
	key.shadow_enabled = true
	key.shadow_opacity = 0.5
	key.directional_shadow_max_distance = 30.0
	add_child(key)
	# Warm lamps in the home, a cool teal one in the garage.
	_lamp(Vector3(-7.0, 2.4, -4.0), Color(1.0, 0.85, 0.7), 1.6, 7.0)
	_lamp(Vector3(-7.0, 2.4, 2.0), Color(1.0, 0.88, 0.72), 1.8, 7.0)
	_lamp(Vector3(1.5, 2.6, -2.0), Color(1.0, 0.82, 0.62), 1.6, 10.0)
	_lamp(Vector3(10.5, 2.6, 0.0), Color(0.6, 0.9, 1.0), 1.4, 10.0)
	_cam = Look.camera()
	add_child(_cam)

func _lamp(pos: Vector3, c: Color, energy: float, reach: float) -> void:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = c
	l.light_energy = energy
	l.omni_range = reach
	add_child(l)

static func _mat(c: Color, rough: float = 0.9, glow: float = 0.0, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = glow
	return m

func _block(parent: Node3D, size: Vector3, pos: Vector3, m: Material, solid: bool = false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)
	if solid:
		_scribe_blockers.append(Rect2(pos.x - size.x / 2.0, pos.z - size.z / 2.0, size.x, size.z))
	return mi

func _mesh(parent: Node3D, mesh: Mesh, pos: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)
	return mi

var _scribe_blockers: Array[Rect2] = []

func _build_house() -> void:
	var root := Node3D.new()
	root.name = "House"
	add_child(root)
	# Night lawn around the house.
	_block(root, Vector3(80, 0.2, 60), Vector3(2, -0.15, 0), _mat(Color(0.06, 0.09, 0.08)))
	# Floors: bedroom rug, kitchen tile, living room wood, garage concrete.
	_floor(root, Rect2(-11, -7, 8, 6), C_RUG, 0.95)
	_floor(root, Rect2(-11, -1, 8, 6), C_TILE, 0.35)
	_floor(root, Rect2(-3, -7, 9, 12), C_WOOD, 0.55)
	_floor(root, Rect2(6, -7, 9, 12), C_CONCRETE, 0.8)
	# A soft round rug in the living room and glowing guide lines on the garage floor.
	var rug := CylinderMesh.new()
	rug.top_radius = 1.9
	rug.bottom_radius = 1.9
	rug.height = 0.02
	rug.radial_segments = 32
	_mesh(root, rug, Vector3(2.4, 0.02, 2.0), _mat(Color(0.72, 0.6, 0.48)))
	for z in [-0.2, 1.6]:
		_block(root, Vector3(7.0, 0.02, 0.06), Vector3(10.8, 0.02, z), _mat(C_TRIM, 0.5, 1.5))
	var wall_m := _mat(C_WALL, 0.85)
	var trim_m := _mat(C_TRIM, 0.4, 1.1)
	for w in WALLS:
		var size := Vector3(w[2] - w[0], w[4], w[3] - w[1])
		var pos := Vector3((w[0] + w[2]) / 2.0, w[4] / 2.0, (w[1] + w[3]) / 2.0)
		_block(root, size, pos, wall_m, true)
		if w[4] < TALL:  # a thin light strip along the top of the low walls
			_block(root, Vector3(size.x + 0.02, 0.05, size.z + 0.02), pos + Vector3(0, w[4] / 2.0, 0), trim_m)
	# Big back windows looking out over the 2060 city at night.
	var city := _city_texture()
	for x in [[-8.6, 3.2], [1.5, 7.0]]:
		var q := QuadMesh.new()
		q.size = Vector2(x[1], 1.5)
		var m := StandardMaterial3D.new()
		m.albedo_texture = city
		m.emission_enabled = true
		m.emission_texture = city
		m.emission_energy_multiplier = 1.2
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mesh(root, q, Vector3(x[0], 1.65, -6.68), m)
		_block(root, Vector3(x[1] + 0.2, 0.08, 0.1), Vector3(x[0], 0.86, -6.64), trim_m)
	# The big garage door on the back wall.
	_block(root, Vector3(4.6, 2.4, 0.08), Vector3(11.0, 1.2, -6.66), _mat(Color(0.42, 0.45, 0.5), 0.5, 0.0, 0.4))
	for i in 5:
		_block(root, Vector3(4.6, 0.03, 0.1), Vector3(11.0, 0.4 + i * 0.45, -6.6), _mat(Color(0.3, 0.32, 0.36)))

func _floor(root: Node3D, r: Rect2, c: Color, rough: float) -> void:
	_block(root, Vector3(r.size.x, 0.1, r.size.y), Vector3(r.get_center().x, -0.05, r.get_center().y), _mat(c, rough))

## A night skyline: dark sky, towers with lit windows, a few sky-lanes of light.
func _city_texture() -> ImageTexture:
	var w := 512
	var h := 128
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	for y in h:
		var t := float(y) / h
		img.fill_rect(Rect2i(0, y, w, 1), Color(0.05, 0.07, 0.18).lerp(Color(0.22, 0.16, 0.32), t))
	var rng := RandomNumberGenerator.new()
	rng.seed = 2060
	var x := 0
	while x < w:
		var bw := rng.randi_range(14, 34)
		var bh := rng.randi_range(30, 110)
		var body := Color(0.06, 0.08, 0.13).lerp(Color(0.1, 0.12, 0.2), rng.randf())
		img.fill_rect(Rect2i(x, h - bh, bw - 2, bh), body)
		for wy in range(h - bh + 4, h - 3, 6):
			for wx in range(x + 3, x + bw - 4, 5):
				if rng.randf() < 0.35:
					var lit := Color(1.0, 0.85, 0.55) if rng.randf() < 0.7 else Color(0.4, 0.95, 0.9)
					img.fill_rect(Rect2i(wx, wy, 2, 3), lit)
		x += bw
	for lane in [22, 34]:
		img.fill_rect(Rect2i(0, lane, w, 1), Color(0.35, 0.9, 0.85))
	return ImageTexture.create_from_image(img)

func _plant(parent: Node3D, pos: Vector3) -> void:
	_mesh(parent, Props.cyl(0.22, 0.16, 0.45, 12), pos + Vector3(0, 0.22, 0), _mat(Color(0.9, 0.9, 0.92), 0.4))
	if Props.nature(parent, "plant", pos + Vector3(0, 0.4, 0), 0.55) == null:
		_mesh(parent, Props.sphere(0.35), pos + Vector3(0, 0.8, 0), _mat(Color(0.3, 0.6, 0.3)))
	_scribe_blockers.append(Rect2(pos.x - 0.25, pos.z - 0.25, 0.5, 0.5))

func _build_furniture() -> void:
	var root := Node3D.new()
	root.name = "Furniture"
	add_child(root)
	var white := _mat(Color(0.93, 0.94, 0.96), 0.5)
	var soft := _mat(Color(0.45, 0.55, 0.68), 1.0)
	var dark := _mat(Color(0.18, 0.2, 0.25), 0.4, 0.0, 0.3)
	var trim := _mat(C_TRIM, 0.4, 1.1)
	var holo := _mat(Color(0.3, 0.95, 0.9, 0.55), 0.2, 2.2)
	holo.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	holo.cull_mode = BaseMaterial3D.CULL_DISABLED
	# Bedroom: bed, desk with a glowing tablet, a plant.
	_block(root, Vector3(1.8, 0.45, 2.4), Vector3(-9.7, 0.22, -5.5), white, true)
	_block(root, Vector3(1.7, 0.18, 1.9), Vector3(-9.7, 0.54, -5.25), soft)
	_block(root, Vector3(1.2, 0.2, 0.5), Vector3(-9.7, 0.6, -6.4), white)
	_block(root, Vector3(1.8, 0.08, 0.8), Vector3(-5.2, 0.76, -6.2), white, true)
	_block(root, Vector3(1.8, 0.04, 0.04), Vector3(-5.2, 0.72, -5.8), trim)
	for x in [-6.0, -4.4]:
		_block(root, Vector3(0.08, 0.72, 0.7), Vector3(x, 0.36, -6.2), dark)
	var screen := _block(root, Vector3(0.9, 0.55, 0.02), Vector3(-5.2, 1.25, -6.25), holo)
	screen.rotation.x = -0.15
	_plant(root, Vector3(-3.7, 0, -6.3))
	# Kitchen: counter along the wall, an island, a fridge.
	_block(root, Vector3(0.8, 0.95, 4.6), Vector3(-10.3, 0.47, 2.2), white, true)
	_block(root, Vector3(0.82, 0.04, 4.62), Vector3(-10.3, 0.96, 2.2), dark)
	_block(root, Vector3(0.9, 2.1, 1.0), Vector3(-10.25, 1.05, -0.2), _mat(Color(0.75, 0.78, 0.82), 0.3, 0.0, 0.5), true)
	_block(root, Vector3(2.6, 0.92, 1.0), Vector3(-6.5, 0.46, 2.4), white, true)
	_block(root, Vector3(2.7, 0.05, 1.1), Vector3(-6.5, 0.94, 2.4), dark)
	_block(root, Vector3(2.6, 0.04, 0.04), Vector3(-6.5, 0.1, 2.92), trim)
	for i in 3:  # bowls of fruit and plates on the island
		_mesh(root, Props.sphere(0.12), Vector3(-7.2 + i * 0.7, 1.05, 2.4), _mat([Color(0.85, 0.25, 0.2), Color(0.95, 0.75, 0.2), Color(0.4, 0.7, 0.3)][i]))
	_plant(root, Vector3(-3.6, 0, 4.2))
	# Living room: sofa, low table, Grandma's armchair and shelf, a holo screen.
	_block(root, Vector3(3.2, 0.45, 1.0), Vector3(1.6, 0.25, -5.9), soft, true)
	_block(root, Vector3(3.2, 0.6, 0.3), Vector3(1.6, 0.6, -6.35), soft)
	for x in [0.0, 3.2]:
		_block(root, Vector3(0.3, 0.6, 1.0), Vector3(x, 0.4, -5.9), soft)
	_block(root, Vector3(1.6, 0.35, 0.8), Vector3(1.6, 0.18, -4.0), white, true)
	_block(root, Vector3(1.0, 0.45, 1.0), Vector3(-1.9, 0.25, -3.0), _mat(Color(0.65, 0.42, 0.38)), true)
	_block(root, Vector3(0.25, 0.75, 1.0), Vector3(-2.35, 0.55, -3.0), _mat(Color(0.6, 0.38, 0.34)))
	_block(root, Vector3(1.6, 1.8, 0.4), Vector3(-0.2, 0.9, -6.45), _mat(Color(0.55, 0.4, 0.3)), true)
	for i in 3:
		_block(root, Vector3(1.5, 0.04, 0.38), Vector3(-0.2, 0.5 + i * 0.5, -6.25), dark)
	for i in 4:  # photo frames on the shelf, and one empty spot
		_block(root, Vector3(0.22, 0.28, 0.04), Vector3(-0.75 + i * 0.3 + (0.4 if i == 3 else 0.0), 0.68 + (i % 2) * 0.5, -6.2), _mat(Color(0.9, 0.85, 0.7), 0.6, 0.3))
	_plant(root, Vector3(5.3, 0, -6.2))
	_plant(root, Vector3(-2.4, 0, 4.2))
	# Garage: workbench, shelves, a hover bike.
	_block(root, Vector3(0.8, 0.9, 3.0), Vector3(14.2, 0.45, 2.6), _mat(Color(0.4, 0.33, 0.27)), true)
	_block(root, Vector3(0.82, 0.04, 3.02), Vector3(14.2, 0.92, 2.6), trim)
	_block(root, Vector3(0.5, 2.0, 2.0), Vector3(14.4, 1.0, -1.2), dark, true)
	for i in 4:
		_block(root, Vector3(0.45, 0.25, 0.4), Vector3(14.35, 0.4 + i * 0.5, -1.6 + (i % 2) * 0.8), _mat(Color(0.8, 0.55, 0.2)))
	var bike := Node3D.new()
	bike.position = Vector3(8.6, 0.55, 3.6)
	root.add_child(bike)
	var body := _mesh(bike, CapsuleMesh.new(), Vector3.ZERO, _mat(Color(0.85, 0.3, 0.25), 0.3, 0.0, 0.5))
	body.rotation.z = PI / 2.0
	body.scale = Vector3(0.45, 1.0, 0.45)
	_block(bike, Vector3(1.6, 0.05, 0.35), Vector3(0, -0.3, 0), trim)
	_scribe_blockers.append(Rect2(7.6, 3.3, 2.0, 0.6))

func _build_machine() -> void:
	var m: Dictionary = _data["machine"]
	var root := Node3D.new()
	root.name = "TimeMachine"
	root.position = Vector3(float(m["x"]), 0, float(m["z"]))
	add_child(root)
	var metal := _mat(Color(0.55, 0.58, 0.64), 0.35, 0.0, 0.7)
	var dark := _mat(Color(0.16, 0.18, 0.22), 0.4, 0.0, 0.5)
	# Platform with a glowing ring.
	_mesh(root, Props.cyl(1.9, 2.05, 0.3, 32), Vector3(0, 0.15, 0), dark)
	var ring_glow := _mat(C_TRIM, 0.3, 2.0)
	_machine_glow.append(ring_glow)
	var floor_ring := TorusMesh.new()
	floor_ring.inner_radius = 1.55
	floor_ring.outer_radius = 1.7
	floor_ring.rings = 40
	_mesh(root, floor_ring, Vector3(0, 0.31, 0), ring_glow)
	# Standing gate rings that spin, faster when it starts.
	var gate := Node3D.new()
	gate.position = Vector3(0, 1.75, 0)
	root.add_child(gate)
	for i in 3:
		var holder := Node3D.new()
		gate.add_child(holder)
		var t := TorusMesh.new()
		t.inner_radius = 1.3 - i * 0.18
		t.outer_radius = 1.42 - i * 0.18
		t.rings = 40
		var mi := _mesh(holder, t, Vector3.ZERO, metal if i == 0 else ring_glow)
		mi.rotation.x = PI / 2.0
		if i > 0:
			holder.rotation.x = 0.5 * i
		_rings.append(holder)
	# The shimmer inside the gate.
	var core := _mat(Color(0.35, 0.8, 0.95, 0.22), 0.1, 0.6)
	core.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	core.cull_mode = BaseMaterial3D.CULL_DISABLED
	_machine_glow.append(core)
	var disk := CylinderMesh.new()
	disk.top_radius = 1.0
	disk.bottom_radius = 1.0
	disk.height = 0.02
	disk.radial_segments = 32
	var d := _mesh(gate, disk, Vector3.ZERO, core)
	d.rotation.x = PI / 2.0
	# Side pillars and a control console with a holo display.
	for s in [-1.0, 1.0]:
		_mesh(root, Props.cyl(0.14, 0.2, 2.2, 10), Vector3(1.7 * s, 1.1, 0), metal)
		_mesh(root, Props.sphere(0.16), Vector3(1.7 * s, 2.3, 0), ring_glow)
	_block(root, Vector3(0.9, 0.95, 0.6), Vector3(-2.7, 0.47, 0.6), dark)
	var panel := _block(root, Vector3(0.8, 0.04, 0.5), Vector3(-2.7, 1.0, 0.6), _mat(C_TRIM, 0.3, 1.6))
	panel.rotation.x = 0.4
	_machine_light = OmniLight3D.new()
	_machine_light.position = Vector3(0, 1.8, 0.8)
	_machine_light.light_color = Color(0.45, 0.95, 1.0)
	_machine_light.light_energy = 2.0
	_machine_light.omni_range = 6.0
	root.add_child(_machine_light)
	_scribe_blockers.append(Rect2(root.position.x - 2.0, root.position.z - 1.0, 4.0, 1.4))
	_scribe_blockers.append(Rect2(root.position.x - 3.15, root.position.z + 0.3, 0.9, 0.6))
	_targets.append({"kind": "machine", "pos": root.position + Vector3(0, 0, 1.2), "range": MACHINE_RANGE,
		"label": "Step into the time machine", "cfg": m})

func _build_family() -> void:
	for f in _data["family"]:
		var pos := Vector3(float(f["x"]), 0, float(f["z"]))
		var node := CharacterFactory.make(String(f["model"]), self, pos)
		node.rotation.y = deg_to_rad(float(f.get("face", 0)))
		if f.get("sit", false):
			_sit(node)
		_family[String(f["id"])] = {"cfg": f, "node": node}
		_targets.append({"kind": "talk", "pos": pos, "range": TALK_RANGE, "label": "Talk to %s" % f["name"], "cfg": f})
		_scribe_blockers.append(Rect2(pos.x - 0.2, pos.z - 0.2, 0.4, 0.4))
	# Biscuit the dog, curled up next to Sam.
	var biscuit := Props.creature(self, "dog", Vector3(3.6, 0, 3.0), 0.8)
	biscuit.rotation.y = 2.4

## Settle someone into their chair: play the sit-down animation and hold its last frame.
func _sit(person: Node3D) -> void:
	var anim := CharacterFactory.animator(person)
	if anim == null or not anim.has_animation("SitDown"):
		return
	anim.play("SitDown")
	anim.seek(anim.get_animation("SitDown").length, true)
	anim.pause()

func _build_looks() -> void:
	for l in _data["looks"]:
		_targets.append({"kind": "look", "pos": Vector3(float(l["x"]), 0, float(l["z"])), "range": LOOK_RANGE,
			"label": "Look: %s" % l["name"], "cfg": l})

func _build_scribe() -> void:
	_scribe = Scribe.new()
	_scribe.female = GameState.scribe_gender == "female"
	_scribe.position = Vector3(-8.0, 0, -3.6)
	_scribe.min_x = HOUSE.position.x
	_scribe.max_x = HOUSE.end.x
	_scribe.min_z = HOUSE.position.y
	_scribe.max_z = HOUSE.end.y
	_scribe.blockers = _scribe_blockers
	add_child(_scribe)

# ---------- HUD ----------

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_title_label = Label.new()
	_title_label.position = Vector2(30, 20)
	_title_label.theme_type_variation = &"HeaderLabel"
	layer.add_child(_title_label)
	_update_title()
	_joystick = Joystick.new()
	_joystick.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_joystick)
	var hint := Label.new()
	_hint = hint
	hint.text = "Drag on the left side to walk"
	hint.position = Vector2(40, 640)
	hint.add_theme_font_size_override("font_size", 26)
	hint.add_theme_color_override("font_outline_color", Color.BLACK)
	hint.add_theme_constant_override("outline_size", 6)
	layer.add_child(hint)
	_action_button = Button.new()
	_action_button.custom_minimum_size = Vector2(460, 120)
	_action_button.position = Vector2(780, 520)
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
	var fade_layer := CanvasLayer.new()
	fade_layer.layer = 20
	add_child(fade_layer)
	_fade = ColorRect.new()
	_fade.color = Color(0.85, 1.0, 1.0, 0.0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_layer.add_child(_fade)

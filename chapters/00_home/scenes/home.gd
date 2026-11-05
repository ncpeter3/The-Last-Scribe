extends Node3D
## Opening scene and tutorial: the scribe's home in the year 2060, the evening they leave.
## A big top-down 3D house in the game's low-poly style (built by home_world.gd). It opens with a
## "How to play" dialogue, then two tasks shown top-left by the task tracker: pack the satchel
## (three items to pick up around the house) and say goodbye to Mom, Dad, Sam and Lily (each talk asks
## the scribe a question). The time machine in the garage only works once both are done; then it
## starts the next chapter not yet finished (Chapter 1 the first time).
## Bumping into family makes them say something; bumping Biscuit makes him hop away.
## All text lives in data/home.json. A dialogue line may have "pose" (talk, wave, cheer, hug).

signal departing

const DialogueBox := preload("res://core/ui/dialogue_box.gd")
const ChoicePanel := preload("res://core/ui/choice_panel.gd")
const Scribe := preload("res://core/player/scribe.gd")
const Joystick := preload("res://core/ui/joystick.gd")
const HomeWorld := preload("res://chapters/00_home/scenes/home_world.gd")
const DATA := "res://chapters/00_home/data/home.json"
const TALK_RANGE := 1.9
const LOOK_RANGE := 1.5
const MACHINE_RANGE := 2.6
const ITEM_RANGE := 1.4
const LOOKS := {"mom": LowPolyPerson.MOM, "dad": LowPolyPerson.DAD, "sam": LowPolyPerson.SAM, "lily": LowPolyPerson.LILY}
const START := Vector3(-14.4, 0, -8.8)
## The camera follows the scribe but stays over the house.
const CAM_MIN := Vector2(-16.4, -10.6)
const CAM_MAX := Vector2(16.8, 2.6)

var _data: Dictionary
var _world: Node3D
var _scribe: Node3D
var _cam: Camera3D
var _dialogue: CanvasLayer
var _choice: CanvasLayer
var _joystick: Control
var _action_button: Button
var _title_label: Label
var _tasks: TaskTracker
var _seen: Array = []  # ids of things looked at (the "explore" side quest)
var _bumper: Bumper
var _fade: ColorRect
var _hint: Label
var _family: Dictionary = {}  # id -> {cfg, node, marker, tag}
var _biscuit: LowPolyDog
var _talked: Array = []  # ids of family members talked to (any order)
var _packed: Array = []  # ids of satchel items picked up
var _items: Dictionary = {}  # id -> sparkle node
var _pet_target: Dictionary
var _targets: Array = []  # {kind, pos, range, label, cfg}
var _near: Dictionary = {}
var _talking_to := ""  # id of the family member in the current conversation
var _dialogue_cb := Callable()
var _choice_cb := Callable()
var _time := 0.0
var _moved := false
var gone := false  # set once the time machine has been started
var auto_change_scene := true  # the playtest turns this off

func _ready() -> void:
	_data = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	_build_environment()
	_world = HomeWorld.new()
	add_child(_world)
	_build_family()
	_build_looks()
	_build_scribe()
	_build_hud()
	_build_bumper()
	_dialogue = DialogueBox.new()
	add_child(_dialogue)
	_dialogue.finished.connect(_on_dialogue_finished)
	_dialogue.line_shown.connect(_on_line)
	_choice = ChoicePanel.new()
	add_child(_choice)
	_choice.chosen.connect(_on_choice)
	_cam.position = _cam_target()
	say(_data["tutorial"] + _data["intro"])

# ---------- camera ----------

## Where the camera wants to be: over the scribe, or closer in over a conversation.
func _cam_target() -> Vector3:
	var focus := _scribe.position
	var offset := Look.CAM_OFFSET
	if _talking_to != "" and (_dialogue.active or _choice.active):
		focus = (_scribe.position + (_family[_talking_to]["node"] as Node3D).position) / 2.0
		offset *= 0.72
	focus.x = clampf(focus.x, CAM_MIN.x, CAM_MAX.x)
	focus.z = clampf(focus.z, CAM_MIN.y, CAM_MAX.y)
	return focus + offset

func _process(delta: float) -> void:
	_time += delta
	_cam.position = _cam.position.lerp(_cam_target(), minf(1.0, delta * 3.5))
	_scribe.move_vec = _joystick.value
	if _scribe.position.distance_to(START) > 0.6:
		_moved = true
	_animate_markers()
	_update_biscuit()
	var busy: bool = _dialogue.active or _choice.active or gone
	_hint.visible = not busy and not _moved
	_tasks.visible = not gone
	_bumper.enabled = not busy
	if busy:
		_action_button.hide()
		for id in _family:
			(_family[id]["tag"] as Label3D).hide()
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
	for id in _family:
		var tag: Label3D = _family[id]["tag"]
		tag.visible = not _near.is_empty() and _near["kind"] == "talk" and String(_near["cfg"]["id"]) == id

func _animate_markers() -> void:
	for id in _family:
		var m: Node3D = _family[id]["marker"]
		if m.visible:
			m.position.y = float(m.get_meta("y")) + sin(_time * 2.5 + m.get_meta("y")) * 0.08
			m.rotation.y += 0.03
	for id in _items:
		var n: Node3D = _items[id]
		n.rotation.y += 0.04
		n.position.y = float(n.get_meta("y")) + sin(_time * 3.0) * 0.04

func _update_biscuit() -> void:
	if gone:
		return
	_pet_target["pos"] = _biscuit.position
	var d := _biscuit.position.distance_to(_scribe.position)
	_biscuit.pose = "sit" if d < 2.6 else "lie"
	_biscuit.wag = 1.0 if d < 2.6 else 0.25
	if d < 4.0:
		var to := _scribe.position - _biscuit.position
		_biscuit.rotation.y = lerp_angle(_biscuit.rotation.y, atan2(-to.z, to.x), 0.05)

# ---------- talking and looking ----------

## Fill in words that depend on the chosen scribe ({child}: boy/girl, {big}: big brother/sister).
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

## Each line: the speaker moves (talks, hugs, cheers...) and everyone else listens.
func _on_line(line: Dictionary) -> void:
	var speaker := String(line.get("speaker", ""))
	var pose := String(line.get("pose", "talk"))
	for id in _family:
		var p: LowPolyPerson = _family[id]["node"]
		if String(_family[id]["cfg"]["name"]) == speaker:
			p.gesture = pose
		elif gone:
			p.gesture = "wave"
		elif id == _talking_to:
			p.gesture = ""
	var me: LowPolyPerson = _scribe._lp
	if speaker == "You":
		me.gesture = pose
	elif pose == "hug" and not gone:
		me.gesture = "hug"
	elif not gone:
		me.gesture = ""

func _on_dialogue_finished() -> void:
	_unfreeze()
	var cb := _dialogue_cb
	_dialogue_cb = Callable()
	if not gone:
		_scribe._lp.gesture = ""
		if _talking_to != "" and not _choice.active:
			(_family[_talking_to]["node"] as LowPolyPerson).gesture = ""
	if cb.is_valid():
		cb.call()
	elif not gone:
		_talking_to = ""

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
			if not String(_near["cfg"]["id"]) in _seen:
				_seen.append(String(_near["cfg"]["id"]))
				_update_title()
			say([{"speaker": _near["cfg"]["name"], "text": _near["cfg"]["note"]}])
		"item":
			_pick_up(_near)
		"pet":
			_biscuit.pose = "stand"
			_biscuit.wag = 1.0
			say([{"speaker": "Biscuit", "text": String(_data["biscuit_bumps"][randi() % 2])},
				{"speaker": "You", "text": "Good boy, Biscuit. Look after everyone while I'm gone, okay?"}])
		"machine":
			_use_machine()

func _talk(id: String) -> void:
	var f: Dictionary = _family[id]
	var cfg: Dictionary = f["cfg"]
	var person: LowPolyPerson = f["node"]
	_talking_to = id
	# Sam and Lily hop up from the floor to talk.
	if cfg.get("sit_floor", false):
		person.sitting = false
	_face_each_other(person, not person.sitting)
	if id in _talked:
		say(cfg["again"], func(): _talking_to = "")
		return
	say(cfg["talk"], func():
		ask(String(cfg["question"]), cfg["options"], func(i: int):
			var lines: Array = cfg["replies"][i] + cfg["after"]
			say(lines, func():
				_talked.append(id)
				(f["marker"] as Node3D).hide()
				_talking_to = ""
				_update_title())))

func _pick_up(t: Dictionary) -> void:
	var cfg: Dictionary = t["cfg"]
	var id := String(cfg["id"])
	_targets.erase(t)
	_near = {}
	_packed.append(id)
	(_items[id] as Node3D).queue_free()
	_items.erase(id)
	var lines: Array = [{"speaker": "You", "text": cfg["text"]}]
	if _packed.size() == (_data["items"] as Array).size():
		lines += _data["packed"]
	say(lines)
	_update_title()

func _face_each_other(person: Node3D, turn_person: bool = true) -> void:
	var d := _scribe.position - person.position
	if turn_person:
		person.rotation.y = atan2(-d.z, d.x)
	(_scribe._visual as Node3D).rotation.y = atan2(d.z, -d.x)

## The task card: packing and goodbyes side by side (do them in any order), then the machine.
## Exploring the house is a side quest.
func _update_title() -> void:
	var t: Dictionary = _data["tasks"]
	var list := []
	if ready_to_leave():
		list.append({"title": String(t["go"]), "done": 1 if gone else 0, "total": 1})
	else:
		var items: Array = _data["items"]
		var left_items := []
		for it in items:
			if not String(it["id"]) in _packed:
				left_items.append(String(it["name"]))
		list.append({"title": String(t["pack"]), "done": _packed.size(), "total": items.size(),
			"hint": ("Still need: " + _list(left_items)) if not left_items.is_empty() else "All packed!"})
		var left_people := []
		for f in _data["family"]:
			if not String(f["id"]) in _talked:
				left_people.append(String(f["name"]))
		list.append({"title": String(t["talk"]), "done": _talked.size(), "total": _family.size(),
			"hint": ("Still to see: " + _list(left_people)) if not left_people.is_empty() else "Everyone's said goodbye."})
	var looks: Array = _data["looks"]
	list.append({"title": String(t["explore"]), "done": _seen.size(), "total": looks.size(), "side": true,
		"hint": String(t["explore_hint"])})
	_tasks.set_tasks(list)

func ready_to_leave() -> bool:
	return _packed.size() == (_data["items"] as Array).size() and _talked.size() == _family.size()

## "a, b and c"
func _list(names: Array) -> String:
	if names.size() <= 1:
		return "".join(names)
	return ", ".join(names.slice(0, names.size() - 1)) + " and " + String(names[-1])

# ---------- the time machine ----------

func _use_machine() -> void:
	if ready_to_leave():
		_depart()
		return
	# Not yet: say exactly what's still missing. There's no way around it.
	var m: Dictionary = _data["machine"]
	var lines: Array = m["not_ready"].duplicate()
	var missing_items := []
	for it in _data["items"]:
		if not String(it["id"]) in _packed:
			missing_items.append(String(it["name"]).to_lower())
	var missing_people := []
	for f in _data["family"]:
		if not String(f["id"]) in _talked:
			missing_people.append(String(f["name"]))
	if not missing_items.is_empty():
		var l: Dictionary = (m["need_pack"] as Dictionary).duplicate()
		l["text"] = String(l["text"]).replace("{items}", _list(missing_items))
		lines.append(l)
	if not missing_people.is_empty():
		var l: Dictionary = (m["need_talk" if not missing_items.is_empty() else "need_talk_only"] as Dictionary).duplicate()
		l["text"] = String(l["text"]).replace("{people}", _list(missing_people))
		lines.append(l)
	say(lines)

func _depart() -> void:
	gone = true
	_freeze()
	_update_title()
	var m: Dictionary = _data["machine"]
	# A quick blink while whoever the scribe talked to gathers at the garage door to see them off.
	var tw := create_tween()
	tw.tween_property(_fade, "color", Color(0, 0, 0, 1), 0.35)
	tw.tween_callback(func():
		var spots := [Vector3(13.2, 0, -6.2), Vector3(14.2, 0, -5.5), Vector3(16.8, 0, -5.5), Vector3(17.8, 0, -6.2)]
		var n := 0
		for id in _talked:
			var person: LowPolyPerson = _family[id]["node"]
			person.sitting = false
			person.position = spots[n % spots.size()]
			person.rotation.y = atan2(-(HomeWorld.MACHINE.z - person.position.z), HomeWorld.MACHINE.x - person.position.x)
			person.gesture = "wave"
			(_family[id]["marker"] as Node3D).hide()
			n += 1
		_biscuit.position = Vector3(15.5, 0, -5.2)
		_biscuit.rotation.y = PI / 2.0
		_biscuit.pose = "sit"
		_biscuit.wag = 1.0
		_scribe.position = HomeWorld.MACHINE + Vector3(0, 0, 2.1)
		(_scribe._visual as Node3D).rotation.y = PI / 2.0
		_world.spin = 0.15
		_cam.position = _cam_target())
	tw.tween_property(_fade, "color", Color(0, 0, 0, 0), 0.35)
	tw.tween_callback(func():
		var lines: Array = m["depart"].duplicate()
		if not _talked.is_empty():
			for l in m["send_off"]:
				for id in _talked:
					if String(_family[id]["cfg"]["name"]) == String(l["speaker"]):
						lines.append(l)
		_dialogue_cb = _launch
		_dialogue.play(_words(lines)))

func _launch() -> void:
	# Step up onto the platform, turn and wave, then the gate spins up and the light takes the scribe.
	var me: LowPolyPerson = _scribe._lp
	me.walk_speed = 1.0
	var tw := create_tween()
	tw.tween_property(_scribe, "position", HomeWorld.MACHINE + Vector3(0, 0.28, 0.1), 1.1)
	tw.tween_callback(func():
		me.walk_speed = 0.0
		me.rotation.y = -PI / 2.0
		me.gesture = "wave")
	tw.tween_property(_world, "spin", 1.0, 1.8)
	tw.parallel().tween_property(_fade, "color", Color(0.85, 1.0, 1.0, 0.0), 0.01)
	tw.tween_property(_fade, "color:a", 1.0, 0.7)
	tw.tween_callback(func():
		departing.emit()
		if auto_change_scene:
			get_tree().change_scene_to_file(GameState.next_chapter_scene()))

# ---------- setup ----------

func _build_environment() -> void:
	# The shared look (core/world/look.gd) at dusk: a cool evening light outside, warm lamps inside.
	var env := Look.environment(null, Color(0.08, 0.09, 0.16))
	env.ambient_light_color = Color(0.62, 0.62, 0.82)
	env.ambient_light_energy = 0.6
	env.fog_enabled = true
	env.fog_light_color = Color(0.16, 0.16, 0.3)
	env.fog_density = 0.012
	env.glow_hdr_threshold = 1.1
	env.glow_intensity = 0.7
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-55, -32, 0)
	key.light_color = Color(1.0, 0.86, 0.74)
	key.light_energy = 0.85
	key.shadow_enabled = true
	key.shadow_opacity = 0.6
	key.shadow_blur = 1.4
	key.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	key.directional_shadow_max_distance = 28.0
	add_child(key)
	_cam = Look.camera()
	add_child(_cam)

func _build_family() -> void:
	var font: Font = load("res://shared_assets/fonts/Nunito.ttf") if ResourceLoader.exists("res://shared_assets/fonts/Nunito.ttf") else null
	for f in _data["family"]:
		var pos := Vector3(float(f["x"]), 0, float(f["z"]))
		var person := LowPolyPerson.create(LOOKS.get(String(f.get("look", f["id"])), LowPolyPerson.MOM))
		person.position = pos
		person.rotation.y = deg_to_rad(float(f.get("face", 0)))
		person.gesture = String(f.get("busy", ""))
		if f.get("sit", false):
			person.sitting = true
		if f.get("sit_floor", false):
			person.sitting = true
			person.sit_height = 0.1
		add_child(person)
		# A gold gem floats over everyone you haven't said goodbye to yet.
		var top := 2.3 if not f.get("sit", false) and not f.get("sit_floor", false) else 1.8
		if String(f.get("look", "")) in ["sam", "lily"]:
			top = 1.7
		var g := LowPoly.new()
		g.ball(Vector3.ZERO, 0.13, LowPoly.glow(LowPoly.GOLD, 0.55), 0, Vector3(0.7, 1.3, 0.7))
		var marker := g.instance(false)
		marker.position = pos + Vector3(0, top, 0)
		marker.set_meta("y", top)
		add_child(marker)
		var tag := Label3D.new()
		tag.text = String(f["name"])
		tag.position = pos + Vector3(0, top + 0.05, 0)
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.no_depth_test = true
		tag.pixel_size = 0.006
		tag.font_size = 48
		tag.outline_size = 14
		tag.modulate = Color(1.0, 0.93, 0.72)
		if font:
			tag.font = font
		tag.hide()
		add_child(tag)
		_family[String(f["id"])] = {"cfg": f, "node": person, "marker": marker, "tag": tag}
		_targets.append({"kind": "talk", "pos": pos, "range": TALK_RANGE, "label": "Talk to %s" % f["name"], "cfg": f})
		_world.blockers.append(Rect2(pos.x - 0.25, pos.z - 0.25, 0.5, 0.5))
	# Biscuit, asleep in his bed in the family room until you come close.
	_biscuit = LowPolyDog.new()
	_biscuit.position = Vector3(2.4, 0.1, 4.6)
	_biscuit.rotation.y = -2.2
	add_child(_biscuit)

func _build_looks() -> void:
	for l in _data["looks"]:
		var pos := Vector3(float(l["x"]), 0, float(l["z"]))
		_targets.append({"kind": "look", "pos": pos, "range": LOOK_RANGE, "label": "Look: %s" % l["name"], "cfg": l})
	# Satchel items: each sits where it was left, with a slowly turning sparkle over it.
	for it in _data["items"]:
		var pos := Vector3(float(it["x"]), 0, float(it["z"]))
		var y := float(it.get("y", 0.5)) + 0.35
		var g := LowPoly.new()
		g.ball(Vector3.ZERO, 0.09, LowPoly.glow(LowPoly.TEAL, 0.9), 0, Vector3(0.8, 1.4, 0.8))
		for k in 4:
			var a := TAU * k / 4.0
			g.ball(Vector3(cos(a) * 0.22, 0.0, sin(a) * 0.22), 0.035, LowPoly.glow(LowPoly.SUN, 1.0), 0)
		var n := g.instance(false)
		n.position = pos + Vector3(0, y, 0)
		n.set_meta("y", y)
		add_child(n)
		_items[String(it["id"])] = n
		_targets.append({"kind": "item", "pos": pos, "range": ITEM_RANGE, "label": "Pick up: %s" % it["name"], "cfg": it})
	_pet_target = {"kind": "pet", "pos": _biscuit.position, "range": LOOK_RANGE, "label": "Pat Biscuit", "cfg": {}}
	_targets.append(_pet_target)
	var m: Dictionary = _data["machine"]
	_targets.append({"kind": "machine", "pos": Vector3(float(m["x"]), 0, float(m["z"]) + 1.2), "range": MACHINE_RANGE,
		"label": "Step into the time machine", "cfg": m})

func _build_scribe() -> void:
	_scribe = Scribe.new()
	_scribe.female = GameState.scribe_gender == "female"
	_scribe.low_poly = true
	_scribe.position = START
	var h: Rect2 = HomeWorld.HOUSE
	_scribe.min_x = h.position.x + 0.1
	_scribe.max_x = h.end.x - 0.1
	_scribe.min_z = h.position.y + 0.1
	_scribe.max_z = h.end.y - 0.1
	_scribe.blockers = _world.blockers
	add_child(_scribe)
	(_scribe._visual as Node3D).rotation.y = -PI / 2.0  # face the camera to start

# ---------- HUD ----------

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_title_label = Label.new()
	_title_label.text = "Home, 2060"
	_title_label.position = Vector2(30, 16)
	_title_label.theme_type_variation = &"HeaderLabel"
	layer.add_child(_title_label)
	_tasks = TaskTracker.new()
	add_child(_tasks)
	_update_title()
	_joystick = Joystick.new()
	_joystick.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_joystick)
	_hint = Label.new()
	_hint.text = "Drag on the left side of the screen to walk"
	_hint.position = Vector2(40, 640)
	_hint.add_theme_font_size_override("font_size", 26)
	layer.add_child(_hint)
	_action_button = Button.new()
	_action_button.custom_minimum_size = Vector2(460, 120)
	_action_button.position = Vector2(780, 520)
	_action_button.add_theme_font_size_override("font_size", 32)
	var gold := StyleBoxFlat.new()
	gold.bg_color = Color(0.55, 0.42, 0.12, 0.92)
	gold.set_corner_radius_all(16)
	gold.border_color = Color(1.0, 0.85, 0.5, 0.6)
	gold.set_border_width_all(2)
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
	_fade.color = Color(0, 0, 0, 0.0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_layer.add_child(_fade)

func _build_bumper() -> void:
	_bumper = Bumper.new()
	_bumper.scribe = _scribe
	add_child(_bumper)
	for id in _family:
		_bumper.add_person(_family[id]["node"], _family[id]["cfg"].get("bumps", []))
	_bumper.add_animal(_biscuit)

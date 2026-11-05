extends Node
## Automated playthrough of the opening home scene (the tutorial level): checks the "How to play"
## dialogue opens it, walls stop the scribe, the time machine refuses to leave until the satchel is
## packed and everyone has been talked to, every pick-up, family talk (with its question), look and
## bump works, and the time machine sends the scribe off. Run headless:  godot --headless res://tools/test/home_playtest.tscn
## With a display, add  -- --shots=<dir>  to save screenshots. Exits 0 on success, 1 on failure.

const HOME := preload("res://chapters/00_home/scenes/home.tscn")
const DialogueBox := preload("res://core/ui/dialogue_box.gd")

var h: Node
var shots := ""
var _n := 0
var _departed := false
var _bumped: Array = []

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			shots = a.substr(8)
	DialogueBox.test_fast = true
	GameState.unlocked_verses = []
	GameState.scribe_gender = "female"
	h = HOME.instantiate()
	h.auto_change_scene = false
	add_child(h)
	h.departing.connect(func(): _departed = true)
	h._bumper.bumped.connect(func(n: Node3D): _bumped.append(n))
	_run()

func _fail(msg: String) -> bool:
	push_error("HOME PLAYTEST FAILED: " + msg)
	print("HOME PLAYTEST FAILED: " + msg)
	get_tree().quit(1)
	return false

func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _shot(label: String) -> void:
	if shots == "":
		return
	await _frames(20)
	_n += 1
	get_viewport().get_texture().get_image().save_png("%s/home_%02d_%s.png" % [shots, _n, label])

func _tap_through() -> void:
	var guard := 0
	while h._dialogue.active:
		var e := InputEventKey.new()
		e.keycode = KEY_SPACE
		e.pressed = true
		Input.parse_input_event(e)
		await _frames(2)
		guard += 1
		if guard > 200:
			_fail("dialogue never ended")
			return

func _put(pos: Vector3) -> void:
	h._scribe.position = pos
	await _frames(3)

func _act(expect: String) -> bool:
	await _frames(2)
	if not h._action_button.visible or h._action_button.text != expect:
		_fail("expected action '%s', got '%s' (visible %s)" % [expect, h._action_button.text, h._action_button.visible])
		return false
	h._on_action()
	await _frames(2)
	return true

## Stand somewhere free near `pos` from which the action button reads `expect`, then press it.
func _use(pos: Vector3, expect: String) -> bool:
	for r in [0.75, 1.0, 1.25, 0.5]:
		for k in 16:
			var a := TAU * k / 16.0 + PI / 2.0
			var p: Vector3 = pos + Vector3(cos(a), 0, sin(a)) * r
			if h._scribe._blocked(p.x, p.z):
				continue
			await _put(p)
			await _frames(2)
			if h._action_button.visible and h._action_button.text == expect:
				h._on_action()
				await _frames(2)
				return true
	_fail("could not find a spot near %s to '%s'" % [pos, expect])
	return false

func _run() -> void:
	await _frames(5)
	if not h._dialogue.active:
		return _fail("tutorial did not play")
	if String(h._dialogue._lines[0]["speaker"]) != "How to play":
		return _fail("level did not open with the controls tutorial")
	await _shot("tutorial")
	await _tap_through()
	if h._tasks.get("visible") == false:
		return _fail("task tracker hidden")
	# Walls: walking right from your bedroom into the bathroom wall must stop before it.
	await _put(Vector3(-12.5, 0, -8.0))
	Input.action_press("move_right")
	await get_tree().create_timer(1.0).timeout
	Input.action_release("move_right")
	if h._scribe.position.x < -12.0:
		return _fail("scribe did not walk (x %.2f)" % h._scribe.position.x)
	if h._scribe.position.x > -11.15:
		return _fail("walked through the bedroom wall (x %.2f)" % h._scribe.position.x)
	# The time machine refuses to leave before packing and goodbyes, and offers no way around it.
	var m: Dictionary = h._data["machine"]
	var mpos := Vector3(float(m["x"]), 0, float(m["z"]) + 2.0)
	await _put(mpos)
	if not await _act("Step into the time machine"):
		return
	var said := ""
	for l in h._dialogue._lines:
		said += String(l["text"]) + " "
	for who in ["Mom", "Dad", "Sam", "Lily", "scroll"]:
		if not who in said:
			return _fail("machine did not say '%s' is still missing: %s" % [who, said])
	await _tap_through()
	if h.gone or h._choice.active:
		return _fail("time machine let the scribe leave (or asked) before they were ready")
	await _shot("garage_not_ready")
	# Pack the satchel.
	for it in h._data["items"]:
		if not await _use(Vector3(float(it["x"]), 0, float(it["z"])), "Pick up: %s" % it["name"]):
			return
		await _tap_through()
	if h._packed.size() != h._data["items"].size():
		return _fail("satchel items not all recorded: %s" % [h._packed])
	# Bump into Mom: she should react.
	var mom: Node3D = h._family["mom"]["node"]
	await _put(mom.position + Vector3(1.8, 0, 0.0))
	await _frames(5)
	Input.action_press("move_left")
	await get_tree().create_timer(0.8).timeout
	Input.action_release("move_left")
	await _shot("bump_mom")
	if not mom in _bumped:
		return _fail("bumping into Mom did nothing")
	# Talk to each family member, alternating answers.
	var i := 0
	for f in h._data["family"]:
		var p := Vector3(float(f["x"]), 0, float(f["z"]))
		if not await _use(p, "Talk to %s" % f["name"]):
			return
		if i == 0:
			await _shot("talk_" + String(f["id"]))
		await _tap_through()
		if not h._choice.active:
			return _fail("%s did not ask a question" % f["id"])
		if i == 2:
			await _shot("question_" + String(f["id"]))
		h._choice._pick((i + 1) % 2)
		await _frames(2)
		await _tap_through()
		if not String(f["id"]) in h._talked:
			return _fail("talk with %s not recorded" % f["id"])
		# Talking again gives a short line.
		if not await _use(p, "Talk to %s" % f["name"]):
			return
		await _tap_through()
		i += 1
	for v in ["Joshua 1:9", "John 8:32"]:
		if not v in GameState.unlocked_verses:
			return _fail("verse %s not recorded" % v)
	for l in h._data["looks"]:
		if not await _use(Vector3(float(l["x"]), 0, float(l["z"])), "Look: %s" % l["name"]):
			return
		await _tap_through()
	if not await _use(h._biscuit.position, "Pat Biscuit"):
		return
	await _tap_through()
	for spot in [["bedroom", Vector3(-14.0, 0, -8.6)], ["kids_room", Vector3(-4.6, 0, -7.4)], ["kitchen", Vector3(-14.0, 0, -0.5)],
			["living_room", Vector3(-4.0, 0, -0.8)], ["family_room", Vector3(5.8, 0, 0.8)], ["garage", Vector3(15.0, 0, -2.0)]]:
		await _put(spot[1])
		await _shot(spot[0])
	# Leave: everyone sees the scribe off, then the scene ends.
	await _put(mpos)
	if not await _act("Step into the time machine"):
		return
	var wait := 0.0
	while not h._dialogue.active and wait < 3.0:
		await get_tree().create_timer(0.1).timeout
		wait += 0.1
	if not h._dialogue.active:
		return _fail("send-off never started")
	await _shot("send_off")
	await _tap_through()
	var t := 0.0
	while not _departed and t < 6.0:
		await get_tree().create_timer(0.1).timeout
		t += 0.1
	if not _departed:
		return _fail("time machine never departed")
	print("HOME PLAYTEST PASSED: packed %d items, talked to %d family members, %d verses recorded" % [h._packed.size(), h._talked.size(), GameState.unlocked_verses.size()])
	get_tree().quit(0)

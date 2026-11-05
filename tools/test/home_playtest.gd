extends Node
## Automated playthrough of the opening home scene: checks walls stop the scribe, the garage asks
## first when nobody has been talked to, every family talk (with its question) works, and the time
## machine sends the scribe off. Run headless:  godot --headless res://tools/test/home_playtest.tscn
## With a display, add  -- --shots=<dir>  to save screenshots. Exits 0 on success, 1 on failure.

const HOME := preload("res://chapters/00_home/scenes/home.tscn")

var h: Node
var shots := ""
var _n := 0
var _departed := false

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			shots = a.substr(8)
	GameState.unlocked_verses = []
	GameState.scribe_gender = "female"
	h = HOME.instantiate()
	h.auto_change_scene = false
	add_child(h)
	h.departing.connect(func(): _departed = true)
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

func _run() -> void:
	await _frames(5)
	if not h._dialogue.active:
		return _fail("intro did not play")
	await _shot("intro")
	await _tap_through()
	# Walls: walking right from the bedroom into the wall must stop before it.
	await _put(Vector3(-5.0, 0, -5.6))
	h._scribe.move_vec = Vector2(1, 0)
	await get_tree().create_timer(1.0).timeout
	h._scribe.move_vec = Vector2.ZERO
	if h._scribe.position.x > -4.15:
		return _fail("walked through the bedroom wall (x %.2f)" % h._scribe.position.x)
	# Garage first, before talking to anyone: it should ask, and "go say goodbye" keeps us home.
	var m: Dictionary = h._data["machine"]
	await _put(Vector3(float(m["x"]), 0, float(m["z"]) + 2.0))
	if not await _act("Step into the time machine"):
		return
	await _tap_through()
	if not h._choice.active:
		return _fail("garage did not ask before leaving with nobody talked to")
	await _shot("garage_asks")
	h._choice._pick(0)
	await _frames(3)
	if h.gone:
		return _fail("left even though the player chose to say goodbye first")
	# Talk to each family member, alternating answers.
	var i := 0
	for f in h._data["family"]:
		var p := Vector3(float(f["x"]), 0, float(f["z"]))
		await _put(p + Vector3(0, 0, 1.0))
		if not await _act("Talk to %s" % f["name"]):
			return
		if i == 0:
			await _shot("talk_" + String(f["id"]))
		await _tap_through()
		if not h._choice.active:
			return _fail("%s did not ask a question" % f["id"])
		if i == 1:
			await _shot("question_" + String(f["id"]))
		h._choice._pick((i + 1) % 2)
		await _frames(2)
		await _tap_through()
		if not String(f["id"]) in h._talked:
			return _fail("talk with %s not recorded" % f["id"])
		# Talking again gives a short line.
		if not await _act("Talk to %s" % f["name"]):
			return
		await _tap_through()
		i += 1
	for v in ["Joshua 1:9", "Isaiah 40:8"]:
		if not v in GameState.unlocked_verses:
			return _fail("verse %s not recorded" % v)
	for l in h._data["looks"]:
		await _put(Vector3(float(l["x"]), 0, float(l["z"]) + 0.9))
		if not await _act("Look: %s" % l["name"]):
			return
		await _tap_through()
	await _put(Vector3(1.2, 0, 1.4))
	await _shot("living_room")
	# Leave: no question this time, the family sees the scribe off, then the scene ends.
	await _put(Vector3(float(m["x"]), 0, float(m["z"]) + 2.0))
	if not await _act("Step into the time machine"):
		return
	if h._choice.active:
		return _fail("garage asked again after talking to family")
	# The family gathers during a short fade, then the send-off lines start.
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
	print("HOME PLAYTEST PASSED: talked to %d family members, %d verses recorded" % [h._talked.size(), GameState.unlocked_verses.size()])
	get_tree().quit(0)

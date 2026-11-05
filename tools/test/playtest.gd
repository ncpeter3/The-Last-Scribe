extends Node
## Automated playthrough of chapter 1: walks to every story beat, plays every challenge to the
## end (including a wrong answer, to check the hint path) and checks the chapter completes.
## Run headless:  godot --headless res://tools/test/playtest.tscn
## With a display, add  -- --shots=<dir>  to save screenshots along the way.
## Exits with code 0 on success, 1 on failure.

const CHAPTER := preload("res://chapters/01_adam_and_eve/scenes/chapter.tscn")

var ch: Node
var shots := ""
var _n := 0

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			shots = a.substr(8)
	GameState.unlocked_verses = []
	GameState.completed_chapters = []
	ch = CHAPTER.instantiate()
	add_child(ch)
	_run()

func _fail(msg: String) -> void:
	push_error("PLAYTEST FAILED: " + msg)
	print("PLAYTEST FAILED: " + msg)
	get_tree().quit(1)

func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _shot(label: String) -> void:
	if shots == "":
		return
	await _frames(20)
	_n += 1
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%02d_%s.png" % [shots, _n, label])

func _tap_through() -> void:
	var guard := 0
	while ch._dialogue.active:
		var e := InputEventKey.new()
		e.keycode = KEY_SPACE
		e.pressed = true
		Input.parse_input_event(e)
		await _frames(2)
		guard += 1
		if guard > 200:
			_fail("dialogue never ended")
			return

## Creatures must be alive: most land animals, fish and birds move within a few seconds, and every
## fish and whale stays inside its water while land animals stay out of it.
func _check_creatures() -> bool:
	var all := ch.find_children("*", "LowPolyAnimal", true, false)
	var start := {}
	for a in all:
		start[a] = (a as Node3D).global_position
	await get_tree().create_timer(4.0).timeout
	var counts := {}
	for a in all:
		var an := a as LowPolyAnimal
		var kind := "swim" if an.mode == "swim" else ("fly" if an.mode == "fly" else ("walk" if an.mode == "wander" else "other"))
		if kind == "other":
			continue
		var c: Array = counts.get(kind, [0, 0])
		c[0] += 1
		if an.global_position.distance_to(start[a]) > 0.2:
			c[1] += 1
		counts[kind] = c
		var p := an.global_position
		if kind == "swim" and not an.water.grow(0.05).has_point(Vector2(p.x, p.z)):
			_fail("%s swam out of its water at %s" % [an.species, p])
			return false
		if kind == "walk" and Props.in_water(p, 0.0):
			_fail("%s walked into water at %s" % [an.species, p])
			return false
	for kind in ["swim", "fly", "walk"]:
		var c: Array = counts.get(kind, [0, 0])
		if c[0] == 0 or c[1] < c[0] / 2:
			_fail("only %d of %d %s creatures moved" % [c[1], c[0], kind])
			return false
	print("Creatures moving: ", counts)
	return true

func _put(pos: Vector3) -> void:
	var s: Node3D = ch._scribe
	s.position = pos
	if ch._challenge:
		ch._challenge._last_pos = pos
		ch._challenge.scribe_speed = 0.0
	await _frames(3)

func _act(expect: String) -> void:
	await _frames(2)
	if not ch._action_button.visible or ch._action_button.text != expect:
		_fail("expected action '%s', got '%s' (visible %s)" % [expect, ch._action_button.text, ch._action_button.visible])
		return
	ch._on_action()
	await _frames(2)

func _run() -> void:
	await _frames(5)
	if not await _check_creatures():
		return
	var beats: Array = ch._beats
	var shot_beats := ["adam", "naming", "eve", "hiding", "gate"]
	for i in beats.size():
		var b: Dictionary = beats[i]
		await _put(Vector3(float(b["x"]), 0, 0))
		if not ch._dialogue.active:
			_fail("beat %s did not start" % b["id"])
			return
		if b["id"] in shot_beats:
			await _shot(b["id"] + "_beat")
		await _tap_through()
		if b.has("challenge"):
			if ch._challenge == null:
				_fail("challenge for %s did not start" % b["id"])
				return
			await _play(String(b["challenge"]["type"]), ch._challenge)
			var t := 0.0
			while ch._challenge != null and t < 5.0:
				await get_tree().create_timer(0.1).timeout
				t += 0.1
			if ch._challenge != null:
				_fail("challenge %s did not finish" % b["challenge"]["type"])
				return
			await _tap_through()
		if ch._beat_index != i + 1:
			_fail("beat index %d after %s" % [ch._beat_index, b["id"]])
			return
	if not "01_adam_and_eve" in GameState.completed_chapters:
		_fail("chapter not marked complete")
		return
	for v in ["Genesis 2:18", "Genesis 2:20", "Genesis 3:10", "Genesis 3:19"]:
		if not v in GameState.unlocked_verses:
			_fail("verse %s was not recorded" % v)
			return
	print("PLAYTEST PASSED: %d beats, %d verses recorded" % [beats.size(), GameState.unlocked_verses.size()])
	get_tree().quit(0)

func _play(kind: String, c: Node) -> void:
	match kind:
		"tend_garden":
			for i in c._plants.size():
				var p: Vector3 = c._plants[i]["pos"]
				if c._jar == 0:
					await _put(Vector3(p.x, 0, -6.0))
					await _act("Fill jar at the river")
				await _put(p + Vector3(0.6, 0, 0.4))
				if i == 2:
					await _shot("tend_garden")
				await _act("Water the plant")
				await _frames(10)
			await _shot("tend_garden_done")
		"name_animals":
			for i in c._animals.size():
				var n: Node3D = c._animals[i]["node"]
				await _put(n.position + Vector3(-1.0, 0, 0.6))
				await _act("Write it in the scroll")
				if not ch._choice.active:
					_fail("no group question")
					return
				if i == 0:
					await _shot("name_animals_question")
					ch._choice._pick((int(c._animals[i]["group"]) + 1) % 3)  # wrong on purpose
					await _frames(2)
					if not ch._dialogue.active:
						_fail("no hint after a wrong group")
						return
					await _tap_through()
					await _act("Write it in the scroll")
				ch._choice._pick(int(c._animals[i]["group"]))
				await _frames(3)
				if i == 4:
					await _shot("name_animals")
		"gather_fruit":
			for i in c._trees.size():
				await _put(c._trees[i]["pos"] + Vector3(0, 0, 1.6 * (1 if c._trees[i]["pos"].z < 0 else -1)))
				if i == 1:
					await _shot("gather_fruit")
				await _act("Gather fruit")
				await _frames(5)
		"find_hiding":
			await _put(Vector3(c.x0 + 6.0, 0, 3.0))
			await _shot("find_hiding")
			await _put(c._spot + Vector3(0, 0, 1.8))
		"scroll_quiz":
			for i in c._qs.size():
				await _frames(2)
				if not ch._choice.active:
					_fail("no quiz question %d" % i)
					return
				if i == 0:
					await _shot("quiz")
					ch._choice._pick((int(c._qs[i]["answer"]) + 1) % 3)
					await _frames(2)
					await _tap_through()
					await _frames(2)
				ch._choice._pick(int(c._qs[i]["answer"]))
				await _frames(2)

extends Node3D
## Checks the shared UI and bump systems: the dialogue box can't be tapped past a line before it
## has been shown, its progress bar fills as lines are read, the task tracker shows tasks with
## progress, and bumping a person makes them speak while bumping an animal sends it scurrying.
## Run headless:  godot --headless res://tools/test/ui_test.tscn   (exits 0 on success, 1 on failure)
## With a display, add  -- --shots=<dir>  to save a screenshot of the dialogue box and tracker.

const DialogueBox := preload("res://core/ui/dialogue_box.gd")

var shots := ""

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			shots = a.substr(8)
	DialogueBox.test_fast = false
	_run()

func _fail(msg: String) -> void:
	push_error("UI TEST FAILED: " + msg)
	print("UI TEST FAILED: " + msg)
	get_tree().quit(1)

func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout

func _tap() -> void:
	var e := InputEventKey.new()
	e.keycode = KEY_SPACE
	e.pressed = true
	Input.parse_input_event(e)
	await _frames(2)

func _run() -> void:
	var env := WorldEnvironment.new()
	env.environment = Look.environment(null, Color(0.3, 0.4, 0.5))
	add_child(env)
	add_child(Look.sun())
	var cam := Look.camera()
	add_child(cam)
	cam.position = Look.CAM_OFFSET
	# ---- dialogue: no skipping ----
	var d := DialogueBox.new()
	add_child(d)
	var done := [false]
	d.finished.connect(func(): done[0] = true)
	var lines := [
		{"speaker": "Scripture", "text": "In the beginning God created the heaven and the earth.", "verse": "Genesis 1:1"},
		{"speaker": "Codex", "text": "Recording. This is the first line of the scroll."},
		{"speaker": "You", "text": "Then let's begin."},
	]
	d.play(lines)
	await _frames(2)
	if d._index != 0 or d.progress() > 0.2:
		return _fail("dialogue started in the wrong place (progress %.2f)" % d.progress())
	# Mashing taps: the first shows the whole line, the rest do nothing until it has been up a moment.
	for i in 5:
		await _tap()
	if d._index != 0:
		return _fail("tapping fast skipped a line before it could be read")
	if d._shown < d._total:
		return _fail("a tap while typing did not show the whole line")
	var p0 := d.progress()
	await _wait(DialogueBox.MIN_READ + 0.1)
	if shots != "":
		await _wait(0.4)
		get_viewport().get_texture().get_image().save_png(shots + "/ui_dialogue.png")
	await _tap()
	if d._index != 1:
		return _fail("could not move on after reading the line")
	await _wait(1.2)
	if d.progress() <= p0:
		return _fail("progress bar did not fill as lines were read")
	var guard := 0
	while d.active and guard < 400:
		await _tap()
		await _wait(0.05)
		guard += 1
	if not done[0]:
		return _fail("dialogue never finished")
	if not "Genesis 1:1" in GameState.unlocked_verses:
		return _fail("verse not recorded")
	# ---- task tracker ----
	var t := TaskTracker.new()
	add_child(t)
	t.set_task("Water the plants", 2, 5)
	await _frames(2)
	if t.count() != 1 or absf(t.value(0) - 0.4) > 0.001:
		return _fail("task tracker did not show 2 of 5")
	t.set_tasks([{"title": "Water the plants", "hint": "Fill the jar at the river.", "done": 5, "total": 5},
		{"title": "Find the lost lamb", "progress": 0.5, "side": true}])
	await _frames(2)
	if t.count() != 2 or t.value(0) < 1.0:
		return _fail("task tracker did not show two tasks")
	await _wait(0.6)
	if shots != "":
		d.play([{"speaker": "Mom", "text": "We are so proud of you. Come back and tell us everything you saw."}])
		await _wait(2.5)
		get_viewport().get_texture().get_image().save_png(shots + "/ui_tracker.png")
		while d.active:
			await _tap()
			await _wait(0.6)
	t.clear()
	await _frames(2)
	if t.count() != 0:
		return _fail("task tracker did not clear")
	# ---- bumps ----
	var scribe := preload("res://core/player/scribe.gd").new()
	add_child(scribe)
	var adam := LowPolyPerson.create(LowPolyPerson.ADAM)
	adam.position = Vector3(2.0, 0, 0)
	add_child(adam)
	var cow := LowPolyAnimal.create("cow")
	cow.position = Vector3(-2.0, 0, 0)
	add_child(cow)
	var b := Bumper.new()
	add_child(b)
	b.scribe = scribe
	b.add_person(adam, ["Peace be with thee, friend."])
	b.add_animal(cow)
	var hits := []
	b.bumped.connect(func(n): hits.append(n))
	await _frames(3)
	# Walk right into Adam.
	scribe.move_vec = Vector2(1, 0)
	var w := 0.0
	while not adam in hits and w < 2.0:
		await _wait(0.05)
		w += 0.05
	scribe.move_vec = Vector2.ZERO
	if not adam in hits:
		return _fail("walking into Adam did not count as a bump")
	if b.bubble_text(adam) != "Peace be with thee, friend.":
		return _fail("Adam did not answer the bump (bubble '%s')" % b.bubble_text(adam))
	if shots != "":
		await _wait(0.4)
		get_viewport().get_texture().get_image().save_png(shots + "/ui_bump.png")
	# Walk left into the cow: it says moo and moves away.
	var cow_start := cow.position
	scribe.move_vec = Vector2(-1, 0)
	w = 0.0
	while not cow in hits and w < 3.0:
		await _wait(0.05)
		w += 0.05
	scribe.move_vec = Vector2.ZERO
	if not cow in hits:
		return _fail("walking into the cow did not count as a bump")
	if b.bubble_text(cow) != "Moo!":
		return _fail("the cow did not moo")
	await _wait(1.0)
	if cow.position.distance_to(cow_start) < 0.8:
		return _fail("the cow did not move out of the way (moved %.2f m)" % cow.position.distance_to(cow_start))
	# Standing still beside someone, or bumps while disabled, do nothing.
	b.enabled = false
	hits.clear()
	scribe.position = adam.position + Vector3(-1.5, 0, 0)
	await _wait(2.5)
	scribe.move_vec = Vector2(1, 0)
	await _wait(0.6)
	scribe.move_vec = Vector2.ZERO
	if not hits.is_empty():
		return _fail("bumped while bumps were turned off")
	print("UI TEST PASSED")
	get_tree().quit(0)

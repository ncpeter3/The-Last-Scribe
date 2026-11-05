extends Node
## Automated run through the start screen: title, choosing a scribe, and every page of the story
## intro. Checks the text can't be skipped (a page only turns once it is fully shown) and that the
## end leads home. Run headless:  godot --headless res://tools/test/start_playtest.tscn
## With a display, add  -- --shots=<dir>  to save screenshots. Exits 0 on success, 1 on failure.

const MAIN := preload("res://core/main.tscn")

var m: Node
var shots := ""
var _n := 0

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			shots = a.substr(8)
	GameState.scribe_gender = "female"
	m = MAIN.instantiate()
	m.auto_change_scene = false
	add_child(m)
	_run()

func _fail(msg: String) -> void:
	push_error("START PLAYTEST FAILED: " + msg)
	print("START PLAYTEST FAILED: " + msg)
	get_tree().quit(1)

func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout

func _shot(label: String) -> void:
	if shots == "":
		return
	await _frames(4)
	_n += 1
	get_viewport().get_texture().get_image().save_png("%s/start_%02d_%s.png" % [shots, _n, label])

func _run() -> void:
	await _wait(2.0)
	if m.step != "title":
		return _fail("did not open on the title")
	await _shot("title")
	m.go_to_select()
	await _wait(1.6)
	if m.step != "select":
		return _fail("tap did not open scribe select")
	m._select("male")
	await _wait(0.8)
	if GameState.scribe_gender != "male":
		return _fail("choosing the male scribe did not stick")
	await _shot("select")
	m.begin()
	await _wait(1.6)
	if m.step != "story":
		return _fail("story did not start after Begin")
	var story: StoryIntro = m.find_children("*", "StoryIntro", true, false)[0]
	for i in StoryIntro.PAGES.size():
		if story.page != i:
			return _fail("expected page %d, on %d" % [i, story.page])
		# Tapping while the text types must not turn the page.
		story.tap()
		await _frames(2)
		if story.page != i:
			return _fail("a tap skipped page %d before it was read" % i)
		var guard := 0
		while not story.is_page_done():
			await _frames(1)
			guard += 1
			if guard > 2000:
				return _fail("page %d never finished typing" % i)
		await _wait(2.2 if i == 0 else 1.2)
		await _shot("story_%d" % (i + 1))
		story.tap()
		await _wait(0.8)
	await _wait(1.2)
	if m.step != "home":
		return _fail("story did not lead home (step %s)" % m.step)
	print("START PLAYTEST PASSED")
	get_tree().quit(0)

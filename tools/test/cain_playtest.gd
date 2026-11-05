extends Node
## Automated playthrough of chapter 2 (Cain and Abel): walks to every story beat, plays every
## challenge to the end (including a wrong answer, to check the hint path), checks the story's people
## (one of each; Abel gone after the field, the mark on Cain, Cain gone to Nod, Seth at the end),
## plays every side quest, and checks the chapter completes.
## Run headless:  godot --headless res://tools/test/cain_playtest.tscn
## With a display, add  -- --shots=<dir>  to save screenshots along the way.
## Exits with code 0 on success, 1 on failure.

const CHAPTER := preload("res://chapters/02_cain_and_abel/scenes/chapter.tscn")
const DialogueBox := preload("res://core/ui/dialogue_box.gd")

var ch: Node
var shots := ""
var _n := 0
var _failed := false

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			shots = a.substr(8)
	DialogueBox.test_fast = true
	GameState.unlocked_verses = []
	GameState.completed_chapters = []
	GameState.side_quests = []
	ch = CHAPTER.instantiate()
	ch.auto_change_scene = false
	add_child(ch)
	_run()

func _fail(msg: String) -> void:
	if _failed:
		return
	_failed = true
	push_error("CAIN PLAYTEST FAILED: " + msg)
	print("CAIN PLAYTEST FAILED: " + msg)
	get_tree().quit(1)

func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _shot(label: String) -> void:
	if shots == "":
		return
	await _frames(30)
	_n += 1
	get_viewport().get_texture().get_image().save_png("%s/%02d_%s.png" % [shots, _n, label])

func _tap_through() -> void:
	var guard := 0
	while ch._dialogue.active:
		var e := InputEventKey.new()
		e.keycode = KEY_SPACE
		e.pressed = true
		Input.parse_input_event(e)
		await _frames(2)
		guard += 1
		if guard > 300:
			_fail("dialogue never ended")
			return

## Read the lines slowly enough for the people to move while they're said (for screenshots too).
func _read_slowly(shot_label: String = "") -> void:
	var k := 0
	while ch._dialogue.active:
		await _frames(12 if shots == "" else 40)
		if k == 1 and shot_label != "":
			await _shot(shot_label)
		var e := InputEventKey.new()
		e.keycode = KEY_SPACE
		e.pressed = true
		Input.parse_input_event(e)
		await _frames(2)
		k += 1
		if k > 60:
			_fail("dialogue never ended")
			return

func _wait_for(cond: Callable, secs: float) -> bool:
	var t := 0.0
	while not cond.call() and t < secs:
		await get_tree().create_timer(0.1).timeout
		t += 0.1
	return cond.call()

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

## Creatures must be alive: land animals, fish and birds move, fish stay in water, land animals out.
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

## There is only ever one of each person in the chapter.
func _one_of_each(when: String) -> bool:
	var count := {"adam": 0, "eve": 0, "cain": 0, "abel": 0, "seth": 0}
	for p in ch.find_children("*", "LowPolyPerson", true, false):
		if p.is_queued_for_deletion():
			continue
		var id := String(p.name).split("_")[0]
		if count.has(id):
			count[id] += 1
	for id in count:
		if count[id] != 1:
			_fail("at the %s there are %d of %s" % [when, count[id], id])
			return false
	return true

func _visible(id: String) -> bool:
	return ch.get_actor(id).visible

func _look(id: String) -> String:
	return String((ch._actors[id]["fig"] as Node).name)

func _run() -> void:
	await _frames(5)
	if not await _check_creatures():
		return
	if not _one_of_each("start"):
		return
	if not (_visible("adam") and _visible("eve")) or _visible("cain") or _visible("abel") or _visible("seth"):
		_fail("only Adam and Eve should be there at the start")
		return
	var beats: Array = ch._beats
	var shot_beats := {"arrive": "arrive", "cain_born": "two_sons", "offerings": "offerings", "warning": "warning",
		"field": "field", "question": "where_is_abel", "mark": "mark", "nod": "nod", "city": "city", "seth": "seth"}
	for i in beats.size():
		var b: Dictionary = beats[i]
		var id := String(b["id"])
		await _put(Vector3(float(b["x"]), 0, 0))
		if not ch._dialogue.active:
			_fail("beat %s did not start" % id)
			return
		await _read_slowly(String(shot_beats.get(id, "")))
		if _failed:
			return
		if b.has("challenge"):
			if ch._challenge == null:
				_fail("challenge for %s did not start" % id)
				return
			await _play(String(b["challenge"]["type"]), ch._challenge)
			if _failed:
				return
			if not await _wait_for(func(): return ch._challenge == null, 6.0):
				_fail("challenge %s did not finish" % b["challenge"]["type"])
				return
			await _tap_through()
		if ch._beat_index != i + 1:
			_fail("beat index %d after %s" % [ch._beat_index, id])
			return
		if not await _check_people(id):
			return
	if not _one_of_each("end"):
		return
	await _tap_through()
	if not await _play_side_quests():
		return
	if not "02_cain_and_abel" in GameState.completed_chapters:
		_fail("chapter not marked complete")
		return
	for v in ["Genesis 4:1", "Genesis 4:2", "Genesis 4:8", "Genesis 4:9", "Genesis 4:15", "Genesis 4:16", "Genesis 4:22", "Genesis 4:26", "Genesis 3:18", "Genesis 5:3"]:
		if not v in GameState.unlocked_verses:
			_fail("verse %s was not recorded" % v)
			return
	for k in range(1, 27):
		if k in [23, 24]:
			continue  # summed up by the Codex
		if not "Genesis 4:%d" % k in GameState.unlocked_verses:
			_fail("Genesis 4:%d was skipped" % k)
			return
	print("CAIN PLAYTEST PASSED: %d beats, %d verses recorded, %d side quests" % [beats.size(), GameState.unlocked_verses.size(), ch._quests.size()])
	get_tree().quit(0)

## After each beat, the people are where the story has them.
func _check_people(id: String) -> bool:
	match id:
		"cain_born":
			if not (_visible("cain") and _visible("abel")):
				_fail("Cain and Abel were not born")
				return false
			if _look("cain") != "cain_young":
				_fail("Cain should be a boy at first, not %s" % _look("cain"))
				return false
		"abel":
			if _look("abel") != "abel" or _look("cain") != "cain":
				_fail("Cain and Abel did not grow up")
				return false
		"field":
			if _visible("abel"):
				_fail("Abel is still there after the field")
				return false
		"question":
			if not _visible("cain"):
				_fail("Cain is missing when the LORD asks where Abel is")
				return false
		"mark":
			if _look("cain") != "cain_marked":
				_fail("no mark on Cain")
				return false
		"nod":
			await _wait_for(func(): return not _visible("cain"), 20.0)
			if _visible("cain"):
				_fail("Cain did not go away to Nod")
				return false
		"seth":
			if not _visible("seth"):
				_fail("Seth was not born")
				return false
			if _visible("abel") or _visible("cain"):
				_fail("Cain or Abel came back at the end")
				return false
	return true

func _play(kind: String, c: Node) -> void:
	match kind:
		"herd_sheep":
			# Call two sheep at once, then the rest one by one, leading each into the fold.
			var fold: Vector3 = c._fold
			for i in c._sheep.size():
				var s: Dictionary = c._sheep[i]
				if s["state"] != "loose":
					continue
				var a: Node3D = s["node"]
				await _put(a.position + Vector3(0.6, 0, 0.6))
				await _act("Call the sheep")
				if i == 0:
					var b: Node3D = c._sheep[1]["node"]
					await _put(b.position + Vector3(0.6, 0, 0.6))
					await _act("Call the sheep")
					await _shot("herd_sheep")
				var from: Vector3 = ch._scribe.position
				var to := fold + Vector3(0, 0, 0.4)
				for k in 50:
					await _put(from.lerp(to, (k + 1) / 50.0))
					await _frames(3)
				if not await _wait_for(func(): return s["state"] == "in", 8.0):
					_fail("sheep %d did not follow into the fold (%s)" % [i, s["state"]])
					return
			await _shot("sheep_in_fold")
		"harvest":
			for i in c._crops.size():
				var cr: Dictionary = c._crops[i]
				await _put(cr["pos"] + Vector3(0.5, 0, 0.6 * (1 if cr["pos"].z < 0 else -1)))
				if i == 1:
					await _shot("harvest")
				await _act(String(c.VERBS[cr["kind"]]))
				await _tap_through()
			var cain: Node3D = ch.get_actor("cain")
			await _put(cain.position + Vector3(0.8, 0, 0.8))
			await _act("Bring the harvest to Cain")
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
					if not ch._dialogue.active:
						_fail("no hint after a wrong answer")
						return
					await _tap_through()
					await _frames(2)
				ch._choice._pick(int(c._qs[i]["answer"]))
				await _frames(2)

## Play every side quest to the end.
func _play_side_quests() -> bool:
	var qs: Array = ch._quests
	if qs.size() < 10:
		_fail("only %d side quests" % qs.size())
		return false
	for q in qs:
		if q.state != "offered":
			_fail("side quest %s is %s, not offered" % [q.name, q.state])
			return false
		await _put(q.marker_pos + Vector3(0.5, 0, 0.3))
		await _act("Side quest: %s" % q.title)
		await _tap_through()
		if q.state != "active":
			_fail("side quest %s did not start" % q.name)
			return false
		match String(q.cfg["type"]):
			"find":
				for it in q._items:
					var n: Node3D = it["node"]
					await _put(n.global_position + Vector3(0.6, 0, 0.6))
					await _act(String(q.cfg.get("verb", "")))
					await _tap_through()
				if q.cfg.has("deliver"):
					await _tap_through()
					var who: Node3D = ch.get_actor(String(q.cfg["deliver"]))
					await _put(who.global_position + Vector3(0.8, 0, 0.8))
					await _act(String(q.cfg["deliver_verb"]))
			"lamb":
				await _put(q._lamb.position + Vector3(0.6, 0, 0.6))
				await _act("Call the lamb")
				await _tap_through()
				var from: Vector3 = ch._scribe.position
				for k in 60:
					await _put(from.lerp(q._flock, (k + 1) / 60.0))
					await _frames(3)
				if not await _wait_for(func(): return q.state != "active", 8.0):
					_fail("the lamb did not follow the scribe home")
					return false
			"rest":
				await _put(q._seat + Vector3(0.6, 0, 0.8))
				await _act("Sit and rest")
				await _wait_for(func(): return ch._dialogue.active, 10.0)
		if _failed:
			return false
		await _wait_for(func(): return ch._dialogue.active or q.state == "done", 3.0)
		await _tap_through()
		if q.state != "done":
			_fail("side quest %s did not finish (%s)" % [q.name, q.progress()])
			return false
	print("Side quests: all %d done" % qs.size())
	return true

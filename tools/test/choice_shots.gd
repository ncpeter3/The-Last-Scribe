extends Node
## Shows every question in the game (home family talks, sorting animals, the scroll quiz) on
## several screen shapes (wide phone, 16:9, tablet) and checks each one fits: the whole card and
## every answer on screen, every answer's text inside its card, and nothing highlighted before
## it is touched. Run:  godot --headless res://tools/test/choice_shots.tscn
## With a display, add  -- --shots=<dir>  to save a screenshot of each.

const ChoicePanel := preload("res://core/ui/choice_panel.gd")
const NameAnimals := preload("res://chapters/01_adam_and_eve/challenges/name_animals.gd")
## Window sizes in pixels: a 20:9 phone, a 16:9 phone, a 4:3 tablet, a small 18:9 phone.
const SCREENS := [Vector2i(2400, 1080), Vector2i(1920, 1080), Vector2i(1600, 1200), Vector2i(1440, 720)]

var shots := ""

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			shots = a.substr(8)
	_run()

func _fail(msg: String) -> void:
	push_error("CHOICE TEST FAILED: " + msg)
	print("CHOICE TEST FAILED: " + msg)
	get_tree().quit(1)

func _questions() -> Array:
	var out := []
	var home = JSON.parse_string(FileAccess.get_file_as_string("res://chapters/00_home/data/home.json"))
	for f in home["family"]:
		if f.has("question"):
			out.append([String(f["question"]), f["options"]])
	out.append(["[b]Adam names this creature.[/b]\nWhich group from Genesis 2:20 should the scribe write it under?", NameAnimals.GROUPS])
	for path in ["res://chapters/01_adam_and_eve/data/beats.json", "res://chapters/02_cain_and_abel/data/beats.json"]:
		var beats = JSON.parse_string(FileAccess.get_file_as_string(path))
		for b in beats["beats"]:
			var qs: Array = b.get("challenge", {}).get("questions", [])
			for i in qs.size():
				var q: Dictionary = qs[i]
				out.append(["[b]Scroll check %d of %d[/b]\nFill in the missing words.\n\n[i]\"%s\"[/i]  (%s)" % [i + 1, qs.size(), q["text"], q["verse"]], q["options"]])
	# A stress case: four long answers.
	out.append(["What do you say?", ["The tablet copies got changed, like someone scribbling in your favorite book, so nobody knows what is true anymore.",
		"Somebody has to see it for real and write it down so it never gets lost again, not ever.",
		"I can't stop thinking about it. I think God wants me to go, and I want to go too.",
		"I'll miss you every single day, but I'll be back before you know it."]])
	return out

func _run() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.35, 0.55, 0.3)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg_layer := CanvasLayer.new()
	bg_layer.layer = -1
	bg_layer.add_child(bg)
	add_child(bg_layer)
	var cp := ChoicePanel.new()
	add_child(cp)
	var qs := _questions()
	var n := 0
	for s in SCREENS:
		get_window().size = s
		await get_tree().process_frame
		await get_tree().process_frame
		for qi in qs.size():
			var q: Array = qs[qi]
			cp.ask(q[0], q[1])
			for f in 4:
				await get_tree().process_frame
			var screen: Vector2 = get_viewport().get_visible_rect().size
			var area := Rect2(Vector2.ZERO, screen).grow(1.0)
			var where := "%dx%d (view %dx%d), question %d" % [s.x, s.y, screen.x, screen.y, qi]
			if not area.encloses(cp._panel.get_global_rect()):
				return _fail("card goes off screen at %s: %s" % [where, cp._panel.get_global_rect()])
			var scroll_rect: Rect2 = cp._scroll.get_global_rect().grow(1.0)
			var opts := cp._buttons.get_children()
			if opts.size() != (q[1] as Array).size():
				return _fail("wrong number of answers at %s" % where)
			for c in opts:
				var card := c as PanelContainer
				var r := card.get_global_rect()
				var l := card.get_child(0) as Label
				if not r.grow(1.0).encloses(l.get_global_rect()):
					return _fail("answer text spills out of its card at %s: '%s'" % [where, l.text])
				if cp._scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED and not scroll_rect.encloses(r):
					return _fail("answer off screen at %s: '%s'" % [where, l.text])
				if card.get_theme_stylebox("panel") != cp._normal:
					return _fail("answer highlighted before being touched at %s" % where)
			if shots != "" and (qi == 2 or qi == 4 or qi == 5 or qi == qs.size() - 1):
				await get_tree().create_timer(0.3).timeout
				n += 1
				get_viewport().get_texture().get_image().save_png("%s/choice_%02d_%dx%d_q%d.png" % [shots, n, s.x, s.y, qi])
			cp._pick(0)
			await get_tree().process_frame
	print("CHOICE TEST PASSED: %d questions on %d screen shapes" % [qs.size(), SCREENS.size()])
	get_tree().quit(0)

extends StoryChapter
## Chapter 2: Genesis 4, Cain and Abel. The scribe arrives east of Eden, where Adam and Eve live in a
## tent of skins. Cain and Abel are born and grow up: Abel keeps sheep (help him bring the flock into
## the fold) and Cain tills the ground (help him bring in the harvest). Then the two offerings, the
## LORD's warning to Cain, the field, "Where is Abel thy brother?", the mark of Cain, the land of Nod,
## Cain's city and family, and the birth of Seth. The chapter ends with a scroll check.
## No blood is ever shown: Cain and Abel walk out of sight into the tall grain, and Abel is not seen again.
## There is one copy of each person: Adam, Eve, Cain, Abel (as boys, then grown), and Seth.
## Story flow, HUD and ground come from core/chapter/story_chapter.gd. All text is in data/beats.json;
## a dialogue line's "cue" moves the characters at that moment (see _on_line).

const Ch2Props := preload("res://chapters/02_cain_and_abel/scenes/ch2_props.gd")

## What each person says when the scribe bumps into them.
const BUMP_LINES := {
	"adam_skins": ["Peace be with thee, scribe.", "I till the ground now, by the sweat of my face.", "We remember the garden every day."],
	"eve_skins": ["Welcome to our home, such as it is.", "Mind the fire, it's hot!", "The LORD has not forgotten us."],
	"cain_young": ["I'm the oldest!", "Someday I'll grow the biggest melons in the world.", "Race thee to the tent!"],
	"abel_young": ["Hast thou seen the lambs? They're so small!", "Cain always wins our races.", "Hello!"],
	"cain": ["Mind the rows! Walk on the path.", "The ground is hard, but it gives bread.", "I've worked this field since sunrise."],
	"abel": ["Gently now, the sheep startle easily.", "I know every one of my flock by sight.", "Peace to thee, friend."],
	"cain_marked": ["Leave me be.", "The ground will not yield to me anymore.", "No one may harm me. The LORD has seen to that."],
	"seth": ["Hello! I'm Seth!", "Mother says the LORD gave me to her.", "Wilt thou play with me?"],
}
const GROUND := {
	"void": Color(0.5, 0.48, 0.3), "outland": Color(0.5, 0.48, 0.3), "homestead": Color(0.46, 0.5, 0.3),
	"pasture": Color(0.36, 0.56, 0.28), "farm": Color(0.5, 0.42, 0.26), "offering": Color(0.48, 0.5, 0.32),
	"hill": Color(0.45, 0.45, 0.32), "field": Color(0.55, 0.5, 0.3), "dusk": Color(0.38, 0.36, 0.3),
	"barren": Color(0.5, 0.4, 0.28), "nod": Color(0.46, 0.4, 0.34), "city": Color(0.52, 0.44, 0.32),
	"dawn": Color(0.38, 0.56, 0.3),
}
const FLOWERS := [Color(1, 0.5, 0.6), Color(1, 0.9, 0.4), Color(0.7, 0.6, 1.0), Color(1, 1, 1), Color(1, 0.6, 0.3)]

var _abel_stone := Vector3.ZERO
var _cain_stone := Vector3.ZERO
var _respect: Node3D  # the light on Abel's offering

func data_path() -> String:
	return "res://chapters/02_cain_and_abel/data/beats.json"

func chapter_id() -> String:
	return "02_cain_and_abel"

func challenge_scripts() -> Dictionary:
	return {
		"herd_sheep": preload("res://chapters/02_cain_and_abel/challenges/herd_sheep.gd"),
		"harvest": preload("res://chapters/02_cain_and_abel/challenges/harvest.gd"),
		"scroll_quiz": preload("res://core/challenges/scroll_quiz.gd"),
	}

func quest_scripts() -> Dictionary:
	return {
		"find": preload("res://core/quests/find.gd"),
		"lamb": preload("res://core/quests/lamb.gd"),
		"rest": preload("res://core/quests/rest.gd"),
	}

func actor_looks() -> Dictionary:
	return {"adam": "adam_skins", "eve": "eve_skins", "cain": "cain_young", "abel": "abel_young", "seth": "seth"}

func bump_lines() -> Dictionary:
	return BUMP_LINES

func station_offsets() -> Dictionary:
	return {"adam": Vector3(1.8, 0, -1.4), "eve": Vector3(3.0, 0, -1.4), "cain": Vector3(2.0, 0, 1.6),
		"abel": Vector3(3.2, 0, 1.6), "seth": Vector3(2.4, 0, -0.2)}

func ground_colors() -> Dictionary:
	return GROUND

func _after_ready() -> void:
	_dialogue.line_shown.connect(_on_line)
	# Adam and Eve are already at home, by their tent, when the scribe arrives.
	var home: Dictionary = _beats[_beat_index_of("cain_born")]
	_show_actor("adam", _station(home, "adam"))
	_show_actor("eve", _station(home, "eve"))
	arrive_flash()

# ---------- the story's people ----------

func _actors_at_beat_start(beat: Dictionary) -> void:
	super(beat)
	var x := float(beat["x"])
	match String(beat["id"]):
		"cain_born":
			_appear("cain", _station(beat, "cain"))
			_roam("cain").radius = 1.0
		"abel":
			_years_pass()
		"offerings":
			# Each brother stands by his own offering stone.
			_pose("abel", _abel_stone + Vector3(-1.2, 0, 0.9), _abel_stone)
			_pose("cain", _cain_stone + Vector3(1.2, 0, 0.9), _cain_stone)
		"field":
			# Cain and Abel walk out together into the tall grain, out of sight.
			for id in ["cain", "abel"]:
				var r := _roam(id)
				r.paused = false
				r.radius = 0.0
				r.place(_station(beat, id))
			_roam("cain").go_to(Vector3(x + 5.0, 0, 11.5))
			_roam("abel").go_to(Vector3(x + 5.8, 0, 11.8))
		"question":
			# Cain comes back alone out of the field.
			var r := _roam("cain")
			get_actor("cain").show()
			r.paused = false
			r.place(Vector3(x + 5.0, 0, 9.0))
			r.radius = 0.0
			r.go_to(_station(beat, "cain"), false, func():
				r.face(_scribe.position)
				r.paused = true)
		"seth":
			_appear("seth", _station(beat, "seth"))
			_roam("seth").radius = 1.5

func _on_beat_finished(beat: Dictionary) -> void:
	match String(beat["id"]):
		"offerings", "question", "mark":
			for id in ["cain", "abel"]:
				if get_actor(id).visible:
					_roam(id).paused = false
					_roam(id).radius = 0.8
		"field":
			get_actor("abel").hide()
			get_actor("cain").hide()
		"nod":
			get_actor("cain").hide()

## Someone stands still at a spot, facing something.
func _pose(id: String, at: Vector3, look_at_pos: Vector3) -> void:
	var r := _roam(id)
	r.place(at)
	r.radius = 0.0
	r.face(look_at_pos)
	r.paused = true

## The boys grow up: a fade to dark and back, and Cain and Abel are grown men.
func _years_pass() -> void:
	var tw := create_tween()
	_fade.color = Color(0.05, 0.04, 0.03, 0.0)
	tw.tween_property(_fade, "color:a", 1.0, 0.45)
	tw.tween_callback(func():
		_dress("cain", "cain")
		_dress("abel", "abel")
		# Cain is out working his field by now, further along the path.
		var farm: Dictionary = _beats[_beat_index_of("cain")]
		_roam("cain").place(_station(farm, "cain"))
		_roam("cain").radius = 1.2
		var pasture: Dictionary = _beats[_beat_index_of("abel")]
		_roam("abel").place(_station(pasture, "abel"))
		_roam("abel").radius = 1.0)
	tw.tween_interval(0.25)
	tw.tween_property(_fade, "color:a", 0.0, 0.6)

## A dialogue line has appeared: some lines move the characters (the "cue" in beats.json).
func _on_line(line: Dictionary) -> void:
	match String(line.get("cue", "")):
		"abel_born":
			var beat: Dictionary = _beats[_beat_index_of("cain_born")]
			_appear("abel", _station(beat, "abel"))
			_roam("abel").radius = 1.0
		"respect":
			# "The LORD had respect unto Abel and to his offering": soft light falls on Abel's stone.
			if _respect == null:
				_respect = Ch2Props.light_shaft(_world, _abel_stone)
				Ch2Props.smoke(_world, _abel_stone + Vector3(0, 0.45, 0))
				_respect.scale = Vector3(0.05, 1, 0.05)
				var tw := _respect.create_tween()
				tw.tween_property(_respect, "scale", Vector3.ONE, 1.2).set_ease(Tween.EASE_OUT)
		"wroth":
			# "His countenance fell": Cain turns away from his brother and his offering.
			var cain := get_actor("cain")
			cain.rotation.y += PI * 0.8
		"field":
			# By the time Scripture tells it, they are out of sight in the tall grain.
			for id in ["cain", "abel"]:
				var n := get_actor(id)
				var r := _roam(id)
				if r.busy() and n.position.z < 10.0:
					r.place(r.anchor)
		"abel_gone":
			get_actor("abel").hide()
		"mark":
			# "The LORD set a mark upon Cain": a small golden sign appears on his brow.
			_dress("cain", "cain_marked")
			var at := get_actor("cain").position
			for k in 8:
				var a := TAU * k / 8.0
				var mote := Props.add(_world, Props.sphere(0.06, 1.0, 5), Color(1.0, 0.9, 0.55), at + Vector3(cos(a) * 0.7, 2.2, sin(a) * 0.7), 3.0)
				var mt := mote.create_tween()
				mt.tween_property(mote, "position", at + Vector3(0.15, 1.75, 0), 1.0)
				mt.tween_callback(mote.queue_free)
		"cain_leaves":
			# "And Cain went out from the presence of the LORD": he walks away east, alone.
			var r := _roam("cain")
			r.paused = false
			r.radius = 0.0
			r.go_to(get_actor("cain").position + Vector3(26.0, 0, -9.0), false, func(): get_actor("cain").hide())

# ---------- scenery ----------

func _ground_detail(p: Vector3, base: Color) -> Color:
	var kind := String(_scenery_at(p.x)["kind"])
	if kind == "farm" and absf(p.z) > 2.6 and absf(p.z) < 9.0:
		# Ploughed furrows: dark soil and green rows, side by side.
		return Color(0.4, 0.3, 0.2) if int(absf(p.z)) % 2 == 0 else Color(0.42, 0.48, 0.26)
	if kind in ["barren", "nod"]:
		return base.lerp(Color(0.55, 0.42, 0.3), 0.4 * absf(sin(p.x * 1.3 + p.z * 0.7)))
	return base

func _build_section(root: Node3D, kind: String, x0: float, x1: float) -> void:
	var len := x1 - x0
	match kind:
		"outland":
			# Behind the scribe: the east gate of Eden, kept by cherubims and a flaming sword (Genesis 3:24).
			for sz in [-3.2, 3.2]:
				Props.flame(root, Vector3(-9.0, 0, sz))
				Props.cherub(root, Vector3(-10.2, 0, sz * 1.3))
			for i in 30:
				var p := Vector3(_rng.randf_range(-20.0, -11.5), 0, _rng.randf_range(-14, 14))
				if absf(p.z) > 2.2:
					Props.tree(root, p, _rng.randf_range(1.1, 1.7), Color(0.2, 0.55, 0.24).lightened(_rng.randf_range(-0.05, 0.1)), Color(0, 0, 0, 0), "blossom" if i % 4 == 0 else "")
			_wild(root, maxf(x0, -8.0), x1, 1.0)
		"homestead":
			_wild(root, x0, x1, 0.6)
			Ch2Props.tent(root, Vector3(x1 - 5.0, 0, -6.0))
			Ch2Props.campfire(root, Vector3(x1 - 3.4, 0, -2.9))
			Ch2Props.woodpile(root, Vector3(x1 - 7.0, 0, -4.6))
			Ch2Props.jar(root, Vector3(x1 - 2.4, 0, -5.2))
			Ch2Props.jar(root, Vector3(x1 - 2.0, 0, -4.7))
			for i in 2:
				_bumper.add_animal(Props.creature(root, "sheep", Vector3(x1 - 8.0 + i * 2.0, 0, 5.5), 0.9))
			_bumper.add_animal(Props.creature(root, "chick", Vector3(x1 - 4.0, 0, 3.5), 1.2))
		"pasture":
			if x0 < 20.0:
				# A pond in the meadow, fed by a little stream, with fish in it.
				var pond := Props.pond(root, Vector3(x0 + 5.0, 0, 6.6), 2.0)
				Props.stream(root, [Vector2(x0 + 6.8, 7.6), Vector2(x0 + 8.2, 9.2), Vector2(x0 + 7.8, 10.8), Vector2(x0 + 9.0, 12.5)], 0.9)
				for i in 4:
					Props.creature(root, "fish", Vector3(pond.get_center().x, 0, pond.get_center().y), 0.8)
			_scatter_plants(root, x0, x1, 0.9, true)
			for i in int(len * 0.6):
				var p := Vector3(_rng.randf_range(x0, x1), 0, _rng.randf_range(-9, 9))
				if absf(p.z) > 1.4 and not Props.in_water(p, 0.3):
					Props.flower(root, p, FLOWERS[_rng.randi() % FLOWERS.size()])
			for i in int(len * 0.25):
				var p := Vector3(_rng.randf_range(x0, x1), 0, _side_z(9.0, 12.0))
				if not Props.in_water(p, 0.8):
					_bumper.add_animal(Props.creature(root, "sheep", p, _rng.randf_range(0.85, 1.05)))
			for i in 3:
				Props.bird(root, Vector3(_rng.randf_range(x0, x1), _rng.randf_range(3.5, 5.5), _rng.randf_range(-6, 4)), Color.WHITE)
		"farm":
			Ch2Props.fence(root, x0 + 1.0, x1 - 1.0, -9.6)
			Ch2Props.fence(root, x0 + 1.0, x1 - 1.0, 9.6)
			var ch: Challenge = _challenges.get(_beat_index_of("cain"))
			var taken: Array = []
			if ch and ch.get("_crops") != null:
				for c in ch.get("_crops"):
					taken.append(c["pos"])
			var x := x0 + 1.0
			while x < x1 - 0.5:
				for z in [-8.0, -6.0, -4.0, 4.0, 6.0, 8.0]:
					var p := Vector3(x + _rng.randf_range(-0.2, 0.2), 0, z + _rng.randf_range(-0.3, 0.3))
					var clear := true
					for t in taken:
						if Vector2(t.x - p.x, t.z - p.z).length() < 1.3:
							clear = false
					if clear and _rng.randf() < 0.75:
						var k: String = ["wheat", "wheat", "sprout", "gourd", "melon"][_rng.randi() % 5]
						Ch2Props.crop(root, p, k)
				x += 1.4
			for i in 2:
				_bumper.add_animal(Props.creature(root, "chick", Vector3(_rng.randf_range(x0, x1), 0, _side_z(1.8, 2.4)), 1.2))
			for i in 3:
				Props.bird(root, Vector3(_rng.randf_range(x0, x1), _rng.randf_range(3.5, 5.0), _rng.randf_range(-6, 2)), Color.WHITE)
		"offering":
			_wild(root, x0, x1, 0.7)
			# Side by side behind the path, Abel's on the left and Cain's on the right.
			_abel_stone = Vector3(x1 + 1.8, 0, -3.6)
			_cain_stone = Vector3(x1 + 4.8, 0, -3.6)
			Ch2Props.offering_stone(root, _abel_stone)
			Ch2Props.offering_stone(root, _cain_stone)
			Ch2Props.produce_heap(root, _cain_stone + Vector3(0, 0.42, 0))
			# Abel's offering: a bundle of the firstlings of his flock, wrapped in white wool.
			Props.add(root, Props.sphere(0.32, 0.6, 7), Color(0.95, 0.93, 0.88), _abel_stone + Vector3(0, 0.5, 0))
		"hill":
			_wild(root, x0, x1, 0.6)
			for i in int(len * 0.25):
				Props.rock(root, Vector3(_rng.randf_range(x0, x1), 0, _side_z(3.0, 12.0)), _rng.randf_range(0.7, 1.6), Color(0.52, 0.5, 0.45))
		"field", "dusk":
			# Tall grain on both sides of the path: once in it, people can't be seen.
			var c := Color("b8a24e") if kind == "field" else Color("8a7a4a")
			for i in int(len * (5.0 if kind == "field" else 2.5)):
				var p := Vector3(_rng.randf_range(x0, x1), 0, _side_z(2.6, 13.0))
				Ch2Props.tall_grass(root, p, c.lightened(_rng.randf_range(-0.05, 0.08)))
			for i in int(len * 0.3):
				Props.grass(root, Vector3(_rng.randf_range(x0, x1), 0, _side_z(1.6, 3.0)), Color(0.3, 0.5, 0.25))
		"barren":
			for i in int(len * 0.5):
				Props.tree(root, Vector3(_rng.randf_range(x0, x1), 0, _side_z(3.5, 14.0)), _rng.randf_range(0.8, 1.3), Color(0.3, 0.3, 0.2), Color(0, 0, 0, 0), "dead_tree")
			for i in int(len * 0.6):
				Ch2Props.cracks(root, Vector3(_rng.randf_range(x0, x1), 0.0, _side_z(1.8, 9.0)))
			for i in int(len * 0.3):
				Props.rock(root, Vector3(_rng.randf_range(x0, x1), 0, _side_z(2.5, 12.0)), _rng.randf_range(0.6, 1.4), Color(0.5, 0.42, 0.34))
			for i in int(len * 0.3):
				Props.treasure(root, "thistle", Vector3(_rng.randf_range(x0, x1), 0, _side_z(2.0, 9.0)))
		"nod":
			for i in int(len * 0.6):
				Props.rock(root, Vector3(_rng.randf_range(x0, x1), 0, _side_z(3.0, 14.0)), _rng.randf_range(0.8, 2.2), Color(0.5, 0.44, 0.4))
			for i in int(len * 0.4):
				Props.nature(root, "bush", Vector3(_rng.randf_range(x0, x1), 0, _side_z(2.2, 9.0)), _rng.randf_range(0.4, 0.7))
			for i in int(len * 0.3):
				Props.tree(root, Vector3(_rng.randf_range(x0, x1), 0, _side_z(4.0, 14.0)), _rng.randf_range(0.9, 1.3), Color(0.3, 0.42, 0.25), Color(0, 0, 0, 0), "dead_tree" if i % 2 == 0 else "")
		"city":
			# The city Cain builded, and the tents, cattle, harp and forge of his family (Genesis 4:17-22).
			for i in 4:
				Ch2Props.house(root, Vector3(x0 + 1.5 + i * 2.6, 0, -8.5 - (i % 2) * 1.2), _rng.randf_range(0.9, 1.1))
			for i in 3:
				Ch2Props.house(root, Vector3(x0 + 2.5 + i * 3.0, 0, 9.5 + (i % 2)), _rng.randf_range(0.85, 1.0))
			Ch2Props.tent(root, Vector3(x1 + 3.0, 0, 6.5), 0.85, Color("8f6438"))
			Ch2Props.tent(root, Vector3(x1 + 6.0, 0, 7.5), 0.8, Color("a87a4a"))
			for i in 3:
				_bumper.add_animal(Props.creature(root, "cow", Vector3(x1 + 2.0 + i * 1.8, 0, 3.6 + (i % 2) * 0.8), 0.95))
			Ch2Props.harp(root, Vector3(x0 + 6.0, 0, -4.0))
			Ch2Props.forge(root, Vector3(x1 - 2.5, 0, -4.6))
			_wild(root, x0, x1, 0.3)
		"dawn":
			_scatter_plants(root, x0, x1, 1.0, true)
			for i in int(len * 0.8):
				var p := Vector3(_rng.randf_range(x0, x1), 0, _rng.randf_range(-9, 9))
				if absf(p.z) > 1.4 and not Props.in_water(p, 0.3):
					Props.flower(root, p, FLOWERS[_rng.randi() % FLOWERS.size()])
			if x0 < 150.0:
				Ch2Props.tent(root, Vector3(x1 - 4.0, 0, -6.8), 0.95)
				Ch2Props.campfire(root, Vector3(x1 - 2.2, 0, -3.9))
				for i in 4:
					Props.bird(root, Vector3(_rng.randf_range(x0, x1), _rng.randf_range(3.5, 5.5), _rng.randf_range(-6, 4)), Color.WHITE)
				for i in 2:
					_bumper.add_animal(Props.creature(root, "sheep", Vector3(x1 + 3.0 + i * 1.5, 0, 6.0), 0.9))

## Wild land outside the garden: grass, bushes, rocks, thistles and a few trees.
func _wild(root: Node3D, x0: float, x1: float, density: float) -> void:
	for i in int((x1 - x0) * density):
		var p := Vector3(_rng.randf_range(x0, x1), 0, _side_z(2.4, 12.0))
		if Props.in_water(p, 0.5):
			continue
		var roll := _rng.randf()
		if roll < 0.15:
			Props.tree(root, p + Vector3(0, 0, signf(p.z) * _rng.randf_range(0, 4)), _rng.randf_range(0.8, 1.3), Color(0.32, 0.5, 0.25).lightened(_rng.randf_range(-0.05, 0.08)))
		elif roll < 0.3:
			Props.nature(root, "bush", p, _rng.randf_range(0.5, 0.8))
		elif roll < 0.45:
			Props.treasure(root, "thistle", p)
		elif roll < 0.55:
			Props.rock(root, p, _rng.randf_range(0.5, 1.2), Color(0.55, 0.5, 0.42))
		else:
			Props.grass(root, p, Color(0.35, 0.55, 0.25))

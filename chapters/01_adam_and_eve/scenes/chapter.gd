extends StoryChapter
## Chapter 1: Genesis 1-3. Creation day by day, the garden of Eden, the fall, and the gate.
## The story flow, HUD, ground and characters come from core/chapter/story_chapter.gd; this file adds
## Eden's scenery, Adam and Eve (who appear when Scripture tells of them, and wear coats of skins at
## the gate) and the forbidden tree, where Adam stops any scribe who reaches for its fruit.
## All text lives in data/beats.json. When the chapter is done, a time gate opens to Chapter 2.

const PLUCK_RANGE := 2.6
## What Adam and Eve say when the scribe bumps into them (in the garden, and at the gate).
const BUMP_LINES := {
	"adam": ["Peace be with thee, friend.", "Mind the animals. I have given each one a name!", "The LORD God made all of this. Is it not very good?"],
	"eve": ["Hello! Hast thou seen the flowers by the river?", "Walk gently. The garden is full of life.", "Every tree here is a gift."],
	"adam_skins": ["Now I must till the ground.", "Write it down true, scribe. All of it."],
	"eve_skins": ["The LORD made us coats of skins. He has not forgotten us.", "We go out from the garden together."],
}
const GROUND := {
	"void": Color(0.06, 0.06, 0.1), "light": Color(0.8, 0.72, 0.48), "sea": Color(0.16, 0.36, 0.5),
	"sky": Color(0.38, 0.56, 0.3), "animals": Color(0.42, 0.58, 0.3), "rest": Color(0.6, 0.62, 0.36),
	"eden": Color(0.31, 0.55, 0.26), "naming": Color(0.34, 0.57, 0.27), "flowers": Color(0.37, 0.6, 0.31),
	"tree": Color(0.28, 0.47, 0.24), "dark": Color(0.19, 0.27, 0.18), "gate": Color(0.52, 0.4, 0.26),
	"garden": Color(0.32, 0.56, 0.27),
}
# Land animals made on day six and named by Adam: [model id, scale].
const LAND_ANIMALS := [["cow", 1.0], ["horse", 1.0], ["sheep", 1.0], ["pig", 1.0], ["llama", 1.0], ["zebra", 1.0],
	["wolf", 1.0], ["fox", 1.0], ["dog", 1.0], ["cat", 1.0], ["chick", 1.2], ["sheep", 0.9], ["cow", 0.9]]

var _forbidden_pos := Vector3.INF  # the tree of the knowledge of good and evil
var _plucks := 0
var _adam_lines: Array = []

func data_path() -> String:
	return "res://chapters/01_adam_and_eve/data/beats.json"

func chapter_id() -> String:
	return "01_adam_and_eve"

func challenge_scripts() -> Dictionary:
	return {
		"tend_garden": preload("res://chapters/01_adam_and_eve/challenges/tend_garden.gd"),
		"name_animals": preload("res://chapters/01_adam_and_eve/challenges/name_animals.gd"),
		"gather_fruit": preload("res://chapters/01_adam_and_eve/challenges/gather_fruit.gd"),
		"find_hiding": preload("res://chapters/01_adam_and_eve/challenges/find_hiding.gd"),
		"scroll_quiz": preload("res://core/challenges/scroll_quiz.gd"),
	}

func quest_scripts() -> Dictionary:
	return {
		"find": preload("res://core/quests/find.gd"),
		"lamb": preload("res://core/quests/lamb.gd"),
		"rest": preload("res://core/quests/rest.gd"),
	}

func actor_looks() -> Dictionary:
	return {"adam": "adam", "eve": "eve"}

func bump_lines() -> Dictionary:
	return BUMP_LINES

func station_offsets() -> Dictionary:
	return {"adam": Vector3(1.8, 0, -1.4), "eve": Vector3(3.0, 0, -1.4)}

func ground_colors() -> Dictionary:
	return GROUND

func _after_ready() -> void:
	_adam_lines = _data.get("forbidden_fruit", [])

# ---------- scenery ----------

func _ground_color(x: float) -> Color:
	var s := _scenery_at(x)
	var c: Color = GROUND[s["kind"]]
	if s["kind"] == "sea" and x > float(s["x0"]) + (float(s["x1"]) - float(s["x0"])) * 0.6:
		c = GROUND["sky"]
	var t := clampf((x - float(s["x0"])) / 8.0, 0.0, 1.0)
	# The sea's stretch ends in dry land, so the next scene blends in from land, not water.
	var prev: Color = GROUND["sky"] if s["prev"] == "sea" else GROUND[s["prev"]]
	return prev.lerp(c, t * t * (3.0 - 2.0 * t))
func _build_section(root: Node3D, kind: String, x0: float, x1: float) -> void:
	var sea_split := x0 + (x1 - x0) * 0.6
	var len := x1 - x0
	match kind:
		"void":
			for i in int(len * 1.2):
				Props.add(root, Props.sphere(_rng.randf_range(0.05, 0.14), 1.0, 4), Color(1, 1, 0.9), Vector3(_rng.randf_range(x0, x1), _rng.randf_range(0.5, 7), _rng.randf_range(-12, 12)), 3.0)
		"light":
			for i in 5:
				var bx := _rng.randf_range(x0 + 2, x1 - 2)
				Props.add(root, Props.box(Vector3(0.7, 40, 0.7)), Color(1, 0.95, 0.6, 0.22), Vector3(bx, 18, _side_z(3.0, 12.0)), 1.5)
			Props.add(root, Props.sphere(1.6), Color(1, 0.95, 0.7), Vector3((x0 + x1) / 2, 7, -10), 3.0)
		"sea":
			# The gathered waters on both sides, with dry land along the path (Genesis 1:9).
			for side in [[-40.0, -1.7], [1.7, 40.0]]:
				Props.water(root, x0, sea_split, side[0], side[1], 0.03, Color(0.1, 0.33, 0.52))
			for i in int(len * 0.3):
				Props.rock(root, Vector3(_rng.randf_range(x0, sea_split), 0.0, _side_z(3.0, 14.0)), _rng.randf_range(0.6, 1.8), Color(0.45, 0.5, 0.52))
			for i in 8:
				Props.creature(root, "fish", Vector3(_rng.randf_range(x0, sea_split), 0.05, _side_z(2.0, 10.0)), 1.6)
			_scatter_plants(root, sea_split, x1, 0.9, false)
		"sky":
			var mid := (x0 + x1) / 2.0
			Props.water(root, mid + 2, mid + 9, -12, -5)
			_scatter_plants(root, x0, x1, 1.0, true)
			Props.add(root, Props.sphere(1.3), Color(1, 0.9, 0.5), Vector3(mid - 5, 8, -9), 3.0)
			Props.add(root, Props.sphere(1.0), Color(0.9, 0.92, 1.0), Vector3(mid + 5, 8, -9), 1.2)
			for i in 6:
				Props.add(root, Props.sphere(0.1, 1.0, 4), Color(1, 1, 0.9), Vector3(_rng.randf_range(x0, x1), _rng.randf_range(6, 12), _rng.randf_range(-12, -6)), 3.0)
			for i in 7:
				Props.bird(root, Vector3(_rng.randf_range(x0, x1), _rng.randf_range(3, 6), _rng.randf_range(-8, 8)), Color(0.9, 0.9, 0.95))
			for i in 6:
				Props.creature(root, "fish", Vector3(mid + _rng.randf_range(2.5, 8.5), 0.05, _rng.randf_range(-11.5, -5.5)), 1.4)
			Props.creature(root, "whale", Vector3(mid + 5.5, -0.9, -8.5), 0.55)
			Props.creature(root, "eagle", Vector3(mid - 3, 4.5, -6), 1.0)
		"animals":
			_scatter_plants(root, x0, x1, 1.0, true)
			for i in int(len * 0.5):
				_land_animal(root, Vector3(_rng.randf_range(x0, x1), 0, _side_z(2.0, 9.0)))
		"rest":
			_scatter_plants(root, x0, x1, 1.3, true)
			for i in int(len * 0.8):
				Props.flower(root, Vector3(_rng.randf_range(x0, x1), 0, _rng.randf_range(-8, 8)), Color(1, 0.9, 0.5))
		"eden", "naming", "flowers", "tree", "dark", "garden":
			_build_garden(root, kind, x0, x1)
		"gate":
			_scatter_plants(root, x0, x1, 0.5, false)
			for sz in [-3.2, 3.2]:
				Props.flame(root, Vector3(x0 + 3.5, 0, sz))
				Props.cherub(root, Vector3(x0 + 2.2, 0, sz * 1.3))
			for i in int(len * 0.15):
				Props.rock(root, Vector3(_rng.randf_range(x0 + 6, x1), 0, _side_z(3.0, 12.0)), _rng.randf_range(0.6, 1.5), Color(0.5, 0.4, 0.3))

const BLOSSOM := [Color(1.0, 0.72, 0.82), Color(0.98, 0.95, 0.97), Color(1.0, 0.82, 0.62), Color(0.86, 0.72, 1.0)]
const FLOWERS := [Color(1, 0.5, 0.6), Color(1, 0.9, 0.4), Color(0.7, 0.6, 1.0), Color(1, 1, 1), Color(1, 0.6, 0.3), Color(0.5, 0.75, 1.0)]
const FRUIT := [Color(1.0, 0.55, 0.15), Color(0.95, 0.3, 0.45), Color(1.0, 0.85, 0.25), Color(0.55, 0.25, 0.55), Color(0.6, 0.85, 0.3)]

## The garden of Eden: lush and full of life. Many kinds of trees (fruit trees, flowering trees,
## palms and tall cypresses), beds of flowers, butterflies, birds, a pond fed by a little stream,
## and the river that waters the garden (Genesis 2:8-10).
func _build_garden(root: Node3D, kind: String, x0: float, x1: float) -> void:
	var len := x1 - x0
	if kind == "dark":
		# After the fall: the same garden, dim and still.
		for i in int(len * 1.3):
			var p := Vector3(_rng.randf_range(x0, x1), 0, _side_z(2.8, 16.0))
			if Props.in_water(p, 0.8):
				continue
			Props.tree(root, p, _rng.randf_range(0.9, 1.7), Color(0.1, 0.25, 0.15).lightened(_rng.randf_range(-0.05, 0.1)), Color(0, 0, 0, 0),
					"dead_tree" if _rng.randf() < 0.35 else "")
		for i in int(len * 0.8):
			Props.flower(root, Vector3(_rng.randf_range(x0, x1), 0, _rng.randf_range(-6, 6)), Color(0.55, 0.5, 0.6))
		return
	if kind == "eden":
		# A spring high in the garden runs down as a little stream into a round pond, and the pond
		# flows on into the river that waters the garden.
		Props.stream(root, [Vector2(x0 + 0.5, -13.5), Vector2(x0 + 1.5, -12.0), Vector2(x0 + 1.0, -10.8), Vector2(x0 + 2.2, -9.6)], 1.0)
		var pond := Props.pond(root, Vector3(x0 + 3.6, 0, -7.6), 2.4)
		Props.stream(root, [Vector2(x0 + 5.9, -7.4), Vector2(x0 + 7.4, -6.9), Vector2(x0 + 9.0, -6.6), Vector2(x0 + 10.4, -6.3)], 1.0)
		for i in 4:
			Props.creature(root, "fish", Vector3(pond.get_center().x + _rng.randf_range(-1, 1), 0, pond.get_center().y + _rng.randf_range(-1, 1)), 0.8)
		Props.add(root, Props.box(Vector3(2.2, 0.08, 0.35)), Color(0.5, 0.36, 0.24), Vector3(x0 + 1.0, 0.05, -5.0))  # a fallen log by the pond
	if kind == "flowers":
		# A lily pond among the flowers, where Eve is brought to Adam.
		var lily := Props.pond(root, Vector3(x0 + 5.0, 0, 6.6), 2.1)
		for i in 3:
			Props.creature(root, "fish", Vector3(lily.get_center().x, 0, lily.get_center().y), 0.7)
		Props.stream(root, [Vector2(x0 + 7.0, 7.4), Vector2(x0 + 8.5, 9.0), Vector2(x0 + 8.0, 10.6), Vector2(x0 + 9.4, 12.5)], 0.9)
	# Challenge areas ("garden") keep trees back so the play space stays open and in view.
	var near := 8.0 if kind == "garden" else 2.8
	for i in int(len * 1.1):
		var p := Vector3(_rng.randf_range(x0, x1), 0, _side_z(near, 16.0))
		if Props.in_water(p, 1.0):
			continue
		_eden_tree(root, p)
	# A back row of tall trees along the hills, so the garden feels enclosed and full.
	for i in int(len * 0.5):
		var p := Vector3(_rng.randf_range(x0, x1), 0, _side_z(13.0, 18.0))
		if not Props.in_water(p, 1.0):
			Props.tree(root, p, _rng.randf_range(1.3, 1.9), Color(0.16, 0.45, 0.2).lightened(_rng.randf_range(-0.05, 0.1)), Color(0, 0, 0, 0), "cypress" if _rng.randf() < 0.4 else "")
	# Beds of flowers: patches of one color, plus single flowers everywhere.
	for i in int(len * 0.45):
		var c: Vector3 = Vector3(_rng.randf_range(x0, x1), 0, _side_z(1.7, 9.0))
		var col: Color = FLOWERS[_rng.randi() % FLOWERS.size()]
		for k in _rng.randi_range(5, 9):
			var p := c + Vector3(_rng.randf_range(-0.9, 0.9), 0, _rng.randf_range(-0.6, 0.6))
			if not Props.in_water(p, 0.2) and absf(p.z) > 1.3:
				Props.flower(root, p, col)
	for i in int(len * 1.2):
		var p := Vector3(_rng.randf_range(x0, x1), 0, _rng.randf_range(-9, 9))
		if Props.in_water(p, 0.2) or absf(p.z) < 1.2:
			continue
		if _rng.randf() < 0.5:
			Props.flower(root, p, FLOWERS[_rng.randi() % FLOWERS.size()])
		elif _rng.randf() < 0.3:
			Props.nature(root, "bush_flowers" if _rng.randf() < 0.6 else "bush", p, _rng.randf_range(0.5, 0.85))
		else:
			Props.grass(root, p, Color(0.25, 0.6, 0.25))
	# Butterflies over the flowers, and birds in the air.
	for i in int(len * 0.35):
		Props.butterfly(root, Vector3(_rng.randf_range(x0, x1), 0, _side_z(1.8, 7.0)), FLOWERS[_rng.randi() % FLOWERS.size()])
	if kind in ["eden", "flowers", "naming"]:
		for i in 3:
			Props.bird(root, Vector3(_rng.randf_range(x0, x1), _rng.randf_range(3.5, 5.5), _rng.randf_range(-6, 6)), Color.WHITE)
	if kind == "eden":
		# The tree of life in the midst of the garden (Genesis 2:9).
		Props.tree(root, Vector3(x1 - 4.0, 0, -3.6), 1.6, Color(0.3, 0.7, 0.3), Color(1.0, 0.85, 0.3), "tree_2")
	if kind == "naming":
		for i in int(len * 0.9):
			_land_animal(root, Vector3(_rng.randf_range(x0, x1), 0, _side_z(1.6, 6.0)))
	if kind == "tree":
		# The tree of the knowledge of good and evil: a twisted tree with red-gold leaves.
		_forbidden_pos = Vector3(x1 - 3.0, 0, -3.4)
		Props.tree(root, _forbidden_pos, 0.55, Color(0.2, 0.5, 0.25), Color(0.85, 0.15, 0.15), "twisted_tree")
		Props.serpent(root, Vector3(x1 - 3.7, 0, -1.8))

## One of Eden's many trees, "pleasant to the sight, and good for food" (Genesis 2:9).
func _eden_tree(root: Node3D, p: Vector3) -> void:
	var roll := _rng.randf()
	var s := _rng.randf_range(0.9, 1.6)
	if roll < 0.28:
		Props.tree(root, p, s, BLOSSOM[_rng.randi() % BLOSSOM.size()], Color(0, 0, 0, 0), "blossom")
	elif roll < 0.38:
		Props.tree(root, p, s * 0.9, Color(0.3, 0.62, 0.25), Color(0, 0, 0, 0), "palm")
	elif roll < 0.48:
		Props.tree(root, p, s, Color(0.15, 0.42, 0.22), Color(0, 0, 0, 0), "cypress")
	elif roll < 0.8:
		Props.tree(root, p, s, Color(0.2, 0.55, 0.24).lightened(_rng.randf_range(-0.05, 0.12)), FRUIT[_rng.randi() % FRUIT.size()], "round")
	else:
		Props.tree(root, p, s, Color(0.18, 0.5, 0.22).lightened(_rng.randf_range(-0.05, 0.1)))

func _land_animal(root: Node3D, pos: Vector3) -> void:
	if Props.in_water(pos, 0.8):
		return
	var a: Array = LAND_ANIMALS[_rng.randi() % LAND_ANIMALS.size()]
	_bumper.add_animal(Props.creature(root, a[0], pos, float(a[1]) * _rng.randf_range(0.9, 1.1)))

# ---------- Adam and Eve ----------

func _on_beat_actors(beat: Dictionary) -> void:
	match String(beat["id"]):
		"adam":
			# "Formed man of the dust of the ground" (Genesis 2:7).
			_appear("adam", _station(beat, "adam"))
			_roam("adam").radius = 1.2
		"eve":
			_appear("eve", _station(beat, "eve"))
			_roam("eve").radius = 1.2
		"gate":
			for a in ["adam", "eve"]:
				_dress(a, a + "_skins")
				_roam(a).paused = false
				_roam(a).place(_station(beat, a))
				_roam(a).radius = 0.8
		"hiding":
			var ch: Challenge = _challenges.get(_beat_index)
			if ch and ch.has_method("spot"):
				hide_actors(ch.spot(), false)

func _roams_in_challenge(beat: Dictionary) -> bool:
	return String(beat["id"]) != "hiding"

## Send Adam and Eve to hide at `spot` (Genesis 3:8). `now` puts them there at once.
func hide_actors(spot: Vector3, now: bool) -> void:
	var offs := {"adam": Vector3(-0.45, 0, 0), "eve": Vector3(0.45, 0, 0)}
	for id in offs:
		var r := _roam(id)
		var n: Node3D = _actors[id]["node"]
		if not n.visible:
			continue
		var at: Vector3 = spot + offs[id]
		r.radius = 0.0
		var crouch := func():
			r.paused = true
			n.rotation.y = PI / 2.0  # facing away, hidden in the trees
		if now:
			if r.busy() or n.position.distance_to(at) > 0.2:
				r.place(at)
			crouch.call()
		else:
			r.go_to(at, true, crouch)

# ---------- the forbidden tree ----------

func _extra_action() -> String:
	return "Pluck a fruit" if _can_pluck() else ""

func _do_extra_action() -> void:
	_pluck()

func _can_pluck() -> bool:
	if _forbidden_pos == Vector3.INF or _challenge != null:
		return false
	# Only before the serpent's scene: after that, the fruit has been eaten (Genesis 3:6).
	var serpent := _beat_index_of("serpent")
	if serpent < 0 or _told >= serpent:
		return false
	return Vector2(_scribe.position.x - _forbidden_pos.x, _scribe.position.z - _forbidden_pos.z).length() < PLUCK_RANGE

## The scribe reaches for the forbidden fruit, and Adam comes running to knock it away. Every time.
var _pluck_fruit: Node3D
var _adam_home := Vector3.ZERO

func _pluck() -> void:
	_busy = true
	_freeze()
	var hand := _scribe.position + Vector3(0.35, 1.0, 0.25)
	_pluck_fruit = Props.add(_world, Props.sphere(0.14, 1.0, 6), Color(0.85, 0.15, 0.15), _forbidden_pos + Vector3(0, 2.3, 0.6))
	var tw := _pluck_fruit.create_tween()
	tw.tween_property(_pluck_fruit, "position", hand, 0.45).set_ease(Tween.EASE_OUT)
	tw.tween_callback(_adam_runs_over)

func _adam_runs_over() -> void:
	var adam := get_actor("adam")
	if adam == null or not adam.visible:
		_smack()
		return
	var r := _roam("adam")
	_adam_home = r.anchor
	var side := Vector3(0.9, 0, 0.5) if adam.position.x >= _scribe.position.x else Vector3(-0.9, 0, 0.5)
	# If he's far off, he's just out of sight, already on his way.
	var gap := Vector3(adam.position.x - _scribe.position.x, 0, adam.position.z - _scribe.position.z)
	if gap.length() > 7.0:
		r.place(_scribe.position + gap.normalized() * 7.0)
		r.anchor = _adam_home
	r.paused = false
	r.go_to(_scribe.position + side, true, _smack)

func _smack() -> void:
	var adam := get_actor("adam")
	var fig: LowPolyPerson = _actors["adam"]["fig"]
	if adam and adam.visible:
		_roam("adam").face(_scribe.position)
		fig.gesture = "talk"
	# The fruit goes flying out of the scribe's hands and rolls away under the tree.
	var from := adam.position if adam and adam.visible else _scribe.position + Vector3.LEFT
	var away := Vector3(_scribe.position.x - from.x, 0, _scribe.position.z - from.z).normalized()
	var land := _scribe.position + away * 2.2 + Vector3(0, 0.14, 0)
	var fruit := _pluck_fruit
	var tw := fruit.create_tween()
	tw.tween_property(fruit, "position", (fruit.position + land) / 2.0 + Vector3(0, 0.9, 0), 0.22).set_ease(Tween.EASE_OUT)
	tw.tween_property(fruit, "position", land, 0.25).set_ease(Tween.EASE_IN)
	tw.tween_interval(0.6)
	tw.tween_property(fruit, "scale", Vector3.ONE * 0.01, 0.3)
	tw.tween_callback(fruit.queue_free)
	var line: Dictionary = {"speaker": "Adam", "text": "Don't you know you are not to eat from that tree?"}
	if not _adam_lines.is_empty():
		line = _adam_lines[_plucks % _adam_lines.size()]
	_plucks += 1
	_busy = false
	say([line], _adam_goes_back)

func _adam_goes_back() -> void:
	var fig: LowPolyPerson = _actors["adam"]["fig"]
	fig.gesture = ""
	if not get_actor("adam").visible:
		return
	var r := _roam("adam")
	r.radius = 1.2
	r.go_to(_adam_home)

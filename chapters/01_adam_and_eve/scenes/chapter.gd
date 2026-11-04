extends Node2D
## Chapter 1: Genesis 1-3. A long side-scrolling world.
## Story beats trigger in order as the scribe reaches each station (the way forward is blocked until
## the current beat is told, so the order of Scripture is kept). Between stations the world is open:
## walk back and forth and tap "Look" on discoverables for Scribe's notes and bonus verses.
## All text lives in data/beats.json.

const DialogueBox := preload("res://core/ui/dialogue_box.gd")
const Scribe := preload("res://core/player/scribe.gd")
const DATA := "res://chapters/01_adam_and_eve/data/beats.json"
const GROUND_Y := 560.0
const NOTE_RANGE := 120.0

var _scribe: CharacterBody2D
var _dialogue: CanvasLayer
var _beats: Array = []
var _discoverables: Array = []
var _seen: Dictionary = {}
var _beat_index := 0
var _world_end := 0.0
var _look_button: Button
var _title_label: Label
var _journal_panel: PanelContainer
var _journal_text: RichTextLabel
var _sky: ColorRect
var _near: Dictionary = {}

func _ready() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	_beats = data["beats"]
	_discoverables = data["discoverables"]
	_world_end = float(_beats[-1]["x"]) + 400.0
	_build_world()
	_build_hud()
	_dialogue = DialogueBox.new()
	add_child(_dialogue)
	_dialogue.finished.connect(_on_beat_finished)
	_update_limit()

func _process(_delta: float) -> void:
	if _dialogue.active:
		_look_button.hide()
		return
	# Trigger the current beat when the scribe reaches its station.
	if _beat_index < _beats.size() and _scribe.position.x >= float(_beats[_beat_index]["x"]) - 4.0:
		_start_beat()
		return
	# Show "Look" when near an unseen discoverable.
	_near = {}
	for d in _discoverables:
		if absf(_scribe.position.x - float(d["x"])) < NOTE_RANGE:
			_near = d
			break
	_look_button.visible = not _near.is_empty()
	if not _near.is_empty():
		_look_button.text = "Look: %s" % _near["name"]

func _start_beat() -> void:
	var beat: Dictionary = _beats[_beat_index]
	_scribe.frozen = true
	_title_label.text = beat["title"]
	_sky.color = Color(beat["tint"])
	_dialogue.play(beat["lines"])

func _on_beat_finished() -> void:
	_scribe.frozen = false
	_beat_index += 1
	if _beat_index >= _beats.size():
		GameState.complete_chapter("01_adam_and_eve")
		_title_label.text = "Chapter complete: %d verses recorded" % GameState.unlocked_verses.size()
	_update_limit()

func _update_limit() -> void:
	# Can walk up to the next station, never past it until its beat is told.
	_scribe.min_x = 0.0
	if _beat_index < _beats.size():
		_scribe.max_x = float(_beats[_beat_index]["x"])
	else:
		_scribe.max_x = _world_end

func _on_look() -> void:
	if _near.is_empty():
		return
	var lines := [{"speaker": _near["name"], "text": _near["note"]}]
	if _near.has("verse"):
		lines[0]["verse"] = _near["verse"]
	_scribe.frozen = true
	_dialogue.finished.connect(func(): _scribe.frozen = false, CONNECT_ONE_SHOT)
	_dialogue.play(lines)

func _build_world() -> void:
	_sky = ColorRect.new()
	_sky.color = Color(_beats[0]["tint"])
	_sky.z_index = -10
	_sky.position = Vector2(-2000, -600)
	_sky.size = Vector2(_world_end + 4000.0, 1200)
	add_child(_sky)
	var ground := ColorRect.new()
	ground.color = Color(0.35, 0.55, 0.3)
	ground.position = Vector2(-2000, GROUND_Y)
	ground.size = Vector2(_world_end + 4000.0, 400)
	add_child(ground)
	# Station markers (stone pillars) and discoverable markers (small glowing squares).
	for b in _beats:
		_marker(float(b["x"]), Color(0.9, 0.85, 0.6), Vector2(24, 120))
	for d in _discoverables:
		_marker(float(d["x"]), Color(1.0, 0.95, 0.4), Vector2(28, 28))
	_scribe = Scribe.new()
	_scribe.position = Vector2(200, GROUND_Y - 40)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(40, 80)
	shape.shape = rect
	_scribe.add_child(shape)
	var body := ColorRect.new()
	body.color = Color(0.9, 0.8, 0.5)
	body.size = Vector2(40, 80)
	body.position = Vector2(-20, -40)
	_scribe.add_child(body)
	var cam := Camera2D.new()
	cam.position_smoothing_enabled = true
	cam.offset = Vector2(250, -150)
	_scribe.add_child(cam)
	add_child(_scribe)

func _marker(x: float, color: Color, size: Vector2) -> void:
	var r := ColorRect.new()
	r.color = color
	r.size = size
	r.position = Vector2(x - size.x / 2.0, GROUND_Y - size.y)
	add_child(r)

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_title_label = Label.new()
	_title_label.position = Vector2(30, 20)
	_title_label.add_theme_font_size_override("font_size", 34)
	_title_label.text = "Walk right to begin"
	layer.add_child(_title_label)
	for spec in [["<", -1.0, Vector2(40, 580)], [">", 1.0, Vector2(200, 580)]]:
		var b := Button.new()
		b.text = spec[0]
		b.custom_minimum_size = Vector2(130, 110)
		b.position = spec[2]
		b.button_down.connect(func(): _scribe.move_dir = spec[1])
		b.button_up.connect(func(): _scribe.move_dir = 0.0)
		layer.add_child(b)
	_look_button = Button.new()
	_look_button.custom_minimum_size = Vector2(420, 110)
	_look_button.position = Vector2(800, 580)
	_look_button.add_theme_font_size_override("font_size", 28)
	_look_button.pressed.connect(_on_look)
	_look_button.hide()
	layer.add_child(_look_button)
	var journal_btn := Button.new()
	journal_btn.text = "Journal"
	journal_btn.position = Vector2(1100, 20)
	journal_btn.custom_minimum_size = Vector2(150, 70)
	journal_btn.pressed.connect(_toggle_journal)
	layer.add_child(journal_btn)
	_journal_panel = PanelContainer.new()
	_journal_panel.anchor_left = 0.1
	_journal_panel.anchor_right = 0.9
	_journal_panel.anchor_top = 0.15
	_journal_panel.anchor_bottom = 0.85
	_journal_text = RichTextLabel.new()
	_journal_text.add_theme_font_size_override("normal_font_size", 26)
	_journal_panel.add_child(_journal_text)
	_journal_panel.hide()
	layer.add_child(_journal_panel)

func _toggle_journal() -> void:
	_journal_panel.visible = not _journal_panel.visible
	if _journal_panel.visible:
		_journal_text.text = "Scroll Journal (%d verses)\n\n%s" % [GameState.unlocked_verses.size(), "\n".join(GameState.unlocked_verses)]

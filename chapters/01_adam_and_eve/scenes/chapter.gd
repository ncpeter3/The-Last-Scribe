extends Node2D
## Greybox for chapter 1. Builds the scene in code: ground, scribe, touch buttons, dialogue.
## Story beats are loaded from data/beats.json so the scripture side can be reviewed without code.

const DialogueBox := preload("res://core/ui/dialogue_box.gd")
const Scribe := preload("res://core/player/scribe.gd")
const DATA := "res://chapters/01_adam_and_eve/data/beats.json"

var _scribe: CharacterBody2D
var _dialogue: CanvasLayer
var _beats: Array = []
var _beat_index := 0

func _ready() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	_beats = data["beats"]
	_build_world()
	_build_controls()
	_dialogue = DialogueBox.new()
	add_child(_dialogue)
	_dialogue.finished.connect(_next_beat)
	_next_beat()

func _next_beat() -> void:
	if _beat_index >= _beats.size():
		GameState.complete_chapter("01_adam_and_eve")
		return
	var beat: Dictionary = _beats[_beat_index]
	_beat_index += 1
	_dialogue.play(beat["lines"])

func _build_world() -> void:
	var ground := ColorRect.new()
	ground.color = Color(0.35, 0.55, 0.3)
	ground.position = Vector2(-2000, 560)
	ground.size = Vector2(6000, 400)
	add_child(ground)
	_scribe = Scribe.new()
	_scribe.position = Vector2(300, 520)
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
	_scribe.add_child(cam)
	add_child(_scribe)

func _build_controls() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	for spec in [["<", -1.0, Vector2(40, 560)], [">", 1.0, Vector2(200, 560)]]:
		var b := Button.new()
		b.text = spec[0]
		b.custom_minimum_size = Vector2(130, 110)
		b.position = spec[2]
		b.button_down.connect(func(): _scribe.move_dir = spec[1])
		b.button_up.connect(func(): _scribe.move_dir = 0.0)
		layer.add_child(b)

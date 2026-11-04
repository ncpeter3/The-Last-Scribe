extends Control
## Start screen: pick a female or male scribe, then begin chapter 1.

const CHAPTER_1 := "res://chapters/01_adam_and_eve/scenes/chapter.tscn"

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.06, 0.1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 24)
	add_child(box)
	box.add_child(_label("The Last Scribe", 72, Color(0.95, 0.85, 0.55)))
	box.add_child(_label("Year 2060. The books are gone. No copy can be trusted.\nYou are the one who goes back to see it, and write it down true.", 28, Color(0.85, 0.82, 0.75)))
	box.add_child(_label("Choose your scribe", 34, Color.WHITE))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 40)
	box.add_child(row)
	row.add_child(_button("Female scribe", "female"))
	row.add_child(_button("Male scribe", "male"))

func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

func _button(text: String, gender: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(320, 120)
	b.add_theme_font_size_override("font_size", 34)
	b.pressed.connect(func():
		GameState.scribe_gender = gender
		GameState.save_game()
		get_tree().change_scene_to_file(CHAPTER_1))
	return b

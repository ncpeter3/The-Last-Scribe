extends Control
## Start screen: pick a female or male scribe, then start at home in 2060 (the garage time machine leads to chapter 1).

const HOME := "res://chapters/00_home/scenes/home.tscn"

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
	row.add_child(_choice("Female scribe", "female"))
	row.add_child(_choice("Male scribe", "male"))

var _turntables: Array[Node3D] = []

func _process(delta: float) -> void:
	for t in _turntables:
		t.rotation.y += delta * 0.6

## A button with a small 3D preview of the scribe above it.
func _choice(text: String, gender: String) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	var id := "scribe_" + gender
	if true:  # every scribe has a low-poly preview
		var holder := SubViewportContainer.new()
		holder.stretch = true
		holder.custom_minimum_size = Vector2(320, 260)
		var vp := SubViewport.new()
		vp.own_world_3d = true
		vp.transparent_bg = true
		holder.add_child(vp)
		var stage := Node3D.new()
		vp.add_child(stage)
		var turn := Node3D.new()
		stage.add_child(turn)
		var model := CharacterFactory.make(id, turn, Vector3.ZERO)
		model.rotation.y = -PI / 2.0  # face the camera
		CharacterFactory.play(model, "Idle")
		_turntables.append(turn)
		var cam := Camera3D.new()
		cam.position = Vector3(0, 1.1, 3.2)
		cam.rotation_degrees = Vector3(-8, 0, 0)
		cam.fov = 40
		stage.add_child(cam)
		var sun := DirectionalLight3D.new()
		sun.rotation_degrees = Vector3(-35, 25, 0)
		stage.add_child(sun)
		var env := WorldEnvironment.new()
		env.environment = Environment.new()
		env.environment.background_mode = Environment.BG_CLEAR_COLOR
		env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.environment.ambient_light_color = Color(0.9, 0.85, 0.8)
		env.environment.ambient_light_energy = 0.6
		stage.add_child(env)
		col.add_child(holder)
	col.add_child(_button(text, gender))
	return col

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
		get_tree().change_scene_to_file(HOME))
	return b

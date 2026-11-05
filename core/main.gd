extends Control
## Start screen. Three steps, all over the same 3D backdrop (core/start/title_stage.gd):
##   1. Title: the game's name and "tap to begin".
##   2. Choose your scribe: two cards with turning 3D previews.
##   3. The story so far (core/start/story_intro.gd), then the scribe's home in 2060.

signal step_changed(step: String)  ## "title", "select", "story" (the automated test listens)

const HOME := "res://chapters/00_home/scenes/home.tscn"
const GOLD := Color(0.96, 0.8, 0.45)
const CREAM := Color(0.97, 0.93, 0.84)

var auto_change_scene := true  ## the test turns this off so it can check the story without leaving
var step := ""
var _stage: TitleStage
var _title_ui: Control
var _select_ui: Control
var _fade: ColorRect
var _cards := {}  # gender -> PanelContainer
var _models := {}  # gender -> LowPolyPerson
var _turntables: Array[Node3D] = []
var _begin_btn: Button
var _tap_label: Label
var _t := 0.0
var _busy := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# The 3D backdrop fills the screen.
	var holder := SubViewportContainer.new()
	holder.stretch = true
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_2X
	holder.add_child(vp)
	_stage = TitleStage.new()
	vp.add_child(_stage)
	add_child(_vignette())

	_title_ui = _build_title()
	add_child(_title_ui)
	_select_ui = _build_select()
	add_child(_select_ui)
	_select_ui.hide()

	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)
	create_tween().tween_property(_fade, "color:a", 0.0, 1.2)
	_set_step("title")

func _set_step(s: String) -> void:
	step = s
	step_changed.emit(s)

func _process(delta: float) -> void:
	_t += delta
	for i in _turntables.size():  # sway side to side so the face stays toward the player
		_turntables[i].rotation.y = sin(_t * 0.7 + i * 1.7) * 0.6
	if _tap_label:
		_tap_label.modulate.a = 0.55 + 0.45 * sin(_t * 3.0)

func _gui_input(event: InputEvent) -> void:
	if step == "title" and _is_tap(event):
		accept_event()
		go_to_select()

func _unhandled_input(event: InputEvent) -> void:
	if step == "title" and (event.is_action_pressed("ui_accept") or event.is_action_pressed("interact")):
		go_to_select()

static func _is_tap(event: InputEvent) -> bool:
	return (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)

# ---------- step 1: title ----------

func _build_title() -> Control:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.set_anchors_preset(Control.PRESET_CENTER_TOP)
	col.anchor_left = 0.0
	col.anchor_right = 1.0
	col.offset_top = 36
	col.add_theme_constant_override("separation", 2)
	root.add_child(col)
	col.add_child(_label("A  JOURNEY  BACK  TO  THE  BEGINNING", 20, Color(0.62, 0.9, 0.88), _font(true, 600)))
	var title := _label("THE LAST SCRIBE", 96, GOLD, _font(true, 800))
	title.add_theme_constant_override("outline_size", 14)
	title.add_theme_color_override("font_outline_color", Color(0.12, 0.07, 0.02, 0.9))
	title.add_theme_constant_override("shadow_offset_y", 6)
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	title.material = _shimmer()
	col.add_child(title)
	col.add_child(_divider(420))

	var bottom := VBoxContainer.new()
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.anchor_left = 0.0
	bottom.anchor_right = 1.0
	bottom.anchor_top = 1.0
	bottom.anchor_bottom = 1.0
	bottom.offset_top = -150
	bottom.offset_bottom = -30
	bottom.alignment = BoxContainer.ALIGNMENT_END
	bottom.add_theme_constant_override("separation", 10)
	root.add_child(bottom)
	bottom.add_child(_label("The year is 2060. The words are fading.\nGo back, see it with your own eyes, and write it down true.",
		24, Color(0.9, 0.88, 0.82)))
	_tap_label = _label("TAP  TO  BEGIN", 30, CREAM, _font(true, 700))
	bottom.add_child(_tap_label)
	return root

func go_to_select() -> void:
	if _busy or step != "title":
		return
	_set_step("select")
	_stage.set_view(1)
	var tw := create_tween()
	tw.tween_property(_title_ui, "modulate:a", 0.0, 0.35)
	tw.tween_callback(func():
		_title_ui.hide()
		_select_ui.modulate.a = 0.0
		_select_ui.show()
		_select(GameState.scribe_gender))
	tw.tween_property(_select_ui, "modulate:a", 1.0, 0.45)

# ---------- step 2: choose your scribe ----------

func _build_select() -> Control:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_top = 28
	col.offset_bottom = -28
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 18)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(col)
	col.add_child(_label("CHOOSE  YOUR  SCRIBE", 44, GOLD, _font(true, 800)))
	col.add_child(_label("Who will carry the pen back through time?", 22, Color(0.82, 0.86, 0.9)))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 56)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(row)
	row.add_child(_card("female", "Female Scribe"))
	row.add_child(_card("male", "Male Scribe"))

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 20)
	col.add_child(buttons)
	var back := Button.new()
	back.text = "Back"
	back.custom_minimum_size = Vector2(150, 72)
	back.add_theme_font_size_override("font_size", 26)
	back.pressed.connect(_back_to_title)
	buttons.add_child(back)
	_begin_btn = Button.new()
	_begin_btn.text = "Begin the Journey"
	_begin_btn.custom_minimum_size = Vector2(380, 72)
	_begin_btn.add_theme_font_size_override("font_size", 30)
	_begin_btn.add_theme_font_override("font", _font(true, 800))
	_begin_btn.add_theme_color_override("font_color", Color(0.15, 0.09, 0.02))
	_begin_btn.add_theme_color_override("font_hover_color", Color(0.1, 0.06, 0.0))
	_begin_btn.add_theme_color_override("font_pressed_color", Color(0.1, 0.06, 0.0))
	_begin_btn.add_theme_color_override("font_focus_color", Color(0.15, 0.09, 0.02))
	_begin_btn.add_theme_stylebox_override("normal", _box(GOLD, Color(1, 0.95, 0.75), 2, 36, Color(1, 0.75, 0.3, 0.45), 14))
	_begin_btn.add_theme_stylebox_override("hover", _box(GOLD.lightened(0.1), Color(1, 0.97, 0.85), 2, 36, Color(1, 0.75, 0.3, 0.6), 18))
	_begin_btn.add_theme_stylebox_override("pressed", _box(GOLD.darkened(0.15), Color(1, 0.95, 0.75), 2, 36, Color(1, 0.75, 0.3, 0.3), 8))
	_begin_btn.pressed.connect(begin)
	buttons.add_child(_begin_btn)
	return root

## A card with a turning 3D preview of the scribe on a glowing pedestal. Tap it to choose.
func _card(gender: String, title: String) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(300, 0)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.pivot_offset = Vector2(150, 190)
	_cards[gender] = card
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 4)
	card.add_child(col)

	var holder := SubViewportContainer.new()
	holder.stretch = true
	holder.custom_minimum_size = Vector2(270, 300)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_2X
	holder.add_child(vp)
	var stage := Node3D.new()
	vp.add_child(stage)
	var ped := LowPoly.new()
	ped.prism(Vector3(0, -0.16, 0), 0.62, 0.56, 0.16, 10, LowPoly.shade(LowPoly.STONE, 0.05))
	ped.ring(Vector3(0, -0.005, 0), 0.5, 0.56, 20, LowPoly.glow(LowPoly.TEAL, 0.6), 0.01)
	stage.add_child(ped.instance())
	var turn := Node3D.new()
	stage.add_child(turn)
	var model := CharacterFactory.make("scribe_" + gender, turn, Vector3.ZERO)
	model.rotation.y = -PI / 2.0  # face the camera
	CharacterFactory.play(model, "Idle")
	_models[gender] = model
	_turntables.append(turn)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.0, 3.7)
	cam.rotation_degrees = Vector3(-5, 0, 0)
	cam.fov = 38
	stage.add_child(cam)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-30, 30, 0)
	key.light_color = Color(1.0, 0.92, 0.8)
	key.light_energy = 1.1
	stage.add_child(key)
	var rim := OmniLight3D.new()
	rim.position = Vector3(-0.8, 1.6, -1.2)
	rim.light_color = Color(0.4, 1.0, 0.95)
	rim.light_energy = 2.0
	rim.omni_range = 3.0
	stage.add_child(rim)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.75, 0.78, 0.95)
	env.environment.ambient_light_energy = 0.55
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment.glow_enabled = true
	stage.add_child(env)
	col.add_child(holder)
	col.add_child(_label(title.to_upper(), 26, CREAM, _font(true, 700)))
	card.gui_input.connect(func(e: InputEvent):
		if _is_tap(e):
			_select(gender))
	return card

func _select(gender: String) -> void:
	if gender not in _cards:
		gender = "female"
	var changed := GameState.scribe_gender != gender
	GameState.scribe_gender = gender
	for g in _cards:
		var on: bool = g == gender
		var card: PanelContainer = _cards[g]
		var style := _box(Color(0.06, 0.07, 0.12, 0.9 if on else 0.8),
			GOLD if on else Color(0.6, 0.65, 0.75, 0.35), 3 if on else 2, 24,
			Color(1.0, 0.75, 0.3, 0.45) if on else Color(0, 0, 0, 0.35), 22 if on else 8)
		style.set_content_margin_all(14)
		card.add_theme_stylebox_override("panel", style)
		var tw := card.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(card, "scale", Vector2.ONE * (1.05 if on else 0.94), 0.3)
		card.modulate = Color.WHITE if on else Color(0.7, 0.7, 0.75)
		CharacterFactory.play(_models[g], "Wave" if on and changed else "Idle")
	if changed:
		get_tree().create_timer(1.6).timeout.connect(func():
			if is_instance_valid(_models[gender]):
				CharacterFactory.play(_models[gender], "Idle"))

func _back_to_title() -> void:
	if _busy:
		return
	_set_step("title")
	_stage.set_view(0)
	_select_ui.hide()
	_title_ui.show()
	create_tween().tween_property(_title_ui, "modulate:a", 1.0, 0.4)

# ---------- step 3: the story so far ----------

func begin() -> void:
	if _busy or step != "select":
		return
	_busy = true
	GameState.save_game()
	CharacterFactory.play(_models[GameState.scribe_gender], "Victory")
	var tw := create_tween()
	tw.tween_interval(0.5)
	tw.tween_property(_fade, "color:a", 1.0, 0.6)
	tw.tween_callback(func():
		_select_ui.hide()
		var story := StoryIntro.new()
		story.finished.connect(_go_home)
		add_child(story)
		move_child(_fade, -1)
		_set_step("story")
		_busy = false)
	tw.tween_property(_fade, "color:a", 0.0, 0.6)

func _go_home() -> void:
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.8)
	tw.tween_callback(func():
		_set_step("home")
		if auto_change_scene:
			get_tree().change_scene_to_file(HOME))

# ---------- look ----------

func _vignette() -> ColorRect:
	var r := ColorRect.new()
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
// Darkens the edges and the very top and bottom so the titles and buttons read clearly.
void fragment() {
	vec2 p = UV - 0.5;
	float v = smoothstep(0.35, 0.85, length(p * vec2(1.0, 1.3)));
	float band = smoothstep(0.3, 0.0, UV.y) * 0.45 + smoothstep(0.72, 1.0, UV.y) * 0.55;
	COLOR = vec4(0.01, 0.01, 0.03, clamp(v * 0.75 + band, 0.0, 0.9));
}
"""
	m.shader = sh
	r.material = m
	return r

## A gold sweep that slides across the title every few seconds.
func _shimmer() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	float x = FRAGCOORD.x * 0.0012 + FRAGCOORD.y * 0.0015;
	float t = mod(TIME * 0.35, 2.2) - 0.3;
	float band = smoothstep(0.12, 0.0, abs(x - t));
	c.rgb += vec3(1.0, 0.95, 0.8) * band * 0.55 * step(0.6, c.r);
	COLOR = c;
}
"""
	m.shader = sh
	return m

func _divider(width: float) -> Control:
	var d := Control.new()
	d.custom_minimum_size = Vector2(width, 22)
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	d.draw.connect(func():
		var cx := d.size.x / 2.0
		var y := 11.0
		for s in [-1.0, 1.0]:
			d.draw_line(Vector2(cx + s * 18, y), Vector2(cx + s * width / 2.0, y), Color(GOLD, 0.7), 2.0, true)
			d.draw_circle(Vector2(cx + s * (width / 2.0 + 4), y), 3.0, Color(GOLD, 0.7))
		d.draw_colored_polygon(PackedVector2Array([Vector2(cx, y - 9), Vector2(cx + 9, y), Vector2(cx, y + 9), Vector2(cx - 9, y)]), GOLD))
	var c := CenterContainer.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(d)
	return c

static func _font(title: bool, weight: int) -> FontVariation:
	var f := FontVariation.new()
	f.base_font = load("res://shared_assets/fonts/Cinzel.ttf" if title else "res://shared_assets/fonts/Nunito.ttf")
	f.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	return f

static func _label(text: String, size: int, color: Color, font: Font = null) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if font:
		l.add_theme_font_override("font", font)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

static func _box(bg: Color, border: Color, bw: int, radius: int, shadow: Color, shadow_size: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(12)
	s.shadow_color = shadow
	s.shadow_size = shadow_size
	s.anti_aliasing = true
	return s

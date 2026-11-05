extends CanvasLayer
## A question with big tap-friendly answer buttons. Call ask(question, options); `chosen` fires
## with the index of the button tapped. Used by challenges (sorting animals, the scroll quiz).

signal chosen(index: int)

var active := false
var _panel: PanelContainer
var _label: RichTextLabel
var _buttons: VBoxContainer

func _ready() -> void:
	layer = 11
	_panel = PanelContainer.new()
	_panel.anchor_left = 0.14
	_panel.anchor_right = 0.86
	_panel.anchor_top = 0.18
	_panel.anchor_bottom = 0.96
	_panel.add_theme_stylebox_override("panel", UiStyle.card(UiStyle.GLASS, 26, 30))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	_panel.add_child(box)
	_label = RichTextLabel.new()
	_label.bbcode_enabled = true
	_label.fit_content = true
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_override("normal_font", UiStyle.font(600))
	_label.add_theme_font_override("bold_font", UiStyle.font(850))
	_label.add_theme_font_override("italics_font", UiStyle.font(500))
	_label.add_theme_font_size_override("normal_font_size", 28)
	_label.add_theme_font_size_override("bold_font_size", 30)
	_label.add_theme_font_size_override("italics_font_size", 27)
	_label.add_theme_color_override("default_color", UiStyle.TEXT)
	box.add_child(_label)
	_buttons = VBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 12)
	box.add_child(_buttons)
	add_child(_panel)
	_panel.hide()

func ask(question: String, options: Array) -> void:
	for c in _buttons.get_children():
		c.queue_free()
	_label.text = question
	for i in options.size():
		# Each answer is a card holding a wrapping label, so long answers grow taller instead of wider.
		var b := PanelContainer.new()
		b.custom_minimum_size = Vector2(0, 78)
		b.mouse_filter = Control.MOUSE_FILTER_STOP
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var normal := _option_style("normal")
		var hover := _option_style("hover")
		b.add_theme_stylebox_override("panel", normal)
		var l := UiStyle.label(String(options[i]), 28, UiStyle.TEXT, 750)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.size_flags_vertical = Control.SIZE_EXPAND_FILL
		b.add_child(l)
		b.mouse_entered.connect(func():
			b.add_theme_stylebox_override("panel", hover)
			l.add_theme_color_override("font_color", Color(0.08, 0.08, 0.12)))
		b.mouse_exited.connect(func():
			b.add_theme_stylebox_override("panel", normal)
			l.add_theme_color_override("font_color", UiStyle.TEXT))
		# A pick needs both the press and the release on this card, so the tap that closed the
		# dialogue before the question can't choose an answer by accident.
		var down := [false]
		b.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
				if e.pressed:
					down[0] = true
				elif down[0]:
					_pick(i))
		_buttons.add_child(b)
	active = true
	_panel.show()
	_panel.modulate.a = 0.0
	create_tween().tween_property(_panel, "modulate:a", 1.0, 0.2)

func _option_style(state: String) -> StyleBoxFlat:
	var s := UiStyle.pill(UiStyle.GLASS_LIGHT, 18)
	s.content_margin_left = 26
	s.content_margin_right = 22
	s.content_margin_top = 10
	s.content_margin_bottom = 12
	s.border_color = Color(UiStyle.GOLD, 0.45)
	s.set_border_width_all(2)
	match state:
		"hover", "pressed":
			s.bg_color = UiStyle.GOLD
			s.border_color = UiStyle.GOLD.lightened(0.3)
		"focus":
			s.draw_center = false
			s.border_color = Color(UiStyle.GOLD, 0.8)
	return s

func _pick(i: int) -> void:
	if not active:
		return
	active = false
	_panel.hide()
	chosen.emit(i)

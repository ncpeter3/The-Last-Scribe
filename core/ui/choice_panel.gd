extends CanvasLayer
## A question with big tap-friendly answer cards. Call ask(question, options); `chosen` fires
## with the index of the answer tapped. Used by family talks, sorting animals and the scroll quiz.
##
## The card sits in the middle of the screen and sizes itself to the question and answers, on any
## screen shape (wide phones, tablets). Long answers wrap; if the answers ever need more room than
## the screen has, they scroll. An answer lights up only while a finger is on it, so nothing stays
## highlighted on a touch screen.

signal chosen(index: int)

const DARK := Color(0.08, 0.08, 0.12)

var active := false
var _root: Control
var _panel: PanelContainer
var _label: RichTextLabel
var _scroll: ScrollContainer
var _buttons: VBoxContainer
var _normal: StyleBoxFlat
var _lit: StyleBoxFlat

func _ready() -> void:
	layer = 11
	_normal = _option_style(false)
	_lit = _option_style(true)
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP  # the world behind can't be tapped while asking
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.35)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UiStyle.card(Color(UiStyle.GLASS, 0.97), 26, 28))
	center.add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	_panel.add_child(box)
	_label = RichTextLabel.new()
	_label.bbcode_enabled = true
	_label.fit_content = true
	_label.scroll_active = false
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_override("normal_font", UiStyle.font(600))
	_label.add_theme_font_override("bold_font", UiStyle.font(850))
	_label.add_theme_font_override("italics_font", UiStyle.font(500))
	_label.add_theme_font_size_override("normal_font_size", 27)
	_label.add_theme_font_size_override("bold_font_size", 29)
	_label.add_theme_font_size_override("italics_font_size", 26)
	_label.add_theme_color_override("default_color", UiStyle.TEXT)
	box.add_child(_label)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(_scroll)
	_buttons = VBoxContainer.new()
	_buttons.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_buttons.add_theme_constant_override("separation", 12)
	_scroll.add_child(_buttons)
	_root.hide()
	get_viewport().size_changed.connect(_fit)

func ask(question: String, options: Array) -> void:
	for c in _buttons.get_children():
		_buttons.remove_child(c)
		c.queue_free()
	_label.text = question
	for i in options.size():
		_buttons.add_child(_option(String(options[i]), i))
	active = true
	_root.show()
	_fit()
	# Sizes settle once the wrapped text has been laid out.
	_fit.call_deferred()
	get_tree().process_frame.connect(_fit, CONNECT_ONE_SHOT)
	_panel.modulate.a = 0.0
	create_tween().tween_property(_panel, "modulate:a", 1.0, 0.2)

## Size the card to the screen: up to 1000 px wide, and never taller than the screen.
func _fit() -> void:
	if not is_inside_tree():
		return
	var screen := get_viewport().get_visible_rect().size
	var w := clampf(screen.x * 0.72, minf(640.0, screen.x - 32.0), 1000.0)
	_panel.custom_minimum_size = Vector2(w, 0)
	_label.custom_minimum_size = Vector2(w - 56.0, 0)
	_buttons.custom_minimum_size = Vector2(w - 56.0, 0)
	# Room left for the answers after the question, the card's margins and a gap at the edges.
	var room := screen.y - 48.0 - 56.0 - 16.0 - _label.get_content_height()
	var need := _buttons.get_combined_minimum_size().y
	_scroll.custom_minimum_size = Vector2(0, clampf(need, 80.0, maxf(80.0, room)))
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO if need > room else ScrollContainer.SCROLL_MODE_DISABLED

## One answer: a card with a wrapping label. A pick needs both the press and the release on the
## card, so the tap that closed the dialogue before the question can't choose an answer.
func _option(text: String, i: int) -> PanelContainer:
	var b := PanelContainer.new()
	b.custom_minimum_size = Vector2(0, 76)
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_stylebox_override("panel", _normal)
	var l := UiStyle.label(text, 27, UiStyle.TEXT, 750)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size_flags_vertical = Control.SIZE_EXPAND_FILL
	b.add_child(l)
	var down := [false]
	var light := func(on: bool):
		b.add_theme_stylebox_override("panel", _lit if on else _normal)
		l.add_theme_color_override("font_color", DARK if on else UiStyle.TEXT)
	b.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
			if e.pressed:
				down[0] = true
				light.call(true)
			else:
				light.call(false)
				if down[0] and Rect2(Vector2.ZERO, b.size).has_point(e.position):
					_pick(i)
				down[0] = false)
	b.mouse_exited.connect(func():
		down[0] = false
		light.call(false))
	return b

func _option_style(lit: bool) -> StyleBoxFlat:
	var s := UiStyle.pill(UiStyle.GOLD if lit else UiStyle.GLASS_LIGHT, 18)
	s.content_margin_left = 24
	s.content_margin_right = 22
	s.content_margin_top = 10
	s.content_margin_bottom = 12
	s.border_color = UiStyle.GOLD.lightened(0.3) if lit else Color(UiStyle.GOLD, 0.45)
	s.set_border_width_all(2)
	return s

func _pick(i: int) -> void:
	if not active:
		return
	active = false
	_root.hide()
	chosen.emit(i)

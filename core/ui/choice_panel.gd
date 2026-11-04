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
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.06, 0.04, 0.9)
	style.set_corner_radius_all(18)
	style.set_content_margin_all(24)
	_panel.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	_panel.add_child(box)
	_label = RichTextLabel.new()
	_label.bbcode_enabled = true
	_label.fit_content = true
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_size_override("normal_font_size", 28)
	_label.add_theme_font_size_override("bold_font_size", 28)
	_label.add_theme_font_size_override("italics_font_size", 28)
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
		var b := Button.new()
		b.text = String(options[i])
		b.custom_minimum_size = Vector2(0, 78)
		b.add_theme_font_size_override("font_size", 30)
		b.pressed.connect(_pick.bind(i))
		_buttons.add_child(b)
	active = true
	_panel.show()

func _pick(i: int) -> void:
	if not active:
		return
	active = false
	_panel.hide()
	chosen.emit(i)

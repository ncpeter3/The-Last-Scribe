extends CanvasLayer
## Tap-to-advance dialogue box. Lines are Dictionaries: {speaker, text, verse?}.
## A "verse" key unlocks that reference in the Scroll Journal. Scripture text itself is KJV.
## Taps are read in _input (before the UI) so the text panel can never swallow them.

signal finished

var active := false
var _lines: Array = []
var _index := 0
var _panel: PanelContainer
var _label: RichTextLabel

func _ready() -> void:
	layer = 10
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.anchor_left = 0.04
	_panel.anchor_right = 0.96
	_panel.anchor_top = 0.60
	_panel.anchor_bottom = 0.97
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.06, 0.04, 0.82)
	style.set_corner_radius_all(18)
	style.set_content_margin_all(22)
	style.border_color = Color(0.95, 0.82, 0.5, 0.45)
	style.set_border_width_all(2)
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 8
	_panel.add_theme_stylebox_override("panel", style)
	_label = RichTextLabel.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.bbcode_enabled = true
	_label.add_theme_font_size_override("normal_font_size", 30)
	_label.add_theme_font_size_override("bold_font_size", 30)
	_label.add_theme_font_size_override("italics_font_size", 26)
	_panel.add_child(_label)
	add_child(_panel)
	_panel.hide()

func play(lines: Array) -> void:
	_lines = lines
	_index = 0
	active = true
	_panel.show()
	_show_line()

func _show_line() -> void:
	var line: Dictionary = _lines[_index]
	var text: String = line.get("text", "")
	var out := "[b][color=#f2d98a]%s[/color][/b]\n%s" % [line.get("speaker", ""), text]
	if line.has("verse"):
		out += "\n\n[i][color=#cfc7b0]%s[/color][/i]" % line["verse"]
		GameState.unlock_verse(line["verse"])
	out += "\n\n[color=#9a9a9a](tap to continue)[/color]"
	_label.text = out

func _input(event: InputEvent) -> void:
	if not active:
		return
	# One tap produces both a touch and an emulated mouse event; count only the mouse one.
	var tapped: bool = event is InputEventMouseButton and event.pressed
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_SPACE, KEY_ENTER]:
		tapped = true
	if not tapped:
		return
	get_viewport().set_input_as_handled()
	_index += 1
	if _index >= _lines.size():
		active = false
		_panel.hide()
		finished.emit()
	else:
		_show_line()

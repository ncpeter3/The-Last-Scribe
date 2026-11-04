extends CanvasLayer
## Tap-to-advance dialogue box. Lines are Dictionaries: {speaker, text, verse?}.
## A "verse" key unlocks that reference in the Scroll Journal. Scripture text itself is KJV.

signal finished

var active := false
var _lines: Array = []
var _index := 0
var _panel: PanelContainer
var _label: RichTextLabel

func _ready() -> void:
	layer = 10
	_panel = PanelContainer.new()
	_panel.anchor_left = 0.05
	_panel.anchor_right = 0.95
	_panel.anchor_top = 0.62
	_panel.anchor_bottom = 0.97
	_label = RichTextLabel.new()
	_label.bbcode_enabled = true
	_label.add_theme_font_size_override("normal_font_size", 28)
	_label.add_theme_font_size_override("bold_font_size", 28)
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
	if line.has("verse"):
		text += "\n\n[i]%s[/i]" % line["verse"]
		GameState.unlock_verse(line["verse"])
	_label.text = "[b]%s[/b]\n%s\n\n[color=gray](tap to continue)[/color]" % [line.get("speaker", ""), text]

func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed):
		_index += 1
		if _index >= _lines.size():
			active = false
			_panel.hide()
			finished.emit()
		else:
			_show_line()
		get_viewport().set_input_as_handled()

extends CanvasLayer
## Tap-to-advance dialogue box. Lines are Dictionaries: {speaker, text, verse?}.
## A "verse" key unlocks that reference in the Scroll Journal. Scripture text itself is KJV.

signal finished

var _lines: Array = []
var _index := 0
var _panel: PanelContainer
var _label: RichTextLabel

func _ready() -> void:
	_panel = PanelContainer.new()
	_panel.anchor_left = 0.05
	_panel.anchor_right = 0.95
	_panel.anchor_top = 0.68
	_panel.anchor_bottom = 0.97
	_label = RichTextLabel.new()
	_label.bbcode_enabled = true
	_label.add_theme_font_size_override("normal_font_size", 28)
	_panel.add_child(_label)
	add_child(_panel)
	_panel.hide()

func play(lines: Array) -> void:
	_lines = lines
	_index = 0
	_panel.show()
	_show_line()

func _show_line() -> void:
	var line: Dictionary = _lines[_index]
	_label.text = "[b]%s[/b]\n%s" % [line.get("speaker", ""), line.get("text", "")]
	if line.has("verse"):
		GameState.unlock_verse(line["verse"])

func _unhandled_input(event: InputEvent) -> void:
	if not _panel.visible:
		return
	if (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed):
		_index += 1
		if _index >= _lines.size():
			_panel.hide()
			finished.emit()
		else:
			_show_line()
		get_viewport().set_input_as_handled()

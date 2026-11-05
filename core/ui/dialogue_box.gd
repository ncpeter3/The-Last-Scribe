extends CanvasLayer
## Tap-to-advance dialogue box. Lines are Dictionaries: {speaker, text, verse?}.
## A "verse" key unlocks that reference in the Scroll Journal. Scripture text itself is KJV.
##
## Every line is shown in full: the text types itself out, a tap while it types shows the rest,
## and a line can only be passed once it has been fully shown for a moment. There is no "skip all".
## A progress bar along the bottom fills as the conversation is read.
## Taps are read in _input (before the UI) so the text panel can never swallow them.
##
## Tests set DialogueBox.test_fast = true so each tap moves straight to the next line.

signal finished
signal line_shown(line: Dictionary)  ## each time a new line appears (scenes use it to animate the speaker)

const CHARS_PER_SEC := 55.0
const MIN_READ := 0.45  ## seconds a fully shown line stays before a tap can pass it

static var test_fast := false

var active := false
var _lines: Array = []
var _index := 0
var _shown := 0.0  # characters revealed so far in this line
var _total := 0  # characters in this line
var _read_time := 0.0  # seconds since the line was fully shown
var _accent := UiStyle.GOLD

var _box: Control
var _panel: PanelContainer
var _panel_style: StyleBoxFlat
var _chip: PanelContainer
var _chip_label: Label
var _label: RichTextLabel
var _bar: ProgressBar
var _count: Label
var _next: Control
var _bar_tween: Tween
var _time := 0.0

func _ready() -> void:
	layer = 10
	_box = Control.new()
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_box)

	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.anchor_left = 0.06
	_panel.anchor_right = 0.94
	_panel.anchor_top = 0.665
	_panel.anchor_bottom = 0.955
	_panel_style = UiStyle.card(Color(UiStyle.GLASS, 0.97), 24, 0)
	_panel_style.content_margin_left = 34
	_panel_style.content_margin_right = 28
	_panel_style.content_margin_top = 30
	_panel_style.content_margin_bottom = 16
	_panel_style.border_width_left = 7
	_panel.add_theme_stylebox_override("panel", _panel_style)
	_box.add_child(_panel)

	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 10)
	_panel.add_child(col)
	_label = RichTextLabel.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.bbcode_enabled = true
	_label.scroll_active = false
	_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_label.add_theme_font_override("normal_font", UiStyle.font(600))
	_label.add_theme_font_override("bold_font", UiStyle.font(850))
	_label.add_theme_font_override("italics_font", UiStyle.font(500))
	_label.add_theme_font_size_override("normal_font_size", 29)
	_label.add_theme_font_size_override("bold_font_size", 29)
	_label.add_theme_font_size_override("italics_font_size", 24)
	_label.add_theme_color_override("default_color", UiStyle.TEXT)
	_label.add_theme_constant_override("line_separation", 4)
	col.add_child(_label)

	var foot := HBoxContainer.new()
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	foot.add_theme_constant_override("separation", 16)
	col.add_child(foot)
	_bar = UiStyle.bar(UiStyle.GOLD, 8)
	_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foot.add_child(_bar)
	_count = UiStyle.label("", 20, UiStyle.TEXT_DIM, 700)
	_count.custom_minimum_size = Vector2(64, 0)
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	foot.add_child(_count)
	_next = NextArrow.new()
	_next.custom_minimum_size = Vector2(26, 26)
	foot.add_child(_next)

	# The speaker's name sits in a colored tag over the top edge of the box.
	_chip = PanelContainer.new()
	_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chip.anchor_left = 0.06
	_chip.anchor_top = 0.665
	_chip.offset_left = 30
	_chip.offset_top = -24
	_chip.grow_vertical = Control.GROW_DIRECTION_END
	var cs := UiStyle.pill(UiStyle.GOLD, 14)
	cs.content_margin_left = 20
	cs.content_margin_right = 20
	cs.content_margin_top = 5
	cs.content_margin_bottom = 7
	cs.shadow_color = Color(0, 0, 0, 0.35)
	cs.shadow_size = 6
	cs.shadow_offset = Vector2(0, 3)
	_chip.add_theme_stylebox_override("panel", cs)
	_chip_label = UiStyle.label("", 24, Color(0.08, 0.08, 0.12), 900)
	_chip.add_child(_chip_label)
	_box.add_child(_chip)
	_box.hide()

func play(lines: Array) -> void:
	_lines = lines
	_index = 0
	active = true
	_bar.value = 0.0
	_box.show()
	# Slide up and fade in.
	_box.modulate.a = 0.0
	_box.position.y = 40.0
	var tw := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_box, "modulate:a", 1.0, 0.22)
	tw.tween_property(_box, "position:y", 0.0, 0.28)
	_show_line()

## 0..1: how much of the whole conversation has been read.
func progress() -> float:
	if _lines.is_empty():
		return 0.0
	var line_part := 1.0 if _total == 0 else clampf(_shown / float(_total), 0.0, 1.0)
	return clampf((float(_index) + line_part) / float(_lines.size()), 0.0, 1.0)

## True once the current line is fully shown and has been up long enough to pass.
func can_advance() -> bool:
	return test_fast or (_shown >= _total and _read_time >= MIN_READ)

func _show_line() -> void:
	var line: Dictionary = _lines[_index]
	var speaker := String(line.get("speaker", ""))
	_accent = UiStyle.accent(speaker)
	_chip.visible = speaker != ""
	_chip_label.text = speaker
	(_chip.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = _accent
	_panel_style.border_color = Color(_accent, 0.9)
	UiStyle.set_bar_color(_bar, _accent)
	var out := String(line.get("text", ""))
	if speaker == "Scripture":
		out = "[i]%s[/i]" % out
	if line.has("verse"):
		out += "\n[font_size=23][color=#%s]— %s[/color][/font_size]" % [_accent.lightened(0.15).to_html(false), line["verse"]]
		GameState.unlock_verse(line["verse"])
	_label.text = out
	_total = _label.get_total_character_count()
	_shown = float(_total) if test_fast else 0.0
	_read_time = 0.0
	_label.visible_characters = -1 if test_fast else 0
	_count.text = "%d / %d" % [_index + 1, _lines.size()]
	_next.modulate.a = 0.0
	line_shown.emit(line)

func _process(delta: float) -> void:
	if not active:
		return
	_time += delta
	if _shown < _total:
		_shown = minf(float(_total), _shown + CHARS_PER_SEC * delta)
		_label.visible_characters = int(_shown)
	else:
		_label.visible_characters = -1
		_read_time += delta
	_bar.value = lerpf(_bar.value, progress(), minf(1.0, delta * 10.0))
	# The arrow fades in and bobs once the line can be passed.
	var can_go := can_advance()
	_next.modulate.a = move_toward(_next.modulate.a, 1.0 if can_go else 0.0, delta * 5.0)
	(_next as NextArrow).color = _accent
	_next.position.y = sin(_time * 6.0) * 3.0 if can_go else 0.0

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
	if _shown < _total:
		# Still typing: show the rest of the line now (it still has to be up a moment before passing).
		_shown = float(_total)
		_label.visible_characters = -1
		return
	if not can_advance():
		return
	_index += 1
	if _index >= _lines.size():
		active = false
		_bar.value = 1.0
		_box.hide()
		finished.emit()
	else:
		_show_line()

## The little "tap to go on" arrow in the corner of the box.
class NextArrow extends Control:
	var color := Color.WHITE:
		set(c):
			if c != color:
				color = c
				queue_redraw()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var s := size
		var pts := PackedVector2Array([Vector2(s.x * 0.15, s.y * 0.3), Vector2(s.x * 0.85, s.y * 0.3), Vector2(s.x * 0.5, s.y * 0.8)])
		draw_colored_polygon(pts, color)

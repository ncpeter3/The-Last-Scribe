class_name StoryIntro
extends Control
## "The story so far": six illustrated screens shown after the player picks a scribe, before
## the home in 2060. The text types itself out with a progress bar under it. Tapping makes it
## type faster but never skips it; once a page is fully shown, a tap goes to the next one.

signal finished
signal page_shown(index: int)

const GOLD := Color(0.96, 0.8, 0.45)
const TEAL := Color(0.25, 0.85, 0.8)
const CHARS_PER_SEC := 34.0
const FAST := 4.0  ## how much faster the text types while the player taps
const PAGES := [
	{"title": "The Year 2060",
	 "text": "The year is 2060. Cities glow with screens, and every word anyone reads now lives on one."},
	{"title": "The Lost Pages",
	 "text": "In the digital age, almost all written text was lost. Paper books were set aside, then recycled, then forgotten, until hardly any were left."},
	{"title": "The Restorers",
	 "text": "A few faithful people searched attics, ruins and old libraries for pages of ancient scripture, and began to piece it back together. But pieces are still missing."},
	{"title": "Corrupted",
	 "text": "The digital copies could not be trusted. Over the years, evil-doing people and governments changed them, little by little, until no one could be sure what was true."},
	{"title": "Back Through Time",
	 "text": "Someone had to go back. Back through time, to see the lost truths with their own eyes..."},
	{"title": "The Last Scribe",
	 "text": "...and to write them down by hand, in a record that can never be lost again. That scribe is you. Your family is waiting at home to say goodbye."},
]

var page := -1
var _art: StoryArt
var _art_fade: ColorRect
var _title: Label
var _text: RichTextLabel
var _bar: ProgressBar
var _hint: Label
var _segments: Array[Panel] = []
var _shown := 0.0  ## characters revealed so far (fractional)
var _fast := false
var _done_at := -1.0
var _clock := 0.0
var _leaving := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_art = StoryArt.new()
	add_child(_art)
	_art_fade = ColorRect.new()
	_art_fade.color = Color(0, 0, 0, 0)
	_art_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_art_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_art_fade)
	_build_segments()
	_build_panel()
	show_page(0)

func _build_segments() -> void:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.anchor_left = 0.5
	row.anchor_right = 0.5
	row.offset_left = -240
	row.offset_right = 240
	row.offset_top = 22
	row.offset_bottom = 28
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	for i in PAGES.size():
		var seg := Panel.new()
		seg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		seg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(seg)
		_segments.append(seg)

func _build_panel() -> void:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -560
	panel.offset_right = 560
	panel.offset_top = -24
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.offset_bottom = -24
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.05, 0.09, 0.88)
	style.set_corner_radius_all(24)
	style.border_color = Color(GOLD, 0.55)
	style.set_border_width_all(2)
	style.border_width_top = 3
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 18
	style.content_margin_left = 34
	style.content_margin_right = 34
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	style.anti_aliasing = true
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)
	_title = Label.new()
	_title.add_theme_font_override("font", load("res://shared_assets/fonts/Cinzel.ttf"))
	_title.add_theme_font_size_override("font_size", 28)
	_title.add_theme_color_override("font_color", GOLD)
	col.add_child(_title)
	_text = RichTextLabel.new()
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.fit_content = true
	_text.scroll_active = false
	_text.custom_minimum_size = Vector2(0, 96)
	_text.add_theme_font_size_override("normal_font_size", 28)
	_text.add_theme_constant_override("line_separation", 4)
	_text.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	col.add_child(_text)
	var foot := HBoxContainer.new()
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	foot.add_theme_constant_override("separation", 18)
	col.add_child(foot)
	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(0, 8)
	_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_bar.max_value = 1.0
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var back := StyleBoxFlat.new()
	back.bg_color = Color(1, 1, 1, 0.12)
	back.set_corner_radius_all(4)
	var fill := StyleBoxFlat.new()
	fill.bg_color = TEAL
	fill.set_corner_radius_all(4)
	_bar.add_theme_stylebox_override("background", back)
	_bar.add_theme_stylebox_override("fill", fill)
	foot.add_child(_bar)
	_hint = Label.new()
	_hint.add_theme_font_size_override("font_size", 22)
	_hint.add_theme_color_override("font_color", Color(0.85, 0.88, 0.92))
	_hint.custom_minimum_size = Vector2(230, 0)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	foot.add_child(_hint)

func show_page(i: int) -> void:
	page = i
	var p: Dictionary = PAGES[i]
	_title.text = p["title"]
	_text.text = p["text"]
	_text.visible_characters = 0
	_shown = 0.0
	_fast = false
	_done_at = -1.0
	_bar.value = 0.0
	_art.slide = i
	for k in _segments.size():
		var s := StyleBoxFlat.new()
		s.set_corner_radius_all(3)
		s.bg_color = GOLD if k < i else (TEAL if k == i else Color(1, 1, 1, 0.18))
		_segments[k].add_theme_stylebox_override("panel", s)
	page_shown.emit(i)

## True once every letter of this page is showing.
func is_page_done() -> bool:
	return _done_at >= 0.0

func _process(delta: float) -> void:
	_clock += delta
	var total := _text.get_total_character_count()
	if _done_at < 0.0:
		_shown += delta * CHARS_PER_SEC * (FAST if _fast else 1.0)
		_text.visible_characters = int(_shown)
		_bar.value = clampf(_shown / maxf(total, 1), 0.0, 1.0)
		_hint.text = "Reading..."
		_hint.modulate.a = 0.5
		if _shown >= total:
			_done_at = _clock
			_text.visible_characters = -1
			_bar.value = 1.0
	else:
		_hint.text = "Tap to go home  ›" if page == PAGES.size() - 1 else "Tap to continue  ›"
		_hint.modulate.a = 0.6 + 0.4 * sin(_clock * 4.0)

## A tap: speeds up the typing, or (once the page is fully shown) goes to the next page.
func tap() -> void:
	if _leaving:
		return
	if _done_at < 0.0:
		_fast = true
		return
	if _clock - _done_at < 0.35:  # a tap right as the text finishes shouldn't also turn the page
		return
	if page >= PAGES.size() - 1:
		_leaving = true
		finished.emit()
		return
	_leaving = true
	var tw := create_tween()
	tw.tween_property(_art_fade, "color:a", 1.0, 0.25)
	tw.tween_callback(func():
		show_page(page + 1)
		_leaving = false)
	tw.tween_property(_art_fade, "color:a", 0.0, 0.35)

func _gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		accept_event()
		tap()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		tap()

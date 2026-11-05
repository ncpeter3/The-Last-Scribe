class_name UiStyle
extends RefCounted
## Shared look for the game's UI cards: the dialogue box, choice panel, task tracker and speech
## bubbles. Dark "glass" cards with soft shadows, a colored accent per speaker, rounded progress bars.

const GLASS := Color(0.06, 0.08, 0.15, 0.9)
const GLASS_LIGHT := Color(0.1, 0.13, 0.22, 0.92)
const EDGE := Color(1.0, 1.0, 1.0, 0.12)
const TEXT := Color(0.97, 0.96, 0.92)
const TEXT_DIM := Color(0.72, 0.76, 0.86)
const GOLD := Color(1.0, 0.8, 0.36)
const TEAL := Color(0.3, 0.84, 0.8)
const GREEN := Color(0.45, 0.88, 0.5)
const TRACK := Color(1.0, 1.0, 1.0, 0.1)

## Accent colors for speakers. Anyone not listed gets a color picked from their name.
const SPEAKERS := {
	"Scripture": Color(1.0, 0.8, 0.36), "Codex": Color(0.45, 0.78, 1.0), "You": Color(0.3, 0.84, 0.8),
	"Scribe": Color(0.3, 0.84, 0.8), "Mom": Color(1.0, 0.55, 0.65), "Dad": Color(0.45, 0.7, 1.0),
	"Grandma": Color(0.75, 0.62, 1.0), "Adam": Color(0.55, 0.85, 0.45), "Eve": Color(0.95, 0.7, 0.45),
}
const PALETTE := [Color(1.0, 0.6, 0.4), Color(0.6, 0.85, 0.4), Color(0.5, 0.75, 1.0), Color(0.9, 0.6, 1.0),
	Color(1.0, 0.85, 0.4), Color(0.4, 0.9, 0.8)]

static var _fonts := {}

static func accent(speaker: String) -> Color:
	if SPEAKERS.has(speaker):
		return SPEAKERS[speaker]
	if speaker == "":
		return GOLD
	return PALETTE[absi(hash(speaker)) % PALETTE.size()]

## Nunito at a given weight (400 regular .. 900 black); Cinzel for titles with title = true.
static func font(weight: int = 650, title: bool = false) -> Font:
	var key := "%d%s" % [weight, title]
	if _fonts.has(key):
		return _fonts[key]
	var path := "res://shared_assets/fonts/%s.ttf" % ("Cinzel" if title else "Nunito")
	var f := FontVariation.new()
	f.base_font = load(path)
	f.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	_fonts[key] = f
	return f

static func card(bg: Color = GLASS, radius: int = 22, margin: float = 22.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(margin)
	s.border_color = EDGE
	s.set_border_width_all(1)
	s.shadow_color = Color(0, 0, 0, 0.4)
	s.shadow_size = 14
	s.shadow_offset = Vector2(0, 5)
	s.anti_aliasing = true
	return s

static func pill(c: Color, radius: int = 999) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = c
	s.set_corner_radius_all(radius)
	s.anti_aliasing = true
	return s

## A slim rounded progress bar with no percentage text.
static func bar(fill: Color, height: float = 10.0) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.min_value = 0.0
	b.max_value = 1.0
	b.step = 0.0
	b.custom_minimum_size = Vector2(0, height)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_theme_stylebox_override("background", pill(TRACK))
	b.add_theme_stylebox_override("fill", pill(fill))
	return b

static func set_bar_color(b: ProgressBar, c: Color) -> void:
	(b.get_theme_stylebox("fill") as StyleBoxFlat).bg_color = c

static func label(text: String, size: int, color: Color = TEXT, weight: int = 650) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", font(weight))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", 0)
	l.add_theme_constant_override("shadow_offset_y", 0)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	return l

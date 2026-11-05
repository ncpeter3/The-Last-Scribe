extends SceneTree
## Builds core/ui/theme.tres, the project-wide UI theme (fonts, buttons, panels).
## Run from the project folder:  godot --headless --script res://tools/ui/make_theme.gd
## Fonts: Nunito (body) and Cinzel (titles), both SIL Open Font License, in shared_assets/fonts.

const OUT := "res://core/ui/theme.tres"
const GOLD := Color(0.95, 0.82, 0.5)
const INK := Color(0.09, 0.07, 0.05, 0.9)

func _init() -> void:
	var t := Theme.new()
	var body := _font("res://shared_assets/fonts/Nunito.ttf", 650)
	var bold := _font("res://shared_assets/fonts/Nunito.ttf", 850)
	var title := _font("res://shared_assets/fonts/Cinzel.ttf", 700)
	t.default_font = body
	t.default_font_size = 28

	# Buttons: dark ink panels with a thin gold edge; gold fill when pressed.
	t.set_stylebox("normal", "Button", _box(INK, GOLD * Color(1, 1, 1, 0.55), 2))
	t.set_stylebox("hover", "Button", _box(Color(0.16, 0.12, 0.07, 0.92), GOLD, 2))
	t.set_stylebox("pressed", "Button", _box(Color(0.55, 0.42, 0.14, 0.95), GOLD, 3))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_stylebox("disabled", "Button", _box(Color(0.1, 0.1, 0.1, 0.6), Color(0.4, 0.4, 0.4, 0.5), 2))
	t.set_font("font", "Button", bold)
	t.set_color("font_color", "Button", Color(0.98, 0.94, 0.85))
	t.set_color("font_hover_color", "Button", Color(1, 0.95, 0.75))
	t.set_color("font_pressed_color", "Button", Color(1, 1, 1))
	t.set_color("font_focus_color", "Button", Color(0.98, 0.94, 0.85))

	# Panels (journal, dialogue, questions).
	t.set_stylebox("panel", "PanelContainer", _box(Color(0.08, 0.06, 0.04, 0.88), GOLD * Color(1, 1, 1, 0.45), 2, 18, 24))

	# Labels get a soft dark outline so they read over bright scenes.
	t.set_color("font_outline_color", "Label", Color(0.05, 0.03, 0.02, 0.85))
	t.set_constant("outline_size", "Label", 6)
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.35))
	t.set_constant("shadow_offset_x", "Label", 0)
	t.set_constant("shadow_offset_y", "Label", 3)

	# Titles: Cinzel, gold.
	t.add_type("HeaderLabel")
	t.set_type_variation("HeaderLabel", "Label")
	t.set_font("font", "HeaderLabel", title)
	t.set_font_size("font_size", "HeaderLabel", 34)
	t.set_color("font_color", "HeaderLabel", Color(1.0, 0.93, 0.72))
	t.set_constant("outline_size", "HeaderLabel", 9)

	# Rich text (dialogue, journal): speaker names in [b] use Cinzel.
	t.set_font("normal_font", "RichTextLabel", body)
	t.set_font("bold_font", "RichTextLabel", title)
	t.set_font("italics_font", "RichTextLabel", _font("res://shared_assets/fonts/Nunito.ttf", 600, true))
	t.set_color("default_color", "RichTextLabel", Color(0.96, 0.93, 0.86))
	t.set_font_size("normal_font_size", "RichTextLabel", 28)

	var err := ResourceSaver.save(t, OUT)
	print("Saved %s (%s)" % [OUT, error_string(err)])
	quit(0 if err == OK else 1)

func _font(path: String, weight: int, slant: bool = false) -> FontVariation:
	var f := FontVariation.new()
	f.base_font = load(path)
	f.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	if slant:
		f.variation_transform = Transform2D(Vector2(1, 0), Vector2(0.2, 1), Vector2.ZERO)
	return f

func _box(bg: Color, border: Color, bw: int, radius: int = 16, margin: int = 14) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(margin)
	s.shadow_color = Color(0, 0, 0, 0.3)
	s.shadow_size = 6
	s.shadow_offset = Vector2(0, 3)
	s.anti_aliasing = true
	return s

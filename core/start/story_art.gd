class_name StoryArt
extends Control
## Moving pictures for the opening story, drawn in flat low-poly shapes to match the game.
## `slide` picks the picture (see PICTURES); everything is drawn in the top part of the screen,
## since the narration panel covers the bottom. Pictures loop gently while the text is read.

const PICTURES := ["city", "lost_books", "restorers", "corrupted", "time", "record"]
const GOLD := Color(0.96, 0.8, 0.45)
const TEAL := Color(0.25, 0.85, 0.8)
const PARCHMENT := Color(0.9, 0.83, 0.66)
const INK := Color(0.32, 0.2, 0.1)
const VERSE := "In the beginning God created the heaven and the earth."
const GLITCH := "#%&@$*!?/<>0101"

var slide := 0:
	set(v):
		slide = v
		t = 0.0
		queue_redraw()
var t := 0.0
var _title_font: Font
var _body_font: Font

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_font = load("res://shared_assets/fonts/Cinzel.ttf")
	_body_font = load("res://shared_assets/fonts/Nunito.ttf")

func _process(delta: float) -> void:
	t += delta
	queue_redraw()

func _draw() -> void:
	match PICTURES[clampi(slide, 0, PICTURES.size() - 1)]:
		"city": _city()
		"lost_books": _lost_books()
		"restorers": _restorers()
		"corrupted": _corrupted()
		"time": _time()
		"record": _record()

# ---------- helpers ----------

func _grad(r: Rect2, top: Color, bottom: Color) -> void:
	draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
		PackedColorArray([top, top, bottom, bottom]))

func _glow(c: Vector2, radius: float, col: Color, _rings: int = 0) -> void:
	draw_texture_rect(_glow_tex(), Rect2(c - Vector2(radius, radius), Vector2(radius, radius) * 2.0), false, Color(col, col.a * 0.8))

static var _glow_cache: Texture2D

## A soft round light (white in the middle fading smoothly to clear), drawn tinted.
static func _glow_tex() -> Texture2D:
	if _glow_cache == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 0.8), Color(1, 1, 1, 0.3), Color(1, 1, 1, 0)])
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 128
		t.height = 128
		_glow_cache = t
	return _glow_cache

static func _hash(n: float) -> float:
	return fposmod(sin(n * 127.1 + 311.7) * 43758.5453, 1.0)

func _ease(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return 1.0 - pow(1.0 - x, 3.0)

## The center of the picture area (above the narration panel).
func _mid() -> Vector2:
	return Vector2(size.x / 2.0, size.y * 0.36)

# ---------- 1: the year 2060 ----------

func _city() -> void:
	var w := size.x
	var h := size.y
	var horizon := h * 0.66
	_grad(Rect2(0, 0, w, horizon), Color(0.02, 0.02, 0.08), Color(0.3, 0.12, 0.32))
	_grad(Rect2(0, horizon, w, h - horizon), Color(0.05, 0.03, 0.08), Color(0.01, 0.01, 0.02))
	for i in 90:
		var p := Vector2(_hash(i) * w, _hash(i + 500) * horizon * 0.8)
		draw_circle(p, 1.0 + _hash(i + 9) * 1.4, Color(1, 1, 1, 0.3 + 0.5 * absf(sin(t * (0.5 + _hash(i + 3) * 2.0) + i))))
	var moon := Vector2(w * 0.82, h * 0.13)
	_glow(moon, 110, Color(0.8, 0.85, 1.0, 0.6))
	draw_circle(moon, 38, Color(0.92, 0.93, 1.0))
	draw_circle(moon + Vector2(12, -6), 9, Color(0.82, 0.84, 0.95))
	# Two layers of towers: far ones pale, near ones dark with lit windows.
	for layer in 2:
		var x := -20.0
		var i := layer * 100
		while x < w + 20:
			var bw := 40.0 + _hash(i) * 70.0
			var bh := (0.12 + _hash(i + 1) * 0.28) * h * (0.75 if layer == 0 else 1.0)
			var top := horizon - bh - (60.0 if layer == 0 else 0.0)
			var col := Color(0.13, 0.1, 0.24) if layer == 0 else Color(0.04, 0.035, 0.09)
			var r := Rect2(x, top, bw, horizon - top)
			draw_rect(r, col)
			if _hash(i + 2) > 0.6:  # a pointed roof or antenna
				draw_colored_polygon(PackedVector2Array([Vector2(x, top), Vector2(x + bw, top), Vector2(x + bw / 2, top - 30)]), col)
				draw_line(Vector2(x + bw / 2, top - 30), Vector2(x + bw / 2, top - 60), col, 2.0)
				draw_circle(Vector2(x + bw / 2, top - 60), 3, Color(1, 0.3, 0.3, 0.5 + 0.5 * sin(t * 3.0 + i)))
			if layer == 1:
				for wy in range(int(top) + 12, int(horizon) - 8, 16):
					for wx in range(int(x) + 8, int(x + bw) - 8, 12):
						var hsh := _hash(wx * 0.37 + wy * 1.91)
						if hsh > 0.55:
							var on := hsh > 0.62 or sin(t * 0.7 + hsh * 50.0) > 0.0
							if on:
								draw_rect(Rect2(wx, wy, 6, 8), TEAL * Color(1, 1, 1, 0.75) if hsh > 0.8 else Color(1.0, 0.82, 0.5, 0.7))
				if _hash(i + 4) > 0.75 and bw > 70:  # a glowing screen billboard
					var br := Rect2(x + 8, top + 20, bw - 16, 40)
					var pulse := 0.6 + 0.4 * sin(t * 2.0 + i)
					draw_rect(br.grow(4), Color(TEAL, 0.15 * pulse))
					draw_rect(br, Color(0.1, 0.5, 0.55, 0.85 * pulse))
					for k in 3:
						draw_rect(Rect2(br.position.x + 6, br.position.y + 7 + k * 11, (br.size.x - 12) * (0.4 + _hash(i + k) * 0.6), 4), Color(0.8, 1, 1, 0.8))
			x += bw + 6.0
			i += 7
	# Flying cars with light trails.
	for c in 5:
		var speed := 60.0 + _hash(c + 40) * 90.0
		var y := h * (0.18 + _hash(c + 41) * 0.3)
		var dir := 1.0 if c % 2 == 0 else -1.0
		var x := fposmod(_hash(c + 42) * w + t * speed * dir, w + 200) - 100
		var trail := Vector2(-dir * 70, 0)
		draw_line(Vector2(x, y) + trail, Vector2(x, y), Color(1.0, 0.5, 0.4, 0.0), 3.0)
		draw_polygon(PackedVector2Array([Vector2(x, y - 1.5) + trail, Vector2(x, y - 1.5), Vector2(x, y + 1.5), Vector2(x, y + 1.5) + trail]),
			PackedColorArray([Color(1, 0.4, 0.4, 0), Color(1, 0.5, 0.4, 0.8), Color(1, 0.5, 0.4, 0.8), Color(1, 0.4, 0.4, 0)]))
		draw_rect(Rect2(x - 7, y - 4, 14, 7), Color(0.75, 0.8, 0.9))
		draw_circle(Vector2(x + dir * 7, y), 2.5, Color(1, 1, 0.8))
	# The year, counting up from today.
	var year := int(lerpf(2026, 2060, _ease(t / 2.2)))
	var txt := str(year)
	var fs := 150
	var tw := _title_font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pos := Vector2(w / 2.0 - tw / 2.0, h * 0.34)
	draw_string_outline(_title_font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 16, Color(0.05, 0.02, 0.08, 0.8))
	draw_string(_title_font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, GOLD)

# ---------- 2: the written word was lost ----------

func _lost_books() -> void:
	var w := size.x
	var h := size.y
	_grad(Rect2(0, 0, w, h), Color(0.09, 0.06, 0.05), Color(0.02, 0.02, 0.03))
	var c := _mid() + Vector2(-w * 0.12, 0)
	_glow(c, 330, Color(1.0, 0.75, 0.4, 0.35))
	# A tablet screen on the right where the words are going.
	var tab := Rect2(w * 0.68, h * 0.14, 190, 270)
	draw_rect(tab.grow(10), Color(0.12, 0.13, 0.17))
	draw_rect(tab, Color(0.06, 0.2, 0.24))
	_glow(tab.get_center(), 200, Color(TEAL, 0.25))
	for k in 9:
		var lw := (tab.size.x - 30) * (0.5 + _hash(k) * 0.5) * clampf(t * 0.4 - k * 0.08, 0.0, 1.0)
		draw_rect(Rect2(tab.position.x + 15, tab.position.y + 20 + k * 26, lw, 6), Color(0.7, 1, 1, 0.7))
	# The open book.
	var pw := 210.0
	var ph := 270.0
	var cover := PackedVector2Array([c + Vector2(-pw - 14, -ph / 2 + 4), c + Vector2(0, -ph / 2 + 18), c + Vector2(pw + 14, -ph / 2 + 4),
		c + Vector2(pw + 14, ph / 2 + 12), c + Vector2(0, ph / 2 + 26), c + Vector2(-pw - 14, ph / 2 + 12)])
	draw_colored_polygon(cover, Color(0.45, 0.18, 0.2))
	for side in [-1.0, 1.0]:
		var page := PackedVector2Array([c + Vector2(0, -ph / 2 + 12), c + Vector2(side * pw, -ph / 2), c + Vector2(side * pw, ph / 2),
			c + Vector2(0, ph / 2 + 14)])
		draw_colored_polygon(page, PARCHMENT if side < 0 else PARCHMENT.darkened(0.06))
		for k in 10:
			var y := -ph / 2 + 30 + k * 23.0
			var x0 := 18.0
			var x1 := pw - 18.0 - _hash(k + side) * 40.0
			var fade := 1.0
			if side > 0:  # the right page is dissolving, line by line from the bottom
				fade = clampf(1.0 - (fposmod(t * 0.25, 1.4) * 10.0 - (9 - k)) * 0.5, 0.0, 1.0)
			if fade > 0.0:
				draw_line(c + Vector2(side * x0, y + 6), c + Vector2(side * x1, y + 6), Color(INK, 0.75 * fade), 4.0)
	draw_line(c + Vector2(0, -ph / 2 + 12), c + Vector2(0, ph / 2 + 14), Color(0.5, 0.4, 0.3), 2.0)
	# Bits of the page breaking off as little squares and drifting into the screen.
	var target := tab.get_center()
	for i in 60:
		var life := fposmod(t * 0.35 + _hash(i), 1.0)
		var start := c + Vector2(30 + _hash(i + 7) * (pw - 50), -ph / 2 + 20 + _hash(i + 8) * (ph - 40))
		var mid := (start + target) / 2.0 + Vector2(0, -120 - _hash(i + 9) * 80)
		var p := start.lerp(mid, life).lerp(mid.lerp(target, life), life)
		var col := PARCHMENT.lerp(TEAL, life)
		col.a = sin(life * PI)
		var s := 4.0 + _hash(i + 10) * 6.0 * (1.0 - life)
		draw_rect(Rect2(p - Vector2(s, s) / 2, Vector2(s, s)), col)

# ---------- 3: a few people put pieces back together ----------

func _restorers() -> void:
	var w := size.x
	var h := size.y
	_grad(Rect2(0, 0, w, h), Color(0.16, 0.1, 0.06), Color(0.05, 0.03, 0.02))
	# Wood grain on the table.
	for k in 14:
		var y := h * 0.05 + k * h * 0.05
		draw_line(Vector2(0, y), Vector2(w, y + sin(k) * 10), Color(0, 0, 0, 0.12), 2.0)
	var lamp := Vector2(w * 0.16, h * 0.08)
	_glow(lamp, 420, Color(1.0, 0.75, 0.35, 0.5), 8)
	var c := _mid()
	var cols := 4
	var rows := 3
	var cw := 105.0
	var rh := 90.0
	var origin := c - Vector2(cols * cw, rows * rh) / 2.0
	var missing := [1, 6, 11]
	# Corner points, jittered so the pieces look torn.
	var pts := {}
	for gy in rows + 1:
		for gx in cols + 1:
			var j := Vector2.ZERO
			if gx > 0 and gx < cols:
				j.x = (_hash(gx * 7 + gy * 3) - 0.5) * 30
			if gy > 0 and gy < rows:
				j.y = (_hash(gx * 5 + gy * 11) - 0.5) * 26
			pts[Vector2i(gx, gy)] = origin + Vector2(gx * cw, gy * rh) + j
	draw_rect(Rect2(origin - Vector2(12, 12), Vector2(cols * cw, rows * rh) + Vector2(24, 24)), Color(0, 0, 0, 0.25))
	for gy in rows:
		for gx in cols:
			var idx := gy * cols + gx
			var poly := PackedVector2Array([pts[Vector2i(gx, gy)], pts[Vector2i(gx + 1, gy)], pts[Vector2i(gx + 1, gy + 1)], pts[Vector2i(gx, gy + 1)]])
			if idx in missing:
				var pulse := 0.5 + 0.5 * sin(t * 2.5 + idx)
				draw_colored_polygon(poly, Color(0.02, 0.02, 0.03, 0.6))
				var closed := poly.duplicate()
				closed.append(poly[0])
				for e in 4:
					draw_dashed_line(closed[e], closed[e + 1], Color(GOLD, 0.4 + 0.4 * pulse), 2.0, 8.0)
				var center := (poly[0] + poly[2]) / 2.0
				var q := "?"
				var qs := 48
				var qw := _title_font.get_string_size(q, HORIZONTAL_ALIGNMENT_LEFT, -1, qs).x
				draw_string(_title_font, center + Vector2(-qw / 2, 16), q, HORIZONTAL_ALIGNMENT_LEFT, -1, qs, Color(GOLD, 0.5 + 0.5 * pulse))
				continue
			# Each piece slides in from somewhere on the table, one after another.
			var k := _ease((t - idx * 0.12) / 0.9)
			var from := Vector2((_hash(idx + 30) - 0.5) * w * 0.9, (_hash(idx + 31) - 0.5) * h * 0.5)
			var off := from * (1.0 - k)
			var rot := (1.0 - k) * (_hash(idx + 32) - 0.5) * 2.0
			var center := (poly[0] + poly[2]) / 2.0
			var moved := PackedVector2Array()
			for p in poly:
				moved.append(center + (p - center).rotated(rot) + off)
			draw_colored_polygon(moved, PARCHMENT.darkened(_hash(idx) * 0.12))
			for line in 3:
				var a := moved[0].lerp(moved[3], 0.25 + line * 0.25) + Vector2(12, 0)
				var b := moved[1].lerp(moved[2], 0.25 + line * 0.25) - Vector2(12 + _hash(idx + line) * 30, 0)
				draw_line(a, b, Color(INK, 0.6), 3.0)
	# A magnifying glass drifting over the page.
	var g := c + Vector2(sin(t * 0.6) * 170, cos(t * 0.8) * 70)
	draw_line(g + Vector2(38, 38), g + Vector2(95, 95), Color(0.35, 0.22, 0.12), 12.0)
	draw_circle(g, 52, Color(0.8, 0.9, 1.0, 0.12))
	draw_arc(g, 52, 0, TAU, 40, Color(0.8, 0.65, 0.35), 7.0, true)
	draw_arc(g + Vector2(-14, -14), 30, PI * 1.1, PI * 1.5, 12, Color(1, 1, 1, 0.5), 3.0, true)

# ---------- 4: the digital copies were corrupted ----------

func _corrupted() -> void:
	var w := size.x
	var h := size.y
	_grad(Rect2(0, 0, w, h), Color(0.07, 0.03, 0.05), Color(0.01, 0.01, 0.02))
	var r := Rect2(w * 0.5 - 330, h * 0.07, 660, h * 0.5)
	_glow(r.get_center(), 420, Color(0.9, 0.2, 0.25, 0.3))
	draw_rect(r.grow(14), Color(0.13, 0.13, 0.16))
	draw_rect(r, Color(0.04, 0.09, 0.12))
	# The verse, with letters being changed one by one.
	var fs := 30
	var lines := ["In the beginning God created", "the heaven and the earth."]
	var step := int(t * 6.0)
	var bad := clampf(t / 6.0, 0.0, 0.55)
	for li in lines.size():
		var text: String = lines[li]
		var x := r.position.x + 40
		var y := r.position.y + 70 + li * 52
		for ci in text.length():
			var ch := text[ci]
			var col := Color(0.75, 0.95, 0.95)
			var seed := float(ci * 13 + li * 101)
			if ch != " " and _hash(seed) < bad:
				ch = GLITCH[int(_hash(seed + step) * GLITCH.length())]
				col = Color(1.0, 0.3, 0.35)
			draw_string(_body_font, Vector2(x, y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
			x += _body_font.get_string_size(text[ci], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	# More lines of text, some of them shifted and red.
	for k in 6:
		var y := r.position.y + 180 + k * 26
		var lw := (r.size.x - 80) * (0.55 + _hash(k + 3) * 0.45)
		var shift := 0.0
		var col := Color(0.6, 0.85, 0.85, 0.5)
		if _hash(k + step * 0.37) > 0.65:
			shift = (_hash(k + step) - 0.5) * 60
			col = Color(1.0, 0.25, 0.3, 0.75)
		draw_rect(Rect2(r.position.x + 40 + shift, y, lw, 9), col)
	# Glitch bands and scanlines.
	for b in 3:
		if _hash(b + step * 1.7) > 0.5:
			var by := r.position.y + _hash(b + step) * r.size.y
			draw_rect(Rect2(r.position.x, by, r.size.x, 4 + _hash(b + step + 1) * 14), Color(1, 0.2, 0.3, 0.25))
	for sy in range(int(r.position.y), int(r.end.y), 4):
		draw_line(Vector2(r.position.x, sy), Vector2(r.end.x, sy), Color(0, 0, 0, 0.18), 1.0)
	# A warning sign blinking in the corner.
	var a := 0.5 + 0.5 * sin(t * 5.0)
	var wc := r.end - Vector2(60, 60)
	draw_colored_polygon(PackedVector2Array([wc + Vector2(0, -34), wc + Vector2(32, 24), wc + Vector2(-32, 24)]), Color(1, 0.3, 0.3, 0.5 + 0.5 * a))
	draw_rect(Rect2(wc + Vector2(-3, -14), Vector2(6, 22)), Color(0.1, 0, 0))
	draw_circle(wc + Vector2(0, 15), 3.5, Color(0.1, 0, 0))
	# A crack across the glass.
	var crack := PackedVector2Array([r.position + Vector2(r.size.x * 0.62, 0), r.position + Vector2(r.size.x * 0.58, 60),
		r.position + Vector2(r.size.x * 0.66, 110), r.position + Vector2(r.size.x * 0.6, 190), r.position + Vector2(r.size.x * 0.7, r.size.y)])
	draw_polyline(crack, Color(1, 1, 1, 0.35), 2.0, true)

# ---------- 5: someone had to go back ----------

func _time() -> void:
	var w := size.x
	var h := size.y
	_grad(Rect2(0, 0, w, h), Color(0.02, 0.03, 0.08), Color(0.03, 0.02, 0.05))
	var c := _mid()
	# Stars rushing out of the center.
	for i in 120:
		var a := _hash(i) * TAU
		var life := fposmod(t * (0.25 + _hash(i + 1) * 0.35) + _hash(i + 2), 1.0)
		var d0 := pow(life, 2.0) * w * 0.7
		var d1 := d0 + 6 + life * 50
		var dir := Vector2(cos(a), sin(a))
		draw_line(c + dir * d0, c + dir * d1, Color(0.8, 0.95, 1.0, life), 1.0 + life * 2.0)
	_glow(c, 260, Color(TEAL, 0.6), 8)
	# Turning rings of the time machine.
	for k in 5:
		var rad := 60.0 + k * 38.0
		var spin := t * (0.8 - k * 0.15) * (1.0 if k % 2 == 0 else -1.0)
		var col := GOLD if k % 2 else TEAL
		for seg in 3:
			var a0 := spin + seg * TAU / 3.0
			draw_arc(c, rad, a0, a0 + TAU / 3.0 * 0.7, 24, Color(col, 0.85 - k * 0.12), 5.0 - k * 0.6, true)
	draw_circle(c, 46, Color(1, 0.97, 0.85, 0.9))
	_glow(c, 90, Color(1, 0.95, 0.75, 0.9))
	# Years spiralling into the ring, back toward the beginning.
	var years := ["2060", "1990", "1611", "AD 30", "1000 BC", "In the beginning"]
	for i in years.size():
		var life := fposmod(t * 0.22 + float(i) / years.size(), 1.0)
		var ang := life * 3.5 + i * 1.3
		var dist := (1.0 - life) * w * 0.38 + 50
		var p := c + Vector2(cos(ang), sin(ang) * 0.55) * dist
		var fs := int(16 + 22 * (1.0 - life))
		var col := Color(1, 0.95, 0.85, sin(life * PI) * 0.9)
		var tw := _title_font.get_string_size(years[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(_title_font, p - Vector2(tw / 2, 0), years[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	# The scribe, seen from behind, walking toward it.
	var s := Vector2(w / 2.0, h * 0.62)
	var bob := sin(t * 4.0) * 2.0
	var dark := Color(0.04, 0.05, 0.1)
	draw_colored_polygon(PackedVector2Array([s + Vector2(-30, 0), s + Vector2(-22, -82 + bob), s + Vector2(22, -82 + bob), s + Vector2(30, 0)]), dark)
	draw_circle(s + Vector2(0, -100 + bob), 20, dark)
	draw_rect(Rect2(s + Vector2(18, -64 + bob), Vector2(18, 26)), Color(0.12, 0.08, 0.05))
	draw_arc(s + Vector2(0, -100 + bob), 21, PI * 1.05, PI * 1.95, 12, Color(TEAL, 0.7), 2.0, true)
	draw_line(s + Vector2(-22, -80 + bob), s + Vector2(22, -40 + bob), Color(TEAL, 0.8), 4.0)

# ---------- 6: write it down, never to be lost again ----------

func _record() -> void:
	var w := size.x
	var h := size.y
	_grad(Rect2(0, 0, w, h), Color(0.13, 0.08, 0.05), Color(0.03, 0.02, 0.02))
	var candle := Vector2(w * 0.85, h * 0.36)
	_glow(candle + Vector2(0, -70), 380, Color(1.0, 0.7, 0.3, 0.5), 8)
	draw_rect(Rect2(candle + Vector2(-16, -60), Vector2(32, 110)), Color(0.93, 0.9, 0.82))
	var fl := 1.0 + sin(t * 13.0) * 0.08
	draw_colored_polygon(PackedVector2Array([candle + Vector2(0, -100 * fl), candle + Vector2(10, -72), candle + Vector2(0, -62), candle + Vector2(-10, -72)]), Color(1, 0.85, 0.4))
	draw_colored_polygon(PackedVector2Array([candle + Vector2(0, -86 * fl), candle + Vector2(5, -72), candle + Vector2(0, -66), candle + Vector2(-5, -72)]), Color(1, 1, 0.9))
	# The scroll, unrolling.
	var c := _mid() + Vector2(-w * 0.06, 0)
	var open := _ease(t / 1.4)
	var half := 300.0 * open + 20.0
	var top := c.y - 175
	var bottom := c.y + 175
	draw_rect(Rect2(c.x - half, top + 8, half * 2, bottom - top - 16), Color(0, 0, 0, 0.3))
	draw_rect(Rect2(c.x - half, top, half * 2, bottom - top), PARCHMENT)
	for side in [-1.0, 1.0]:
		var x: float = c.x + side * half
		draw_rect(Rect2(x - 16, top - 18, 32, bottom - top + 36), Color(0.55, 0.36, 0.2))
		draw_rect(Rect2(x - 16, top - 18, 10, bottom - top + 36), Color(0.68, 0.47, 0.28))
		for e in [top - 26.0, bottom + 18.0]:
			draw_rect(Rect2(x - 22, e, 44, 10), GOLD.darkened(0.2))
	if open < 0.98:
		return
	var title := "The Record"
	var tw := _title_font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 34).x
	draw_string(_title_font, Vector2(c.x - tw / 2, top + 50), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, INK)
	# Handwriting appearing line by line, with the quill at the end of the newest stroke.
	var pen := Vector2(c.x - 240, top + 90)
	var progress := (t - 1.4) * 0.45
	for line in 7:
		var amount := clampf(progress - line, 0.0, 1.0)
		if amount <= 0.0:
			break
		var y := top + 90 + line * 34.0
		var x0 := c.x - 250.0
		var length := 480.0 - _hash(line) * 120.0
		var pts := PackedVector2Array()
		var n := int(60 * amount)
		for k in n + 1:
			var x := x0 + length * amount * k / maxf(n, 1)
			pts.append(Vector2(x, y + sin(x * 0.45 + line) * 4.0 + sin(x * 0.13) * 2.0))
		if pts.size() > 1:
			draw_polyline(pts, Color(INK, 0.85), 2.5, true)
		pen = pts[pts.size() - 1]
	# The quill.
	var q := pen
	draw_colored_polygon(PackedVector2Array([q, q + Vector2(30, -40), q + Vector2(110, -150), q + Vector2(60, -60)]), Color(0.97, 0.96, 0.92))
	draw_line(q, q + Vector2(110, -150), Color(0.75, 0.72, 0.65), 2.0)

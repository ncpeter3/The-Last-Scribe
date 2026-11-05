class_name TitleStage
extends Node3D
## The 3D backdrop behind the start screen: a small stone island floating among the stars, with a
## lectern holding an open, glowing book, a quill and candles, and a slowly turning time ring
## behind it (the old book and the 2060 time machine in one picture). Golden letters drift up
## from the book. The camera sways slowly around it. Built from the low-poly kit like the rest of
## the game.

const L := preload("res://core/lowpoly/low_poly.gd")
const LETTERS := "ABCDEGHIKLMNOPRSTW"

var _cam: Camera3D
var _rings: Array[Node3D] = []
var _letters: Array[Label3D] = []
var _flames: Array[Node3D] = []
var _t := 0.0
var _orbit := 0.0  ## camera angle offset; the select screen moves it a little
var _orbit_target := 0.0
var _height_target := 2.0
var _height := 2.0
var _letter_alpha := 1.0  ## the floating letters dim behind the select screen's cards

func _ready() -> void:
	var env := WorldEnvironment.new()
	env.environment = Look.environment(_sky())
	env.environment.ambient_light_color = Color(0.45, 0.5, 0.75)
	env.environment.ambient_light_energy = 0.5
	env.environment.fog_enabled = false
	env.environment.glow_intensity = 0.9
	env.environment.glow_bloom = 0.08
	add_child(env)

	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-40, 35, 0)
	moon.light_color = Color(0.7, 0.78, 1.0)
	moon.light_energy = 0.55
	moon.shadow_enabled = true
	add_child(moon)

	_build_island()
	_build_lectern()
	_build_rings()
	_build_candles()
	Look.motes(self, Color(1.0, 0.86, 0.5), 60).emission_box_extents = Vector3(6, 3, 6)
	for i in 14:
		_spawn_letter(randf())

	_cam = Camera3D.new()
	_cam.fov = 42
	add_child(_cam)
	_place_camera()

## Swing the camera: 0 = the title view, 1 = the scribe-select view (lower and to the side).
func set_view(v: int) -> void:
	_orbit_target = 0.0 if v == 0 else 0.55
	_height_target = 2.0 if v == 0 else 1.4

func _process(delta: float) -> void:
	_t += delta
	_orbit = lerpf(_orbit, _orbit_target, 1.0 - exp(-delta * 2.0))
	_height = lerpf(_height, _height_target, 1.0 - exp(-delta * 2.0))
	_letter_alpha = lerpf(_letter_alpha, 1.0 if _orbit_target == 0.0 else 0.25, 1.0 - exp(-delta * 3.0))
	_place_camera()
	if _rings.size() >= 3:
		_rings[0].rotation.z += delta * 0.25
		_rings[1].rotation.z -= delta * 0.4
		_rings[2].rotation.y += delta * 0.6
	for f in _flames:
		f.scale = Vector3.ONE * (1.0 + sin(_t * 13.0 + f.position.x * 7.0) * 0.12)
	for l in _letters:
		var life: float = l.get_meta("life") + delta / l.get_meta("span")
		if life >= 1.0:
			_reset_letter(l, 0.0)
			continue
		l.set_meta("life", life)
		var start: Vector3 = l.get_meta("start")
		var drift: Vector3 = l.get_meta("drift")
		l.position = start + drift * life + Vector3(sin(_t + start.x * 3.0) * 0.12, life * 2.6, 0)
		l.modulate.a = sin(life * PI) * 0.9 * _letter_alpha

func _place_camera() -> void:
	var a := sin(_t * 0.12) * 0.28 + _orbit
	var r := 6.6
	_cam.position = Vector3(sin(a) * r, _height + sin(_t * 0.2) * 0.12, cos(a) * r)
	_cam.look_at(Vector3(0, 1.45, 0))

func _sky() -> Sky:
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = """
shader_type sky;
// Deep night: indigo above, a teal-violet glow at the horizon, and twinkling stars.
float hash(vec3 p) { return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453); }
void sky() {
	float h = EYEDIR.y;
	vec3 top = vec3(0.02, 0.025, 0.07);
	vec3 mid = vec3(0.07, 0.06, 0.16);
	vec3 low = vec3(0.10, 0.20, 0.28);
	vec3 c = mix(mid, top, smoothstep(0.0, 0.6, h));
	c = mix(c, low, smoothstep(0.25, -0.15, h));
	vec3 cell = floor(EYEDIR * 160.0);
	float s = hash(cell);
	if (s > 0.992) {
		float tw = 0.6 + 0.4 * sin(TIME * (1.5 + s * 4.0) + s * 40.0);
		c += vec3(0.9, 0.9, 1.0) * tw * smoothstep(-0.1, 0.2, h) * (s - 0.992) * 120.0;
	}
	COLOR = c;
}
"""
	mat.shader = sh
	var sky := Sky.new()
	sky.sky_material = mat
	return sky

func _build_island() -> void:
	var b := L.new()
	# The top: an eight-sided slab of stone, with a ring of darker flagstones.
	b.prism(Vector3(0, -0.3, 0), 3.0, 3.0, 0.3, 9, L.STONE, L.shade(L.STONE, 0.08))
	b.ring(Vector3(0, 0.0, 0), 1.3, 1.5, 18, L.shade(L.STONE, -0.18), 0.015)
	b.ring(Vector3(0, 0.0, 0), 1.5, 1.56, 18, L.glow(L.GOLD, 0.08), 0.02)
	# The rocky underside, tapering to a point, with a few hanging rocks.
	b.prism(Vector3(0, -2.6, 0), 0.4, 2.9, 2.3, 9, L.shade(L.CONCRETE, -0.25), Color(), Vector2.ONE, 0.2)
	b.prism(Vector3(0, -3.6, 0), 0.0, 0.5, 1.0, 6, L.shade(L.CONCRETE, -0.35))
	for i in 5:
		var a := TAU * i / 5.0 + 0.4
		var p := Vector3(cos(a) * 2.6, 0.0, sin(a) * 2.6)
		b.ball(p + Vector3(0, 0.08, 0), 0.32 + 0.1 * (i % 2), L.shade(L.STONE, -0.1 - 0.05 * i), 0, Vector3(1, 0.6, 1))
	# Grass tufts and moss on the edges.
	for i in 9:
		var a := TAU * i / 9.0
		b.dome(Vector3(cos(a) * 2.35, 0.0, sin(a) * 2.35), 0.28, L.LEAF_DARK if i % 2 else L.GRASS, 0, Vector3(1.2, 0.6, 1))
	add_child(b.instance())
	# Two small rocks floating nearby.
	for p in [Vector3(-4.2, 0.6, -1.5), Vector3(3.8, 2.6, -3.0)]:
		var r := L.new()
		r.prism(Vector3(0, -0.5, 0), 0.0, 0.6, 0.5, 6, L.shade(L.CONCRETE, -0.3))
		r.prism(Vector3(0, 0.0, 0), 0.6, 0.55, 0.12, 6, L.STONE)
		r.dome(Vector3(0.1, 0.12, 0), 0.22, L.GRASS, 0)
		var mi := r.instance()
		mi.position = p
		add_child(mi)

func _build_lectern() -> void:
	var b := L.new()
	# A stone step, a carved wooden stand and a slanted reading top.
	b.prism(Vector3(0, 0.0, 0), 0.7, 0.65, 0.14, 8, L.shade(L.STONE, 0.12))
	b.prism(Vector3(0, 0.14, 0), 0.32, 0.22, 0.12, 6, L.WOOD_DARK)
	b.prism(Vector3(0, 0.26, 0), 0.12, 0.1, 0.8, 6, L.WOOD)
	b.prism(Vector3(0, 1.0, 0), 0.14, 0.26, 0.12, 6, L.WOOD_DARK)
	var tilt := Transform3D(Basis(Vector3.RIGHT, 0.32), Vector3(0, 1.17, 0))
	b.at = tilt
	b.box(Vector3(0, 0, 0), Vector3(1.0, 0.06, 0.72), L.WOOD_DARK, L.WOOD, 0.02)
	# The open book: covers, then two page blocks rising toward the spine.
	b.box(Vector3(0, 0.045, 0), Vector3(0.9, 0.03, 0.62), L.BERRY)
	# A ribbon marker hanging off the front.
	b.box(Vector3(0.05, -0.02, 0.36), Vector3(0.04, 0.02, 0.16), L.TERRACOTTA)
	for side in [-1.0, 1.0]:
		b.at = tilt * Transform3D(Basis(Vector3.BACK, side * -0.09), Vector3(side * 0.215, 0.085, 0))
		b.box(Vector3.ZERO, Vector3(0.4, 0.05, 0.56), L.BONE, L.CLOUD)
		# Lines of glowing gold writing.
		for k in 6:
			var w := 0.3 - 0.06 * float((k * 3 + int(side + 1)) % 3)
			b.box(Vector3(0, 0.028, -0.2 + k * 0.075), Vector3(w, 0.006, 0.022), L.glow(L.GOLD, 0.55))
	b.at = Transform3D.IDENTITY
	# An ink pot with a quill on the stone step.
	b.prism(Vector3(0.48, 0.14, 0.2), 0.08, 0.06, 0.1, 6, L.INK)
	b.at = Transform3D(Basis(Vector3.BACK, -0.35), Vector3(0.48, 0.22, 0.2))
	b.box(Vector3(0, 0.25, 0), Vector3(0.012, 0.5, 0.012), L.CLOUD)
	b.wedge(Vector3(0, 0.36, 0), Vector3(0.012, 0.32, 0.09), L.CLOUD)
	b.at = Transform3D.IDENTITY
	add_child(b.instance())
	# Warm light from the book onto the scene.
	var glow := OmniLight3D.new()
	glow.position = Vector3(0, 1.6, 0.3)
	glow.light_color = Color(1.0, 0.8, 0.45)
	glow.light_energy = 1.6
	glow.omni_range = 4.0
	add_child(glow)

func _build_rings() -> void:
	# The time ring: a large teal ring with gold notches, a counter-turning inner ring,
	# and a small gyroscope ring on top of it.
	var holder := Node3D.new()
	holder.position = Vector3(0, 1.6, -1.6)
	add_child(holder)
	var outer := L.new()
	outer.hoop(Vector3.ZERO, 1.5, 0.06, 36, L.glow(L.TEAL, 0.25), 5)
	for i in 12:
		var a := TAU * i / 12.0
		outer.box(Vector3(cos(a), sin(a), 0) * 1.5, Vector3(0.12, 0.12, 0.2), L.GOLD)
	var inner := L.new()
	inner.hoop(Vector3.ZERO, 1.22, 0.035, 30, L.glow(L.GOLD, 0.15), 4)
	for i in 3:
		var a := TAU * i / 3.0
		inner.ball(Vector3(cos(a), sin(a), 0) * 1.22, 0.08, L.glow(L.SUN, 0.7), 0)
	var gyro := L.new()
	gyro.hoop(Vector3.ZERO, 0.95, 0.025, 24, L.glow(L.TEAL, 0.15), 4)
	for m in [outer, inner, gyro]:
		var n := Node3D.new()
		n.add_child(m.instance(false))
		holder.add_child(n)
		_rings.append(n)
	# A faint disc of light inside the ring.
	var disc := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(2.9, 2.9)
	disc.mesh = q
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, shadows_disabled;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float swirl = 0.5 + 0.5 * sin(a * 5.0 + r * 9.0 - TIME * 1.6);
	float fall = smoothstep(1.0, 0.2, r);
	ALBEDO = mix(vec3(0.1, 0.6, 0.6), vec3(0.9, 0.75, 0.35), swirl * 0.4) * fall * (0.22 + swirl * 0.18);
}
"""
	mat.shader = sh
	disc.material_override = mat
	holder.add_child(disc)
	var light := OmniLight3D.new()
	light.light_color = Color(0.35, 0.95, 0.9)
	light.light_energy = 1.4
	light.omni_range = 5.0
	holder.add_child(light)
	# The ring's stone base: two small pillars.
	var base := L.new()
	for x in [-1.25, 1.25]:
		base.prism(Vector3(x * 0.9, 0.0, -1.6), 0.2, 0.16, 0.5, 6, L.shade(L.STONE, -0.05), L.GOLD)
	add_child(base.instance())

func _build_candles() -> void:
	for p in [Vector3(-0.9, 0.0, 0.45), Vector3(-1.15, 0.0, -0.2), Vector3(0.95, 0.0, -0.35)]:
		var b := L.new()
		var h: float = 0.25 + absf(p.x) * 0.15
		b.prism(Vector3.ZERO, 0.07, 0.065, h, 6, L.CLOUD)
		b.prism(Vector3(0, h, 0), 0.008, 0.008, 0.04, 3, L.INK)
		var mi := b.instance()
		mi.position = p
		add_child(mi)
		var f := L.new()
		f.ball(Vector3(0, 0.05, 0), 0.04, L.glow(L.SUN, 1.0), 0, Vector3(1, 1.8, 1))
		var fm := f.instance(false)
		fm.position = p + Vector3(0, h + 0.04, 0)
		add_child(fm)
		_flames.append(fm)
		var lamp := OmniLight3D.new()
		lamp.position = p + Vector3(0, h + 0.15, 0)
		lamp.light_color = Color(1.0, 0.7, 0.35)
		lamp.light_energy = 0.7
		lamp.omni_range = 2.2
		add_child(lamp)

func _spawn_letter(life: float) -> void:
	var l := Label3D.new()
	l.font = preload("res://shared_assets/fonts/Cinzel.ttf")
	l.font_size = 64
	l.pixel_size = 0.004
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.shaded = false
	l.no_depth_test = false
	l.outline_size = 0
	add_child(l)
	_letters.append(l)
	_reset_letter(l, life)

func _reset_letter(l: Label3D, life: float) -> void:
	l.text = LETTERS[randi() % LETTERS.length()]
	l.modulate = Color(1.0, 0.85, 0.45, 0.0) * Color(1.6, 1.6, 1.6, 1.0)
	l.set_meta("life", life)
	l.set_meta("span", randf_range(4.0, 7.0))
	l.set_meta("start", Vector3(randf_range(-0.35, 0.35), 1.3, randf_range(-0.2, 0.25)))
	l.set_meta("drift", Vector3(randf_range(-1.4, 1.4), 0, randf_range(-0.8, 0.6)))

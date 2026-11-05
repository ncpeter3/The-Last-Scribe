class_name Look
extends RefCounted
## The game's shared look: camera angle, lighting/post-processing, ground, water and floating
## particles. Every scene (chapters, the home in 2060, ...) uses these so the whole game looks
## like one world. Everything here works on the Mobile renderer (no SSAO/SSR/volumetric fog).
## The UI look (fonts, buttons, panels) lives in core/ui/theme.tres, the project-wide theme.

## Angled 3/4 bird's-eye camera: far enough down to see faces, high enough to see around.
## Put the camera at the player's position + CAM_OFFSET, rotated CAM_PITCH degrees down.
const CAM_OFFSET := Vector3(0.6, 7.4, 7.9)
const CAM_PITCH := -46.0
const CAM_FOV := 44.0

static var _noise_cache: Dictionary = {}
static var _faded: Dictionary = {}

## A camera set up with the shared angle. Move it each frame to target + CAM_OFFSET.
static func camera() -> Camera3D:
	var cam := Camera3D.new()
	cam.fov = CAM_FOV
	cam.rotation_degrees = Vector3(CAM_PITCH, 0, 0)
	cam.far = 120.0
	return cam

## An Environment with the shared color grading: filmic tonemap, soft glow on bright things
## (sun, orbs, flames), a little extra contrast and color, and light distance fog.
## `sky` may be null for indoor scenes (then `clear` is the background color).
static func environment(sky: Sky = null, clear: Color = Color(0.05, 0.05, 0.08)) -> Environment:
	var env := Environment.new()
	if sky:
		env.background_mode = Environment.BG_SKY
		env.sky = sky
	else:
		env.background_mode = Environment.BG_COLOR
		env.background_color = clear
	# Flat ambient color (set per scene) gives clearer light/shade than ambient from the sky.
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.68, 0.8)
	env.ambient_light_energy = 0.55
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_strength = 0.9
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 0.95
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 1.12
	env.fog_enabled = true
	env.fog_density = 0.006
	env.fog_sky_affect = 0.4
	return env

## The sun: warm, angled so shadows fall toward the camera's lower left and read clearly.
static func sun() -> DirectionalLight3D:
	var s := DirectionalLight3D.new()
	s.rotation_degrees = Vector3(-48, -38, 0)
	s.light_color = Color(1.0, 0.94, 0.82)
	s.light_energy = 1.25
	s.shadow_enabled = true
	s.shadow_opacity = 0.8
	s.shadow_blur = 1.6
	s.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	s.directional_shadow_max_distance = 32.0
	return s

## Make a tall model (a tree) dissolve when it comes between the camera and the player, so it never
## blocks the view. Uses the cheap dithered distance fade; materials are shared, so each is set once.
static func fade_near_camera(model: Node) -> void:
	for g in model.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (g as MeshInstance3D).mesh
		if mesh == null:
			continue
		for i in mesh.get_surface_count():
			var m := mesh.surface_get_material(i) as BaseMaterial3D
			if m == null or _faded.has(m):
				continue
			_faded[m] = true
			m.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_DITHER
			m.distance_fade_min_distance = 6.0
			m.distance_fade_max_distance = 9.0

## Seamless noise texture, made once and shared.
static func noise(freq: float, size: int = 256, normal: bool = false) -> NoiseTexture2D:
	var key := "%s_%d_%s" % [freq, size, normal]
	if not _noise_cache.has(key):
		var n := FastNoiseLite.new()
		n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		n.frequency = freq
		n.fractal_octaves = 3
		var t := NoiseTexture2D.new()
		t.width = size
		t.height = size
		t.seamless = true
		t.noise = n
		t.as_normal_map = normal
		t.bump_strength = 4.0
		t.generate_mipmaps = true
		_noise_cache[key] = t
	return _noise_cache[key]

## Ground material. `colors` is a strip texture (one pixel per `step` meters along X starting at
## `x_start`): RGB = ground color there, A = how strongly the walking path shows (0 = no path).
## Adds soft patches of lighter/darker grass and a worn, slightly wavy dirt path along Z = 0.
static func ground_material(colors: Texture2D, x_start: float, length: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = preload("res://core/world/ground.gdshader")
	m.set_shader_parameter("colors", colors)
	m.set_shader_parameter("x_start", x_start)
	m.set_shader_parameter("x_length", length)
	m.set_shader_parameter("patches", noise(0.012, 256))
	m.set_shader_parameter("detail", noise(0.08, 256))
	return m

## Water: a moving rippled surface that catches the sun. `deep` is the color in the middle.
static func water_material(deep: Color = Color(0.12, 0.38, 0.55)) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = preload("res://core/world/water.gdshader")
	m.set_shader_parameter("deep", deep)
	m.set_shader_parameter("ripples", noise(0.03, 256, true))
	return m

## Small glowing specks drifting through the air around `parent` (pollen in a garden, dust in a
## sunbeam, stars in the dark). Cheap CPU particles, fine on phones.
static func motes(parent: Node3D, color: Color = Color(1.0, 0.95, 0.7), amount: int = 40) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = 6.0
	p.preprocess = 6.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(11, 2.0, 9)
	p.position = Vector3(0, 1.8, -2)
	p.direction = Vector3(0.3, 1, 0)
	p.spread = 60.0
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = 0.05
	p.initial_velocity_max = 0.25
	p.local_coords = false
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0))
	curve.add_point(Vector2(0.2, 1))
	curve.add_point(Vector2(0.8, 1))
	curve.add_point(Vector2(1, 0))
	p.scale_amount_curve = curve
	var q := QuadMesh.new()
	q.size = Vector2(0.07, 0.07)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = _dot()
	q.material = mat
	p.mesh = q
	parent.add_child(p)
	return p

static var _dot_tex: Texture2D

## A soft round dot (white center fading to clear) for particles.
static func _dot() -> Texture2D:
	if _dot_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 32
		t.height = 32
		_dot_tex = t
	return _dot_tex

// Low-poly water: a grid of triangles that rises and falls in slow waves. Each triangle is lit flat,
// so the surface sparkles in facets. Slightly see-through so fish show beneath it.
shader_type spatial;
render_mode blend_mix, depth_draw_always, diffuse_lambert, specular_schlick_ggx, cull_disabled;

uniform vec3 deep : source_color = vec3(0.1, 0.34, 0.52);
uniform vec3 crest : source_color = vec3(0.4, 0.72, 0.82);
uniform float height = 0.05;
uniform float opacity = 0.84;

varying float wave;

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wave = sin(w.x * 0.9 + TIME * 1.1) * 0.5 + sin(w.z * 1.3 - TIME * 0.8) * 0.35 + sin((w.x + w.z) * 0.6 + TIME * 0.6) * 0.25;
	VERTEX.y += wave * height;
}

void fragment() {
	NORMAL = normalize(cross(dFdy(VERTEX), dFdx(VERTEX)));
	ALBEDO = mix(deep, crest, clamp(wave * 0.35 + 0.25, 0.0, 1.0));
	ROUGHNESS = 0.15;
	SPECULAR = 0.6;
	ALPHA = opacity;
}

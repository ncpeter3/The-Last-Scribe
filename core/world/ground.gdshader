shader_type spatial;
// Ground for the top-down world. Colors along X come from a strip texture (see Look.ground_material);
// noise adds soft patches and fine grain so the ground never looks like flat paint, and a worn
// dirt path runs along Z = 0 wherever the strip's alpha says so.

uniform sampler2D colors : filter_linear, repeat_disable;
uniform float x_start = 0.0;
uniform float x_length = 100.0;
uniform sampler2D patches : filter_linear_mipmap, repeat_enable;
uniform sampler2D detail : filter_linear_mipmap, repeat_enable;
uniform vec3 path_color : source_color = vec3(0.72, 0.6, 0.42);
uniform float path_half_width = 1.15;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;
	vec4 strip = texture(colors, vec2((world_pos.x - x_start) / x_length, 0.5));
	float big = texture(patches, p * 0.02).r;
	float fine = texture(detail, p * 0.12).r;
	vec3 base = strip.rgb;
	// Big soft patches: a bit darker and cooler, or lighter and warmer.
	base *= mix(0.82, 1.14, big);
	base = mix(base, base * vec3(1.06, 1.04, 0.86), smoothstep(0.55, 0.8, big) * 0.6);
	// Fine grain.
	base *= mix(0.93, 1.06, fine);
	// The path: wavy edges, packed earth with a grassy, uneven border.
	float wobble = (big - 0.5) * 0.9 + (fine - 0.5) * 0.35;
	float d = abs(p.y + wobble * 0.6);
	float path = (1.0 - smoothstep(path_half_width - 0.35, path_half_width + 0.15, d)) * strip.a;
	vec3 dirt = mix(path_color * 0.85, path_color * 1.08, fine);
	dirt = mix(dirt, strip.rgb, 0.18);
	ALBEDO = mix(base, dirt, path);
	ROUGHNESS = 1.0;
	SPECULAR = 0.2;
}

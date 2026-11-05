shader_type spatial;
// Simple phone-friendly water: two scrolling ripple normal maps catch the sun, the color lightens
// toward the edges of the pool and a gentle shimmer moves across it. Opaque, so it's cheap.

uniform vec3 deep : source_color = vec3(0.12, 0.38, 0.55);
uniform vec3 shallow : source_color = vec3(0.35, 0.7, 0.78);
uniform sampler2D ripples : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float speed = 0.05;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz * 0.12;
	vec2 t = vec2(TIME * speed, TIME * speed * 0.6);
	vec3 n1 = texture(ripples, p + t).rgb;
	vec3 n2 = texture(ripples, p * 1.7 - t * 1.3).rgb;
	NORMAL_MAP = normalize(n1 + n2 - 1.0) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 1.2;
	// Lighter near the edges of the mesh (UV 0..1 across a box/plane face).
	vec2 e = min(UV, 1.0 - UV);
	float edge = 1.0 - smoothstep(0.0, 0.12, min(e.x, e.y));
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = mix(deep, shallow, clamp(edge * 0.7 + fres * 0.35, 0.0, 1.0));
	ROUGHNESS = 0.08;
	METALLIC = 0.0;
	SPECULAR = 0.7;
}

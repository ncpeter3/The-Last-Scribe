// Shared material for the low-poly kit: flat colors from the mesh's vertex colors.
// Vertex alpha below 1 means "glow": the color is also emitted, brighter the lower the alpha.
shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx;

uniform float glow_power = 5.0;

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.92;
	SPECULAR = 0.25;
	float g = 1.0 - COLOR.a;
	EMISSION = COLOR.rgb * g * glow_power;
}

// See-through version of the low-poly material, for glass and holograms.
// Vertex alpha is used as glow strength here too; every face is drawn half see-through.
shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_never, diffuse_lambert, specular_schlick_ggx;

uniform float opacity = 0.42;
uniform float glow_power = 3.0;

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.1;
	float g = 1.0 - COLOR.a;
	EMISSION = COLOR.rgb * g * glow_power;
	ALPHA = opacity + g * 0.2;
}

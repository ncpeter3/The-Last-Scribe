// See-through version of flat_color.gdshader (light beams, glows).
// so even round shapes look cut and faceted like the rest of the low-poly world.
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, diffuse_lambert, specular_schlick_ggx;

uniform vec4 color : source_color = vec4(1.0);
uniform float glow = 0.0;

void fragment() {
	NORMAL = normalize(cross(dFdy(VERTEX), dFdx(VERTEX)));
	ALBEDO = color.rgb;
	ROUGHNESS = 0.9;
	ALPHA = color.a;
	SPECULAR = 0.25;
	EMISSION = color.rgb * glow;
}

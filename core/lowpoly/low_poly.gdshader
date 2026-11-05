// Shared material for the low-poly kit: flat colors from the mesh's vertex colors.
// Vertex alpha below 1 means "glow": the color is also emitted, brighter the lower the alpha.
// fade_near > 0 dissolves the mesh (dithered) when it gets that close to the camera, so trees
// between the camera and the scribe never block the view.
shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx;

uniform float glow_power = 5.0;
uniform float fade_near = 0.0;

void fragment() {
	if (fade_near > 0.0) {
		float d = length(VERTEX);
		float keep = clamp((d - fade_near) / 3.0, 0.0, 1.0);
		// 4x4 ordered dither.
		int x = int(FRAGCOORD.x) % 4;
		int y = int(FRAGCOORD.y) % 4;
		float m[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
		if (keep < (m[y * 4 + x] + 0.5) / 16.0) {
			discard;
		}
	}
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.92;
	SPECULAR = 0.25;
	float g = 1.0 - COLOR.a;
	EMISSION = COLOR.rgb * g * glow_power;
}

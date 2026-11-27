shader_type spatial;
// Leaves, grass, hedges: alpha-cut cards that move in the wind. The whole plant leans with slow gusts
// (more the higher up it is), and every leaf flutters on its own. Sunlight comes through the leaves
// from behind (backlight), the way real foliage glows.
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 albedo : source_color = vec4(1.0);
uniform float alpha_cut = 0.45;
uniform float roughness = 0.75;
uniform float wind = 1.0;            // the zone's wind: 0 = dead still
uniform float sway_height = 8.0;     // the plant's height in its own units (how far up the sway grows)
uniform float sway = 0.22;           // lean at the very top, metres
uniform float flutter = 0.035;       // each leaf's own shiver, metres
uniform vec3 backlight_color : source_color = vec3(0.32, 0.38, 0.12);
uniform float tint_vary = 0.12;      // plant-to-plant colour variety

varying float v_vary;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float phase = dot(origin.xz, vec2(0.137, 0.211));
	float bend = pow(clamp(VERTEX.y / sway_height, 0.0, 1.0), 1.6);
	float gust = sin(TIME * 0.83 + phase) * 0.6 + sin(TIME * 1.71 + phase * 1.7) * 0.28 + sin(TIME * 0.27 + phase * 0.4) * 0.5;
	vec3 lean = vec3(1.0, 0.0, 0.35) * (gust * 0.5 + 0.55) * sway * bend * wind;
	float f = sin(TIME * 5.3 + wp.x * 2.1 + wp.z * 1.7 + VERTEX.y * 3.1) + sin(TIME * 7.9 + wp.z * 3.3 - wp.y * 2.0) * 0.6;
	vec3 shiver = vec3(f, f * 0.6, -f * 0.8) * flutter * wind * (0.35 + bend);
	// back into the plant's own space (lean and shiver are in world metres; undo its scale and turn)
	mat3 inv = inverse(mat3(MODEL_MATRIX[0].xyz, MODEL_MATRIX[1].xyz, MODEL_MATRIX[2].xyz));
	VERTEX += inv * (lean + shiver);
	v_vary = hash(origin.xz * 0.37) - 0.5;
}

void fragment() {
	vec4 t = texture(albedo_tex, UV);
	ALBEDO = t.rgb * albedo.rgb * (1.0 + v_vary * tint_vary * vec3(0.6, 1.0, 0.4));
	ALPHA = t.a * albedo.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_cut;
	ROUGHNESS = roughness;
	SPECULAR = 0.3;
	BACKLIGHT = backlight_color;
}

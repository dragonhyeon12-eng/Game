shader_type spatial;
// Bark that bends with its leaves (the same slow lean as foliage.gdshader, without the flutter), so a tree
// sways as one thing, trunk to twig.
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 albedo : source_color = vec4(1.0);
uniform float roughness = 0.9;
uniform float use_normal = 1.0;
uniform float wind = 1.0;
uniform float sway_height = 8.0;
uniform float sway = 0.22;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	float phase = dot(origin.xz, vec2(0.137, 0.211));
	float bend = pow(clamp(VERTEX.y / sway_height, 0.0, 1.0), 1.6);
	float gust = sin(TIME * 0.83 + phase) * 0.6 + sin(TIME * 1.71 + phase * 1.7) * 0.28 + sin(TIME * 0.27 + phase * 0.4) * 0.5;
	vec3 lean = vec3(1.0, 0.0, 0.35) * (gust * 0.5 + 0.55) * sway * bend * wind;
	mat3 inv = inverse(mat3(MODEL_MATRIX[0].xyz, MODEL_MATRIX[1].xyz, MODEL_MATRIX[2].xyz));
	VERTEX += inv * lean;
}

void fragment() {
	ALBEDO = texture(albedo_tex, UV).rgb * albedo.rgb;
	ROUGHNESS = roughness;
	if (use_normal > 0.5) {
		NORMAL_MAP = texture(normal_tex, UV).rgb;
	}
}

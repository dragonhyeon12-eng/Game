shader_type spatial;
// Pool water: transparent, glassy, gently moving. Reflections come from screen-space reflections
// (high quality) and the environment; the colour deepens toward the edges of view (fresnel).

render_mode blend_mix, depth_draw_always, cull_disabled, specular_schlick_ggx;

uniform vec4 shallow : source_color = vec4(0.25, 0.7, 0.75, 1.0);
uniform vec4 deep : source_color = vec4(0.02, 0.12, 0.2, 1.0);
uniform float clarity = 0.55;      // lower = more see-through
uniform float wave_speed = 0.35;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xz;
	float t = TIME * wave_speed;
	// two layers of drifting ripples -> normal
	float e = 0.08;
	float h0 = vnoise(p * 1.3 + vec2(t, t * 0.6)) + 0.5 * vnoise(p * 3.1 - vec2(t * 1.3, t * 0.4));
	float hx = vnoise((p + vec2(e, 0.0)) * 1.3 + vec2(t, t * 0.6)) + 0.5 * vnoise((p + vec2(e, 0.0)) * 3.1 - vec2(t * 1.3, t * 0.4));
	float hz = vnoise((p + vec2(0.0, e)) * 1.3 + vec2(t, t * 0.6)) + 0.5 * vnoise((p + vec2(0.0, e)) * 3.1 - vec2(t * 1.3, t * 0.4));
	vec3 n_world = normalize(vec3((h0 - hx) * 0.6, 1.0, (h0 - hz) * 0.6));
	NORMAL = normalize((VIEW_MATRIX * vec4(n_world, 0.0)).xyz);

	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = mix(shallow.rgb, deep.rgb, 0.55 + 0.45 * fres);
	ALPHA = clamp(clarity + fres * 0.4, 0.0, 0.95);
	ROUGHNESS = 0.03;
	METALLIC = 0.1;
	SPECULAR = 0.7;
}

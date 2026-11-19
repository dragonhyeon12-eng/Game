shader_type spatial;
// LOW graphics water: the same look from a distance, without reading back the screen or the depth
// buffer (on phones and in the browser that copy is the most expensive thing in a frame). A see-through
// tinted surface that ripples, darkens with clarity and reflects at grazing angles. Same parameters
// as water.gdshader, so the zones can set either.

render_mode blend_mix, depth_draw_opaque, cull_disabled, specular_schlick_ggx;

uniform vec4 shallow : source_color = vec4(0.8, 0.98, 1.0, 1.0);
uniform vec4 deep : source_color = vec4(0.03, 0.27, 0.38, 1.0);
uniform float clarity = 0.55;
uniform float absorb = 0.14;
uniform float wave_speed = 0.35;
uniform float wave_height = 0.025;
uniform float refraction = 0.035;
uniform float foam_amount = 1.0;

varying vec3 wpos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}
float ripples(vec2 p, float t) {
	return vnoise(p * 0.9 + vec2(t * 0.8, t * 0.5)) * 0.65 + vnoise(p * 2.3 - vec2(t * 1.2, t * 0.3)) * 0.35;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += (ripples(wpos.xz * 0.6, TIME * wave_speed) - 0.5) * wave_height * 2.0;
}

void fragment() {
	float t = TIME * wave_speed;
	vec2 p = wpos.xz;
	float h0 = ripples(p, t);
	float hx = ripples(p + vec2(0.05, 0.0), t);
	float hz = ripples(p + vec2(0.0, 0.05), t);
	vec3 n_world = normalize(vec3((h0 - hx) * 0.9, 1.0, (h0 - hz) * 0.9));
	if (!FRONT_FACING) {
		n_world = -n_world;
	}
	NORMAL = normalize((VIEW_MATRIX * vec4(n_world, 0.0)).xyz);
	float fres = 0.02 + 0.98 * pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 5.0);
	if (!FRONT_FACING) {
		fres = mix(fres, 0.9, smoothstep(0.35, 0.15, dot(NORMAL, VIEW)));
	}
	float murk = clamp(0.35 + clarity * 0.5 + absorb * 0.5, 0.0, 0.95);
	vec3 tint = mix(shallow.rgb, deep.rgb, murk);
	ALBEDO = deep.rgb * 0.2;
	EMISSION = tint * 0.35 * (1.0 - fres);
	ROUGHNESS = 0.05;
	SPECULAR = 0.6;
	ALPHA = clamp(mix(murk, 1.0, fres), 0.3, 0.97);
}

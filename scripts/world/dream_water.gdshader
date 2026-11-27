shader_type spatial;
// Still, clear water whose reflection is of a slightly different sky: warmer, later in the day, its clouds
// drifting the other way, and the faint rings that aren't in the real one. Ripples spread from where the
// fountain's water falls. Seen straight down it's clear; at a glancing angle it's all reflection.
render_mode blend_mix, depth_draw_always, cull_back, unshaded, shadows_disabled;

uniform vec3 body : source_color = vec3(0.16, 0.36, 0.38);
uniform vec3 zenith : source_color = vec3(0.24, 0.42, 0.78);
uniform vec3 horizon : source_color = vec3(0.98, 0.84, 0.7);
uniform float ripple_r = 0.0;     // radius of the falling water's ripple ring source (0 = none)
uniform float clarity = 0.55;

varying vec3 wpos;

void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }

float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1, 0)), f.x), mix(h(i + vec2(0, 1)), h(i + vec2(1, 1)), f.x), f.y); }
float fbm(vec2 p) { float v = 0.0; float a = 0.5; for (int i = 0; i < 4; i++) { v += a * n(p); p *= 2.03; a *= 0.5; } return v; }

vec3 other_sky(vec3 d) {
	float hh = max(d.y, 0.0);
	vec3 c = mix(horizon, zenith, pow(hh, 0.6));
	vec2 uv = d.xz / (hh + 0.1);
	float cl = fbm(uv * 1.1 - vec2(TIME * 0.006, TIME * 0.002));      // (the real clouds drift the other way)
	c = mix(c, vec3(1.0, 0.93, 0.88), smoothstep(0.52, 0.8, cl) * 0.85);
	// a ring of pale light that isn't up there
	float r = dot(d, normalize(vec3(0.25, 0.62, -0.75))) - 0.58;
	c += vec3(0.9, 0.95, 1.0) * exp(-pow(r / 0.006, 2.0)) * 0.6;
	return c;
}

void fragment() {
	vec3 view_w = normalize(CAMERA_POSITION_WORLD - wpos);
	vec2 q = wpos.xz;
	float rr = length(q - NODE_POSITION_WORLD.xz);
	vec2 rip = vec2(n(q * 3.0 + TIME * 0.4), n(q * 3.0 - TIME * 0.37)) - 0.5;
	if (ripple_r > 0.0) {
		float wave = sin((rr - ripple_r) * 14.0 - TIME * 5.0) * exp(-abs(rr - ripple_r) * 0.9);
		rip += normalize(q - NODE_POSITION_WORLD.xz + 0.0001) * wave * 0.6;
	}
	vec3 nrm = normalize(vec3(rip.x * 0.06, 1.0, rip.y * 0.06));
	float f = 0.03 + 0.97 * pow(1.0 - clamp(dot(view_w, nrm), 0.0, 1.0), 5.0);
	vec3 refl = other_sky(reflect(-view_w, nrm));
	vec3 col = mix(body, refl, clamp(f * 1.6 + 0.12, 0.0, 1.0));
	ALBEDO = col;
	ALPHA = mix(clarity, 0.97, f);
}

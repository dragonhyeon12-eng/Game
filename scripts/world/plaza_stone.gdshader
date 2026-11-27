shader_type spatial;
// Polished pale stone paving, as if just rained on: big square slabs (each a slightly different stone), fine
// grout, a soft cloudy veining, and a near-mirror finish that catches the sky and the sun.
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 stone : source_color = vec3(0.78, 0.78, 0.76);
uniform float slab = 1.4;
uniform float gloss = 0.06;

varying vec3 wpos;

void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }

float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1, 0)), f.x), mix(h(i + vec2(0, 1)), h(i + vec2(1, 1)), f.x), f.y); }

void fragment() {
	vec2 p = wpos.xz / slab;
	vec2 cell = floor(p);
	vec2 f = fract(p);
	float fw = fwidth(p.x) + fwidth(p.y);
	float grout = 1.0 - smoothstep(0.0, 0.012 + fw, min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y)));
	float tone = h(cell) * 0.12 - 0.06;
	float cloud = n(wpos.xz * 1.3 + cell * 7.0) * 0.6 + n(wpos.xz * 4.1) * 0.4;
	float vein = smoothstep(0.03, 0.0, abs(n(wpos.xz * 0.9 + cell * 3.0) - 0.5)) * 0.08;
	vec3 c = stone * (1.0 + tone + (cloud - 0.5) * 0.08) - vein;
	ALBEDO = mix(c, stone * 0.55, grout);
	ROUGHNESS = mix(gloss + h(cell + 3.0) * 0.05, 0.7, grout);
	SPECULAR = 0.6;
}

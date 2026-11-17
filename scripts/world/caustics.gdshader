shader_type spatial;
// Caustics: the bright net of light that ripples across the bottom of a pool. Drawn as an additive
// layer just above the floor; two drifting Voronoi patterns multiplied give the familiar shifting cells.

render_mode blend_add, unshaded, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 color : source_color = vec4(0.55, 0.9, 1.0, 1.0);
uniform float strength = 0.35;
uniform float scale = 1.6;
uniform float speed = 0.35;

varying vec3 wpos;

vec2 hash2(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453);
}
float voronoi_edge(vec2 x, float t) {
	vec2 n = floor(x);
	vec2 f = fract(x);
	float f1 = 8.0;
	float f2 = 8.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 o = hash2(n + g);
			o = 0.5 + 0.45 * sin(t + 6.2831 * o);
			float d = length(g + o - f);
			if (d < f1) { f2 = f1; f1 = d; } else if (d < f2) { f2 = d; }
		}
	}
	return f2 - f1;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float t = TIME * speed;
	vec2 p = wpos.xz * scale;
	float a = 1.0 - smoothstep(0.0, 0.18, voronoi_edge(p + vec2(t * 0.3, t * 0.2), t));
	float b = 1.0 - smoothstep(0.0, 0.22, voronoi_edge(p * 1.35 - vec2(t * 0.25, -t * 0.15) + 3.7, t * 1.3));
	float c = pow(a * 0.6 + b * 0.6, 2.0);
	ALBEDO = color.rgb * c * strength;
}

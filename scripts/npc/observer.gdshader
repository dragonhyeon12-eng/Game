shader_type spatial;
// The Observer: pure black, unlit, untouched by fog - and wrong. Horizontal slices of him shear
// sideways, blocks of him drop out, and a thin red/cyan fringe flashes at his edges.
// `glitch` (0..1) is driven by the Observer script: low while idle, high when seen and when vanishing.

render_mode unshaded, fog_disabled, cull_back, depth_draw_opaque;

uniform float glitch = 0.15;
uniform float seed = 0.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float tick = floor(TIME * 16.0 + seed);
	// shear thin horizontal bands of the body sideways for a frame or two
	float band = floor(world.y * 7.0);
	float r = hash(vec2(band, tick));
	vec3 off = vec3(0.0);
	if (r < glitch * 0.45) {
		off.x = (hash(vec2(band + 3.1, tick)) - 0.5) * 0.35 * glitch;
		off.z = (hash(vec2(band + 7.7, tick)) - 0.5) * 0.25 * glitch;
	}
	// rare whole-body stutter
	if (hash(vec2(tick, seed)) < glitch * 0.12) {
		off.y += (hash(vec2(tick, 1.0)) - 0.5) * 0.15;
	}
	VERTEX += inverse(mat3(MODEL_MATRIX)) * off;
}

void fragment() {
	float tick = floor(TIME * 16.0 + seed);
	// blocky dropout
	vec2 cell = floor(FRAGCOORD.xy / 7.0);
	if (hash(cell + vec2(tick * 1.37, seed)) < glitch * 0.22) {
		discard;
	}
	float rim = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 4.0);
	float flash = step(hash(vec2(tick, 5.0 + seed)), glitch * 0.8);
	vec3 fringe = mix(vec3(0.7, 0.0, 0.05), vec3(0.0, 0.6, 0.7), step(0.5, hash(vec2(tick, cell.y))));
	ALBEDO = fringe * rim * flash * 0.9;
}

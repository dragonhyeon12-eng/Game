shader_type spatial;
// Water in motion on a mesh: streaks that run along the mesh's V (down a cascade sheet, or up a jet),
// thicker in the middle, fraying at the ends; bright where the sun catches it.
render_mode blend_mix, depth_draw_never, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform vec4 tint : source_color = vec4(0.85, 0.95, 1.0, 1.0);
uniform float speed = 1.4;        // + down the sheet (V grows), - up it
uniform float streaks = 60.0;
uniform float opacity = 0.75;

float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1, 0)), f.x), mix(h(i + vec2(0, 1)), h(i + vec2(1, 1)), f.x), f.y); }

void fragment() {
	float v = UV.y;
	float s = n(vec2(UV.x * streaks, v * 3.0 - TIME * speed)) * 0.65 + n(vec2(UV.x * streaks * 2.7, v * 7.0 - TIME * speed * 1.6)) * 0.35;
	float a = smoothstep(0.3, 0.75, s);
	a *= smoothstep(0.0, 0.12, v) * (1.0 - smoothstep(0.75, 1.0, v) * 0.6);
	ALBEDO = tint.rgb;
	EMISSION = tint.rgb * 0.25 * a;
	ROUGHNESS = 0.08;
	SPECULAR = 0.8;
	ALPHA = clamp(a * opacity, 0.0, 1.0);
}

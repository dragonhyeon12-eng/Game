shader_type canvas_item;
// DREAD post-processing: vignette, desaturation, film grain and a faint colour fringe.
// Driven every frame by Game (scaled by the visual-intensity accessibility setting).

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float vignette = 0.25;
uniform float grain = 0.0;
uniform float desat = 0.0;
uniform float fringe = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 c = uv - 0.5;
	vec3 col;
	if (fringe > 0.001) {
		vec2 o = c * fringe * 0.012;
		col = vec3(texture(screen_tex, uv + o).r, texture(screen_tex, uv).g, texture(screen_tex, uv - o).b);
	} else {
		col = texture(screen_tex, uv).rgb;
	}
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(lum), clamp(desat, 0.0, 1.0));
	float v = 1.0 - smoothstep(0.3, 0.85, length(c * vec2(1.15, 1.0))) * clamp(vignette, 0.0, 1.0);
	col *= v;
	float n = fract(sin(dot(uv * (1.0 + fract(TIME)), vec2(12.9898, 78.233))) * 43758.5453);
	col += (n - 0.5) * grain * 0.3;
	COLOR = vec4(col, 1.0);
}

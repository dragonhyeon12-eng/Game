shader_type canvas_item;
// LOW graphics version of post.gdshader: the vignette and the grain, laid over the picture instead of
// re-reading it (copying the whole screen every frame is slow on phones). No desaturation or fringe.

uniform float vignette = 0.25;
uniform float grain = 0.0;
uniform float desat = 0.0;
uniform float fringe = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 c = uv - 0.5;
	float dark = smoothstep(0.3, 0.85, length(c * vec2(1.15, 1.0))) * clamp(vignette, 0.0, 1.0);
	float n = fract(sin(dot(uv * (1.0 + fract(TIME)), vec2(12.9898, 78.233))) * 43758.5453);
	float g = (n - 0.5) * grain * 0.3;
	// darken toward the edges; the grain flecks dark or light
	float a = clamp(dark + abs(g), 0.0, 1.0);
	vec3 col = g > 0.0 ? vec3(abs(g) / max(a, 0.001)) : vec3(0.0);
	COLOR = vec4(col, a);
}

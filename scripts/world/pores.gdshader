shader_type spatial;
// PATTERN's holes: each a little cup (dark throat, raised rim, wet), drawn by the thousand from one MultiMesh.
// They breathe: every pit slowly opens and closes, out of step with its neighbours.

uniform float pulse = 0.12;        // how far they open (scaled down by the visual-intensity setting)
uniform float speed = 0.9;

varying float v_open;

void vertex() {
	// a phase from where this pit is in the world: neighbours drift in and out of step
	vec3 at = MODEL_MATRIX[3].xyz;
	float ph = at.x * 3.7 + at.y * 2.9 + at.z * 3.1;
	float o = sin(TIME * speed + ph) * 0.5 + 0.5;
	v_open = o;
	// the throat widens (the inner rings move out), the rim stays put
	float r = length(VERTEX.xz);
	float inner = 1.0 - smoothstep(0.3, 0.5, r);
	VERTEX.xz *= 1.0 + pulse * o * inner;
	VERTEX.y -= pulse * 0.05 * o * inner;
}

void fragment() {
	vec3 c = COLOR.rgb;
	ALBEDO = c * (1.0 - 0.25 * v_open * step(c.r, 0.2));   // deeper when open
	ROUGHNESS = 0.26;
	SPECULAR = 0.65;
}

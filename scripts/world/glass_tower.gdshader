shader_type spatial;
// A glass skyscraper: curtain wall in world space (floors and mullions that never stretch), blue-green
// mirror glass that reflects the sky, a darker spandrel band at every floor, a few panes a shade off.
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 glass : source_color = vec3(0.28, 0.42, 0.55);
uniform vec3 frame : source_color = vec3(0.72, 0.75, 0.78);
uniform float floor_h = 3.8;
uniform float bay = 1.5;

varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void fragment() {
	if (abs(wnrm.y) > 0.5) {         // the roof
		ALBEDO = vec3(0.5, 0.52, 0.54);
		ROUGHNESS = 0.8;
	} else {
		float u = abs(wnrm.x) > abs(wnrm.z) ? wpos.z : wpos.x;
		vec2 g = vec2(u / bay, wpos.y / floor_h);
		vec2 f = fract(g);
		vec2 fw = fwidth(g);
		float mull = 1.0 - smoothstep(0.0, 0.035 + fw.x, min(f.x, 1.0 - f.x));
		float band = smoothstep(0.0, 0.03 + fw.y, f.y) * (1.0 - smoothstep(0.16, 0.19 + fw.y, f.y));
		float pane = h(floor(g)) * 0.1;
		vec3 gl = glass * (0.9 + pane);
		vec3 c = mix(gl, glass * 0.45, band);
		c = mix(c, frame, mull);
		ALBEDO = c;
		METALLIC = mix(0.85, 0.5, max(mull, band));
		ROUGHNESS = mix(0.04 + pane * 0.3, 0.35, max(mull, band));
	}
}

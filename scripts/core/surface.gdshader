shader_type spatial;
// Procedural surfaces for every built-in material: tiles, wallpaper, wood, carpet, concrete, plaster,
// grass, fabric. Patterns are projected in world space (along the dominant normal axis), so they never
// stretch when a box is scaled. Base colour = per-instance MultiMesh colour (COLOR) x albedo.

render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 albedo : source_color = vec4(1.0);
uniform vec4 accent : source_color = vec4(0.5, 0.5, 0.5, 1.0);   // grout, seams, stains
uniform int pattern = 0;
uniform float scale = 1.0;
uniform float roughness_base = 0.85;
uniform float metallic_base = 0.0;
uniform float bump = 0.4;

varying vec3 wpos;
varying vec3 wnrm;
varying vec3 base_col;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	base_col = COLOR.rgb;
}

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * vnoise(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

// planar projection on the dominant axis; "up" = world Y on walls
vec2 plane_uv(out int axis) {
	vec3 n = abs(wnrm);
	if (n.y > n.x && n.y > n.z) { axis = 1; return wpos.xz; }
	if (n.x > n.z) { axis = 0; return vec2(wpos.z, wpos.y); }
	axis = 2;
	return vec2(wpos.x, wpos.y);
}

void fragment() {
	int axis;
	vec2 uv = plane_uv(axis) * scale;
	vec3 c = base_col * albedo.rgb;
	float rough = roughness_base;
	float h = 0.0;                    // height, used for a little fake relief
	float n = fbm(uv * 1.7);

	if (pattern == 0) {               // plain, with gentle mottling
		c *= 0.93 + 0.14 * n;
	} else if (pattern == 1) {        // tiles with grout
		vec2 g = fract(uv);
		float edge = min(min(g.x, 1.0 - g.x), min(g.y, 1.0 - g.y));
		float grout = 1.0 - smoothstep(0.025, 0.05, edge);
		float tone = hash(floor(uv)) * 0.08;
		c = mix(c * (0.96 + tone - 0.04), accent.rgb, grout);
		c *= 0.94 + 0.08 * n;
		rough = mix(roughness_base, 0.95, grout);
		h = -grout;
	} else if (pattern == 2) {        // old wallpaper: stripes, a faint motif, damp stains near the floor
		float stripe = smoothstep(0.42, 0.5, abs(fract(uv.x * 2.0) - 0.5));
		float motif = sin(uv.x * 25.13) * sin(uv.y * 18.85);
		c *= 0.93 + 0.06 * stripe + 0.035 * motif;
		float stain = smoothstep(0.55, 0.82, fbm(uv * 0.35 + vec2(3.0, 7.0)));
		float damp = (1.0 - smoothstep(0.0, 0.6, wpos.y)) * 0.25;
		c = mix(c, c * accent.rgb, clamp(stain * 0.45 + damp, 0.0, 0.7));
		rough = 0.9;
	} else if (pattern == 3) {        // wood: grain along one axis + plank seams
		vec2 w = axis == 1 ? uv : uv.yx;
		float grain = fbm(vec2(w.x * 0.6, w.y * 14.0));
		float rings = smoothstep(0.3, 0.7, fract(grain * 6.0));
		float plank = 1.0 - smoothstep(0.0, 0.03, abs(fract(w.y * 2.5) - 0.5) * 2.0 - 0.94);
		c *= 0.9 + 0.12 * rings + 0.06 * n;
		c = mix(c, c * 0.45, plank * step(0.5, float(axis == 1)));
		rough = roughness_base + 0.1 * rings;
		h = rings * 0.1 - plank;
	} else if (pattern == 4) {        // worn carpet
		float fibre = vnoise(uv * 90.0);
		float blotch = smoothstep(0.5, 0.75, fbm(uv * 0.5));
		c *= 0.9 + 0.14 * fibre;
		c = mix(c, c * accent.rgb, blotch * 0.55);
		rough = 1.0;
		h = fibre * 0.15;
	} else if (pattern == 5) {        // concrete / asphalt
		float speck = vnoise(uv * 35.0);
		c *= 0.9 + 0.1 * speck + 0.1 * n;
		rough = 0.95;
		h = speck * 0.15;
	} else if (pattern == 6) {        // painted plaster
		c *= 0.94 + 0.1 * n + 0.03 * vnoise(uv * 40.0);
		rough = roughness_base;
	} else if (pattern == 7) {        // grass
		float blades = vnoise(uv * 22.0);
		float patch = fbm(uv * 0.4);
		c *= 0.88 + 0.16 * blades + 0.06 * n;
		c = mix(c, c * vec3(1.15, 1.1, 0.75), smoothstep(0.45, 0.8, patch) * 0.6);
		rough = 1.0;
		h = blades * 0.2;
	} else if (pattern == 8) {        // fabric weave
		// weave fades out with distance / pixel footprint so it never aliases into a checkerboard
		vec2 f = uv * 140.0;
		float fw = clamp(1.0 - length(fwidth(f)) * 0.4, 0.0, 1.0);
		float weave = 0.5 + 0.5 * sin(f.x) * sin(f.y);
		c *= 0.95 + 0.05 * weave * fw + 0.06 * n;
		rough = 0.95;
	}

	// fake relief: tilt the normal by the screen-space slope of the pattern height
	if (bump > 0.0) {
		float dx = dFdx(h);
		float dy = dFdy(h);
		NORMAL = normalize(NORMAL - (dx * TANGENT + dy * BINORMAL) * bump * 6.0);
	}
	ALBEDO = c;
	ROUGHNESS = clamp(rough, 0.04, 1.0);
	METALLIC = metallic_base;
}

shader_type sky;
// A sky with real weather: a height gradient, the sun (or moon) and its glow, and two layers of
// drifting clouds lit from the sun's side, with stars at night. Used by the city (a perfect summer
// afternoon) and ABOVE (night above the clouds).

uniform vec3 zenith : source_color = vec3(0.2, 0.42, 0.82);
uniform vec3 horizon : source_color = vec3(0.72, 0.82, 0.93);
uniform vec3 ground : source_color = vec3(0.35, 0.37, 0.4);
uniform vec3 sun_color : source_color = vec3(1.0, 0.95, 0.85);
uniform vec3 cloud_light : source_color = vec3(1.0, 0.98, 0.95);
uniform vec3 cloud_shadow : source_color = vec3(0.58, 0.64, 0.74);
uniform float cloud_cover = 0.45;
uniform float cloud_speed = 0.004;
uniform float sun_size = 0.9995;
uniform float stars = 0.0;
uniform float exposure = 1.0;
uniform int octaves = 6;            // cloud detail (LOW graphics: 3)

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}
float fbm(vec2 p, int oct) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 6; i++) {
		if (i >= oct) {
			break;
		}
		v += a * vnoise(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

void sky() {
	int oct = AT_CUBEMAP_PASS ? 2 : octaves;     // the lighting cubemap doesn't need fine detail
	vec3 d = EYEDIR;
	float h = d.y;
	vec3 col = mix(horizon, zenith, pow(clamp(h, 0.0, 1.0), 0.55));
	col = mix(col, ground, smoothstep(0.0, -0.08, h));

	vec3 sd = LIGHT0_DIRECTION;
	float sdot = dot(d, sd);
	float glow = pow(max(sdot, 0.0), 8.0) * 0.35 + pow(max(sdot, 0.0), 120.0) * 0.6;
	col += sun_color * glow * LIGHT0_ENERGY * 0.4;
	if (sdot > sun_size && h > -0.02) {
		col = mix(col, sun_color * 6.0, smoothstep(sun_size, sun_size + 0.0002, sdot));
	}

	if (stars > 0.0 && h > 0.0) {
		vec2 sp = d.xz / (h + 0.15) * 300.0;
		float s = step(0.9975, hash(floor(sp))) * (0.5 + 0.5 * sin(TIME * 2.0 + hash(floor(sp) + 3.0) * 30.0));
		col += vec3(s) * stars * smoothstep(0.0, 0.25, h);
	}

	if (h > 0.01) {
		vec2 uv = d.xz / (h + 0.08);
		float t = TIME * cloud_speed;
		float n = fbm(uv * 1.2 + vec2(t, t * 0.4), oct);
		float n2 = fbm(uv * 3.1 - vec2(t * 1.7, 0.0) + 5.0, oct);
		float dens = smoothstep(1.0 - cloud_cover, 1.0 - cloud_cover + 0.32, n * 0.75 + n2 * 0.35);
		// light the cloud from the sun's side: sample a little toward the sun
		float n_sun = octaves >= 6 ? fbm((uv + sd.xz * 0.06) * 1.2 + vec2(t, t * 0.4), oct) : n - 0.05;
		float lit = clamp(0.55 + (n - n_sun) * 3.5, 0.0, 1.0);
		vec3 ccol = mix(cloud_shadow, cloud_light, lit) + sun_color * pow(max(sdot, 0.0), 6.0) * 0.4;
		float fade = smoothstep(0.01, 0.2, h);
		col = mix(col, ccol, dens * fade * 0.95);
	}
	COLOR = col * exposure;
}

shader_type spatial;
// Water that behaves like water: it refracts what is under it, absorbs light with depth (clear and
// pale where shallow, deep blue-green where deep), reflects the room at grazing angles (Fresnel; the
// specular picks up screen-space reflections and the sky), ripples in several layers, and foams a
// little where it meets walls. Seen from below, the surface turns silvery (total internal reflection).

render_mode blend_mix, depth_draw_always, cull_disabled, specular_schlick_ggx;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap, repeat_disable;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest, repeat_disable;
uniform vec4 shallow : source_color = vec4(0.8, 0.98, 1.0, 1.0);
uniform vec4 deep : source_color = vec4(0.03, 0.27, 0.38, 1.0);
uniform float clarity = 0.55;       // (older parameter: higher = murkier)
uniform float absorb = 0.14;        // how fast light dies per metre of water
uniform float wave_speed = 0.35;
uniform float wave_height = 0.025;
uniform float refraction = 0.035;
uniform float foam_amount = 1.0;

varying vec3 wpos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}
float ripples(vec2 p, float t) {
	return vnoise(p * 0.9 + vec2(t * 0.8, t * 0.5)) * 0.55
		+ vnoise(p * 2.3 - vec2(t * 1.2, t * 0.3)) * 0.3
		+ vnoise(p * 6.1 + vec2(t * 0.4, -t * 1.6)) * 0.12
		+ vnoise(p * 15.0 - vec2(t * 2.1, t * 1.1)) * 0.04;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float t = TIME * wave_speed;
	VERTEX.y += (ripples(wpos.xz * 0.6, t) - 0.5) * wave_height * 2.0;
}

void fragment() {
	float t = TIME * wave_speed;
	vec2 p = wpos.xz;
	float e = 0.05;
	float h0 = ripples(p, t);
	float hx = ripples(p + vec2(e, 0.0), t);
	float hz = ripples(p + vec2(0.0, e), t);
	vec3 n_world = normalize(vec3((h0 - hx) * 0.9, 1.0, (h0 - hz) * 0.9));
	if (!FRONT_FACING) {
		n_world = -n_world;
	}
	NORMAL = normalize((VIEW_MATRIX * vec4(n_world, 0.0)).xyz);

	// how much water lies between the surface and whatever is behind it
	vec2 ruv = clamp(SCREEN_UV + n_world.xz * refraction, vec2(0.001), vec2(0.999));
	float raw = texture(depth_tex, ruv).r;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(ruv, raw) * 2.0 - 1.0;
#else
	vec3 ndc = vec3(ruv * 2.0 - 1.0, raw);
#endif
	vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	view.xyz /= view.w;
	float thickness = max(-view.z - (-VERTEX.z), 0.0);
	if (thickness < 0.02) {
		ruv = SCREEN_UV;      // don't refract things in front of the water
	}
	vec3 behind = textureLod(screen_tex, ruv, 0.0).rgb;

	float trans = exp(-thickness * absorb * (0.4 + clarity));
	vec3 tint = mix(deep.rgb, shallow.rgb, trans);
	vec3 col = behind * tint * mix(0.45, 1.0, trans) + deep.rgb * (1.0 - trans) * 0.8;

	float fres = 0.02 + 0.98 * pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 5.0);
	if (!FRONT_FACING) {
		fres = mix(fres, 0.9, smoothstep(0.35, 0.15, dot(NORMAL, VIEW)));   // the surface from below
	}
	// foam where the water meets walls and the pool edge
	float foam = (1.0 - smoothstep(0.0, 0.12, thickness)) * smoothstep(0.45, 0.75, vnoise(p * 9.0 + t * 2.0)) * foam_amount;

	EMISSION = col * (1.0 - fres) + vec3(0.85) * foam * 0.35;
	ALBEDO = mix(deep.rgb * 0.2, vec3(0.9), foam);
	ROUGHNESS = mix(0.02, 0.6, foam);
	METALLIC = 0.0;
	SPECULAR = 0.6;
	ALPHA = 1.0;
}

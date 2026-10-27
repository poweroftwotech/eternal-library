// A great waterfall (phase-8-design.md 8.5): an opaque core whose streaks
// speed up as the water falls, a bright smooth lip at the top, edges and the
// lower third breaking into ragged threads. `veil` draws the wider, thinner
// sheet behind the core. Used by GreatFall (scripts/world/great_fall.gd).
shader_type spatial;
// fog_disabled: volumetric fog's depth slices showed as bands across the
// arcing sheet; the fall fades into the distance by itself (fog_tint).
render_mode blend_mix, cull_disabled, depth_draw_never, fog_disabled;

uniform float seed = 0.0;
uniform float veil = 0.0;              // 0: the core; 1: a veil
uniform float speed = 1.6;             // streak speed at the lip, in UV per second
uniform float length_m = 40.0;         // the fall's height, so streaks keep their size
uniform vec3 water_dark : source_color = vec3(0.30, 0.46, 0.52);
uniform vec3 water_light : source_color = vec3(0.86, 0.94, 0.96);
uniform float glow = 0.35;             // its own light in the dark cavern
uniform vec3 fog_tint : source_color = vec3(0.16, 0.21, 0.24);
uniform float fog_far = 300.0;         // fully hazed at this distance (m)

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7)) + seed) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	// Falling water accelerates: distance fallen grows with the square of
	// time, so the scroll uses sqrt(v) and streaks stretch toward the foot.
	float v = UV.y;
	float fall = sqrt(v) * length_m * 0.18;
	// Two layers of value noise half a cell apart, so no row of the noise
	// lattice shows as a band across the sheet.
	float fx = UV.x * (veil > 0.5 ? 18.0 : 30.0);
	float fy = fall * 3.0 - TIME * speed * 3.0;
	float threads = noise(vec2(fx, fy)) * 0.5 + noise(vec2(fx + 0.5, fy * 1.31 + 0.5)) * 0.5;
	threads = clamp((threads - 0.5) * 1.6 + 0.5, 0.0, 1.0);
	float sy = fall * 6.0 - TIME * speed * 6.0;
	float streak = noise(vec2(UV.x * 90.0, sy)) * 0.5 + noise(vec2(UV.x * 90.0 + 0.5, sy * 1.27 + 0.5)) * 0.5;
	float cy = v * 6.0 - TIME * speed * 0.8;
	float churn = noise(vec2(UV.x * 12.0 + TIME * 0.3, cy)) * 0.5 + noise(vec2(UV.x * 12.0 + 0.5, cy * 1.29 + 0.5)) * 0.5;
	float edge_w = veil > 0.5 ? 0.42 : 0.12;
	float edge = smoothstep(0.0, edge_w, UV.x) * smoothstep(0.0, edge_w, 1.0 - UV.x);
	// The lower third breaks up: threads thin out where the noise is low.
	float breakup = smoothstep(0.55, 1.0, v);
	float body = mix(1.0, smoothstep(0.25 + breakup * 0.35, 0.75, threads + churn * 0.3), breakup);
	float tail = 1.0 - smoothstep(0.9, 1.0, v);
	float lip = 1.0 - smoothstep(0.0, 0.05, v);
	float a = veil > 0.5 ? (0.16 + threads * 0.22) : (0.72 + threads * 0.25);
	ALPHA = clamp(a * edge * body * tail + lip * edge * 0.2, 0.0, 1.0);
	vec3 c = mix(water_dark, water_light, clamp(threads * 0.55 + streak * 0.35 + lip * 0.6 + (1.0 - veil) * 0.15, 0.0, 1.0));
	float haze = clamp(length(VERTEX) / fog_far, 0.0, 1.0) * 0.75;
	ALBEDO = mix(c, fog_tint, haze);
	ROUGHNESS = 0.3;
	EMISSION = mix(c * glow * (0.6 + streak * 0.5), fog_tint * 0.3, haze);
	NORMAL_MAP = vec3(0.5 + (threads - 0.5) * 0.25, 0.5 + (streak - 0.5) * 0.15, 1.0);
}

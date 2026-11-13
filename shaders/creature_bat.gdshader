shader_type spatial;
// Bats (phase 19 step 2): one roost's colony in one MultiMesh. An instance's
// origin is where the bat hangs, its scale the bat's size. Custom data: x
// phase (0..1), w its take-off delay (s). Per roost (BatRoost sets them):
// `clock`, seconds since the colony took flight (below 0: at rest), `centre`
// the roost and `exit_dir` the way they stream off along the vault, fading
// into the dark.
// At rest a bat hangs head down, stirs, turns, now and then stretches its
// wings; and every so often it drops off, flies a loop or two under the
// roost and comes back to its place (`wing_share`: the share of its time it
// spends on the wing).
// Dark, with a dim indigo lift (`self_glow`) so it shows against a black
// vault, and shaded by itself (v_shade: no lamp reaches a roost): wing
// panels by how they are turned, the body darker than the membrane. It
// lights nothing.
render_mode unshaded, cull_disabled, shadows_disabled;

uniform vec3 colour : source_color = vec3(0.16, 0.12, 0.1);
uniform float self_glow = 0.05;
uniform float wing_share = 0.3;
instance uniform float clock = -1.0;
instance uniform vec3 centre = vec3(0.0);
instance uniform vec3 exit_dir = vec3(1.0, 0.0, 0.0);
varying float v_shade;

const float SWIRL = 2.4;     // s circling the roost before they stream off
const float STREAM = 6.5;    // m/s along the vault
const float GONE = 2.6;      // s of streaming before they have faded out
const float LIFT = 1.4;      // s to drop off its place, and to come back to it

vec3 circling(vec3 c, float phase, float t) {
	float a = t * (1.2 + phase * 0.6) + phase * 6.2832;
	float r = 1.6 + phase * 2.2;
	return c + vec3(cos(a) * r, -1.6 - 0.9 * sin(t * 0.9 + phase * 7.0), sin(a) * r);
}

vec3 leaving(vec3 roost, vec3 c, float phase, float tt) {
	float s = min(tt, SWIRL);
	float a = s * 2.6 + phase * 6.2832;
	float r = 0.8 + s * 1.1;
	vec3 swirl = c + vec3(cos(a) * r, -0.7 - s * 0.35, sin(a) * r);
	vec3 p = mix(roost, swirl, smoothstep(0.0, 0.45, tt));
	float e = max(tt - SWIRL, 0.0);
	p += exit_dir * e * STREAM + vec3(sin(e * 3.0 + phase * 9.0), sin(e * 2.3 + phase * 5.0) * 0.6, cos(e * 2.7 + phase * 4.0)) * 0.5 * min(e, 1.0);
	return p;
}

// Where a resting bat is at time `t` of its own cycle: at its place, or off
// on a short flight (`aloft` 0..1 says how far off its place it is).
vec3 resting(vec3 roost, vec3 c, float phase, float turn, float t, out float aloft) {
	float period = 26.0 + turn * 30.0;
	float flight = period * wing_share;
	float u = fract(t / period + turn * 0.71 + phase * 0.37) * period;
	aloft = smoothstep(0.0, LIFT, u) * (1.0 - smoothstep(flight - LIFT, flight, u)) * step(2.0 * LIFT, flight);
	return mix(roost, circling(c, phase, t), aloft);
}

void vertex() {
	vec3 roost = MODEL_MATRIX[3].xyz;
	float s = length(MODEL_MATRIX[0].xyz);
	float phase = INSTANCE_CUSTOM.x;
	float turn = fract(INSTANCE_CUSTOM.w * 0.7143 + phase * 3.3);
	float tt = clock - INSTANCE_CUSTOM.w;
	vec3 v = VERTEX;
	vec3 world;
	float aloft = 0.0;
	vec3 p = roost;
	vec3 ahead = roost;
	if (tt < 0.0) {
		float a2;
		p = resting(roost, centre, phase, turn, TIME, aloft);
		ahead = resting(roost, centre, phase, turn, TIME + 0.05, a2);
	} else {
		aloft = 1.0;
		p = leaving(roost, centre, phase, tt);
		ahead = leaving(roost, centre, phase, tt + 0.05);
	}
	// Hanging head down, wings folded: it stirs and turns, and now and then
	// stretches its wings out and folds them again.
	float every = 9.0 + phase * 14.0;
	float st = fract(TIME / every + phase * 3.7) * every;
	float stretch = smoothstep(0.0, 0.5, st) * (1.0 - smoothstep(1.3, 2.2, st));
	float yaw = phase * 6.2832 + sin(TIME * 0.5 + phase * 31.0) * 0.5;
	vec3 hx = vec3(cos(yaw), 0.0, sin(yaw));
	vec3 hz = vec3(-sin(yaw), 0.0, cos(yaw));
	vec3 hang = vec3(v.x * mix(0.35, 0.95, stretch), v.z, -abs(v.x) * mix(0.12, 0.3, stretch));
	float sway = sin(TIME * 1.1 + phase * 13.0) * 0.16 * (0.5 - hang.y);
	vec3 hung = (hx * (hang.x + sway) + vec3(0.0, hang.y, 0.0) + hz * hang.z) * s;
	// Flying: nose along its way, wings beating.
	vec3 f = ahead - p;
	f = length(f) > 0.0001 ? normalize(f) : vec3(0.0, 0.0, -1.0);
	vec3 z_axis = -f;
	vec3 x_axis = normalize(cross(vec3(0.0, 1.0, 0.0), z_axis) + vec3(0.0001));
	vec3 y_axis = cross(z_axis, x_axis);
	vec3 w = v;
	if (UV.x > 0.0) {
		float flap = sin(TIME * 15.0 + phase * 20.0) * (0.55 + 0.5 * UV.x);
		w = vec3(v.x * cos(flap), abs(v.x) * sin(flap), v.z);
	}
	float fade = tt < 0.0 ? 1.0 : 1.0 - smoothstep(SWIRL + GONE - 0.8, SWIRL + GONE, tt);
	vec3 flying = (x_axis * w.x + y_axis * w.y + z_axis * w.z) * s * fade;
	world = p + mix(hung, flying, smoothstep(0.0, 0.5, aloft));
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
	// Its own shading (the vault has no light to shade it): each wing panel
	// by how it is turned to a dim light from above, so the wings read as
	// folding planes as they beat; the body dark, the membrane paler and
	// thinner toward the wing tips.
	vec3 n = hz;
	if (aloft > 0.25) {
		float flap = UV.x > 0.0 ? sin(TIME * 15.0 + phase * 20.0) * (0.55 + 0.5 * UV.x) : 0.0;
		n = normalize(x_axis * (-sign(v.x) * sin(flap)) + y_axis * cos(flap));
	}
	float facing = abs(dot(n, normalize(vec3(0.35, 1.0, 0.25))));
	float part = UV.x > 0.0 ? 0.75 + 0.6 * UV.x : 0.45;
	v_shade = (0.3 + 0.7 * facing) * part;
}

void fragment() {
	// A dark animal with a dim indigo lift of its own, so it shows against a
	// black vault without looking lit.
	ALBEDO = colour * v_shade + vec3(0.2, 0.24, 0.62) * self_glow * v_shade;
}

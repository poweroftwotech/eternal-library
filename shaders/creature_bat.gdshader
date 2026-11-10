shader_type spatial;
// Bats (phase 19 step 2): one roost's colony in one MultiMesh. An instance's
// origin is where the bat hangs, its scale the bat's size. Custom data: x
// phase (0..1), z 1 for a bat that keeps circling under the roost, w its
// take-off delay (s). Per roost (BatRoost sets them): `clock`, seconds since
// the colony took flight (below 0: hanging), `centre` the roost and `exit_dir`
// the way they stream off along the vault, fading into the dark.
// Unshaded and dark: a silhouette, with a faint lift (`self_glow`) so it shows
// against a black vault. It lights nothing.
render_mode unshaded, cull_disabled, shadows_disabled;

uniform vec3 colour : source_color = vec3(0.16, 0.12, 0.1);
uniform float self_glow = 0.05;
instance uniform float clock = -1.0;
instance uniform vec3 centre = vec3(0.0);
instance uniform vec3 exit_dir = vec3(1.0, 0.0, 0.0);
varying float v_shade;

const float SWIRL = 2.4;     // s circling the roost before they stream off
const float STREAM = 6.5;    // m/s along the vault
const float GONE = 2.6;      // s of streaming before they have faded out

vec3 circling(vec3 c, float phase, float t) {
	float a = t * (1.2 + phase * 0.6) + phase * 6.2832;
	float r = 1.6 + phase * 2.2;
	return c + vec3(cos(a) * r, -1.3 - 0.5 * sin(t * 0.9 + phase * 7.0), sin(a) * r);
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

void vertex() {
	vec3 roost = MODEL_MATRIX[3].xyz;
	float s = length(MODEL_MATRIX[0].xyz);
	float phase = INSTANCE_CUSTOM.x;
	bool circler = INSTANCE_CUSTOM.z > 0.5;
	float tt = clock - INSTANCE_CUSTOM.w;
	vec3 v = VERTEX;
	vec3 world;
	if (!circler && tt < 0.0) {
		// Hanging head down, wings folded, swaying a little.
		float yaw = phase * 6.2832;
		vec3 x_axis = vec3(cos(yaw), 0.0, sin(yaw));
		vec3 z_axis = vec3(-sin(yaw), 0.0, cos(yaw));
		vec3 hang = vec3(v.x * 0.35, v.z, -abs(v.x) * 0.12);
		float sway = sin(TIME * 0.7 + phase * 13.0) * 0.08 * (0.5 - hang.y);
		world = roost + (x_axis * (hang.x + sway) + vec3(0.0, hang.y, 0.0) + z_axis * hang.z) * s;
	} else {
		float t = circler && tt < 0.0 ? TIME : tt;
		vec3 p = circler && tt < 0.0 ? circling(centre, phase, t) : leaving(roost, centre, phase, t);
		vec3 ahead = circler && tt < 0.0 ? circling(centre, phase, t + 0.05) : leaving(roost, centre, phase, t + 0.05);
		vec3 f = ahead - p;
		f = length(f) > 0.0001 ? normalize(f) : vec3(0.0, 0.0, -1.0);
		vec3 z_axis = -f;
		vec3 x_axis = normalize(cross(vec3(0.0, 1.0, 0.0), z_axis) + vec3(0.0001));
		vec3 y_axis = cross(z_axis, x_axis);
		if (UV.x > 0.0) {
			float flap = sin(TIME * 15.0 + phase * 20.0) * (0.55 + 0.5 * UV.x);
			v = vec3(v.x * cos(flap), abs(v.x) * sin(flap), v.z);
		}
		float fade = 1.0;
		if (!(circler && tt < 0.0)) {
			fade = 1.0 - smoothstep(SWIRL + GONE - 0.8, SWIRL + GONE, tt);
		}
		world = p + (x_axis * v.x + y_axis * v.y + z_axis * v.z) * s * fade;
	}
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
	v_shade = 0.75 + 0.25 * UV.x;
}

void fragment() {
	ALBEDO = colour * v_shade + vec3(self_glow) * colour * 4.0;
}

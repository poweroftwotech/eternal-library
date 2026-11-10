shader_type spatial;
// Candle moths (phase 19 step 2): every moth of a room in one MultiMesh, all
// their flight here. An instance's origin is the flame it circles, its scale
// the moth's size, its colour the flame's light. Custom data: x phase (0..1),
// y orbit radius (m), z orbit speed (rad/s, signed), w 1 for a moth loose
// over the floor (the Garden Court's beds) instead of at a flame.
// Unshaded: a moth by a flame is lit by it, so it takes the flame's colour,
// paler close in. It lights nothing.
render_mode unshaded, cull_disabled, shadows_disabled;

uniform vec3 wing_colour : source_color = vec3(0.85, 0.8, 0.7);
uniform vec3 body_colour : source_color = vec3(0.5, 0.42, 0.3);
varying float v_lit;
varying vec3 v_light;

vec3 flight(vec3 centre, float phase, float radius, float speed, float loose, float t) {
	float a = t * speed + phase * 6.2832;
	if (loose > 0.5) {
		// Wandering low over the beds: a slow figure across its patch.
		return centre + vec3(sin(t * 0.21 + phase * 11.0) * radius + sin(a) * 0.35,
			0.35 * sin(t * 0.33 + phase * 5.0) + 0.06 * sin(t * 7.0 + phase * 31.0),
			sin(t * 0.17 + phase * 7.0) * radius + cos(a) * 0.35);
	}
	// Round the flame, breathing in and out; now and then a dart at the flame.
	float r = radius * (1.0 + 0.25 * sin(t * 0.7 + phase * 9.0));
	r *= 1.0 - 0.75 * pow(max(0.0, sin(t * 0.23 + phase * 17.0)), 14.0);
	return centre + vec3(cos(a) * r, 0.3 * r * sin(a * 1.7 + phase * 5.0) + 0.04 * sin(t * 9.0 + phase * 30.0), sin(a) * r * 0.85);
}

void vertex() {
	vec3 centre = MODEL_MATRIX[3].xyz;
	float s = length(MODEL_MATRIX[0].xyz);
	float phase = INSTANCE_CUSTOM.x;
	vec3 p = flight(centre, phase, INSTANCE_CUSTOM.y, INSTANCE_CUSTOM.z, INSTANCE_CUSTOM.w, TIME);
	vec3 ahead = flight(centre, phase, INSTANCE_CUSTOM.y, INSTANCE_CUSTOM.z, INSTANCE_CUSTOM.w, TIME + 0.05);
	vec3 f = ahead - p;
	f = length(f) > 0.0001 ? normalize(f) : vec3(0.0, 0.0, -1.0);
	vec3 z_axis = -f;
	vec3 x_axis = normalize(cross(vec3(0.0, 1.0, 0.0), z_axis) + vec3(0.0001));
	vec3 y_axis = cross(z_axis, x_axis);
	vec3 v = VERTEX;
	if (UV.x > 0.0) {
		float flap = sin(TIME * 26.0 + phase * 20.0) * 1.0;
		v = vec3(v.x * cos(flap), abs(v.x) * sin(flap), v.z);
	}
	vec3 world = p + (x_axis * v.x + y_axis * v.y + z_axis * v.z) * s;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
	float d = INSTANCE_CUSTOM.w > 0.5 ? 1.0 : distance(p, centre);
	v_lit = clamp(1.35 - d * 1.1, 0.35, 1.2);
	v_light = COLOR.rgb;
}

void fragment() {
	vec3 c = UV.x > 0.0 ? wing_colour : body_colour;
	ALBEDO = c * v_light * v_lit;
}

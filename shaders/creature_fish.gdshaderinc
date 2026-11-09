// Shared by creature_fish.gdshader (drawn under the water) and
// creature_fish_clear.gdshader (drawn over its surface). Each instance's
// custom data: x its phase (0..1), y tail beats a second, z its colour pattern
// (row of `skin`). The body bends from the nose (UV.x 0) to the tail (UV.x 1).
// A school (FishSchool) also lets each fish wander round its place (`drift`)
// and part round a point (`avoid_at`, `avoid_radius`, per school). Lit by the
// room's lamps; `self_glow` lets a pale fish show a little in the dark without
// lighting anything.

uniform sampler2D skin : source_color, filter_nearest_mipmap;
uniform float patterns = 4.0;
uniform float self_glow = 0.0;
uniform float wiggle = 1.0;
uniform float drift = 0.0;
uniform float clarity = 1.0;
instance uniform vec3 avoid_at = vec3(0.0, -10000.0, 0.0);
instance uniform float avoid_radius = 0.0;
varying flat float v_pattern;

void vertex() {
	float phase = INSTANCE_CUSTOM.x * 6.2832;
	float rate = INSTANCE_CUSTOM.y;
	v_pattern = INSTANCE_CUSTOM.z;
	float along = UV.x;
	vec3 side = normalize(MODEL_MATRIX[0].xyz);
	float len = length(MODEL_MATRIX[2].xyz);
	float beat = TIME * rate * 6.2832 + phase - along * 4.5;
	VERTEX += side * sin(beat) * 0.1 * len * wiggle * along * along;
	vec3 origin = MODEL_MATRIX[3].xyz;
	if (drift > 0.0) {
		float t = TIME;
		VERTEX += vec3(sin(t * 0.37 + phase * 1.7), sin(t * 0.23 + phase * 2.9) * 0.2, cos(t * 0.31 + phase * 1.3)) * drift;
	}
	if (avoid_radius > 0.0) {
		vec2 d = origin.xz - avoid_at.xz;
		float dist = length(d);
		float push = max(0.0, avoid_radius - dist);
		VERTEX.xz += (dist > 0.001 ? d / dist : vec2(1.0, 0.0)) * push * 0.9;
	}
}

vec4 fish_skin(vec2 uv) {
	return texture(skin, vec2(uv.x, (uv.y + floor(v_pattern + 0.5)) / patterns));
}

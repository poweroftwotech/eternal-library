shader_type spatial;
// The small animals of the ground and the walls (phase 19 step 4): the rat,
// the wall gecko, and the rat's hole. Models from GroundBody: a corner's
// COLOR.r is its colour (0 body, 0.5 pale, 1 dark), COLOR.g what moves it (0
// the body, 0.5 a leg, 1 the tail), COLOR.b which pair a leg steps with; UV.y
// is how far along the animal it is. MultiMesh custom data: x how fast it is
// going (0 still, 1 flat out), y its phase (0..1), z its shade (0..1).
// Lit like the world; `self_glow` lifts it a little in the dark (it lights
// nothing).
render_mode cull_disabled, shadows_disabled;

uniform vec3 body_colour : source_color = vec3(0.4, 0.35, 0.3);
uniform vec3 dark_colour : source_color = vec3(0.08, 0.07, 0.06);
uniform vec3 pale_colour : source_color = vec3(0.75, 0.65, 0.6);
uniform float self_glow = 0.0;
// 1: a flat animal that wriggles side to side as it runs (the gecko).
uniform float flat_body = 0.0;
varying float v_shade;

void vertex() {
	float gait = INSTANCE_CUSTOM.x;
	float phase = INSTANCE_CUSTOM.y * 6.2832;
	float step_t = TIME * mix(9.0, 34.0, gait) + phase;
	if (COLOR.g > 0.75) {
		// The tail: trails and sways, more toward its tip.
		float k = clamp((UV.y - 0.5) * 2.0, 0.0, 1.0);
		VERTEX.x += sin(TIME * 2.2 + phase + UV.y * 4.0) * 0.1 * k * (0.4 + gait);
	} else if (COLOR.g > 0.25) {
		// A leg: forward and back, the two pairs opposite; lifted going forward.
		float s = sin(step_t + COLOR.b * 3.1416);
		VERTEX.z += s * 0.09 * gait;
		VERTEX.y += max(cos(step_t + COLOR.b * 3.1416), 0.0) * 0.03 * gait * (1.0 - flat_body);
	}
	if (flat_body > 0.5) {
		VERTEX.x += sin(step_t * 0.5 + UV.y * 7.0) * 0.035 * gait;
	} else {
		// Scurrying bob; still, it breathes and its nose works.
		VERTEX.y += abs(sin(step_t * 0.5)) * 0.02 * gait;
		VERTEX.y += sin(TIME * 7.0 + phase) * 0.012 * (1.0 - gait) * (1.0 - UV.y) * step(COLOR.g, 0.25);
	}
	v_shade = 0.82 + 0.3 * INSTANCE_CUSTOM.z;
}

void fragment() {
	vec3 c = COLOR.r > 0.75 ? dark_colour : (COLOR.r > 0.25 ? pale_colour : body_colour * v_shade);
	if (COLOR.a < 0.5) {
		c = vec3(0.015);     // an eye
	}
	ALBEDO = c;
	ROUGHNESS = 0.9;
	SPECULAR = 0.15;
	EMISSION = c * self_glow;
}

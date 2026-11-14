shader_type spatial;
// The spiny eel (phase 20 step 3). EelBody's model: UV.x snout (0) to tail (1),
// UV.y round the body, 0 the back, 1 the belly (the fins at 0.02 and 0.98).
// MultiMesh custom data: x its phase (0..1), y waves a second, z how far it
// swings (0 still, 1 swimming), w its shade. A wave runs down the whole body,
// one and a half lengths of it, the head swinging least. Drawn under the
// water like the fish (the surface tints it).
render_mode world_vertex_coords, cull_disabled;

uniform vec3 dark_colour : source_color = vec3(0.23, 0.23, 0.18);
uniform vec3 body_colour : source_color = vec3(0.48, 0.44, 0.27);
uniform vec3 belly_colour : source_color = vec3(0.79, 0.72, 0.47);
uniform float self_glow = 0.0;
// Its own light (phase 20 step 3, look 1): a row of dots down each side and
// a few along the back, a slow pulse running down the body, brighter on the
// move. It lights nothing round it.
uniform vec3 glow_colour : source_color = vec3(0.3, 0.95, 0.85);
uniform float glow = 2.2;
varying float v_shade;
varying float v_phase;
varying float v_swing;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	float phase = INSTANCE_CUSTOM.x * 6.2832;
	float rate = INSTANCE_CUSTOM.y;
	float swing = INSTANCE_CUSTOM.z;
	v_shade = INSTANCE_CUSTOM.w;
	v_phase = phase;
	v_swing = swing;
	float along = UV.x;
	vec3 side = normalize(MODEL_MATRIX[0].xyz);
	float len = length(MODEL_MATRIX[2].xyz);
	float wave = TIME * rate * 6.2832 + phase - along * 9.4;
	// Still in its hole, only the head sways a little, breathing.
	float amp = mix(0.012, 0.075, swing) * mix(0.35, 1.0, along);
	VERTEX += side * sin(wave) * amp * len;
}

void fragment() {
	// Mottled: blotches a few to the body's width, larger along it.
	vec2 cell = floor(vec2(UV.x * 34.0, UV.y * 5.0));
	float n = hash(cell + floor(v_shade * 7.0));
	vec3 c = mix(body_colour, dark_colour, step(0.55, n) * smoothstep(0.75, 0.3, UV.y));
	// Darker along the back, a pale belly.
	c = mix(c, dark_colour, smoothstep(0.25, 0.0, UV.y) * 0.6);
	c = mix(c, belly_colour, smoothstep(0.62, 0.85, UV.y));
	// A dark line through the eye, and the eye.
	float eye_line = step(0.06, UV.x) * step(UV.x, 0.15) * step(0.32, UV.y) * step(UV.y, 0.46);
	c = mix(c, dark_colour * 0.6, eye_line);
	float eye = step(0.115, UV.x) * step(UV.x, 0.13) * step(0.34, UV.y) * step(UV.y, 0.44);
	c = mix(c, vec3(0.02), eye);
	// The fins: thin, the body colour, a little paler.
	if (UV.y < 0.03 || UV.y > 0.97) {
		c = mix(body_colour, belly_colour, 0.35);
	}
	c *= mix(0.85, 1.1, v_shade);
	// The lights: dots on the sides' line and every third one on the back.
	float row = fract(UV.x * 28.0);
	float dot_x = smoothstep(0.42, 0.2, abs(row - 0.5)) * step(0.12, UV.x) * step(UV.x, 0.9);
	float side = smoothstep(0.07, 0.02, abs(UV.y - 0.5));
	float back = smoothstep(0.08, 0.03, UV.y - 0.04) * step(0.5, fract(UV.x * 28.0 / 3.0)) * step(0.06, UV.y);
	float spots = dot_x * max(side, back * 0.8);
	float pulse = 0.55 + 0.45 * sin(TIME * mix(1.2, 3.0, v_swing) - UV.x * 9.0 + v_phase);
	float lit = spots * pulse * mix(0.7, 1.15, v_swing);
	c = mix(c, glow_colour, lit * 0.6);
	ALBEDO = c;
	EMISSION = c * self_glow + glow_colour * lit * glow;
	ROUGHNESS = 0.35;
	SPECULAR = 0.5;
}

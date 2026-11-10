shader_type spatial;
// The cat (phase 19 step 3). One model, many coats: the texture is a mask
// (tools/creature_cat.py): R tabby stripes, G pale fur, B what a texel is
// (0 fur, 0.5 nose and ear skin, darker with R (the mouth), 1 an eye). In an
// eye R is 1 on the rim and 0.6 on the pupil; G is 1 on the glint and 0.5 on
// the row that stays dark when the eye is shut. Each cat sets its coat with
// instance uniforms (CatBody.COATS). Lit like the world; the open eyes keep a
// faint shine of their own in the dark (it lights nothing).
render_mode cull_disabled;

uniform sampler2D mask : filter_nearest, hint_default_black;
instance uniform vec3 coat = vec3(0.55, 0.55, 0.56);
instance uniform vec3 stripe = vec3(0.26, 0.26, 0.27);
instance uniform vec3 pale = vec3(0.85, 0.82, 0.77);
instance uniform vec3 eye_colour = vec3(0.78, 0.62, 0.18);
instance uniform float stripe_amount = 1.0;
// 1: the eyes are shut (asleep, a blink).
instance uniform float eyes_shut = 0.0;
const vec3 SKIN = vec3(0.7, 0.44, 0.44);
const float EYE_SHINE = 0.35;

void fragment() {
	vec3 m = texture(mask, UV).rgb;
	vec3 c = mix(coat, pale, m.g);
	c = mix(c, stripe, m.r * (1.0 - m.g) * stripe_amount);
	bool eye = m.b > 0.75;
	bool open = eye && eyes_shut < 0.5;
	if (open) {
		bool glint = m.g > 0.75;
		float dark = step(0.3, m.r);
		c = glint ? vec3(0.95) : mix(eye_colour, vec3(0.02), dark);
		EMISSION = (glint ? vec3(0.5) : eye_colour * (1.0 - dark)) * EYE_SHINE;
	} else if (eye) {
		// Shut: the lid is coat, the lashes' line dark.
		c = (m.g > 0.25 && m.g < 0.75) ? stripe * 0.4 : coat;
	} else if (m.b > 0.25) {
		c = mix(SKIN, SKIN * 0.18, m.r);
	}
	ALBEDO = c;
	ROUGHNESS = open ? 0.25 : 0.92;
	SPECULAR = open ? 0.6 : 0.2;
}

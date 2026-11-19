shader_type spatial;
// A resident (phase 21 step 1). One model, many people: the texture is a mask
// (tools/resident_body.py). B says what a texel is, in tenths: 0 the main
// garment, 1 the under garment and leather, 2 the sash and head cloth, 3 skin,
// 4 hair, 5 an eye, 6 glow thread, 7 brass, 8 what is worn over (cloak, cape,
// shawl), 9 a lantern, 10 pale undyed cloth. R darkens it (in an eye: the
// iris). G is trim on cloth and beard on skin. Each person sets their colours
// with instance uniforms (ResidentBody). Lit like the world; glow thread and
// lanterns shine by themselves and light nothing.
render_mode cull_disabled;

uniform sampler2D mask : filter_nearest, hint_default_black;
instance uniform vec3 cloth_a = vec3(0.36, 0.26, 0.45);
instance uniform vec3 cloth_b = vec3(0.3, 0.27, 0.22);
instance uniform vec3 cloth_c = vec3(0.75, 0.68, 0.52);
instance uniform vec3 cloth_d = vec3(0.3, 0.22, 0.16);
instance uniform vec3 trim = vec3(0.78, 0.6, 0.25);
instance uniform vec3 skin = vec3(0.72, 0.52, 0.38);
instance uniform vec3 hair = vec3(0.09, 0.07, 0.06);
// The glow thread's colour (its home area's); black: none is worn.
instance uniform vec3 glow = vec3(1.0, 0.82, 0.5);
// 1: a full beard; 0: none (the mask's beard texels are skin).
instance uniform float beard = 1.0;
// 1: the eyes are shut (asleep, a blink).
instance uniform float eyes_shut = 0.0;
const vec3 EYE_WHITE = vec3(0.8, 0.77, 0.72);
const vec3 BRASS = vec3(0.78, 0.58, 0.24);
const vec3 FLAME = vec3(1.0, 0.78, 0.42);
const vec3 PALE = vec3(0.82, 0.78, 0.68);
const float DARKEN = 0.62;
const float MASK_SIZE = 512.0;
const float GLOW_ENERGY = 0.9;
const float FLAME_ENERGY = 2.0;

void fragment() {
	vec3 m = texture(mask, UV).rgb;
	int what = int(m.b * 10.0 + 0.5);
	vec3 c;
	vec3 shine = vec3(0.0);
	float rough = 0.95;
	float metal = 0.0;
	if (what == 5) {
		c = eyes_shut > 0.5 ? skin * 0.5 : mix(EYE_WHITE, hair * 0.6, m.r);
	} else if (what == 6) {
		// Glow thread; with none worn it is plain trim.
		bool worn = dot(glow, vec3(1.0)) > 0.01;
		c = worn ? glow * 0.5 : trim;
		shine = glow * GLOW_ENERGY;
	} else if (what == 9) {
		c = FLAME;
		shine = FLAME * FLAME_ENERGY;
	} else {
		if (what == 0) {
			c = mix(cloth_a, trim, m.g);
		} else if (what == 1) {
			c = mix(cloth_b, trim, m.g);
		} else if (what == 2) {
			c = mix(cloth_c, trim, m.g);
		} else if (what == 3) {
			c = mix(skin, mix(skin, hair, 0.88), m.g * beard);
		} else if (what == 4) {
			c = hair;
		} else if (what == 7) {
			c = BRASS;
			rough = 0.35;
			metal = 0.8;
		} else if (what == 8) {
			c = mix(cloth_d, trim, m.g);
		} else {
			c = mix(PALE, trim, m.g * 0.5);
		}
		c *= 1.0 - DARKEN * m.r;
		// The weave: 3 cm squares, as the world's cloth has (two mask texels),
		// and a little grain per texel. Skin, hair and brass get the grain only.
		vec2 tx = floor(UV * MASK_SIZE);
		vec2 cell = floor(tx * 0.5);
		float grain = fract(sin(dot(tx, vec2(12.9898, 78.233))) * 43758.5453);
		if (what < 3 || what == 8 || what == 10) {
			c *= (mod(cell.x + cell.y, 2.0) < 0.5 ? 0.9 : 1.0) * (0.96 + 0.08 * grain);
		} else {
			c *= 0.97 + 0.06 * grain;
		}
		if (what == 3) {
			rough = 0.75;
		}
	}
	ALBEDO = c;
	EMISSION = shine;
	ROUGHNESS = rough;
	METALLIC = metal;
	SPECULAR = 0.2;
}

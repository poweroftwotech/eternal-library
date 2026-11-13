shader_type spatial;
// A small animal's shadow under it (cats, rats, geckos): a soft dark blob
// on the floor or wall, darkest in the middle and fading smoothly to nothing
// at its edge, so the animal sits on its surface. Small animals cast no real
// shadows (phase 19 Q12: most lamps cast none either); this is theirs
// (BlobShadow). It only darkens what is behind it.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform float strength = 0.6;

void fragment() {
	float r = length(UV * 2.0 - 1.0);
	// Full under the animal, fading over the outer part (its body hides the middle).
	float a = 1.0 - smoothstep(0.3, 1.0, r);
	ALBEDO = vec3(0.0);
	ALPHA = a * strength;
}

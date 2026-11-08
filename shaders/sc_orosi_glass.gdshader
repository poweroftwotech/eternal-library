shader_type spatial;
// The Orosi Scriptorium's window glass (phase 17, R08): coloured panes lit from
// behind by the lumen-moss garden. Its colour is its own (emission), like
// orosi_glass.gdshader, but the panes let a little through, so the moss and
// rock behind show as soft shapes; the leading is opaque. Real lights in the
// hall add only a small, sharp highlight.
render_mode blend_mix, cull_disabled, depth_draw_opaque, ambient_light_disabled;

uniform sampler2D glass_tex : source_color, filter_nearest;
uniform float brightness = 1.6;     // the glow from behind
uniform float see_through : hint_range(0.0, 1.0) = 0.25;     // how much of the garden shows through a pane
uniform float pale_see_through : hint_range(0.0, 1.0) = 0.45;   // the pale border panes are clearer
uniform float gloss_roughness : hint_range(0.0, 1.0) = 0.12;
uniform float shine : hint_range(0.0, 1.0) = 0.12;
uniform float light_pickup : hint_range(0.0, 1.0) = 0.2;
// The moss behind swells and fades (scripted on the room; 1 = as drawn).
instance uniform float swell = 1.0;

void fragment() {
	vec4 t = texture(glass_tex, UV);
	if (t.a < 0.5) {
		discard;
	}
	vec3 c = t.rgb;
	float lead = step(max(max(c.r, c.g), c.b), 0.2);
	float pale = step(0.7, min(min(c.r, c.g), c.b));
	ALBEDO = mix(c, vec3(0.6), 0.5) * light_pickup;
	EMISSION = c * brightness * swell * (1.0 - lead);
	ROUGHNESS = gloss_roughness;
	SPECULAR = shine;
	METALLIC = 0.0;
	ALPHA = mix(1.0 - mix(see_through, pale_see_through, pale), 1.0, lead);
}

shader_type spatial;
// Stained glass (orosi) for the Light-Well Stair's taghcheh (room rework step 6,
// your walk). Its colour is its own (emission), so the shaft's sun and haze
// can't wash it white; the room's reflections and ambient are off, and only
// real lights add a small, sharp highlight, broken up by the leading's normal map.
render_mode cull_disabled, ambient_light_disabled;

uniform sampler2D glass_tex : source_color, filter_nearest_mipmap;
uniform sampler2D normal_tex : hint_normal, filter_nearest;
uniform sampler2D rough_tex : hint_roughness_g, filter_nearest;
uniform float brightness = 0.42;
uniform float gloss_roughness : hint_range(0.0, 1.0) = 0.15;
uniform float shine : hint_range(0.0, 1.0) = 0.6;
uniform float bump : hint_range(0.0, 2.0) = 1.0;
// How much nearby lights (the glowing plants' green) colour the glass, as
// they do the walls; ambient stays off, so the haze still can't whiten it.
uniform float light_pickup : hint_range(0.0, 1.0) = 0.35;

void fragment() {
	vec3 c = texture(glass_tex, UV).rgb;
	ALBEDO = mix(c, vec3(0.6), 0.5) * light_pickup;
	EMISSION = c * brightness;
	ROUGHNESS = mix(gloss_roughness, 0.9, texture(rough_tex, UV).g);
	SPECULAR = shine;
	METALLIC = 0.0;
	NORMAL_MAP = texture(normal_tex, UV).rgb;
	NORMAL_MAP_DEPTH = bump;
}

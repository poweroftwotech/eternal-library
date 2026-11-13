shader_type spatial;
// Fish (phase 19 step 1) drawn over the water's surface at `clarity`, so they
// read in a bright pool (the goldfish). Drawn after the water (the material's
// render_priority), so the water's own tint and glints don't reach them; this
// puts the water back on them: the deeper a fish is, the more it takes the
// water's colour and the fainter it shows, moving bands of light (caustics)
// cross its back, its outline wavers (the include), and it has no shine of
// its own. See creature_fish.gdshaderinc.
render_mode world_vertex_coords, cull_disabled, depth_draw_never, specular_disabled;

#include "res://shaders/creature_fish.gdshaderinc"

void fragment() {
	vec4 c = fish_skin(UV);
	float deep = clamp(v_depth / 0.6, 0.0, 1.0);
	// The water's colour over it, by depth.
	float lum = dot(c.rgb, vec3(0.3, 0.55, 0.15));
	vec3 col = mix(c.rgb, water_tint * (0.55 + lum), 0.3 + 0.5 * deep);
	// Bands of light moving over its back.
	float bands = sin(v_at.x * 23.0 + TIME * 1.3) * sin(v_at.z * 19.0 - TIME * 1.1);
	col *= 0.9 + 0.22 * smoothstep(0.2, 0.9, bands) * (1.0 - 0.6 * deep);
	ALBEDO = col;
	EMISSION = col * self_glow;
	ROUGHNESS = 1.0;
	ALPHA = clarity * (1.0 - 0.45 * deep);
}

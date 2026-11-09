shader_type spatial;
// Fish (phase 19 step 1) drawn over the water's surface at `clarity`, so they
// read in a bright pool (the goldfish). Drawn after the water (the material's
// render_priority). See creature_fish.gdshaderinc.
render_mode world_vertex_coords, cull_disabled, depth_draw_never;

#include "res://shaders/creature_fish.gdshaderinc"

void fragment() {
	vec4 c = fish_skin(UV);
	ALBEDO = c.rgb;
	EMISSION = c.rgb * self_glow;
	ROUGHNESS = 0.6;
	SPECULAR = 0.2;
	ALPHA = clarity;
}

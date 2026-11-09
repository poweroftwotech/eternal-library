shader_type spatial;
// Fish (phase 19 step 1), drawn under the water like the pool's floor: the
// water's surface tints them. See creature_fish.gdshaderinc.
render_mode world_vertex_coords, cull_disabled;

#include "res://shaders/creature_fish.gdshaderinc"

void fragment() {
	vec4 c = fish_skin(UV);
	ALBEDO = c.rgb;
	EMISSION = c.rgb * self_glow;
	ROUGHNESS = 0.4;
	SPECULAR = 0.45;
}

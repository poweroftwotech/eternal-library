shader_type spatial;
// Glowworms (phase 19 step 2): a colony's points of light on a dark roof, one
// MultiMesh. An instance hangs from its origin on the roof, its basis setting
// the thread's width and length. Its bead is a quad (UV.y 1, corner in the
// vertex's x, z) turned to face the eye and never smaller than a few pixels,
// so a roof of them reads as a field of stars from the floor. Custom data: x
// phase (0..1), y when it goes dark (0..1: low ones first), z its own
// brightness. Per colony (GlowColony sets them): `dark` (0 all glowing, 1 all
// dark: you ran past) and `glow`, the area's fungus colour. Added light only:
// it lights nothing.
render_mode unshaded, cull_disabled, shadows_disabled, blend_add, depth_draw_never;

instance uniform float dark = 0.0;
instance uniform vec3 glow = vec3(0.4, 0.85, 1.0);
// The bead's core (m), and how many pixels it is at least (at 1080p).
uniform float core_radius = 0.012;
uniform float min_pixels = 2.2;
// The halo round it, as a multiple of the core.
uniform float halo = 4.0;
varying float v_lit;
varying vec2 v_corner;

void vertex() {
	float h = INSTANCE_CUSTOM.y;
	float on = smoothstep(h - 0.08, h + 0.08, 1.0 - dark);
	float pulse = 0.65 + 0.35 * sin(TIME * (0.3 + INSTANCE_CUSTOM.z * 0.4) + INSTANCE_CUSTOM.x * 6.2832);
	v_lit = on * pulse * (0.6 + 0.6 * INSTANCE_CUSTOM.z);
	v_corner = VERTEX.xz;
	if (UV.y > 0.5) {
		vec4 centre = VIEW_MATRIX * (MODEL_MATRIX * vec4(0.0, -1.0, 0.0, 1.0));
		float dist = max(-centre.z, 0.05);
		// A pixel's size at that distance (the lens's vertical view over 1080 rows).
		float px = 2.0 * dist / (PROJECTION_MATRIX[1][1] * 1080.0);
		float r = max(core_radius, px * min_pixels) * halo;
		centre.xy += VERTEX.xz * r;
		POSITION = PROJECTION_MATRIX * centre;
	} else {
		POSITION = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	}
}

void fragment() {
	if (UV.y > 0.5) {
		float d = length(v_corner) * halo;          // 1 at the core's edge
		float core = 1.0 - smoothstep(0.6, 1.0, d);
		float soft = exp(-d * 0.9) * 0.35;
		float a = core * 3.0 + soft;
		if (a < 0.004) {
			discard;
		}
		ALBEDO = glow * v_lit * a;
	} else {
		ALBEDO = glow * v_lit * 0.06;
	}
}

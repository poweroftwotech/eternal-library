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
//
// They are animals, not fungus, and move like it: each worm lets its thread
// down and reels it in, slowly and in its own time; the threads sway in the
// cave's air; waves of brightening pass across the colony; and now and then
// one flares (something touched its thread) and hauls its line up fast.
render_mode unshaded, cull_disabled, shadows_disabled, blend_add, depth_draw_never;

instance uniform float dark = 0.0;
instance uniform vec3 glow = vec3(0.4, 0.85, 1.0);
// The bead's core (m), and how many pixels it is at least (at 1080p).
uniform float core_radius = 0.012;
uniform float min_pixels = 2.2;
// The halo round it, as a multiple of the core.
uniform float halo = 4.0;
// How lively: 0 still (as fungus), 1 the usual.
uniform float life = 1.0;
varying float v_lit;
varying vec2 v_corner;

const float CATCH_EVERY = 38.0;   // s between one worm's catches, about
const float CATCH_S = 5.0;        // s a catch takes: flare, haul up, let down

void vertex() {
	float phase = INSTANCE_CUSTOM.x;
	float own = INSTANCE_CUSTOM.z;
	float h = INSTANCE_CUSTOM.y;
	vec3 roof = MODEL_MATRIX[3].xyz;
	float on = smoothstep(h - 0.08, h + 0.08, 1.0 - dark);
	// Its own slow pulse, and a wave crossing the colony.
	float pulse = 0.62 + 0.38 * sin(TIME * (0.3 + own * 0.4) + phase * 6.2832);
	float wave = 0.5 + 0.5 * sin(TIME * 0.55 - roof.x * 0.5 - roof.z * 0.37);
	// A catch: a flare, the line hauled in, then let down again.
	float period = CATCH_EVERY * (0.6 + own * 0.8);
	float c = fract(TIME / period + phase) * period;      // s into this worm's cycle
	float flare = (1.0 - smoothstep(0.0, 0.9, c)) * step(c, CATCH_S);
	float hauled = smoothstep(0.1, 0.8, c) * (1.0 - smoothstep(1.6, CATCH_S, c));
	// How far down its thread the bead hangs (0 at the roof, 1 full length).
	float let_down = 0.72 + 0.28 * sin(TIME * (0.11 + own * 0.13) + phase * 9.0);
	let_down = mix(1.0, let_down * (1.0 - 0.8 * hauled), life);
	v_lit = on * (pulse * mix(1.0, 0.55 + 0.75 * wave, life) + 2.2 * flare * life) * (0.6 + 0.6 * own);
	v_corner = VERTEX.xz;
	// The thread sways from the roof down, more at its end; the bead with it.
	float len = length(MODEL_MATRIX[1].xyz);
	vec2 sway = vec2(sin(TIME * 0.8 + phase * 11.0 + roof.x), cos(TIME * 0.63 + phase * 7.0 + roof.z)) * 0.035 * len * life;
	if (UV.y > 0.5) {
		vec3 world = roof + vec3(sway.x, -len, sway.y) * let_down;
		vec4 centre = VIEW_MATRIX * vec4(world, 1.0);
		float dist = max(-centre.z, 0.05);
		// A pixel's size at that distance (the lens's vertical view over 1080 rows).
		float px = 2.0 * dist / (PROJECTION_MATRIX[1][1] * 1080.0);
		float r = max(core_radius, px * min_pixels) * halo * (1.0 + 0.5 * flare * life);
		centre.xy += VERTEX.xz * r;
		POSITION = PROJECTION_MATRIX * centre;
	} else {
		float down = -VERTEX.y;                           // 0 at the roof, 1 at the end
		vec3 world = (MODEL_MATRIX * vec4(VERTEX.x, VERTEX.y * let_down, VERTEX.z, 1.0)).xyz;
		world.xz += sway * down * let_down;
		POSITION = PROJECTION_MATRIX * (VIEW_MATRIX * vec4(world, 1.0));
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
		ALBEDO = glow * v_lit * 0.1;
	}
}

shader_type spatial;
// The Lake Landing (phase 18, R20, Q7): a lantern's reflection painted on the
// water. A quad on the water's plane under the lantern (x across -0.5..0.5,
// z along 0..1) is turned every frame to run toward the camera and stretched
// with distance, as a light's reflection on rippled water does, and broken into
// shimmering bands that drift with the waves. Added, unshaded, no depth write.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled, world_vertex_coords;

uniform vec3 color : source_color = vec3(1.0, 0.7, 0.36);
uniform float strength = 1.0;
// The streak's length is distance * stretch, between min_length and max_length.
uniform float stretch = 0.16;
uniform float min_length = 1.2;
uniform float max_length = 26.0;
// Its width at the lantern, and how much it widens far off (so far lights read).
uniform float width = 0.35;
uniform float widen = 0.008;
uniform float simulation_time = 0.0;
varying float v_along;
varying float v_across;
varying float v_dist;

float hash(vec2 p){ return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p){
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void vertex(){
	vec3 origin = MODEL_MATRIX[3].xyz;
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	vec2 to_cam = cam.xz - origin.xz;
	float dist = max(length(to_cam), 0.01);
	vec2 dir = to_cam / dist;
	vec2 side = vec2(-dir.y, dir.x);
	// Object-space quad: x in -0.5..0.5, z in 0..1 (the mesh is built that way).
	vec3 local = (inverse(MODEL_MATRIX) * vec4(VERTEX, 1.0)).xyz;
	float along = clamp(local.z, 0.0, 1.0);
	float across = local.x;
	float len = clamp(dist * stretch, min_length, max_length);
	float w = width + dist * widen;
	// The reflection starts a little toward the camera from under the lamp.
	vec2 p = origin.xz + dir * (along * len) + side * across * w * (1.0 - 0.55 * along);
	VERTEX = vec3(p.x, origin.y, p.y);
	v_along = along;
	v_across = across;
	v_dist = dist;
}

void fragment(){
	float t = simulation_time;
	// Bands across the streak that shimmer and drift.
	float band = vnoise(vec2(v_along * 22.0 - t * 0.9, v_across * 3.0 + t * 0.3));
	band = smoothstep(0.35, 0.8, band);
	float fine = vnoise(vec2(v_along * 70.0 + t * 1.7, v_across * 9.0));
	float edge = 1.0 - smoothstep(0.15, 0.5, abs(v_across));
	float ends = smoothstep(0.0, 0.06, v_along) * (1.0 - smoothstep(0.55, 1.0, v_along));
	float far = 1.0 / (1.0 + v_dist * 0.012);
	float k = edge * ends * (0.25 + 0.75 * band) * (0.7 + 0.3 * fine) * far;
	ALBEDO = color * strength * k;
}

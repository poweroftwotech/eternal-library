shader_type spatial;
// Rings spreading on still water where a fall lands (the Bridge Hall's pit
// pool), snapped to the pixel grid (texel per m), fading by the disc's edge,
// with churned water in the middle. Draw it on a plane `radius * 2` across.
// simulation_time is driven by its owner so captures stay deterministic.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
uniform float simulation_time = 0.0;
uniform float radius = 2.0;         // m, the plane's half size
uniform float texel = 32.0;
uniform vec3 colour : source_color = vec3(.55, .66, .68);
uniform float strength = .25;
uniform float speed = .45;          // m/s the rings spread
uniform float spacing = .45;        // m between rings
float hash(vec2 p){ return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void fragment(){
	vec2 m = floor((UV - .5) * 2.0 * radius * texel) / texel;   // metres, one value per texel
	float r = length(m);
	float phase = fract((r - simulation_time * speed) / spacing);
	float ring = smoothstep(0.0, .1, phase) * (1.0 - smoothstep(.1, .3, phase));
	float fade = 1.0 - smoothstep(radius * .3, radius, r);
	float churn = (1.0 - smoothstep(0.0, radius * .3, r)) * (.4 + .6 * hash(m * 7.0 + floor(simulation_time * 8.0)));
	ALBEDO = colour * (ring * fade * (1.0 - churn) + churn) * strength;
}

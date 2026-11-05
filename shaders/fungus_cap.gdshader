shader_type spatial;
render_mode unshaded, cull_back;
// The Fungus Terraces' caps (phase 13, walk 4: "solid color… flat 2d shape"
// and, lit, they washed out to white). Glowing, so unlit and saturated; read in
// the round by shading them from the shape itself: brightest on top, darker
// down the sides and rim, mottled in pixels. Gills use it dark and flat.

uniform vec3 color : source_color = vec3(0.55, 0.25, 0.95);
uniform float top = 1.15;          // brightness facing up
uniform float side = 0.45;         // brightness facing sideways (and below)
uniform float mottle = 0.25;       // pixel speckle, +-
uniform sampler2D mottle_tex : filter_nearest, repeat_enable;

varying vec3 wpos;
varying vec3 wnorm;

void vertex(){
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
void fragment(){
	float up = clamp(wnorm.y, 0.0, 1.0);
	float shade = mix(side, top, up * up);
	vec2 uv = abs(wnorm.y) > 0.6 ? wpos.xz : vec2(wpos.x + wpos.z, wpos.y);
	float m = texture(mottle_tex, uv * 3.0).r;
	ALBEDO = color * shade * (1.0 + (m - 0.5) * 2.0 * mottle);
}

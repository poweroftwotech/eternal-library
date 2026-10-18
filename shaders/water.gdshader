shader_type spatial;
// v0.12 channel water: pixel-snapped flowing normals (32 texels/m), refraction
// of the real streambed, depth-based tint and edge foam. simulation_time is
// driven by atmosphere.gd so captures stay deterministic.
render_mode cull_disabled, depth_draw_never;
uniform float simulation_time = 0.0;
uniform vec3 shallow_tint : source_color = vec3(.78,.9,.8);
uniform vec3 deep_tint : source_color = vec3(.10,.20,.18);
uniform vec2 flow = vec2(0.0, .22);          // m/s, along +z toward the camp
uniform float texel = 32.0;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
varying vec3 world_pos;

float hash(vec2 p){ return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p){
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
float waves(vec2 p, float t){
	return vnoise(p * 5.0 - flow * t * 5.0) * .6
		+ vnoise(p * 11.0 - flow * t * 9.0 + 3.7) * .3
		+ vnoise(p * 23.0 + vec2(t * .4, -t * .3)) * .1;
}
void vertex(){ world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment(){
	float e = 1.0 / texel;
	vec2 p = floor(world_pos.xz * texel) * e;          // one value per texel
	float t = simulation_time;
	float h = waves(p, t);
	float dx = waves(p + vec2(e, 0), t) - h;
	float dz = waves(p + vec2(0, e), t) - h;
	NORMAL_MAP = normalize(vec3(-dx * 3.0, -dz * 3.0, 1.0)) * .5 + .5;
	NORMAL_MAP_DEPTH = .9;
	// Water thickness along the view ray, from the opaque depth buffer.
	float depth = textureLod(depth_tex, SCREEN_UV, 0.0).r;
	vec4 view = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	view.xyz /= view.w;
	float thickness = max(VERTEX.z - view.z, 0.0);
	float murk = clamp(thickness / .6, 0.0, 1.0);
	vec3 bed = textureLod(screen_tex, SCREEN_UV + vec2(dx, dz) * .05 * murk, 0.0).rgb;
	float foam = step(thickness, .03 + h * .035);       // contact lines at banks and stones
	vec3 tint = mix(shallow_tint, deep_tint, murk);
	ALBEDO = mix(tint * .25, vec3(.80, .84, .76), foam * .8);
	EMISSION = bed * tint * (1.0 - foam * .8);
	ROUGHNESS = .2;
	SPECULAR = .3;
	METALLIC = 0.0;
	ALPHA = 1.0;
}

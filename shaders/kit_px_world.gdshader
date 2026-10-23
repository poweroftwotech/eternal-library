// Kit pixel materials on world triplanar (ENVIRONMENT_PLAN.md polish C item 9).
// The same sampling as a StandardMaterial3D with uv1_world_triplanar (texture
// filter nearest + mipmaps + anisotropic, roughness from R, metallic_specular),
// plus world-space variation that breaks up the 2 m tiling:
//  * macro tint and roughness: value noise at 1.5 m and 5 m, read at the centre
//    of the 32 tx/m texel and quantised to a few steps with ordered dithering,
//    so every texel still holds one flat colour;
//  * floor wear: walked paths polished into the floor, from the room's baked
//    wear map (FloorWear sets the kit_wear_* globals; no FloorWear, no wear).
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D texture_albedo : source_color, filter_nearest_mipmap_anisotropic, repeat_enable;
uniform sampler2D texture_roughness : hint_roughness_r, filter_nearest_mipmap_anisotropic, repeat_enable;
uniform sampler2D texture_normal : hint_roughness_normal, filter_nearest_mipmap_anisotropic, repeat_enable;
uniform float specular = 0.65;
uniform float normal_scale = 1.0;
uniform vec3 uv1_scale = vec3(0.5);
uniform float uv1_blend_sharpness = 1.0;

group_uniforms macro;
uniform float tint_strength = 0.12;    // +- albedo brightness at the extremes
uniform vec3 tint_warm : source_color = vec3(1.04, 0.98, 0.9);   // hue of the darker patches
uniform float rough_variation = 0.12;  // +- roughness
uniform float tint_steps = 4.0;        // quantisation levels per side
uniform vec3 albedo_scale = vec3(1.0);  // a paler or darker copy of a texture (dome_plaster)
group_uniforms wear;
uniform float wear_strength = 0.0;     // 0 off; floor_stone polishes walked paths
uniform float wear_roughness = 0.3;    // roughness at full wear
group_uniforms;

global uniform sampler2D kit_wear_map : filter_nearest;
global uniform vec4 kit_wear_rect;     // world x, z of the map's corner; size x, z (m)
global uniform vec2 kit_wear_y;        // world y range that gets wear (ground floor only)

const float TEXEL = 32.0;

varying vec3 uv1_triplanar_pos;
varying vec3 uv1_power_normal;
varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	vec3 normal = MODEL_NORMAL_MATRIX * NORMAL;
	TANGENT = vec3(0.0, 0.0, -1.0) * abs(normal.x);
	TANGENT += vec3(1.0, 0.0, 0.0) * abs(normal.y);
	TANGENT += vec3(1.0, 0.0, 0.0) * abs(normal.z);
	TANGENT = inverse(MODEL_NORMAL_MATRIX) * normalize(TANGENT);
	BINORMAL = vec3(0.0, 1.0, 0.0) * abs(normal.x);
	BINORMAL += vec3(0.0, 0.0, -1.0) * abs(normal.y);
	BINORMAL += vec3(0.0, 1.0, 0.0) * abs(normal.z);
	BINORMAL = inverse(MODEL_NORMAL_MATRIX) * normalize(BINORMAL);
	uv1_power_normal = pow(abs(normal), vec3(uv1_blend_sharpness));
	uv1_power_normal /= dot(uv1_power_normal, vec3(1.0));
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(normal);
	uv1_triplanar_pos = world_pos * uv1_scale * vec3(1.0, -1.0, 1.0);
}

vec4 triplanar_texture(sampler2D p_sampler, vec3 p_weights, vec3 p_triplanar_pos) {
	vec4 samp = vec4(0.0);
	samp += texture(p_sampler, p_triplanar_pos.xy) * p_weights.z;
	samp += texture(p_sampler, p_triplanar_pos.xz) * p_weights.y;
	samp += texture(p_sampler, p_triplanar_pos.zy * vec2(-1.0, 1.0)) * p_weights.x;
	return samp;
}

float hash3(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.x + p.y) * p.z);
}

float value_noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash3(i), hash3(i + vec3(1, 0, 0)), f.x),
	               mix(hash3(i + vec3(0, 1, 0)), hash3(i + vec3(1, 1, 0)), f.x), f.y),
	           mix(mix(hash3(i + vec3(0, 0, 1)), hash3(i + vec3(1, 0, 1)), f.x),
	               mix(hash3(i + vec3(0, 1, 1)), hash3(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

// 4x4 Bayer threshold in -0.5..0.5 for an integer texel coordinate.
float bayer(ivec2 c) {
	int m[16] = int[16](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	return float(m[(c.y & 3) * 4 + (c.x & 3)]) / 16.0 - 0.5;
}

void fragment() {
	vec4 albedo_tex = triplanar_texture(texture_albedo, uv1_power_normal, uv1_triplanar_pos);
	float rough = triplanar_texture(texture_roughness, uv1_power_normal, uv1_triplanar_pos).r;

	// Centre of this texel on the 32 tx/m grid. Nudge inward along the normal
	// so a face lying exactly on a grid plane doesn't flicker between cells.
	vec3 n = world_normal;
	vec3 cell = floor((world_pos - n * 0.25 / TEXEL) * TEXEL);
	vec3 centre = (cell + 0.5) / TEXEL;
	vec3 an = abs(n);
	ivec2 face = an.y > max(an.x, an.z) ? ivec2(cell.xz) : (an.x > an.z ? ivec2(cell.zy) : ivec2(cell.xy));
	float d = bayer(face);

	float macro = value_noise(centre / 1.5) * 0.6 + value_noise(centre / 5.0 + 17.0) * 0.4;
	float tone = clamp(floor((macro - 0.5) * 2.0 * tint_steps + 0.5 + d * 0.9), -tint_steps, tint_steps) / tint_steps;
	vec3 tint = mix(vec3(1.0), tint_warm, clamp(-tone, 0.0, 1.0)) * (1.0 + tone * tint_strength);
	float grit = value_noise(centre / 0.9 + 41.0);
	rough += (floor((grit - 0.5) * 2.0 * tint_steps + 0.5 + d * 0.9) / tint_steps) * rough_variation;

	if (wear_strength > 0.0 && kit_wear_rect.z > 0.0 && n.y > 0.7 && centre.y > kit_wear_y.x && centre.y < kit_wear_y.y) {
		vec2 wuv = (centre.xz - kit_wear_rect.xy) / kit_wear_rect.zw;
		if (all(greaterThanEqual(wuv, vec2(0.0))) && all(lessThan(wuv, vec2(1.0)))) {
			float wear = texture(kit_wear_map, wuv).r * wear_strength;
			rough = mix(rough, wear_roughness, wear);
			tint *= 1.0 - wear * 0.05;   // polish deepens the colour a touch
		}
	}

	ALBEDO = albedo_tex.rgb * tint * albedo_scale;
	ROUGHNESS = clamp(rough, 0.05, 1.0);
	METALLIC = 0.0;
	SPECULAR = specular;
	NORMAL_MAP = triplanar_texture(texture_normal, uv1_power_normal, uv1_triplanar_pos).rgb;
	NORMAL_MAP_DEPTH = normal_scale;
}

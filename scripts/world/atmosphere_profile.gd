@tool
class_name AtmosphereProfile
extends Resource
## The "look" of an area or room (ENVIRONMENT_PLAN.md 4.2, phase 1 step 4):
## tonemap, ambient, glow, haze, AO, grade and GI. Ported from the constants in
## scripts/art_direction.gd. kit/atmosphere/prototype_v011.tres holds exactly
## the prototype's numbers, and art_direction.gd now applies it, so tuning that
## file changes the prototype too. Rules in ART_DIRECTION.md section 2: teal
## shadows / amber highlights, saturation x1.12, never a black foreground.
##
## The defaults below ARE the prototype's v0.11 numbers, and prototype_v011.tres
## stores only what differs from them (nothing). Tune profiles in their .tres
## files; changing a default here would silently change the prototype.

@export_group("Background")
## Only used when the profile builds a whole Environment (Atmosphere node).
@export var background_color: Color = Color("080f17")

@export_group("Tonemap and ambient")
@export var tonemapper: Environment.ToneMapper = Environment.TONE_MAPPER_AGX
@export_range(0.1, 4.0, 0.01) var exposure: float = 0.97
@export var ambient_color: Color = Color("5a86a6")
@export_range(0.0, 4.0, 0.01) var ambient_energy: float = 0.22

@export_group("Glow")
@export_range(0.0, 4.0, 0.01) var glow_intensity: float = 0.85
@export_range(0.0, 1.0, 0.01) var glow_bloom: float = 0.04
@export_range(0.0, 4.0, 0.01) var glow_threshold: float = 0.95
@export_range(0.0, 4.0, 0.01) var glow_hdr_scale: float = 2.0
## Which of the 7 glow levels contribute (1.0 on, 0.0 off).
@export var glow_levels: PackedFloat32Array = [0.0, 1.0, 1.0, 1.0, 1.0, 1.0, 0.0]

@export_group("Haze")
@export_range(0.0, 0.2, 0.0001) var fog_density: float = 0.003
@export var fog_albedo: Color = Color("c0c6bf")
@export_range(0.0, 1.0, 0.01) var fog_ambient_inject: float = 0.22
## Forward scattering: light shafts glow toward the camera.
@export_range(-0.9, 0.9, 0.01) var fog_anisotropy: float = 0.55

@export_group("Ambient occlusion")
@export_range(0.0, 16.0, 0.01) var ssao_intensity: float = 2.2
@export_range(0.01, 16.0, 0.01) var ssao_radius: float = 1.0
@export_range(0.0, 8.0, 0.01) var ssao_power: float = 1.6
@export_range(0.0, 5.0, 0.01) var ssao_detail: float = 0.7
@export_range(0.0, 1.0, 0.01) var ssao_light_affect: float = 0.35

@export_group("Grade")
@export_range(0.5, 2.0, 0.01) var contrast: float = 1.06
@export_range(0.0, 3.0, 0.01) var saturation: float = 1.12
## Per-channel curve: shadows lean teal, highlights lean amber.
@export var split_tone: Gradient = default_split_tone()

@export_group("Global illumination")
## SDFGI: real bounce light (warm lantern bounce on stone). Costs GPU time.
@export var sdfgi: bool = true
@export_range(0.0, 4.0, 0.01) var sdfgi_energy: float = 1.0
@export_range(0.01, 1.0, 0.01) var sdfgi_min_cell_size: float = 0.15

@export_group("Lamps")
## Gentle sway of lit lantern lights (fraction of energy), from atmosphere.gd.
@export_range(0.0, 0.3, 0.005) var lantern_sway: float = 0.045


## The prototype's v0.11 grade curve (art_direction.gd split_tone()).
static func default_split_tone() -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.18, 0.5, 0.82, 1.0])
	g.colors = PackedColorArray([
		Color(0.0, 0.012, 0.018), Color(0.155, 0.185, 0.195), Color(0.495, 0.50, 0.50),
		Color(0.83, 0.82, 0.80), Color(0.98, 0.98, 0.965)])
	return g


## Writes the look onto an existing Environment. Touches exactly what
## art_direction.gd environment() used to set, so the prototype is unchanged.
func apply(env: Environment) -> void:
	env.tonemap_mode = tonemapper
	env.tonemap_exposure = exposure
	env.ambient_light_color = ambient_color
	env.ambient_light_energy = ambient_energy
	env.glow_enabled = true
	env.glow_intensity = glow_intensity
	env.glow_strength = 1.0
	env.glow_bloom = glow_bloom
	env.glow_hdr_threshold = glow_threshold
	env.glow_hdr_scale = glow_hdr_scale
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	for i: int in 7:
		env.set_glow_level(i, glow_levels[i] if i < glow_levels.size() else 0.0)
	env.volumetric_fog_density = fog_density
	env.volumetric_fog_albedo = fog_albedo
	env.volumetric_fog_ambient_inject = fog_ambient_inject
	env.volumetric_fog_anisotropy = fog_anisotropy
	env.ssao_intensity = ssao_intensity
	env.ssao_radius = ssao_radius
	env.ssao_power = ssao_power
	env.ssao_detail = ssao_detail
	env.ssao_light_affect = ssao_light_affect
	env.adjustment_enabled = true
	env.adjustment_contrast = contrast
	env.adjustment_saturation = saturation
	var tex := GradientTexture1D.new()
	tex.gradient = split_tone
	tex.width = 256
	env.adjustment_color_correction = tex
	if sdfgi:
		env.sdfgi_enabled = true
		env.sdfgi_use_occlusion = true
		env.sdfgi_energy = sdfgi_energy
		env.sdfgi_cascades = 4
		env.sdfgi_min_cell_size = sdfgi_min_cell_size


## A complete Environment for a room that owns its look (Atmosphere node):
## the background, ambient source, fog and AO switches the prototype sets in
## world.gd, then apply().
func build_environment() -> Environment:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = background_color
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.volumetric_fog_enabled = fog_density > 0.0
	env.ssao_enabled = ssao_intensity > 0.0
	env.ssil_enabled = true
	env.ssil_intensity = 0.7
	apply(env)
	return env

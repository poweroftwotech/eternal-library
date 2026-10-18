extends RefCounted
## v0.11 art-direction pass. Runs last in world._ready (before merging and
## atmosphere) and owns the "look": light hierarchy, haze, bloom and grade.
## Targets come from design/Campfire in the Eternal Library.png; see
## ART_DIRECTION.md for the rules and the measured luminance targets.
##
## Brightness hierarchy we are building (brightest first):
##   1. sunlit garden through the central arch (hero)
##   2. hearth fire + lanterns (bloom halos)
##   3. warm firelit foreground (pot, provisions, piers)
##   4. cool teal archive on the right
## Every number that matters is a constant here so it can be tuned from captures.

const TONEMAPPER: int = Environment.TONE_MAPPER_AGX
const EXPOSURE: float = .97
const AMBIENT_ENERGY: float = .22
const AMBIENT_COLOR: Color = Color("5a86a6")

const GARDEN_KEY_ENERGY: float = 15.0      # SpotLight under the lightwell
const GARDEN_KEY_COLOR: Color = Color("f2f5e2")
const GARDEN_KEY_AIM: Vector3 = Vector3(-1.7,0,-3.4)  # tilted toward the arch/camera
const GARDEN_FOG_ENERGY: float = 1.3        # how strongly the key paints the haze
const GARDEN_HAZE_SCALE: float = 2.0        # multiplies existing garden FogVolumes
const GLOBAL_HAZE: float = .0030
const LIGHTWELL_GLOW: float = 1.0           # emissive glass in the vault opening

const FIRE_ENERGY: float = 2.4              # base; atmosphere.gd adds flicker
const EMBER_GLOW: float = 1.8
const LANTERN_FLAME_GLOW: float = 2.5
const LANTERN_LIGHT_SCALE: float = .1     # lamp OmniLights (world.lantern, 1.8 base)
const ARCHIVE_FILL_ENERGY: float = 2.9       # cool teal fill on the right-hand shelves

const SSAO_INTENSITY: float = 2.2
const GLOW_THRESHOLD: float = .95
const GLOW_INTENSITY: float = .85
const GLOW_BLOOM: float = .04

## SDFGI gives real bounce light (warm fire bounce on the piers) but costs GPU
## time. Off by default; try it on the target machine.
const USE_SDFGI: bool = true

var world
var art

func _init(owner, factory) -> void:
	world = owner
	art = factory

func build() -> void:
	environment()
	garden_key()
	hearth()
	foreground_fill()
	archive_fill()
	enforce_texel_density()

func environment() -> void:
	var env: Environment = world.environment
	env.tonemap_mode = TONEMAPPER
	env.tonemap_exposure = EXPOSURE
	env.ambient_light_color = AMBIENT_COLOR
	env.ambient_light_energy = AMBIENT_ENERGY
	env.glow_enabled = true
	env.glow_intensity = GLOW_INTENSITY
	env.glow_strength = 1.0
	env.glow_bloom = GLOW_BLOOM
	env.glow_hdr_threshold = GLOW_THRESHOLD
	env.glow_hdr_scale = 2.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	for i in range(7):
		env.set_glow_level(i,1.0 if i in [1,2,3,4,5] else 0.0)
	env.volumetric_fog_density = GLOBAL_HAZE
	env.volumetric_fog_albedo = Color("c0c6bf")
	env.volumetric_fog_ambient_inject = .22
	env.volumetric_fog_anisotropy = .55   # forward scattering: shafts glow toward camera
	# Grounding: stronger, tighter AO that also darkens direct light at contacts.
	env.ssao_intensity = SSAO_INTENSITY
	env.ssao_radius = 1.0
	env.ssao_power = 1.6
	env.ssao_detail = .7
	env.ssao_light_affect = .35
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.06
	env.adjustment_saturation = 1.12
	env.adjustment_color_correction = split_tone()
	if USE_SDFGI:
		env.sdfgi_enabled = true
		env.sdfgi_use_occlusion = true
		env.sdfgi_energy = 1.0
		env.sdfgi_cascades = 4
		env.sdfgi_min_cell_size = .15

## Per-channel curves: shadows lean teal, highlights lean amber (concept grade).
func split_tone() -> GradientTexture1D:
	var gradient = Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0,.18,.5,.82,1.0])
	gradient.colors = PackedColorArray([
		Color(0.0,0.012,0.018),
		Color(.155,.185,.195),
		Color(.495,.50,.50),
		Color(.83,.82,.80),
		Color(.98,.98,.965)])
	var texture = GradientTexture1D.new()
	texture.gradient = gradient
	texture.width = 256
	return texture

func garden_key() -> void:
	for child in world.get_children():
		if child is SpotLight3D:
			child.light_energy = GARDEN_KEY_ENERGY
			child.light_color = GARDEN_KEY_COLOR
			child.light_volumetric_fog_energy = GARDEN_FOG_ENERGY
			child.spot_angle = 36
			child.spot_range = 30
			child.set_meta("base_energy",GARDEN_KEY_ENERGY)
			child.set_meta("aim",GARDEN_KEY_AIM)
			child.look_at(GARDEN_KEY_AIM,Vector3.FORWARD)
		if child is FogVolume and child.position.z < -2.0 and child.position.z > -10.0:
			var material: FogMaterial = child.material
			material.density *= GARDEN_HAZE_SCALE
			material.albedo = Color("dde4d8")
	# Sunlit back gallery, stair and tree crown (concept: the far court is lit).
	var back = world.light(Vector3(-2.4,5.5,-9.2),Color("e6ead6"),1.7,11)
	back.light_cull_mask = 1
	back.light_volumetric_fog_energy = .6
	var crown = world.light(Vector3(-3.6,7.5,-5.0),Color("eef4dc"),2.4,8)
	crown.light_cull_mask = 1
	# The vault's glazed opening reads as the sky source and blooms.
	for node in world.find_children("*","MeshInstance3D",true,false):
		var material = node.material_override
		if material is StandardMaterial3D and material.emission_enabled and material.emission.is_equal_approx(Color("c1d8c6")):
			material.emission = Color("f2f8ec")
			material.emission_energy_multiplier = LIGHTWELL_GLOW

func hearth() -> void:
	world.fire_light.set_meta("base_energy",FIRE_ENERGY)
	world.fire_light.light_volumetric_fog_energy = 1.5
	var ember = art.mat("ember")
	ember.emission_energy_multiplier = EMBER_GLOW
	for node in world.find_children("*","MeshInstance3D",true,false):
		var material = node.material_override
		if material is StandardMaterial3D and material.emission_enabled and material.emission.is_equal_approx(Color("ffd27d")):
			material.emission_energy_multiplier = LANTERN_FLAME_GLOW
	for node in world.find_children("*","OmniLight3D",true,false):
		if node.has_meta("lantern"):
			node.light_energy *= LANTERN_LIGHT_SCALE
	for data in world.effects:
		if data.kind == "flame":
			var material: StandardMaterial3D = data.material
			material.albedo_color = Color(2.2,1.5,.9)   # HDR so flame cards bloom
	# Warm bounce from the fire onto the near piers and pot belly.
	var bounce = world.light(world.hearth+Vector3(0,.6,1.4),Color("ff9a4a"),1.0,5.5)
	bounce.light_cull_mask = 1

func foreground_fill() -> void:
	# Concept's left edge is lantern-lit shelving, not black (measured 44 vs 13).
	var left = world.light(Vector3(-5.6,1.7,6.2),Color("ffd0a4"),2.0,6.5)
	left.shadow_enabled = true
	left.light_cull_mask = 1
	var shelves = world.light(Vector3(-7.2,2.8,3.6),Color("e8c098"),1.25,5.0)
	shelves.light_cull_mask = 1

## Rule 1: one texel = 1/32 m everywhere. Duplicated materials that changed
## uv1_scale (e.g. organic_pass paving) are reset to the pixel density.
func enforce_texel_density() -> void:
	for node in world.find_children("*","GeometryInstance3D",true,false):
		var material = node.get("material_override")
		if material is StandardMaterial3D and material.has_meta("px_scale"):
			material.uv1_scale = material.get_meta("px_scale")

func archive_fill() -> void:
	# Concept's right archive is cool but readable (41), never a black wall.
	var archive = world.light(Vector3(6.8,3.0,1.2),Color("2c74e6"),ARCHIVE_FILL_ENERGY,7.5)
	archive.light_cull_mask = 1

class_name BazaarLife
extends Node3D
## The R04 Grand Bazaar's air (phase 15 steps 2 and 4). BazaarGrammar puts this (slot
## bz:life) at the room's origin; on _ready it reads grid.meta and adds the dust
## turning slowly in the crossing's beam, steam off the food stalls' pots and the
## fountain's spray. No lights, no collision. PipelineWarm draws warm() while a place settles.

## How high the dust's column reaches, and its radius.
const DUST_TOP: float = 15.0
const DUST_RADIUS: float = 2.6

static var _dust_mat: StandardMaterial3D
static var _steam_mat: StandardMaterial3D


func _ready() -> void:
	_build()


func _build() -> void:
	await get_tree().process_frame
	var room: GeneratedRoom = _room()
	if room == null or room.grid == null or not room.grid.meta.has("bazaar"):
		return
	var meta: Dictionary = room.grid.meta
	var dust: GPUParticles3D = _dust(90)
	dust.position = (meta["centre"] as Vector3) + Vector3(0.0, DUST_TOP * 0.5, 0.0) - position
	add_child(dust)
	for at: Vector3 in meta.get("steam", []):
		var s: GPUParticles3D = _steam()
		s.position = at - position
		add_child(s)
	if (meta.get("jet", Vector3.ZERO) as Vector3) != Vector3.ZERO:
		var jet: GPUParticles3D = GardenCourtLife._jet()
		(jet.process_material as ParticleProcessMaterial).spread = 9.0
		jet.position = (meta["jet"] as Vector3) - position
		add_child(jet)


## Slow soft puffs rising off a pot and thinning out under the shop's vault.
static func _steam() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "Steam"
	var quad := QuadMesh.new()
	quad.size = Vector2(0.5, 0.5)
	quad.material = _steam_material()
	p.draw_pass_1 = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.amount = 14
	p.lifetime = 4.5
	p.randomness = 0.6
	p.preprocess = 4.5
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = 0.18
	m.direction = Vector3.UP
	m.spread = 12.0
	m.gravity = Vector3.ZERO
	m.initial_velocity_min = 0.3
	m.initial_velocity_max = 0.5
	m.scale_min = 0.5
	m.scale_max = 0.9
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.5))
	grow.add_point(Vector2(1.0, 1.6))
	var size := CurveTexture.new()
	size.curve = grow
	m.scale_curve = size
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0))
	fade.set_color(1, Color(1, 1, 1, 0))
	fade.add_point(0.2, Color(1, 1, 1, 0.5))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	m.color_ramp = ramp
	p.process_material = m
	p.visibility_aabb = AABB(Vector3(-2.0, -1.0, -2.0), Vector3(4.0, 5.0, 4.0))
	return p


static func _steam_material() -> StandardMaterial3D:
	if _steam_mat == null:
		_steam_mat = StandardMaterial3D.new()
		_steam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_steam_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		_steam_mat.vertex_color_use_as_albedo = true
		_steam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_steam_mat.albedo_color = Color(0.95, 0.82, 0.68, 0.42)
		var soft := Gradient.new()
		soft.set_color(0, Color(1, 1, 1, 1))
		soft.set_color(1, Color(1, 1, 1, 0))
		var tex := GradientTexture2D.new()
		tex.gradient = soft
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1.0, 0.5)
		_steam_mat.albedo_texture = tex
	return _steam_mat


static func _dust(amount: int) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "Dust"
	var quad := QuadMesh.new()
	quad.size = Vector2(0.025, 0.025)
	quad.material = _dust_material()
	p.draw_pass_1 = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.amount = amount
	p.lifetime = 14.0
	p.randomness = 1.0
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = Vector3(DUST_RADIUS, DUST_TOP * 0.5, DUST_RADIUS)
	m.gravity = Vector3(0.0, -0.01, 0.0)
	m.direction = Vector3.UP
	m.spread = 180.0
	m.initial_velocity_min = 0.03
	m.initial_velocity_max = 0.12
	m.turbulence_enabled = true
	m.turbulence_noise_strength = 0.6
	m.turbulence_noise_scale = 3.0
	m.turbulence_influence_min = 0.03
	m.turbulence_influence_max = 0.08
	m.scale_min = 0.6
	m.scale_max = 1.4
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0))
	fade.set_color(1, Color(1, 1, 1, 0))
	fade.add_point(0.2, Color(1, 1, 1, 1))
	fade.add_point(0.75, Color(1, 1, 1, 0.8))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	m.color_ramp = ramp
	p.process_material = m
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-5.0, -10.0, -5.0), Vector3(10.0, 20.0, 10.0))
	return p


static func _dust_material() -> StandardMaterial3D:
	if _dust_mat == null:
		_dust_mat = StandardMaterial3D.new()
		_dust_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_dust_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_dust_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_dust_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		_dust_mat.vertex_color_use_as_albedo = true
		_dust_mat.albedo_color = Color(1.0, 0.88, 0.62)
		_dust_mat.disable_receive_shadows = true
	return _dust_mat


func _room() -> GeneratedRoom:
	var n: Node = get_parent()
	while n != null and not n is GeneratedRoom:
		n = n.get_parent()
	return n as GeneratedRoom


static func warm() -> Array[GPUParticles3D]:
	return [_dust(2), _steam()]

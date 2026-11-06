class_name QuarterLife
extends Node3D
## The R06 Domicile Quarter's motion (phase 14 step 2). QuarterGrammar puts this
## (slot qt:life) at the room's origin; on _ready it reads grid.meta and adds:
##   - cooking smoke rising from the roofs' chimneys (meta.smoke);
##   - in the Bath Ring, steam from the lantern on the dome;
##   - at the Hauz Square, a drop now and then on the pool.
## The washing moves by itself (its material is kit_foliage.gdshader).
## Particles only: no lights, no collision. One emitter a frame; PipelineWarm
## draws warm() while a place settles.

## The top of the bath-house's lantern above the ground.
const BATH_TOP: float = 12.3
## The hauz's water above the ground, and how far from its middle drops land.
const POOL_Y: float = 0.33
const POOL_REACH: float = 1.2

static var _puff_mat: StandardMaterial3D


func _ready() -> void:
	_build()


func _build() -> void:
	await get_tree().process_frame
	var room: GeneratedRoom = _room()
	if room == null or room.grid == null or not room.grid.meta.has("quarter"):
		return
	var meta: Dictionary = room.grid.meta
	var mark: Vector3 = meta["landmark"]
	var i: int = 0
	for at: Vector3 in meta.get("smoke", []):
		await get_tree().process_frame
		if not is_inside_tree():
			return
		var p: GPUParticles3D = _smoke(36)
		p.name = "Smoke_%d" % i
		p.position = at - position
		add_child(p)
		i += 1
	if meta.get("deserted", false):
		return
	if meta["layout"] == "bath":
		var steam: GPUParticles3D = _smoke(54)
		steam.name = "Steam"
		steam.position = mark + Vector3(0.0, BATH_TOP, 0.0) - position
		add_child(steam)
	elif meta["layout"] == "hauz":
		var drops: GPUParticles3D = ConeDrips._splashes()
		drops.name = "PoolDrops"
		drops.amount = 2
		drops.position = mark + Vector3(0.0, POOL_Y, 0.0) - position
		var m: ParticleProcessMaterial = drops.process_material
		m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		m.emission_box_extents = Vector3(POOL_REACH, 0.0, POOL_REACH)
		m.initial_velocity_max = 0.7
		add_child(drops)
		FungusTerracesLife._sparse_splash(drops, 4.0)


func _room() -> GeneratedRoom:
	var n: Node = get_parent()
	while n != null and not n is GeneratedRoom:
		n = n.get_parent()
	return n as GeneratedRoom


## Thin smoke going straight up and spreading as it fades.
static func _smoke(amount: int) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.7, 0.7)
	quad.material = _material()
	p.draw_pass_1 = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.amount = amount
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.visibility_aabb = AABB(Vector3(-4.0, -1.0, -4.0), Vector3(8.0, 9.0, 8.0))
	var m := ParticleProcessMaterial.new()
	m.direction = Vector3.UP
	m.spread = 7.0
	m.gravity = Vector3.ZERO
	m.initial_velocity_min = 0.35
	m.initial_velocity_max = 0.55
	m.turbulence_enabled = true
	m.turbulence_noise_strength = 0.5
	m.turbulence_noise_scale = 2.5
	m.turbulence_influence_min = 0.03
	m.turbulence_influence_max = 0.08
	var size := Curve.new()
	size.max_value = 3.0
	size.add_point(Vector2(0.0, 0.4))
	size.add_point(Vector2(1.0, 2.4))
	var sizes := CurveTexture.new()
	sizes.curve = size
	m.scale_curve = sizes
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0))
	fade.set_color(1, Color(1, 1, 1, 0))
	fade.add_point(0.12, Color(1, 1, 1, 1))
	fade.add_point(0.6, Color(1, 1, 1, 0.45))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	m.color_ramp = ramp
	p.process_material = m
	return p


static func _material() -> StandardMaterial3D:
	if _puff_mat == null:
		var soft := Gradient.new()
		soft.set_color(0, Color(1, 1, 1, 1))
		soft.set_color(1, Color(1, 1, 1, 0))
		var tex := GradientTexture2D.new()
		tex.gradient = soft
		tex.width = 16
		tex.height = 16
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1.0, 0.5)
		_puff_mat = StandardMaterial3D.new()
		_puff_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_puff_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_puff_mat.albedo_texture = tex
		_puff_mat.albedo_color = Color(0.5, 0.46, 0.5, 0.13)
		_puff_mat.vertex_color_use_as_albedo = true
		_puff_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		_puff_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	return _puff_mat


static func warm() -> Array[GPUParticles3D]:
	return [_smoke(2)]

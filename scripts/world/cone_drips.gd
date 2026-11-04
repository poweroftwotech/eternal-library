class_name ConeDrips
extends Node3D
## Water in the Light-Well Stair (room rework step 6, your walk: "water drops
## and moisture"). RingGrammar puts this (slot cone:drips) on the cone's axis
## at the floor; on _ready it reads the room's grid.meta and adds:
##  - drops falling from the oculus's vines through the sunlight to the pool,
##  - drips from under each storey's ledge, all the way round the stair,
##  - small splashes on the pool.
## Particles only: no collision, no lights. One emitter a frame (the room
## rework's frame gate: all three at once took 20 ms of the room's entry), and
## PipelineWarm draws warm() while a place settles, so their shaders are ready.
const G: float = 9.8
const POOL_Z: float = 0.3           # kit_add_r03.py cone_base: the water
const POOL_R: float = 1.55
const DROP_LEN: float = 0.11
## The ledge drips fall this share of the way out from the axis (your walk:
## toward the middle, about 60%), so they start in the open shaft.
const LEDGE_IN: float = 0.6


func _ready() -> void:
	_build()


func _build() -> void:
	await get_tree().process_frame
	var room: GeneratedRoom = _room()
	if room == null or room.grid == null or not room.grid.meta.has("cone"):
		return
	var meta: Dictionary = room.grid.meta
	var r0: float = float(meta["radius"])
	var levels: int = int(meta["levels"])
	var r_top: float = r0 - 1.5 * (levels - 1)
	var z_oc: float = (levels - 1) * RingGrammar.STOREY + (r_top - RingGrammar.OCULUS) / RingGrammar.LEAN
	var drop: Mesh = _drop_mesh()
	# From the oculus's vines into the pool.
	var oculus := _falling(drop, 26, z_oc - 3.0 - POOL_Z)
	oculus.name = "OculusDrops"
	oculus.position = Vector3(0.0, z_oc - 3.0, 0.0)
	var pm: ParticleProcessMaterial = oculus.process_material
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_axis = Vector3.UP
	pm.emission_ring_radius = POOL_R - 0.2
	pm.emission_ring_inner_radius = 0.3
	pm.emission_ring_height = 0.0
	add_child(oculus)
	await get_tree().process_frame
	if not is_inside_tree():
		return
	# From under the ledges: points along each storey's ledge edge.
	var pts: PackedVector3Array = []
	for j: int in levels - 1:
		var r: float = r0 - 1.5 * j
		var c: Vector2 = RingGrammar.climb(r)
		for i: int in 60:
			var t: float = c.x + (c.y - c.x) * (i + 0.5) / 60.0
			var z: float = RingGrammar.tread(r, t) - 0.3
			if j == 0 and z < 1.2:
				continue
			pts.append(RingGrammar._point(Vector3.ZERO, j, t, (RingGrammar.face(r, z) - RingGrammar.LEDGE + 0.1) * LEDGE_IN, z))
	if not pts.is_empty():
		var top: float = 0.0
		for p: Vector3 in pts:
			top = maxf(top, p.y)
		var ledges := _falling(drop, 40, top)
		ledges.name = "LedgeDrips"
		var lm: ParticleProcessMaterial = ledges.process_material
		var img := Image.create(pts.size(), 1, false, Image.FORMAT_RGBF)
		for i: int in pts.size():
			img.set_pixel(i, 0, Color(pts[i].x, pts[i].y, pts[i].z))
		lm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINTS
		lm.emission_point_texture = ImageTexture.create_from_image(img)
		lm.emission_point_count = pts.size()
		add_child(ledges)
		await get_tree().process_frame
		if not is_inside_tree():
			return
	add_child(_splashes())


func _room() -> GeneratedRoom:
	var n: Node = get_parent()
	while n != null and not n is GeneratedRoom:
		n = n.get_parent()
	return n as GeneratedRoom


## The three emitters' kinds, tiny, for PipelineWarm (their particle and draw
## shaders compile while the place settles).
static func warm() -> Array[GPUParticles3D]:
	var out: Array[GPUParticles3D] = []
	var drop: Mesh = _drop_mesh()
	var ring := _falling(drop, 2, 1.0)
	var rm: ParticleProcessMaterial = ring.process_material
	rm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	rm.emission_ring_axis = Vector3.UP
	out.append(ring)
	var points := _falling(drop, 2, 1.0)
	var pm: ParticleProcessMaterial = points.process_material
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINTS
	pm.emission_point_texture = ImageTexture.create_from_image(Image.create(1, 1, false, Image.FORMAT_RGBF))
	pm.emission_point_count = 1
	out.append(points)
	out.append(_splashes())
	return out


## Drops falling `height` metres from rest (their lifetime: the fall).
static func _falling(drop: Mesh, amount: int, height: float) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	var life: float = sqrt(2.0 * maxf(height, 0.5) / G)
	p.amount = amount
	p.lifetime = life
	# No preprocess: it simulated a whole fall on the frame each emitter
	# arrived (about 10 ms each at the frame gate); the room loads out of
	# sight, so the drops have started falling by the time you see them.
	p.randomness = 1.0
	p.explosiveness = 0.0
	p.draw_pass_1 = drop
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-14, -height - 1.0, -14), Vector3(28, height + 4.0, 28))
	var m := ParticleProcessMaterial.new()
	m.gravity = Vector3(0, -G, 0)
	m.direction = Vector3.DOWN
	m.spread = 0.0
	m.initial_velocity_min = 0.0
	m.initial_velocity_max = 0.3
	m.particle_flag_align_y = true
	p.process_material = m
	return p


static func _splashes() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "PoolSplashes"
	p.position = Vector3(0.0, POOL_Z + 0.01, 0.0)
	p.amount = 36
	p.lifetime = 0.35
	p.explosiveness = 0.0
	p.randomness = 1.0
	p.draw_pass_1 = _drop_mesh(0.035)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-2, -0.5, -2), Vector3(4, 1.5, 4))
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = POOL_R - 0.15
	m.emission_shape_scale = Vector3(1, 0.0, 1)
	m.direction = Vector3.UP
	m.spread = 25.0
	m.initial_velocity_min = 0.6
	m.initial_velocity_max = 1.2
	m.gravity = Vector3(0, -G, 0)
	m.particle_flag_align_y = true
	p.process_material = m
	return p


static var _material: StandardMaterial3D


static func _drop_mesh(length: float = DROP_LEN) -> Mesh:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_material.albedo_color = Color(0.82, 0.9, 1.0, 0.55)
		_material.roughness = 0.05
		_material.metallic_specular = 1.0
		_material.emission_enabled = true
		_material.emission = Color(0.6, 0.75, 0.85)
		_material.emission_energy_multiplier = 0.35
	var m := CylinderMesh.new()
	m.top_radius = 0.006
	m.bottom_radius = 0.009
	m.height = length
	m.radial_segments = 4
	m.rings = 1
	m.material = _material
	return m

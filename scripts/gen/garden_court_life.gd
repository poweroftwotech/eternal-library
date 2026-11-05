class_name GardenCourtLife
extends Node3D
## The R07 Garden Court's life (phase 13 step 2). GardenCourtGrammar puts this
## (slot garden:life) at the pool's centre; on _ready it reads the room's
## grid.meta and adds:
##   - the herbs and roots to pick in the beds (meta.forage; mushrooms in the
##     talar's shade when the garden has gone wild), as the Bridge Hall's:
##     NicheThings over the forage patches, grown back when the room is next
##     built;
##   - the fountain running: drops falling from the upper bowl's lip into the
##     lower bowl and from the lower into the pool (tended only: the wild
##     garden's fountain is dry);
##   - petals drifting down the sunlight (wild: dry leaves) and a few moths
##     over the beds.
## Particles only: no lights, no collision. One emitter a frame (as the
## light-well's drips); PipelineWarm draws warm() while a place settles.

const HERB: String = "res://kit/dressing/forage_herb.tscn"
const ROOT: String = "res://kit/dressing/forage_root.tscn"
const MUSHROOM: String = "res://kit/dressing/forage_mushroom.tscn"
## The fountain (tools/kit_add_r07.py garden_pool): the bowls' lips and the
## water under each.
const UPPER_R: float = 0.5
const UPPER_Z: float = 1.49
const JET_Z: float = 1.84         # the finial's tip
const LOWER_R: float = 0.98
const LOWER_Z: float = 0.93
const POOL_Z: float = 0.36
## The sunlit air the petals fall through (the court, 20 m square, round the pool).
const COURT_HALF: float = 9.0

static var _petal_mat: StandardMaterial3D
static var _leaf_mat: StandardMaterial3D
static var _moth_mat: StandardMaterial3D


func _ready() -> void:
	_build()


func _build() -> void:
	await get_tree().process_frame
	var room: GeneratedRoom = _room()
	if room == null or room.grid == null or not room.grid.meta.has("garden"):
		return
	var meta: Dictionary = room.grid.meta
	var wild: bool = bool(meta.get("wild", false))
	var i: int = 0
	for f: Dictionary in meta.get("forage", []):
		var xf := Transform3D(Basis(Vector3.UP, i * 2.3), (f["at"] as Vector3) - position)
		var kind: String = f["kind"]
		var visual: String = HERB if kind == "herb" else (ROOT if kind == "root" else MUSHROOM)
		BridgeHallLife.pickable(kind, visual, xf, self, "Forage_%d" % i)
		i += 1
	await get_tree().process_frame
	if not is_inside_tree():
		return
	add_child(_drift(false, wild))
	await get_tree().process_frame
	if not is_inside_tree():
		return
	add_child(_drift(true, wild))
	if wild:
		return
	for k: int in 2:
		await get_tree().process_frame
		if not is_inside_tree():
			return
		var r: float = UPPER_R if k == 0 else LOWER_R
		var top: float = UPPER_Z if k == 0 else LOWER_Z
		var bottom: float = LOWER_Z if k == 0 else POOL_Z
		var p: GPUParticles3D = ConeDrips._falling(ConeDrips._drop_mesh(0.16), 40 if k == 0 else 70, top - bottom)
		p.name = "FountainDrops_%d" % k
		p.position = Vector3(0.0, top, 0.0)
		var pm: ParticleProcessMaterial = p.process_material
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
		pm.emission_ring_axis = Vector3.UP
		pm.emission_ring_radius = r + 0.02
		pm.emission_ring_inner_radius = r - 0.02
		pm.emission_ring_height = 0.0
		pm.direction = Vector3.DOWN
		pm.initial_velocity_max = 0.15
		p.visibility_aabb = AABB(Vector3(-1.5, -(top - bottom) - 0.5, -1.5), Vector3(3.0, top - bottom + 1.0, 3.0))
		add_child(p)
	add_child(_jet())


## Your walk 5 (the water at the top was flat faces): the jet, a spray of
## drops thrown up off the finial that falls back into the top bowl.
static func _jet() -> GPUParticles3D:
	var p: GPUParticles3D = ConeDrips._falling(ConeDrips._drop_mesh(0.12), 60, JET_Z - UPPER_Z)
	p.name = "FountainJet"
	p.position = Vector3(0.0, JET_Z, 0.0)
	p.lifetime = 0.62
	var pm: ParticleProcessMaterial = p.process_material
	pm.direction = Vector3.UP
	pm.spread = 14.0
	pm.initial_velocity_min = 2.0
	pm.initial_velocity_max = 2.5
	p.visibility_aabb = AABB(Vector3(-1.0, -0.6, -1.0), Vector3(2.0, 1.2, 2.0))
	return p


func _room() -> GeneratedRoom:
	var n: Node = get_parent()
	while n != null:
		if n is GeneratedRoom:
			return n as GeneratedRoom
		n = n.get_parent()
	return null


## Petals (wild: dry leaves) drifting down through the sunlit air over the
## court, or (`moths`) a few pale moths wandering low over the beds.
static func _drift(moths: bool, wild: bool, amount: int = -1) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "Moths" if moths else ("Leaves" if wild else "Petals")
	var quad := QuadMesh.new()
	quad.size = Vector2(0.07, 0.05) if moths else Vector2(0.08, 0.06)
	quad.material = _material(moths, wild)
	p.draw_pass_1 = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.randomness = 1.0
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.turbulence_enabled = true
	m.angular_velocity_min = -120.0
	m.angular_velocity_max = 120.0
	m.angle_min = 0.0
	m.angle_max = 360.0
	if moths:
		p.amount = amount if amount > 0 else 12
		p.lifetime = 7.0
		p.position = Vector3(0.0, 1.4, 0.0)
		m.emission_box_extents = Vector3(COURT_HALF - 1.0, 0.8, COURT_HALF - 1.0)
		m.gravity = Vector3.ZERO
		m.initial_velocity_min = 0.2
		m.initial_velocity_max = 0.5
		m.spread = 180.0
		m.turbulence_noise_strength = 2.5
		m.turbulence_noise_scale = 1.5
		m.turbulence_noise_speed_random = 1.0
		m.turbulence_influence_min = 0.3
		m.turbulence_influence_max = 0.6
		p.visibility_aabb = AABB(Vector3(-COURT_HALF - 2.0, -2.0, -COURT_HALF - 2.0), Vector3(2.0 * COURT_HALF + 4.0, 5.0, 2.0 * COURT_HALF + 4.0))
	else:
		p.amount = amount if amount > 0 else (60 if wild else 120)
		p.lifetime = 22.0
		p.preprocess = 0.0
		p.position = Vector3(0.0, 12.0, 0.0)
		m.emission_box_extents = Vector3(COURT_HALF - 2.0, 2.0, COURT_HALF - 2.0)
		m.gravity = Vector3(0.0, -0.18, 0.0)
		m.direction = Vector3(0.3, -1.0, 0.1)
		m.initial_velocity_min = 0.1
		m.initial_velocity_max = 0.35
		m.turbulence_noise_strength = 1.2
		m.turbulence_noise_scale = 4.0
		m.turbulence_influence_min = 0.08
		m.turbulence_influence_max = 0.2
		m.collision_mode = ParticleProcessMaterial.COLLISION_DISABLED
		p.visibility_aabb = AABB(Vector3(-COURT_HALF - 3.0, -13.0, -COURT_HALF - 3.0), Vector3(2.0 * COURT_HALF + 6.0, 17.0, 2.0 * COURT_HALF + 6.0))
	p.process_material = m
	return p


static func _material(moths: bool, wild: bool) -> StandardMaterial3D:
	var cached: StandardMaterial3D = _moth_mat if moths else (_leaf_mat if wild else _petal_mat)
	if cached != null:
		return cached
	var mat := StandardMaterial3D.new()
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.roughness = 0.9
	if moths:
		mat.albedo_color = Color(0.93, 0.9, 0.82)
	elif wild:
		mat.albedo_color = Color(0.55, 0.38, 0.2)
	else:
		mat.albedo_color = Color(1.0, 0.78, 0.84)      # blossom pink (the brief's tint)
	if moths:
		_moth_mat = mat
	elif wild:
		_leaf_mat = mat
	else:
		_petal_mat = mat
	return mat


## The emitters' kinds, tiny, for PipelineWarm (their particle and draw
## shaders compile while the place settles).
static func warm() -> Array[GPUParticles3D]:
	var out: Array[GPUParticles3D] = [_drift(false, false, 2), _drift(true, false, 2), _drift(false, true, 2)]
	return out

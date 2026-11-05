class_name FungusTerracesLife
extends Node3D
## The R15 Fungus Terraces' life (phase 13 step 4). FungusTerracesGrammar puts
## this (slot ft:life) at the room's origin; on _ready it reads grid.meta and
## adds:
##   - the mushrooms to pick (meta.forage: on the tended crop by the stair and
##     in the wild patches), as the Bridge Hall's: NicheThings, grown back when
##     the room is next built;
##   - spores: violet motes drifting up off the beds through the glow, over the
##     whole slope;
##   - the cascade's drops falling off each terrace's step into the channel
##     below (and the first into the well at the foot).
## Particles only: no lights, no collision. One emitter a frame (as the
## light-well's drips); PipelineWarm draws warm() while a place settles.

const MUSHROOM: String = "res://kit/dressing/forage_mushroom.tscn"
## The cascade's channel across a row piece (tools/kit_add_r15.py CH0..CH1,
## inside its walls) and the room's width.
const CH_MID: float = 7.3
const CH_HALF: float = 0.5
const WIDTH: float = 20.0

static var _spore_mat: StandardMaterial3D


func _ready() -> void:
	_build()


func _build() -> void:
	await get_tree().process_frame
	var room: GeneratedRoom = _room()
	if room == null or room.grid == null or not room.grid.meta.has("terraces"):
		return
	var meta: Dictionary = room.grid.meta
	var rows: int = int(meta["rows"])
	var i: int = 0
	for f: Dictionary in meta.get("forage", []):
		var xf := Transform3D(Basis(Vector3.UP, i * 2.3), (f["at"] as Vector3) - position)
		BridgeHallLife.pickable("mushroom", MUSHROOM, xf, self, "Forage_%d" % i)
		i += 1
	# Spores: one emitter, a box tilted up the slope over all the terraces.
	await get_tree().process_frame
	if not is_inside_tree():
		return
	var a: Vector3 = FungusTerracesGrammar.row_xf(1).origin
	var b: Vector3 = FungusTerracesGrammar.row_xf(rows - 1).origin + Vector3(0.0, 0.0, -FungusTerracesGrammar.BAY)
	add_child(_spores(a, b))
	# The falls: drops off each terrace's step, a few each.
	for z: int in range(1, rows):
		await get_tree().process_frame
		if not is_inside_tree():
			return
		var p: GPUParticles3D = ConeDrips._falling(ConeDrips._drop_mesh(0.2), 24, FungusTerracesGrammar.RISE)
		p.name = "FallDrops_%d" % z
		p.position = FungusTerracesGrammar.row_xf(z) * Vector3(CH_MID, -0.3, 0.14)   # walk 5: under the lip (drops stuck out over the top)
		var pm: ParticleProcessMaterial = p.process_material
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		pm.emission_box_extents = Vector3(CH_HALF, 0.02, 0.03)
		pm.direction = Vector3(0.0, -1.0, 0.35)
		pm.initial_velocity_max = 0.6
		p.visibility_aabb = AABB(Vector3(-1.0, -FungusTerracesGrammar.RISE - 0.8, -0.5), Vector3(2.0, FungusTerracesGrammar.RISE + 1.2, 1.5))
		add_child(p)
	# Walk 3 ("missing a texture or water?"): splashes where the first fall
	# hits the foot well's water, so it reads as water from above.
	var s: GPUParticles3D = ConeDrips._splashes()
	s.name = "WellSplashes"
	s.amount = 48
	s.position = FungusTerracesGrammar.row_xf(0) * Vector3(CH_MID, -0.44, -3.6)
	var sm: ParticleProcessMaterial = s.process_material
	sm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	sm.emission_box_extents = Vector3(CH_HALF + 0.1, 0.0, 0.2)
	sm.direction = Vector3(0.0, 1.0, 0.6)
	add_child(s)
	# Walk 4 ("why an awning underground?"): the roof drips over the shelter.
	# Drops fall from the rock onto the cloth, run off its low front edge, and
	# splash on the floor in front (the shelter: tools/kit_add_r15.py shelter(),
	# X 0..6 along the wall, the cloth from 2.6 m at the back to 1.95 m 2.55 m out).
	var sh: Transform3D = FungusTerracesGrammar.row_xf(0) * Transform3D(Basis(), Vector3(13.4, 0.0, -0.4))
	var roof: GPUParticles3D = ConeDrips._falling(ConeDrips._drop_mesh(0.18), 2, 3.8)
	roof.name = "ShelterRoofDrips"
	roof.position = sh * Vector3(3.0, 6.2, -1.4)
	var rm: ParticleProcessMaterial = roof.process_material
	rm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	rm.emission_box_extents = Vector3(2.6, 0.02, 0.9)
	add_child(roof)
	var edge: GPUParticles3D = ConeDrips._falling(ConeDrips._drop_mesh(0.1), 2, 1.95)
	edge.name = "ShelterEdgeDrips"
	edge.position = sh * Vector3(3.0, 1.93, -2.58)
	var em: ParticleProcessMaterial = edge.process_material
	em.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	em.emission_box_extents = Vector3(2.8, 0.01, 0.02)
	add_child(edge)
	var puddle: GPUParticles3D = ConeDrips._splashes()
	puddle.name = "ShelterSplashes"
	puddle.amount = 2
	puddle.position = sh * Vector3(3.0, 0.01, -2.6)
	var pm2: ParticleProcessMaterial = puddle.process_material
	pm2.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm2.emission_box_extents = Vector3(2.8, 0.0, 0.08)
	pm2.initial_velocity_max = 0.8
	add_child(puddle)
	# Walk 5 ("way too much water drip… a few drops once every few secs"):
	# one drop every second or two from the roof, fewer off the edge.
	_sparse(roof, 3.8, 3.0)
	_sparse(edge, 1.95, 5.0)
	_sparse_splash(puddle, 5.0)


## Violet spores drifting slowly up off the beds over the slope from the first
## terrace's front (`a`, its south-west corner) to the top one's back (`b`).
static func _spores(a: Vector3, b: Vector3, amount: int = 260) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "Spores"
	var quad := QuadMesh.new()
	quad.size = Vector2(0.035, 0.035)
	quad.material = _material()
	p.draw_pass_1 = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.amount = amount
	p.lifetime = 9.0
	p.randomness = 1.0
	var run: Vector3 = b - a
	var slope: float = atan2(run.y, -run.z)
	var length: float = Vector2(run.y, run.z).length()
	# The box's middle half a metre over the beds, tilted up the slope.
	p.position = Vector3(a.x + WIDTH * 0.5, (a.y + b.y) * 0.5 + 0.9, (a.z + b.z) * 0.5)
	p.rotation = Vector3(slope, 0.0, 0.0)
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = Vector3(WIDTH * 0.5 - 0.5, 0.5, length * 0.5)
	m.gravity = Vector3(0.0, 0.04, 0.0)
	m.direction = Vector3.UP
	m.spread = 60.0
	m.initial_velocity_min = 0.03
	m.initial_velocity_max = 0.12
	m.turbulence_enabled = true
	m.turbulence_noise_strength = 0.6
	m.turbulence_noise_scale = 3.0
	m.turbulence_influence_min = 0.05
	m.turbulence_influence_max = 0.15
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
	p.visibility_aabb = AABB(Vector3(-WIDTH * 0.5 - 1.0, -3.0, -length * 0.5 - 2.0), Vector3(WIDTH + 2.0, 8.0, length + 4.0))
	return p


static func _material() -> StandardMaterial3D:
	if _spore_mat == null:
		_spore_mat = StandardMaterial3D.new()
		_spore_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_spore_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_spore_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_spore_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		_spore_mat.vertex_color_use_as_albedo = true
		_spore_mat.albedo_color = Color(0.75, 0.5, 1.0)
		_spore_mat.disable_receive_shadows = true
	return _spore_mat


func _room() -> GeneratedRoom:
	var n: Node = get_parent()
	while n != null:
		if n is GeneratedRoom:
			return n as GeneratedRoom
		n = n.get_parent()
	return null


## The emitters' kinds, tiny, for PipelineWarm (their particle and draw
## shaders compile while the place settles).
static func warm() -> Array[GPUParticles3D]:
	return [_spores(Vector3.ZERO, Vector3(0.0, 1.0, -4.0), 2)]


## Falling drops `p` (from `height`) made sparse: each lives `every` seconds
## but shows only while it falls, so its `amount` drops come that far apart.
static func _sparse(p: GPUParticles3D, height: float, every: float) -> void:
	var fall: float = sqrt(2.0 * height / ConeDrips.G)
	p.lifetime = every
	(p.process_material as ParticleProcessMaterial).scale_curve = _shown_for(fall / every)


## Splashes `p` made as sparse as the drops that cause them.
static func _sparse_splash(p: GPUParticles3D, every: float) -> void:
	var show: float = p.lifetime
	p.lifetime = every
	(p.process_material as ParticleProcessMaterial).scale_curve = _shown_for(show / every)


## A scale curve: 1 for the first `part` of a particle's life, then 0.
static func _shown_for(part: float) -> CurveTexture:
	var c := Curve.new()
	c.add_point(Vector2(0.0, 1.0))
	c.add_point(Vector2(clampf(part, 0.01, 0.98), 1.0))
	c.add_point(Vector2(clampf(part, 0.01, 0.98) + 0.01, 0.0))
	c.add_point(Vector2(1.0, 0.0))
	var t := CurveTexture.new()
	t.curve = c
	return t

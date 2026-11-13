class_name BatRoost
extends MultiMeshInstance3D
## One colony of bats hanging from a dark roof (phase 19 step 2), one
## MultiMesh. They hang head down and shift; a few circle under the roost.
## Come close and the colony takes flight: it swirls round the roost, then
## streams off along the vault, away from you, into the dark. Once you have
## gone away for a while, they are back (unseen). Their flight is in
## creature_bat.gdshader; this only keeps the colony's clock.

## Seconds from take-off until the last of them has faded out (the shader's
## SWIRL + GONE, and the longest take-off delay).
const AWAY_S: float = 6.5
## Back once you are this far (m) for this long (s).
const RETURN_DISTANCE: float = 18.0
const RETURN_S: float = 15.0

var def: CreatureDef
var bounds: AABB
var focus: Vector3
var centre: Vector3
## Open ways along the vault from under the roost: [{dir, reach}].
var ways: Array = []
var clock: float = -1.0
var _gone_since: int = 0


## `spots`: where each bat hangs (global, its feet on the roof).
func setup(d: CreatureDef, at: Vector3, spots: Array[Vector3], open_ways: Array, rng: RandomNumberGenerator) -> void:
	def = d
	centre = at
	ways = open_ways
	name = "%s_%d" % [d.id, rng.randi() & 0xffff]
	top_level = true
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	position = at
	focus = at - Vector3(0, 0.3, 0)
	bounds = AABB(at, Vector3.ZERO).grow(3.0)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = AirBody.bat_mesh()
	mm.instance_count = spots.size()
	for i: int in spots.size():
		var size: float = d.length_m * rng.randf_range(d.length_spread.x, d.length_spread.y)
		var hang: Vector3 = spots[i] - Vector3(0, 0.55 * size, 0)
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * size), hang - position))
		mm.set_instance_custom_data(i, Color(rng.randf(), 0.0, 0.0, rng.randf_range(0.0, 1.4)))
	multimesh = mm
	material_override = AirBody.material(d)
	# Room for the swirl and the stream (the shader moves them up to ~20 m).
	custom_aabb = AABB(Vector3(-22, -6, -22), Vector3(44, 8, 44))
	set_instance_shader_parameter("centre", at - Vector3(0, 0.4, 0))
	set_instance_shader_parameter("clock", clock)


func tick(delta: float, player: Vector3, _moving: float) -> void:
	var eye: Vector3 = player + Vector3(0, 1.6, 0)
	var dist: float = eye.distance_to(centre)
	if clock < 0.0:
		if dist < def.startle_radius:
			clock = 0.0
			set_instance_shader_parameter("exit_dir", _way_out(player))
		else:
			return
	elif clock < AWAY_S:
		clock += delta
		if clock >= AWAY_S:
			_gone_since = Time.get_ticks_msec()
	else:
		if dist < RETURN_DISTANCE:
			_gone_since = Time.get_ticks_msec()
		elif Time.get_ticks_msec() - _gone_since > int(RETURN_S * 1000.0):
			clock = -1.0
	set_instance_shader_parameter("clock", clock)


## The open way along the vault that leads most directly away from you.
func _way_out(player: Vector3) -> Vector3:
	var away := Vector3(centre.x - player.x, 0, centre.z - player.z)
	away = away.normalized() if away.length() > 0.01 else Vector3.RIGHT
	var best: Vector3 = away
	var best_score: float = -INF
	for w: Dictionary in ways:
		var dir: Vector3 = w["dir"]
		var score: float = dir.dot(away) * 2.0 + minf(float(w["reach"]), 20.0) / 10.0
		if score > best_score:
			best_score = score
			best = dir
	return best

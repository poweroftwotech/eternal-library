class_name FishSchool
extends MultiMeshInstance3D
## A school of small fish moving as one (phase 19 step 1, the "swarm" tier:
## the blind cave barb). Its fish keep their places in a loose shoal round
## this node; the shader lets each wander a little and part round you. Fauna
## ticks it: only the school's own position and heading are worked out here.
##
## The school drifts slowly from place to place in its water. Blind barbs feel
## your steps when you wade (def.feels_water_only): the shoal parts round your
## legs, and if you keep coming the school moves off.

## How far the shoal spreads for its size (m, per square root of fish).
const SPREAD: float = 0.16
## How far the school looks for its next place (m).
const REACH: float = 6.0
const PART_RADIUS: float = 1.4

var def: CreatureDef
var body: WaterBody
var target: Vector3
var _vel: Vector3 = Vector3.ZERO
var _hang: float = 0.0
var _flee: float = 0.0
var _rng := RandomNumberGenerator.new()
var _space: PhysicsDirectSpaceState3D
var _places: PackedVector3Array
var _radius: float = 0.5


func setup(d: CreatureDef, b: WaterBody, count: int, seed_value: int, start: Vector3) -> void:
	def = d
	body = b
	_rng.seed = seed_value
	_places = b.deep_samples(d.min_depth)
	if _places.is_empty():
		_places = b.samples
	name = "%s_school_%d" % [d.id, seed_value & 0xffff]
	top_level = true
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visibility_range_end = Fauna.SLEEP_DISTANCE + 5.0
	_radius = SPREAD * sqrt(count)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = FishBody.mesh(d)
	mm.instance_count = count
	multimesh = mm
	material_override = FishBody.material(d)
	for i: int in count:
		# Their places in the shoal: a flat disc, denser in the middle, all
		# heading the school's way give or take.
		var r: float = _radius * sqrt(_rng.randf())
		var a: float = _rng.randf() * TAU
		var at := Vector3(cos(a) * r, _rng.randf_range(-0.08, 0.08), sin(a) * r * 1.4)
		var size: float = d.length_m * _rng.randf_range(d.length_spread.x, d.length_spread.y)
		var yaw: float = _rng.randf_range(-0.35, 0.35)
		mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(size, size, size)), at))
		mm.set_instance_custom_data(i, Color(_rng.randf(), _rng.randf_range(1.8, 2.6), float(_rng.randi() % d.patterns), 0.0))
	position = _swim_point(start)
	target = position
	_hang = _rng.randf_range(0.0, 4.0)


func tick(delta: float, player: Vector3, moving: float) -> void:
	if _space == null:
		_space = get_world_3d().direct_space_state
	var wading_here: bool = player.y < body.surface + 0.1 and body.contains_xz(Vector2(player.x, player.z))
	var feels: bool = wading_here or not def.feels_water_only
	var dist: float = Vector2(position.x - player.x, position.z - player.z).length()
	if feels and dist < _radius + PART_RADIUS * 2.5:
		set_instance_shader_parameter("avoid_at", player)
		set_instance_shader_parameter("avoid_radius", PART_RADIUS)
		if moving > 0.3 and dist < _radius + def.startle_radius and _flee <= 0.0:
			_flee = 3.0
			_hang = 0.0
			target = _away_from(Vector2(player.x, player.z))
	else:
		set_instance_shader_parameter("avoid_radius", 0.0)
	_flee = maxf(0.0, _flee - delta)
	var want := Vector3.ZERO
	if _hang > 0.0:
		_hang -= delta
	else:
		var d: Vector3 = target - position
		if d.length() < 0.25:
			_hang = _rng.randf_range(1.5, 6.0)
			target = _next_place()
		else:
			want = d.normalized() * (def.speed.y if _flee > 0.0 else def.speed.x)
	_vel = _vel.lerp(want, 1.0 - exp(-1.2 * delta))
	position += _vel * delta
	if Vector2(_vel.x, _vel.z).length() > 0.02:
		rotation.y = lerp_angle(rotation.y, atan2(-_vel.x, -_vel.z), 1.0 - exp(-1.5 * delta))


func _next_place() -> Vector3:
	for _try: int in 6:
		var p: Vector3 = _places[_rng.randi() % _places.size()]
		if Vector2(p.x - position.x, p.z - position.z).length() > REACH:
			continue
		var at: Vector3 = _swim_point(p)
		if HabitatScan.clear_path(_space, position, at):
			return at
	return position


func _away_from(threat: Vector2) -> Vector3:
	var best: Vector3 = position
	var best_d: float = -1.0
	for _try: int in 8:
		var p: Vector3 = _places[_rng.randi() % _places.size()]
		var d: float = Vector2(p.x, p.z).distance_to(threat)
		if d > best_d and Vector2(p.x - position.x, p.z - position.z).length() < REACH:
			var at: Vector3 = _swim_point(p)
			if HabitatScan.clear_path(_space, position, at):
				best = at
				best_d = d
	return best


func _swim_point(p: Vector3) -> Vector3:
	var room: float = body.surface - p.y - 0.06
	var depth: float = clampf(_rng.randf_range(def.swim_depth.x, def.swim_depth.y), def.swim_depth.x, maxf(def.swim_depth.x, room))
	return Vector3(p.x, body.surface - depth, p.z)

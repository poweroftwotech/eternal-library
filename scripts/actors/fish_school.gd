class_name FishSchool
extends MultiMeshInstance3D
## A school of small fish (phase 19 step 1: the blind cave barb), one
## MultiMesh. The school as a whole drifts from place to place in its water;
## each fish swims by itself to keep its place in the shoal: it always moves
## the way it faces, turns at its own rate, speeds up when it has fallen
## behind and idles in a small circle when it is where it wants to be. So a
## change of way ripples through the school fish by fish, and none slides
## sideways or backwards. (Until 2026-11-13 the shoal was one stiff thing
## moved and turned as a whole.) Ticked by Fauna.
##
## Blind barbs feel your steps when you wade (def.feels_water_only): the fish
## near your legs turn away, and if you keep coming the school moves off.

## How far the shoal spreads for its size (m, per square root of fish).
const SPREAD: float = 0.16
## How far the school looks for its next place (m).
const REACH: float = 6.0
const PART_RADIUS: float = 1.4
## A fish turns this fast (rad/s; twice as fast fleeing), never goes slower
## than IDLE (m/s), and makes up ground at up to CATCH_UP times the school's
## speed.
const TURN_RATE: float = 2.6
const IDLE: float = 0.05
const CATCH_UP: float = 1.7

var def: CreatureDef
var body: WaterBody
var target: Vector3
## Each fish: {slot (its place in the shoal, from the school's middle), pos
## (global), yaw, speed, size, phase}.
var fish: Array[Dictionary] = []
var _vel: Vector3 = Vector3.ZERO
var _hang: float = 0.0
var _flee: float = 0.0
var _rng := RandomNumberGenerator.new()
var _space: PhysicsDirectSpaceState3D
var _places: PackedVector3Array
var _radius: float = 0.5
var _clock: float = 0.0


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
	set_instance_shader_parameter("surface_y", b.surface)
	set_instance_shader_parameter("water_tint", FishBody.water_tint(b))
	position = _swim_point(start)
	target = position
	_hang = _rng.randf_range(0.0, 4.0)
	# Room for the fish that stray from the school's middle.
	custom_aabb = AABB(Vector3(-_radius - 2.0, -1.0, -_radius - 2.0), Vector3(_radius * 2.0 + 4.0, 2.0, _radius * 2.0 + 4.0))
	for i: int in count:
		# Their places in the shoal: a flat disc, denser in the middle.
		var r: float = _radius * sqrt(_rng.randf())
		var a: float = _rng.randf() * TAU
		var slot := Vector3(cos(a) * r, _rng.randf_range(-0.08, 0.08), sin(a) * r * 1.4)
		var f: Dictionary = {"slot": slot, "pos": position + slot, "yaw": _rng.randf() * TAU, "speed": IDLE,
			"size": d.length_m * _rng.randf_range(d.length_spread.x, d.length_spread.y), "phase": _rng.randf() * TAU}
		fish.append(f)
		mm.set_instance_custom_data(i, Color(_rng.randf(), _rng.randf_range(1.8, 2.6), float(_rng.randi() % d.patterns), 0.0))
		_draw(i)


func tick(delta: float, player: Vector3, moving: float) -> void:
	if _space == null:
		_space = get_world_3d().direct_space_state
	_clock += delta
	var wading_here: bool = player.y < body.surface + 0.1 and body.contains_xz(Vector2(player.x, player.z))
	var feels: bool = wading_here or not def.feels_water_only
	var dist: float = Vector2(position.x - player.x, position.z - player.z).length()
	if feels and moving > 0.3 and dist < _radius + def.startle_radius and _flee <= 0.0:
		_flee = 3.0
		_hang = 0.0
		target = _away_from(Vector2(player.x, player.z))
		SoundSystem.cue("fish_splash", Vector3(position.x, body.surface, position.z), 14.0, -7.0, 0.6)     # the school turning (phase 20 Q2)
	_flee = maxf(0.0, _flee - delta)
	# The school's middle: toward its next place, then a rest.
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
	# Each fish, to its own place in it.
	var cruise: float = def.speed.y if _flee > 0.0 else def.speed.x
	var turn: float = TURN_RATE * (2.0 if _flee > 0.0 else 1.0) * delta
	for i: int in fish.size():
		var f: Dictionary = fish[i]
		var phase: float = f["phase"]
		var pos: Vector3 = f["pos"]
		# Its place wanders a little, so the shoal is never a fixed pattern.
		var goal: Vector3 = position + (f["slot"] as Vector3) + Vector3(sin(_clock * 0.37 + phase), 0.0, cos(_clock * 0.31 + phase * 1.7)) * 0.09
		var to := Vector2(goal.x - pos.x, goal.z - pos.z)
		var away: float = to.length()
		if feels:
			# Round your legs.
			var from_you := Vector2(pos.x - player.x, pos.z - player.z)
			if from_you.length() < PART_RADIUS:
				to = from_you.normalized() * PART_RADIUS
				away = PART_RADIUS
		var yaw: float = f["yaw"]
		if away > 0.04:
			yaw = rotate_toward(yaw, atan2(-to.x, -to.y), turn)
		else:
			yaw += 0.6 * delta     # where it wants to be: a slow idle circle
		# Faster the further behind it is; never still, never backwards.
		var speed: float = clampf(away * 1.6, IDLE, maxf(cruise * CATCH_UP, IDLE))
		speed = lerpf(float(f["speed"]), speed, minf(1.0, 3.0 * delta))
		pos += Vector3(-sin(yaw), 0.0, -cos(yaw)) * speed * delta
		pos.y = lerpf(pos.y, goal.y, minf(1.0, 1.5 * delta))
		f["yaw"] = yaw
		f["speed"] = speed
		f["pos"] = pos
		_draw(i)


func _draw(i: int) -> void:
	var f: Dictionary = fish[i]
	var size: float = f["size"]
	multimesh.set_instance_transform(i, Transform3D(Basis(Vector3.UP, float(f["yaw"])).scaled(Vector3(size, size, size)), (f["pos"] as Vector3) - position))


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

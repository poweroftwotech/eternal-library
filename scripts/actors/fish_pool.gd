class_name FishPool
extends MultiMeshInstance3D
## A few fish living in one body of water, each with a mind of its own
## (phase 19 step 1, the "simple" tier: the goldfish). Drawn as one MultiMesh;
## Fauna ticks it.
##
## Each fish cruises from place to place in the water (WaterBody.samples,
## only along straight lines clear of piers and walls), now and then hangs
## still for a moment (facing upstream in running water), and scatters away
## when you come close moving: it doesn't startle while you stand still, so
## they drift back.

## Seconds a fish may hang still, and how often it does (chance per arrival).
const HANG: Vector2 = Vector2(0.8, 3.5)
const HANG_CHANCE: float = 0.45
## How far a fish looks for its next place (m).
const REACH: float = 3.5
## How long a startled fish keeps fleeing (s).
const FLEE_S: float = 1.6

var def: CreatureDef
var body: WaterBody
## The water's flow (m/s, x/z), from its material: fish hang facing into it.
var flow: Vector2 = Vector2.ZERO
var fish: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
var _space: PhysicsDirectSpaceState3D
var _places: PackedVector3Array


func setup(d: CreatureDef, b: WaterBody, count: int, seed_value: int, survivor: bool = false) -> void:
	def = d
	body = b
	_rng.seed = seed_value
	_places = b.deep_samples(d.min_depth)
	if _places.is_empty():
		_places = b.samples
	name = "%s_%d" % [d.id, seed_value & 0xffff]
	top_level = true
	# At the water, not the origin: visibility_range_end is measured from here.
	position = Vector3(b.bounds.get_center().x, b.surface, b.bounds.get_center().z)
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visibility_range_end = Fauna.SLEEP_DISTANCE + 5.0
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = FishBody.mesh(d)
	mm.instance_count = count
	multimesh = mm
	material_override = FishBody.material(d)
	set_instance_shader_parameter("surface_y", b.surface)
	set_instance_shader_parameter("water_tint", FishBody.water_tint(b))
	for i: int in count:
		var at: Vector3 = _swim_point(_places[_rng.randi() % _places.size()])
		var size: float = d.length_m * _rng.randf_range(d.length_spread.x, d.length_spread.y)
		var pattern: int = _rng.randi() % d.patterns
		if survivor:
			size = d.length_m * d.survivor_scale
			pattern = d.patterns - 1
		var f: Dictionary = {"pos": at, "vel": Vector3.ZERO, "target": at, "size": size, "hang": _rng.randf_range(0.0, HANG.y),
			"flee": 0.0, "yaw": _rng.randf() * TAU, "beat": _rng.randf_range(1.6, 2.4), "phase": _rng.randf(), "pattern": float(pattern)}
		fish.append(f)
		mm.set_instance_custom_data(i, Color(f["phase"], f["beat"] * 0.5, f["pattern"], 0.0))
	_draw_all()


var _splash_at: int = 0


## One step. `player` is the player's feet; `moving` its speed (m/s).
func tick(delta: float, player: Vector3, moving: float) -> void:
	if _space == null:
		_space = get_world_3d().direct_space_state
	var near_player: bool = player.y < body.surface + 2.2 and (not def.feels_water_only or (player.y < body.surface + 0.1 and body.contains_xz(Vector2(player.x, player.z))))
	for i: int in fish.size():
		var f: Dictionary = fish[i]
		var pos: Vector3 = f["pos"]
		var to_player := Vector2(pos.x - player.x, pos.z - player.z)
		if near_player and moving > 0.4 and to_player.length() < def.startle_radius and float(f["flee"]) <= 0.0:
			f["flee"] = FLEE_S
			f["hang"] = 0.0
			f["target"] = _away_from(pos, Vector2(player.x, player.z))
			# Phase 20 (Q2): a splash as they turn, one for the pool at a time.
			if Time.get_ticks_msec() > _splash_at:
				_splash_at = Time.get_ticks_msec() + 1600
				SoundSystem.cue("fish_splash", Vector3(pos.x, body.surface, pos.z), 16.0, -3.0)
		f["flee"] = maxf(0.0, float(f["flee"]) - delta)
		var speed: float = def.speed.y if float(f["flee"]) > 0.0 else def.speed.x
		var want := Vector3.ZERO
		if float(f["hang"]) > 0.0:
			f["hang"] = float(f["hang"]) - delta
		else:
			var d: Vector3 = (f["target"] as Vector3) - pos
			if d.length() < 0.12:
				if _rng.randf() < HANG_CHANCE:
					f["hang"] = _rng.randf_range(HANG.x, HANG.y)
				f["target"] = _next_place(pos)
			else:
				want = d.normalized() * speed
		var vel: Vector3 = (f["vel"] as Vector3).lerp(want, 1.0 - exp(-3.0 * delta))
		pos += vel * delta
		f["pos"] = pos
		f["vel"] = vel
		# Face where it swims; hanging, ease into the current (or keep its heading).
		var yaw: float = f["yaw"]
		if Vector2(vel.x, vel.z).length() > 0.03:
			yaw = lerp_angle(yaw, atan2(-vel.x, -vel.z), 1.0 - exp(-6.0 * delta))
		elif flow.length() > 0.02:
			yaw = lerp_angle(yaw, atan2(flow.x, flow.y), 1.0 - exp(-1.5 * delta))
		f["yaw"] = yaw
		# Beats faster when it hurries.
		var beat: float = float(f["beat"]) * (0.6 + vel.length() / maxf(def.speed.x, 0.01) * 0.5)
		multimesh.set_instance_custom_data(i, Color(f["phase"], beat, f["pattern"], 0.0))
	_draw_all()


func _draw_all() -> void:
	for i: int in fish.size():
		var f: Dictionary = fish[i]
		var s: float = f["size"]
		multimesh.set_instance_transform(i, Transform3D(Basis(Vector3.UP, f["yaw"]).scaled(Vector3(s, s, s)), (f["pos"] as Vector3) - position))


## A place within REACH it can swim to in a straight line.
func _next_place(from: Vector3) -> Vector3:
	for _try: int in 6:
		var p: Vector3 = _places[_rng.randi() % _places.size()]
		if Vector2(p.x - from.x, p.z - from.z).length() > REACH:
			continue
		var at: Vector3 = _swim_point(p)
		if HabitatScan.clear_path(_space, from, at):
			return at
	return from + Vector3(_rng.randf_range(-0.2, 0.2), 0, _rng.randf_range(-0.2, 0.2)) if body.contains_xz(Vector2(from.x, from.z)) else from


## The clearest place away from `threat` (x/z).
func _away_from(from: Vector3, threat: Vector2) -> Vector3:
	var best: Vector3 = from
	var best_d: float = -1.0
	for _try: int in 8:
		var p: Vector3 = _places[_rng.randi() % _places.size()]
		var d: float = Vector2(p.x, p.z).distance_to(threat)
		if d > best_d and Vector2(p.x - from.x, p.z - from.z).length() < REACH * 1.4:
			var at: Vector3 = _swim_point(p)
			if HabitatScan.clear_path(_space, from, at):
				best = at
				best_d = d
	return best


## A height to swim at over place `p` (x, floor, z).
func _swim_point(p: Vector3) -> Vector3:
	var room: float = body.surface - p.y - 0.04
	var depth: float = clampf(_rng.randf_range(def.swim_depth.x, def.swim_depth.y), def.swim_depth.x, maxf(def.swim_depth.x, room))
	return Vector3(p.x + _rng.randf_range(-0.15, 0.15), body.surface - depth, p.z + _rng.randf_range(-0.15, 0.15))

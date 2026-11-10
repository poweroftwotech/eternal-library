class_name RatPack
extends MultiMeshInstance3D
## The rats of one forgotten room (phase 19 step 4), one MultiMesh. Each rat
## keeps to one run: a stretch along the foot of a wall with a hole at each
## end. It comes out of a hole, scurries along the wall, stops to sniff, goes
## on, and goes in at the other hole; after a while it comes out again. Come
## within its startle distance and it bolts for the nearer hole and stays in
## until you have gone. Ticked by Fauna; its scurry is in
## creature_crawler.gdshader.

enum { IN, RUN, SNIFF, BOLT }
## A run is at least this long (m), at most REACH each way from where its
## wall was found; a rat keeps OFF from the wall (m).
const MIN_RUN: float = 3.0
const REACH: float = 6.0
const OFF: float = 0.14
const RUNS_APART: float = 5.0
## The hole's width (m).
const HOLE: float = 0.22
## Out again once you are this far (m).
const SAFE: float = 7.0

var def: CreatureDef
var bounds: AABB
var focus: Vector3
## [{a, b, normal}]: the two holes (global, on the floor), the wall's normal.
var runs: Array[Dictionary] = []
var rats: Array[Dictionary] = []
## Tests: they take no notice of you.
var tame: bool = false
var _rng := RandomNumberGenerator.new()


## Stretches along the foot of walls in a room: looks out from some of its
## floor cells (CellGrid, in the frame `xf`) for a wall, then follows it both
## ways while there is floor, the wall goes on and nothing is in the way.
static func find_runs(space: PhysicsDirectSpaceState3D, cells: Array, xf: Transform3D, rng: RandomNumberGenerator, most: int) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	var q := PhysicsRayQueryParameters3D.new()
	q.collision_mask = LaneGraph.WORLD
	q.hit_from_inside = true
	var order: Array = cells.duplicate()
	# A seeded shuffle.
	for i: int in range(order.size() - 1, 0, -1):
		var k: int = rng.randi() % (i + 1)
		var t: Variant = order[i]
		order[i] = order[k]
		order[k] = t
	for c: Vector3i in order.slice(0, 60):
		if found.size() >= most:
			break
		var centre: Variant = _floor(space, q, xf * (CellGrid.cell_centre(c) + Vector3(0, 0.3, 0)))
		if centre == null:
			continue
		for k: int in 4:
			var dir: Vector3 = xf.basis * Vector3(cos(k * PI * 0.5), 0, sin(k * PI * 0.5))
			q.from = (centre as Vector3) + Vector3(0, 0.08, 0)
			q.to = q.from + dir * (CellGrid.BAY * 0.65)
			var hit: Dictionary = space.intersect_ray(q)
			if hit.is_empty() or absf((hit["normal"] as Vector3).y) > 0.3 or (hit["normal"] as Vector3).length_squared() < 0.5:
				continue
			var n: Vector3 = hit["normal"]
			n.y = 0.0
			n = n.normalized()
			var foot: Variant = _floor(space, q, (hit["position"] as Vector3) + n * OFF + Vector3(0, 0.3, 0))
			if foot == null:
				continue
			var along: Vector3 = n.cross(Vector3.UP).normalized()
			var a: Vector3 = _follow(space, q, foot, along, n)
			var b: Vector3 = _follow(space, q, foot, -along, n)
			if a.distance_to(b) < MIN_RUN:
				continue
			var mid: Vector3 = (a + b) * 0.5
			if found.any(func(r: Dictionary) -> bool: return ((r["a"] as Vector3) + (r["b"] as Vector3)).distance_to(mid * 2.0) < RUNS_APART * 2.0):
				continue
			found.append({"a": a, "b": b, "normal": n})
			break
	return found


## As far along the wall's foot from `from` as a rat can go.
static func _follow(space: PhysicsDirectSpaceState3D, q: PhysicsRayQueryParameters3D, from: Vector3, along: Vector3, n: Vector3) -> Vector3:
	var at: Vector3 = from
	for i: int in int(REACH / 0.5):
		var next: Variant = _floor(space, q, at + along * 0.5 + Vector3(0, 0.3, 0))
		if next == null or absf((next as Vector3).y - at.y) > 0.12:
			break
		# The wall still beside it.
		q.from = (next as Vector3) + Vector3(0, 0.08, 0)
		q.to = q.from - n * (OFF + 0.25)
		var wall: Dictionary = space.intersect_ray(q)
		if wall.is_empty() or (wall["normal"] as Vector3).dot(n) < 0.8 or q.from.distance_to(wall["position"]) < OFF * 0.5:
			break
		# Nothing in its way.
		q.from = at + Vector3(0, 0.05, 0)
		q.to = (next as Vector3) + Vector3(0, 0.05, 0)
		if not space.intersect_ray(q).is_empty():
			break
		at = next
	return at


static func _floor(space: PhysicsDirectSpaceState3D, q: PhysicsRayQueryParameters3D, p: Vector3) -> Variant:
	q.from = p
	q.to = p - Vector3(0, 1.0, 0)
	var hit: Dictionary = space.intersect_ray(q)
	if hit.is_empty() or (hit["normal"] as Vector3).y < 0.7:
		return null
	return hit["position"]


func setup(d: CreatureDef, found: Array[Dictionary], count: int, seed_value: int, boxes: Array = []) -> void:
	def = d
	runs = found
	_rng.seed = seed_value
	name = "%s_%d" % [d.id, seed_value & 0xffff]
	top_level = true
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	position = runs[0]["a"]
	focus = ((runs[0]["a"] as Vector3) + (runs[0]["b"] as Vector3)) * 0.5
	bounds = AABB(runs[0]["a"], Vector3.ZERO)
	for r: Dictionary in runs:
		bounds = bounds.expand(r["a"]).expand(r["b"])
		for end: String in ["a", "b"]:
			var hole := MeshInstance3D.new()
			hole.mesh = GroundBody.hole_mesh()
			hole.material_override = GroundBody.hole_material()
			hole.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(hole)
			var n: Vector3 = r["normal"]
			# On what you see of the wall there, which may stand proud of it.
			var foot: Vector3 = (r[end] as Vector3) - n * OFF
			var proud: float = maxf(0.0, GeckoWall.proud_at(GeckoWall.near(boxes, foot, 1.0), foot + Vector3(0, HOLE * 0.4, 0), n))
			# On the wall's face, looking out of it.
			hole.global_transform = Transform3D(Basis(n.cross(Vector3.UP).normalized() * -1.0, Vector3.UP, n).scaled(Vector3.ONE * HOLE), foot + n * (proud + 0.012))
	bounds = bounds.grow(0.5)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = GroundBody.rat_mesh()
	mm.instance_count = count
	multimesh = mm
	material_override = GroundBody.material(d)
	custom_aabb = AABB(bounds.position - position, bounds.size)
	for i: int in count:
		var run: int = i % runs.size()
		var length: float = ((runs[run]["a"] as Vector3)).distance_to(runs[run]["b"])
		var rat: Dictionary = {"run": run, "s": 0.0, "to": 1.0, "state": IN, "timer": _rng.randf_range(0.0, 9.0), "length": length,
			"size": d.length_m * _rng.randf_range(d.length_spread.x, d.length_spread.y), "phase": _rng.randf(), "shade": _rng.randf(), "pace": _rng.randf_range(0.85, 1.15)}
		if _rng.randf() < 0.5:
			# Out on its run already.
			rat["state"] = RUN
			rat["s"] = _rng.randf() * length
			rat["to"] = 1.0 if _rng.randf() < 0.5 else -1.0
			rat["timer"] = _rng.randf_range(0.5, 2.5)
		else:
			rat["s"] = 0.0 if _rng.randf() < 0.5 else length
		rats.append(rat)
		_place(i)


func tick(delta: float, player: Vector3, _moving: float) -> void:
	for i: int in rats.size():
		var rat: Dictionary = rats[i]
		var run: Dictionary = runs[int(rat["run"])]
		var length: float = rat["length"]
		var at: Vector3 = (run["a"] as Vector3).lerp(run["b"], float(rat["s"]) / length)
		var near: float = INF if tame else at.distance_to(player)
		var state: int = rat["state"]
		match state:
			IN:
				rat["timer"] = float(rat["timer"]) - delta
				if near < SAFE:
					rat["timer"] = maxf(float(rat["timer"]), 2.5)     # not while you are about
				elif float(rat["timer"]) <= 0.0:
					rat["state"] = RUN
					rat["to"] = 1.0 if float(rat["s"]) < length * 0.5 else -1.0
					rat["timer"] = _rng.randf_range(0.6, 2.8)
					_place(i)
				continue
			RUN, SNIFF:
				if near < def.startle_radius:
					rat["state"] = BOLT
					rat["to"] = -1.0 if float(rat["s"]) < length * 0.5 else 1.0
				elif state == SNIFF:
					rat["timer"] = float(rat["timer"]) - delta
					if float(rat["timer"]) <= 0.0:
						rat["state"] = RUN
						rat["timer"] = _rng.randf_range(0.6, 2.8)
						# Sometimes it turns back.
						if _rng.randf() < 0.25:
							rat["to"] = -float(rat["to"])
				else:
					rat["timer"] = float(rat["timer"]) - delta
					if float(rat["timer"]) <= 0.0:
						rat["state"] = SNIFF
						rat["timer"] = _rng.randf_range(0.5, 2.2)
		if int(rat["state"]) == RUN or int(rat["state"]) == BOLT:
			var speed: float = (def.speed.y if int(rat["state"]) == BOLT else def.speed.x) * float(rat["pace"])
			var s: float = float(rat["s"]) + float(rat["to"]) * speed * delta
			if s <= 0.0 or s >= length:
				# Into the hole.
				rat["s"] = clampf(s, 0.0, length)
				rat["state"] = IN
				rat["timer"] = _rng.randf_range(2.0, 11.0)
			else:
				rat["s"] = s
		_place(i)


func _place(i: int) -> void:
	var rat: Dictionary = rats[i]
	var state: int = rat["state"]
	if state == IN:
		multimesh.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ZERO), Vector3.ZERO))
		return
	var run: Dictionary = runs[int(rat["run"])]
	var a: Vector3 = run["a"]
	var b: Vector3 = run["b"]
	var at: Vector3 = a.lerp(b, float(rat["s"]) / float(rat["length"]))
	var ahead: Vector3 = (b - a).normalized() * float(rat["to"])
	var basis: Basis = Basis.looking_at(ahead, Vector3.UP).scaled(Vector3.ONE * float(rat["size"]))
	multimesh.set_instance_transform(i, Transform3D(basis, at - position))
	var gait: float = 1.0 if state == BOLT else (0.45 if state == RUN else 0.0)
	multimesh.set_instance_custom_data(i, Color(gait, float(rat["phase"]), float(rat["shade"]), 0.0))

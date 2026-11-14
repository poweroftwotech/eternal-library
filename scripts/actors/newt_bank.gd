class_name NewtBank
extends MultiMeshInstance3D
## Luristan newts (phase 20 step 3, C04) by one body of running water: a few
## on the wet stone of its edge and on the floor of its shallows. Drawn as one
## MultiMesh (GroundBody's newt); Fauna ticks it.
##
## A newt sits a long while, then walks slowly to a spot close by (bank to
## shallows and back). When you come near it freezes; within SLIP_RADIUS it
## slips into the water, down to the bottom, and is gone; one comes back a
## while after, somewhere along the bank, once you are away.

enum { SIT, WALK, FREEZE, SLIP, GONE }

## You this close (m): it freezes; this close: it slips in.
const FREEZE_RADIUS: float = 4.0
const SLIP_RADIUS: float = 2.0
## Seconds it sits, and gone after slipping in.
const SIT_S: Vector2 = Vector2(5.0, 18.0)
const GONE_S: Vector2 = Vector2(25.0, 50.0)
## A walk goes this far at most (m).
const STEP: float = 1.3
## Spots: at most this many, this far apart (m).
const MOST_SPOTS: int = 40
const APART: float = 0.28

var def: CreatureDef
var body: WaterBody
## {at, wet (in the water)}.
var spots: Array[Dictionary] = []
var newts: Array[Dictionary] = []
var bounds: AABB
var _rng := RandomNumberGenerator.new()


## Where newts can be along `b`: its shallows (the floor under a little
## water) and the stone just past its edge, about level with the surface.
static func find_spots(b: WaterBody, space: PhysicsDirectSpaceState3D, seed_value: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var q := PhysicsRayQueryParameters3D.new()
	q.collision_mask = HabitatScan.WORLD_MASK
	q.hit_back_faces = true
	if b.tris.size() < 3:
		return out
	# Points anywhere on the surface (not the sounding's places, which keep
	# clear of walls: a narrow channel, the Fungus Terraces', has none), the
	# floor under each found with a ray.
	for _t: int in 90:
		if out.size() >= MOST_SPOTS:
			break
		var ti: int = (rng.randi() % (b.tris.size() / 3)) * 3
		var u: float = rng.randf()
		var v: float = rng.randf()
		if u + v > 1.0:
			u = 1.0 - u
			v = 1.0 - v
		var xz: Vector2 = b.tris[ti] + (b.tris[ti + 1] - b.tris[ti]) * u + (b.tris[ti + 2] - b.tris[ti]) * v
		var down: Dictionary = _seen_down(space, q, Vector3(xz.x, b.surface + 1.0, xz.y), b.surface - 1.5)
		if not down.is_empty() and (down["position"] as Vector3).y > b.surface - 0.03:
			continue     # (not under the water here)
		if down.is_empty() or (down["normal"] as Vector3).y < 0.7:
			continue
		var s: Vector3 = down["position"]
		var depth: float = b.surface - s.y
		if depth < 0.25 and not _crowded(out, s):
			out.append({"at": s, "wet": true})
		if depth > 0.6:
			continue
		# The bank: a step out past the edge, a floor about level with the
		# water or up to a kerb's height over it.
		var turn: float = rng.randf() * TAU
		for k: int in 8:
			var dir := Vector3(cos(turn + k * TAU / 8.0), 0, sin(turn + k * TAU / 8.0))
			var found: bool = false
			for d: float in [0.2, 0.4, 0.65, 0.9]:
				var p: Vector3 = Vector3(xz.x, 0, xz.y) + dir * d
				if b.contains_xz(Vector2(p.x, p.z)):
					continue
				var hit: Dictionary = _seen_down(space, q, Vector3(p.x, b.surface + 0.8, p.z), b.surface - 0.4)
				if hit.is_empty() or (hit["normal"] as Vector3).y < 0.8:
					break
				var at: Vector3 = hit["position"]
				var over: float = at.y - b.surface
				# (the first step past the edge, so nothing stands between; the
				# collision can't say, being a slab over some channels)
				if over > -0.3 and over < 0.5 and not _crowded(out, at):
					out.append({"at": at, "wet": false})
					found = true
				break
			if found:
				break
	return out


## The first surface you see straight down from `from` to height `bottom`:
## {position, normal}, or empty. Collision there may not be what you see (the
## Fungus Terraces' rows are a slab over their channels), so the mesh of what
## was hit is asked where its own faces are along the same line.
static var _tri_meshes: Dictionary = {}


static func _seen_down(space: PhysicsDirectSpaceState3D, q: PhysicsRayQueryParameters3D, from: Vector3, bottom: float) -> Dictionary:
	var to := Vector3(from.x, bottom, from.z)
	q.from = from
	q.to = to
	var hit: Dictionary = space.intersect_ray(q)
	if hit.is_empty():
		return hit
	var holder: Node = (hit["collider"] as Node).get_parent()
	var meshes: Array = [holder] + holder.get_children()
	var best: Dictionary = {}
	for node: Node in meshes:
		var m := node as MeshInstance3D
		if m == null or m.mesh == null:
			continue
		var part: String = str(m.name)
		if ["water", "fall", "caps", "gills", "stalks", "drip", "spore"].any(func(w: String) -> bool: return part.contains(w)):
			continue     # (the water itself, and what grows: not stone to sit on)
		var key: int = m.mesh.get_instance_id()
		if not _tri_meshes.has(key):
			_tri_meshes[key] = m.mesh.generate_triangle_mesh()
		var tm: TriangleMesh = _tri_meshes[key]
		if tm == null:
			continue
		var inv: Transform3D = m.global_transform.affine_inverse()
		var seen: Dictionary = tm.intersect_segment(inv * from, inv * to)
		if seen.is_empty():
			continue
		var at: Vector3 = m.global_transform * (seen["position"] as Vector3)
		if best.is_empty() or at.y > (best["position"] as Vector3).y:
			var n: Vector3 = (m.global_transform.basis * (seen["normal"] as Vector3)).normalized()
			best = {"position": at, "normal": n if n.y >= 0.0 else -n}
	return hit if best.is_empty() else best


static func _crowded(out: Array[Dictionary], at: Vector3) -> bool:
	return out.any(func(o: Dictionary) -> bool: return (o["at"] as Vector3).distance_to(at) < APART)


func setup(d: CreatureDef, b: WaterBody, found: Array[Dictionary], count: int, seed_value: int) -> void:
	def = d
	body = b
	spots = found
	_rng.seed = seed_value
	name = "%s_%d" % [d.id, seed_value & 0xffff]
	top_level = true
	position = Vector3(b.bounds.get_center().x, b.surface, b.bounds.get_center().z)
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visibility_range_end = Fauna.SLEEP_DISTANCE + 5.0
	bounds = b.bounds.grow(1.0)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = GroundBody.newt_mesh()
	mm.instance_count = count
	multimesh = mm
	material_override = GroundBody.material(d)
	# Mostly on the bank to begin with: that's where you see them.
	var dry: Array[int] = []
	var wet: Array[int] = []
	for i: int in spots.size():
		(wet if spots[i]["wet"] else dry).append(i)
	for k: int in count:
		var pool: Array[int] = dry if not dry.is_empty() and (k < count - 1 or wet.is_empty()) else wet
		if pool.is_empty():
			pool = wet
		var si: int = pool.pop_at(_rng.randi() % pool.size())
		var n: Dictionary = {"spot": si, "pos": spots[si]["at"], "goal": spots[si]["at"], "yaw": _rng.randf() * TAU, "state": SIT,
			"timer": _rng.randf_range(0.0, SIT_S.y), "len": d.length_m * _rng.randf_range(d.length_spread.x, d.length_spread.y),
			"phase": _rng.randf(), "shade": _rng.randf(), "gait": 0.0}
		newts.append(n)
	_draw_all()


func count() -> int:
	return newts.size()


## One step. `player` is the player's feet; `moving` its speed (m/s).
func tick(delta: float, player: Vector3, _moving: float) -> void:
	for i: int in newts.size():
		var n: Dictionary = newts[i]
		var pos: Vector3 = n["pos"]
		var near: float = Vector2(pos.x - player.x, pos.z - player.z).length() if absf(player.y - pos.y) < 2.5 else INF
		var gait: float = 0.0
		match int(n["state"]):
			SIT, FREEZE:
				if near < SLIP_RADIUS:
					_slip(n)
				elif near < FREEZE_RADIUS:
					n["state"] = FREEZE
				else:
					if int(n["state"]) == FREEZE:
						n["state"] = SIT
						n["timer"] = _rng.randf_range(2.0, 6.0)     # (still a moment more)
					n["timer"] = float(n["timer"]) - delta
					if float(n["timer"]) <= 0.0:
						_wander(n)
			WALK:
				if near < SLIP_RADIUS:
					_slip(n)
				elif near < FREEZE_RADIUS:
					n["state"] = FREEZE     # (stops mid-step)
				else:
					gait = 0.25
					if _go(n, def.speed.x, delta):
						n["state"] = SIT
						n["timer"] = _rng.randf_range(SIT_S.x, SIT_S.y)
			SLIP:
				gait = 1.0
				if _go(n, def.speed.y, delta):
					n["state"] = GONE
					n["timer"] = _rng.randf_range(GONE_S.x, GONE_S.y)
			GONE:
				n["timer"] = float(n["timer"]) - delta
				if float(n["timer"]) <= 0.0:
					_come_back(n, player)
		n["gait"] = move_toward(float(n["gait"]), gait, delta * 4.0)
		multimesh.set_instance_custom_data(i, Color(n["gait"], n["phase"], n["shade"], 0.0))
	_draw_all()


## Toward its goal; true when there.
func _go(n: Dictionary, speed: float, delta: float) -> bool:
	var pos: Vector3 = n["pos"]
	var goal: Vector3 = n["goal"]
	var d: Vector3 = goal - pos
	if d.length() < 0.01:
		n["pos"] = goal
		return true
	if Vector2(d.x, d.z).length() > 0.01:
		n["yaw"] = lerp_angle(float(n["yaw"]), atan2(-d.x, -d.z), 1.0 - exp(-5.0 * delta))
	n["pos"] = pos.move_toward(goal, speed * delta)
	return false


## A spot close by, free of other newts.
func _wander(n: Dictionary) -> void:
	n["timer"] = _rng.randf_range(SIT_S.x, SIT_S.y)
	var pos: Vector3 = n["pos"]
	for _t: int in 8:
		var si: int = _rng.randi() % spots.size()
		var at: Vector3 = spots[si]["at"]
		if si == int(n["spot"]) or at.distance_to(pos) > STEP or _held(si):
			continue
		n["spot"] = si
		n["goal"] = at
		n["state"] = WALK
		return


## Into the water: to the nearest place a little deep, and down onto its floor.
func _slip(n: Dictionary) -> void:
	var pos: Vector3 = n["pos"]
	var best: Vector3 = pos - Vector3(0, 0.15, 0)
	var best_d: float = INF
	for s: Vector3 in body.samples:
		var d: float = Vector2(s.x - pos.x, s.z - pos.z).length()
		if body.surface - s.y > 0.08 and d < best_d and d < 2.5:
			best_d = d
			best = s
	for sp: Dictionary in spots:     # (a narrow channel has no sounded places: its wet spots)
		var s: Vector3 = sp["at"]
		var d: float = Vector2(s.x - pos.x, s.z - pos.z).length()
		if sp["wet"] and d < best_d and d < 2.5:
			best_d = d
			best = s - Vector3(0, 0.02, 0)
	n["goal"] = best
	n["state"] = SLIP


## Back on the bank, somewhere you are not.
func _come_back(n: Dictionary, player: Vector3) -> void:
	for _t: int in 10:
		var si: int = _rng.randi() % spots.size()
		var at: Vector3 = spots[si]["at"]
		if Vector2(at.x - player.x, at.z - player.z).length() < FREEZE_RADIUS + 3.0 or _held(si):
			continue
		n["spot"] = si
		n["pos"] = at
		n["goal"] = at
		n["state"] = SIT
		n["timer"] = _rng.randf_range(SIT_S.x, SIT_S.y)
		return
	n["timer"] = 5.0


func _held(si: int) -> bool:
	for o: Dictionary in newts:
		if int(o["spot"]) == si and int(o["state"]) != GONE:
			return true
	return false


func _draw_all() -> void:
	for i: int in newts.size():
		var n: Dictionary = newts[i]
		var s: float = 0.0 if int(n["state"]) == GONE else float(n["len"])
		multimesh.set_instance_transform(i, Transform3D(Basis(Vector3.UP, float(n["yaw"])).scaled(Vector3.ONE * s), (n["pos"] as Vector3) - position))


## What each newt is doing, for the overlay.
func doing(i: int) -> String:
	return ["sitting", "walking", "frozen", "slipping in", "gone in"][int(newts[i]["state"])]

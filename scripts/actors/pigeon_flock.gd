class_name PigeonFlock
extends Node3D
## A flock of pigeons (phase 20 step 2, C16): 6 to 20 birds on the ledges of
## a place (a quarter's pigeon tower, parapets, the rim of the bazaar dome's
## eye, the Gorge's roofs), a few strutting and pecking on open ground. Drawn
## as three MultiMeshes, one per pose (PigeonBody), so a flock costs three
## draw calls. Ticked by Fauna as one band.
##
##   PERCH  sits facing out over its ledge's edge, turns its head, shuffles a
##          step along the ledge, coos now and then
##   WALK   on the ground: struts with its head bobbing, stops to peck, walks
##          out of your way
##   FLY    lifting off, or coming in to land: a short arc (bezier)
##   WHEEL  the flock circles over the place, two or three laps, and comes back
##
## The flock wheels by itself every minute or two (some of it), and all of it
## bursts up with a clap of wings if you run near, or come right up to one.
##
## Perches are found on what you see (the geckos' lesson: a wall's collision
## sits behind its face): the room's meshes' upward faces, kept where the
## edge drops away in front, there is room to stand and nothing solid at the
## spot (find_ledges).

enum { PERCH, WALK, FLY, WHEEL }

## A ledge is at least this high over what is below its edge (m).
const LEDGE_DROP: float = 1.0
## And this high over the floor under it (m).
const LEDGE_HIGH: float = 2.2
const APART: float = 0.34
## Most perches kept, and candidates tried, per room.
const MOST: int = 140
const MOST_TRIES: int = 700
## Upward faces sampled per mesh (cached by mesh), and faces read at most.
const PER_MESH: int = 60
const MOST_FACES: int = 4000
## Wheeling: speed (m/s), radius range (m), over the highest perch by (m).
const WHEEL_SPEED: float = 7.0
const WHEEL_RADIUS: Vector2 = Vector2(3.0, 9.0)
const WHEEL_OVER: float = 2.5
## Walking (m/s), fleeing on foot (m/s).
const STRUT: float = 0.32
const SHY: float = 0.9
## You come this near a pigeon on the ground walking, it walks away (m); this
## near, or running within RUN_RADIUS, the whole flock goes up.
const STEP_AWAY: float = 2.4
const FLUSH: float = 0.9
const RUN_SPEED: float = 4.5
const RUN_RADIUS: float = 7.0
## Coos: one bird at a time, now and then (s between, at random).
const COO_GAP: Vector2 = Vector2(2.5, 9.0)
const COO_REACH: float = 18.0
const PLANT_PARTS: PackedStringArray = ["__wood", "__bark", "__stems", "__leaves", "__flowers", "_figs", "water", "__fall"]

static var _mesh_tops: Dictionary = {}

var def: CreatureDef
## {at, face (out over the edge, level), high (over the floor), ground}.
var perches: Array[Dictionary] = []
## {pos, yaw, pitch, state, perch, timer, peck, phase, fly{a, b, c, t, dur, to}, lap_a, lap_r, lap_h, laps}.
var birds: Array[Dictionary] = []
var bounds: AABB
var centre: Vector3
var wheel_radius: float = 0.0
var wheel_height: float = 0.0
var why: String = ""
var _mm: Array[MultiMeshInstance3D] = []
var _taken: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _space: PhysicsDirectSpaceState3D
var _clock: float = 0.0
var _next_wheel: float = 0.0
var _next_coo: float = 0.0
var _calm: float = 0.0


## Finding a room's ledges, a little each frame (Fauna's budget): the room's
## meshes in a fixed shuffled order, a few points off each one's upward faces
## tried at once, until MOST perches are kept or `most_tries` are used.
class LedgeScan:
	var boxes: Array = []
	var ground := PackedVector3Array()
	## Eye points on the room's floor: a ledge must be seen from one (empty:
	## anywhere, the Gorge's open scenery).
	var eyes := PackedVector3Array()
	## Nothing lower than this is a ledge (the floor plus LEDGE_HIGH; -INF: no floor).
	var low: float = -INF
	var most_tries: int = MOST_TRIES
	## Points tried on each mesh (more when there are few, big ones: the Gorge).
	var per_mesh: int = 4
	var at: int = 0
	var tries: int = 0
	var out: Array[Dictionary] = []
	var rng := RandomNumberGenerator.new()


static func begin(boxes: Array, ground: PackedVector3Array, eyes: PackedVector3Array, seed_value: int, most_tries: int = MOST_TRIES) -> LedgeScan:
	var scan := LedgeScan.new()
	scan.rng.seed = seed_value
	scan.ground = ground
	scan.eyes = eyes
	scan.most_tries = most_tries
	if not eyes.is_empty():
		scan.low = INF
		for e: Vector3 in eyes:
			scan.low = minf(scan.low, e.y - 1.6 + LEDGE_HIGH)
	# Only meshes that reach high enough, and aren't plants or water.
	for e: Array in boxes:
		var m: MeshInstance3D = e[0]
		if not is_instance_valid(m) or m.mesh == null or (e[1] as AABB).end.y < scan.low:
			continue
		if eyes.size() > 0 and not _near_eye(e[1], eyes):
			continue
		var part: String = str(m.name).to_lower()
		var skip: bool = false
		for p: String in PLANT_PARTS:
			if part.contains(p):
				skip = true
		if not skip:
			scan.boxes.append(m)
	# A fixed shuffle, so the tries spread over the room.
	for i: int in range(scan.boxes.size() - 1, 0, -1):
		var k: int = scan.rng.randi() % (i + 1)
		var t: Variant = scan.boxes[i]
		scan.boxes[i] = scan.boxes[k]
		scan.boxes[k] = t
	if scan.boxes.size() < 60:
		scan.per_mesh = clampi(most_tries / maxi(scan.boxes.size(), 1), 4, 40)
	return scan


## Some eye close enough to see a perch on `box` (as _try asks).
static func _near_eye(box: AABB, eyes: PackedVector3Array) -> bool:
	for e: Vector3 in eyes:
		var c: Vector3 = e.clamp(box.position, box.end)
		if Vector2(c.x - e.x, c.z - e.z).length() <= 18.0 and box.position.y - e.y <= 16.0:
			return true
	return false


## Works until `deadline_usec`; true when done (scan.out holds the perches,
## ground spots last).
static func step(scan: LedgeScan, s: PhysicsDirectSpaceState3D, deadline_usec: int) -> bool:
	var q := PhysicsRayQueryParameters3D.new()
	q.collision_mask = HabitatScan.WORLD_MASK
	var pt := PhysicsPointQueryParameters3D.new()
	pt.collision_mask = HabitatScan.WORLD_MASK
	while scan.at < scan.boxes.size() and scan.out.size() < MOST and scan.tries < scan.most_tries:
		if Time.get_ticks_usec() >= deadline_usec:
			return false
		var m: MeshInstance3D = scan.boxes[scan.at]
		scan.at += 1
		if not is_instance_valid(m):
			continue
		var tops: PackedVector3Array = _tops(m.mesh, PER_MESH if scan.per_mesh <= 4 else scan.per_mesh * 15)
		if tops.is_empty():
			continue
		for _k: int in mini(scan.per_mesh, tops.size()):
			var at: Vector3 = m.global_transform * tops[scan.rng.randi() % tops.size()]
			if scan.per_mesh > 4 and not scan.eyes.is_empty() and not _near_eye(AABB(at, Vector3.ZERO), scan.eyes):
				continue     # (a big mesh: only its parts near the walks)
			var p: Variant = _try(at, scan, s, q, pt)
			if p != null:
				(p as Dictionary)["tower"] = str(m.name).contains("pigeon")     # (the quarter's pigeon tower)
				scan.out.append(p)
	for g: Vector3 in scan.ground:
		scan.out.append({"at": g, "face": Vector3(cos(hash(g) % 628 / 100.0), 0, sin(hash(g) % 628 / 100.0)), "high": 0.0, "ground": true})
	scan.ground = PackedVector3Array()
	return true


## A perch at `at`, or null: high over what is below its edge, room to stand
## and nothing solid there, open in front, and seen from the room's floor.
static func _try(at: Vector3, scan: LedgeScan, s: PhysicsDirectSpaceState3D, q: PhysicsRayQueryParameters3D, pt: PhysicsPointQueryParameters3D) -> Variant:
	if at.y < scan.low:
		return null
	for o: Dictionary in scan.out:
		if (o["at"] as Vector3).distance_squared_to(at) < APART * APART:
			return null
	scan.tries += 1
	q.from = at + Vector3(0, 0.03, 0)
	q.to = at + Vector3(0, 0.4, 0)
	if not s.intersect_ray(q).is_empty():
		return null
	pt.position = at + Vector3(0, 0.08, 0)
	if not s.intersect_point(pt, 1).is_empty():
		return null
	# The edge: just past it the ledge drops away (measured past the edge, not
	# from the ledge itself, which may have its own collision).
	var face := Vector3.ZERO
	var high: float = 0.0
	for k: int in 8:
		var dir := Vector3(cos(k * TAU / 8.0), 0.0, sin(k * TAU / 8.0))
		q.from = at + dir * 0.22 + Vector3(0, 0.06, 0)
		q.to = q.from - Vector3(0, 40.0, 0)
		var hit: Dictionary = s.intersect_ray(q)
		var drop: float = 40.0 if hit.is_empty() else q.from.y - (hit["position"] as Vector3).y
		if drop < LEDGE_HIGH:
			continue
		# (and no wall right there, in front of its face)
		q.from = at + Vector3(0, 0.1, 0)
		q.to = at + dir * 0.35 + Vector3(0, 0.1, 0)
		if s.intersect_ray(q).is_empty():
			face = dir
			high = drop
			break
	if face == Vector3.ZERO:
		return null
	# Seen from the floor (not the top of a roof outside the room).
	if not scan.eyes.is_empty():
		var seen: bool = false
		var tried: int = 0
		for e: Vector3 in scan.eyes:
			if tried >= 4:
				break
			if Vector2(e.x - at.x, e.z - at.z).length() > 18.0 or at.y - e.y > 16.0:
				continue
			tried += 1
			q.from = at + Vector3(0, 0.15, 0) + face * 0.25
			q.to = e
			if s.intersect_ray(q).is_empty():
				seen = true
				break
		if not seen:
			return null
	return {"at": at, "face": face, "high": high, "ground": false}


## Up to PER_MESH points on a mesh's upward faces (local), cached per mesh.
static func _tops(mesh: Mesh, most: int = PER_MESH) -> PackedVector3Array:
	var key: Array = [mesh.get_instance_id(), most]
	if _mesh_tops.has(key):
		return _mesh_tops[key]
	var pts := PackedVector3Array()
	for si: int in mesh.get_surface_count():
		var arrays: Array = mesh.surface_get_arrays(si)
		var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var tris: int = (idx.size() if not idx.is_empty() else v.size()) / 3
		var stride: int = maxi(1, tris / MOST_FACES)
		for t: int in range(0, tris, stride):
			var a: Vector3 = v[idx[t * 3] if not idx.is_empty() else t * 3]
			var b: Vector3 = v[idx[t * 3 + 1] if not idx.is_empty() else t * 3 + 1]
			var c: Vector3 = v[idx[t * 3 + 2] if not idx.is_empty() else t * 3 + 2]
			var n: Vector3 = (b - a).cross(c - a)
			if n.length_squared() < 1e-8:
				continue
			n = n.normalized()
			if absf(n.y) < 0.85:     # (either winding: some kit pieces are mirrored)
				continue
			if n.y < 0.0 and (a + b + c).y / 3.0 < 0.0:
				continue
			# Its middle and its edges' middles (a ledge's edge is where it matters).
			pts.append((a + b + c) / 3.0)
			pts.append((a + b) * 0.5)
			pts.append((b + c) * 0.5)
			pts.append((c + a) * 0.5)
	# Keep PER_MESH of them, spread through the list.
	if pts.size() > most:
		var kept := PackedVector3Array()
		var step: float = float(pts.size()) / most
		for i: int in most:
			kept.append(pts[int(i * step)])
		pts = kept
	_mesh_tops[key] = pts
	return pts


## Enough ledge perches for a flock.
static func ledges_of(found: Array[Dictionary]) -> int:
	return found.filter(func(p: Dictionary) -> bool: return not p["ground"]).size()


func setup(d: CreatureDef, found: Array[Dictionary], count: int, seed_value: int, space: PhysicsDirectSpaceState3D) -> void:
	def = d
	perches = found
	_space = space
	_rng.seed = seed_value
	name = "pigeon_flock_%d" % (seed_value & 0xffff)
	top_level = true
	# Where it wheels: over the middle of its ledges, as wide as the space allows.
	var sum := Vector3.ZERO
	var top: float = -INF
	var n_ledge: int = 0
	for p: Dictionary in perches:
		if not p["ground"]:
			sum += p["at"]
			top = maxf(top, (p["at"] as Vector3).y)
			n_ledge += 1
	centre = sum / maxi(n_ledge, 1)
	var q := PhysicsRayQueryParameters3D.new()
	q.collision_mask = HabitatScan.WORLD_MASK
	q.hit_back_faces = true
	# Over the ledges, and under the ceiling all round the circle (a dome's
	# eye lets a ray from the middle straight out: it isn't the ceiling; and a
	# dome comes down toward its edge, so the height and the width are settled
	# together, twice over).
	wheel_height = top + WHEEL_OVER
	wheel_radius = WHEEL_RADIUS.y
	for _pass: int in 2:
		var mid := Vector3(centre.x, wheel_height, centre.z)
		var reach: float = WHEEL_RADIUS.y / 0.7
		for k: int in 12:
			q.from = mid
			q.to = mid + Vector3(cos(k * TAU / 12.0), 0, sin(k * TAU / 12.0)) * reach
			var hit: Dictionary = space.intersect_ray(q)
			if not hit.is_empty():
				reach = minf(reach, mid.distance_to(hit["position"]))
		wheel_radius = clampf(reach * 0.7, 0.0, WHEEL_RADIUS.y)
		var h: float = top + WHEEL_OVER
		for k: int in 9:
			var off: Vector3 = Vector3.ZERO if k == 0 else Vector3(cos(k * TAU / 8.0), 0, sin(k * TAU / 8.0)) * (wheel_radius * 1.15 + 0.5)
			q.from = Vector3(centre.x, centre.y + 0.5, centre.z) + off
			q.to = q.from + Vector3(0, 40.0, 0)
			var ceiling: Dictionary = space.intersect_ray(q)
			if not ceiling.is_empty():
				h = minf(h, (ceiling["position"] as Vector3).y - 1.5)
		wheel_height = maxf(h, centre.y + 1.0)
	# What you see isn't always solid (the bazaar's dome has no collision), so
	# the ledges themselves bound it too: just over the highest of them, and
	# inside their ring when they face in (a dome's drum, a court's walls) or
	# round it when they face out (round a pigeon tower).
	var high: Array[Dictionary] = []
	for p: Dictionary in perches:
		if not p["ground"] and (p["at"] as Vector3).y > top - 2.0:
			high.append(p)
	var inward: int = 0
	var dist: float = 0.0
	for p: Dictionary in high:
		var off: Vector3 = (p["at"] as Vector3) - centre
		off.y = 0.0
		dist += off.length()
		# (toward the middle: open across a dome or a court; a tower in the way)
		q.from = (p["at"] as Vector3) + Vector3(0, 0.15, 0)
		q.to = Vector3(centre.x, q.from.y, centre.z)
		if off.length() > 0.5 and space.intersect_ray(q).is_empty():
			inward += 1
	dist /= maxi(high.size(), 1)
	wheel_height = minf(wheel_height, top + 1.2)
	if inward * 2 >= high.size():
		wheel_radius = minf(wheel_radius, dist * 0.8)
	else:
		wheel_radius = maxf(wheel_radius, dist + 2.0)
	# A pigeon tower (its meshes are named so): round the tower, just over
	# its rim, as wide as the space round it allows.
	var tower: Array[Dictionary] = perches.filter(func(p: Dictionary) -> bool: return p.get("tower", false))
	if tower.size() >= 4:
		var axis := Vector3.ZERO
		var rim: float = -INF
		for p: Dictionary in tower:
			axis += p["at"]
			rim = maxf(rim, (p["at"] as Vector3).y)
		axis /= tower.size()
		var r_tower: float = 0.0
		for p: Dictionary in tower:
			r_tower = maxf(r_tower, Vector2((p["at"] as Vector3).x - axis.x, (p["at"] as Vector3).z - axis.z).length())
		centre = Vector3(axis.x, axis.y, axis.z)
		wheel_height = rim + 1.0
		var room: float = r_tower + 6.0
		for k: int in 12:
			var dir := Vector3(cos(k * TAU / 12.0), 0, sin(k * TAU / 12.0))
			q.from = Vector3(axis.x, wheel_height, axis.z) + dir * (r_tower + 0.4)
			q.to = Vector3(axis.x, wheel_height, axis.z) + dir * (r_tower + 6.0)
			var hit: Dictionary = space.intersect_ray(q)
			if not hit.is_empty():
				room = minf(room, Vector2((hit["position"] as Vector3).x - axis.x, (hit["position"] as Vector3).z - axis.z).length())
		wheel_radius = r_tower + (room - r_tower) * 0.6 if room - r_tower > 1.4 else 0.0
		if wheel_radius == 0.0:
			# Hemmed in (a tight court): over the top of it instead, if the
			# ceiling leaves room.
			var over: float = rim + 3.5
			q.from = Vector3(axis.x, over, axis.z)
			q.to = q.from + Vector3(0, 40.0, 0)
			var lid: Dictionary = space.intersect_ray(q)
			if lid.is_empty() or (lid["position"] as Vector3).y > over + 2.0:
				var reach: float = WHEEL_RADIUS.y / 0.7
				for k: int in 12:
					q.to = q.from + Vector3(cos(k * TAU / 12.0), 0, sin(k * TAU / 12.0)) * reach
					var hit: Dictionary = space.intersect_ray(q)
					if not hit.is_empty():
						reach = minf(reach, q.from.distance_to(hit["position"]))
				wheel_height = over
				wheel_radius = reach * 0.7
	if wheel_radius < WHEEL_RADIUS.x:
		wheel_radius = 0.0     # no room to circle: it flutters to other ledges instead
	# The birds: on ledges in rows (a free perch next to one taken), a few on the ground.
	var ledges: Array[int] = []
	var grounds: Array[int] = []
	for i: int in perches.size():
		(grounds if perches[i]["ground"] else ledges).append(i)
	var on_ground: int = mini(grounds.size(), int(count * 0.3)) if not grounds.is_empty() else 0
	for k: int in count:
		var pi: int = _free_perch(grounds if k < on_ground else ledges, k > 0 and k >= on_ground)
		if pi < 0:
			pi = _free_perch(ledges, false)
		if pi < 0:
			break
		var p: Dictionary = perches[pi]
		_taken[pi] = true
		var face: Vector3 = p["face"]
		birds.append({"pos": p["at"], "yaw": atan2(-face.x, -face.z) + _rng.randf_range(-0.4, 0.4), "pitch": 0.0, "state": WALK if p["ground"] else PERCH,
			"perch": pi, "timer": _rng.randf_range(1.0, 6.0), "peck": 0.0, "phase": _rng.randf() * TAU, "fly": {}, "goal": p["at"],
			"lap_a": 0.0, "lap_r": 0.0, "lap_h": 0.0, "laps": 0.0, "scale": _rng.randf_range(0.92, 1.08)})
	# The three poses' MultiMeshes.
	var ms: Array[ArrayMesh] = PigeonBody.meshes()
	for pose: int in 3:
		var mmi := MultiMeshInstance3D.new()
		mmi.name = ["Folded", "Up", "Down"][pose]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = ms[pose]
		mm.instance_count = birds.size()
		mmi.multimesh = mm
		mmi.material_override = PigeonBody.material()
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)
		_mm.append(mmi)
	bounds = AABB(centre, Vector3.ZERO)
	for p: Dictionary in perches:
		bounds = bounds.expand(p["at"])
	if wheel_radius > 0.0:
		bounds = bounds.merge(AABB(Vector3(centre.x - wheel_radius - 1.5, wheel_height - 2.0, centre.z - wheel_radius - 1.5), Vector3(wheel_radius * 2.0 + 3.0, 4.0, wheel_radius * 2.0 + 3.0)))
	bounds = bounds.grow(1.0)
	for mmi: MultiMeshInstance3D in _mm:
		mmi.custom_aabb = AABB(bounds.position - global_position, bounds.size)
	_next_wheel = _rng.randf_range(30.0, 90.0)
	_next_coo = _rng.randf_range(1.0, COO_GAP.y)
	for i: int in birds.size():
		_draw(i)


func count() -> int:
	return birds.size()


## A free perch from `pool`; `beside`: next to one already taken, if any is (rows).
func _free_perch(pool: Array[int], beside: bool) -> int:
	var free: Array[int] = pool.filter(func(i: int) -> bool: return not _taken.has(i))
	if free.is_empty():
		return -1
	if beside:
		var best: int = -1
		var best_d: float = 0.8
		for i: int in free:
			for t: int in _taken:
				if perches[t]["ground"]:
					continue
				var d: float = (perches[i]["at"] as Vector3).distance_to(perches[t]["at"])
				if d < best_d:
					best_d = d
					best = i
		if best >= 0:
			return best
	return free[_rng.randi() % free.size()]


func tick(delta: float, feet: Vector3, moving: float) -> void:
	if birds.is_empty():
		return
	_clock += delta
	_calm = maxf(0.0, _calm - delta)
	# You: running near, or walking right up to one, puts the whole flock up.
	var flush: bool = false
	for b: Dictionary in birds:
		if int(b["state"]) == WHEEL or int(b["state"]) == FLY:
			continue
		var pos: Vector3 = b["pos"]
		var flat: float = Vector2(pos.x - feet.x, pos.z - feet.z).length()
		var up: float = absf(pos.y - (feet.y + 0.9))
		if up > 3.0:
			continue
		if (moving > RUN_SPEED and flat < RUN_RADIUS) or (moving > 0.3 and flat < FLUSH):
			flush = true
			break
	if flush:
		_take_off(1.0, true)
	elif _clock >= _next_wheel:
		_next_wheel = _clock + _rng.randf_range(60.0, 150.0)
		if _calm <= 0.0:
			_take_off(_rng.randf_range(0.4, 0.8), false)
	# One coo at a time, from a bird at rest.
	if _clock >= _next_coo:
		_next_coo = _clock + _rng.randf_range(COO_GAP.x, COO_GAP.y)
		var b: Dictionary = birds[_rng.randi() % birds.size()]
		if int(b["state"]) == PERCH or int(b["state"]) == WALK:
			SoundSystem.cue("pigeon_coo", b["pos"], COO_REACH, -4.0, 1.0, 0.08)
	for i: int in birds.size():
		var b: Dictionary = birds[i]
		match int(b["state"]):
			PERCH:
				_perch(b, delta)
			WALK:
				_walk(b, delta, feet, moving)
			FLY:
				_fly(b, delta)
			WHEEL:
				_wheel(b, delta)
		_draw(i)


## `share` of the flock goes up to wheel (all of it, alarmed, with a clap).
func _take_off(share: float, alarmed: bool) -> void:
	var went: int = 0
	for b: Dictionary in birds:
		if int(b["state"]) == WHEEL or int(b["state"]) == FLY:
			continue
		if not alarmed and _rng.randf() > share:
			continue
		_taken.erase(int(b["perch"]))
		b["perch"] = -1
		went += 1
		if wheel_radius > 0.0:
			var a: float = atan2((b["pos"] as Vector3).z - centre.z, (b["pos"] as Vector3).x - centre.x) + _rng.randf_range(-0.3, 0.3)
			b["lap_a"] = a
			b["lap_r"] = wheel_radius * _rng.randf_range(0.8, 1.1)
			b["lap_h"] = wheel_height + _rng.randf_range(-1.0, 1.0)
			b["laps"] = _rng.randf_range(1.6, 2.8) * TAU
			b["lift"] = -a     # (level with the entry where it joins the circle)
			var entry := Vector3(centre.x + cos(a) * float(b["lap_r"]), float(b["lap_h"]), centre.z + sin(a) * float(b["lap_r"]))
			_arc(b, entry, -1, alarmed)
		else:
			# Nowhere to circle: off to another ledge.
			var to: int = _free_perch(_ledge_list(), false)
			if to >= 0:
				_taken[to] = true
				_arc(b, perches[to]["at"], to, alarmed)
	if went > 0:
		_calm = 20.0 if alarmed else 6.0
		SoundSystem.cue("wings_clap" if alarmed else "wings_flock", centre, 25.0, 0.0 if alarmed else -5.0, 1.0, 0.05)


func _ledge_list() -> Array[int]:
	var out: Array[int] = []
	for i: int in perches.size():
		if not perches[i]["ground"]:
			out.append(i)
	return out


## Flies `b` from where it is to `to` along an arc; `perch`: lands there (-1:
## joins the wheel at the end).
func _arc(b: Dictionary, to: Vector3, perch: int, quick: bool) -> void:
	var from: Vector3 = b["pos"]
	var mid: Vector3 = (from + to) * 0.5 + Vector3(0, 0.6 + from.distance_to(to) * 0.15, 0)
	var dur: float = clampf(from.distance_to(to) / (WHEEL_SPEED * (1.1 if quick else 0.8)), 0.5, 4.0) + (0.0 if quick else _rng.randf_range(0.0, 0.8))
	b["fly"] = {"a": from, "b": mid, "c": to, "t": 0.0, "dur": dur, "to": perch, "wait": 0.0 if quick else _rng.randf_range(0.0, 0.6)}
	b["state"] = FLY


func _perch(b: Dictionary, delta: float) -> void:
	b["timer"] = float(b["timer"]) - delta
	b["pitch"] = lerpf(float(b["pitch"]), 0.0, minf(1.0, 6.0 * delta))
	if float(b["timer"]) > 0.0:
		return
	b["timer"] = _rng.randf_range(1.5, 7.0)
	var p: Dictionary = perches[int(b["perch"])]
	var face: Vector3 = p["face"]
	var r: float = _rng.randf()
	if r < 0.55:
		b["yaw"] = atan2(-face.x, -face.z) + _rng.randf_range(-0.9, 0.9)     # looks about
	elif r < 0.75:
		b["pitch"] = 0.5     # preens / bobs
	else:
		# A step along the ledge to a free perch close by.
		for i: int in perches.size():
			if _taken.has(i) or perches[i]["ground"]:
				continue
			var d: float = (perches[i]["at"] as Vector3).distance_to(p["at"])
			if d < 0.75:
				_taken.erase(int(b["perch"]))
				_taken[i] = true
				b["perch"] = i
				b["pos"] = perches[i]["at"]
				var f: Vector3 = perches[i]["face"]
				b["yaw"] = atan2(-f.x, -f.z)
				break


func _walk(b: Dictionary, delta: float, feet: Vector3, moving: float) -> void:
	var pos: Vector3 = b["pos"]
	var goal: Vector3 = b["goal"]
	var from_you := Vector2(pos.x - feet.x, pos.z - feet.z)
	var shy: bool = moving > 0.3 and from_you.length() < STEP_AWAY and absf(pos.y - feet.y) < 1.5
	if shy and float(b["peck"]) <= 0.0:
		# Out of your way: to the ground perch furthest from you, close by.
		var best: Vector3 = goal
		var best_d: float = -1.0
		for p: Dictionary in perches:
			if not p["ground"]:
				continue
			var at: Vector3 = p["at"]
			if at.distance_to(pos) > 3.0:
				continue
			var d: float = Vector2(at.x - feet.x, at.z - feet.z).length()
			if d > best_d:
				best_d = d
				best = at
		b["goal"] = best
		goal = best
	var to := Vector2(goal.x - pos.x, goal.z - pos.z)
	if float(b["peck"]) > 0.0:
		b["peck"] = float(b["peck"]) - delta
		b["pitch"] = 0.75 if fmod(float(b["peck"]), 0.35) > 0.17 else 0.35
		return
	if to.length() < 0.06:
		b["pitch"] = lerpf(float(b["pitch"]), 0.0, minf(1.0, 8.0 * delta))
		b["timer"] = float(b["timer"]) - delta
		if float(b["timer"]) <= 0.0:
			b["timer"] = _rng.randf_range(0.8, 3.0)
			if _rng.randf() < 0.55:
				b["peck"] = _rng.randf_range(0.7, 1.6)
			else:
				# A few steps to somewhere near on the ground.
				var options: Array = perches.filter(func(p: Dictionary) -> bool: return p["ground"] and (p["at"] as Vector3).distance_to(pos) < 2.5)
				if not options.is_empty():
					var next: Vector3 = options[_rng.randi() % options.size()]["at"]
					b["goal"] = next + Vector3(_rng.randf_range(-0.4, 0.4), 0, _rng.randf_range(-0.4, 0.4))
		return
	var speed: float = SHY if shy else STRUT
	var step: Vector2 = to.normalized() * minf(speed * delta, to.length())
	b["yaw"] = rotate_toward(float(b["yaw"]), atan2(-to.x, -to.y), 6.0 * delta)
	pos.x += step.x
	pos.z += step.y
	b["pos"] = pos
	b["phase"] = float(b["phase"]) + delta * (14.0 if shy else 9.0)
	b["pitch"] = 0.12 + 0.12 * sin(float(b["phase"]))     # the head-bob of a walking pigeon


func _fly(b: Dictionary, delta: float) -> void:
	var f: Dictionary = b["fly"]
	if float(f["wait"]) > 0.0:
		f["wait"] = float(f["wait"]) - delta
		return
	f["t"] = float(f["t"]) + delta / float(f["dur"])
	var t: float = minf(1.0, float(f["t"]))
	var prev: Vector3 = b["pos"]
	var at: Vector3 = _bezier(f, t)
	b["pos"] = at
	var dir: Vector3 = at - prev
	if Vector2(dir.x, dir.z).length() > 0.001:
		b["yaw"] = atan2(-dir.x, -dir.z)
	b["pitch"] = clampf(-dir.y / maxf(dir.length(), 0.001), -0.5, 0.5) * 0.6
	b["phase"] = float(b["phase"]) + delta * 9.0
	if t < 1.0:
		return
	var to: int = int(f["to"])
	if to >= 0:
		b["perch"] = to
		var p: Dictionary = perches[to]
		b["pos"] = p["at"]
		b["goal"] = p["at"]
		b["state"] = WALK if p["ground"] else PERCH
		var face: Vector3 = p["face"]
		b["yaw"] = atan2(-face.x, -face.z)
		b["pitch"] = 0.0
		b["timer"] = _rng.randf_range(1.0, 4.0)
	else:
		b["state"] = WHEEL


func _wheel(b: Dictionary, delta: float) -> void:
	var w: float = WHEEL_SPEED / maxf(float(b["lap_r"]), 1.0)
	b["lap_a"] = float(b["lap_a"]) + w * delta
	b["laps"] = float(b["laps"]) - w * delta
	var a: float = b["lap_a"]
	var r: float = b["lap_r"]
	# (a slow rise and fall once round, each bird a little apart: not the wing
	# beat's clock, which made them bob)
	var h: float = float(b["lap_h"]) + 0.5 * sin(a + float(b.get("lift", 0.0)))
	b["pos"] = Vector3(centre.x + cos(a) * r, h, centre.z + sin(a) * r)
	b["yaw"] = atan2(sin(a), -cos(a))     # along the circle (beak to -sin a, cos a)
	b["pitch"] = 0.0
	b["phase"] = float(b["phase"]) + delta * 9.0
	if float(b["laps"]) > 0.0:
		return
	# Back down: a free perch, the ground for some if there is any.
	var pool: Array[int] = []
	for i: int in perches.size():
		pool.append(i)
	var to: int = _free_perch(pool, false)
	if to < 0:
		b["laps"] = TAU
		return
	_taken[to] = true
	_arc(b, perches[to]["at"], to, false)
	(b["fly"] as Dictionary)["wait"] = 0.0


static func _bezier(f: Dictionary, t: float) -> Vector3:
	var a: Vector3 = f["a"]
	var m: Vector3 = f["b"]
	var c: Vector3 = f["c"]
	return a.lerp(m, t).lerp(m.lerp(c, t), t)


## Puts bird `i` in the MultiMesh of its pose, hidden in the others.
func _draw(i: int) -> void:
	var b: Dictionary = birds[i]
	var flying: bool = int(b["state"]) == FLY and float((b["fly"] as Dictionary).get("wait", 0.0)) <= 0.0 or int(b["state"]) == WHEEL
	var pose: int = PigeonBody.Pose.FOLDED
	if flying:
		# Wings beating (about 8 a second); gliding on the wheel's long side.
		var glide: bool = int(b["state"]) == WHEEL and sin(float(b["lap_a"]) * 1.5) > 0.4
		pose = PigeonBody.Pose.UP if glide or sin(float(b["phase"]) * 5.5) > 0.0 else PigeonBody.Pose.DOWN
	var s: float = def.length_m / PigeonBody.SIZE * float(b["scale"])
	var basis := Basis(Vector3.UP, float(b["yaw"])) * Basis(Vector3.RIGHT, -float(b["pitch"]))
	if int(b["state"]) == WHEEL:
		# Banked into the turn (inward wing down), as steep as speed and radius ask.
		var bank: float = minf(atan(WHEEL_SPEED * WHEEL_SPEED / (9.8 * maxf(float(b["lap_r"]), 1.0))), 0.6)
		basis = basis * Basis(Vector3(0, 0, 1), -bank)
	var xf := Transform3D(basis.scaled(Vector3.ONE * s), (b["pos"] as Vector3) - global_position)
	var hidden := Transform3D(Basis().scaled(Vector3.ZERO), xf.origin)
	for k: int in 3:
		_mm[k].multimesh.set_instance_transform(i, xf if k == pose else hidden)


## Where bird `i` is (global), for the overlay and tests.
func where(i: int) -> Vector3:
	return birds[i]["pos"]

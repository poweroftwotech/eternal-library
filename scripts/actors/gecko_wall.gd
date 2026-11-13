class_name GeckoWall
extends MultiMeshInstance3D
## The wall geckos of one room (phase 19 step 4), one MultiMesh: one to three
## on the wall beside some of its burning lamps. A gecko clings, now and then
## darts a hand's width and freezes again; come close and it runs up the wall
## out of reach, and comes down once you have gone. When its lamp is put out
## it is gone. Ticked by Fauna; its wriggle is in creature_crawler.gdshader.

enum { CLING, DART, FLEE, HIGH, DOWN }
## A wall within this far of a flame (m) has geckos; they keep within ROAM of
## where they started (m).
const WALL_REACH: float = 1.5
const ROAM: float = 0.55
## Up the wall this far at most (m), at this speed (m/s); down again once you
## are SAFE m off for SAFE_S s.
const CLIMB: float = 1.5
const SAFE: float = 4.5
const SAFE_S: float = 5.0
## The lamps are looked at this often (s).
const LAMP_CHECK_S: float = 1.0
## Held this far off what you see of the wall (m).
const PROUD: float = 0.004
## The most a wall's look is taken to stand in front of its collision (m).
const MAX_PROUD: float = 0.12
## Nothing may stand within this far in front of it (m).
const COVER: float = 0.7
## Mesh id -> its triangles (TriangleMesh), made once (kit meshes are shared).
static var _triangles: Dictionary = {}

var def: CreatureDef
var bounds: AABB
var focus: Vector3
var geckos: Array[Dictionary] = []
## Tests: they take no notice of you.
var tame: bool = false
var _rng := RandomNumberGenerator.new()
var shadows: MultiMeshInstance3D
var _lamp_wait: float = 0.0


## The wall beside a flame: {at, normal, up, lamp} or null. `up`: how far the
## wall goes on above the place (m, at most CLIMB).
## Why the last find_site found nothing (for the overlay).
static var why: String = ""


static func find_site(space: PhysicsDirectSpaceState3D, flame: Dictionary, reach: float = WALL_REACH, climb: float = CLIMB) -> Variant:
	why = "no wall within %.1f m of the lamp" % reach
	var q := PhysicsRayQueryParameters3D.new()
	q.collision_mask = LaneGraph.WORLD
	var from: Vector3 = flame["at"]
	var hits: Array = []
	for k: int in 8:
		q.from = from
		q.to = from + Vector3(cos(k * TAU / 8.0), 0, sin(k * TAU / 8.0)) * reach
		var hit: Dictionary = space.intersect_ray(q)
		if hit.is_empty() or absf((hit["normal"] as Vector3).y) > 0.25:
			continue
		var d: float = from.distance_to(hit["position"])
		if d > 0.05:
			hits.append([d, hit])
	hits.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for e: Array in hits:
		var n: Vector3 = e[1]["normal"]
		n.y = 0.0
		n = n.normalized()
		var at: Vector3 = e[1]["position"]
		var side: Vector3 = n.cross(Vector3.UP).normalized()
		# A real wall: flat for half a metre each way and above (not a jar, a post).
		if not (on_wall(space, q, at + side * 0.5, n) and on_wall(space, q, at - side * 0.5, n) and on_wall(space, q, at + Vector3(0, 0.4, 0), n)):
			why = "the wall by it is not flat and wide enough"
			continue
		# And open to the room in front of it (not the back of a shelf behind
		# jars, not a niche): clear for 1.5 m at the middle and to each side.
		var open: bool = true
		for off: float in [0.0, -0.45, 0.45]:
			q.from = at + side * off + n * 0.05
			q.to = q.from + n * 1.5
			if not space.intersect_ray(q).is_empty():
				open = false
				break
		if not open:
			why = "the wall by it is not open to the room (something stands within 1.5 m)"
			continue
		return {"at": at, "normal": n, "up": _wall_above(space, q, at, n, climb), "lamp": flame.get("node")}
	return null


## A room's meshes with their boxes ([[MeshInstance3D, global AABB], ...]),
## made once per room; `near` picks the few within `reach` of a point, which
## is what proud_at is given.
static func boxes_of(room: Node) -> Array:
	var out: Array = []
	for n: Node in room.find_children("*", "MeshInstance3D", true, false):
		var m := n as MeshInstance3D
		if m.mesh != null and m.is_visible_in_tree():
			out.append([m, m.global_transform * m.get_aabb()])
	return out


static func near(boxes: Array, p: Vector3, reach: float) -> Array:
	var out: Array = []
	var around := AABB(p - Vector3.ONE * reach, Vector3.ONE * reach * 2.0)
	for e: Array in boxes:
		if (e[1] as AABB).intersects(around):
			out.append(e[0])
	return out


## How far what you see of a wall stands proud of the wall that was found
## (m), at `p` on it: plaster, trim, tile bands and hangings are often a few
## cm in front of the collision. Looks along the wall's normal at the
## triangles of the meshes near `p` (`meshes`: the room's MeshInstance3Ds).
## -1: nothing to see there within MAX_PROUD, or something else stands in
## front of it within COVER (a shelf's edge, a jar): not a place to be seen.
static func proud_at(meshes: Array, p: Vector3, n: Vector3) -> float:
	var best: float = -1.0
	var near: Array = []
	for m: MeshInstance3D in meshes:
		if not is_instance_valid(m) or m.mesh == null or not m.is_visible_in_tree():
			continue
		var inv: Transform3D = m.global_transform.affine_inverse()
		if not m.mesh.get_aabb().grow(COVER).has_point(inv * p):
			continue
		var key: int = m.mesh.get_instance_id()
		if not _triangles.has(key):
			_triangles[key] = m.mesh.generate_triangle_mesh()
		var tm: TriangleMesh = _triangles[key]
		if tm == null:
			continue
		near.append([m, inv, tm])
		var hit: Dictionary = tm.intersect_segment(inv * (p + n * MAX_PROUD), inv * (p - n * 0.02))
		if not hit.is_empty():
			best = maxf(best, (m.global_transform * (hit["position"] as Vector3) - p).dot(n))
	if best < 0.0:
		return -1.0
	for e: Array in near:
		var inv: Transform3D = e[1]
		if not (e[2] as TriangleMesh).intersect_segment(inv * (p + n * COVER), inv * (p + n * (best + 0.01))).is_empty():
			return -1.0
	return best


## Whether the wall is there at `p` (a point on or near its face).
static func on_wall(space: PhysicsDirectSpaceState3D, q: PhysicsRayQueryParameters3D, p: Vector3, n: Vector3) -> bool:
	q.from = p + n * 0.25
	q.to = p - n * 0.15
	var hit: Dictionary = space.intersect_ray(q)
	return not hit.is_empty() and (hit["normal"] as Vector3).dot(n) > 0.85 and absf((hit["position"] as Vector3 - p).dot(n)) < 0.04


static func _wall_above(space: PhysicsDirectSpaceState3D, q: PhysicsRayQueryParameters3D, at: Vector3, n: Vector3, climb: float = CLIMB) -> float:
	var up: float = 0.0
	while up < climb and on_wall(space, q, at + Vector3(0, up + 0.3, 0), n):
		up += 0.3
	return up


## `sites`: walls beside flames (find_site). One to group_size.y on each.
func setup(d: CreatureDef, sites: Array[Dictionary], space: PhysicsDirectSpaceState3D, seed_value: int) -> void:
	def = d
	_rng.seed = seed_value
	name = "%s_%d" % [d.id, seed_value & 0xffff]
	top_level = true
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var q := PhysicsRayQueryParameters3D.new()
	q.collision_mask = LaneGraph.WORLD
	for site: Dictionary in sites:
		var n: Vector3 = site["normal"]
		var side: Vector3 = n.cross(Vector3.UP).normalized()
		var meshes: Array = site.get("meshes", [])
		for k: int in _rng.randi_range(d.group_size.x, d.group_size.y):
			if geckos.size() >= d.room_cap:
				break
			for tries: int in 8:
				var home: Vector3 = (site["at"] as Vector3) + side * _rng.randf_range(-0.6, 0.6) + Vector3(0, _rng.randf_range(-0.25, 0.5), 0)
				var proud: float = proud_at(meshes, home, n) if not meshes.is_empty() else 0.0
				if not on_wall(space, q, home, n) or proud < 0.0:
					continue
				geckos.append({"home": home, "at": home, "normal": n, "side": side, "up": float(site["up"]), "lamp": site["lamp"], "turn": _rng.randf() * TAU,
					"state": CLING, "timer": _rng.randf_range(1.0, 10.0), "from": home, "to": home, "t": 0.0, "safe": 0.0, "gone": false,
					"size": d.length_m * _rng.randf_range(d.length_spread.x, d.length_spread.y), "phase": _rng.randf(), "shade": _rng.randf(), "proud": proud + PROUD})
				break
	if geckos.is_empty():
		return
	position = geckos[0]["home"]
	focus = position
	bounds = AABB(position, Vector3.ZERO)
	for g: Dictionary in geckos:
		bounds = bounds.expand(g["home"]).expand((g["home"] as Vector3) + Vector3(0, float(g["up"]), 0))
	bounds = bounds.grow(0.6)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = GroundBody.gecko_mesh()
	mm.instance_count = geckos.size()
	multimesh = mm
	material_override = GroundBody.material(d)
	custom_aabb = AABB(bounds.position - position, bounds.size)
	# Their shadows: one soft blob each, under it on its floor or wall.
	shadows = BlobShadow.many(geckos.size())
	shadows.custom_aabb = custom_aabb
	add_child(shadows)
	for i: int in geckos.size():
		_place(i, 0.0)


func tick(delta: float, player: Vector3, _moving: float) -> void:
	var eye: Vector3 = player + Vector3(0, 1.4, 0)
	_lamp_wait -= delta
	var look_at_lamps: bool = _lamp_wait <= 0.0
	if look_at_lamps:
		_lamp_wait = LAMP_CHECK_S
	for i: int in geckos.size():
		var g: Dictionary = geckos[i]
		if look_at_lamps:
			var lamp: Variant = g["lamp"]
			var out: bool = lamp != null and (not is_instance_valid(lamp) or str((lamp as Node).get_meta("lamp_state", "lit")) == "dark")
			if out != bool(g["gone"]):
				g["gone"] = out
				_place(i, 0.0)
		if bool(g["gone"]):
			continue
		var at: Vector3 = g["at"]
		var near: float = INF if tame else at.distance_to(eye)
		var state: int = g["state"]
		if near < def.startle_radius and (state == CLING or state == DART or state == DOWN) and float(g["up"]) > 0.6:
			# Up the wall, out of reach.
			_go(g, at, Vector3((g["home"] as Vector3).x, (g["home"] as Vector3).y + float(g["up"]), (g["home"] as Vector3).z) + (g["side"] as Vector3) * _rng.randf_range(-0.2, 0.2), FLEE)
			state = FLEE
		match state:
			CLING:
				g["timer"] = float(g["timer"]) - delta
				if float(g["timer"]) <= 0.0:
					# A dart: a hand's width, back toward home when it has strayed.
					var home: Vector3 = g["home"]
					var a: float = _rng.randf() * TAU
					var step: Vector3 = ((g["side"] as Vector3) * cos(a) + Vector3.UP * sin(a)) * _rng.randf_range(0.08, 0.22)
					if (at + step).distance_to(home) > ROAM:
						step = (home - at).normalized() * 0.2
					_go(g, at, at + step, DART)
			DART, FLEE, DOWN:
				var speed: float = def.speed.y if state != DOWN else def.speed.x
				var dist: float = maxf((g["from"] as Vector3).distance_to(g["to"]), 0.001)
				g["t"] = minf(1.0, float(g["t"]) + speed * delta / dist)
				g["at"] = (g["from"] as Vector3).lerp(g["to"], float(g["t"]))
				_place(i, 1.0 if state != DOWN else 0.5)
				if float(g["t"]) >= 1.0:
					g["state"] = HIGH if state == FLEE else CLING
					g["timer"] = _rng.randf_range(2.5, 12.0)
					g["safe"] = 0.0
					_place(i, 0.0)
			HIGH:
				g["safe"] = float(g["safe"]) + delta if near > def.safe_radius else 0.0
				if float(g["safe"]) > SAFE_S:
					_go(g, at, g["home"], DOWN)


func _go(g: Dictionary, from: Vector3, to: Vector3, state: int) -> void:
	g["from"] = from
	g["to"] = to
	g["t"] = 0.0
	g["state"] = state
	var d: Vector3 = to - from
	# Its heading, as an angle in the wall's plane (0: along `side`, a quarter turn: up).
	g["turn"] = atan2(d.y, d.dot(g["side"]))


## Flat on the wall: its back to the room, its nose along its heading.
func _place(i: int, gait: float) -> void:
	var g: Dictionary = geckos[i]
	if bool(g["gone"]):
		if shadows != null:
			BlobShadow.place(shadows, i, Vector3.ZERO, Vector3.UP, Vector3.FORWARD, Vector2.ZERO)
		multimesh.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ZERO), Vector3.ZERO))
		return
	var n: Vector3 = g["normal"]
	var ahead: Vector3 = (g["side"] as Vector3) * cos(float(g["turn"])) + Vector3.UP * sin(float(g["turn"]))
	var basis := Basis(n.cross(-ahead).normalized(), n, -ahead).scaled(Vector3.ONE * float(g["size"]))
	multimesh.set_instance_transform(i, Transform3D(basis, (g["at"] as Vector3) + n * float(g["proud"]) - position))
	if shadows != null:
		# On the wall just behind it, a little below (the lamps are above).
		BlobShadow.place(shadows, i, (g["at"] as Vector3) + n * (float(g["proud"]) - 0.002) - Vector3(0, 0.012, 0) - position, n, ahead, Vector2(1.0, 1.6) * float(g["size"]))
	multimesh.set_instance_custom_data(i, Color(gait, float(g["phase"]), float(g["shade"]), 0.0))

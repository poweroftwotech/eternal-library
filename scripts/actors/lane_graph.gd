class_name LaneGraph
extends RefCounted
## Where a walking animal can go in one room (phase 19 Q6): the lanes people
## have walked into its floor (the room's FloorWear lines, the same ones that
## polish the stone), as points a short step apart joined into a graph, plus
## its rest spots (rugs, cushions, bedrolls, benches, a takht) and the places
## beside still water to watch the fish from. A room with no lanes (the camp)
## gets a few points round each rest spot instead, where the floor is clear.
##
## Nothing here is a navigation mesh: an animal only ever stands on a point or
## walks the straight line between two joined points.
##
## Built a slice a frame (begin, then step until it returns true): reading a
## big room's nodes for rugs takes several ms in all.

## Points along a lane are this far apart (m); two points closer than JOIN are
## joined (where lanes cross or meet).
const STEP: float = 0.5
const JOIN: float = 0.62
## A rest spot joins the lanes when a lane point is within this far (m) and
## the way is clear.
const SPOT_REACH: float = 5.0
## No lanes: points this far (m) out from each rest spot, and as far again.
const RING: float = 2.4
const RING_WAYS: int = 8
## Most rest spots kept for one room.
const MAX_SPOTS: int = 24
## The fish are watched from within this far of the water's edge (m); a place
## is made at the edge when a point is within EDGE_REACH of it.
const WATCH_REACH: float = 2.0
const EDGE_REACH: float = 9.0
## Node names (lower case) that are somewhere to lie.
const SOFT: Array[String] = ["rug", "carpet", "cushion", "bedroll", "takht", "bench"]
const NOT_SOFT: Array[String] = ["moss", "hearth", "rack", "loom"]
## An animal's way is checked this high over the floor (m).
const BODY_HEIGHT: float = 0.14
## A grid point needs this much room round it at body height (m): not inside
## a wall, not against furniture.
const ROOM_ROUND: float = 0.3
## Fewer soft rest spots than this: corners and dead ends serve too, this far
## apart (m).
const NOOKS_UNDER: int = 3
const NOOK_APART: float = 5.0
## The world's floors and walls: layer 1, or layer 9 in the places joined
## without a loading screen (SeamlessPlaces.OPEN_LAYER: the camp, the Gorge).
const WORLD: int = 1 | (1 << 8)

var points: PackedVector3Array = PackedVector3Array()
var links: Array[PackedInt32Array] = []
## Point ids: somewhere soft to lie.
var spots: PackedInt32Array = PackedInt32Array()
## Places to watch fish from: [{node, at}] (at: the water's middle).
var watch: Array[Dictionary] = []
var bounds: AABB = AABB()
## The points animals live among: the biggest joined-up part (ids).
var home: PackedInt32Array = PackedInt32Array()
## How many soft things the room has (reachable or not): how lived-in it is.
var soft_found: int = 0
## How many of its points came from walked lanes.
var lane_points: int = 0

var _bodies: Array = []
var _stage: int = 0
var _stack: Array[Node] = []
var _wears: Array[FloorWear] = []
var _soft: Array[Node3D] = []
var _lines: Array = []          # [wear, line]
var _cells: Dictionary = {}     # Vector2i -> [ids]
var _grid: Array = []           # the room's floor cells (Vector3i) still to lay points in
var _grid_xf := Transform3D.IDENTITY
var _grid_ids: Dictionary = {}  # Vector3i -> id
var _ring_from: Array[int] = [] # no lanes: the points the rings go out from
var _q := PhysicsRayQueryParameters3D.new()


## Starts the graph of `room`; `bodies` its still water (WaterBody), kept out
## of. `cells`: its floor cells (CellGrid, in the frame `xf`): with no lanes
## of its own (the Domicile Quarter) the room is walked on a 1 m grid of
## points over those cells, joined where the way between two is clear.
static func begin(room: Node3D, bodies: Array, cells: Array = [], xf: Transform3D = Transform3D.IDENTITY) -> LaneGraph:
	var g := LaneGraph.new()
	g._bodies = bodies
	g._stack = [room]
	g._grid = cells.duplicate()
	g._grid_xf = xf
	g._q.collision_mask = WORLD
	g._q.hit_back_faces = true
	g._q.hit_from_inside = true
	return g


## The whole graph at once (tests).
static func build(room: Node3D, space: PhysicsDirectSpaceState3D, bodies: Array, cells: Array = [], xf: Transform3D = Transform3D.IDENTITY) -> LaneGraph:
	var g: LaneGraph = begin(room, bodies, cells, xf)
	while not g.step(space, Time.get_ticks_usec() + 1000000):
		pass
	return g


## More of the work, until `deadline_usec`; true once the graph is whole.
func step(space: PhysicsDirectSpaceState3D, deadline_usec: int) -> bool:
	while _stage < 4 and Time.get_ticks_usec() < deadline_usec:
		_one(space)
	return _stage >= 4


func _one(space: PhysicsDirectSpaceState3D) -> void:
	match _stage:
		0:     # read the room: its walked lanes and its soft things
			var n: int = 0
			while not _stack.is_empty() and n < 200:
				n += 1
				var node: Node = _stack.pop_back()
				if not is_instance_valid(node):
					continue
				if node is FloorWear:
					_wears.append(node as FloorWear)
					continue
				if node is Node3D:
					var lower: String = String(node.name).to_lower()
					if SOFT.any(func(w: String) -> bool: return lower.contains(w)) and not NOT_SOFT.any(func(w: String) -> bool: return lower.contains(w)):
						if _soft.size() < MAX_SPOTS * 2:
							_soft.append(node as Node3D)
						continue     # (not its parts as well)
				if node is MeshInstance3D or node is CollisionObject3D or node is Light3D:
					continue
				_stack.append_array(node.get_children())
			if _stack.is_empty():
				for w: FloorWear in _wears:
					for line: PackedVector2Array in w.paths:
						_lines.append([w, line])
				_stage = 1
		1:     # the lanes, a line at a time; with none, the floor grid, a few points at a time
			if not _lines.is_empty():
				var e: Array = _lines.pop_back()
				if is_instance_valid(e[0]):
					_lane(space, e[0], e[1])
				return
			if not _cells.is_empty():
				_join()
			if points.size() == _grid_ids.size() and not _grid.is_empty():
				for k: int in mini(1, _grid.size()):
					_grid_cell(space, _grid.pop_back())
				return
			lane_points = points.size()
			_stage = 2
		2:     # somewhere soft to lie, a thing at a time
			if _soft.is_empty() or spots.size() >= MAX_SPOTS:
				_stage = 3
				return
			var thing: Node3D = _soft.pop_back()
			if is_instance_valid(thing) and thing.is_inside_tree():
				_spot(space, thing)
		3:
			if lane_points == 0:
				_rings(space)
			_home()
			_watch(space)
			for k: int in home.size():
				bounds = AABB(points[home[k]], Vector3.ZERO) if k == 0 else bounds.expand(points[home[k]])
			_stage = 4


## One cell of the floor grid: sixteen points 1 m apart, on the cell's middle
## lines (where its doorways are) and between, each kept where there is floor
## and joined to the neighbours already in where the way is clear.
func _grid_cell(space: PhysicsDirectSpaceState3D, c: Vector3i) -> void:
	for k: int in 16:
		var i: int = k % 4
		var j: int = k >> 2
		var key := Vector3i(c.x * 4 + i, c.y, c.z * 4 + j)
		if _grid_ids.has(key):
			continue
		var local := Vector3(c.x * CellGrid.BAY + i, c.y * CellGrid.BAY + 0.2, -c.z * CellGrid.BAY - j)
		var hit: Variant = _floor(space, _q, _grid_xf * local, 1.0)
		if hit == null or absf((hit as Vector3).y - (_grid_xf * local).y + 0.2) > 0.3 or _in_water(hit as Vector3, _bodies):
			continue     # no floor, or not the cell's own (a table top, the ground under a wall)
		var crowded: bool = false
		for way: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
			_q.from = (hit as Vector3) + Vector3(0, BODY_HEIGHT, 0)
			_q.to = _q.from + way * ROOM_ROUND
			if not space.intersect_ray(_q).is_empty():
				crowded = true
				break
		if crowded:
			continue
		var id: int = _add(hit as Vector3)
		_grid_ids[key] = id
		for d: Vector3i in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
			var other: int = _grid_ids.get(key + d, -1)
			if other >= 0 and _clear(space, _q, points[id], points[other]):
				_link(id, other)


func _lane(space: PhysicsDirectSpaceState3D, wear: FloorWear, line: PackedVector2Array) -> void:
	var y0: float = wear.global_position.y
	var last: int = -1
	for k: int in line.size() - 1:
		var a: Vector3 = wear.to_global(Vector3(line[k].x, 0, line[k].y))
		var b: Vector3 = wear.to_global(Vector3(line[k + 1].x, 0, line[k + 1].y))
		var n: int = maxi(1, ceili(a.distance_to(b) / STEP))
		for i: int in (n + 1 if k == line.size() - 2 else n):
			var p: Vector3 = a.lerp(b, float(i) / n)
			var hit: Variant = _floor(space, _q, Vector3(p.x, y0, p.z), 1.0)
			if hit == null or _in_water(hit as Vector3, _bodies):
				last = -1
				continue
			var id: int = _add(hit as Vector3)
			if last >= 0:
				_link(last, id)
			last = id
			var c := Vector2i(floori(p.x / JOIN), floori(p.z / JOIN))
			if not _cells.has(c):
				_cells[c] = []
			(_cells[c] as Array).append(id)


## Lanes that cross or meet: join points that are close.
func _join() -> void:
	for c: Vector2i in _cells:
		for id: int in _cells[c]:
			for dx: int in [0, 1]:
				for dz: int in [-1, 0, 1]:
					if dx == 0 and dz < 0:
						continue
					for other: int in _cells.get(c + Vector2i(dx, dz), []):
						if other != id and points[id].distance_to(points[other]) < JOIN:
							_link(id, other)
	_cells.clear()


## A soft thing: a place on its top that nothing stands on (a rug's middle
## may have a table on it), and a way to it from the lanes: straight on when
## it is flat on the floor, by a hop up from beside it when it is raised (a
## cushion, a bedroll on a bed).
func _spot(space: PhysicsDirectSpaceState3D, thing: Node3D) -> void:
	var found: Variant = _box_of(thing)
	if found == null:
		return
	var box: AABB = found
	var top: float = box.end.y
	var s := Vector3.INF
	for off: Vector2 in [Vector2.ZERO, Vector2(0.3, 0.3), Vector2(-0.3, -0.3), Vector2(0.3, -0.3), Vector2(-0.3, 0.3)]:
		var c := Vector3(box.get_center().x + off.x * box.size.x, top, box.get_center().z + off.y * box.size.z)
		var hit: Variant = _floor(space, _q, c, 1.2)
		if hit == null or (hit as Vector3).y > top + 0.08 or top - (hit as Vector3).y > 0.7 or _in_water(hit as Vector3, _bodies):
			continue     # something stands here, or this isn't its top
		s = Vector3(c.x, top, c.z)
		break
	if s != Vector3.INF:
		soft_found += 1
	if s == Vector3.INF:
		return
	for id: int in spots:
		if points[id].distance_to(s) < 0.8:
			return
	# The floor beside it, the nearest of eight ways round.
	var feet: Array[Vector3] = []
	for k: int in 8:
		var dir := Vector3(cos(k * TAU / 8.0), 0, sin(k * TAU / 8.0))
		var out: float = minf(absf(box.size.x * 0.5 / maxf(absf(dir.x), 0.01)), absf(box.size.z * 0.5 / maxf(absf(dir.z), 0.01))) + 0.3
		var p := Vector3(box.get_center().x, top, box.get_center().z) + dir * out
		var hit: Variant = _floor(space, _q, Vector3(p.x, top - 0.3, p.z), 0.8)
		if hit != null and (hit as Vector3).y < top + 0.05 and not _in_water(hit as Vector3, _bodies):
			feet.append(hit as Vector3)
	if feet.is_empty():
		return
	var flat: bool = feet.all(func(f: Vector3) -> bool: return top - f.y < 0.12)
	if lane_points == 0:
		var id: int = _add(s)
		spots.append(id)
		if flat:
			_ring_from.append(id)
		else:
			var foot: int = _add(feet[0])
			_link(id, foot)
			_ring_from.append(foot)
		return
	# The nearest few lane points: joined to the first the way is clear to.
	var near: Array = []
	for i: int in lane_points:
		var d: float = points[i].distance_to(s)
		if d < SPOT_REACH and absf(points[i].y - s.y) < 0.7:
			near.append([d, i])
	near.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for e: Array in near.slice(0, 5):
		var lane: Vector3 = points[e[1]]
		if flat:
			if _clear(space, _q, Vector3(s.x, feet[0].y, s.z), lane):
				var id: int = _add(s)
				_link(id, e[1])
				spots.append(id)
				return
			continue
		feet.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.distance_to(lane) < b.distance_to(lane))
		for f: Vector3 in feet.slice(0, 3):
			if _clear(space, _q, f, lane):
				var id: int = _add(s)
				var foot: int = _add(f)
				_link(id, foot)
				_link(foot, e[1])
				spots.append(id)
				return


## No lanes: a few points round each rest spot where the floor is clear, and
## the rest spots joined through them.
func _rings(space: PhysicsDirectSpaceState3D) -> void:
	var ring: Array[int] = []
	for s: int in _ring_from:
		for k: int in RING_WAYS:
			var dir := Vector3(cos(k * TAU / RING_WAYS), 0, sin(k * TAU / RING_WAYS))
			var from: int = s
			for r: int in 2:
				var hit: Variant = _floor(space, _q, points[from] + dir * RING, 0.6)
				if hit == null or _in_water(hit as Vector3, _bodies) or not _clear(space, _q, points[from], hit as Vector3):
					break
				var id: int = _add(hit as Vector3)
				_link(from, id)
				ring.append(id)
				from = id
	for i: int in ring.size():
		for k: int in range(i + 1, ring.size()):
			var a: Vector3 = points[ring[i]]
			var b: Vector3 = points[ring[k]]
			if a.distance_to(b) < RING * 1.2 and not links[ring[i]].has(ring[k]) and _clear(space, _q, a, b):
				_link(ring[i], ring[k])


## The biggest joined-up part of the graph is where the animals live (a
## quarter's alleys and courts, not a room behind a shut door): the soft
## places in it are its rest spots; with fewer than NOOKS_UNDER of those,
## corners and dead ends (a doorstep, the foot of a wall) are rest spots too.
func _home() -> void:
	var part := PackedInt32Array()
	part.resize(points.size())
	part.fill(-1)
	var best: int = -1
	var best_n: int = 0
	for i: int in points.size():
		if part[i] >= 0:
			continue
		var n: int = 0
		var front := PackedInt32Array([i])
		part[i] = i
		while not front.is_empty():
			var next := PackedInt32Array()
			for a: int in front:
				n += 1
				for b: int in links[a]:
					if part[b] < 0:
						part[b] = i
						next.append(b)
			front = next
		if n > best_n:
			best_n = n
			best = i
	for i: int in points.size():
		if part[i] == best:
			home.append(i)
	var kept := PackedInt32Array()
	for s: int in spots:
		if part[s] == best:
			kept.append(s)
	spots = kept
	if spots.size() >= NOOKS_UNDER:
		return
	var stride: int = maxi(1, home.size() / 97)
	for k: int in range(0, home.size(), stride):
		if spots.size() >= NOOKS_UNDER + 3:
			break
		var i: int = home[k]
		if links[i].size() > 2:
			continue
		var apart: bool = true
		for s: int in spots:
			if points[s].distance_to(points[i]) < NOOK_APART:
				apart = false
				break
		if apart:
			spots.append(i)


## The fish, from the nearest point to each water; a place at its edge is made
## when no point is near enough.
func _watch(space: PhysicsDirectSpaceState3D) -> void:
	for b: WaterBody in _bodies:
		var box: AABB = b.bounds
		var best: int = -1
		var best_d: float = EDGE_REACH
		for i: int in home:
			var p: Vector3 = points[i]
			var d: float = Vector2(p.x, p.z).distance_to(Vector2(clampf(p.x, box.position.x, box.end.x), clampf(p.z, box.position.z, box.end.z)))
			if d > 0.3 and d < best_d and absf(p.y - b.surface) < 1.2:
				best_d = d
				best = i
		if best < 0:
			continue
		if best_d > WATCH_REACH:
			var p: Vector3 = points[best]
			var edge := Vector3(clampf(p.x, box.position.x, box.end.x), p.y, clampf(p.z, box.position.z, box.end.z))
			var hit: Variant = _floor(space, _q, edge + (p - edge).normalized() * 0.55, 0.6)
			if hit == null or _in_water(hit as Vector3, _bodies) or not _clear(space, _q, p, hit as Vector3):
				continue
			var id: int = _add(hit as Vector3)
			_link(best, id)
			best = id
			home.append(id)
		watch.append({"node": best, "at": box.get_center()})


func _add(p: Vector3) -> int:
	points.append(p)
	links.append(PackedInt32Array())
	return points.size() - 1


func _link(a: int, b: int) -> void:
	if a == b or links[a].has(b):
		return
	links[a].append(b)
	links[b].append(a)


## The point nearest `p` within `reach_m` among the first `count` (-1: all), or -1.
func nearest(p: Vector3, reach_m: float = INF, count: int = -1) -> int:
	var best: int = -1
	var best_d: float = reach_m
	for i: int in (points.size() if count < 0 else count):
		var d: float = points[i].distance_to(p)
		if d < best_d:
			best_d = d
			best = i
	return best


## Each point's step back toward `from` (-1: not reached within `hops`).
func reach(from: int, hops: int = 100000) -> PackedInt32Array:
	var back := PackedInt32Array()
	back.resize(points.size())
	back.fill(-1)
	back[from] = from
	var front := PackedInt32Array([from])
	var depth: int = 0
	while not front.is_empty() and depth < hops:
		var next := PackedInt32Array()
		for i: int in front:
			for k: int in links[i]:
				if back[k] < 0:
					back[k] = i
					next.append(k)
		front = next
		depth += 1
	return back


## The way from `from` to `to` (both ends included), empty when there is none.
func path(from: int, to: int, back: PackedInt32Array = PackedInt32Array()) -> PackedInt32Array:
	if back.is_empty():
		back = reach(from)
	if to < 0 or to >= back.size() or back[to] < 0:
		return PackedInt32Array()
	var out := PackedInt32Array([to])
	var at: int = to
	while at != from:
		at = back[at]
		out.append(at)
	out.reverse()
	return out


static func _floor(space: PhysicsDirectSpaceState3D, q: PhysicsRayQueryParameters3D, p: Vector3, reach_m: float) -> Variant:
	q.from = p + Vector3(0, reach_m, 0)
	q.to = p - Vector3(0, reach_m, 0)
	var hit: Dictionary = space.intersect_ray(q)
	if hit.is_empty() or (hit["normal"] as Vector3).y < 0.7:
		return null
	return hit["position"]


static func _clear(space: PhysicsDirectSpaceState3D, q: PhysicsRayQueryParameters3D, a: Vector3, b: Vector3) -> bool:
	var up := Vector3(0, BODY_HEIGHT, 0)
	q.from = a + up
	q.to = b + up
	if not space.intersect_ray(q).is_empty():
		return false
	# Floor all the way (no gap, no drop).
	var n: int = maxi(1, ceili(a.distance_to(b) / STEP))
	for i: int in range(1, n):
		var p: Vector3 = a.lerp(b, float(i) / n)
		var hit: Variant = _floor(space, q, p, 0.6)
		if hit == null or absf((hit as Vector3).y - p.y) > 0.25:
			return false
	return true


static func _in_water(p: Vector3, bodies: Array) -> bool:
	for b: WaterBody in bodies:
		if p.y < b.surface and b.bounds.grow(0.1).has_point(Vector3(p.x, b.bounds.get_center().y, p.z)) and b.contains_xz(Vector2(p.x, p.z)):
			return true
	return false


## A thing's box (global), from its first mesh; null without one, or too big.
static func _box_of(n: Node3D) -> Variant:
	var mi: MeshInstance3D = n as MeshInstance3D
	if mi == null:
		var found: Array[Node] = n.find_children("*", "MeshInstance3D", true, false)
		mi = found[0] as MeshInstance3D if not found.is_empty() else null
	if mi == null or mi.mesh == null or not mi.is_visible_in_tree():
		return null
	var box: AABB = mi.global_transform * mi.get_aabb()
	if box.size.x > 9.0 or box.size.z > 9.0:
		return null     # a whole floor's carpet: no one place on it
	return box

class_name WalkMap
extends RefCounted
## Where people can walk (phase 21 step 3, Q5): a walking surface made for each
## room when it is built, from the room's own floors, walls and furniture. One
## WalkMap serves an area; each room is a region of it.
##
## Making a room's surface has two halves: reading the room's collision shapes
## (on the main thread, a few ms) and the bake (on another thread). `add_room`
## does the first and starts the second; `ready_for(room)` says when it is in.
## Doors are left out of the reading, so a doorway is a way through: whoever
## walks it opens the door (Residents).
##
## The surface is for a person: 0.25 m wide of the walls, 1.75 m of headroom,
## a step of 0.25 m.

const CELL: float = 0.125
const RADIUS: float = 0.25
const HEIGHT: float = 1.75
const CLIMB: float = 0.25
## The floors, walls and furniture a person can't walk through.
const SOLID: int = 1 | (1 << 8) | WorldProp.LAYER_PROPS

var map: RID
## What the last room cost: reading its shapes (main thread), and the bake
## (another thread; the time until it came back).
var last_read_ms: float = 0.0
var last_bake_ms: float = 0.0
var _bake_from: int = 0
## room (instance id) -> {region: RID, mesh: NavigationMesh, done: bool, room}
var _rooms: Dictionary = {}


func _init() -> void:
	map = NavigationServer3D.map_create()
	NavigationServer3D.map_set_cell_size(map, CELL)
	NavigationServer3D.map_set_cell_height(map, CELL)
	NavigationServer3D.map_set_up(map, Vector3.UP)
	NavigationServer3D.map_set_active(map, true)


## Frees the server's map and regions (the area is leaving).
func close() -> void:
	for id: int in _rooms:
		NavigationServer3D.free_rid(_rooms[id]["region"])
	_rooms.clear()
	if map.is_valid():
		NavigationServer3D.free_rid(map)
		map = RID()


## Starts a room's surface. `probe`: a place on the room's floor (global), to
## tell when the surface is in. `leave_out`: bodies that are not in the way
## (doors).
func add_room(room: Node3D, probe: Vector3, leave_out: Array = []) -> void:
	var id: int = room.get_instance_id()
	if _rooms.has(id):
		return
	var nm := NavigationMesh.new()
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = SOLID
	nm.cell_size = CELL
	nm.cell_height = CELL
	nm.agent_radius = RADIUS
	nm.agent_height = HEIGHT
	nm.agent_max_climb = CLIMB
	nm.agent_max_slope = 40.0
	var layers: Array[int] = []
	for b: Variant in leave_out:
		layers.append((b as CollisionObject3D).collision_layer)
		(b as CollisionObject3D).collision_layer = 0
	var src := NavigationMeshSourceGeometryData3D.new()
	var t0: int = Time.get_ticks_usec()
	NavigationServer3D.parse_source_geometry_data(nm, src, room)
	last_read_ms = (Time.get_ticks_usec() - t0) / 1000.0
	_bake_from = Time.get_ticks_usec()
	for i: int in leave_out.size():
		(leave_out[i] as CollisionObject3D).collision_layer = layers[i]
	var entry: Dictionary = {"region": RID(), "mesh": nm, "done": false, "room": room, "probe": probe}
	_rooms[id] = entry
	NavigationServer3D.bake_from_source_geometry_data_async(nm, src, _baked.bind(id))


func _baked(id: int) -> void:
	if not _rooms.has(id) or not map.is_valid():
		return
	var entry: Dictionary = _rooms[id]
	var room: Node3D = entry["room"] as Node3D
	if not is_instance_valid(room) or not room.is_inside_tree():
		_rooms.erase(id)
		return
	last_bake_ms = (Time.get_ticks_usec() - _bake_from) / 1000.0
	var region: RID = NavigationServer3D.region_create()
	NavigationServer3D.region_set_transform(region, room.global_transform)
	NavigationServer3D.region_set_navigation_mesh(region, entry["mesh"])
	NavigationServer3D.region_set_map(region, map)
	entry["region"] = region
	entry["done"] = true


## Whether the room's surface is made and the server has taken it in (it does
## that in its own time, a frame or two after the bake).
func ready_for(room: Node3D) -> bool:
	var entry: Variant = _rooms.get(room.get_instance_id())
	if entry == null or not bool((entry as Dictionary)["done"]):
		return false
	# Taken in: a place known to be floor is found on the surface.
	var probe: Vector3 = (entry as Dictionary)["probe"]
	var found: Vector3 = nearest(probe)
	return Vector2(found.x - probe.x, found.z - probe.z).length() < 1.5 and absf(found.y - probe.y) < 1.0


## Forgets rooms that have gone.
func tidy() -> void:
	for id: int in _rooms.keys():
		if not is_instance_valid(_rooms[id]["room"]):
			if (_rooms[id]["region"] as RID).is_valid():
				NavigationServer3D.free_rid(_rooms[id]["region"])
			_rooms.erase(id)


## The way from a to b along the floor. If b can't be walked to, the way ends
## at the nearest place that can. Empty if a isn't on a surface at all.
func path(a: Vector3, b: Vector3) -> PackedVector3Array:
	return NavigationServer3D.map_get_path(map, a, b, true)


## The walkable point nearest to p.
func nearest(p: Vector3) -> Vector3:
	return NavigationServer3D.map_get_closest_point(map, p)


## Whether p (at any height near the floor) is on the surface, within `slack`.
func on(p: Vector3, slack: float = 0.12) -> bool:
	var q: Vector3 = nearest(p)
	return Vector2(q.x - p.x, q.z - p.z).length() <= slack and absf(q.y - p.y) < 0.6


## The surface's edges, for the overlay: pairs of points (global).
func outline(room: Node3D) -> PackedVector3Array:
	var out := PackedVector3Array()
	var entry: Variant = _rooms.get(room.get_instance_id())
	if entry == null or not bool((entry as Dictionary)["done"]):
		return out
	var nm: NavigationMesh = (entry as Dictionary)["mesh"]
	var verts: PackedVector3Array = nm.get_vertices()
	var xf: Transform3D = room.global_transform
	# An edge used by one polygon only is the surface's rim.
	var count: Dictionary = {}
	for p: int in nm.get_polygon_count():
		var poly: PackedInt32Array = nm.get_polygon(p)
		for k: int in poly.size():
			var i: int = poly[k]
			var j: int = poly[(k + 1) % poly.size()]
			var key := Vector2i(mini(i, j), maxi(i, j))
			count[key] = int(count.get(key, 0)) + 1
	for key: Vector2i in count:
		if count[key] == 1:
			out.append(xf * verts[key.x])
			out.append(xf * verts[key.y])
	return out


## How far it is to walk from a to b; INF if b can't be walked to from a.
func walk_length(a: Vector3, b: Vector3) -> float:
	var p: PackedVector3Array = path(a, b)
	if p.is_empty():
		return INF
	var last: Vector3 = p[p.size() - 1]
	if Vector2(last.x - b.x, last.z - b.z).length() > 0.3:
		return INF
	var total: float = 0.0
	for i: int in range(1, p.size()):
		total += p[i - 1].distance_to(p[i])
	return total


## The floor to stand on to get at `spot` (a seat, a bed in a niche, a place
## behind a counter), for someone who lives at `home` (a point on the floor):
## near the spot, and not the other side of a wall from it. The nearest point
## of the surface alone won't do: behind a bed's wall there is often ground.
func approach(spot: Vector3, home: Vector3) -> Vector3:
	var best: Vector3 = home
	var best_cost: float = INF
	for r: float in [0.0, 0.3, 0.6, 0.9, 1.3, 1.8]:
		for k: int in (1 if r == 0.0 else 8):
			var a: float = k * PI * 0.25
			var c: Vector3 = nearest(Vector3(spot.x + sin(a) * r, home.y, spot.z + cos(a) * r))
			var near: float = Vector2(c.x - spot.x, c.z - spot.z).length()
			if near >= best_cost:
				continue
			# A long way round to somewhere close by is the far side of a wall.
			var walk: float = walk_length(home, c)
			var cost: float = near + maxf(0.0, walk - home.distance_to(c) * 1.6 - 4.0)
			if cost < best_cost:
				best_cost = cost
				best = c
		if best_cost < r + 0.3:
			break
	return best

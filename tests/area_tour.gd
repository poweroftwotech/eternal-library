class_name AreaTour
extends RefCounted
## The walking route the area GPU tests share (area_walk_capture,
## area_pop_capture): from R01's hall out to every leaf room's far end and
## back, as floor points (cell centres, y 0), plus R01's door spots.

const STARTS: Dictionary = {
	&"SNAP_door_west": Vector3(1.5, 0.0, -6),
	&"SNAP_door_east": Vector3(10.5, 0.0, -6),
	&"SNAP_entrance": Vector3(6, 0.0, -1.5),
}


static func length(path: Array[Vector3]) -> float:
	var total: float = 0.0
	for i: int in path.size() - 1:
		total += path[i].distance_to(path[i + 1])
	return total


## Floor points from R01's hall out to every leaf's far end and back (cell
## centres; R01's door spots as in area_route_test).
static func tour(p: AreaPlan) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for r: AreaPlan.Room in p.rooms:
		if r.parent == "" or r.children_count() > 0:
			continue
		var there: Array[Vector3] = leg(p, r)
		var back: Array[Vector3] = there.duplicate()
		back.reverse()
		out.append_array(there + back)
	return out


## Floor points from R01's door spot to room `r`'s far end (the root room: just
## R01's west door spot).
static func leg(p: AreaPlan, r: AreaPlan.Room) -> Array[Vector3]:
	var chain: Array[AreaPlan.Room] = []
	var at: AreaPlan.Room = r
	while at.parent != "":
		chain.push_front(at)
		at = p.room(at.parent)
	if chain.is_empty():
		return [STARTS[&"SNAP_door_west"]]
	var out: Array[Vector3] = [STARTS[chain[0].parent_connector]]
	for i: int in chain.size():
		var room: AreaPlan.Room = chain[i]
		var in_xf: Transform3D = room.connectors[room.entry]["xf"]
		var from: Vector3i = AreaPlan.cell_of(in_xf.origin + in_xf.basis.z * 2.0)
		var goal: Vector3i = Vector3i.MAX
		if i + 1 < chain.size():
			var out_xf: Transform3D = room.connectors[chain[i + 1].parent_connector]["xf"]
			goal = AreaPlan.cell_of(out_xf.origin + out_xf.basis.z * 2.0)
		for c: Vector3i in cell_path(room, from, goal):
			out.append(AreaPlan.cell_box(c).get_center() * Vector3(1, 0, 1))
	return out


## Floor points from room `a`'s far end to room `b`'s, by way of R01's hall.
static func between(p: AreaPlan, a: AreaPlan.Room, b: AreaPlan.Room) -> Array[Vector3]:
	var out: Array[Vector3] = leg(p, a)
	out.reverse()
	out.append_array(leg(p, b))
	return out


static func cell_path(r: AreaPlan.Room, from: Vector3i, to: Vector3i) -> Array[Vector3i]:
	var parent: Dictionary = {from: from}
	var order: Array[Vector3i] = [from]
	var head: int = 0
	while head < order.size():
		var c: Vector3i = order[head]
		head += 1
		for side: int in CellGrid.ALL_SIDES:
			var n: Vector3i = CellGrid.neighbour(c, side)
			if parent.has(n) or not r.floor_cells.has(n) or not r.sight.has(CellGrid.key(c, side)):
				continue
			parent[n] = c
			order.append(n)
	var goal: Vector3i = to if to != Vector3i.MAX else order[-1]
	if not parent.has(goal):
		return [from]
	var out: Array[Vector3i] = []
	var c: Vector3i = goal
	while c != from:
		out.push_front(c)
		c = parent[c]
	out.push_front(from)
	return out

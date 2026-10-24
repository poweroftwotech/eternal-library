class_name AreaTour
extends RefCounted
## The walking routes the area tests share (stream_test, area_walk_capture,
## area_pop_capture, persist_test): from the root room out to every leaf
## room's far end and back, as floor points (cell centres, y 0, area frame).
## The root is R01 (its door spots) or a generated room (from its first bay,
## through its bays to the door); walks go round a room's blocked bays (a
## hall's bookcases and rubble heaps, phase 5).

## R01's door spots, by the connector a room joins it at.
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


## Floor points from the root out to every leaf's far end and back.
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


## Where a walk starts in the root room: R01's west door spot, or a generated
## root's first bay (the game's spawn).
static func start(p: AreaPlan) -> Vector3:
	var root_room: AreaPlan.Room = p.rooms[0]
	if root_room.kind != "generated":
		return STARTS[&"SNAP_door_west"]
	return _centre(AreaPlan.cell_of(root_room.xf * CellGrid.cell_centre(Vector3i.ZERO)))


## Floor points from the root's start to room `r`'s far end (the root room:
## just the start).
static func leg(p: AreaPlan, r: AreaPlan.Room) -> Array[Vector3]:
	var chain: Array[AreaPlan.Room] = []
	var at: AreaPlan.Room = r
	while at.parent != "":
		chain.push_front(at)
		at = p.room(at.parent)
	if chain.is_empty():
		return [start(p)]
	var out: Array[Vector3] = []
	if at.kind == "generated":
		var first_xf: Transform3D = chain[0].connectors[chain[0].entry]["xf"]
		var door: Vector3i = AreaPlan.cell_of(first_xf.origin - first_xf.basis.z * 2.0)
		for c: Vector3i in cell_path(at, AreaPlan.cell_of(start(p)), door):
			out.append(_centre(c))
	else:
		out.append(STARTS[chain[0].parent_connector])
	for i: int in chain.size():
		var room: AreaPlan.Room = chain[i]
		if room.grid != null and room.grid.meta.get("ring", false):
			# A light-well: round the gallery and up (or down) the stair to the
			# next room's door, or to the top of the stair (phase 5 step 4).
			var to: Array = ring_door(room, chain[i + 1].parent_connector) if i + 1 < chain.size() else []
			for q: Vector3 in RingGrammar.route(room.grid.meta, [0, CellGrid.Side.S], to):
				out.append(room.xf * q)
			continue
		var in_xf: Transform3D = room.connectors[room.entry]["xf"]
		var from: Vector3i = AreaPlan.cell_of(in_xf.origin + in_xf.basis.z * 2.0)
		var goal: Vector3i = Vector3i.MAX
		if i + 1 < chain.size():
			var out_xf: Transform3D = room.connectors[chain[i + 1].parent_connector]["xf"]
			goal = AreaPlan.cell_of(out_xf.origin + out_xf.basis.z * 2.0)
		for c: Vector3i in cell_path(room, from, goal):
			out.append(_centre(c))
	return out


## Floor points from room `a`'s far end to room `b`'s, by way of the root.
static func between(p: AreaPlan, a: AreaPlan.Room, b: AreaPlan.Room) -> Array[Vector3]:
	var out: Array[Vector3] = leg(p, a)
	out.reverse()
	out.append_array(leg(p, b))
	return out


## Cells from `from` to `to` (Vector3i.MAX: the farthest cell) through the
## room's open edges, round its blocked cells (breadth first).
static func cell_path(r: AreaPlan.Room, from: Vector3i, to: Vector3i) -> Array[Vector3i]:
	var parent: Dictionary = {from: from}
	var order: Array[Vector3i] = [from]
	var head: int = 0
	while head < order.size():
		var c: Vector3i = order[head]
		head += 1
		for side: int in CellGrid.ALL_SIDES:
			var n: Vector3i = CellGrid.neighbour(c, side)
			if parent.has(n) or not r.floor_cells.has(n) or r.blocked_cells.has(n) or not r.sight.has(CellGrid.key(c, side)):
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


## The [level, side] of a light-well's door that connector `conn` is.
static func ring_door(r: AreaPlan.Room, conn: StringName) -> Array:
	var meta: Dictionary = r.grid.meta
	var across: int = meta["across"]
	for d: Array in meta["doors"]:
		var c: Vector3i = RingGrammar.door_cell(d[1], d[0], across / 2, across)
		if StringName("SNAP_exit_" + CellGrid.key(c, d[1])) == conn:
			return d
	return []


## A cell's centre on its storey's floor (y: the storey's height).
static func _centre(c: Vector3i) -> Vector3:
	var at: Vector3 = AreaPlan.cell_box(c).get_center()
	return Vector3(at.x, c.y * AreaPlan.BAY, at.z)

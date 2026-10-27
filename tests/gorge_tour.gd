class_name GorgeTour
extends RefCounted
## The Gorge's walking route for the frame gate and tests (phase 6 step 4):
## AreaTour's grid paths can't follow the Overlook's stair or the network's
## rooms, which are turned to the grid. From the balcony down the rock-cut
## stair to the Overlook ledge's corner (the route of tests/gorge_route_test.gd),
## then out along the network to every leaf ledge's far end and back, as feet
## points (area frame).

const FOREGROUND = preload("res://scripts/vista_foreground.gd")
const EYE: Vector3 = Vector3(-1, 2.25, -27.45)
const LANDING_HALF: float = 6.0
const ON_BAYS: int = 3


## The balcony to the Overlook ledge's corner bay (where the span leaves).
static func overlook_route() -> Array[Vector3]:
	var top: Vector3 = FOREGROUND.STAIR_TOP
	var landing: Vector3 = FOREGROUND.STAIR_LANDING
	var flat: Vector3 = Vector3(landing.x - top.x, 0, landing.z - top.z).normalized()
	# The landing and the walk beyond keep their own line (only the stair turned).
	var line: Vector3 = FOREGROUND.landing_flat()
	var land := Transform3D(Basis(Vector3.UP, atan2(line.x, line.z)), landing)
	var far_mid: Vector3 = land * Vector3(0, 0, LANDING_HALF)
	var g_basis := Basis(Vector3.UP.cross(-line).normalized(), Vector3.UP, -line)
	var g := Transform3D(g_basis, far_mid - g_basis.x * 2.0)
	var head_mid: Vector3 = Vector3(top.x, FOREGROUND.STAIR_FLOOR, top.z) - flat * FOREGROUND.STAIR_HEAD * .5
	var route: Array[Vector3] = [EYE, Vector3(head_mid.x, 2.2, -27.4), head_mid]
	for d: float in [2.0, 10.0, 20.0, 28.0]:
		route.append(top + flat * d)
	route.append(landing)
	route.append(land * Vector3(0, 0, LANDING_HALF - 1.0))
	route.append(far_mid + line * 4.0)
	for j: int in range(2, 2 + ON_BAYS):
		route.append(g * Vector3(2.0, -4.0, -j * 4.0 - 2.0))
	return route


## From the balcony to every leaf's far end and back.
static func tour(p: AreaPlan) -> Array[Vector3]:
	var start: Array[Vector3] = overlook_route()
	var out: Array[Vector3] = start.duplicate()
	for r: AreaPlan.Room in p.rooms:
		if r.parent == "" or r.children_count() > 0:
			continue
		var there: Array[Vector3] = leg(p, r)
		var back: Array[Vector3] = there.duplicate()
		back.reverse()
		out.append_array(there + back)
	return out


## From the Overlook's corner to room r's far end, room by room.
static func leg(p: AreaPlan, r: AreaPlan.Room) -> Array[Vector3]:
	var chain: Array[AreaPlan.Room] = []
	var at: AreaPlan.Room = r
	while at.parent != "":
		chain.push_front(at)
		at = p.room(at.parent)
	var out: Array[Vector3] = []
	for i: int in chain.size():
		var room: AreaPlan.Room = chain[i]
		var entry: Vector3 = (room.connectors[room.entry]["xf"] as Transform3D).origin
		var exit_xf: Transform3D = room.connectors[chain[i + 1].parent_connector]["xf"] if i + 1 < chain.size() else Transform3D()
		if room.kind == "ledge":
			# Along its middle from the way in to the way on (or its far end).
			var inv: Transform3D = room.xf.affine_inverse()
			var x_in: float = clampf((inv * entry).x, 1.2, room.span["bays"] * 4.0 - 1.2)
			var x_out: float
			if i + 1 < chain.size():
				x_out = clampf((inv * exit_xf.origin).x, 1.2, room.span["bays"] * 4.0 - 1.2)
			else:
				x_out = 1.2 if x_in > room.span["bays"] * 2.0 else room.span["bays"] * 4.0 - 1.2
			out.append(room.xf * Vector3(x_in, 0, -2.0))
			out.append(room.xf * Vector3(x_out, 0, -2.0))
		else:
			# A link's (or span's) walk and landings, from the end it's entered by.
			var pts: Array = (room.span["walk"] as Array).duplicate()
			pts.append_array(room.span.get("landings", []))
			pts.sort_custom(func(x: Vector3, y: Vector3) -> bool: return x.z > y.z)
			var world: Array[Vector3] = []
			for q: Vector3 in pts:
				world.append(room.xf * q)
			if not world.is_empty() and world[-1].distance_to(entry) < world[0].distance_to(entry):
				world.reverse()
			out.append_array(world)
	return out

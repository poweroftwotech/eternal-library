extends SceneTree
## Gate for a whole area built from its plan, everything loaded at once
## (phase-4-design.md 8.1.7, step 1).
##   godot --headless --path . --script res://tests/area_route_test.gd [-- seeds=N]
## For area seeds 1-5 of the library wing, streaming off: every planned room is built as a
## direct child of the Area; Validate Room is clean on every generated room
## and error-free on R01 and the baked gallery; every joint meets face to
## face; floor collision under every generated cell; every solid side and
## every unjoined exit blocks; and the real player's capsule (radius 0.35,
## height 1.8) walks from R01's hall out to every leaf room's far end and
## back, through every room on the way. Prints what each room cost to build
## (to size step 2) and the wear map's size and time.

const RECIPE: String = "res://gen/recipes/library_wing.tres"
const SEEDS: int = 5
## Audit walking speed: 0.13 m per physics step, well under the capsule radius.
const SPEED: float = 8.0
## Spots in R01's hall to walk from, per door (clear of the tables and stairs),
## as in r02_route_test.
const STARTS: Dictionary = {
	&"SNAP_door_west": Vector3(1.5, 0.95, -6),
	&"SNAP_door_east": Vector3(10.5, 0.95, -6),
	&"SNAP_entrance": Vector3(6, 0.95, -1.5),
}

var failures: PackedStringArray = []
var checks: int = 0


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures.append(what)


func run() -> void:
	var seeds: int = SEEDS
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("seeds="):
			seeds = a.trim_prefix("seeds=").to_int()
	save_format()
	for s: int in range(1, seeds + 1):
		await audit(s)
	print("area_route_test: %d checks, %d failures" % [checks, failures.size()])
	for f: String in failures:
		print("  FAIL ", f)
	quit(1 if not failures.is_empty() else 0)


## Save version 2 (8.1.6): a phase 3 (version 1) file still loads, with its
## changes in the library area and no area of its own to resume into.
func save_format() -> void:
	var ws: Node = root.get_node("/root/WorldState")
	var path: String = "user://test/v1_save.json"
	var v1: Dictionary = {"version": 1, "world_seed": 1, "clock_days": 0.0, "scene": "res://rooms/authored/reading_room.tscn",
		"player": {}, "gen_seed_override": -1, "inventory": {},
		"areas": {"library": {"deltas": {"reading_room@1/Dressing/vase": {"s": "moved"}}, "spawned": []}}}
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(v1))
	f.close()
	var old_path: String = ws.get("path")
	ws.set("path", path)
	var ok: bool = ws.call("load_save")
	var data: Dictionary = ws.get("data")
	check(ok and int(data["version"]) == 2 and str(data["area"]) == "" and str(data["scene"]).ends_with("reading_room.tscn"),
		"a version 1 save loads as version 2, in no area, with its scene (%s)" % [data.keys()])
	check(not (ws.call("delta", "reading_room@1/Dressing/vase") as Dictionary).is_empty(), "its R01 change is still there, under library")
	ws.set("path", old_path)
	ws.set("data", ws.call("blank"))


func audit(s: int) -> void:
	var tag: String = "area seed %d" % s
	Area.seed_override = s
	var area := Area.new()
	area.recipe = load(RECIPE)
	area.streaming = false     # step 1: every room at once
	root.add_child(area)
	await physics_frame
	await physics_frame
	var ws: Node = root.get_node("/root/WorldState")
	check(ws.get("area_id") == "library", "%s: rooms read and write the library area's changes" % tag)
	var p: AreaPlan = area.plan
	check(p.check().is_empty(), "%s: the plan checks clean (%s)" % [tag, p.check()])
	check(area.rooms.size() == p.rooms.size() and area.get_children().filter(func(n: Node) -> bool: return n is RoomTemplate).size() == p.rooms.size(),
		"%s: all %d planned rooms are built as the area's own children" % [tag, p.rooms.size()])
	report(area, tag)
	# Validate Room per room, and each joint face to face.
	for r: AreaPlan.Room in p.rooms:
		var room: RoomTemplate = area.rooms[r.slot_id]
		var v: Dictionary = KitValidateRoom.run(room)
		if r.kind == "generated":
			check((v["errors"] as PackedStringArray).is_empty() and (v["warnings"] as PackedStringArray).is_empty(),
				"%s: %s validates clean (%s)" % [tag, r.slot_id, v])
		else:
			check((v["errors"] as PackedStringArray).is_empty(), "%s: %s validates without errors (%s)" % [tag, r.slot_id, v["errors"]])
		check(room.room_key() == "%s@%d" % [r.slot_id, r.seed_value], "%s: %s has room key %s (%s)" % [tag, r.slot_id, "%s@%d" % [r.slot_id, r.seed_value], room.room_key()])
	for e: Dictionary in p.edges:
		var a: Node3D = area.rooms[e["a"]].get_node(NodePath("Connectors/" + String(e["a_conn"])))
		var b: Node3D = area.rooms[e["b"]].get_node(NodePath("Connectors/" + String(e["b_conn"])))
		check(a != null and b != null and a.global_position.distance_to(b.global_position) < 0.01 and a.global_basis.z.dot(b.global_basis.z) < -0.99,
			"%s: %s/%s meets %s/%s face to face" % [tag, e["a"], e["a_conn"], e["b"], e["b_conn"]])
	var intruders: PackedStringArray = recess_intruders(area)
	check(intruders.is_empty(), "%s: no room's geometry reaches into another room's shelf recesses (%s)" % [tag, intruders.slice(0, 6)])
	var space: PhysicsDirectSpaceState3D = area.get_world_3d().direct_space_state
	var body: CharacterBody3D = make_capsule(area)
	for r: AreaPlan.Room in p.rooms:
		if r.kind != "generated":
			continue
		var g: GeneratedRoom = area.rooms[r.slot_id]
		var floors: int = 0
		var leaks: PackedStringArray = []
		for cell: Vector3i in g.grid.cells:
			var c: Vector3 = g.to_global(CellGrid.cell_centre(cell))
			var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(c + Vector3(0, 0.5, 0), c - Vector3(0, 1, 0), 1))
			if not hit.is_empty() and absf((hit["position"] as Vector3).y) < 0.05:
				floors += 1
			for side: int in CellGrid.ALL_SIDES:
				var edge: Dictionary = g.grid.edge(cell, side)
				if edge.is_empty() or edge["host"]:
					continue
				var joined: bool = edge["mark"] == CellGrid.Mark.DOOR and str(r.connectors.get(StringName("SNAP_exit_" + CellGrid.key(cell, side)), {}).get("joined", "")) != ""
				if not (edge["mark"] == CellGrid.Mark.SOLID or (edge["mark"] == CellGrid.Mark.DOOR and not joined)):
					continue
				var out: Vector3 = g.global_basis * (Vector3(CellGrid.neighbour(cell, side) - cell) * Vector3(1, 0, -1))
				if not await blocked(body, c + Vector3(0, 0.95, 0), out * 3.0):
					leaks.append("%s %s" % [cell, CellGrid.SIDE_NAMES[side]])
		check(floors == g.grid.cells.size(), "%s: %s has floor under all %d cells (%d)" % [tag, r.slot_id, g.grid.cells.size(), floors])
		check(leaks.is_empty(), "%s: %s: every solid side and unjoined exit blocks (%s)" % [tag, r.slot_id, leaks])
	# The baked gallery's own exit: blocked unless a room joined it.
	for r: AreaPlan.Room in p.rooms:
		if r.kind != "scene":
			continue
		for name: StringName in r.connectors:
			if not String(name).begins_with("SNAP_exit") or str(r.connectors[name]["joined"]) != "":
				continue
			var xf: Transform3D = r.connectors[name]["xf"]
			var inside: Vector3 = xf.origin + xf.basis.z * 2.0 + Vector3(0, 0.95, 0)
			check(await blocked(body, inside, -xf.basis.z * 3.0), "%s: %s's unjoined %s blocks" % [tag, r.slot_id, name])
	# Walk from R01's hall to every leaf's far end and back.
	var walked: Dictionary = {}
	for r: AreaPlan.Room in p.rooms:
		if r.children_count() > 0 or r.parent == "":
			continue
		var chain: Array[AreaPlan.Room] = []
		var at: AreaPlan.Room = r
		while at.parent != "":
			chain.push_front(at)
			at = p.room(at.parent)
		var start: Vector3 = STARTS[chain[0].parent_connector]
		var route: Array[Vector3] = route_through(p, chain)
		body.global_position = start
		await physics_frame
		var reached: int = await follow(body, route)
		var feet_out: float = body.global_position.y - 0.9
		var back: Array[Vector3] = route.duplicate()
		back.reverse()
		back.append(start)
		var returned: int = await follow(body, back)
		var feet: float = body.global_position.y - 0.9
		var names: PackedStringArray = []
		for c: AreaPlan.Room in chain:
			names.append(c.slot_id)
			walked[c.slot_id] = true
		check(reached == route.size() and returned == back.size() and absf(feet_out) < 0.1 and absf(feet) < 0.1,
			"%s: walk from R01 through %s to the far end and back (%d of %d stops out, %d of %d back, feet %.2f / %.2f)" % [tag, " > ".join(names), reached, route.size(), returned, back.size(), feet_out, feet])
	check(walked.size() == p.rooms.size() - 1, "%s: the walks pass through every room but R01 (%d of %d)" % [tag, walked.size(), p.rooms.size() - 1])
	body.queue_free()
	area.queue_free()
	await process_frame
	await process_frame


## Cell centres (world, y 0) from R01's door through each room of `chain`, to
## the last room's farthest cell.
func route_through(p: AreaPlan, chain: Array[AreaPlan.Room]) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for i: int in chain.size():
		var r: AreaPlan.Room = chain[i]
		var in_xf: Transform3D = r.connectors[r.entry]["xf"]
		var entry_cell: Vector3i = AreaPlan.cell_of(in_xf.origin + in_xf.basis.z * 2.0)
		var goal: Vector3i = Vector3i.MAX
		if i + 1 < chain.size():
			var next: AreaPlan.Room = chain[i + 1]
			var out_xf: Transform3D = r.connectors[next.parent_connector]["xf"]
			goal = AreaPlan.cell_of(out_xf.origin + out_xf.basis.z * 2.0)
		for c: Vector3i in cell_path(r, entry_cell, goal):
			out.append(AreaPlan.cell_box(c).get_center() * Vector3(1, 0, 1))
	return out


## Cells from `from` to `to` through `r`'s floor (open edges of a generated
## room, any neighbour in a scene room); to = MAX: to the farthest cell.
func cell_path(r: AreaPlan.Room, from: Vector3i, to: Vector3i) -> Array[Vector3i]:
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
	var out: Array[Vector3i] = []
	if not parent.has(goal):
		push_warning("area_route_test: %s has no path from %s to %s" % [r.slot_id, from, goal])
		return [from]
	var c: Vector3i = goal
	while c != from:
		out.push_front(c)
		c = parent[c]
	out.push_front(from)
	return out


## What building cost, per room and in all (sizes step 2's budget).
## Recess bays (Area._clear_recesses keeps them clear) whose cavity
## (0.25 m past the wall line; the 3 m arch as two boxes: full width up to the
## spring at 1.9 m, the middle 1.2 m up to 3.3 m) another room's meshes reach
## into: what the gallery vaults did through R01's upper recesses over its
## doors. Mesh bounds, so it can over-report.
const RECESS_CAVITY: Array[AABB] = [AABB(Vector3(0.6, 0.2, 0.02), Vector3(2.8, 1.7, 0.23)), AABB(Vector3(1.4, 0.2, 0.02), Vector3(1.2, 3.1, 0.23))]
func recess_intruders(area: Area) -> PackedStringArray:
	var out: PackedStringArray = []
	for slot: String in area.rooms:
		var room: RoomTemplate = area.rooms[slot]
		for n: Node in room.find_children("*", "KitModule", true, false):
			var m := n as KitModule
			if m.edge != "recess":
				continue
			for other_slot: String in area.rooms:
				if other_slot == slot:
					continue
				for g: Node in (area.rooms[other_slot] as Node).find_children("*", "MeshInstance3D", true, false):
					var mi := g as MeshInstance3D
					if mi.mesh == null or not mi.is_visible_in_tree():
						continue
					var bounds: AABB = mi.global_transform * mi.get_aabb()
					if RECESS_CAVITY.any(func(c: AABB) -> bool: return (m.global_transform * c).intersects(bounds)):
						out.append("%s/%s ← %s/%s" % [slot, room.get_path_to(m), other_slot, (area.rooms[other_slot] as Node).get_path_to(mi)])
	return out


func report(area: Area, tag: String) -> void:
	var t: Dictionary = area.timings
	var lines: PackedStringArray = []
	var worst: float = 0.0
	for slot: String in t["rooms"]:
		var r: Dictionary = t["rooms"][slot]
		lines.append("%s %s %.0f+%.0f ms" % [slot, r["kind"], r["instance_ms"], r["enter_ms"]])
		worst = maxf(worst, r["instance_ms"] + r["enter_ms"])
	print("  %s: %d rooms; plan %.0f ms, wear map %s m in %.0f ms, all in %.0f ms; slowest room %.0f ms" % [tag, area.plan.rooms.size(),
		t["plan_ms"], FloorWear.map_rect.size, t["wear_ms"], t["total_ms"], worst])
	print("    " + ", ".join(lines))


## Steers the capsule (move_and_slide with gravity) through each point in
## turn; returns how many it reached (within 0.3 m in plan), giving up on one
## after 6 s.
func follow(body: CharacterBody3D, points: Array[Vector3]) -> int:
	var reached: int = 0
	for target: Vector3 in points:
		var ok: bool = false
		for _i: int in 360:
			var to: Vector3 = target - body.global_position
			to.y = 0.0
			if to.length() < 0.3:
				ok = true
				break
			var v: Vector3 = to.normalized() * minf(SPEED, to.length() * 30.0)
			body.velocity.x = v.x
			body.velocity.z = v.z
			body.velocity.y = 0.0 if body.is_on_floor() else body.velocity.y - 9.8 / 60.0
			body.move_and_slide()
			await physics_frame
		if not ok:
			break
		reached += 1
	return reached


func make_capsule(parent: Node) -> CharacterBody3D:
	var body := CharacterBody3D.new()
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	shape.shape = capsule
	body.add_child(shape)
	body.collision_mask = 1
	parent.add_child(body)
	return body


func blocked(body: CharacterBody3D, at: Vector3, motion: Vector3) -> bool:
	body.global_position = at
	await physics_frame
	var params := PhysicsTestMotionParameters3D.new()
	params.from = body.global_transform
	params.motion = motion
	return PhysicsServer3D.body_test_motion(body.get_rid(), params)

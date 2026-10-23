extends SceneTree
## Gate for a whole area built from its plan, everything loaded at once
## (phase-4-design.md 8.1.7, step 1).
##   godot --headless --path . --script res://tests/area_route_test.gd [-- seeds=N] [area=<id>]
## For area seeds 1-5 of the library wing and the Lower Stacks (phase 5),
## streaming off: every planned room is built as a
## direct child of the Area; Validate Room is clean on every generated room
## and error-free on R01 and the baked gallery; every joint meets face to
## face; floor collision under every generated cell; every solid side and
## every unjoined exit blocks; and the real player's capsule (radius 0.35,
## height 1.8) walks from the root room (AreaTour) out to every leaf room's far end and
## back, through every room on the way. Prints what each room cost to build
## (to size step 2) and the wear map's size and time.

## Both areas (phase-5-design.md 5.6.9); `area=<id>` runs one.
const RECIPES: Dictionary = {"library": "res://gen/recipes/library_wing.tres", "lower_stacks": "res://gen/recipes/lower_stacks.tres"}
const SEEDS: int = 5
## Audit walking speed: 0.13 m per physics step, well under the capsule radius.
const SPEED: float = 8.0

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
	var areas: Array = RECIPES.keys()
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("seeds="):
			seeds = a.trim_prefix("seeds=").to_int()
		elif a.begins_with("area="):
			areas = [a.trim_prefix("area=")]
	save_format()
	for id: String in areas:
		for s: int in range(1, seeds + 1):
			await audit(id, s)
	Area.seed_override = -1
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


func audit(id: String, s: int) -> void:
	var tag: String = "%s seed %d" % [id, s]
	Area.seed_override = s
	var area := Area.new()
	area.recipe = load(RECIPES[id])
	area.streaming = false     # step 1: every room at once
	root.add_child(area)
	await physics_frame
	await physics_frame
	var ws: Node = root.get_node("/root/WorldState")
	check(ws.get("area_id") == id, "%s: rooms read and write the %s area's changes" % [tag, id])
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
			# Down to the floor at its height (a cistern's water bays are lower), through
			# whatever stands on it (a hall's cases, heaps, landmark).
			var floor_y: float = float(g.grid.cells[cell].get("floor_y", 0.0))
			var ray := PhysicsRayQueryParameters3D.create(c + Vector3(0, 0.5, 0), c - Vector3(0, 2.5, 0), 1)
			for _try: int in 4:
				var hit: Dictionary = space.intersect_ray(ray)
				if hit.is_empty():
					break
				if absf((g.to_local(hit["position"]) as Vector3).y - floor_y) < 0.05:
					floors += 1
					break
				ray.exclude = ray.exclude + [hit["rid"]]
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
	# Walk from the root room to every leaf's far end and back (AreaTour).
	var walked: Dictionary = {}
	for r: AreaPlan.Room in p.rooms:
		if r.children_count() > 0 or r.parent == "":
			continue
		var chain: Array[AreaPlan.Room] = []
		var at: AreaPlan.Room = r
		while at.parent != "":
			chain.push_front(at)
			at = p.room(at.parent)
		var route: Array[Vector3] = AreaTour.leg(p, r)
		var start: Vector3 = route.pop_front() + Vector3(0, 0.95, 0)
		body.global_position = start
		await physics_frame
		var reached: int = await follow(body, route)
		for _i: int in 30:     # let it land (a walk may end down in a cistern's shallows)
			body.velocity = Vector3(0, -3.0, 0)
			body.move_and_slide()
			if body.is_on_floor():
				break
			await physics_frame
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
		# The far end may be in a cistern's shallows (its floor 0.9 m down).
		var end_floor: float = float(r.grid.cells.get(AreaPlan.cell_of(r.xf.affine_inverse() * (route[-1] + Vector3(0, 0.1, 0))) * Vector3i(1, 0, 1), {}).get("floor_y", 0.0)) if r.grid != null else 0.0
		check(reached == route.size() and returned == back.size() and absf(feet_out - end_floor) < 0.1 and absf(feet) < 0.1,
			"%s: walk from the root through %s to the far end and back (%d of %d stops out, %d of %d back, feet %.2f / %.2f, the end's floor %.2f)" % [tag, " > ".join(names), reached, route.size(), returned, back.size(), feet_out, feet, end_floor])
	check(walked.size() == p.rooms.size() - 1, "%s: the walks pass through every room but the root (%d of %d)" % [tag, walked.size(), p.rooms.size() - 1])
	body.queue_free()
	area.queue_free()
	await process_frame
	await process_frame


## What building cost, per room and in all (sizes step 2's budget).
## Recess bays (Area._clear_recesses keeps them clear) whose cavity
## (0.25 m past the wall line; the 3 m arch as two boxes: full width up to the
## spring at 1.9 m, the middle 1.2 m up to 3.3 m) another room's meshes reach
## into: what the gallery vaults did through R01's upper recesses over its
## doors. Mesh bounds pick the candidates; a mesh counts only if one of its
## vertices is inside the cavity (bounds alone over-reported a gallery fern
## behind a cistern wall, phase 5 step 3).
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
					if RECESS_CAVITY.any(func(c: AABB) -> bool: return (m.global_transform * c).intersects(bounds)) and _reaches_into(mi, m):
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


## True if a vertex of `mi` lies inside one of `m`'s recess cavity boxes.
func _reaches_into(mi: MeshInstance3D, m: Node3D) -> bool:
	var to_m: Transform3D = m.global_transform.affine_inverse() * mi.global_transform
	for s: int in mi.mesh.get_surface_count():
		var verts: PackedVector3Array = mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
		for v: Vector3 in verts:
			var p: Vector3 = to_m * v
			if RECESS_CAVITY.any(func(c: AABB) -> bool: return c.has_point(p)):
				return true
	return false

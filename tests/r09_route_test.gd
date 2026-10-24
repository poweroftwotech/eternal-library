extends SceneTree
## R09 route gate (phase-5-design.md 5.6.6; rev 2, the cone), headless:
##   godot --headless --path . --script res://tests/r09_route_test.gd [-- seeds=N]
## The Lower Stacks' light-well, seeds 1-6 (those with one), every room built
## at once. The validator is clean. The real player's capsule (radius 0.35,
## height 1.8) climbs from the entry up the whole
## stair to the top landing, its feet on the top floor, and back down; walks
## from the entry to every doorway, out through its passage, into the room
## beyond when one joined (feet on that storey) and back. From every step the
## parapet stops a walk into the shaft (but on the floor's first steps) and the
## wall a walk out (but at a doorway's landing); the stair's end on the top
## level and the pool's curb stop a walk on. Nothing on the stair holds the
## capsule back on its way up or down (your walk: it caught here and there).

const RECIPE: String = "res://gen/recipes/lower_stacks.tres"
const SEEDS: int = 6
const SPEED: float = 6.0

var failures: PackedStringArray = []
## Frames the capsule was held back mid-stretch (moving under half its speed
## more than 0.8 m from the next point): the stair catching it (follow()).
var snags: int = 0
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
	var walked: int = 0
	for s: int in range(1, seeds + 1):
		walked += 1 if await walk_seed(s) else 0
	Area.seed_override = -1
	check(walked >= seeds - 1, "most seeds have a light-well to walk (%d of %d)" % [walked, seeds])
	print("r09_route_test: %d checks, %d failures" % [checks, failures.size()])
	for f: String in failures.slice(0, 30):
		print("  FAIL ", f)
	quit(1 if not failures.is_empty() else 0)


func walk_seed(s: int) -> bool:
	var tag: String = "lower stacks %d" % s
	Area.seed_override = s
	var area := Area.new()
	area.recipe = load(RECIPE)
	area.streaming = false
	root.add_child(area)
	for _i: int in 4:
		await physics_frame
	var plan: AreaPlan.Room = area.plan.room("lightwell_1")
	if plan == null:
		print("  %s: no light-well" % tag)
		area.queue_free()
		await process_frame
		return false
	var room: GeneratedRoom = area.rooms[plan.slot_id]
	var m: Dictionary = plan.grid.meta
	var v: Dictionary = KitValidateRoom.run(room)
	check((v["errors"] as PackedStringArray).is_empty() and (v["warnings"] as PackedStringArray).is_empty(), "%s: the light-well validates clean (%s)" % [tag, v])
	var body: CharacterBody3D = make_capsule(area)
	var levels: int = m["levels"]
	var top: float = (levels - 1) * RingGrammar.STOREY
	# Up the whole stair and back down.
	var up: Array[Vector3] = []
	for p: Vector3 in RingGrammar.route(m, [0, CellGrid.Side.S], []):
		up.append(room.to_global(p))
	body.global_position = up[0] + Vector3(0, 0.95, 0)
	await physics_frame
	snags = 0
	var got: int = await follow(body, up)
	var feet: float = room.to_local(body.global_position).y - 0.9
	check(got == up.size() and absf(feet - top) < 0.15, "%s: the capsule climbs to the top level (%d of %d points, feet %.2f, top %.1f)" % [tag, got, up.size(), feet, top])
	var down: Array[Vector3] = up.duplicate()
	down.reverse()
	got = await follow(body, down)
	feet = room.to_local(body.global_position).y - 0.9
	check(got == down.size() and absf(feet) < 0.15, "%s: and back down to the floor (%d of %d, feet %.2f)" % [tag, got, down.size(), feet])
	check(snags == 0, "%s: nothing on the stair catches the capsule, up or down (%d frames held back)" % [tag, snags])
	# Up again hugging each edge of the walk: the guide wall inside, the back
	# wall (and the niches) outside.
	# (Four points a step, so the straight legs keep to the curve.)
	for lane: float in [-0.18, 0.2]:
		var hug: Array[Vector3] = []
		var centre_g: Vector3 = room.to_global(m["centre"])
		var stair: Array[Vector3] = up.slice(1)
		for i: int in stair.size():
			for k: int in (4 if i + 1 < stair.size() else 1):
				var p: Vector3 = stair[i].lerp(stair[i + 1], k / 4.0) if k > 0 else stair[i]
				var flat := Vector3(p.x - centre_g.x, 0, p.z - centre_g.z)
				var rad: float = lerpf(Vector2(stair[i].x - centre_g.x, stair[i].z - centre_g.z).length(),
					Vector2(stair[mini(i + 1, stair.size() - 1)].x - centre_g.x, stair[mini(i + 1, stair.size() - 1)].z - centre_g.z).length(), k / 4.0)
				hug.append(Vector3(centre_g.x, p.y, centre_g.z) + flat.normalized() * (rad + lane))
		body.global_position = hug[0] + Vector3(0, 0.95, 0)
		await physics_frame
		snags = 0
		got = await follow(body, hug)
		check(got == hug.size() and snags == 0, "%s: up the stair hugging its %s edge, nothing catches (%d of %d points, %d frames held back)" % [tag, "inner" if lane < 0.0 else "outer", got, hug.size(), snags])
	# Out of every doorway.
	var doors: Array = m["doors"]
	for d: Array in doors.slice(1):
		var way: Array[Vector3] = []
		for p: Vector3 in RingGrammar.route(m, [0, CellGrid.Side.S], d):
			way.append(room.to_global(p))
		var across: int = m["across"]
		var c: Vector3i = RingGrammar.door_cell(d[1], d[0], across / 2, across)
		var conn: StringName = StringName("SNAP_exit_" + CellGrid.key(c, d[1]))
		var joined: String = str(plan.connectors[conn]["joined"])
		var door_xf: Transform3D = plan.connectors[conn]["xf"]
		if joined != "":
			way.append(area.to_global(door_xf.origin - door_xf.basis.z * 2.5))
		body.global_position = way[0] + Vector3(0, 0.95, 0)
		await physics_frame
		got = await follow(body, way)
		feet = area.to_local(body.global_position).y - 0.9
		var level_y: float = plan.xf.origin.y + int(d[0]) * RingGrammar.STOREY
		check(got == way.size() and absf(feet - level_y) < 0.15, "%s: from the entry out of the door on level %d %s (%d of %d points, feet %.2f)" % [tag, d[0], "into " + joined.get_slice("/", 0) if joined != "" else "to its stub", got, way.size(), feet])
		var back: Array[Vector3] = way.duplicate()
		back.reverse()
		got = await follow(body, back)
		check(got == back.size(), "%s: and back to the entry (%d of %d)" % [tag, got, back.size()])
	# Rails: no walk into the shaft.
	var open_ways: PackedStringArray = await rails(body, room, m)
	check(open_ways.is_empty(), "%s: the parapet, the wall, the stair's end and the pool's curb hold (%s)" % [tag, open_ways.slice(0, 6)])
	print("  %s: r%d, %d levels, doors %s, %d points up" % [tag, m["radius"], levels, doors, up.size()])
	body.queue_free()
	area.queue_free()
	await process_frame
	await process_frame
	return true


func rails(body: CharacterBody3D, room: Node3D, m: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = []
	var centre: Vector3 = m["centre"]
	var r0: float = float(m["radius"])
	var levels: int = m["levels"]
	var door_levels: Dictionary = {}
	for d: Array in m["doors"]:
		door_levels[int(d[0])] = true
	# From every step: inward over the parapet, and outward into the wall.
	for j: int in levels:
		var r: float = r0 - 1.5 * j
		var c: Vector2 = RingGrammar.climb(r)
		var ts: Array[float] = [0.0]
		if j + 1 < levels:
			var edges: PackedFloat32Array = [c.x]
			edges.append_array(RingGrammar.risers(r))
			edges.append(c.y)
			for k: int in edges.size() - 1:
				ts.append((edges[k] + edges[k + 1]) * 0.5)
		for t: float in ts:
			var z: float = RingGrammar.tread(r, t)
			var a: float = RingGrammar.TURN * j + t
			var dir := Vector3(sin(a), 0, cos(a))
			var at: Vector3 = room.to_global(centre + dir * (RingGrammar.face(r, z) + RingGrammar.WALK) + Vector3(0, j * RingGrammar.STOREY + z + 0.95 + 0.1, 0))
			var inward: Vector3 = room.global_basis * (-dir * 1.6)
			if not (j == 0 and z < 0.6) and await free_way(body, at, inward):
				out.append("parapet %d/%.2f" % [j, t])
			if not (t == 0.0 and door_levels.has(j)) and await free_way(body, at, -inward * 1.4):
				out.append("wall %d/%.2f" % [j, t])
	# The stair's end on the top level: on along the stair from its landing.
	var rt: float = r0 - 1.5 * (levels - 1)
	var a0: float = RingGrammar.TURN * (levels - 1)
	var from: Vector3 = room.to_global(centre + Vector3(sin(a0), 0, cos(a0)) * (RingGrammar.face(rt, 0.0) + RingGrammar.WALK) + Vector3(0, (levels - 1) * RingGrammar.STOREY + 1.05, 0))
	var a1: float = a0 + RingGrammar.half_landing(rt) * 2.5
	var to: Vector3 = room.to_global(centre + Vector3(sin(a1), 0, cos(a1)) * (RingGrammar.face(rt, 0.0) + RingGrammar.WALK) + Vector3(0, (levels - 1) * RingGrammar.STOREY + 1.05, 0))
	if await free_way(body, from, to - from):
		out.append("stair end")
	if await free_way(body, room.to_global(centre + Vector3(0, 0.95, 3.2)), room.global_basis * Vector3(0, 0, -2.5)):
		out.append("pool curb")
	return out


func free_way(body: CharacterBody3D, from: Vector3, motion: Vector3) -> bool:
	body.global_position = from
	await physics_frame
	var params := PhysicsTestMotionParameters3D.new()
	params.from = body.global_transform
	params.motion = motion
	return not PhysicsServer3D.body_test_motion(body.get_rid(), params)


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
			var real: Vector3 = body.get_real_velocity()
			if to.length() > 0.8 and v.length() > SPEED * 0.9 and Vector2(real.x, real.z).length() < SPEED * 0.5:
				snags += 1
			await physics_frame
		if not ok:
			break
		reached += 1
	for _i: int in 30:     # land before the feet are read
		body.velocity = Vector3(0, -3.0, 0)
		body.move_and_slide()
		if body.is_on_floor():
			break
		await physics_frame
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

extends SceneTree
## Gate for the R01 Reading Room (ENVIRONMENT_PLAN.md phase 1 step 2).
##   godot --headless --path . --script res://tests/reading_room_test.gd
## Kit validation, sockets, floor in every cell, and a route audit with the
## player capsule (radius 0.35, height 1.8): doors open, walls closed, the
## hall walkable into the iwan, and both stairs up onto their galleries.

const ROOM: String = "res://rooms/authored/reading_room.tscn"

var failures: PackedStringArray = []
var checks: int = 0


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures.append(what)


func run() -> void:
	var packed: PackedScene = load(ROOM)
	check(packed != null, "reading room loads")
	if packed != null:
		await audit(packed.instantiate() as Node3D)
	print("reading_room_test: %d checks, %d failures" % [checks, failures.size()])
	for f: String in failures:
		print("  FAIL ", f)
	quit(1 if not failures.is_empty() else 0)


func audit(room: Node3D) -> void:
	root.add_child(room)
	var tmpl := room as RoomTemplate
	check(tmpl != null and tmpl.room_id == "reading_room", "root is a RoomTemplate with room_id reading_room")
	for g: String in ["Shell", "Sockets", "Props", "Dressing", "Lights", "Connectors", "Bounds"]:
		check(room.get_node_or_null(g) != null, "has %s" % g)
	var problems: PackedStringArray = KitValidate.scene(room)
	for p: String in problems:
		print("  validate: ", p)
	check(problems.is_empty(), "passes KitValidate (%d modules)" % KitValidate.count_modules(room))
	if tmpl != null:
		var sockets: Array[VariantSocket] = tmpl.sockets()
		var by_set: Dictionary = {}
		for s: VariantSocket in sockets:
			var key: String = s.socket_set.resource_path.get_file().get_basename() if s.socket_set != null else "(none)"
			by_set[key] = int(by_set.get(key, 0)) + 1
		check(by_set == {"recess_library": 16, "iwan_centre": 1, "table_props": 4, "lamp_state": 7},
			"sockets: 16 recesses (atlas), iwan centrepiece, 4 table tops, 7 lamps (found %s)" % by_set)
		check(tmpl.resolve_sockets(7) == tmpl.resolve_sockets(7), "socket picks are deterministic")
	check(room.get_node("Connectors").get_child_count() == 3, "three door connectors")
	await physics_frame
	await physics_frame
	var space: PhysicsDirectSpaceState3D = room.get_world_3d().direct_space_state
	var floors: int = 0
	for k: int in 5:
		for i: int in 3:
			var p := Vector3(2 + i * 4, 0, -2 - k * 4)
			var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3(0, 0.5, 0), p - Vector3(0, 1, 0), 1))
			if not hit.is_empty() and absf((hit["position"] as Vector3).y) < 0.05:
				floors += 1
	check(floors == 15, "floor collision in all 15 cells (%d)" % floors)

	var body: CharacterBody3D = make_capsule(room)
	# Doors open, walls closed.
	check(not await blocked(body, Vector3(6, 0.95, -1.5), Vector3(0, 0, 3)), "entrance arch is open")
	check(not await blocked(body, Vector3(1.5, 0.95, -6), Vector3(-3, 0, 0)), "west side door is open")
	check(not await blocked(body, Vector3(10.5, 0.95, -6), Vector3(3, 0, 0)), "east side door is open")
	check(await blocked(body, Vector3(1.5, 0.95, -18), Vector3(-3, 0, 0)), "west wall blocks (bay 4)")
	check(await blocked(body, Vector3(10.5, 0.95, -2), Vector3(3, 0, 0)), "east wall blocks (bay 0)")
	check(await blocked(body, Vector3(3, 0.95, -1.5), Vector3(0, 0, 3)), "south wall blocks beside the entrance")
	# Walk the hall down the runner, then step aside (the iwan centrepiece has
	# collision on the centre line) and into the alcove.
	await walk(body, Vector3(6, 0.95, -1.0), Vector3(0, 0, -3), func(p: Vector3) -> bool: return p.z < -17.5)
	await walk(body, Vector3.INF, Vector3(-2, 0, 0), func(p: Vector3) -> bool: return p.x < 4.0)
	var feet: Vector3 = await walk(body, Vector3.INF, Vector3(0, 0, -2), func(p: Vector3) -> bool: return p.z < -21.8)
	check(feet.z < -21.5 and absf(feet.y) < 0.1, "walk the hall into the iwan alcove beside the centrepiece (feet at %s)" % feet)
	# West stair: foot at z -16 in bay 4, rises toward the entrance.
	feet = await walk(body, Vector3(0.95, 0.95, -18.5), Vector3(0, 0, 3), func(p: Vector3) -> bool: return p.z > -4.0)
	check(feet.z > -5.0 and absf(feet.y - 4.15) < 0.1, "west stair reaches the west gallery (feet at %s)" % feet)
	# East stair (mirrored module): foot at z -16 in bay 4, also rises toward the entrance.
	feet = await walk(body, Vector3(11.05, 0.95, -18.5), Vector3(0, 0, 3), func(p: Vector3) -> bool: return p.z > -4.0)
	check(feet.z > -5.0 and absf(feet.y - 4.15) < 0.1, "east stair reaches the east gallery (feet at %s)" % feet)
	# Step 2b: the galleries are one U. From the west stair head, round both
	# corners along the entrance wall and back down the east side.
	await walk(body, Vector3(0.95, 0.95, -18.5), Vector3(0, 0, 3), func(p: Vector3) -> bool: return p.z > -4.0)
	feet = await walk(body, Vector3.INF, Vector3(0, 0, 2), func(p: Vector3) -> bool: return p.z > -0.95)
	feet = await walk(body, Vector3.INF, Vector3(2, 0, 0), func(p: Vector3) -> bool: return p.x > 11.0)
	check(feet.x > 10.6 and absf(feet.y - 4.15) < 0.1, "west gallery turns the corner and crosses the end gallery (feet at %s)" % feet)
	feet = await walk(body, Vector3.INF, Vector3(0, 0, -2), func(p: Vector3) -> bool: return p.z < -6.0)
	check(feet.z < -5.5 and feet.x > 10.4 and absf(feet.y - 4.15) < 0.1, "end gallery turns onto the east gallery (feet at %s)" % feet)
	check(await blocked(body, Vector3(6, 5.1, -0.95), Vector3(0, 0, -2)), "end gallery rail keeps the player off the hall")
	check(await blocked(body, Vector3(0.95, 5.1, -4), Vector3(2, 0, 0)), "west gallery rail still closes mid-run")
	# Out through the west door onto the temporary safety floor.
	feet = await walk(body, Vector3(1.5, 0.95, -6), Vector3(-3, 0, 0), func(p: Vector3) -> bool: return p.x < -3.0)
	check(feet.x < -2.5 and feet.y > -0.4, "safety floor catches the player outside a side door (feet at %s)" % feet)
	room.queue_free()
	await process_frame


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


## move_and_slide with gravity until `done` or 10 s; returns the feet position.
## `at` = Vector3.INF continues from where the body is.
func walk(body: CharacterBody3D, at: Vector3, velocity: Vector3, done: Callable) -> Vector3:
	if at != Vector3.INF:
		body.global_position = at
		body.velocity = Vector3.ZERO
		await physics_frame
	for _i: int in 600:
		body.velocity.x = velocity.x
		body.velocity.z = velocity.z
		body.velocity.y = 0.0 if body.is_on_floor() else body.velocity.y - 9.8 / 60.0
		body.move_and_slide()
		await physics_frame
		if done.call(body.global_position):
			break
	return body.global_position - Vector3(0, 0.9, 0)

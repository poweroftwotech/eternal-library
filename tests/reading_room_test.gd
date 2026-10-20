extends SceneTree
## Gate for the R01 Reading Room (ENVIRONMENT_PLAN.md phase 1 step 2).
##   godot --headless --path . --script res://tests/reading_room_test.gd
## Kit validation, sockets, floor in every cell, and a route audit with the
## player capsule (radius 0.35, height 1.8): doors open, walls closed, the
## hall walkable into the iwan, and both stairs up onto their galleries. Runs
## twice: with both stairs pinned to masonry, then to open wood. The galleries are
## masonry as saved (polish 1c), so both passes walk through the arcade.

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
		# Polish 1c: pin the stairs, so the pass does not depend on the saved pins.
		var masonry: RoomTemplate = packed.instantiate()
		check(pin_stairs(masonry, "masonry") == 2, "both stairs pin to the masonry look")
		await audit(masonry, false)
		# Weathering item 4: the stair look is a socket. Pin both stairs to open
		# wood and run the whole audit again, routes up both stairs included.
		var open: RoomTemplate = packed.instantiate()
		check(pin_stairs(open, "open wood") == 2, "both stairs pin to the open wooden look")
		await audit(open, true)
	print("reading_room_test: %d checks, %d failures" % [checks, failures.size()])
	for f: String in failures:
		print("  FAIL ", f)
	quit(1 if not failures.is_empty() else 0)


func audit(room: Node3D, open_stairs: bool) -> void:
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
		check(by_set == {"recess_library": 16, "iwan_centre": 1, "table_props": 4, "lamp_state": 7, "seam_debris": 10,
				"wall_stains": 10, "floor_wear": 15, "lamp_soot": 7, "stair_style": 1, "stair_style_r": 1,
				"gallery_style_slab": 2, "gallery_style_open_end": 1, "gallery_style_open_start": 1, "gallery_style_end": 1,
				"gallery_support": 6, "gallery_support_corner": 2, "arch_growth": 3, "arch_growth_iwan": 1, "cornice_growth": 10,
				"parapet_growth": 5, "parapet_growth_stair": 1, "parapet_growth_stair_r": 1},
			"sockets: 16 recesses (atlas), iwan centrepiece, 4 table tops, 7 lamps, 10 seams, 10 wall stains, 15 floors, 7 soot, 2 stairs, 5 gallery looks, 8 column points, growth over 4 arches, 10 cornices and 7 copings (found %s)" % by_set)
		check(tmpl.resolve_sockets(7) == tmpl.resolve_sockets(7), "socket picks are deterministic")
	check(room.get_node("Connectors").get_child_count() == 3, "three door connectors")
	# Floor wear (polish C item 9): the walked lanes are polished, under the rug is not.
	var wear: FloorWear = room.get_node_or_null("FloorWear")
	FloorWear.rebuild_now()
	check(wear != null and FloorWear.map != null, "FloorWear baked a wear map")
	if wear != null and FloorWear.map != null:
		var lanes: Vector3 = Vector3(wear_at(room, 4.0, -10.0), wear_at(room, 6.0, -10.0), wear_at(room, 8.0, -10.0))
		check(lanes.x > 0.4 and lanes.z > 0.4 and lanes.y == 0.0,
			"wear runs down both lanes beside the rug, none mid-rug (%s)" % lanes)
	var floor_mat: ShaderMaterial = load("res://kit/materials/floor_stone.tres") as ShaderMaterial
	check(floor_mat != null and float(floor_mat.get_shader_parameter("wear_strength")) > 0.0, "floor_stone takes the wear")
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
	# Polish slice A: under the high end of each stair (bay 2) the masonry look
	# is solid, the open wooden one can be walked under, up to the wall.
	for side: Array in [[Vector3(3.0, 0.95, -9.5), -1.0], [Vector3(9.0, 0.95, -9.5), 1.0]]:
		var start: Vector3 = side[0]
		var dir: float = side[1]
		if open_stairs:
			feet = await walk(body, start, Vector3(dir * 2, 0, 0), func(p: Vector3) -> bool: return absf(p.x - 6.0) > 4.9)
			check(absf(feet.x - 6.0) > 4.8 and absf(feet.y) < 0.1, "walk under the open stair to the wall (feet at %s)" % feet)
		else:
			check(await blocked(body, start, Vector3(dir * 2.5, 0, 0)), "the masonry stair is solid underneath (from %s)" % start)
	# Claims: behind masonry the wall-base seams are cleared; open wood shows them.
	if tmpl != null:
		var behind: int = 0
		var hidden_walls: Array[Vector3] = [Vector3(0, 0, -12), Vector3(0, 0, -16), Vector3(12, 0, -8), Vector3(12, 0, -12)]
		for s: VariantSocket in tmpl.sockets():
			var host: Node = s.get_parent()
			while host != null and not host is KitModule:
				host = host.get_parent()
			if s.socket_set != null and s.socket_set.resource_path.ends_with("seam_debris.tres") and host != null \
					and hidden_walls.has((host as Node3D).position.snappedf(0.01)):
				behind += s.last_count
		check((behind > 0) == open_stairs, "seams behind the stairs: %d items (%s)" % [behind,
			"open wood shows them" if open_stairs else "masonry claims them"])
		# Polish 1c fix: every gallery draws its look. No stair claim may clear
		# one (the slab at the west stair head sat on the corner of the masonry
		# stair's claim and walked as an invisible slab).
		var bare: PackedStringArray = []
		for s: VariantSocket in tmpl.sockets():
			if s.socket_set != null and s.socket_set.resource_path.get_file().begins_with("gallery_style_") \
					and s.get_children(true).is_empty():
				bare.append(tmpl.socket_key(s))
		check(bare.is_empty(), "every gallery draws its look (bare: %s)" % [bare])
		# Polish 1c: a masonry stair carries the arcade itself and claims the
		# column point at its head; an open wooden stair needs the column.
		var head_columns: int = 0
		for s: VariantSocket in tmpl.sockets():
			if s.socket_set != null and s.socket_set.resource_path.ends_with("gallery_support.tres") \
					and absf(s.global_position.z + 8.0) < 0.01:
				head_columns += s.get_children(true).size()
		check(head_columns == (2 if open_stairs else 0), "columns at the stair heads: %d (%s)" % [head_columns,
			"open wood needs them" if open_stairs else "masonry claims them"])
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
	# Polish 1c: the masonry arcade. From the hall through the arches to the
	# walls under the side galleries (bay 0) and to the entrance under the end one.
	feet = await walk(body, Vector3(6, 0.95, -2.7), Vector3(-2, 0, 0), func(p: Vector3) -> bool: return p.x < 0.9)
	check(feet.x < 1.0, "through the west arcade to the wall (feet at %s)" % feet)
	feet = await walk(body, Vector3(6, 0.95, -2.7), Vector3(2, 0, 0), func(p: Vector3) -> bool: return p.x > 11.1)
	check(feet.x > 11.0, "through the east arcade to the wall (feet at %s)" % feet)
	feet = await walk(body, Vector3(6, 0.95, -5), Vector3(0, 0, 2), func(p: Vector3) -> bool: return p.z > -0.9)
	check(feet.z > -1.0, "under the end arcade to the entrance (feet at %s)" % feet)
	room.queue_free()
	await process_frame


## Pins every stair_style socket in the room to `label`, as the Sockets panel
## would. Returns how many stairs were pinned.
## Shared wear (0..1) at room x/z.
func wear_at(room: Node3D, x: float, z: float) -> float:
	return FloorWear.wear_at(room.to_global(Vector3(x, 0, z)))


func pin_stairs(room: RoomTemplate, label: String) -> int:
	var lib: SocketSet = load("res://kit/sockets/stair_style.tres")
	var pins: Dictionary[String, int] = {}
	pins.assign(room.socket_pins)
	var count: int = 0
	for key: String in room.socket_pins:
		if key.ends_with("/SOCKET_stair_style"):
			pins[key] = lib.index_of(label)
			count += 1
	room.socket_pins = pins
	return count


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

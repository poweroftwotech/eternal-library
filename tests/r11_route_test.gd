extends SceneTree
## R11 route gate (phase-5-design.md 5.6.4, Q10), headless:
##   godot --headless --path . --script res://tests/r11_route_test.gd [-- seeds=N]
## The Lower Stacks' cistern, seeds 1-5 (those with one), every room built at
## once. The validator is clean; every bay has its floor at its height (the
## causeway at 0, shallows 0.9 m down, deep bays 2 m). A capsule like the
## player's (radius 0.35, height 1.8, colliding with the world and the
## player-only walls) walks the causeway to the sealed door, which blocks;
## then wades a tour of every open bay and back, its feet on the bed. From
## every open bay beside a deep bay or a platform, walking in is blocked.
## The real player, walking forward, moves at full speed on the causeway
## and at wade_speed_factor in the shallows.

const RECIPE: String = "res://gen/recipes/lower_stacks.tres"
const SEEDS: int = 5
const SPEED: float = 8.0
const PLAYER_BLOCKERS: int = 1 << 7

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
	var walked: int = 0
	for s: int in range(1, seeds + 1):
		walked += 1 if await walk_seed(s) else 0
	Area.seed_override = -1
	check(walked >= seeds - 1, "most seeds have a cistern to walk (%d of %d)" % [walked, seeds])
	print("r11_route_test: %d checks, %d failures" % [checks, failures.size()])
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
	var slot: String = ""
	for r: AreaPlan.Room in area.plan.rooms:
		if r.slot_id.begins_with("cistern"):
			slot = r.slot_id
	if slot == "":
		print("  %s: no cistern" % tag)
		area.queue_free()
		await process_frame
		return false
	var room: GeneratedRoom = area.rooms[slot]
	var g: CellGrid = room.grid
	var v: Dictionary = KitValidateRoom.run(room)
	check((v["errors"] as PackedStringArray).is_empty() and (v["warnings"] as PackedStringArray).is_empty(), "%s: the cistern validates clean (%s)" % [tag, v])
	# Floors at their heights.
	var space: PhysicsDirectSpaceState3D = area.get_world_3d().direct_space_state
	var wrong: PackedStringArray = []
	for c: Vector3i in g.cells:
		var top: Vector3 = room.to_global(CellGrid.cell_centre(c) + Vector3(0, 0.5, 0))
		var ray := PhysicsRayQueryParameters3D.create(top, top - Vector3(0, 3.0, 0), 1)
		var hit: Dictionary = space.intersect_ray(ray)
		var y: float = room.to_local(hit["position"]).y if not hit.is_empty() else 99.0
		if absf(y - float(g.cells[c]["floor_y"])) > 0.05:
			wrong.append("%s %s at %.2f" % [c, g.cells[c]["floor_slot"], y])
	check(wrong.is_empty(), "%s: every bay's floor is at its height (%s)" % [tag, wrong.slice(0, 6)])
	var body: CharacterBody3D = make_capsule(area)
	var far := Vector3i(0, 0, 0)
	for c: Vector3i in g.cells:
		if c.x == 0 and c.z > far.z:
			far = c
	# The causeway to the sealed door.
	body.global_position = room.to_global(CellGrid.cell_centre(Vector3i.ZERO) + Vector3(0, 0.95, 0))
	await physics_frame
	var way: Array[Vector3] = []
	for z: int in range(0, far.z + 1):
		way.append(room.to_global(CellGrid.cell_centre(Vector3i(0, 0, z))))
	var got: int = await follow(body, way)
	check(got == way.size() and absf(room.to_local(body.global_position).y - 0.9) < 0.1, "%s: the capsule walks the causeway to the far end (%d of %d)" % [tag, got, way.size()])
	var at_door: Vector3 = room.to_global(CellGrid.cell_centre(far) + Vector3(0, 0.95, 0))
	check(await blocked(body, at_door, room.global_basis * Vector3(0, 0, -3.0)), "%s: the sealed door blocks" % tag)
	# Wade a tour of the open bays, depth first from the entry.
	body.global_position = room.to_global(CellGrid.cell_centre(Vector3i.ZERO) + Vector3(0, 0.95, 0))
	await physics_frame
	var tour: Array[Vector3] = []
	var cells: Array[Vector3i] = []
	_tour(g, Vector3i.ZERO, {}, tour, cells, room)
	var reached: int = 0
	var feet_bad: PackedStringArray = []
	for i: int in tour.size():
		if await follow(body, [tour[i]]) != 1:
			break
		reached += 1
		var feet: float = room.to_local(body.global_position).y - 0.9
		if absf(feet - float(g.cells[cells[i]]["floor_y"])) > 0.12:
			feet_bad.append("%s %.2f" % [cells[i], feet])
	var open: int = g.cells.keys().filter(func(c: Vector3i) -> bool: return not g.cells[c].get("blocked", false)).size()
	var stuck: String = "" if reached == tour.size() else " stuck going from %s to %s at %s" % [cells[maxi(reached - 1, 0)], cells[reached], room.to_local(body.global_position)]
	check(reached == tour.size(), "%s: the capsule wades the tour of the open bays (%d of %d points, %d bays%s)" % [tag, reached, tour.size(), open, stuck])
	check(feet_bad.is_empty(), "%s: its feet are on each bay's floor (%s)" % [tag, feet_bad.slice(0, 6)])
	# Deep bays and platforms can't be entered from any open bay beside them.
	var open_ways: PackedStringArray = []
	for c: Vector3i in g.cells:
		if not g.cells[c].get("blocked", false):
			continue
		for side: int in CellGrid.ALL_SIDES:
			var n: Vector3i = CellGrid.neighbour(c, side)
			if not g.cells.has(n) or g.cells[n].get("blocked", false):
				continue
			var from: Vector3 = room.to_global(CellGrid.cell_centre(n) + Vector3(0, float(g.cells[n]["floor_y"]) + 0.95, 0))
			if not await blocked(body, from, room.to_global(CellGrid.cell_centre(c)) - room.to_global(CellGrid.cell_centre(n))):
				open_ways.append("%s %s from %s" % [c, g.cells[c]["floor_slot"], n])
	check(open_ways.is_empty(), "%s: no deep bay or platform can be walked into (%s)" % [tag, open_ways.slice(0, 6)])
	body.queue_free()
	await wade_speed(tag, area, room, g)
	print("  %s: %s, %d bays, tour %d points" % [tag, slot, g.cells.size(), tour.size()])
	area.queue_free()
	await process_frame
	await process_frame
	return true


## The real player walking forward: full speed on the causeway, slower in a shallow bay.
func wade_speed(tag: String, area: Area, room: Node3D, g: CellGrid) -> void:
	var shallow: Vector3i = Vector3i.MAX
	for c: Vector3i in g.cells:
		var ahead: Vector3i = c + Vector3i(0, 0, 1)
		if g.cells[c]["floor_slot"] == "cell:basin" and not g.cells[c].get("blocked", false) \
				and g.cells.has(ahead) and g.cells[ahead]["floor_slot"] == "cell:basin" and not g.cells[ahead].get("blocked", false):
			shallow = c
	for action: String in ["forward", "back", "left", "right", "sprint", "jump", "interact"]:     # main.gd installs these in the game
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	var player: CharacterBody3D = (load("res://scripts/player.gd") as GDScript).new()
	area.add_child(player)
	player.blocked = false
	var speeds: Array[float] = []
	for c: Vector3i in [Vector3i.ZERO, shallow]:
		if c == Vector3i.MAX:
			speeds.append(-1.0)
			continue
		player.teleport(room.to_global(CellGrid.cell_centre(c) + Vector3(0, float(g.cells[c]["floor_y"]) + 0.05, 0)), room.global_rotation.y)
		Input.action_press("forward")
		for _i: int in 30:
			await physics_frame
		speeds.append(Vector2(player.velocity.x, player.velocity.z).length())
		Input.action_release("forward")
		for _i: int in 5:
			await physics_frame
	player.queue_free()
	check(absf(speeds[0] - player.walking_speed) < 0.1, "%s: the player walks the causeway at full speed (%.2f m/s)" % [tag, speeds[0]])
	if speeds[1] >= 0.0:
		check(absf(speeds[1] - player.walking_speed * player.wade_speed_factor) < 0.1, "%s: and wades the shallows at %.0f%% (%.2f m/s)" % [tag, player.wade_speed_factor * 100.0, speeds[1]])


## Depth-first tour points (bay centres, global, at floor level) through the
## open bays; returns to each bay after visiting its children.
func _tour(g: CellGrid, c: Vector3i, seen: Dictionary, out: Array[Vector3], cells: Array[Vector3i], room: Node3D) -> void:
	seen[c] = true
	out.append(room.to_global(CellGrid.cell_centre(c)))
	cells.append(c)
	for side: int in CellGrid.ALL_SIDES:
		var n: Vector3i = CellGrid.neighbour(c, side)
		if g.cells.has(n) and not seen.has(n) and not g.cells[n].get("blocked", false):
			_tour(g, n, seen, out, cells, room)
			out.append(room.to_global(CellGrid.cell_centre(c)))
			cells.append(c)


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
		# Let it settle onto the floor before the next point.
		for _i: int in 20:
			body.velocity = Vector3(0, -2.0, 0)
			body.move_and_slide()
			if body.is_on_floor():
				break
			await physics_frame
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
	body.collision_mask = 1 | PLAYER_BLOCKERS
	parent.add_child(body)
	return body


func blocked(body: CharacterBody3D, at: Vector3, motion: Vector3) -> bool:
	body.global_position = at
	await physics_frame
	var params := PhysicsTestMotionParameters3D.new()
	params.from = body.global_transform
	params.motion = motion
	return PhysicsServer3D.body_test_motion(body.get_rid(), params)

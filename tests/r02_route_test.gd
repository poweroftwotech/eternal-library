extends SceneTree
## Gate for the generated R02 Stack Gallery joined to R01 (ENVIRONMENT_PLAN.md
## 5.5.8, phase 2 slice 1).
##   godot --headless --path . --script res://tests/r02_route_test.gd
## The rules file is sound. Then for seeds 1-20 it builds
## rooms/test/reading_room_r02.tscn and checks the layout, Validate Room on
## both rooms, floor under every cell, closed walls, and a route audit with
## the player capsule (radius 0.35, height 1.8) from R01's hall through the
## west door, round every corner to the end of the corridor and back. Slice 2:
## straight stretches within min/max_straight_bays, groin vaults on corners,
## and changing max_straight_bays changes the corridor. Same seed, same
## build; different seeds, different builds.

const SCENE: String = "res://rooms/test/reading_room_r02.tscn"
const SEEDS: int = 20
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
	var rules: ModuleRules = load("res://gen/rules/r02_brick.tres")
	var problems: PackedStringArray = rules.check()
	check(problems.is_empty(), "r02_brick rules are sound (%s)" % [problems])
	# A deliberately wrong rule is caught: a floor offered for a wall.
	var bad := ModuleRules.new()
	var r := ModuleRule.new()
	r.slot = "edge:solid"
	var c := ModuleChoice.new()
	c.scene = load("res://kit/modules/walls/floor_4m.tscn")
	r.choices = [c]
	bad.rules = [r]
	check(bad.check().size() == 1, "a floor offered for a wall is reported (%s)" % [bad.check()])

	var grammar: StackGalleryGrammar = load("res://gen/grammars/r02_stack_gallery.tres")
	var signatures: Dictionary = {}
	var lengths: Dictionary = {}
	var turned: int = 0
	for s: int in range(1, SEEDS + 1):
		var room: RoomTemplate = (load(SCENE) as PackedScene).instantiate()
		var g: GeneratedRoom = room.get_node("StackGallery")
		g.gen_seed = s
		root.add_child(room)
		await audit(room, g, grammar, s)
		print("  seed %d: %d bays, %d failures so far" % [s, g.bay_count(), failures.size()])
		signatures[g.module_signature()] = true
		lengths[g.bay_count()] = true
		turned += 1 if corners(g) > 0 else 0
		room.queue_free()
		await process_frame
	check(turned * 2 >= SEEDS, "most seeds turn at least once (%d of %d)" % [turned, SEEDS])
	await straight_rule()
	check(signatures.size() >= SEEDS - 2, "different seeds give different corridors (%d distinct of %d)" % [signatures.size(), SEEDS])
	check(lengths.size() >= 4, "corridor lengths vary with the seed (%s)" % [lengths.keys()])
	print("r02_route_test: %d checks, %d failures" % [checks, failures.size()])
	for f: String in failures:
		print("  FAIL ", f)
	quit(1 if not failures.is_empty() else 0)


func audit(room: RoomTemplate, g: GeneratedRoom, grammar: StackGalleryGrammar, s: int) -> void:
	var tag: String = "seed %d" % s
	var bays: int = g.bay_count()
	check(bays >= grammar.min_bays and bays <= grammar.max_bays, "%s: %d bays within %d-%d" % [tag, bays, grammar.min_bays, grammar.max_bays])
	var grid_problems: PackedStringArray = g.grid.check()
	check(grid_problems.is_empty(), "%s: layout check (%s)" % [tag, grid_problems])
	# Slice 2: straight stretches between corners stay within the grammar's limits
	# (the last one may stop short), and every corner has a groin vault.
	var runs: Array[int] = StackGalleryGrammar.stretches(g.grid)
	var bad_runs: bool = runs.any(func(n: int) -> bool: return n > grammar.max_straight_bays)
	for i: int in runs.size() - 1:
		bad_runs = bad_runs or runs[i] < grammar.min_straight_bays
	check(not bad_runs, "%s: stretches %s within %d-%d bays" % [tag, runs, grammar.min_straight_bays, grammar.max_straight_bays])
	var cross: int = g.modules.filter(func(m: Node3D) -> bool: return m.scene_file_path.ends_with("vault_cross_4m.tscn")).size()
	check(cross == corners(g), "%s: a groin vault on each of %d corners (%d)" % [tag, corners(g), cross])
	var lamps: int = g.grid.lamps.size()
	check(lamps == bays / grammar.lamp_every_bays, "%s: a lamp every %d bays (%d lamps)" % [tag, grammar.lamp_every_bays, lamps])
	# Validate Room on the corridor and on R01 (which must not see the corridor).
	var gv: Dictionary = KitValidateRoom.run(g)
	check((gv["errors"] as PackedStringArray).is_empty() and (gv["warnings"] as PackedStringArray).is_empty(),
		"%s: the corridor validates clean (%s)" % [tag, gv])
	check(KitValidate.scene(g).is_empty(), "%s: corridor modules on the grid (%s)" % [tag, KitValidate.scene(g)])
	var rv: Dictionary = KitValidateRoom.run(room)
	check((rv["errors"] as PackedStringArray).is_empty(), "%s: R01 still validates without errors (%s)" % [tag, rv["errors"]])
	var r01_sockets: int = room.sockets().size()
	check(r01_sockets == 106, "%s: R01 keeps its own 106 sockets, none of the corridor's (%d)" % [tag, r01_sockets])
	check(g.sockets().size() > bays * 2, "%s: corridor sockets resolved (%d)" % [tag, g.sockets().size()])
	# Same seed, same build.
	var first: String = g.module_signature()
	g.generate()
	check(g.module_signature() == first, "%s: regenerating gives the same build" % tag)
	# Joined face to face: the entry connector sits on R01's west door.
	var entry: Node3D = g.get_node("Connectors/SNAP_entry")
	var door: Node3D = room.get_node("Connectors/SNAP_door_west")
	check(entry.global_position.distance_to(door.global_position) < 0.01
		and entry.global_basis.z.dot(door.global_basis.z) < -0.99, "%s: entry meets R01's west door face to face" % tag)

	await physics_frame
	await physics_frame
	var space: PhysicsDirectSpaceState3D = room.get_world_3d().direct_space_state
	var floors: int = 0
	for cell: Vector3i in g.grid.cells:
		var p: Vector3 = g.to_global(CellGrid.cell_centre(cell))
		var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3(0, 0.5, 0), p - Vector3(0, 1, 0), 1))
		if not hit.is_empty() and absf((hit["position"] as Vector3).y) < 0.05:
			floors += 1
	check(floors == bays, "%s: floor collision under all %d cells (%d)" % [tag, bays, floors])
	# A vault over every cell, its crown at 6.0 m (barrel and groin alike).
	var crowns: PackedStringArray = []
	for cell: Vector3i in g.grid.cells:
		var p: Vector3 = g.to_global(CellGrid.cell_centre(cell))
		var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3(0, 1, 0), p + Vector3(0, 9, 0), 1))
		if hit.is_empty() or absf((hit["position"] as Vector3).y - 6.01) > 0.05:
			crowns.append("%s %s" % [cell, hit.get("position", "open")])
	check(crowns.is_empty(), "%s: a vault crown at 6.0 m over every cell (%s)" % [tag, crowns])

	var body: CharacterBody3D = make_capsule(room)
	# Walls closed: from each cell centre, push 3 m through every solid side.
	var leaks: PackedStringArray = []
	for cell: Vector3i in g.grid.cells:
		var p: Vector3 = g.to_global(CellGrid.cell_centre(cell)) + Vector3(0, 0.95, 0)
		for side: int in CellGrid.ALL_SIDES:
			var e: Dictionary = g.grid.edge(cell, side)
			if e.is_empty() or e["mark"] != CellGrid.Mark.SOLID:
				continue
			var out: Vector3 = g.global_basis * (Vector3(CellGrid.neighbour(cell, side) - cell) * Vector3(1, 0, -1))
			if not await blocked(body, p, out * 3.0):
				leaks.append("%s %s" % [cell, CellGrid.SIDE_NAMES[side]])
	check(leaks.is_empty(), "%s: every solid side blocks, the dead end included (%s)" % [tag, leaks])
	# Walk from R01's hall (beside the west door, clear of the reading table)
	# through the door and every bay, round the corners, to the far end, and back.
	var order: Array = g.grid.cells.keys()
	order.sort_custom(func(a: Vector3i, b: Vector3i) -> bool: return g.grid.cells[a]["bay"] < g.grid.cells[b]["bay"])
	var route: Array[Vector3] = []
	for cell: Vector3i in order:
		route.append(g.to_global(CellGrid.cell_centre(cell)))
	body.global_position = Vector3(1.5, 0.95, -6)
	await physics_frame
	var reached: int = await follow(body, route)
	var feet: Vector3 = body.global_position - Vector3(0, 0.9, 0)
	check(reached == route.size() and absf(feet.y) < 0.1,
		"%s: walk from R01 through the west door, round %d corners, to the end (%d of %d bays)" % [tag, corners(g), reached, route.size()])
	var back: Array[Vector3] = route.duplicate()
	back.reverse()
	back.append(Vector3(1.5, 0.0, -6))
	reached = await follow(body, back)
	feet = body.global_position - Vector3(0, 0.9, 0)
	check(reached == back.size() and absf(feet.y) < 0.1, "%s: and back into R01 (feet at %s)" % [tag, feet])
	body.queue_free()


func corners(g: GeneratedRoom) -> int:
	return g.grid.cells.values().filter(func(c: Dictionary) -> bool: return c["kind"] == "corner").size()


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



## The phase 2 done-when: changing max_straight_bays and generating again
## visibly changes the corridor. Seed 5 runs 6 bays straight at the default;
## at 2 the same seed must turn within every 2 bays, and back at 6 it is the
## old corridor again.
func straight_rule() -> void:
	var room: RoomTemplate = (load(SCENE) as PackedScene).instantiate()
	var g: GeneratedRoom = room.get_node("StackGallery")
	g.gen_seed = 5
	var grammar: StackGalleryGrammar = (g.grammar as StackGalleryGrammar).duplicate()
	g.grammar = grammar
	root.add_child(room)
	var before: String = g.module_signature()
	var runs_before: Array[int] = StackGalleryGrammar.stretches(g.grid)
	grammar.max_straight_bays = 2
	g.generate()
	var runs_after: Array[int] = StackGalleryGrammar.stretches(g.grid)
	check(g.module_signature() != before, "max_straight_bays 6 -> 2 changes the corridor (seed 5: %s -> %s)" % [runs_before, runs_after])
	check(runs_after.all(func(n: int) -> bool: return n <= 2) and corners(g) >= 2,
		"at max_straight_bays 2 every stretch is at most 2 bays (%s, %d corners)" % [runs_after, corners(g)])
	var v: Dictionary = KitValidateRoom.run(g)
	check((v["errors"] as PackedStringArray).is_empty() and (v["warnings"] as PackedStringArray).is_empty(),
		"the zigzag validates clean (%s)" % [v])
	grammar.max_straight_bays = 6
	g.generate()
	check(g.module_signature() == before, "back at 6 it is the same corridor again")
	room.queue_free()
	await process_frame

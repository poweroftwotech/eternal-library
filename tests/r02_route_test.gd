extends SceneTree
## Gate for the generated R02 Stack Gallery joined to R01 (ENVIRONMENT_PLAN.md
## 5.5.8, phase 2 slices 1-5).
##   godot --headless --path . --script res://tests/r02_route_test.gd
## The rules file is sound. Then for seeds 1-20 it builds
## rooms/test/reading_room_r02.tscn and checks the layout, Validate Room on
## both rooms, floor under every cell, closed walls, and a route audit with
## the player capsule (radius 0.35, height 1.8) from R01's hall through the
## west door, round every corner to the end of the corridor and back. Slice 2:
## straight stretches within min/max_straight_bays, groin vaults on corners,
## and changing max_straight_bays changes the corridor. Same seed, same
## build; different seeds, different builds. Slice 3: alcoves (walked into and
## out of), collapsed bays (collapsed recesses and rubble), lamps on corners with
## pinned states that fall off with distance, cool fills, the exit (connector,
## free cell beyond, glow stub that blocks) and the dead-end alternative.
## Slice 5: the same audit on the east door and on the entrance, and R01 with
## galleries on all three doors at once (no overlap, every route walks, the
## build independent of tree order). User args: doors=west,east,entrance,three
## (default all) and seeds=N (default 20; fewer skips the tally checks).

const SCENE: String = "res://rooms/test/reading_room_r02.tscn"
## Galleries on all three of R01's doors (slice 5).
const THREE: String = "res://rooms/test/reading_room_r02_three.tscn"
const SEEDS: int = 20
## Audit walking speed: 0.13 m per physics step, well under the capsule radius.
const SPEED: float = 8.0
## R01's doors: connector, and a spot in R01's hall to walk from (clear of the
## reading tables and the stair).
const DOORS: Dictionary = {
	"west": {"connector": &"SNAP_door_west", "start": Vector3(1.5, 0.95, -6)},
	"east": {"connector": &"SNAP_door_east", "start": Vector3(10.5, 0.95, -6)},
	"entrance": {"connector": &"SNAP_entrance", "start": Vector3(6, 0.95, -1.5)},
}
## Gallery node -> door in THREE; seeds there are s + offset.
const THREE_ROOMS: Dictionary = {"StackGallery": ["west", 0], "StackGalleryEast": ["east", 100], "StackGalleryEntrance": ["entrance", 200]}

var failures: PackedStringArray = []
var checks: int = 0
## Slice 3 tallies across one door's seeds.
var stats: Dictionary = {}
var seeds: int = SEEDS


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures.append(what)


## User args: doors=west,east,entrance,three (default all), seeds=N.
func run() -> void:
	var parts: PackedStringArray = ["west", "east", "entrance", "three"]
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("doors="):
			parts = a.trim_prefix("doors=").split(",")
		elif a.begins_with("seeds="):
			seeds = a.trim_prefix("seeds=").to_int()
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
	for door: String in DOORS:
		if parts.has(door):
			await run_door(door)
	if parts.has("west"):
		await dead_end()
		await straight_rule()
	if parts.has("three"):
		await three_doors()
	print("r02_route_test: %d checks, %d failures" % [checks, failures.size()])
	for f: String in failures:
		print("  FAIL ", f)
	quit(1 if not failures.is_empty() else 0)


## R01 with one gallery on `door`, joined there.
func one_gallery(door: String, s: int) -> RoomTemplate:
	var room: RoomTemplate = (load(SCENE) as PackedScene).instantiate()
	var g: GeneratedRoom = room.get_node("StackGallery")
	g.join_connector = DOORS[door]["connector"]
	g.gen_seed = s
	return room


## The 20-seed audit of one gallery on `door`.
func run_door(door: String) -> void:
	print(" %s door" % door)
	stats = {"alcove_seeds": 0, "collapsed_seeds": 0, "near": 0, "near_lit": 0, "far": 0, "far_lit": 0}
	var grammar: StackGalleryGrammar = load("res://gen/grammars/r02_stack_gallery.tres")
	var signatures: Dictionary = {}
	var lengths: Dictionary = {}
	var turned: int = 0
	for s: int in range(1, seeds + 1):
		var room: RoomTemplate = one_gallery(door, s)
		var g: GeneratedRoom = room.get_node("StackGallery")
		root.add_child(room)
		await audit(room, g, grammar, door, s)
		print("  %s seed %d: %d bays, %d failures so far" % [door, s, g.bay_count(), failures.size()])
		signatures[g.module_signature()] = true
		lengths[g.bay_count()] = true
		turned += 1 if corners(g) > 0 else 0
		room.queue_free()
		await process_frame
	var tag: String = "%s door" % door
	check(turned * 2 >= seeds, "%s: most seeds turn at least once (%d of %d)" % [tag, turned, seeds])
	check(stats["alcove_seeds"] >= seeds / 4, "%s: side passages occur (%d of %d seeds have an alcove)" % [tag, stats["alcove_seeds"], seeds])
	check(stats["collapsed_seeds"] >= 1 or seeds < SEEDS, "%s: collapsed bays occur (%d of %d seeds)" % [tag, stats["collapsed_seeds"], seeds])
	var near: float = float(stats["near_lit"]) / maxf(stats["near"], 1)
	var far: float = float(stats["far_lit"]) / maxf(stats["far"], 1)
	print("  %s slice 4: wear map rebuilt in up to %.0f ms (R01 + gallery)" % [tag, stats.get("wear_ms", 0.0)])
	print("  %s slice 3: %d seeds with alcoves, %d with collapsed bays, lamps lit %.0f%% within 3 bays and %.0f%% from 8 bays" % [tag, stats["alcove_seeds"], stats["collapsed_seeds"], near * 100.0, far * 100.0])
	check(near > far + 0.15 or seeds < SEEDS, "%s: lamps fall off with distance: %.0f%% lit within 3 bays, %.0f%% from 8 bays (%s)" % [tag, near * 100.0, far * 100.0, stats])
	check(signatures.size() >= seeds - 2, "%s: different seeds give different corridors (%d distinct of %d)" % [tag, signatures.size(), seeds])
	check(lengths.size() >= 4 or seeds < SEEDS, "%s: corridor lengths vary with the seed (%s)" % [tag, lengths.keys()])


func audit(room: RoomTemplate, g: GeneratedRoom, grammar: StackGalleryGrammar, door_name: String, s: int) -> void:
	var tag: String = "%s seed %d" % [door_name, s]
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
	await features(g, grammar, tag)
	wear(room, g, door_name, tag)
	var wear_before: String = str(g.grid.wear)
	# Validate Room on the corridor and on R01 (which must not see the corridor).
	validate(room, g, tag)
	check(g.sockets().size() > bays * 2, "%s: corridor sockets resolved (%d)" % [tag, g.sockets().size()])
	# Same seed, same build.
	var first: String = g.module_signature()
	g.generate()
	check(g.module_signature() == first, "%s: regenerating gives the same build" % tag)
	check(str(g.grid.wear) == wear_before and not g.grid.wear.is_empty(), "%s: regenerating gives the same wear lanes" % tag)
	await physics_frame
	await physics_frame
	await walk(room, g, door_name, tag)


## Validate Room on the corridor (clean) and on R01 (no errors, and none of
## the corridor's sockets), and the entry on R01's door face to face.
func validate(room: RoomTemplate, g: GeneratedRoom, tag: String) -> void:
	var gv: Dictionary = KitValidateRoom.run(g)
	check((gv["errors"] as PackedStringArray).is_empty() and (gv["warnings"] as PackedStringArray).is_empty(),
		"%s: the corridor validates clean (%s)" % [tag, gv])
	check(KitValidate.scene(g).is_empty(), "%s: corridor modules on the grid (%s)" % [tag, KitValidate.scene(g)])
	var rv: Dictionary = KitValidateRoom.run(room)
	check((rv["errors"] as PackedStringArray).is_empty(), "%s: R01 still validates without errors (%s)" % [tag, rv["errors"]])
	var r01_sockets: int = room.sockets().size()
	check(r01_sockets == 106, "%s: R01 keeps its own 106 sockets, none of the corridor's (%d)" % [tag, r01_sockets])
	var entry: Node3D = g.get_node("Connectors/SNAP_entry")
	var door: Node3D = room.get_node(NodePath("Connectors/" + String(g.join_connector)))
	check(entry.global_position.distance_to(door.global_position) < 0.01
		and entry.global_basis.z.dot(door.global_basis.z) < -0.99, "%s: entry meets R01's %s face to face" % [tag, g.join_connector])


## Floor and vault over every cell, closed walls, and the route audit: from
## R01's hall through the gallery's door and every bay, into each alcove and
## out, round the corners, to the far end, and back.
func walk(room: RoomTemplate, g: GeneratedRoom, door_name: String, tag: String) -> void:
	var space: PhysicsDirectSpaceState3D = room.get_world_3d().direct_space_state
	var floors: int = 0
	for cell: Vector3i in g.grid.cells:
		var p: Vector3 = g.to_global(CellGrid.cell_centre(cell))
		var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3(0, 0.5, 0), p - Vector3(0, 1, 0), 1))
		if not hit.is_empty() and absf((hit["position"] as Vector3).y) < 0.05:
			floors += 1
	check(floors == g.grid.cells.size(), "%s: floor collision under all %d cells, alcoves included (%d)" % [tag, g.grid.cells.size(), floors])
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
			# Solid walls, and an own exit door (its exit_glow stub blocks until a room joins).
			if e.is_empty() or not (e["mark"] == CellGrid.Mark.SOLID or (e["mark"] == CellGrid.Mark.DOOR and not e["host"])):
				continue
			var out: Vector3 = g.global_basis * (Vector3(CellGrid.neighbour(cell, side) - cell) * Vector3(1, 0, -1))
			if not await blocked(body, p, out * 3.0):
				leaks.append("%s %s" % [cell, CellGrid.SIDE_NAMES[side]])
	check(leaks.is_empty(), "%s: every solid side and the exit block (%s)" % [tag, leaks])
	var route: Array[Vector3] = []
	for cell: Vector3i in g.grid.tour():
		route.append(g.to_global(CellGrid.cell_centre(cell)))
	var start: Vector3 = DOORS[door_name]["start"]
	body.global_position = start
	await physics_frame
	var reached: int = await follow(body, route)
	var feet: Vector3 = body.global_position - Vector3(0, 0.9, 0)
	check(reached == route.size() and absf(feet.y) < 0.1,
		"%s: walk from R01 through the %s door, round %d corners and into %d alcoves, to the end (%d of %d stops)" % [tag, door_name, corners(g), alcoves(g), reached, route.size()])
	var back: Array[Vector3] = route.duplicate()
	back.reverse()
	back.append(start * Vector3(1, 0, 1))
	reached = await follow(body, back)
	feet = body.global_position - Vector3(0, 0.9, 0)
	check(reached == back.size() and absf(feet.y) < 0.1, "%s: and back into R01 (feet at %s)" % [tag, feet])
	body.queue_free()


## Slice 3: alcoves, collapsed bays, lamps (corners, states by distance), cool
## fills and the exit, checked on the built room.
func features(g: GeneratedRoom, grammar: StackGalleryGrammar, tag: String) -> void:
	var grid: CellGrid = g.grid
	var by_name: Dictionary = {}
	for m: Node3D in g.modules:
		by_name[String(m.name)] = m
	# Alcoves: one cell off a straight bay through an arch, gabled at both ends,
	# with nothing of the room beside it but its bay.
	var bad: PackedStringArray = []
	for c: Vector3i in grid.cells:
		if grid.cells[c]["kind"] != "alcove":
			continue
		var opens: int = 0
		for side: int in CellGrid.ALL_SIDES:
			var e: Dictionary = grid.edge(c, side)
			var n: Vector3i = CellGrid.neighbour(c, side)
			if e["mark"] == CellGrid.Mark.OPENING:
				opens += 1
				var arch: Node3D = by_name.get("edge_" + CellGrid.key(c, side))
				if arch == null or not arch.scene_file_path.ends_with("wall_arch_3m.tscn") or not grid.cells.has(n) \
						or grid.cells[n]["kind"] != "floor" or not by_name.has("gable_" + CellGrid.key(c, side)):
					bad.append("%s mouth" % c)
			elif e["mark"] != CellGrid.Mark.SOLID or grid.cells.has(n):
				bad.append("%s side %s" % [c, CellGrid.SIDE_NAMES[side]])
		if opens != 1:
			bad.append("%s has %d openings" % [c, opens])
	check(bad.is_empty(), "%s: %d alcoves, each one arch off a straight bay into a closed, gabled cell (%s)" % [tag, alcoves(g), bad])
	# Collapsed bays: both side walls shelf recesses showing "collapsed", rubble at each.
	bad = []
	var collapsed: int = 0
	for c: Vector3i in grid.cells:
		if grid.cells[c]["kind"] != "collapsed":
			continue
		collapsed += 1
		for side: int in StackGalleryGrammar.side_walls(grid, c):
			var k: String = CellGrid.key(c, side)
			var wall: Node3D = by_name.get("edge_" + k)
			var shown: String = ""
			for n: Node in wall.find_children("*", "VariantSocket", true, false) if wall != null else []:
				var s := n as VariantSocket
				if s.socket_set != null and s.socket_set.index_of("collapsed") >= 0:
					shown = s.entry_label(s.last_pick)
			var rubble: Node3D = by_name.get("prop_rubble_" + k)
			var pieces: int = 0
			if rubble != null:
				for n: Node in rubble.find_children("*", "VariantSocket", true, false):
					pieces += (n as VariantSocket).last_count
			if shown != "collapsed" or pieces < 5:
				bad.append("%s %s: recess %s, %d rubble pieces" % [c, CellGrid.SIDE_NAMES[side], shown, pieces])
	check(bad.is_empty(), "%s: %d collapsed bays show collapsed recesses and rubble (%s)" % [tag, collapsed, bad])
	stats["alcove_seeds"] += 1 if alcoves(g) > 0 else 0
	stats["collapsed_seeds"] += 1 if collapsed > 0 else 0
	# Lamps: on every lamp_every_bays-th bay and every corner; each lamp's state
	# socket shows the grammar's pin. Tally lit lamps by distance.
	bad = []
	for c: Vector3i in grid.run_order():
		var i: int = grid.cells[c]["bay"]
		var want: bool = i % grammar.lamp_every_bays == grammar.lamp_every_bays - 1 or (grammar.lamp_on_corners and grid.cells[c]["kind"] == "corner")
		if want != grid.lamps.has(c):
			bad.append("bay %d" % i)
	for c: Vector3i in grid.lamps:
		var lamp: Node3D = by_name.get("lamp_" + CellGrid.cell_name(c))
		var state: String = ""
		for n: Node in lamp.find_children("*", "VariantSocket", true, false) if lamp != null else []:
			var s := n as VariantSocket
			if s.mode == VariantSocket.Mode.STATE:
				state = s.entry_label(s.last_pick)
		if state == "" or state != grid.pins.get("lamp_" + CellGrid.cell_name(c), "?"):
			bad.append("%s state %s" % [c, state])
		var band: String = "near" if int(grid.cells[c]["bay"]) <= 3 else ("far" if int(grid.cells[c]["bay"]) >= 8 else "")
		if band != "":
			stats[band] += 1
			stats[band + "_lit"] += 1 if state == "lit" else 0
	check(bad.is_empty(), "%s: lamps on every %d bays and every corner, states as pinned (%s)" % [tag, grammar.lamp_every_bays, bad])
	# Cool fills: shadowless, on every fill_every_bays-th bay of the run.
	var fills: Array[Node] = g.get_node("Lights").get_children() if g.has_node("Lights") else []
	var want_fills: int = grid.run_order().size() / grammar.fill_every_bays
	var cool: bool = fills.all(func(l: Node) -> bool: return l is OmniLight3D and not (l as OmniLight3D).shadow_enabled \
		and (l as OmniLight3D).light_color.b > (l as OmniLight3D).light_color.r)
	check(fills.size() == want_fills and cool, "%s: %d cool shadowless fills (%d)" % [tag, want_fills, fills.size()])
	# The exit: one own door on the last bay, a connector there pointing out of
	# the room, the cell beyond left free for the next room, and its glow stub.
	var exits: Array[Node] = g.get_node("Connectors").get_children().filter(func(n: Node) -> bool: return String(n.name).begins_with("SNAP_exit"))
	var last: Vector3i = grid.run_order()[-1]
	var ok: bool = exits.size() == 1
	if ok:
		var m := exits[0] as Marker3D
		var side: int = -1
		for s: int in CellGrid.ALL_SIDES:
			var e: Dictionary = grid.edge(last, s)
			if not e.is_empty() and e["mark"] == CellGrid.Mark.DOOR and not e["host"]:
				side = s
		var beyond: Vector3i = CellGrid.neighbour(last, side) if side >= 0 else last
		var outward: Vector3 = CellGrid.cell_centre(beyond) - CellGrid.cell_centre(last)
		ok = side >= 0 and grid.is_free(beyond) and m.transform.origin.distance_to(CellGrid.door_transform(last, side).origin) < 0.01 \
			and (-m.transform.basis.z).dot(outward.normalized()) > 0.99 and by_name.has("prop_exit_" + CellGrid.key(last, side))
	check(ok, "%s: an exit door on the last bay with its connector, a free cell beyond and the glow stub" % tag)


## Slice 4: generated FloorWear lanes in the shared wear map. Worn across
## every run cell and alcove and at the joint with R01 on both sides of its
## wall; unworn 0.5 m off every solid side wall of a straight bay; busier
## near the entry than far out.
func wear(room: RoomTemplate, g: GeneratedRoom, door_name: String, tag: String) -> void:
	FloorWear.rebuild_now()
	var grid: CellGrid = g.grid
	var order: Array[Vector3i] = grid.run_order()
	var unworn: PackedStringArray = []
	var walls: PackedStringArray = []
	var near: Array[float] = []
	var far: Array[float] = []
	for i: int in order.size():
		var c: Vector3i = order[i]
		var o: Vector3 = CellGrid.cell_centre(c)
		var peak: float = maxf(line_wear(g, o + Vector3(-1, 0, 0), o + Vector3(1, 0, 0)), line_wear(g, o + Vector3(0, 0, -1), o + Vector3(0, 0, 1)))
		if peak <= 0.0:
			unworn.append(str(c))
		if grid.cells[c]["bay"] <= 2:
			near.append(peak)
		elif grid.cells[c]["bay"] >= 9:
			far.append(peak)
		if grid.cells[c]["kind"] == "corner" or i == order.size() - 1:
			continue
		for side: int in StackGalleryGrammar.side_walls(grid, c):
			var e: Dictionary = grid.edge(c, side)
			if e["mark"] != CellGrid.Mark.SOLID:
				continue
			var mid: Vector3 = CellGrid.door_transform(c, side).origin
			var p: Vector3 = mid + (o - mid).normalized() * 0.5
			if FloorWear.wear_at(g.to_global(p)) > 0.0:
				walls.append("%s %s" % [c, CellGrid.SIDE_NAMES[side]])
	for c: Vector3i in grid.cells:
		if grid.cells[c]["kind"] == "alcove":
			var o: Vector3 = CellGrid.cell_centre(c)
			if maxf(line_wear(g, o + Vector3(-1, 0, 0), o + Vector3(1, 0, 0)), line_wear(g, o + Vector3(0, 0, -1), o + Vector3(0, 0, 1))) <= 0.0:
				unworn.append("alcove %s" % c)
	check(unworn.is_empty(), "%s: wear lanes cross every bay and alcove (unworn: %s)" % [tag, unworn])
	check(walls.is_empty(), "%s: no wear 0.5 m off the side walls (%s)" % [tag, walls])
	# The R01 side: 0.2 m in from the door (connectors point -Z out of the room).
	var door: Node3D = room.get_node(NodePath("Connectors/" + String(g.join_connector)))
	var inside: Vector3 = door.global_position + door.global_basis.z * 0.2
	var joint: Vector2 = Vector2(FloorWear.wear_at(inside), FloorWear.wear_at(g.to_global(Vector3(2, 0, -0.5))))
	check(joint.x > 0.0 and joint.y > 0.0, "%s: worn on both sides of R01's %s wall (%s)" % [tag, door_name, joint])
	if not far.is_empty():
		var mn: float = near.reduce(func(a: float, b: float) -> float: return a + b, 0.0) / near.size()
		var mf: float = far.reduce(func(a: float, b: float) -> float: return a + b, 0.0) / far.size()
		check(mn > mf, "%s: busier near R01 than far out (%.2f vs %.2f)" % [tag, mn, mf])
	stats["wear_ms"] = maxf(float(stats.get("wear_ms", 0.0)), FloorWear.last_build_ms)


## The most wear on a room-space line (sampled every 4 cm).
func line_wear(g: Node3D, a: Vector3, b: Vector3) -> float:
	var best: float = 0.0
	for i: int in 51:
		best = maxf(best, FloorWear.wear_at(g.to_global(a.lerp(b, i / 50.0))))
	return best


func alcoves(g: GeneratedRoom) -> int:
	return g.grid.cells.values().filter(func(c: Dictionary) -> bool: return c["kind"] == "alcove").size()


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


## end_kind dead_end: no exit door, connector or glow; the far end is a wall
## with a gable, it validates clean and it blocks.
func dead_end() -> void:
	var room: RoomTemplate = (load(SCENE) as PackedScene).instantiate()
	var g: GeneratedRoom = room.get_node("StackGallery")
	g.gen_seed = 3
	var grammar: StackGalleryGrammar = (g.grammar as StackGalleryGrammar).duplicate()
	grammar.end_kind = "dead_end"
	g.grammar = grammar
	root.add_child(room)
	var last: Vector3i = g.grid.run_order()[-1]
	var dir: Vector3i = last - g.grid.run_order()[-2]
	var side: int = StackGalleryGrammar.side_of(dir)
	var e: Dictionary = g.grid.edge(last, side)
	var exits: int = g.get_node("Connectors").get_children().filter(func(n: Node) -> bool: return String(n.name).begins_with("SNAP_exit")).size()
	var stubs: int = g.modules.filter(func(m: Node3D) -> bool: return String(m.name).begins_with("prop_exit_")).size()
	check(e["mark"] == CellGrid.Mark.SOLID and exits == 0 and stubs == 0 and g.modules.any(func(m: Node3D) -> bool: return String(m.name) == "gable_" + CellGrid.key(last, side)),
		"end_kind dead_end: a wall and gable at the far end, no exit (%d connectors, %d stubs)" % [exits, stubs])
	var v: Dictionary = KitValidateRoom.run(g)
	check((v["errors"] as PackedStringArray).is_empty() and (v["warnings"] as PackedStringArray).is_empty(), "the dead end validates clean (%s)" % [v])
	await physics_frame
	await physics_frame
	var body: CharacterBody3D = make_capsule(room)
	var out: Vector3 = g.global_basis * (Vector3(dir) * Vector3(1, 0, -1))
	check(await blocked(body, g.to_global(CellGrid.cell_centre(last)) + Vector3(0, 0.95, 0), out * 3.0), "the dead end blocks")
	room.queue_free()
	await process_frame


## Slice 5: galleries on all three of R01's doors at once (THREE), seeds s,
## s + 100, s + 200. No gallery has a cell in, or beside, another's cells or
## the bay beyond another's exit; each validates and walks there and back.
## The build doesn't depend on tree order. Built alone on their doors, the
## same three galleries do clash in some seeds, so the case tests something.
func three_doors() -> void:
	print(" all three doors")
	var grammar: StackGalleryGrammar = load("res://gen/grammars/r02_stack_gallery.tres")
	var changed: int = 0
	var solo_clashed: int = 0
	for s: int in range(1, seeds + 1):
		var tag: String = "three seed %d" % s
		var room: RoomTemplate = (load(THREE) as PackedScene).instantiate()
		var gs: Array[GeneratedRoom] = []
		for n: String in THREE_ROOMS:
			var g: GeneratedRoom = room.get_node(n)
			g.gen_seed = s + int(THREE_ROOMS[n][1])
			gs.append(g)
		root.add_child(room)
		var prints: Array = []
		var sigs: Dictionary = {}
		var bays: Array[int] = []
		for g: GeneratedRoom in gs:
			var tag_g: String = "%s %s" % [tag, g.name]
			var problems: PackedStringArray = g.grid.check()
			check(problems.is_empty(), "%s: layout check (%s)" % [tag_g, problems])
			check(g.bay_count() >= grammar.min_bays, "%s: %d bays, at least min_bays %d" % [tag_g, g.bay_count(), grammar.min_bays])
			prints.append(footprint(g))
			sigs[String(g.name)] = g.module_signature()
			bays.append(g.bay_count())
		var found: PackedStringArray = clashes(THREE_ROOMS.keys(), prints)
		check(found.is_empty(), "%s: no gallery in, beside or past the exit of another (%s)" % [tag, found])
		FloorWear.rebuild_now()
		await physics_frame
		await physics_frame
		for g: GeneratedRoom in gs:
			var door: String = THREE_ROOMS[String(g.name)][0]
			validate(room, g, "%s %s" % [tag, door])
			await walk(room, g, door, "%s %s" % [tag, door])
		room.queue_free()
		await process_frame
		# Tree order doesn't matter: the galleries reversed under R01 build the same.
		room = (load(THREE) as PackedScene).instantiate()
		for n: String in THREE_ROOMS:
			var g: GeneratedRoom = room.get_node(n)
			g.gen_seed = s + int(THREE_ROOMS[n][1])
			room.move_child(g, room.get_child_count() - 1 - THREE_ROOMS.keys().find(n))
		root.add_child(room)
		var same: bool = true
		for n: String in THREE_ROOMS:
			same = same and (room.get_node(n) as GeneratedRoom).module_signature() == sigs[n]
		check(same, "%s: the same builds with the galleries in reverse tree order" % tag)
		room.queue_free()
		await process_frame
		# Against each gallery alone on its door.
		var solo_changed: PackedStringArray = []
		var solo_prints: Array = []
		for n: String in THREE_ROOMS:
			var door: String = THREE_ROOMS[n][0]
			var solo: RoomTemplate = one_gallery(door, s + int(THREE_ROOMS[n][1]))
			root.add_child(solo)
			var g: GeneratedRoom = solo.get_node("StackGallery")
			if g.module_signature() != sigs[n]:
				solo_changed.append(door)
			solo_prints.append(footprint(g))
			solo.queue_free()
			await process_frame
		changed += 1 if not solo_changed.is_empty() else 0
		var solo_found: PackedStringArray = clashes(THREE_ROOMS.keys(), solo_prints)
		solo_clashed += 1 if not solo_found.is_empty() else 0
		print("  %s: bays %s, changed by a sibling: %s, built alone they'd clash: %s, %d failures so far" % [tag, bays, solo_changed, solo_found.size(), failures.size()])
	print("  slice 5: a sibling changed a later gallery in %d of %d seeds; built alone, %d seeds clash" % [changed, seeds, solo_clashed])
	check(solo_clashed > 0 or seeds < SEEDS, "built alone on their doors, the galleries clash in some seeds (%d of %d)" % [solo_clashed, seeds])


## A gallery's world cells (x/z centres on whole metres) and the bays beyond
## its exits: [cells, exits], each a Dictionary used as a set.
func footprint(g: GeneratedRoom) -> Array:
	var cells: Dictionary = {}
	for c: Vector3i in g.grid.cells:
		cells[snap_xz(g.to_global(CellGrid.cell_centre(c)))] = true
	var beyond: Dictionary = {}
	for n: Node in g.get_node("Connectors").get_children():
		if String(n.name).begins_with("SNAP_exit"):
			var m := n as Node3D
			beyond[snap_xz(m.global_position - m.global_basis.z * CellGrid.BAY * 0.5)] = true
	return [cells, beyond]


## Cells of one gallery in, or beside, another's cells, or in the bay beyond
## another's exit.
func clashes(names: Array, prints: Array) -> PackedStringArray:
	var out: PackedStringArray = []
	for i: int in prints.size():
		for j: int in prints.size():
			if i == j:
				continue
			for w: Vector2i in prints[i][0]:
				if prints[j][0].has(w) or prints[j][1].has(w):
					out.append("%s %s in %s" % [names[i], w, names[j]])
				for d: Vector2i in [Vector2i(4, 0), Vector2i(-4, 0), Vector2i(0, 4), Vector2i(0, -4)]:
					if i < j and prints[j][0].has(w + d):
						out.append("%s %s beside %s" % [names[i], w, names[j]])
	return out


func snap_xz(p: Vector3) -> Vector2i:
	return Vector2i(roundi(p.x), roundi(p.z))

extends SceneTree
## Phase 12 step 4: the Bridge Hall in the real game, saved in one OS process
## and resumed in a fresh one (AGENTS.md: persistence gate).
##   godot --headless --path . --script res://tests/r21_resume_test.gd -- save --save=user://test/r21.json --fresh
##   godot --headless --path . --script res://tests/r21_resume_test.gd -- load --save=user://test/r21.json
## Both runs use Lower Stacks area seed SEED (it has a Bridge Hall, bridge_1).
## save: walk from the caravanserai into the Bridge Hall (through its entry
##       passage) and onto the middle of the bridge. Step off it into the air
##       over the drop: you're put back in the passage you came in by last (Q6),
##       facing the hall. Walk back to the middle of the bridge and quit
##       through the game's own save-and-quit.
## load: a new process resumes on the bridge, on its deck (not the safety
##       floor under the drop). The map draws the hall as its bridge and
##       passages: no cell of the hall's air. Run without --headless it also
##       saves a capture of the open map to CAPTURE after 100 frames.

const AREA: String = "lower_stacks"
const SEED: int = 1
const SLOT: String = "bridge_1"
const EXPECT: String = "user://test/r21_expect.json"
const CAPTURE: String = "res://previews/phase12_step4/map.png"

var main_script: GDScript = load("res://scripts/main.gd")
var failures: PackedStringArray = []
var checks: int = 0
var game: Node
var area: Area
var ws: Node


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures.append(what)


func run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var mode: String = args[0] if args.size() > 0 else "save"
	ws = root.get_node_or_null("WorldState")
	Area.seed_override = SEED
	if mode == "save":
		main_script.room_override = "area:" + AREA
	game = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	current_scene = game
	for _i: int in 12:
		await physics_frame
	area = game.world as Area
	check(area != null and area.recipe.id == AREA, "the game is in the Lower Stacks (%s)" % game.world)
	if area == null or area.plan.room(SLOT) == null:
		check(false, "seed %d has a Bridge Hall (%s)" % [SEED, SLOT])
		finish(mode)
		return
	await until(func() -> bool: return not area.streamer.busy())
	if mode == "save":
		await save_mode()
	else:
		await load_mode()
	finish(mode)


## The hall's bridge node, once its room is built.
func bridge() -> BridgeHallBridge:
	var room: Node = area.rooms.get(SLOT)
	if room == null:
		return null
	var found: Array[Node] = room.find_children("*", "BridgeHallBridge", true, false)
	return found[0] as BridgeHallBridge if not found.is_empty() else null


## The middle of the bridge's walk, global, standing on its deck.
func mid_bridge(b: BridgeHallBridge) -> Vector3:
	var meta: Dictionary = (area.rooms[SLOT] as GeneratedRoom).grid.meta["bridge"]
	var walk: Array = BridgeHallBridge.plan(int(meta["bays"]), int(meta.get("rise", 0)), BridgeHallBridge.PIT, false)["walk"]
	return b.to_global(walk[walk.size() / 2] as Vector3)


func save_mode() -> void:
	var p: AreaPlan = area.plan
	await walk(AreaTour.leg(p, p.room(SLOT)))
	await until(func() -> bool: return bridge() != null)
	var b: BridgeHallBridge = bridge()
	check(b != null, "the Bridge Hall is built when you reach it")
	if b == null:
		return
	var on: Vector3 = mid_bridge(b)
	game.player.teleport(on + Vector3(0, 0.05, 0), game.player.rotation.y)
	await wait(0.5)
	check(on_deck(), "on the middle of the bridge you stand on its deck")
	# Off the side, over the drop (toward the hall's middle, away from the walls).
	var hall: AABB = (area.rooms[SLOT] as GeneratedRoom).grid.meta["hall"]
	var room: Node3D = area.rooms[SLOT]
	var local: Vector3 = room.to_local(on)
	var out: float = signf(hall.get_center().x - local.x)
	if out == 0.0:
		out = 1.0
	# A bay and a half along from the middle: the landing's side deck stands on
	# the middle bay.
	game.player.teleport(room.to_global(local + Vector3(out * 3.5, 0.5, CellGrid.BAY * 1.5)), game.player.rotation.y)
	# The walk ended at the room's far end, so the passage you came in by
	# last may be either one.
	var gm: Dictionary = (area.rooms[SLOT] as GeneratedRoom).grid.meta
	var entry: Array = (gm["entry_cells"] as Array) + (gm["far_cells"] as Array)
	var from_entry := func() -> float:
		var at: Vector3 = room.to_local(game.player.global_position)
		var best: float = INF
		for c: Vector3i in entry:
			var q: Vector3 = CellGrid.cell_centre(c)
			best = minf(best, Vector2(at.x, at.z).distance_to(Vector2(q.x, q.z)))
		return best
	await until(func() -> bool: return from_entry.call() < 1.0)
	var near: float = from_entry.call()
	check(near < 1.0, "stepping off the bridge puts you back in a passage you came in by (%.2f m from its cells; at %s)" % [near, room.to_local(game.player.global_position)])
	game.player.teleport(on + Vector3(0, 0.05, 0), game.player.rotation.y)
	await wait(0.8)
	check(on_deck(), "back on the bridge")
	var f := FileAccess.open(EXPECT, FileAccess.WRITE)
	f.store_string(JSON.stringify({"at": [game.player.global_position.x, game.player.global_position.y, game.player.global_position.z]}))
	f.close()


func load_mode() -> void:
	var expect: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(EXPECT))
	var want := Vector3(float(expect["at"][0]), float(expect["at"][1]), float(expect["at"][2]))
	await until(func() -> bool: return bridge() != null)
	await wait(0.5)
	var d: float = game.player.global_position.distance_to(want)
	check(d < 0.5, "a new process resumes on the bridge (%.2f m from where you saved)" % d)
	check(on_deck(), "standing on its deck")
	# The map: the hall drawn as its bridge and passages.
	game.map.open()
	await process_frame
	var c: MapCanvas = game.map.canvas
	check(game.map.is_open() and c.place_id == AREA, "the map opens on the Lower Stacks")
	var sketch: Variant = null
	for s: Variant in c.rooms:
		if s.slot_id == SLOT:
			sketch = s
	check(sketch != null, "it draws the Bridge Hall")
	if sketch != null:
		var g: GeneratedRoom = area.rooms[SLOT]
		var r: AreaPlan.Room = area.plan.room(SLOT)
		var air: int = 0
		for gc: Vector3i in g.grid.cells:
			if g.grid.cells[gc].get("no_map", false) and sketch.floor_cells.has(AreaPlan.cell_of(r.xf * (CellGrid.cell_centre(gc) + Vector3(0, 0.1, 0)))):
				air += 1
		check(air == 0, "as its bridge and passages, none of the hall's air (%d air cells drawn)" % air)
		check(sketch.floor_cells.size() > 0 and sketch.floor_cells.size() < r.floor_cells.size(),
			"%d cells drawn of the room's %d" % [sketch.floor_cells.size(), r.floor_cells.size()])
	check(not c.you.is_empty(), "with you on it")
	if DisplayServer.get_name() != "headless":
		for _i: int in 100:
			await process_frame
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CAPTURE.get_base_dir()))
		var err: Error = root.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(CAPTURE))
		check(err == OK, "saved the capture %s" % CAPTURE)
		print("r21_resume_test: capture ", ProjectSettings.globalize_path(CAPTURE))
	game.map.close()


## Whether the player stands on the bridge's deck: a ray down from the
## player's feet meets the bridge, not the safety floor under the drop.
func on_deck() -> bool:
	var at: Vector3 = game.player.global_position + Vector3(0, 0.3, 0)
	var q := PhysicsRayQueryParameters3D.create(at, at + Vector3.DOWN * 1.2)
	q.exclude = [game.player.get_rid()]
	var hit: Dictionary = area.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return false
	var n: Node = hit["collider"]
	var b: BridgeHallBridge = bridge()
	return b != null and b.is_ancestor_of(n)


func finish(mode: String) -> void:
	Area.seed_override = -1 if mode == "load" else Area.seed_override
	print("r21_resume_test %s: %d checks, %d failures" % [mode, checks, failures.size()])
	for f: String in failures:
		print("  FAIL ", f)
	if failures.is_empty() and game != null:
		game.save_and_quit()
	else:
		quit(1 if not failures.is_empty() else 0)


## Teleports the player along floor points, letting the streamer catch up at each.
func walk(points: Array[Vector3]) -> void:
	for i: int in points.size():
		var to: Vector3 = area.to_global(points[i])
		var yaw: float = game.player.rotation.y
		if i + 1 < points.size():
			var d: Vector3 = area.to_global(points[i + 1]) - to
			if d.length() > 0.1:
				yaw = atan2(-d.x, -d.z)
		game.player.teleport(to + Vector3(0, 0.05, 0), yaw)
		await wait(0.3)
		await until(func() -> bool: return not area.streamer.busy())


func wait(s: float) -> void:
	var stop_ms: int = Time.get_ticks_msec() + int(s * 1000.0)
	while Time.get_ticks_msec() < stop_ms:
		await physics_frame


func until(cond: Callable) -> void:
	var stop_ms: int = Time.get_ticks_msec() + 10000
	while not cond.call() and Time.get_ticks_msec() < stop_ms:
		await process_frame

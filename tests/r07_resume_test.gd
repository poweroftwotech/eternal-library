extends SceneTree
## Phase 13 step 2: the Garden Court in the real game, saved in one OS process
## and resumed in a fresh one (AGENTS.md: persistence gate).
##   godot --audio-driver Dummy --headless --path . --script res://tests/r07_resume_test.gd -- save --save=user://test/r07.json --fresh [--in=forgotten_wing]
##   godot --audio-driver Dummy --headless --path . --script res://tests/r07_resume_test.gd -- load --save=user://test/r07.json [--in=forgotten_wing]
## Both runs use area seed SEED with the live recipe (the garden, garden_1,
## grows there: under a seed override shared rooms grow everywhere).
## save: walk from the area's first room into the garden, stand under the
##       great tree's crown (beside its trunk, toward the pool), and quit
##       through the game's own save-and-quit.
## load: a new process resumes there, standing on the court's floor, the
##       great tree and the pool built. The map draws the garden, the pool's
##       cell left out, with you on it. Without --headless it also saves a
##       capture of the open map.

const SEED: int = 1
const SLOT: String = "garden_1"

var main_script: GDScript = load("res://scripts/main.gd")
var failures: PackedStringArray = []
var checks: int = 0
var game: Node
var area: Area
var area_id: String = "lower_stacks"


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures.append(what)


func run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var mode: String = args[0] if args.size() > 0 else "save"
	for a: String in args:
		if a.begins_with("--in="):     # not --area=: main.gd starts afresh in an area named so
			area_id = a.trim_prefix("--in=")
	Area.seed_override = SEED
	if mode == "save":
		main_script.room_override = "area:" + area_id
	game = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	current_scene = game
	for _i: int in 12:
		await physics_frame
	area = game.world as Area
	check(area != null and area.recipe.id == area_id, "the game is in %s (%s)" % [area_id, game.world])
	if area == null or area.plan.room(SLOT) == null:
		check(false, "seed %d grows a Garden Court (%s)" % [SEED, SLOT])
		finish(mode)
		return
	await until(func() -> bool: return not area.streamer.busy())
	if mode == "save":
		await save_mode()
	else:
		await load_mode()
	finish(mode)


func garden() -> GeneratedRoom:
	return area.rooms.get(SLOT) as GeneratedRoom


func tree() -> Node3D:
	var g: GeneratedRoom = garden()
	return g.find_child("prop_great_tree", true, false) as Node3D if g != null else null


func expect_path() -> String:
	return "user://test/r07_expect_%s.json" % area_id


func save_mode() -> void:
	await walk(AreaTour.leg(area.plan, area.plan.room(SLOT)))
	await until(func() -> bool: return tree() != null)
	var t: Node3D = tree()
	check(t != null, "the great tree is built when you reach the garden")
	if t == null:
		return
	var g: GeneratedRoom = garden()
	var pool: Vector3 = g.to_global(CellGrid.cell_centre(g.grid.meta["centre"]))
	var toward: Vector3 = pool - t.global_position
	toward.y = 0.0
	var at: Vector3 = t.global_position + toward.normalized() * 1.4
	game.player.teleport(at + Vector3(0, 0.1, 0), atan2(-toward.x, -toward.z))
	await wait(0.8)
	check(on_floor(), "under the great tree you stand on the court's floor (at %s)" % g.to_local(game.player.global_position))
	var p: Vector3 = game.player.global_position
	var f := FileAccess.open(expect_path(), FileAccess.WRITE)
	f.store_string(JSON.stringify({"at": [p.x, p.y, p.z]}))
	f.close()


func load_mode() -> void:
	var expect: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(expect_path()))
	var want := Vector3(float(expect["at"][0]), float(expect["at"][1]), float(expect["at"][2]))
	await until(func() -> bool: return tree() != null)
	await wait(0.5)
	var d: float = game.player.global_position.distance_to(want)
	check(d < 0.5, "a new process resumes under the great tree (%.2f m from where you saved)" % d)
	check(on_floor(), "standing on the court's floor")
	var g: GeneratedRoom = garden()
	check(g != null and g.find_child("prop_pool", true, false) != null, "the pool is built")
	game.map.open()
	await process_frame
	var c: MapCanvas = game.map.canvas
	check(game.map.is_open() and c.place_id == area_id, "the map opens on %s" % area_id)
	var sketch: Variant = null
	for s: Variant in c.rooms:
		if s.slot_id == SLOT:
			sketch = s
	check(sketch != null, "it draws the Garden Court")
	if sketch != null:
		var r: AreaPlan.Room = area.plan.room(SLOT)
		check(sketch.floor_cells.size() > 20, "%d of its cells drawn (the room has %d)" % [sketch.floor_cells.size(), r.floor_cells.size()])
	check(not c.you.is_empty(), "with you on it")
	if DisplayServer.get_name() != "headless":
		for _i: int in 100:
			await process_frame
		var cap: String = "res://previews/phase13_step2/map_%s.png" % area_id
		var err: Error = root.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(cap))
		check(err == OK, "saved the capture %s" % cap)
	game.map.close()


## A ray down from the player's feet meets the garden's floor (not a safety floor).
func on_floor() -> bool:
	var at: Vector3 = game.player.global_position + Vector3(0, 0.3, 0)
	var q := PhysicsRayQueryParameters3D.create(at, at + Vector3.DOWN * 1.2)
	q.exclude = [game.player.get_rid()]
	var hit: Dictionary = area.get_world_3d().direct_space_state.intersect_ray(q)
	var g: GeneratedRoom = garden()
	return not hit.is_empty() and g != null and g.is_ancestor_of(hit["collider"] as Node)


func finish(mode: String) -> void:
	Area.seed_override = -1 if mode == "load" else Area.seed_override
	print("r07_resume_test %s %s: %d checks, %d failures" % [mode, area_id, checks, failures.size()])
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

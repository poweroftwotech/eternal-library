extends SceneTree
## Phase 15 step 5: the Grand Bazaar in the real game, saved in one OS process
## and resumed in a fresh one (AGENTS.md: persistence gate).
##   godot --audio-driver Dummy --headless --path . --script res://tests/r04_resume_test.gd -- save --save=user://test/r04.json --fresh
##   godot --audio-driver Dummy --headless --path . --script res://tests/r04_resume_test.gd -- load --save=user://test/r04.json
## Both runs use area seed SEED with the live Mahaleh.
## save: stand inside the first open shop of bazaar_1 and quit through the game's
##       own save-and-quit.
## load: a new process resumes there, on the shop's floor, the room's life built.
##       The map draws the streets, with you on it. Without --headless it also
##       saves a capture of the open map.

const SEED: int = 2
const SLOT: String = "bazaar_1"
const AREA_ID: String = "mahaleh"

var main_script: GDScript = load("res://scripts/main.gd")
var failures: PackedStringArray = []
var checks: int = 0
var game: Node
var area: Area


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures.append(what)


func run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var mode: String = args[0] if args.size() > 0 else "save"
	Area.seed_override = SEED
	if mode == "save":
		main_script.room_override = "area:" + AREA_ID
	game = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	current_scene = game
	for _i: int in 12:
		await physics_frame
	area = game.world as Area
	check(area != null and area.recipe.id == AREA_ID, "the game is in %s (%s)" % [AREA_ID, game.world])
	if area == null or area.plan.room(SLOT) == null:
		check(false, "seed %d grows %s" % [SEED, SLOT])
		finish(mode)
		return
	await until(func() -> bool: return not area.streamer.busy())
	if mode == "save":
		await save_mode()
	else:
		await load_mode()
	finish(mode)


func bazaar() -> GeneratedRoom:
	return area.rooms.get(SLOT) as GeneratedRoom


func expect_path() -> String:
	return "user://test/r04_expect.json"


func save_mode() -> void:
	# Stream to the bazaar along the way there; the entrance's walk isn't the test.
	for p: Vector3 in AreaTour.leg(area.plan, area.plan.room(SLOT)):
		game.player.teleport(area.to_global(p) + Vector3(0, 0.1, 0), 0.0)
		for _i: int in 4:
			await physics_frame
		await until(func() -> bool: return not area.streamer.busy())
	var g: GeneratedRoom = bazaar()
	check(g != null, "the bazaar is built when you reach it")
	if g == null:
		return
	var at: Vector3 = g.to_global((g.grid.meta["shops"] as Array)[0][0])
	game.player.teleport(at + Vector3(0, 0.1, 0), 0.0)
	await wait(0.8)
	check(on_floor(), "inside the shop you stand on its floor (at %s)" % g.to_local(game.player.global_position))
	var p: Vector3 = game.player.global_position
	var f := FileAccess.open(expect_path(), FileAccess.WRITE)
	f.store_string(JSON.stringify({"at": [p.x, p.y, p.z], "shops": (g.grid.meta["shops"] as Array).size()}))
	f.close()


func load_mode() -> void:
	var expect: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(expect_path()))
	var want := Vector3(float(expect["at"][0]), float(expect["at"][1]), float(expect["at"][2]))
	await until(func() -> bool: return bazaar() != null and bazaar().find_child("Dust", true, false) != null)
	await wait(0.5)
	var d: float = game.player.global_position.distance_to(want)
	check(d < 0.5, "a new process resumes in the shop (%.2f m from where you saved)" % d)
	check(on_floor(), "standing on the shop's floor")
	var g: GeneratedRoom = bazaar()
	check(g != null and (g.grid.meta["shops"] as Array).size() == int(expect["shops"]), "the same shops")
	check(g != null and g.find_child("Dust", true, false) != null, "the room's life is built")
	game.map.open()
	await process_frame
	var c: MapCanvas = game.map.canvas
	check(game.map.is_open() and c.place_id == AREA_ID, "the map opens on %s" % AREA_ID)
	var sketch: Variant = null
	for s: Variant in c.rooms:
		if s.slot_id == SLOT:
			sketch = s
	check(sketch != null, "it draws the bazaar")
	if sketch != null:
		var cells: Dictionary = {}
		for x: Vector3i in sketch.floor_cells:
			cells[x] = true
		var streets: int = 0
		var r: AreaPlan.Room = area.plan.room(SLOT)
		for p: Vector3 in r.grid.meta["route"]:
			var cell: Vector3i = AreaPlan.cell_of(r.xf * p + Vector3(0, 0.1, 0))
			if cells.has(cell):
				streets += 1
		check(streets >= (r.grid.meta["route"] as Array).size() / 2, "its streets are on it (%d of %d stops; %d cells drawn)" % [streets, (r.grid.meta["route"] as Array).size(), sketch.floor_cells.size()])
	check(not c.you.is_empty(), "with you on it")
	if DisplayServer.get_name() != "headless":
		for _i: int in 100:
			await process_frame
		var cap: String = "res://previews/phase15_step5/map.png"
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(cap.get_base_dir()))
		check(root.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(cap)) == OK, "saved the capture")
	game.map.close()


## A ray down from the player's feet meets the bazaar (not a safety floor).
func on_floor() -> bool:
	var at: Vector3 = game.player.global_position + Vector3(0, 0.3, 0)
	var q := PhysicsRayQueryParameters3D.create(at, at + Vector3.DOWN * 1.2)
	q.exclude = [game.player.get_rid()]
	var hit: Dictionary = area.get_world_3d().direct_space_state.intersect_ray(q)
	var g: GeneratedRoom = bazaar()
	return not hit.is_empty() and g != null and g.is_ancestor_of(hit["collider"] as Node) and not String((hit["collider"] as Node).name).contains("Safety")


func until(done: Callable, frames: int = 2400) -> void:
	for _i: int in frames:
		if done.call():
			return
		await process_frame


func wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func finish(mode: String) -> void:
	Area.seed_override = -1 if mode == "load" else Area.seed_override
	print("r04_resume_test %s: %s (%d checks, %d failures)" % [mode, "PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	for f: String in failures:
		print("  FAIL ", f)
	if failures.is_empty() and game != null:
		game.save_and_quit()
	else:
		quit(1 if not failures.is_empty() else 0)

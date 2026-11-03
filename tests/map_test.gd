extends SceneTree
## Phase 11 step 1: the map of an interior, saved in one OS process and
## restored in a fresh one (AGENTS.md: persistence gate).
##   godot --headless --path . --script res://tests/map_test.gd -- save --save=user://test/map.json --fresh
##   godot --headless --path . --script res://tests/map_test.gd -- load --save=user://test/map.json
## save: the Lower Stacks; walk to its deepest room. Every room on the way is
##       entered, rooms seen through doorways are seen and not entered; the
##       map opens on it with you on it, pauses the game, closes again; quit
##       through the game's own save-and-quit.
## load: a new process resumes there: the save holds the same rooms; the map
##       draws them, lists the Lower Stacks as here, opens on your floor. Run
##       without --headless it also saves a capture of the open map to
##       previews/p11_step1/map.png after 100 frames.

const AREA: String = "lower_stacks"
const EXPECT: String = "user://test/map_expect.json"
const CAPTURE: String = "res://previews/p11_step1/map.png"

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
	if mode == "save":
		main_script.room_override = "area:" + AREA
	game = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	current_scene = game
	for _i: int in 12:
		await physics_frame
	area = game.world as Area
	check(area != null and area.recipe.id == AREA, "the game is in the Lower Stacks (%s)" % game.world)
	if area == null:
		finish(mode)
		return
	await until(func() -> bool: return not area.streamer.busy())
	if mode == "save":
		await save_mode()
	else:
		await load_mode()
	finish(mode)


func save_mode() -> void:
	var p: AreaPlan = area.plan
	var far: AreaPlan.Room = null
	for r: AreaPlan.Room in p.rooms:
		if far == null or r.depth > far.depth:
			far = r
	await walk(AreaTour.leg(p, far))
	await wait(0.4)
	var known: Dictionary = ws.call("map_place", AREA, p.recipe_version)
	var entered: Array = known["entered"]
	var seen: Array = known["seen"]
	# Every room from the root to the deepest was walked through.
	var chain: Array[String] = []
	var r: AreaPlan.Room = far
	while r != null:
		chain.append(r.slot_id)
		r = p.room(r.parent) if r.parent != "" else null
	for s: String in chain:
		check(entered.has(s), "walked through %s, the map has it entered" % s)
	check(entered.size() < p.rooms.size(), "not every room is entered (%d of %d)" % [entered.size(), p.rooms.size()])
	check(not seen.is_empty(), "some rooms are only seen (%d)" % seen.size())
	for s: Variant in seen:
		check(not entered.has(s), "%s is seen or entered, not both" % s)
	check(ws.call("map_places").has(AREA), "the Lower Stacks is a place the map knows")
	# Open, look, close.
	game.map.open()
	await process_frame
	check(game.map.is_open() and game.player.blocked, "M opens the map and the game pauses")
	check(game.map.shown_id == AREA and game.map.canvas.rooms.size() == entered.size() + seen.size(), "it opens on the Lower Stacks, every room known sketched (%d)" % game.map.canvas.rooms.size())
	check(not game.map.canvas.you.is_empty(), "you are on it")
	game.map.close()
	check(not game.map.is_open() and not game.player.blocked, "it closes and the game goes on")
	var f := FileAccess.open(EXPECT, FileAccess.WRITE)
	f.store_string(JSON.stringify({"entered": entered, "seen": seen, "storey": MapPage.storey_of(p, area.to_local(game.player.global_position))}))
	f.close()


func load_mode() -> void:
	var expect: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(EXPECT))
	var p: AreaPlan = area.plan
	var known: Dictionary = ws.call("map_place", AREA, p.recipe_version)
	var entered: Array = (known["entered"] as Array).duplicate()
	var want: Array = (expect["entered"] as Array).duplicate()
	entered.sort()
	want.sort()
	check(entered == want, "a new process has the same rooms entered (%d, saved %d)" % [entered.size(), want.size()])
	check((known["seen"] as Array).size() >= (expect["seen"] as Array).size(), "and the rooms seen")
	game.map.open()
	await process_frame
	var c: MapCanvas = game.map.canvas
	check(game.map.is_open() and c.place_id == AREA, "the map opens on the Lower Stacks")
	check(c.entered.size() == want.size(), "it draws the %d rooms entered" % want.size())
	check(c.storey == int(expect["storey"]), "on your floor (%d)" % int(expect["storey"]))
	check(not c.you.is_empty(), "with you on it")
	# A place never visited isn't listed; a recipe that moved rooms forgets its place.
	check(not ws.call("map_places").has("sanctum"), "the Sanctum, never visited, isn't listed")
	var stale: Dictionary = ws.call("map_place", AREA, p.recipe_version + 1)
	check((stale["entered"] as Array).is_empty(), "a newer recipe forgets the place's map")
	(ws.get("data")["map"]["places"] as Dictionary)[AREA] = known     # put it back
	if DisplayServer.get_name() != "headless":
		for _i: int in 100:
			await process_frame
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CAPTURE.get_base_dir()))
		var err: Error = root.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(CAPTURE))
		check(err == OK, "saved the capture %s" % CAPTURE)
		print("map_test: capture ", ProjectSettings.globalize_path(CAPTURE))
	game.map.close()


func finish(mode: String) -> void:
	print("map_test %s: %d checks, %d failures" % [mode, checks, failures.size()])
	for f: String in failures:
		print("  FAIL ", f)
	if failures.is_empty() and game != null:
		game.save_and_quit()
	else:
		quit(1 if not failures.is_empty() else 0)


## Teleports the player along floor points, letting the streamer and the map catch up at each.
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

extends SceneTree
## Phase 17 step 5: the Orosi Scriptorium in the real game, saved in one OS
## process and resumed in a fresh one (AGENTS.md: persistence gate).
##   godot --audio-driver Dummy --headless --path . --script res://tests/r08_resume_test.gd -- save --save=user://test/r08.json --fresh
##   godot --audio-driver Dummy --headless --path . --script res://tests/r08_resume_test.gd -- load --save=user://test/r08.json
## Both runs use area seed SEED with the live Grand Study.
## save: walk to the scriptorium, stand in the aisle under the glass, read a
##       copy, and quit through the game's own save-and-quit.
## load: a new process resumes under the glass, standing on the floor; the room
##       is built the same (the same glass, the same copy at the same desk, in
##       the same hand); the moss breathes; the map draws the room.

const SEED: int = 2
const SLOT: String = "scriptorium_1"
const AREA_ID: String = "grand_study"

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


func room() -> GeneratedRoom:
	return area.rooms.get(SLOT) as GeneratedRoom


func copies() -> Array[ScriptoriumCopy]:
	var out: Array[ScriptoriumCopy] = []
	if room() != null:
		for n: Node in room().find_children("prop_copy_*", "", true, false):
			if n is ScriptoriumCopy:
				out.append(n as ScriptoriumCopy)
	return out


func glass() -> String:
	var found: Array[Node] = room().find_children("prop_orosi", "Node3D", true, false) if room() != null else []
	return str(found[0].get_meta("palette", "")) if not found.is_empty() else ""


func expect_path() -> String:
	return "user://test/r08_expect.json"


func save_mode() -> void:
	for p: Vector3 in AreaTour.leg(area.plan, area.plan.room(SLOT)):
		game.player.teleport(area.to_global(p) + Vector3(0, 0.1, 0), 0.0)
		for _i: int in 4:
			await physics_frame
		await until(func() -> bool: return not area.streamer.busy())
	var g: GeneratedRoom = room()
	check(g != null, "the scriptorium is built when you reach it")
	if g == null:
		return
	await until(func() -> bool: return not copies().is_empty())
	# The aisle (room x 2 m), a bay short of the glass.
	var rows: int = int(g.grid.meta.get("rows", 3))
	game.player.teleport(g.to_global(Vector3(2.0, 0.1, -(rows * CellGrid.BAY - 2.0))), 0.0)
	await wait(0.8)
	check(on_floor(), "under the glass you stand on the hall's floor")
	var cs: Array[ScriptoriumCopy] = copies()
	check(cs.size() >= 12, "every desk has a copy (%d)" % cs.size())
	var c: ScriptoriumCopy = cs.back()
	check(c.interaction_prompt(Vector3.ZERO) == "Read the copy", "a copy offers to be read")
	c.interact(game.player, Vector3.ZERO)
	await process_frame
	check(game.modal_context == "book", "reading opens the page (%s)" % game.modal_context)
	check(c.title().contains(", in the hand of "), "its title names the copyist (%s)" % c.title())
	game.close_panel()
	var life: Array[Node] = g.find_children("prop_life", "", true, false)
	check(not life.is_empty() and not (life[0] as ScriptoriumLife)._moss.is_empty(), "the moss breathes (the life node found its lights)")
	var p: Vector3 = game.player.global_position
	var f := FileAccess.open(expect_path(), FileAccess.WRITE)
	f.store_string(JSON.stringify({"at": [p.x, p.y, p.z], "copy": String(c.name), "title": c.title(), "body": c.body(), "glass": glass(), "copies": cs.size()}))
	f.close()


func load_mode() -> void:
	var expect: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(expect_path()))
	var want := Vector3(float(expect["at"][0]), float(expect["at"][1]), float(expect["at"][2]))
	await until(func() -> bool: return room() != null and not copies().is_empty())
	await wait(0.8)
	var d: float = game.player.global_position.distance_to(want)
	check(d < 0.5, "a new process resumes under the glass (%.2f m from where you saved)" % d)
	check(on_floor(), "standing on the hall's floor")
	check(glass() == str(expect["glass"]), "the same glass (%s, saved %s)" % [glass(), expect["glass"]])
	check(copies().size() == int(expect["copies"]), "the same desks (%d copies, saved %d)" % [copies().size(), int(expect["copies"])])
	var same: ScriptoriumCopy = null
	for c: ScriptoriumCopy in copies():
		if String(c.name) == str(expect["copy"]):
			same = c
	check(same != null and same.title() == str(expect["title"]), "the same copy at the same desk, in the same hand (%s)" % (same.title() if same != null else "missing"))
	check(same != null and same.body() == str(expect["body"]), "word for word")
	var life: Array[Node] = room().find_children("prop_life", "", true, false)
	await wait(0.3)
	check(not life.is_empty() and not (life[0] as ScriptoriumLife)._moss.is_empty(), "the moss breathes")
	game.map.open()
	await process_frame
	var m: MapCanvas = game.map.canvas
	check(game.map.is_open() and m.place_id == AREA_ID, "the map opens on %s" % AREA_ID)
	var sketch: Variant = null
	for s: Variant in m.rooms:
		if s.slot_id == SLOT:
			sketch = s
	check(sketch != null and sketch.floor_cells.size() > 0, "it draws the scriptorium")
	check(not m.you.is_empty(), "with you on it")
	game.map.close()


## A ray down from the player's feet meets the room (not a safety floor).
func on_floor() -> bool:
	var at: Vector3 = game.player.global_position + Vector3(0, 0.3, 0)
	var q := PhysicsRayQueryParameters3D.create(at, at + Vector3.DOWN * 1.2)
	q.exclude = [game.player.get_rid()]
	var hit: Dictionary = area.get_world_3d().direct_space_state.intersect_ray(q)
	var g: GeneratedRoom = room()
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
	print("r08_resume_test %s: %s (%d checks, %d failures)" % [mode, "PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	for f: String in failures:
		print("  FAIL ", f)
	if failures.is_empty() and game != null:
		game.save_and_quit()
	else:
		quit(1 if not failures.is_empty() else 0)

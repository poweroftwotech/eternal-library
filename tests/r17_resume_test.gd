extends SceneTree
## Phase 16 step 5: the Ossuary of Books in the real game, saved in one OS process
## and resumed in a fresh one (AGENTS.md: persistence gate).
##   godot --audio-driver Dummy --headless --path . --script res://tests/r17_resume_test.gd -- save --save=user://test/r17.json --fresh
##   godot --audio-driver Dummy --headless --path . --script res://tests/r17_resume_test.gd -- load --save=user://test/r17.json
## Both runs use area seed SEED with the live Mahaleh.
## save: walk to the shrine, light the candle, take a lore book, and quit through
##       the game's own save-and-quit.
## load: a new process resumes at the shrine with the candle still burning and the
##       book yours and gone from its niche. The map draws the passages. Then the
##       candle's time is run out: it goes out, and it can be lit again.

const SEED: int = 2
const SLOT: String = "ossuary_1"
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


func room() -> GeneratedRoom:
	return area.rooms.get(SLOT) as GeneratedRoom


func candle() -> ShrineCandle:
	var found: Array[Node] = room().find_children("*", "ShrineCandle", true, false)
	return found.front() as ShrineCandle if not found.is_empty() else null


func books() -> Array[WorldProp]:
	var out: Array[WorldProp] = []
	for n: Node in room().find_children("*", "WorldProp", true, false):
		if (n as WorldProp).item != null:
			out.append(n as WorldProp)
	return out


func expect_path() -> String:
	return "user://test/r17_expect.json"


func save_mode() -> void:
	for p: Vector3 in AreaTour.leg(area.plan, area.plan.room(SLOT)):
		game.player.teleport(area.to_global(p) + Vector3(0, 0.1, 0), 0.0)
		for _i: int in 4:
			await physics_frame
		await until(func() -> bool: return not area.streamer.busy())
	var g: GeneratedRoom = room()
	check(g != null, "the Ossuary is built when you reach it")
	if g == null:
		return
	game.player.teleport(g.to_global(g.grid.meta["chamber"] as Vector3) + Vector3(0, 0.1, 0), 0.0)
	await until(func() -> bool: return candle() != null and not books().is_empty())
	await wait(0.8)
	check(on_floor(), "in the chamber you stand on its floor")
	var c: ShrineCandle = candle()
	check(c != null and c.interaction_prompt(Vector3.ZERO) == "Light a candle", "the shrine offers a candle")
	if c == null or books().is_empty():
		check(false, "the room has its candle and a lore book")
		return
	c.interact(game.player, Vector3.ZERO)
	check(c.burning() > 0.99, "it burns once lit")
	var book: WorldProp = books().front()
	var what: StringName = book.item.id
	var left: int = books().size()
	book.interact(game.player, Vector3.ZERO)
	await process_frame
	var ws: Node = root.get_node("WorldState")
	check(bool(ws.call("owns", what)), "the book %s is yours" % what)
	var p: Vector3 = game.player.global_position
	var f := FileAccess.open(expect_path(), FileAccess.WRITE)
	f.store_string(JSON.stringify({"at": [p.x, p.y, p.z], "book": String(what), "books": left - 1}))
	f.close()


func load_mode() -> void:
	var expect: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(expect_path()))
	var want := Vector3(float(expect["at"][0]), float(expect["at"][1]), float(expect["at"][2]))
	await until(func() -> bool: return room() != null and candle() != null)
	await wait(0.8)
	var d: float = game.player.global_position.distance_to(want)
	check(d < 0.5, "a new process resumes at the shrine (%.2f m from where you saved)" % d)
	check(on_floor(), "standing on the chamber's floor")
	var ws: Node = root.get_node("WorldState")
	var c: ShrineCandle = candle()
	check(c != null and c.burning() > 0.9, "the candle still burns (%.2f)" % (c.burning() if c != null else -1.0))
	check(bool(ws.call("owns", StringName(expect["book"]))), "the book is still yours")
	var there: Array[String] = []
	for b: WorldProp in books():
		there.append(String(b.item.id))
	check(not there.has(str(expect["book"])), "it is gone from its niche (%s)" % [there])
	check(there.size() == int(expect["books"]), "the other books are left (%d of %d)" % [there.size(), int(expect["books"])])
	game.map.open()
	await process_frame
	var m: MapCanvas = game.map.canvas
	check(game.map.is_open() and m.place_id == AREA_ID, "the map opens on %s" % AREA_ID)
	var sketch: Variant = null
	for s: Variant in m.rooms:
		if s.slot_id == SLOT:
			sketch = s
	check(sketch != null and sketch.floor_cells.size() > 0, "it draws the Ossuary")
	check(not m.you.is_empty(), "with you on it")
	game.map.close()
	if c == null:
		return
	# Thirty minutes of play later.
	(ws.get("data") as Dictionary)["played_s"] = float(ws.call("played")) + ShrineCandle.BURN_S + 1.0
	await wait(ShrineCandle.TICK_S + 0.5)
	check(c.burning() == 0.0, "the candle burns out (%.2f)" % c.burning())
	check(c.interaction_prompt(Vector3.ZERO) == "Light a new candle", "a stub is left that can be lit again (%s)" % c.interaction_prompt(Vector3.ZERO))
	c.interact(game.player, Vector3.ZERO)
	check(c.burning() > 0.99, "and it can")


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
	print("r17_resume_test %s: %s (%d checks, %d failures)" % [mode, "PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	for f: String in failures:
		print("  FAIL ", f)
	if failures.is_empty() and game != null:
		game.save_and_quit()
	else:
		quit(1 if not failures.is_empty() else 0)

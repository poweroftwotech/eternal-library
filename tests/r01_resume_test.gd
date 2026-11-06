extends SceneTree
## The generated Reading Room in the real game, saved in one OS process and
## resumed in a fresh one (AGENTS.md: persistence gate).
##   godot --audio-driver Dummy --headless --path . --script res://tests/r01_resume_test.gd -- save --save=user://test/r01.json --draft=r01_wood
##   godot --audio-driver Dummy --headless --path . --script res://tests/r01_resume_test.gd -- load --save=user://test/r01.json --draft=r01_wood
## save: stand on the gallery deck, quit through the game's own save-and-quit.
## load: a new process stands on the deck of the same room, its style and
##       lore shelves as they were, and the map draws it.

const SEED: int = 3
const SLOT: String = "entrance"
const AREA: String = "grand_study"

var main_script: GDScript = load("res://scripts/main.gd")
var failures: PackedStringArray = []
var checks: int = 0
var game: Node
var area: Area
var draft: String = "r01_masonry"


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
		if a.begins_with("--draft="):
			draft = a.trim_prefix("--draft=")
	Area.seed_override = SEED
	root.get_node("/root/WorldState").set("walk_area", AREA)
	root.get_node("/root/WorldState").set("walk_recipe", "res://gen/recipes/drafts/%s/%s.tres" % [AREA, draft])
	if mode == "save":
		main_script.room_override = "area:" + AREA
	game = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	current_scene = game
	for _i: int in 12:
		await physics_frame
	area = game.world as Area
	check(area != null and area.recipe.id == AREA, "the game is in %s (%s)" % [AREA, game.world])
	if area == null:
		finish(mode)
		return
	await until(func() -> bool: return not area.streamer.busy() and area.rooms.has(SLOT))
	var g: GeneratedRoom = area.rooms.get(SLOT) as GeneratedRoom
	check(g != null and g.grammar is ReadingRoomGrammar, "the area's first room is a generated Reading Room")
	if g == null:
		finish(mode)
		return
	var want: int = 1 if draft.contains("wood") else 0
	check(int(area.plan.room(SLOT).style_overrides.get("gallery_build", -1)) == want, "its gallery is the version's build")
	for pin: LoreBookPin in g.lore_books:
		var s: VariantSocket = g.get_node_or_null(NodePath(pin.socket)) as VariantSocket
		check(s != null and g.generated_pins.has(pin.socket), "the lore shelf %s stands, pinned" % pin.socket)
	if mode == "save":
		game.player.teleport(g.to_global(Vector3(2, 4.1, -1)), PI)
		await wait(0.8)
		check(on_deck(g), "you stand on the gallery deck (at %s)" % g.to_local(game.player.global_position))
		var p: Vector3 = game.player.global_position
		var f := FileAccess.open("user://test/r01_expect.json", FileAccess.WRITE)
		f.store_string(JSON.stringify({"at": [p.x, p.y, p.z]}))
		f.close()
	else:
		var e: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("user://test/r01_expect.json"))
		await wait(0.5)
		var d: float = game.player.global_position.distance_to(Vector3(float(e["at"][0]), float(e["at"][1]), float(e["at"][2])))
		check(d < 0.5, "a new process resumes on the deck (%.2f m from where you saved)" % d)
		check(on_deck(g), "standing on the deck")
		game.map.open()
		await process_frame
		var c: MapCanvas = game.map.canvas
		var sketch: Variant = null
		for s: Variant in c.rooms:
			if s.slot_id == SLOT:
				sketch = s
		check(sketch != null, "the map draws the Reading Room")
		game.map.close()
	finish(mode)


func on_deck(g: GeneratedRoom) -> bool:
	var at: Vector3 = game.player.global_position + Vector3(0, 0.3, 0)
	var q := PhysicsRayQueryParameters3D.create(at, at + Vector3.DOWN * 1.2)
	q.exclude = [game.player.get_rid()]
	var hit: Dictionary = area.get_world_3d().direct_space_state.intersect_ray(q)
	return not hit.is_empty() and g.is_ancestor_of(hit["collider"] as Node)


func finish(mode: String) -> void:
	print("r01_resume_test %s: %d checks, %d failures" % [mode, checks, failures.size()])
	for f: String in failures:
		print("  FAIL ", f)
	if failures.is_empty() and game != null:
		game.save_and_quit()
	else:
		quit(1 if not failures.is_empty() else 0)


func wait(s: float) -> void:
	var stop_ms: int = Time.get_ticks_msec() + int(s * 1000.0)
	while Time.get_ticks_msec() < stop_ms:
		await physics_frame


func until(cond: Callable) -> void:
	var stop_ms: int = Time.get_ticks_msec() + 10000
	while not cond.call() and Time.get_ticks_msec() < stop_ms:
		await physics_frame

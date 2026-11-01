extends SceneTree
## Gate for phase 10 step 1 (docs/environment/phase-10-approval.md): a seed
## per world, and the Strata Board to look at.
##   godot --headless --path . --script res://tests/strata_board_test.gd
##   godot --path . --script res://tests/strata_board_test.gd -- capture=<png>   (GPU: the board as you'd see it)
##   ... -- seed_save <save>  then, a new process,  ... -- seed_load <save>        (the world seed survives a restart)
## Checks: the service's plan is the planner's own (same signature) for both
## interiors; the seed is the world seed's area seed; the per-rule counts
## add up to the rooms placed; the pipe to a separate planner process gives the
## same plan; recipes describe their entrance-only rooms (Q6); tests keep
## world seed 1, the player's slot rolls one, --world-seed and forget(n) set
## it; and the board itself plans, draws every room and rule, and sweeps 20
## seeds, each marked valid or not.

const Service: GDScript = preload("res://addons/strata_board/strata_service.gd")
const Board: GDScript = preload("res://addons/strata_board/strata_board.gd")
const Client: GDScript = preload("res://addons/strata_board/planner_client.gd")
const INTERIORS: Dictionary = {"library": "res://gen/recipes/library_wing.tres", "lower_stacks": "res://gen/recipes/lower_stacks.tres"}

var failures: PackedStringArray = []
var checks: int = 0


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures.append(what)


func run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() >= 2 and args[0] in ["seed_save", "seed_load"]:
		seed_process(args[0], args[1])
	else:
		var capture: String = ""
		for a: String in args:
			if a.begins_with("capture="):
				capture = a.trim_prefix("capture=")
		service()
		world_seed()
		await pipe()
		await board(capture)
	print("strata_board_test: %d checks, %d failures" % [checks, failures.size()])
	for f: String in failures:
		print("  FAIL ", f)
	quit(1 if not failures.is_empty() else 0)


func service() -> void:
	var st: Dictionary = Service.handle({"cmd": "stratum"})
	var ids: Array = (st["places"] as Array).map(func(p: Dictionary) -> String: return str(p["id"]))
	check(ids == ["camp", "gorge", "library", "lower_stacks"] and (st["links"] as Array).size() == 3,
		"the stratum has the camp, the Gorge and both interiors, and their 3 links (%s, %s)" % [ids, st["links"]])
	for id: String in INTERIORS:
		var recipe: AreaRecipe = load(INTERIORS[id])
		var desc: Dictionary = Service.handle({"cmd": "recipe", "path": INTERIORS[id]})
		var root: Dictionary = (desc["slots"] as Array)[0]
		check(bool(root["entrance_only"]), "%s: its entrance %s is marked entrance only (Q6)" % [id, root["slot_id"]])
		check((desc["slots"] as Array).slice(1).all(func(s: Dictionary) -> bool: return str(s["kind"]) == "scene" or not bool(s["entrance_only"])),
			"%s: no generated room is entrance only" % id)
		check((desc["grow"] as Array).size() == recipe.grow.size(), "%s: every grow rule is described" % id)
		for w: int in [1, 2, 3]:
			var answer: Dictionary = Service.handle({"cmd": "plan", "path": INTERIORS[id], "world_seed": w, "map_px": 0})
			var direct: AreaPlan = AreaPlanner.plan(recipe, AreaPlanner.area_seed_for(recipe, w))
			check(int(answer["area_seed"]) == AreaPlanner.area_seed_for(recipe, w), "%s world %d: the area seed is the world seed's" % [id, w])
			check(str(answer["signature"]) == direct.signature().sha256_text(), "%s world %d: the board's plan is the planner's own" % [id, w])
			check(bool(answer["valid"]) == direct.check().is_empty(), "%s world %d: valid exactly when the plan checks clean" % [id, w])
			var grown: int = 0
			for g: Dictionary in answer["stats"]["grow"]:
				grown += int(g["added"])
				check(int(g["tried"]) + int(g["taken"]) <= int(g["doors"]), "%s world %d: %s tried no more doors than it saw (%s)" % [id, w, g["prefix"], g])
			var required: int = (answer["rooms"] as Array).filter(func(r: Dictionary) -> bool: return bool(r["required"])).size()
			check(required + grown == (answer["rooms"] as Array).size(), "%s world %d: required + grown = %d rooms (%d + %d)" % [id, w, (answer["rooms"] as Array).size(), required, grown])
	# World 5 of the library wing grew a gallery through the Reading Room before
	# scene rooms blocked their own cells (phase 10 step 1).
	var w5: Dictionary = Service.handle({"cmd": "plan", "path": INTERIORS["library"], "world_seed": 5, "map_px": 0})
	check(bool(w5["valid"]), "library world 5: no grown room overlaps the Reading Room (%s)" % [w5["problems"]])


func world_seed() -> void:
	var ws: Node = root.get_node("/root/WorldState")
	check(int(ws.call("world_seed")) == 1, "a test run keeps world seed 1 (%d)" % int(ws.call("world_seed")))
	check(int(ws.call("new_world_seed")) == 1, "a new world in a test save is seed 1")
	var old_path: String = ws.get("path")
	ws.set("path", ws.get("DEFAULT_PATH"))
	var rolled: Dictionary = {}
	for i: int in 8:
		rolled[int(ws.call("new_world_seed"))] = true
	ws.set("path", old_path)
	check(rolled.size() > 1 and rolled.keys().all(func(s: int) -> bool: return s >= 1 and s <= 999999),
		"a new world in the player's own slot rolls a random seed in 1..999999 (%s)" % [rolled.keys()])
	ws.set("path", "user://test/strata_forget.json")
	ws.call("forget", 4242)
	check(int(ws.call("world_seed")) == 4242, "forget(4242) starts world 4242 (%d)" % int(ws.call("world_seed")))
	ws.call("forget")
	check(int(ws.call("world_seed")) == 1, "forget() in a test save starts world 1 again")
	ws.set("path", old_path)


## The same plan through the pipe to a separate headless planner process.
func pipe() -> void:
	var c: Node = Client.new()
	root.add_child(c)
	var got: Array = []
	var t0: int = Time.get_ticks_msec()
	c.call("request", {"cmd": "plan", "path": INTERIORS["lower_stacks"], "world_seed": 1, "map_px": 0}, func(a: Dictionary) -> void: got.append(a))
	while got.is_empty() and Time.get_ticks_msec() - t0 < 60000:
		await process_frame
	var direct: Dictionary = Service.handle({"cmd": "plan", "path": INTERIORS["lower_stacks"], "world_seed": 1, "map_px": 0})
	check(not got.is_empty() and str(got[0].get("signature", "")) == str(direct["signature"]),
		"the planner process gives the same plan as planning here (%s)" % [str(got[0]).left(200) if not got.is_empty() else "no answer in 60 s"])
	print("  planner process: first answer in %d ms" % (Time.get_ticks_msec() - t0))
	c.call("stop")
	c.queue_free()


func board(capture: String) -> void:
	if capture != "":
		root.size = Vector2i(1600, 1000)
	var b: Control = Board.new()
	b.set("local_planner", true)
	b.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(b)
	if not await until(func() -> bool: return not (b.get("plan") as Dictionary).is_empty(), 60.0):
		check(false, "the board planned its first seed within 60 s")
		return
	var plan: Dictionary = b.get("plan")
	var recipe: Dictionary = (b.get("recipes") as Dictionary)[str(b.get("area_id"))]
	check(str(b.get("area_id")) == "lower_stacks" and int(plan["world_seed"]) == 1, "the board opens on the Lower Stacks, world seed 1")
	var plan_view: Control = b.get("_plan_view")
	var recipe_view: Control = b.get("_recipe_view")
	await process_frame
	check((plan_view.get("placed") as Dictionary).size() == (plan["rooms"] as Array).size(), "the plan view draws every room (%d)" % (plan["rooms"] as Array).size())
	check((recipe_view.get("nodes") as Array).size() == (recipe["slots"] as Array).size() + (recipe["grow"] as Array).size(),
		"the recipe view draws every required room and grow rule")
	check(str((b.get("_plan_status") as RichTextLabel).text).contains("valid"), "the plan status says whether it's valid")
	var map_view: Control = b.get("_map")
	check((map_view.get("order") as Array).size() == (plan["rooms"] as Array).size() and (map_view.get("hits") as Array).size() == (plan["rooms"] as Array).reduce(func(n: int, r: Dictionary) -> int: return n + (r["floor"] as Array).size(), 0),
		"the top-down map draws every room, every cell clickable")
	b.call("select", {"panel": "plan", "id": "hall"})
	check((map_view.call("_lit") as Dictionary).keys() == ["hall"], "a room selected in the plan lights on the map")
	var cell: Rect2 = (map_view.get("hits") as Array).filter(func(h: Array) -> bool: return str(h[1]["id"]) == "gallery_1")[0][0]
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = cell.get_center()
	map_view.call("_gui_input", click)
	check(str((b.get("sel") as Dictionary).get("id", "")) == "gallery_1", "clicking a room on the map selects it")
	check(str(map_view.call("_get_tooltip", cell.get_center())).contains("gallery_1"), "hovering a room on the map names it")
	# Step to world seed 2 and back; select a grow rule (lights its rooms).
	b.call("set_world_seed", 2)
	await until(func() -> bool: return not (b.get("plan") as Dictionary).is_empty(), 30.0)
	check(int((b.get("plan") as Dictionary)["world_seed"]) == 2, "stepping the seed replans world 2")
	b.call("set_world_seed", 1)
	await until(func() -> bool: return not (b.get("plan") as Dictionary).is_empty(), 30.0)
	b.call("select", {"panel": "recipe", "id": "grow:lightwell"})
	check(str((b.get("_inspector") as RichTextLabel).text).contains("Light-Well"), "the inspector shows the selected grow rule")
	# The sweep.
	var t0: int = Time.get_ticks_msec()
	b.call("start_sweep")
	if not await until(func() -> bool: return (b.get("sweep_results") as Dictionary).size() == Board.SWEEP, 120.0):
		check(false, "the sweep planned 20 seeds within 120 s (%d)" % (b.get("sweep_results") as Dictionary).size())
		return
	var results: Dictionary = b.get("sweep_results")
	var valid: int = results.values().filter(func(r: Dictionary) -> bool: return bool(r["valid"])).size()
	check(results.keys().all(func(s: int) -> bool: return s >= 1 and s <= 20), "the sweep covers world seeds 1-20")
	var lower: AreaRecipe = load(INTERIORS["lower_stacks"])
	var same: bool = true
	for s: int in [1, 7, 20]:
		same = same and bool(results[s]["valid"]) == AreaPlanner.plan(lower, AreaPlanner.area_seed_for(lower, s)).check().is_empty()
	check(same, "the sweep's valid marks are the planner's checks")
	print("  sweep: 20 Lower Stacks worlds in %.1f s (one process), %d valid" % [(Time.get_ticks_msec() - t0) / 1000.0, valid])
	await process_frame
	await process_frame
	check(((b.get("_sweep_flow") as Node).get_child_count()) == Board.SWEEP, "the sweep shows 20 worlds")
	if capture != "":
		b.call("select", {"panel": "recipe", "id": "grow:upper"})
		for _i: int in 30:
			await process_frame
		var img: Image = root.get_texture().get_image()
		img.save_png(capture)
		print("  saved ", capture)
		# Scrolled down: the sweep.
		(b.find_children("*", "ScrollContainer", false, false)[0] as ScrollContainer).scroll_vertical = 100000
		for _i: int in 10:
			await process_frame
		var sweep_png: String = capture.get_basename() + "_sweep.png"
		root.get_texture().get_image().save_png(sweep_png)
		print("  saved ", sweep_png)
	b.queue_free()


## Waits (frames) until `cond` holds; false after `limit_s`.
func until(cond: Callable, limit_s: float) -> bool:
	var t0: int = Time.get_ticks_msec()
	while not cond.call():
		if Time.get_ticks_msec() - t0 > limit_s * 1000.0:
			return false
		await process_frame
	return true


## Persistence gate (AGENTS.md 6): a random world seed saved in one process is
## the seed a freshly launched one loads.
func seed_process(mode: String, save: String) -> void:
	var ws: Node = root.get_node("/root/WorldState")
	if mode == "seed_save":
		ws.set("path", save)
		ws.call("forget", ws.call("roll_world_seed"))
		ws.call("save_now")
		var f := FileAccess.open(save + ".seed", FileAccess.WRITE)
		f.store_string(str(int(ws.call("world_seed"))))
		f.close()
		print("  saved world seed %d" % int(ws.call("world_seed")))
		check(int(ws.call("world_seed")) >= 1, "a rolled seed")
	else:
		ws.set("path", save)
		check(bool(ws.call("load_save")), "the save loads")
		var want: int = FileAccess.get_file_as_string(save + ".seed").to_int()
		check(int(ws.call("world_seed")) == want, "a new process loads world seed %d (%d)" % [want, int(ws.call("world_seed"))])
		print("  loaded world seed %d" % int(ws.call("world_seed")))

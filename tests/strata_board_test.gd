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
var capture_path: String = ""     # capture=<png>: the board's pictures (GPU)
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
	elif args.has("edit"):
		edit()
	elif args.has("copies"):
		await copies()
	elif args.has("stratum"):
		for a: String in args:
			if a.begins_with("capture="):
				capture_path = a.trim_prefix("capture=")
		await stratum_plan()
	else:
		var capture: String = ""
		for a: String in args:
			if a.begins_with("capture="):
				capture = a.trim_prefix("capture=")
				capture_path = capture
		service()
		world_seed()
		edit()
		await pipe()
		await board(capture)
		await copies()
		await stratum_plan()
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
	await board_edit(b)
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
	await board_save(b)
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
		var first: AreaPlan = _plan_kept(ws)
		ws.call("save_now")
		var f := FileAccess.open(save + ".seed", FileAccess.WRITE)
		f.store_string(str(int(ws.call("world_seed"))))
		f.close()
		print("  saved world seed %d" % int(ws.call("world_seed")))
		check(int(ws.call("world_seed")) >= 1, "a rolled seed")
		check(first.variants.has("caravanserai"), "the plan records the caravanserai's variant")
		print("  kept %s" % str(ws.call("kept_variants", "lower_stacks")))
	else:
		ws.set("path", save)
		check(bool(ws.call("load_save")), "the save loads")
		var want: int = FileAccess.get_file_as_string(save + ".seed").to_int()
		check(int(ws.call("world_seed")) == want, "a new process loads world seed %d (%d)" % [want, int(ws.call("world_seed"))])
		print("  loaded world seed %d" % int(ws.call("world_seed")))
		# Q5: the recipe changed since (pinned to another variant); the save's room stays.
		var kept: Dictionary = ws.call("kept_variants", "lower_stacks")
		check(kept.has("caravanserai"), "a new process loads the kept variants (%s)" % str(kept))
		var recipe: AreaRecipe = (load(INTERIORS["lower_stacks"]) as AreaRecipe).duplicate(true)
		var court: AreaSlot = recipe.slots.filter(func(s: AreaSlot) -> bool: return s.slot_id == "caravanserai")[0]
		var other: int = (court.scene_choices.map(func(sc: PackedScene) -> String: return sc.resource_path).find(kept.get("caravanserai", "")) + 1) % court.scene_choices.size()
		court.pinned_choice = other
		var seed_value: int = AreaPlanner.area_seed_for(recipe, int(ws.call("world_seed")))
		var again: AreaPlan = AreaPlanner.plan(recipe, seed_value, kept)
		check(again.variants.get("caravanserai") == kept.get("caravanserai"), "the saved world keeps its caravanserai after the recipe pins another (%s)" % again.variants.get("caravanserai"))
		var fresh: AreaPlan = AreaPlanner.plan(recipe, seed_value)
		check(fresh.variants.get("caravanserai") == court.scene_choices[other].resource_path, "a new world takes the pinned one (%s)" % fresh.variants.get("caravanserai"))


## Plans the Lower Stacks of `ws`'s world as the game does (kept variants in,
## new ones recorded) and saves.
func _plan_kept(ws: Node) -> AreaPlan:
	var recipe: AreaRecipe = load(INTERIORS["lower_stacks"])
	var p: AreaPlan = AreaPlanner.plan(recipe, AreaPlanner.area_seed_for(recipe, int(ws.call("world_seed"))), ws.call("kept_variants", recipe.id))
	ws.call("keep_variants", recipe.id, p.variants, recipe.version)
	ws.call("save_now")
	return p


## Step 2: the board's edits. An unchanged description plans exactly as the
## file; edits to counts, depth, weights and the connection table do what
## they say; a save writes a recipe that plans as the edit did, raises the
## version when rooms move, and refuses when the file changed under it.
func edit() -> void:
	var cat: Dictionary = Service.handle({"cmd": "catalog"})
	var gtypes: Array = (cat["grammars"] as Array).map(func(g: Dictionary) -> String: return str(g["type"]))
	check(["R02", "R03", "R05", "R09", "R11"].all(func(t: String) -> bool: return gtypes.has(t)), "the catalog has every generated type (%s)" % [gtypes])
	var entrance: Dictionary = {}
	for s: Dictionary in cat["scenes"]:
		entrance[str(s["path"]).get_file()] = bool(s["entrance_only"])
	check(entrance.get("reading_room.tscn") == true and entrance.get("caravanserai_5x5.tscn") == true and entrance.get("stack_gallery_west_7.tscn") == false,
		"the catalog marks the entrance-only scenes (%s)" % [entrance])
	for id: String in INTERIORS:
		var recipe: AreaRecipe = load(INTERIORS[id])
		var desc: Dictionary = Service.handle({"cmd": "recipe", "path": INTERIORS[id]})
		var same: AreaRecipe = Service.build(desc)
		for w: int in [1, 2, 3]:
			var a: Dictionary = Service.handle({"cmd": "plan", "desc": desc, "world_seed": w, "map_px": 0})
			var direct: AreaPlan = AreaPlanner.plan(recipe, AreaPlanner.area_seed_for(recipe, w))
			check(str(a["signature"]) == direct.signature().sha256_text(), "%s world %d: an unedited description plans as the file" % [id, w])
		check(Service.moved(recipe, same, [1, 2, 3, 4, 5]).is_empty(), "%s: an unedited description moves nothing" % id)

	var ls: AreaRecipe = load(INTERIORS["lower_stacks"])
	var base: Dictionary = Service.handle({"cmd": "recipe", "path": INTERIORS["lower_stacks"]})
	# Fewer galleries: rooms move, and no rule places more than its maximum (Q4).
	var fewer: Dictionary = base.duplicate(true)
	(fewer["grow"][0] as Dictionary)["count"] = [1, 1]
	var moved: Array = Service.moved(ls, Service.build(fewer), range(1, 11))
	check(not moved.is_empty(), "one gallery instead of 3-5 moves rooms (in %s of worlds 1-10)" % [moved])
	for w: int in [1, 2, 3, 4]:
		var a: Dictionary = Service.handle({"cmd": "plan", "desc": fewer, "world_seed": w, "map_px": 0})
		var galleries: int = (a["rooms"] as Array).filter(func(r: Dictionary) -> bool: return str(r["grow"]) == "gallery").size()
		check(galleries <= 1, "world %d: a 1-1 gallery rule places at most one (%d), even when the area is short (Q4)" % [w, galleries])
	# A minimum depth no door reaches: none placed, and the counts say why.
	var deep: Dictionary = base.duplicate(true)
	(deep["grow"][2] as Dictionary)["min_depth"] = 40
	var d: Dictionary = Service.handle({"cmd": "plan", "desc": deep, "world_seed": 1, "map_px": 0})
	var st: Dictionary = (d["stats"]["grow"] as Array).filter(func(g: Dictionary) -> bool: return str(g["prefix"]) == str(deep["grow"][2]["prefix"]))[0]
	check(int(st["added"]) == 0 and int(st["near_entrance"]) > 0, "a rule 40 doors deep places nothing, for being near the entrance (%s)" % [st])
	# Weights: only the 3x3 court can come up in a new world; a saved world keeps its own (Q5).
	var heavy: Dictionary = base.duplicate(true)
	var court: Dictionary = heavy["slots"][0]
	court["weights"] = (court["scenes"] as Array).map(func(p: String) -> float: return 1.0 if p.ends_with("3x3.tscn") else 0.0)
	var courts: Dictionary = {}
	for w: int in range(1, 9):
		var a: Dictionary = Service.handle({"cmd": "plan", "desc": heavy, "world_seed": w, "map_px": 0})
		courts[str((a["rooms"] as Array)[0]["scene"]).get_file()] = true
	check(courts.keys() == ["caravanserai_3x3.tscn"], "weighted 1-0-0, every new world gets the 3x3 court (%s)" % [courts.keys()])
	check(Service.moved(ls, Service.build(heavy), range(1, 11)).is_empty(), "a weights change moves no room in a saved world (Q5)")
	# The connection table: galleries never off a hall or a gallery.
	var gtype: String = str(base["grow"][0]["type"])
	var never: Dictionary = {}
	for t: String in RoomTypes.NAMES:
		never["%s>%s" % [t, gtype]] = "never"
	var n: Dictionary = Service.handle({"cmd": "plan", "path": INTERIORS["lower_stacks"], "connections": never, "world_seed": 1, "map_px": 0})
	var ng: int = (n["rooms"] as Array).filter(func(r: Dictionary) -> bool: return str(r["type"]) == gtype and not bool(r["required"])).size()
	check(ng == 0, "with %s never joining anything, none are grown (%d)" % [gtype, ng])
	var after: Dictionary = Service.handle({"cmd": "plan", "path": INTERIORS["lower_stacks"], "world_seed": 1, "map_px": 0})
	check(str(after["signature"]) == AreaPlanner.plan(ls, AreaPlanner.area_seed_for(ls, 1)).signature().sha256_text(), "an unsaved table is forgotten after its plan")
	# Saving: to a scratch copy, never the game's file.
	var to: String = "user://test/strata_edit.tres"
	DirAccess.make_dir_recursive_absolute("user://test")
	var saved: Dictionary = Service.handle({"cmd": "save", "desc": fewer, "to": to, "mtime": int(base["mtime"])})
	check(int(saved.get("version", 0)) == int(base["version"]) + 1 and not (saved.get("moved", []) as Array).is_empty(),
		"a save that moves rooms raises the version (%d -> %s, moved in %s)" % [int(base["version"]), saved.get("version"), saved.get("moved")])
	var back: AreaRecipe = ResourceLoader.load(to, "", ResourceLoader.CACHE_MODE_IGNORE)
	check(back != null and back.grow[0].count == Vector2i(1, 1) and back.placement != null and back.atmosphere != null and back.slots[0].thresholds.size() == ls.slots[0].thresholds.size(),
		"the saved recipe has the edit and keeps placement, atmosphere and doors out")
	if back != null:
		check(AreaPlanner.plan(back, AreaPlanner.area_seed_for(back, 3)).signature() == AreaPlanner.plan(Service.build(fewer), AreaPlanner.area_seed_for(ls, 3)).signature(),
			"the saved recipe plans as the edit did")
	var same_save: Dictionary = Service.handle({"cmd": "save", "desc": base, "to": to, "mtime": 0})
	check(int(same_save.get("version", 0)) == int(base["version"]), "saving without a change keeps the version (%s)" % same_save.get("version"))
	var stale: Dictionary = Service.handle({"cmd": "save", "desc": base, "mtime": int(base["mtime"]) - 5})
	check(stale.has("conflict"), "a save refuses when the file changed since it was read (%s)" % [stale])
	var two_roots: Dictionary = base.duplicate(true)
	(two_roots["slots"][1] as Dictionary)["parent"] = ""
	check(Service.handle({"cmd": "save", "desc": two_roots, "to": to}).has("error"), "a recipe with two entrances isn't saved")
	check(ls.version == int(base["version"]) and FileAccess.get_modified_time(INTERIORS["lower_stacks"]) == int(base["mtime"]), "the game's recipe file is untouched")


## Step 2 on the board: edits mark the recipe unsaved, replan the edit, and
## keep what refers to a room or rule in step; Revert drops them.
func board_edit(b: Control) -> void:
	var planned: Callable = func() -> bool: return not (b.get("plan") as Dictionary).is_empty()
	var file_sig: String = str((b.get("plan") as Dictionary)["signature"])
	var form: Node = b.get("_form")
	b.call("select", {"panel": "recipe", "id": "grow:gallery"})
	await process_frame
	check(form.get_child_count() > 6, "the form edits the selected grow rule (%d rows)" % form.get_child_count())
	b.call("set_grow_field", "gallery", "count", [1, 1])
	check(bool(b.call("is_dirty", "lower_stacks")), "an edit marks the recipe unsaved")
	check((b.get("_walk_button") as Button).disabled and not (b.get("_save_button") as Button).disabled, "unsaved: Save on, Walk this seed off")
	check(int(b.get("sweep_base")) == 0, "an edit drops the (now stale) sweep")
	await until(planned, 30.0)
	var galleries: int = ((b.get("plan") as Dictionary)["rooms"] as Array).filter(func(r: Dictionary) -> bool: return str(r["grow"]) == "gallery").size()
	check(galleries <= 1, "the board plans the edit: one gallery at most (%d)" % galleries)
	var cistern: Dictionary = b.call("_grow_rule", "cistern")
	check((cistern["from"] as Array).has("gallery_1") and not (cistern["from"] as Array).has("gallery_2"), "a rule growing from the galleries follows their count (%s)" % [cistern["from"]])
	b.call("revert")
	check(not bool(b.call("is_dirty", "lower_stacks")), "Revert drops the edit")
	await until(planned, 30.0)
	check(str((b.get("plan") as Dictionary)["signature"]) == file_sig, "after Revert the plan is the file's again")
	# Rename the hall: what joins it and grows from it follows.
	b.call("set_slot_field", "hall", "slot_id", "nave")
	var joins_nave: bool = (b.get("recipes")["lower_stacks"]["slots"] as Array).any(func(s: Dictionary) -> bool: return str(s["parent"]) == "nave")
	var grows_nave: bool = (b.get("recipes")["lower_stacks"]["grow"] as Array).all(func(g: Dictionary) -> bool: return not (g["from"] as Array).has("hall"))
	check(grows_nave and (joins_nave or (b.get("recipes")["lower_stacks"]["slots"] as Array).size() == 2), "renaming a room renames it where rules grow from it")
	await until(planned, 30.0)
	check(not ((b.get("plan") as Dictionary)["rooms"] as Array).filter(func(r: Dictionary) -> bool: return str(r["slot_id"]) == "nave").is_empty(), "the renamed room is planned under its new id")
	b.call("revert")
	# Add a room off the entrance, then remove it.
	b.call("select", {})
	b.call("add_slot")
	var added: String = str((b.get("sel") as Dictionary).get("id", ""))
	check(added != "" and not (b.call("_slot", added) as Dictionary).is_empty(), "+ Required room adds one and selects it (%s)" % added)
	await process_frame
	check(((b.get("_recipe_view") as Control).get("nodes") as Array).any(func(n: Dictionary) -> bool: return str(n["id"]) == added), "the recipe graph draws it")
	await until(planned, 30.0)
	check(not (b.get("plan") as Dictionary).has("error"), "the board plans a recipe with an added room (%s)" % (b.get("plan") as Dictionary).get("error", ""))
	b.call("remove_slot", added)
	check(not bool(b.call("is_dirty", "lower_stacks")), "removing it again leaves the recipe as it was")
	# Order, entrance, connections.
	b.call("move_grow", "upper", -1)
	check(int((b.call("_grow_rule", "upper") as Dictionary)["order"]) == 2, "▲ runs a rule one earlier")
	b.call("revert")
	check(str(b.call("entrance_blocked", "hall")).contains("entrance only"), "an entrance-only entrance stays the entrance (Q6)")
	check(str(b.call("remove_blocked", "caravanserai")) != "", "the entrance can't be removed")
	b.call("set_connection", "R03", "R02", "never")
	check(bool(b.call("connections_dirty")), "a connection edit is unsaved")
	await until(planned, 30.0)
	var st: Dictionary = b.call("_grow_stats", "gallery")
	check(int(st.get("ruled_out", 0)) > 0 or int(st.get("added", 0)) == 0, "galleries never off a hall: doors ruled out (%s)" % [st])
	check(str((b.get("_plan_status") as RichTextLabel).text).contains("ruled out") or int(st.get("added", 0)) >= int(st.get("want", 0)), "the status says doors were ruled out")
	b.call("revert")
	check(not bool(b.call("connections_dirty")), "Revert drops the connection edit")
	# Leave a weights edit on show for the capture.
	b.call("select", {"panel": "recipe", "id": "caravanserai"})
	b.call("set_slot_field", "caravanserai", "weights", [1.0, 3.0, 1.0])
	(b.get("_conn_panel") as Control).visible = true
	b.call("_refresh")
	await until(planned, 30.0)


## Save on the board, to a scratch copy: the notice says what moved.
func board_save(b: Control) -> void:
	var mtime: int = FileAccess.get_modified_time(INTERIORS["lower_stacks"])
	b.call("revert")
	b.set("save_to", "user://test/strata_board_save.tres")
	b.call("set_grow_field", "gallery", "count", [1, 1])
	b.call("save")
	if not await until(func() -> bool: return not bool(b.call("is_dirty", "lower_stacks")), 120.0):
		check(false, "the board saved within 120 s (%s)" % b.get("notice"))
		return
	check(str(b.get("notice")).contains("version goes"), "the save notice says rooms moved and the version went up (%s)" % b.get("notice"))
	check(ResourceLoader.exists("user://test/strata_board_save.tres"), "the board wrote the recipe")
	check(FileAccess.get_modified_time(INTERIORS["lower_stacks"]) == mtime, "the game's recipe file is untouched")


## Named recipe copies: Save as copy, open, walk, Make live (the live recipe
## before kept as a copy), delete. All on scratch files: the copies folder and
## the live Lower Stacks recipe point under user://test/copies.
func copies() -> void:
	var scratch: String = "user://test/copies"
	_wipe(ProjectSettings.globalize_path(scratch))
	DirAccess.make_dir_recursive_absolute(scratch)
	var live: String = scratch + "/live_lower_stacks.tres"
	DirAccess.copy_absolute(ProjectSettings.globalize_path(INTERIORS["lower_stacks"]), ProjectSettings.globalize_path(live))
	var original: PackedByteArray = FileAccess.get_file_as_bytes(live)
	var real_mtime: int = FileAccess.get_modified_time(INTERIORS["lower_stacks"])
	Service.scratch(scratch + "/drafts", {"lower_stacks": live})
	var names: Callable = func() -> Array: return Service.drafts("lower_stacks").map(func(d: Dictionary) -> String: return str(d["name"]))

	var desc: Dictionary = Service.handle({"cmd": "recipe", "path": live, "fresh": true})
	var v0: int = int(desc["version"])
	check((names.call() as Array).is_empty(), "no copies to start with")
	for g: Dictionary in desc["grow"]:
		if str(g["prefix"]) == "gallery":
			g["count"] = [1, 1]
	var a: Dictionary = Service.handle({"cmd": "save", "desc": desc, "as": "Tight galleries!"})
	check(str(a.get("saved", "")) == scratch + "/drafts/lower_stacks/tight_galleries.tres", "Save as copy names the file from the name (%s)" % a.get("saved", a))
	check(int(a.get("version", -1)) == v0 and (a.get("moved", [1]) as Array).is_empty(), "saving a copy never raises a version")
	check(FileAccess.get_file_as_bytes(live) == original, "Save as copy leaves the live recipe alone")
	check(names.call() == ["tight galleries"], "the copy is listed (%s)" % [names.call()])
	check(str(Service.handle({"cmd": "save", "desc": desc, "as": "tight  galleries"}).get("error", "")).contains("already"), "a copy is never saved over another")
	check(Service.handle({"cmd": "save", "desc": desc, "as": "!!"}).has("error"), "a copy needs a usable name")
	var p: Dictionary = Service.handle({"cmd": "plan", "path": a.get("saved", ""), "world_seed": 1, "map_px": 0})
	check(not p.has("error") and (p["rooms"] as Array).filter(func(r: Dictionary) -> bool: return str(r["grow"]) == "gallery").size() <= 1, "the copy plans as edited")
	var st: Dictionary = Service.handle({"cmd": "stratum"})
	var place: Dictionary = (st["places"] as Array).filter(func(q: Dictionary) -> bool: return str(q["id"]) == "lower_stacks")[0]
	check((place["drafts"] as Array).size() == 1, "the stratum lists the area's copies")

	var ml: Dictionary = Service.handle({"cmd": "make_live", "path": a.get("saved", "")})
	check(not ml.has("error"), "Make live works (%s)" % ml.get("error", ""))
	check(int(ml.get("version", -1)) == v0 + 1 and not (ml.get("moved", []) as Array).is_empty(), "making the copy live raises the version: rooms move (%d → %s)" % [v0, ml.get("version")])
	var now: AreaRecipe = ResourceLoader.load(live, "", ResourceLoader.CACHE_MODE_IGNORE)
	check(now.version == v0 + 1 and now.grow.any(func(g: AreaGrow) -> bool: return g.slot_prefix == "gallery" and g.count == Vector2i(1, 1)), "the live recipe is now the copy")
	check(FileAccess.get_file_as_bytes(str(ml.get("kept", ""))) == original, "the live recipe before is kept as a copy, byte for byte")
	check(names.call() == ["live v%d before tight galleries" % v0, "tight galleries"], "both copies listed (%s)" % [names.call()])
	check(Service.handle({"cmd": "delete_draft", "path": live}).has("error"), "delete never touches a live recipe")
	var d: Dictionary = Service.handle({"cmd": "delete_draft", "path": a.get("saved", "")})
	check(not d.has("error") and names.call() == ["live v%d before tight galleries" % v0], "Delete removes just that copy (%s)" % [names.call()])

	await board_copies(scratch)
	Service.scratch("", {})
	check(FileAccess.get_modified_time(INTERIORS["lower_stacks"]) == real_mtime, "the game's own recipe file is untouched")
	check(not DirAccess.dir_exists_absolute(Service.DRAFTS + "/lower_stacks"), "nothing was written to the real copies folder")


func board_copies(scratch: String) -> void:
	var b: Control = Board.new()
	b.set("local_planner", true)
	b.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(b)
	var planned: Callable = func() -> bool: return not (b.get("plan") as Dictionary).is_empty()
	if not await until(planned, 60.0):
		check(false, "the board planned within 60 s")
		return
	var copy_path: String = scratch + "/drafts/lower_stacks/board_copy.tres"
	var copy_of: Callable = func() -> String: return str((b.get("open_copy") as Dictionary).get("lower_stacks", ""))
	var galleries: Callable = func() -> int: return ((b.get("plan") as Dictionary)["rooms"] as Array).filter(func(r: Dictionary) -> bool: return str(r["grow"]) == "gallery").size()
	var pick: OptionButton = b.get("_copy_pick")
	check(pick.item_count == 2 and (b.get("_make_live_button") as Button).disabled, "the copy picker shows Live and the one copy; Make live is off on Live (%d items)" % pick.item_count)
	b.call("set_grow_field", "gallery", "count", [2, 2])
	check(pick.disabled, "the picker is off while there are unsaved edits")
	b.call("save_as", "board copy")
	if not await until(func() -> bool: return copy_of.call() != "", 60.0):
		check(false, "Save as copy opened the new copy within 60 s (%s)" % b.get("notice"))
		return
	check(copy_of.call() == copy_path and not bool(b.call("is_dirty", "lower_stacks")), "Save as copy opens the copy, nothing unsaved")
	check(str((b.get("_crumb") as Label).text).contains("copy: board copy") and pick.item_count == 3, "the crumb names the copy; the picker lists it (%s, %d)" % [(b.get("_crumb") as Label).text, pick.item_count])
	await until(planned, 30.0)
	check(galleries.call() == 2, "the board plans the copy (2 galleries: %d)" % galleries.call())
	var walked: Array = []
	b.connect("walk_requested", func(id: String, s: int, recipe: String) -> void: walked.append([id, s, recipe]))
	(b.get("_walk_button") as Button).pressed.emit()
	check(walked.size() == 1 and str(walked[0][2]) == copy_path, "Walk this seed walks the open copy (%s)" % [walked])
	b.call("open_copy_at", "")
	await until(func() -> bool: return copy_of.call() == "" and (b.get("recipes") as Dictionary).has("lower_stacks") and planned.call(), 30.0)
	check(str((b.get("recipes") as Dictionary).get("lower_stacks", {}).get("path", "")) == INTERIORS["lower_stacks"], "Live opens the live recipe")
	b.call("open_copy_at", copy_path)
	await until(func() -> bool: return (b.get("recipes") as Dictionary).has("lower_stacks") and planned.call(), 30.0)
	check(not (b.get("_make_live_button") as Button).disabled, "Make live is on for a saved copy")
	b.call("make_live")
	if not await until(func() -> bool: return copy_of.call() == "", 60.0):
		check(false, "Make live finished within 60 s (%s)" % b.get("notice"))
		return
	check(str(b.get("notice")).contains("is live") and str(b.get("notice")).contains("kept as the copy"), "the notice says it's live and where the old recipe went (%s)" % b.get("notice"))
	var live: AreaRecipe = ResourceLoader.load(scratch + "/live_lower_stacks.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	check(live.grow.any(func(g: AreaGrow) -> bool: return g.slot_prefix == "gallery" and g.count == Vector2i(2, 2)), "the board's Make live wrote the live recipe")
	b.call("open_copy_at", copy_path)
	await until(func() -> bool: return (b.get("recipes") as Dictionary).has("lower_stacks"), 30.0)
	b.call("delete_copy")
	await until(func() -> bool: return copy_of.call() == "" and not FileAccess.file_exists(copy_path), 30.0)
	check(not FileAccess.file_exists(copy_path) and copy_of.call() == "", "Delete copy removes it and goes back to Live")
	b.queue_free()
	await process_frame


## The stratum plan (step 3): the game reads the places and links the code
## used to hold; then, all on scratch files (the stratum plan, the Gorge's
## recipe for its version, new recipes), an area is added behind a door place,
## the Gorge's network reaches its door and the layout places it, its door
## moves, and it's removed.
func stratum_plan() -> void:
	StratumPlan.drop_cache()
	var game_areas: int = SeamlessPlaces.recipes().size()
	check(SeamlessPlaces.recipes().get("gorge") == "res://gen/recipes/gorge.tres" and SeamlessPlaces.recipes().get("library") == "res://gen/recipes/library_wing.tres"
		and SeamlessPlaces.recipes().get("lower_stacks") == "res://gen/recipes/lower_stacks.tres", "the game's areas come from the stratum plan, as the code had them (%s)" % SeamlessPlaces.recipes())
	check(StratumPlan.current().triples().has(["gorge", "library", "door"]) and StratumPlan.current().triples().has(["gorge", "lower_stacks", "door"]),
		"the links come from the stratum plan, as the code had them (%s)" % [StratumPlan.current().triples()])
	check(SeamlessPlaces.links() == [["camp", "gorge", "corridor"]], "only the camp's corridor streams; every door travels (%s)" % [SeamlessPlaces.links()])
	var gorge: AreaRecipe = load(SeamlessPlaces.recipes()["gorge"])
	StratumPlan.current().apply_doors(gorge.network.frontage)
	check(gorge.network.frontage.slot("b2_l17_E_s1_2").door == "lower_stacks" and gorge.network.frontage.slot("b3_l18_W_s1_0").door == "library",
		"the Gorge's doors stand where the frontage had them")

	var scratch: String = "user://test/stratum"
	_wipe(ProjectSettings.globalize_path(scratch))
	DirAccess.make_dir_recursive_absolute(scratch)
	for f: String in ["stratum.tres", "gorge.tres"]:
		var src: String = StratumPlan.PATH if f == "stratum.tres" else SeamlessPlaces.recipes()["gorge"]
		DirAccess.copy_absolute(ProjectSettings.globalize_path(src), ProjectSettings.globalize_path(scratch + "/" + f))
	Service.scratch("", {"gorge": scratch + "/gorge.tres"}, scratch + "/stratum.tres", scratch + "/recipes")
	var real: Dictionary = {}
	for p: String in [StratumPlan.PATH, SeamlessPlaces.recipes()["gorge"], SeamlessPlaces.recipes()["lower_stacks"]]:
		real[p] = FileAccess.get_modified_time(p)
	# A door place for the test, if the frontage has no free one yet.
	var trial: FrontageSlot = null
	if gorge.network.frontage.slots.filter(func(s: FrontageSlot) -> bool: return s.door_place and s.door == "").is_empty():
		trial = gorge.network.frontage.slot("b1_l17_W_s2_0")
		trial.door_place = true
	var st: Dictionary = Service.handle({"cmd": "stratum"})
	var free: Array = (st["door_places"] as Array).filter(func(d: Dictionary) -> bool: return str(d["area"]) == "")
	check(not free.is_empty(), "the stratum lists the door places and which are free (%d)" % free.size())
	var at: String = str(free[0]["id"]) if not free.is_empty() else ""
	check(Service.handle({"cmd": "add_area", "name": "The Gorge", "from": "lower_stacks"}).has("error"), "an area can't take the Gorge's name")
	check(Service.handle({"cmd": "add_area", "name": "Dome", "from": "gorge"}).has("error"), "a new area can't start from the Gorge (it has no rooms to copy)")
	check(Service.handle({"cmd": "add_area", "name": "Dome", "from": "lower_stacks", "at": "b2_l17_E_s1_2"}).has("error"), "a door place another area has is refused")
	var a: Dictionary = Service.handle({"cmd": "add_area", "name": "The Dome Archive", "from": "lower_stacks", "at": at})
	check(str(a.get("added", "")) == "dome_archive", "add_area names the area from its name (%s)" % a.get("error", a.get("added", "")))
	var made: AreaRecipe = ResourceLoader.load(str(a.get("recipe_path", "")), "", ResourceLoader.CACHE_MODE_IGNORE) if a.has("recipe_path") else null
	check(made != null and made.id == "dome_archive" and made.display_name == "The Dome Archive" and made.version == 1 and made.slots.size() == load(SeamlessPlaces.recipes()["lower_stacks"]).slots.size(),
		"its recipe is the Lower Stacks' as a new file: its own id and name, version 1")
	check(str(a.get("recipe_path", "")).begins_with(scratch), "the new recipe went to the scratch folder")
	check(SeamlessPlaces.recipes().has("dome_archive") and StratumPlan.current().triples().has(["gorge", "dome_archive", "door"]) and StratumPlan.current().door_slot("dome_archive") == at,
		"the game's stratum now has it, behind its door place")
	check((a.get("gorge_version", []) as Array).size() == 2 and int(a["gorge_version"][1]) == int(a["gorge_version"][0]) + 1, "a new door raises the Gorge's version (%s)" % [a.get("gorge_version")])
	var reached: int = 0
	for w: int in [1, 2]:
		var gp: AreaPlan = AreaPlanner.plan(gorge, AreaPlanner.area_seed_for(gorge, w))
		if not gp.threshold("dome_archive").is_empty() and not gp.threshold("library").is_empty() and not gp.threshold("lower_stacks").is_empty():
			reached += 1
	check(reached == 2, "the Gorge's walkways reach the new door and the old ones (worlds 1-2: %d)" % reached)
	var lay: Dictionary = Service.handle({"cmd": "layout", "world_seed": 1})
	var dome: Array = (lay["areas"] as Array).filter(func(x: Dictionary) -> bool: return str(x["id"]) == "dome_archive")
	check(dome.size() == 1 and str(dome[0]["error"]) == "" and not (dome[0]["quads"] as Array).is_empty() and dome[0].has("door"), "from above, the new area stands at its door (%s)" % [dome[0]["error"] if not dome.is_empty() else "missing"])
	check(Service.handle({"cmd": "set_door", "area": "dome_archive", "at": "b3_l18_W_s1_0"}).has("error"), "moving a door onto another area's is refused")
	# The camp's back door (door travel, 2026-11-01).
	check((st["door_places"] as Array).any(func(d: Dictionary) -> bool: return str(d["id"]) == StratumPlan.CAMP_BACK_DOOR and bool(d.get("camp", false))), "the camp's back door is a door place")
	var c: Dictionary = Service.handle({"cmd": "set_door", "area": "dome_archive", "at": StratumPlan.CAMP_BACK_DOOR})
	check(not c.has("error") and StratumPlan.current().camp_back_area() == "dome_archive" and StratumPlan.current().door_slot("dome_archive") == StratumPlan.CAMP_BACK_DOOR,
		"set_door puts the area behind the camp's back door (%s)" % c.get("error", StratumPlan.current().door_slot("dome_archive")))
	check(StratumPlan.current().door_target("dome_archive", "gorge") == "camp" and StratumPlan.current().door_target("lower_stacks", "gorge") == "gorge",
		"its entrance (\"gorge\" in its recipe) now leads to the camp; the Lower Stacks' still to the Gorge")
	check((c.get("gorge_version", []) as Array).size() == 2, "taking a door out of the Gorge raises its version")
	var gp1: AreaPlan = AreaPlanner.plan(gorge, AreaPlanner.area_seed_for(gorge, 1))
	check(gp1.threshold("dome_archive").is_empty(), "the Gorge has no door to it any more")
	check(Service.handle({"cmd": "set_door", "area": "lower_stacks", "at": StratumPlan.CAMP_BACK_DOOR}).has("error"), "the camp's back door already taken is refused")
	var lay2: Dictionary = Service.handle({"cmd": "layout", "world_seed": 1})
	var dome2: Array = (lay2["areas"] as Array).filter(func(x: Dictionary) -> bool: return str(x["id"]) == "dome_archive")
	check(dome2.size() == 1 and str(dome2[0]["error"]) == "" and bool(dome2[0].get("camp", false)), "from above, it is listed as behind the camp's back door")
	check(not Service.handle({"cmd": "set_door", "area": "dome_archive", "at": at}).has("error") and StratumPlan.current().camp_back_area() == "", "and back to its Gorge door place")
	check(Service.handle({"cmd": "remove_area", "area": "gorge"}).has("error"), "the Gorge can't be removed")
	var r: Dictionary = Service.handle({"cmd": "remove_area", "area": "dome_archive"})
	check(not r.has("error") and not SeamlessPlaces.recipes().has("dome_archive") and FileAccess.file_exists(str(a.get("recipe_path", ""))),
		"remove_area takes it out of the stratum; its recipe file stays")
	await board_stratum(at)
	if trial != null:
		trial.door_place = false
	Service.scratch("", {})
	StratumPlan.drop_cache()
	for p: String in real:
		check(FileAccess.get_modified_time(p) == int(real[p]), "the game's own %s is untouched" % p.get_file())
	check(SeamlessPlaces.recipes().size() == game_areas, "back on the game's stratum plan")


## The stratum on the board: + Area, the door picker, from above, remove.
func board_stratum(at: String) -> void:
	var b: Control = Board.new()
	b.set("local_planner", true)
	b.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(b)
	if not await until(func() -> bool: return not (b.get("plan") as Dictionary).is_empty(), 60.0):
		check(false, "the board planned within 60 s")
		return
	var door_pick: OptionButton = b.get("_door_pick")
	var places_n: int = ((b.get("stratum") as Dictionary)["places"] as Array).size()
	check(door_pick.visible and str(door_pick.get_item_metadata(door_pick.selected)) == "b2_l17_E_s1_2", "the door picker shows the Lower Stacks' Gorge door")
	b.call("add_area", "Board Hall", "lower_stacks", at)
	if not await until(func() -> bool: return str(b.get("area_id")) == "board_hall" and (b.get("recipes") as Dictionary).has("board_hall") and not (b.get("plan") as Dictionary).is_empty(), 60.0):
		check(false, "+ Area opened the new area within 60 s (%s)" % b.get("notice"))
		return
	check(str(b.get("notice")).contains("Added board_hall") and str(b.get("notice")).contains("version goes"), "the notice says where it is and that the Gorge's version went up (%s)" % b.get("notice"))
	check(((b.get("stratum") as Dictionary)["places"] as Array).size() == places_n + 1 and str(door_pick.get_item_metadata(door_pick.selected)) == at, "the side-on view has it, and the door picker its door")
	check(bool((b.get("plan") as Dictionary).get("valid", false)), "the new area plans valid for world seed 1, as the recipe it copied")
	b.call("plan_top")
	if not await until(func() -> bool: return not (b.get("top") as Dictionary).is_empty(), 90.0):
		check(false, "the view from above came within 90 s")
		return
	var top: Dictionary = b.get("top")
	check((top["areas"] as Array).any(func(x: Dictionary) -> bool: return str(x["id"]) == "board_hall" and str(x["error"]) == ""), "from above, the board places the new area")
	check((b.get("_top_view") as Control).visible and str((b.get("_top_status") as Label).text).begins_with("World seed 1"), "the view from above shows, with what overlaps (%s)" % (b.get("_top_status") as Label).text)
	await process_frame
	if capture_path != "":
		for _i: int in 30:
			await process_frame
		root.get_viewport().get_texture().get_image().save_png(capture_path.get_basename() + "_stratum.png")
	b.call("remove_area")
	await until(func() -> bool: return str(b.get("area_id")) != "board_hall" and ((b.get("stratum") as Dictionary)["places"] as Array).size() == places_n, 60.0)
	check(((b.get("stratum") as Dictionary)["places"] as Array).size() == places_n and str(b.get("notice")).contains("Took"), "Remove area takes it out and opens another (%s)" % b.get("notice"))
	b.queue_free()
	await process_frame


func _wipe(dir: String) -> void:
	if not DirAccess.dir_exists_absolute(dir):
		return
	for sub: String in DirAccess.get_directories_at(dir):
		_wipe(dir.path_join(sub))
	for f: String in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))
	DirAccess.remove_absolute(dir)

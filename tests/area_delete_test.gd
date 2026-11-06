extends SceneTree
## Areas can come and go (the themed-areas rework, 2026-11-05). Nothing here
## touches the live files: the stratum and new recipes go to user://test/.
##   godot --headless --audio-driver Dummy --path . --script res://tests/area_delete_test.gd
## Checks: a recipe that's gone is left out of the stratum; a rule shared between
## areas survives losing one; a copy of a recipe keeps its shared rooms; with
## every interior removed a new area starts from just a room, valid and with
## its door back; a recipe that names no door of its entrance still gets one.

const Service: GDScript = preload("res://addons/strata_board/strata_service.gd")
const DIR: String = "user://test/area_delete"

var failures: PackedStringArray = []
var checks: int = 0


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures.append(what)


func run() -> void:
	DirAccess.make_dir_recursive_absolute(DIR + "/recipes")
	for f: String in DirAccess.get_files_at(DIR + "/recipes"):
		DirAccess.remove_absolute(DIR + "/recipes/" + f)
	var live: StratumPlan = load(StratumPlan.PATH)
	var gorge: String = DIR + "/gorge.tres"
	var out := FileAccess.open(gorge, FileAccess.WRITE)
	out.store_string(FileAccess.get_file_as_string(live.path_of("gorge")))
	out.close()
	# Just the camp and the Gorge: the test makes its own areas, so it holds
	# whatever the live stratum has in it.
	var plan: StratumPlan = live.duplicate(true)
	plan.places = plan.places.filter(func(p: Dictionary) -> bool: return str(p["id"]) in ["camp", "gorge"])
	plan.links = plan.links.filter(func(l: Dictionary) -> bool: return str(l["kind"]) == StratumPlan.CORRIDOR)
	ResourceSaver.save(plan, DIR + "/stratum.tres")
	Service.scratch(DIR + "/drafts", {"gorge": gorge}, DIR + "/stratum.tres", DIR + "/recipes")
	# The one interior the rest start from, with a rule shared with an area long gone.
	var first: Dictionary = Service.add_area("First", "room:res://gen/grammars/r03_hypostyle.tres", "")
	var seed_recipe: AreaRecipe = load(str(first.get("recipe_path", "")))
	var seed_rule := AreaGrow.new()
	seed_rule.grammar = load("res://gen/grammars/r02_stack_gallery.tres")
	seed_rule.slot_prefix = "shared"
	seed_rule.one_of = PackedStringArray(["first", "no_such_area"])
	seed_recipe.grow.append(seed_rule)
	ResourceSaver.save(seed_recipe, str(first.get("recipe_path", "")))

	# A recipe that's gone is left out, not a crash.
	var gone: StratumPlan = live.duplicate(true)
	gone.places.append({"id": "lost", "path": "res://gen/recipes/no_such_area.tres"})
	check(not gone.recipes().has("lost"), "a recipe file that's gone is left out of the stratum")

	# A rule shared between areas, with one of them gone.
	var shared := AreaGrow.new()
	shared.slot_prefix = "shared"
	shared.one_of = PackedStringArray(["first", "no_such_area"])
	var kept: bool = true
	for w: int in range(1, 41):
		kept = kept and AreaPlanner.one_of_pick(shared, w) == "first"
	check(kept, "a shared rule always picks the area still in the stratum")
	shared.one_of = PackedStringArray(["no_such_area"])
	check(AreaPlanner.one_of_pick(shared, 1) == "", "a shared rule whose areas are all gone picks none")

	# A copy keeps its shared rooms.
	var copied: Dictionary = Service.add_area("A Copy", "first", "")
	check(not copied.has("error"), "a copy of an interior is added: %s" % copied.get("error", ""))
	var copy: AreaRecipe = ResourceLoader.load(str(copied.get("recipe_path", "")), "", ResourceLoader.CACHE_MODE_IGNORE)
	check(copy != null and copy.grow.all(func(g: AreaGrow) -> bool: return g.one_of.is_empty()), "a copy's rules aren't shared with areas that don't name it")

	# Every interior out, then start again from a room.
	for id: String in StratumPlan.current().recipes().keys():
		if id != "gorge":
			check(not Service.remove_area(id).has("error"), "%s is removed" % id)
	check(StratumPlan.current().triples().size() == 1, "only the camp-Gorge corridor is left")
	check(Service.add_area("Nothing To Copy", "", "").has("error"), "a new area needs something to start from")
	check((Service.stratum()["spare"] as Array).size() == 2, "a removed area's recipe can be started from")
	for start: Array in [["From A Grammar", "room:res://gen/grammars/r03_hypostyle.tres", ""], ["From A Scene", "room:res://rooms/baked/caravanserai_5x5.tscn", ""], ["From The Reading Room", "room:res://rooms/authored/reading_room.tscn", ""],
			["Behind The Camp", "room:res://gen/grammars/r07_garden.tres", StratumPlan.CAMP_BACK_DOOR]]:
		var added: Dictionary = Service.add_area(start[0], start[1], start[2])
		check(not added.has("error"), "%s is added: %s" % [start[0], added.get("error", "")])
		var r: AreaRecipe = ResourceLoader.load(str(added.get("recipe_path", "")), "", ResourceLoader.CACHE_MODE_IGNORE)
		if r == null:
			continue
		var p: AreaPlan = AreaPlanner.plan_world(r, 3)
		check(p.errors.is_empty() and p.check().is_empty(), "%s plans clean: %s %s" % [start[0], p.errors, p.check()])
		check(not p.threshold("gorge").is_empty(), "%s has its door back" % start[0])

	# A gallery has one exit: its door back must not take it.
	var gal: Dictionary = Service.add_area("A Gallery", "room:res://gen/grammars/r02_stack_gallery.tres", "")
	var gr: AreaRecipe = ResourceLoader.load(str(gal.get("recipe_path", "")), "", ResourceLoader.CACHE_MODE_IGNORE)
	var rule := AreaGrow.new()
	rule.grammar = load("res://gen/grammars/r03_hypostyle.tres")
	rule.slot_prefix = "hall"
	rule.count = Vector2i(1, 1)
	gr.grow.append(rule)
	var grew: int = 0
	for w: int in range(1, 11):
		var gp: AreaPlan = AreaPlanner.plan_world(gr, w)
		check(not gp.threshold("gorge").is_empty() and gp.threshold("gorge")[1] == &"SNAP_exit_0_0_0_S", "a generated entrance's door back is at its start (world %d)" % w)
		grew += 1 if gp.rooms.size() > 1 else 0
	check(grew >= 8, "rooms grow from a gallery entrance (%d of 10 worlds)" % grew)

	# An entrance whose recipe names doors it doesn't have.
	var wrong: AreaRecipe = ResourceLoader.load(DIR + "/recipes/from_a_scene.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	wrong.slots[0].thresholds = {&"SNAP_no_such_door": "gorge"}
	check(not AreaPlanner.plan_world(wrong, 3).threshold("gorge").is_empty(), "an entrance that doesn't have the door its recipe names still gets one")

	Service.scratch("", {})
	if failures.is_empty():
		print("area_delete_test: PASS (%d checks)" % checks)
		quit(0)
	else:
		for f: String in failures:
			printerr("FAIL: " + f)
		print("area_delete_test: FAIL (%d of %d)" % [failures.size(), checks])
		quit(1)

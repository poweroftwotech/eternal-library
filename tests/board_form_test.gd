extends SceneTree
## The Strata Board's edit form follows the selection (2026-11-05). Works on
## its own area in user://test/, whatever the live stratum holds.
##   godot --headless --audio-driver Dummy --path . --script res://tests/board_form_test.gd
## Checks: with a field in the form in use, picking another room shows that
## room's values, and what was typed went to the room it was typed for; the
## area's settings are there whatever is selected.

const Service: GDScript = preload("res://addons/strata_board/strata_service.gd")
const Board: GDScript = preload("res://addons/strata_board/strata_board.gd")
const DIR: String = "user://test/board_form"

var failures: PackedStringArray = []
var checks: int = 0


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures.append(what)


func first_field(b: Control) -> LineEdit:
	var form: Node = b.get("_form")
	var fields: Array = form.find_children("*", "LineEdit", true, false)
	return fields[0] as LineEdit if not fields.is_empty() else null


func has_label(b: Control, text: String) -> bool:
	var form: Node = b.get("_form")
	return form.find_children("*", "Label", true, false).any(func(l: Label) -> bool: return l.text == text)


func run() -> void:
	DirAccess.make_dir_recursive_absolute(DIR + "/recipes")
	for f: String in DirAccess.get_files_at(DIR + "/recipes"):
		DirAccess.remove_absolute(DIR + "/recipes/" + f)
	var live: StratumPlan = load(StratumPlan.PATH)
	var gorge: String = DIR + "/gorge.tres"
	var out := FileAccess.open(gorge, FileAccess.WRITE)
	out.store_string(FileAccess.get_file_as_string(live.path_of("gorge")))
	out.close()
	var plan: StratumPlan = live.duplicate(true)
	plan.places = plan.places.filter(func(p: Dictionary) -> bool: return str(p["id"]) in ["camp", "gorge"])
	plan.links = plan.links.filter(func(l: Dictionary) -> bool: return str(l["kind"]) == StratumPlan.CORRIDOR)
	ResourceSaver.save(plan, DIR + "/stratum.tres")
	Service.scratch(DIR + "/drafts", {"gorge": gorge}, DIR + "/stratum.tres", DIR + "/recipes")
	var added: Dictionary = Service.add_area("Form Test", "room:res://gen/grammars/r02_stack_gallery.tres", "")
	var recipe: AreaRecipe = load(str(added["recipe_path"]))
	recipe.slots[0].display_name = "Alpha"
	var rule := AreaGrow.new()
	rule.grammar = load("res://gen/grammars/r03_hypostyle.tres")
	rule.slot_prefix = "hall"
	rule.display_name = "Beta"
	recipe.grow.append(rule)
	ResourceSaver.save(recipe, str(added["recipe_path"]))

	var b: Control = Board.new()
	b.set("local_planner", true)
	b.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(b)
	for i: int in 1200:
		await process_frame
		if not (b.get("plan") as Dictionary).is_empty() and not (b.get("catalog") as Dictionary).is_empty():
			break
	check(str(b.get("area_id")) == "form_test", "the board opens on the only interior")
	check(has_label(b, "AREA"), "the area's settings show with nothing selected")

	b.call("select", {"panel": "recipe", "id": "entrance"})
	await process_frame
	var field: LineEdit = first_field(b)
	check(field != null and field.text == "Alpha", "the form shows the selected room")
	check(has_label(b, "AREA"), "the area's settings show with a room selected")
	field.grab_focus()
	field.text = "Typed"
	await process_frame
	check(b.get_viewport().gui_get_focus_owner() == field, "the field is in use")

	# A click on the canvas: select(), focus left where it was.
	b.call("select", {"panel": "recipe", "id": "grow:hall"})
	await process_frame
	await process_frame
	var next: LineEdit = first_field(b)
	check(next != null and next.text == "Beta", "picking another room shows its values (shows %s)" % (next.text if next != null else "nothing"))
	check(has_label(b, "AREA"), "the area's settings show with a rule selected")
	var slots: Array = (b.get("recipes") as Dictionary)["form_test"]["slots"]
	check(str(slots[0]["display_name"]) == "Typed", "what was typed went to the room it was typed for")
	var grows: Array = (b.get("recipes") as Dictionary)["form_test"]["grow"]
	check(str(grows[0]["display_name"]) == "Beta", "the room picked next is untouched")

	b.call("select", {})
	await process_frame
	check(has_label(b, "AREA"), "the area's settings show after clearing the selection")

	# No two grammars read the same in the type pickers.
	var labels: Dictionary = {}
	for g: Dictionary in (b.get("catalog") as Dictionary)["grammars"]:
		labels[b.call("_grammar_label", g)] = true
	check(labels.size() == ((b.get("catalog") as Dictionary)["grammars"] as Array).size(), "each grammar has its own name in the pickers: %s" % [labels.keys()])

	# What generation needs reaches the saved recipe, and a new area starts with it.
	var desc: Dictionary = (b.get("recipes") as Dictionary)["form_test"]
	check(str(desc["atmosphere"]) != "", "a new area has an atmosphere")
	check(float((desc["envelope"] as Array)[4]) == 48.0, "a new area has room for tall rooms")
	check(((b.get("catalog") as Dictionary)["atmospheres"] as Array).size() >= 2, "the board lists the atmospheres")
	b.call("set_area_field", "atmosphere", "")
	b.call("set_area_field", "fall_limit", -30.0)
	b.call("set_area_field", "open_sight", true)
	var env: Array = (desc["envelope"] as Array).duplicate()
	env[4] = 60.0
	b.call("set_area_field", "envelope", env)
	b.call("set_grow_field", "hall", "one_of", ["form_test", "elsewhere"])
	b.call("set_slot_field", "entrance", "seed_mode", "fixed")
	var built: AreaRecipe = Service.build((b.get("recipes") as Dictionary)["form_test"])
	check(built.atmosphere == null and built.fall_limit == -30.0 and built.open_sight, "atmosphere, fall limit and open cavern are built")
	check(built.placement.envelope.size.y == 60.0 and recipe.placement.envelope.size.y == 48.0, "the build space changes the copy, not the saved recipe")
	check(Array(built.grow[0].one_of) == ["form_test", "elsewhere"], "a shared rule is built")

	# A rule can grow from its own rooms as well as from others.
	b.call("set_grows_from", "hall", "entrance", true)
	b.call("set_grows_from", "hall", "grow:hall", true)
	var from: Array = (b.call("_grow_rule", "hall") as Dictionary)["from"]
	check(from.has("entrance") and from.has("hall_1"), "Itself adds the rule's own rooms beside the others (%s)" % [from])
	b.call("set_grow_field", "hall", "count", [1, 6])
	from = (b.call("_grow_rule", "hall") as Dictionary)["from"]
	check(from.has("hall_6"), "Itself reaches every room when the count grows (%s)" % [from])
	b.call("set_grows_from", "hall", "grow:hall", false)
	from = (b.call("_grow_rule", "hall") as Dictionary)["from"]
	check(from == ["entrance"], "Itself turns off again (%s)" % [from])
	b.call("set_grows_from", "hall", "*", true)
	check(built.slots[0].seed_mode == AreaSlot.SeedMode.FIXED, "a fixed seed is built")

	# A room's own settings: on the form for stack galleries, built when changed, gone when blanked.
	b.call("select", {"panel": "recipe", "id": "entrance"})
	await process_frame
	await process_frame
	check(has_label(b, "Bays to abandoned"), "a stack gallery shows its own settings")
	b.call("set_tweak", b.call("_slot", "entrance"), "length", "short")
	b.call("set_tweak", b.call("_slot", "entrance"), "decay", 2.0)
	var tweaked: AreaRecipe = Service.build((b.get("recipes") as Dictionary)["form_test"])
	check(str(tweaked.slots[0].tweaks.get("length", "")) == "short" and float(tweaked.slots[0].tweaks.get("decay", 0.0)) == 2.0, "a room's settings are built")
	b.call("set_tweak", b.call("_slot", "entrance"), "decay", "")
	check(not (b.call("_slot", "entrance")["tweaks"] as Dictionary).has("decay"), "a blanked setting goes back to the default")
	b.call("select", {"panel": "recipe", "id": "grow:hall"})
	await process_frame
	await process_frame
	check(not has_label(b, "Bays to abandoned"), "a hall has no stacks settings")

	b.queue_free()
	await process_frame
	Service.scratch("", {})
	if failures.is_empty():
		print("board_form_test: PASS (%d checks)" % checks)
		quit(0)
	else:
		for f: String in failures:
			printerr("FAIL: " + f)
		print("board_form_test: FAIL (%d of %d)" % [failures.size(), checks])
		quit(1)

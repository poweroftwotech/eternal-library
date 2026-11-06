extends SceneTree
## Per-room stacks settings (AreaSlot.tweaks, AreaGrow.tweaks,
## StackGalleryGrammar.tweaked).
##   godot --headless --audio-driver Dummy --path . --script res://tests/r02_tweaks_test.gd
## Checks: no settings leave a room's plan as it was; each length keeps its
## bays in range and stays an R02 on the board; Starts at, the pace, blue,
## fog and decay reach only the room asked for; settings survive a save.
## Leaves user://test/r02_tweaks/stacks_<length>.tres for area_route_test recipe=.

const Service: GDScript = preload("res://addons/strata_board/strata_service.gd")
const DIR: String = "user://test/r02_tweaks"
const SEEDS: int = 12

var failures: PackedStringArray = []
var checks: int = 0


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures.append(what)


## An area of its own (the live recipes change): a hall with four galleries
## grown off it, `tweaks` on their rule.
func with_tweaks(tweaks: Dictionary) -> AreaRecipe:
	var r: AreaRecipe = base_recipe()
	var hall := AreaSlot.new()
	hall.slot_id = "entrance"
	hall.grammar = load("res://gen/grammars/r03_hypostyle.tres")
	r.slots = [hall] as Array[AreaSlot]
	var rule := AreaGrow.new()
	rule.grammar = load("res://gen/grammars/r02_stack_gallery.tres")
	rule.slot_prefix = "stacks"
	rule.count = Vector2i(4, 4)
	rule.tweaks = tweaks
	r.grow = [rule] as Array[AreaGrow]
	return r


func base_recipe() -> AreaRecipe:
	var r := AreaRecipe.new()
	r.id = "tweak_test"
	r.room_count = Vector2i(1, 20)
	r.max_sight_depth = 4
	r.placement = AreaPlacement.new()
	r.placement.envelope = AABB(Vector3(-300, -24, -300), Vector3(600, 48, 600))
	return r


func galleries(p: AreaPlan) -> Array[AreaPlan.Room]:
	var out: Array[AreaPlan.Room] = []
	for r: AreaPlan.Room in p.rooms:
		if r.slot_id.begins_with("stacks_"):
			out.append(r)
	return out


func signature(p: AreaPlan) -> String:
	var parts: PackedStringArray = []
	for r: AreaPlan.Room in p.rooms:
		parts.append("%s@%d:%s:%s" % [r.slot_id, r.seed_value, r.xf.origin, r.grid.cells.size() if r.grid != null else 0])
	return ",".join(parts)


func run() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	var plain: AreaRecipe = with_tweaks({})
	var stock: StackGalleryGrammar = load("res://gen/grammars/r02_stack_gallery.tres")
	check(stock.tweaked({}) == stock, "no settings: the shared grammar itself, no copy")

	var blank: AreaRecipe = with_tweaks({})
	for s: int in range(1, SEEDS + 1):
		check(signature(AreaPlanner.plan(plain, s)) == signature(AreaPlanner.plan(blank, s)), "seed %d: blank settings plan the same" % s)

	for length: String in ["short", "medium"]:
		var want: Vector2i = StackGalleryGrammar.LENGTHS[length]
		var recipe: AreaRecipe = with_tweaks({"length": length})
		var seen: int = 0
		var longest: int = 0
		for s: int in range(1, SEEDS + 1):
			var p: AreaPlan = AreaPlanner.plan(recipe, s)
			check(p.errors.is_empty(), "%s seed %d plans: %s" % [length, s, p.errors])
			for r: AreaPlan.Room in galleries(p):
				var bays: int = r.grid.run_order().size()
				seen += 1
				longest = maxi(longest, bays)
				check(bays >= want.x and bays <= want.y, "%s %s seed %d: %d bays, want %s" % [length, r.slot_id, s, bays, want])
				check(r.room_type == "R02", "%s %s: still a stack gallery (%s)" % [length, r.slot_id, r.room_type])
				check(r.grammar.source_path() == stock.resource_path, "%s %s: the board still finds its grammar" % [length, r.slot_id])
		check(seen > 0, "%s: galleries were grown" % length)
		print("%s: %d galleries over %d seeds, longest %d bays" % [length, seen, SEEDS, longest])
		var at: String = DIR + "/stacks_%s.tres" % length
		recipe.take_over_path(at)
		check(ResourceSaver.save(recipe, at) == OK, "%s saves" % length)
		var back: AreaRecipe = ResourceLoader.load(at, "", ResourceLoader.CACHE_MODE_IGNORE)
		check(str(Service.describe(back)["grow"].filter(func(g: Dictionary) -> bool: return g["prefix"] == "stacks")[0]["tweaks"].get("length", "")) == length, "%s survives a save" % length)
	check(stock.min_bays == 6 and stock.max_bays == 12, "the shared grammar is untouched")

	var fixed: AreaRecipe = with_tweaks({"abandon_start": 0.8, "abandon_over_bays": 5})
	for s: int in range(1, 5):
		for r: AreaPlan.Room in galleries(AreaPlanner.plan(fixed, s)):
			var first: Vector3i = r.grid.run_order()[0]
			check(is_equal_approx(float(r.grid.cells[first]["abandon"]), 0.8), "%s seed %d starts at 0.8" % [r.slot_id, s])
			check(float(r.grid.meta["abandon_end"]) == 1.0, "%s seed %d reaches abandoned at the faster pace" % [r.slot_id, s])

	var g: StackGalleryGrammar = stock.tweaked({"tint": 0.0, "tint_from": 0.5, "ground_fog_from": 0.2, "decay": 0.0})
	check(g != stock and g.mood_tint.a == 0.0 and g.tint_from == 0.5 and g.ground_fog_from == 0.2, "blue and fog apply")
	check(g.fill_colour_far == stock.fill_colour, "no blue: the fills lose theirs too")
	check(g.rock_breach_chance == 0.0 and g.puddle_chance == 0.0 and g.cobweb_chance == 0.0 and g.roots_chance == 0.0, "decay 0 clears rock, puddles, webs and roots")
	check(is_equal_approx(stock.tweaked({"decay": 2.0}).rock_breach_chance, stock.rock_breach_chance * 2.0), "decay scales")

	# A required room on a generated parent: its named door moves with the seed.
	var moved: AreaRecipe = base_recipe()
	var gallery := AreaSlot.new()
	gallery.slot_id = "entrance"
	gallery.grammar = stock
	gallery.tweaks = {"length": "medium"}
	var joined := AreaSlot.new()
	joined.slot_id = "joined_hall"
	joined.grammar = load("res://gen/grammars/r03_hypostyle.tres")
	joined.parent = "entrance"
	joined.connector = &"SNAP_exit_no_such_door"
	moved.slots = [gallery, joined] as Array[AreaSlot]
	var used: Dictionary = {}
	for s: int in range(1, 41):
		var p: AreaPlan = AreaPlanner.plan_world(moved, s)
		var hall: AreaPlan.Room = p.room("joined_hall")
		check(p.errors.is_empty(), "world %d: a required room finds a door: %s" % [s, p.errors])
		check(hall != null, "world %d: the required room is there" % s)
		if hall != null:
			used[hall.parent_connector] = true
			check(hall.parent_connector != &"SNAP_exit_0_0_0_S", "world %d: the way out stays free" % s)
	check(used.size() > 1, "the door moves with the seed")
	var fixed_parent: AreaRecipe = (load("res://gen/recipes/library_wing.tres") as AreaRecipe).duplicate(false)
	var slots: Array[AreaSlot] = fixed_parent.slots.duplicate()
	var wrong: AreaSlot = slots[1].duplicate(false)
	wrong.connector = &"SNAP_exit_no_such_door"
	slots[1] = wrong
	fixed_parent.slots = slots
	check(" ".join(AreaPlanner.plan(fixed_parent, 1).errors).contains("no connector"), "a baked parent's wrong door is still an error")

	if failures.is_empty():
		print("r02_tweaks_test: PASS (%d checks)" % checks)
		quit(0)
	else:
		for f: String in failures.slice(0, 30):
			printerr("FAIL: " + f)
		print("r02_tweaks_test: FAIL (%d of %d)" % [failures.size(), checks])
		quit(1)

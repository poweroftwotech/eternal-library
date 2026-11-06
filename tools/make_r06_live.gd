extends SceneTree
## Phase 14 step 5: the Domicile Quarter in the live Mahaleh (Q7): two to four
## quarters grown off an alley, the garden or each other, each behind a short
## entry alley. Adds the grow rule, bumps the recipe's version, and reports over
## WORLDS seeds how many quarters grow and which layouts.
##   godot --audio-driver Dummy --headless --path . --script res://tools/make_r06_live.gd [-- --dry]

const PATH: String = "res://gen/recipes/mahaleh.tres"
const WORLDS: int = 40


func _initialize() -> void:
	var dry: bool = OS.get_cmdline_user_args().has("--dry")
	var live: AreaRecipe = load(PATH)
	var grows: Array[AreaGrow] = []
	for g: AreaGrow in live.grow:
		if g != null and g.slot_prefix != "quarter":
			grows.append(g)
	var had: bool = grows.size() != live.grow.size()
	var g := AreaGrow.new()
	g.grammar = load("res://gen/grammars/r06_quarter.tres")
	g.display_name = "The Domicile Quarter"
	g.count = Vector2i(2, 4)
	g.tweaks = {"alley": "short"}
	g.slot_prefix = "quarter"
	g.from = PackedStringArray(["alley_1", "alley_2", "garden_1", "quarter_1", "quarter_2", "quarter_3", "quarter_4"])
	grows.append(g)
	live.grow = grows
	if not had:
		live.version += 1
	var counts: Dictionary = {}
	var layouts: Dictionary = {}
	var errors: int = 0
	for s: int in range(1, WORLDS + 1):
		var p: AreaPlan = AreaPlanner.plan(live, s)
		var n: int = 0
		for q: AreaPlan.Room in p.rooms:
			if q.slot_id.begins_with("quarter_"):
				n += 1
				layouts[q.grid.meta["layout"]] = int(layouts.get(q.grid.meta["layout"], 0)) + 1
		counts[n] = int(counts.get(n, 0)) + 1
		errors += p.errors.size()
		for e: String in p.errors:
			print("  seed %d error: %s" % [s, e])
	print("make_r06_live: quarters per world %s, layouts %s, %d plan errors" % [counts, layouts, errors])
	var err: int = OK if dry else ResourceSaver.save(live, PATH)
	print("make_r06_live: %s (%d), recipe v%d" % ["dry run" if dry else "saved", err, live.version])
	quit(err)

extends SceneTree
## Phase 15 step 5: the Grand Bazaar in the live Mahaleh (Q7): one per area, off an
## alley or the garden, placed before the quarters take the space. Adds the grow
## rule, bumps the recipe's version, and reports over WORLDS seeds how often it
## grows and how many quarters are left beside it.
##   godot --audio-driver Dummy --headless --path . --script res://tools/make_r04_live.gd [-- --dry]

const PATH: String = "res://gen/recipes/mahaleh.tres"
const WORLDS: int = 40


func _initialize() -> void:
	var dry: bool = OS.get_cmdline_user_args().has("--dry")
	var live: AreaRecipe = load(PATH)
	var grows: Array[AreaGrow] = []
	for g: AreaGrow in live.grow:
		if g != null and g.slot_prefix != "bazaar":
			grows.append(g)
	var had: bool = grows.size() != live.grow.size()
	var g := AreaGrow.new()
	g.grammar = load("res://gen/grammars/r04_bazaar.tres")
	g.display_name = "The Grand Bazaar"
	g.count = Vector2i(1, 1)
	g.slot_prefix = "bazaar"
	g.from = PackedStringArray(["alley_1", "alley_2", "garden_1"])
	grows.insert(grows.find_custom(func(x: AreaGrow) -> bool: return x.slot_prefix == "quarter"), g)
	live.grow = grows
	if not had:
		live.version += 1
	var seeds: PackedStringArray = []
	var quarters: Dictionary = {}
	var errors: int = 0
	for s: int in range(1, WORLDS + 1):
		var p: AreaPlan = AreaPlanner.plan(live, s)
		var q: int = 0
		for r: AreaPlan.Room in p.rooms:
			if r.slot_id.begins_with("quarter_"):
				q += 1
			elif r.slot_id.begins_with("bazaar_"):
				seeds.append("%d(%s)" % [s, ",".join(r.grid.meta["streets"].keys())])
		quarters[q] = int(quarters.get(q, 0)) + 1
		errors += p.errors.size()
		for e: String in p.errors:
			print("  seed %d error: %s" % [s, e])
	print("make_r04_live: bazaar in %d of %d worlds: %s" % [seeds.size(), WORLDS, " ".join(seeds)])
	print("make_r04_live: quarters per world %s, %d plan errors" % [quarters, errors])
	var err: int = OK if dry else ResourceSaver.save(live, PATH)
	print("make_r04_live: %s (%d), recipe v%d" % ["dry run" if dry else "saved", err, live.version])
	quit(err)

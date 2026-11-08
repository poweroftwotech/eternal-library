extends SceneTree
## Phase 15: a copy of the Mahaleh's recipe with one Grand Bazaar grown off an
## alley (gen/recipes/drafts/mahaleh/bazaar_test.tres). Walk it from the Strata
## Board (Walk this seed on the copy), or tests/r04_capture.gd.
##   godot --audio-driver Dummy --headless --path . --script res://tools/make_r04_draft.gd

const OUT: String = "res://gen/recipes/drafts/mahaleh/bazaar_test.tres"
const OUT_DESERTED: String = "res://gen/recipes/drafts/mahaleh/bazaar_deserted.tres"


func _initialize() -> void:
	var live: AreaRecipe = load("res://gen/recipes/mahaleh.tres")
	var r: AreaRecipe = live.duplicate(true)
	var g := AreaGrow.new()
	g.grammar = load("res://gen/grammars/r04_bazaar.tres")
	g.display_name = "The Grand Bazaar"
	g.count = Vector2i(1, 1)
	g.slot_prefix = "bazaar"
	g.from = PackedStringArray(["alley_1", "alley_2", "garden_1"])
	# After the alleys and garden it joins, before the quarters take the space.
	var grows: Array[AreaGrow] = r.grow.filter(func(x: AreaGrow) -> bool: return x.slot_prefix != "bazaar")
	grows.insert(grows.find_custom(func(x: AreaGrow) -> bool: return x.slot_prefix == "quarter"), g)
	r.grow = grows
	DirAccess.make_dir_recursive_absolute(OUT.get_base_dir())
	var err: int = ResourceSaver.save(r, OUT)
	# The same, deserted: the Forgotten City's version (the brief's Q6).
	var empty: AreaRecipe = r.duplicate(true)
	for eg: AreaGrow in empty.grow:
		if eg.slot_prefix == "bazaar":
			eg.tweaks = {"state": "abandoned"}
	err = maxi(err, ResourceSaver.save(empty, OUT_DESERTED))
	var found: int = 0
	for s: int in range(1, 21):
		var p: AreaPlan = AreaPlanner.plan(r, s)
		for q: AreaPlan.Room in p.rooms:
			if q.slot_id.begins_with("bazaar_"):
				found += 1
				print("  seed %d: %s off %s, streets %s" % [s, q.slot_id, q.parent, q.grid.meta["streets"]])
		for e: String in p.errors:
			print("  seed %d error: %s" % [s, e])
	print("make_r04_draft: saved (%d); bazaar in %d of 20 seeds" % [err, found])
	quit(err)

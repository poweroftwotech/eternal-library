extends SceneTree
## Phase 14: a copy of the Mahaleh's recipe with two to four Domicile Quarters grown off
## an alley, the garden or each other, each behind a short entry alley
## (gen/recipes/drafts/mahaleh/quarter_test.tres). Walk
## it from the Strata Board (Walk this seed on the copy), or tests/r06_capture.gd.
##   godot --audio-driver Dummy --headless --path . --script res://tools/make_r06_draft.gd

const OUT: String = "res://gen/recipes/drafts/mahaleh/quarter_test.tres"
const OUT_DESERTED: String = "res://gen/recipes/drafts/mahaleh/quarter_deserted.tres"


func _initialize() -> void:
	var live: AreaRecipe = load("res://gen/recipes/mahaleh.tres")
	var r: AreaRecipe = live.duplicate(true)
	var g := AreaGrow.new()
	g.grammar = load("res://gen/grammars/r06_quarter.tres")
	g.display_name = "The Domicile Quarter"
	g.count = Vector2i(2, 4)
	g.tweaks = {"alley": "short"}
	g.slot_prefix = "quarter"
	g.from = PackedStringArray(["alley_1", "alley_2", "garden_1", "quarter_1", "quarter_2", "quarter_3", "quarter_4"])
	var grows: Array[AreaGrow] = r.grow.duplicate()
	grows.append(g)
	r.grow = grows
	DirAccess.make_dir_recursive_absolute(OUT.get_base_dir())
	var err: int = ResourceSaver.save(r, OUT)
	# The same with every quarter deserted, for the Forgotten City's tests.
	var empty: AreaRecipe = r.duplicate(true)
	var eg: AreaGrow = empty.grow[empty.grow.size() - 1]
	eg.tweaks = {"alley": "short", "state": "deserted"}
	err = maxi(err, ResourceSaver.save(empty, OUT_DESERTED))
	var found: int = 0
	for s: int in range(1, 21):
		var p: AreaPlan = AreaPlanner.plan(r, s)
		var line: PackedStringArray = []
		for q: AreaPlan.Room in p.rooms:
			if q.slot_id.begins_with("quarter_"):
				line.append("%s %s off %s" % [q.slot_id, q.grid.meta["layout"], q.parent])
		if not line.is_empty():
			found += 1
			print("  seed %d: %s" % [s, ", ".join(line)])
		for e: String in p.errors:
			print("  seed %d error: %s" % [s, e])
	print("make_r06_draft: saved (%d); quarter in %d of 20 seeds" % [err, found])
	quit(err)

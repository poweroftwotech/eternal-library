extends SceneTree
## Phase 16: a copy of the Mahaleh's recipe with one Ossuary of Books grown off a
## quarter (gen/recipes/drafts/mahaleh/ossuary_test.tres). Walk it from the Strata
## Board (Walk this seed on the copy), or tests/r17_capture.gd. It starts from
## the live recipe, whatever version that is, and never writes the live file.
##   godot --audio-driver Dummy --headless --path . --script res://tools/make_r17_draft.gd

const OUT: String = "res://gen/recipes/drafts/mahaleh/ossuary_test.tres"


func _initialize() -> void:
	var live: AreaRecipe = load("res://gen/recipes/mahaleh.tres")
	var r: AreaRecipe = live.duplicate(true)
	var g := AreaGrow.new()
	g.grammar = load("res://gen/grammars/r17_ossuary.tres")
	g.display_name = "The Ossuary of Books"
	g.count = Vector2i(1, 1)
	g.slot_prefix = "ossuary"
	g.from = PackedStringArray(["quarter_1", "quarter_2", "quarter_3", "quarter_4"])
	var grows: Array[AreaGrow] = r.grow.filter(func(x: AreaGrow) -> bool: return x.slot_prefix != "ossuary")
	grows.append(g)
	r.grow = grows
	DirAccess.make_dir_recursive_absolute(OUT.get_base_dir())
	var err: int = ResourceSaver.save(r, OUT)
	# The Forgotten version, to look at: the same room with State set as on the board.
	var f: AreaRecipe = r.duplicate(true)
	for x: AreaGrow in f.grow:
		if x.slot_prefix == "ossuary":
			x.tweaks = {"state": "forgotten"}
	err = maxi(err, ResourceSaver.save(f, OUT.replace("ossuary_test", "ossuary_forgotten_test")))
	var found: int = 0
	for s: int in range(1, 21):
		var p: AreaPlan = AreaPlanner.plan(r, s)
		for q: AreaPlan.Room in p.rooms:
			if q.slot_id.begins_with("ossuary_"):
				found += 1
				for bad: String in q.grid.check():
					print("  seed %d check: %s" % [s, bad])
				print("  seed %d: %s off %s, %d cells, far door %s, %d dead ends" % [s, q.slot_id, q.parent, int(q.grid.meta.get("cells", 0)),
					q.grid.meta.get("far_door", false), (q.grid.meta.get("stops", []) as Array).size()])
		for e: String in p.errors:
			print("  seed %d error: %s" % [s, e])
	print("make_r17_draft: saved (%d); ossuary in %d of 20 seeds" % [err, found])
	quit(err)

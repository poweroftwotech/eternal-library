extends SceneTree
## Phase 13 step 3: a copy of the Lower Stacks' recipe with the Fungus
## Terraces grown off the hall, a gallery or the garden, before the galleries
## fill the space (gen/recipes/drafts/lower_stacks/terraces_test.tres). Walk it
## from the Strata Board (Walk this seed on the copy), or tests/r15_capture.gd.
##   godot --audio-driver Dummy --headless --path . --script res://tools/make_r15_draft.gd

const OUT: String = "res://gen/recipes/drafts/lower_stacks/terraces_test.tres"


func _initialize() -> void:
	var live: AreaRecipe = load("res://gen/recipes/lower_stacks.tres")
	var r: AreaRecipe = live.duplicate(true)
	var g := AreaGrow.new()
	g.grammar = load("res://gen/grammars/r15_fungus_terraces.tres")
	g.display_name = "The Fungus Terraces"
	g.count = Vector2i(1, 1)
	g.slot_prefix = "terraces"
	g.from = PackedStringArray(["hall", "gallery_1", "gallery_2", "gallery_3", "gallery_4", "gallery_5"])
	var grows: Array[AreaGrow] = r.grow.duplicate()
	grows.insert(0, g)
	r.grow = grows
	DirAccess.make_dir_recursive_absolute(OUT.get_base_dir())
	var err: int = ResourceSaver.save(r, OUT)
	var found: int = 0
	for s: int in range(1, 21):
		var p: AreaPlan = AreaPlanner.plan(r, s)
		var t: AreaPlan.Room = p.room("terraces_1")
		if t != null:
			found += 1
			print("  seed %d: terraces up %d storeys (%d terraces)" % [s, int(t.grid.meta.get("storeys", 0)), int(t.grid.meta.get("rows", 1)) - 1])
	print("make_r15_draft: saved (%d); terraces in %d of 20 seeds" % [err, found])
	quit(err)

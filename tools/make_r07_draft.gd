extends SceneTree
## Phase 13: copies of the areas' recipes with a Garden Court grown off the
## hall or a gallery, first: the Lower Stacks' tended garden
## (gen/recipes/drafts/lower_stacks/garden_test.tres) and, from step 2, the
## Forgotten Wing's wild one (gen/recipes/drafts/forgotten_wing/garden_test.tres).
## Walk them from the Strata Board (Walk this seed on the copy), or
## tests/r07_capture.gd.
##   godot --headless --path . --script res://tools/make_r07_draft.gd

const COPIES: Array = [
	["lower_stacks", {}],
	["forgotten_wing", {"state": RoomGrammar.ABANDONED}],
]


func _initialize() -> void:
	var err: int = OK
	for copy: Array in COPIES:
		var area: String = copy[0]
		var out: String = "res://gen/recipes/drafts/%s/garden_test.tres" % area
		var live: AreaRecipe = load("res://gen/recipes/%s.tres" % area)
		var r: AreaRecipe = live.duplicate(true)
		var g := AreaGrow.new()
		g.grammar = load("res://gen/grammars/r07_garden.tres")
		g.tweaks = (copy[1] as Dictionary).duplicate()
		g.display_name = "The Garden Court"
		g.count = Vector2i(1, 1)
		g.slot_prefix = "garden"
		g.from = PackedStringArray(["hall", "gallery_1", "gallery_2", "gallery_3", "gallery_4", "gallery_5"])
		var grows: Array[AreaGrow] = []
		for x: AreaGrow in r.grow:
			if x != null and x.slot_prefix != "garden":
				grows.append(x)       # the live recipe grows its own garden since step 2
		grows.insert(0, g)
		r.grow = grows
		DirAccess.make_dir_recursive_absolute(out.get_base_dir())
		err = maxi(err, ResourceSaver.save(r, out))
		var found: int = 0
		for s: int in range(1, 21):
			if AreaPlanner.plan(r, s).room("garden_1") != null:
				found += 1
		print("make_r07_draft: %s: a garden court in %d of 20 seeds -> %s" % [area, found, out])
	quit(err)

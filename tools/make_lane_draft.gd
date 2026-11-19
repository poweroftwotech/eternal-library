extends SceneTree
## Phase 21: the residents' test lane, a copy of the Mahaleh's recipe that is
## one Domicile Quarter and nothing else (gen/recipes/drafts/mahaleh/
## lane_test.tres): the quarter with the hauz, as the area's first room, so
## you stand in its lane as soon as you arrive. Walk it from the Strata Board
## (Walk this seed on the copy), with `-- --lane`, or from the tests.
##   godot --audio-driver Dummy --headless --path . --script res://tools/make_lane_draft.gd

const OUT: String = "res://gen/recipes/drafts/mahaleh/lane_test.tres"


func _initialize() -> void:
	var live: AreaRecipe = load("res://gen/recipes/mahaleh.tres")
	var r: AreaRecipe = live.duplicate(true)
	var slot := AreaSlot.new()
	slot.slot_id = "entrance"
	slot.display_name = "The test lane"
	slot.grammar = load("res://gen/grammars/r06_quarter.tres")
	slot.tweaks = {"layout": "hauz"}
	slot.pinned = true
	var slots: Array[AreaSlot] = [slot]
	r.slots = slots
	var none: Array[AreaGrow] = []
	r.grow = none
	r.room_count = Vector2i(1, 1)
	DirAccess.make_dir_recursive_absolute(OUT.get_base_dir())
	var err: int = ResourceSaver.save(r, OUT)
	for s: int in range(1, 4):
		var p: AreaPlan = AreaPlanner.plan(r, s)
		for q: AreaPlan.Room in p.rooms:
			print("  seed %d: %s %s, %d homes" % [s, q.slot_id, q.grid.meta.get("layout", "?"), (q.grid.meta.get("homes", []) as Array).size()])
		for e: String in p.errors:
			print("  seed %d error: %s" % [s, e])
	print("make_lane_draft: saved (%d)" % err)
	quit(err)

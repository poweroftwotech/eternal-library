extends SceneTree
## Phase 12 step 1: a copy of the Lower Stacks' recipe with a Bridge Hall
## grown off the hall or a gallery, before the galleries (they fill the space first otherwise)
## (gen/recipes/drafts/lower_stacks/bridge_hall_test.tres). Walk it from the
## Strata Board (Walk this seed on the copy), or tests/r21_capture.gd.
##   godot --headless --path . --script res://tools/make_r21_draft.gd

const OUT: String = "res://gen/recipes/drafts/lower_stacks/bridge_hall_test.tres"


func _initialize() -> void:
	var live: AreaRecipe = load("res://gen/recipes/lower_stacks.tres")
	var r: AreaRecipe = live.duplicate(true)
	var g := AreaGrow.new()
	g.grammar = load("res://gen/grammars/r21_bridge_hall.tres")
	g.display_name = "The Bridge Hall"
	g.count = Vector2i(1, 1)
	g.slot_prefix = "bridge"
	g.from = PackedStringArray(["hall", "gallery_1", "gallery_2", "gallery_3", "gallery_4", "gallery_5"])
	var grows: Array[AreaGrow] = r.grow.duplicate()
	grows.insert(0, g)
	r.grow = grows
	DirAccess.make_dir_recursive_absolute(OUT.get_base_dir())
	var err: int = ResourceSaver.save(r, OUT)
	var found: int = 0
	for s: int in range(1, 21):
		var p: AreaPlan = AreaPlanner.plan(r, s)
		var b: AreaPlan.Room = p.room("bridge_1")
		if b != null:
			found += 1
			var rise: int = int((b.grid.meta.get("bridge", {}) as Dictionary).get("rise", 0))
			print("  seed %d: bridge hall %d bays, %s, off %s" % [s, int(b.grid.meta.get("bays", 0)), ["drops a storey", "level", "climbs a storey"][rise + 1], b.parent if "parent" in b else "?"])
	print("make_r21_draft: saved (%d); a bridge hall in %d of 20 seeds" % [err, found])
	quit(err)

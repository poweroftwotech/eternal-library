extends SceneTree
## Phase 12 step 4: how often the Lower Stacks and the Forgotten Wing grow a
## Bridge Hall, headless (plans only, nothing built):
##   godot --headless --path . --script res://tests/r21_fit_sweep.gd [-- seeds=N]
## For area seeds 1-N of each recipe: whether the plan has a Bridge Hall, its
## length and rise, the room it grows off, the plan's room count, and that
## AreaPlan.check() is clean.

const RECIPES: Dictionary = {"lower_stacks": "res://gen/recipes/lower_stacks.tres", "forgotten_wing": "res://gen/recipes/forgotten_wing.tres"}


func _initialize() -> void:
	var seeds: int = 20
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("seeds="):
			seeds = a.trim_prefix("seeds=").to_int()
	var bad: int = 0
	for id: String in RECIPES:
		var recipe: AreaRecipe = load(RECIPES[id])
		var have: int = 0
		var others: Dictionary = {"cistern": 0, "lightwell": 0, "upper": 0}
		for s: int in range(1, seeds + 1):
			var p: AreaPlan = AreaPlanner.plan(recipe, s)
			var line: String = "%s %2d: %2d rooms" % [id, s, p.rooms.size()]
			for r: AreaPlan.Room in p.rooms:
				for k: String in others:
					if r.slot_id == k + "_1":
						others[k] += 1
				if r.slot_id.begins_with("bridge"):
					have += 1
					line += ", bridge hall off %s" % r.parent
			var faults: PackedStringArray = p.check()
			if not faults.is_empty():
				bad += 1
				line += "  CHECK: " + "; ".join(faults)
			print(line)
		print("r21_fit_sweep: %s has a Bridge Hall in %d of %d seeds" % [id, have, seeds])
		print("r21_fit_sweep: %s also has a cistern in %d, a light-well in %d, upper stacks in %d" % [id, others["cistern"], others["lightwell"], others["upper"]])
	print("r21_fit_sweep: %d plan check faults" % bad)
	quit(1 if bad > 0 else 0)

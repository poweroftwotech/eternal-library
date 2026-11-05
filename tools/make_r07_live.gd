extends SceneTree
## Phase 13 step 2: the Garden Court in the live areas (Q2: at most one per
## stratum, in the Lower Stacks or the Forgotten Wing, the world seed picks;
## Q5: tended in the Lower Stacks, wild in the Forgotten Wing). Adds one grow
## rule to each recipe, right after the galleries (the garden is big, so it
## picks its door before the other grown rooms), shared by the two areas
## (AreaGrow.one_of), and bumps the recipes' versions. Then reports, over
## WORLDS worlds, which area each world picks, whether the garden fits there,
## and how the other grown rooms fare before and after.
##   godot --headless --path . --script res://tools/make_r07_live.gd [-- --dry]

const AREAS: Dictionary = {
	"lower_stacks": "res://gen/grammars/r07_garden.tres",
	"forgotten_wing": "res://gen/grammars/r07_garden_wild.tres",
}
const WORLDS: int = 40
const OTHERS: PackedStringArray = ["lightwell_1", "bridge_1", "cistern_1"]


func _initialize() -> void:
	var dry: bool = OS.get_cmdline_user_args().has("--dry")
	var before: Dictionary = {}
	var after: Dictionary = {}
	var err: int = OK
	for id: String in AREAS:
		var path: String = "res://gen/recipes/%s.tres" % id
		var live: AreaRecipe = load(path)
		before[id] = live.duplicate(true)
		var grows: Array[AreaGrow] = []
		for g: AreaGrow in live.grow:
			if g != null and g.slot_prefix != "garden":
				grows.append(g)
		var g := AreaGrow.new()
		g.grammar = load(AREAS[id])
		g.display_name = "The Garden Court"
		g.count = Vector2i(1, 1)
		g.slot_prefix = "garden"
		g.from = PackedStringArray(["hall", "gallery_1", "gallery_2", "gallery_3", "gallery_4", "gallery_5"])
		g.one_of = PackedStringArray(AREAS.keys())
		var at: int = 0
		for i: int in grows.size():
			if grows[i].slot_prefix == "gallery":
				at = i + 1
		for a: String in OS.get_cmdline_user_args():
			if a.begins_with("--after="):
				for i: int in grows.size():
					if grows[i].slot_prefix == a.trim_prefix("--after="):
						at = i + 1
		if OS.get_cmdline_user_args().has("--last"):
			at = grows.size()
			for i: int in grows.size():
				if grows[i].slot_prefix == "upper":
					at = i      # the light-well's upper rooms grow off it, after
		grows.insert(at, g)
		var had: bool = live.grow.any(func(x: AreaGrow) -> bool: return x != null and x.slot_prefix == "garden")
		live.grow = grows
		if not had:
			live.version += 1
		after[id] = live
		if not dry:
			err = maxi(err, ResourceSaver.save(live, path))
		print("make_r07_live: %s version %d, garden grown after the galleries%s" % [id, live.version, " (dry run)" if dry else ""])
	var placed: int = 0
	var counts_before: Dictionary = {}
	var counts_after: Dictionary = {}
	for w: int in range(1, WORLDS + 1):
		var line: String = "  world %2d:" % w
		for id: String in AREAS:
			var pa: AreaPlan = AreaPlanner.plan_world(after[id], w)
			var pb: AreaPlan = AreaPlanner.plan_world(before[id], w)
			if pa.room("garden_1") != null:
				placed += 1
				line += " garden in %s;" % id
			for o: String in OTHERS:
				var k: String = id + ":" + o
				counts_before[k] = int(counts_before.get(k, 0)) + (1 if pb.room(o) != null else 0)
				counts_after[k] = int(counts_after.get(k, 0)) + (1 if pa.room(o) != null else 0)
			if not pa.check().is_empty():
				line += " %s plan problems: %s;" % [id, pa.check()]
		var pick: String = AreaPlanner.one_of_pick((after["lower_stacks"] as AreaRecipe).grow.filter(func(x: AreaGrow) -> bool: return x.slot_prefix == "garden")[0], w)
		print(line + " (picked %s)" % pick)
	print("make_r07_live: a garden in %d of %d worlds" % [placed, WORLDS])
	for k: String in counts_before:
		print("  %s: %d -> %d of %d worlds" % [k, counts_before[k], counts_after[k], WORLDS])
	quit(err)

extends SceneTree
## Phase 13 step 5: the Fungus Terraces in the live areas (Q2: the Lower
## Stacks and the Forgotten Wing, at most one per area, like the Bridge Hall).
## Adds one grow rule to each recipe after the rule `--after=<slot prefix>`
## (default: the garden's), and bumps the recipes' versions. Then reports, over
## WORLDS worlds, where the terraces fit and how the other grown rooms fare
## before (without the terraces) and after.
##   godot --headless --path . --script res://tools/make_r15_live.gd [-- --dry] [--after=bridge]

const AREAS: PackedStringArray = ["lower_stacks", "forgotten_wing"]
const GRAMMAR: String = "res://gen/grammars/r15_fungus_terraces.tres"
const WORLDS: int = 40
const OTHERS: PackedStringArray = ["garden_1", "lightwell_1", "bridge_1", "cistern_1", "upper_1"]


func _initialize() -> void:
	var dry: bool = OS.get_cmdline_user_args().has("--dry")
	var after_prefix: String = "garden"
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--after="):
			after_prefix = a.trim_prefix("--after=")
	var before: Dictionary = {}
	var after: Dictionary = {}
	var err: int = OK
	for id: String in AREAS:
		var path: String = "res://gen/recipes/%s.tres" % id
		var live: AreaRecipe = load(path)
		var had: bool = live.grow.any(func(x: AreaGrow) -> bool: return x != null and x.slot_prefix == "terraces")
		var grows: Array[AreaGrow] = []
		for g: AreaGrow in live.grow:
			if g != null and g.slot_prefix != "terraces":
				grows.append(g)
		var old: AreaRecipe = live.duplicate(true)
		old.grow = grows.duplicate()
		before[id] = old
		var t := AreaGrow.new()
		t.grammar = load(GRAMMAR)
		t.display_name = "The Fungus Terraces"
		t.count = Vector2i(1, 1)
		t.slot_prefix = "terraces"
		t.from = PackedStringArray(["hall", "gallery_1", "gallery_2", "gallery_3", "gallery_4", "gallery_5"])
		# --from-any: off any room's free door, not only the hall's and galleries'.
		if OS.get_cmdline_user_args().has("--from-any"):
			t.from = PackedStringArray()
		# --one-of: one area per world (the seed picks), as the garden.
		if OS.get_cmdline_user_args().has("--one-of"):
			t.one_of = AREAS
		var at: int = grows.size()
		for i: int in grows.size():
			if grows[i].slot_prefix == "upper":
				at = mini(at, i)      # the light-well's upper rooms grow off it, last
		if after_prefix == "first":
			at = 0
		if after_prefix == "last":
			at = grows.size()
		for i: int in grows.size():
			if grows[i].slot_prefix == after_prefix:
				at = i + 1
		grows.insert(at, t)
		live.grow = grows
		if not had:
			live.version += 1
		after[id] = live
		if not dry:
			err = maxi(err, ResourceSaver.save(live, path))
		print("make_r15_live: %s version %d, terraces grown after '%s'%s" % [id, live.version, after_prefix, " (dry run)" if dry else ""])
	var placed: Dictionary = {}
	var counts_before: Dictionary = {}
	var counts_after: Dictionary = {}
	for w: int in range(1, WORLDS + 1):
		var line: String = "  world %2d:" % w
		for id: String in AREAS:
			var pa: AreaPlan = AreaPlanner.plan_world(after[id], w)
			var pb: AreaPlan = AreaPlanner.plan_world(before[id], w)
			if pa.room("terraces_1") != null:
				placed[id] = int(placed.get(id, 0)) + 1
				line += " %s terraces;" % id
			for o: String in OTHERS:
				var k: String = id + ":" + o
				counts_before[k] = int(counts_before.get(k, 0)) + (1 if pb.room(o) != null else 0)
				counts_after[k] = int(counts_after.get(k, 0)) + (1 if pa.room(o) != null else 0)
			if not pa.check().is_empty():
				line += " %s plan problems: %s;" % [id, pa.check()]
		print(line)
	for id: String in AREAS:
		print("make_r15_live: terraces in %s in %d of %d worlds" % [id, int(placed.get(id, 0)), WORLDS])
	for k: String in counts_before:
		print("  %s: %d -> %d of %d worlds" % [k, counts_before[k], counts_after[k], WORLDS])
	quit(err)

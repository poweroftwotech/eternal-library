extends SceneTree
## Phase 16 step 5: the Ossuary of Books in the live recipes (Q7, Q8): tended, off
## a quarter of the Mahaleh; forgotten, off any free door of the Forgotten City.
## Adds one grow rule to each, last so it takes no other room's place, and bumps
## the versions. Reports over WORLDS worlds where the room fits.
##   godot --audio-driver Dummy --headless --path . --script res://tools/make_r17_live.gd [-- --dry]

const WORLDS: int = 40
const AREAS: Dictionary = {
	"mahaleh": {"from": ["quarter_1", "quarter_2", "quarter_3", "quarter_4"], "tweaks": {}},
	"forgotten_city": {"from": [], "tweaks": {"state": "abandoned"}},
}


func _initialize() -> void:
	var dry: bool = OS.get_cmdline_user_args().has("--dry")
	var err: int = OK
	for id: String in AREAS:
		var path: String = "res://gen/recipes/%s.tres" % id
		var live: AreaRecipe = load(path)
		var had: bool = live.grow.any(func(x: AreaGrow) -> bool: return x != null and x.slot_prefix == "ossuary")
		var grows: Array[AreaGrow] = []
		for g: AreaGrow in live.grow:
			if g != null and g.slot_prefix != "ossuary":
				grows.append(g)
		var t := AreaGrow.new()
		t.grammar = load("res://gen/grammars/r17_ossuary.tres")
		t.display_name = "The Ossuary of Books"
		t.count = Vector2i(1, 1)
		t.slot_prefix = "ossuary"
		t.from = PackedStringArray(AREAS[id]["from"])
		t.tweaks = AREAS[id]["tweaks"]
		grows.append(t)
		live.grow = grows
		if not had:
			live.version += 1
		if not dry:
			err = maxi(err, ResourceSaver.save(live, path))
		var placed: PackedInt32Array = []
		var problems: int = 0
		for w: int in range(1, WORLDS + 1):
			var p: AreaPlan = AreaPlanner.plan_world(live, w)
			if p.room("ossuary_1") != null:
				placed.append(w)
			problems += p.check().size()
		print("make_r17_live: %s version %d: ossuary in %d of %d worlds, %d plan problems%s" % [id, live.version, placed.size(), WORLDS, problems, " (dry run)" if dry else ""])
		print("  worlds: %s" % [placed])
	quit(err)

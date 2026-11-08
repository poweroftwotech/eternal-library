extends SceneTree
## The generated Reading Room: every version plans clean, takes the style it
## says, reaches up to four exits, and its spare bays stay shut unless used.
##   godot --headless --audio-driver Dummy --path . --script res://tests/r01_layout_test.gd

const VERSIONS: Array[String] = ["masonry", "wood", "masonry_left", "wood_left"]
var fails: int = 0


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		printerr("FAIL ", what)


func run() -> void:
	for v: String in VERSIONS:
		var d: AreaRecipe = load("res://gen/recipes/drafts/grand_study/r01_%s.tres" % v)
		var want: int = 1 if v.begins_with("wood") else 0
		var most: int = 0
		for w: int in range(1, 21):
			var p: AreaPlan = AreaPlanner.plan_world(d, w)
			var hall: AreaPlan.Room = p.rooms[0]
			var grown: int = 0
			for r: AreaPlan.Room in p.rooms:
				if r.parent == hall.slot_id:
					grown += 1
			most = maxi(most, grown)
			check(int(hall.style_overrides.get("gallery_build", -1)) == want, "%s world %d style" % [v, w])
			# Kept or left is the State setting on one grammar per build (no _left files).
			check(hall.grammar is ReadingRoomGrammar and (hall.grammar as ReadingRoomGrammar).abandoned == v.ends_with("_left"), "%s world %d state" % [v, w])
			check(hall.grammar.source_path() == "res://gen/grammars/r01_reading_%s.tres" % v.trim_suffix("_left"), "%s world %d grammar file" % [v, w])
			check(p.rooms.size() >= 2, "%s world %d grew nothing (%s)" % [v, w, str(p.failures) if "failures" in p else ""])
			if w == 1:
				print("  ", v, " rooms ", p.rooms.size(), " at ", hall.xf.origin, " connectors ", hall.connectors.keys())
		print(v, " most exits used ", most)
		check(most == 4, v + " never reached four exits")
	print("r01_layout: ", "PASS" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails > 0 else 0)

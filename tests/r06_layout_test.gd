extends SceneTree
## R06 Domicile Quarter layouts, no display needed: each of the four layouts,
## with each entry alley, over many seeds, is sound on the grid (every lane
## reached, both doors reached, no lane wider than one cell outside a square),
## and quarters of one area differ until all four are used.
##   godot --audio-driver Dummy --headless --path . --script res://tests/r06_layout_test.gd

var failures: int = 0
var checks: int = 0
var share: Dictionary = {}


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("  FAIL: ", what)


func _initialize() -> void:
	var base: QuarterGrammar = load("res://gen/grammars/r06_quarter.tres")
	for kind: String in QuarterGrammar.LAYOUTS:
		for alley: String in ["", "short", "long"]:
			var g: QuarterGrammar = base.tweaked({"layout": kind, "alley": alley})
			for s: int in range(1, 41):
				_layout(g, kind, alley, s)
	for s: int in range(1, 41):
		_state(base, s)
	var inner: float = float(share["inner_lit"]) / share["inner_all"]
	var outer: float = float(share["outer_lit"]) / share["outer_all"]
	print("  lit or door fronts: %.0f%% near the heart, %.0f%% further out" % [inner * 100.0, outer * 100.0])
	check(outer < inner * 0.8, "the quarter thins out from its heart")
	for area: int in range(1, 41):
		var seen: Dictionary = {}
		for n: int in range(1, 5):
			var grid := CellGrid.new()
			grid.quiet = true
			grid.meta = {"slot_id": "quarter_%d" % n, "area_seed": area}
			(base.duplicate(false) as QuarterGrammar).layout(grid, area * 7 + n)
			seen[grid.meta["layout"]] = true
		check(seen.size() == 4, "area %d: four quarters take four layouts (%s)" % [area, seen.keys()])
	print("r06_layout_test: %s (%d checks, %d failures)" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(1 if failures > 0 else 0)


## Lived in: people, smoke, lamps, a thinner edge. Deserted: none of those.
func _state(base: QuarterGrammar, s: int) -> void:
	var lived: Dictionary = _slots(base.tweaked({"alley": "short"}), s)
	var empty: Dictionary = _slots(base.tweaked({"alley": "short", "state": "deserted"}), s)
	var name: String = "seed %d" % s
	check(lived["people"] > 0, name + ": people in a lived-in quarter")
	check(lived["lit"] > 0 and lived["glow"] > 0, name + ": lit fronts and lamps in a lived-in quarter")
	check(lived["dark"] > 0, name + ": dark fronts toward the edge")
	for k: String in ["inner_lit", "inner_all", "outer_lit", "outer_all"]:
		share[k] = int(share.get(k, 0)) + int(lived[k])
	check(empty["people"] == 0 and empty["figures"] == 0, name + ": nobody in a deserted quarter")
	check(empty["lit"] == 0 and empty["glow"] == 0 and empty["doorlamp"] == 0, name + ": no lit fronts or lamps when deserted")
	check(empty["smoke"] == 0 and empty["washing"] == 0, name + ": no smoke or washing when deserted")
	check(empty["hearths"] == 0, name + ": no fires when deserted")
	check(empty["weeds"] > lived["weeds"], name + ": more plants when deserted (%d, %d)" % [empty["weeds"], lived["weeds"]])
	check(empty["notes"] >= 1, name + ": a note left in a deserted quarter")
	check(empty["fills"] >= 3, name + ": deserted, but not pitch black (%d fills)" % empty["fills"])


func _slots(g: QuarterGrammar, s: int) -> Dictionary:
	var grid := CellGrid.new()
	grid.quiet = true
	g.layout(grid, s)
	var out: Dictionary = {"people": grid.meta["people"], "smoke": (grid.meta["smoke"] as Array).size(), "fills": grid.fills.size(), "lit": 0, "dark": 0, "glow": 0, "doorlamp": 0,
		"figures": 0, "washing": 0, "hearths": 0, "weeds": 0, "notes": 0, "inner_lit": 0, "outer_lit": 0, "inner_all": 0, "outer_all": 0}
	var heart := Vector3(0.0, 0.0, -(g._oz + QuarterGrammar.HEART_Z + 0.5) * QuarterGrammar.BAY)
	for k: String in grid.props:
		var p: Dictionary = grid.props[k]
		var slot: String = p["slot"]
		if slot.begins_with("qt:g_") and k.begins_with("qt_w_"):
			var at: Vector3 = (p["xf"] as Transform3D).origin
			if at.z < -g._oz * QuarterGrammar.BAY:
				var ring: String = "inner" if Vector2(at.x, at.z - heart.z).length() < 12.0 else "outer"
				out[ring + "_all"] += 1
				if slot.contains("_lit_") or slot.contains("_door_"):
					out[ring + "_lit"] += 1
		if slot.contains("_lit_"):
			out["lit"] += 1
		elif slot.contains("_dark_"):
			out["dark"] += 1
		elif slot == "qt:glow":
			out["glow"] += 1
		elif slot == "qt:door_lamp":
			out["doorlamp"] += 1
		elif slot.begins_with("qt:fig_"):
			out["figures"] += 1
		elif slot.begins_with("qt:washing") or slot == "qt:cloth":
			out["washing"] += 1
		elif slot == "qt:x_hearth":
			out["hearths"] += 1
		elif slot.begins_with("qt:note_"):
			out["notes"] += 1
		elif k.begins_with("qt_weed_"):
			out["weeds"] += 1
	return out


func _layout(g: QuarterGrammar, kind: String, alley: String, s: int) -> void:
	var name: String = "%s/%s seed %d" % [kind, alley, s]
	var grid := CellGrid.new()
	grid.quiet = true
	g.layout(grid, s)
	check(grid.meta.get("layout", "") == kind, name + ": the asked-for layout")
	check(grid.check().is_empty(), name + ": grid check %s" % [grid.check()])
	check(int(grid.meta["alley"]) == int(QuarterGrammar.ALLEYS.get(alley, 0)), name + ": the alley's length")
	var exits: int = 0
	for k: String in grid.edges:
		var e: Dictionary = grid.edges[k]
		if e["mark"] == CellGrid.Mark.DOOR and not e["host"]:
			exits += 1
	check(exits >= 2, name + ": far and side doors (%d)" % exits)
	# Every lane cell is reached from the entry; the walks end at their doors.
	var lanes: Dictionary = g._lane
	var reached: Dictionary = {Vector2i.ZERO: true}
	var queue: Array[Vector2i] = [Vector2i.ZERO]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_back()
		for d: Vector2i in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1)]:
			if lanes.has(c + d) and not reached.has(c + d):
				reached[c + d] = true
				queue.append(c + d)
	check(reached.size() == lanes.size(), name + ": every lane joined up (%d of %d)" % [reached.size(), lanes.size()])
	check(g._sound_lanes(), name + ": lanes one cell wide")
	var route: Array = grid.meta["route"]
	check(route.size() >= 6, name + ": a walk to the far door (%d points)" % route.size())
	for arm: Array in grid.meta["arms"]:
		check(arm.size() >= 4, name + ": a walk down an arm (%d points)" % arm.size())
	check((grid.meta["arms"] as Array).size() == 2, name + ": a side door's lane and a blind end")
	var homes: Array = grid.meta["homes"]
	check(homes.size() >= 3 and homes.size() <= QuarterGrammar.HOME_MAX, name + ": three to five homes (%d)" % homes.size())
	var kinds: Dictionary = {}
	for h: Dictionary in homes:
		kinds[h["kind"]] = true
	check(kinds.size() >= mini(homes.size(), 4), name + ": different households (%s)" % [kinds.keys()])
	for c: Vector2i in g._keep:
		check(not lanes.has(c), name + ": the landmark stands clear of the lanes")

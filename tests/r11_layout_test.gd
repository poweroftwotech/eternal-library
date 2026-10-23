extends SceneTree
## R11 Cistern Archive layout gate (phase-5-design.md 5.6.4), headless:
##   godot --headless --path . --script res://tests/r11_layout_test.gd
## For Lower Stacks seeds 1-20 the cistern as the area planner lays it out
## (grown off a gallery), and for seeds 1-20 a standalone cistern: the plan
## and the grid check clean; the cistern is size_min..size_max bays each way
## and a dead end; the causeway runs straight from the entry to the far wall,
## whose middle edge is the sealed vault door; with no side doors there are no
## quays (they sit where a branch to a side door meets the causeway);
## every bay beside the causeway is shallow; every bay is causeway, shallow
## (floor 0.9 m down) or deep (2 m down, blocked); platforms stand off the
## bays along the walls and
## the causeway and are blocked; every shallow bay without a platform can be
## waded to from the causeway; lanterns hang over the causeway; the same seed
## gives the same cistern. Prints how often a Lower Stacks seed has one.

const RECIPE: String = "res://gen/recipes/lower_stacks.tres"
const GRAMMAR: String = "res://gen/grammars/r11_cistern.tres"

var failures: PackedStringArray = []
var checks: int = 0
var grammar: CisternGrammar


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures.append(what)


func run() -> void:
	grammar = load(GRAMMAR)
	check((grammar.rules as ModuleRules).check().is_empty(), "the cistern's module rules check clean (%s)" % [(grammar.rules as ModuleRules).check()])
	var recipe: AreaRecipe = load(RECIPE)
	var found: int = 0
	var totals: Dictionary = {}
	for s: int in range(1, 21):
		var p: AreaPlan = AreaPlanner.plan(recipe, s)
		check(p.errors.is_empty() and p.check().is_empty(), "lower stacks %d: the plan checks clean (%s %s)" % [s, p.errors, p.check()])
		var c: AreaPlan.Room = null
		for r: AreaPlan.Room in p.rooms:
			if r.slot_id.begins_with("cistern"):
				c = r
		if c == null:
			continue
		found += 1
		check(c.slot_id == "cistern_1" and c.parent.begins_with("gallery_"), "lower stacks %d: cistern_1 grows off a gallery (%s off %s)" % [s, c.slot_id, c.parent])
		check(c.children_count() == 0, "lower stacks %d: the cistern is a dead end" % s)
		audit("lower stacks %d" % s, c.grid, totals)
		var again: AreaPlan = AreaPlanner.plan(recipe, s)
		check(again.room(c.slot_id) != null and again.room(c.slot_id).grid.signature() == c.grid.signature() and again.room(c.slot_id).grid.props.keys() == c.grid.props.keys(),
			"lower stacks %d: the same seed lays out the same cistern" % s)
	for s: int in range(1, 21):
		var g := CellGrid.new()
		grammar.layout(g, s)
		audit("standalone %d" % s, g, totals)
	print("r11_layout_test: a cistern in %d of 20 Lower Stacks; bays %s" % [found, totals])
	check(found >= 18, "nearly every Lower Stacks seed has a cistern (%d of 20)" % found)
	check(int(totals.get("cell:basin", 0)) > 0 and int(totals.get("cell:basin_deep", 0)) > 0 and int(totals.get("platform", 0)) > 0, "the cisterns have shallow bays, deep bays and platforms (%s)" % [totals])
	print("r11_layout_test: %d checks, %d failures" % [checks, failures.size()])
	for f: String in failures.slice(0, 30):
		print("  FAIL ", f)
	quit(1 if not failures.is_empty() else 0)


func audit(tag: String, g: CellGrid, totals: Dictionary) -> void:
	check(g.check().is_empty(), "%s: the grid checks clean (%s)" % [tag, g.check()])
	var xs: Array = []
	var zs: Array = []
	for c: Vector3i in g.cells:
		xs.append(c.x)
		zs.append(c.z)
		var slot: String = g.cells[c]["floor_slot"]
		totals[slot] = int(totals.get(slot, 0)) + 1
	var w: int = xs.max() - xs.min() + 1
	var d: int = zs.max() - zs.min() + 1
	check(g.cells.size() == w * d and w >= grammar.size_min and w <= grammar.size_max and d >= grammar.size_min and d <= grammar.size_max,
		"%s: a full rectangle of %d x %d bays, within %d..%d" % [tag, w, d, grammar.size_min, grammar.size_max])
	var far := Vector3i(0, 0, zs.max())
	var doors: int = 0
	for k: String in g.edges:
		if g.edges[k]["mark"] == CellGrid.Mark.DOOR:
			doors += 1
	check(doors == 1, "%s: one door, the entry (%d)" % [tag, doors])
	var vault: Dictionary = g.edge(far, CellGrid.Side.N)
	check(not vault.is_empty() and vault["mark"] == CellGrid.Mark.SOLID and vault["slot"] == "edge:vault_door", "%s: the sealed door is in the far wall, in line with the entry" % tag)
	var platform: Dictionary = {}
	for k: String in g.props:
		if g.props[k]["slot"] == "dressing:case":
			var at: Vector3i = AreaPlan.cell_of((g.props[k]["xf"] as Transform3D) * Vector3(2.0, 0.1, -2.0))
			platform[Vector3i(at.x, 0, at.z)] = true
	totals["platform"] = int(totals.get("platform", 0)) + platform.size()
	var causeway: Dictionary = {}
	for c: Vector3i in g.cells:
		var cell: Dictionary = g.cells[c]
		var slot: String = cell["floor_slot"]
		var on_way: bool = slot == "cell:causeway" or slot == "cell:quay"
		if on_way:
			causeway[c] = true
		check(on_way == (c.x == 0), "%s: the causeway is the entry's column, and only that (%s %s)" % [tag, c, slot])
		check(slot != "cell:quay", "%s: no quays in a cistern with no side doors (%s)" % [tag, c])
		var want_y: float = 0.0 if on_way else (CisternGrammar.SHALLOW_Y if slot == "cell:basin" else CisternGrammar.DEEP_Y)
		check(slot in ["cell:causeway", "cell:quay", "cell:basin", "cell:basin_deep"] and is_equal_approx(float(cell.get("floor_y", 99.0)), want_y),
			"%s: %s is causeway, shallow or deep, at its floor height (%s %s)" % [tag, c, slot, cell.get("floor_y")])
		check(bool(cell.get("blocked", false)) == (slot == "cell:basin_deep" or platform.has(c)), "%s: deep bays and platforms, and only those, are blocked (%s)" % [tag, c])
		check(not (on_way and platform.has(c)), "%s: no platform on the causeway (%s)" % [tag, c])
		check(not (platform.has(c) and (c.x == xs.min() or c.x == xs.max() or c.z == zs.min() or c.z == zs.max())), "%s: no platform in a bay along the walls (%s)" % [tag, c])
		if g.lamps.has(c) and c.x == 0:
			totals["causeway lamps"] = int(totals.get("causeway lamps", 0)) + 1
	for c: Vector3i in causeway:
		for side: int in CellGrid.ALL_SIDES:
			var n: Vector3i = CellGrid.neighbour(c, side)
			if g.cells.has(n) and not causeway.has(n) and not platform.has(n):
				check(g.cells[n]["floor_slot"] == "cell:basin", "%s: the bay beside the causeway at %s is shallow" % [tag, n])
	# Every shallow bay without a platform can be waded to from the causeway.
	var seen: Dictionary = causeway.duplicate()
	var todo: Array = causeway.keys()
	while not todo.is_empty():
		var c: Vector3i = todo.pop_back()
		for side: int in CellGrid.ALL_SIDES:
			var n: Vector3i = CellGrid.neighbour(c, side)
			if g.cells.has(n) and not seen.has(n) and not g.cells[n].get("blocked", false):
				seen[n] = true
				todo.append(n)
	var open: int = g.cells.keys().filter(func(c: Vector3i) -> bool: return not g.cells[c].get("blocked", false)).size()
	check(seen.size() == open, "%s: all %d open bays can be reached from the causeway (%d)" % [tag, open, seen.size()])
	check(g.lamps.has(Vector3i(0, 0, grammar.lamp_every_bays - 1)) or d < grammar.lamp_every_bays, "%s: a lantern hangs over the causeway" % tag)

extends SceneTree
## R03 Hypostyle Stacks layout gate (phase-5-design.md 5.6.2), headless:
##   godot --headless --path . --script res://tests/r03_layout_test.gd
## For Lower Stacks seeds 1-20 the hall as the area planner lays it out, and
## for seeds 1-20 a standalone hall with nothing round it: the plan checks
## clean; the hall is size_min..size_max bays each way; the entry is the S
## door of cell (0,0,0); at most one door per wall, none on the N wall in line
## with the entry; one landmark under the oculus at the centre; every door's
## aisle reaches it with no bookcase on the way; no bookcase in a door bay, in
## the bays along the walls, or in the landmark square; every bay can be
## reached from the entry (a bookcase is passed along its length only); the
## same seed gives the same layout; and how many bays hold a case.
## Step 2: halls up to size_max (10); a collapsed bay (a rubble heap under a
## fallen dome) is never on an aisle, the walk along the walls or the landmark
## square, and is never needed to reach another bay; lamp clusters hang only
## on the lattice, never over a heap or with a single lamp; bays with a case,
## a heap or the landmark are marked blocked. Across all halls, some collapse, some reach
## 9 or 10 bays, and every hall has clusters.

const RECIPE: String = "res://gen/recipes/lower_stacks.tres"
const GRAMMAR: String = "res://gen/grammars/r03_hypostyle.tres"

var failures: PackedStringArray = []
var checks: int = 0
var grammar: HypostyleGrammar


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures.append(what)


func run() -> void:
	grammar = load(GRAMMAR)
	check((grammar.rules as ModuleRules).check().is_empty(), "the hall's module rules check clean (%s)" % [(grammar.rules as ModuleRules).check()])
	var recipe: AreaRecipe = load(RECIPE)
	var fill: Array = []
	for s: int in range(1, 21):
		var p: AreaPlan = AreaPlanner.plan(recipe, s)
		check(p.errors.is_empty() and p.check().is_empty(), "lower stacks %d: the plan checks clean (%s %s)" % [s, p.errors, p.check()])
		var hall: AreaPlan.Room = p.room("hall")
		check(hall != null and hall.grid != null and not hall.grid.cells.is_empty(), "lower stacks %d: the hall is laid out" % s)
		if hall != null and hall.grid != null:
			fill.append(audit("lower stacks %d" % s, hall.grid, true))
			var again: AreaPlan = AreaPlanner.plan(recipe, s)
			check(again.room("hall").grid.signature() == hall.grid.signature() and again.room("hall").grid.props.keys() == hall.grid.props.keys(),
				"lower stacks %d: the same seed lays out the same hall" % s)
	for s: int in range(1, 21):
		var g := CellGrid.new()
		grammar.layout(g, s)
		fill.append(audit("standalone %d" % s, g, false))
	var total: int = 0
	var cased: int = 0
	var heaps: int = 0
	var biggest: int = 0
	var halls_with_heaps: int = 0
	var clusters: int = 0
	for f: Array in fill:
		total += int(f[0])
		cased += int(f[1])
		heaps += int(f[2])
		halls_with_heaps += 1 if int(f[2]) > 0 else 0
		biggest = maxi(biggest, int(f[3]))
		clusters += int(f[4])
		check(int(f[4]) > 0, "every hall has lamp clusters")
	var share: float = float(cased) / maxf(total, 1.0)
	print("r03_layout_test: %d of %d bays off the aisles hold a case (%.0f%%, case_density %.0f%%); %d collapsed bays in %d of %d halls; %d clusters; widest hall %d bays" % [
		cased, total, share * 100.0, grammar.case_density * 100.0, heaps, halls_with_heaps, fill.size(), clusters, biggest])
	check(absf(share - grammar.case_density) < 0.15, "bookcases fill about case_density of the free bays (%.2f)" % share)
	check(heaps > 0, "some bays collapse (%d)" % heaps)
	check(biggest >= 9, "some halls are 9 or 10 bays across (widest %d)" % biggest)
	print("r03_layout_test: %d checks, %d failures" % [checks, failures.size()])
	for f: String in failures.slice(0, 30):
		print("  FAIL ", f)
	quit(1 if not failures.is_empty() else 0)


## Checks one hall; returns [bays a case could stand in, bays with a case,
## collapsed bays, widest side in bays, clusters].
func audit(tag: String, g: CellGrid, planned: bool) -> Array:
	check(g.check().is_empty(), "%s: the grid checks clean (%s)" % [tag, g.check()])
	var xs: Array = []
	var zs: Array = []
	for c: Vector3i in g.cells:
		xs.append(c.x)
		zs.append(c.z)
	var w: int = xs.max() - xs.min() + 1
	var d: int = zs.max() - zs.min() + 1
	check(g.cells.size() == w * d, "%s: the hall is a full rectangle" % tag)
	check(w >= grammar.size_min and w <= grammar.size_max and d >= grammar.size_min and d <= grammar.size_max, "%s: %d x %d bays, within %d..%d" % [tag, w, d, grammar.size_min, grammar.size_max])
	check(g.cells.has(Vector3i.ZERO) and zs.min() == 0, "%s: the entry bay is cell (0,0,0) on the S wall" % tag)
	var entry: Dictionary = g.edge(Vector3i.ZERO, CellGrid.Side.S)
	check(not entry.is_empty() and entry["mark"] == CellGrid.Mark.DOOR, "%s: the entry is a door" % tag)
	var centre := Vector3i(xs.min() + w / 2, 0, zs.min() + d / 2)
	check(g.cells[centre].get("ceiling_slot", "") == "cell:oculus", "%s: the oculus is over the centre" % tag)
	var landmarks: Array = g.props.keys().filter(func(k: String) -> bool: return g.props[k]["slot"] == "landmark")
	check(landmarks.size() == 1 and (g.props[landmarks[0]]["xf"] as Transform3D).origin.is_equal_approx(CellGrid.cell_centre(centre)), "%s: one landmark, at the centre" % tag)
	# Doors.
	var doors: Array = []
	var walls: Dictionary = {}
	for k: String in g.edges:
		var e: Dictionary = g.edges[k]
		if e["mark"] == CellGrid.Mark.DOOR:
			doors.append([e["cell"], e["side"]])
			walls[e["side"]] = int(walls.get(e["side"], 0)) + 1
	check(walls.values().all(func(n: int) -> bool: return n == 1), "%s: one door per wall (%s)" % [tag, walls])
	for dr: Array in doors:
		if dr[1] == CellGrid.Side.N:
			check(absi((dr[0] as Vector3i).x) >= 2, "%s: the N door isn't in line with the entry (x %d)" % [tag, (dr[0] as Vector3i).x])
	# Cases.
	var case_at: Dictionary = {}       # cell -> long axis (Vector3i)
	for k: String in g.props:
		if g.props[k]["slot"] == "dressing:case":
			var xf: Transform3D = g.props[k]["xf"]
			var c: Vector3i = AreaPlan.cell_of(xf * Vector3(2.0, 0.1, -2.0))
			c = Vector3i(c.x, 0, c.z)
			var along: Vector3 = xf.basis.x
			case_at[c] = Vector3i(roundi(absf(along.x)), 0, roundi(absf(along.z)))
	var heap_at: Dictionary = {}
	var cluster_at: Dictionary = {}
	for k: String in g.props:
		var at: Vector3i = AreaPlan.cell_of((g.props[k]["xf"] as Transform3D) * Vector3(2.0, 0.1, -2.0))
		if g.props[k]["slot"] == "dressing:rubble_heap":
			heap_at[Vector3i(at.x, 0, at.z)] = true
		elif g.props[k]["slot"] == "lamp:cluster":
			cluster_at[AreaPlan.cell_of((g.props[k]["xf"] as Transform3D).origin + Vector3(0, 0.1, 0))] = true
	for c: Vector3i in g.cells:
		check((g.cells[c].get("ceiling_slot", "") == "cell:dome_fallen") == heap_at.has(c), "%s: a fallen dome over every heap and only there (%s)" % [tag, c])
		check(bool(g.cells[c].get("blocked", false)) == (heap_at.has(c) or case_at.has(c) or c == centre), "%s: bays with a case, a heap or the landmark, and only those, are marked blocked (%s)" % [tag, c])
		check(not (heap_at.has(c) and case_at.has(c)), "%s: no case in a collapsed bay (%s)" % [tag, c])
	for c: Vector3i in cluster_at:
		var dc: Vector3i = c - centre
		check(c != centre and dc.x % grammar.lamp_cluster_every == 0 and dc.z % grammar.lamp_cluster_every == 0, "%s: the cluster at %s is on the lattice" % [tag, c])
		check(not heap_at.has(c) and not g.lamps.has(c), "%s: no heap or single lamp under the cluster at %s" % [tag, c])
	for dr: Array in doors:
		check(not case_at.has(dr[0]), "%s: no bookcase in the door bay %s" % [tag, dr[0]])
		var aisle: Array[Vector3i] = grammar.aisle_to(dr[0], dr[1], centre, 0)
		check(aisle[-1] == centre and aisle.all(func(c: Vector3i) -> bool: return g.cells.has(c) and not case_at.has(c) and not heap_at.has(c)),
			"%s: the aisle from the door at %s reaches the landmark clear" % [tag, dr[0]])
	var aisles: Dictionary = {}
	for dr: Array in doors:
		for c: Vector3i in grammar.aisle_to(dr[0], dr[1], centre, 0):
			aisles[c] = true
	for c: Vector3i in g.cells:
		if (grammar.cross_aisles >= 1 and c.z == centre.z) or (grammar.cross_aisles >= 2 and c.x == centre.x):
			aisles[c] = true
	var free_bays: int = 0
	for c: Vector3i in g.cells:
		var ring: bool = c.x == xs.min() or c.x == xs.max() or c.z == zs.min() or c.z == zs.max()
		var near_centre: bool = (c - centre).abs().x <= 1 and (c - centre).abs().z <= 1
		if ring:
			check(not case_at.has(c) and not heap_at.has(c), "%s: no bookcase or heap along the walls (%s)" % [tag, c])
		if aisles.has(c):
			check(not heap_at.has(c), "%s: no heap on an aisle (%s)" % [tag, c])
		if c == centre or (near_centre and w >= grammar.landmark_wide_from and d >= grammar.landmark_wide_from):
			check(not case_at.has(c) and not heap_at.has(c), "%s: no bookcase or heap in the landmark square (%s)" % [tag, c])
		elif not ring and not aisles.has(c) and not heap_at.has(c):
			free_bays += 1
	# Every bay reachable from the entry; a case is passed along its length only.
	var seen: Dictionary = {Vector3i.ZERO: true}
	var todo: Array[Vector3i] = [Vector3i.ZERO]
	while not todo.is_empty():
		var c: Vector3i = todo.pop_back()
		for side: int in CellGrid.ALL_SIDES:
			var n: Vector3i = CellGrid.neighbour(c, side)
			if not g.cells.has(n) or seen.has(n) or heap_at.has(n):
				continue
			var step: Vector3i = (n - c).abs()
			if (case_at.has(c) and case_at[c] != step) or (case_at.has(n) and case_at[n] != step):
				continue
			seen[n] = true
			todo.append(n)
	check(seen.size() == g.cells.size() - heap_at.size(), "%s: all %d bays but the %d collapsed can be reached from the entry (%d)" % [tag, g.cells.size(), heap_at.size(), seen.size()])
	if planned:
		check(not g.lamps.has(centre), "%s: no lamp over the landmark" % tag)
	return [free_bays, case_at.size(), heap_at.size(), maxi(w, d), cluster_at.size()]

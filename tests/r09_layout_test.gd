extends SceneTree
## R09 Light-Well Stair layout gate (phase-5-design.md 5.6.6; rev 2, the cone),
## headless:
##   godot --headless --path . --script res://tests/r09_layout_test.gd
## For Lower Stacks seeds 1-20 the light-well as the area planner lays it out,
## and for seeds 1-20 a standalone one: the plan and the grid check clean; the
## floor radius is 10 or 12 m with the square of cells round it on every
## storey; 3 levels up to the size's most; the entry on level 0 and an exit on
## the top level, at most max_exits, each a door edge in the middle of the side
## its storey's landing faces (0.75 turns a storey); the base, a storey piece
## for every level but the top (with a doorway where a door is, and on the
## floor), the cap for this size and height, each turned 0.75 turns a storey
## and 4 m up; a passage from every doorway out to the square's edge, never
## past it; the upper storeys' niches pinned plain; rooms grown off an exit
## stand on that exit's storey; the same seed gives the same layout. Every
## rule's module is in the kit, and each storey piece carries a niche socket
## of the cone_niche set (with its "plain" entry).

const RECIPE: String = "res://gen/recipes/lower_stacks.tres"
const GRAMMAR: String = "res://gen/grammars/r09_lightwell.tres"

var failures: PackedStringArray = []
var checks: int = 0
var grammar: RingGrammar


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures.append(what)


func run() -> void:
	grammar = load(GRAMMAR)
	var rules: ModuleRules = grammar.rules
	check(rules.check().is_empty(), "the light-well's module rules check clean (%s)" % [rules.check()])
	var chunk: Node = (load("res://kit/modules/walls/cone_c105_closed.tscn") as PackedScene).instantiate()
	var niches: Array[Node] = chunk.find_children("*", "VariantSocket", true, false)
	check(not niches.is_empty() and niches.all(func(s: Node) -> bool: return (s as VariantSocket).socket_set != null and (s as VariantSocket).socket_set.index_of("plain") >= 0),
		"a storey piece's niches are cone_niche sockets with a plain entry (%d)" % niches.size())
	chunk.free()
	var recipe: AreaRecipe = load(RECIPE)
	var found: int = 0
	var seen: Dictionary = {}
	var upper: int = 0
	for s: int in range(1, 21):
		var p: AreaPlan = AreaPlanner.plan(recipe, s)
		check(p.errors.is_empty() and p.check().is_empty(), "lower stacks %d: the plan checks clean (%s %s)" % [s, p.errors, p.check()])
		var lw: AreaPlan.Room = p.room("lightwell_1")
		if lw == null:
			continue
		found += 1
		audit("lower stacks %d" % s, lw.grid, seen)
		for r: AreaPlan.Room in p.rooms:
			if r.parent != lw.slot_id:
				continue
			var d: Array = AreaTour.ring_door(lw, r.parent_connector)
			check(not d.is_empty() and r.storey == lw.storey + int(d[0]), "lower stacks %d: %s stands on the storey of the exit it grew from (%d, exit level %s)" % [s, r.slot_id, r.storey, d])
			upper += 1
		var again: AreaPlan = AreaPlanner.plan(recipe, s)
		check(again.room("lightwell_1") != null and again.room("lightwell_1").grid.signature() == lw.grid.signature() and again.room("lightwell_1").grid.props.keys() == lw.grid.props.keys(),
			"lower stacks %d: the same seed lays out the same light-well" % s)
	for s: int in range(1, 21):
		var g := CellGrid.new()
		grammar.layout(g, s)
		audit("standalone %d" % s, g, seen)
	print("r09_layout_test: a light-well in %d of 20 Lower Stacks; %d rooms off its upper exits; sizes and levels seen %s" % [found, upper, seen.keys()])
	check(found >= 14, "most Lower Stacks seeds have a light-well (%d of 20)" % found)
	check(upper > 0, "rooms grow off the light-wells' upper exits (%d)" % upper)
	check(seen.keys().any(func(k: String) -> bool: return k.begins_with("r12")) and seen.keys().any(func(k: String) -> bool: return k.begins_with("r10")), "both sizes appear (%s)" % [seen.keys()])
	print("r09_layout_test: %d checks, %d failures" % [checks, failures.size()])
	for f: String in failures.slice(0, 30):
		print("  FAIL ", f)
	quit(1 if not failures.is_empty() else 0)


func audit(tag: String, g: CellGrid, seen: Dictionary) -> void:
	check(g.check().is_empty(), "%s: the grid checks clean (%s)" % [tag, g.check()])
	var m: Dictionary = g.meta
	check(m.get("cone", false), "%s: the grid keeps the cone's layout" % tag)
	if not m.get("cone", false):
		return
	var r0: int = m["radius"]
	var levels: int = m["levels"]
	var across: int = m["across"]
	var centre: Vector3 = m["centre"]
	seen["r%d x%d" % [r0, levels]] = true
	check(r0 in [10, 12] and across == RingGrammar.cells_across(r0), "%s: radius %d, %d cells across" % [tag, r0, across])
	check(levels >= grammar.levels_min and levels <= int(RingGrammar.MOST_LEVELS[r0]), "%s: %d levels" % [tag, levels])
	check(g.cells.size() == across * across * levels, "%s: the square of cells on every storey (%d)" % [tag, g.cells.size()])
	# Doors.
	var doors: Array = m["doors"]
	check(doors[0] == [0, CellGrid.Side.S] and doors.size() - 1 <= grammar.max_exits, "%s: the entry first, then at most %d exits (%s)" % [tag, grammar.max_exits, doors])
	check(doors.any(func(d: Array) -> bool: return d[0] == levels - 1), "%s: an exit on the top level (%s)" % [tag, doors])
	var door_count: int = 0
	for k: String in g.edges:
		if g.edges[k]["mark"] == CellGrid.Mark.DOOR:
			door_count += 1
	check(door_count == doors.size(), "%s: a door edge for each door (%d, %d)" % [tag, door_count, doors.size()])
	var levels_with_doors: Dictionary = {}
	for d: Array in doors:
		levels_with_doors[int(d[0])] = true
		var c: Vector3i = RingGrammar.door_cell(d[1], d[0], across / 2, across)
		check(g.edge(c, d[1]).get("mark", -1) == CellGrid.Mark.DOOR and int(d[1]) == RingGrammar.side_of(d[0]), "%s: door %s is a door edge on its landing's side" % [tag, d])
	# Pieces.
	var r10: int = r0 * 10
	check(str(g.props.get("cone_base", {}).get("slot", "")) == "cone:base%d" % r10, "%s: the base for this size" % tag)
	for j: int in levels - 1:
		var pr: Dictionary = g.props.get("cone_c_%d" % j, {})
		var kind: String = "exit" if j == 0 or levels_with_doors.has(j) else "closed"
		var want := Transform3D(Basis(Vector3.UP, RingGrammar.TURN * j), centre + Vector3(0, j * RingGrammar.STOREY, 0))
		check(not pr.is_empty() and str(pr["slot"]) == "cone:c%d_%s" % [roundi((r0 - 1.5 * j) * 10), kind] and (pr["xf"] as Transform3D).is_equal_approx(want),
			"%s: storey %d's piece (%s), turned and raised" % [tag, j, pr.get("slot", "none")])
		check((j >= grammar.shelf_levels) == (str(g.pins.get("prop_cone_c_%d" % j, "")) == "plain"), "%s: storey %d's niches %s" % [tag, j, "plain" if j >= grammar.shelf_levels else "rolled"])
		check(rules_has(str(pr.get("slot", ""))), "%s: a module for %s" % [tag, pr.get("slot", "")])
	var cap: Dictionary = g.props.get("cone_cap", {})
	check(str(cap.get("slot", "")) == "cone:cap%d_%d" % [r10, levels] and rules_has(str(cap.get("slot", ""))), "%s: the cap for %d levels (%s)" % [tag, levels, cap.get("slot", "none")])
	var edge: float = across / 2 * CellGrid.BAY + CellGrid.BAY * 0.5
	for d: Array in doors:
		var reach: float = 0.0
		var inner: float = INF
		for key: String in g.props:
			if not key.begins_with("cone_p_%d_" % int(d[0])):
				continue
			var pr: Dictionary = g.props[key]
			var o: Vector3 = (pr["xf"] as Transform3D).origin - centre
			var rad: float = Vector2(o.x, o.z).length()
			var length: float = 2.0 if str(pr["slot"]).ends_with("2m") else 0.5
			reach = maxf(reach, rad + length)
			inner = minf(inner, rad)
		check(reach > edge - 0.35 and reach <= edge - 0.29 and inner < RingGrammar.face(r0 - 1.5 * int(d[0]), 0.0) + RingGrammar.WALL - 1.0 and inner > RingGrammar.face(r0 - 1.5 * int(d[0]), 0.0) + RingGrammar.DEPTH,
			"%s: door %s's passage runs from the wall (%.1f) to the square's edge (%.2f of %.1f)" % [tag, d, inner, reach, edge])


func rules_has(slot: String) -> bool:
	for r: ModuleRule in (grammar.rules as ModuleRules).rules:
		if r.slot == slot and not r.choices.is_empty() and r.choices[0].scene != null:
			return true
	return false

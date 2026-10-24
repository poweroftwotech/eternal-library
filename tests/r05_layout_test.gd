extends SceneTree
## R05 layout gate (phase-5-design.md 5.6.7 and 5.6.9), headless:
##   godot --headless --path . --script res://tests/r05_layout_test.gd
## The 5 x 5 caravanserai template, seeds 1-20, laid out as an area's root
## and as a joined room: the grid checks clean; 45 cells (the corners solid)
## mirror each other across the gate's axis; the gate is cell (0, 0, 0) with
## the entry door, side doors in the side walls' middle; the stair halls take
## the entry wall's corner cells and open to the court at the corner end
## only; every piece is there once per cell (bays, upper cells, passages,
## corners, the two stairs mirrored, the gate, the paving, the rock, the
## hearth at the centre, the well in a far corner, lantern strings, cell and loggia
## lamps); the loggia's cells run round the ring without a gap; every slot
## has its kit module; the same seed gives the same court; a dead end keeps
## only its entry. The baked scene is the template, module for module, with
## its sockets. The Lower Stacks, seeds 1-20: the baked court is the root,
## pinned, the hall joins its gate, and no two rooms share a cell.

const GRAMMAR: String = "res://gen/grammars/r05_court_5x5.tres"
const BAKED: String = "res://rooms/baked/caravanserai_5x5.tscn"
const RECIPE: String = "res://gen/recipes/lower_stacks.tres"

var failures: PackedStringArray = []
var checks: int = 0


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures.append(what)


func run() -> void:
	var grammar: CourtyardGrammar = load(GRAMMAR)
	check(grammar.rules.check().is_empty(), "the court's rules check clean (%s)" % [grammar.rules.check()])
	for s: int in range(1, 21):
		for root_room: bool in [true, false]:
			layout_checks(grammar, s, root_room)
	var dead := CellGrid.new()
	dead.root = true
	dead.end_kind = "dead_end"
	grammar.layout(dead, 1)
	var dead_doors: int = 0
	for k: String in dead.edges:
		dead_doors += 1 if dead.edges[k]["mark"] == CellGrid.Mark.DOOR else 0
	check(dead_doors == 1, "a dead-end court keeps only its gate (%d doors)" % dead_doors)
	await bake_checks(grammar)
	plan_checks()
	print("r05_layout_test: %d checks, %d failures" % [checks, failures.size()])
	for f: String in failures.slice(0, 40):
		print("  FAIL ", f)
	quit(1 if not failures.is_empty() else 0)


func layout_checks(grammar: CourtyardGrammar, s: int, root_room: bool) -> void:
	var tag: String = "seed %d %s" % [s, "root" if root_room else "joined"]
	var grid := CellGrid.new()
	grid.root = root_room
	grammar.layout(grid, s)
	check(grid.check().is_empty(), "%s: the grid checks clean (%s)" % [tag, grid.check()])
	var m: Dictionary = grid.meta
	var h: int = m["h"]
	var top: int = m["top"]
	check(h == 3 and top == 6 and grid.cells.size() == 45, "%s: a 7 x 7 ring round a 5 x 5 court, corners solid (%d cells)" % [tag, grid.cells.size()])
	var kinds: Dictionary = {}
	var mirrored: bool = true
	for c: Vector3i in grid.cells:
		var kind: String = grid.cells[c]["kind"]
		kinds[kind] = kinds.get(kind, 0) + 1
		var twin := Vector3i(-c.x, 0, c.z)
		if not grid.cells.has(twin) or grid.cells[twin]["kind"] != kind:
			mirrored = false
	check(kinds == {"court": 25, "bay": 13, "passage": 2, "gate": 1, "stair": 4}, "%s: cells by kind %s" % [tag, kinds])
	check(mirrored, "%s: the court mirrors across the gate's axis" % tag)
	var entry: Dictionary = grid.edge(Vector3i.ZERO, CellGrid.Side.S)
	check(grid.cells[Vector3i.ZERO]["kind"] == "gate" and entry.get("mark", -1) == CellGrid.Mark.DOOR and entry.get("host", true) == not root_room,
		"%s: the gate is cell (0, 0, 0), its S side the entry (%s)" % [tag, entry])
	var doors: Array = m["doors"]
	check(doors.size() == 3 and doors[1] == [Vector3i(-h, 0, 3), CellGrid.Side.W] and doors[2] == [Vector3i(h, 0, 3), CellGrid.Side.E],
		"%s: side doors in the side walls' middle (%s)" % [tag, doors])
	for d: Array in doors.slice(1):
		var e: Dictionary = grid.edge(d[0], d[1])
		check(e.get("mark", -1) == CellGrid.Mark.DOOR and not e["host"] and grid.cells[d[0]]["kind"] == "passage", "%s: the door at %s is an exit through a passage" % [tag, d[0]])
	var stairs: Array = m["stairs"]
	check(stairs == [[Vector3i(-2, 0, 0), Vector3i(-1, 0, 0)], [Vector3i(2, 0, 0), Vector3i(1, 0, 0)]], "%s: the stair halls flank the gate (%s)" % [tag, stairs])
	for st: Array in stairs:
		var corner_end: Dictionary = grid.edge(st[0], CellGrid.Side.N)
		var gate_end: Dictionary = grid.edge(st[1], CellGrid.Side.N)
		check(corner_end["mark"] == CellGrid.Mark.OPENING and gate_end["mark"] == CellGrid.Mark.SOLID and grid.edge(st[0], CellGrid.Side.E if st[0].x < 0 else CellGrid.Side.W)["mark"] == CellGrid.Mark.OPEN,
			"%s: the stair hall %s opens to the court at its corner end only" % [tag, st])
	# Pieces.
	var slots: Dictionary = {}
	for k: String in grid.props:
		var slot: String = grid.props[k]["slot"]
		slots[slot] = slots.get(slot, 0) + 1
		check(grammar.rules.rule_for(slot, grammar.styles) != null, "%s: slot %s has its kit module" % [tag, slot])
	var want: Dictionary = {"cell:court_floor": 25, "cell:court_bay": 13, "cell:court_bay_upper": 15, "cell:court_passage": 2,
		"cell:court_gate": 1, "cell:court_stair": 1, "cell:court_stair_r": 1, "cell:court_corner": 4, "cell:court_corner_upper": 2,
		"cell:court_corner_upper_stair": 1, "cell:court_corner_upper_stair_r": 1, "cell:cavern_5x5": 1, "court:hearth": 1,
		"court:well": 1, "court:lantern_string": 3, "court:loggia_lantern": 5, "court:cell_lantern": 7, "stub:exit": 3 if root_room else 2}
	check(slots == want, "%s: pieces %s" % [tag, slots])
	var centre: Vector3i = m["centre"]
	check(centre == Vector3i(0, 0, 3) and (grid.props["hearth"]["xf"] as Transform3D).origin.is_equal_approx(CellGrid.cell_centre(centre)) and grid.cells[centre].get("blocked", false),
		"%s: the hearth stands at the court's centre, its cell blocked" % tag)
	var well: Vector3i = m["well"]
	check(absi(well.x) == h - 1 and well.z == top - 1 and grid.cells[well].get("blocked", false), "%s: the well in a far corner of the court, blocked (%s)" % [tag, well])
	# The loggia: every upper cell of the side and far walls, each next to the last
	# (or round a corner: two apart diagonally), from the west stair to the east.
	var upper: Array = m["upper"]
	var joined: bool = upper.size() == 15 and upper[0] == Vector3i(-h, 1, 1) and upper[-1] == Vector3i(h, 1, 1)
	for i: int in upper.size() - 1:
		var d: Vector3i = (upper[i + 1] as Vector3i) - (upper[i] as Vector3i)
		if d.length_squared() != 1 and d.abs() != Vector3i(1, 0, 1):
			joined = false
	check(joined, "%s: the loggia runs round without a gap (%s)" % [tag, upper])
	var again := CellGrid.new()
	again.root = root_room
	grammar.layout(again, s)
	check(again.signature() == grid.signature() and again.props.keys() == grid.props.keys(), "%s: the same seed, the same court" % tag)


func bake_checks(grammar: CourtyardGrammar) -> void:
	var baked := (load(BAKED) as PackedScene).instantiate() as RoomTemplate
	var meta: Dictionary = baked.get_meta("baked_from", {})
	var seed_value: int = int(meta.get("seed", -1))
	check(meta.get("grammar", "") == GRAMMAR and seed_value >= 0, "the bake records its grammar and seed (%s)" % [meta.get("grammar", "")])
	var g := GeneratedRoom.new()
	g.root_room = true
	g.gen_seed = seed_value
	g.grammar = grammar
	root.add_child(g)
	await process_frame
	var fresh: Dictionary = {}
	for n: Node in g.modules:
		fresh[str(g.get_path_to(n))] = [n.scene_file_path, (n as Node3D).transform]
	var same: int = 0
	var differ: PackedStringArray = []
	for path: String in fresh:
		var b := baked.get_node_or_null(path) as Node3D
		if b != null and b.scene_file_path == fresh[path][0] and b.transform.is_equal_approx(fresh[path][1]):
			same += 1
		else:
			differ.append(path)
	check(differ.is_empty() and same == g.modules.size(), "the baked scene is the template, module for module (%d of %d; differ %s)" % [same, g.modules.size(), differ.slice(0, 5)])
	check(baked.get_node_or_null("PlayerSpawn") != null and baked.get_node("Connectors").get_child_count() == 3, "the bake has its spawn and three doors")
	var sets: Dictionary = {}
	for s: Node in baked.find_children("*", "VariantSocket", true, false):
		var vs := s as VariantSocket
		var name: String = vs.socket_set.resource_path.get_file().get_basename() if vs.socket_set != null else "none"
		sets[name] = sets.get(name, 0) + 1
	check(sets.get("court_cell", 0) == 13 and sets.get("court_cell_upper", 0) == 15 and sets.get("court_hearth", 0) == 1,
		"every cell and the hearth roll what they hold (%s)" % [sets])
	g.queue_free()
	baked.free()
	await process_frame


func plan_checks() -> void:
	var recipe: AreaRecipe = load(RECIPE)
	for s: int in range(1, 21):
		var p: AreaPlan = AreaPlanner.plan(recipe, s)
		var court: AreaPlan.Room = p.rooms[0]
		var hall: AreaPlan.Room = p.room("hall")
		check(p.errors.is_empty(), "lower stacks %d: plans clean (%s)" % [s, p.errors])
		check(court.slot_id == "caravanserai" and court.kind == "scene" and court.pinned, "lower stacks %d: the baked court is the pinned root" % s)
		check(hall != null and hall.parent == "caravanserai" and hall.parent_connector == &"SNAP_exit_0_0_0_S", "lower stacks %d: the hall joins the gate" % s)
		check(court.sight.size() == 60 and court.blocked_cells.size() == 6, "lower stacks %d: the court walks as baked (%d open edges, %d blocked)" % [s, court.sight.size(), court.blocked_cells.size()])
		var owner: Dictionary = {}
		var clash: PackedStringArray = []
		for r: AreaPlan.Room in p.rooms:
			for c: Vector3i in r.cells:
				if owner.has(c):
					clash.append("%s/%s at %s" % [owner[c], r.slot_id, c])
				owner[c] = r.slot_id
		check(clash.is_empty(), "lower stacks %d: no two rooms share a cell (%s)" % [s, clash.slice(0, 4)])

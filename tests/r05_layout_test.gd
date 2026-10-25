extends SceneTree
## R05 layout gate (phase-5-design.md 5.6.7 and 5.6.9), headless:
##   godot --headless --path . --script res://tests/r05_layout_test.gd
## The caravanserai template in each size (5 x 5, 7 x 5, 3 x 3), seeds 1-20, laid out as an area's root
## and as a joined room: the grid checks clean; its cells (the corners solid)
## mirror each other across the gate's axis; the gate is cell (0, 0, 0) with
## the entry door, side doors in the side walls' middle; the stair halls take
## the entry wall's corner cells (a 3 x 3: the side walls' far cells) and
## open to the court at the corner end only; every piece is there once per cell (bays, upper cells, passages,
## corners, the two stairs mirrored, the gate, the paving, the rock, the
## hearth at the centre, the well in a far corner, lantern strings, cell and loggia
## lamps); the loggia's cells run round the ring without a gap; every slot
## has its kit module; the same seed gives the same court; a dead end keeps
## only its entry. The baked scene is the template, module for module, with
## its sockets. The Lower Stacks, seeds 1-20: the baked court is the root,
## pinned, in every size, the hall joins its gate, and no two rooms share a cell.

## Per size: its grammar, bake and what it holds (the 3 x 3's stair halls run
## up its side walls into the far corners, its side doors are the side walls'
## first cells, and it has no well).
const SIZES: Dictionary = {
	"5x5": {"grammar": "res://gen/grammars/r05_court_5x5.tres", "baked": "res://rooms/baked/caravanserai_5x5.tscn", "h": 3, "top": 6,
		"kinds": {"court": 25, "bay": 13, "passage": 2, "gate": 1, "stair": 4}, "upper": 15, "loggia": 15, "cell_bays": 13, "doors": 3, "blocked": 6},
	"7x5": {"grammar": "res://gen/grammars/r05_court_7x5.tres", "baked": "res://rooms/baked/caravanserai_7x5.tscn", "h": 4, "top": 6,
		"kinds": {"court": 35, "bay": 17, "passage": 2, "gate": 1, "stair": 4}, "upper": 19, "loggia": 17, "cell_bays": 17, "doors": 3, "blocked": 6},
	"3x3": {"grammar": "res://gen/grammars/r05_court_3x3.tres", "baked": "res://rooms/baked/caravanserai_3x3.tscn", "h": 2, "top": 4,
		"kinds": {"court": 9, "bay": 5, "passage": 2, "gate": 1, "stair": 4}, "upper": 7, "loggia": 3, "cell_bays": 5, "doors": 3, "blocked": 5},
}
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
	for size: String in SIZES:
		var want: Dictionary = SIZES[size]
		var grammar: CourtyardGrammar = load(want["grammar"])
		check(grammar.rules.check().is_empty(), "the court's rules check clean (%s)" % [grammar.rules.check()])
		for s: int in range(1, 21):
			for root_room: bool in [true, false]:
				layout_checks(grammar, want, "%s seed %d %s" % [size, s, "root" if root_room else "joined"], s, root_room)
		var dead := CellGrid.new()
		dead.root = true
		dead.end_kind = "dead_end"
		grammar.layout(dead, 1)
		var dead_doors: int = 0
		for k: String in dead.edges:
			dead_doors += 1 if dead.edges[k]["mark"] == CellGrid.Mark.DOOR else 0
		check(dead_doors == 1, "%s: a dead-end court keeps only its gate (%d doors)" % [size, dead_doors])
		await bake_checks(grammar, want, size)
	plan_checks()
	print("r05_layout_test: %d checks, %d failures" % [checks, failures.size()])
	for f: String in failures.slice(0, 40):
		print("  FAIL ", f)
	quit(1 if not failures.is_empty() else 0)


func layout_checks(grammar: CourtyardGrammar, want: Dictionary, tag: String, s: int, root_room: bool) -> void:
	var grid := CellGrid.new()
	grid.root = root_room
	grammar.layout(grid, s)
	check(grid.check().is_empty(), "%s: the grid checks clean (%s)" % [tag, grid.check()])
	var m: Dictionary = grid.meta
	var h: int = m["h"]
	var top: int = m["top"]
	var cells: int = (2 * h + 1) * (top + 1) - 4
	check(h == want["h"] and top == want["top"] and grid.cells.size() == cells, "%s: a ring round the court, corners solid (%d cells)" % [tag, grid.cells.size()])
	var kinds: Dictionary = {}
	var mirrored: bool = true
	for c: Vector3i in grid.cells:
		var kind: String = grid.cells[c]["kind"]
		kinds[kind] = kinds.get(kind, 0) + 1
		var twin := Vector3i(-c.x, 0, c.z)
		if not grid.cells.has(twin) or grid.cells[twin]["kind"] != kind:
			mirrored = false
	check(kinds == want["kinds"], "%s: cells by kind %s" % [tag, kinds])
	check(mirrored, "%s: the court mirrors across the gate's axis" % tag)
	var entry: Dictionary = grid.edge(Vector3i.ZERO, CellGrid.Side.S)
	check(grid.cells[Vector3i.ZERO]["kind"] == "gate" and entry.get("mark", -1) == CellGrid.Mark.DOOR and entry.get("host", true) == not root_room,
		"%s: the gate is cell (0, 0, 0), its S side the entry (%s)" % [tag, entry])
	var doors: Array = m["doors"]
	var mid: int = 1 if grammar.side_stairs() else top / 2
	check(doors.size() == want["doors"] and (doors.size() == 1 or (doors[1] == [Vector3i(-h, 0, mid), CellGrid.Side.W] and doors[2] == [Vector3i(h, 0, mid), CellGrid.Side.E])),
		"%s: side doors in the side walls' middle (%s)" % [tag, doors])
	for d: Array in doors.slice(1):
		var e: Dictionary = grid.edge(d[0], d[1])
		check(e.get("mark", -1) == CellGrid.Mark.DOOR and not e["host"] and grid.cells[d[0]]["kind"] == "passage", "%s: the door at %s is an exit through a passage" % [tag, d[0]])
	var stairs: Array = m["stairs"]
	var side_stairs: bool = grammar.side_stairs()
	var want_stairs: Array = [[Vector3i(-h + 1, 0, 0), Vector3i(-h + 2, 0, 0)], [Vector3i(h - 1, 0, 0), Vector3i(h - 2, 0, 0)]]
	if side_stairs:
		want_stairs = [[Vector3i(-h, 0, top - 1), Vector3i(-h, 0, top - 2)], [Vector3i(h, 0, top - 1), Vector3i(h, 0, top - 2)]]
	check(stairs == want_stairs, "%s: the stair halls %s (%s)" % [tag, "up the side walls" if side_stairs else "flank the gate", stairs])
	for st: Array in stairs:
		var face: int = CourtyardGrammar.court_side(st[0], h, top)
		var corner_end: Dictionary = grid.edge(st[0], face)
		var other_end: Dictionary = grid.edge(st[1], face)
		var between: int = -1
		for side: int in CellGrid.ALL_SIDES:
			if CellGrid.neighbour(st[0], side) == st[1]:
				between = side
		check(corner_end["mark"] == CellGrid.Mark.OPENING and other_end["mark"] == CellGrid.Mark.SOLID and grid.edge(st[0], between)["mark"] == CellGrid.Mark.OPEN,
			"%s: the stair hall %s opens to the court at its corner end only" % [tag, st])
	# Pieces.
	var slots: Dictionary = {}
	for k: String in grid.props:
		var slot: String = grid.props[k]["slot"]
		slots[slot] = slots.get(slot, 0) + 1
		check(grammar.rules.rule_for(slot, grammar.styles) != null, "%s: slot %s has its kit module" % [tag, slot])
	var kinds_want: Dictionary = want["kinds"]
	var pieces: Dictionary = {"cell:court_floor": kinds_want["court"], "cell:court_bay": kinds_want["bay"], "cell:court_bay_upper": want["upper"],
		"cell:court_gate": 1, "cell:court_stair": 1, "cell:court_stair_r": 1, "cell:court_corner": 4, "cell:court_corner_upper": 2,
		"cell:court_corner_upper_stair": 1, "cell:court_corner_upper_stair_r": 1, grammar.ceiling_slot: 1, "court:hearth": 1,
		grammar.lantern_string_slot: grammar.lantern_strings, "court:loggia_lantern": ceili((want["loggia"] - grammar.loggia_lamp_every / 2) / float(grammar.loggia_lamp_every)),
		"court:cell_lantern": ceili(want["cell_bays"] / float(grammar.cell_lamp_every))}
	if want["doors"] - (0 if root_room else 1) > 0:
		pieces["stub:exit"] = want["doors"] - (0 if root_room else 1)
	if kinds_want.has("passage"):
		pieces["cell:court_passage"] = kinds_want["passage"]
	if grammar.well:
		pieces["court:well"] = 1
	check(slots == pieces, "%s: pieces %s" % [tag, slots])
	var centre: Vector3i = m["centre"]
	check(centre == Vector3i(0, 0, top / 2) and (grid.props["hearth"]["xf"] as Transform3D).origin.is_equal_approx(CellGrid.cell_centre(centre)) and grid.cells[centre].get("blocked", false),
		"%s: the hearth stands at the court's centre, its cell blocked" % tag)
	if grammar.well:
		var well: Vector3i = m["well"]
		check(absi(well.x) == h - 1 and well.z == top - 1 and grid.cells[well].get("blocked", false), "%s: the well in a far corner of the court, blocked (%s)" % [tag, well])
	# The loggia: every upper cell of the side and far walls (a 3 x 3: the far
	# wall's), each next to the last (or round a corner: two apart diagonally),
	# from the west stair to the east.
	var upper: Array = m["upper"]
	var first := Vector3i(-h + 1, 1, top) if side_stairs else Vector3i(-h, 1, 1)
	var joined: bool = upper.size() == want["loggia"] and upper[0] == first and upper[-1] == Vector3i(-first.x, 1, first.z)
	for i: int in upper.size() - 1:
		var d: Vector3i = (upper[i + 1] as Vector3i) - (upper[i] as Vector3i)
		if d.length_squared() != 1 and d.abs() != Vector3i(1, 0, 1):
			joined = false
	check(joined, "%s: the loggia runs round without a gap (%s)" % [tag, upper])
	var again := CellGrid.new()
	again.root = root_room
	grammar.layout(again, s)
	check(again.signature() == grid.signature() and again.props.keys() == grid.props.keys(), "%s: the same seed, the same court" % tag)


func bake_checks(grammar: CourtyardGrammar, want: Dictionary, size: String) -> void:
	var baked := (load(want["baked"]) as PackedScene).instantiate() as RoomTemplate
	var meta: Dictionary = baked.get_meta("baked_from", {})
	var seed_value: int = int(meta.get("seed", -1))
	check(meta.get("grammar", "") == want["grammar"] and seed_value >= 0, "%s: the bake records its grammar and seed (%s)" % [size, meta.get("grammar", "")])
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
	check(differ.is_empty() and same == g.modules.size(), size + ": the baked scene is the template, module for module (%d of %d; differ %s)" % [same, g.modules.size(), differ.slice(0, 5)])
	check(baked.get_node_or_null("PlayerSpawn") != null and baked.get_node("Connectors").get_child_count() == want["doors"], "%s: the bake has its spawn and its %d doors" % [size, want["doors"]])
	var sets: Dictionary = {}
	for s: Node in baked.find_children("*", "VariantSocket", true, false):
		var vs := s as VariantSocket
		var name: String = vs.socket_set.resource_path.get_file().get_basename() if vs.socket_set != null else "none"
		sets[name] = sets.get(name, 0) + 1
	check(sets.get("court_cell", 0) == want["kinds"]["bay"] and sets.get("court_cell_upper", 0) == want["upper"] and sets.get("court_hearth", 0) == 1,
		size + ": every cell and the hearth roll what they hold (%s)" % [sets])
	g.queue_free()
	baked.free()
	await process_frame


func plan_checks() -> void:
	var recipe: AreaRecipe = load(RECIPE)
	var seen: Dictionary = {}
	for s: int in range(1, 21):
		var p: AreaPlan = AreaPlanner.plan(recipe, s)
		var court: AreaPlan.Room = p.rooms[0]
		var hall: AreaPlan.Room = p.room("hall")
		check(p.errors.is_empty(), "lower stacks %d: plans clean (%s)" % [s, p.errors])
		check(court.slot_id == "caravanserai" and court.kind == "scene" and court.pinned, "lower stacks %d: the baked court is the pinned root" % s)
		check(hall != null and hall.parent == "caravanserai" and hall.parent_connector == &"SNAP_exit_0_0_0_S", "lower stacks %d: the hall joins the gate" % s)
		var size: String = court.scene.resource_path.get_file().get_basename().trim_prefix("caravanserai_")
		seen[size] = true
		var baked: Node = court.scene.instantiate()
		var walk: Array = (baked.get_meta("baked_from", {}) as Dictionary).get("walk", [])
		baked.free()
		check(SIZES.has(size) and court.sight.size() == walk.size() and court.blocked_cells.size() == SIZES[size]["blocked"],
			"lower stacks %d: the %s court walks as baked (%d open edges, %d blocked)" % [s, size, court.sight.size(), court.blocked_cells.size()])
		var owner: Dictionary = {}
		var clash: PackedStringArray = []
		for r: AreaPlan.Room in p.rooms:
			for c: Vector3i in r.cells:
				if owner.has(c):
					clash.append("%s/%s at %s" % [owner[c], r.slot_id, c])
				owner[c] = r.slot_id
		check(clash.is_empty(), "lower stacks %d: no two rooms share a cell (%s)" % [s, clash.slice(0, 4)])
	check(seen.size() == SIZES.size(), "lower stacks 1-20: the court comes in every size (%s)" % [seen.keys()])

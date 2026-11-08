@tool
class_name ReadingRoomGrammar
extends RoomGrammar
## R01 Reading Room (design/room-atlas.html): a tall hall three bays wide and
## five long, a gallery round its entry end reached by a stair up each side,
## an iwan at the far end. Reading tables down the hall, floor seats by the
## entry, lamps on the furniture. rooms/authored/reading_room.tscn is the
## hand-built room this came from.
##
## Two versions (gen/grammars/r01_reading_*.tres): fixed_styles gallery_build
## says masonry or wood steps and deck. Kept or left is the room's State on
## the Strata Board (RoomGrammar.state_options), which sets `abandoned`.
##
## Up to five doors: the entry, a door in the second bay of each side wall,
## and a shelf bay at the far end of each side wall that opens only if a room
## grows there (grid.meta optional_doors, as the hall's).
##
## Cell x -1..1, z 0..4 (the entry is the S side of cell (0, 0, 0)); z 5 is the
## iwan's depth and storey 1 the upper hall: neither is walked as cells, both
## are there so nothing else is built in them.

## Kept or left: shelves emptied, flames out, furniture gone, water and rubble.
## Set by the State setting (_abandon), not in a grammar file.
@export var abandoned: bool = false:
	set(value):
		abandoned = value
		emit_changed()
## Side doors that are real doors (0 to 2).
@export_range(0, 2) var side_doors: int = 2:
	set(value):
		side_doors = value
		emit_changed()
## Far-end shelf bays that can open (0 to 2).
@export_range(0, 2) var spare_doors: int = 2:
	set(value):
		spare_doors = value
		emit_changed()
## Left: the chance each reading group is gone.
@export_range(0.0, 1.0, 0.01) var gone_chance: float = 0.6:
	set(value):
		gone_chance = value
		emit_changed()

const ROWS: int = 5
const BAY: float = CellGrid.BAY
const LEFT_TINT := Color(0.42, 0.6, 0.85, 0.55)
const COOL := Color(0.1725, 0.4549, 0.902)


func state_options() -> PackedStringArray:
	return ["Kept", "Abandoned", "Kept: full shelves, lamps lit, readers' things on the tables. Abandoned: shelves emptied, flames out, furniture gone, water and rubble, a cold blue light."]


func _abandon() -> void:
	abandoned = true
	wetness = 0.35


func layout(grid: CellGrid, seed_value: int) -> void:
	if not _free(grid):
		if not grid.quiet:
			push_warning("ReadingRoomGrammar: no room for the hall")
		return
	var exits: bool = (grid.end_kind if grid.end_kind != "" else "exit") == "exit"
	var doors: Array = []
	var spare: Array = []
	if exits:
		var sides: Array = [[Vector3i(-1, 0, 1), CellGrid.Side.W], [Vector3i(1, 0, 1), CellGrid.Side.E]]
		for d: Array in sides.slice(0, side_doors):
			if grid.is_free(CellGrid.neighbour(d[0], d[1])):
				doors.append(d)
		var far: Array = [[Vector3i(-1, 0, 4), CellGrid.Side.W], [Vector3i(1, 0, 4), CellGrid.Side.E]]
		for d: Array in far.slice(0, spare_doors):
			if grid.is_free(CellGrid.neighbour(d[0], d[1])):
				spare.append(d)
	_add_cells(grid)
	_mark_edges(grid, doors)
	_place_shell(grid)
	_place_gallery(grid)
	_place_lights(grid)
	if abandoned:
		_place_left(grid, seed_value)
	else:
		_place_furniture(grid, {})
	_pin_shelves(grid, seed_value)
	_clear_above_doors(grid, doors, spare)
	grid.meta["optional_doors"] = spare
	grid.meta["doors"] = doors
	# Past the rug's table, down the side of it (tests/area_tour.gd).
	grid.meta["walk_stops"] = {Vector3i(2, 0, -10): Vector3(3.2, 0, -10)}
	if abandoned:
		grid.meta["abandon_end"] = 0.8


## A shelf recess reaches past the wall line, so over a door in use the next
## room's vault would show in it: those upper bays are plain. Spare bays go
## plain only if they open (grid.meta over_door, read by the planner).
func _clear_above_doors(grid: CellGrid, doors: Array, spare: Array) -> void:
	for d: Array in doors:
		var bay: String = _upper_bay(d)
		grid.props[bay]["slot"] = "edge:plain"
		grid.pins.erase("prop_" + bay)
	var over: Dictionary = {}
	for d: Array in spare:
		over[CellGrid.key(d[0], d[1])] = _upper_bay(d)
	grid.meta["over_door"] = over


func _upper_bay(door: Array) -> String:
	return ("upper_w_%d" if door[1] == CellGrid.Side.W else "upper_e_%d") % door[0].z


func _free(grid: CellGrid) -> bool:
	for z: int in ROWS + 1:
		for x: int in range(-1, 2):
			for y: int in 2:
				if not grid.is_free(Vector3i(x, y, z)):
					return false
	return true


func _add_cells(grid: CellGrid) -> void:
	for z: int in ROWS + 1:
		for x: int in range(-1, 2):
			var c := Vector3i(x, 0, z)
			var up := Vector3i(x, 1, z)
			grid.add_cell(c, "floor" if z < ROWS else "iwan", Vector3i(0, 0, 1), z)
			grid.add_cell(up, "air", Vector3i(0, 0, 1), z)
			var cell: Dictionary = grid.cells[c]
			cell["ceiling_slot"] = ""
			cell["gables"] = false
			cell["links"] = [up]
			if z == ROWS:
				cell["floor_slot"] = ""        # the iwan brings its own
				cell["blocked"] = true
				cell["no_floor"] = x != 0        # the iwan is narrower than the hall
			elif x != 0 and z in [0, 2, 3]:
				cell["blocked"] = true        # seats, tables and stair foot: the way is down the hall
			var air: Dictionary = grid.cells[up]
			air["floor_slot"] = ""
			air["ceiling_slot"] = ""
			air["gables"] = false
			air["blocked"] = true
			air["no_floor"] = true
			air["no_map"] = true


func _mark_edges(grid: CellGrid, doors: Array) -> void:
	var door_at: Dictionary = {}
	for d: Array in doors:
		door_at[CellGrid.key(d[0], d[1])] = true
	for c: Vector3i in grid.cells:
		for side: int in CellGrid.ALL_SIDES:
			var n: Vector3i = CellGrid.neighbour(c, side)
			var k: String = CellGrid.key(c, side)
			if grid.cells.has(n):
				var mouth: bool = c.y == 0 and (grid.cells[c]["kind"] == "iwan") != (grid.cells[n]["kind"] == "iwan")
				grid.set_edge(c, side, CellGrid.Mark.OPENING if mouth else CellGrid.Mark.OPEN, false, "none" if mouth else "")
			elif c.y != 0 or c.z == ROWS or side == CellGrid.Side.N:
				grid.set_edge(c, side, CellGrid.Mark.SOLID, false, "none")
			elif side == CellGrid.Side.S:
				_mark_entry_wall(grid, c, side, k)
			elif door_at.has(k):
				grid.set_edge(c, side, CellGrid.Mark.DOOR)
				grid.props["exit_" + k] = {"slot": "stub:exit", "xf": CellGrid.door_transform(c, side)}
			elif c.z == 2 or c.z == 3:
				grid.set_edge(c, side, CellGrid.Mark.SOLID, false, "edge:plain")     # behind the stairs
			else:
				grid.set_edge(c, side, CellGrid.Mark.SOLID)


## The entry wall: the door in the middle, plain either side, no piers along
## it (the gallery's columns stand there).
func _mark_entry_wall(grid: CellGrid, c: Vector3i, side: int, k: String) -> void:
	if c.x != 0:
		grid.set_edge(c, side, CellGrid.Mark.SOLID, false, "none")
		grid.props["entry_wall_" + k] = {"slot": "edge:plain", "xf": CellGrid.edge_transform(c, side), "shell": true}
	elif grid.root:
		grid.set_edge(c, side, CellGrid.Mark.DOOR, false, "none")
		grid.props["entry_arch"] = {"slot": "edge:door", "xf": CellGrid.edge_transform(c, side), "shell": true}
		grid.props["exit_" + k] = {"slot": "stub:exit", "xf": CellGrid.door_transform(c, side)}
	else:
		grid.set_edge(c, side, CellGrid.Mark.DOOR, true)


func _shell(grid: CellGrid, key: String, slot: String, xf: Transform3D) -> void:
	grid.props[key] = {"slot": slot, "xf": xf, "shell": true}


func _place_shell(grid: CellGrid) -> void:
	for z: int in ROWS:
		_shell(grid, "vault_%d" % z, "cell:vault", Transform3D(Basis(), Vector3(-BAY, BAY, -z * BAY)))
		_shell(grid, "upper_w_%d" % z, "edge:solid", CellGrid.edge_transform(Vector3i(-1, 1, z), CellGrid.Side.W))
		_shell(grid, "upper_e_%d" % z, "edge:solid", CellGrid.edge_transform(Vector3i(1, 1, z), CellGrid.Side.E))
	for z: int in ROWS + 1:
		_shell(grid, "upper_pier_w_%d" % z, "post:pier", Transform3D(Basis(), Vector3(-BAY, BAY, -z * BAY)))
		_shell(grid, "upper_pier_e_%d" % z, "post:pier", Transform3D(Basis(), Vector3(2.0 * BAY, BAY, -z * BAY)))
	for x: int in range(-1, 2):
		_shell(grid, "upper_s_%d" % (x + 1), "edge:solid" if x == 0 and grid.root else "edge:plain", CellGrid.edge_transform(Vector3i(x, 1, 0), CellGrid.Side.S))
	_shell(grid, "gable_s", "edge:gable_12m", Transform3D(Basis(), Vector3(-BAY, BAY, 0)))
	var far := Transform3D(Basis(Vector3.UP, PI), Vector3(2.0 * BAY, 0, -ROWS * BAY))
	_shell(grid, "iwan", "edge:iwan", far)
	_shell(grid, "gable_n", "edge:gable_12m", Transform3D(far.basis, far.origin + Vector3(0, BAY, 0)))


## Round the entry end: the deck along the entry wall and the first two bays
## of each side, a stair up each side wall, the columns under the deck.
func _place_gallery(grid: CellGrid) -> void:
	var w0: Transform3D = CellGrid.edge_transform(Vector3i(-1, 0, 0), CellGrid.Side.W)
	var w1: Transform3D = CellGrid.edge_transform(Vector3i(-1, 0, 1), CellGrid.Side.W)
	var e0: Transform3D = CellGrid.edge_transform(Vector3i(1, 0, 0), CellGrid.Side.E)
	var e1: Transform3D = CellGrid.edge_transform(Vector3i(1, 0, 1), CellGrid.Side.E)
	var e2: Transform3D = CellGrid.edge_transform(Vector3i(1, 0, 2), CellGrid.Side.E)
	var s := Transform3D(Basis(), Vector3(-BAY, 0, 0))
	_shell(grid, "deck_end", "edge:gallery_end", s)
	_shell(grid, "deck_w0", "edge:gallery_open_end", w0)
	_shell(grid, "deck_e0", "edge:gallery_open_start", e0)
	_shell(grid, "deck_w1", "edge:gallery_slab", w1)
	_shell(grid, "deck_e1", "edge:gallery_slab", e1)
	_shell(grid, "stair_w", "edge:gallery_stair", CellGrid.edge_transform(Vector3i(-1, 0, 3), CellGrid.Side.W))
	_shell(grid, "stair_e", "edge:gallery_stair_r", e2)
	_shell(grid, "col_corner_w", "gallery:corner", s)
	_shell(grid, "col_corner_e", "gallery:corner_r", e0)
	_shell(grid, "col_w0", "gallery:column", w0)
	_shell(grid, "col_w1", "gallery:column", w1)
	_shell(grid, "col_e1", "gallery:column", e1)
	_shell(grid, "col_e2", "gallery:column", e2)
	_shell(grid, "col_s0", "gallery:column", Transform3D(Basis(), Vector3.ZERO))
	_shell(grid, "col_s1", "gallery:column", Transform3D(Basis(), Vector3(BAY, 0, 0)))


func _place_lights(grid: CellGrid) -> void:
	for p: Array in [["cluster_near", -6.0], ["cluster_far", -14.0]]:
		grid.props[p[0]] = {"slot": "lamp:cluster", "xf": Transform3D(Basis(), Vector3(2, 0, p[1])), "shell": true,
			"meta": {"ageless": true, "light_energy_scale": 0.45}}
		if abandoned:
			grid.pins["prop_" + p[0]] = "dark"
	_shell(grid, "lantern_iwan", "lamp:hanging", Transform3D(Basis(), Vector3(2, 3.5, -21.5)))
	var energy: float = 1.1 if abandoned else 0.5
	var reach: float = 11.0 if abandoned else 9.0
	grid.fills["CoolFillWest"] = {"at": Vector3(-2, 6.5, -14), "colour": COOL, "energy": energy, "range": reach}
	grid.fills["CoolFillEast"] = {"at": Vector3(6, 6.5, -14), "colour": COOL, "energy": energy, "range": reach}
	if abandoned:
		grid.pins["prop_lantern_iwan"] = "failing"
		grid.fills["CoolFillEntry"] = {"at": Vector3(2, 6.5, -5), "colour": COOL, "energy": 0.9, "range": 11.0}
		grid.fills["CoolFillFar"] = {"at": Vector3(2, 3.0, -16), "colour": COOL, "energy": 1.0, "range": 12.0}
	else:
		grid.fills["IwanGlow"] = {"at": Vector3(2, 2.4, -21), "colour": Color(1, 0.8118, 0.5412), "energy": 1.2, "range": 5.0}


## The reading tables down the hall, the seats by the entry. `gone`: groups
## left out.
func _place_furniture(grid: CellGrid, gone: Dictionary) -> void:
	var quarter := Basis(Vector3.UP, PI * 0.5)
	if not gone.has("rug"):
		grid.props["rug_hall"] = {"slot": "dressing:rug_hall", "xf": Transform3D(Basis(), Vector3(2, 0, -10))}
	for g: Array in [["w1", -1.0, -10.0, -1.0], ["w2", -1.0, -14.0, -1.0], ["e1", 5.0, -10.0, 1.0], ["e2", 5.0, -14.0, 1.0]]:
		if gone.has(g[0]):
			continue
		var x: float = g[1]
		var z: float = g[2]
		var wall: float = g[3]        # which way the wall is from the table
		grid.props["table_" + g[0]] = {"slot": "dressing:table", "xf": Transform3D(quarter, Vector3(x, 0, z))}
		grid.props["seat_" + g[0]] = {"slot": "dressing:seat", "xf": Transform3D(Basis(Vector3.UP, PI * 0.5 * wall * -1.0 if wall < 0.0 else PI * 0.5), Vector3(x + wall, 0, z))}
		grid.props["pouf_%s_a" % g[0]] = {"slot": "dressing:pouf", "xf": Transform3D(Basis(), Vector3(x - wall, 0, z + 0.5))}
		grid.props["pouf_%s_b" % g[0]] = {"slot": "dressing:pouf", "xf": Transform3D(Basis(), Vector3(x - wall, 0, z - 0.5))}
	for g: Array in [["w", -1.0, -2.0, 0.5], ["e", 5.0, 6.0, 3.5]]:
		if gone.has("nook_" + g[0]):
			continue
		grid.props["nook_rug_" + g[0]] = {"slot": "dressing:rug_nook", "xf": Transform3D(quarter, Vector3(g[1], 0, -2.75))}
		grid.props["nook_seat_" + g[0]] = {"slot": "dressing:seat", "xf": Transform3D(Basis(), Vector3(g[1], 0, -1.5))}
		grid.props["nook_pouf_" + g[0]] = {"slot": "dressing:pouf", "xf": Transform3D(Basis(), Vector3(g[2], 0, -2))}
		grid.props["nook_tray_" + g[0]] = {"slot": "dressing:tray", "xf": Transform3D(Basis(), Vector3(g[3], 0, -2))}
	grid.props["vase_w"] = {"slot": "dressing:vase", "xf": Transform3D(Basis(), Vector3(-1.8, 0, -16.6))}
	grid.props["vase_e"] = {"slot": "dressing:vase", "xf": Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(5.8, 0, -16.6))}


## Left: most of the furniture gone, what remains among rubble and standing
## water, low fog over the floor, shelves empty (_pin_shelves).
func _place_left(grid: CellGrid, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, "left"])
	var gone: Dictionary = {}
	for g: String in ["w1", "w2", "e1", "e2", "nook_w", "nook_e", "rug"]:
		if rng.randf() < gone_chance:
			gone[g] = true
	_place_furniture(grid, gone)
	var cells: Array = grid.cells.keys()
	cells.sort()
	for c: Vector3i in cells:
		if c.y != 0 or c.z >= ROWS:
			continue
		var n: String = CellGrid.cell_name(c)
		var at: Vector3 = CellGrid.cell_centre(c)
		grid.props["fog_" + n] = {"slot": "fx:ground_fog", "xf": Transform3D(Basis(), at)}
		if rng.randf() < 0.3:
			var off := Vector3(rng.randf_range(-1.0, 1.0), 0, rng.randf_range(-1.0, 1.0))
			grid.props["puddle_" + n] = {"slot": "dressing:puddle", "xf": Transform3D(Basis(Vector3.UP, rng.randf() * TAU), at + off)}
	for k: String in grid.edges:
		if grid.edges[k]["mark"] == CellGrid.Mark.DOOR:
			grid.pins["edge_" + k] = "heavy"
	grid.pins["prop_iwan"] = "heavy"


## Two shelves hold the room's lore books; the far-end bays are working niches
## (seeded) while kept. Left, shelves are sparse or fallen.
func _pin_shelves(grid: CellGrid, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, "shelves"])
	var lore_label: String = "sparse shelves" if abandoned else "full shelves"
	grid.pins["edge_" + CellGrid.key(Vector3i(-1, 0, 0), CellGrid.Side.W)] = lore_label
	grid.pins["prop_upper_w_0"] = lore_label
	var far: Array[String] = ["edge_" + CellGrid.key(Vector3i(-1, 0, 4), CellGrid.Side.W), "edge_" + CellGrid.key(Vector3i(1, 0, 4), CellGrid.Side.E)]
	if not abandoned:
		var niches: Array[String] = ["hearth niche", "herb niche", "pantry niche"]
		for b: String in far:
			grid.pins[b] = niches[rng.randi_range(0, niches.size() - 1)]
		return
	var bays: Array[String] = far.duplicate()
	bays.append("edge_" + CellGrid.key(Vector3i(1, 0, 0), CellGrid.Side.E))
	bays.append("prop_upper_s_1")
	for z: int in ROWS:
		bays.append("prop_upper_w_%d" % z)
		bays.append("prop_upper_e_%d" % z)
	for b: String in bays:
		if not grid.pins.has(b):
			var fallen: bool = rng.randf() < 0.45
			grid.pins[b] = "collapsed" if fallen else "sparse shelves"
			if fallen and b.begins_with("edge_") and not b.contains("_0_0_"):        # along the wall's foot, as the stacks'; not by the gallery corners
				var k: String = b.trim_prefix("edge_")
				var e: Dictionary = grid.edges[k]
				grid.props["rubble_" + k] = {"slot": "dressing:rubble", "xf": CellGrid.edge_transform(e["cell"], e["side"])}


## Blue where left, as the far stacks.
func tint_at(_grid: CellGrid, _local: Vector3) -> Color:
	return LEFT_TINT if abandoned else mood_tint

@tool
class_name CourtyardGrammar
extends RoomGrammar
## R05 Caravanserai (design/room-atlas.html; phase-5-design.md 5.6.7): a court
## open to the cavern, ringed by two storeys of arched cells, a pishtaq gate
## on the entry wall with a stair hall either side of it, side doors, a raised
## hearth in the middle and a well. A template: generated once per size, then
## baked to a scene (tools/bake_court.gd) and finished by hand.
##
## The ring is one bay deep round a court of court_w x court_d bays. The gate
## is cell (0, 0, 0), the entry (S) wall's middle; its S side is the entry
## door (an exit when the court is an area's root). Each stair takes the two
## entry-wall cells next to a corner and comes up into the corner, where the
## upper storey's loggia turns along the side walls; the loggia runs through
## every upper cell of the side and far walls. Every piece is a grid prop
## (tools/kit_add_r05.py), placed like an edge module on its cell's court
## side; the grid's edges only say what opens onto what (the bake keeps them
## for walking, AreaPlanner._scene_info).

## Court bays across (odd, at least 5: the gate and a stair hall each side)
## and deep.
@export_range(5, 9, 2) var court_w: int = 5:
	set(value):
		court_w = value
		emit_changed()
@export_range(3, 9) var court_d: int = 5:
	set(value):
		court_d = value
		emit_changed()
## Doors through the side walls' middle cells: 0, 1 (west) or 2.
@export_range(0, 2) var side_doors: int = 2:
	set(value):
		side_doors = value
		emit_changed()
## Strings of lanterns across the court.
@export_range(0, 6) var lantern_strings: int = 3:
	set(value):
		lantern_strings = value
		emit_changed()
## A lantern under the loggia's beams in every Nth upper cell round the ring
## (0 = none).
@export_range(0, 8) var loggia_lamp_every: int = 3:
	set(value):
		loggia_lamp_every = value
		emit_changed()
## A lantern in the mouth of every Nth ground cell round the ring (0 = none):
## with every cell lit the court went over the light budget.
@export_range(0, 8) var cell_lamp_every: int = 2:
	set(value):
		cell_lamp_every = value
		emit_changed()
## The cavern's rock over the court (a piece per size): its slot.
@export var ceiling_slot: String = "cell:cavern_5x5":
	set(value):
		ceiling_slot = value
		emit_changed()

const STOREY := Vector3(0, 4, 0)


func layout(grid: CellGrid, seed_value: int) -> void:
	var h: int = court_w / 2 + 1          # ring cells run x -h..h
	var top: int = court_d + 1            # and z 0..top
	if court_w < 5 or not _free(grid, h, top):
		if not grid.quiet:
			push_warning("CourtyardGrammar: no room for a %d x %d court" % [court_w, court_d])
		return
	var centre := Vector3i(0, 0, top / 2)
	var mid: int = (court_d + 1) / 2
	var stair_w: Array[Vector3i] = [Vector3i(-h + 1, 0, 0), Vector3i(-h + 2, 0, 0)]
	var stair_e: Array[Vector3i] = [Vector3i(h - 1, 0, 0), Vector3i(h - 2, 0, 0)]
	var doors: Array = [[Vector3i.ZERO, CellGrid.Side.S]]
	if side_doors >= 1:
		doors.append([Vector3i(-h, 0, mid), CellGrid.Side.W])
	if side_doors >= 2:
		doors.append([Vector3i(h, 0, mid), CellGrid.Side.E])
	if (grid.end_kind if grid.end_kind != "" else "exit") != "exit":
		doors.resize(1)
	var door_cells: Dictionary = {}
	for d: Array in doors:
		door_cells[d[0]] = d[1]
	for z: int in range(0, top + 1):
		for x: int in range(-h, h + 1):
			var c := Vector3i(x, 0, z)
			var ring: bool = absi(x) == h or z == 0 or z == top
			if ring and absi(x) == h and (z == 0 or z == top):
				continue          # the corners: solid, no cell (planning takes them from the pieces)
			var kind: String = "court"
			if c == Vector3i.ZERO:
				kind = "gate"
			elif stair_w.has(c) or stair_e.has(c):
				kind = "stair"
			elif door_cells.has(c):
				kind = "passage"
			elif ring:
				kind = "bay"
			grid.add_cell(c, kind, Vector3i(0, 0, 1), absi(x) + z)
			var cell: Dictionary = grid.cells[c]
			cell["floor_slot"] = ""
			cell["ceiling_slot"] = ""
			cell["gables"] = false
			if kind == "stair" or c == centre:
				cell["blocked"] = true        # a stair hall's a dead end; the hearth's fire stands mid-court
	_mark_edges(grid, doors, stair_w, stair_e)
	var upper: Array[Vector3i] = _place_ring(grid, h, top, stair_w, stair_e)
	grid.meta = {"court": true, "h": h, "top": top, "centre": centre, "doors": doors,
		"stairs": [stair_w, stair_e], "upper": upper}
	_place_court(grid, h, top, centre, seed_value)
	_place_lamps(grid, upper, h, top)
	grid.props["ceiling"] = {"slot": ceiling_slot, "xf": Transform3D(Basis(), Vector3(-h * CellGrid.BAY, 0, 0)), "shell": true}
	_lanes(grid, doors, centre)


func _free(grid: CellGrid, h: int, top: int) -> bool:
	for z: int in range(0, top + 1):
		for x: int in range(-h, h + 1):
			if not grid.is_free(Vector3i(x, 0, z)):
				return false
	return true


## The side of ring cell c that faces the court (a corner: -1).
static func court_side(c: Vector3i, h: int, top: int) -> int:
	if c.z == 0 and absi(c.x) < h:
		return CellGrid.Side.N
	if c.z == top and absi(c.x) < h:
		return CellGrid.Side.S
	if c.x == -h and c.z > 0 and c.z < top:
		return CellGrid.Side.E
	if c.x == h and c.z > 0 and c.z < top:
		return CellGrid.Side.W
	return -1


## Open between court cells and inside a stair hall, an opening where a ring
## cell's arch (or the gate, or a passage) meets the court, walls (built by
## the pieces) everywhere else; the doors.
func _mark_edges(grid: CellGrid, doors: Array, stair_w: Array[Vector3i], stair_e: Array[Vector3i]) -> void:
	var h: int = court_w / 2 + 1
	var top: int = court_d + 1
	for c: Vector3i in grid.cells:
		for side: int in CellGrid.ALL_SIDES:
			var n: Vector3i = CellGrid.neighbour(c, side)
			if not grid.cells.has(n):
				grid.set_edge(c, side, CellGrid.Mark.SOLID, false, "none")
				continue
			var a: String = grid.cells[c]["kind"]
			var b: String = grid.cells[n]["kind"]
			if a == "court" and b == "court":
				grid.set_edge(c, side, CellGrid.Mark.OPEN)
			elif a == "stair" and b == "stair":
				grid.set_edge(c, side, CellGrid.Mark.OPEN)
			elif a == "court" or b == "court":
				var ring: Vector3i = n if a == "court" else c
				var yard: Vector3i = c if a == "court" else n
				var arch: bool = CellGrid.neighbour(ring, court_side(ring, h, top)) == yard
				# A stair hall opens to the court only at its corner-side cell.
				if grid.cells[ring]["kind"] == "stair":
					arch = ring == stair_w[0] or ring == stair_e[0]
				grid.set_edge(c, side, CellGrid.Mark.OPENING if arch else CellGrid.Mark.SOLID, false, "none")
			else:
				grid.set_edge(c, side, CellGrid.Mark.SOLID, false, "none")
	for i: int in doors.size():
		var c: Vector3i = doors[i][0]
		var side: int = doors[i][1]
		var host: bool = i == 0 and not grid.root
		grid.set_edge(c, side, CellGrid.Mark.DOOR, host, "none")
		if not host:
			grid.props["exit_" + CellGrid.key(c, side)] = {"slot": "stub:exit", "xf": CellGrid.door_transform(c, side)}


## The ring's pieces: bays, the gate, the stair halls, passages and corners
## on both storeys. Returns the upper cells the loggia runs through, in ring
## order from the west stair round to the east one.
func _place_ring(grid: CellGrid, h: int, top: int, stair_w: Array[Vector3i], stair_e: Array[Vector3i]) -> Array[Vector3i]:
	var up := Transform3D(Basis(), STOREY)
	for c: Vector3i in grid.cells:
		var kind: String = grid.cells[c]["kind"]
		var n: String = CellGrid.cell_name(c)
		if kind == "court":
			_piece(grid, "floor_" + n, "cell:court_floor", CellGrid.cell_transform(c, Vector3i(0, 0, 1)))
			continue
		var xf: Transform3D = CellGrid.edge_transform(c, court_side(c, h, top))
		match kind:
			"gate":
				_piece(grid, "gate", "cell:court_gate", xf)
			"bay":
				_piece(grid, "bay_" + n, "cell:court_bay", xf)
			"passage":
				_piece(grid, "passage_" + n, "cell:court_passage", xf)
		if kind == "bay" or kind == "passage":
			_piece(grid, "upper_" + n, "cell:court_bay_upper", up * xf)
	# Stair halls: each piece's X = 8 end is the corner (the mirrored one's X = 0).
	_piece(grid, "stair_w", "cell:court_stair", CellGrid.edge_transform(stair_w[1], CellGrid.Side.N))
	_piece(grid, "stair_e", "cell:court_stair_r", CellGrid.edge_transform(stair_e[0], CellGrid.Side.N))
	for corner: Vector3i in [Vector3i(-h, 0, 0), Vector3i(h, 0, 0), Vector3i(-h, 0, top), Vector3i(h, 0, top)]:
		var inner := Vector3(corner.x * CellGrid.BAY + (CellGrid.BAY if corner.x < 0 else 0.0), 0.0,
			-corner.z * CellGrid.BAY - (CellGrid.BAY if corner.z == 0 else 0.0))
		var frame: int = -1
		for side: int in CellGrid.ALL_SIDES:
			if CellGrid.edge_ends(corner, side)[0].is_equal_approx(inner):
				frame = side
		var xf: Transform3D = CellGrid.edge_transform(corner, frame)
		var n: String = CellGrid.cell_name(corner)
		_piece(grid, "corner_" + n, "cell:court_corner", xf)
		var slot: String = "cell:court_corner_upper"
		if corner.z == 0:
			# The stair comes up through the side facing the entry wall's cells.
			var stair_side: int = CellGrid.Side.E if corner.x < 0 else CellGrid.Side.W
			slot = "cell:court_corner_upper_stair" + ("_r" if stair_side == frame else "")
		_piece(grid, "corner_upper_" + n, slot, up * xf)
	var upper: Array[Vector3i] = []
	for z: int in range(1, top):
		upper.append(Vector3i(-h, 1, z))
	for x: int in range(-h + 1, h):
		upper.append(Vector3i(x, 1, top))
	for z: int in range(top - 1, 0, -1):
		upper.append(Vector3i(h, 1, z))
	return upper


## The court's paving is in _place_ring; the hearth at the middle, the well
## in a far corner (seeded), strings of lanterns across.
func _place_court(grid: CellGrid, h: int, top: int, centre: Vector3i, seed_value: int) -> void:
	grid.props["hearth"] = {"slot": "court:hearth", "xf": Transform3D(Basis(), CellGrid.cell_centre(centre))}
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, "court_well"])
	var well := Vector3i(-(h - 1) if rng.randi_range(0, 1) == 0 else h - 1, 0, top - 1)
	grid.props["well"] = {"slot": "court:well", "xf": Transform3D(Basis(Vector3.UP, rng.randf_range(0.0, TAU)), CellGrid.cell_centre(well))}
	grid.cells[well]["blocked"] = true
	grid.meta["well"] = well
	var x: float = CellGrid.cell_centre(centre).x
	for i: int in lantern_strings:
		var z: float = -CellGrid.BAY - CellGrid.BAY * court_d * (i + 1.0) / (lantern_strings + 1.0)
		grid.props["string_%d" % i] = {"slot": "court:lantern_string", "xf": Transform3D(Basis(), Vector3(x, 0, z))}


## Lanterns in the mouth of every cell_lamp_every-th ground cell round the
## ring, and under the loggia's beams in every loggia_lamp_every-th upper cell.
func _place_lamps(grid: CellGrid, upper: Array[Vector3i], h: int, top: int) -> void:
	var bays: Array[Vector3i] = []
	for c: Vector3i in upper:
		if grid.cells.get(Vector3i(c.x, 0, c.z), {}).get("kind", "") == "bay":
			bays.append(Vector3i(c.x, 0, c.z))
	for x: int in range(-h + 1, h):
		if grid.cells.get(Vector3i(x, 0, 0), {}).get("kind", "") == "bay":
			bays.append(Vector3i(x, 0, 0))
	for i: int in bays.size():
		if cell_lamp_every > 0 and i % cell_lamp_every == 0:
			var xf: Transform3D = CellGrid.edge_transform(bays[i], court_side(bays[i], h, top))
			grid.props["cell_lamp_" + CellGrid.cell_name(bays[i])] = {"slot": "court:cell_lantern", "xf": Transform3D(xf.basis, xf * Vector3(2.0, 0.0, -1.1))}
	if loggia_lamp_every <= 0:
		return
	for i: int in upper.size():
		if i % loggia_lamp_every != loggia_lamp_every / 2:
			continue
		var c: Vector3i = upper[i]
		var xf: Transform3D = CellGrid.edge_transform(Vector3i(c.x, 0, c.z), court_side(Vector3i(c.x, 0, c.z), h, top))
		var at: Vector3 = xf * Vector3(2.0, 0.0, -(0.5 + 1.8) * 0.5) + STOREY + Vector3(0, 0.05, 0)
		grid.props["loggia_lamp_" + CellGrid.cell_name(c)] = {"slot": "court:loggia_lantern", "xf": Transform3D(xf.basis, at)}


## Walked lanes from every door in to the hearth's steps.
func _lanes(grid: CellGrid, doors: Array, centre: Vector3i) -> void:
	grid.wear.clear()
	if not wear_lanes_enabled:
		return
	var mid: Vector2 = _xz(CellGrid.cell_centre(centre))
	for d: Array in doors:
		var door: Transform3D = CellGrid.door_transform(d[0], d[1])
		var from: Vector2 = _xz(door.origin - door.basis.z * WEAR_PAST_DOOR)
		var to: Vector2 = mid + (from - mid).normalized() * 4.4
		_add_lane(grid, [[from, traffic(0)], [_xz(CellGrid.cell_centre(d[0])), traffic(1)], [to, traffic(3)]])


func _piece(grid: CellGrid, key: String, slot: String, xf: Transform3D) -> void:
	grid.props["court_" + key] = {"slot": slot, "xf": xf, "shell": true}


## The court's lanes are laid in layout().
func wear_lanes(_grid: CellGrid, _seed_value: int) -> void:
	pass

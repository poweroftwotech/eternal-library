@tool
class_name ScriptoriumGrammar
extends RoomGrammar
## R08 Orosi Scriptorium (design/room-atlas.html; phase 17,
## docs/environment/phase-17-approval.md). Always the same hall: 12 m wide
## (three cells), one storey 6.4 m high, cream niche walls under a timber
## ceiling, and at the far end the orosi wall (three tall windows of coloured
## glass) with the lumen-moss garden behind it. By seed: the length (Q2, three
## to five cells), the glass palette (Q3) and the rugs.
##
## Cells x -1..1, z 0..rows-1 (the entry is the S side of cell (0, 0, 0)).
## Storey 1 over the hall, and the two rows behind the orosi wall up to
## storey 2 (the garden and the lights standing over it), are kept empty: not
## walked, not mapped, so nothing else is built in them.
##
## Doors: the entry, and a side door in the second bay of each long wall when
## the area can grow there (side_doors). Never through the orosi wall.

## Shortest and longest hall, in cells (Q2).
@export_range(3, 5) var rows_min: int = 3:
	set(value):
		rows_min = value
		emit_changed()
@export_range(3, 5) var rows_max: int = 5:
	set(value):
		rows_max = value
		emit_changed()
## Side doors that are real doors (0 to 2).
@export_range(0, 2) var side_doors: int = 2:
	set(value):
		side_doors = value
		emit_changed()
## "" = by seed; else one of OrosiGlass.PALETTES.
@export var palette: String = "":
	set(value):
		palette = value
		emit_changed()

const BAY: float = CellGrid.BAY
## Rows kept behind the orosi wall: the wall's depth and the garden behind it
## (5.5 m with its rock); storeys kept there: the window lights stand 8.2 m up,
## under the garden's roof at 10.6 m.
const GARDEN_ROWS: int = 2
const GARDEN_STOREYS: int = 3
const RUGS: PackedStringArray = ["herati", "medallion", "kilim", "gabbeh", "garden"]
## A grand rug's length (along the hall) and the gap between two.
const RUG_LONG: float = 6.0
const RUG_GAP: float = 0.5


func layout(grid: CellGrid, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, "scriptorium"])
	var want: int = rng.randi_range(mini(rows_min, rows_max), maxi(rows_min, rows_max))
	var rows: int = 0
	for n: int in range(want, mini(rows_min, rows_max) - 1, -1):     # shorter if the longer doesn't fit
		if _free(grid, n):
			rows = n
			break
	if rows == 0:
		if not grid.quiet:
			push_warning("ScriptoriumGrammar: no room for the hall")
		return
	var exits: bool = (grid.end_kind if grid.end_kind != "" else "exit") == "exit"
	var doors: Array = []
	if exits:
		var sides: Array = [[Vector3i(-1, 0, 1), CellGrid.Side.W], [Vector3i(1, 0, 1), CellGrid.Side.E]]
		for d: Array in sides.slice(0, side_doors):
			if grid.is_free(CellGrid.neighbour(d[0], d[1])):
				doors.append(d)
	_add_cells(grid, rows)
	_mark_edges(grid, rows, doors)
	_place_shell(grid, rows, _palette(rng))
	_place_rugs(grid, rows, RUGS[rng.randi_range(0, RUGS.size() - 1)])
	grid.meta["doors"] = doors
	grid.meta["rows"] = rows


func _palette(rng: RandomNumberGenerator) -> String:
	var pick: String = OrosiGlass.PALETTES[rng.randi_range(0, OrosiGlass.PALETTES.size() - 1)]
	return palette if palette != "" else pick


func _free(grid: CellGrid, rows: int) -> bool:
	for z: int in rows + GARDEN_ROWS:
		for x: int in range(-1, 2):
			for y: int in (2 if z < rows else GARDEN_STOREYS):
				if not grid.is_free(Vector3i(x, y, z)):
					return false
	return true


func _add_cells(grid: CellGrid, rows: int) -> void:
	for z: int in rows + GARDEN_ROWS:
		for x: int in range(-1, 2):
			var hall: bool = z < rows
			for y: int in (2 if hall else GARDEN_STOREYS):
				var c := Vector3i(x, y, z)
				grid.add_cell(c, "floor" if hall and y == 0 else "air", Vector3i(0, 0, 1), z)
				var cell: Dictionary = grid.cells[c]
				cell["ceiling_slot"] = ""
				cell["gables"] = false
				if hall and y == 0:
					cell["links"] = [Vector3i(x, 1, z)]
					continue
				cell["floor_slot"] = ""
				if not hall and y == 1:
					cell["links"] = [Vector3i(x, 0, z), Vector3i(x, 2, z)]     # the garden behind the glass, floor to roof: one kept space
				cell["blocked"] = true
				cell["no_floor"] = true
				cell["no_map"] = true


func _mark_edges(grid: CellGrid, rows: int, doors: Array) -> void:
	var door_at: Dictionary = {}
	for d: Array in doors:
		door_at[CellGrid.key(d[0], d[1])] = true
	for c: Vector3i in grid.cells:
		for side: int in CellGrid.ALL_SIDES:
			var n: Vector3i = CellGrid.neighbour(c, side)
			var k: String = CellGrid.key(c, side)
			var walked: bool = c.y == 0 and c.z < rows
			if grid.cells.has(n):
				if walked and n.z >= rows:
					grid.set_edge(c, side, CellGrid.Mark.SOLID, false, "none")     # the orosi wall (a shell prop)
				else:
					grid.set_edge(c, side, CellGrid.Mark.OPEN)
			elif not walked:
				grid.set_edge(c, side, CellGrid.Mark.SOLID, false, "none")
			elif side == CellGrid.Side.S:
				_mark_entry_wall(grid, c, side, k)
			elif door_at.has(k):
				grid.set_edge(c, side, CellGrid.Mark.DOOR, false, "none")
				_shell(grid, "door_" + k, "sc:door", CellGrid.edge_transform(c, side))
				grid.props["exit_" + k] = {"slot": "stub:exit", "xf": CellGrid.door_transform(c, side)}
			else:
				grid.set_edge(c, side, CellGrid.Mark.SOLID, false, "none")
				_shell(grid, "wall_" + k, "sc:wall", CellGrid.edge_transform(c, side))


## The entry wall: the doorway in the middle (the host's, or ours if the room is
## the area's first), niche walls either side.
func _mark_entry_wall(grid: CellGrid, c: Vector3i, side: int, k: String) -> void:
	if c.x != 0:
		grid.set_edge(c, side, CellGrid.Mark.SOLID, false, "none")
		_shell(grid, "wall_" + k, "sc:wall", CellGrid.edge_transform(c, side))
	elif grid.root:
		grid.set_edge(c, side, CellGrid.Mark.DOOR, false, "none")
		_shell(grid, "entry", "sc:door", CellGrid.edge_transform(c, side))
		grid.props["exit_" + k] = {"slot": "stub:exit", "xf": CellGrid.door_transform(c, side)}
	else:
		grid.set_edge(c, side, CellGrid.Mark.DOOR, true)


func _shell(grid: CellGrid, key: String, slot: String, xf: Transform3D, meta: Dictionary = {}) -> void:
	grid.props[key] = {"slot": slot, "xf": xf, "shell": true, "meta": meta}


## The timber ceiling bay by bay, and the orosi wall with its garden across the
## far end (its room face on the last row's far edge, the garden behind).
func _place_shell(grid: CellGrid, rows: int, glass: String) -> void:
	for z: int in rows:
		_shell(grid, "ceiling_%d" % z, "sc:ceiling", Transform3D(Basis(), Vector3(-BAY, 0, -z * BAY)))
	_shell(grid, "orosi", "sc:orosi", Transform3D(Basis(), Vector3(-BAY, 0, -rows * BAY)), {"palette": glass})


## Grand rugs down either side of a bare aisle, end to end from the entry to
## a little short of the glass (the patches fall on them).
func _place_rugs(grid: CellGrid, rows: int, design: String) -> void:
	var length: float = rows * BAY - 1.0
	var count: int = maxi(1, floori((length + RUG_GAP) / (RUG_LONG + RUG_GAP)))
	var step: float = length / count
	var quarter := Basis(Vector3.UP, PI * 0.5)
	for i: int in count:
		var z: float = -(0.5 + step * (i + 0.5))
		for s: Array in [["w", -1.0], ["e", 5.0]]:
			grid.props["rug_%s_%d" % [s[0], i]] = {"slot": "rug:" + design, "xf": Transform3D(quarter, Vector3(s[1], 0.0, z))}

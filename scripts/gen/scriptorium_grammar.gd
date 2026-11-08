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
## Desk rows: the first copyist this far in from the entry, the rows this far
## apart, a desk this deep in front of its copyist, and the last row's desk at
## least this far from the glass.
const DESK_FIRST: float = 3.0
const DESK_STEP: float = 3.0
const DESK_DEPTH: float = 0.85
const GLASS_CLEAR: float = 1.1
## The gap after the first row is this much wider: a gangway across the hall
## at the side doors (the second bay), so the way from the aisle to a side door
## is clear (the route audit walks it).
const DOOR_GANGWAY: float = 1.0
## Chance of a copyist at a desk in the near (lamplit) half, and of a
## straggler (one at most) at a desk in the row left half done.
const COPYIST_NEAR: float = 0.8
const COPYIST_LEFT: float = 0.2
## The room whose red the glass keeps clear of (Q3).
const RED_NEIGHBOUR: String = "R03"

## Nobody comes any more (the Forgotten Wing's version; the brief's Q7): no
## copyists, every lamp cold, every desk under dust, the moss dimmer so the
## glass glows faintly.
@export var forgotten: bool = false


func state_options() -> PackedStringArray:
	return ["Tended", "Forgotten", "Tended: copyists at work by the door, copies left half done and then under dust toward the glass. Forgotten: nobody, every lamp cold, every desk under dust, the glass glowing faintly."]


func _abandon() -> void:
	forgotten = true
	ambient_scale = 0.8


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
	_block_desk_bays(grid, rows, doors)
	_place_shell(grid, rows, _palette(rng, grid))
	_place_rugs(grid, rows, RUGS[rng.randi_range(0, RUGS.size() - 1)])
	_place_desks(grid, rows, rng)
	grid.meta["doors"] = doors
	grid.meta["rows"] = rows


## The glass by seed (Q3). Beside the red hall (the Hypostyle Stacks, R03) no
## ruby: the room then picks saffron and green or the full spectrum, so the
## change across the doorway stays clear. Draws from `rng` the same either way,
## so nothing else in the room changes.
func _palette(rng: RandomNumberGenerator, grid: CellGrid) -> String:
	var pick: String = OrosiGlass.PALETTES[rng.randi_range(0, OrosiGlass.PALETTES.size() - 1)]
	if pick.begins_with("ruby") and str(grid.meta.get("host_type", "")) == RED_NEIGHBOUR:
		pick = ["saffron_green", "spectrum"][absi(hash([grid.meta.get("area_seed", 0), grid.meta.get("slot_id", "")])) % 2]
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


## Rows of copy desks on the rugs, two a side, the copyists kneeling behind them
## facing the glass, and on every desk a copy you can read (ScriptoriumCopy).
## Lamps only in the near half (Light in the brief: the glass lights the far
## half and no flame stands beside it): the aisle-side desk of each near row.
## Story (step 4): busy near the door (copyists at most desks, the copies under
## way); the first row past the lamps left half done (a straggler at most, the
## other desks' copies broken off); beyond it, desks under dust. Forgotten:
## every desk under dust, the lamps cold, nobody.
func _place_desks(grid: CellGrid, rows: int, rng: RandomNumberGenerator) -> void:
	var length: float = rows * BAY
	var face := Basis(Vector3.UP, PI)        # the modules face +Z; the copyists face the glass (-Z)
	var r: int = 0
	var z: float = -DESK_FIRST
	var text: int = -1
	var left_row: int = -1                     # the first row past the lamps
	var straggler: bool = false               # at most one copyist still at it there
	while z - DESK_DEPTH > -length + GLASS_CLEAR:
		var near: bool = z > -length * 0.5
		if not near and left_row < 0:
			left_row = r
		var story: String = "busy" if near else ("left" if r == left_row else "dust")
		if forgotten:
			story = "dust"
		# One text a row (never the last row's), the desks beside each other
		# disagreeing in a word.
		var t: int = rng.randi_range(0, ScriptoriumCopy.TEXTS.size() - 2)
		text = t + 1 if text >= 0 and t >= text else t
		var flip: int = rng.randi_range(0, 1)
		var i: int = 0
		for d: Array in [["w0", -1.85, false], ["w1", -0.15, true], ["e0", 4.15, true], ["e1", 5.85, false]]:
			var xf := Transform3D(face, Vector3(d[1], 0.0, z))
			var lamp: bool = near and d[2]
			var state: String = story
			var copyist: bool = false
			if story == "busy":
				copyist = rng.randf() < COPYIST_NEAR
			elif story == "left" and not straggler and rng.randf() < COPYIST_LEFT:
				straggler = true
				copyist = true                 # a straggler still at it
				state = "busy"
			var slot: String = {"busy": "sc:desk", "left": "sc:desk_left", "dust": "sc:desk_dust"}[state]
			if lamp:
				slot = "sc:desk_dust_lamp" if state == "dust" else "sc:desk_lamp"
			var k: String = "%d_%s" % [r, d[0]]
			grid.props["desk_" + k] = {"slot": slot, "xf": xf}
			if copyist:
				grid.props["copyist_" + k] = {"slot": "sc:copyist_read" if rng.randf() < 0.3 else "sc:copyist_write", "xf": xf}
			grid.props["copy_" + k] = {"slot": "sc:copy", "xf": xf, "meta": {
				"text": text, "variant": (i + flip) % 2, "hand": rng.randi_range(0, ScriptoriumCopy.HANDS.size() - 1), "state": state}}
			i += 1
		z -= DESK_STEP + (DOOR_GANGWAY if r == 0 else 0.0)
		r += 1
	grid.props["life"] = {"slot": "sc:life", "xf": Transform3D(), "meta": {"forgotten": forgotten}}


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


## The bays the desk rows stand in (the side columns) aren't walked through:
## walks keep to the aisle (AreaTour goes round blocked cells), and cross the
## gangway into a side door's bay. You can still walk between the desks.
func _block_desk_bays(grid: CellGrid, rows: int, doors: Array) -> void:
	var door_cells: Dictionary = {}
	for d: Array in doors:
		door_cells[d[0]] = true
	for z: int in rows:
		for x: int in [-1, 1]:
			var c := Vector3i(x, 0, z)
			if not door_cells.has(c):
				grid.cells[c]["blocked"] = true

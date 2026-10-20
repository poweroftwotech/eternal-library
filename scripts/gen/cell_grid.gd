class_name CellGrid
extends RefCounted
## A generated room's layout on the 4 m grid (ENVIRONMENT_PLAN.md 5.5.2): which
## cells exist and what every cell edge is. Data only; a RoomGrammar fills it,
## RoomBuilder turns it into kit modules.
##
## Cell (x, storey, z) spans x 4x..4x+4, y 4*storey.., z -4z..-4z-4 in room
## space (the kit's cell convention: a room grows into -Z). Each boundary is
## stored once, keyed by the cell on its +Z or -X side (sides S and W).

const BAY: float = 4.0

## S: the cell's +Z face (z = -4z). N: its -Z face. W: -X face. E: +X face.
enum Side { S, N, W, E }
enum Mark { SOLID, OPENING, DOOR, OPEN }
const MARK_NAMES: PackedStringArray = ["solid", "opening", "door", "open"]
const SIDE_NAMES: PackedStringArray = ["S", "N", "W", "E"]
const ALL_SIDES: Array[int] = [Side.S, Side.N, Side.W, Side.E]
## How far a host module may reach into a cell (wall half-thickness plus a
## shelf-bay back) before the cell counts as taken.
const HOST_MARGIN: float = 0.6
## Cell boxes are tested against host modules up to this height (a storey
## plus the vault).
const CELL_HEIGHT: float = 7.0

## Vector3i -> {kind: String, run: Vector3i (barrel axis), bay: int (cells from the entry)}
var cells: Dictionary = {}
## edge key -> {cell: Vector3i, side: int, mark: int, host: bool}. `cell` and
## `side` are the room cell the edge faces into (its module's interior side).
var edges: Dictionary = {}
## Vector3i -> lamp origin height above the cell's floor.
var lamps: Dictionary = {}
## Room-space boxes the room may not build into (the host's modules).
var blockers: Array[AABB] = []


func add_cell(c: Vector3i, kind: String, run: Vector3i, bay: int) -> void:
	cells[c] = {"kind": kind, "run": run, "bay": bay}


## Marks the edge on `side` of room cell `c`; `host` = a door whose module the
## host room already has (only meaningful with Mark.DOOR).
## `slot` asks RoomBuilder for a more specific ModuleRules slot (e.g.
## edge:solid_corner); it falls back to the mark's own slot if no rule has it.
func set_edge(c: Vector3i, side: int, mark: int, host: bool = false, slot: String = "") -> void:
	edges[key(c, side)] = {"cell": c, "side": side, "mark": mark, "host": host, "slot": slot}


func edge(c: Vector3i, side: int) -> Dictionary:
	return edges.get(key(c, side), {})


## True if cell c may be built: not already a cell, and no host module reaches
## more than HOST_MARGIN into it.
func is_free(c: Vector3i) -> bool:
	if cells.has(c):
		return false
	var box := AABB(Vector3(c.x * BAY + HOST_MARGIN, c.y * BAY, -c.z * BAY - BAY + HOST_MARGIN),
		Vector3(BAY - 2.0 * HOST_MARGIN, CELL_HEIGHT, BAY - 2.0 * HOST_MARGIN))
	for b: AABB in blockers:
		if b.intersects(box):
			return false
	return true


static func neighbour(c: Vector3i, side: int) -> Vector3i:
	match side:
		Side.S:
			return c - Vector3i(0, 0, 1)
		Side.N:
			return c + Vector3i(0, 0, 1)
		Side.W:
			return c - Vector3i(1, 0, 0)
	return c + Vector3i(1, 0, 0)


## Order-free key: the same boundary seen from either cell gives the same key.
static func key(c: Vector3i, side: int) -> String:
	match side:
		Side.N:
			c = neighbour(c, Side.N)
			side = Side.S
		Side.E:
			c = neighbour(c, Side.E)
			side = Side.W
	return "%d_%d_%d_%s" % [c.x, c.y, c.z, SIDE_NAMES[side]]


static func cell_name(c: Vector3i) -> String:
	return "%d_%d_%d" % [c.x, c.y, c.z]


static func cell_centre(c: Vector3i) -> Vector3:
	return Vector3(c.x * BAY + BAY * 0.5, c.y * BAY, -c.z * BAY - BAY * 0.5)


## Where an EDGE module goes so that it closes `side` of cell c with its
## interior (-Z) facing into the cell. Edge modules run along local +X.
static func edge_transform(c: Vector3i, side: int) -> Transform3D:
	var x: float = c.x * BAY
	var y: float = c.y * BAY
	var z: float = -c.z * BAY
	match side:
		Side.S:
			return Transform3D(Basis(), Vector3(x, y, z))
		Side.N:
			return Transform3D(Basis(Vector3.UP, PI), Vector3(x + BAY, y, z - BAY))
		Side.W:
			return Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(x, y, z - BAY))
	return Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(x + BAY, y, z))


## Where a 1 x 1 CELL module goes on cell c, turned so its local -Z (a vault's
## barrel axis) runs along `run`.
static func cell_transform(c: Vector3i, run: Vector3i) -> Transform3D:
	var x: float = c.x * BAY
	var y: float = c.y * BAY
	var z: float = -c.z * BAY
	if run.x != 0:
		return Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(x + BAY, y, z))
	return Transform3D(Basis(), Vector3(x, y, z))


## The two ends of the edge on `side` of cell c, at floor level.
static func edge_ends(c: Vector3i, side: int) -> Array[Vector3]:
	var xf: Transform3D = edge_transform(c, side)
	return [xf.origin, xf.origin + xf.basis.x * BAY]


## Sides at the ends of a cell's barrel (where a vault needs a gable).
static func run_ends(run: Vector3i) -> Array[int]:
	if run.x != 0:
		return [Side.W, Side.E]
	return [Side.S, Side.N]


## Problems with the layout (5.5.8): unmarked sides, open boundaries, cells in
## a host's space, and cells not reachable from the entry door.
func check() -> PackedStringArray:
	var out: PackedStringArray = []
	var entry: Vector3i = Vector3i.MAX
	for c: Vector3i in cells:
		for side: int in ALL_SIDES:
			var e: Dictionary = edge(c, side)
			var n: Vector3i = neighbour(c, side)
			if e.is_empty():
				out.append("cell %s side %s is unmarked" % [c, SIDE_NAMES[side]])
				continue
			var mark: int = e["mark"]
			if not cells.has(n) and mark != Mark.SOLID and mark != Mark.DOOR:
				out.append("cell %s side %s is %s on the room boundary" % [c, SIDE_NAMES[side], MARK_NAMES[mark]])
			if mark == Mark.DOOR and e["host"]:
				entry = c
		var box := AABB(Vector3(c.x * BAY + HOST_MARGIN, c.y * BAY, -c.z * BAY - BAY + HOST_MARGIN),
			Vector3(BAY - 2.0 * HOST_MARGIN, CELL_HEIGHT, BAY - 2.0 * HOST_MARGIN))
		for b: AABB in blockers:
			if b.intersects(box):
				out.append("cell %s overlaps the host room" % c)
				break
	if cells.is_empty():
		out.append("no cells")
		return out
	if entry == Vector3i.MAX:
		entry = cells.keys()[0]
	var seen: Dictionary = {entry: true}
	var todo: Array[Vector3i] = [entry]
	while not todo.is_empty():
		var c: Vector3i = todo.pop_back()
		for side: int in ALL_SIDES:
			var n: Vector3i = neighbour(c, side)
			var e: Dictionary = edge(c, side)
			if cells.has(n) and not seen.has(n) and not e.is_empty() \
					and (e["mark"] == Mark.OPEN or e["mark"] == Mark.OPENING):
				seen[n] = true
				todo.append(n)
	if seen.size() != cells.size():
		out.append("%d of %d cells are not reachable from the entry" % [cells.size() - seen.size(), cells.size()])
	return out


## One line per cell and edge, sorted: equal layouts give equal signatures.
func signature() -> String:
	var lines: PackedStringArray = []
	for c: Vector3i in cells:
		lines.append("c %s %s %s" % [cell_name(c), cells[c]["kind"], cells[c]["run"]])
	for k: String in edges:
		lines.append("e %s %s%s" % [k, MARK_NAMES[edges[k]["mark"]], " host" if edges[k]["host"] else ""])
	for c: Vector3i in lamps:
		lines.append("l %s" % cell_name(c))
	lines.sort()
	return "\n".join(lines)

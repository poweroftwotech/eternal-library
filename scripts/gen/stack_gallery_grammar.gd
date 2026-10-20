@tool
class_name StackGalleryGrammar
extends RoomGrammar
## R02 Stack Gallery (design/room-atlas.html; ENVIRONMENT_PLAN.md 5.5.4): a
## corridor one bay wide, walls of shelf recesses under a barrel vault, lamps
## every few bays. The run walks the grid from the entry door and turns left or
## right; a corner cell takes a groin vault (slot cell:ceiling_cross).
##
## The walk never puts a cell beside one of its own (other than the cells it
## joins) or beside the host, so every wall has the corridor on one side only.

## Total bays on the run, corners included (the seed picks a length in this range).
@export_range(1, 64) var min_bays: int = 6:
	set(value):
		min_bays = value
		emit_changed()
@export_range(1, 64) var max_bays: int = 12:
	set(value):
		max_bays = value
		emit_changed()
## The longest straight stretch (bays between corners, or from the entry):
## the walk turns once it has gone this far. The atlas: "no more than 6
## straight bays without a feature".
@export_range(1, 64) var max_straight_bays: int = 6:
	set(value):
		max_straight_bays = value
		emit_changed()
## No turn until a stretch is at least this long.
@export_range(1, 64) var min_straight_bays: int = 2:
	set(value):
		min_straight_bays = value
		emit_changed()
## Chance to turn at each bay between min_straight_bays and max_straight_bays.
@export_range(0.0, 1.0, 0.01) var turn_chance: float = 0.35:
	set(value):
		turn_chance = value
		emit_changed()
## A lamp hangs on every Nth bay (0 = none).
@export_range(0, 16) var lamp_every_bays: int = 2:
	set(value):
		lamp_every_bays = value
		emit_changed()
## Lamp origin above the floor: lantern_hanging's 1 m chain then meets the
## vault crown (intrados about 6.0 m, barrel and groin alike).
@export var lamp_height: float = 2.0:
	set(value):
		lamp_height = value
		emit_changed()
## Far end: a dead end (wall and gable) or an exit door with a connector for
## a later room.
@export_enum("dead_end", "exit") var end_kind: String = "dead_end":
	set(value):
		end_kind = value
		emit_changed()

## Walks tried before settling for the longest: a walk can box itself in.
const ATTEMPTS: int = 8


func layout(grid: CellGrid, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, "length"])
	var want: int = rng.randi_range(mini(min_bays, max_bays), maxi(min_bays, max_bays))
	var best: Array = []
	for attempt: int in ATTEMPTS:
		var path: Array = walk(grid, want, hash([seed_value, "layout", attempt]))
		if path.size() > best.size():
			best = path
		if best.size() >= want:
			break
	if best.size() < mini(min_bays, max_bays):
		push_warning("StackGalleryGrammar: the run stops after %d bays (min_bays %d): the space is boxed in" % [best.size(), min_bays])
	mark(grid, best)


## One walk from the entry; returns [[cell, dir], ...], where dir is the
## direction the run leaves the cell (into the next cell, or past the end).
func walk(grid: CellGrid, want: int, seed_value: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var taken: Dictionary = {}
	var start := Vector3i.ZERO
	if not grid.is_free(start):
		return []
	var dir := Vector3i(0, 0, 1)
	var path: Array = [[start, dir]]
	taken[start] = true
	var straight: int = 1          # bays in the current stretch
	while path.size() < want:
		var cur: Vector3i = path[-1][0]
		var next: Vector3i = cur + dir
		var may_turn: bool = straight >= min_straight_bays
		var must_turn: bool = straight >= max_straight_bays
		var turn: bool = must_turn or (may_turn and rng.randf() < turn_chance)
		if turn and path.size() + 1 >= want:
			# A corner would be the last bay. A free turn waits; a forced one takes
			# one more bay past the corner if max_bays allows, else the run ends.
			if not must_turn:
				turn = false
			elif want < max_bays:
				want += 1
			else:
				break
		if not turn and not fits(grid, taken, next, cur):
			turn = may_turn         # blocked ahead: turn if the rules allow, else stop
			if not turn or path.size() + 1 >= want:
				break
		if not turn:
			path.append([next, dir])
			taken[next] = true
			straight += 1
			continue
		if not may_turn:
			break                   # must turn before it may (min > max): stop here
		# The next cell becomes the corner; the run leaves it to one side.
		var sides: Array[Vector3i] = [Vector3i(-dir.z, 0, dir.x), Vector3i(dir.z, 0, -dir.x)]
		if rng.randf() < 0.5:
			sides.reverse()
		var turned: bool = false
		for side: Vector3i in sides:
			if fits(grid, taken, next, cur) and fits(grid, taken.merged({next: true}), next + side, next):
				path.append([next, side])
				taken[next] = true
				dir = side
				straight = 0
				turned = true
				break
		if not turned:
			break
	return path


## True if `c` can join the run after `prev`: free of the host, and no cell
## of the run (or the host) beside it except `prev`.
func fits(grid: CellGrid, taken: Dictionary, c: Vector3i, prev: Vector3i) -> bool:
	if taken.has(c) or not grid.is_free(c):
		return false
	for side: int in CellGrid.ALL_SIDES:
		var n: Vector3i = CellGrid.neighbour(c, side)
		if n == prev:
			continue
		if taken.has(n) or not grid.is_free(n):
			return false
	return true


## Cells, edges and lamps for a walked path.
func mark(grid: CellGrid, path: Array) -> void:
	if path.is_empty():
		return
	for i: int in path.size():
		var c: Vector3i = path[i][0]
		var out: Vector3i = path[i][1]
		var into: Vector3i = Vector3i(0, 0, 1) if i == 0 else path[i - 1][1]
		var corner: bool = out != into
		grid.add_cell(c, "corner" if corner else "floor", Vector3i.ZERO if corner else out.abs(), i)
		if lamp_every_bays > 0 and i % lamp_every_bays == lamp_every_bays - 1:
			grid.lamps[c] = lamp_height
	for i: int in path.size():
		var c: Vector3i = path[i][0]
		for side: int in CellGrid.ALL_SIDES:
			var n: Vector3i = CellGrid.neighbour(c, side)
			if i == 0 and side == CellGrid.Side.S:
				grid.set_edge(c, side, CellGrid.Mark.DOOR, true)
			elif (i > 0 and n == path[i - 1][0]) or (i + 1 < path.size() and n == path[i + 1][0]):
				grid.set_edge(c, side, CellGrid.Mark.OPEN)
			elif i + 1 == path.size() and n == c + (path[i][1] as Vector3i) and end_kind == "exit":
				grid.set_edge(c, side, CellGrid.Mark.DOOR)
			else:
				grid.set_edge(c, side, CellGrid.Mark.SOLID, false, inner_corner(path, i, side))


## Lengths of the straight stretches of a marked grid, in walk order (corners
## end a stretch and are not counted).
static func stretches(grid: CellGrid) -> Array[int]:
	var order: Array = grid.cells.keys()
	order.sort_custom(func(a: Vector3i, b: Vector3i) -> bool: return grid.cells[a]["bay"] < grid.cells[b]["bay"])
	var out: Array[int] = []
	var run: int = 0
	for c: Vector3i in order:
		if grid.cells[c]["kind"] == "corner":
			out.append(run)
			run = 0
		else:
			run += 1
	out.append(run)
	return out


## "edge:solid_corner" for the walls of path[i] that meet a turn's inner
## corner (the side the run turns toward, on the bay before a corner and the
## bay after it), else "".
static func inner_corner(path: Array, i: int, side: int) -> String:
	if i + 2 < path.size() and path[i + 1][1] != path[i][1] and side == side_of(path[i + 1][1]):
		return "edge:solid_corner"      # the bay before a corner
	if i >= 2 and path[i - 1][1] != path[i - 2][1] and side == side_of(-(path[i - 2][1] as Vector3i)):
		return "edge:solid_corner"      # the bay after a corner
	return ""


static func side_of(dir: Vector3i) -> int:
	if dir.x > 0:
		return CellGrid.Side.E
	if dir.x < 0:
		return CellGrid.Side.W
	return CellGrid.Side.N if dir.z > 0 else CellGrid.Side.S

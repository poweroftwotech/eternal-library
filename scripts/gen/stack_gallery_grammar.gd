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
##
## Slice 3 features, each rolled on its own key: side passages into one-cell
## alcoves, collapsed bays, lamps on corners with their state by distance from
## the entry, cool fill lights, and an exit door at the far end.

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

@export_group("Features")
## Per bay side: the wall becomes an arch (an `opening` edge) into a one-bay
## dead-end alcove, where the grid has room for one.
@export_range(0.0, 1.0, 0.01) var side_passage_chance: float = 0.11:
	set(value):
		side_passage_chance = value
		emit_changed()
## Chance that an alcove has its own lamp (the atlas mock: 0.6).
@export_range(0.0, 1.0, 0.01) var alcove_lamp_chance: float = 0.6:
	set(value):
		alcove_lamp_chance = value
		emit_changed()
## Per bay: a collapsed bay. Both side walls are shelf recesses pinned to
## "collapsed", with rubble (slot dressing:rubble) along their feet.
@export_range(0.0, 1.0, 0.01) var collapse_chance: float = 0.08:
	set(value):
		collapse_chance = value
		emit_changed()

@export_group("Lamps")
## Every corner gets a lamp too, as well as every lamp_every_bays-th bay.
@export var lamp_on_corners: bool = true:
	set(value):
		lamp_on_corners = value
		emit_changed()
## Chance that a lamp is lit, by bays from the entry (x, 0 to 12 bays; past
## the end the last value holds): the darkness says how far out you are.
## Empty: 0.9 at the entry falling straight to 0.35 at 12 bays.
@export var lamp_lit_by_distance: Curve:
	set(value):
		if lamp_lit_by_distance != null and lamp_lit_by_distance.changed.is_connected(emit_changed):
			lamp_lit_by_distance.changed.disconnect(emit_changed)
		lamp_lit_by_distance = value
		if lamp_lit_by_distance != null:
			lamp_lit_by_distance.changed.connect(emit_changed)
		emit_changed()
## Of the lamps that are not lit, the share still guttering (failing, a
## flicker) rather than dark.
@export_range(0.0, 1.0, 0.01) var lamp_failing_share: float = 0.3:
	set(value):
		lamp_failing_share = value
		emit_changed()

@export_group("Cool fills")
## A cool, shadowless fill light on every Nth bay (0 = none): the atlas's
## teal archive light, which is all that is left where the lamps are dark.
@export_range(0, 16) var fill_every_bays: int = 3:
	set(value):
		fill_every_bays = value
		emit_changed()
@export var fill_colour: Color = Color(0.36, 0.62, 0.64):
	set(value):
		fill_colour = value
		emit_changed()
@export_range(0.0, 8.0, 0.01) var fill_energy: float = 0.6:
	set(value):
		fill_energy = value
		emit_changed()
@export_range(0.5, 30.0, 0.1) var fill_range: float = 7.0:
	set(value):
		fill_range = value
		emit_changed()
## Fill height above the floor (the vault crown is at about 6.0 m).
@export var fill_height: float = 4.6:
	set(value):
		fill_height = value
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
	if best.size() < mini(min_bays, max_bays) and not grid.quiet:
		push_warning("StackGalleryGrammar: the run stops after %d bays (min_bays %d): the space is boxed in" % [best.size(), min_bays])
	mark(grid, best, seed_value)


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


## Cells, edges, features and lamps for a walked path. Every feature roll is
## keyed by what it decides (seed, feature, cell, side), so changing one knob
## leaves the other features where they were.
func mark(grid: CellGrid, path: Array, seed_value: int) -> void:
	if path.is_empty():
		return
	var taken: Dictionary = {}
	for i: int in path.size():
		var c: Vector3i = path[i][0]
		var out: Vector3i = path[i][1]
		var into: Vector3i = Vector3i(0, 0, 1) if i == 0 else path[i - 1][1]
		var corner: bool = out != into
		grid.add_cell(c, "corner" if corner else "floor", Vector3i.ZERO if corner else out.abs(), i)
		taken[c] = true
	var exit_side: int = exit_side_for(grid, path, taken)
	if exit_side >= 0:
		taken[CellGrid.neighbour(path[-1][0], exit_side)] = true    # kept free for the next room
	for i: int in path.size():
		var c: Vector3i = path[i][0]
		for side: int in CellGrid.ALL_SIDES:
			var n: Vector3i = CellGrid.neighbour(c, side)
			if i == 0 and side == CellGrid.Side.S:
				grid.set_edge(c, side, CellGrid.Mark.DOOR, true)
			elif (i > 0 and n == path[i - 1][0]) or (i + 1 < path.size() and n == path[i + 1][0]):
				grid.set_edge(c, side, CellGrid.Mark.OPEN)
			elif i + 1 == path.size() and side == exit_side:
				grid.set_edge(c, side, CellGrid.Mark.DOOR)
			else:
				grid.set_edge(c, side, CellGrid.Mark.SOLID, false, inner_corner(path, i, side))
	if exit_side >= 0:
		# Until a room joins here (phase 4), the exit shows a lit room beyond and
		# blocks the way (slot stub:exit, in the door connector's frame).
		grid.props["exit_" + CellGrid.key(path[-1][0], exit_side)] = {"slot": "stub:exit",
			"xf": CellGrid.door_transform(path[-1][0], exit_side)}
	for i: int in range(1, path.size()):
		add_alcoves(grid, path[i][0], taken, seed_value)
	for i: int in range(1, path.size()):
		maybe_collapse(grid, path[i][0], seed_value)
	place_lamps(grid, seed_value)
	place_fills(grid)


## The side of the last bay that becomes the exit door: straight on if a room
## could be built there, else either side; -1 for a dead end.
func exit_side_for(grid: CellGrid, path: Array, taken: Dictionary) -> int:
	if (grid.end_kind if grid.end_kind != "" else end_kind) != "exit":
		return -1
	var last: Vector3i = path[-1][0]
	var dir: Vector3i = path[-1][1]
	for d: Vector3i in [dir, Vector3i(-dir.z, 0, dir.x), Vector3i(dir.z, 0, -dir.x)]:
		if fits(grid, taken, last + d, last):
			return side_of(d)
	if not grid.quiet:
		push_warning("StackGalleryGrammar: no room for an exit beyond bay %d; the run ends in a dead end" % (path.size() - 1))
	return -1


## The two walls of a straight bay (across its barrel), or none for a corner.
static func side_walls(grid: CellGrid, c: Vector3i) -> Array[int]:
	var run: Vector3i = grid.cells[c]["run"]
	var out: Array[int] = []
	if run.x != 0:
		out.assign([CellGrid.Side.S, CellGrid.Side.N])
	elif run.z != 0:
		out.assign([CellGrid.Side.W, CellGrid.Side.E])
	return out


## Side passages: a plain solid side wall of a straight bay may open (an arch,
## edge mark `opening`) into a one-cell alcove, if nothing else of the room is
## beside that cell. The alcove's barrel runs out from the bay, so its vault
## ends (and takes a gable) at the arch and at its back wall. Its two side
## walls meet the corridor's wall line, so they ask for edge:solid_corner.
func add_alcoves(grid: CellGrid, c: Vector3i, taken: Dictionary, seed_value: int) -> void:
	if grid.cells[c]["kind"] != "floor":
		return
	for side: int in side_walls(grid, c):
		var e: Dictionary = grid.edge(c, side)
		if e["mark"] != CellGrid.Mark.SOLID or e["slot"] != "":
			continue
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([seed_value, "passage", CellGrid.cell_name(c), side])
		if rng.randf() >= side_passage_chance:
			continue
		var a: Vector3i = CellGrid.neighbour(c, side)
		if not fits(grid, taken, a, c):
			continue
		var out: Vector3i = a - c
		taken[a] = true
		grid.add_cell(a, "alcove", out.abs(), grid.cells[c]["bay"])
		grid.set_edge(c, side, CellGrid.Mark.OPENING)
		for s: int in CellGrid.ALL_SIDES:
			var n: Vector3i = CellGrid.neighbour(a, s)
			if n == c:
				continue
			grid.set_edge(a, s, CellGrid.Mark.SOLID, false, "" if n == a + out else "edge:solid_corner")
		if rng.randf() < alcove_lamp_chance:
			grid.lamps[a] = lamp_height


## A collapsed bay: a straight bay whose two side walls are both plain solid
## walls (no alcove, door or inner corner). They ask for edge:recess (a shelf
## recess, never a blank wall) and pin it to "collapsed"; a rubble strip lies
## along each one (dressing:rubble, placed on the wall line like the wall).
func maybe_collapse(grid: CellGrid, c: Vector3i, seed_value: int) -> void:
	if grid.cells[c]["kind"] != "floor":
		return
	var walls: Array[int] = side_walls(grid, c)
	for side: int in walls:
		var e: Dictionary = grid.edge(c, side)
		if e["mark"] != CellGrid.Mark.SOLID or e["slot"] != "":
			return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, "collapse", CellGrid.cell_name(c)])
	if rng.randf() >= collapse_chance:
		return
	grid.cells[c]["kind"] = "collapsed"
	for side: int in walls:
		var k: String = CellGrid.key(c, side)
		grid.edges[k]["slot"] = "edge:recess"
		grid.pins["edge_" + k] = "collapsed"
		grid.props["rubble_" + k] = {"slot": "dressing:rubble", "xf": CellGrid.edge_transform(c, side)}


## Lamps on every lamp_every_bays-th bay of the run and on every corner
## (alcove lamps come with the alcove), then each one's state by its distance
## from the entry (lamp_lit_by_distance), pinned through grid.pins so the
## grammar never reaches inside the lamp's socket.
func place_lamps(grid: CellGrid, seed_value: int) -> void:
	for c: Vector3i in grid.run_order():
		var i: int = grid.cells[c]["bay"]
		var every: bool = lamp_every_bays > 0 and i % lamp_every_bays == lamp_every_bays - 1
		if every or (lamp_on_corners and grid.cells[c]["kind"] == "corner"):
			grid.lamps[c] = lamp_height
	for c: Vector3i in grid.lamps:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([seed_value, "lamp_lit", CellGrid.cell_name(c)])
		var state: String = "lit"
		if rng.randf() >= lit_chance(grid.cells[c]["bay"]):
			state = "failing" if rng.randf() < lamp_failing_share else "dark"
		grid.pins["lamp_" + CellGrid.cell_name(c)] = state


## lamp_lit_by_distance at `bay` bays from the entry.
func lit_chance(bay: int) -> float:
	if lamp_lit_by_distance == null:
		return lerpf(0.9, 0.35, clampf(bay / 12.0, 0.0, 1.0))
	var x: float = clampf(float(bay), lamp_lit_by_distance.min_domain, lamp_lit_by_distance.max_domain)
	return clampf(lamp_lit_by_distance.sample(x), 0.0, 1.0)


## A cool fill on every fill_every_bays-th bay of the run.
func place_fills(grid: CellGrid) -> void:
	if fill_every_bays <= 0:
		return
	for c: Vector3i in grid.run_order():
		var i: int = grid.cells[c]["bay"]
		if i % fill_every_bays == fill_every_bays - 1:
			grid.fills["fill_" + CellGrid.cell_name(c)] = {"at": CellGrid.cell_centre(c) + Vector3(0, fill_height, 0),
				"colour": fill_colour, "energy": fill_energy, "range": fill_range}


## Lengths of the straight stretches of a marked grid, in walk order (corners
## end a stretch and are not counted; alcoves are off the run).
static func stretches(grid: CellGrid) -> Array[int]:
	var order: Array[Vector3i] = grid.run_order()
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

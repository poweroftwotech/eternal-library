@tool
class_name RoomGrammar
extends Resource
## Layout rules for one generated room type (ENVIRONMENT_PLAN.md 5.5.4); one
## subclass per type, one .tres per variant in gen/grammars/. A grammar only
## marks a CellGrid; RoomBuilder picks the modules from `rules`.

## Room styles: select ModuleRules rules (and later, socket conditions).
@export var styles: PackedStringArray = ["brick"]:
	set(value):
		styles = value
		emit_changed()
@export var rules: ModuleRules:
	set(value):
		if rules != null and rules.changed.is_connected(emit_changed):
			rules.changed.disconnect(emit_changed)
		rules = value
		if rules != null:
			rules.changed.connect(emit_changed)
		emit_changed()


## Fill `grid` (cells, edges, lamps). The entry door is the S side of cell
## (0, 0, 0), joined to the host. Every random choice comes from seed_value.
func layout(_grid: CellGrid, _seed_value: int) -> void:
	push_error("RoomGrammar.layout() is overridden by each room type")


@export_group("Floor wear")
## Walked lanes polished into the floor (ENVIRONMENT_PLAN.md 5.5.10):
## GeneratedRoom gives them to a FloorWear.
@export var wear_lanes_enabled: bool = true:
	set(value):
		wear_lanes_enabled = value
		emit_changed()
## Lane weight at the entry and at wear_far_bays cells out (beyond, it holds):
## busy by the host room, faint far out.
@export_range(0.0, 1.0, 0.01) var wear_entry_weight: float = 1.0:
	set(value):
		wear_entry_weight = value
		emit_changed()
@export_range(0.0, 1.0, 0.01) var wear_far_weight: float = 0.45:
	set(value):
		wear_far_weight = value
		emit_changed()
@export_range(1, 64) var wear_far_bays: int = 12:
	set(value):
		wear_far_bays = value
		emit_changed()
## Share of the lane weight on spurs off the main lane (into alcoves) and on
## the browse marks where a lane stops.
@export_range(0.0, 1.0, 0.01) var wear_spur_weight: float = 0.6:
	set(value):
		wear_spur_weight = value
		emit_changed()
## How far a lane strays sideways in a cell, metres (seeded per cell).
@export_range(0.0, 1.0, 0.01) var wear_wander: float = 0.3:
	set(value):
		wear_wander = value
		emit_changed()
## A turn is cut across: the lane passes this far before and after the
## corner cell's centre, metres.
@export_range(0.0, 1.9, 0.01) var wear_corner_cut: float = 0.8:
	set(value):
		wear_corner_cut = value
		emit_changed()
## A lane into a dead end stops this far short of its far wall, metres.
@export_range(0.0, 1.9, 0.01) var wear_stop: float = 1.0:
	set(value):
		wear_stop = value
		emit_changed()
## Full-wear half width of a lane, metres (FloorWear.half_width).
@export_range(0.05, 1.0, 0.01) var wear_half_width: float = 0.32:
	set(value):
		wear_half_width = value
		emit_changed()

## How far lanes reach past a door, so they meet the next room's.
const WEAR_PAST_DOOR: float = 0.4
## Half the length of a browse mark across a lane's stop.
const WEAR_BROWSE: float = 0.7


## Fills grid.wear with walked lanes ({points: room x/z, weight}) for any
## marked grid. The cells form a tree from the host door through open and
## opening edges. The main lane runs from just outside the entry door to an
## own door (and just past it), else to the deepest cell; spurs run into the
## other branches (alcoves). A lane into a dead end stops short of its far
## wall with a browse mark across it. Weights fall off with tree depth, and
## every stray is seeded per cell.
func wear_lanes(grid: CellGrid, seed_value: int) -> void:
	grid.wear.clear()
	if not wear_lanes_enabled or grid.cells.is_empty():
		return
	var entry_side: int = -1
	var start: Vector3i
	var exits: Array = []          # [[cell, side], ...] in key order
	var keys: Array = grid.edges.keys()
	keys.sort()
	for k: String in keys:
		var e: Dictionary = grid.edges[k]
		if e["mark"] != CellGrid.Mark.DOOR:
			continue
		if e["host"]:
			start = e["cell"]
			entry_side = e["side"]
		else:
			exits.append([e["cell"], e["side"]])
	if entry_side < 0:
		return
	# The tree, breadth first from the entry cell (sides in a fixed order).
	var parent: Dictionary = {start: start}
	var depth: Dictionary = {start: 0}
	var children: Dictionary = {start: 0}
	var order: Array[Vector3i] = [start]
	var head: int = 0
	while head < order.size():
		var c: Vector3i = order[head]
		head += 1
		for side: int in CellGrid.ALL_SIDES:
			var n: Vector3i = CellGrid.neighbour(c, side)
			var e: Dictionary = grid.edge(c, side)
			if grid.cells.has(n) and not parent.has(n) and not e.is_empty() \
					and (e["mark"] == CellGrid.Mark.OPEN or e["mark"] == CellGrid.Mark.OPENING):
				parent[n] = c
				depth[n] = depth[c] + 1
				children[n] = 0
				children[c] += 1
				order.append(n)
	# The main lane's far end: the first own door, else the deepest cell.
	var target: Vector3i = start
	var exit_side: int = -1
	for x: Array in exits:
		if parent.has(x[0]):
			target = x[0]
			exit_side = x[1]
			break
	if exit_side < 0:
		for c: Vector3i in order:
			if depth[c] > depth[target]:
				target = c
	var chain: Array[Vector3i] = [target]
	while chain[0] != start:
		chain.push_front(parent[chain[0]])
	var lane_point: Dictionary = {}    # cell -> where its lane passes (spurs start there)
	var door: Transform3D = CellGrid.door_transform(start, entry_side)
	var into: Vector2 = _xz(door.basis.z)            # connectors point -Z out of the room
	var pts: Array = [[_xz(door.origin - door.basis.z * WEAR_PAST_DOOR), traffic(0)]]
	for i: int in chain.size():
		var c: Vector3i = chain[i]
		var w: float = traffic(depth[c])
		var centre: Vector2 = _xz(CellGrid.cell_centre(c))
		lane_point[c] = centre
		if i + 1 == chain.size() and exit_side < 0:
			_stop(grid, pts, c, into, w, seed_value)
			break
		var out: Vector2 = _dir(c, chain[i + 1]) if i + 1 < chain.size() \
			else _xz(-CellGrid.door_transform(c, exit_side).basis.z)
		if not out.is_equal_approx(into):
			pts.append([centre - into * wear_corner_cut, w])     # cut across the turn
			pts.append([centre + out * wear_corner_cut, w])
		else:
			lane_point[c] = centre + _wander(c, into, seed_value)
			pts.append([lane_point[c], w])
		into = out
	if exit_side >= 0:
		door = CellGrid.door_transform(target, exit_side)
		pts.append([_xz(door.origin - door.basis.z * WEAR_PAST_DOOR), traffic(depth[target])])
	_add_lane(grid, pts)
	# Spurs: each tree edge off the main lane, from the parent's lane point
	# through the shared edge into the child.
	for c: Vector3i in order:
		if lane_point.has(c):
			continue
		var p: Vector3i = parent[c]
		var dir: Vector2 = _dir(p, c)
		var w: float = traffic(depth[c]) * wear_spur_weight
		var mid: Vector2 = (_xz(CellGrid.cell_centre(p)) + _xz(CellGrid.cell_centre(c))) * 0.5
		var spur: Array = [[lane_point[p], w], [mid, w]]
		lane_point[c] = _xz(CellGrid.cell_centre(c)) + _wander(c, dir, seed_value)
		if children[c] == 0:
			_stop(grid, spur, c, dir, w, seed_value)
		else:
			spur.append([lane_point[c], w])
		_add_lane(grid, spur)


## A lane's weight `bays` cells out from the entry.
func traffic(bays: int) -> float:
	return lerpf(wear_entry_weight, wear_far_weight, clampf(float(bays) / wear_far_bays, 0.0, 1.0))


## Ends a lane heading `dir` into dead-end cell c: it stops wear_stop short of
## the far wall, with a browse mark across it.
func _stop(grid: CellGrid, pts: Array, c: Vector3i, dir: Vector2, w: float, seed_value: int) -> void:
	var stop: Vector2 = _xz(CellGrid.cell_centre(c)) + dir * (CellGrid.BAY * 0.5 - wear_stop) + _wander(c, dir, seed_value) * 0.5
	pts.append([stop, w])
	var across := Vector2(-dir.y, dir.x) * WEAR_BROWSE
	grid.wear.append({"points": PackedVector2Array([stop - across, stop + across]), "weight": w * wear_spur_weight})


## One path per segment, so the weight can change along the lane.
static func _add_lane(grid: CellGrid, pts: Array) -> void:
	for i: int in pts.size() - 1:
		grid.wear.append({"points": PackedVector2Array([pts[i][0], pts[i + 1][0]]),
			"weight": (float(pts[i][1]) + float(pts[i + 1][1])) * 0.5})


## Sideways stray of a lane crossing cell c along `dir`, seeded per cell.
func _wander(c: Vector3i, dir: Vector2, seed_value: int) -> Vector2:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, "wear", CellGrid.cell_name(c)])
	return Vector2(-dir.y, dir.x) * rng.randf_range(-wear_wander, wear_wander)


## Room x/z direction from cell a to its neighbour b.
static func _dir(a: Vector3i, b: Vector3i) -> Vector2:
	return Vector2(b.x - a.x, -(b.z - a.z))


static func _xz(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)

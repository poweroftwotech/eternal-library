@tool
class_name RingGrammar
extends RoomGrammar
## R09 Light-Well Stair (design/room-atlas.html; phase-5-design.md 5.6.6), rev 2
## after your review: a cone, wide at the floor and narrow at the oculus, its
## stair cut into the wall (concept: previews/p5_cone_idea/v5). The stair climbs
## a storey every three-quarters of a turn, so each floor's doorway faces
## another side (W, N, E, S, ...); a ledge with a parapet and columns runs along
## its open edge, and niches between the columns hold a cone_niche socket
## (books, a tile panel, a sealed door; plain brick on the upper floors). A
## pool lies under the oculus.
##
## Off the grid: the cone's pieces are FREE modules placed by angle (grid props,
## tools/kit_add_r03.py's cone set: one per storey, a cap, a base). The grid only
## reserves the square of cells round the cone on every storey (planning,
## overlap, doors): its sides build nothing ("none"), and its doors are ordinary
## door modules at the square's edge, reached from the stair by a passage. The
## grid keeps the layout in `meta` for the tests and the tours (route()).

## Floor radius 10 m (3-4 levels) or 12 m (3-5), picked by the seed.
@export var radii: PackedInt32Array = [10, 12]:
	set(value):
		radii = value
		emit_changed()
## Levels (storeys) from the bottom to the top (Q9; the cone's size caps it).
@export_range(2, 8) var levels_min: int = 3:
	set(value):
		levels_min = value
		emit_changed()
@export_range(2, 8) var levels_max: int = 5:
	set(value):
		levels_max = value
		emit_changed()
## Chance a level between the bottom and the top has a doorway out; the top
## always has one. At most max_exits.
@export_range(0.0, 1.0, 0.01) var exit_chance: float = 0.5:
	set(value):
		exit_chance = value
		emit_changed()
@export_range(1, 6) var max_exits: int = 3:
	set(value):
		max_exits = value
		emit_changed()
## Storeys from the bottom whose niches roll the cone_niche socket (books, a
## tile panel, a sealed door); the niches above are plain brick.
@export_range(0, 8) var shelf_levels: int = 2:
	set(value):
		shelf_levels = value
		emit_changed()
## A lantern over every Nth bay of the stair (0 = none), and one over each
## doorway's landing; on the shelf_levels storeys (the reading floors, under
## the wall's overhang) every shelf_lamp_every_bays-th bay.
@export_range(0, 12) var lamp_every_bays: int = 3:
	set(value):
		lamp_every_bays = value
		emit_changed()
@export_range(0, 12) var shelf_lamp_every_bays: int = 2:
	set(value):
		shelf_lamp_every_bays = value
		emit_changed()

const STOREY: float = 4.0
## The Blender twin's constants (tools/kit_add_r03.py, CONE_*).
const LEAN: float = 0.375
const WALL: float = 3.6
const DEPTH: float = 1.0
const HEAD: float = 2.6
const RISERS: int = 20
const BAY: float = 4.8
const TURN: float = 1.5 * PI
## Levels each floor radius allows (the top storey's wall at least 5.5 m out).
const MOST_LEVELS: Dictionary = {10: 4, 12: 5}
## Where a walk keeps to on the stair, out from the wall's face at the tread
## (the columns' inner face is 0.25 inside it, the cut's back 1.0 out).
const WALK: float = 0.4
## The side a storey's doorway faces, as a share of a turn (S toward the entry).
const SIDE_TURN: Dictionary = {CellGrid.Side.S: 0.0, CellGrid.Side.E: 0.25, CellGrid.Side.N: 0.5, CellGrid.Side.W: 0.75}


## Half the square (cells) round a cone of floor radius r0: its outer face and
## a margin inside the square's edge.
static func half_cells(r0: int) -> int:
	return int(ceil((r0 + WALL + 0.4 - CellGrid.BAY * 0.5) / CellGrid.BAY))


static func cells_across(r0: int) -> int:
	return 2 * half_cells(r0) + 1


## The side storey y's doorway faces: the stair reaches it 0.75 y turns round.
static func side_of(y: int) -> int:
	var turn: float = fposmod(0.75 * y, 1.0)
	for side: int in SIDE_TURN:
		if absf(SIDE_TURN[side] - turn) < 0.01:
			return side
	return CellGrid.Side.S


## The wall's inner face at height z over a storey whose face is r at 0.
static func face(r: float, z: float) -> float:
	return r - LEAN * z


static func half_landing(r: float) -> float:
	return 1.8 / maxf(r + 0.5, 2.0)


## [start, end] angles of the climb from a storey with radius r.
static func climb(r: float) -> Vector2:
	return Vector2(half_landing(r), TURN - half_landing(r - 1.5))


static func risers(r: float) -> PackedFloat32Array:
	var c: Vector2 = climb(r)
	var out: PackedFloat32Array = []
	for i: int in RISERS:
		out.append(c.x + (i + 0.5) * (c.y - c.x) / RISERS)
	return out


static func bays(r: float) -> int:
	var c: Vector2 = climb(r)
	return maxi(3, roundi((c.y - c.x) * (r + 0.3) / BAY))


## The tread's height at angle t within a storey of radius r (0 on its landing).
static func tread(r: float, t: float) -> float:
	var n: int = 0
	for a: float in risers(r):
		if a <= t:
			n += 1
	return 0.2 * n


## The middle of the step that angle t is on.
static func step_middle(r: float, t: float) -> float:
	var c: Vector2 = climb(r)
	var edges: PackedFloat32Array = [c.x]
	edges.append_array(risers(r))
	edges.append(c.y)
	for k: int in edges.size() - 1:
		if edges[k] <= t and t <= edges[k + 1]:
			return (edges[k] + edges[k + 1]) * 0.5
	return t


func layout(grid: CellGrid, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, "ring_size"])
	var sizes: Array = Array(radii) if not radii.is_empty() else [10]
	var r0: int = sizes[rng.randi_range(0, sizes.size() - 1)]
	var want: int = rng.randi_range(mini(levels_min, levels_max), maxi(levels_min, levels_max))
	var levels: int = 0
	for r: int in [r0, 10]:
		levels = _fit(grid, r, mini(want, int(MOST_LEVELS.get(r, 4))))
		if levels > 0:
			r0 = r
			break
	if levels == 0:
		if not grid.quiet:
			push_warning("RingGrammar: no room for a light-well")
		return
	var across: int = cells_across(r0)
	var h: int = across / 2
	var centre := Vector3(CellGrid.BAY * 0.5, 0.0, -(h * CellGrid.BAY + CellGrid.BAY * 0.5))
	# The cells: the square on every storey; the centre column links the storeys.
	for y: int in levels:
		for z: int in across:
			for x: int in range(-h, h + 1):
				var c := Vector3i(x, y, z)
				grid.add_cell(c, "floor", Vector3i(0, 0, 1), absi(x) + z + y)
				var cell: Dictionary = grid.cells[c]
				cell["floor_slot"] = ""
				cell["ceiling_slot"] = ""
				cell["gables"] = false
				cell["no_floor"] = true
		if y + 1 < levels:
			grid.cells[Vector3i(0, y, h)]["links"] = [Vector3i(0, y + 1, h)]
	for c: Vector3i in grid.cells:
		for side: int in CellGrid.ALL_SIDES:
			if grid.cells.has(CellGrid.neighbour(c, side)):
				grid.set_edge(c, side, CellGrid.Mark.OPEN)
			else:
				grid.set_edge(c, side, CellGrid.Mark.SOLID, false, "none")
	# Doors: the entry, then exits (the top level first), each on the side its
	# storey's landing faces.
	var doors: Array = [[0, CellGrid.Side.S]]
	grid.set_edge(Vector3i.ZERO, CellGrid.Side.S, CellGrid.Mark.DOOR, not grid.root)
	# Always a way on from the top, even when the area asks for a dead end (a
	# shaft that leads nowhere is pointless).
	var tries: Array = [levels - 1]
	for y: int in range(levels - 2, 0, -1):
		tries.append(y)
	for y: int in tries:
		if doors.size() > max_exits:
			break
		var roll := RandomNumberGenerator.new()
		roll.seed = hash([seed_value, "ring_exit", y])
		if y != levels - 1 and roll.randf() >= exit_chance:
			continue
		var side: int = side_of(y)
		var dc: Vector3i = door_cell(side, y, h, across)
		if not grid.is_free(CellGrid.neighbour(dc, side)):
			continue
		doors.append([y, side])
		grid.set_edge(dc, side, CellGrid.Mark.DOOR)
		var k: String = CellGrid.key(dc, side)
		grid.props["exit_" + k] = {"slot": "stub:exit", "xf": CellGrid.door_transform(dc, side)}
		grid.pins["edge_" + k] = "nothing"     # no ivy over the arch: the passage walls are right behind it
	var door_levels: Dictionary = {}
	for d: Array in doors:
		door_levels[int(d[0])] = true
	# The pieces.
	var r10: int = r0 * 10
	_piece(grid, "base", "cone:base%d" % r10, Transform3D(Basis(), centre))
	for j: int in levels - 1:
		var r: float = r0 - 1.5 * j
		var kind: String = "exit" if j == 0 or door_levels.has(j) else "closed"
		_piece(grid, "c_%d" % j, "cone:c%d_%s" % [roundi(r * 10), kind], _at(centre, j, 0.0, 0.0, 0.0))
		if j >= shelf_levels:
			grid.pins["prop_cone_c_%d" % j] = "plain"
		if lamp_every_bays > 0:
			var c: Vector2 = climb(r)
			var nb: int = bays(r)
			var every: int = shelf_lamp_every_bays if j < shelf_levels and shelf_lamp_every_bays > 0 else lamp_every_bays
			for b: int in nb:
				if b % every != every / 2:
					continue
				var t: float = step_middle(r, c.x + (c.y - c.x) * (b + 0.5) / nb)
				var z: float = tread(r, t)
				_piece(grid, "l_%d_%d" % [j, b], "cone:lantern", _at(centre, j, t, face(r, z) + WALK + 0.1, z))
	_piece(grid, "cap", "cone:cap%d_%d" % [r10, levels], _at(centre, levels - 1, 0.0, 0.0, 0.0))
	for y: int in door_levels:
		var r: float = r0 - 1.5 * y
		if lamp_every_bays > 0:
			_piece(grid, "l_%d_door" % y, "cone:lantern", _at(centre, y, 0.0, face(r, 0.0) + WALK + 0.1, 0.0))
	# Passages from each doorway out to the square's edge, 2 m pieces from the
	# edge in, then 0.5 m ones (cone:passage_2m, cone:passage_05m).
	for d: Array in doors:
		var y: int = d[0]
		var t: float = TAU * SIDE_TURN[d[1]]
		var from: float = face(r0 - 1.5 * y, 0.0) + WALL - 1.4
		var at: float = h * CellGrid.BAY + CellGrid.BAY * 0.5 - 0.3
		var i: int = 0
		while at - 2.0 >= from - 0.5:
			at -= 2.0
			_piece(grid, "p_%d_%d" % [y, i], "cone:passage_2m", _radial(centre, y, t, at))
			i += 1
		while at > from - 0.5:
			at -= 0.5
			_piece(grid, "p_%d_%d" % [y, i], "cone:passage_05m", _radial(centre, y, t, at))
			i += 1
	grid.meta = {"ring": true, "cone": true, "radius": r0, "levels": levels, "centre": centre, "across": across, "doors": doors}
	grid.wear.clear()


func _piece(grid: CellGrid, key: String, slot: String, xf: Transform3D) -> void:
	grid.props["cone_" + key] = {"slot": slot, "xf": xf, "shell": true}


## A piece on storey j, turned with the storey (0.75 j turns) and then by t,
## at radius rad and height z over the storey's floor.
static func _at(centre: Vector3, j: int, t: float, rad: float, z: float) -> Transform3D:
	var a: float = TURN * j + t
	return Transform3D(Basis(Vector3.UP, a), centre + Vector3(sin(a) * rad, j * STOREY + z, cos(a) * rad))


static func _radial(centre: Vector3, y: int, t: float, rad: float) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, t), centre + Vector3(sin(t) * rad, y * STOREY, cos(t) * rad))


## Levels that fit (from `want` down to levels_min) with the top storey's
## doorway free (each storey's faces one side), or 0.
func _fit(grid: CellGrid, r0: int, want: int) -> int:
	var across: int = cells_across(r0)
	var h: int = across / 2
	for levels: int in range(want, mini(levels_min, levels_max) - 1, -1):
		var top: int = side_of(levels - 1)
		var ok: bool = grid.is_free(CellGrid.neighbour(door_cell(top, levels - 1, h, across), top))
		for y: int in levels:
			for z: int in across:
				for x: int in range(-h, h + 1):
					if not grid.is_free(Vector3i(x, y, z)):
						ok = false
		if ok:
			return levels
	return 0


## The cell whose `side` is a door on level y (the middle of that side of the square).
static func door_cell(side: int, y: int, h: int, across: int) -> Vector3i:
	match side:
		CellGrid.Side.S:
			return Vector3i(0, y, 0)
		CellGrid.Side.N:
			return Vector3i(0, y, across - 1)
		CellGrid.Side.W:
			return Vector3i(-h, y, h)
	return Vector3i(h, y, h)


## Room-space walking points from door `a` to door `b` ([level, side] of
## meta.doors; b = [] for the top landing): in along a's passage to its
## landing, up (or down) the stair a point on every step, and out along b's
## passage.
static func route(meta: Dictionary, a: Array, b: Array) -> Array[Vector3]:
	var levels: int = meta["levels"]
	var level_b: int = b[0] if not b.is_empty() else levels - 1
	if level_b < int(a[0]):
		var back: Array[Vector3] = route(meta, b, a)
		back.reverse()
		return back
	var out: Array[Vector3] = []
	var centre: Vector3 = meta["centre"]
	var r0: float = float(meta["radius"])
	var edge: float = int(meta["across"]) / 2 * CellGrid.BAY + CellGrid.BAY * 0.5
	var level_a: int = a[0]
	out.append(_point(centre, level_a, TAU * SIDE_TURN[a[1]] - TURN * level_a, edge - 1.0, 0.0))
	out.append(_point(centre, level_a, 0.0, face(r0 - 1.5 * level_a, 0.0) + WALK, 0.0))
	for j: int in range(level_a, level_b):
		var r: float = r0 - 1.5 * j
		var c: Vector2 = climb(r)
		var edges: PackedFloat32Array = [c.x]
		edges.append_array(risers(r))
		edges.append(c.y)
		for k: int in edges.size() - 1:
			var t: float = (edges[k] + edges[k + 1]) * 0.5
			var z: float = tread(r, t)
			out.append(_point(centre, j, t, face(r, z) + WALK, z))
		out.append(_point(centre, j + 1, 0.0, face(r - 1.5, 0.0) + WALK, 0.0))
	if not b.is_empty():
		out.append(_point(centre, level_b, TAU * SIDE_TURN[b[1]] - TURN * level_b, edge - 1.0, 0.0))
	return out


## Storey j's point at angle t (from its landing), radius rad, height z over its floor.
static func _point(centre: Vector3, j: int, t: float, rad: float, z: float) -> Vector3:
	var a: float = TURN * j + t
	return centre + Vector3(sin(a) * rad, j * STOREY + z, cos(a) * rad)


func wear_lanes(_grid: CellGrid, _seed_value: int) -> void:
	pass

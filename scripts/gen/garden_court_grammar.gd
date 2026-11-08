@tool
class_name GardenCourtGrammar
extends RoomGrammar
## R07 Garden Court (design/room-atlas.html; docs/environment/phase-13-approval.md):
## a chahar bagh under a broad shaft of daylight. A court of 5 x 5 bays ringed
## by a talar (your walk, after Chehel Sotoun): tall wooden columns, a flat
## painted ceiling, one tall niched wall behind; the entry through a door in
## the near talar's back wall, a grand iwan closing the far side with the way
## out at the back of its hood. Each door is reached down a vaulted corridor
## two bays long (your walk: longer ways between rooms). In the court: an
## octagonal pool in the middle, rills along the two axes, four planted
## quarters with fruit trees; over it all the rock and the shaft up to the
## sky (kit_garden.blend, tools/kit_add_r07.py), whose sun and fills are the
## room's only light.
##
## Cells: the entry corridor (0, 0, 0..1); the ring x -3..3, z 2..8 (the
## corners are pieces, not walked cells... they are cells here: the talar
## turns them); the court x -2..2, z 3..7; the iwan (0, 0, 8), its piece over
## the cells either side (solid, no cells); the exit corridor (0, 0, 9..10).

## The planting in the quarters.
@export var orchard_slot: String = "garden:tree_orchard":
	set(value):
		orchard_slot = value
		emit_changed()
## Trees per quarter (0..4: one per bed cell, at its outer corner).
@export_range(0, 4) var orchard_trees: int = 4:
	set(value):
		orchard_trees = value
		emit_changed()

## The garden's state (phase 13 Q5): tended, or gone wild: the fountain dry
## and broken, the rills dry and cracked, the beds overgrown, ivy over the
## talar, the gardener's things left long ago. Set by the room's State on the
## Strata Board (_abandon), not in a grammar file.
@export var wild: bool = false:
	set(value):
		wild = value
		emit_changed()


func state_options() -> PackedStringArray:
	return ["Tended", "Gone wild", "Tended: the fountain running, beds kept, the gardener's things about. Gone wild: fountain and rills dry and cracked, beds overgrown, ivy over the talar."]


func _abandon() -> void:
	wild = true

const CORR: int = 2          # corridor bays at each end
const H_RING: int = 3        # ring cells run x -3..3
const Z0: int = CORR         # the ring's near row
const TOP: int = CORR + 6    # its far row (the iwan's)
const END: int = TOP + CORR  # the exit corridor's last cell


func layout(grid: CellGrid, seed_value: int) -> void:
	if not _free(grid):
		if not grid.quiet:
			push_warning("GardenCourtGrammar: no room for the garden")
		return
	var centre := Vector3i(0, 0, (Z0 + TOP) / 2)
	var iwan := Vector3i(0, 0, TOP)
	var exit: bool = (grid.end_kind if grid.end_kind != "" else "exit") == "exit"
	var doors: Array = [[Vector3i.ZERO, CellGrid.Side.S]]
	if exit:
		doors.append([Vector3i(0, 0, END), CellGrid.Side.N])
	for z: int in range(0, CORR):
		_cell(grid, Vector3i(0, 0, z), "corridor")
	if exit:
		for z: int in range(TOP + 1, END + 1):
			_cell(grid, Vector3i(0, 0, z), "corridor")
	for z: int in range(Z0, TOP + 1):
		for x: int in range(-H_RING, H_RING + 1):
			var c := Vector3i(x, 0, z)
			var ring: bool = absi(x) == H_RING or z == Z0 or z == TOP
			if z == TOP and absi(x) == 1:
				continue          # inside the iwan's piers
			var kind: String = "court"
			if c == Vector3i(0, 0, Z0):
				kind = "door"
			elif c == iwan:
				kind = "iwan"
			elif ring and absi(x) == H_RING and (z == Z0 or z == TOP):
				kind = "corner"
			elif ring:
				kind = "bay"
			_cell(grid, c, kind)
			if c == centre:
				grid.cells[c]["blocked"] = true       # the pool
	_mark_edges(grid, doors)
	_place_ring(grid)
	_place_garden(grid, centre, seed_value)
	var forage: Array = _place_life(grid, centre, seed_value)
	grid.props["ceiling"] = {"slot": "garden:shaft", "xf": Transform3D(Basis(), Vector3(-H_RING * CellGrid.BAY, 0, -Z0 * CellGrid.BAY)), "shell": true}
	grid.props["life"] = {"slot": "garden:life", "xf": Transform3D(Basis(), CellGrid.cell_centre(centre))}
	grid.meta = {"garden": true, "h": H_RING, "z0": Z0, "top": TOP, "centre": centre, "iwan": iwan, "doors": doors,
		"wild": wild, "seed": seed_value, "forage": forage, "route": _route(centre, exit),
		# The iwan's hood is 7 m wide, 1.5 m past its cell either side: the
		# route audit's probes reach that far before calling a side open.
		"side_reach": 4.0}
	_lanes(grid, doors, centre)


## The walk (AreaTour, the tests), as a player goes, on the paths: down the
## entry corridor, up the main rill, round the pool's east side on the path
## between its coping and the clipped beds, on up to the iwan and, if a room
## goes on, through its corridor to the far door. Cell to cell it would run
## through the benches, the takhts and the pool's rim.
func _route(centre: Vector3i, exit: bool) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for z: int in range(0, centre.z):
		out.append(CellGrid.cell_centre(Vector3i(0, 0, z)))
	var mid: Vector3 = CellGrid.cell_centre(centre)
	for i: int in 9:
		var a: float = PI * 0.5 - PI * i / 8.0      # from the entry side round the east to the iwan side
		out.append(mid + Vector3(cos(a), 0.0, sin(a)) * 3.75)
	for z: int in range(centre.z + 1, (END if exit else TOP) + 1):
		out.append(CellGrid.cell_centre(Vector3i(0, 0, z)))
	if exit:
		var at: Vector3 = CellGrid.door_transform(Vector3i(0, 0, END), CellGrid.Side.N).origin
		out.append(Vector3(at.x, 0.0, at.z + 0.6))
	return out


func _cell(grid: CellGrid, c: Vector3i, kind: String) -> void:
	grid.add_cell(c, kind, Vector3i(0, 0, 1), absi(c.x) + c.z)
	var cell: Dictionary = grid.cells[c]
	cell["floor_slot"] = ""
	cell["ceiling_slot"] = ""
	cell["gables"] = false


func _free(grid: CellGrid) -> bool:
	for z: int in range(0, END + 1):
		for x: int in range(-H_RING, H_RING + 1):
			if (z < Z0 or z > TOP) and x != 0:
				continue
			if not grid.is_free(Vector3i(x, 0, z)):
				return false
	return true


## The side of ring cell c that faces the court (a corner: -1).
static func court_side(c: Vector3i) -> int:
	if c.z == Z0 and absi(c.x) < H_RING:
		return CellGrid.Side.N
	if c.z == TOP and absi(c.x) < H_RING:
		return CellGrid.Side.S
	if c.x == -H_RING and c.z > Z0 and c.z < TOP:
		return CellGrid.Side.E
	if c.x == H_RING and c.z > Z0 and c.z < TOP:
		return CellGrid.Side.W
	return -1


## Open across the court, along the talar (bays and corners are one porch)
## and between it and the court; the iwan opens to the court; the corridors
## open into each other and through the door and the iwan's back; the doors.
func _mark_edges(grid: CellGrid, doors: Array) -> void:
	const PORCH: Array[String] = ["bay", "corner", "door"]
	for c: Vector3i in grid.cells:
		for side: int in CellGrid.ALL_SIDES:
			var n: Vector3i = CellGrid.neighbour(c, side)
			if not grid.cells.has(n):
				grid.set_edge(c, side, CellGrid.Mark.SOLID, false, "none")
				continue
			var a: String = grid.cells[c]["kind"]
			var b: String = grid.cells[n]["kind"]
			var mark: int = CellGrid.Mark.SOLID
			if a == "court" and b == "court":
				mark = CellGrid.Mark.OPEN
			elif PORCH.has(a) and PORCH.has(b):
				mark = CellGrid.Mark.OPEN
			elif (a == "court" and (PORCH.has(b) or b == "iwan")) or (b == "court" and (PORCH.has(a) or a == "iwan")):
				mark = CellGrid.Mark.OPEN
			elif a == "corridor" and b == "corridor":
				mark = CellGrid.Mark.OPEN
			elif (a == "corridor" and (b == "door" or b == "iwan")) or (b == "corridor" and (a == "door" or a == "iwan")):
				mark = CellGrid.Mark.OPENING
			grid.set_edge(c, side, mark, false, "" if mark == CellGrid.Mark.OPEN else "none")
	for i: int in doors.size():
		var c: Vector3i = doors[i][0]
		var side: int = doors[i][1]
		var host: bool = i == 0 and not grid.root
		grid.set_edge(c, side, CellGrid.Mark.DOOR, host, "none")
		if not host:
			grid.props["exit_" + CellGrid.key(c, side)] = {"slot": "stub:exit", "xf": CellGrid.door_transform(c, side)}


## The talar's bays and corners, the door in the near side's back wall, the
## iwan, and the corridors.
func _place_ring(grid: CellGrid) -> void:
	for c: Vector3i in grid.cells:
		var kind: String = grid.cells[c]["kind"]
		var n: String = CellGrid.cell_name(c)
		match kind:
			"corridor":
				_piece(grid, "corridor_" + n, "garden:corridor", CellGrid.cell_transform(c, Vector3i(0, 0, 1)))
			"iwan":
				# Three cells wide, its origin at the west one's corner (rev 4).
				_piece(grid, "iwan", "garden:iwan", CellGrid.edge_transform(c, court_side(c)).translated_local(Vector3(-CellGrid.BAY, 0, 0)))
				if not grid.cells.has(CellGrid.neighbour(c, CellGrid.Side.N)):
					# No room on past the garden (a dead end): the doorway in the
					# hood's back wall is shut, as any exit nothing joined.
					grid.props["seal_iwan"] = {"slot": "stub:exit", "xf": CellGrid.door_transform(c, CellGrid.Side.N)}
			"bay":
				_piece(grid, "talar_" + n, "garden:talar", CellGrid.edge_transform(c, court_side(c)))
			"door":
				_piece(grid, "talar_door", "garden:talar_door", CellGrid.edge_transform(c, court_side(c)))
			"corner":
				# The corner piece's frame: the court's corner at its origin.
				var inner := Vector3(c.x * CellGrid.BAY + (CellGrid.BAY if c.x < 0 else 0.0), 0.0,
					-c.z * CellGrid.BAY - (CellGrid.BAY if c.z == Z0 else 0.0))
				for side: int in CellGrid.ALL_SIDES:
					if CellGrid.edge_ends(c, side)[0].is_equal_approx(inner):
						_piece(grid, "talar_corner_" + n, "garden:talar_corner", CellGrid.edge_transform(c, side))


## The chahar bagh: the pool in the middle, rills along both axes to the
## talar, the quarters planted, fruit trees at their outer corners.
func _place_garden(grid: CellGrid, centre: Vector3i, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, "garden"])
	grid.props["pool"] = {"slot": "garden:pool_dry" if wild else "garden:pool", "xf": Transform3D(Basis(), CellGrid.cell_centre(centre))}
	for c: Vector3i in grid.cells:
		if grid.cells[c]["kind"] != "court":
			continue
		var n: String = CellGrid.cell_name(c)
		if c == centre:
			_piece(grid, "floor_" + n, "cell:court_floor", CellGrid.cell_transform(c, Vector3i(0, 0, 1)))
		elif c.x == 0:
			_piece(grid, "rill_" + n, "garden:rill_dry" if wild else "garden:rill", CellGrid.cell_transform(c, Vector3i(0, 0, 1)))
		elif c.z == centre.z:
			_piece(grid, "rill_" + n, "garden:rill_dry" if wild else "garden:rill", CellGrid.cell_transform(c, Vector3i(1, 0, 0)))
		else:
			# A bed, turned by seed so the four quarters don't repeat.
			var run := Vector3i(1, 0, 0) if rng.randi_range(0, 1) == 0 else Vector3i(0, 0, 1)
			if absi(c.x) == 1 and absi(c.z - centre.z) == 1:
				# Your walk 3: the four beds by the pool have their corner
				# toward it cut off, so a path runs round the pool.
				_piece(grid, "bed_" + n, "garden:bed_clip_wild" if wild else "garden:bed_clip", _clip_xf(c, centre))
			else:
				_piece(grid, "bed_" + n, "garden:bed_wild" if wild else "garden:bed", CellGrid.cell_transform(c, run))
	# The orchard: in each quarter, trees at the bed cells' corners away from both axes.
	for c: Vector3i in grid.cells:
		if grid.cells[c]["kind"] != "court" or c.x == 0 or c.z == centre.z:
			continue
		if rng.randi_range(0, 3) >= orchard_trees:
			continue
		var mid: Vector3 = CellGrid.cell_centre(c)
		var away_z: float = 1.0 if c.z < centre.z else -1.0       # world z grows toward the entry
		var at := Vector3(mid.x + signf(c.x) * 1.1, 0.0, mid.z + away_z * 1.1) \
			+ Vector3(rng.randf_range(-0.25, 0.25), 0.0, rng.randf_range(-0.25, 0.25))
		grid.props["orchard_" + CellGrid.cell_name(c)] = {"slot": orchard_slot, "xf": Transform3D(Basis(Vector3.UP, rng.randf_range(0.0, TAU)), at)}
	_place_great_tree(grid, seed_value)


## After walk 5 (the room's one thing to remember): a great old pomegranate,
## centred in one of the two beds beside the iwan (the seed picks), in the
## sun's patch, its crown over the paths. It takes that bed's orchard tree's
## place. Its own rng, so the rest of the layout is unchanged.
func _place_great_tree(grid: CellGrid, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, "garden_great_tree"])
	var c := Vector3i(1 if rng.randi_range(0, 1) == 0 else -1, 0, TOP - 1)
	if not grid.cells.has(c) or grid.cells[c]["kind"] != "court":
		return
	grid.props.erase("orchard_" + CellGrid.cell_name(c))
	grid.cells[c]["blocked"] = true      # its trunk mid-cell: the walk goes round (route audit)
	grid.props["great_tree"] = {"slot": "garden:tree_old_wild" if wild else "garden:tree_old",
		"xf": Transform3D(Basis(Vector3.UP, rng.randf_range(0.0, TAU)), CellGrid.cell_centre(c))}


## A clipped bed's frame: the piece's cut corner (Blender's origin) at the
## cell's corner nearest the pool, its X and Y running away from the pool.
static func _clip_xf(c: Vector3i, centre: Vector3i) -> Transform3D:
	var mid: Vector3 = CellGrid.cell_centre(c)
	var pool: Vector3 = CellGrid.cell_centre(centre)
	var ax: float = signf(mid.x - pool.x)
	var az: float = signf(mid.z - pool.z)
	var corner := mid - Vector3(ax, 0.0, az) * CellGrid.BAY * 0.5
	var basis: Basis
	if ax * az < 0.0:
		basis = Basis(Vector3(ax, 0, 0), Vector3.UP, Vector3(0, 0, -az))
	else:
		basis = Basis(Vector3(0, 0, az), Vector3.UP, Vector3(-ax, 0, 0))
	return Transform3D(basis, corner)


## Step 2's life, as props (the life node, garden:life, adds what moves and
## what you pick from meta.forage): in the side talars a takht facing the
## court and a sitting corner on a rug; shelves in some back-wall niches; two
## stone benches by the cross rill; the gardener's basket, jar and knife on
## the paving by a bed. Wild: ivy over most of the talar, the sitting corner
## left to rubble, fewer shelves, the gardener's things long abandoned.
## Returns the things to pick: [{kind, at}] in the room's frame.
func _place_life(grid: CellGrid, centre: Vector3i, seed_value: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, "garden_life"])
	var sx: int = 1 if rng.randi_range(0, 1) == 0 else -1
	var takht := Vector3i(sx * H_RING, 0, centre.z)
	var sitting := Vector3i(-sx * H_RING, 0, centre.z + (2 if rng.randi_range(0, 1) == 0 else -2))
	# Your walk 3: seats stand centred in a gap between two columns, never
	# behind one.
	var gaps: Array = _place_columns(grid, seed_value)
	var takht_gap: Dictionary = _gap_near(gaps, takht)
	var sit_gap: Dictionary = _gap_near(gaps, sitting)
	for c: Vector3i in grid.cells:
		var kind: String = grid.cells[c]["kind"]
		if kind != "bay" and kind != "door":
			continue
		var xf: Transform3D = CellGrid.edge_transform(c, court_side(c))
		var n: String = CellGrid.cell_name(c)
		if wild and rng.randf() < 0.7:
			grid.props["vines_" + n] = {"slot": "garden:talar_vines", "xf": xf}
		if kind == "door":
			continue
		if c == takht and not wild:
			grid.props["takht"] = {"slot": "landmark:takht", "xf": _seat(takht_gap, 0.0, 2.0, PI)}
		elif c == sitting:
			grid.props["sit_rug"] = {"slot": "garden:rug", "xf": _seat(sit_gap, 0.0, 2.0, 0.0)}
			if wild:
				grid.props["sit_rubble"] = {"slot": "garden:rubble", "xf": _seat(sit_gap, 0.6, 2.6, rng.randf() * TAU)}
				grid.props["sit_vase"] = {"slot": "garden:vase_broken", "xf": _seat(sit_gap, -1.0, 3.0, rng.randf() * TAU)}
			else:
				for i: int in 2:
					grid.props["sit_cushion_%d" % i] = {"slot": "garden:cushion", "xf": _seat(sit_gap, -0.7 + 1.4 * i, 2.9, PI)}
				grid.props["sit_tray"] = {"slot": "garden:tray", "xf": _seat(sit_gap, 0.0, 2.0, 0.0)}
		elif rng.randf() < (0.25 if wild else 0.45):
			grid.props["shelves_" + n] = {"slot": "garden:shelves", "xf": xf}
	var used: Array = [sit_gap] if wild else [takht_gap, sit_gap]
	if not wild:
		_place_seats(grid, gaps, used, seed_value)
	_place_planters(grid, gaps, used, seed_value)
	# Benches beside the cross rill, facing it, one each side of the pool.
	for s: int in [-1, 1]:
		var c := Vector3i(s * 2, 0, centre.z)
		var mid: Vector3 = CellGrid.cell_centre(c)
		var off: float = -1.15 * s
		grid.props["bench_%d" % s] = {"slot": "garden:bench",
			"xf": Transform3D(Basis(Vector3.UP, 0.0 if off < 0.0 else PI), mid + Vector3(0.0, 0.0, off))}
		grid.cells[c]["blocked"] = true      # the walk goes round (the route audit: a 1.8 m bench in a 4 m cell is on a line in or out)
	# The gardener's things on the paving beside a rill, by a bed.
	var spots: Array = [[Vector3i(0, 0, centre.z + 1), Vector3(1.0, 0, 0)], [Vector3i(0, 0, centre.z - 1), Vector3(-1.0, 0, 0)],
		[Vector3i(1, 0, centre.z), Vector3(0, 0, 1.0)], [Vector3i(-1, 0, centre.z), Vector3(0, 0, -1.0)]]
	var spot: Array = spots[rng.randi_range(0, spots.size() - 1)]
	grid.props["traces"] = {"slot": "garden:traces_old" if wild else "garden:traces",
		"xf": Transform3D(Basis(Vector3.UP, rng.randf() * TAU), CellGrid.cell_centre(spot[0]) + (spot[1] as Vector3))}
	# Things to pick: herbs and roots at the beds' inner corners (the trees
	# stand at the outer ones); wild, more herbs and mushrooms in the talar's shade.
	var forage: Array = []
	var beds: Array[Vector3i] = []
	for c: Vector3i in grid.cells:
		if grid.cells[c]["kind"] == "court" and c.x != 0 and c.z != centre.z:
			beds.append(c)
	beds.sort()
	var n_herb: int = 8 if wild else 6
	var n_root: int = 2 if wild else 3
	for i: int in mini(n_herb + n_root, beds.size()):
		var k: int = rng.randi_range(i, beds.size() - 1)
		var c: Vector3i = beds[k]
		beds[k] = beds[i]
		beds[i] = c
		var mid: Vector3 = CellGrid.cell_centre(c)
		var away_z: float = 1.0 if c.z < centre.z else -1.0
		var at := mid - Vector3(signf(c.x) * 0.7, 0.0, away_z * 0.7) + Vector3(rng.randf_range(-0.2, 0.2), 0.04, rng.randf_range(-0.2, 0.2))
		forage.append({"kind": "herb" if i < n_herb else "root", "at": at})
	if wild:
		var shade: Array[Vector3i] = []
		for c: Vector3i in grid.cells:
			if grid.cells[c]["kind"] == "bay" and c != sitting:
				shade.append(c)
		shade.sort()
		for i: int in mini(4, shade.size()):
			var c: Vector3i = shade[rng.randi_range(0, shade.size() - 1)]
			var xf: Transform3D = CellGrid.edge_transform(c, court_side(c))
			forage.append({"kind": "mushroom", "at": xf * Vector3(rng.randf_range(0.6, 3.4), 0.0, -3.15)})
	_place_shrubs(grid, centre, seed_value)
	return forage


## The talar's columns (your walk 3: too many at two per bay): six along each
## side between the corner columns, evenly about 3 m apart, those over the
## iwan left out; the near side's middle pair flank the door. Some with ivy
## (most, wild; a few, tended). Returns the gaps between columns (corner
## column to column too): [{cell, kind, lx, xf}], lx along the bay piece's
## frame xf, so a seat or pot stands centred in one.
func _place_columns(grid: CellGrid, seed_value: int) -> Array:
	const COL_Y: float = 0.4
	const PER_SIDE: int = 6
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, "garden_columns"])
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for c: Vector3i in grid.cells:
		if grid.cells[c]["kind"] == "court":
			var m: Vector3 = CellGrid.cell_centre(c)
			lo = lo.min(Vector2(m.x, m.z) - Vector2.ONE * CellGrid.BAY * 0.5)
			hi = hi.max(Vector2(m.x, m.z) + Vector2.ONE * CellGrid.BAY * 0.5)
	lo -= Vector2.ONE * COL_Y
	hi += Vector2.ONE * COL_Y
	var gaps: Array = []
	var cells: Array = grid.cells.keys()
	cells.sort()
	for c: Vector3i in cells:
		var kind: String = grid.cells[c]["kind"]
		if kind != "bay" and kind != "door":
			continue
		var xf: Transform3D = CellGrid.edge_transform(c, court_side(c))
		var d := Vector2(xf.basis.x.x, xf.basis.x.z).normalized()
		var p0: Vector3 = xf * Vector3(0.0, 0.0, -COL_Y)
		var start: float = minf(lo.dot(d), hi.dot(d))
		var t0: float = Vector2(p0.x, p0.z).dot(d) - start
		var step: float = absf((hi - lo).dot(d)) / float(PER_SIDE + 1)
		var n: String = CellGrid.cell_name(c)
		for k: int in range(0, PER_SIDE + 2):
			var t: float = step * k
			if k >= 1 and k <= PER_SIDE and t >= t0 and t < t0 + CellGrid.BAY:
				var slot: String = "garden:column_ivy" if rng.randf() < (0.6 if wild else 0.25) else "garden:column"
				grid.props["garden_column_%s_%d" % [n, k]] = {"slot": slot, "shell": true,
					"xf": Transform3D(xf.basis.rotated(Vector3.UP, PI * 0.5 * rng.randi_range(0, 3)), xf * Vector3(t - t0, 0.0, -COL_Y))}
			var mid: float = t + step * 0.5
			if k <= PER_SIDE and mid >= t0 and mid < t0 + CellGrid.BAY:
				gaps.append({"cell": c, "kind": kind, "lx": mid - t0, "xf": xf})
	return gaps


## The gap on cell c's side of the court nearest c's middle.
static func _gap_near(gaps: Array, c: Vector3i) -> Dictionary:
	var want: Vector3 = CellGrid.cell_centre(c)
	var side: int = court_side(c)
	var best: Dictionary = {}
	var best_d: float = INF
	for g: Dictionary in gaps:
		if court_side(g["cell"]) != side:
			continue
		var at: Vector3 = (g["xf"] as Transform3D) * Vector3(g["lx"], 0.0, 0.0)
		var dd: float = Vector2(at.x - want.x, at.z - want.z).length()
		if dd < best_d:
			best_d = dd
			best = g
	return best


## A transform in a gap's frame: x along the colonnade from the gap's middle,
## y in from the court face (Blender's, as _at).
static func _seat(g: Dictionary, x: float, y: float, yaw: float) -> Transform3D:
	return (g["xf"] as Transform3D) * _at(float(g["lx"]) + x, y, yaw)


static func _gap_pos(g: Dictionary) -> Vector3:
	return (g["xf"] as Transform3D) * Vector3(g["lx"], 0.0, 0.0)


## Your walk 3: more places to sit along the talar's walls (the tended
## garden): up to four more, a takht or a rug with cushions and a tray in
## turn, each centred in a gap between columns, not by the door, never in
## the gap next to another seat.
func _place_seats(grid: CellGrid, gaps: Array, used: Array, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, "garden_seats"])
	var free: Array = gaps.filter(func(g: Dictionary) -> bool: return g["kind"] != "door")
	for i: int in range(free.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Variant = free[i]
		free[i] = free[j]
		free[j] = tmp
	var placed: int = 0
	for g: Dictionary in free:
		if placed >= 4:
			break
		var near: bool = false
		for u: Dictionary in used:
			if not u.is_empty() and _gap_pos(u).distance_to(_gap_pos(g)) < 4.0:
				near = true
		if near:
			continue
		used.append(g)
		var key: String = "seat_%d" % placed
		if placed % 2 == 0:
			grid.props[key] = {"slot": "landmark:takht", "xf": _seat(g, 0.0, 2.0, PI)}
		else:
			grid.props[key + "_rug"] = {"slot": "garden:rug", "xf": _seat(g, 0.0, 2.0, 0.0)}
			for k: int in 2:
				grid.props[key + "_cushion_%d" % k] = {"slot": "garden:cushion", "xf": _seat(g, -0.7 + 1.4 * k, 2.9, PI)}
			grid.props[key + "_tray"] = {"slot": "garden:tray", "xf": _seat(g, 0.0, 2.0, 0.0)}
		placed += 1


## Big planted pots in about half the free gaps (a third, wild), on the
## colonnade's line; never in the door's gap or a seat's.
func _place_planters(grid: CellGrid, gaps: Array, used: Array, seed_value: int) -> void:
	const COL_Y: float = 0.4
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, "garden_planters"])
	for g: Dictionary in gaps:
		if g["kind"] == "door" or used.has(g):
			continue
		if rng.randf() < (0.35 if wild else 0.5):
			grid.props["planter_%s_%d" % [CellGrid.cell_name(g["cell"]), int(float(g["lx"]) * 10.0)]] = {
				"slot": "garden:planter_wild" if wild else "garden:planter",
				"xf": Transform3D(Basis(Vector3.UP, rng.randf() * TAU), (g["xf"] as Transform3D) * Vector3(g["lx"], 0.0, -COL_Y))}


## Shrubs in the beds' two free corners (the tree stands at the outer one,
## the herbs at the inner one): one or two a bed, bigger and more of them wild.
func _place_shrubs(grid: CellGrid, centre: Vector3i, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, "garden_shrubs"])
	var cells: Array = grid.cells.keys()
	cells.sort()
	for c: Vector3i in cells:
		if grid.cells[c]["kind"] != "court" or c.x == 0 or c.z == centre.z:
			continue
		var mid: Vector3 = CellGrid.cell_centre(c)
		var sx: float = signf(c.x)
		var az: float = 1.0 if c.z < centre.z else -1.0
		var n: String = CellGrid.cell_name(c)
		var corners: Array[Vector3] = [Vector3(sx * 1.05, 0.0, -az * 1.05), Vector3(-sx * 1.05, 0.0, az * 1.05)]
		for i: int in corners.size():
			if i == 1 and rng.randf() < 0.4:
				continue
			var s: float = rng.randf_range(1.0, 1.45) if wild else rng.randf_range(0.8, 1.15)
			var at: Vector3 = mid + corners[i] + Vector3(rng.randf_range(-0.15, 0.15), 0.0, rng.randf_range(-0.15, 0.15))
			grid.props["shrub_%s_%d" % [n, i]] = {"slot": "garden:shrub",
				"xf": Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), at)}


## A transform in an edge piece's frame from Blender's (x along the edge, y
## into the bay), turned by `yaw` about up.
static func _at(bx: float, by: float, yaw: float) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw), Vector3(bx, 0.0, -by))


## Walked lanes: down the corridor, up the main axis, round the pool, on
## through the iwan and its corridor.
func _lanes(grid: CellGrid, doors: Array, centre: Vector3i) -> void:
	grid.wear.clear()
	if not wear_lanes_enabled:
		return
	var entry: Transform3D = CellGrid.door_transform(doors[0][0], doors[0][1])
	var from: Vector2 = _xz(entry.origin - entry.basis.z * WEAR_PAST_DOOR)
	var mid: Vector2 = _xz(CellGrid.cell_centre(centre))
	var pts: Array = [[from, traffic(0)], [_xz(CellGrid.cell_centre(Vector3i(0, 0, Z0))), traffic(1)],
		[mid + Vector2(0.0, 4.0), traffic(2)], [mid + Vector2(-4.0, 0.0), traffic(3)], [mid + Vector2(0.0, -4.0), traffic(4)]]
	if doors.size() > 1:
		var far: Transform3D = CellGrid.door_transform(doors[1][0], doors[1][1])
		pts.append([_xz(CellGrid.cell_centre(Vector3i(0, 0, TOP))), traffic(5)])
		pts.append([_xz(far.origin - far.basis.z * WEAR_PAST_DOOR), traffic(6)])
	_add_lane(grid, pts)


func _piece(grid: CellGrid, key: String, slot: String, xf: Transform3D) -> void:
	grid.props["garden_" + key] = {"slot": slot, "xf": xf, "shell": true}


## The garden's lanes are laid in layout().
func wear_lanes(_grid: CellGrid, _seed_value: int) -> void:
	pass

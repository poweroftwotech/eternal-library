@tool
class_name HypostyleGrammar
extends RoomGrammar
## R03 Hypostyle Stacks (design/room-atlas.html; phase-5-design.md 5.6.2): a
## grid of bays under small domes on twisted columns, freestanding bookcases
## between them, and clear aisles from every door to a landmark at the centre.
##
## The entry is the S side of cell (0, 0, 0), as for every generated room;
## the hall spreads to both sides of it and away from the host. Every random
## choice is keyed by what it decides (seed, feature, cell), so changing one
## knob leaves the others where they were.

## Bays across and deep: the seed picks each in this range, then the hall
## shrinks until it fits beside its neighbours (never below the minimum).
@export_range(3, 20) var size_min: int = 6:
	set(value):
		size_min = value
		emit_changed()
@export_range(3, 20) var size_max: int = 8:
	set(value):
		size_max = value
		emit_changed()
## The entry may sit this many bays off the middle of its wall.
@export_range(0, 4) var entry_offset_max: int = 1:
	set(value):
		entry_offset_max = value
		emit_changed()
## Doors on the other walls (an area may grow rooms from them); none when the
## area wants this room to be a dead end.
@export_range(0, 3) var exit_min: int = 1:
	set(value):
		exit_min = value
		emit_changed()
@export_range(0, 3) var exit_max: int = 2:
	set(value):
		exit_max = value
		emit_changed()
## The landmark's clear square (bays, odd): 1, or 3 once the hall is at
## least landmark_wide_from bays both ways.
@export_range(5, 21) var landmark_wide_from: int = 7:
	set(value):
		landmark_wide_from = value
		emit_changed()
## Aisles straight through the landmark from wall to wall: 0, 1 (across) or 2
## (across and along).
@export_range(0, 2) var cross_aisles: int = 1:
	set(value):
		cross_aisles = value
		emit_changed()
## Keep the bays along the walls clear (the atlas plan's walk round the hall):
## you can browse the wall recesses, and what spills out of them has room.
@export var wall_aisle: bool = true:
	set(value):
		wall_aisle = value
		emit_changed()
## Chance that a bay off the aisles holds a freestanding bookcase.
@export_range(0.0, 1.0, 0.01) var case_density: float = 0.7:
	set(value):
		case_density = value
		emit_changed()
## A lamp hangs from the dome of every Nth bay along each aisle (0 = none).
@export_range(0, 8) var lamp_every_bays: int = 2:
	set(value):
		lamp_every_bays = value
		emit_changed()

## A bookcase's long side runs along X or Z (the seed picks one per hall).
const CASE_AXES: Array[Vector3i] = [Vector3i(0, 0, 1), Vector3i(1, 0, 0)]


func layout(grid: CellGrid, seed_value: int) -> void:
	var rect: Rect2i = fit(grid, seed_value)
	if rect.size == Vector2i.ZERO:
		if not grid.quiet:
			push_warning("HypostyleGrammar: no room for a %d x %d hall" % [size_min, size_min])
		return
	var cells: Array[Vector3i] = []
	for z: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			cells.append(Vector3i(x, 0, z))
	var centre := Vector3i(rect.position.x + rect.size.x / 2, 0, rect.position.y + rect.size.y / 2)
	var wide: bool = rect.size.x >= landmark_wide_from and rect.size.y >= landmark_wide_from
	var doors: Array = [[Vector3i.ZERO, CellGrid.Side.S]] + pick_exits(grid, rect, seed_value)
	var aisle: Dictionary = {}       # cell -> true: kept clear
	for d: Array in doors:
		for c: Vector3i in aisle_to(d[0], d[1], centre, seed_value):
			aisle[c] = true
	if cross_aisles >= 1:
		for x: int in range(rect.position.x, rect.end.x):
			aisle[Vector3i(x, 0, centre.z)] = true
	if cross_aisles >= 2:
		for z: int in range(rect.position.y, rect.end.y):
			aisle[Vector3i(centre.x, 0, z)] = true
	var clear: Dictionary = aisle.duplicate()
	if wall_aisle:
		for c: Vector3i in cells:
			if c.x == rect.position.x or c.x == rect.end.x - 1 or c.z == rect.position.y or c.z == rect.end.y - 1:
				clear[c] = true
	for dz: int in range(-1, 2):
		for dx: int in range(-1, 2):
			if wide or (dx == 0 and dz == 0):
				clear[centre + Vector3i(dx, 0, dz)] = true
	for c: Vector3i in cells:
		var d: Vector3i = (c - Vector3i.ZERO).abs()
		grid.add_cell(c, "floor", Vector3i(0, 0, 1), d.x + d.z)
		grid.cells[c]["ceiling_slot"] = "cell:oculus" if c == centre else "cell:dome"
		grid.cells[c]["gables"] = false
	mark_edges(grid, rect, doors)
	place_posts(grid, rect)
	grid.props["landmark"] = {"slot": "landmark", "xf": Transform3D(Basis(), CellGrid.cell_centre(centre))}
	place_cases(grid, cells, clear, seed_value)
	var walk: Dictionary = aisle.duplicate()
	if wall_aisle:
		for c: Vector3i in cells:
			if c.x == rect.position.x or c.x == rect.end.x - 1 or c.z == rect.position.y or c.z == rect.end.y - 1:
				walk[c] = true
	place_lamps(grid, walk, centre, seed_value)
	lanes(grid, doors, centre)


## The hall's rectangle (x, z cells), or a zero rect if even size_min won't fit.
func fit(grid: CellGrid, seed_value: int) -> Rect2i:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, "hall_size"])
	var lo: int = mini(size_min, size_max)
	var hi: int = maxi(size_min, size_max)
	var w0: int = rng.randi_range(lo, hi)
	var d0: int = rng.randi_range(lo, hi)
	var shift: int = rng.randi_range(-entry_offset_max, entry_offset_max)
	for area: int in range(w0 * d0, lo * lo - 1, -1):
		for w: int in range(w0, lo - 1, -1):
			if area % w != 0 or area / w > d0 or area / w < lo:
				continue
			var d: int = area / w
			for s: int in [shift, 0, -shift]:
				var x0: int = clampi(-(w / 2) + s, -(w - 1), 0)
				var rect := Rect2i(x0, 0, w, d)
				if _free(grid, rect):
					return rect
	return Rect2i()


func _free(grid: CellGrid, rect: Rect2i) -> bool:
	for z: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			if not grid.is_free(Vector3i(x, 0, z)):
				return false
	return true


## Exit doors as [[cell, side], ...]: on the W, E and N walls, never straight
## across from the entry or from each other (the sightline rule), each with a
## free cell beyond it for the next room.
func pick_exits(grid: CellGrid, rect: Rect2i, seed_value: int) -> Array:
	if (grid.end_kind if grid.end_kind != "" else "exit") != "exit":
		return []
	var options: Array = []
	for x: int in range(rect.position.x, rect.end.x):
		if absi(x) >= 2:
			options.append([Vector3i(x, 0, rect.end.y - 1), CellGrid.Side.N])
	for z: int in range(1, rect.end.y - 1):
		options.append([Vector3i(rect.position.x, 0, z), CellGrid.Side.W])
		options.append([Vector3i(rect.end.x - 1, 0, z), CellGrid.Side.E])
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, "hall_exits"])
	for i: int in range(options.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var t: Variant = options[i]
		options[i] = options[j]
		options[j] = t
	var want: int = rng.randi_range(mini(exit_min, exit_max), maxi(exit_min, exit_max))
	var out: Array = []
	for o: Array in options:
		if out.size() >= want:
			break
		var c: Vector3i = o[0]
		var side: int = o[1]
		if not grid.is_free(CellGrid.neighbour(c, side)):
			continue
		var clash: bool = false
		for p: Array in out:
			if p[1] == side or (side != CellGrid.Side.N and p[1] != CellGrid.Side.N and (p[0] as Vector3i).z == c.z) \
					or ((p[0] as Vector3i) - c).length_squared() <= 2:
				clash = true      # one door per wall, none facing another, none side by side
		if not clash:
			out.append(o)
	return out


## Cells from a door's cell straight in, then (one dog-leg) along to the centre.
func aisle_to(from: Vector3i, side: int, centre: Vector3i, _seed_value: int) -> Array[Vector3i]:
	var into: Vector3i = -_offset(side)
	var out: Array[Vector3i] = [from]
	var c: Vector3i = from
	# Straight in until level with the centre on the door's axis.
	while (into.z != 0 and c.z != centre.z) or (into.x != 0 and c.x != centre.x):
		c += into
		out.append(c)
	var along := Vector3i(signi(centre.x - c.x), 0, signi(centre.z - c.z))
	while c != centre:
		c += along
		out.append(c)
	return out


## The cell step a side faces (S = -z, N = +z, W = -x, E = +x).
static func _offset(side: int) -> Vector3i:
	return CellGrid.neighbour(Vector3i.ZERO, side)


## Arcades between hall cells, doors where doors are, walls everywhere else,
## and the upper band over every wall and door (dressing in the shell).
func mark_edges(grid: CellGrid, rect: Rect2i, doors: Array) -> void:
	var door_of: Dictionary = {}
	for i: int in doors.size():
		door_of[CellGrid.key(doors[i][0], doors[i][1])] = i
	for c: Vector3i in grid.cells:
		for side: int in CellGrid.ALL_SIDES:
			var n: Vector3i = CellGrid.neighbour(c, side)
			var k: String = CellGrid.key(c, side)
			if grid.cells.has(n):
				grid.set_edge(c, side, CellGrid.Mark.OPEN, false, "edge:arcade")
				continue
			grid.props["band_" + k] = {"slot": "edge:band", "xf": CellGrid.edge_transform(c, side), "shell": true}
			if not door_of.has(k):
				grid.set_edge(c, side, CellGrid.Mark.SOLID)
			elif door_of[k] == 0 and not grid.root:
				grid.set_edge(c, side, CellGrid.Mark.DOOR, true)
			else:
				grid.set_edge(c, side, CellGrid.Mark.DOOR)
				# Until a room joins here, the exit shows a lit room beyond and blocks the way.
				grid.props["exit_" + k] = {"slot": "stub:exit", "xf": CellGrid.door_transform(c, side)}


## Columns on every inner corner; the top of a pier over the host door's two
## corners (the host's own pier stands below). Wall corners take the rules'
## "post" (a tall hall pier).
func place_posts(grid: CellGrid, rect: Rect2i) -> void:
	for z: int in range(rect.position.y + 1, rect.end.y):
		for x: int in range(rect.position.x + 1, rect.end.x):
			grid.posts["%d_0_%d" % [x, z]] = "post:column"
	if grid.root:
		return          # no host pier under the entry's corners: they take the full pier
	grid.posts["0_0_0"] = "post:pier_cap"
	grid.posts["1_0_0"] = "post:pier_cap"


## A bookcase in each bay off the aisles and the landmark, by case_density;
## then any case that cuts a bay off from the entry is taken out again. A
## case along X can be passed along X only, and one along Z along Z only
## (its ends nearly touch the columns).
func place_cases(grid: CellGrid, cells: Array[Vector3i], clear: Dictionary, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, "case_axis"])
	var axis: Vector3i = CASE_AXES[rng.randi_range(0, 1)]
	var cased: Dictionary = {}
	for c: Vector3i in cells:
		if clear.has(c):
			continue
		var roll := RandomNumberGenerator.new()
		roll.seed = hash([seed_value, "case", CellGrid.cell_name(c)])
		if roll.randf() < case_density:
			cased[c] = true
	var order: Array = cased.keys()
	order.sort()
	while true:
		var cut_off: Vector3i = _first_cut_off(grid, cased, axis)
		if cut_off == Vector3i.MAX:
			break
		# Take out the case nearest the unreachable bay (deterministic order).
		var best: Vector3i = Vector3i.MAX
		for c: Vector3i in order:
			if cased.has(c) and (best == Vector3i.MAX or (c - cut_off).length_squared() < (best - cut_off).length_squared()):
				best = c
		cased.erase(best)
	for c: Vector3i in order:
		if cased.has(c):
			grid.props["case_" + CellGrid.cell_name(c)] = {"slot": "dressing:case", "xf": CellGrid.cell_transform(c, Vector3i(1, 0, 0) if axis.z != 0 else Vector3i(0, 0, 1))}


## The first bay (sorted) the entry can't reach, or Vector3i.MAX.
func _first_cut_off(grid: CellGrid, cased: Dictionary, axis: Vector3i) -> Vector3i:
	var seen: Dictionary = {Vector3i.ZERO: true}
	var todo: Array[Vector3i] = [Vector3i.ZERO]
	while not todo.is_empty():
		var c: Vector3i = todo.pop_back()
		for side: int in CellGrid.ALL_SIDES:
			var n: Vector3i = CellGrid.neighbour(c, side)
			if not grid.cells.has(n) or seen.has(n):
				continue
			# A case's long side runs along `axis`: you pass it that way only.
			if (cased.has(c) or cased.has(n)) and (n - c).abs() != axis:
				continue
			seen[n] = true
			todo.append(n)
	var keys: Array = grid.cells.keys()
	keys.sort()
	for c: Vector3i in keys:
		if not seen.has(c):
			return c
	return Vector3i.MAX


## Lamps hang over every lamp_every_bays-th bay of the aisles and the walk
## along the walls (counted from the landmark), never over the landmark,
## whose oculus lights it.
func place_lamps(grid: CellGrid, aisle: Dictionary, centre: Vector3i, _seed_value: int) -> void:
	if lamp_every_bays <= 0:
		return
	for c: Vector3i in aisle:
		if c == centre:
			continue
		var d: Vector3i = (c - centre).abs()
		if (d.x + d.z) % lamp_every_bays == 1 % lamp_every_bays:
			grid.lamps[c] = 0.0


## Walked lanes along the aisles: from each door to the landmark, busiest from
## the entry (RoomGrammar's lane weights).
func lanes(grid: CellGrid, doors: Array, centre: Vector3i) -> void:
	grid.wear.clear()
	if not wear_lanes_enabled:
		return
	for i: int in doors.size():
		var cells: Array[Vector3i] = aisle_to(doors[i][0], doors[i][1], centre, 0)
		var door: Transform3D = CellGrid.door_transform(doors[i][0], doors[i][1])
		var w0: float = traffic(0) if i == 0 else traffic(wear_far_bays / 2)
		var pts: Array = [[_xz(door.origin - door.basis.z * WEAR_PAST_DOOR), w0]]
		for j: int in cells.size():
			pts.append([_xz(CellGrid.cell_centre(cells[j])), lerpf(w0, traffic(wear_far_bays), float(j) / maxf(cells.size(), 1.0))])
		_add_lane(grid, pts)


## The base class lays lanes on any tree of open edges; a hall's every bay is
## open, so its lanes follow the aisles instead (laid in layout()).
func wear_lanes(_grid: CellGrid, _seed_value: int) -> void:
	pass

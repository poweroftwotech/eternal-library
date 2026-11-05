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
@export_range(3, 20) var size_max: int = 10:
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
## Chance that a solid wall bay holds a tall bookcase against it, floor to the
## tile band (room rework step 4); the others keep the rules' wall (a shelf
## recess or plain brick). Never on a door's wall bay.
@export_range(0.0, 1.0, 0.01) var wall_case_chance: float = 0.0:
	set(value):
		wall_case_chance = value
		emit_changed()
## A lamp hangs from the dome of every Nth bay along each aisle (0 = none).
@export_range(0, 8) var lamp_every_bays: int = 2:
	set(value):
		lamp_every_bays = value
		emit_changed()
## A cluster of lanterns hangs from the dome of every Nth bay both ways from
## the landmark, aisle or not (0 = none); it takes the place of a single lamp.
@export_range(0, 8) var lamp_cluster_every: int = 3:
	set(value):
		lamp_cluster_every = value
		emit_changed()
## Scatter the lantern clusters instead (hall rework step 1, your note: "a few
## hanging red-fire lanterns ... scattered across the room"): one per this many
## bays, seeded over the walked bays, never two within two bays of each other.
## 0 = the lattice of lamp_cluster_every.
@export_range(0, 40) var lantern_per_bays: int = 0:
	set(value):
		lantern_per_bays = value
		emit_changed()
## Sunlit domes (hall rework step 1): besides the landmark's, one dome per
## this many bays opens to the sky (cell:oculus), seeded over the bays that
## stay open, never two side by side. 0 = the landmark's only.
## The grand landmark (hall rework step 2): the landmark slot holds a pool
## under a dome whose sunbeam falls straight down (cell:oculus_centre), with a
## takht (a raised reading platform, landmark:takht) beside it facing the pool.
@export var grand_landmark: bool = false:
	set(value):
		grand_landmark = value
		emit_changed()
## Chance that a bay off the aisles and the walls holds scholars' furniture (a
## reading nook, a book cart or a sorting table; hall rework step 3).
@export_range(0.0, 1.0, 0.01) var scholar_chance: float = 0.0:
	set(value):
		scholar_chance = value
		emit_changed()
## Hang a dim lamp over any bay left with no light over it or a bay next to it.
@export var fill_dark_bays: bool = false:
	set(value):
		fill_dark_bays = value
		emit_changed()
@export_range(0, 40) var sun_per_bays: int = 0:
	set(value):
		sun_per_bays = value
		emit_changed()
## Chance that a bay off the aisles has collapsed: its dome lies in a heap of
## rubble on the floor and the bay can't be entered.
@export_range(0.0, 1.0, 0.01) var collapse_chance: float = 0.06:
	set(value):
		collapse_chance = value
		emit_changed()

## A bookcase's long side runs along X or Z (the seed picks one per hall).
const CASE_AXES: Array[Vector3i] = [Vector3i(0, 0, 1), Vector3i(1, 0, 0)]
## A takht stands this far back from its bay's centre, away from the pool (your
## walk: room to walk between them, ~1.2 m).
const TAKHT_BACK: float = 0.5


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
	mark_edges(grid, rect, doors, seed_value)
	place_posts(grid, rect)
	grid.props["landmark"] = {"slot": "landmark", "xf": Transform3D(Basis(), CellGrid.cell_centre(centre))}
	grid.cells[centre]["blocked"] = true      # its plinth and what stands on it: walk round
	if grand_landmark:
		grid.cells[centre]["ceiling_slot"] = "cell:oculus_centre"     # the beam straight down onto the pool
		for t: Vector3i in pick_takhts(grid, centre, aisle, wide):
			clear[t] = true      # no heap here
			var face: Vector3 = CellGrid.cell_centre(centre) - CellGrid.cell_centre(t)
			grid.props["takht_" + CellGrid.cell_name(t)] = {"slot": "landmark:takht",
				"xf": Transform3D(Basis.looking_at(face, Vector3.UP), CellGrid.cell_centre(t) - face.normalized() * TAKHT_BACK)}
			grid.cells[t]["blocked"] = true
	var fallen: Dictionary = pick_collapses(cells, clear, seed_value)
	place_cases(grid, cells, clear, fallen, seed_value)
	place_scholars(grid, cells, clear, fallen, seed_value)
	var walk: Dictionary = aisle.duplicate()
	if wall_aisle:
		for c: Vector3i in cells:
			if c.x == rect.position.x or c.x == rect.end.x - 1 or c.z == rect.position.y or c.z == rect.end.y - 1:
				walk[c] = true
	var sunlit: Dictionary = pick_suns(grid, cells, centre, seed_value)
	place_lamps(grid, walk, centre, fallen, seed_value, sunlit)
	lanes(grid, doors, centre)


## Scholars at work (hall rework step 3): a reading nook, a book cart or a
## sorting table (the rules' dressing:scholar) in bays off the aisles and the
## walk round the walls, by scholar_chance, each turned a seeded quarter. A bay
## with one is blocked; any that would cut a bay off from the entry is taken
## out again, nearest that bay first.
func place_scholars(grid: CellGrid, cells: Array[Vector3i], clear: Dictionary, fallen: Dictionary, seed_value: int) -> void:
	if scholar_chance <= 0.0:
		return
	var placed: Dictionary = {}
	for c: Vector3i in cells:
		if clear.has(c) or fallen.has(c) or grid.cells[c].get("blocked", false):
			continue
		var roll := RandomNumberGenerator.new()
		roll.seed = hash([seed_value, "scholar", CellGrid.cell_name(c)])
		if roll.randf() < scholar_chance:
			placed[c] = roll.randi_range(0, 3)
	var walls: Dictionary = fallen.duplicate()      # bays you can't enter: heaps, the landmark, takhts
	for c: Vector3i in cells:
		if grid.cells[c].get("blocked", false):
			walls[c] = true
	while true:
		var cut_off: Vector3i = _first_cut_off(grid, {}, walls.merged(placed), Vector3i.ZERO)
		if cut_off == Vector3i.MAX or placed.is_empty():
			break
		var best: Vector3i = Vector3i.MAX
		var order: Array = placed.keys()
		order.sort()
		for c: Vector3i in order:
			if best == Vector3i.MAX or (c - cut_off).length_squared() < (best - cut_off).length_squared():
				best = c
		placed.erase(best)
	var keys: Array = placed.keys()
	keys.sort()
	for c: Vector3i in keys:
		grid.props["scholar_" + CellGrid.cell_name(c)] = {"slot": "dressing:scholar",
			"xf": Transform3D(Basis(Vector3.UP, placed[c] * PI / 2.0), CellGrid.cell_centre(c))}
		grid.cells[c]["blocked"] = true
		grid.cells[c]["scholar"] = true      # a lamp hangs over it (place_lamps)


## The takhts' bays: beside the landmark, never on an aisle (the way from
## every door to the landmark stays clear). One in a hall whose landmark is a
## single bay; in a wide hall a pair on opposite sides when both are free.
func pick_takhts(grid: CellGrid, centre: Vector3i, aisle: Dictionary, wide: bool) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	for pair: Array in [[CellGrid.Side.N, CellGrid.Side.S], [CellGrid.Side.W, CellGrid.Side.E]]:
		var free: Array[Vector3i] = []
		for side: int in pair:
			var n: Vector3i = CellGrid.neighbour(centre, side)
			if grid.cells.has(n) and not aisle.has(n):
				free.append(n)
		if free.size() == 2 and wide:
			return free
		if out.is_empty() and not free.is_empty():
			out.append(free[0])
	return out


## Domes open to the sky, by sun_per_bays: cell -> true (the landmark's too).
## Only over bays you can walk into (no case, heap or landmark under the beam).
func pick_suns(grid: CellGrid, cells: Array[Vector3i], centre: Vector3i, seed_value: int) -> Dictionary:
	var out: Dictionary = {centre: true}
	if sun_per_bays <= 0:
		return out
	var options: Array[Vector3i] = []
	for c: Vector3i in cells:
		if not grid.cells[c].get("blocked", false):
			options.append(c)
	_shuffle(options, hash([seed_value, "sun"]))
	var want: int = maxi(1, cells.size() / sun_per_bays)
	for c: Vector3i in options:
		if out.size() > want:
			break
		if _near(out, c, 1):
			continue
		out[c] = true
		grid.cells[c]["ceiling_slot"] = "cell:oculus"
	return out


## Whether any cell in `taken` is within `bays` of c (both ways).
static func _near(taken: Dictionary, c: Vector3i, bays: int) -> bool:
	for o: Vector3i in taken:
		if absi(o.x - c.x) <= bays and absi(o.z - c.z) <= bays:
			return true
	return false


static func _shuffle(list: Array[Vector3i], seed_hash: int) -> void:
	list.sort()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_hash
	for i: int in range(list.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var t: Vector3i = list[i]
		list[i] = list[j]
		list[j] = t


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
func mark_edges(grid: CellGrid, rect: Rect2i, doors: Array, seed_value: int = 0) -> void:
	var door_of: Dictionary = {}
	var walls: Dictionary = {}       # solid edge key -> its two ends (for the cases' corners)
	var cased: Array[String] = []
	var door_ends: Dictionary = {}   # door edge key -> its two ends
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
			if door_of.has(k):
				var dxf: Transform3D = CellGrid.edge_transform(c, side)
				door_ends[k] = [dxf.origin, dxf * Vector3(CellGrid.BAY, 0, 0)]
			if not door_of.has(k):
				grid.set_edge(c, side, CellGrid.Mark.SOLID)
				var xf: Transform3D = CellGrid.edge_transform(c, side)
				walls[k] = [xf.origin, xf * Vector3(CellGrid.BAY, 0, 0)]
				var roll := RandomNumberGenerator.new()
				roll.seed = hash([seed_value, "wall_case", k])
				# Not where the wall turns inward at an end: the case would stand in
				# the next wall's recess.
				var along: Vector3i = Vector3i(1, 0, 0) if (n - c).x == 0 else Vector3i(0, 0, 1)
				var inner: bool = grid.cells.has(n + along) or grid.cells.has(n - along)
				if not inner and roll.randf() < wall_case_chance:
					grid.set_edge(c, side, CellGrid.Mark.SOLID, false, "edge:plain")
					grid.props["wallcase_" + k] = {"slot": "dressing:wall_case", "xf": CellGrid.edge_transform(c, side)}
					grid.pins["edge_" + k] = "nothing"      # no seam debris at its foot: it would land inside the case
					cased.append(k)
			elif door_of[k] == 0 and not grid.root:
				grid.set_edge(c, side, CellGrid.Mark.DOOR, true)
			else:
				grid.set_edge(c, side, CellGrid.Mark.DOOR)
				# Until a room joins here, the exit shows a lit room beyond and blocks the way.
				grid.props["exit_" + k] = {"slot": "stub:exit", "xf": CellGrid.door_transform(c, side)}
	# A wall meeting a case at its end drops no seam debris either (it would
	# land inside the case's end).
	for k: String in cased:
		for other: String in walls:
			for e: Vector3 in walls[other]:
				if e.distance_to(walls[k][0]) < 0.01 or e.distance_to(walls[k][1]) < 0.01:
					grid.pins["edge_" + other] = "nothing"
		# A door meeting a case at its corner grows no ivy under its arch: the
		# growth would hang into the case's end.
		for d: String in door_ends:
			for e: Vector3 in door_ends[d]:
				if e.distance_to(walls[k][0]) < 0.01 or e.distance_to(walls[k][1]) < 0.01:
					grid.pins["edge_" + d] = "nothing"


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


## Bays off the aisles that have collapsed, by collapse_chance: cell -> true.
func pick_collapses(cells: Array[Vector3i], clear: Dictionary, seed_value: int) -> Dictionary:
	var out: Dictionary = {}
	for c: Vector3i in cells:
		if clear.has(c):
			continue
		var roll := RandomNumberGenerator.new()
		roll.seed = hash([seed_value, "collapse", CellGrid.cell_name(c)])
		if roll.randf() < collapse_chance:
			out[c] = true
	return out


## A bookcase in each bay off the aisles, the landmark and the collapsed bays,
## by case_density; then any case or collapse that cuts a bay off from the
## entry is taken out again. A case along X can be passed along X only, and
## one along Z along Z only (its ends nearly touch the columns); a collapsed
## bay can't be entered at all. Bays that keep a case or a heap (and the
## landmark's, set in layout) are marked "blocked" in the grid (the tests
## walk round them).
func place_cases(grid: CellGrid, cells: Array[Vector3i], clear: Dictionary, fallen: Dictionary, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, "case_axis"])
	var axis: Vector3i = CASE_AXES[rng.randi_range(0, 1)]
	var cased: Dictionary = {}
	for c: Vector3i in cells:
		if clear.has(c) or fallen.has(c):
			continue
		var roll := RandomNumberGenerator.new()
		roll.seed = hash([seed_value, "case", CellGrid.cell_name(c)])
		if roll.randf() < case_density:
			cased[c] = true
	var order: Array = cased.keys() + fallen.keys()
	order.sort()
	while true:
		var cut_off: Vector3i = _first_cut_off(grid, cased, fallen, axis)
		if cut_off == Vector3i.MAX:
			break
		# Take out the case or heap nearest the unreachable bay (deterministic order).
		var best: Vector3i = Vector3i.MAX
		for c: Vector3i in order:
			if (cased.has(c) or fallen.has(c)) and (best == Vector3i.MAX or (c - cut_off).length_squared() < (best - cut_off).length_squared()):
				best = c
		cased.erase(best)
		fallen.erase(best)
	for c: Vector3i in order:
		if cased.has(c):
			grid.props["case_" + CellGrid.cell_name(c)] = {"slot": "dressing:case", "xf": CellGrid.cell_transform(c, Vector3i(1, 0, 0) if axis.z != 0 else Vector3i(0, 0, 1))}
			grid.cells[c]["blocked"] = true
		elif fallen.has(c):
			grid.props["rubble_" + CellGrid.cell_name(c)] = {"slot": "dressing:rubble_heap", "xf": CellGrid.cell_transform(c, Vector3i(1, 0, 0))}
			grid.cells[c]["ceiling_slot"] = "cell:dome_fallen"
			grid.cells[c]["blocked"] = true


## The first bay (sorted) the entry can't reach, or Vector3i.MAX. Collapsed
## bays are neither entered nor counted.
func _first_cut_off(grid: CellGrid, cased: Dictionary, fallen: Dictionary, axis: Vector3i) -> Vector3i:
	var seen: Dictionary = {Vector3i.ZERO: true}
	var todo: Array[Vector3i] = [Vector3i.ZERO]
	while not todo.is_empty():
		var c: Vector3i = todo.pop_back()
		for side: int in CellGrid.ALL_SIDES:
			var n: Vector3i = CellGrid.neighbour(c, side)
			if not grid.cells.has(n) or seen.has(n) or fallen.has(n):
				continue
			# A case's long side runs along `axis`: you pass it that way only.
			if (cased.has(c) or cased.has(n)) and (n - c).abs() != axis:
				continue
			seen[n] = true
			todo.append(n)
	var keys: Array = grid.cells.keys()
	keys.sort()
	for c: Vector3i in keys:
		if not seen.has(c) and not fallen.has(c):
			return c
	return Vector3i.MAX


## Clusters hang on a lattice every lamp_cluster_every bays both ways from the
## landmark (not over a collapsed bay); single lamps over every
## lamp_every_bays-th bay of the aisles and the walk along the walls (counted
## from the landmark) where no cluster hangs. Never over the landmark, whose
## oculus lights it, nor under a sunlit dome; lantern_per_bays scatters the
## clusters instead of the lattice.
func place_lamps(grid: CellGrid, aisle: Dictionary, centre: Vector3i, fallen: Dictionary, seed_value: int, sunlit: Dictionary = {}) -> void:
	var clustered: Dictionary = {}
	if lantern_per_bays > 0:
		var options: Array[Vector3i] = []
		for c: Vector3i in aisle:
			if not sunlit.has(c) and not fallen.has(c):
				options.append(c)
		_shuffle(options, hash([seed_value, "red_lantern"]))
		var want: int = maxi(1, grid.cells.size() / lantern_per_bays)
		for c: Vector3i in options:
			if clustered.size() >= want:
				break
			if _near(clustered, c, 2):
				continue
			grid.props["cluster_" + CellGrid.cell_name(c)] = {"slot": "lamp:cluster", "xf": Transform3D(Basis(), CellGrid.cell_centre(c))}
			clustered[c] = true
	elif lamp_cluster_every > 0:
		for c: Vector3i in grid.cells:
			var d: Vector3i = c - centre
			if c != centre and not fallen.has(c) and d.x % lamp_cluster_every == 0 and d.z % lamp_cluster_every == 0:
				grid.props["cluster_" + CellGrid.cell_name(c)] = {"slot": "lamp:cluster", "xf": Transform3D(Basis(), CellGrid.cell_centre(c))}
				clustered[c] = true
	if lamp_every_bays <= 0:
		return
	if fill_dark_bays:
		for c: Vector3i in grid.cells:     # scholars work under a lamp (your walk: their bays were dim)
			if grid.cells[c].get("scholar", false) and not clustered.has(c):
				grid.lamps[c] = 0.0
	# Light budget (rework final pass): an aisle lamp is left out where a lamp
	# or a lantern cluster already hangs over a bay next to it.
	var hung: Dictionary = clustered.duplicate()
	hung.merge(grid.lamps)
	var aisle_keys: Array = aisle.keys()
	aisle_keys.sort()
	for c: Vector3i in aisle_keys:
		if c == centre or clustered.has(c) or sunlit.has(c):
			continue
		var d: Vector3i = (c - centre).abs()
		if (d.x + d.z) % lamp_every_bays == 1 % lamp_every_bays:
			if fill_dark_bays and _near(hung, c, 1):
				continue
			grid.lamps[c] = 0.0
			hung[c] = true
	if not fill_dark_bays:
		return
	# Your walk (hall rework step 1): no dark corners. Any bay with no lamp
	# over it or a bay next to it gets a dim one (not over a heap or the
	# landmark), in a fixed order so the fill is the same every time.
	var lit: Dictionary = clustered.duplicate()     # a sunbeam lights only where it lands, not its neighbours
	for c: Vector3i in grid.lamps:
		lit[c] = true
	# Light budget (rework final pass, your pick "fewer dim lamps"): each dim
	# lamp goes where it lights the most dark bays (itself and the 8 around it),
	# ties in a fixed order, so the same bays end up lit with fewer lamps.
	var keys: Array = grid.cells.keys()
	keys.sort()
	var dark: Dictionary = {}
	for c: Vector3i in keys:
		if not fallen.has(c) and c != centre and not _near(lit, c, 1):
			dark[c] = true
	while not dark.is_empty():
		var best: Vector3i = Vector3i.MAX
		var best_n: int = 0
		for c: Vector3i in keys:
			if fallen.has(c) or c == centre or sunlit.has(c):     # no lamp in a sunbeam
				continue
			var n: int = 0
			for dx: int in range(-1, 2):
				for dz: int in range(-1, 2):
					if dark.has(c + Vector3i(dx, 0, dz)):
						n += 1
			if n > best_n:
				best_n = n
				best = c
		if best_n == 0:
			break
		grid.lamps[best] = 0.0
		for dx: int in range(-1, 2):
			for dz: int in range(-1, 2):
				dark.erase(best + Vector3i(dx, 0, dz))


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

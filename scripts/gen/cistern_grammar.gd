@tool
class_name CisternGrammar
extends HypostyleGrammar
## R11 Cistern Archive (design/room-atlas.html; phase-5-design.md 5.6.4): the
## hall's grid of bays, flooded. A causeway runs from the entry straight to a
## sealed bronze door in the far wall (and along a row to any other door);
## every other bay is water, shallow (you wade, at half speed) or deep (you
## can't go in). Timber platforms of book crates stand in the water where
## the hall has bookcases. Brick piers, arches and plain brick domes come
## from the rules (gen/rules/r11_cistern.tres); the water's pieces carry the
## surface, and deep bays a wall only the player meets.

## Chance that a bay off the causeway is deep (the bays beside it are always
## shallow, so there is water to wade into); any shallow bay you couldn't
## wade to from the causeway is made deep too.
@export_range(0.0, 1.0, 0.01) var deep_chance: float = 0.35:
	set(value):
		deep_chance = value
		emit_changed()

## Floor heights of the water pieces (tools/kit_add_r03.py), kept on each bay
## as "floor_y" for the tests.
const SHALLOW_Y: float = -0.9
const DEEP_Y: float = -2.0


func layout(grid: CellGrid, seed_value: int) -> void:
	var rect: Rect2i = fit(grid, seed_value)
	if rect.size == Vector2i.ZERO:
		if not grid.quiet:
			push_warning("CisternGrammar: no room for a %d x %d cistern" % [size_min, size_min])
		return
	var cells: Array[Vector3i] = []
	for z: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			cells.append(Vector3i(x, 0, z))
	var far := Vector3i(0, 0, rect.end.y - 1)
	var doors: Array = [[Vector3i.ZERO, CellGrid.Side.S]]
	for d: Array in pick_exits(grid, rect, seed_value):
		if d[1] != CellGrid.Side.N:          # the far wall holds the sealed door
			doors.append(d)
	# The causeway: entry to the far wall, and a branch along each other door's row.
	var causeway: Dictionary = {}
	for z: int in range(rect.position.y, rect.end.y):
		causeway[Vector3i(0, 0, z)] = true
	# Quays (flat to the walls, sheer to the water) where a branch meets the
	# causeway and at its doors; the entry and the far end keep the sloping
	# sides, so you can climb out of the water anywhere along the causeway.
	var quays: Dictionary = {}
	for d: Array in doors.slice(1):
		var c: Vector3i = d[0]
		quays[c] = true
		quays[Vector3i(0, 0, c.z)] = true
		while c.x != 0:
			causeway[c] = true
			c.x -= signi(c.x)
	var deep: Dictionary = {}
	var platforms: Dictionary = {}
	for c: Vector3i in cells:
		if causeway.has(c):
			continue
		var roll := RandomNumberGenerator.new()
		roll.seed = hash([seed_value, "deep", CellGrid.cell_name(c)])
		var beside: bool = causeway.has(c + Vector3i(1, 0, 0)) or causeway.has(c - Vector3i(1, 0, 0)) or causeway.has(c + Vector3i(0, 0, 1)) or causeway.has(c - Vector3i(0, 0, 1))
		if roll.randf() < deep_chance and not beside:
			deep[c] = true
		# Platforms stand between the piers, off the bays along the walls (where
		# the wall recesses' books would spill onto them).
		var by_wall: bool = c.x == rect.position.x or c.x == rect.end.x - 1 or c.z == rect.position.y or c.z == rect.end.y - 1
		roll.seed = hash([seed_value, "case", CellGrid.cell_name(c)])
		if roll.randf() < case_density and not by_wall:
			platforms[c] = true
	# Shallow bays you can't wade to from the causeway (round platforms and deep
	# water) are deep too.
	var reached: Dictionary = causeway.duplicate()
	var todo: Array = causeway.keys()
	while not todo.is_empty():
		var c: Vector3i = todo.pop_back()
		for side: int in CellGrid.ALL_SIDES:
			var n: Vector3i = CellGrid.neighbour(c, side)
			if rect.has_point(Vector2i(n.x, n.z)) and not reached.has(n) and not deep.has(n) and not platforms.has(n):
				reached[n] = true
				todo.append(n)
	for c: Vector3i in cells:
		var d: Vector3i = c.abs()
		grid.add_cell(c, "floor", Vector3i(0, 0, 1), d.x + d.z)
		var cell: Dictionary = grid.cells[c]
		cell["ceiling_slot"] = "cell:dome"
		cell["gables"] = false
		if quays.has(c):
			cell["floor_slot"] = "cell:quay"
			cell["floor_y"] = 0.0
		elif causeway.has(c):
			cell["floor_slot"] = "cell:causeway"
			cell["floor_run"] = Vector3i(1, 0, 0) if c.x != 0 else Vector3i(0, 0, 1)
			cell["floor_y"] = 0.0
		elif reached.has(c) or (platforms.has(c) and not deep.has(c)):     # a platform keeps its own depth
			cell["floor_slot"] = "cell:basin"
			cell["floor_y"] = SHALLOW_Y
		else:
			cell["floor_slot"] = "cell:basin_deep"
			cell["floor_y"] = DEEP_Y
			cell["blocked"] = true
		if platforms.has(c):
			grid.props["platform_" + CellGrid.cell_name(c)] = {"slot": "dressing:case", "xf": CellGrid.cell_transform(c, Vector3i(1, 0, 0))}
			cell["blocked"] = true
	mark_edges(grid, rect, doors)
	grid.set_edge(far, CellGrid.Side.N, CellGrid.Mark.SOLID, false, "edge:vault_door")
	# Below the floor, the walls go down to the bed wherever there is water.
	for k: String in grid.edges:
		var e: Dictionary = grid.edges[k]
		if e["mark"] == CellGrid.Mark.SOLID and not quays.has(e["cell"]):
			grid.props["basin_edge_" + k] = {"slot": "edge:basin_edge", "xf": CellGrid.edge_transform(e["cell"], e["side"]), "shell": true}
	place_posts(grid, rect)
	# Lanterns over the causeway and out over the water, every lamp_every_bays
	# both ways, so their light (and its reflection) spreads across the water.
	if lamp_every_bays > 0:
		for c: Vector3i in cells:
			if c.x % lamp_every_bays == 0 and c.z % lamp_every_bays == lamp_every_bays - 1:
				grid.lamps[c] = 0.0
	# The one walked lane: the entry along the causeway to the sealed door.
	grid.wear.clear()
	if wear_lanes_enabled:
		var door: Transform3D = CellGrid.door_transform(Vector3i.ZERO, CellGrid.Side.S)
		var pts: Array = [[_xz(door.origin - door.basis.z * WEAR_PAST_DOOR), traffic(0)]]
		for z: int in range(0, rect.end.y):
			pts.append([_xz(CellGrid.cell_centre(Vector3i(0, 0, z))), traffic(z)])
		_add_lane(grid, pts)

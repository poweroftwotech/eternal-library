@tool
class_name FungusTerracesGrammar
extends RoomGrammar
## R15 Fungus Terraces (design/room-atlas.html; docs/environment/phase-13-approval.md):
## growing beds climbing a cavern slope, lit only by their violet crop. A foot
## landing with the entry door, then terraces each RISE (4/3 m) over the one
## below, three a storey, up 2, 3 or 4 storeys (6, 9 or 12 terraces, Q6: the
## room joins two storeys), the last one the top landing with the far door.
## Down the middle bay the cascade falls a step at each terrace's wall, the
## stair beside it (tools/kit_add_r15.py, kit_fungus.blend).
##
## The grid, room frame (entry door on the S side of cell (0, 0, 0), the
## slope climbing toward +z cells):
##   rows      z 0 (the foot) .. 3 * storeys (the top terrace), x -2..2
##   storeys   0 .. storeys + 2 (the roof is 7-9.5 m over each row's floor)
##   far door  N side of (0, storeys, 3 * storeys)
## Every cell builds nothing of its own ("none" sides, no floor or ceiling):
## each row is one free shell prop (slots "ft:*", gen/rules/r15_fungus_terraces.tres)
## carrying its terrace, its stretch of the cavern and its light. The map
## draws each row on the storey its floor is on; the rest is air or earth.

const WIDTH: int = 5
const RISE: float = CellGrid.BAY / 3.0
const BAY: float = CellGrid.BAY
## Storeys climbed, tried in this order from a seed-picked start (Q6).
const STOREYS: Array[int] = [3, 2, 4]
## Cells of rough cave passage before the foot and after the top terrace
## (walk 1: space between the terraces and the rooms either side, and a
## proper way into a cavern), the Bridge Hall's cave piece.
const PASS: int = 2
## The room's width, and each bed's outer end (tools/kit_add_r15.py OUT), a
## patch prop of its own.
const W_ROOM: float = 20.0
const OUT: float = 3.4


func layout(grid: CellGrid, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, "fungus_terraces"])
	var order: Array[int] = STOREYS.duplicate()
	if rng.randf() < 0.35:
		order = [2, 3, 4]
	for s: int in order:
		if _fits(grid, s):
			_lay(grid, s, rng)
			return
	if not grid.quiet:
		push_warning("FungusTerracesGrammar: no room for the terraces")


func _cells(storeys: int) -> Array[Vector3i]:
	var out: Array[Vector3i] = _passage(storeys)
	for z: int in range(PASS, PASS + 3 * storeys + 1):
		for y: int in range(0, storeys + 3):
			for x: int in range(-2, 3):
				out.append(Vector3i(x, y, z))
	return out


## The passages' cells: in from the entry door, out to the far door.
func _passage(storeys: int) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	for z: int in PASS:
		out.append(Vector3i(0, 0, z))
	for k: int in PASS:
		out.append(Vector3i(0, storeys, PASS + 3 * storeys + 1 + k))
	return out


func _fits(grid: CellGrid, storeys: int) -> bool:
	for c: Vector3i in _cells(storeys):
		if not grid.is_free(c):
			return false
	return grid.is_free(Vector3i(0, storeys, 3 * storeys + 1 + 2 * PASS))


func _lay(grid: CellGrid, storeys: int, rng: RandomNumberGenerator) -> void:
	var rows: int = 3 * storeys + 1
	var i: int = 0
	for c: Vector3i in _cells(storeys):
		grid.add_cell(c, "floor", Vector3i(0, 0, 1), i)
		i += 1
		var cell: Dictionary = grid.cells[c]
		cell["floor_slot"] = ""
		cell["ceiling_slot"] = ""
		cell["gables"] = false
		cell["no_floor"] = true
		# The map: each row on the storey its floor stands on.
		if c.z >= PASS and c.z <= PASS + 3 * storeys and c.y != floori((c.z - PASS) * RISE / BAY + 0.001):
			cell["no_map"] = true
		elif c.z >= PASS and c.z <= PASS + 3 * storeys:
			cell["floor_y"] = (c.z - PASS) * RISE - c.y * BAY     # the row's floor over its storey (the tests)
	# One space: open between all its cells on each storey, and a column of
	# links up the middle so the grid's check reaches every storey.
	for c: Vector3i in grid.cells:
		for side: int in CellGrid.ALL_SIDES:
			grid.set_edge(c, side, CellGrid.Mark.SOLID, false, "none")
	for c: Vector3i in grid.cells:
		for side: int in CellGrid.ALL_SIDES:
			if grid.cells.has(CellGrid.neighbour(c, side)):
				grid.set_edge(c, side, CellGrid.Mark.OPEN)
	for z: int in range(PASS, PASS + rows):
		for y: int in range(0, storeys + 3):
			var to: Array = []
			for dy: int in [-1, 1]:
				if y + dy >= 0 and y + dy < storeys + 3:
					to.append(Vector3i(0, y + dy, z))
			grid.cells[Vector3i(0, y, z)]["links"] = to
	# The doors: the entry at the foot, the far one off the top terrace.
	grid.set_edge(Vector3i.ZERO, CellGrid.Side.S, CellGrid.Mark.DOOR, not grid.root)
	var top := Vector3i(0, storeys, PASS + rows - 1 + PASS)
	grid.set_edge(top, CellGrid.Side.N, CellGrid.Mark.DOOR)
	var k2: String = CellGrid.key(top, CellGrid.Side.N)
	grid.props["exit_" + k2] = {"slot": "stub:exit", "xf": CellGrid.door_transform(top, CellGrid.Side.N)}
	grid.pins["edge_" + k2] = "nothing"
	# The rows: the foot, the terraces (no variant twice running), the top.
	var last: int = -1
	for z: int in rows:
		var slot: String = "ft:foot" if z == 0 else ("ft:top" if z == rows - 1 else "")
		if slot == "":
			var v: int = rng.randi_range(0, 2)
			if v == last:
				v = (v + 1 + rng.randi_range(0, 1)) % 3
			last = v
			slot = "ft:row_%d" % v
		grid.props["ft_row_%d" % z] = {"slot": slot, "xf": row_xf(z), "shell": true}
	# The passages: rough rock, dark, the cell's floor.
	for c: Vector3i in _passage(storeys):
		var mid: Vector3 = CellGrid.cell_centre(c)
		grid.props["ft_cave_%s" % CellGrid.cell_name(c)] = {"slot": "ft:cave", "shell": true,
			"xf": Transform3D(Basis(), Vector3(mid.x - BAY * 0.5, c.y * BAY, mid.z + BAY * 0.5))}
	# The walk (AreaTour, the tests): in at the door, up each flight to its
	# landing, out at the far door.
	var route: Array[Vector3] = [Vector3(BAY * 0.5, 0.0, -0.6)]
	for z: int in PASS:
		route.append(Vector3(BAY * 0.5, 0.0, -BAY * (z + 0.5)))
	for z: int in range(1, rows):
		route.append(row_xf(z) * Vector3(10.0, -RISE + 0.05, -0.25))
		route.append(row_xf(z) * Vector3(10.0, 0.0, -3.4))
	for k: int in PASS:
		route.append(row_xf(rows - 1) * Vector3(10.0, 0.0, -BAY * (k + 1.5)))
	var exit_at: Vector3 = CellGrid.door_transform(top, CellGrid.Side.N).origin
	route.append(Vector3(exit_at.x, exit_at.y, exit_at.z + 0.6))
	var life_rng := RandomNumberGenerator.new()
	life_rng.seed = rng.randi()
	var forage: Array = _place_life(grid, rows, life_rng)
	grid.meta = {"terraces": true, "storeys": storeys, "rows": rows, "rise": RISE, "pass": PASS, "route": route, "forage": forage}
	grid.wear.clear()


## Row z's piece frame: its south-west corner on its floor (Blender X across,
## Y up the slope = Godot -Z).
static func row_xf(z: int) -> Transform3D:
	return Transform3D(Basis(), Vector3(-2.0 * BAY, z * RISE, -(z + PASS) * BAY))


func wear_lanes(_grid: CellGrid, _seed_value: int) -> void:
	pass


## Step 4's life (Q8, Q9), as props, and the mushrooms to pick (meta.forage,
## added by the life node, ft:life, with the spores and the falls' drops).
## Each bed's outer end (OUT) is a patch: tended by the doors (the first and
## top terraces), wilder further up the slope, a blighted one or two. Workers
## (3-8) on the paths behind the tended crop by the stair, tools and trays at
## some beds' ends, the shelter at the foot. A point in a row's piece frame
## (Blender X, Y, Z) is row_xf(z) * Vector3(X, Z, -Y).
func _place_life(grid: CellGrid, rows: int, rng: RandomNumberGenerator) -> Array:
	var forage: Array = []
	var blights: int = 0
	var used: Dictionary = {}
	for z: int in range(1, rows):
		var t: float = float(z - 1) / float(maxi(rows - 2, 1))
		for side: int in 2:
			var x0: float = 0.0 if side == 0 else W_ROOM - OUT
			var state: String = "tended"
			if z > 1 and z < rows - 1:
				if blights < 2 and rng.randf() < 0.1:
					state = "blight"
					blights += 1
				elif rng.randf() < 0.15 + 0.65 * t:
					state = "wild"
			grid.props["ft_patch_%d_%d" % [z, side]] = {"slot": "ft:patch_" + state, "xf": row_xf(z) * Transform3D(Basis(), Vector3(x0, 0.0, 0.0))}
			if state == "wild":
				for k: int in 2:
					forage.append({"kind": "mushroom", "at": row_xf(z) * Vector3(x0 + rng.randf_range(0.5, OUT - 0.5), 0.25, -rng.randf_range(1.0, 2.4))})
			# The tended crop by the stair: now and then one ready to pick.
			if rng.randf() < 0.35:
				var ix: float = rng.randf_range(OUT + 0.4, 6.0) if side == 0 else rng.randf_range(12.6, W_ROOM - OUT - 0.4)
				forage.append({"kind": "mushroom", "at": row_xf(z) * Vector3(ix, 0.25, -2.35)})
	# The workers: one to a row's side at most, on the path behind the crop.
	var spots: Array = []
	for z: int in range(1, rows):
		for side: int in 2:
			spots.append([z, side])
	for i: int in range(spots.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var s: Array = spots[i]
		spots[i] = spots[j]
		spots[j] = s
	var n: int = mini(rng.randi_range(3, 8), spots.size())
	const KINDS: Array[String] = ["stoop", "kneel", "carry"]
	for i: int in n:
		var z: int = spots[i][0]
		var side: int = spots[i][1]
		used["%d_%d" % [z, side]] = true
		var x: float = rng.randf_range(OUT + 0.6, 5.6) if side == 0 else rng.randf_range(12.9, W_ROOM - OUT - 0.6)
		var yaw: float = rng.randf_range(-0.3, 0.3)
		grid.props["ft_worker_%d" % i] = {"slot": "ft:worker_" + KINDS[rng.randi_range(0, 2)],
			"xf": row_xf(z) * Transform3D(Basis(Vector3.UP, yaw), Vector3(x, 0.0, -3.3))}
	# Tools, trays and baskets at some beds' outer ends, against the next wall.
	for z: int in range(1, rows - 1):
		for side: int in 2:
			if used.has("%d_%d" % [z, side]) or rng.randf() > 0.35:
				continue
			var tx: float = 0.9 if side == 0 else W_ROOM - 2.0
			grid.props["ft_tools_%d_%d" % [z, side]] = {"slot": "ft:bed_tools", "xf": row_xf(z) * Transform3D(Basis(), Vector3(tx, 0.0, -BAY))}
	# The shelter at the foot, east of the door, its back to the entry wall.
	grid.props["ft_shelter"] = {"slot": "ft:shelter", "xf": row_xf(0) * Transform3D(Basis(), Vector3(13.4, 0.0, -0.4))}
	# Its two cells (X 5.4-11.3 m, the foot's back half): the walk goes round
	# (the route audit's probes started inside its body).
	for x: int in [1, 2]:
		if grid.cells.has(Vector3i(x, 0, PASS)):
			grid.cells[Vector3i(x, 0, PASS)]["blocked"] = true
	grid.props["ft_life"] = {"slot": "ft:life", "xf": Transform3D()}
	return forage

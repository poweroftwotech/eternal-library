@tool
class_name QuarterGrammar
extends RoomGrammar
## R06 Domicile Quarter (design/room-atlas.html; docs/environment/phase-14-approval.md):
## narrow lanes between houses under a dark cavern roof. Four layouts, each with
## its own lane shape and its own landmark, so you can tell quarters apart:
##   hauz    a square with a pool, arms running out of it
##   wind    one bending lane past a tall wind tower (badgir)
##   bath    a lane circling a domed bath-house
##   pigeon  a long street, a round pigeon tower closing the lane off it
## Quarters of one area take different layouts until all four are used.
## An entry alley (the "alley" setting) is a narrow neck of houses before the
## block, with a sabat over it, so joined rooms don't run into each other.
##
## The grid, room frame (entry door on the S side of cell (0, 0, 0)):
##   the neck, if any: x -1..1, z 0..alley - 1, storeys 0..NECK_STOREYS - 1
##   the block: x -HALF..HALF, z alley..alley + DEPTH - 1, storeys 0..STOREYS - 1
##   lane cells: the walked ground. Every other column of cells is a house,
##   1-3 storeys of HOUSE_STOREY (3 m, not the grid's 4: Q3)
## Layouts are drawn in block cells (_mark, _at), mirrored by seed; everything
## after that is in grid cells.
## Every cell builds nothing of its own ("none" sides, no floor or ceiling):
## this grammar places each piece as a shell prop (slots "qt:*",
## gen/rules/r06_quarter.tres), as the edge tables are too coarse for lanes.

const BAY: float = CellGrid.BAY
const HALF: int = 4
const DEPTH: int = 8
const STOREYS: int = 5
const NECK_STOREYS: int = 3
const HOUSE_STOREY: float = 3.0
const LAYOUTS: PackedStringArray = ["hauz", "wind", "bath", "pigeon"]
## The entry alley's lengths, in cells.
const ALLEYS: Dictionary = {"short": 2, "long": 3}
## The row of the square's middle; the stair, its landing and the far door
## are always beyond it.
const SQUARE_Z: int = 3
const STAIR_Z: int = 5
const LAND_Z: int = 7
## How far a set-back front stands behind a proud one.
const SET_BACK: float = 0.3
## The most lights the windows bring, and how far apart.
const GLOW_MAX: int = 12
const GLOW_SPACING: float = 6.0
## The cool air of the lanes: dim shadowless fills low down, so the dark between
## the windows' pools is dusk and not black.
const COOL: Color = Color(0.68, 0.7, 0.88)
const COOL_MAX: int = 5
const COOL_MAX_DESERTED: int = 8
const COOL_SPACING: float = 10.0
const WASHING_MAX: int = 4
const CHIMNEY_MAX: int = 3
## Homes you can walk into (Q1, Q2): enough for the four kinds of household to
## show up. A home is a lane front with a real door and a room one or two cells
## deep behind it.
const HOME_MIN: int = 4
const HOME_MAX: int = 5
const DEEP_CHANCE: float = 0.65
const HOME_KINDS: PackedStringArray = ["scholar", "family", "hunter"]
## The homes of a deserted quarter.
const EMPTY_KINDS: PackedStringArray = ["abandoned", "fled", "bare"]
## Chance that a lived-in home has a note left out (an abandoned one always does).
const NOTE_CHANCE: float = 0.6
## The quarter thins out from its heart: this many cells in from the entry row,
## on the middle line. Full life out to HEART_FULL cells, none by HEART_NONE.
const HEART_Z: int = 3
const HEART_FULL: float = 1.0
const HEART_NONE: float = 5.0
## A front at life L stays lived-in up to L * FRONT_LIFE: 1 and over always is.
const FRONT_LIFE: float = 1.4
## People at their doors, only where life is at least PEOPLE_LIFE.
const PEOPLE_MAX: int = 6
const PEOPLE_SPACING: float = 8.0
const PEOPLE_LIFE: float = 0.45
## Things growing in, and rubble, along the lanes' walls.
const WEEDS_MAX: int = 12
const WEEDS_DESERTED: int = 34
## A home's things are drawn from this close (they're behind walls: nothing else
## stops them being drawn).
const FURNITURE_REACH: float = 20.0
## Nothing stands this close to a home's door.
const DOOR_CLEAR: float = 2.4
## The door's hinge in a front's frame.
const HINGE: Vector3 = Vector3(0.58, 0.0, 0.38)
## What's in each kind of home: [slot, x, depth, yaw, height off the floor]. X runs along the front
## (the door at 1.2, the window at 3.0), depth away from it into the room, in
## metres; a negative depth counts from the back wall. `back` always goes in;
## `front` too, kept to the first 3 m; `deep` only in a two-cell room.
const FURNISH: Dictionary = {
	"scholar": {
		"lamp": Vector3(2.6, 0.9, 2.5), "note": Vector3(3.2, 0.21, 1.0),
		"back": [["qt:x_books_untidy", 2.0, -0.3, 0.0]],
		"front": [["qt:x_rug_kilim", 2.05, 2.2, 0.0], ["qt:x_reading_table", 2.75, 2.5, 1.5708], ["qt:x_cushion", 2.05, 2.5, 0.0], ["qt:fig_read", 2.05, 2.5, 1.5708, 0.1],
			["qt:x_book_stack", 3.2, 1.0, 0.4], ["qt:x_book_stack", 3.25, 1.45, 1.1]],
		"deep": [["qt:x_books", 0.74, 5.6, -1.5708], ["qt:x_seat", 3.2, 5.3, 1.5708], ["qt:x_book_open", 2.0, 5.2, 0.5],
			["qt:x_scroll", 2.2, 5.6, 1.2], ["qt:x_inkwell", 1.8, 5.5, 0.0]],
	},
	"family": {
		"lamp": Vector3(2.1, 1.3, 2.0), "note": Vector3(1.85, 0.7, 2.2),
		"back": [["qt:x_hearth", 2.0, -0.3, 0.0], ["qt:fig_stir", 3.05, -1.0, -0.7]],
		"front": [["qt:x_rug_gabbeh", 2.05, 2.1, 0.0], ["qt:x_low_table", 2.1, 2.0, 0.0], ["qt:x_lamp", 2.1, 2.0, 0.0, 0.7], ["qt:x_pouf", 2.1, 1.25, 0.0],
			["qt:x_pouf", 3.0, 1.7, 0.0], ["qt:x_pot", 3.3, 0.8, 0.0]],
		"deep": [["qt:x_bed", 3.1, 5.0, 1.5708], ["qt:x_bedroll", 3.1, 4.6, 1.5708, 0.45], ["qt:x_bedroll", 3.1, 5.4, 1.5708, 0.45],
			["qt:x_pantry", 0.74, 5.4, -1.5708]],
	},
	"hunter": {
		"lamp": Vector3(2.3, 1.3, 2.4), "note": Vector3(2.55, 0.7, 2.55),
		"back": [["qt:x_traps", 2.0, -0.32, 0.0]],
		"front": [["qt:home_hides", 3.3, 2.1, 1.5708], ["qt:x_low_table", 2.3, 2.4, 0.0], ["qt:x_lamp", 2.3, 2.4, 0.0, 0.7], ["qt:x_pack", 3.05, 0.85, 1.5708], ["qt:fig_mend", 2.3, 1.7, 0.0]],
		"deep": [["qt:x_nets", 0.74, 5.4, -1.5708], ["qt:x_bedroll", 3.0, 5.0, 1.5708], ["qt:x_cushion", 2.2, 5.3, 0.0], ["qt:x_pot", 3.2, 6.4, 0.0]],
	},
	"abandoned": {
		"note": Vector3(1.9, 0.02, 2.9),
		"back": [["qt:x_books_webbed", 2.0, -0.3, 0.0], ["qt:x_cobwebs", 2.0, -0.1, 0.0]],
		"front": [["qt:x_vase_broken", 3.1, 0.9, 0.7], ["qt:x_rubble", 2.1, 1.9, 0.3], ["qt:x_rubble", 2.5, 2.3, 2.0], ["qt:x_tuft", 1.5, 2.6, 0.9], ["qt:x_candles_spent", 3.0, 2.4, 0.0]],
		"deep": [["qt:x_shelves_broken", 0.74, 5.6, -1.5708], ["qt:x_log", 2.8, 5.6, 1.1], ["qt:x_rubble", 2.6, 4.6, 1.4]],
	},
	"fled": {
		"note": Vector3(1.9, 0.7, 2.2),
		"back": [["qt:x_hearth_cold", 2.0, -0.3, 0.0], ["qt:x_cobwebs", 2.0, -0.1, 0.0]],
		"front": [["qt:x_rug_gabbeh", 2.05, 2.1, 0.2], ["qt:x_low_table", 2.1, 2.0, 0.4], ["qt:x_pouf", 3.0, 1.7, 0.0], ["qt:x_vase_broken", 3.3, 0.8, 0.5],
			["qt:x_tuft", 1.3, 2.7, 0.4]],
		"deep": [["qt:x_bed", 3.1, 5.0, 1.5708], ["qt:x_books_fallen", 0.74, 5.4, -1.5708], ["qt:x_moss", 2.4, 6.2, 0.0]],
	},
	"bare": {
		"back": [["qt:x_cobwebs", 2.0, -0.1, 0.0]],
		"front": [["qt:x_rubble", 2.8, 1.9, 0.6], ["qt:x_rubble", 2.3, 2.5, 2.3], ["qt:x_tuft", 3.2, 1.2, 0.0], ["qt:x_moss", 2.7, 2.7, 0.0], ["qt:x_fern", 3.2, 2.9, 1.0]],
		"deep": [["qt:x_fern", 3.1, 6.1, 2.0], ["qt:x_moss", 2.6, 5.4, 0.0], ["qt:x_rubble", 1.2, 6.4, 0.9]],
	},
}

## One of LAYOUTS; "": the area's seed deals them out.
@export var layout_name: String = ""
## Cells of entry alley (0: none).
@export var alley: int = 0
## Nobody lives here any more: no people, no lamps or fires, every home empty,
## plants coming in (the Forgotten City's version; Q6).
@export var deserted: bool = false

var _lane: Dictionary = {}      # Vector2i -> "lane" | "square" | "stair" | "landing"
var _height: Dictionary = {}    # Vector2i (a house cell) -> storeys
var _tint: Dictionary = {}      # Vector2i (a house cell) -> "r" | "c"
var _quiet: Dictionary = {}     # Vector2i (a house cell) -> only blank walls (a stair's side, a landmark)
var _keep: Dictionary = {}      # Vector2i (a landmark's cell) -> storeys of the house under it
var _homes: Array[Dictionary] = []     # {kind, lane, side, n, deep, tint}
var _home_edge: Dictionary = {}  # "x_z_side" of the lane cell's wall -> its home
var _home_cell: Dictionary = {}  # Vector2i -> true: a cell with a room in it
var _steps: Array[Dictionary] = []     # {xf, c}: a house door's foot, on a lived-in front
var _foot: Dictionary = {}      # Vector2i -> true: every cell of the room
var _oz: int = 0                # the block's first row
var _flip: int = 1              # 1, or -1: the layout mirrored


func tweak_fields() -> Array[Dictionary]:
	return [
		{"key": "layout", "label": "Layout", "tip": "Each layout has its own lanes and landmark. Seed picks: quarters of an area take different ones.", "options": [
			{"label": "Seed picks", "value": ""},
			{"label": "Hauz Square", "value": "hauz"},
			{"label": "Wind Tower", "value": "wind"},
			{"label": "Bath Ring", "value": "bath"},
			{"label": "Pigeon Tower", "value": "pigeon"}]},
		{"key": "alley", "label": "Entry alley", "tip": "A narrow alley of houses at the entrance, between this room and the one it joins.", "options": [
			{"label": "None", "value": ""},
			{"label": "Short (8 m)", "value": "short"},
			{"label": "Long (12 m)", "value": "long"}]},
		{"key": "state", "label": "State", "tip": "Lived in, thinning out toward the edges; or deserted: no people, no lamps, plants coming in.", "options": [
			{"label": "Lived in", "value": ""},
			{"label": "Deserted", "value": "deserted"}]},
	]


func tweaked(tweaks: Dictionary) -> RoomGrammar:
	if tweaks.is_empty():
		return self
	var g: QuarterGrammar = duplicate(false)
	g.set_meta("source_path", source_path())
	if LAYOUTS.has(str(tweaks.get("layout", ""))):
		g.layout_name = str(tweaks["layout"])
	g.alley = int(ALLEYS.get(str(tweaks.get("alley", "")), alley))
	if str(tweaks.get("state", "")) == "deserted":
		g.deserted = true
		g.lamps_dark = true
	return g


func layout(grid: CellGrid, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, "quarter"])
	_oz = alley
	_foot.clear()
	for x: int in range(-HALF, HALF + 1):
		for z: int in DEPTH:
			_foot[Vector2i(x, z + _oz)] = true
	for x: int in range(-1, 2):
		for z: int in _oz:
			_foot[Vector2i(x, z)] = true
	if not _fits(grid):
		if not grid.quiet:
			push_warning("QuarterGrammar: no room for the quarter")
		return
	_flip = 1 if rng.randf() < 0.5 else -1
	var plan: Dictionary = _plan(_pick(grid, rng), rng)
	for z: int in _oz:
		_lane[Vector2i(0, z)] = "lane"
	_lay(grid, plan, rng)


func _storeys(c: Vector2i) -> int:
	return STOREYS if c.y >= _oz else NECK_STOREYS


func _fits(grid: CellGrid) -> bool:
	for c: Vector2i in _foot:
		for y: int in _storeys(c):
			if not grid.is_free(Vector3i(c.x, y, c.y)):
				return false
	return true


## This room's layout: its own setting, else its place in the area's shuffled
## order, so an area's quarters differ until all four are used.
func _pick(grid: CellGrid, rng: RandomNumberGenerator) -> String:
	if LAYOUTS.has(layout_name):
		return layout_name
	var slot: String = str(grid.meta.get("slot_id", ""))
	if slot == "":
		return LAYOUTS[rng.randi_range(0, LAYOUTS.size() - 1)]
	var pool: Array = []
	for l: String in LAYOUTS:
		pool.append(l)
	var order: Array = []
	var deal := RandomNumberGenerator.new()
	deal.seed = hash([grid.meta.get("area_seed", 0), "quarter_layouts"])
	while not pool.is_empty():
		order.append(pool.pop_at(deal.randi_range(0, pool.size() - 1)))
	var n: int = slot.get_slice("_", slot.get_slice_count("_") - 1).to_int()
	return order[(maxi(n, 1) - 1) % order.size()]


## The lanes of layout `kind`: {kind, far, far_y, side_at, side_dir}, cells in
## the grid, and hauz (the pool's cell) for that layout.
func _plan(kind: String, rng: RandomNumberGenerator) -> Dictionary:
	_lane.clear()
	_keep.clear()
	var plan: Dictionary = {}
	match kind:
		"wind":
			plan = _wind_lanes(rng)
		"bath":
			plan = _bath_lanes(rng)
		"pigeon":
			plan = _pigeon_lanes(rng)
		_:
			for _try: int in 60:
				plan = _lanes(rng)
				if _sound():
					break
				plan = {}
			if plan.is_empty():
				plan = _plain_lanes()
	plan["kind"] = kind
	return plan


## A block cell in the grid.
func _at(x: int, z: int) -> Vector2i:
	return Vector2i(x * _flip, z + _oz)


func _doors(far_x: int, far_y: int, side_x: int, side_z: int) -> Dictionary:
	return {"far": _at(far_x, LAND_Z), "far_y": far_y, "side_at": _at(side_x, side_z), "side_dir": signi(side_x) * _flip}


## A stair up to a landing at the far edge, in column x.
func _stair(x: int) -> void:
	_mark(Vector2i(x, STAIR_Z), "stair")
	_mark(Vector2i(x, STAIR_Z + 1), "stair")
	_mark(Vector2i(x, LAND_Z), "landing")


## A straight run of lane, ends included.
func _run(from: Vector2i, to: Vector2i) -> void:
	var step := Vector2i(signi(to.x - from.x), signi(to.y - from.y))
	var c: Vector2i = from
	while c != to:
		_mark(c, "lane")
		c += step
	_mark(to, "lane")


## One try at the square's lanes; _sound() says if it will do.
func _lanes(rng: RandomNumberGenerator) -> Dictionary:
	_lane.clear()
	var px: int = rng.randi_range(-1, 1)
	var sign_far: int = 1 if rng.randf() < 0.5 else -1
	var fx: int = px + sign_far
	if fx == 0:
		fx = px - sign_far
	_square(px)
	_run(Vector2i(0, 0), Vector2i(0, 1))
	_stair(fx)
	# The arms: one to a side door at the room's edge, one ending among the houses.
	var exit_side: int = 1 if rng.randf() < 0.5 else -1
	var exit_row: int = _arm(px, exit_side, HALF, rng)
	_arm(px, -exit_side, HALF - 1, rng)
	var plan: Dictionary = _doors(fx, 1, exit_side * HALF, exit_row)
	plan["hauz"] = _at(px, SQUARE_Z)
	return plan


## The plain layout, if no try was sound.
func _plain_lanes() -> Dictionary:
	_lane.clear()
	_square(0)
	_run(Vector2i(0, 0), Vector2i(0, 1))
	_stair(1)
	_run(Vector2i(2, SQUARE_Z), Vector2i(HALF, SQUARE_Z))
	_run(Vector2i(-HALF + 1, SQUARE_Z), Vector2i(-2, SQUARE_Z))
	var plan: Dictionary = _doors(1, 1, HALF, SQUARE_Z)
	plan["hauz"] = _at(0, SQUARE_Z)
	return plan


## One lane bending through the whole quarter. The wind tower stands on the house
## closing the view as you come in, between the two long runs, so you pass it
## twice; a side door at the first
## bend, a blind end past the stair.
func _wind_lanes(rng: RandomNumberGenerator) -> Dictionary:
	var sx: int = -1 if rng.randf() < 0.5 else -2
	_run(Vector2i(0, 0), Vector2i(0, 2))
	_run(Vector2i(0, 2), Vector2i(HALF, 2))
	_run(Vector2i(3, 2), Vector2i(3, 4))
	_run(Vector2i(3, 4), Vector2i(-3, 4))
	_run(Vector2i(-3, 4), Vector2i(-3, 2))
	_stair(sx)
	_keep[_at(0, 3)] = 2
	return _doors(sx, 1, HALF, 2)


## A lane all the way round the bath-house, whose door faces you as you arrive;
## the far door straight on behind it, a side door and a blind end off the ring.
func _bath_lanes(rng: RandomNumberGenerator) -> Dictionary:
	var row: int = rng.randi_range(3, 5)
	_run(Vector2i(0, 0), Vector2i(0, 2))
	_run(Vector2i(-2, 2), Vector2i(2, 2))
	_run(Vector2i(2, 2), Vector2i(2, 6))
	_run(Vector2i(2, 6), Vector2i(-2, 6))
	_run(Vector2i(-2, 6), Vector2i(-2, 2))
	_run(Vector2i(0, 6), Vector2i(0, LAND_Z))
	_run(Vector2i(2, row), Vector2i(HALF, row))
	_run(Vector2i(-2, 4), Vector2i(-HALF, 4))
	for x: int in range(-1, 2):
		for z: int in range(3, 6):
			_keep[_at(x, z)] = 2
	return _doors(0, 0, HALF, row)


## A long street across the quarter. A lane off it runs up to the pigeon tower,
## which closes the view, and round the block back to the street; the stair
## leaves from the street's far end, a blind lane from its near side.
func _pigeon_lanes(rng: RandomNumberGenerator) -> Dictionary:
	var blind: int = 2 if rng.randf() < 0.5 else -2
	_run(Vector2i(0, 0), Vector2i(0, 3))
	_run(Vector2i(-3, 3), Vector2i(HALF, 3))
	_run(Vector2i(-3, 3), Vector2i(-3, 4))
	_run(Vector2i(0, 3), Vector2i(0, 5))
	_run(Vector2i(0, 5), Vector2i(3, 5))
	_run(Vector2i(3, 5), Vector2i(3, 3))
	_run(Vector2i(blind, 3), Vector2i(blind, 1))
	_stair(-3)
	for c: Vector2i in [Vector2i(0, 6), Vector2i(1, 6), Vector2i(0, 7), Vector2i(1, 7)]:
		_keep[_at(c.x, c.y)] = 1
	return _doors(-3, 1, HALF, 3)


func _square(px: int) -> void:
	for x: int in range(px - 1, px + 2):
		for z: int in range(SQUARE_Z - 1, SQUARE_Z + 2):
			_mark(Vector2i(x, z), "square")


## Marks a block cell.
func _mark(c: Vector2i, kind: String) -> void:
	_lane[_at(c.x, c.y)] = kind


## An arm out of the square's `side`, turning once, to column side * reach.
## Returns the row it ends on.
func _arm(px: int, side: int, reach: int, rng: RandomNumberGenerator) -> int:
	var x0: int = px + side * 2
	var row: int = rng.randi_range(SQUARE_Z - 1, SQUARE_Z + 1)
	# Only room to run straight out: the square is already at this side.
	if x0 * side >= reach - 1:
		_run(Vector2i(x0, row), Vector2i(side * reach, row))
		return row
	var bend: int = side * rng.randi_range(x0 * side + 1, reach - 1)
	var row2: int = clampi(row + (2 if rng.randf() < 0.5 else -2), 1, DEPTH - 2)
	_run(Vector2i(x0, row), Vector2i(bend, row))
	_run(Vector2i(bend, row), Vector2i(bend, row2))
	_run(Vector2i(bend, row2), Vector2i(side * reach, row2))
	return row2


## Lanes stay inside the block.
func _sound() -> bool:
	for c: Vector2i in _lane:
		if absi(c.x) > HALF or c.y < _oz or c.y >= _oz + DEPTH:
			return false
	return _sound_lanes()


## Lanes stay one cell wide outside the square: no 2 x 2 of lane, and the
## stair stands clear of every lane but the square.
func _sound_lanes() -> bool:
	for c: Vector2i in _lane:
		if _lane[c] == "square":
			continue
		var quad: bool = _lane.has(c + Vector2i(1, 0)) and _lane.has(c + Vector2i(0, 1)) and _lane.has(c + Vector2i(1, 1))
		if quad:
			return false
		if _lane[c] == "stair" or _lane[c] == "landing":
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0)]:
				if _lane.has(c + d):
					return false
	return true


func _lay(grid: CellGrid, plan: Dictionary, rng: RandomNumberGenerator) -> void:
	var i: int = 0
	for f: Vector2i in _foot:
		for y: int in _storeys(f):
			var c := Vector3i(f.x, y, f.y)
			grid.add_cell(c, "floor", Vector3i(0, 0, 1), i)
			i += 1
			var cell: Dictionary = grid.cells[c]
			cell["floor_slot"] = ""
			cell["ceiling_slot"] = ""
			cell["gables"] = false
			cell["no_floor"] = true
			var kind: String = str(_lane.get(f, ""))
			var walked: bool = (y == 1 and kind == "landing") or (y == 0 and kind != "" and kind != "landing")
			if not walked:
				cell["no_map"] = true
	# One space, as the terraces: open between its cells on each storey, a
	# column of links so the grid's check reaches every storey.
	for c: Vector3i in grid.cells:
		for side: int in CellGrid.ALL_SIDES:
			grid.set_edge(c, side, CellGrid.Mark.SOLID, false, "none")
	for c: Vector3i in grid.cells:
		for side: int in CellGrid.ALL_SIDES:
			if grid.cells.has(CellGrid.neighbour(c, side)):
				grid.set_edge(c, side, CellGrid.Mark.OPEN)
	for y: int in STOREYS:
		var to: Array = []
		for dy: int in [-1, 1]:
			if y + dy >= 0 and y + dy < STOREYS:
				to.append(Vector3i(0, y + dy, _oz))
		grid.cells[Vector3i(0, y, _oz)]["links"] = to
	# The doors.
	var entry := Vector3i.ZERO
	var far_at: Vector2i = plan["far"]
	var far := Vector3i(far_at.x, plan["far_y"], far_at.y)
	var side_at: Vector2i = plan["side_at"]
	var side_door := Vector3i(side_at.x, 0, side_at.y)
	var side_of: int = CellGrid.Side.E if int(plan["side_dir"]) > 0 else CellGrid.Side.W
	grid.set_edge(entry, CellGrid.Side.S, CellGrid.Mark.DOOR, not grid.root)
	var doors: Array = [[entry, CellGrid.Side.S], [far, CellGrid.Side.N], [side_door, side_of]]
	for d: Array in doors.slice(1):
		grid.set_edge(d[0], d[1], CellGrid.Mark.DOOR)
		grid.props["exit_" + CellGrid.key(d[0], d[1])] = {"slot": "stub:exit", "xf": CellGrid.door_transform(d[0], d[1])}
	_houses(rng, doors)
	var sabats: Array[Vector2i] = _sabats(grid, rng)
	for s: Vector2i in sabats:
		for d: Vector2i in _across(s):
			_height[s + d] = maxi(int(_height.get(s + d, 2)), 2)
			_quiet[s + d] = true     # a sabat's body would cut through their windows
	_lots(rng)
	_floors(grid)
	_fronts(grid, rng, doors, sabats)
	_rock(grid, doors, rng)
	_shell(grid, "qt_cavern", "qt:cavern", Transform3D(Basis(), Vector3(-HALF * BAY, 0.0, -_oz * BAY)))
	if _oz > 0:
		_shell(grid, "qt_cavern_neck", "qt:cavern_neck_%d" % _oz, Transform3D(Basis(), Vector3(-BAY, 0.0, 0.0)))
	var mark: Vector3 = _landmark(grid, plan)
	var homes: Array = _furnish(grid, rng)
	var people: int = _people(grid, rng)
	_washing(grid, rng, sabats)
	_weeds(grid, rng)
	var smoke: Array[Vector3] = _chimneys(grid, rng)
	_cool(grid)
	if deserted:
		# The landmark stays the way to find your feet, a pale shape over the roofs.
		grid.fills["CoolMark"] = {"at": mark + Vector3(0.0, 7.0, 3.0), "colour": COOL, "energy": 1.2, "range": 16.0}
	grid.props["qt_life"] = {"slot": "qt:life", "xf": Transform3D()}
	var route: Array[Vector3] = _walk(_path(Vector2i.ZERO, far_at, grid), Vector2i(0, 1))
	var arms: Array = [_walk(_path(Vector2i.ZERO, side_at, grid), Vector2i(int(plan["side_dir"]), 0))]
	var blind: Vector2i = _blind_end(far_at, side_at)
	if blind.y >= 0:
		arms.append(_walk(_path(Vector2i.ZERO, blind, grid), Vector2i.ZERO))
	grid.meta.merge({"quarter": true, "layout": plan["kind"], "alley": _oz, "route": route, "arms": arms, "landmark": mark, "far": far, "sabats": sabats, "smoke": smoke, "homes": homes, "people": people, "deserted": deserted, "near_only": ["prop_qt_item_", FURNITURE_REACH]}, true)
	grid.wear.clear()


## The layout's landmark; returns where it stands, in the room.
func _landmark(grid: CellGrid, plan: Dictionary) -> Vector3:
	if plan["kind"] == "hauz":
		var pool: Vector2i = plan["hauz"]
		var at := Vector3((pool.x + 0.5) * BAY, 0.0, -(pool.y + 0.5) * BAY)
		_shell(grid, "qt_hauz", "qt:hauz", Transform3D(Basis(), at))
		grid.cells[Vector3i(pool.x, 0, pool.y)]["blocked"] = true
		return at
	var mid := Vector3.ZERO
	for c: Vector2i in _keep:
		mid += Vector3((c.x + 0.5) * BAY, 0.0, -(c.y + 0.5) * BAY)
	mid /= float(_keep.size())
	match plan["kind"]:
		"wind":
			_shell(grid, "qt_badgir", "qt:badgir", Transform3D(Basis(), mid))
		"pigeon":
			_shell(grid, "qt_pigeon", "qt:pigeon", Transform3D(Basis(), mid))
		"bath":
			_shell(grid, "qt_bath", "qt:bath", Transform3D(Basis(), mid + Vector3(0.0, 2.0 * HOUSE_STOREY, 0.0)))
			# Its door faces the lane you arrive by.
			var lane := Vector3i(0, 0, _oz + 2)
			_shell(grid, "qt_bath_portal", "qt:bath_portal", CellGrid.edge_transform(lane, CellGrid.Side.N))
	return mid


## Each house cell's storeys and tint: lower in the middle, higher against the
## rock; the stair's sides are tall and blank. The neck's stay under its low
## roof, and a landmark's stand as it says.
func _houses(rng: RandomNumberGenerator, doors: Array) -> void:
	_height.clear()
	_tint.clear()
	_quiet.clear()
	for c: Vector2i in _foot:
		if _lane.has(c):
			continue
		var t: float = rng.randf()
		var h: int = 1 if t < 0.3 else (2 if t < 0.8 else 3)
		if absi(c.x) == HALF or c.y == _oz or c.y == _oz + DEPTH - 1:
			h = mini(h + 1, 3)
		_height[c] = h if c.y >= _oz else 2
		_tint[c] = "r" if rng.randf() < 0.65 else "c"
	for c: Vector2i in _lane:
		if _lane[c] == "stair" or _lane[c] == "landing":
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0)]:
				if _height.has(c + d):
					_height[c + d] = 3
					_quiet[c + d] = true
	for d: Array in doors:
		var c := Vector2i(d[0].x, d[0].z)
		for n: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if _height.has(c + n):
				_height[c + n] = maxi(_height[c + n], 2)
	for c: Vector2i in _keep:
		_height[c] = _keep[c]
		_quiet[c] = true


## The two cells either side of a straight lane cell, if it has houses both
## sides; else [].
func _across(c: Vector2i) -> Array[Vector2i]:
	for pair: Array[Vector2i] in [[Vector2i(1, 0), Vector2i(-1, 0)] as Array[Vector2i], [Vector2i(0, 1), Vector2i(0, -1)] as Array[Vector2i]]:
		if _height.has(c + pair[0]) and _height.has(c + pair[1]):
			return pair
	return []


## One sabat where you come in (over the alley's end, if there is one), one
## more over an arm.
func _sabats(grid: CellGrid, rng: RandomNumberGenerator) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var first := Vector2i(0, _oz - 1 if _oz > 0 else 1)
	var picks: Array[Vector2i] = [first]
	var arms: Array[Vector2i] = []
	for c: Vector2i in _lane:
		if _lane[c] == "lane" and c.y > _oz + 1 and absi(c.x) < HALF and _across(c).size() == 2:
			arms.append(c)
	arms.sort()
	if not arms.is_empty():
		picks.append(arms[rng.randi_range(0, arms.size() - 1)])
	for c: Vector2i in picks:
		var across: Array[Vector2i] = _across(c)
		if across.size() != 2:
			continue
		_shell(grid, "qt_sabat_%d_%d" % [c.x, c.y], "qt:sabat", _across_frame(c))
		out.append(c)
	return out


## A house cell a room can go in: clear of the rock (it juts into the cells along
## the edge), blank walls and landmarks.
func _open_lot(c: Vector2i) -> bool:
	return _height.has(c) and not _quiet.has(c) and not _keep.has(c) and absi(c.x) < HALF and c.y > _oz and c.y < _oz + DEPTH - 1


## Picks the homes: lane fronts with a room behind them, two cells deep where
## the house runs back that far. The kinds are dealt so all show when there are
## four; the abandoned home is the one furthest from the quarter's heart (the
## brief: emptier toward the edge).
func _lots(rng: RandomNumberGenerator) -> void:
	_homes.clear()
	_home_edge.clear()
	_home_cell.clear()
	var spots: Array[Dictionary] = []
	for c: Vector2i in _lane:
		if c.y < _oz or (_lane[c] != "lane" and _lane[c] != "square"):
			continue
		for side: int in CellGrid.ALL_SIDES:
			var n3: Vector3i = CellGrid.neighbour(Vector3i(c.x, 0, c.y), side)
			var n := Vector2i(n3.x, n3.z)
			if _open_lot(n):
				spots.append({"lane": c, "side": side, "n": n, "deep": _open_lot(n + n - c) and rng.randf() < DEEP_CHANCE})
	var want: int = rng.randi_range(HOME_MIN, HOME_MAX)
	for deep: bool in [true, false]:
		var round_spots: Array[Dictionary] = spots.filter(func(s: Dictionary) -> bool: return bool(s["deep"]) == deep)
		while not round_spots.is_empty() and _homes.size() < want:
			var s: Dictionary = round_spots.pop_at(rng.randi_range(0, round_spots.size() - 1))
			var n: Vector2i = s["n"]
			var far: Vector2i = n + n - (s["lane"] as Vector2i)
			if _home_cell.has(n) or (deep and _home_cell.has(far)):
				continue
			_home_cell[n] = true
			if deep:
				_home_cell[far] = true
			s["tint"] = _tint[n]
			_homes.append(s)
	_homes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _reach(a["n"]) > _reach(b["n"]))
	var kinds: Array = []
	for k: String in (EMPTY_KINDS if deserted else HOME_KINDS):
		kinds.insert(rng.randi_range(0, kinds.size()), k)
	for i: int in _homes.size():
		var h: Dictionary = _homes[i]
		h["kind"] = kinds[i % kinds.size()] if deserted else ("abandoned" if i == 0 else kinds[(i - 1) % kinds.size()])
		var lane: Vector2i = h["lane"]
		_home_edge["%d_%d_%d" % [lane.x, lane.y, h["side"]]] = h


## How far a cell is from the quarter's heart, in cells.
func _reach(c: Vector2i) -> float:
	return Vector2(c).distance_to(Vector2(0.0, _oz + HEART_Z))


## How lived-in a cell is, 1 to 0. The entry alley is the way in: it counts as
## the heart.
func _life(c: Vector2i) -> float:
	if deserted:
		return 0.0
	if c.y < _oz:
		return 1.0
	return clampf((HEART_NONE - _reach(c)) / (HEART_NONE - HEART_FULL), 0.0, 1.0)


## If a spot is clear of every home's door.
func _clear_of_homes(at: Vector3) -> bool:
	for h: Dictionary in _homes:
		if (_home_frame(h) * Vector3(1.2, at.y, -0.6)).distance_to(at) < DOOR_CLEAR:
			return false
	return true


## People at their doors and on their steps, near the heart; returns how many.
func _people(grid: CellGrid, rng: RandomNumberGenerator) -> int:
	var placed: Array[Vector3] = []
	var spots: Array[Dictionary] = _steps.filter(func(s: Dictionary) -> bool: return _life(s["c"]) >= PEOPLE_LIFE)
	while not spots.is_empty() and placed.size() < PEOPLE_MAX:
		var s: Dictionary = spots.pop_at(rng.randi_range(0, spots.size() - 1))
		var xf: Transform3D = s["xf"]
		if not _clear_of_homes(xf.origin) or placed.any(func(p: Vector3) -> bool: return p.distance_to(xf.origin) < PEOPLE_SPACING):
			continue
		var t: float = rng.randf()
		var slot: String = "qt:fig_stand" if t < 0.45 else ("qt:fig_sit" if t < 0.75 else "qt:fig_jar")
		# Beside the door, or on its step for someone sitting; facing the lane.
		var at := Vector3(0.0 if slot == "qt:fig_sit" else 0.95, 0.12 if slot == "qt:fig_sit" else 0.0, -0.8)
		grid.props["qt_fig_%d" % placed.size()] = {"slot": slot, "xf": xf * Transform3D(Basis(Vector3.UP, PI + rng.randf_range(-0.5, 0.5)), at)}
		placed.append(xf.origin)
	return placed.size()


## Plants getting in and fallen plaster along the walls, where life has thinned;
## all through a deserted quarter, with ivy down the fronts.
func _weeds(grid: CellGrid, rng: RandomNumberGenerator) -> void:
	var spots: Array[Array] = []
	for c: Vector2i in _lane:
		if c.y < _oz or (_lane[c] != "lane" and _lane[c] != "square") or rng.randf() < _life(c) * 1.4:
			continue
		for side: int in CellGrid.ALL_SIDES:
			var n3: Vector3i = CellGrid.neighbour(Vector3i(c.x, 0, c.y), side)
			var n := Vector2i(n3.x, n3.z)
			if _height.has(n) and not _keep.has(n) and not _home_edge.has("%d_%d_%d" % [c.x, c.y, side]):
				spots.append([c, side])
	var cap: int = WEEDS_DESERTED if deserted else WEEDS_MAX
	var i: int = 0
	while not spots.is_empty() and i < cap:
		var s: Array = spots.pop_at(rng.randi_range(0, spots.size() - 1))
		var c: Vector2i = s[0]
		var xf: Transform3D = CellGrid.edge_transform(Vector3i(c.x, 0, c.y), s[1])
		var at := Vector3(rng.randf_range(0.5, 3.5), 0.0, -0.62)
		var t: float = rng.randf()
		var slot: String = "qt:x_tuft" if t < 0.35 else ("qt:x_moss" if t < 0.55 else ("qt:x_rubble" if t < 0.8 else "qt:x_fern"))
		if deserted and t > 0.82:
			slot = "qt:x_ivy"
			at = Vector3(at.x, 2.9, -0.34)
		elif not _clear_of_homes(xf * at):
			continue
		grid.props["qt_weed_%d" % i] = {"slot": slot, "xf": xf * Transform3D(Basis(Vector3.UP, PI if slot == "qt:x_ivy" else rng.randf_range(0.0, TAU)), at)}
		i += 1


## A home's frame: its front's, X along the lane, +Z into the house.
func _home_frame(h: Dictionary) -> Transform3D:
	var lane: Vector2i = h["lane"]
	return CellGrid.edge_transform(Vector3i(lane.x, 0, lane.y), h["side"])


## Each home's room, door and things; returns them for the tests and captures:
## [{kind, deep, door (the lane in front of it), front, inside, back, walk (a
## clear way in, lane to back room)}].
func _furnish(grid: CellGrid, rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	var i: int = 0
	for h: Dictionary in _homes:
		var xf: Transform3D = _home_frame(h)
		var deep: bool = h["deep"]
		var depth: float = 7.6 if deep else 3.6
		var kind: String = h["kind"]
		var key: String = "qt_home%d" % i
		var lived: bool = FURNISH[kind].has("lamp")
		_shell(grid, key, "qt:home_2" if deep else "qt:home_1", xf)
		grid.props[key + "_door"] = {"slot": "qt:home_door" if lived else "qt:home_door_ajar", "xf": xf * Transform3D(Basis(), HINGE)}
		var set: Dictionary = FURNISH[kind]
		if set.has("note") and (not lived or rng.randf() < NOTE_CHANCE):
			grid.props[key + "_note"] = {"slot": "qt:note_" + (kind if lived else "abandoned"), "xf": xf * Transform3D(Basis(), set["note"])}
		var items: Array = (set["back"] as Array).map(func(t: Array) -> Array: return [t[0], t[1], depth + float(t[2]), t[3]])
		items.append_array(set["front"])
		if deep:
			items.append_array(set["deep"])
		var j: int = 0
		for t: Array in items:
			var at := Vector3(float(t[1]), 0.0, float(t[2]))
			if t.size() > 4:
				at.y = float(t[4])
			grid.props["qt_item_%d_%d" % [i, j]] = {"slot": t[0], "xf": xf * Transform3D(Basis(Vector3.UP, float(t[3])), at)}
			j += 1
		var n: Vector2i = h["n"]
		grid.cells[Vector3i(n.x, 0, n.y)].erase("no_map")
		if deep:
			var far: Vector2i = n + n - (h["lane"] as Vector2i)
			grid.cells[Vector3i(far.x, 0, far.y)].erase("no_map")
		if not lived:
			grid.fills["HomeDim%d" % i] = {"at": xf * Vector3(2.0, 1.3, depth * 0.5), "colour": COOL, "energy": 0.34, "range": 8.0}
		var walk: Array = [xf * Vector3(1.2, 0.0, -1.2), xf * Vector3(1.2, 0.0, 0.9), xf * Vector3(1.05, 0.0, 2.9)]
		if deep:
			walk.append_array([xf * Vector3(2.0, 0.0, 3.3), xf * Vector3(2.0, 0.0, 4.6)])
		out.append({"kind": kind, "deep": deep, "door": walk[0], "front": walk[1], "walk": walk,
			"inside": xf * Vector3(2.0, 0.0, depth * 0.5), "back": xf * Vector3(2.0, 0.0, depth - 0.6)})
		i += 1
	return out


## The frame of a piece spanning lane cell c: its X across the lane, its Y along.
func _across_frame(c: Vector2i) -> Transform3D:
	if _across(c)[0].y == 0:
		return _cell_frame(c)
	return Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(c.x * BAY, 0.0, -(c.y + 1) * BAY))


## Washing and cloth strung between the houses, over straight lanes with a
## house of two storeys or more each side.
func _washing(grid: CellGrid, rng: RandomNumberGenerator, sabats: Array[Vector2i]) -> void:
	var spots: Array[Vector2i] = []
	for c: Vector2i in _lane:
		if _lane[c] != "lane" or c.y < _oz or absi(c.x) >= HALF or sabats.has(c):
			continue
		var across: Array[Vector2i] = _across(c)
		if across.size() == 2 and int(_height[c + across[0]]) >= 2 and int(_height[c + across[1]]) >= 2:
			spots.append(c)
	var used: Array[Vector2i] = []
	while not spots.is_empty() and used.size() < WASHING_MAX:
		var c: Vector2i = spots.pop_at(rng.randi_range(0, spots.size() - 1))
		if used.any(func(u: Vector2i) -> bool: return Vector2(u - c).length() < 2.5) or sabats.any(func(u: Vector2i) -> bool: return Vector2(u - c).length() < 1.5):
			continue
		used.append(c)
		var t: float = rng.randf()
		var slot: String = "qt:cloth" if t < 0.25 else ("qt:washing_a" if t < 0.65 else "qt:washing_b")
		if _life(c) < PEOPLE_LIFE:
			slot = "qt:rags"
		_shell(grid, "qt_hung_%d_%d" % [c.x, c.y], slot, _across_frame(c))


## A few brick stacks on the roofs; returns where smoke starts, from those with
## someone home under them.
func _chimneys(grid: CellGrid, rng: RandomNumberGenerator) -> Array[Vector3]:
	var roofs: Array[Vector2i] = []
	for c: Vector2i in _height:
		if int(_height[c]) >= 2 and c.y >= _oz and not _keep.has(c):
			roofs.append(c)
	var out: Array[Vector3] = []
	var stacks: Array[Vector3] = []
	while not roofs.is_empty() and stacks.size() < CHIMNEY_MAX:
		var c: Vector2i = roofs.pop_at(rng.randi_range(0, roofs.size() - 1))
		var at := Vector3((c.x + 0.5) * BAY, _height[c] * HOUSE_STOREY, -(c.y + 0.5) * BAY)
		if stacks.any(func(o: Vector3) -> bool: return Vector2(o.x - at.x, o.z - at.z).length() < 10.0):
			continue
		_shell(grid, "qt_chimney_%d_%d" % [c.x, c.y], "qt:chimney", Transform3D(Basis(), at))
		stacks.append(at)
		if _life(c) >= PEOPLE_LIFE:
			out.append(at + Vector3(0.0, 1.15, 0.0))
	return out


## The lanes' cool air, spread along them.
func _cool(grid: CellGrid) -> void:
	var at: Array[Vector3] = []
	for c: Vector2i in _lane:
		if at.size() >= (COOL_MAX_DESERTED if deserted else COOL_MAX) or _lane[c] == "stair" or _lane[c] == "landing":
			continue
		var p := Vector3((c.x + 0.5) * BAY, 1.3, -(c.y + 0.5) * BAY)
		if at.all(func(o: Vector3) -> bool: return o.distance_to(p) >= COOL_SPACING):
			at.append(p)
	for i: int in at.size():
		grid.fills["CoolAir%d" % i] = {"at": at[i], "colour": COOL, "energy": 0.85 if deserted else 0.34, "range": 12.0}


## A cell-sized piece's frame on cell c: its south-west corner on the ground.
func _cell_frame(c: Vector2i, y: float = 0.0) -> Transform3D:
	return Transform3D(Basis(), Vector3(c.x * BAY, y, -c.y * BAY))


func _floors(grid: CellGrid) -> void:
	for c: Vector2i in _lane:
		var kind: String = _lane[c]
		var n: String = "%d_%d" % [c.x, c.y]
		match kind:
			"square":
				_shell(grid, "qt_floor_" + n, "qt:lane_plain", _cell_frame(c))
			"stair":
				if not _lane.has(c + Vector2i(0, -1)) or _lane[c + Vector2i(0, -1)] != "stair":
					_shell(grid, "qt_stair", "qt:stair", _cell_frame(c))
			"landing":
				_shell(grid, "qt_landing", "qt:lane_high", _cell_frame(c, BAY))
			_:
				var across_lane: bool = _lane.has(c + Vector2i(1, 0)) or _lane.has(c + Vector2i(-1, 0))
				var along: bool = _lane.has(c + Vector2i(0, 1)) or _lane.has(c + Vector2i(0, -1))
				if across_lane and along:
					_shell(grid, "qt_floor_" + n, "qt:lane_plain", _cell_frame(c))
				elif across_lane:
					_shell(grid, "qt_floor_" + n, "qt:lane", Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(c.x * BAY, 0.0, -(c.y + 1) * BAY)))
				else:
					_shell(grid, "qt_floor_" + n, "qt:lane", _cell_frame(c))
	for c: Vector2i in _height:
		_shell(grid, "qt_roof_%d_%d" % [c.x, c.y], "qt:roof", _cell_frame(c, _height[c] * HOUSE_STOREY))


## Every wall: from each cell, up the side of a taller house next to it. A
## lane sees a street front; a lower house sees a blank party wall above its
## roof. Corner posts where a house turns a lane corner.
func _fronts(grid: CellGrid, rng: RandomNumberGenerator, doors: Array, sabats: Array[Vector2i]) -> void:
	var glows: Array[Vector3] = []
	_steps.clear()
	# A home's lamp lights its room and, through its window, the lane outside.
	for h: Dictionary in _homes:
		if FURNISH[h["kind"]].has("lamp"):
			glows.append(_home_frame(h) * (FURNISH[h["kind"]]["lamp"] as Vector3))
	# The sabats' lit windows shine on the lane either side of them.
	for s: Vector2i in ([] as Array[Vector2i] if deserted else sabats):
		var mid := Vector3((s.x + 0.5) * BAY, 3.4, -(s.y + 0.5) * BAY)
		var along := Vector3(0.0, 0.0, 2.8) if _across(s)[0].y == 0 else Vector3(2.8, 0.0, 0.0)
		glows.append(mid - along)
		glows.append(mid + along)
	# The stair's walls have no windows: a lamp at its foot and on the landing.
	for c: Vector2i in _lane:
		if _lane[c] == "landing" and not deserted:
			glows.append(Vector3((c.x + 0.5) * BAY, BAY + 2.4, -(c.y + 0.6) * BAY))
			glows.append(Vector3((c.x + 0.5) * BAY, 2.6, -(c.y - 1.6) * BAY))
	for c: Vector2i in _foot:
		var base: int = int(_height.get(c, 0))
		var street: bool = _lane.has(c)
		for side: int in CellGrid.ALL_SIDES:
			var n3: Vector3i = CellGrid.neighbour(Vector3i(c.x, 0, c.y), side)
			var n := Vector2i(n3.x, n3.z)
			if not _height.has(n) or int(_height[n]) <= base:
				continue
			_stack(grid, c, side, n, base, street, rng, glows)
	# The doors: the frame round each, a storey of wall above it, a parapet.
	for d: Array in doors:
		var k: String = CellGrid.key(d[0], d[1])
		grid.pins["edge_" + k] = "nothing"     # no growth hung in the gate's wall
		var xf: Transform3D = CellGrid.edge_transform(d[0], d[1])
		_shell(grid, "qt_gate_" + k, "qt:gate", xf)
		_shell(grid, "qt_over_" + k, "qt:u_blank_r_4", xf.translated_local(Vector3(0.0, 6.0, -0.4)))
		_shell(grid, "qt_overcap_" + k, "qt:cap_r_4", xf.translated_local(Vector3(0.0, 9.0, -0.4)))
	# The corner posts.
	for c: Vector2i in _height:
		for dx: int in [-1, 1]:
			for dz: int in [-1, 1]:
				if not _lane.has(c + Vector2i(dx, 0)) or not _lane.has(c + Vector2i(0, dz)):
					continue
				var at := Vector3((c.x + (1 if dx > 0 else 0)) * BAY, 0.0, -(c.y + (1 if dz > 0 else 0)) * BAY)
				var h: int = _height[c]
				for s: int in h:
					_shell(grid, "qt_pier_%d_%d_%d_%d_%d" % [c.x, c.y, dx, dz, s], "qt:pier", Transform3D(Basis(), at + Vector3(0.0, s * HOUSE_STOREY, 0.0)))
				_shell(grid, "qt_piercap_%d_%d_%d_%d" % [c.x, c.y, dx, dz], "qt:pier_cap", Transform3D(Basis(), at + Vector3(0.0, h * HOUSE_STOREY, 0.0)))
	for i: int in glows.size():
		_shell(grid, "qt_glow_%d" % i, "qt:glow", Transform3D(Basis(), glows[i]))


## The wall of house `n` seen from cell c across `side`, storeys base..top.
func _stack(grid: CellGrid, c: Vector2i, side: int, n: Vector2i, base: int, street: bool, rng: RandomNumberGenerator, glows: Array[Vector3]) -> void:
	var xf: Transform3D = CellGrid.edge_transform(Vector3i(c.x, 0, c.y), side)
	var top: int = _height[n]
	var tint: String = _tint[n]
	var quiet: bool = _quiet.has(n) or not street
	var k: String = "%d_%d_%d" % [c.x, c.y, side]
	var home: Dictionary = _home_edge.get(k, {})
	if street and not quiet and not _home_cell.has(n) and rng.randf() < 0.3:
		xf = xf.translated_local(Vector3(0.0, 0.0, SET_BACK))
	var split: bool = street and not quiet and home.is_empty() and rng.randf() < 0.4
	var empty: bool = rng.randf() > _life(n) * FRONT_LIFE
	for s: int in range(base, top):
		var at: Transform3D = xf.translated_local(Vector3(0.0, s * HOUSE_STOREY, 0.0))
		var ground: bool = s == 0 and street
		if ground and not home.is_empty():
			_shell(grid, "qt_w_%s_%d" % [k, s], "qt:g_home_" + tint, at)
			continue
		if split:
			for half: int in 2:
				var kind: String = _kind(ground, quiet, empty, rng)
				var piece: Transform3D = at.translated_local(Vector3(2.0 * half, 0.0, 0.0))
				if kind == "door":
					_steps.append({"xf": piece.translated_local(Vector3(1.0, 0.0, 0.0)), "c": c})
				_shell(grid, "qt_w_%s_%d_%d" % [k, s, half], _slot(ground, kind, tint, 2), piece)
				if _note_glow(kind, ground, piece * Vector3(1.0, 1.9, -1.4), glows) and kind == "door":
					_shell(grid, "qt_lamp_%s_%d_%d" % [k, s, half], "qt:door_lamp", piece.translated_local(Vector3(1.8, 0.0, 0.0)))
		else:
			var kind: String = _kind(ground, quiet, empty, rng)
			_shell(grid, "qt_w_%s_%d" % [k, s], _slot(ground, kind, tint, 4), at)
			if kind == "door":
				_steps.append({"xf": at.translated_local(Vector3(1.2, 0.0, 0.0)), "c": c})
			if _note_glow(kind, ground, at * Vector3(2.0, 1.9, -1.4), glows) and kind == "door":
				_shell(grid, "qt_lamp_%s_%d" % [k, s], "qt:door_lamp", at.translated_local(Vector3(2.1, 0.0, 0.0)))
	_shell(grid, "qt_c_" + k, "qt:cap_%s_4" % tint, xf.translated_local(Vector3(0.0, top * HOUSE_STOREY, 0.0)))


## A front's kind. An empty house has its shutters closed, or nothing there at all.
func _kind(ground: bool, quiet: bool, empty: bool, rng: RandomNumberGenerator) -> String:
	if quiet:
		return "blank"
	var t: float = rng.randf()
	if empty:
		return "dark" if t < 0.75 else "blank"
	if ground:
		return "door" if t < 0.38 else ("lit" if t < 0.6 else ("dark" if t < 0.82 else "blank"))
	return "lit" if t < 0.32 else ("dark" if t < 0.68 else "blank")


func _slot(ground: bool, kind: String, tint: String, w: int) -> String:
	return "qt:%s_%s_%s_%d" % ["g" if ground else "u", kind, tint, w]


## A lit ground window or door throws a pool on the lane: real lights only so
## far apart, and only so many (the rest glow without lighting anything).
## Returns if this one got a light.
func _note_glow(kind: String, ground: bool, at: Vector3, glows: Array[Vector3]) -> bool:
	if kind == "dark" or kind == "blank" or glows.size() >= GLOW_MAX or (not ground and at.y > 4.5):
		return false
	for g: Vector3 in glows:
		if g.distance_to(at) < GLOW_SPACING:
			return false
	glows.append(at)
	return true


## The cavern's wall round the block; over a door or the neck it starts higher
## up. The neck has a low wall of its own, up to its roof.
func _rock(grid: CellGrid, doors: Array, rng: RandomNumberGenerator) -> void:
	var at_door: Dictionary = {}
	for d: Array in doors:
		at_door[CellGrid.key(Vector3i(d[0].x, 0, d[0].z), d[1])] = true
	var edges: Array = []
	for x: int in range(-HALF, HALF + 1):
		edges.append([Vector3i(x, 0, _oz), CellGrid.Side.S])
		edges.append([Vector3i(x, 0, _oz + DEPTH - 1), CellGrid.Side.N])
	for z: int in DEPTH:
		edges.append([Vector3i(-HALF, 0, z + _oz), CellGrid.Side.W])
		edges.append([Vector3i(HALF, 0, z + _oz), CellGrid.Side.E])
	for e: Array in edges:
		var k: String = CellGrid.key(e[0], e[1])
		var t: float = rng.randf()
		var over_neck: bool = _oz > 0 and e[1] == CellGrid.Side.S and absi(e[0].x) <= 1
		var slot: String = "qt:rock_wall_top" if at_door.has(k) or over_neck else ("qt:rock_wall_lit" if t < 0.3 else ("qt:rock_wall" if t < 0.65 else "qt:rock_wall_b"))
		_shell(grid, "qt_rock_" + k, slot, CellGrid.edge_transform(e[0], e[1]))
	if _oz == 0:
		return
	var neck: Array = [[Vector3i(-1, 0, 0), CellGrid.Side.S], [Vector3i(1, 0, 0), CellGrid.Side.S]]
	for z: int in _oz:
		neck.append([Vector3i(-1, 0, z), CellGrid.Side.W])
		neck.append([Vector3i(1, 0, z), CellGrid.Side.E])
	for e: Array in neck:
		var k: String = CellGrid.key(e[0], e[1])
		_shell(grid, "qt_rock_" + k, "qt:rock_low" if rng.randf() < 0.5 else "qt:rock_low_b", CellGrid.edge_transform(e[0], e[1]))
	var door_edge := Vector3i.ZERO
	_shell(grid, "qt_rock_door", "qt:rock_low_top", CellGrid.edge_transform(door_edge, CellGrid.Side.S))


## The way along the lanes from cell `from` to `to`, round the pool.
func _path(from: Vector2i, to: Vector2i, grid: CellGrid) -> Array[Vector2i]:
	var came: Dictionary = {from: from}
	var queue: Array[Vector2i] = [from]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		if c == to:
			break
		for d: Vector2i in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if _lane.has(n) and not came.has(n) and not grid.cells[Vector3i(n.x, 0, n.y)].get("blocked", false):
				came[n] = c
				queue.append(n)
	var out: Array[Vector2i] = []
	var c: Vector2i = to
	while came.has(c) and c != from:
		out.push_front(c)
		c = came[c]
	out.push_front(from)
	return out


## Room-space points along a path of cells (AreaTour, the tests): in at the
## entry door, and out through the door at the last cell's `out` side, if any.
func _walk(path: Array[Vector2i], out: Vector2i) -> Array[Vector3]:
	var points: Array[Vector3] = [Vector3(BAY * 0.5, 0.0, -0.6)]
	for c: Vector2i in path:
		points.append(_centre(c))
	if out != Vector2i.ZERO:
		var last: Vector3 = points[points.size() - 1]
		points.append(last + Vector3(out.x * (BAY * 0.5 - 0.6), 0.0, -out.y * (BAY * 0.5 - 0.6)))
	return points


## The ground at a lane cell's middle.
func _centre(c: Vector2i) -> Vector3:
	var y: float = 0.0
	if _lane[c] == "landing":
		y = BAY
	elif _lane[c] == "stair":
		y = BAY * (0.75 if str(_lane.get(c + Vector2i(0, -1), "")) == "stair" else 0.25)
	return Vector3((c.x + 0.5) * BAY, y, -(c.y + 0.5) * BAY)


## A lane cell with one way out and no door; (0, -1) if there's none.
func _blind_end(far: Vector2i, side: Vector2i) -> Vector2i:
	for c: Vector2i in _lane:
		if c == far or c == side or c == Vector2i.ZERO or _lane[c] != "lane":
			continue
		var ways: int = 0
		for d: Vector2i in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1)]:
			if _lane.has(c + d):
				ways += 1
		if ways == 1:
			return c
	return Vector2i(0, -1)


func _shell(grid: CellGrid, name: String, slot: String, xf: Transform3D) -> void:
	grid.props[name] = {"slot": slot, "xf": xf, "shell": true}


func wear_lanes(_grid: CellGrid, _seed_value: int) -> void:
	pass

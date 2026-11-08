@tool
class_name OssuaryGrammar
extends RoomGrammar
## R17 Ossuary of Books (design/room-atlas.html; docs/environment/phase-16-approval.md):
## a tree of low niche passages, one cell each, cut into pale stone. From the
## entry a cave cell and a throat lead down into the passage, which soon reaches
## the shrine's chamber (the landmark, so it goes down first). Two arms leave
## the chamber: the longer runs on to the far door, the other ends in the rock.
## Side passages and small bier rooms branch off the straight stretches.
##
## Every cell builds nothing of its own ("none" sides, no floor or ceiling): it
## is one free shell prop (slots "os:*", gen/rules/r17_ossuary.tres,
## tools/kit_add_r17.py). A passage cell never touches another except the one
## it joins, so there is always a cell of rock between passages.

## Passage cells in all, the seed picks in this range (Q3).
@export_range(4, 64) var min_cells: int = 12:
	set(value):
		min_cells = value
		emit_changed()
@export_range(4, 64) var max_cells: int = 24:
	set(value):
		max_cells = value
		emit_changed()

const BAY: float = CellGrid.BAY
## Cells past the chamber where a candle may still stand (the tended stretch).
const TENDED: int = 8
## Threads of falling dust in a room at most.
const MAX_DUST: int = 9
## Lore books in a room (the brief's Q6), from the pool in tools/make_r17_rules.gd.
const LORE: PackedStringArray = ["laying_out", "roll_of_candles", "those_who_wait"]
const LORE_COUNT: int = 2
## How far past the chamber things start to fall, and cloth to go to rags, in
## tended stretches (TENDED cells).
const FALLS_FROM: float = 0.6
const RAGS_FROM: float = 1.2
## The Forgotten version: everywhere is this far gone.
const FORGOTTEN_AGE: float = 1.5
## Cells between hung lanterns in the tended part, and between clumps of cold
## glowcaps past it. The gaps stay dark: that is the contrast.
const LANTERN_EVERY: int = 4
const GLOW_EVERY: int = 2
const MAX_PUDDLES: int = 8
## What lies in the niches is only drawn this close (grid.meta "near_only").
const GOODS_REACH: float = 24.0
## Where a body lies on a bier, in the cell's frame.
const BIER_BODY := Vector3(2.0, 0.75, -1.9)
## A piece's walls with niches, in its plan (tools/kit_add_r17.py): [from, to,
## bays], the room on the left going from one to the other.
const WALLS: Dictionary = {
	"straight": [[Vector2(3.1, 0), Vector2(3.1, 4), 2], [Vector2(0.9, 4), Vector2(0.9, 0), 2]],
	"bend": [[Vector2(4, 3.1), Vector2(0.9, 3.1), 1], [Vector2(0.9, 3.1), Vector2(0.9, 0), 1]],
	"tee": [[Vector2(4, 3.1), Vector2(0, 3.1), 2]],
	"cross": [],
	"end": [[Vector2(3.1, 0), Vector2(3.1, 3.1), 1], [Vector2(3.1, 3.1), Vector2(0.9, 3.1), 1], [Vector2(0.9, 3.1), Vector2(0.9, 0), 1]],
	"bier": [[Vector2(3.4, 0.6), Vector2(3.4, 3.35), 1], [Vector2(3.4, 3.35), Vector2(0.6, 3.35), 1], [Vector2(0.6, 3.35), Vector2(0.6, 0.6), 1]],
}
## The small niches of a bay: along the wall, sill.
const SMALL: Array[Vector2] = [Vector2(0.525, 0.98), Vector2(1.475, 0.98), Vector2(0.525, 1.5), Vector2(1.475, 1.5)]
## Sides in the order a piece turns through: a quarter turn clockwise takes
## each side to the next.
const TURN: Array[int] = [CellGrid.Side.N, CellGrid.Side.E, CellGrid.Side.S, CellGrid.Side.W]
## Each plain piece's open sides before it is turned.
const SHAPES: Dictionary = {
	"straight": [CellGrid.Side.S, CellGrid.Side.N],
	"bend": [CellGrid.Side.S, CellGrid.Side.E],
	"tee": [CellGrid.Side.S, CellGrid.Side.E, CellGrid.Side.W],
	"cross": [CellGrid.Side.S, CellGrid.Side.E, CellGrid.Side.N, CellGrid.Side.W],
	"end": [CellGrid.Side.S],
}

## Nobody comes any more (the Forgotten City's version; the brief's Q7): every
## niche dark, cloth in rags, but one candle still burning at the shrine.
@export var forgotten: bool = false

var _grid: CellGrid
var _rng: RandomNumberGenerator
var _sights: Dictionary       # one of each thing, for tests/r17_capture.gd
var _links: Dictionary        # passage cell -> sides open to another cell
var _kind: Dictionary         # cell -> "cave", "throat", "chamber", "passage" or "bier"
var _turn: Dictionary         # throat cell -> the side its cave end faces
var _parent: Dictionary       # cell -> the cell it grew from (the tree)
var _chamber: Vector3i
var _candle_spots: Array[Vector3]
var _puddles: int = 0
var _lit_biers: Dictionary    # bier cell -> true: it has its own candle
var _seed: int


func state_options() -> PackedStringArray:
	return ["Tended", "Forgotten", "Tended near the entry and forgotten deeper in; or forgotten throughout: every niche dark, cloth in rags, one candle still burning at the shrine."]


func _abandon() -> void:
	forgotten = true
	mood_tint = Color(0.5, 0.62, 0.85, 0.9)
	ambient_scale = 0.85


func layout(grid: CellGrid, seed_value: int) -> void:
	_grid = grid
	_seed = seed_value
	_lit_biers = {}
	_puddles = 0
	_sights = {}
	_rng = RandomNumberGenerator.new()
	_rng.seed = hash([seed_value, "ossuary"])
	_links = {}
	_kind = {}
	_turn = {}
	_parent = {}
	_candle_spots = []
	var target: int = _rng.randi_range(min_cells, max_cells)
	if not _entry():
		if not grid.quiet:
			push_warning("OssuaryGrammar: no room for the entry and the chamber")
		return
	var arms: Array[Vector3i] = _arms(target)
	var far: Array = _far_door(arms)
	_branches(target)
	_mark(far)
	_props(far)


## A cell the tree can take from `from`: free, and touching nothing but it.
func _can(c: Vector3i, from: Vector3i) -> bool:
	if c.y != 0 or _kind.has(c) or not _grid.is_free(c):
		return false
	for side: int in CellGrid.ALL_SIDES:
		var n: Vector3i = CellGrid.neighbour(c, side)
		if n != from and _kind.has(n):
			return false
	return true


func _join(a: Vector3i, side: int, b: Vector3i, kind: String) -> void:
	_kind[b] = kind
	_parent[b] = a
	(_links.get_or_add(a, []) as Array).append(side)
	(_links.get_or_add(b, []) as Array).append(_opposite(side))


static func _opposite(side: int) -> int:
	return TURN[(TURN.find(side) + 2) % 4]


static func _left(side: int) -> int:
	return TURN[(TURN.find(side) + 3) % 4]


static func _right(side: int) -> int:
	return TURN[(TURN.find(side) + 1) % 4]


## The cave cell, the throat, a short run and the chamber, straight on from the
## door: the shortest run that fits, from a seed-picked start.
func _entry() -> bool:
	var run: int = _rng.randi_range(2, 4)
	for tries: int in 4:
		var n: int = run + tries
		var cells: Array[Vector3i] = []
		for z: int in n + 2:
			cells.append(Vector3i(0, 0, z))
		var mid := Vector3i(0, 0, n + 3)
		if _free_line(cells) and _block_free(mid, cells[-1]):
			_kind[cells[0]] = "cave"
			_parent[cells[0]] = cells[0]
			_links[cells[0]] = [CellGrid.Side.S]
			_join(cells[0], CellGrid.Side.N, cells[1], "throat")
			_turn[cells[1]] = CellGrid.Side.S
			for i: int in range(2, cells.size()):
				_join(cells[i - 1], CellGrid.Side.N, cells[i], "passage")
			_chamber = mid
			for c: Vector3i in _block(mid):
				_kind[c] = "chamber"
				_parent[c] = mid
			var door: Vector3i = mid + Vector3i(0, 0, -1)
			_parent[door] = cells[-1]
			_parent[mid] = door
			(_links[cells[-1]] as Array).append(CellGrid.Side.N)
			return true
	return false


func _free_line(cells: Array[Vector3i]) -> bool:
	for c: Vector3i in cells:
		if not _grid.is_free(c):
			return false
	return true


static func _block(mid: Vector3i) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	for x: int in range(-1, 2):
		for z: int in range(-1, 2):
			out.append(mid + Vector3i(x, 0, z))
	return out


func _block_free(mid: Vector3i, from: Vector3i) -> bool:
	for c: Vector3i in _block(mid):
		if not _grid.is_free(c):
			return false
	return from == mid + Vector3i(0, 0, -2)


## Walks out of the chamber's two arm mouths, the first (seed-picked) toward
## the far door with the bigger share of the cells. Returns the two ends.
func _arms(target: int) -> Array[Vector3i]:
	var sides: Array[int] = [CellGrid.Side.E, CellGrid.Side.W]
	if _rng.randf() < 0.5:
		sides.reverse()
	var left: int = maxi(target - _count(), 4)
	var ends: Array[Vector3i] = []
	for i: int in 2:
		var side: int = sides[i]
		var mouth: Vector3i = _chamber + Vector3i(1 if side == CellGrid.Side.E else -1, 0, 0)
		var first: Vector3i = CellGrid.neighbour(mouth, side)
		if not _can(first, mouth):
			ends.append(Vector3i.MAX)
			continue
		_kind[first] = "passage"
		_parent[first] = mouth
		_links[first] = [_opposite(side)]
		var n: int = int(left * (0.6 if i == 0 else 0.25))
		ends.append(_walk(first, side, maxi(n, 2)))
	return ends


func _count() -> int:
	var n: int = 0
	for c: Vector3i in _kind:
		if _kind[c] == "passage" or _kind[c] == "bier":
			n += 1
	return n


## From `c` heading `dir`, up to `n` more cells: straight runs of 2-5 with a
## turn left or right between them. Returns the last cell.
func _walk(c: Vector3i, dir: int, n: int) -> Vector3i:
	var run: int = 1
	var stretch: int = _rng.randi_range(2, 5)
	for i: int in n:
		var order: Array[int] = [dir]
		var turns: Array[int] = [_left(dir), _right(dir)]
		if _rng.randf() < 0.5:
			turns.reverse()
		if run >= stretch:
			order = turns.duplicate()
			order.append(dir)
		else:
			order.append_array(turns)
		var moved: bool = false
		for side: int in order:
			var nxt: Vector3i = CellGrid.neighbour(c, side)
			if _can(nxt, c):
				_join(c, side, nxt, "passage")
				if side != dir:
					run = 0
					stretch = _rng.randi_range(2, 5)
				dir = side
				c = nxt
				run += 1
				moved = true
				break
		if not moved:
			break
	return c


## The far door, past a throat and a cave cell, off the first arm's end if it
## fits, else the other's. Returns [door cell, door side], or [] for none.
func _far_door(ends: Array[Vector3i]) -> Array:
	for end: Vector3i in ends:
		if end == Vector3i.MAX:
			continue
		var into: int = _opposite((_links[end] as Array)[0])
		for side: int in [into, _left(into), _right(into)]:
			var a: Vector3i = CellGrid.neighbour(end, side)
			var b: Vector3i = CellGrid.neighbour(a, side)
			if _can(a, end) and _can(b, a):
				_join(end, side, a, "throat")
				_turn[a] = side
				_join(a, side, b, "cave")
				(_links[b] as Array).append(side)
				return [b, side]
	return []


## Side passages off straight stretches until the room has its cells; a one
## cell spur is a bier room, about one in three.
func _branches(target: int) -> void:
	var spots: Array = []
	var keys: Array = _kind.keys()
	keys.sort()
	for c: Vector3i in keys:
		if _kind[c] == "passage":
			for side: int in CellGrid.ALL_SIDES:
				spots.append([c, side])
	for i: int in range(spots.size() - 1, 0, -1):
		var j: int = _rng.randi_range(0, i)
		var s: Array = spots[i]
		spots[i] = spots[j]
		spots[j] = s
	var biers: int = 0
	for s: Array in spots:
		var c: Vector3i = s[0]
		var side: int = s[1]
		if _count() >= target and biers > 0:
			break
		if (_links[c] as Array).size() >= 3 or (_links[c] as Array).has(side):
			continue
		var nxt: Vector3i = CellGrid.neighbour(c, side)
		if not _can(nxt, c):
			continue
		if biers == 0 or _rng.randf() < 0.35:
			_join(c, side, nxt, "bier")
			biers += 1
		else:
			_join(c, side, nxt, "passage")
			_walk(nxt, side, _rng.randi_range(1, 4))


func _mark(far: Array) -> void:
	var grid: CellGrid = _grid
	var keys: Array = _kind.keys()
	keys.sort()
	var i: int = 0
	for c: Vector3i in keys:
		grid.add_cell(c, "floor", Vector3i(0, 0, 1), i)
		i += 1
		var cell: Dictionary = grid.cells[c]
		cell["floor_slot"] = ""
		cell["ceiling_slot"] = ""
		cell["gables"] = false
		cell["no_floor"] = true
	for c: Vector3i in grid.cells:
		for side: int in CellGrid.ALL_SIDES:
			grid.set_edge(c, side, CellGrid.Mark.SOLID, false, "none")
	for c: Vector3i in _links:
		for side: int in _links[c]:
			if grid.cells.has(CellGrid.neighbour(c, side)):
				grid.set_edge(c, side, CellGrid.Mark.OPEN)
	# The chamber is one space; the corners of its block are rock.
	for c: Vector3i in _block(_chamber):
		for side: int in CellGrid.ALL_SIDES:
			if _block(_chamber).has(CellGrid.neighbour(c, side)):
				grid.set_edge(c, side, CellGrid.Mark.OPEN)
		if c.x != _chamber.x and c.z != _chamber.z:
			grid.cells[c]["blocked"] = true
	for side: int in [CellGrid.Side.E, CellGrid.Side.W]:
		var mouth: Vector3i = _chamber + Vector3i(1 if side == CellGrid.Side.E else -1, 0, 0)
		var out: Vector3i = CellGrid.neighbour(mouth, side)
		if _parent.get(out, Vector3i.MAX) == mouth:
			grid.set_edge(mouth, side, CellGrid.Mark.OPEN)
	grid.set_edge(_chamber + Vector3i(0, 0, -1), CellGrid.Side.S, CellGrid.Mark.OPEN)
	grid.set_edge(Vector3i.ZERO, CellGrid.Side.S, CellGrid.Mark.DOOR, not grid.root)
	if not far.is_empty():
		var k: String = CellGrid.key(far[0], far[1])
		grid.set_edge(far[0], far[1], CellGrid.Mark.DOOR)
		grid.props["exit_" + k] = {"slot": "stub:exit", "xf": CellGrid.door_transform(far[0], far[1])}
		grid.pins["edge_" + k] = "nothing"


## A piece's place: `turns` quarter turns clockwise about the cell's middle.
static func cell_xf(c: Vector3i, turns: int) -> Transform3D:
	var mid: Vector3 = CellGrid.cell_centre(c)
	var b := Basis(Vector3.UP, -turns * PI * 0.5)
	return Transform3D(b, Vector3(mid.x, c.y * BAY, mid.z)) * Transform3D(Basis(), Vector3(-BAY * 0.5, 0.0, BAY * 0.5))


## The plain piece for a set of open sides, and its quarter turns.
static func piece(open: Array) -> Array:
	for shape: String in SHAPES:
		var base: Array = SHAPES[shape]
		if base.size() != open.size():
			continue
		for turns: int in 4:
			var ok: bool = true
			for s: int in base:
				if not open.has(TURN[(TURN.find(s) + turns) % 4]):
					ok = false
					break
			if ok:
				return [shape, turns]
	return ["end", 0]


func _props(far: Array) -> void:
	var grid: CellGrid = _grid
	var stops: Array[Vector3] = []
	var stop_from: Array[Vector3] = []
	var keys: Array = _links.keys()
	keys.sort()
	for c: Vector3i in keys:
		var kind: String = _kind[c]
		var name: String = "os_%s" % CellGrid.cell_name(c)
		var open: Array = _links[c]
		match kind:
			"cave":
				var yaw: int = 0
				if open.has(CellGrid.Side.E) or open.has(CellGrid.Side.W):
					yaw = 1
				grid.props[name] = {"slot": "os:cave", "shell": true, "xf": cell_xf(c, yaw)}
			"throat":
				# Its cave end (piece S) faces the entry, or the far door's way.
				var s: int = _turn[c]
				var turns: int = (TURN.find(s) - TURN.find(CellGrid.Side.S) + 4) % 4
				grid.props[name] = {"slot": "os:throat", "shell": true, "xf": cell_xf(c, turns)}
			"bier":
				var t: int = (TURN.find(open[0]) - TURN.find(CellGrid.Side.S) + 4) % 4
				grid.props[name] = {"slot": "os:bier", "shell": true, "xf": cell_xf(c, t)}
				stops.append(CellGrid.cell_centre(c))
				stop_from.append(CellGrid.cell_centre(_parent[c]))
			"passage":
				var p: Array = piece(open)
				grid.props[name] = {"slot": "os:" + p[0], "shell": true, "xf": cell_xf(c, p[1])}
				if p[0] == "end":
					stops.append(CellGrid.cell_centre(c))
					stop_from.append(CellGrid.cell_centre(_parent[c]))
	var mid: Vector3 = CellGrid.cell_centre(_chamber)
	var at := Vector3(mid.x, 0.0, mid.z)
	grid.props["os_chamber"] = {"slot": "os:chamber", "shell": true, "xf": Transform3D(Basis(), at)}
	for side: int in [CellGrid.Side.E, CellGrid.Side.W]:
		var mouth: Vector3i = _chamber + Vector3i(1 if side == CellGrid.Side.E else -1, 0, 0)
		if _parent.get(CellGrid.neighbour(mouth, side), Vector3i.MAX) != mouth:
			var b := Basis() if side == CellGrid.Side.E else Basis(Vector3.UP, PI)
			grid.props["os_plug_%d" % side] = {"slot": "os:plug", "shell": true, "xf": Transform3D(b, at)}
	grid.props["os_shrine"] = {"slot": "os:shrine_old" if forgotten else "os:shrine", "xf": Transform3D(Basis(), at)}
	grid.props["os_vigil"] = {"slot": "os:vigil", "xf": Transform3D(Basis(), at + Vector3(0.0, 0.006, -3.95))}
	var dust: Array[Vector3] = _light(at)
	var route: Array[Vector3] = [Vector3(BAY * 0.5, 0.0, -0.6)]
	if not far.is_empty():
		var chain: Array[Vector3i] = [far[0]]
		while _parent[chain[0]] != chain[0]:
			chain.push_front(_parent[chain[0]])
		for c: Vector3i in chain:
			route.append(CellGrid.cell_centre(c))
		var exit_at: Vector3 = CellGrid.door_transform(far[0], far[1]).origin
		var back: Vector3 = (CellGrid.cell_centre(far[0]) - exit_at).normalized() * 0.6
		route.append(Vector3(exit_at.x, 0.0, exit_at.z) + Vector3(back.x, 0.0, back.z))
	var hosts: Array[Transform3D] = _dress(at)
	# Last: it looks for the candles when it is placed, and a streamed room places in order.
	grid.props["os_life"] = {"slot": "os:life", "xf": Transform3D()}
	# Every dead end, from the entry: the route test walks them all.
	var arms: Array = []
	for i: int in stops.size():
		var cell: Vector3i = _cell_at(stop_from[i])
		var way: Array[Vector3] = []
		if _kind[_cell_at(stops[i])] != "bier":     # a bier fills its cell: stop before it
			way.append(stops[i])
		while true:
			way.push_front(CellGrid.cell_centre(cell))
			if _parent[cell] == cell:
				break
			cell = _parent[cell]
		arms.append(way)
	grid.meta = {"ossuary": true, "arms": arms, "route": route, "chamber": at, "stops": stops, "stop_from": stop_from, "dust": dust, "candles": _candle_spots.duplicate(), "cells": _count(), "far_door": not far.is_empty(),
		"hosts": hosts, "near_only": ["prop_os_item_", GOODS_REACH], "sights": _sights.duplicate(), "forgotten": forgotten}


## Fills every bay: the long niche and the four small ones, tended near the entry
## and greyer past the chamber. It has its own dice, so nothing it picks moves
## the layout or the lights. Returns the biers' bodies, the future possession
## hosts (the brief's Q2).
func _dress(at: Vector3) -> Array[Transform3D]:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([_seed, "ossuary_goods"])
	var hosts: Array[Transform3D] = []
	var books: Dictionary = _lore_cells(rng)
	var keys: Array = _links.keys()
	keys.sort()
	for c: Vector3i in keys:
		var kind: String = _kind[c]
		if kind != "passage" and kind != "bier":
			continue
		var past: float = FORGOTTEN_AGE if forgotten else float(_depth(c) - _depth(_chamber)) / float(TENDED)
		var shape: String = "bier"
		var xf: Transform3D
		if kind == "bier":
			xf = cell_xf(c, (TURN.find(_links[c][0]) - TURN.find(CellGrid.Side.S) + 4) % 4)
			var slot: String = "os:item_bier" if _lit_biers.has(c) else "os:item_bier_old"
			if past >= RAGS_FROM:
				slot = "os:item_bier_rag"
			_grid.props["os_item_bier_%s" % CellGrid.cell_name(c)] = {"slot": slot, "xf": xf}
			hosts.append(xf * Transform3D(Basis(), BIER_BODY))
			if _lit_biers.has(c):
				_offer("bier_" + CellGrid.cell_name(c), xf * Transform3D(Basis(Vector3.UP, rng.randf_range(-0.4, 0.4)), Vector3(2.0, 0.0, -0.76)), rng)
		else:
			var p: Array = piece(_links[c])
			shape = p[0]
			xf = cell_xf(c, p[1])
		var n: int = 0
		for wall: Array in WALLS[shape]:
			for b: Transform3D in _bays(wall[0], wall[1], wall[2]):
				var book: String = books.get(c, "")
				if _bay("%s_%d" % [CellGrid.cell_name(c), n], xf * b, past, rng, book, shape == "straight"):
					books.erase(c)
				n += 1
	_dress_chamber(at, rng)
	return hosts


## Which cells hold a lore book: the deepest dead ends first, then the deepest
## passages, so they reward going on. Returns cell -> book.
func _lore_cells(rng: RandomNumberGenerator) -> Dictionary:
	var pool: Array = Array(LORE).duplicate()
	for i: int in range(pool.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var s: String = pool[i]
		pool[i] = pool[j]
		pool[j] = s
	var cells: Array = []
	for c: Vector3i in _links:
		if (_kind[c] == "passage" or _kind[c] == "bier") and _depth(c) > _depth(_chamber):
			cells.append(c)
	cells.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
		var ea: bool = (_links[a] as Array).size() == 1
		var eb: bool = (_links[b] as Array).size() == 1
		if ea != eb:
			return ea
		return _depth(a) > _depth(b) or (_depth(a) == _depth(b) and a < b))
	var out: Dictionary = {}
	for i: int in mini(LORE_COUNT, cells.size()):
		if not WALLS[piece(_links[cells[i]])[0] if _kind[cells[i]] == "passage" else "bier"].is_empty():
			out[cells[i]] = pool[i]
	return out


## Something a mourner left, on the floor at `xf`.
func _offer(tag: String, xf: Transform3D, rng: RandomNumberGenerator) -> void:
	if forgotten:
		return
	var kind: String = ["cloth", "bowl", "flowers", "tray"][rng.randi_range(0, 3)]
	_grid.props["os_item_offer_%s" % tag] = {"slot": "os:item_offer_" + kind, "xf": xf}
	_sight("offer_" + kind, xf * Vector3(1.0, 1.1, 0.5), xf.origin)


func _sight(what: String, eye: Vector3, look: Vector3) -> void:
	if not _sights.has(what):
		_sights[what] = [eye, look]


## The chamber's bays: the walls of its arms and its four slanting sides, less
## any arm a plug closes (the plug has a bay of its own).
func _dress_chamber(at: Vector3, rng: RandomNumberGenerator) -> void:
	var a: float = 3.6
	var o: float = a * tan(PI / 8.0)
	var e: float = 6.0
	var h: float = 1.1
	var walls: Array = [[Vector2(h, -e), Vector2(h, -a)], [Vector2(o, -a), Vector2(a, -o)], [Vector2(a, o), Vector2(o, a)],
		[Vector2(-o, a), Vector2(-a, o)], [Vector2(-a, -o), Vector2(-o, -a)], [Vector2(-h, -a), Vector2(-h, -e)]]
	var east: Vector3i = _chamber + Vector3i(1, 0, 0)
	var west: Vector3i = _chamber + Vector3i(-1, 0, 0)
	if _parent.get(CellGrid.neighbour(east, CellGrid.Side.E), Vector3i.MAX) == east:
		walls.append_array([[Vector2(a, -h), Vector2(e, -h)], [Vector2(e, h), Vector2(a, h)]])
	else:
		walls.append([Vector2(a, -h), Vector2(a, h)])
	if _parent.get(CellGrid.neighbour(west, CellGrid.Side.W), Vector3i.MAX) == west:
		walls.append_array([[Vector2(-a, h), Vector2(-e, h)], [Vector2(-e, -h), Vector2(-a, -h)]])
	else:
		walls.append([Vector2(-a, h), Vector2(-a, -h)])
	var n: int = 0
	var frame := Transform3D(Basis(), at)
	for wall: Array in walls:
		for b: Transform3D in _bays(wall[0], wall[1], 1):
			_bay("chamber_%d" % n, frame * b, FORGOTTEN_AGE if forgotten else 0.0, rng, "", false)
			n += 1
	# What the mourners left before the shrine, one of each.
	var i: int = 0
	for spot: Vector3 in [Vector3(0.95, 0.0, -3.05), Vector3(-0.9, 0.0, -3.1), Vector3(-0.42, 0.0, -3.28), Vector3(0.42, 0.0, -3.3)]:
		if not forgotten:
			var kind: String = ["tray", "bowl", "flowers", "cloth"][i]
			var xf := Transform3D(Basis(Vector3.UP, rng.randf_range(-0.5, 0.5)), at + spot)
			_grid.props["os_item_offer_shrine_%s" % kind] = {"slot": "os:item_offer_" + kind, "xf": xf}
		i += 1


## Each bay along a wall (as Wall.build): X out into the room, Y (-Z here) back
## along the wall, so a bay's start is its far end from `from`.
static func _bays(from: Vector2, to: Vector2, bays: int) -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	var length: float = from.distance_to(to)
	var t: Vector2 = (to - from) / length
	var nrm := Vector2(-t.y, t.x)
	for i: int in bays:
		var p: Vector2 = from + t * ((length - 2.0 * bays) * 0.5 + 2.0 * i + 2.0)
		out.append(Transform3D(Basis(Vector3.UP, atan2(nrm.y, nrm.x)), Vector3(p.x, 0.0, -p.y)))
	return out


## One bay's contents. `past`: how far past the chamber, in tended stretches.
## `book`: a lore book to lay in one of its small niches. `solid`: rock may break
## through here. Returns whether the book went in.
func _bay(tag: String, xf: Transform3D, past: float, rng: RandomNumberGenerator, book: String, solid: bool) -> bool:
	var old: bool = rng.randf() < clampf(past * 1.15 - 0.1, 0.0, 1.0)
	# A candle's niche stays clear of everything but the candle.
	var flame := Vector3.INF
	for spot: Vector3 in _candle_spots:
		var local: Vector3 = xf.affine_inverse() * spot
		if absf(local.x) < 1.0 and -local.z >= 0.0 and -local.z <= 2.0:
			flame = local
	var plain: bool = flame == Vector3.INF and book == ""
	if plain and solid and past >= FALLS_FROM and rng.randf() < minf(past * 0.16, 0.24):
		var rock: String = "low" if rng.randf() < 0.5 else "high"
		_grid.props["os_item_rock_%s" % tag] = {"slot": "os:item_rock_" + rock, "xf": xf}
		_sight("rock_" + rock, xf * Vector3(1.9, 1.4, -1.0), xf * Vector3(0.0, 0.8, -1.0))
		return false
	if plain and past >= 0.8 and rng.randf() < minf((past - 0.6) * 0.5, 0.45):
		_grid.props["os_item_web_%s" % tag] = {"slot": "os:item_web_" + ("b" if rng.randf() < 0.4 else "a"), "xf": xf}
	var long: String = _pick_long(old, past, rng)
	if long != "" and not (flame != Vector3.INF and flame.y < 0.5):
		_grid.props["os_item_long_%s" % tag] = {"slot": "os:item_long_" + long, "xf": xf}
		if long.begins_with("slump") or long.begins_with("rag"):
			_sight(long.left(4), xf * Vector3(1.7, 1.25, -0.4), xf * Vector3(-0.1, 0.25, -1.1))
	if old and past >= FALLS_FROM and not long.begins_with("slump") and rng.randf() < minf((past - 0.4) * 0.5, 0.45):
		var spill: String = "a" if rng.randf() < 0.5 else "b"
		_grid.props["os_item_spill_%s" % tag] = {"slot": "os:item_spill_" + spill, "xf": xf}
		_sight("spill_" + spill, xf * Vector3(1.7, 1.25, -0.4), xf * Vector3(0.1, 0.15, -1.1))
	if not old and past < 0.4 and rng.randf() < 0.22:
		_offer(tag, xf * Transform3D(Basis(Vector3.UP, rng.randf_range(-0.5, 0.5)), Vector3(0.26, 0.0, -rng.randf_range(0.4, 1.6))), rng)
	if plain:
		var kind: String = ["old_a", "old_b", "old_c"][rng.randi_range(0, 2)] if old else ["a", "b", "c"][rng.randi_range(0, 2)]
		_grid.props["os_item_upper_%s" % tag] = {"slot": "os:item_upper_" + kind, "xf": xf}
		return false
	if flame != Vector3.INF and flame.y < 0.5 and book == "":
		var kind: String = "old_a" if old else "a"
		_grid.props["os_item_upper_%s" % tag] = {"slot": "os:item_upper_" + kind, "xf": xf}
		return false
	# A niche to itself: a lore book on the lower row, or the candle's. The
	# others get single pieces.
	var keep: int = rng.randi_range(0, 1)
	var placed: bool = false
	var i: int = -1
	for s: Vector2 in SMALL:
		i += 1
		var at: Transform3D = xf * Transform3D(Basis(), Vector3(0.0, s.y, -s.x))
		if flame != Vector3.INF and absf(s.x + flame.z) < 0.3 and absf(s.y - flame.y) < 0.2:
			continue
		if book != "" and not placed and i >= keep and i < 2:
			_grid.props["os_lore_%s" % book] = {"slot": "os:lore_" + book, "xf": at}
			_sight("lore", at * Vector3(1.3, 0.35, 0.0), at * Vector3(-0.3, 0.05, 0.0))
			placed = true
			continue
		if not old or rng.randf() < 0.6:
			var nook: String = ["row", "stack", "bundle"][rng.randi_range(0, 2)]
			_grid.props["os_item_nook_%s_%d" % [tag, i]] = {"slot": "os:item_nook_" + nook, "xf": at}
	return placed


func _pick_long(old: bool, past: float, rng: RandomNumberGenerator) -> String:
	var roll: float = rng.randf()
	var head: String = "a" if rng.randf() < 0.5 else "b"
	if old:
		if past >= RAGS_FROM and roll < 0.4:
			return "rag_" + head
		if past >= FALLS_FROM and roll < 0.5:
			return "slump_" + head
		if roll < 0.5:
			return "old_" + head
		if roll < 0.65:
			return "books_old"
		return "bundles_old" if roll < 0.8 else ""
	if roll < 0.5:
		return "body_" + head
	if roll < 0.7:
		return "books"
	return "bundles" if roll < 0.9 else ""


## A cell's steps from the entry along the tree.
func _depth(c: Vector3i) -> int:
	var n: int = 0
	while _parent[c] != c:
		c = _parent[c]
		n += 1
	return n


## Every light has a source you can see. Single candles in the tended stretch,
## thinning to none past TENDED cells beyond the chamber; never two cells running,
## none by the doors. A hung lantern at most every LANTERN_EVERY cells and in dead
## ends there; past it, and all through the Forgotten state, glowcaps at the foot
## of the walls. Returns where dust falls: more of it deeper in.
func _light(at: Vector3) -> Array[Vector3]:
	var grid: CellGrid = _grid
	var keys: Array = _links.keys()
	keys.sort_custom(func(a: Vector3i, b: Vector3i) -> bool: return _depth(a) < _depth(b) or (_depth(a) == _depth(b) and a < b))
	var end: int = _depth(_chamber) + TENDED
	var lit: Dictionary = {}
	var dark: Dictionary = {}       # cell -> cells since the last light along the tree
	var dust: Array[Vector3] = []
	for c: Vector3i in keys:
		var kind: String = _kind[c]
		if kind != "passage" and kind != "bier":
			continue
		var d: int = _depth(c)
		var open: Array = _links[c]
		var near: bool = lit.has(_parent[c])
		var chance: float = clampf(1.0 - float(d - 3) / float(maxi(end - 3, 1)), 0.0, 1.0) * 0.8
		var mid: Vector3 = CellGrid.cell_centre(c)
		if not forgotten and kind == "passage" and d >= 3 and not near and piece(open)[0] == "straight" and _rng.randf() < chance:
			var xf: Transform3D = _niche_xf(c, piece(open)[1])
			grid.props["os_candle_%s" % CellGrid.cell_name(c)] = {"slot": "os:candle", "xf": xf}
			_candle_spots.append(xf.origin)
			lit[c] = true
			dark[c] = 0
		elif kind == "bier" and d <= end and not forgotten:
			_lit_biers[c] = true        # its candle is the bier's own (os_item_bier)
			dark[c] = 0
		elif d <= end and not forgotten and (int(dark.get(_parent[c], 0)) + 1 >= LANTERN_EVERY or open.size() == 1):
			grid.props["os_lantern_%s" % CellGrid.cell_name(c)] = {"slot": "os:lantern", "xf": Transform3D(Basis(), Vector3(mid.x, 0.0, mid.z))}
			dark[c] = 0
		elif (d > end or forgotten) and open.size() < 4 and (int(dark.get(_parent[c], 0)) + 1 >= GLOW_EVERY or open.size() == 1):
			_fungus(c, open, mid)
			dark[c] = 0
		else:
			dark[c] = int(dark.get(_parent[c], 0)) + 1
		if forgotten:
			_wet(c, mid)
		if _rng.randf() < (0.2 if d <= end and not forgotten else 0.45) and dust.size() < MAX_DUST:
			dust.append(Vector3(mid.x + _rng.randf_range(-0.6, 0.6), 0.0, mid.z + _rng.randf_range(-0.6, 0.6)))
	if forgotten:
		for i: int in 4:
			var off := Vector3(2.2 if i % 2 == 0 else -2.2, 0.0, 2.2 if i < 2 else -2.2)
			grid.props["os_fog_chamber_%d" % i] = {"slot": "os:fog", "xf": Transform3D(Basis(), Vector3(at.x, 0.0, at.z) + off)}
		for c: Vector3i in _turn:
			var m: Vector3 = CellGrid.cell_centre(c)
			grid.props["os_fog_%s" % CellGrid.cell_name(c)] = {"slot": "os:fog", "xf": Transform3D(Basis(), Vector3(m.x, 0.0, m.z))}
	dust.append(at + Vector3(0.7, 0.0, -2.6))
	return dust


## The Forgotten state's floor: fog in every cell, and now and then a puddle
## off the walked line with water dripping into it from the vault.
func _wet(c: Vector3i, mid: Vector3) -> void:
	var name: String = CellGrid.cell_name(c)
	_grid.props["os_fog_%s" % name] = {"slot": "os:fog", "xf": Transform3D(Basis(), Vector3(mid.x, 0.0, mid.z))}
	if _puddles < MAX_PUDDLES and _rng.randf() < 0.4:
		_puddles += 1
		var off := Vector3(_rng.randf_range(-0.6, 0.6), 0.0, _rng.randf_range(-0.6, 0.6))
		_grid.props["os_puddle_%s" % name] = {"slot": "os:puddle_a" if _rng.randf() < 0.5 else "os:puddle_b",
			"xf": Transform3D(Basis(Vector3.UP, _rng.randf_range(0.0, TAU)), Vector3(mid.x, 0.0, mid.z) + off)}


## A clump of glowcaps at the foot of a wall, sometimes with a few more over the
## way. Beside a bier they grow towards the way in, clear of the plinth.
func _fungus(c: Vector3i, open: Array, mid: Vector3) -> void:
	var walls: Array = TURN.filter(func(s: int) -> bool: return not open.has(s))
	var bier: bool = _kind[c] == "bier"
	var way: Vector3 = _side_dir(c, open[0])
	if bier:
		walls = walls.filter(func(s: int) -> bool: return absf(_side_dir(c, s).dot(way)) < 0.5)
	var reach: float = 1.4 if piece(open)[0] == "straight" else 0.7
	for i: int in mini(walls.size(), 2):
		if i == 1 and _rng.randf() < 0.5:
			break
		var side: int = walls[_rng.randi_range(0, walls.size() - 1)]
		walls.erase(side)
		var out: Vector3 = _side_dir(c, side)
		var along: Vector3 = way * 1.3 if bier else Vector3(-out.z, 0.0, out.x) * _rng.randf_range(-reach, reach)
		_grid.props["os_glow%s_%s" % ["" if i == 0 else "_small", CellGrid.cell_name(c)]] = {"slot": "os:glow" if i == 0 else "os:glow_small",
			"xf": Transform3D(Basis(Vector3.UP, _rng.randf_range(0.0, TAU)), Vector3(mid.x, 0.0, mid.z) + out * 0.76 + along)}


func _side_dir(c: Vector3i, side: int) -> Vector3:
	return (CellGrid.cell_centre(CellGrid.neighbour(c, side)) - CellGrid.cell_centre(c)).normalized()


## A straight cell's candle: one niche of the eight small or four long ones,
## its passage side on the prop's +X.
func _niche_xf(c: Vector3i, turns: int) -> Transform3D:
	var east: bool = _rng.randf() < 0.5
	var bay: float = 2.0 * _rng.randi_range(0, 1)
	var row: int = _rng.randi_range(0, 2)
	var y: float = bay + 1.0
	var z: float = 0.22
	if row > 0:
		y = bay + (0.525 if _rng.randf() < 0.5 else 1.475)
		z = 0.98 if row == 1 else 1.5
	var x: float = 3.1 + 0.3 if east else 0.9 - 0.3
	var b := Basis(Vector3.UP, PI) if east else Basis()
	return cell_xf(c, turns) * Transform3D(b, Vector3(x, z, -y))


func wear_lanes(_grid2: CellGrid, _seed_value: int) -> void:
	pass


func _cell_at(p: Vector3) -> Vector3i:
	return Vector3i(floori(p.x / BAY), floori(p.y / BAY), floori(-p.z / BAY))

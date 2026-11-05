@tool
class_name BridgeHallGrammar
extends RoomGrammar
## R21 Bridge Hall (design/room-atlas.html; docs/environment/phase-12-approval.md):
## a tall cavern hall crossed by one straight bridge from a door in one end
## wall to a door in the other, over a drop into mist. Its long walls are
## carved into storeys of facades; its end walls and roof are rough rock. At
## each end a dark cave passage, three cells with a bend, leads from the
## area's door to the hall (your addition: the light changes slowly between
## rooms, and the bend hides each room's lamps from the other).
##
## The grid, room frame (entry door on the S side of cell (0, 0, 0), growing
## toward +z cells):
##   entry passage  A (0,0,0) -> B (0,0,1) -> C (d,0,1), d = +-1 (the bend)
##   hall           WIDTH columns x `bays` rows from z 2, storeys -BELOW..ABOVE-1;
##                  the bridge on column bc (1 or 3), the deck at storey 0
##   far passage    C' (bx,r,zf) -> B' (bx+e,r,zf) -> A' (bx+e,r,zf+1), door N,
##                  on storey r: the bridge is level (0), or climbs (1) or
##                  drops (-1) a storey on a flight in its far half (Q3)
##   older bridge   scenery in the other column (4 - bc), level, a storey over
##                  the deck (under it when the bridge climbs), ending at a
##                  sealed carved door at each end (Q4)
## Every cell builds nothing of its own ("none" sides, no floor or ceiling):
## the pieces are FREE shell props (slots "bh:*", gen/rules/r21_bridge_hall.tres),
## as the light-well's cone. The bridge is built when the room is
## (bh:bridge, BridgeHallBridge) from grid.meta["bridge"], with the span's
## pieces (ChasmGrammar.build_room).

const WIDTH: int = 5
const BELOW: int = 2
const ABOVE: int = 3
const BAY: float = CellGrid.BAY

## Hall length in bays, tried longest first that fits (Q2: 6-8).
@export var bays_min: int = 6:
	set(value):
		bays_min = value
		emit_changed()
@export var bays_max: int = 8:
	set(value):
		bays_max = value
		emit_changed()


func layout(grid: CellGrid, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, "bridge_hall"])
	var want: int = rng.randi_range(mini(bays_min, bays_max), maxi(bays_min, bays_max))
	var bends: Array = [1, -1] if rng.randf() < 0.5 else [-1, 1]
	var far_bends: Array = [1, -1] if rng.randf() < 0.5 else [-1, 1]
	# Level, climbing or dropping, a third each (Q3); the others if it won't fit.
	var rises: Array = [0, 1, -1]
	var r0: int = rng.randi_range(0, 2)
	rises = rises.slice(r0) + rises.slice(0, r0)
	var lengths: Array[int] = [want]
	for n: int in range(maxi(bays_min, bays_max), mini(bays_min, bays_max) - 1, -1):
		if n != want:
			lengths.append(n)
	for n: int in lengths:
		for r: int in rises:
			for d: int in bends:
				for e: int in far_bends:
					var plan: Dictionary = _plan(n, d, e, r)
					if _fits(grid, plan):
						_lay(grid, plan, seed_value)
						return
	if not grid.quiet:
		push_warning("BridgeHallGrammar: no room for a bridge hall")


## The cells of a hall `n` bays long, its entry bend toward d (+-1 in x) and
## its far bend toward e. The bridge's column is where the entry passage meets
## the hall; it stands in hall column 1 or 3, the side away from the bend, so
## the hall's width lies past the passage. The far passage is on storey r.
func _plan(n: int, d: int, e: int, r: int = 0) -> Dictionary:
	var bx: int = d                          # the bridge's x (C's)
	var bc: int = 1 if d < 0 else 3          # its hall column
	var x0: int = bx - bc
	var zf: int = 2 + n                      # the far passage's first row
	return {"bays": n, "d": d, "e": e, "bx": bx, "bc": bc, "x0": x0, "zf": zf, "rise": r,
		"old": -1 if r == 1 else 1,
		"entry": [Vector3i(0, 0, 0), Vector3i(0, 0, 1), Vector3i(bx, 0, 1)],
		"far": [Vector3i(bx, r, zf), Vector3i(bx + e, r, zf), Vector3i(bx + e, r, zf + 1)]}


func _hall_cells(p: Dictionary) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	for y: int in range(-BELOW, ABOVE):
		for z: int in range(2, 2 + int(p["bays"])):
			for x: int in range(int(p["x0"]), int(p["x0"]) + WIDTH):
				out.append(Vector3i(x, y, z))
	return out


func _fits(grid: CellGrid, p: Dictionary) -> bool:
	for c: Vector3i in _hall_cells(p) + (p["entry"] as Array) + (p["far"] as Array):
		if not grid.is_free(c):
			return false
	var a2: Vector3i = p["far"][2]
	return grid.is_free(CellGrid.neighbour(a2, CellGrid.Side.N))


func _lay(grid: CellGrid, p: Dictionary, seed_value: int) -> void:
	var n: int = p["bays"]
	var x0: int = p["x0"]
	var bx: int = p["bx"]
	var bc: int = p["bc"]
	var zf: int = p["zf"]
	var passage: Array = (p["entry"] as Array) + (p["far"] as Array)
	var i: int = 0
	for c: Vector3i in _hall_cells(p) + passage:
		grid.add_cell(c, "floor", Vector3i(0, 0, 1), i)
		i += 1
		var cell: Dictionary = grid.cells[c]
		cell["floor_slot"] = ""
		cell["ceiling_slot"] = ""
		cell["gables"] = false
		cell["no_floor"] = true
	# Open between the hall's cells and along each passage; the passages open
	# into the hall's bridge cells at the ends; the rest solid, building nothing.
	var links: Array = []          # [cell, side] pairs open between room cells
	var hall: Dictionary = {}
	for c: Vector3i in _hall_cells(p):
		hall[c] = true
	for c: Vector3i in hall:
		for side: int in CellGrid.ALL_SIDES:
			if hall.has(CellGrid.neighbour(c, side)):
				links.append([c, side])
	var chain: Array = (p["entry"] as Array) + [Vector3i(bx, 0, 2)]
	var rise: int = p["rise"]
	var old: int = p["old"]
	var far_chain: Array = [Vector3i(bx, rise, 2 + n - 1)] + (p["far"] as Array)
	for ch: Array in [chain, far_chain]:
		for k: int in ch.size() - 1:
			links.append([ch[k], _side_to(ch[k], ch[k + 1])])
	for c: Vector3i in grid.cells:
		for side: int in CellGrid.ALL_SIDES:
			grid.set_edge(c, side, CellGrid.Mark.SOLID, false, "none")
	for l: Array in links:
		grid.set_edge(l[0], l[1], CellGrid.Mark.OPEN)
	# The hall's storeys are one space: a column of links joins them (as the
	# light-well's), so the grid's check reaches every cell.
	for y: int in range(-BELOW, ABOVE):
		var to: Array = []
		for dy: int in [-1, 1]:
			if y + dy >= -BELOW and y + dy < ABOVE:
				to.append(Vector3i(bx, y + dy, 2))
		grid.cells[Vector3i(bx, y, 2)]["links"] = to
	# The doors: the entry, and the far one (always: a bridge to nowhere is
	# pointless).
	grid.set_edge(Vector3i.ZERO, CellGrid.Side.S, CellGrid.Mark.DOOR, not grid.root)
	var a2: Vector3i = p["far"][2]
	grid.set_edge(a2, CellGrid.Side.N, CellGrid.Mark.DOOR)
	var k2: String = CellGrid.key(a2, CellGrid.Side.N)
	grid.props["exit_" + k2] = {"slot": "stub:exit", "xf": CellGrid.door_transform(a2, CellGrid.Side.N)}
	grid.pins["edge_" + k2] = "nothing"
	# The passages: straight pieces and bends, each turned to its openings.
	for ch: Array in [chain, far_chain]:
		var cells: Array = ch.slice(1, ch.size()) if ch == far_chain else ch.slice(0, ch.size() - 1)
		for c: Vector3i in cells:
			var opens: Array[int] = []
			var at: int = ch.find(c)
			if at > 0:
				opens.append(_side_to(c, ch[at - 1]))
			elif c == Vector3i.ZERO:
				opens.append(CellGrid.Side.S)
			if at + 1 < ch.size():
				opens.append(_side_to(c, ch[at + 1]))
			else:
				opens.append(CellGrid.Side.N)       # the far door
			_cave_piece(grid, c, opens)
	# The hall's shell: end walls with the mouths, long walls by storey, the
	# roof and the pit.
	var first := Vector3i(x0, 0, 2)
	var last := Vector3i(x0 + WIDTH - 1, 0, 2 + n - 1)
	_piece(grid, "end_s", "bh:end_c%d_lv_%s" % [bc, OLD_NAME[old]], CellGrid.edge_transform(first, CellGrid.Side.S))
	_piece(grid, "end_n", "bh:end_c%d_%s_%s" % [WIDTH - 1 - bc, STOREY_NAME[rise], OLD_NAME[old]],
		CellGrid.edge_transform(last, CellGrid.Side.N))
	_piece(grid, "mouth_s", "bh:mouth", CellGrid.edge_transform(Vector3i(bx, 0, 2), CellGrid.Side.S))
	_piece(grid, "mouth_n", "bh:mouth", CellGrid.edge_transform(Vector3i(bx, rise, 2 + n - 1), CellGrid.Side.N))
	# The older bridge's sealed doors, carved into the end walls' outcrops
	# (tools/kit_add_r21.py: the panel's back flush with the wall).
	var ox: int = x0 + WIDTH - 1 - bc
	var old_doors: Array[Transform3D] = [_face(Vector3i(ox, old, 1), CellGrid.Side.N, DOOR_IN),
		_face(Vector3i(ox, old, 2 + n), CellGrid.Side.S, DOOR_IN)]
	_piece(grid, "old_door_s", "bh:old_door", old_doors[0])
	_piece(grid, "old_door_n", "bh:old_door", old_doors[1])
	# The long walls: carved rock under the deck and at the top; on the deck's
	# storey and the one over it, houses: runs of 2-3 bays, both storeys, one
	# material each (walked step 1: a material per bay read as patchwork),
	# some windows lit. A lit window may get a warm light in front of it.
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, "bridge_hall_fronts"])
	var window_spots: Array[Vector3] = []
	var lit_windows: Array[Transform3D] = []      # their faces: the hanging gardens (step 3)
	for side: String in ["w", "e"]:
		var z: int = 2
		while z < 2 + n:
			var run: int = rng.randi_range(2, 3)
			var mat: String = _pick_material(rng)
			for zz: int in range(z, mini(z + run, 2 + n)):
				for y: int in range(-BELOW, ABOVE):
					var slot: String = "bh:wall_low" if y < -1 else ("bh:wall_under" if y == -1 else "bh:wall_top")
					var lit: bool = false
					if y >= 0 and y < ABOVE - 1:
						lit = rng.randf() < LIT_CHANCE
						slot = "bh:front_%s_%s" % [mat, "lit" if lit else "dark"]
					var xf: Transform3D = _face(Vector3i(x0 - 1, y, zz), CellGrid.Side.E) if side == "w" \
						else _face(Vector3i(x0 + WIDTH, y, zz), CellGrid.Side.W)
					_piece(grid, "%s_%d_%d" % [side, y, zz], slot, xf)
					if lit:
						window_spots.append(xf * Vector3(2.0, 2.2, 1.0))
						lit_windows.append(xf)
			z += run
	var window_lights: Array[Vector3] = []
	for si: int in window_spots.size():
		var j: int = rng.randi_range(si, window_spots.size() - 1)
		var t: Vector3 = window_spots[si]
		window_spots[si] = window_spots[j]
		window_spots[j] = t
	for q: Vector3 in window_spots:
		if window_lights.size() >= WINDOW_LIGHTS_MAX:
			break
		if window_lights.all(func(o: Vector3) -> bool: return o.distance_to(q) >= WINDOW_LIGHT_SPACING):
			window_lights.append(q)
	# A little glowing moss at a foot of each passage cell's wall (dim, never black).
	for c: Vector3i in passage:
		var q: Vector3 = CellGrid.cell_centre(c)
		var turn: float = rng.randf_range(0.0, TAU)
		_piece(grid, "moss_%s" % CellGrid.cell_name(c), "bh:moss",
			Transform3D(Basis(Vector3.UP, turn), Vector3(q.x, c.y * BAY, q.z) + Vector3(sin(turn), 0.0, cos(turn)) * 1.3))
	# Things to pick in each passage's cell by the hall (step 3), found on the
	# rock by a ray (BridgeHallBridge): mushrooms in its dark closed corner;
	# wild herbs by the hall opening, on the closed side, where the bridge-end
	# lamp reaches (walked step 3: herbs in pots by the lamps looked wrong).
	# The entry's (bx, 0, 1) opens toward its bend (-d) and the hall (N, -z);
	# the far's (bx, rise, zf) toward the hall (S, +z) and its bend (+e).
	var d: int = p["d"]
	var e: int = p["e"]
	var forage: Array = [
		{"kind": "mushroom", "cell": Vector3i(bx, 0, 1), "shift": Vector3.ZERO, "dir": Vector3(d, 0, 1)},
		{"kind": "herb", "cell": Vector3i(bx, 0, 1), "shift": Vector3(0, 0, -FORAGE_SHIFT), "dir": Vector3(d, 0, 0)},
		{"kind": "mushroom", "cell": Vector3i(bx, rise, zf), "shift": Vector3.ZERO, "dir": Vector3(-e, 0, -1)},
		{"kind": "herb", "cell": Vector3i(bx, rise, zf), "shift": Vector3(0, 0, FORAGE_SHIFT), "dir": Vector3(-e, 0, 0)}]
	var corner := Transform3D(Basis(), Vector3(x0 * BAY, 0.0, -2 * BAY))
	_piece(grid, "roof", "bh:roof_%d" % n, corner)
	_piece(grid, "pit", "bh:pit_%d" % n, corner)
	# The bridge: its run from the entry mouth, -Z along the room.
	var start := Transform3D(Basis(), Vector3(bx * BAY + BAY * 0.5, 0.0, -2 * BAY))
	_piece(grid, "bridge", "bh:bridge", start)
	var route: Array[Vector3] = []
	for c: Vector3i in chain + far_chain:
		var q: Vector3 = CellGrid.cell_centre(c)
		route.append(Vector3(q.x, q.y, q.z))
	route.push_front(Vector3(BAY * 0.5, 0.0, 0.6))
	var exit_at: Vector3 = CellGrid.door_transform(a2, CellGrid.Side.N).origin
	route.append(Vector3(exit_at.x, exit_at.y, exit_at.z + 0.6))
	grid.meta = {"bridge_hall": true, "bays": n, "x0": x0, "bridge_x": bx, "bridge_column": bc,
		"bridge": {"bays": n, "start": start, "seed": seed_value, "rise": rise},
		"old_bridge": {"start": Transform3D(Basis(), Vector3(ox * BAY + BAY * 0.5, old * BAY, -2 * BAY)), "storey": old, "doors": old_doors}, "window_lights": window_lights,
		"lit_windows": lit_windows, "forage": forage,
		"entry_cells": p["entry"], "far_cells": p["far"], "route": route,
		"hall": AABB(Vector3(x0 * BAY, -BELOW * BAY, -(2 + n) * BAY), Vector3(WIDTH * BAY, (BELOW + ABOVE) * BAY, n * BAY))}
	grid.wear.clear()


## House fronts: the Persian kit's materials, carved rock most often.
const MATERIALS: Dictionary = {"rock": 3.0, "plaster": 2.0, "brick": 1.0, "tile": 1.0, "banai": 1.0}
const LIT_CHANCE: float = 0.4
## At most this many warm lights at lit windows, this far apart (light budget).
const WINDOW_LIGHTS_MAX: int = 6
const WINDOW_LIGHT_SPACING: float = 8.0
## How far toward the hall from a passage cell's middle its herbs grow.
const FORAGE_SHIFT: float = 1.3


static func _pick_material(rng: RandomNumberGenerator) -> String:
	var total: float = 0.0
	for k: String in MATERIALS:
		total += float(MATERIALS[k])
	var r: float = rng.randf() * total
	for k: String in MATERIALS:
		r -= float(MATERIALS[k])
		if r <= 0.0:
			return k
	return "rock"


## The side of cell a that faces its neighbour b.
static func _side_to(a: Vector3i, b: Vector3i) -> int:
	for side: int in CellGrid.ALL_SIDES:
		if CellGrid.neighbour(a, side) == b:
			return side
	return -1


## A Persian face piece (tools/kit_add_persian.py: the face at its Y 0, the
## building behind it, toward the module's -Z) on the hall's long wall, facing
## into the hall: the edge of the cell outside the wall, `side` toward the
## hall, brought FACE_IN in so the building behind the face (a window's 1.4 m
## recess) stays within the hall's own cells.
const FACE_IN: float = 1.5
## The older bridge's carved doors (persian_carved_door_dark): the panel runs
## 1.8 m behind its face, so it stands that far in, its back on the end wall.
const DOOR_IN: float = 1.8
## End wall names (tools/kit_add_r21.py): the mouth's storey, and whether the
## older bridge's door is over the deck or under it.
const STOREY_NAME: Dictionary = {-1: "dn", 0: "lv", 1: "up"}
const OLD_NAME: Dictionary = {1: "hi", -1: "lo"}
static func _face(outside: Vector3i, side: int, inset: float = FACE_IN) -> Transform3D:
	var xf: Transform3D = CellGrid.edge_transform(outside, side)
	xf.origin += xf.basis.z * inset
	return xf


## Straight (open S and N) or bend (open S and E) cave piece, turned about
## the cell's middle so its openings are `opens`.
func _cave_piece(grid: CellGrid, c: Vector3i, opens: Array[int]) -> void:
	# A turn of +90 degrees about UP takes S to E, E to N, N to W, W to S.
	const NEXT: Dictionary = {CellGrid.Side.S: CellGrid.Side.E, CellGrid.Side.E: CellGrid.Side.N,
		CellGrid.Side.N: CellGrid.Side.W, CellGrid.Side.W: CellGrid.Side.S}
	var want: Dictionary = {}
	for s: int in opens:
		want[s] = true
	for kind: String in ["straight", "bend"]:
		var base: Array = [CellGrid.Side.S, CellGrid.Side.N] if kind == "straight" else [CellGrid.Side.S, CellGrid.Side.E]
		for turn: int in 4:
			var got: Dictionary = {}
			for s: int in base:
				var t: int = s
				for _k: int in turn:
					t = NEXT[t]
				got[t] = true
			if got == want:
				var mid: Vector3 = CellGrid.cell_centre(c)
				mid.y = c.y * BAY
				var xf := Transform3D(Basis(Vector3.UP, PI * 0.5 * turn), mid) * Transform3D(Basis(), Vector3(-BAY * 0.5, 0.0, BAY * 0.5))
				_piece(grid, "cave_%s" % CellGrid.cell_name(c), "bh:cave_" + kind, xf)
				return
	push_warning("BridgeHallGrammar: no cave piece opens %s" % [opens])


func _piece(grid: CellGrid, key: String, slot: String, xf: Transform3D) -> void:
	grid.props["bh_" + key] = {"slot": slot, "xf": xf, "shell": true}


func wear_lanes(_grid: CellGrid, _seed_value: int) -> void:
	pass

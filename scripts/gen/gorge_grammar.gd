@tool
class_name GorgeGrammar
extends Resource
## The gorge rebuilt from kit pieces (phase-6-design.md 5.7.2, phase 6 step 1).
## What vista.gd built by code, laid out in the kit_gorge pieces from the same
## numbers, for a bake to an editable scene.
##
## A bank is a stack of tiers. Each tier is a notched rectangle of whole bays
## (vista.gd's tower_outline), turned and offset a little from the one below
## as today, on its own 4 m grid, and 2 or 3 storeys tall (today 8.3-11.7 m).
## On every face toward the gorge (vista.gd's facade rule): a storey of wall
## and a facade bay per bay and storey, piers where faces turn; on its top a
## deck, and over the gorge-facing faces an overhanging deck edge (a crowned
## edge on the top tier); lamps in clusters; figures, cypress, pavilions and
## banners on the occupied tiers. Output: placements, each {"scene", "xf"}
## or {"light": position, "color", "energy", "range"}, in the gorge's frame.

const MOD: String = "res://kit/modules/"
const CAVERN = preload("res://scripts/cavern.gd")
const BAY: float = 4.0
## Every bank starts at the mist floor (vista.gd).
const BASE_Y: float = -176.0
## Facade module mix (vista.gd slice 7), as fractions of bays.
const FACADE_DOORWAY: float = .12
const FACADE_WINDOW: float = .22
const FACADE_BALCONY: float = .08
const FACADE_PANEL: float = .14
const FACADE_LADDER: float = .35
## Above UPPER_FROM, this share of a tier's upper storeys are plain stone wall
## (no bay): walked, bay upon tiled bay up there read as too busy.
const PLAIN_UPPER: float = .35
const UPPER_FROM: float = -40.0
## Lamp clusters (vista_light.gd): a lamp burns where this noise is high.
const LAMP_CLUSTER_FREQUENCY: float = .035
const LAMP_CLUSTER_CUTOFF: float = .05
## Weathering (vista.gd slice 8), per deck edge piece.
const EDGE_MOSSY: float = .35
const EDGE_STREAKED: float = .8
const CROWN_BROKEN: float = .12
const CROWN_WORN: float = .4
const PIER_STREAKED: float = .65
## Near the overlook, stacks are candle-lit and bays carry lamps (vista_light.gd).
const EYE: Vector3 = Vector3(-1, 4, -27.5)
const NEAR_REACH: float = 110.0

const STONES: Array[String] = ["gorge_wall_4m", "gorge_wall_4m_aged", "gorge_wall_4m_clean"]
const CYPRESS: Array[String] = ["gorge_cypress_5", "gorge_cypress_6", "gorge_cypress_8"]

var _noise: FastNoiseLite


func _init() -> void:
	_noise = FastNoiseLite.new()
	_noise.seed = 4417
	_noise.frequency = LAMP_CLUSTER_FREQUENCY


## One bank of tiers, as vista.gd's bank(): centre (x, z), radii, top height,
## seed. The tiers' shape and turn follow the same random sequence as today.
func bank(center: Vector2, rx: float, rz: float, top: float, seed_value: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var local := RandomNumberGenerator.new()
	local.seed = seed_value * 8329
	var top_q: float = BASE_Y + BAY * roundf((top - BASE_Y) / BAY)
	var bottom: float = BASE_Y
	var level: int = 0
	var tiers: Array[Dictionary] = []
	while bottom < top_q - .05:
		var raw: float = local.randf_range(8.3, 11.7)
		var storeys: int = mini(2 if raw < 10.0 else 3, roundi((top_q - bottom) / BAY))
		var t: float = (bottom + 176.0) / (top + 176.0)
		var sx: float = rx * (1.09 - .22 * t + .15 * sin(level * 1.71 + seed_value))
		var sz: float = rz * (1.02 - .16 * t + .12 * cos(level * 1.29 + seed_value))
		var offset := Vector2(sin(level * .87 + seed_value) * rx * .10, cos(level * .72 + seed_value) * rz * .09)
		var turn: float = .13 * sin(level * .69 + seed_value)
		var crowned: bool = bottom + storeys * BAY >= top_q - .05
		var stone: String = STONES[int(_hash01(Vector3(center.x, bottom, center.y)) * 3.0)]
		tiers.append(_tier_shape(center + offset, sx * .88, sz * .88, turn, bottom, storeys))
		tiers[-1].merge({"occupied": level % 3 == seed_value % 3, "crowned": crowned, "level": level, "stone": stone})
		bottom += storeys * BAY
		level += 1
	for i: int in tiers.size():
		_tier(out, tiers[i], tiers[i + 1] if i + 1 < tiers.size() else {}, seed_value)
	_towers(out, tiers[-1], top_q, seed_value, local)
	# A few roof pavilions break the silhouette; bank 4 also has a rotunda,
	# generated at the bake (vista.gd rotunda).
	if seed_value in [1, 4, 7]:
		out.append(_piece("dressing/gorge_pavilion_8", Transform3D(Basis(), Vector3(center.x, top_q + .2, center.y))))
		if seed_value == 4:
			out.append({"rotunda": Vector3(center.x - 4, top_q, center.y + 5), "radius": 5.4, "height": 9.5})
	return out


## The whole gorge from its layout: every bank with its towers, the sanctum's
## tiers, the aqueducts (and the waterfalls through their arches).
func gorge(layout: GorgeLayout) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for b: PackedFloat32Array in layout.banks:
		out.append_array(bank(Vector2(b[0], b[1]), b[2], b[3], b[4], int(b[5])))
	out.append_array(sanctum(layout.sanctum))
	for a: PackedFloat32Array in layout.aqueducts:
		var falls: Array[int] = []
		for k: int in range(6, a.size()):
			falls.append(int(a[k]))
		out.append_array(aqueduct(Vector3(a[0], a[1], a[2]), Vector3(a[3], a[4], a[5]), falls))
	return out


# --- Persian towers (vista.gd bank_towers, persian_tower) ------------------------------

## One or two square towers on a crowned bank's top, toward the gorge, unless
## they'd stand in the sightline to a rock gate.
func _towers(out: Array[Dictionary], top_tier: Dictionary, top: float, seed_value: int, local: RandomNumberGenerator) -> void:
	var center: Vector2 = top_tier["c"]
	var sx: float = top_tier["hx"]
	var sz: float = top_tier["hz"]
	var inward: float = -signf(center.x)
	var count: int = 1 + seed_value % 2
	for k: int in count:
		var z: float = center.y + (0.0 if count == 1 else (k * 2 - 1) * sz * .42)
		var half: float = local.randf_range(5.5, 7.5)
		var c := Vector2(center.x + inward * (sx - half - 2.5), z)
		if _blocks_gate_sightline(c, half + 4.0):
			continue
		_tower(out, c, half, top, top + local.randf_range(10, 19))


## A square tower of 3 or 4 bays: walls of clean stone, faience on the top
## storey and every third, a pair of windows a storey on each face, a faience
## band every two storeys, a crown
## with merlons, a carpet down its face toward the gorge, a lamp over it.
func _tower(out: Array[Dictionary], c: Vector2, half: float, bottom: float, top: float) -> void:
	var w: int = clampi(roundi(2.0 * half / BAY), 3, 4)
	var storeys: int = maxi(2, roundi((top - bottom) / BAY))
	var cells: Dictionary = footprint(w, w, 0)
	var frame := Transform3D(Basis(), Vector3(c.x - w * BAY * .5, bottom, c.y + w * BAY * .5))
	var windows: Array[int] = [0, 2]
	if w == 4:
		windows = [1, 2]
	for cell: Vector2i in cells:
		for side: int in CellGrid.ALL_SIDES:
			if cells.has(_beside(cell, side)):
				continue
			var along: int = _bay_index(cell, side, w)
			for s: int in storeys:
				var xf: Transform3D = frame * CellGrid.edge_transform(Vector3i(cell.x, s, cell.y), side)
				# Faience on the top storey and every third; clean stone between (all
				# faience, the towers read as too busy up close).
				var tiled: bool = s == storeys - 1 or s % 3 == 2
				out.append(_piece("walls/" + ("gorge_tower_window" if windows.has(along) else "gorge_tower_wall") + ("" if tiled else "_stone"), xf))
				if s % 2 == 1 and s < storeys - 1:
					out.append(_piece("walls/gorge_tower_band", xf))
			var top_xf: Transform3D = frame * CellGrid.edge_transform(Vector3i(cell.x, storeys, cell.y), side)
			out.append(_piece("walls/gorge_tower_crown", top_xf))
			if not cells.has(_before(cell, side)):
				out.append(_piece("walls/gorge_tower_crown_corner", top_xf))
		out.append(_piece("walls/gorge_deck", frame * CellGrid.cell_transform(Vector3i(cell.x, storeys, cell.y), Vector3i(0, 0, 1))))
	# The carpet and the lamp face the gorge (vista.gd: out = -sign(x)).
	var out_dir: float = -signf(c.x)
	var face_x: float = c.x + out_dir * (w * BAY * .5 + .12)
	var yaw: float = PI * .5 if out_dir > 0 else -PI * .5
	var hang := Transform3D(Basis(Vector3.UP, yaw), Vector3(face_x, bottom + storeys * BAY - 1.0, c.y))
	out.append(_piece("dressing/gorge_carpet", hang))
	out.append(_piece("dressing/gorge_lamp_big", Transform3D(Basis(), Vector3(c.x + out_dir * (w * BAY * .5 + 1.0), bottom + storeys * BAY + 1.2, c.y))))


## Which bay along its face (0 from the face's start) an edge is, for the
## towers' window pairs.
static func _bay_index(cell: Vector2i, side: int, w: int) -> int:
	match side:
		CellGrid.Side.S:
			return cell.x
		CellGrid.Side.N:
			return w - 1 - cell.x
		CellGrid.Side.W:
			return w - 1 - cell.y
	return cell.y


static func _blocks_gate_sightline(c: Vector2, margin: float) -> bool:
	var eye := Vector2(EYE.x, EYE.z)
	for gate: Array in CAVERN.PORTALS:
		var sill: Vector3 = CAVERN.portal_sill(gate)
		var target := Vector2(sill.x, sill.z)
		var t: float = clampf((c - eye).dot(target - eye) / eye.distance_squared_to(target), 0.0, 1.0)
		if c.distance_to(eye.lerp(target, t)) < margin:
			return true
	return false


# --- the sanctum (vista.gd sanctum) ----------------------------------------------------

## The sanctum's nine terraced tiers of gorge_pier stone, narrowing as they
## rise (24 storeys, today 94.5 m); their rotunda, portal, columns, hangings
## and light are generated at the bake.
func sanctum(p: Vector3) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var heights: Array[int] = [3, 3, 3, 3, 2, 3, 2, 3, 2]
	var bottom: float = p.y - 44.0
	for i: int in heights.size():
		var tier: Dictionary = _tier_shape(Vector2(p.x, p.z - i * .7), 38.0 - i * 2.8, 26.0 - i * 1.9, 0.0, bottom, heights[i])
		tier.merge({"occupied": i % 2 == 0, "crowned": false, "level": i, "stone": "gorge_wall_4m_faience"})
		var next: Dictionary = {}
		if i + 1 < heights.size():
			next = _tier_shape(Vector2(p.x, p.z - (i + 1) * .7), 38.0 - (i + 1) * 2.8, 26.0 - (i + 1) * 1.9, 0.0, bottom + heights[i] * BAY, heights[i + 1])
		_tier(out, tier, next, 2)
		bottom += heights[i] * BAY
	return out


# --- aqueducts (vista.gd bridge) -------------------------------------------------------

## A two-tier aqueduct from a to b: 12 m bays in a frame turned along it, each
## at its own height under the sloping deck (so the piers stay vertical), the
## upper arcade, a faience course and the taller lower arcade, a plain pier
## under every other bay down into the mist; the deck in sloped 12 m pieces
## with lamps and readers; a landing at each end (no pavilion: it clipped the
## banks' balustrades beside it); waterfalls
## through the `falls` bays' upper arches.
func aqueduct(a: Vector3, b: Vector3, falls: Array[int]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var flat := Vector3(b.x - a.x, 0, b.z - a.z)
	var run: float = flat.length()
	flat = flat.normalized()
	var across: Vector3 = flat.cross(Vector3.UP)
	var level := Basis(flat, Vector3.UP, across)
	var span: float = 12.0
	var bays: int = maxi(3, roundi(run / span))
	var lead: float = (run - bays * span) * .5
	var along: Vector3 = (b - a).normalized()
	var deck_basis := Basis(along, across.cross(along).normalized(), across)
	for i: int in bays:
		var s: float = lead + i * span
		var start := Vector3(a.x, 0, a.z) + flat * s
		var mid: Vector3 = a.lerp(b, (s + span * .5) / run)
		var top: float = mid.y - 1.0
		var bay := Transform3D(level, Vector3(start.x, top, start.z))
		out.append(_piece("walls/aqueduct_upper_12m", bay))
		out.append(_piece("walls/aqueduct_lower_12m", bay.translated(Vector3(0, -12.0, 0))))
		if i % 2 == 0:
			var foot: float = top - 32.6
			while foot > -177.0:
				out.append(_piece("walls/aqueduct_pier_20m", Transform3D(level, Vector3(start.x, foot, start.z))))
				foot -= 20.0
		var deck_at: Vector3 = a.lerp(b, s / run)
		out.append(_piece("walls/aqueduct_deck_12m", Transform3D(deck_basis, deck_at)))
		for x: float in [1.2, 8.4]:
			for side: float in [-2.0, 2.0]:
				out.append(_piece("dressing/gorge_lamp", Transform3D(deck_basis, deck_at + along * x + deck_basis.y * 1.38 + across * side)))
		for k: int in 2:
			var p: Vector3 = a.lerp(b, (s + 3.0 + k * 6.0) / run) + Vector3.UP * .45 + across * (.6 if (i * 2 + k) % 2 == 0 else -.6)
			out.append(_piece("dressing/gorge_figure", Transform3D(level, p)))
		if falls.has(i):
			var spring: float = top - 1.4 - (span * .5 - 1.2)
			out.append({"waterfall": Vector3(mid.x, spring, mid.z), "size": Vector2(span * .5, spring + 90.0)})
	for point: Vector3 in [a, b]:
		out.append(_piece("dressing/aqueduct_landing", Transform3D(Basis(), point)))
	return out


## The cells of a tier's notched rectangle: (i, j) for i < w, j < d, less an
## n x n square at each corner.
func footprint(w: int, d: int, n: int) -> Dictionary:
	var cells: Dictionary = {}
	for i: int in w:
		for j: int in d:
			if (i < n or i >= w - n) and (j < n or j >= d - n):
				continue
			cells[Vector2i(i, j)] = true
	return cells


## A tier's notched rectangle of whole bays, on its own grid: {frame, cells,
## storeys, bottom}.
func _tier_shape(c: Vector2, hx: float, hz: float, turn: float, bottom: float, storeys: int) -> Dictionary:
	var w: int = maxi(3, roundi(2.0 * hx / BAY))
	var d: int = maxi(3, roundi(2.0 * hz / BAY))
	var n: int = clampi(roundi(minf(hx, hz) * .18 / BAY), 1, mini(w, d) / 2 - 1) if mini(w, d) >= 4 else 0
	# Cell (i, j) spans x 4i..4i+4 and z -4j-4..-4j (CellGrid); centred on c,
	# turned as vista.gd turns a Vector2 (about +Y by -turn).
	var frame := Transform3D(Basis(Vector3.UP, -turn), Vector3(c.x, bottom, c.y)) * Transform3D(Basis(), Vector3(-w * BAY * .5, 0, d * BAY * .5))
	return {"frame": frame, "cells": footprint(w, d, n), "storeys": storeys, "bottom": bottom, "c": c, "hx": hx, "hz": hz}


## One tier's pieces; `above` is the tier on it ({} for the top), whose
## footprint hides the deck under it.
func _tier(out: Array[Dictionary], tier: Dictionary, above: Dictionary, seed_value: int) -> void:
	var frame: Transform3D = tier["frame"]
	var cells: Dictionary = tier["cells"]
	var storeys: int = tier["storeys"]
	var bottom: float = tier["bottom"]
	var crowned: bool = tier["crowned"]
	var stone: String = tier["stone"]
	var style: int = seed_value + int(tier["level"])
	var run: int = 0
	for cell: Vector2i in cells:
		for side: int in CellGrid.ALL_SIDES:
			if cells.has(_beside(cell, side)):
				continue
			var top_xf: Transform3D = frame * CellGrid.edge_transform(Vector3i(cell.x, storeys, cell.y), side)
			if not _faces_gorge(top_xf):
				continue
			var first: bool = not _exposed(cells, _before(cell, side), side)
			var last: bool = not _exposed(cells, _after(cell, side), side)
			for s: int in storeys:
				var xf: Transform3D = frame * CellGrid.edge_transform(Vector3i(cell.x, s, cell.y), side)
				out.append(_piece("walls/" + stone, xf))
				var plain: bool = s > 0 and xf.origin.y > UPPER_FROM and _hash01(xf.origin * 1.7 + Vector3(0, 0, 11)) < PLAIN_UPPER
				if not plain:
					_bay(out, xf, s == 0)
				if first:
					out.append(_piece("walls/" + _pier(xf), xf))
				if last:
					out.append(_piece("walls/" + _pier(xf), xf * Transform3D(Basis(), Vector3(BAY, 0, 0))))
			out.append(_piece("walls/" + _edge(top_xf, crowned), top_xf))
			_edge_lamps(out, top_xf, crowned)
			if first and not cells.has(_before(cell, side)):     # a convex corner: the overhang's square
				out.append(_piece("walls/" + ("gorge_crown_corner" if crowned else "gorge_deck_corner"), top_xf))
			# A convex corner at the run's end whose face round it isn't built
			# (it faces away from the gorge): the square there too, turned, or the
			# overhang's end stood open.
			var round_xf: Transform3D = top_xf * Transform3D(Basis(Vector3.UP, PI * .5), Vector3(BAY, 0, 0))
			if last and not cells.has(_after(cell, side)) and not _faces_gorge(round_xf):
				out.append(_piece("walls/" + ("gorge_crown_corner" if crowned else "gorge_deck_corner"), round_xf))
			if first:
				if tier["occupied"]:
					_dressing(out, cells, cell, side, frame, storeys, run, style)
				# Some faces' own light (vista.gd facades: every ninth face, above the mist).
				if bottom > -110.0 and (run + style) % 9 == 0:
					var face: Transform3D = frame * CellGrid.edge_transform(Vector3i(cell.x, 0, cell.y), side)
					var at: Vector3 = face * Vector3(_run_length(cells, cell, side) * BAY * .5, storeys * BAY * .7, 3.5)
					out.append({"light": at, "color": Color("ffc790"), "energy": 4.0, "range": 18.0})
				run += 1
		if not _covered(above, frame * Vector3(cell.x * BAY + BAY * .5, storeys * BAY, -cell.y * BAY - BAY * .5)):
			out.append(_piece("walls/gorge_deck", frame * CellGrid.cell_transform(Vector3i(cell.x, storeys, cell.y), Vector3i(0, 0, 1))))


## Terrace life on an occupied tier, once per face run (vista.gd ledge_edges):
## a figure, a pair of cypresses, every other run a pavilion, some a banner.
func _dressing(out: Array[Dictionary], cells: Dictionary, cell: Vector2i, side: int, frame: Transform3D, storeys: int,
		run: int, style: int) -> void:
	var xf: Transform3D = frame * CellGrid.edge_transform(Vector3i(cell.x, storeys, cell.y), side)
	var mid: float = _run_length(cells, cell, side) * BAY * .5
	if run % 3 == style % 3:
		out.append(_piece("dressing/gorge_figure", xf * Transform3D(Basis(), Vector3(mid, .15, 1.3))))
		for k: int in [-1, 1]:
			var tree: String = CYPRESS[(style + run + k + 2) % CYPRESS.size()]
			out.append(_piece("dressing/" + tree, xf * Transform3D(Basis(), Vector3(mid + k * 2.6, .15, .6))))
		if run % 2 == 0:
			out.append(_piece("dressing/gorge_pavilion_4", xf * Transform3D(Basis(), Vector3(mid, .2, -2.2))))     # posts 3.6 m apart: the front pair clear of the edge's balustrade (at 1.8 they stood in it)
	if style % 4 == run % 4:
		out.append(_piece("dressing/gorge_banner_%d" % (style % 3), xf * Transform3D(Basis(), Vector3(mid, -.5, 2.5))))


## Lamps on a deck edge where the cluster noise burns (vista.gd lamp()): every
## third baluster (2 m apart, so at x = 1 or 3 by the edge's place).
func _edge_lamps(out: Array[Dictionary], xf: Transform3D, crowned: bool) -> void:
	for x: float in [1.0, 3.0]:
		var p: Vector3 = xf * Vector3(x, 1.0 if crowned else 1.37, 2.2)
		if int(roundf(p.x + p.z * 3.0)) % 3 != 0:
			continue
		if _noise.get_noise_3dv(p) < LAMP_CLUSTER_CUTOFF:
			continue
		out.append(_piece("dressing/gorge_lamp", Transform3D(xf.basis, p)))


## A facade bay and its lamp: a doorway's always burns (vista.gd
## arch_bay_module), a bay near the overlook may have one where the cluster
## noise burns.
func _bay(out: Array[Dictionary], xf: Transform3D, ground_row: bool) -> void:
	var kind: String = _facade(xf, ground_row)
	out.append(_piece("walls/" + kind, xf))
	if kind == "gorge_bay_doorway":
		out.append(_piece("dressing/gorge_lamp", xf * Transform3D(Basis(), Vector3(3.9, 3.2, .42))))
	elif kind != "gorge_bay_panel" and xf.origin.distance_to(EYE) < NEAR_REACH:
		var p: Vector3 = xf * Vector3(3.62, 2.76, .42)
		if _noise.get_noise_3dv(p) >= LAMP_CLUSTER_CUTOFF:
			out.append(_piece("dressing/gorge_lamp", Transform3D(xf.basis, p)))


## Where a deck point is under the tier above (it then isn't built).
func _covered(above: Dictionary, p: Vector3) -> bool:
	if above.is_empty():
		return false
	var local: Vector3 = (above["frame"] as Transform3D).affine_inverse() * p
	return (above["cells"] as Dictionary).has(Vector2i(floori(local.x / BAY), floori(-local.z / BAY)))


func _facade(xf: Transform3D, ground_row: bool) -> String:
	var pick: float = _hash01(xf.origin)
	if ground_row and pick < FACADE_DOORWAY:
		return "gorge_bay_doorway"
	if pick < FACADE_DOORWAY + FACADE_WINDOW:
		return "gorge_bay_window"
	if pick < FACADE_DOORWAY + FACADE_WINDOW + FACADE_BALCONY:
		return "gorge_bay_balcony"
	if pick < 1.0 - FACADE_PANEL:
		var near: String = "_near" if xf.origin.distance_to(EYE) < NEAR_REACH else ""
		return ("gorge_bay_stack_ladder" if fposmod(pick * 7.0, 1.0) < FACADE_LADDER else "gorge_bay_stack") + near
	return "gorge_bay_panel"


func _pier(xf: Transform3D) -> String:
	return "gorge_pier_streaked" if _hash01(xf.origin * 3.1) < PIER_STREAKED else "gorge_pier"


func _edge(xf: Transform3D, crowned: bool) -> String:
	var h: float = _hash01(xf.origin * 1.7)
	if crowned:
		return "gorge_crown_edge_broken" if h < CROWN_BROKEN else ("gorge_crown_edge_worn" if h < CROWN_WORN else "gorge_crown_edge")
	return "gorge_deck_edge_mossy" if h < EDGE_MOSSY else ("gorge_deck_edge_streaked" if h < EDGE_STREAKED else "gorge_deck_edge")


## vista.gd's rule: a face is dressed if it faces the gorge's axis or the overlook.
func _faces_gorge(xf: Transform3D) -> bool:
	var normal: Vector3 = xf.basis.z.normalized()
	var centre: Vector3 = xf * Vector3(BAY * .5, 0, 0)
	return normal.dot(Vector3(-centre.x, 0, 0).normalized()) >= .05 or normal.z >= .35


## Bays in the face run starting at `cell`.
func _run_length(cells: Dictionary, cell: Vector2i, side: int) -> int:
	var length: int = 1
	var at: Vector2i = cell
	while _exposed(cells, _after(at, side), side):
		at = _after(at, side)
		length += 1
	return length


func _exposed(cells: Dictionary, cell: Vector2i, side: int) -> bool:
	return cells.has(cell) and not cells.has(_beside(cell, side))


## The cell across `side` (CellGrid: N is +j).
static func _beside(cell: Vector2i, side: int) -> Vector2i:
	var n: Vector3i = CellGrid.neighbour(Vector3i(cell.x, 0, cell.y), side)
	return Vector2i(n.x, n.z)


## The cells before and after a face's edge along it (CellGrid.edge_transform:
## S runs +x, N -x, W toward -j, E toward +j).
static func _before(cell: Vector2i, side: int) -> Vector2i:
	match side:
		CellGrid.Side.S:
			return cell + Vector2i(-1, 0)
		CellGrid.Side.N:
			return cell + Vector2i(1, 0)
		CellGrid.Side.W:
			return cell + Vector2i(0, 1)
	return cell + Vector2i(0, -1)


static func _after(cell: Vector2i, side: int) -> Vector2i:
	return cell * 2 - _before(cell, side)


func _piece(path: String, xf: Transform3D) -> Dictionary:
	return {"scene": MOD + path + ".tscn", "xf": xf}


static func _hash01(p: Vector3) -> float:
	return fposmod(sin(p.x * 12.9898 + p.y * 78.233 + p.z * 37.719) * 43758.5453, 1.0)

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
## An inner corner's deck edge (gorge_*_edge_inner): the overhang stops where
## the face round the corner's overhang begins (tools/kit_add_gorge.py INNER).
const INNER_EDGE: float = BAY - 2.2     # BAY less DECK_OVER (below)
## A tier's core stands this far behind its faces (a wall body is 0.5 deep),
## in its walls' stone (tools/kit_add_gorge.py wall()).
const CORE_INSET: float = .45
const CORE_STONE: Dictionary = {"gorge_wall_4m": "gorge_stone", "gorge_wall_4m_aged": "gorge_stone_aged", "gorge_wall_4m_clean": "gorge_stone_clean", "gorge_wall_4m_faience": "gorge_pier"}
## Every bank starts at the mist floor (vista.gd).
const BASE_Y: float = -176.0
## Facade module mix (vista.gd slice 7), as fractions of bays.
const FACADE_DOORWAY: float = .12
const FACADE_WINDOW: float = .22
const FACADE_BALCONY: float = .02     # .08 until the second fly-mode walk: "less is more"
const FACADE_PANEL: float = .2        # .14 until then (a calm tiled bay)
const FACADE_LADDER: float = .35
## Above UPPER_FROM, this share of a tier's upper storeys are plain stone wall
## (no bay): walked, bay upon tiled bay up there read as too busy. Since the
## second fly-mode walk a whole storey of a tier at once (a calm band, not
## gaps scattered through it), from lower down.
const PLAIN_UPPER: float = .45
const UPPER_FROM: float = -100.0
## Lamp clusters (vista_light.gd): a lamp burns where this noise is high.
## Walked in fly mode (2026-10-26): at .05 about half the edges burned and the
## fog-lit terraces were lamp-lit too; at .22 the lamps gather in fewer, tighter
## clusters with dark stretches between.
const LAMP_CLUSTER_FREQUENCY: float = .035
const LAMP_CLUSTER_CUTOFF: float = .22
## A face's own warm light, every this many face runs (was 9: too many).
const FACE_LIGHT_EVERY: int = 18
## Weathering (vista.gd slice 8), per deck edge piece.
const EDGE_MOSSY: float = .35
const EDGE_STREAKED: float = .8
const CROWN_BROKEN: float = .12
const CROWN_WORN: float = .4
const PIER_STREAKED: float = .65
## Near the overlook, stacks are candle-lit and bays carry lamps (vista_light.gd).
const EYE: Vector3 = Vector3(-1, 4, -27.5)
const NEAR_REACH: float = 110.0

## Banks built as a Persian hill town (phase-8-design.md 8.3, PersianTown),
## each with its landmarks; the others keep their bays until theirs. At most
## one monument in a view (bank 1, across from bank 2) and three or four
## great falls in all (Q3).
const PERSIAN_BANKS: Dictionary = {
	1: ["monument", "iwan", "fall", "shaft"],
	2: ["iwan", "fall"],
	3: ["iwan", "shaft"],
	4: ["iwan", "fall"],
	5: ["iwan", "shaft"],     # its grand buildings: PersianTown._grand_share
	6: ["iwan", "shaft"],     # no fall fits its sheer faces (three in all)
	7: ["iwan"],
	8: ["iwan", "fall", "shaft"],  # the last bank: monuments and grand buildings
}
## How ornamental a bank is, 0 by the camp to 1 at the furthest (your call,
## phase 8: more gardens, tiles and iwans the further a bank is, building up
## to a last bank of monuments and grand buildings): its centre's distance
## from the Overlook between the nearest's and the furthest's. Banks 1 and 2
## stay as you approved them (0).
const ORNAMENT_FIXED: Dictionary = {1: 0.0, 2: 0.0, SANCTUM: 1.0}
## The sanctum's seed for PersianTown (not a bank: no landmarks of its own).
const SANCTUM: int = 9


static func ornament(layout: GorgeLayout, seed_value: int) -> float:
	if seed_value in ORNAMENT_FIXED:
		return ORNAMENT_FIXED[seed_value]
	var near: float = INF
	var far: float = 0.0
	var mine: float = 0.0
	for b: PackedFloat32Array in layout.banks:
		var d: float = Vector2(b[0] - EYE.x, b[1] - EYE.z).length()
		near = minf(near, d)
		far = maxf(far, d)
		if int(b[5]) == seed_value:
			mine = d
	return clampf((mine - near) / maxf(far - near, 1.0), 0.0, 1.0)
const STONES: Array[String] = ["gorge_wall_4m", "gorge_wall_4m_aged", "gorge_wall_4m_clean"]
const CYPRESS: Array[String] = ["gorge_cypress_5", "gorge_cypress_6", "gorge_cypress_8"]

var _noise: FastNoiseLite
## Each bank's terrace dressing (dressing()), once a session: [layout, seed] -> points.
static var _bank_dressing: Dictionary = {}


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
	var tiers: Array[Dictionary] = bank_tiers(center, rx, rz, top, seed_value, local)
	if seed_value in PERSIAN_BANKS:
		return PersianTown.new(self).bank(tiers, seed_value)
	for i: int in tiers.size():
		_tier(out, tiers[i], tiers[i + 1] if i + 1 < tiers.size() else {}, seed_value, tiers[i - 1] if i > 0 else {})
	var top_q: float = BASE_Y + BAY * roundf((top - BASE_Y) / BAY)
	_towers(out, tiers[-1], top_q, seed_value, local)
	# A few roof pavilions break the silhouette; bank 4 also has a rotunda,
	# generated at the bake (vista.gd rotunda).
	if seed_value in [1, 4, 7]:
		out.append(_piece("dressing/gorge_pavilion_8", Transform3D(Basis(), Vector3(center.x, top_q + .2, center.y))))
		if seed_value == 4:
			out.append({"rotunda": Vector3(center.x - 4, top_q, center.y + 5), "radius": 5.4, "height": 9.5})
	return out


## A bank's tiers (_tier_shape's dictionaries plus occupied, crowned, level and
## stone), bottom to top, drawing from `local` as bank() always has.
func bank_tiers(center: Vector2, rx: float, rz: float, top: float, seed_value: int, local: RandomNumberGenerator) -> Array[Dictionary]:
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
		# A Persian bank's roofs end at its walls: no deck overhang to stand a
		# pier on (your walk, phase 8: link piers half over a terrace's edge).
		if seed_value in PERSIAN_BANKS:
			tiers[-1]["over"] = 0.0
		bottom += storeys * BAY
		level += 1
	return tiers


## Every bank's tiers, for what must keep out of them (the spans, phase 6
## step 3): [{frame, cells, bottom, storeys, ...}].
func keep_out(layout: GorgeLayout) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for b: PackedFloat32Array in layout.banks:
		var local := RandomNumberGenerator.new()
		local.seed = int(b[5]) * 8329
		out.append_array(bank_tiers(Vector2(b[0], b[1]), b[2], b[3], b[4], int(b[5]), local))
	return out


## Where the dressing on the terraces of the banks within `reach` of `near`
## (x/z) stands (figures, cypresses, pavilions, banners, lamps): a pier on a
## terrace keeps clear of them. Vector4(x, y, z, radius).
func dressing(layout: GorgeLayout, near: Vector2, reach: float) -> Array[Vector4]:
	const RADII: Dictionary = {"gorge_pavilion": 3.0, "gorge_cypress": 1.2, "gorge_figure": 1.0, "gorge_banner": 2.5, "gorge_lamp": .6}
	var out: Array[Vector4] = []
	for b: PackedFloat32Array in layout.banks:
		if Vector2(b[0], b[1]).distance_to(near) > reach + maxf(b[2], b[3]) * 1.3:
			continue
		var key: Array = [layout, b[5]]
		if not _bank_dressing.has(key):
			var found: Array[Vector4] = []
			for p: Dictionary in bank(Vector2(b[0], b[1]), b[2], b[3], b[4], int(b[5])):
				var file: String = str(p.get("scene", "")).get_file()
				for k: String in RADII:
					if file.begins_with(k):
						var at: Vector3 = (p["xf"] as Transform3D).origin
						found.append(Vector4(at.x, at.y, at.z, RADII[k]))
						break
			_bank_dressing[key] = found
		out.append_array(_bank_dressing[key])
	return out


## Whether p is inside a tier of `tiers` (keep_out), its walls grown by
## `margin` metres sideways; round its top, its deck's overhang (DECK_OVER
## past its faces, from its fascia under the top to DECK_EDGE_H over it: the
## deck edge's balustrade and lamps).
const DECK_EDGE_H: float = 1.6
const DECK_OVER: float = 2.2          # tools/kit_add_gorge.py OVER
const DECK_FASCIA: float = 1.4
static func solid_at(tiers: Array[Dictionary], p: Vector3, margin: float = 0.0) -> bool:
	for t: Dictionary in tiers:
		var bottom: float = t["bottom"]
		var top: float = bottom + int(t["storeys"]) * BAY
		if p.y < bottom or p.y > top + DECK_EDGE_H:
			continue
		var grow: float = margin + (DECK_OVER if p.y > top - DECK_FASCIA else 0.0)
		if _over(t, p, grow):
			return true
	return false


## The top of the highest tier deck under p (at or below p.y; its overhang
## counts, a tier's "over" or DECK_OVER), or the mist floor.
static func ground_at(tiers: Array[Dictionary], p: Vector3) -> float:
	var t: Dictionary = ground_tier(tiers, p)
	return float(t["bottom"]) + int(t["storeys"]) * BAY if not t.is_empty() else BASE_Y


## The tier whose deck is the highest under p ({} over the mist).
static func ground_tier(tiers: Array[Dictionary], p: Vector3) -> Dictionary:
	var best: Dictionary = {}
	var best_top: float = BASE_Y
	for t: Dictionary in tiers:
		var top: float = float(t["bottom"]) + int(t["storeys"]) * BAY
		if top > p.y + .01 or top <= best_top:
			continue
		if _over(t, p, float(t.get("over", DECK_OVER))):
			best = t
			best_top = top
	return best


## Whether p's x/z is over tier t's cells grown by `grow` metres.
static func _over(t: Dictionary, p: Vector3, grow: float) -> bool:
	# Far from the tier: not over it (a quick test; the inverse frame is kept
	# on the tier the first time, as these run millions of times a plan).
	var c: Vector2 = t["c"]
	var r: float = Vector2(float(t["hx"]), float(t["hz"])).length() + BAY * 2.0 + grow
	if Vector2(p.x - c.x, p.z - c.y).length_squared() > r * r:
		return false
	if not t.has("inv"):
		t["inv"] = (t["frame"] as Transform3D).affine_inverse()
	var l: Vector3 = (t["inv"] as Transform3D) * p
	var cells: Dictionary = t["cells"]
	for dx: float in ([0.0] if grow <= 0.0 else [-grow, 0.0, grow]):
		for dz: float in ([0.0] if grow <= 0.0 else [-grow, 0.0, grow]):
			if cells.has(Vector2i(floori((l.x + dx) / BAY), floori(-(l.z + dz) / BAY))):
				return true
	return false


## The whole gorge from its layout: every bank with its towers, the sanctum's
## tiers, the aqueducts (and the waterfalls through their arches), but those
## a walkable span takes the place of (`layout.walked`, Q9).
func gorge(layout: GorgeLayout) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for b: PackedFloat32Array in layout.banks:
		out.append_array(bank(Vector2(b[0], b[1]), b[2], b[3], b[4], int(b[5])))
	out.append_array(sanctum(layout.sanctum))
	for i: int in layout.aqueducts.size():
		var a: PackedFloat32Array = layout.aqueducts[i]
		if layout.walked.has(i) or layout.removed.has(i):
			continue
		var falls: Array[int] = []
		for k: int in range(6, a.size()):
			falls.append(int(a[k]))
		out.append_array(aqueduct(Vector3(a[0], a[1], a[2]), Vector3(a[3], a[4], a[5]), falls, [not layout.open_ends.has(i * 2), not layout.open_ends.has(i * 2 + 1)]))
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

## The sanctum's tiers: four tall ones (nine short ones until the second
## fly-mode walk: terrace upon terrace, "less is more"), narrowing as they
## rise (94.5 m), each built as two of three storeys on the same footprint
## (the Persian town's fronts and portals are three storeys tall).
func sanctum_tiers(p: Vector3) -> Array[Dictionary]:
	var tiers: Array[Dictionary] = []
	var heights: Array[int] = [6, 6, 6, 6]
	var step := Vector2(2.8, 1.9) * 9.0 / heights.size()
	var bottom: float = p.y - 44.0
	for i: int in heights.size():
		for half: int in 2:
			var storeys: int = heights[i] / 2
			var tier: Dictionary = _tier_shape(Vector2(p.x, p.z - i * .7), 38.0 - i * step.x, 26.0 - i * step.y, 0.0, bottom, storeys)
			tier.merge({"occupied": false, "crowned": i == heights.size() - 1 and half == 1, "level": tiers.size(), "stone": "gorge_wall_4m_faience", "over": 0.0})
			tiers.append(tier)
			bottom += storeys * BAY
	return tiers


## The sanctum in the Persian look at the furthest bank's ornament (your
## walk, 2026-10-27: the old windows and bookshelves, one blue tile wall):
## its rotunda, portal light and hangings are generated at the bake.
func sanctum(p: Vector3) -> Array[Dictionary]:
	return PersianTown.new(self).bank(sanctum_tiers(p), SANCTUM)


# --- aqueducts (vista.gd bridge) -------------------------------------------------------

## How far an aqueduct's gate stands back from the deck's end (its landing
## is 3 m deep: the deck's last metre on it).
const GATE_BACK: float = 2.0

## A two-tier aqueduct from a to b: 12 m bays in a frame turned along it, each
## at its own height under the sloping deck (so the piers stay vertical), the
## upper arcade, a faience course and the taller lower arcade, a plain pier
## under every other bay down into the mist; the deck in sloped 12 m pieces
## with lamps and readers; a gatehouse at each end that `gates` asks for
## (no pavilion: it clipped the banks' balustrades beside it); waterfalls
## through the `falls` bays' upper arches.
func aqueduct(a: Vector3, b: Vector3, falls: Array[int], gates: Array = [true, true]) -> Array[Dictionary]:
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
			# From a trough on the arcade's face (ChasmGrammar.TROUGH; walked:
			# through the arch it fell through the lower arcade's course).
			var face := Transform3D(level, Vector3(start.x, top, start.z) + flat * span * .5 + across * ChasmGrammar.ARCADE_HALF)
			var from: Vector3 = face * ChasmGrammar.FALL_FROM
			out.append({"waterfall": from, "size": Vector2(ChasmGrammar.FALL_WIDTH, from.y + 90.0), "basis": level})
			for stone: Array in ChasmGrammar.TROUGH:
				out.append({"stone": face.translated_local(stone[0]), "size": stone[1]})
	# A gatehouse at each end facing back along the deck, its door a pishtaq
	# (fly-mode walk: the decks ran into the banks' walls), set GATE_BACK back
	# from the end into the bank, so the deck arrives on its landing; none
	# where the deck lands on a terrace (`gates`, GorgeLayout.open_ends).
	for end: Array in [[a, -flat, gates[0]], [b, flat, gates[1]]]:
		if not end[2]:
			continue
		var out_dir: Vector3 = end[1]
		var gate := Basis(out_dir, Vector3.UP, out_dir.cross(Vector3.UP))
		out.append(_piece("dressing/aqueduct_gate", Transform3D(gate, (end[0] as Vector3) + out_dir * GATE_BACK)))
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
## footprint hides the deck under it; `below` the one it stands on ({} for the
## bottom). Walked (phase 6 step 3): where the tier overhangs the one below, a
## soffit closes its underside; a deck goes wherever any of its cell is open
## (by the wall above, a whole cell's skip left a gap); a face whose deck edge
## would run under the tier above has none; and a stack bay with nothing to
## stand on in front of it is books behind a window.
func _tier(out: Array[Dictionary], tier: Dictionary, above: Dictionary, seed_value: int, below: Dictionary = {}) -> void:
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
				var plain: bool = s > 0 and xf.origin.y > UPPER_FROM and _hash01(Vector3(frame.origin.x, xf.origin.y, frame.origin.z) * 1.7 + Vector3(0, 0, 11)) < PLAIN_UPPER
				var floor_out: bool = s == 0 and _covered(below, xf * Vector3(BAY * .5, -.2, 1.5))
				_wall_bay(out, stone, xf, plain, s == 0, floor_out)
				if first:
					out.append(_piece("walls/" + _pier(xf), xf))
				if last:
					out.append(_piece("walls/" + _pier(xf), xf * Transform3D(Basis(), Vector3(BAY, 0, 0))))
			var under: bool = _covered(above, top_xf * Vector3(BAY * .5, .5, 1.1))
			if not under:
				# At an inside corner whose other face has its edge, the two overhangs
				# meet instead of crossing (fly-mode walk): the face ending there stops
				# short (_inner), the face starting there starts its rail DECK_OVER in
				# (_inner_start), a one-bay face between two such corners has no rail
				# (_inner_both).
				var inner_end: bool = last and cells.has(_after(cell, side)) and _inner_face_built(cells, cell, side, frame, storeys, above, true)
				var inner_start: bool = first and cells.has(_before(cell, side)) and _inner_face_built(cells, cell, side, frame, storeys, above, false)
				var edge: String = _edge(top_xf, crowned)
				if inner_end or inner_start:
					edge = ("gorge_crown_edge_inner" if crowned else "gorge_deck_edge_inner") + ("_both" if inner_end and inner_start else ("" if inner_end else "_start"))
				out.append(_piece("walls/" + edge, top_xf))
				_edge_lamps(out, top_xf, crowned, INNER_EDGE if inner_end else BAY, DECK_OVER if inner_start else 0.0)
				if first and not cells.has(_before(cell, side)):     # a convex corner: the overhang's square
					out.append(_piece("walls/" + ("gorge_crown_corner" if crowned else "gorge_deck_corner"), top_xf))
				# A convex corner at the run's end whose face round it isn't built
				# (it faces away from the gorge): the square there too, turned, or the
				# overhang's end stood open.
				var round_xf: Transform3D = top_xf * Transform3D(Basis(Vector3.UP, PI * .5), Vector3(BAY, 0, 0))
				if last and not cells.has(_after(cell, side)) and not _faces_gorge(round_xf):
					out.append(_piece("walls/" + ("gorge_crown_corner" if crowned else "gorge_deck_corner"), round_xf))
			if first:
				if tier["occupied"] and not under:
					_dressing(out, cells, cell, side, frame, storeys, run, style)
				# Some faces' own light (vista.gd facades: every ninth face, above the mist).
				if bottom > -110.0 and (run + style) % FACE_LIGHT_EVERY == 0:
					var face: Transform3D = frame * CellGrid.edge_transform(Vector3i(cell.x, 0, cell.y), side)
					var at: Vector3 = face * Vector3(_run_length(cells, cell, side) * BAY * .5, storeys * BAY * .7, 3.5)
					out.append({"light": at, "color": Color("ffc790"), "energy": 4.0, "range": 18.0})
				run += 1
		var corners: Array[Vector3] = []
		for k: Vector2 in [Vector2(.05, .05), Vector2(3.95, .05), Vector2(.05, 3.95), Vector2(3.95, 3.95)]:
			corners.append(frame * Vector3(cell.x * BAY + k.x, 0, -cell.y * BAY - k.y))
		var open_top: bool = false
		var open_under: bool = false
		for c: Vector3 in corners:
			open_top = open_top or not _covered(above, c + Vector3(0, storeys * BAY, 0))
			open_under = open_under or (not below.is_empty() and not _covered(below, c - Vector3(0, .5, 0)))
		if open_top:
			out.append(_piece("walls/gorge_deck", frame * CellGrid.cell_transform(Vector3i(cell.x, storeys, cell.y), Vector3i(0, 0, 1))))
		if open_under:
			out.append(_piece("walls/gorge_soffit", frame * CellGrid.cell_transform(Vector3i(cell.x, 0, cell.y), Vector3i(0, 0, 1))))
		# The tier's core (fly-mode walk): faces that don't look at the gorge get
		# no wall, so behind the facades the tier stood hollow, slits through it
		# where a run turned away. Plain stone, set back behind the walls (their
		# bodies are CORE_INSET deep) on every open side, up under the deck slab.
		var lo := Vector2(cell.x * BAY + (CORE_INSET if not cells.has(cell + Vector2i(-1, 0)) else 0.0), cell.y * BAY + (CORE_INSET if not cells.has(cell + Vector2i(0, -1)) else 0.0))
		var hi := Vector2((cell.x + 1) * BAY - (CORE_INSET if not cells.has(cell + Vector2i(1, 0)) else 0.0), (cell.y + 1) * BAY - (CORE_INSET if not cells.has(cell + Vector2i(0, 1)) else 0.0))
		var height: float = storeys * BAY - CORE_INSET
		out.append({"stone": frame * Transform3D(Basis(), Vector3((lo.x + hi.x) * .5, height * .5, -(lo.y + hi.y) * .5)),
			"size": Vector3(hi.x - lo.x, height, hi.y - lo.y), "material": CORE_STONE.get(stone, "gorge_stone")})


## Whether the face across the inside corner at the end (`at_end`) or start of
## `cell`'s `side` face (the cell along is there but covered on that side) gets
## its deck edge: it faces the gorge and nothing above covers it.
func _inner_face_built(cells: Dictionary, cell: Vector2i, side: int, frame: Transform3D, storeys: int, above: Dictionary, at_end: bool) -> bool:
	var open: Vector2i = _beside(cell, side)
	var across: Vector2i = _after(open, side) if at_end else _before(open, side)
	if not cells.has(across):
		return false
	for t: int in CellGrid.ALL_SIDES:
		if _beside(across, t) == open:
			var xf: Transform3D = frame * CellGrid.edge_transform(Vector3i(across.x, storeys, across.y), t)
			return _faces_gorge(xf) and not _covered(above, xf * Vector3(BAY * .5, .5, 1.1))
	return false


## Terrace life on an occupied tier, once per face run (vista.gd ledge_edges):
## a figure, a pair of cypresses, every other run a pavilion, some a banner.
func _dressing(out: Array[Dictionary], cells: Dictionary, cell: Vector2i, side: int, frame: Transform3D, storeys: int,
		run: int, style: int) -> void:
	var xf: Transform3D = frame * CellGrid.edge_transform(Vector3i(cell.x, storeys, cell.y), side)
	var mid: float = _run_length(cells, cell, side) * BAY * .5
	if run % 3 == style % 3:
		out.append(_piece("dressing/gorge_figure", xf * Transform3D(Basis(), Vector3(mid, .15, 1.3))))
		# The cypresses stand 2.6 m either side: on a one-bay run that's past its
		# ends, in the next face's rails (fly-mode walk).
		for k: int in ([-1, 1] if _run_length(cells, cell, side) >= 2 else []):
			var tree: String = CYPRESS[(style + run + k + 2) % CYPRESS.size()]
			out.append(_piece("dressing/" + tree, xf * Transform3D(Basis(), Vector3(mid + k * 2.6, .15, .6))))
		if run % 2 == 0:
			out.append(_piece("dressing/gorge_pavilion_4", xf * Transform3D(Basis(), Vector3(mid, .2, -2.2))))     # posts 3.6 m apart: the front pair clear of the edge's balustrade (at 1.8 they stood in it)
	if style % 4 == run % 4:
		out.append(_piece("dressing/gorge_banner_%d" % (style % 3), xf * Transform3D(Basis(), Vector3(mid, -.5, 2.5))))


## Lamps on a deck edge where the cluster noise burns (vista.gd lamp()): every
## third baluster (2 m apart, so at x = 1 or 3 by the edge's place).
func _edge_lamps(out: Array[Dictionary], xf: Transform3D, crowned: bool, length: float = BAY, from: float = 0.0) -> void:
	for x: float in [1.0, 3.0]:
		if x >= length or x <= from:
			continue
		var p: Vector3 = xf * Vector3(x, 1.0 if crowned else 1.37, 2.2)
		if int(roundf(p.x + p.z * 3.0)) % 3 != 0:
			continue
		if _noise.get_noise_3dv(p) < LAMP_CLUSTER_CUTOFF:
			continue
		out.append(_piece("dressing/gorge_lamp", Transform3D(xf.basis, p)))


## A storey's wall and its bay (none if `plain`). Windows, stack windows and
## stacks sit flush in an opening through the wall (`stone`'s _arch or _rect;
## walked in fly mode, standing out from it they read as boxes stuck on), the
## others in front of the plain wall.
func _wall_bay(out: Array[Dictionary], stone: String, xf: Transform3D, plain: bool, ground_row: bool, floor_out: bool) -> void:
	var kind: String = "" if plain else _facade(xf, ground_row, floor_out)
	var opening: String = _opening(kind)
	out.append(_piece("walls/" + stone + opening, xf))
	if not plain:
		_bay(out, xf, kind if opening == "" else kind.trim_suffix("_near") + "_flush" + ("_near" if kind.ends_with("_near") else ""))


## The opening a bay kind sits in: "_arch" (windows), "_rect" (stacks) or "".
static func _opening(kind: String) -> String:
	if kind.begins_with("gorge_bay_window") or kind.begins_with("gorge_bay_stack_window"):
		return "_arch"
	return "_rect" if kind.begins_with("gorge_bay_stack") else ""


## A facade bay (`kind`, a module) and its lamp: a doorway's always burns
## (vista.gd arch_bay_module), a bay near the overlook may have one where the
## cluster noise burns.
func _bay(out: Array[Dictionary], xf: Transform3D, kind: String) -> void:
	out.append(_piece("walls/" + kind, xf))
	if kind == "gorge_bay_doorway":
		out.append(_piece("dressing/gorge_lamp", xf * Transform3D(Basis(), Vector3(3.9, 3.2, .62))))     # clear of the pishtaq's frame (0.45 out)
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


## `floor_out`: something to stand on in front (a stack without it is books
## behind a window).
func _facade(xf: Transform3D, ground_row: bool, floor_out: bool = true) -> String:
	var pick: float = _hash01(xf.origin)
	if ground_row and pick < FACADE_DOORWAY:
		return "gorge_bay_doorway"
	if pick < FACADE_DOORWAY + FACADE_WINDOW:
		return "gorge_bay_window"
	if pick < FACADE_DOORWAY + FACADE_WINDOW + FACADE_BALCONY:
		return "gorge_bay_balcony"
	if pick < 1.0 - FACADE_PANEL:
		var near: String = "_near" if xf.origin.distance_to(EYE) < NEAR_REACH else ""
		if not floor_out:
			return "gorge_bay_stack_window" + near
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

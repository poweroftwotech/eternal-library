class_name PersianTown
extends RefCounted
## A bank of the gorge as a Persian hill town (phase-8-design.md 8.3): the
## same tiers as GorgeGrammar (they drive walk planning, frontage slots and
## keep-out), but what stands on them is composed per building, not per bay.
## Each face run is split into buildings of one to three bays, each a house
## (plaster or lime), a carved front (rock) or, on one run, a monument; a
## house's door opens onto the terrace below it, every terrace gets a stair
## up, roofs have parapets, and the light decides what grows (8.4): green
## under a shaft of light or round a lumen stone, glowing fungi elsewhere.
## Once per bank: the monument (portal, crown, dome, minarets) on the top
## tier, an iwan cut into a tier with its lumen-lit garden on the terrace in
## front, and a great fall from a spillway that steps down terraces into the
## mist, a shaft of light over its first pool.
##
## Lights and nodes the batcher would drop (lumen stones, fungus glow, the
## falls, the shaft) go out as extras the bake builds (tools/bake_gorge.gd).

const P: String = "persian/"
const BAY: float = 4.0
## The network's galleries meet the banks at the frontage slots
## (gen/gorge/frontage.tres): no feature (monument, iwan, fall, shaft) stands
## in front of one (`_near_slot`). Bank 1 used a z line (-95) instead, which
## would have shut half of bank 2 out.
const FRONTAGE: String = "res://gen/gorge/frontage.tres"
## Bank 1 keeps its z line (its layout is the one you walked and approved).
const SLOT_Z: float = -95.0
const SLOT_Z_BANKS: Array[int] = [1]
const LUMEN: Color = Color(1.0, 0.93, 0.78)
const TEAL: Color = Color(0.24, 0.9, 0.8)
const TEAL_SPACING: float = 18.0
## Roof slabs sit this much below the walls' tops, and walls stand at least
## WALL_PROUD in front of the slab's edge: flush, the slab's edge and the
## wall front fought (your report: a flickering band at the top of the houses).
const ROOF_DROP: float = .02
const WALL_PROUD: float = .03
## Soffits hang this much below a tier's floor: level with it, their underside
## and the walls' undersides fought along the foot of every overhanging
## house (your report).
const SOFFIT_DROP: float = .04

var g: GorgeGrammar
var out: Array[Dictionary] = []
var tiers: Array[Dictionary] = []
var runs: Array = []               # per tier: [{cells, side, normal, eye, axis}]
var taken: Dictionary = {}         # "t:x,y:side:storey" -> a feature stands there
var plain: Dictionary = {}         # the same keys: a plain wall (behind a stair)
var doors: Dictionary = {}         # the same keys: a door (a stair's landing before it)
var no_core: Dictionary = {}       # "t:x,y"
var no_edge: Dictionary = {}       # "t:x,y:side"
var zones: Array[Dictionary] = []  # {p, r, kind: "sun" | "gem" | "garden" | "monument"}
var cut: Dictionary = {}           # tier -> {cell: true} cut away round the monument
var bay_off: Dictionary = {}       # "t:x,y:side" -> how far its walls stand out (_bay)
var slots: Array[FrontageSlot] = []     # this bank's frontage slots
var slot_z: bool = false              # this bank uses SLOT_Z instead
var teal_lights: Array[Vector3] = []   # where the fungal beds' lights stand
var ornament: float = 0.0             # 0 by the camp .. 1 at the furthest bank (GorgeGrammar.ornament)
var iwans: Array[Vector3] = []         # where this bank's iwans stand
var stair_feet: Array[Vector3] = []    # each stair flight's middle, on the terrace it stands on
var clearings: Array[Dictionary] = []  # {t, p (its roof's middle), xf (its roof at the face)}
var sanctum: bool = false             # building the sanctum (GorgeGrammar.SANCTUM), not a bank
var others: Array[Dictionary] = []     # the sanctum's tiers, which a bank's features must not face into
var forced: Dictionary = {}            # "t:x,y:side" of a clearing's first bay -> its bays
var reserved: Dictionary = {}          # "t:x,y:side": a clearing's bays (no stair, no iwan)


func _init(grammar: GorgeGrammar) -> void:
	g = grammar


func bank(bank_tiers: Array[Dictionary], seed_value: int) -> Array[Dictionary]:
	tiers = bank_tiers
	for t: Dictionary in tiers:
		runs.append(_runs(t))
	slot_z = seed_value in SLOT_Z_BANKS
	var layout: GorgeLayout = load("res://gen/gorge/gorge_layout.tres")
	ornament = GorgeGrammar.ornament(layout, seed_value)
	sanctum = seed_value == GorgeGrammar.SANCTUM
	if not sanctum:
		others = g.sanctum_tiers(layout.sanctum)
	if ResourceLoader.exists(FRONTAGE):
		for s: FrontageSlot in (load(FRONTAGE) as GorgeFrontage).slots:
			if s.bank == seed_value:
				slots.append(s)
	for p: Vector3 in OPEN_EDGES:
		for t: int in tiers.size():
			if absf(_top(t) - p.y) < 1.0 and g._covered(tiers[t], p):
				_open_edge(p)
	# This bank's landmarks (GorgeGrammar.PERSIAN_BANKS).
	var program: Array = GorgeGrammar.PERSIAN_BANKS.get(seed_value, [])
	if "monument" in program:
		_monument()
	if "iwan" in program:
		# More the further from the camp: one by it, four at the furthest bank.
		for n: int in roundi(1.0 + ornament * 3.0):
			_iwan()
	if not program.is_empty():
		_clearings()     # after the iwans, clear of them (the sanctum keeps its shape)
	if "fall" in program:
		_cascade()
	if "shaft" in program:
		_shaft()
	for i: int in range(1, tiers.size()):
		_stair(i)
	if not slot_z:
		_parks()
	for i: int in tiers.size():
		_tier(i, seed_value)
	for i: int in range(0, tiers.size() - 1):
		_supports(i)
	return out


# ------------------------------------------------------------------ helpers

func _key(t: int, cell: Vector2i, side: int, storey: int = -1) -> String:
	return "%d:%d,%d:%d:%d" % [t, cell.x, cell.y, side, storey]


func _xf(t: int, cell: Vector2i, side: int, storey: int) -> Transform3D:
	return tiers[t]["frame"] * CellGrid.edge_transform(Vector3i(cell.x, storey, cell.y), side)


func _top(t: int) -> float:
	return tiers[t]["bottom"] + tiers[t]["storeys"] * BAY


## A point on tier t's open roof: inside its footprint, not under the tier above.
func _on_roof(t: int, p: Vector3) -> bool:
	if t < 0 or not g._covered(tiers[t], p):
		return false
	return t + 1 >= tiers.size() or not g._covered(tiers[t + 1], p)


## Garden and roof life that may simply be left out where it would stand in
## a KEEP_CLEAR volume (the Overlook's bridge).
const LOOSE: Array[String] = ["persian_pool", "persian_fountain", "persian_bed", "persian_pomegranate", "persian_fungus",
	"persian_lumen_post", "persian_windcatcher", "persian_glowmoss", "gorge_cypress", "gorge_banner"]


func _loose_blocked(path: String, xf: Transform3D) -> bool:
	for l: String in LOOSE:
		if path.get_file().begins_with(l):
			return _blocked(xf.origin, 2.0) or _blocked(xf.origin + Vector3(0, 6.0, 0), 2.0)
	return false


func _put(path: String, xf: Transform3D, top: float = 0.0) -> void:
	if _loose_blocked(path, xf):
		return
	var p: Dictionary = g._piece(P + path, xf)
	if top > 0.0:
		p["top"] = top     # its height for the rock's clearance (bake_gorge PIECE_TOP)
	out.append(p)


func _dress(path: String, xf: Transform3D) -> void:
	if _loose_blocked(path, xf):
		return
	out.append(g._piece(path, xf))


func _light(p: Vector3, color: Color, energy: float, reach: float) -> void:
	out.append({"light": p, "color": color, "energy": energy, "range": reach})


## Zones count in plan (x, z); with `dy`, only those within dy of p's height
## (a park on a roof far above an iwan's garden).
func _zone(p: Vector3, dy: float = INF) -> String:
	for z: Dictionary in zones:
		if z["kind"] not in ["garden", "monument"] and absf(p.y - z["p"].y) < dy and Vector2(p.x - z["p"].x, p.z - z["p"].z).length() < z["r"]:
			return z["kind"]
	return "dark"


func _in_garden(p: Vector3, dy: float = INF) -> bool:
	for z: Dictionary in zones:
		if z["kind"] in ["garden", "monument"] and absf(p.y - z["p"].y) < dy and Vector2(p.x - z["p"].x, p.z - z["p"].z).length() < z["r"]:
			return true
	return false


## The face runs of a tier that face the gorge: their cells in order along
## the face, the face's outward normal, how squarely it faces the Overlook
## (eye) and the gorge's axis (axis).
func _runs(t: Dictionary, gone: Dictionary = {}) -> Array:
	var result: Array = []
	var cells: Dictionary = t["cells"]
	for cell: Vector2i in cells:
		for side: int in CellGrid.ALL_SIDES:
			if cells.has(GorgeGrammar._beside(cell, side)) or g._exposed(cells, GorgeGrammar._before(cell, side), side):
				continue
			var xf: Transform3D = t["frame"] * CellGrid.edge_transform(Vector3i(cell.x, 0, cell.y), side)
			if not g._faces_gorge(xf) and not gone.has(GorgeGrammar._beside(cell, side)):
				continue
			var list: Array[Vector2i] = [cell]
			while g._exposed(cells, GorgeGrammar._after(list[-1], side), side):
				list.append(GorgeGrammar._after(list[-1], side))
			var n: Vector3 = Vector3(xf.basis.z.x, 0, xf.basis.z.z).normalized()
			var inner: bool = false     # it faces into the opening cut round the monument
			for c: Vector2i in list:
				inner = inner or gone.has(GorgeGrammar._beside(c, side))
			result.append({"cells": list, "side": side, "normal": n, "inner": inner,
				"eye": n.dot((GorgeGrammar.EYE - xf.origin).normalized()),
				"axis": n.dot(Vector3(-xf.origin.x, 0, 0).normalized())})
	return result


## Whether a feature may not stand here: its origin past SLOT_Z (bank 1), or
## `p` near a frontage slot (the other banks).
func _shut(origin: Vector3, p: Vector3, reach: float) -> bool:
	return origin.z < SLOT_Z if slot_z else _near_slot(p, reach)


## Whether p is within `reach` (metres, along the face and up and down) of
## one of this bank's frontage slots, where a gallery's ledge stands out from
## the face (one bay deep, with headroom).
func _near_slot(p: Vector3, reach: float) -> bool:
	for s: FrontageSlot in slots:
		var l: Vector3 = s.xf.affine_inverse() * p
		if l.x > -reach and l.x < s.width * BAY + reach and l.y > -reach and l.y < reach + 4.0 and l.z > -BAY - reach and l.z < reach:
			return true
	return false


## A house's finish from `u` (its 0..1 hash): lime or plaster as on banks 1
## and 2, and further out banai brick and glazed tile, TILE_SHARE and
## BANAI_SHARE of the houses at the furthest bank (none at ornament 0).
const TILE_SHARE: float = .45
const BANAI_SHARE: float = .3


func _tint(u: float) -> String:
	if u > 1.0 - TILE_SHARE * ornament:
		return "tile"
	if u > 1.0 - (TILE_SHARE + BANAI_SHARE) * ornament:
		return "banai"
	return "lime" if u < .35 else "plaster"


## Where fungal vines (persian_glowmoss) hang on a storey's wall `piece`:
## from under its top, beside its window or door, never across it (your
## walk: they floated in front of an opening). A rock wall's opening is
## 1.0 to 1.4 m wide in the middle; the vines are 0.6 m wide; the door side
## away from its lamp (x 3.1).
func _vines_at(piece: String, h: float) -> Transform3D:
	var left: bool = piece.contains("_door") or fposmod(h * 5.0, 1.0) < .5
	return Transform3D(Basis(), Vector3(.65 if left else 3.35, 3.75, .06))


func _take(t: int, cell: Vector2i, side: int, storeys: Array) -> void:
	for s: int in storeys:
		taken[_key(t, cell, side, s)] = true


# ---------------------------------------------------------------- features

## The monument, the bank's landmark (the user, 2026-10-27, after step 2:
## on the top tier it sat on the houses like a hat; it should dominate the
## bank, sandwiched mid-stack with houses below and above, a garden in front,
## more than two storeys). It stands on a mid tier's roof, set back MON_BACK
## from the tier's face: the tier's houses below it, its roof in front the
## garden (a chahar bagh lit by two lumen stones, two tall minarets), then
## four storeys (16 m) of arcades and coloured-glass windows with the grand
## portal (21 m) in the middle and the grand dome behind. The tiers above are
## cut away over the garden, the monument and the dome; tiers wholly above
## the dome stand over the rest.
const MON_WINGS: int = 2
const MON_PORTAL: int = 4
const MON_STOREYS: int = 4
const MON_BACK: float = 8.0
## Where in the stack it should stand: the middle of what the Overlook sees
## of the bank, above the mist (at -48 the mist washed it out).
const MON_HEIGHT: float = -20.0
## Tiers above keep nothing this far out in front of the garden's edge, so
## nothing overhangs the monument's view (metres).
const MON_SIGHT: float = 16.0


func _monument() -> void:
	var span: int = MON_WINGS * 2 + MON_PORTAL
	var best: Array = []
	var best_score: float = -INF
	for t: int in range(2, tiers.size() - 2):
		for r: Dictionary in runs[t]:
			if r["eye"] < .45 or r["cells"].size() < span:
				continue
			for k: int in range(0, r["cells"].size() - span + 1):
				var top_xf: Transform3D = _xf(t, r["cells"][k], r["side"], tiers[t]["storeys"])
				var far: Vector3 = _xf(t, r["cells"][k + span - 1], r["side"], 0).origin
				if _shut(top_xf.origin, top_xf.origin, 10.0) or _shut(far, far, 10.0):
					continue
				var fit: Dictionary = _mon_room(t, top_xf, span)
				if fit.is_empty():
					continue
				var score: float = r["eye"] + (.15 if fit["dome"] == "grand" else 0.0) - absf(_top(t) - MON_HEIGHT) * .012
				if score > best_score:
					best_score = score
					best = [t, r, k, fit]
	if best.is_empty():
		push_warning("PersianTown: no run fits the monument")
		return
	var t: int = best[0]
	var r: Dictionary = best[1]
	var top_xf: Transform3D = _xf(t, r["cells"][best[2]], r["side"], tiers[t]["storeys"])
	_cut_for_monument(t, top_xf, span, best[3])
	_build_monument(t, top_xf, span, best[3])


## Room on tier t's roof behind the face (`top_xf`, at the roof's height) for
## the garden and the monument: 12 m deep (the grand dome) or 8 (a plain one)
## behind the garden; {} if not even that.
func _mon_room(t: int, top_xf: Transform3D, span: int) -> Dictionary:
	var w: float = span * BAY
	for depth: float in [12.0, 8.0]:
		var ok: bool = true
		for d: float in [.5, MON_BACK, MON_BACK + depth * .5, MON_BACK + depth - .5]:
			for x: float in [.5, w * .5, w - .5]:
				ok = ok and g._covered(tiers[t], top_xf * Vector3(x, 0, -d))
		if ok:
			return {"depth": depth, "dome": "grand" if depth >= 12.0 else "plain"}
	return {}


## Sandwiched: the tiers above tier t lose the cells over the garden, the
## monument and its dome, all the way up, so it stands in a clearing open to
## the cavern with houses below it and rising either side (with tiers left
## over it, it read as tucked under a roof and its dome was hidden). The
## faces round the opening get walls (_runs builds them even where they look
## away from the gorge).
func _cut_for_monument(t: int, top_xf: Transform3D, span: int, fit: Dictionary) -> void:
	var w: float = span * BAY
	var depth: float = fit["depth"]
	var grand: bool = fit["dome"] == "grand"
	var dome_c := Vector2(w * .5, -MON_BACK - (7.0 if grand else 4.0))
	var dome_r: float = 6.6 if grand else 5.0
	_cut_above(t, top_xf, func(l: Vector3) -> bool:
		var in_x: bool = l.x > -1.0 and l.x < w + 1.0
		# Over the garden and anything hanging out in front of it: a house
		# overhanging the garden hid the monument (your report).
		var in_garden: bool = in_x and l.z > -MON_BACK and l.z < MON_SIGHT
		var in_body: bool = in_x and l.z > -MON_BACK - depth - 1.0 and l.z <= -MON_BACK
		var in_dome: bool = Vector2(l.x, l.z).distance_to(dome_c) < dome_r
		return in_garden or in_body or in_dome)


## Every tier above t loses the cells any of whose points `inside` (in
## `top_xf`'s frame) holds, all the way up, and the small pieces that leaves.
func _cut_above(t: int, top_xf: Transform3D, inside: Callable) -> void:
	var inv: Transform3D = top_xf.affine_inverse()
	for u: int in range(t + 1, tiers.size()):
		var cells: Dictionary = tiers[u]["cells"]
		var frame: Transform3D = tiers[u]["frame"]
		var gone: Dictionary = {}
		for cell: Vector2i in cells:
			for k: Vector2 in [Vector2(.2, .2), Vector2(3.8, .2), Vector2(.2, 3.8), Vector2(3.8, 3.8), Vector2(2, 2)]:
				if inside.call(inv * (frame * Vector3(cell.x * BAY + k.x, 0, -cell.y * BAY - k.y))):
					gone[cell] = true
					break
		if gone.is_empty():
			continue
		for cell: Vector2i in gone:
			cells.erase(cell)
		# What the cut leaves of a tier in small pieces would hang in the air:
		# keep only its larger parts.
		for part: Dictionary in _parts(cells):
			if part.size() < 12:
				for cell: Vector2i in part:
					cells.erase(cell)
					gone[cell] = true
		var all: Dictionary = cut.get(u, {})
		all.merge(gone)
		cut[u] = all
		runs[u] = _runs(tiers[u], all)


## A footprint's connected parts (cells sharing a side).
func _parts(cells: Dictionary) -> Array[Dictionary]:
	var seen: Dictionary = {}
	var parts: Array[Dictionary] = []
	for start: Vector2i in cells:
		if seen.has(start):
			continue
		var part: Dictionary = {}
		var stack: Array[Vector2i] = [start]
		seen[start] = true
		while not stack.is_empty():
			var c: Vector2i = stack.pop_back()
			part[c] = true
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if cells.has(c + d) and not seen.has(c + d):
					seen[c + d] = true
					stack.append(c + d)
		parts.append(part)
	return parts


func _build_monument(t: int, top_xf: Transform3D, span: int, fit: Dictionary) -> void:
	var w: float = span * BAY
	var depth: float = fit["depth"]
	var height: float = MON_STOREYS * BAY
	var front: Transform3D = top_xf * Transform3D(Basis(), Vector3(0, 0, -MON_BACK))
	zones.append({"p": front * Vector3(w * .5, 0, -depth * .5), "r": maxf(w, depth) * .5 + 1.0, "kind": "monument"})
	zones.append({"p": top_xf * Vector3(w * .5, 0, -MON_BACK * .5), "r": w * .5, "kind": "garden"})
	zones.append({"p": top_xf * Vector3(w * .5, 0, -MON_BACK * .5), "r": w * .5 + 3.0, "kind": "gem"})
	# The front: the grand portal over its four middle bays, the wings either side.
	_put("persian_portal_grand", front * Transform3D(Basis(), Vector3(MON_WINGS * BAY, 0, 0)), 22.0)
	for b: int in span:
		if b >= MON_WINGS and b < MON_WINGS + MON_PORTAL:
			continue
		for s: int in MON_STOREYS:
			var piece: String = ["persian_wall_brick_arcade" if b % 2 == 0 else "persian_wall_brick_arcade_dark",
				"persian_wall_brick_orosi", "persian_wall_brick_arcade_dark", "persian_wall_brick"][s]
			_put(piece, front * Transform3D(Basis(), Vector3(b * BAY, s * BAY, WALL_PROUD)))
		_put("persian_crown", front * Transform3D(Basis(), Vector3(b * BAY, height, 0)))
	# Its sides and back, and a roof of its own.
	var turns: Array = [[Basis(Vector3.UP, -PI * .5), func(j: int) -> Vector3: return Vector3(0, 0, -depth + j * BAY), int(depth / BAY)],
		[Basis(Vector3.UP, PI * .5), func(j: int) -> Vector3: return Vector3(w, 0, -j * BAY), int(depth / BAY)],
		[Basis(Vector3.UP, PI), func(j: int) -> Vector3: return Vector3(w - j * BAY, 0, -depth), span]]
	for turn: Array in turns:
		for j: int in turn[2]:
			var at: Vector3 = (turn[1] as Callable).call(j)
			for s: int in MON_STOREYS:
				_put("persian_wall_brick_arcade_dark" if s == 1 else "persian_wall_brick", front * Transform3D(turn[0], at + Vector3(0, s * BAY, 0)) * Transform3D(Basis(), Vector3(0, 0, WALL_PROUD)))
			_put("persian_crown", front * Transform3D(turn[0], at + Vector3(0, height, 0)))
	for i: int in span:
		for j: int in int(depth / BAY):
			_put("persian_roof", front * Transform3D(Basis(), Vector3(i * BAY, height - ROOF_DROP, -j * BAY)))
	if fit["dome"] == "grand":
		_put("persian_dome_grand", front * Transform3D(Basis(), Vector3(w * .5, height, -7.0)), 24.0)
	else:
		_put("persian_dome", front * Transform3D(Basis(), Vector3(w * .5, height, -4.0)), 17.0)
	_light(front * Vector3(w * .5, 6.0, 1.0), Color(1.0, .74, .42), 3.5, 18.0)
	# The garden in front, on the tier's roof: two tall minarets flanking the
	# portal, a pool along the front with its fountain, beds either side,
	# cypress rows along the parapet, two lumen stones before the portal,
	# pomegranates at the ends.
	for x: float in [MON_WINGS * BAY - 2.4, (MON_WINGS + MON_PORTAL) * BAY + 2.4]:
		_put("persian_minaret_tall", front * Transform3D(Basis(), Vector3(x, 0, 3.0)), 34.0)
	var along := Basis(Vector3.UP, PI * .5)
	_put("persian_pool", top_xf * Transform3D(along, Vector3(w * .5, 0, -3.6)))
	_put("persian_fountain", top_xf * Transform3D(Basis(), Vector3(w * .5, 0, -3.6)))
	for x: float in [w * .5 - 8.0, w * .5 + 8.0]:
		_put("persian_bed", top_xf * Transform3D(Basis(), Vector3(x, 0, -3.6)))
	for xi: int in range(2, int(w) - 1, 4):
		var p: Vector3 = top_xf * Vector3(float(xi), 0, -1.2)
		if _on_roof(t, p):
			_dress("dressing/gorge_cypress_6", Transform3D(top_xf.basis, p))
	for x: float in [w * .5 - 4.6, w * .5 + 4.6]:
		var p: Vector3 = front * Vector3(x, 0, 1.8)
		_put("persian_lumen_post", Transform3D(top_xf.basis, p))
		_light(p + Vector3(0, 3.2, 0), LUMEN, 2.6, 14.0)
	for x: float in [1.4, w - 1.4]:
		var p: Vector3 = top_xf * Vector3(x, 0, -3.6)
		if _on_roof(t, p):
			_put("persian_pomegranate", Transform3D(top_xf.basis, p))


## The iwan: two bays of a three-storey tier facing the Overlook, with a
## terrace at least 9 m deep in front (the tier below's roof); its lumen
## stone, and a garden on that terrace: a pool running out from it, beds
## either side, cypresses and pomegranates.
func _iwan() -> void:
	var best: Array = _iwan_spot()
	# On a grand bank whose high tiers no walkway sees (bank 7: the walkways
	# see only its low faces), as on the banks no walkway sees at all: facing
	# the gorge's open middle.
	if best.is_empty() and ornament >= GRAND_FROM and not _walk_blind():
		_middle = true
		best = _iwan_spot()
		_middle = false
	if best.is_empty():
		return
	_build_iwan(best)


## Seen fractions measure facing the gorge's open middle (_walk_blind's rule).
var _middle: bool = false


## The best place for an iwan, [t, run, bay], or [].
func _iwan_spot() -> Array:
	var best: Array = []
	var best_score: float = -INF
	for t: int in range(1, tiers.size() - 1):
		# Three storeys; on the other banks two will do (the two-storey iwan:
		# bank 2's tiers the walkways see are two storeys tall).
		if tiers[t]["storeys"] != 3 and (slot_z or tiers[t]["storeys"] != 2):
			continue
		# From bank 3 on, high up where the walkways look across at it (your
		# walk: bank 4's two sat low in the mist); banks 1 and 2 as approved.
		var high: float = _height01(t)
		if ornament > 0.0 and high < IWAN_HIGH:
			continue
		for r: Dictionary in runs[t]:
			if r["inner"] or maxf(r["eye"], r["axis"] if _middle else -1.0) < .3 or r["cells"].size() < 4:
				continue
			for k: int in range(1, r["cells"].size() - 2):
				var xf: Transform3D = _xf(t, r["cells"][k], r["side"], 0)
				if _shut(xf.origin, xf * Vector3(4, 4, 0), 6.0) or taken.has(_key(t, r["cells"][k], r["side"], 0)) or taken.has(_key(t, r["cells"][k + 1], r["side"], 0)) \
						or reserved.has(_key(t, r["cells"][k], r["side"])) or reserved.has(_key(t, r["cells"][k + 1], r["side"])):
					continue
				if _in_garden(xf * Vector3(4, 0, 5)) or _in_garden(xf * Vector3(4, 0, -2)):
					continue     # the monument or its garden is here
				if iwans.any(func(q: Vector3) -> bool: return q.distance_to(xf.origin) < IWAN_SPACING):
					continue     # another of this bank's iwans
				var deep: bool = true
				# High up the tiers step back less: a balcony of a terrace will do
				# there, its pool left out where it won't fit.
				for d: float in ([2.0, IWAN_SHALLOW] if ornament > 0.0 else [2.0, 5.0, 7.5]):
					for x: float in [1.0, 7.0]:
						deep = deep and _on_roof(t - 1, xf * Vector3(x, -.2, d))
				if not deep:
					continue
				var shut_in: bool = false
				for d: float in [6.0, 12.0]:
					for x: float in [1.0, 7.0]:
						shut_in = shut_in or _fronted(xf * Vector3(x, 2.0, d)) or _fronted(xf * Vector3(x, 8.0, d))
				if shut_in:
					continue     # it would look into the sanctum's walls
				var score: float = r["eye"] - (xf.origin - GorgeGrammar.EYE).length() * .002
				if not slot_z:
					# Seen from the walkways (your call: bank 2's stood behind the camp's
					# front from the Overlook); bank 1's stays where you approved it.
					var seen: float = _seen_fraction(xf, tiers[t]["storeys"])
					if seen < IWAN_SEEN:
						continue
					score += seen * 2.0
				if ornament > 0.0:
					score += high * 3.0
				if score > best_score:
					best_score = score
					best = [t, r, k]
	return best


func _build_iwan(best: Array) -> void:
	var t: int = best[0]
	var r: Dictionary = best[1]
	var k: int = best[2]
	var side: int = r["side"]
	var xf: Transform3D = _xf(t, r["cells"][k], side, 0)
	iwans.append(xf.origin)
	var storeys: int = tiers[t]["storeys"]
	_put("persian_iwan_tier" if storeys == 3 else "persian_iwan_tier2", xf * Transform3D(Basis(), Vector3(0, 0, WALL_PROUD)))
	for b: int in [k, k + 1]:
		_take(t, r["cells"][b], side, range(storeys))
		no_core["%d:%d,%d" % [t, r["cells"][b].x, r["cells"][b].y]] = true
	_put("persian_lumen_post", xf * Transform3D(Basis(), Vector3(4, 0, -1.6)))
	_light(xf * Vector3(4, 3.4, -.6), LUMEN, 3.2, 17.0)
	zones.append({"p": xf * Vector3(4, 0, 4), "r": 15.0, "kind": "gem"})
	zones.append({"p": xf * Vector3(4, 0, 5), "r": 9.0, "kind": "garden"})
	_extend_terrace(t - 1, xf)
	# The pool lies along the face (8 x 4 m; run out from it, it hung over the
	# terrace's parapet: your report), beds between it and the iwan either
	# side of the spring's channel.
	var turn := Basis(Vector3.UP, PI * .5)
	if _on_roof(t - 1, xf * Vector3(1, -.2, 6.8)) and _on_roof(t - 1, xf * Vector3(7, -.2, 6.8)):
		_put("persian_pool", xf * Transform3D(turn, Vector3(4, 0, 4.6)))
		_put("persian_fountain", xf * Transform3D(Basis(), Vector3(4, 0, 4.6)))
	for x: float in [1.6, 6.4]:
		_put("persian_bed", xf * Transform3D(Basis(), Vector3(x, 0, 1.4)))
	for x: float in [-.2, 8.2]:
		for d: float in [1.5, 4.5, 7.0]:
			var p: Vector3 = xf * Vector3(x, 0, d)
			if _on_roof(t - 1, p):
				_dress("dressing/gorge_cypress_6", Transform3D(xf.basis, p))
	for x: float in [-2.2, 10.2]:
		var p: Vector3 = xf * Vector3(x, 0, 6.0)
		if _on_roof(t - 1, p):
			_put("persian_pomegranate", Transform3D(xf.basis, p))


## Parks on the widest open roofs (your walk: a big empty terrace on bank 2
## "would be a nice place for a fungal garden plus water pool, almost like a
## park"): where a square PARK_HALF each way from a cell's centre is all open
## roof with nothing over it, nearest its tier's middle first, up to
## PARKS_PER_TIER on a roof PARK_SPACING apart and MAX_PARKS a bank (the widest
## tiers first). A pool with a fountain in the middle,
## two beds either side with paths between, fungi (dark) or pomegranates and
## cypresses (lit) at the corners and ends. Not on bank 1 (as approved).
const PARK_HALF: float = 9.0
const MAX_PARKS: int = 4
const PARKS_PER_TIER: int = 3
const PARK_SPACING: float = 26.0
const PARK_LUMEN: float = 1.5


func _parks() -> void:
	var order: Array = range(tiers.size())
	order.sort_custom(func(a: int, b: int) -> bool: return (tiers[a]["cells"] as Dictionary).size() > (tiers[b]["cells"] as Dictionary).size())
	var placed: Array[Vector3] = []
	for t: int in order:
		var frame: Transform3D = tiers[t]["frame"]
		var c: Vector2 = tiers[t]["c"]
		var spots: Array[Vector3] = []
		for cell: Vector2i in tiers[t]["cells"]:
			var at: Vector3 = frame * Vector3(cell.x * BAY + 2.0, 0, -cell.y * BAY - 2.0)
			at.y = _top(t)
			spots.append(at)
		spots.sort_custom(func(a: Vector3, b: Vector3) -> bool: return Vector2(a.x - c.x, a.z - c.y).length() < Vector2(b.x - c.x, b.z - c.y).length())
		var here: int = 0
		for at: Vector3 in spots:
			if placed.size() >= MAX_PARKS + roundi(ornament * 4.0) or here >= PARKS_PER_TIER:
				break
			if placed.any(func(q: Vector3) -> bool: return q.distance_to(at) < PARK_SPACING):
				continue
			if _park_fits(t, at, frame.basis):
				_park(t, at, frame.basis)
				placed.append(at)
				here += 1


func _park_fits(t: int, at: Vector3, basis: Basis) -> bool:
	var x: float = -PARK_HALF
	while x <= PARK_HALF + .01:
		var z: float = -PARK_HALF
		while z <= PARK_HALF + .01:
			var p: Vector3 = at + basis * Vector3(x, 0, z)
			if not _on_roof(t, p) or not _open_above(t, p) or _in_garden(p, 6.0) or _blocked(p, 1.0) or _near_slot(p, 2.0):
				return false
			z += 3.0
		x += 3.0
	return true


func _park(t: int, at: Vector3, basis: Basis) -> void:
	var dark: bool = _zone(at, 12.0) == "dark"
	# Further from the camp, more parks have a lumen stone, and real planting
	# under it (plants grow only by light), PARK_LUMEN of them at the furthest.
	var lumen: bool = dark and GorgeGrammar._hash01(at * .37) < ornament * PARK_LUMEN
	if lumen:
		dark = false
	var turn := Basis(Vector3.UP, PI * .5)
	var put := func(path: String, local: Vector3, b: Basis = Basis()) -> void:
		var p: Vector3 = at + basis * local
		if _on_roof(t, p):
			if path.begins_with("dressing/"):
				_dress(path, Transform3D(basis * b, p))
			else:
				_put(path, Transform3D(basis * b, p))
	put.call("persian_pool", Vector3.ZERO)
	if lumen:
		put.call("persian_lumen_post", Vector3(0, 0, 7.0))
		_light(at + basis * Vector3(0, 3.4, 7.0), LUMEN, 3.2, 17.0)
		zones.append({"p": at, "r": PARK_HALF + 4.0, "kind": "gem"})
	put.call("persian_fountain", Vector3.ZERO)
	for x: float in [-4.6, 4.6]:
		for z: float in [-2.4, 2.4]:
			put.call("persian_bed_fungal" if dark else "persian_bed", Vector3(x, 0, z), turn)
	if dark:
		for corner: Array in [[Vector3(-5.2, 0, -5.6), "persian_fungus_giant_9"], [Vector3(5.2, 0, 5.6), "persian_fungus_giant_9"],
				[Vector3(5.2, 0, -5.6), "persian_fungus_giant_6"], [Vector3(-5.2, 0, 5.6), "persian_fungus_giant_6"]]:
			put.call(corner[1], corner[0])
		for p: Vector3 in [Vector3(-7.4, 0, 0), Vector3(7.4, 0, 0)]:
			put.call("persian_fungus_jelly", p)
		for p: Vector3 in [Vector3(-2.6, 0, -6.2), Vector3(2.6, 0, 6.2)]:
			put.call("persian_fungus_cluster", p)
		for p: Vector3 in [Vector3(2.6, 0, -6.2), Vector3(-2.6, 0, 6.2)]:
			put.call("persian_fungus_small", p)
		var lit: bool = true
		for q: Vector3 in teal_lights:
			lit = lit and q.distance_to(at) > TEAL_SPACING
		if lit:
			teal_lights.append(at)
			_light(at + Vector3(0, 3.0, 0), TEAL, 1.6, 12.0)
	else:
		for p: Vector3 in [Vector3(-5.2, 0, -5.6), Vector3(5.2, 0, 5.6), Vector3(5.2, 0, -5.6), Vector3(-5.2, 0, 5.6)]:
			put.call("persian_pomegranate", p)
		for p: Vector3 in [Vector3(-7.4, 0, -2.4), Vector3(-7.4, 0, 2.4), Vector3(7.4, 0, -2.4), Vector3(7.4, 0, 2.4)]:
			put.call("dressing/gorge_cypress_6", p)
	zones.append({"p": at, "r": PARK_HALF, "kind": "garden"})


## How much of an iwan at `xf` (its two bays, `storeys` tall) the walkways
## see (your call: bank 2's, from the span and the links, not the Overlook):
## of nine points over its front, those some walkway eye (_walk_eyes) sees
## within WALK_SIGHT, in front of the iwan, with a clear line past every
## bank's tiers and the colossi on their piers (vista_foreground.gd). At
## least IWAN_SEEN of it, where any is.
const IWAN_SEEN: float = .6
const IWAN_SPACING: float = 24.0     # between a bank's iwans
const IWAN_HIGH: float = .75         # of the bank's height, from bank 3 on
const IWAN_SHALLOW: float = 4.5      # terrace depth the high iwans need


## How high tier t's bottom stands in its bank: 0 at the gorge floor, 1 at the
## top tier's roof.
func _height01(t: int) -> float:
	var low: float = tiers[0]["bottom"]
	var top: float = float(tiers[-1]["bottom"]) + int(tiers[-1]["storeys"]) * GorgeGrammar.BAY
	return (float(tiers[t]["bottom"]) - low) / maxf(top - low, 1.0)
const WALK_SIGHT: float = 90.0
const FOREGROUND: GDScript = preload("res://scripts/vista_foreground.gd")
const CAVERN: GDScript = preload("res://scripts/cavern.gd")
static var _all_tiers: Array[Dictionary] = []
static var _eyes: Array[Vector3] = []


func _seen_fraction(xf: Transform3D, storeys: int = 3) -> float:
	if _all_tiers.is_empty():
		_all_tiers = g.keep_out(load("res://gen/gorge/gorge_layout.tres"))
	var n: Vector3 = xf.basis.z.normalized()
	if _walk_blind() or _middle:
		return clampf(n.dot(Vector3(-signf(xf.origin.x), 0, 0)) * 1.25, 0.0, 1.0)
	var seen: int = 0
	for x: float in [1.0, 4.0, 7.0]:
		for y: float in [.17, .5, .83]:
			var p: Vector3 = xf * Vector3(x, y * storeys * BAY, .6)
			for e: Vector3 in _walk_eyes():
				var d: float = p.distance_to(e)
				if d < WALK_SIGHT and n.dot(e - p) > .3 * d and _sight(e, p):
					seen += 1
					break
	return seen / 9.0


## The far banks (bank 6 on): no walkway reaches or sees them, and the
## Overlook sees them only between the nearer banks; their faces toward the
## Overlook look into the gap by the nearer banks and the cavern's rock, so
## their features face the gorge's open middle (x = 0) instead.
## Whether this bank is one: no walkway sees any bay at the middle of its
## runs.
var _blind: int = -1


func _walk_blind() -> bool:
	if _blind < 0:
		_blind = 1
		for t: int in range(1, tiers.size() - 1, 2):
			for r: Dictionary in runs[t]:
				if r["inner"] or r["eye"] < .3:
					continue
				var xf: Transform3D = _xf(t, r["cells"][r["cells"].size() / 2], r["side"], 0)
				var p: Vector3 = xf * Vector3(2, tiers[t]["storeys"] * BAY * .5, .6)
				var n: Vector3 = xf.basis.z.normalized()
				for e: Vector3 in _walk_eyes():
					var d: float = p.distance_to(e)
					if d < WALK_SIGHT and n.dot(e - p) > .3 * d and _sight(e, p):
						_blind = 0
						return false
	return _blind == 1



## Where you stand on the walkways, at eye height: each bay of every
## frontage slot's gallery ledge (every seed's network walks them), and the
## span from the Overlook's connector out over the gorge, level or a storey
## or two down (links.res `fixed`; its length the longest a span may be).
func _walk_eyes() -> Array[Vector3]:
	if not _eyes.is_empty():
		return _eyes
	for s: FrontageSlot in (load(FRONTAGE) as GorgeFrontage).slots:
		for k: int in s.width:
			_eyes.append(s.xf * Vector3(k * BAY + 2.0, 1.6, -2.0))
	var links: Resource = load("res://gen/gorge/links.res")
	for id: Variant in links.get("fixed"):
		if not String(id).ends_with("SNAP_exit_span"):
			continue
		var start: Transform3D = links.get("fixed")[id]
		for d: float in range(4, 24 * int(BAY) + 1, 8):
			for y: float in [1.6, -6.4]:
				_eyes.append(start * Vector3(0, y, -d))
	return _eyes


func _sight(from: Vector3, p: Vector3) -> bool:
	var length: float = from.distance_to(p)
	var d: float = 3.0
	while d < length - 2.0:
		var q: Vector3 = from.lerp(p, d / length)
		for c: Array in FOREGROUND.COLOSSI:
			var r: float = FOREGROUND.PIER_RADIUS + .5 if q.y < FOREGROUND.COLOSSUS_FLOOR else 6.5
			if q.y < FOREGROUND.COLOSSUS_FLOOR + 6.2 * FOREGROUND.COLOSSUS_SCALE and Vector2(q.x - float(c[0]), q.z - float(c[1])).length() < r:
				return false
		if GorgeGrammar.solid_at(_all_tiers, q):
			return false
		d += 2.0
	return true


## The iwan's garden filled its terrace, so no one could walk past it (your
## report). Tier `low`'s face under the garden steps forward EXT over the
## terrace below (which gets narrower): those bays become a deeper building,
## walls at the new face, returns at its ends, a roof, parapet and cornice
## over the gap; its old face is left unbuilt. Only where the terrace below
## stays at least EXT_LEFT deep, and not on a bay a stair needs.
const EXT: float = 3.0
const EXT_LEFT: float = 2.5


func _extend_terrace(low: int, iwan_xf: Transform3D) -> void:
	if low < 1:
		return
	var inv: Transform3D = iwan_xf.affine_inverse()
	var storeys: int = tiers[low]["storeys"]
	for r: Dictionary in runs[low]:
		var list: Array = r["cells"]
		var side: int = r["side"]
		var group: Array = []
		var best: Array = []
		for cell: Vector2i in list:
			var xf: Transform3D = _xf(low, cell, side, 0)
			var mid: Vector3 = inv * (xf * Vector3(2, 0, 0))
			var ok: bool = mid.x > -2.0 and mid.x < 10.0 and mid.z > 4.0 and mid.z < 12.0
			for x: float in [.5, 3.5]:
				ok = ok and _on_roof(low - 1, xf * Vector3(x, -.2, EXT + EXT_LEFT)) and _on_roof(low - 1, xf * Vector3(x, -.2, .5))
			ok = ok and not taken.has(_key(low, cell, side, 0))
			if ok:
				group.append(cell)
				if group.size() > best.size():
					best = group.duplicate()
			else:
				group = []
		if best.is_empty():
			continue
		var tint: String = "plaster"
		var parapet: String = "persian_parapet"
		var front := Transform3D(Basis(), Vector3(0, 0, EXT + WALL_PROUD))
		for i: int in best.size():
			var cell: Vector2i = best[i]
			_take(low, cell, side, range(storeys))
			no_edge[_key(low, cell, side)] = true
			for s: int in storeys:
				var xf: Transform3D = _xf(low, cell, side, s)
				var h: float = GorgeGrammar._hash01(xf.origin * 1.7)
				var lit: bool = g._noise.get_noise_3dv(xf * Vector3(2, 2, 0)) > -.05
				var piece: String = "persian_wall_%s_door" % tint if s == 0 and i == best.size() / 2 else \
					("persian_wall_%s_window2" % tint if s > 0 and h < .5 else "persian_wall_%s_window" % tint) + ("" if lit else "_dark")
				_put(piece, xf * front)
			var top: Transform3D = _xf(low, cell, side, storeys)
			_put("persian_roof", top * Transform3D(Basis.from_scale(Vector3(1, 1, EXT / BAY)), Vector3(0, -ROOF_DROP, EXT)))
			_put(parapet, top * front)
			_put("persian_cornice", _xf(low, cell, side, storeys - 1) * front)
		# The returns at its two ends: walls across the step, parapet over them.
		var ends: Array = [[best[0], 0.0, Basis(Vector3.UP, -PI * .5), 0.0], [best[-1], BAY, Basis(Vector3.UP, PI * .5), EXT + WALL_PROUD]]
		for e: Array in ends:
			for s: int in storeys + 1:
				var at: Transform3D = _xf(low, e[0], side, s) * Transform3D(e[2] * Basis.from_scale(Vector3((EXT + WALL_PROUD) / BAY, 1, 1)), Vector3(e[1], 0, e[3]))
				_put(parapet if s == storeys else "persian_wall_%s" % tint, at)
		zones.append({"p": _xf(low, best[best.size() / 2], side, storeys) * Vector3(2, 0, EXT * .5), "r": best.size() * BAY * .5 + 1.0, "kind": "garden"})
		return


## The great fall: a spillway on a mid tier's run facing the gorge's axis,
## its water stepping down the terraces below it (a pool where it lands,
## then over the terrace's edge) to the mist; a shaft of natural light over
## the first pool, and a sunlit garden round it.
func _cascade() -> void:
	for t: int in range(tiers.size() - 2, 2, -1):
		var bottom: float = tiers[t]["bottom"]
		if bottom < -110.0 or bottom > -40.0 or tiers[t]["storeys"] < 2:
			continue
		for r: Dictionary in runs[t]:
			if r["inner"] or r["axis"] < .8 or r["eye"] < .3 or r["cells"].size() < 5:
				continue
			for k: int in range(1, r["cells"].size() - 3):
				var xf: Transform3D = _xf(t, r["cells"][k], r["side"], 0)
				if _shut(xf.origin, xf * Vector3(6, 4, 0), 8.0):
					continue
				var free: bool = true
				for b: int in range(k, k + 3):
					free = free and not taken.has(_key(t, r["cells"][b], r["side"], 0))
				if not free:
					continue
				var lip: Vector3 = xf * Vector3(6, 1.0, 2.2)
				var steps: Array = _fall_steps(t, lip, xf.basis)
				if steps.size() < 2 or steps[0]["drop"] > 50.0:
					continue
				var into_garden: bool = false
				for st: Dictionary in steps:
					into_garden = into_garden or (st.has("at") and _in_garden(st["at"]))
				if into_garden:
					continue     # not onto the monument or a garden
				_put("persian_spillway_great", xf * Transform3D(Basis(), Vector3(0, 0, WALL_PROUD)))
				for b: int in range(k, k + 3):
					_take(t, r["cells"][b], r["side"], [0, 1])
				_lay_cascade(steps, xf.basis)
				return


## Where water poured at `lip` along the basis's +Z lands, step by step:
## [{from, drop, tier (-1: the mist), at}].
func _fall_steps(t: int, lip: Vector3, basis: Basis) -> Array:
	var steps: Array = []
	var out_dir: Vector3 = Vector3(basis.z.x, 0, basis.z.z).normalized()
	var from: Vector3 = lip
	var below: int = t - 1
	for _step: int in 4:
		var land: Vector3 = from + out_dir * 3.0
		var hit: int = -1
		for u: int in range(below, -1, -1):
			if g._covered(tiers[u], land):
				hit = u
				break
		if hit < 0:
			steps.append({"from": from, "drop": from.y - GorgeGrammar.BASE_Y + 6.0, "tier": -1})
			return steps
		var y: float = _top(hit)
		steps.append({"from": from, "drop": from.y - y, "tier": hit, "at": Vector3(land.x, y, land.z)})
		# The water runs across the roof to its edge and over.
		var edge: Vector3 = Vector3(land.x, y, land.z)
		while g._covered(tiers[hit], edge + out_dir * .5):
			edge += out_dir * .5
		from = edge + Vector3(0, .3, 0)
		below = hit - 1
	return steps


const MIN_DROP: float = 3.0


func _lay_cascade(steps: Array, basis: Basis) -> void:
	var first: bool = true
	for s: Dictionary in steps:
		var fall_xf := Transform3D(basis, s["from"])
		# A step shorter than MIN_DROP (the spillway's mouth onto the terrace in
		# front) is the spillway's own water and the pool: as a fall node its
		# mist and spray light hung at the next fall's lip and shone as white
		# blots in the Overlook's view (bank 2).
		if float(s["drop"]) >= MIN_DROP:
			out.append({"fall": fall_xf, "width": 7.5 if first else 9.0, "height": s["drop"], "arc": 3.0, "mist": true})
		if s["tier"] < 0:
			break
		var at: Vector3 = s["at"]
		var pool_xf := Transform3D(basis * Basis(Vector3.UP, PI * .5), at + basis.z.normalized() * 1.0)     # along the face: run out, it overhung the edge
		var fits: bool = true
		for c: Vector3 in [Vector3(-2.1, 0, -4.1), Vector3(2.1, 0, -4.1), Vector3(-2.1, 0, 4.1), Vector3(2.1, 0, 4.1)]:
			fits = fits and _on_roof(s["tier"], pool_xf * c)
		if fits:
			_put("persian_pool", pool_xf)
		zones.append({"p": at, "r": 7.0, "kind": "garden"})
		first = false
	# The edges the water pours over have no parapet (_tier skips them).
	for s: Dictionary in steps.slice(1):
		_open_edge(s["from"] - basis.z.normalized() * .6)


## The shaft garden: the terrace most squarely facing the Overlook that is
## open to the cavern (no tier above it at all), away from the iwan's
## lumen light; a shaft of natural light falls on it from a crack in the
## roof, and green things grow round a pool.
func _shaft() -> void:
	var best: Array = []
	var best_score: float = -INF
	for t: int in range(1, tiers.size()):     # the top tier's roof too: open to the cavern
		for r: Dictionary in runs[t]:
			var list: Array = r["cells"]
			for k: int in range(1, list.size() - 1):
				var xf: Transform3D = _xf(t, list[k], r["side"], tiers[t]["storeys"])
				var at: Vector3 = xf * Vector3(2, 0, -3.5)
				if _shut(at, at, 8.0) or r["inner"] or not _on_roof(t, at) or not _open_above(t, at) or _blocked(at, 8.0) or _in_garden(at) or _zone(at) != "dark" or _in_clearing(at, 8.0):
					continue
				if not (_on_roof(t, xf * Vector3(-3, 0, -3.5)) and _on_roof(t, xf * Vector3(7, 0, -3.5)) and _on_roof(t, xf * Vector3(-2, 0, -6.0)) and _on_roof(t, xf * Vector3(6, 0, -6.0)) and _on_roof(t, xf * Vector3(2, 0, -1.2))):
					continue
				# The pool (8 x 4 m along the face) must fit the roof clear of walls.
				var pool_fits: bool = true
				for c: Vector3 in [Vector3(-2.2, 0, -1.4), Vector3(6.2, 0, -1.4), Vector3(-2.2, 0, -5.6), Vector3(6.2, 0, -5.6)]:
					pool_fits = pool_fits and _on_roof(t, xf * c)
				if not pool_fits:
					continue
				var score: float = r["eye"] - (at - GorgeGrammar.EYE).length() * .002
				if score > best_score:
					best_score = score
					best = [t, xf, at]
	if best.is_empty():
		return
	var xf: Transform3D = best[1]
	var at: Vector3 = best[2]
	var basis := Basis(xf.basis.x, xf.basis.y, xf.basis.z)
	out.append({"shaft": at + Vector3(0, 90, 0), "height": 90.0, "radius": 10.0})
	zones.append({"p": at, "r": 13.0, "kind": "sun"})
	zones.append({"p": at, "r": 6.0, "kind": "garden"})
	_put("persian_pool", Transform3D(basis * Basis(Vector3.UP, PI * .5), at))
	_put("persian_fountain", Transform3D(basis, at))
	_sun_garden(best[0], at, basis)


## No tier above t that comes down below `y_top` covers p (higher tiers may
## stand over it).
func _clear(t: int, p: Vector3, y_top: float) -> bool:
	for u: int in range(t + 1, tiers.size()):
		if float(tiers[u]["bottom"]) < y_top - .05 and g._covered(tiers[u], p):
			return false
	return true


## No tier anywhere above tier t covers p.
func _open_above(t: int, p: Vector3) -> bool:
	for u: int in range(t + 1, tiers.size()):
		if g._covered(tiers[u], p):
			return false
	return true


func _sun_garden(t: int, at: Vector3, basis: Basis) -> void:
	var right: Vector3 = basis.x.normalized()
	var back: Vector3 = -basis.z.normalized()
	var turn := Basis(Vector3.UP, PI * .5)
	for side: float in [-1.0, 1.0]:
		var bed_at: Vector3 = at + right * side * 4.5 + back * 1.0
		if _on_roof(t, bed_at):
			_put("persian_bed", Transform3D(basis * turn, bed_at))
		for d: float in [-3.0, 1.0, 5.0]:
			var p: Vector3 = at + right * side * 6.8 + back * d
			if _on_roof(t, p):
				_dress("dressing/gorge_cypress_6", Transform3D(basis, p))
		var tree_at: Vector3 = at + right * side * 3.0 + back * 5.0
		if _on_roof(t, tree_at):
			_put("persian_pomegranate", Transform3D(basis, tree_at))


func _open_edge(p: Vector3) -> void:
	for t: int in tiers.size():
		if absf(_top(t) - p.y) > 1.0:
			continue
		var local: Vector3 = (tiers[t]["frame"] as Transform3D).affine_inverse() * p
		var cell := Vector2i(floori(local.x / BAY), floori(-local.z / BAY))
		for side: int in CellGrid.ALL_SIDES:
			no_edge[_key(t, cell, side)] = true


## Where other structures cross the banks' terraces: the Overlook's west
## bridge, its deck at -12 on an arch down to -25, from the Overlook's arcade
## to bank 1's face (tools/bake_overlook.gd; measured from
## rooms/gorge/overlook.tscn); aqueduct 3's landing on bank 5's terrace at -24
## (GorgeLayout.open_ends). Nothing of the town stands in them: a stair ran up
## beside the bridge's landing, and the shaft garden's cypresses grew up
## through its deck (your walks). [from, to, half width, bottom, top].
const KEEP_CLEAR: Array = [[Vector3(-27.0, 0, -80.8), Vector3(-47.5, 0, -72.6), 4.5, -27.0, -6.0],
	[Vector3(-37.8, 0, -206.8), Vector3(-45.3, 0, -204.1), 3.5, -25.0, -12.0]]
## Where a deck arrives over a terrace's edge, which has no parapet there.
const OPEN_EDGES: Array[Vector3] = [Vector3(-38.9, -24.0, -206.4)]


## Whether something of radius r at p stands in a KEEP_CLEAR volume.
func _blocked(p: Vector3, r: float = 0.0) -> bool:
	for c: Array in KEEP_CLEAR:
		if p.y < c[3] or p.y > c[4]:
			continue
		var a := Vector2(c[0].x, c[0].z)
		var b := Vector2(c[1].x, c[1].z)
		var q := Vector2(p.x, p.z)
		var t: float = clampf((q - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
		if q.distance_to(a.lerp(b, t)) < float(c[2]) + r:
			return true
	return false


## A stair up tier i's face from the terrace below (tier i-1's roof) to its
## own roof: one flight per storey in consecutive bays, on the run that faces
## the Overlook most squarely, the whole of it over the terrace. Under each
## upper flight a brick pier with a niche per storey fills down to the
## terrace (your walk: flights hung on stepped undersides). Not in a
## KEEP_CLEAR volume. Better (your walk: no room at its top, a narrow way to
## its foot) where its top arrives on roof room to walk on, there is a way to
## its foot (3 m of terrace along the face before it), and
## no feature (an iwan's stepped-forward building) stands beside either end;
## without one anywhere, a stair still goes up. Every flight has headroom
## (_headroom); where the tier above overhangs the face, so that its top
## flight would ram into it (your walk), the stair ends a storey short on a
## landing (persian_stair_landing) at a door into the top storey.
func _stair(i: int) -> void:
	var storeys: int = tiers[i]["storeys"]
	var best: Array = []
	var best_score: float = -INF
	for r: Dictionary in runs[i]:
		var cells: Array = r["cells"]
		var side: int = r["side"]
		if r["inner"] and ornament > 0.0:
			continue     # not up a clearing's sides, onto its roof
		for k: int in range(0, cells.size() - storeys + 1):
			var ok: bool = true
			var clear: Array[bool] = []      # per bay: its flight has headroom
			for b: int in range(k, k + storeys):
				var xf: Transform3D = _xf(i, cells[b], side, 0)
				ok = ok and not taken.has(_key(i, cells[b], side, 0)) and not reserved.has(_key(i, cells[b], side))
				for p: Vector3 in [Vector3(.4, -.2, .4), Vector3(3.6, -.2, .4), Vector3(.4, -.2, 1.6), Vector3(3.6, -.2, 1.6)]:
					ok = ok and _on_roof(i - 1, xf * p)
				for p: Vector3 in [Vector3(0, 0, .9), Vector3(4, 0, .9)]:
					ok = ok and not _blocked(xf * p + Vector3(0, BAY * (b - k), 0), 1.0) and not _blocked(xf * p + Vector3(0, BAY * (b - k + 1), 0), 1.0)
				clear.append(_headroom(i, xf, b - k))
			if not ok:
				continue
			var full: bool = not clear.has(false)
			var to_door: bool = false
			if not full and storeys > 1:
				to_door = not clear.slice(0, storeys - 1).has(false) and _landing_headroom(i, _xf(i, cells[k + storeys - 1], side, storeys - 1))
			if not full and not to_door:
				continue
			var foot: Transform3D = _xf(i, cells[k], side, 0)
			var landing: Transform3D = _xf(i, cells[k + storeys - 1], side, storeys)
			var room_top: bool = to_door or _on_roof(i, landing * Vector3(3.0, 0, -1.2))
			# Its foot is reached along the face (its parapet closes its open side).
			var way_in: bool = true
			for p: Vector3 in [Vector3(-1.0, -.2, .4), Vector3(-1.0, -.2, 1.6), Vector3(-3.0, -.2, .4), Vector3(-3.0, -.2, 1.6)]:
				way_in = way_in and _on_roof(i - 1, foot * p)
			var free_ends: bool = (k == 0 or not taken.has(_key(i, cells[k - 1], side, 0))) \
				and (k + storeys >= cells.size() or not taken.has(_key(i, cells[k + storeys], side, 0)))
			var score: float = r["eye"] + (1.0 if room_top else 0.0) + (1.0 if way_in else 0.0) + (1.0 if free_ends else 0.0) + (2.0 if full else 0.0)
			if score > best_score:
				best_score = score
				best = [r, k, full]
	if best.is_empty():
		return
	var r: Dictionary = best[0]
	var full: bool = best[2]
	for s: int in storeys:
		var cell: Vector2i = r["cells"][best[1] + s]
		var at: Transform3D = _xf(i, cell, r["side"], s)
		stair_feet.append(_xf(i, cell, r["side"], 0) * Vector3(2, 0, .8))
		if full:
			# The top flight's parapet closes its far end (your walk: it ended in a drop).
			_put("persian_stair_flight_top" if s == storeys - 1 else "persian_stair_flight", at)
		else:
			_put("persian_stair_landing" if s == storeys - 1 else "persian_stair_flight", at)
		for st: int in s:
			_put("persian_stair_pier", _xf(i, cell, r["side"], st))
		for st: int in storeys:
			plain[_key(i, cell, r["side"], st)] = true
	var last: Vector2i = r["cells"][best[1] + storeys - 1]
	if full:
		no_edge[_key(i, last, r["side"])] = true
	else:
		doors[_key(i, last, r["side"], storeys - 1)] = true
		plain.erase(_key(i, last, r["side"], storeys - 1))


## Headroom over a landing at `xf` (a storey's floor): as _headroom.
func _landing_headroom(i: int, xf: Transform3D) -> bool:
	for x: float in [.4, 2.0, 3.6]:
		for z: float in [.3, 1.0, 1.7]:
			var p: Vector3 = xf * Vector3(x, STAIR_HEADROOM, z)
			for u: int in range(i + 1, tiers.size()):
				if float(tiers[u]["bottom"]) < p.y and g._covered(tiers[u], p):
					return false
	return true


## Whether the flight up bay `xf` from storey s of tier i (rising along +X
## over the bay, 0.2 to 1.8 m out from the face) has STAIR_HEADROOM over its
## steps and its top: no tier above hangs lower over it (your walk: a stair
## rammed into the building overhanging it).
const STAIR_HEADROOM: float = 2.4


func _headroom(i: int, xf: Transform3D, s: int) -> bool:
	for x: float in [.4, 2.0, 3.6, 4.4]:
		for z: float in [.3, 1.0, 1.7]:
			var p: Vector3 = xf * Vector3(x, BAY * s + minf(x, BAY) + STAIR_HEADROOM, z)
			for u: int in range(i + 1, tiers.size()):
				if float(tiers[u]["bottom"]) < p.y and g._covered(tiers[u], p):
					return false
	return true


# ------------------------------------------------------------------ a tier

func _tier(t: int, seed_value: int) -> void:
	var tier: Dictionary = tiers[t]
	var frame: Transform3D = tier["frame"]
	var cells: Dictionary = tier["cells"]
	var storeys: int = tier["storeys"]
	var above: Dictionary = tiers[t + 1] if t + 1 < tiers.size() else {}
	var below: Dictionary = tiers[t - 1] if t > 0 else {}
	var crowned: bool = tier["crowned"]
	# Carved fronts grow toward the mist and toward the cavern's roof (Q5).
	var carved_p: float = .25 + (.35 if tier["bottom"] < -125.0 else 0.0) + (.2 if t >= tiers.size() - 2 else 0.0)
	carved_p *= 1.0 - ornament * .8     # built and ornamented, not cut from the rock, further out
	for r: Dictionary in runs[t]:
		var list: Array = r["cells"]
		var side: int = r["side"]
		# The sanctum stands mid-gorge, seen from every side.
		var grand_p: float = _grand_share() if (r["eye"] > GRAND_EYE or sanctum) and storeys >= 2 else 0.0
		var b: int = 0
		var building: int = 0
		var tops: Array[Dictionary] = []
		while b < list.size():
			var h: float = GorgeGrammar._hash01(Vector3(frame.origin.x + b, tier["bottom"], frame.origin.z + side * 7.0))
			var length: int = mini(1 + int(h * 3.0), list.size() - b)
			# Most faces have the tier above flush over them, no roof for a dome:
			# where there is one, more of them are grand.
			var glen: int = mini(GRAND_MIN + int(fposmod(h * 5.3, 1.0) * 3.0), list.size() - b)
			var grand: bool = grand_p > 0.0 and glen >= GRAND_MIN and (fposmod(h * 23.1, 1.0) < grand_p
				or (fposmod(h * 29.0, 1.0) < grand_p * 3.0 and _roof_depth(t, list, side, b, glen) >= GRAND_ROOF))
			# A clearing's building starts where it was chosen; the one before
			# it ends there.
			var clearing: bool = forced.has(_key(t, list[b], side))
			if clearing:
				grand = true
				glen = mini(forced[_key(t, list[b], side)], list.size() - b)
			else:
				for j: int in range(b + 1, b + maxi(length, glen if grand else 0)):
					if j < list.size() and forced.has(_key(t, list[j], side)):
						length = j - b
						glen = j - b
						grand = grand and glen >= GRAND_MIN
						break
			if grand:
				length = glen
				_grand_portal(t, list, side, b, length)
			var kind: String = "monument" if grand else ("carved" if fposmod(h * 13.7, 1.0) < carved_p else "house")
			var tint: String = _tint(fposmod(h * 7.3, 1.0))
			var door_bay: int = b + length / 2
			# Buildings stand a little in or out of the run (their side walls show),
			# so neighbours read as separate houses, not one long wall.
			var off: float = WALL_PROUD if kind == "monument" else [WALL_PROUD, .45, .2][int(fposmod(h * 31.0, 1.0) * 3.0)]
			for k: int in range(b, b + length):
				tops.append(_bay(t, list[k], side, kind, tint, k == door_bay, below, above, crowned, off))
			if grand and not (sanctum and crowned):     # the sanctum's top carries its rotunda
				_grand_roof(t, list, side, b, length, h, clearing)
			b += length
			building += 1
		_joins(t, list, side, tops)
		_roof_life(t, r, above)
	_decks(t, frame, cells, storeys, above, below)


## The grand buildings (your direction: the further a bank, the more
## ornamental, the furthest mostly monuments and grand buildings): from
## GRAND_FROM on a share of the buildings on runs the walkways see wear the
## monument's front (brick arcades, orosi, the crown), GRAND_MAX of them at
## the furthest bank; on a three-storey tier a long one has a portal rising
## above its roof, and their roofs carry a dome and minarets where there is
## room to walk round them.
const GRAND_FROM: float = .45
const GRAND_MAX: float = .85
const GRAND_EYE: float = .2          # runs that look this squarely toward the Overlook or more
const GRAND_MIN: int = 2             # bays
const GRAND_WALK: float = 3.0        # roof kept to walk behind a dome or minaret
## [piece, radius, height]: the plain dome over three bays and more, the small
## one over two.
const GRAND_DOMES: Array = [["persian_dome", 4.6, 17.0], ["persian_dome_small", 2.6, 7.5]]
const MINARET_R: float = 1.5
const MINARET_TOP: float = 26.0


const GRAND_ROOF: float = 9.4        # roof the small dome needs, with the walk behind it


## The clearings (your call, bank 5): over the grand buildings the walkways
## see best, the tiers above are cut away as over bank 1's monument, so their
## domes and minarets stand mid-stack, open to the cavern; one at the first
## grand bank, CLEAR_MORE more by the furthest. A clearing is CLEAR_BAYS wide
## and CLEAR_DEPTH deep on its tier's roof (the plain dome, minarets either
## side, a walk behind), open CLEAR_SIGHT out in front (as the monument), CLEAR_SPACING apart,
## clear of the frontage slots the links reach at any height above it (the
## link table sees the uncut tiers).
const CLEAR_BAYS: int = 4           # the plain dome with a minaret either side
const CLEAR_DEPTH: float = 14.0
const CLEAR_SIGHT: float = 16.0       # as MON_SIGHT: tiers above can jut 13 m past the face (bank 6)
const CLEAR_SPACING: float = 30.0
const CLEAR_MORE: float = 4.0
const CLEAR_LOWEST: float = -70.0    # its roof above the thick of the mist


func _clearings() -> void:
	var share: float = _grand_share()
	if share <= 0.0:
		return
	var w: float = CLEAR_BAYS * BAY
	for n: int in 1 + roundi(share / GRAND_MAX * CLEAR_MORE):
		var best: Array = _clear_spot(w)
		if best.is_empty() and not _walk_blind():
			_middle = true     # as the iwans (_iwan)
			best = _clear_spot(w)
			_middle = false
		if best.is_empty():
			return
		var t: int = best[0]
		var r: Dictionary = best[1]
		var k: int = best[2]
		var top_xf: Transform3D = _xf(t, r["cells"][k], r["side"], tiers[t]["storeys"])
		_cut_above(t, top_xf, func(l: Vector3) -> bool:
			return l.x > -1.0 and l.x < w + 1.0 and l.z > -CLEAR_DEPTH - 1.0 and l.z < CLEAR_SIGHT)
		forced[_key(t, r["cells"][k], r["side"])] = CLEAR_BAYS
		for j: int in range(k, k + CLEAR_BAYS):
			reserved[_key(t, r["cells"][j], r["side"])] = true
		clearings.append({"t": t, "p": top_xf * Vector3(w * .5, 0, -CLEAR_DEPTH * .5), "xf": top_xf})


## The best place for a clearing, [t, run, bay], or [].
func _clear_spot(w: float) -> Array:
	var best: Array = []
	var best_score: float = -INF
	for t: int in range(1, tiers.size() - 1):
		var storeys: int = tiers[t]["storeys"]
		if storeys < 2 or _top(t) < CLEAR_LOWEST:
			continue
		for r: Dictionary in runs[t]:
			var facing: float = maxf(r["eye"], r["axis"] if _middle else -1.0)
			if r["inner"] or facing < .3 or r["cells"].size() < CLEAR_BAYS:
				continue
			for k: int in range(0, r["cells"].size() - CLEAR_BAYS + 1):
				var top_xf: Transform3D = _xf(t, r["cells"][k], r["side"], storeys)
				var base: float = facing - absf(_top(t) - MON_HEIGHT) * .012
				if base + 2.0 <= best_score or not _clear_fits(t, r, k, top_xf, w):
					continue
				var seen: float = _seen_fraction(_xf(t, r["cells"][k], r["side"], 0) * Transform3D(Basis(), Vector3(2, 0, 0)), storeys)
				if seen < IWAN_SEEN:
					continue
				if base + seen * 2.0 > best_score:
					best_score = base + seen * 2.0
					best = [t, r, k]
	return best


## Whether p (in plan) is inside a cavern spur's quarried drum, grown by
## `margin`: it rises to the bank's top and hides what stands in it (bank 6's
## first clearing).
func _in_spur(p: Vector3, margin: float) -> bool:
	for s: Array in CAVERN.SPURS:
		if Vector2(p.x - float(s[0]), p.z - float(s[1])).length() < float(s[2]) * CAVERN.QUARRIED_RADIUS + margin:
			return true
	return false


## Whether p is inside the sanctum's tiers or within a metre of them: a
## feature facing into them is hidden (your walk: bank 8's first clearing
## sank among its terraces).
func _fronted(p: Vector3) -> bool:
	return GorgeGrammar.solid_at(others, p, 1.0)


## Whether p is on a clearing's roof or within `margin` of it.
func _in_clearing(p: Vector3, margin: float) -> bool:
	for c: Dictionary in clearings:
		var l: Vector3 = (c["xf"] as Transform3D).affine_inverse() * p
		if absf(l.y) < 6.0 and l.x > -margin and l.x < CLEAR_BAYS * BAY + margin and l.z > -CLEAR_DEPTH - margin and l.z < margin:
			return true
	return false


## Whether a clearing can stand on bays k.. of run r on tier t: its tier's
## roof runs CLEAR_DEPTH back, its bays are free, no garden is there, no
## other clearing is near or would be cut by it, and no frontage slot stands
## in the column it opens.
func _clear_fits(t: int, r: Dictionary, k: int, top_xf: Transform3D, w: float) -> bool:
	for j: int in range(k, k + CLEAR_BAYS):
		for s: int in tiers[t]["storeys"]:
			if taken.has(_key(t, r["cells"][j], r["side"], s)):
				return false
	for x: float in [.5, w * .5, w - .5]:
		for d: float in [.5, CLEAR_DEPTH * .5, CLEAR_DEPTH - .5]:
			if not g._covered(tiers[t], top_xf * Vector3(x, 0, -d)):
				return false
	var mid: Vector3 = top_xf * Vector3(w * .5, 0, -CLEAR_DEPTH * .5)
	if _in_garden(mid, 8.0):
		return false
	# A spur's drum may close its back (bank 5), not stand on its dome's place
	# or in front of it (bank 6's first try).
	if _in_spur(top_xf * Vector3(w * .5, 0, -6.0), 0.0):
		return false
	for x: float in [-1.0, w * .5, w + 1.0]:
		for d: float in [1.0, CLEAR_SIGHT * .5, CLEAR_SIGHT]:
			if _in_spur(top_xf * Vector3(x, 0, d), 1.0) or _fronted(top_xf * Vector3(x, .5, d)) or _fronted(top_xf * Vector3(x, 10.0, d)):
				return false
	for y: float in [2.0, 10.0, 18.0, 26.0]:     # its dome and minarets, not in or under the sanctum
		for x: float in [-1.0, w * .5, w + 1.0]:
			for d: float in [-1.0, -6.0, -CLEAR_DEPTH + 1.0]:
				if _fronted(top_xf * Vector3(x, y, d)):
					return false
	var inv: Transform3D = top_xf.affine_inverse()
	var in_column := func(p: Vector3, margin: float) -> bool:
		var l: Vector3 = inv * p
		return l.y > -1.0 and l.x > -1.0 - margin and l.x < w + 1.0 + margin and l.z > -CLEAR_DEPTH - 1.0 - margin and l.z < CLEAR_SIGHT + margin
	for c: Dictionary in clearings:
		if (c["p"] as Vector3).distance_to(mid) < CLEAR_SPACING or in_column.call(c["p"], 4.0):
			return false
	for q: Vector3 in iwans:
		for x: float in [0.0, 4.0, 8.0]:
			if in_column.call(q + Vector3(x, 0, 0), 4.0) or in_column.call(q + Vector3(-x, 0, 0), 4.0):
				return false     # an iwan's tier stands over it
	for s: FrontageSlot in slots:
		for x: int in range(0, s.width * 4 + 1, 2):
			for z: float in [0.0, -2.0, -4.0]:
				if in_column.call(s.xf * Vector3(x, 0, z), 3.0):
					return false
	return not slot_z


func _grand_share() -> float:
	return clampf((ornament - GRAND_FROM) / (1.0 - GRAND_FROM), 0.0, 1.0) * GRAND_MAX


## How deep the open roof is behind the middle of bays b..b+length (metres).
func _roof_depth(t: int, list: Array, side: int, b: int, length: int) -> float:
	var a: Transform3D = _xf(t, list[b], side, tiers[t]["storeys"])
	var d: float = 0.0
	while d < 20.0 and _on_roof(t, a * Vector3(length * BAY * .5, 0, -d - .25)) and _open_above(t, a * Vector3(length * BAY * .5, 0, -d - .25)):
		d += .5
	return d


## The pishtaq (persian_portal, 12 x 16 m, 1.5 m proud) over a grand
## building's middle three bays on a three-storey tier: its screen on the
## terrace in front, with a way past it, and open roof behind its top.
func _grand_portal(t: int, list: Array, side: int, b: int, length: int) -> void:
	if tiers[t]["storeys"] != 3 or length < 3 or t == 0:
		return
	var k: int = b + (length - 3) / 2
	for j: int in range(k, k + 3):
		for s: int in 3:
			var key: String = _key(t, list[j], side, s)
			if taken.has(key) or plain.has(key) or doors.has(key):
				return
	var xf: Transform3D = _xf(t, list[k], side, 0)
	var top: Transform3D = _xf(t, list[k], side, 3)
	for x: float in [.5, 6.0, 11.5]:
		for d: float in [1.0, 3.5]:
			var p: Vector3 = xf * Vector3(x, -.2, d)
			if not _on_roof(t - 1, p) or not _open_above(t, p) or _in_garden(p, 6.0) or _blocked(p + Vector3(0, 8, 0), 2.0):
				return
		var q: Vector3 = top * Vector3(x, 0, -2.2)
		if not _on_roof(t, q) or not _open_above(t, q):
			return
	_put("persian_portal", xf, 16.0)
	for j: int in range(k, k + 3):
		_take(t, list[j], side, range(3))
		no_edge[_key(t, list[j], side)] = true


## A grand building's roof: a dome on it, set in from its face, with roof to
## walk behind it, and a minaret at either end of the longer ones, all clear
## of the tiers above, gardens and stairs. Its size from a hash `h`.
func _grand_roof(t: int, list: Array, side: int, b: int, length: int, h: float, clearing: bool = false) -> void:
	var storeys: int = tiers[t]["storeys"]
	var a: Transform3D = _xf(t, list[b], side, storeys)
	var w: float = length * BAY
	var room := func(p: Vector3, r: float) -> bool:
		if not _on_roof(t, p) or not _open_above(t, p) or _in_garden(p, 6.0) or _blocked(p, r) or (r > 0.0 and _in_spur(p, r * .5)) \
				or _fronted(p + Vector3(0, 2.0, 0)) or _fronted(p + Vector3(0, 10.0, 0)):     # a dome may graze a drum, not stand in it (nor in the sanctum)
			return false
		for f: Vector3 in stair_feet:
			if absf(f.y - p.y) < 1.0 and Vector2(f.x - p.x, f.z - p.z).length() < r + 2.5:
				return false
		return true
	var dome_r: float = 0.0
	var found: Array[Dictionary] = []
	for dome: Array in GRAND_DOMES:
		var r: float = dome[1]
		if 2.0 * r + 1.0 > w:
			continue
		var c: Vector3 = a * Vector3(w * .5, 0, -r - 1.2)
		var ok: bool = room.call(c, r)
		for x: float in [-r, 0.0, r]:
			ok = ok and room.call(c + a.basis * Vector3(x, 0, -r - GRAND_WALK), 0.0)
		for k: int in 8:
			ok = ok and room.call(c + Basis(Vector3.UP, k * PI * .25) * Vector3(r + .3, 0, 0), 0.0)
		if ok:
			_put(dome[0], Transform3D(a.basis, c), dome[2])
			found.append({"p": c, "r": r + 1.0, "kind": "monument"})
			dome_r = r
			break
	if length >= 3 and (clearing or fposmod(h * 41.0, 1.0) < .7):
		for x: float in [MINARET_R + .1, w - MINARET_R - .1]:
			if dome_r > 0.0 and absf(x - w * .5) < dome_r + MINARET_R + .2:
				continue     # the dome fills the roof
			var c: Vector3 = a * Vector3(x, 0, -MINARET_R - .5)
			var ok: bool = room.call(a * Vector3(x, 0, -MINARET_R * 2.0 - .5 - GRAND_WALK), 0.0)
			for k: int in 8:
				ok = ok and room.call(c + Basis(Vector3.UP, k * PI * .25) * Vector3(MINARET_R, 0, 0), 0.0)
			if ok:
				_put("persian_minaret", Transform3D(a.basis, c), MINARET_TOP)
				found.append({"p": c, "r": MINARET_R + .5, "kind": "monument"})
	zones.append_array(found)


## One bay of a building, all its storeys, and its top edge.
## Returns what it built at its top: {off, edge (a parapet piece or ""),
## cornice}, for _joins.
func _bay(t: int, cell: Vector2i, side: int, kind: String, tint: String, door_bay: bool, below: Dictionary, above: Dictionary, crowned: bool, off: float = 0.0) -> Dictionary:
	var storeys: int = tiers[t]["storeys"]
	if plain.has(_key(t, cell, side, 0)) or taken.has(_key(t, cell, side, 0)):
		off = WALL_PROUD     # a stair stands against it, or a feature beside it
	bay_off[_key(t, cell, side)] = off
	var built: Dictionary = {"off": off, "edge": "", "cornice": false}
	var shift := Transform3D(Basis(), Vector3(0, 0, off))
	for s: int in storeys:
		if taken.has(_key(t, cell, side, s)):
			continue
		var xf: Transform3D = _xf(t, cell, side, s) * shift
		var lit: bool = g._noise.get_noise_3dv(xf * Vector3(2, 2, 0)) > -.05
		var h: float = GorgeGrammar._hash01(xf.origin * 1.3)
		var on_terrace: bool = s == 0 and not below.is_empty() and _on_roof(t - 1, xf * Vector3(2, -.2, 1.2))
		var piece: String
		if doors.has(_key(t, cell, side, s)):
			piece = {"house": "persian_wall_%s_door" % tint, "carved": "persian_wall_rock_door" + ("" if lit else "_dark"), "monument": "persian_wall_brick_arcade"}[kind]
		elif plain.has(_key(t, cell, side, s)):
			piece = {"house": "persian_wall_" + tint, "carved": "persian_wall_rock", "monument": "persian_wall_brick"}[kind]
		elif kind == "monument":
			if s == 0:
				piece = "persian_wall_brick_arcade" if lit else "persian_wall_brick_arcade_dark"
			elif s == 1:
				piece = "persian_wall_brick_orosi" if h < .5 else "persian_wall_brick_arcade_dark"
			else:
				piece = "persian_wall_brick"
		else:
			# Houses (your report: too plain next to the old banks): few blank
			# walls, paired windows on upper storeys, an oriel on some blank upper
			# walls, an awning over some doors, a banner from some parapets.
			var wall: String = "persian_wall_" + (tint if kind == "house" else "rock")
			var top_storey: bool = s == storeys - 1
			if on_terrace and door_bay:
				piece = wall + "_door" + ("" if kind == "house" or lit else "_dark")
				if lit and g._noise.get_noise_3dv(xf.origin) > -.2:
					_put("persian_lamp_bracket", xf * Transform3D(Basis(), Vector3(2.95 if kind == "house" else 3.1, 2.7, 0)))
				elif kind == "house" and h > .55:
					_put("persian_awning", xf)
			elif h < (.1 if s == 0 else .16):
				piece = wall
				if kind == "house" and s > 0 and not top_storey and h > .05:
					_put("persian_oriel", xf)
				elif kind == "house" and top_storey and h > .04 and not g._covered(above, _xf(t, cell, side, storeys) * Vector3(2, .5, -.4)):
					_dress("dressing/gorge_banner_%d" % (int(h * 300.0) % 3), xf * Transform3D(Basis(), Vector3(2, BAY - .62, .3)))
			elif kind == "house" and s > 0 and fposmod(h * 17.0, 1.0) < .45:
				piece = wall + "_window2" + ("" if lit else "_dark")
			else:
				piece = wall + "_window" + ("" if lit else "_dark")
			if kind == "carved" and h > .91 and _zone(xf.origin) == "dark":
				_put("persian_glowmoss", xf * _vines_at(piece, h))
		_put(piece, xf)
	# The top edge: a parapet on a house's or carved front's roof, the crown on
	# a monument; none under the tier above, where the water pours or a stair
	# arrives.
	var top_xf: Transform3D = _xf(t, cell, side, storeys) * shift
	if no_edge.has(_key(t, cell, side)) or g._covered(above, top_xf * Vector3(2, .5, -.4)):
		return built
	var edge: String = {"house": "persian_parapet" + {"lime": "_lime", "banai": "_banai", "tile": "_banai"}.get(tint, ""), "carved": "persian_parapet_rock", "monument": "persian_crown"}[kind]
	_put(edge, top_xf)
	built["edge"] = edge
	if kind == "house" and not taken.has(_key(t, cell, side, storeys - 1)):
		_put("persian_cornice", _xf(t, cell, side, storeys - 1) * shift)     # finishes the wall under its parapet
		built["cornice"] = true
	var cells: Dictionary = tiers[t]["cells"]
	if not cells.has(GorgeGrammar._before(cell, side)):
		_put("persian_parapet_corner", top_xf)
	return built


## Brackets under the tier above where it overhangs tier t's face by more
## than OVERHANG_MIN (your report: large overhangs should be visibly carried
## by the wall under them): one at each of tier t's bay edges (always clear
## of its windows, doors and oriels), stretched from the wall out to the
## overhang's edge, deeper overhangs carried by taller brackets. Not where a
## stair climbs the face or a feature stands.
const OVERHANG_MIN: float = 1.2


func _supports(t: int) -> void:
	var storeys: int = tiers[t]["storeys"]
	var above: Dictionary = tiers[t + 1]
	for r: Dictionary in runs[t]:
		var list: Array = r["cells"]
		var side: int = r["side"]
		for k: int in list.size() + 1:
			var cell: Vector2i = list[mini(k, list.size() - 1)]
			var x: float = 0.0 if k < list.size() else BAY
			var near: Array = [list[k - 1]] if k == list.size() else ([list[k], list[k - 1]] if k > 0 else [list[k]])
			var skip: bool = false
			for c: Vector2i in near:
				for s: int in storeys:
					skip = skip or taken.has(_key(t, c, side, s)) or plain.has(_key(t, c, side, s))
			if skip:
				continue
			var off: float = 0.0
			for c: Vector2i in near:
				off = maxf(off, float(bay_off.get(_key(t, c, side), WALL_PROUD)))
			var top_xf: Transform3D = _xf(t, cell, side, storeys)
			var n: Vector3 = Vector3(top_xf.basis.z.x, 0, top_xf.basis.z.z).normalized()
			var p: Vector3 = top_xf * Vector3(x, 0, off)
			var d: float = 0.0
			while d < 8.0 and g._covered(above, p + n * (d + .25) + Vector3(0, .5, 0)):
				d += .25
			if d < OVERHANG_MIN:
				continue
			var h: float = clampf(d * .7, .8, 2.4)
			_put("persian_corbel", Transform3D(top_xf.basis * Basis.from_scale(Vector3(1, h, d)), p))
## (and cornices) end apart (your report: the rail "should not be
## disconnected"): a short return runs between them at the step, an L joint,
## in the prouder building's parapet.
func _joins(t: int, list: Array, side: int, tops: Array[Dictionary]) -> void:
	var storeys: int = tiers[t]["storeys"]
	for k: int in range(1, tops.size()):
		var a: Dictionary = tops[k - 1]
		var b: Dictionary = tops[k]
		var gap: float = absf(float(a["off"]) - float(b["off"]))
		if gap < .05 or a["edge"] == "" or b["edge"] == "" or a["edge"] == "persian_crown" or b["edge"] == "persian_crown":
			continue
		var b_proud: bool = float(b["off"]) > float(a["off"])
		var proud: Dictionary = b if b_proud else a
		var lo: float = minf(a["off"], b["off"]) - .05
		var hi: float = maxf(a["off"], b["off"]) + .05
		var stretch := Basis.from_scale(Vector3((hi - lo) / BAY, 1, 1))
		# Turned so the piece runs across the step from the deeper face to the
		# prouder one, its thickness (and a cornice's projection) on the deeper
		# building's side of the prouder one's exposed side wall.
		var turn := Basis(Vector3.UP, -PI * .5) if b_proud else Basis(Vector3.UP, PI * .5)
		var origin_z: float = lo if b_proud else hi
		_put(proud["edge"], _xf(t, list[k], side, storeys) * Transform3D(turn * stretch, Vector3(0, 0, origin_z)))
		if a["cornice"] and b["cornice"]:
			_put("persian_cornice", _xf(t, list[k], side, storeys - 1) * Transform3D(turn * stretch, Vector3(0, 0, origin_z)))


## Life on a run's roof (the terrace behind its parapet): by the light, a
## planted bed and cypresses (sun, gem) or a fungal bed, giant or jelly fungi
## and a teal glow (dark); some house roofs a windcatcher instead.
func _roof_life(t: int, r: Dictionary, above: Dictionary) -> void:
	var list: Array = r["cells"]
	if list.size() < 2:
		return
	var mid: int = list.size() / 2
	var xf: Transform3D = _xf(t, list[mid], r["side"], tiers[t]["storeys"])
	var at: Vector3 = xf * Vector3(2, 0, -2.6)
	if not _on_roof(t, at) or _in_garden(at):
		return
	var h: float = GorgeGrammar._hash01(at * .7)
	var zone: String = _zone(at)
	var turn := Basis(Vector3.UP, 0.0)
	if zone == "dark":
		if h < .2:
			_put("persian_windcatcher", Transform3D(xf.basis, at))
			return
		_put("persian_bed_fungal", Transform3D(xf.basis * turn, at))
		var big: Vector3 = xf * Vector3(2 + (5.0 if h > .5 else -3.0), 0, -3.2)
		if _on_roof(t, big):
			_put("persian_fungus_giant_9" if h > .75 else ("persian_fungus_jelly" if h > .45 else "persian_fungus_giant_6"), Transform3D(xf.basis, big))
		var small: Vector3 = xf * Vector3(2 - (4.0 if h > .5 else -4.5), 0, -2.0)
		if _on_roof(t, small):
			_put("persian_fungus_cluster" if h < .6 else "persian_fungus_small", Transform3D(xf.basis, small))
		# Its teal light only where no other is within TEAL_SPACING: the fungi glow
		# by their own material, and a dark bank (bank 2) asked for 23 lights.
		var lit: bool = true
		for q: Vector3 in teal_lights:
			lit = lit and q.distance_to(at) > TEAL_SPACING
		if lit:
			teal_lights.append(at)
			_light(at + Vector3(0, 2.5, 0), TEAL, 1.6, 9.0)
	else:
		_put("persian_bed", Transform3D(xf.basis, at))
		for x: float in [-1.0, 5.0]:
			var p: Vector3 = xf * Vector3(x, 0, -2.6)
			if _on_roof(t, p):
				_dress("dressing/gorge_cypress_6", Transform3D(xf.basis, p))


## Roofs on a tier's open cells, soffits where it overhangs the tier below,
## and its stone core (GorgeGrammar._tier's rules), but not behind an iwan.
func _decks(t: int, frame: Transform3D, cells: Dictionary, storeys: int, above: Dictionary, below: Dictionary) -> void:
	var rects: Array = []     # the core's cells: [lo, hi] in the tier's plan
	for cell: Vector2i in cells:
		var corners: Array[Vector3] = []
		for k: Vector2 in [Vector2(.05, .05), Vector2(3.95, .05), Vector2(.05, 3.95), Vector2(3.95, 3.95)]:
			corners.append(frame * Vector3(cell.x * BAY + k.x, 0, -cell.y * BAY - k.y))
		var open_top: bool = false
		var open_under: bool = false
		for c: Vector3 in corners:
			open_top = open_top or not g._covered(above, c + Vector3(0, storeys * BAY, 0))
			open_under = open_under or (not below.is_empty() and not g._covered(below, c - Vector3(0, .5, 0)))
		if open_top:
			_put("persian_roof", frame * CellGrid.cell_transform(Vector3i(cell.x, storeys, cell.y), Vector3i(0, 0, 1)) * Transform3D(Basis(), Vector3(0, -ROOF_DROP, 0)))
		if open_under:
			out.append(g._piece("walls/gorge_soffit", frame * CellGrid.cell_transform(Vector3i(cell.x, 0, cell.y), Vector3i(0, 0, 1)) * Transform3D(Basis(), Vector3(0, -SOFFIT_DROP, 0))))
		if no_core.has("%d:%d,%d" % [t, cell.x, cell.y]):
			continue
		var inset: float = GorgeGrammar.CORE_INSET
		var lo := Vector2(cell.x * BAY + (inset if not cells.has(cell + Vector2i(-1, 0)) else 0.0), cell.y * BAY + (inset if not cells.has(cell + Vector2i(0, -1)) else 0.0))
		var hi := Vector2((cell.x + 1) * BAY - (inset if not cells.has(cell + Vector2i(1, 0)) else 0.0), (cell.y + 1) * BAY - (inset if not cells.has(cell + Vector2i(0, 1)) else 0.0))
		rects.append([lo, hi])
	# Cells that meet merged into larger boxes (the budget check: a box a cell
	# was 48,000 boxes, drawn three times with the shadows); the faces between
	# them were never seen.
	var height: float = storeys * BAY - GorgeGrammar.CORE_INSET
	for r: Array in _merge_rects(rects):
		var lo: Vector2 = r[0]
		var hi: Vector2 = r[1]
		out.append({"stone": frame * Transform3D(Basis(), Vector3((lo.x + hi.x) * .5, height * .5, -(lo.y + hi.y) * .5)),
			"size": Vector3(hi.x - lo.x, height, hi.y - lo.y), "material": "gorge_stone"})


## Rectangles [lo, hi] merged where two share a whole edge: along x first
## (same y extent, meeting), then along y (same x extent, meeting).
static func _merge_rects(rects: Array) -> Array:
	var merged: Array = rects.duplicate()
	for axis: int in [0, 1]:
		var other: int = 1 - axis
		merged.sort_custom(func(a: Array, b: Array) -> bool:
			if not is_equal_approx(a[0][other], b[0][other]):
				return a[0][other] < b[0][other]
			if not is_equal_approx(a[1][other], b[1][other]):
				return a[1][other] < b[1][other]
			return a[0][axis] < b[0][axis])
		var out: Array = []
		for r: Array in merged:
			if not out.is_empty():
				var last: Array = out[-1]
				if is_equal_approx(last[0][other], r[0][other]) and is_equal_approx(last[1][other], r[1][other]) and is_equal_approx(last[1][axis], r[0][axis]):
					var hi: Vector2 = last[1]
					hi[axis] = r[1][axis]
					out[-1] = [last[0], hi]
					continue
			out.append([r[0], r[1]])
		merged = out
	return merged


# ---------------------------------------------------------- the camp's cliff

## The cliff round the camp's loggia (phase 8 step 3; was GorgeGrammar.cliff's
## library bays): in each of `zones` (vista_cliff.gd FACADES: x, y, width,
## height on the face at `face_z`, which looks toward -Z) a cliff village.
## Tall zones are bands of two storeys, each on a rock-cut ledge path along
## the face: dwellings carved into the rock and plaster or lime house fronts
## built against it, a door per building onto its ledge, lanterns, oriels,
## glowing moss on dark rock. A stair tower at the zone's inner end (by the
## pishtaq) climbs the whole height with a door onto every ledge, so each
## level has its way up. A low zone (over the pishtaq) is a row of rock-cut
## windows and oriels under a rock parapet.
const TOWER_OUT: float = 2.9       # the stair tower's front, out from the face
const TOWER_DOOR: float = 1.1      # its side door pieces start this far into the rock (door 0.9 m out, over the ledge)


func cliff(zones: Array[Rect2], face_z: float) -> Array[Dictionary]:
	for zone: Rect2 in zones:
		var bays: int = roundi(zone.size.x / BAY)
		var storeys: int = roundi(zone.size.y / BAY)
		# Bay i's frame: turned to face -Z, its local x 0 at the bay's +x end.
		var bay_xf := func(i: int, s: int) -> Transform3D:
			return Transform3D(Basis(Vector3.UP, PI), Vector3(zone.position.x + (i + 1) * BAY, zone.position.y + s * BAY, face_z))
		if storeys < 6:
			_cliff_windows(bays, storeys, bay_xf)
			continue
		# The inner end: the one nearer the pishtaq (x 0).
		var tower: int = bays - 1 if absf(zone.position.x + zone.size.x) < absf(zone.position.x) else 0
		_cliff_tower(tower, storeys, bay_xf, tower == 0)
		for band: int in range(0, storeys, 2):
			var top_band: bool = band + 2 >= storeys
			var i: int = 0
			while i < bays:
				var h: float = GorgeGrammar._hash01(Vector3(zone.position.x + i * 3.1, band * 1.7, face_z))
				var length: int = mini(1 + int(h * 3.0), bays - i)
				var house: bool = fposmod(h * 13.7, 1.0) < .4
				var tint: String = "lime" if fposmod(h * 7.3, 1.0) < .35 else "plaster"
				for k: int in range(i, i + length):
					if k == tower:
						continue
					_cliff_bay(k, band, mini(2, storeys - band), bay_xf, house, tint, k == i + length / 2, top_band)
				i += length
	return out


## One bay of a band: its ledge, its storeys and, on the top band, a parapet.
func _cliff_bay(i: int, band: int, n: int, bay_xf: Callable, house: bool, tint: String, door_bay: bool, top_band: bool) -> void:
	_put("persian_rock_path", bay_xf.call(i, band))
	var off: float = .3 if house else WALL_PROUD
	var shift := Transform3D(Basis(), Vector3(0, 0, off))
	var wall: String = "persian_wall_" + (tint if house else "rock")
	for s: int in range(band, band + n):
		var xf: Transform3D = bay_xf.call(i, s) * shift
		var lit: bool = g._noise.get_noise_3dv(xf * Vector3(2, 2, 0)) > -.05
		var h: float = GorgeGrammar._hash01(xf.origin * 1.3)
		var piece: String
		if s == band and door_bay:
			piece = wall + "_door" + ("" if house or lit else "_dark")
			if lit:
				_put("persian_lamp_bracket", xf * Transform3D(Basis(), Vector3(2.95 if house else 3.1, 2.7, 0)))
		elif h < .14 and s > band:
			piece = wall
			if house:
				_put("persian_oriel", xf)
		elif house and s > band and fposmod(h * 17.0, 1.0) < .45:
			piece = wall + "_window2" + ("" if lit else "_dark")
		else:
			piece = wall + "_window" + ("" if lit else "_dark")
		if not house and h > .88 and not lit:
			_put("persian_glowmoss", xf * _vines_at(piece, h))
		_put(piece, xf)
	if house:
		_put("persian_cornice", bay_xf.call(i, band + n - 1) * shift)
		# Its sides, where it stands out of the rock (a house built against it).
		for e: Array in [[0.0, Basis(Vector3.UP, -PI * .5)], [BAY, Basis(Vector3.UP, PI * .5)]]:
			for s: int in range(band, band + n):
				_put("persian_wall_" + tint, bay_xf.call(i, s) * Transform3D(e[1] * Basis.from_scale(Vector3(off / BAY, 1, 1)), Vector3(e[0], 0, off if e[0] > 0.0 else 0.0)))
	if top_band:
		_put("persian_parapet" + ("_lime" if tint == "lime" else "") if house else "persian_parapet_rock", bay_xf.call(i, band + n) * shift)


## The stair tower in bay i: plaster walls TOWER_OUT out from the face, its
## side toward the ledges a door onto each (every second storey), a window
## on each storey up the front, staggered like a stair's; a parapet and roof.
func _cliff_tower(i: int, storeys: int, bay_xf: Callable, ledges_on_plus_x: bool) -> void:
	var front := Transform3D(Basis(), Vector3(0, 0, TOWER_OUT))
	# The ledges' side: local x 0 faces the bays at lower i (world +x).
	var near_x: float = 0.0 if ledges_on_plus_x else BAY
	for s: int in storeys:
		var xf: Transform3D = bay_xf.call(i, s)
		var lit: bool = g._noise.get_noise_3dv(xf.origin * .7) > -.2
		_put("persian_wall_plaster_window" + ("" if lit else "_dark"), xf * front)
		for x: float in [0.0, BAY]:
			var turn: Basis = Basis(Vector3.UP, -PI * .5) if x == 0.0 else Basis(Vector3.UP, PI * .5)
			# Turned, a side piece runs from the face out; its origin end is the
			# far one when turned +90 degrees.
			var at := Vector3(x, 0, -TOWER_DOOR if x == 0.0 else TOWER_OUT)
			var stretch := Basis.from_scale(Vector3((TOWER_OUT + TOWER_DOOR) / BAY, 1, 1))
			var door: bool = x == near_x and s % 2 == 0
			var piece: String = "persian_wall_plaster_door" if door else "persian_wall_plaster"
			if door:
				# Unstretched, so the door keeps its shape, centred 0.9 m out.
				_put(piece, xf * Transform3D(turn, at))
				if lit:
					_put("persian_lamp_bracket", xf * Transform3D(turn, at) * Transform3D(Basis(), Vector3(2.95, 2.7, 0)))
			else:
				_put(piece, xf * Transform3D(turn * stretch, at))
		if s == storeys - 1:
			_put("persian_cornice", xf * front)
	var top: Transform3D = bay_xf.call(i, storeys)
	_put("persian_roof", top * Transform3D(Basis.from_scale(Vector3(1, 1, (TOWER_OUT + TOWER_DOOR) / BAY)), Vector3(0, -ROOF_DROP, TOWER_OUT)))
	_put("persian_parapet", top * front)
	for x: float in [0.0, BAY]:
		var turn: Basis = Basis(Vector3.UP, -PI * .5) if x == 0.0 else Basis(Vector3.UP, PI * .5)
		_put("persian_parapet", top * Transform3D(turn * Basis.from_scale(Vector3(TOWER_OUT / BAY, 1, 1)), Vector3(x, 0, 0.0 if x == 0.0 else TOWER_OUT)))
	_put("persian_parapet_corner", top * front)
	_put("persian_parapet_corner", top * Transform3D(Basis(), Vector3(BAY, 0, TOWER_OUT)))


## A low zone: rock-cut windows, a few oriels, a rock parapet along the top.
func _cliff_windows(bays: int, storeys: int, bay_xf: Callable) -> void:
	for i: int in bays:
		for s: int in storeys:
			var xf: Transform3D = bay_xf.call(i, s)
			var lit: bool = g._noise.get_noise_3dv(xf * Vector3(2, 2, 0)) > -.05
			var h: float = GorgeGrammar._hash01(xf.origin * 1.3)
			_put("persian_wall_rock" if h < .2 else "persian_wall_rock_window" + ("" if lit else "_dark"), xf * Transform3D(Basis(), Vector3(0, 0, WALL_PROUD)))
			if h > .1 and h < .2 and s > 0:
				_put("persian_oriel", xf)
		_put("persian_parapet_rock", bay_xf.call(i, storeys))

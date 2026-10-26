@tool
class_name ChasmGrammar
extends RoomGrammar
## R10 Chasm Spans (design/room-atlas.html; phase-6-design.md 5.7.4, phase 6
## step 3): a walkway from a ledge's connector straight out across the gorge
## to a ledge in front of the far cliff, in kit pieces.
##
## The span's frame puts its start connector at the origin with the run along
## -Z, a 4 m deck bay a cell. The far ledge (the head) is a row of cells
## across the run's end, as close to the far cliff as the cliff allows
## (face_clearance), found by walking out bay by bay against the gorge's tiers
## (GorgeGrammar.keep_out). The seed picks the head's storey: level with the
## start, a **bridge**; one to drop_storeys_max storeys lower, a **chain**,
## whose last bays step down as flights and landings toward the far cliff.
##
## Under the deck, the scenery aqueducts' arcades in 12 m bays (three cells),
## an upper and a lower tier, piers at every bay's ends down into the mist (or
## onto a tier below); arcades that would reach into a tier give way to piers.
## Bays left over at the start stand on corbels and piers, as the Overlook's
## ledge does; so does the head. Some upper arches pour a waterfall. Every open
## side has a balustrade (chasm_parapet_4m, with its guard: phase 6 Q4), the
## flights their own; square newels at every joint, lamp posts on some.
##
## Output (solve): a plan in the span's frame, built into a room by build_room.

## Furthest the head may be from the start, in bays (the atlas's 40 m spans
## can't cross this gorge: bank to bank is about 80 m where the near aqueduct
## stood).
@export_range(4, 40) var bridge_max_bays: int = 24:
	set(value):
		bridge_max_bays = value
		emit_changed()
## Chance the head is level with the start (a bridge), else lower (a chain).
@export_range(0.0, 1.0, 0.01) var bridge_chance: float = 0.5:
	set(value):
		bridge_chance = value
		emit_changed()
## A chain's head is 1 to this many storeys below its start.
@export_range(1, 4) var drop_storeys_max: int = 3:
	set(value):
		drop_storeys_max = value
		emit_changed()
## The head reaches this many bays either side of the run (seeded in range).
@export var head_side_bays: Vector2i = Vector2i(1, 2):
	set(value):
		head_side_bays = value
		emit_changed()
## The head stands at least this far off the far cliff's tiers, metres.
@export_range(0.0, 4.0, 0.1) var face_clearance: float = 1.0:
	set(value):
		face_clearance = value
		emit_changed()
## One arcade bay in this many pours a waterfall (at least one a span).
@export_range(1, 12) var falls_every: int = 4:
	set(value):
		falls_every = value
		emit_changed()
## A lamp post on every this many bays, alternating sides.
@export_range(1, 12) var lamp_every_bays: int = 3:
	set(value):
		lamp_every_bays = value
		emit_changed()
## Piers stop here at the latest (the mist hides their feet).
@export var pier_foot: float = -120.0:
	set(value):
		pier_foot = value
		emit_changed()
## The gorge whose tiers the span keeps out of.
@export var gorge_layout: GorgeLayout:
	set(value):
		gorge_layout = value
		emit_changed()

const MOD: String = "res://kit/modules/"
const BAY: float = 4.0
## Cells per arcade bay (the scenery aqueducts' 12 m bays).
const GROUP: int = 3
## The arcades hang from the deck course's underside, 1 m under the walk.
const COURSE: float = 1.0
## A waterfall's stone spout under its arch's crown (across, tall, along),
## and the fall's width there (it spreads by half as it falls).
const SPOUT: Vector3 = Vector3(3.4, .45, 3.0)
const FALL_WIDTH: float = 3.2
const UPPER_H: float = 12.0
const LOWER_H: float = 20.6        # 0.6 m faience course and the 20 m arcade
const ARCADE_HALF: float = 1.6     # the upper arcade's half width
## Piers at the arcade bays' ends (along, across: the lower arcade's end piers
## a touch proud, so their faces don't fight), and under corbels.
const ARCADE_PIER: Vector2 = Vector2(3.12, 2.9)
const CORBEL_PIER: float = 1.6
const CORBEL_UNDER: float = 2.3
## A pier on a terrace stands this far in from its deck's edge.
const EDGE_INSET: float = .6
## Headroom kept clear of the tiers over every walk cell.
const HEADROOM: float = 3.5
const NEWEL: float = .55
const NEWEL_MERGE: float = .7
## The span's entry, -Z out of the span (back toward where it starts).
const ENTRY: Transform3D = Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)
## Arcade pieces' frame: X along the run (-Z), Z across (+X).
const ARC_BASIS: Basis = Basis(Vector3(0, 0, -1), Vector3.UP, Vector3(1, 0, 0))

static var _tier_cache: Dictionary = {}
static var _dressing_cache: Dictionary = {}
## The terraces' dressing near the span being solved (GorgeGrammar.dressing).
var _dressing: Array[Vector4] = []


func layout(_grid: CellGrid, _seed_value: int) -> void:
	pass     # a span isn't laid out on a CellGrid: AreaPlanner calls solve()


## The span from `start` (its frame in the area: origin on the start ledge's
## edge, -Z out over the gorge) for a seed. `kind` forces "bridge" or "chain"
## (the tests). Returns {ok, why, kind, drop, bays, head: Vector2i(left,
## right), pieces [{scene, xf}], piers [{at, size}], joints, lamps, falls
## [{at, size}], connectors {name: xf}, walk [Vector3 cell centres], boxes},
## all in the span's frame.
func solve(start: Transform3D, seed_value: int, kind: String = "") -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, "span"])
	var chain: bool = kind == "chain" or (kind == "" and rng.randf() >= bridge_chance)
	var drop: int = rng.randi_range(1, drop_storeys_max) if chain else 0
	var left: int = rng.randi_range(head_side_bays.x, head_side_bays.y)
	var right: int = rng.randi_range(head_side_bays.x, head_side_bays.y)
	var tiers: Array[Dictionary] = _near_tiers(start)
	# Out bay by bay: the rows the head fits in clear of the far cliff, with
	# the run up to them clear. Each head cell stands on a pier in the mist or
	# well on a terrace; its sides reach as far as the seed asks while that
	# holds (at least one bay to a side).
	var low: float = -drop * BAY
	var rows: Array[Array] = []         # [h, Vector2i(left, right)]
	for h: int in range(GROUP, bridge_max_bays + 1):
		if not _clear(start, tiers, Vector3(0, 0, -h * BAY + BAY * .5), low, 0.0, .5):
			break      # the run itself would meet the cliff
		var sides := Vector2i(-1, -1)
		if _head_cell_ok(start, tiers, h, 0, low):
			sides = Vector2i.ZERO
			while sides.x < left and _head_cell_ok(start, tiers, h, -sides.x - 1, low):
				sides.x += 1
			while sides.y < right and _head_cell_ok(start, tiers, h, sides.y + 1, low):
				sides.y += 1
		if sides.x + sides.y > 0:
			rows.append([h, sides])
	var out: Dictionary = {"ok": false, "kind": "chain" if drop > 0 else "bridge", "drop": drop, "bays": 0, "head": Vector2i(left, right)}
	if rows.is_empty() or int(rows[-1][0]) == bridge_max_bays:
		out["why"] = "no far cliff within %d bays" % bridge_max_bays if not rows.is_empty() else "no room for the head"
		return out
	# The furthest row whose whole run can be carried (walked: a chain's last
	# flights by the far bank stood on nothing).
	for r: int in range(rows.size() - 1, -1, -1):
		out = _lay(start, tiers, seed_value, rows[r][0], mini(drop, int(rows[r][0]) / GROUP), rows[r][1])
		if out["ok"]:
			return out
	out["why"] = "no row whose run can be carried"
	return out


## Lays the span out to a head in row n, `drop` storeys down, its sides
## reaching `head` bays. ok only if every bay is carried: an arcade bay by its
## upper arcade and a pier at one end at least, else every bay by a pier of
## its own; the corbelled bays by theirs.
func _lay(start: Transform3D, tiers: Array[Dictionary], seed_value: int, n: int, drop: int, head: Vector2i) -> Dictionary:
	var left: int = head.x
	var right: int = head.y
	var low: float = -drop * BAY
	var out: Dictionary = {"ok": false, "why": "", "kind": "chain" if drop > 0 else "bridge", "drop": drop, "bays": n,
		"head": head, "pieces": [], "piers": [], "joints": [], "lamps": [], "falls": [],
		"connectors": {&"SNAP_entry": ENTRY}, "walk": [], "boxes": []}
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, "falls"])
	var lead: int = (n - GROUP * drop) % GROUP       # bays before the first arcade bay
	var level: PackedFloat32Array = []                # each run bay's deck height at its start
	for k: int in n:
		var into_chain: int = k - (n - GROUP * drop)
		level.append(0.0 if into_chain < 0 else -(into_chain / GROUP) * BAY)
	# The run: corbelled bays, then arcade bays of three (level decks, or a
	# flight and its landing).
	var carried: bool = true
	for k: int in lead:
		carried = _corbel_cell(out, start, tiers, Vector3(-2, 0, -k * BAY)) and carried
		_side_parapets(out, Vector3(-2, 0, -k * BAY))
	var groups: Array[Dictionary] = []
	for a: int in range(lead, n, GROUP):
		var stepping: bool = a >= n - GROUP * drop
		var top: float = level[a] - (BAY if stepping else 0.0)        # the deck the arcade carries
		if stepping:
			_piece(out, "walls/chasm_span_flight", Vector3(-2, level[a], -a * BAY))
			_flight_joints(out, Vector3(-2, level[a], -a * BAY))
			_piece(out, "walls/chasm_deck_4m", Vector3(-2, top, -(a + 2) * BAY))
			_side_parapets(out, Vector3(-2, top, -(a + 2) * BAY))
		else:
			for k: int in range(a, a + GROUP):
				_piece(out, "walls/chasm_deck_4m", Vector3(-2, top, -k * BAY))
				_side_parapets(out, Vector3(-2, top, -k * BAY))
		groups.append({"a": a, "top": top - COURSE})     # a flight's mass, too, stops there
	carried = _arcades(out, start, tiers, groups, rng) and carried
	# The head across the run's end, its back toward the far cliff.
	for i: int in range(-left, right + 1):
		var at := Vector3(i * BAY - 2, low, -n * BAY)
		carried = _corbel_cell(out, start, tiers, at) and carried
		var sides: Array[int] = [2]
		if i != 0:
			sides.append(0)
		if i == right:
			sides.append(1)
		if i == -left:
			sides.append(3)
		for side: int in sides:
			_parapet(out, Transform3D(Basis(), at) * _cell_edge(side))
		out["connectors"][StringName("SNAP_exit_far_%d" % (i + left))] = Transform3D(Basis(), Vector3(i * BAY, low, -(n + 1) * BAY))
	# Lamps: on the newel at a bay's far end, every lamp_every_bays bays,
	# alternating sides (not on flights); and the head's two front corners.
	for k: int in range(lamp_every_bays - 1, n, lamp_every_bays):
		var into_chain: int = k - (n - GROUP * drop)
		if into_chain >= 0 and into_chain % GROUP != GROUP - 1:
			continue
		var side: float = 1.0 if (k / lamp_every_bays) % 2 == 0 else -1.0
		var y: float = level[k] - (BAY if into_chain >= 0 else 0.0)
		(out["lamps"] as Array).append(Vector3(side * 1.82, y, -(k + 1) * BAY))
	(out["lamps"] as Array).append(Vector3(-left * BAY - 1.82, low, -n * BAY - .18))
	(out["lamps"] as Array).append(Vector3(right * BAY + 1.82, low, -n * BAY - .18))
	out["ok"] = carried
	if not carried:
		out["why"] = "a bay carried by nothing"
	return out


## For other builders (tools/bake_overlook.gd): whether a pier of `half` size
## (x, z) under area point p stands cleanly (in the mist, or well on one
## terrace clear of its dressing): {} if not, else {"foot": the height it
## stands on}.
func pier_under(p: Vector3, half: Vector2) -> Dictionary:
	var layout: GorgeLayout = gorge_layout if gorge_layout != null else load("res://gen/gorge/gorge_layout.tres")
	if not _tier_cache.has(layout):
		_tier_cache[layout] = GorgeGrammar.new().keep_out(layout)
	var key: Array = [layout, (p / 40.0).floor()]
	if not _dressing_cache.has(key):
		_dressing_cache[key] = GorgeGrammar.new().dressing(layout, Vector2(p.x, p.z), 60.0)
	_dressing = _dressing_cache[key]
	var tiers: Array[Dictionary] = _tier_cache[layout]
	if not _column_ok(Transform3D(), tiers, p, half):
		return {}
	return {"foot": _ground(Transform3D(), tiers, p)}


## The gorge's tiers near a span leaving `start` (within reach of its run);
## also sets _dressing, their terraces' dressing.
func _near_tiers(start: Transform3D) -> Array[Dictionary]:
	var layout: GorgeLayout = gorge_layout if gorge_layout != null else load("res://gen/gorge/gorge_layout.tres")
	if not _tier_cache.has(layout):
		_tier_cache[layout] = GorgeGrammar.new().keep_out(layout)
	var reach: float = (bridge_max_bays + 2) * BAY
	var a: Vector3 = start.origin
	var b: Vector3 = start * Vector3(0, 0, -reach)
	var key: Array = [layout, a.snapped(Vector3.ONE), b.snapped(Vector3.ONE)]
	if not _dressing_cache.has(key):
		var mid: Vector3 = (a + b) * .5
		_dressing_cache[key] = GorgeGrammar.new().dressing(layout, Vector2(mid.x, mid.z), reach * .5 + 20.0)
	_dressing = _dressing_cache[key]
	var out: Array[Dictionary] = []
	for t: Dictionary in _tier_cache[layout]:
		var c: Vector2 = t["c"]
		var r: float = Vector2(float(t["hx"]), float(t["hz"])).length() + 12.0 + (head_side_bays.y + 1) * BAY
		if Geometry2D.get_closest_point_to_segment(c, Vector2(a.x, a.z), Vector2(b.x, b.z)).distance_to(c) < r:
			out.append(t)
	return out


## Whether a walk cell centred at `c` (span frame; its deck at c.y + from
## .. c.y + to as the run descends) is clear of the tiers, with headroom, its
## sides grown by `margin`.
func _clear(start: Transform3D, tiers: Array[Dictionary], c: Vector3, from: float, to: float, margin: float) -> bool:
	var h: float = BAY * .5 + margin
	for y: float in [minf(from, to) - COURSE, maxf(from, to) + 1.2, maxf(from, to) + HEADROOM]:
		for x: float in [-h, 0.0, h]:
			for z: float in [-h, 0.0, h]:
				if GorgeGrammar.solid_at(tiers, start * (c + Vector3(x, y, z))):
					return false
	return true


## Where a pier under p (span frame) stands, in the span's frame: the deck
## under it, or pier_foot (both area heights).
func _ground(start: Transform3D, tiers: Array[Dictionary], p: Vector3) -> float:
	return maxf(pier_foot, GorgeGrammar.ground_at(tiers, start * p)) - start.origin.y


## Whether head cell i of row h (deck at `low`) is clear of the far cliff by
## face_clearance, its pier standing cleanly.
func _head_cell_ok(start: Transform3D, tiers: Array[Dictionary], h: int, i: int, low: float) -> bool:
	var c := Vector3(i * BAY, 0, -h * BAY - BAY * .5)
	return _clear(start, tiers, c, low, low, face_clearance) \
		and _column_ok(start, tiers, c + Vector3(0, low - CORBEL_UNDER, 0), Vector2.ONE * CORBEL_PIER * .5)


## Whether a pier under `c` (span frame; `half` its half size across and
## along) comes down on one thing: the mist, or one terrace's deck with
## EDGE_INSET to spare all round (by its edge it would stand in the deck
## edge's balustrade), clear of the terrace's dressing.
func _column_ok(start: Transform3D, tiers: Array[Dictionary], c: Vector3, half: Vector2) -> bool:
	var first: float = NAN
	for dx: float in [-half.x - EDGE_INSET, 0.0, half.x + EDGE_INSET]:
		for dz: float in [-half.y - EDGE_INSET, 0.0, half.y + EDGE_INSET]:
			var g: float = maxf(pier_foot, GorgeGrammar.ground_at(tiers, start * (c + Vector3(dx, 0, dz))))
			if is_nan(first):
				first = g
			elif absf(g - first) > .01:
				return false
	if first > pier_foot:
		var at: Vector3 = start * c
		for d: Vector4 in _dressing:
			if d.y > first - 4.0 and d.y < first + 10.0 \
					and Vector2(d.x, d.z).distance_to(Vector2(at.x, at.z)) < d.w + half.length() + EDGE_INSET:
				return false
	return true


## Whether a box (span frame: from `lo` to `hi`) is clear of the tiers,
## sampled every 2 m.
func _box_clear(start: Transform3D, tiers: Array[Dictionary], lo: Vector3, hi: Vector3) -> bool:
	var steps := Vector3i(ceili((hi.x - lo.x) / 2.0), ceili((hi.y - lo.y) / 2.0), ceili((hi.z - lo.z) / 2.0))
	for i: int in steps.x + 1:
		for j: int in steps.y + 1:
			for k: int in steps.z + 1:
				var p := Vector3(lerpf(lo.x, hi.x, float(i) / maxi(steps.x, 1)), lerpf(lo.y, hi.y, float(j) / maxi(steps.y, 1)),
					lerpf(lo.z, hi.z, float(k) / maxi(steps.z, 1)))
				if GorgeGrammar.solid_at(tiers, start * p):
					return false
	return true


## The arcades under each 12 m bay (upper, then lower if both fit clear of
## the tiers), piers at the bays' ends from under the arcades down where they
## stand cleanly, and the waterfalls. An arcade bay with neither end on a
## pier gives way to a pier under each of its bays (walked: near the far bank
## a chain's flights stood on nothing). Whether every bay is carried.
func _arcades(out: Dictionary, start: Transform3D, tiers: Array[Dictionary], groups: Array[Dictionary], rng: RandomNumberGenerator) -> bool:
	var falls: Array[int] = []
	for g: int in groups.size():
		if rng.randi_range(1, falls_every) == 1:
			falls.append(g)
	if falls.is_empty() and not groups.is_empty():
		falls.append(rng.randi_range(0, groups.size() - 1))
	# The arcades each bay could have, and the feet over each bay end.
	var feet: Array[float] = []
	var bottoms: Dictionary = {}      # bay end z -> the highest arcade foot over it
	for g: int in groups.size():
		var a: int = groups[g]["a"]
		var top: float = groups[g]["top"]
		var z0: float = -a * BAY
		var z1: float = z0 - GROUP * BAY
		var foot: float = top
		if _box_clear(start, tiers, Vector3(-ARCADE_HALF, top - UPPER_H, z1), Vector3(ARCADE_HALF, top, z0)):
			foot = top - UPPER_H
			if _box_clear(start, tiers, Vector3(-ARCADE_HALF, top - UPPER_H - LOWER_H, z1), Vector3(ARCADE_HALF, top - UPPER_H, z0)):
				foot -= LOWER_H
		feet.append(foot)
		if foot < top:
			for z: float in [z0, z1]:
				bottoms[z] = maxf(float(bottoms.get(z, -INF)), foot)
	var ends: Dictionary = {}        # bay end z -> its pier
	for z: float in bottoms:
		var from: float = bottoms[z]
		if not _column_ok(start, tiers, Vector3(0, from, z), Vector2(ARCADE_PIER.y, ARCADE_PIER.x) * .5):
			continue
		var ground: float = _ground(start, tiers, Vector3(0, from, z))
		if from - ground > .1:
			ends[z] = {"at": Vector3(0, (from + ground) * .5, z), "size": Vector3(ARCADE_PIER.y, from - ground, ARCADE_PIER.x)}
	var carried: bool = true
	var used: Dictionary = {}
	for g: int in groups.size():
		var a: int = groups[g]["a"]
		var top: float = groups[g]["top"]
		var z0: float = -a * BAY
		var z1: float = z0 - GROUP * BAY
		if feet[g] < top and (ends.has(z0) or ends.has(z1)):
			_piece(out, "walls/aqueduct_upper_12m", Vector3(0, top, z0), ARC_BASIS)
			if feet[g] < top - UPPER_H:
				_piece(out, "walls/aqueduct_lower_12m", Vector3(0, top - UPPER_H, z0), ARC_BASIS)
			for z: float in [z0, z1]:
				if ends.has(z):
					used[z] = true
			(out["boxes"] as Array).append(AABB(Vector3(-ARCADE_HALF, feet[g], z1), Vector3(ARCADE_HALF * 2, top - feet[g], z0 - z1)))
			if falls.has(g):
				# From a stone spout under the upper arch's crown (walked: from
				# its spring line the water seemed to come out of the air),
				# narrow enough for the arch.
				var crown := Vector3(0, top - 1.4, (z0 + z1) * .5)
				(out["falls"] as Array).append({"at": crown - Vector3(0, SPOUT.y, 0), "size": Vector2(FALL_WIDTH, (start * crown).y + 90.0), "spout": crown - Vector3(0, SPOUT.y * .5, 0)})
			continue
		# No arcade: a pier under each bay, wherever along it one stands.
		for k: int in GROUP:
			var found: bool = false
			for along: float in [2.0, 1.4, 2.6, .9, 3.1]:
				var c := Vector3(0, top, z0 - k * BAY - along)
				if _column_ok(start, tiers, c, Vector2.ONE * CORBEL_PIER * .5):
					var ground: float = _ground(start, tiers, c)
					(out["piers"] as Array).append({"at": Vector3(0, (top + ground) * .5, c.z), "size": Vector3(CORBEL_PIER, top - ground, CORBEL_PIER)})
					(out["boxes"] as Array).append(AABB(Vector3(-CORBEL_PIER * .5, ground, c.z - CORBEL_PIER * .5), Vector3(CORBEL_PIER, top - ground, CORBEL_PIER)))
					found = true
					break
			carried = carried and found
	# Only the piers an arcade stands on (one an arcade gave way beside would
	# carry nothing).
	for z: float in used:
		(out["piers"] as Array).append(ends[z])
	return carried


## A walk cell on a stepped corbel (cliff_ledge_4m) with its pier down to
## whatever is under it, if the pier stands cleanly (whether it does). `at`:
## the cell's frame (x 0..4, z -4..0 from it).
func _corbel_cell(out: Dictionary, start: Transform3D, tiers: Array[Dictionary], at: Vector3) -> bool:
	_piece(out, "walls/cliff_ledge_4m", at)
	(out["walk"] as Array).append(at + Vector3(2, 0, -2))
	var under: Vector3 = at + Vector3(2, -CORBEL_UNDER, -2)
	if not _column_ok(start, tiers, under, Vector2.ONE * CORBEL_PIER * .5):
		return false
	var ground: float = _ground(start, tiers, under)
	if under.y - ground > .1:
		(out["piers"] as Array).append({"at": Vector3(under.x, (under.y + ground) * .5, under.z), "size": Vector3(CORBEL_PIER, under.y - ground, CORBEL_PIER)})
	return true


## Balustrades down both sides of a run cell at `at`.
func _side_parapets(out: Dictionary, at: Vector3) -> void:
	for side: int in [1, 3]:
		_parapet(out, Transform3D(Basis(), at) * _cell_edge(side))
	if not (out["walk"] as Array).has(at + Vector3(2, 0, -2)):
		(out["walk"] as Array).append(at + Vector3(2, 0, -2))


func _parapet(out: Dictionary, xf: Transform3D) -> void:
	(out["pieces"] as Array).append({"scene": MOD + "walls/chasm_parapet_4m.tscn", "xf": xf})
	(out["joints"] as Array).append(xf * Vector3(0, 0, -.18))
	(out["joints"] as Array).append(xf * Vector3(4, 0, -.18))


## A flight's balustrades' ends (tools/kit_add_r10.py: 0.18 m in from its
## edges, 0.1 m under its top, at its foot 8 m on and 4 m down), and its walk.
func _flight_joints(out: Dictionary, at: Vector3) -> void:
	for x: float in [.18, 3.82]:
		(out["joints"] as Array).append(at + Vector3(x, -.1, 0))
		(out["joints"] as Array).append(at + Vector3(x, -BAY, -2 * BAY))
	(out["walk"] as Array).append(at + Vector3(2, -1.0, -2))
	(out["walk"] as Array).append(at + Vector3(2, -3.0, -6))


func _piece(out: Dictionary, path: String, at: Vector3, basis: Basis = Basis()) -> void:
	(out["pieces"] as Array).append({"scene": MOD + path + ".tscn", "xf": Transform3D(basis, at)})


## An edge module's frame on a cell's side (0 the cell's +Z side, 1 +X, 2 -Z,
## 3 -X, in the cell's frame where it spans x 0..4, z -4..0); -Z into the
## cell (as tools/bake_overlook.gd).
static func _cell_edge(side: int) -> Transform3D:
	match side:
		0:
			return Transform3D(Basis(), Vector3(0, 0, 0))
		1:
			return Transform3D(Basis(Vector3.UP, PI * .5), Vector3(4, 0, 0))
		2:
			return Transform3D(Basis(Vector3.UP, PI), Vector3(4, 0, -4))
	return Transform3D(Basis(Vector3.UP, -PI * .5), Vector3(0, 0, -4))


# --- building ---------------------------------------------------------------------------

## The room for a solved span: its pieces (drawn in batches), the piers and
## newels as one mesh each, lamp posts, waterfalls, connectors. Newels where
## the span meets its start are the start ledge's own.
static func build_room(span: Dictionary) -> RoomTemplate:
	var room := RoomTemplate.new()
	room.name = "Span"
	room.display_name = "The Span"
	room.off_grid = true
	var pieces := KitBatcher.new()
	pieces.name = "Pieces"
	room.add_child(pieces)
	var scenes: Dictionary = {}
	var n: int = 0
	for p: Dictionary in span["pieces"]:
		var path: String = p["scene"]
		if not scenes.has(path):
			scenes[path] = load(path)
		var node: Node3D = (scenes[path] as PackedScene).instantiate()
		node.name = "%s_%d" % [path.get_file().get_basename(), n]
		node.transform = p["xf"]
		pieces.add_child(node)
		n += 1
	var stone: Material = load("res://kit/materials/gorge_sandstone.tres")
	var piers := SurfaceTool.new()
	for p: Dictionary in span["piers"]:
		var box := BoxMesh.new()
		box.size = p["size"]
		piers.append_from(box, 0, Transform3D(Basis(), p["at"]))
	if not (span["piers"] as Array).is_empty():
		_mesh(room, "piers", piers.commit(), stone)
	_newels(room, span, scenes)
	var water: Shader = load("res://shaders/waterfall.gdshader")
	for i: int in (span["falls"] as Array).size():
		var f: Dictionary = span["falls"][i]
		var material := ShaderMaterial.new()
		material.shader = water
		material.set_shader_parameter("seed", float(i + 1) * 7.13)
		# The ribbon falls along the run's line, bending out over the gorge
		# toward the span's +X side.
		var fall := _mesh(room, "waterfall_%d" % i, waterfall_mesh(f["size"]), material)
		fall.transform = Transform3D(Basis(Vector3(0, 0, -1), Vector3.UP, Vector3(1, 0, 0)), f["at"])
		fall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var spouts := SurfaceTool.new()
	for f: Dictionary in span["falls"]:
		var box := BoxMesh.new()
		box.size = SPOUT
		spouts.append_from(box, 0, Transform3D(Basis(), f["spout"]))
	if not (span["falls"] as Array).is_empty():
		_mesh(room, "spouts", spouts.commit(), load("res://kit/materials/gorge_faience.tres"))
	var holder := Node3D.new()
	holder.name = "Connectors"
	room.add_child(holder)
	for name: StringName in span["connectors"]:
		var m := Marker3D.new()
		m.name = name
		m.transform = span["connectors"][name]
		holder.add_child(m)
	return room


## Square newels on the joints (those within NEWEL_MERGE as one), all the posts
## as one mesh and the caps as another; a lamp post on the newels with a lamp.
static func _newels(room: RoomTemplate, span: Dictionary, scenes: Dictionary) -> void:
	var groups: Array = []
	for p: Vector3 in span["joints"]:
		var found: bool = false
		for gr: Array in groups:
			if (gr[0] as Vector3).distance_to(p) < NEWEL_MERGE:
				gr.append(p)
				found = true
				break
		if not found:
			groups.append([p])
	var post_box := BoxMesh.new()
	post_box.size = Vector3(NEWEL, 1.4, NEWEL)
	var cap_box := BoxMesh.new()
	cap_box.size = Vector3(NEWEL + .1, .1, NEWEL + .1)
	var posts := SurfaceTool.new()
	var caps := SurfaceTool.new()
	var lamp_path: String = MOD + "dressing/chasm_lamp_post.tscn"
	var n: int = 0
	for gr: Array in groups:
		var at := Vector3.ZERO
		for p: Vector3 in gr:
			at += p
		at /= gr.size()
		if absf(at.y) < .2 and absf(at.z) < NEWEL_MERGE and absf(absf(at.x) - 1.82) < NEWEL_MERGE:
			continue      # the start ledge's newel
		posts.append_from(post_box, 0, Transform3D(Basis(), at + Vector3(0, .45, 0)))
		caps.append_from(cap_box, 0, Transform3D(Basis(), at + Vector3(0, 1.2, 0)))
		for l: Vector3 in span["lamps"]:
			if l.distance_to(at) < NEWEL_MERGE:
				if not scenes.has(lamp_path):
					scenes[lamp_path] = load(lamp_path)
				var post: Node3D = (scenes[lamp_path] as PackedScene).instantiate()
				post.name = "chasm_lamp_post_%d" % n
				post.transform = Transform3D(Basis().scaled(Vector3.ONE * .6), at + Vector3(0, 1.25, 0))
				room.add_child(post)
				n += 1
				break
	_mesh(room, "newel_posts", posts.commit(), load("res://kit/materials/gorge_sandstone.tres"))
	_mesh(room, "newel_caps", caps.commit(), load("res://kit/materials/gorge_limestone.tres"))


static func _mesh(room: Node, name: String, mesh: Mesh, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	mi.mesh = mesh
	mi.material_override = material
	room.add_child(mi)
	return mi


## The scenery's waterfall ribbon (vista.gd waterfall): two bent layers that
## spread toward the foot, `size` (width, drop), hanging from the origin, its
## bend toward +Z.
static func waterfall_mesh(size: Vector2) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for layer: int in 2:
		for y: int in 28:
			for x: int in 10:
				for corner: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
					var uv := Vector2(float(x + corner.x) / 10, float(y + corner.y) / 28)
					var spread: float = 1 + pow(uv.y, 3) * .5
					surface.set_uv(uv)
					surface.set_normal(Vector3.FORWARD)
					surface.add_vertex(Vector3((uv.x - .5) * size.x * spread, -uv.y * size.y, sin(uv.y * 4) * 2.7 + pow(uv.y, 2) * 5 + layer * .55))
	return surface.commit()

class_name ChasmLink
extends RefCounted
## A span between two given connectors (phase-6-design.md 5.7.4-5.7.5, phase 6
## step 4): the network's spans across the gorge and stairs along its cliffs,
## each joining two ledges the planner has already placed. Step 3's span grows
## from one connector and finds its own far end; a link knows both.
##
## The link runs straight from its upper end `a` toward its lower end `b`,
## level at first, then a flight and a landing per storey down (the kit's
## span flights, as step 3's chains), on the scenery aqueducts' arcades in
## 12 m bays where they fit clear of the tiers (a pier under each flight where
## they don't), the level part on arcades stretched to fit it (a short one a
## lintel between its ends). The ends seldom face the run
## square (each ledge faces its own cliff): a landing cut to fit takes up the
## angle, up to MAX_TURN. Lengths aren't whole bays, so the level run and the
## landings are made to measure (ChasmMasonry) in the materials the kit's
## pieces use, which map in world space and so run on without a seam.
##
## Output (join): a plan in the link's frame (a at the origin, -Z toward b),
## as ChasmGrammar.solve's, built by ChasmGrammar.build_room.

## Furthest a run may turn from either end's facing.
const MAX_TURN: float = deg_to_rad(30.0)
const BAY: float = 4.0
const GROUP: int = 3
## The level run's balustrade comes in lengths of about this (newels between).
const RAIL_STEP: float = 4.0
## Under a span's walk its faience course is as deep as the kit deck's.
const COURSE: float = .55
## The made slab and its course under the walk; the corbel's steps under that
## (the kit ledge's), its pier under them.
const SLAB_UNDER: float = .45 + COURSE
const CORBEL_STEPS: float = 1.55
const PIER: float = 1.6
const HEADROOM: float = 3.6
## A level run this short is a lintel between its ends; from ARCADE_MIN it
## stands on arcades (stretched to fit: 6 m is half a bay).
const LINTEL: float = 4.5
const ARCADE_MIN: float = 6.0
## A walk keeps this much further clear of the backdrop (GorgeBackdrop) on
## either side than its own width.
const BACKDROP_SPARE: float = 1.5


## The link from connector a to connector b (area frame, each -Z out of its
## room) for a seed, solved from the higher end. {ok, why, reversed (solved b
## to a: its frame starts at b), xf (its frame in the area), drop, length,
## pieces, piers, joints, lamps, falls, connectors {SNAP_a at a, SNAP_b at b},
## walk, boxes, claims, slabs, rails, blocks, no_newels, landings, lintel
## (the level run carried by its ends alone)}.
static func join(grammar: ChasmGrammar, a: Transform3D, b: Transform3D, seed_value: int) -> Dictionary:
	if b.origin.y > a.origin.y + .01:
		var r: Dictionary = join(grammar, b, a, seed_value)
		r["reversed"] = true
		var conns: Dictionary = r["connectors"]
		if conns.has(&"SNAP_a"):        # named for the caller's ends
			r["connectors"] = {&"SNAP_a": conns[&"SNAP_b"], &"SNAP_b": conns[&"SNAP_a"]}
		return r
	var out: Dictionary = {"ok": false, "why": "", "reversed": false, "name": "Link", "display_name": "The Span",
		"pieces": [], "piers": [], "joints": [], "lamps": [], "falls": [], "connectors": {}, "walk": [], "boxes": [],
		"claims": [], "no_newels": []}
	var flat := Vector3(b.origin.x - a.origin.x, 0, b.origin.z - a.origin.z)
	var length: float = flat.length()
	var rise: float = a.origin.y - b.origin.y
	var drop: int = roundi(rise / BAY)
	out["length"] = length
	out["drop"] = drop
	if absf(rise - drop * BAY) > .05:
		out["why"] = "not a whole storey between the ends (%.2f m)" % rise
		return out
	if length > (grammar.bridge_max_bays + 2) * BAY:
		out["why"] = "too long (%.0f m)" % length
		return out
	var fwd: Vector3 = flat / length
	var s := Transform3D(Basis.looking_at(fwd, Vector3.UP), a.origin)
	out["xf"] = s
	var turn_a: float = _turn(-a.basis.z, fwd)
	var turn_b: float = _turn(-b.basis.z, -fwd)
	if absf(turn_a) > MAX_TURN or absf(turn_b) > MAX_TURN:
		out["why"] = "the ends turn too far from the run (%.0f, %.0f degrees)" % [rad_to_deg(turn_a), rad_to_deg(turn_b)]
		return out
	# Each end's landing reaches out until the run's square end clears the
	# end's edge.
	var ka: float = _reach(turn_a)
	var kb: float = _reach(turn_b)
	var low: float = -drop * BAY
	# The stepping: a flight and its landing per storey (12 m), the last
	# flight arriving straight on b's edge (8 m).
	var stepping: float = GROUP * BAY * drop - (BAY if drop > 0 else 0.0)
	var t0: float = length - kb - stepping      # where the stepping starts
	if t0 - ka < 0.0:
		out["why"] = "too short for %d storeys down (%.0f m)" % [drop, length]
		return out
	var tiers: Array[Dictionary] = grammar._near_tiers(s)
	# The walk and its headroom clear of the tiers, before any arcade is
	# tried (the cheap test first): the level run every 4 m, each flight's
	# two points and its landing.
	var planned: Array[Vector3] = []
	var lv0: float = t0 - ka
	for j: int in maxi(1, ceili(lv0 / BAY)):
		planned.append(Vector3(0, 0, -ka - lv0 * (j + .5) / maxi(1, ceili(lv0 / BAY))))
	for g: int in drop:
		var t: float = t0 + g * GROUP * BAY
		planned.append_array([Vector3(0, -g * BAY - 1.0, -t - 2.0), Vector3(0, -g * BAY - 3.0, -t - 6.0)])
		if g < drop - 1:
			planned.append(Vector3(0, -(g + 1) * BAY, -t - 10.0))
	for w: Vector3 in planned:
		if not _clear(s, tiers, w):
			out["why"] = "runs into the gorge's tiers at %.0f m" % -w.z
			return out
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, "link"])
	# The level run: made slab and balustrades, newels about every 4 m.
	var lv: float = t0 - ka
	if lv > .05:
		ChasmMasonry.slab(out, PackedVector2Array([Vector2(-2, -ka), Vector2(2, -ka), Vector2(2, -t0), Vector2(-2, -t0)]), 0.0, COURSE)
		var pieces: int = maxi(1, roundi(lv / RAIL_STEP))
		for side: float in [-1.0, 1.0]:
			for k: int in pieces:
				var z0: float = -ka - lv * k / pieces
				var z1: float = -ka - lv * (k + 1) / pieces
				ChasmMasonry.rail(out, Vector3(side * 1.82, 0, z0), Vector3(side * 1.82, 0, z1))
				(out["joints"] as Array).append(Vector3(side * 1.82, 0, z0))
				(out["joints"] as Array).append(Vector3(side * 1.82, 0, z1))
				if (k + 1) % 3 == 0 and ((k + 1) / 3) % 2 == (0 if side > 0 else 1):
					(out["lamps"] as Array).append(Vector3(side * 1.82, 0, z1))
		var m: int = maxi(1, ceili(lv / BAY))
		for j: int in m:
			(out["walk"] as Array).append(Vector3(0, 0, -ka - lv * (j + .5) / m))
	var groups: Array[Dictionary] = []
	for g: int in drop:
		var t: float = t0 + g * GROUP * BAY
		var top: float = -g * BAY
		grammar._piece(out, "walls/chasm_span_flight", Vector3(-2, top, -t))
		grammar._flight_joints(out, Vector3(-2, top, -t))
		if g < drop - 1:
			grammar._piece(out, "walls/chasm_deck_4m", Vector3(-2, top - BAY, -t - 2 * BAY))
			grammar._side_parapets(out, Vector3(-2, top - BAY, -t - 2 * BAY))
			groups.append({"z0": -t, "top": top - BAY - ChasmGrammar.COURSE, "flight": true})
		else:
			groups.append({"z0": -t, "top": top - BAY - ChasmGrammar.COURSE, "bays": 2, "flight": true, "last": true})
		(out["claims"] as Array).append({"at": Vector3(0, top - BAY * .5 + (HEADROOM - COURSE) * .5, -t - (GROUP if g < drop - 1 else 2) * BAY * .5),
			"size": Vector3(4.3, BAY + HEADROOM + COURSE, (GROUP if g < drop - 1 else 2) * BAY)})
	# Under the level run: up to LINTEL long, nothing (a lintel between its
	# ends); from ARCADE_MIN, arcades stretched to fit it end to end (walked:
	# where 12 m bays left odd metres by the start, straight piers there read
	# as another bridge's); between, a corbel and pier in its middle.
	var level: int = 0
	if lv >= ARCADE_MIN:
		level = maxi(1, roundi(lv / (GROUP * BAY)))
		var zs: Array[float] = []
		for k: int in level + 1:
			zs.append(snappedf(-ka - lv * k / level, .001))
		zs[level] = snappedf(-t0, .001)
		for k: int in range(level - 1, -1, -1):
			groups.push_front({"z0": zs[k], "length": zs[k] - zs[k + 1], "top": -ChasmGrammar.COURSE})
	var carried: bool = grammar._arcades(out, s, tiers, groups, rng)
	out["lintel"] = lv <= LINTEL
	if level == 0 and lv > LINTEL:
		carried = _corbel(out, grammar, s, tiers, ka + lv * .5) and carried
	# The landings at the ends, cut from each end's edge to the run's.
	_landing(out, s, a, ka, 0.0)
	_landing(out, s, b, length - kb, low)
	out["connectors"][&"SNAP_a"] = s.affine_inverse() * a * Transform3D(Basis(Vector3.UP, PI))
	out["connectors"][&"SNAP_b"] = s.affine_inverse() * b * Transform3D(Basis(Vector3.UP, PI))
	# What of the gorge clears off: the walk and its headroom, the arcades
	# and piers.
	if lv > .05:
		(out["claims"] as Array).append({"at": Vector3(0, (HEADROOM - COURSE) * .5, -(ka + t0) * .5), "size": Vector3(4.3, HEADROOM + COURSE, lv)})
	for box: AABB in out["boxes"]:
		(out["claims"] as Array).append({"at": box.get_center(), "size": box.size})
	for w: Vector3 in out["walk"]:
		(out["boxes"] as Array).append(AABB(w + Vector3(-2, -1.0, -2), Vector3(4, 1.0 + HEADROOM, 4)))
	out["ok"] = carried
	if not carried:
		out["why"] = "a bay carried by nothing"
	return out


## Whether a walk point's deck and headroom are clear of the tiers: 2.5 m
## of it (a stair along a cliff may pass under a tier's deck overhang, as
## a ledge may: a covered way).
static func _clear(s: Transform3D, tiers: Array[Dictionary], w: Vector3) -> bool:
	for x: float in [-1.8, 0.0, 1.8]:
		for z: float in [-1.8, 0.0, 1.8]:
			for y: float in [-1.0, 1.2, 2.5]:
				if GorgeGrammar.solid_at(tiers, s * (w + Vector3(x, y, z))):
					return false
	# The backdrop's masses (when loaded: the tools) further off: walked, a
	# stair hard against the blank mass by the Overlook hid where it went.
	if GorgeBackdrop.loaded() and GorgeBackdrop.crosses(s, w + Vector3(-2.0 - BACKDROP_SPARE, .3, -2.0), w + Vector3(2.0 + BACKDROP_SPARE, HEADROOM, 2.0)):
		return false
	return true


## The signed angle from `from` to `to` about +Y (horizontal).
static func _turn(from: Vector3, to: Vector3) -> float:
	return Vector2(from.x, from.z).angle_to(Vector2(to.x, to.z))


## How far out from an end's edge the run's square end must start for an end
## turned by `turn` (its far corner just clear), 0 for a square end.
static func _reach(turn: float) -> float:
	if absf(turn) < deg_to_rad(.5):
		return 0.0
	return (2.0 * sin(absf(turn)) + .05) / cos(turn)


## A point of the level run t along it carried by a stepped corbel on a pier
## (the kit ledge's, under the deeper course), where one stands cleanly
## there or a little along. Whether one does.
static func _corbel(out: Dictionary, grammar: ChasmGrammar, s: Transform3D, tiers: Array[Dictionary], t: float) -> bool:
	const TOP: float = -SLAB_UNDER - CORBEL_STEPS
	for off: Vector2 in [Vector2(0, 0), Vector2(0, .8), Vector2(0, -.8), Vector2(.6, 0), Vector2(-.6, 0), Vector2(0, 1.6), Vector2(0, -1.6)]:
		var c := Vector3(off.x, TOP, -t - off.y)
		if not grammar._column_ok(s, tiers, c, Vector2.ONE * PIER * .5):
			continue
		ChasmMasonry.block(out, Vector3(c.x, -SLAB_UNDER - .2, c.z), Vector3(2.6, .4, 2.6))
		ChasmMasonry.block(out, Vector3(c.x, -SLAB_UNDER - .65, c.z), Vector3(1.6, .5, 1.6))
		ChasmMasonry.block(out, Vector3(c.x, -SLAB_UNDER - 1.225, c.z), Vector3(.8, .65, .8))
		var ground: float = grammar._ground(s, tiers, c)
		if c.y - ground > .1:
			(out["piers"] as Array).append({"at": Vector3(c.x, (c.y + ground) * .5, c.z), "size": Vector3(PIER, c.y - ground, PIER)})
			(out["boxes"] as Array).append(AABB(Vector3(c.x - PIER * .5, ground, c.z - PIER * .5), Vector3(PIER, c.y - ground, PIER)))
		return true
	return false


## The landing between an end's edge (connector c, area frame) and the run's
## square end t along it (at height y): a slab cut to the quadrilateral
## between them, a balustrade down each of its sides. The end's room has its
## newels at its edge's corners (no_newels). Its middle goes in "landings".
static func _landing(out: Dictionary, s: Transform3D, c: Transform3D, t: float, y: float) -> void:
	var inv: Transform3D = s.affine_inverse()
	var mid: Vector3 = inv * c.origin
	var across: Vector3 = (inv.basis * c.basis.x).normalized()
	var e0: Vector3 = mid - across * 2.0
	var e1: Vector3 = mid + across * 2.0
	if e0.x > e1.x:         # e0 on the run's -x side
		var tmp: Vector3 = e0
		e0 = e1
		e1 = tmp
	var ins: Vector3 = (e1 - e0).normalized() * .18
	(out["no_newels"] as Array).append(e0 + ins)
	(out["no_newels"] as Array).append(e1 - ins)
	var r0 := Vector3(-2, y, -t)
	var r1 := Vector3(2, y, -t)
	if e0.distance_to(r0) < .02 and e1.distance_to(r1) < .02:
		return       # square: the run starts right on the edge
	ChasmMasonry.slab(out, PackedVector2Array([Vector2(e0.x, e0.z), Vector2(e1.x, e1.z), Vector2(r1.x, r1.z), Vector2(r0.x, r0.z)]), y, COURSE)
	ChasmMasonry.rail(out, e0 + ins, r0 + Vector3(.18, 0, 0))
	ChasmMasonry.rail(out, e1 - ins, r1 - Vector3(.18, 0, 0))
	(out["joints"] as Array).append(r0 + Vector3(.18, 0, 0))
	(out["joints"] as Array).append(r1 - Vector3(.18, 0, 0))
	if not out.has("landings"):
		out["landings"] = []
	(out["landings"] as Array).append((e0 + e1 + r0 + r1) * .25)

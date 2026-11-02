class_name AreaNetwork
extends RefCounted
## The near gorge's network in an AreaPlan (phase-6-design.md 5.7.5, phase 6
## step 4), after the recipe's own rooms (the Overlook; the recipe's span is
## replaced: the main span is the network's first link).
##
## Every link the network could have is solved once ahead of time
## (tools/gorge_links.gd -> GorgeLinks); planning searches over that table,
## checking only boxes, so it can try many trees. A tree grows from the
## Overlook's corner, shortest link first (a little shuffled by the seed and
## by each try): each round, every link from one of the tree's free
## connectors to a connector a ledge could have on a slot not yet used,
## where that ledge (2-5 bays, all the ways it can sit on the slot so that
## connector is on it) and the link overlap nothing planned. The main span
## goes first, to the far cliff, as straight out of the Overlook's corner as
## it can (step 3's line: turned toward its ledge it filled the box art's
## mist floor) and no more than step 3's chains up or down; then the cliffs
## take turns once one has two ledges and the other none. Every ledge has
## one way to it (no loops, phase 5 Q4). Of the tries, the first with the
## seed's 4-6 ledges is kept (or after a dozen, one with at least 4; else
## the fullest); only its links are solved. A try that comes up short rules
## its main span out of the tries after it (its ledge may be a dead end).
## Every slot with a door (step 5) is to have its ledge: links to one cost
## DOOR_PULL less, a tree may grow past the seed's count (to the most
## allowed) until it has them, and a tree that reaches every door beats one
## that doesn't, whatever its size.
##
## Rooms are "ledge" and "link" (their plans in Room.span), built by
## ChasmGrammar.build_room; each link's parent is the room nearer the
## balcony, its child the ledge beyond.
##
## (The design's Kruskal over ledges placed first left most of them
## unreachable: the far cliff's ledges that can face the Overlook's span are
## few, and most of the rest are reached only by a stair from one of them.)

## Trees tried at most; after ENOUGH_TRIES, one with the fewest ledges
## allowed will do.
const TRIES: int = 80
const ENOUGH_TRIES: int = 12
## Each try shuffles the links' order by up to this much of their length.
const JITTER: float = .3
## Metres of length a degree of the main span's turn at the Overlook costs.
const MAIN_TURN_COST: float = 4.0
## Metres a main span not of the seed's kind (bridge or chain) costs.
const MAIN_KIND_COST: float = 16.0
## A span across that doubles one already planned (_doubled) costs this many
## metres more: taken only if nothing else will do. Spans across are
## doubled within this far apart in plan ...
const DOUBLED_COST: float = 80.0
const CROSS_GAP: float = 24.0
## ... or, leaving the same ledge, splayed less than this many degrees.
const CROSS_SPLAY: float = 12.0
## A link to a ledge on a slot with a door (step 5) costs this many metres
## less: every tree is to reach every door.
const DOOR_PULL: float = 40.0
## Ledges a tree may add past the seed's maximum to reach every door (phase 10
## step 3: more areas, more doors). Only trees still missing a door grow them,
## so a world whose doors were reached plans as before.
const DOOR_LEDGES: int = 4


static func plan(p: AreaPlan, net: GorgeNetwork) -> void:
	if net.frontage == null or net.ledge == null or net.chasm == null or net.links == null:
		p.errors.append("network: frontage, links, ledge and chasm grammars needed")
		return
	StratumPlan.current().apply_doors(net.frontage)     # the doors into areas (phase 10 step 3)
	var main: AreaPlan.Room = p.room(net.main_slot)
	if main != null and p.rooms[-1] == main:
		p.remove_last()
	var from: AreaPlan.Room = p.room(net.main_from)
	var main_id: String = "%s:%s" % [net.main_from, net.main_connector]
	if from == null or not from.connectors.has(net.main_connector):
		p.errors.append("network: %s has no %s" % [net.main_from, net.main_connector])
		return
	if not net.links.fixed.has(main_id) or not (net.links.fixed[main_id] as Transform3D).is_equal_approx(from.connectors[net.main_connector]["xf"]):
		p.errors.append("network: gen/gorge/links.res was made for another Overlook: run tools/gorge_links.gd")
		return
	var by_conn: Dictionary = {}       # connector id -> [entry indices]
	for i: int in net.links.entries.size():
		for end: String in ["a", "b"]:
			var id: String = net.links.entries[i][end]
			if not by_conn.has(id):
				by_conn[id] = []
			(by_conn[id] as Array).append(i)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([p.area_seed, "network"])
	var want: int = rng.randi_range(net.ledges.x, net.ledges.y)
	var bridge: bool = rng.randf() < net.chasm.bridge_chance
	# What's planned already: the recipe's rooms; all but the Overlook for the
	# main span, which leaves it.
	var fixed: Array[AABB] = []
	for r: AreaPlan.Room in p.rooms:
		for b: AABB in r.blockers:
			fixed.append(b.abs())
	var fixed_open: Array[AABB] = _without(p, fixed, net.main_from)
	var ledge_cache: Dictionary = {}
	var best: Dictionary = {}
	var dead: Dictionary = {}      # main spans whose trees came up short
	for t: int in TRIES:
		var g: Dictionary = _tree(p, net, by_conn, main_id, fixed, fixed_open, want, bridge, t, ledge_cache, dead)
		if best.is_empty() or _score(net, g) > _score(net, best):
			best = g
		if (g["ledges"] as Array).size() < net.ledges.x and not (g["links"] as Array).is_empty():
			dead[g["links"][0]["entry"]] = true      # the next tries leave the Overlook another way
		var held: bool = _doors_missing(net, best["ledges"]) == 0
		if held and ((best["ledges"] as Array).size() >= want or (t >= ENOUGH_TRIES and (best["ledges"] as Array).size() >= net.ledges.x)):
			break
	p.stats["ledges_wanted"] = want
	if _doors_missing(net, best["ledges"]) > 0:
		p.errors.append("network: no tree reaches every door (%d missing)" % _doors_missing(net, best["ledges"]))
	if (best["ledges"] as Array).is_empty():
		p.errors.append("network: the main span finds no ledge on the %s cliff" % net.main_cliff)
		return
	_commit(p, net, best["ledges"], best["links"])


## One tree, its links' order shuffled by try `t`: {ledges: [{slot, first,
## bays, seed, xf, boxes, ids}], links: [{entry, from, to (connector ids),
## from_node, to_node (ledge index; -1 a recipe room)}]}.
static func _tree(p: AreaPlan, net: GorgeNetwork, by_conn: Dictionary, main_id: String, fixed: Array[AABB], fixed_open: Array[AABB],
		want: int, bridge: bool, t: int, ledge_cache: Dictionary, dead: Dictionary) -> Dictionary:
	var ledges: Array[Dictionary] = []
	var links: Array[Dictionary] = []
	var free: Dictionary = {main_id: -1}     # free connector id -> its node
	var cliffs: Dictionary = {"left": 0, "right": 0}
	while ledges.size() < want or (_doors_missing(net, ledges) > 0 and ledges.size() < net.ledges.y + DOOR_LEDGES):
		var on: Array = ["left", "right"]
		var main_round: bool = ledges.is_empty()
		if main_round:
			on = [net.main_cliff]
		else:
			for c: String in cliffs:
				if int(cliffs[c]) == 0 and ledges.size() >= 2:
					on = [c]
		var grown: bool = false
		for kind: int in ([0 if bridge else -1] if main_round else [-2]):
			if _grow(p, net, by_conn, fixed, fixed_open, ledges, links, free, cliffs, on, t, kind, ledge_cache, dead):
				grown = true
				break
		if not grown and on.size() == 1 and not main_round:
			grown = _grow(p, net, by_conn, fixed, fixed_open, ledges, links, free, cliffs, ["left", "right"], t, -2, ledge_cache, dead)
		if not grown:
			break
	return {"ledges": ledges, "links": links}


## One round: the best link from a free connector to a ledge that can stand
## on a slot of a cliff in `on` (for the main span, `rise` 0: level, -1:
## lower, else any: preferred, never more than step 3's chains), joined.
## Whether one was.
static func _grow(p: AreaPlan, net: GorgeNetwork, by_conn: Dictionary, fixed: Array[AABB], fixed_open: Array[AABB], ledges: Array[Dictionary],
		links: Array[Dictionary], free: Dictionary, cliffs: Dictionary, on: Array, t: int, rise: int, ledge_cache: Dictionary,
		dead: Dictionary) -> bool:
	var used: Dictionary = {}
	for l: Dictionary in ledges:
		used[(l["slot"] as FrontageSlot).id] = true
	var cands: Array = []          # [cost, entry index, from id, to id]
	for f: String in free:
		for ei: int in by_conn.get(f, []):
			var e: Dictionary = net.links.entries[ei]
			var to: String = e["b"] if e["a"] == f else e["a"]
			var slot_id: String = GorgeLinks.slot_of(to)
			if slot_id == "" or used.has(slot_id):
				continue
			var slot: FrontageSlot = net.frontage.slot(slot_id)
			if not on.has(slot.cliff):
				continue
			var cost: float = maxf(float(e["length"]), net.min_link)
			if int(free[f]) == -1:
				if dead.has(ei):
					continue
				# The main span: step 3's chains at most, up or down; level for a
				# bridge, else lower, if the seed asked; as straight as it can.
				var drop: int = int(e["drop"]) * (1 if e["a"] == f else -1)
				if absi(drop) > net.chasm.drop_storeys_max:
					continue
				if (rise == 0 and drop != 0) or (rise == -1 and drop <= 0):
					cost += MAIN_KIND_COST      # not the kind the seed asked for: it may still do
				cost += MAIN_TURN_COST * float(e["turn_a"])
			elif _doubled(net, links, e, int(free[f]), f, to):
				cost += DOUBLED_COST
			if slot.door != "":
				cost = maxf(cost - DOOR_PULL, 1.0)
			cost *= 1.0 + JITTER * float(hash([p.area_seed, t, ei]) & 0xffff) / 65535.0 * (0.0 if t == 0 else 1.0)
			cands.append([cost, ei, f, to])
	cands.sort_custom(func(x: Array, y: Array) -> bool: return x[0] < y[0])
	for cd: Array in cands:
		var e: Dictionary = net.links.entries[cd[1]]
		var f: String = cd[2]
		var to: String = cd[3]
		var from_node: int = free[f]
		var seg: PackedVector2Array = _segment(net, e)
		var across: bool = _across(net, f, to)
		var kboxes: Array[AABB] = []
		kboxes.assign(e["boxes"])
		# The link clear of everything planned but the room it leaves.
		if _meets(kboxes, fixed if from_node != -1 else fixed_open):
			continue
		var clash: bool = false
		for i: int in ledges.size():
			if i != from_node and _meets(kboxes, ledges[i]["boxes"]):
				clash = true
				break
		for l: Dictionary in links:
			if clash or _meets(kboxes, l["boxes"]):
				clash = true
				break
		if clash:
			continue
		# A ledge with that connector on it, the longest first (a seed's turn
		# among its lengths), clear of everything but its link where they meet.
		var slot: FrontageSlot = net.frontage.slot(GorgeLinks.slot_of(to))
		var lengths: Array = range(mini(net.ledge.bays.y, slot.width), net.ledge.bays.x - 1, -1)
		var shift: int = hash([p.area_seed, t, to]) % maxi(lengths.size(), 1)
		lengths = lengths.slice(shift) + lengths.slice(0, shift)
		var placed: Dictionary = {}
		for n: int in lengths:
			for first: int in range(0, slot.width - n + 1):
				if GorgeLinks.ledge_connector(to, first, n) == &"":
					continue
				var key: String = "%s/%d/%d" % [slot.id, first, n]
				if not ledge_cache.has(key):
					var seed_value: int = hash([p.area_seed, "ledge", key]) & 0x7fffffff
					var lp: Dictionary = net.ledge.at(slot, first, n, seed_value)
					var boxes: Array[AABB] = []
					for b: AABB in lp["boxes"]:
						boxes.append((lp["xf"] as Transform3D) * b)
					ledge_cache[key] = {"seed": seed_value, "xf": lp["xf"], "boxes": boxes}
				var lc: Dictionary = ledge_cache[key]
				if _meets(lc["boxes"], fixed) or _meets_but_joint(kboxes, lc["boxes"], GorgeLinks.slot_connector(net.frontage, to).origin):
					continue
				var free_of: bool = true
				for l: Dictionary in ledges:
					if _meets(lc["boxes"], l["boxes"]):
						free_of = false
						break
				for l: Dictionary in links:
					if free_of and _meets(lc["boxes"], l["boxes"]):
						free_of = false
						break
				if free_of:
					placed = {"slot": slot, "first": first, "bays": n, "seed": lc["seed"], "xf": lc["xf"], "boxes": lc["boxes"]}
					break
			if not placed.is_empty():
				break
		if placed.is_empty():
			continue
		var node: int = ledges.size()
		placed["ids"] = []
		ledges.append(placed)
		cliffs[slot.cliff] = int(cliffs[slot.cliff]) + 1
		links.append({"entry": cd[1], "from": f, "to": to, "from_node": from_node, "to_node": node, "boxes": kboxes,
			"seg": seg, "across": across})
		free.erase(f)
		# The new ledge's other connectors join the free ones.
		for k: int in range(placed["first"], int(placed["first"]) + int(placed["bays"])):
			_free(free, "%s:F:%d" % [slot.id, k], to, node)
		_free(free, "%s:L:%d" % [slot.id, placed["first"]], to, node)
		_free(free, "%s:R:%d" % [slot.id, int(placed["first"]) + int(placed["bays"])], to, node)
		return true
	return false


## A tree's rank: the doors it reaches first, then its ledges.
static func _score(net: GorgeNetwork, g: Dictionary) -> int:
	return -_doors_missing(net, g["ledges"]) * 100 + (g["ledges"] as Array).size()


## How many of the frontage's doors have no ledge in `ledges`.
static func _doors_missing(net: GorgeNetwork, ledges: Array) -> int:
	var on: Dictionary = {}
	for l: Dictionary in ledges:
		on[(l["slot"] as FrontageSlot).id] = true
	var n: int = 0
	for s: FrontageSlot in net.frontage.slots:
		if s != null and s.door != "" and not on.has(s.id):
			n += 1
	return n


## Whether a span across from connector f (of node `from_node`) to `to`
## would double one across already planned (two side by side read as one
## doubled bridge, and darken the box art's mist floor): near it in plan,
## or, leaving the ledge it arrives at, splayed less than CROSS_SPLAY.
static func _doubled(net: GorgeNetwork, links: Array[Dictionary], e: Dictionary, from_node: int, f: String, to: String) -> bool:
	if not _across(net, f, to):
		return false
	var seg: PackedVector2Array = _segment(net, e)
	for l: Dictionary in links:
		if not l["across"]:
			continue
		if l["to_node"] == from_node or l["from_node"] == from_node:
			var u: Vector2 = (l["seg"] as PackedVector2Array)[1] - (l["seg"] as PackedVector2Array)[0]
			var splay: float = rad_to_deg(absf(u.angle_to(seg[1] - seg[0])))
			if minf(splay, 180.0 - splay) < CROSS_SPLAY:
				return true
		elif _gap(seg, l["seg"]) < CROSS_GAP:
			return true
	return false


## A link's line in plan (x, z), its ends'.
static func _segment(net: GorgeNetwork, e: Dictionary) -> PackedVector2Array:
	var a: Vector3 = _connector_xf(net, e["a"]).origin
	var b: Vector3 = _connector_xf(net, e["b"]).origin
	return PackedVector2Array([Vector2(a.x, a.z), Vector2(b.x, b.z)])


## Whether a link between two connectors crosses the gorge (from the
## Overlook, or between the cliffs).
static func _across(net: GorgeNetwork, a: String, b: String) -> bool:
	var sa: String = GorgeLinks.slot_of(a)
	var sb: String = GorgeLinks.slot_of(b)
	return sa == "" or sb == "" or net.frontage.slot(sa).cliff != net.frontage.slot(sb).cliff


## The least distance between two segments in plan.
static func _gap(s: PackedVector2Array, t: PackedVector2Array) -> float:
	if Geometry2D.segment_intersects_segment(s[0], s[1], t[0], t[1]) != null:
		return 0.0
	var d: float = INF
	for q: Vector2 in [s[0], s[1]]:
		d = minf(d, q.distance_to(Geometry2D.get_closest_point_to_segment(q, t[0], t[1])))
	for q: Vector2 in [t[0], t[1]]:
		d = minf(d, q.distance_to(Geometry2D.get_closest_point_to_segment(q, s[0], s[1])))
	return d


static func _free(free: Dictionary, id: String, taken: String, node: int) -> void:
	if id != taken:
		free[id] = node


## The fixed boxes but a recipe room's (where the main span leaves it).
static func _without(p: AreaPlan, fixed: Array[AABB], slot_id: String) -> Array[AABB]:
	var skip: Dictionary = {}
	for b: AABB in p.room(slot_id).blockers:
		skip[b.abs()] = true
	var out: Array[AABB] = []
	for b: AABB in fixed:
		if not skip.has(b):
			out.append(b)
	return out


## Whether boxes meet others away from the point where they join (a box
## within 3 m of it may).
static func _meets_but_joint(boxes: Array[AABB], others: Array[AABB], joint: Vector3) -> bool:
	for b: AABB in boxes:
		if b.grow(3.0).has_point(joint):
			continue
		for o: AABB in others:
			if _overlap(b, o):
				return true
	return false


static func _meets(boxes: Array[AABB], others: Array[AABB]) -> bool:
	for b: AABB in boxes:
		for o: AABB in others:
			if _overlap(b, o):
				return true
	return false


## Whether two boxes overlap by more than 5 cm on every axis (thin ones too:
## AABB.grow would turn them inside out).
static func _overlap(a: AABB, b: AABB) -> bool:
	for k: int in 3:
		if minf(a.end[k], b.end[k]) - maxf(a.position[k], b.position[k]) <= .05:
			return false
	return true


## How long a link between two connectors would be, or -1 if they can't be
## joined: facing each other within MAX_TURN, a whole number of storeys apart,
## with room for the flights (tools/gorge_links.gd).
static func _pair_cost(a: Transform3D, b: Transform3D) -> float:
	var flat := Vector3(b.origin.x - a.origin.x, 0, b.origin.z - a.origin.z)
	var length: float = flat.length()
	if length < 4.0:
		return -1.0
	var fwd: Vector3 = flat / length
	if absf(ChasmLink._turn(-a.basis.z, fwd)) > ChasmLink.MAX_TURN or absf(ChasmLink._turn(-b.basis.z, -fwd)) > ChasmLink.MAX_TURN:
		return -1.0
	var rise: float = absf(a.origin.y - b.origin.y)
	var drop: int = roundi(rise / ChasmLink.BAY)
	if absf(rise - drop * ChasmLink.BAY) > .05 or length < maxf(drop * ChasmLink.GROUP * ChasmLink.BAY - ChasmLink.BAY, 0.0) + 1.0:
		return -1.0
	return length


## Adds the tree to the plan in the order it grew (each link's parent the room
## it left, its child the new ledge): each ledge laid out with its joined
## connectors open, each link solved as the table solved it.
static func _commit(p: AreaPlan, net: GorgeNetwork, ledges: Array[Dictionary], links: Array[Dictionary]) -> void:
	var open: Dictionary = {}      # ledge index -> [connector names]
	for l: Dictionary in links:
		for end: Array in [[l["from"], l["from_node"]], [l["to"], l["to_node"]]]:
			if int(end[1]) >= 0:
				var lg: Dictionary = ledges[end[1]]
				if not open.has(end[1]):
					open[end[1]] = []
				(open[end[1]] as Array).append(GorgeLinks.ledge_connector(end[0], lg["first"], lg["bays"]))
	var rooms: Dictionary = {}     # ledge index -> Room
	for i: int in ledges.size():
		var l: Dictionary = ledges[i]
		var lp: Dictionary = net.ledge.at(l["slot"], l["first"], l["bays"], l["seed"], open.get(i, []))
		lp["name"] = "Ledge"
		lp["display_name"] = "A Ledge"
		rooms[i] = _room(p, "ledge_%d" % (i + 1), "ledge", lp, l["xf"], l["seed"])
		if lp.has("door"):
			var door := StringName("THRESHOLD_" + str(lp["door"]))
			_add_connector(rooms[i], door, (l["xf"] as Transform3D) * (lp["connectors"][door] as Transform3D))
			rooms[i].connectors[door]["cap"] = "threshold"
			rooms[i].connectors[door]["to"] = lp["door"]
	for k: int in links.size():
		var l: Dictionary = links[k]
		var e: Dictionary = net.links.entries[l["entry"]]
		var xa: Transform3D = _connector_xf(net, e["a"])
		var xb: Transform3D = _connector_xf(net, e["b"])
		net.chasm.side_offsets = [0.0, .9, -.9]
		net.chasm.clears_dressing = true
		var lk: Dictionary = ChasmLink.join(net.chasm, xa, xb, hash([e["a"], e["b"]]) & 0x7fffffff)
		net.chasm.side_offsets = [0.0]
		net.chasm.clears_dressing = false
		if not lk["ok"]:
			p.errors.append("network: %s - %s no longer stands (%s): run tools/gorge_links.gd" % [e["a"], e["b"], lk["why"]])
			continue
		var at_from: StringName = &"SNAP_a" if e["a"] == l["from"] else &"SNAP_b"
		var at_to: StringName = &"SNAP_b" if at_from == &"SNAP_a" else &"SNAP_a"
		var from_node: int = l["from_node"]
		var to_node: int = l["to_node"]
		var main: bool = from_node == -1
		var across: bool = main or (ledges[from_node]["slot"] as FrontageSlot).cliff != (ledges[to_node]["slot"] as FrontageSlot).cliff
		lk["display_name"] = "The Span" if across else "A Cliff Stair"
		var link_room: AreaPlan.Room = _room(p, net.main_slot if main else "link_%d" % k, "link", lk, lk["xf"], hash([e["a"], e["b"]]) & 0x7fffffff)
		for name: StringName in lk["connectors"]:
			_add_connector(link_room, name, (lk["xf"] as Transform3D) * (lk["connectors"][name] as Transform3D))
		var parent_room: AreaPlan.Room = p.room(net.main_from) if main else rooms[from_node]
		var parent_conn: StringName = net.main_connector if main else GorgeLinks.ledge_connector(l["from"], ledges[from_node]["first"], ledges[from_node]["bays"])
		_add_connector(parent_room, parent_conn, parent_room.xf * (parent_room.span["connectors"][parent_conn] as Transform3D) if not main else _connector_xf(net, l["from"]))
		link_room.entry = at_from
		_cells(p, link_room)
		p.add_room(link_room)
		p.join(link_room, parent_room, parent_conn)
		var child_room: AreaPlan.Room = rooms[to_node]
		var child_conn: StringName = GorgeLinks.ledge_connector(l["to"], ledges[to_node]["first"], ledges[to_node]["bays"])
		_add_connector(child_room, child_conn, child_room.xf * (child_room.span["connectors"][child_conn] as Transform3D))
		child_room.entry = child_conn
		_cells(p, child_room)
		p.add_room(child_room)
		p.join(child_room, link_room, at_to)
	p.stats["ledges"] = ledges.size()
	p.stats["links"] = links.size()


static func _connector_xf(net: GorgeNetwork, id: String) -> Transform3D:
	if net.links.fixed.has(id):
		return net.links.fixed[id]
	return GorgeLinks.slot_connector(net.frontage, id)


## A network room from its plan (its own frame -> area by xf) and its
## blockers; its cells as it's added (_cells), its connectors as they're
## joined.
static func _room(p: AreaPlan, slot_id: String, kind: String, plan_dict: Dictionary, xf: Transform3D, seed_value: int) -> AreaPlan.Room:
	var r := AreaPlan.Room.new()
	r.slot_id = slot_id
	r.display_name = plan_dict.get("display_name", "")
	r.kind = kind
	r.span = plan_dict
	r.seed_value = seed_value
	r.xf = xf
	r.storey = AreaPlan.cell_of(xf.origin).y
	r.pinned = true
	for b: AABB in plan_dict["boxes"]:
		r.blockers.append(xf * b)
	AreaPlanner._sight_all_open(r)
	return r


## A network room's cells: its walk's, but those another room holds already
## (the 4 m grid can't follow two rooms turned to each other at their
## joint; the planner keeps them from overlapping by their boxes).
static func _cells(p: AreaPlan, r: AreaPlan.Room) -> void:
	for c: Vector3 in r.span["walk"]:
		var at: Vector3i = AreaPlan.cell_of(r.xf * (c + Vector3(0, .1, 0)))
		if p.room_at_cell(at) == null:
			r.floor_cells[at] = true
			r.cells[at] = true


static func _add_connector(r: AreaPlan.Room, name: StringName, xf: Transform3D) -> void:
	if not r.connectors.has(name):
		r.connectors[name] = {"xf": xf, "storey": AreaPlan.cell_of(xf.origin).y, "joined": "", "cap": ""}

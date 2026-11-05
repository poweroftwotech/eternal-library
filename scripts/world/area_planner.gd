class_name AreaPlanner
extends RefCounted
## Turns an AreaRecipe and a seed into an AreaPlan (phase-4-design.md 8.1.2).
## Deterministic: the same recipe and seed always give the same plan. Every
## room is laid out as data before any is built, against every room placed
## so far, so a room is the same whichever others happen to be loaded.
##
## Order: required slots in recipe order (the root at the origin, the rest on
## their parent's connector), then grow rooms on free exits (required slots'
## exits first, then the grown rooms' own), each kept only if it fits, is at
## least its grammar's min_bays long and keeps every sightline within
## max_sight_depth. Leaves keep their glowing exit stub (Q10).

## Bays kept clear straight out from a connector a pending required room will
## join (as GeneratedRoom.OCCUPIED_DOOR_BAYS); other free connectors keep one.
const PENDING_DOOR_BAYS: int = 3
## Style groups a generated room takes from the room it joins.
const INHERIT_GROUPS: PackedStringArray = ["gallery_build"]
## Once the area has its minimum rooms, a grown room ends in a plain wall with
## this chance (up to max_dead_ends of them).
const DEAD_END_CHANCE: float = 0.35
## A scene room's own cells block shrunk by this much, so a neighbour's cell
## that only touches one face stays free.
const CELL_INSET: float = 0.05

## Authored and baked scenes read once per session: "path@seed" -> info.
static var _scene_cache: Dictionary = {}


## The area seed of `recipe` in world `world_seed` (8.1.2 step 1).
static func area_seed_for(recipe: AreaRecipe, world_seed: int) -> int:
	return hash([world_seed, recipe.id]) & 0x7fffffff


## The plan of `recipe` in world `world_seed`, as the game makes it.
static func plan_world(recipe: AreaRecipe, world_seed: int, keep: Dictionary = {}) -> AreaPlan:
	return plan(recipe, area_seed_for(recipe, world_seed), keep, world_seed)


## The area a rule shared by a stratum's areas (AreaGrow.one_of) grows in, in
## world `world_seed`.
static func one_of_pick(g: AreaGrow, world_seed: int) -> String:
	return g.one_of[(hash([world_seed, "one_of", g.slot_prefix]) & 0x7fffffff) % g.one_of.size()]


## `keep`: slot -> scene path a save recorded for a room with scene choices
## (Q5): that choice stands even if the weights changed since.
static func plan(recipe: AreaRecipe, area_seed: int, keep: Dictionary = {}, world_seed: int = -1) -> AreaPlan:
	var t0: int = Time.get_ticks_usec()
	var p := AreaPlan.new()
	p.world_seed = world_seed
	p.area_id = recipe.id
	p.display_name = recipe.display_name
	p.area_seed = area_seed
	p.recipe_version = recipe.version
	p.room_count = recipe.room_count
	p.max_sight_depth = recipe.max_sight_depth
	p.placement = recipe.placement if recipe.placement != null else AreaPlacement.new()
	p.open_sight = recipe.open_sight
	p.stats = {"tried": 0, "boxed_in": 0, "too_short": 0, "sightline": 0, "grow": []}
	for s: AreaSlot in recipe.slots:
		if s == null:
			continue
		var r: AreaPlan.Room = _place_slot(p, recipe, s, keep)
		if r == null:
			continue
	_grow(p, recipe)
	if recipe.network != null:
		AreaNetwork.plan(p, recipe.network)
	_plain_backed_walls(p)
	_gables_at_ring_doors(p)
	var sight: Dictionary = p.compute_sight()
	for v: String in sight["violations"]:
		p.errors.append(v)
	p.stats["lines"] = sight["lines"]
	p.stats["deepest"] = sight["deepest"]
	p.plan_ms = (Time.get_ticks_usec() - t0) / 1000.0
	return p


static func _seed_for(p: AreaPlan, slot_id: String) -> int:
	return hash([p.area_seed, slot_id, "seed"]) & 0x7fffffff


## A required slot: placed, joined to its parent, recorded. Null (and an error)
## if it can't be.
static func _place_slot(p: AreaPlan, recipe: AreaRecipe, s: AreaSlot, keep: Dictionary = {}) -> AreaPlan.Room:
	var parent_room: AreaPlan.Room = null
	if s.parent != "":
		parent_room = p.room(s.parent)
		if parent_room == null or not parent_room.connectors.has(s.connector):
			p.errors.append("%s: parent %s has no connector %s (place the parent first)" % [s.slot_id, s.parent, s.connector])
			return null
		if str(parent_room.connectors[s.connector]["joined"]) != "":
			p.errors.append("%s: %s %s is already joined" % [s.slot_id, s.parent, s.connector])
			return null
	elif not p.rooms.is_empty():
		p.errors.append("%s: only the first slot may be the root" % s.slot_id)
		return null
	var r: AreaPlan.Room
	var scene: PackedScene = s.scene
	if not s.scene_choices.is_empty():
		scene = _pick_scene(p, s, str(keep.get(s.slot_id, "")))
		p.variants[s.slot_id] = scene.resource_path
	if scene != null:
		var info: Dictionary = _scene_info(scene, -1)     # FIXED: the scene's own preview_seed (a bake keeps its seed there)
		var seed_value: int = int(info["seed"]) if s.seed_mode == AreaSlot.SeedMode.FIXED else _seed_for(p, s.slot_id)
		if s.seed_mode == AreaSlot.SeedMode.AREA:
			info = _scene_info(scene, seed_value)
		r = _scene_room(p, s.slot_id, s.display_name, scene, info, seed_value, parent_room, s.connector)
		if r == null:
			return null
	elif s.grammar is ChasmGrammar:
		var seed_value: int = s.fixed_seed if s.seed_mode == AreaSlot.SeedMode.FIXED else _seed_for(p, s.slot_id)
		r = _span_room(p, s, seed_value, parent_room)
		if r == null:
			return null
	else:
		var seed_value: int = s.fixed_seed if s.seed_mode == AreaSlot.SeedMode.FIXED else _seed_for(p, s.slot_id)
		r = _generated_room(p, recipe, s.slot_id, s.display_name, s.grammar, s.rules, seed_value, parent_room, s.connector, "exit")
		var why: String = _fault(r, s.grammar)
		if why != "":
			p.errors.append("%s (seed %d) on %s %s: %s" % [s.slot_id, seed_value, s.parent, s.connector, why])
	r.pinned = s.pinned
	for name: StringName in s.thresholds:
		if r.connectors.has(name) and str(r.connectors[name]["joined"]) == "":
			r.connectors[name]["cap"] = "threshold"
			r.connectors[name]["to"] = str(s.thresholds[name])
			if String(name).begins_with("SNAP_exit"):
				_drop_stub(r, name)
			break
	p.add_room(r)
	if parent_room != null:
		p.join(r, parent_room, s.connector)
		_inherit(r, parent_room)
		if String(s.connector).begins_with("SNAP_exit"):
			_drop_stub(parent_room, s.connector)
	return r


## Which of a slot's scene choices it gets: the one the save kept, the pinned
## one, or a roll: equal weights as before phase 10 (hash % n), else weighted.
static func _pick_scene(p: AreaPlan, s: AreaSlot, kept: String) -> PackedScene:
	for sc: PackedScene in s.scene_choices:
		if kept != "" and sc != null and sc.resource_path == kept:
			return sc
	var n: int = s.scene_choices.size()
	if s.pinned_choice >= 0 and s.pinned_choice < n:
		return s.scene_choices[s.pinned_choice]
	var roll: int = hash([p.area_seed, s.slot_id, "scene"]) & 0x7fffffff
	var w: PackedFloat32Array = s.scene_weights
	var equal: bool = w.size() != n or Array(w).all(func(x: float) -> bool: return is_equal_approx(x, w[0]))
	if equal:
		return s.scene_choices[roll % n]
	var total: float = 0.0
	for x: float in w:
		total += maxf(x, 0.0)
	if total <= 0.0:
		return s.scene_choices[roll % n]
	var rng := RandomNumberGenerator.new()
	rng.seed = roll
	var at: float = rng.randf() * total
	for i: int in n:
		at -= maxf(w[i], 0.0)
		if at < 0.0:
			return s.scene_choices[i]
	return s.scene_choices[n - 1]


## Why a planned generated room can't be used ("" = it can).
static func _fault(r: AreaPlan.Room, grammar: RoomGrammar) -> String:
	if r.grid == null or r.grid.cells.is_empty():
		return "boxed in (no cells)"
	var problems: PackedStringArray = r.grid.check()
	if not problems.is_empty():
		return "layout problems %s" % [problems]
	var min_bays: Variant = grammar.get("min_bays")
	if min_bays != null and r.grid.run_order().size() < int(min_bays):
		return "only %d bays (min_bays %d)" % [r.grid.run_order().size(), int(min_bays)]
	return ""


static func _grow(p: AreaPlan, recipe: AreaRecipe) -> void:
	for g: AreaGrow in recipe.grow:
		if g == null or g.grammar == null:
			continue
		if not g.one_of.is_empty() and p.world_seed >= 0 and one_of_pick(g, p.world_seed) != recipe.id:
			(p.stats["grow"] as Array).append({"prefix": g.slot_prefix, "rolled": 0, "want": 0, "added": 0, "doors": 0, "taken": 0, "tried": 0,
				"boxed_in": 0, "too_short": 0, "sightline": 0, "ruled_out": 0, "near_entrance": 0, "other_area": one_of_pick(g, p.world_seed)})
			continue     # this world puts it in another area of the stratum
		var n: int = 0     # per grow entry: its rooms are <slot_prefix>_1, _2 …
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([p.area_seed, "grow_count", g.slot_prefix])
		var want: int = rng.randi_range(mini(g.count.x, g.count.y), maxi(g.count.x, g.count.y))
		var rolled: int = want
		# Never more than the rule's own count (Q4): only the area's maximum lowers
		# it. (Before phase 10 step 2 it was raised to reach the area's minimum.)
		want = clampi(want, 0, maxi(recipe.room_count.y - p.rooms.size(), 0))
		# What this rule did and why it fell short (the Strata Board shows it).
		var gs: Dictionary = {"prefix": g.slot_prefix, "rolled": rolled, "want": want, "added": 0, "doors": 0,
			"taken": 0, "tried": 0, "boxed_in": 0, "too_short": 0, "sightline": 0, "ruled_out": 0, "near_entrance": 0}
		# Free exits, required rooms' first, each tier in seeded order.
		var candidates: Array = _free_exits(p, p.rooms, g, hash([p.area_seed, "grow_order", g.slot_prefix, 0]), gs)
		gs["doors"] = candidates.size()
		var dead_ends: int = 0
		var added: int = 0
		(p.stats["grow"] as Array).append(gs)
		while added < want and not candidates.is_empty():
			var c: Array = candidates.pop_front()
			var parent_room: AreaPlan.Room = c[0]
			var conn: StringName = c[1]
			if str(parent_room.connectors[conn]["joined"]) != "":
				gs["taken"] += 1
				continue
			if parent_room.depth + 1 < g.min_depth:
				gs["near_entrance"] += 1
				continue
			var slot_id: String = "%s_%d" % [g.slot_prefix, n + 1]
			var seed_value: int = _seed_for(p, slot_id)
			var end_kind: String = "exit"
			if p.rooms.size() + 1 >= recipe.room_count.x and dead_ends < recipe.max_dead_ends:
				var roll := RandomNumberGenerator.new()
				roll.seed = hash([p.area_seed, "dead_end", slot_id])
				if roll.randf() < DEAD_END_CHANCE:
					end_kind = "dead_end"
			p.stats["tried"] += 1
			gs["tried"] += 1
			var r: AreaPlan.Room = _generated_room(p, recipe, slot_id, g.display_name, g.grammar, g.rules, seed_value, parent_room, conn, end_kind)
			var why: String = _fault(r, g.grammar)
			if why != "":
				p.stats["too_short" if why.begins_with("only") else "boxed_in"] += 1
				gs["too_short" if why.begins_with("only") else "boxed_in"] += 1
				continue
			r.pinned = g.pinned
			p.add_room(r)
			p.join(r, parent_room, conn)
			if not p.compute_sight(r.slot_id)["violations"].is_empty():
				p.remove_last()
				p.stats["sightline"] += 1
				gs["sightline"] += 1
				continue
			_inherit(r, parent_room)
			_drop_stub(parent_room, conn)
			n += 1
			added += 1
			gs["added"] = added
			if end_kind == "dead_end":
				dead_ends += 1
			var more: Array = _free_exits(p, [r], g, hash([p.area_seed, "grow_order", g.slot_prefix, n]), gs)
			gs["doors"] += more.size()
			candidates.append_array(more)


## [[room, connector], ...] free exits of `among` that `g` may grow from, shuffled by
## `order_seed`: a never door in the connection table left out (counted in
## gs.ruled_out), a preferred one more likely first.
static func _free_exits(p: AreaPlan, among: Array, g: AreaGrow, order_seed: int, gs: Dictionary = {}) -> Array:
	var out: Array = []
	var table: ConnectionTable = ConnectionTable.default()
	var to_type: String = RoomTypes.of_resource(g.grammar)
	var weighted: bool = false
	for r: AreaPlan.Room in among:
		if not g.from.is_empty() and not g.from.has(r.slot_id):
			continue
		var names: Array = r.connectors.keys()
		# By text: StringNames sort by where they sit in memory, so plain sort()
		# gave the first plan in a process a different order from later ones.
		names.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
		for name: StringName in names:
			if String(name).begins_with("SNAP_exit") and str(r.connectors[name]["joined"]) == "" and str(r.connectors[name]["cap"]) != "threshold":
				var rule: String = table.rule(r.room_type, to_type) if not table.is_empty() else ConnectionTable.ALLOWED
				if rule == ConnectionTable.NEVER:
					gs["ruled_out"] = int(gs.get("ruled_out", 0)) + 1
					continue
				weighted = weighted or rule == ConnectionTable.PREFERRED
				out.append([r, name])
	var rng := RandomNumberGenerator.new()
	rng.seed = order_seed
	if weighted:     # a seeded weighted shuffle: each door's key is u^(1/w), highest first
		var keyed: Array = []
		for c: Array in out:
			var w: float = ConnectionTable.PREFER_WEIGHT if table.rule((c[0] as AreaPlan.Room).room_type, to_type) == ConnectionTable.PREFERRED else 1.0
			keyed.append([pow(rng.randf(), 1.0 / w), c])
		keyed.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
		return keyed.map(func(k: Array) -> Array: return k[1])
	for i: int in range(out.size() - 1, 0, -1):     # Fisher-Yates, seeded
		var j: int = rng.randi_range(0, i)
		var t: Variant = out[i]
		out[i] = out[j]
		out[j] = t
	return out


## Style groups a generated room takes from the room it joins.
static func _inherit(r: AreaPlan.Room, parent_room: AreaPlan.Room) -> void:
	if r.kind != "generated":
		return
	for g: String in INHERIT_GROUPS:
		var idx: int = -1
		if parent_room.kind == "generated":
			idx = int(parent_room.style_overrides.get(g, -1))
		else:
			idx = int((_scene_info(parent_room.scene, parent_room.seed_value)["styles"] as Dictionary).get(g, -1))
		if idx >= 0:
			r.style_overrides[g] = idx


## A room now joins `parent_room` at `conn`: its exit stub goes (a generated
## parent's planned prop, or a baked parent's node).
static func _drop_stub(parent_room: AreaPlan.Room, conn: StringName) -> void:
	var k: String = String(conn).trim_prefix("SNAP_exit_")
	if parent_room.grid != null:
		parent_room.grid.props.erase("exit_" + k)
	else:
		parent_room.drop_nodes.append("Dressing/prop_exit_" + k)


# --- rooms -------------------------------------------------------------------------

## Where a room goes so its entry meets `conn` of `parent_room` face to face
## (as GeneratedRoom._join).
static func _joined_xf(parent_room: AreaPlan.Room, conn: StringName, entry_local: Transform3D) -> Transform3D:
	var at: Transform3D = parent_room.connectors[conn]["xf"]
	return at * Transform3D(Basis(Vector3.UP, PI)) * entry_local.affine_inverse()


static func _scene_room(p: AreaPlan, slot_id: String, display_name: String, scene: PackedScene, info: Dictionary,
		seed_value: int, parent_room: AreaPlan.Room, conn: StringName) -> AreaPlan.Room:
	var r := AreaPlan.Room.new()
	r.slot_id = slot_id
	r.display_name = display_name if display_name != "" else str(info["display_name"])
	r.kind = "scene"
	r.scene = scene
	r.room_type = RoomTypes.of_resource(scene)
	r.seed_value = seed_value
	if parent_room != null:
		if not info["connectors"].has(&"SNAP_entry"):
			p.errors.append("%s: %s has no SNAP_entry to join by" % [slot_id, scene.resource_path])
			return null
		r.entry = &"SNAP_entry"
		r.xf = _joined_xf(parent_room, conn, info["connectors"][&"SNAP_entry"])
	r.storey = AreaPlan.cell_of(r.xf.origin).y
	for name: StringName in info["connectors"]:
		var xf: Transform3D = r.xf * (info["connectors"][name] as Transform3D)
		r.connectors[name] = {"xf": xf, "storey": AreaPlan.cell_of(xf.origin).y, "joined": "",
			"cap": "glow" if String(name).begins_with("SNAP_exit") else ("" if name == r.entry else "open")}
	for box: AABB in info["boxes"]:
		r.blockers.append(r.xf * box)
	for box: AABB in info["recess_cavities"]:
		r.recess_cavities.append(r.xf * box)
	for c: Vector3i in info["cells"]:
		var at: Vector3i = AreaPlan.cell_of(r.xf * _centre(c))
		for s: int in range(info["storeys"].x, info["storeys"].y + 1):
			r.cells[Vector3i(at.x, at.y + s, at.z)] = true
			# Its cells block whole, as a generated room's do: a room's open
			# middle has no module mesh in it, and a grown gallery threaded
			# through the Reading Room (library wing, world seed 5).
			r.blockers.append(AreaPlan.cell_box(Vector3i(at.x, at.y + s, at.z)).grow(-CELL_INSET))
		r.floor_cells[at] = true
	if (info["walk"] as Array).is_empty():
		_sight_all_open(r)
	for w: Array in info["walk"]:     # a baked room keeps its grid's open edges (RoomBaker)
		r.sight[AreaPlan.key_between(AreaPlan.cell_of(r.xf * _centre(w[0])), AreaPlan.cell_of(r.xf * _centre(w[1])))] = w[2]
	for c: Vector3i in info["blocked"]:
		r.blocked_cells[AreaPlan.cell_of(r.xf * _centre(c))] = true
	return r


## A span (phase-6-design.md 5.7.4) from the parent's connector out over the
## gorge, solved by its ChasmGrammar. Its far ledge's connectors are exits
## for later steps.
static func _span_room(p: AreaPlan, s: AreaSlot, seed_value: int, parent_room: AreaPlan.Room) -> AreaPlan.Room:
	if parent_room == null:
		p.errors.append("%s: a span starts from a parent's connector" % s.slot_id)
		return null
	var r := AreaPlan.Room.new()
	r.slot_id = s.slot_id
	r.display_name = s.display_name
	r.kind = "span"
	r.grammar = s.grammar
	r.room_type = "R10"
	r.seed_value = seed_value
	r.entry = &"SNAP_entry"
	r.xf = _joined_xf(parent_room, s.connector, ChasmGrammar.ENTRY)
	r.storey = AreaPlan.cell_of(r.xf.origin).y
	r.span = (s.grammar as ChasmGrammar).solve(r.xf, seed_value)
	if not r.span["ok"]:
		p.errors.append("%s (seed %d): %s" % [s.slot_id, seed_value, r.span["why"]])
	for name: StringName in r.span["connectors"]:
		var xf: Transform3D = r.xf * (r.span["connectors"][name] as Transform3D)
		r.connectors[name] = {"xf": xf, "storey": AreaPlan.cell_of(xf.origin).y, "joined": "", "cap": "" if name == r.entry else "glow"}
	for c: Vector3 in r.span["walk"]:
		var at: Vector3i = AreaPlan.cell_of(r.xf * (c + Vector3(0, .1, 0)))
		r.floor_cells[at] = true
		r.cells[at] = true
		r.blockers.append(r.xf * AABB(c - Vector3(2, 0, 2), Vector3(4, CellGrid.CELL_HEIGHT, 4)))
	for b: AABB in r.span["boxes"]:
		r.blockers.append(r.xf * b)
	_sight_all_open(r)
	return r


## How abandoned the stacks are where a room opens off `parent` (stacks rework,
## StackGalleryGrammar.abandon_over_bays): a gallery's far end carries on into
## the next gallery; the lived-in rooms (the Reading Room, the caravanserai,
## the hall) start the stacks kept; the Light-Well Stair and the Cistern Archive
## are further out.
static func _abandon_after(parent: AreaPlan.Room) -> float:
	if parent == null:
		return 0.0
	if parent.grid != null and parent.grid.meta.has("abandon_end"):
		return float(parent.grid.meta["abandon_end"])
	return {"R09": 0.35, "R11": 0.5}.get(parent.room_type, 0.0)


static func _generated_room(p: AreaPlan, recipe: AreaRecipe, slot_id: String, display_name: String, grammar: RoomGrammar,
		rules: ModuleRules, seed_value: int, parent_room: AreaPlan.Room, conn: StringName, end_kind: String) -> AreaPlan.Room:
	var r := AreaPlan.Room.new()
	r.slot_id = slot_id
	r.display_name = display_name
	r.kind = "generated"
	r.grammar = grammar
	r.room_type = RoomTypes.of_resource(grammar)
	r.rules = rules
	r.seed_value = seed_value
	r.end_kind = end_kind
	r.entry = &"SNAP_entry" if parent_room != null else &""
	if parent_room != null:
		r.xf = _joined_xf(parent_room, conn, GeneratedRoom.ENTRY)
	r.storey = AreaPlan.cell_of(r.xf.origin).y
	var grid := CellGrid.new()
	grid.end_kind = end_kind
	grid.quiet = true
	grid.root = parent_room == null
	var to_local: Transform3D = r.xf.affine_inverse()
	for b: AABB in _blockers(p, recipe, parent_room, conn):
		grid.blockers.append(to_local * b)
	if grammar == null:
		r.grid = grid
		return r
	grid.meta["abandon_start"] = _abandon_after(parent_room)
	grammar.layout(grid, seed_value)
	grammar.wear_lanes(grid, seed_value)
	r.grid = grid
	if parent_room != null:
		r.connectors[&"SNAP_entry"] = {"xf": r.xf * GeneratedRoom.ENTRY, "storey": r.storey, "joined": "", "cap": ""}
	for k: String in grid.edges:
		var e: Dictionary = grid.edges[k]
		if e["mark"] == CellGrid.Mark.DOOR and not e["host"]:
			var xf: Transform3D = r.xf * CellGrid.door_transform(e["cell"], e["side"])
			r.connectors[StringName("SNAP_exit_" + k)] = {"xf": xf, "storey": AreaPlan.cell_of(xf.origin).y, "joined": "", "cap": "glow"}
	var tall: int = floori((CellGrid.CELL_HEIGHT - 0.01) / CellGrid.BAY)
	var to_area: Dictionary = {}     # grid cell -> area cell
	for c: Vector3i in grid.cells:
		var at: Vector3i = AreaPlan.cell_of(r.xf * _centre(c))
		to_area[c] = at
		r.floor_cells[at] = true
		if grid.cells[c].get("blocked", false):
			r.blocked_cells[at] = true
		for s: int in tall + 1:
			r.cells[Vector3i(at.x, at.y + s, at.z)] = true
		r.blockers.append(r.xf * AABB(Vector3(c.x * CellGrid.BAY, c.y * CellGrid.BAY, -c.z * CellGrid.BAY - CellGrid.BAY),
			Vector3(CellGrid.BAY, CellGrid.CELL_HEIGHT, CellGrid.BAY)))
	for k: String in grid.edges:
		var e: Dictionary = grid.edges[k]
		var n: Vector3i = CellGrid.neighbour(e["cell"], e["side"])
		if not grid.cells.has(n):
			continue
		var half: float = AreaPlan.OPEN_HALF if e["mark"] == CellGrid.Mark.OPEN else (AreaPlan.ARCH_HALF if e["mark"] == CellGrid.Mark.OPENING else -1.0)
		if half > 0.0:
			r.sight[AreaPlan.key_between(to_area[e["cell"]], to_area[n])] = half
	return r


## A generated room's solid wall backing onto a cell another room stands in
## is a plain wall (slot edge:plain): a shelf recess there would dig 0.25 m into
## the room behind it (its door, a fern, the other room's own recess). A
## grammar's own wall slots (a corner) are kept; a collapsed bay's recess
## becomes a plain wall too (its rubble stays).
static func _plain_backed_walls(p: AreaPlan) -> void:
	for r: AreaPlan.Room in p.rooms:
		if r.grid == null:
			continue
		for k: String in r.grid.edges:
			var e: Dictionary = r.grid.edges[k]
			if e["mark"] != CellGrid.Mark.SOLID or e.get("slot", "") not in ["", "edge:solid", "edge:recess"]:
				continue
			var n: Vector3i = CellGrid.neighbour(e["cell"], e["side"])
			if r.grid.cells.has(n):
				continue
			var behind: Vector3i = AreaPlan.cell_of(r.xf * _centre(n))
			if p.rooms.any(func(o: AreaPlan.Room) -> bool: return o != r and o.cells.has(behind)):
				e["slot"] = "edge:plain"
				# A recess pin goes with the recess; "no seam debris" (a hall's tall
				# case beside it) holds on a plain wall too.
				if r.grid.pins.get("edge_" + k, "") != "nothing":
					r.grid.pins.erase("edge_" + k)


## A light-well's doorway is a plain arched wall the height of a storey and it
## builds no gables, so a room it opens into closes its own vault over that
## doorway (room rework step 6: the Upper Stacks' vault end stood open onto
## the cone's outside). RoomBuilder places a gable on a door edge marked so.
static func _gables_at_ring_doors(p: AreaPlan) -> void:
	for r: AreaPlan.Room in p.rooms:
		if r.grid == null:
			continue
		for k: String in r.grid.edges:
			var e: Dictionary = r.grid.edges[k]
			if e["mark"] != CellGrid.Mark.DOOR or not e["host"]:
				continue
			var behind: Vector3i = AreaPlan.cell_of(r.xf * _centre(CellGrid.neighbour(e["cell"], e["side"])))
			for o: AreaPlan.Room in p.rooms:
				if o != r and o.grid != null and o.cells.has(behind) and bool(o.grid.meta.get("ring", false)):
					e["gable"] = true


## Every edge between two of a scene room's floor cells is open to sight (its
## inner walls aren't modelled: the conservative choice).
static func _sight_all_open(r: AreaPlan.Room) -> void:
	for c: Vector3i in r.floor_cells:
		for side: int in [CellGrid.Side.N, CellGrid.Side.E]:
			var n: Vector3i = CellGrid.neighbour(c, side)
			if r.floor_cells.has(n):
				r.sight[CellGrid.key(c, side)] = AreaPlan.OPEN_HALF


## What a new room's layout keeps out of (area frame): every placed room, the
## bay outside every free connector but the one it joins (three bays where a
## required room is still to come), and everything outside the envelope.
static func _blockers(p: AreaPlan, recipe: AreaRecipe, parent_room: AreaPlan.Room, conn: StringName) -> Array[AABB]:
	var out: Array[AABB] = []
	var pending: Dictionary = {}     # "slot/connector" a required room will join
	for s: AreaSlot in recipe.slots:
		if s != null and s.parent != "" and p.room(s.slot_id) == null:
			pending["%s/%s" % [s.parent, s.connector]] = true
	for r: AreaPlan.Room in p.rooms:
		out.append_array(r.blockers)
		for name: StringName in r.connectors:
			if (r == parent_room and name == conn) or str(r.connectors[name]["joined"]) != "":
				continue
			var bays: int = PENDING_DOOR_BAYS if pending.has("%s/%s" % [r.slot_id, name]) else 1
			for i: int in bays:
				out.append(_bay_outside(r.connectors[name]["xf"], i))
	var env: AABB = p.placement.envelope
	const FAR: float = 4096.0
	out.append(AABB(Vector3(env.position.x - FAR, -FAR, -FAR), Vector3(FAR, FAR * 2, FAR * 2)))      # west
	out.append(AABB(Vector3(env.end.x, -FAR, -FAR), Vector3(FAR, FAR * 2, FAR * 2)))                 # east
	out.append(AABB(Vector3(-FAR, -FAR, env.position.z - FAR), Vector3(FAR * 2, FAR * 2, FAR)))      # north
	out.append(AABB(Vector3(-FAR, -FAR, env.end.z), Vector3(FAR * 2, FAR * 2, FAR)))                 # south
	out.append(AABB(Vector3(-FAR, env.end.y, -FAR), Vector3(FAR * 2, FAR, FAR * 2)))                 # above
	out.append(AABB(Vector3(-FAR, env.position.y - FAR, -FAR), Vector3(FAR * 2, FAR, FAR * 2)))      # below
	return out


## The area-frame cell box `depth` bays out from a connector (-Z points out).
static func _bay_outside(at: Transform3D, depth: int = 0) -> AABB:
	var centre: Vector3 = at.origin - at.basis.z.normalized() * CellGrid.BAY * (depth + 0.5)
	return AABB(centre - Vector3(2, 0, 2), Vector3(4, CellGrid.CELL_HEIGHT, 4))


static func _centre(c: Vector3i) -> Vector3:
	return CellGrid.cell_centre(c) + Vector3(0, 0.1, 0)


# --- authored and baked scenes ---------------------------------------------------------

## A recess edge module's cavity past its wall line, in the module's frame: the
## 3 m arch opening, 3.45 m up, 0.25 m deep (tools/kit_seed_walls.py's cutter).
const RECESS_CAVITY: AABB = AABB(Vector3(0.5, 0.0, 0.0), Vector3(3.0, 3.45, 0.25))


## What the planner needs from an authored or baked room, read from an off-tree
## instance once per session (seed -1: the scene's own preview_seed): {seed,
## display_name, connectors {name: room-frame Transform3D}, boxes (room-frame
## module boxes, as GeneratedRoom._module_boxes), cells (room-frame grid cells
## its CELL modules stand on, storey 0), storeys (Vector2i: lowest and highest
## storey above the floor its modules reach), styles {group: index},
## recess_cavities (room-frame boxes, RECESS_CAVITY of each recess module),
## and from a bake (phase 5 step 5): walk ([cell, cell, sight half] open
## edges), blocked cells, layout (the grammar's meta) and spawn (PlayerSpawn)}.
static func _scene_info(scene: PackedScene, seed_value: int) -> Dictionary:
	var key: String = "%s@%d" % [scene.resource_path, seed_value]
	if _scene_cache.has(key):
		return _scene_cache[key]
	var room := scene.instantiate() as RoomTemplate
	var baked: Dictionary = room.get_meta("baked_from", {})
	var spawn: Node3D = room.get_node_or_null("PlayerSpawn") as Node3D
	var info: Dictionary = {"seed": room.preview_seed if seed_value < 0 else seed_value, "display_name": room.display_name,
		"connectors": {}, "boxes": [], "cells": {}, "storeys": Vector2i.ZERO, "styles": {}, "recess_cavities": [],
		"walk": baked.get("walk", []), "blocked": baked.get("blocked", []), "layout": baked.get("layout", {}),
		"spawn": KitValidateRoom._relative(room, spawn) if spawn != null else Transform3D()}
	var holder: Node = room.get_node_or_null("Connectors")
	for c: Node in holder.get_children() if holder != null else []:
		if c is Node3D:
			info["connectors"][c.name] = KitValidateRoom._relative(room, c as Node3D)
	var found: Array[KitModule] = []
	KitValidateRoom._modules(room, found)
	var top: float = 0.0
	for m: KitModule in found:
		if m.shape == KitModule.Shape.FREE or m.shape == KitModule.Shape.POST:
			continue
		if m.edge == "recess":
			(info["recess_cavities"] as Array).append(KitValidateRoom._relative(room, m) * RECESS_CAVITY)
		var module_box := AABB()
		var first: bool = true
		for node: Node in m.find_children("*", "MeshInstance3D", true, false):
			var mi := node as MeshInstance3D
			if mi.mesh == null:
				continue
			var box: AABB = KitValidateRoom._relative(room, mi) * mi.get_aabb()
			(info["boxes"] as Array).append(box)
			module_box = box if first else module_box.merge(box)
			first = false
			top = maxf(top, box.end.y)
		if m.shape == KitModule.Shape.CELL and not first and KitValidateRoom._relative(room, m).origin.y < 1.0:
			# Ground-storey cell modules: every cell whose centre the module covers.
			for x: int in range(floori(module_box.position.x / CellGrid.BAY), ceili(module_box.end.x / CellGrid.BAY)):
				for z: int in range(floori(-module_box.end.z / CellGrid.BAY), ceili(-module_box.position.z / CellGrid.BAY)):
					var centre := Vector3(x * CellGrid.BAY + 2.0, 0.0, -z * CellGrid.BAY - 2.0)
					if centre.x > module_box.position.x and centre.x < module_box.end.x \
							and centre.z > module_box.position.z and centre.z < module_box.end.z:
						info["cells"][Vector3i(x, 0, z)] = true
	# Plain stone a baked room marks as blocking (tools/bake_overlook.gd: its
	# piers), which no kit module carries.
	for node: Node in room.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh != null and mi.is_in_group(&"blocker"):
			(info["boxes"] as Array).append(KitValidateRoom._relative(room, mi) * mi.get_aabb())
	info["storeys"] = Vector2i(0, maxi(floori((top - 0.01) / CellGrid.BAY), 0))
	var effective: int = int(info["seed"])
	for g: String in INHERIT_GROUPS:
		var idx: int = room.style_choice(g, effective)
		if idx >= 0:
			info["styles"][g] = idx
	room.free()
	_scene_cache[key] = info
	return info

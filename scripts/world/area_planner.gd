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

## Authored and baked scenes read once per session: "path@seed" -> info.
static var _scene_cache: Dictionary = {}


## The area seed of `recipe` in world `world_seed` (8.1.2 step 1).
static func area_seed_for(recipe: AreaRecipe, world_seed: int) -> int:
	return hash([world_seed, recipe.id]) & 0x7fffffff


static func plan(recipe: AreaRecipe, area_seed: int) -> AreaPlan:
	var t0: int = Time.get_ticks_usec()
	var p := AreaPlan.new()
	p.area_id = recipe.id
	p.display_name = recipe.display_name
	p.area_seed = area_seed
	p.recipe_version = recipe.version
	p.room_count = recipe.room_count
	p.max_sight_depth = recipe.max_sight_depth
	p.placement = recipe.placement if recipe.placement != null else AreaPlacement.new()
	p.stats = {"tried": 0, "boxed_in": 0, "too_short": 0, "sightline": 0}
	for s: AreaSlot in recipe.slots:
		if s == null:
			continue
		var r: AreaPlan.Room = _place_slot(p, recipe, s)
		if r == null:
			continue
	_grow(p, recipe)
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
static func _place_slot(p: AreaPlan, recipe: AreaRecipe, s: AreaSlot) -> AreaPlan.Room:
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
	if s.scene != null:
		var info: Dictionary = _scene_info(s.scene, -1)     # FIXED: the scene's own preview_seed (a bake keeps its seed there)
		var seed_value: int = int(info["seed"]) if s.seed_mode == AreaSlot.SeedMode.FIXED else _seed_for(p, s.slot_id)
		if s.seed_mode == AreaSlot.SeedMode.AREA:
			info = _scene_info(s.scene, seed_value)
		r = _scene_room(p, s.slot_id, s.display_name, s.scene, info, seed_value, parent_room, s.connector)
		if r == null:
			return null
	else:
		var seed_value: int = s.fixed_seed if s.seed_mode == AreaSlot.SeedMode.FIXED else _seed_for(p, s.slot_id)
		r = _generated_room(p, recipe, s.slot_id, s.display_name, s.grammar, s.rules, seed_value, parent_room, s.connector, "exit")
		var why: String = _fault(r, s.grammar)
		if why != "":
			p.errors.append("%s (seed %d) on %s %s: %s" % [s.slot_id, seed_value, s.parent, s.connector, why])
	r.pinned = s.pinned
	p.add_room(r)
	if parent_room != null:
		p.join(r, parent_room, s.connector)
		_inherit(r, parent_room)
		if String(s.connector).begins_with("SNAP_exit"):
			_drop_stub(parent_room, s.connector)
	return r


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
	var n: int = 0
	for g: AreaGrow in recipe.grow:
		if g == null or g.grammar == null:
			continue
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([p.area_seed, "grow_count", g.slot_prefix])
		var want: int = rng.randi_range(mini(g.count.x, g.count.y), maxi(g.count.x, g.count.y))
		want = clampi(want, recipe.room_count.x - p.rooms.size(), recipe.room_count.y - p.rooms.size())
		# Free exits, required rooms' first, each tier in seeded order.
		var candidates: Array = _free_exits(p, p.rooms, g, hash([p.area_seed, "grow_order", g.slot_prefix, 0]))
		var dead_ends: int = 0
		var added: int = 0
		while added < want and not candidates.is_empty():
			var c: Array = candidates.pop_front()
			var parent_room: AreaPlan.Room = c[0]
			var conn: StringName = c[1]
			if str(parent_room.connectors[conn]["joined"]) != "":
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
			var r: AreaPlan.Room = _generated_room(p, recipe, slot_id, g.display_name, g.grammar, g.rules, seed_value, parent_room, conn, end_kind)
			var why: String = _fault(r, g.grammar)
			if why != "":
				p.stats["too_short" if why.begins_with("only") else "boxed_in"] += 1
				continue
			p.add_room(r)
			p.join(r, parent_room, conn)
			if not p.compute_sight(r.slot_id)["violations"].is_empty():
				p.remove_last()
				p.stats["sightline"] += 1
				continue
			_inherit(r, parent_room)
			_drop_stub(parent_room, conn)
			n += 1
			added += 1
			if end_kind == "dead_end":
				dead_ends += 1
			candidates.append_array(_free_exits(p, [r], g, hash([p.area_seed, "grow_order", g.slot_prefix, n])))


## [[room, connector], ...] free exits of `among` that `g` may grow from, shuffled by `order_seed`.
static func _free_exits(p: AreaPlan, among: Array, g: AreaGrow, order_seed: int) -> Array:
	var out: Array = []
	for r: AreaPlan.Room in among:
		if not g.from.is_empty() and not g.from.has(r.slot_id):
			continue
		var names: Array = r.connectors.keys()
		names.sort()
		for name: StringName in names:
			if String(name).begins_with("SNAP_exit") and str(r.connectors[name]["joined"]) == "":
				out.append([r, name])
	var rng := RandomNumberGenerator.new()
	rng.seed = order_seed
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
		r.floor_cells[at] = true
	_sight_all_open(r)
	return r


static func _generated_room(p: AreaPlan, recipe: AreaRecipe, slot_id: String, display_name: String, grammar: RoomGrammar,
		rules: ModuleRules, seed_value: int, parent_room: AreaPlan.Room, conn: StringName, end_kind: String) -> AreaPlan.Room:
	var r := AreaPlan.Room.new()
	r.slot_id = slot_id
	r.display_name = display_name
	r.kind = "generated"
	r.grammar = grammar
	r.rules = rules
	r.seed_value = seed_value
	r.end_kind = end_kind
	r.entry = &"SNAP_entry"
	if parent_room != null:
		r.xf = _joined_xf(parent_room, conn, GeneratedRoom.ENTRY)
	r.storey = AreaPlan.cell_of(r.xf.origin).y
	var grid := CellGrid.new()
	grid.end_kind = end_kind
	grid.quiet = true
	var to_local: Transform3D = r.xf.affine_inverse()
	for b: AABB in _blockers(p, recipe, parent_room, conn):
		grid.blockers.append(to_local * b)
	if grammar == null:
		r.grid = grid
		return r
	grammar.layout(grid, seed_value)
	grammar.wear_lanes(grid, seed_value)
	r.grid = grid
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
## recess_cavities (room-frame boxes, RECESS_CAVITY of each recess module)}.
static func _scene_info(scene: PackedScene, seed_value: int) -> Dictionary:
	var key: String = "%s@%d" % [scene.resource_path, seed_value]
	if _scene_cache.has(key):
		return _scene_cache[key]
	var room := scene.instantiate() as RoomTemplate
	var info: Dictionary = {"seed": room.preview_seed if seed_value < 0 else seed_value, "display_name": room.display_name,
		"connectors": {}, "boxes": [], "cells": {}, "storeys": Vector2i.ZERO, "styles": {}, "recess_cavities": []}
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
	info["storeys"] = Vector2i(0, maxi(floori((top - 0.01) / CellGrid.BAY), 0))
	var effective: int = int(info["seed"])
	for g: String in INHERIT_GROUPS:
		var idx: int = room.style_choice(g, effective)
		if idx >= 0:
			info["styles"][g] = idx
	room.free()
	_scene_cache[key] = info
	return info

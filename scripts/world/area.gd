class_name Area
extends Node3D
## A live area (phase-4-design.md 8.1.1): plans its recipe, then builds rooms
## from the plan, each as its own direct child, placed by the plan, never
## nested in another room. It owns the area's WorldEnvironment (rooms' own
## Atmosphere steps aside) and tells WorldState which area's changes apply.
##
## Streaming (step 2): only the rooms near the player are live; an
## AreaStreamer builds and frees the rest as the player walks. With
## `streaming` off every room is built at once (step 1; area_route_test).

## The game sets this (menu reseed, `--area-seed=N`) before loading; -1 = the
## seed the world seed gives this area.
static var seed_override: int = -1

@export var recipe: AreaRecipe
@export var streaming: bool = true
## Null: StreamSettings.default().
@export var stream_settings: StreamSettings

var plan: AreaPlan
## slot id -> the live RoomTemplate.
var rooms: Dictionary = {}
## Where the visit starts, in the area frame (a resumed save's position);
## INF: the root room's PlayerSpawn. The rooms around it are built first.
var start_point: Vector3 = Vector3.INF
## The saved room's slot, for a start point in a doorway (no room there).
var start_room: String = ""
var streamer: AreaStreamer
var light_budget: LightBudget
## What building cost: plan_ms, wear_ms, total_ms, and with streaming off per
## room {slot: {instance_ms, enter_ms}} (enter = generate, sockets, save restore).
var timings: Dictionary = {}
var _env: WorldEnvironment
## The kit's water (the cistern's): the Reading Garden's shader, its ripples
## run by the area's clock as atmosphere.gd runs the garden's (phase 5 step 3).
const KIT_WATER: ShaderMaterial = preload("res://kit/materials/cistern_water.tres")
var _water_time: float = 0.0


func _process(delta: float) -> void:
	_water_time += delta
	KIT_WATER.set_shader_parameter("simulation_time", _water_time)


## The seed this area plans from.
func area_seed() -> int:
	if seed_override >= 0:
		return seed_override
	var ws: Node = get_node_or_null("/root/WorldState")
	var world_seed: int = int((ws.get("data") as Dictionary).get("world_seed", 1)) if ws != null else 1
	return AreaPlanner.area_seed_for(recipe, world_seed)


func _ready() -> void:
	if recipe == null:
		push_error("Area: no recipe")
		return
	var t0: int = Time.get_ticks_usec()
	var ws: Node = get_node_or_null("/root/WorldState")
	if ws != null:
		ws.call("enter_area", recipe.id, recipe.version)
	plan = AreaPlanner.plan(recipe, area_seed())
	for e: String in plan.check():
		push_warning("Area %s (seed %d): %s" % [recipe.id, plan.area_seed, e])
	timings = {"plan_ms": plan.plan_ms, "rooms": {}}
	if recipe.atmosphere != null:
		_env = WorldEnvironment.new()
		_env.name = "AreaEnvironment"
		_env.environment = recipe.atmosphere.build_environment()
		add_child(_env)
	var settings: StreamSettings = stream_settings if stream_settings != null else StreamSettings.default()
	light_budget = LightBudget.new()
	light_budget.name = "LightBudget"
	light_budget.shadow_budget = settings.shadow_budget
	light_budget.light_fade_m = settings.light_fade_m
	light_budget.seen_rooms = seen_rooms
	add_child(light_budget)
	var b: AABB = plan.bounds()
	FloorWear.fixed_rect = Rect2(b.position.x - 2.0, b.position.z - 2.0, b.size.x + 4.0, b.size.z + 4.0)
	if streaming:
		streamer = AreaStreamer.new()
		streamer.name = "Streamer"
		streamer.area = self
		streamer.settings = settings
		var at: AreaPlan.Room = plan.room_at(start_point) if start_point != Vector3.INF else null
		if at == null and start_room != "":
			at = plan.room(start_room)
		streamer.start(at.slot_id if at != null else plan.rooms[0].slot_id)
		add_child(streamer)
	else:
		for r: AreaPlan.Room in plan.rooms:
			build_room(r)
	var tw: int = Time.get_ticks_usec()
	FloorWear.rebuild_now()
	timings["wear_ms"] = (Time.get_ticks_usec() - tw) / 1000.0
	timings["total_ms"] = (Time.get_ticks_usec() - t0) / 1000.0


func _exit_tree() -> void:
	FloorWear.fixed_rect = Rect2()
	var ws: Node = get_node_or_null("/root/WorldState")
	if ws != null:
		ws.call("leave_area")


## Builds one planned room as a child of this area, all at once, and returns it.
func build_room(r: AreaPlan.Room) -> RoomTemplate:
	var t0: int = Time.get_ticks_usec()
	var room: RoomTemplate = make_room(r)
	var t1: int = Time.get_ticks_usec()
	enter_room(r, room)
	timings["rooms"][r.slot_id] = {"kind": r.kind, "instance_ms": (t1 - t0) / 1000.0, "enter_ms": (Time.get_ticks_usec() - t1) / 1000.0}
	return room


## A planned room's node, configured but not in the tree and not built:
## entering the tree builds it, unless it was prepared off the tree first
## (AreaStreamer).
func make_room(r: AreaPlan.Room) -> RoomTemplate:
	var room: RoomTemplate
	if r.kind == "generated":
		var g := GeneratedRoom.new()
		g.grammar = r.grammar
		g.rules = r.rules
		g.planned_grid = r.grid
		g.planned_seed = r.seed_value
		g.planned_styles = r.style_overrides
		g.planned_storey = r.storey
		g.inherit_style_groups = []
		room = g
	else:
		room = r.scene.instantiate() as RoomTemplate
		room.area_seed = r.seed_value
		for path: String in r.drop_nodes:
			var n: Node = room.get_node_or_null(path)
			if n != null:
				n.get_parent().remove_child(n)
				n.free()
		var atmos: Node = room.get_node_or_null("Atmosphere")
		if atmos is Atmosphere:
			(atmos as Atmosphere).own_environment = false
	room.name = r.slot_id
	room.room_id = r.slot_id
	if r.display_name != "":
		room.display_name = r.display_name
	room.transform = r.xf
	room.set_meta("area_slot", r.slot_id)
	return room


## Puts a room from make_room into the area.
func enter_room(r: AreaPlan.Room, room: RoomTemplate) -> void:
	add_child(room)
	finish_entering(r, room)


## The rest of entering, once all of the room's parts are in the tree (the
## streamer adds a big room's parts over several frames, phase 5 step 4).
func finish_entering(r: AreaPlan.Room, room: RoomTemplate) -> void:
	_clear_recesses(r, room)
	rooms[r.slot_id] = room
	light_budget.add_room(room, r.slot_id)


## The rooms whose lights are on: the one you're in and those you can see into
## from it (the plan's sightlines); empty (all) before the streamer knows.
func seen_rooms() -> Dictionary:
	if streamer == null or streamer.player_room == "":
		return {}
	var out: Dictionary = {streamer.player_room: true}
	for s: String in plan.visible.get(streamer.player_room, PackedStringArray()):
		out[s] = true
	return out


## How far past the back of a neighbour's recess a shortened module starts.
const RECESS_CLEARANCE: float = 0.05


## A recess bay's cavity goes 0.25 m past its room's edge (made for walls
## backed by rock; AreaPlan.Room.recess_cavities). A cell module of this room
## that reaches into another room's cavity (a gallery's first vault bay, over
## R01's door) would show inside it, so it's shortened to start just past the
## cavity. What it loses was inside the neighbour's wall; its materials map in
## world space, so nothing stretches.
func _clear_recesses(r: AreaPlan.Room, room: RoomTemplate) -> void:
	var cavities: Array[AABB] = []
	for other: AreaPlan.Room in plan.rooms:
		if other != r:
			for c: AABB in other.recess_cavities:
				if r.blockers.any(func(b: AABB) -> bool: return b.intersects(c)):     # most rooms touch none
					cavities.append(global_transform * c)
	if cavities.is_empty():
		return
	for n: Node in room.find_children("*", "KitModule", true, false):
		var m := n as KitModule
		if m.shape != KitModule.Shape.CELL:
			continue
		var bounds: AABB = _mesh_bounds(m)
		for c: AABB in cavities:
			if not bounds.has_volume() or not bounds.intersects(c):
				continue
			var k: int = Vector3.AXIS_X if c.size.x < c.size.z else Vector3.AXIS_Z     # the wall's normal: the cavity's thin side
			var a0: float = bounds.position[k]
			var a1: float = bounds.end[k]
			var s0: float = a0
			var s1: float = a1
			if c.end[k] - a0 < a1 - c.position[k]:
				s0 = c.end[k] + RECESS_CLEARANCE     # the cavity is at the module's low end
			else:
				s1 = c.position[k] - RECESS_CLEARANCE
			var f: float = (s1 - s0) / (a1 - a0)
			var squash := Vector3.ONE
			squash[k] = f
			var offset := Vector3.ZERO
			offset[k] = s0 - a0 * f
			m.global_transform = Transform3D(Basis.from_scale(squash), offset) * m.global_transform
			bounds = _mesh_bounds(m)


## The world bounds of a module's meshes.
static func _mesh_bounds(m: Node3D) -> AABB:
	var out := AABB()
	var first: bool = true
	for node: Node in m.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		var b: AABB = mi.global_transform * mi.get_aabb()
		out = b if first else out.merge(b)
		first = false
	return out


## Where a new visit starts: the root room's PlayerSpawn, or (a generated
## root) the middle of its first cell, facing in.
func spawn_transform() -> Transform3D:
	var root_room: RoomTemplate = rooms.get(plan.rooms[0].slot_id) if plan != null and not plan.rooms.is_empty() else null
	var spawn: Node3D = root_room.get_node_or_null("PlayerSpawn") if root_room != null else null
	if spawn != null:
		return spawn.global_transform
	if root_room is GeneratedRoom:
		return root_room.global_transform * Transform3D(Basis(), CellGrid.cell_centre(Vector3i.ZERO) + Vector3(0, 0.1, 0))
	return global_transform


## The plan room at a world point, or null.
func room_at(world_point: Vector3) -> AreaPlan.Room:
	return plan.room_at(to_local(world_point)) if plan != null else null


## The live room the point is in (null in a doorway, outside the area, or
## where the room isn't loaded).
func live_room_at(world_point: Vector3) -> RoomTemplate:
	var r: AreaPlan.Room = room_at(world_point)
	return rooms.get(r.slot_id) if r != null else null

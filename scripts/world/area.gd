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
var streamer: AreaStreamer
var light_budget: LightBudget
## What building cost: plan_ms, wear_ms, total_ms, and with streaming off per
## room {slot: {instance_ms, enter_ms}} (enter = generate, sockets, save restore).
var timings: Dictionary = {}
var _env: WorldEnvironment


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
	add_child(light_budget)
	var b: AABB = plan.bounds()
	FloorWear.fixed_rect = Rect2(b.position.x - 2.0, b.position.z - 2.0, b.size.x + 4.0, b.size.z + 4.0)
	if streaming:
		streamer = AreaStreamer.new()
		streamer.name = "Streamer"
		streamer.area = self
		streamer.settings = settings
		var at: AreaPlan.Room = plan.room_at(start_point) if start_point != Vector3.INF else null
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
	rooms[r.slot_id] = room
	light_budget.add_room(room)


## Where a new visit starts: the root room's PlayerSpawn.
func spawn_transform() -> Transform3D:
	var root_room: RoomTemplate = rooms.get(plan.rooms[0].slot_id) if plan != null and not plan.rooms.is_empty() else null
	var spawn: Node3D = root_room.get_node_or_null("PlayerSpawn") if root_room != null else null
	return spawn.global_transform if spawn != null else global_transform


## The plan room at a world point, or null.
func room_at(world_point: Vector3) -> AreaPlan.Room:
	return plan.room_at(to_local(world_point)) if plan != null else null


## The live room the point is in (null in a doorway, outside the area, or
## where the room isn't loaded).
func live_room_at(world_point: Vector3) -> RoomTemplate:
	var r: AreaPlan.Room = room_at(world_point)
	return rooms.get(r.slot_id) if r != null else null

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
## Arriving through a door from this area (phase-6-design.md 5.7.6): the
## visit starts just inside this area's door back to it. Set before _ready.
var arrive_from: String = ""
## Where that is (area frame), once planned; null: the root's PlayerSpawn.
var _arrival: Variant = null
## How far inside the door you arrive.
const ARRIVE_IN: float = 2.0
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

## Built in the background (phase 9, one continuous world) while you are in
## a neighbouring place: the plan given (`prepared_plan`, made on a worker
## thread), the scenery built one piece a frame from recipe.scenery_pieces
## (built whole, it stalled the frame), the rooms streamed in within the
## streamer's budget, nothing at once. Not `active` until activate(): the
## save's changes and the floor wear stay the active place's. `built` once
## the scenery and the rooms around the start are in.
var background: bool = false
var prepared_plan: AreaPlan
var active: bool = true
var is_built: bool = false
## False when SeamlessPlaces blends the environments of the camp and this
## area: activate() leaves its own WorldEnvironments off.
var owns_environment: bool = true
## Doors (the area each leads to) walked through with no loading screen
## (phase 9, SeamlessPlaces): no Threshold, and a ledge's pishtaq is open.
## Set before _ready.
var open_doors: PackedStringArray = []
const OPEN_DOOR: String = "res://kit/modules/walls/gorge_door_open.tscn"
signal built
## Scenery pieces built (or shown) a frame in the background.
const PIECES_A_FRAME: int = 1
## The kit's clearing in the background: about this much a frame (ms).
const CLEAR_BUDGET_MS: float = 2.0
var _claims: Array = []
var _start_slot: String = ""
var _reveal_token: int = 0


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
	if background:
		active = false
	var ws: Node = get_node_or_null("/root/WorldState")
	if ws != null and active:
		ws.call("enter_area", recipe.id, recipe.version)
	plan = prepared_plan if prepared_plan != null else AreaPlanner.plan(recipe, area_seed())
	for e: String in plan.check():
		push_warning("Area %s (seed %d): %s" % [recipe.id, plan.area_seed, e])
	if arrive_from != "":
		var door: Array = plan.threshold(arrive_from)
		if door.is_empty():
			push_warning("Area %s: no door back to %s, starting at the spawn" % [recipe.id, arrive_from])
		else:
			var at: Transform3D = (door[0] as AreaPlan.Room).connectors[door[1]]["xf"]
			_arrival = Transform3D(at.basis * Basis(Vector3.UP, PI), at * Vector3(0, .1, ARRIVE_IN))
			start_point = (_arrival as Transform3D).origin
			start_room = (door[0] as AreaPlan.Room).slot_id
	timings = {"plan_ms": plan.plan_ms, "rooms": {}}
	if recipe.atmosphere != null:
		_env = WorldEnvironment.new()
		_env.name = "AreaEnvironment"
		var env: Environment = recipe.atmosphere.build_environment()
		_env.set_meta("environment", env)
		_env.environment = env if active else null     # a neighbour's would take over the place you're in
		add_child(_env)
	if recipe.scenery != null and background and recipe.scenery_pieces != null:
		for r: AreaPlan.Room in plan.rooms:
			for c: Dictionary in r.span.get("claims", []):
				_claims.append({"xf": global_transform * r.xf * Transform3D(Basis(), c["at"]), "size": c["size"]})
		_claims.append_array(_vestibule_claims())
		_build_scenery.call_deferred()
	elif recipe.scenery != null:
		var scenery: Node = recipe.scenery.instantiate()
		scenery.name = "Scenery"
		add_child(scenery)
		timings["scenery_ms"] = (Time.get_ticks_usec() - t0) / 1000.0 - plan.plan_ms
		var claims: Array = []
		for r: AreaPlan.Room in plan.rooms:
			for c: Dictionary in r.span.get("claims", []):
				claims.append({"xf": global_transform * r.xf * Transform3D(Basis(), c["at"]), "size": c["size"]})
		claims.append_array(_vestibule_claims())
		if recipe.network != null:
			GorgeScenery.lift_mist(scenery, recipe.network.mist_glow)
		_open_cores(scenery)
		var kit: Node = scenery.get_node_or_null("Kit")
		if kit != null:
			var tc: int = Time.get_ticks_usec()
			timings["cleared"] = GorgeScenery.clear(kit, claims)
			timings["clear_ms"] = (Time.get_ticks_usec() - tc) / 1000.0
	var settings: StreamSettings = stream_settings if stream_settings != null else StreamSettings.default()
	light_budget = LightBudget.new()
	light_budget.name = "LightBudget"
	light_budget.shadow_budget = settings.shadow_budget
	light_budget.light_fade_m = settings.light_fade_m
	light_budget.seen_rooms = seen_rooms
	add_child(light_budget)
	if active:
		_wear_rect()
	if streaming:
		streamer = AreaStreamer.new()
		streamer.name = "Streamer"
		streamer.area = self
		streamer.settings = settings
		var at: AreaPlan.Room = plan.room_at(start_point) if start_point != Vector3.INF else null
		if at == null and start_room != "":
			at = plan.room(start_room)
		if background:
			_start_slot = at.slot_id if at != null else plan.rooms[0].slot_id     # started once its scenery is in (_build_scenery)
			if recipe.scenery == null or recipe.scenery_pieces == null:
				_build_scenery.call_deferred()     # no scenery: the rooms only
		else:
			streamer.start(at.slot_id if at != null else plan.rooms[0].slot_id)
			add_child(streamer)
	else:
		for r: AreaPlan.Room in plan.rooms:
			build_room(r)
	if active:
		var tw: int = Time.get_ticks_usec()
		FloorWear.rebuild_now()
		timings["wear_ms"] = (Time.get_ticks_usec() - tw) / 1000.0
	timings["total_ms"] = (Time.get_ticks_usec() - t0) / 1000.0
	if not background:
		is_built = true


func _wear_rect() -> void:
	var b: AABB = global_transform * plan.bounds()     # placed by SeamlessPlaces, turned
	FloorWear.fixed_rect = Rect2(b.position.x - 2.0, b.position.z - 2.0, b.size.x + 4.0, b.size.z + 4.0)


## The scenery from recipe.scenery_pieces, one piece a frame (background):
## as the whole scene's, Scenery/Environment, Generated and Kit; the kit
## cleared where the network's rooms stand piece by piece. Then waits for the
## streamer's rooms round the start and says it's built.
func _build_scenery() -> void:
	var t0: int = Time.get_ticks_usec()
	var pieces: PlacePieces = recipe.scenery_pieces
	if pieces != null:
		await _build_pieces(pieces, t0)
	# Each room's scenes built once and thrown away, one a frame, so the
	# streamer's first build of them doesn't make their meshes then.
	var seen: Dictionary = {}
	for r: AreaPlan.Room in plan.rooms:
		var scenes: Array = r.span.get("pieces", []).map(func(p: Dictionary) -> String: return p["scene"])
		if r.scene != null:
			scenes.append(r.scene.resource_path)
		for path: String in scenes:
			if not seen.has(path):
				seen[path] = true
				(load(path) as PackedScene).instantiate().free()
				await get_tree().process_frame
	if pieces != null:
		(load(ChasmGrammar.MOD + "dressing/chasm_lamp_post.tscn") as PackedScene).instantiate().free()
	if streamer != null:
		streamer.start_background(_start_slot)
		add_child(streamer)
	while streamer != null and streamer.busy():
		await get_tree().process_frame
	is_built = true
	built.emit()


func _build_pieces(pieces: PlacePieces, t0: int) -> void:
	var scenery := Node3D.new()
	scenery.name = "Scenery"
	add_child(scenery)
	var env := WorldEnvironment.new()
	env.name = "Environment"
	env.environment = pieces.environment if active else null     # a neighbour's would take over the place you're in (activate)
	scenery.add_child(env)
	var cleared: int = 0
	for part: Array in [["Generated", pieces.generated], ["Kit", pieces.kit]]:
		var holder := Node3D.new()
		holder.name = part[0]
		scenery.add_child(holder)
		var n: int = 0
		for path: String in part[1]:
			var piece: Node = (load(path) as PackedScene).instantiate()
			holder.add_child(piece)
			relayer(piece)
			if part[0] == "Kit" and not _claims.is_empty():
				# Its batches cleared a budget a frame (one piece: up to 37 ms).
				var reach: AABB = GorgeScenery.claims_reach(_claims)
				var start: int = Time.get_ticks_usec()
				for m: Node in piece.get_children():
					if m is MultiMeshInstance3D:
						cleared += GorgeScenery.clear_batch(m as MultiMeshInstance3D, _claims, reach, pieces.module_bounds)
						if Time.get_ticks_usec() - start > CLEAR_BUDGET_MS * 1000.0:
							await get_tree().process_frame
							start = Time.get_ticks_usec()
			elif recipe.network != null:
				GorgeScenery.lift_mist(piece, recipe.network.mist_glow)
			n += 1
			if n % PIECES_A_FRAME == 0:
				await get_tree().process_frame
	_open_cores(scenery)
	timings["scenery_ms"] = (Time.get_ticks_usec() - t0) / 1000.0
	timings["cleared"] = cleared


## Makes this the place you're in (phase 9): the save's changes go to it and
## the floor wear is its own.
func activate() -> void:
	if active:
		return
	active = true
	var ws: Node = get_node_or_null("/root/WorldState")
	if ws != null:
		ws.call("enter_area", recipe.id, recipe.version)
	if owns_environment:
		_show_environment(true)
	var b: AABB = global_transform * plan.bounds()
	FloorWear.retarget(Rect2(b.position.x - 2.0, b.position.z - 2.0, b.size.x + 4.0, b.size.z + 4.0))


## The place you're in is now another one.
func deactivate() -> void:
	if not active:
		return
	active = false
	var ws: Node = get_node_or_null("/root/WorldState")
	if ws != null:
		ws.call("leave_area")
	_show_environment(false)


## The area's WorldEnvironments (its own and its scenery's) on or off: two in
## the tree, the last one in takes over the view.
func _show_environment(on: bool) -> void:
	for n: Node in find_children("*", "WorldEnvironment", true, false):
		var we := n as WorldEnvironment
		if on and we.environment == null and we.has_meta("environment"):
			we.environment = we.get_meta("environment")
		elif not on and we.environment != null:
			we.set_meta("environment", we.environment)
			we.environment = null
	if on and _env == null and recipe.scenery_pieces != null:
		var scenery_env: WorldEnvironment = get_node_or_null("Scenery/Environment")
		if scenery_env != null and scenery_env.environment == null:
			scenery_env.environment = recipe.scenery_pieces.environment


## The environment this area shows when you're in it.
func environment() -> Environment:
	if _env != null:
		return _env.environment if _env.environment != null else _env.get_meta("environment", null)
	var scenery_env: WorldEnvironment = get_node_or_null("Scenery/Environment")
	if scenery_env == null:
		return null
	if scenery_env.environment != null:
		return scenery_env.environment
	return scenery_env.get_meta("environment", recipe.scenery_pieces.environment if recipe.scenery_pieces != null else null)


## Shows this area one scenery piece a frame (phase 9: shown at once, the
## first frame took 17 ms), from hidden.
func reveal(per_frame: int = PIECES_A_FRAME) -> void:
	_reveal_token += 1
	var token: int = _reveal_token
	var pieces: Array[Node3D] = []
	var scenery: Node = get_node_or_null("Scenery")
	for part: String in ["Generated", "Kit"]:
		var holder: Node = scenery.get_node_or_null(part) if scenery != null else null
		if holder != null:
			for c: Node in holder.get_children():
				if c is Node3D:
					(c as Node3D).visible = false
					pieces.append(c as Node3D)
	visible = true
	for i: int in pieces.size():
		if token != _reveal_token:
			return     # hidden (or shown again) meanwhile: the newer call finishes
		pieces[i].visible = true
		if (i + 1) % per_frame == 0:
			await get_tree().process_frame


## Hides the area at once (a reveal under way stops).
func conceal() -> void:
	_reveal_token += 1
	visible = false


func _exit_tree() -> void:
	if not active:
		return     # a neighbour going: the place you're in keeps its own
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
	elif r.kind in ["span", "ledge", "link"]:
		var span: Dictionary = r.span
		if open_doors.has(str(span.get("door", ""))):
			# Its door opens onto a vestibule (phase 9, SeamlessPlaces): the open pishtaq.
			span = span.duplicate()
			span["pieces"] = (span["pieces"] as Array).map(func(p: Dictionary) -> Dictionary:
				return {"scene": OPEN_DOOR, "xf": p["xf"]} if str(p["scene"]).ends_with('/gorge_door_pishtaq.tscn') else p)
		room = ChasmGrammar.build_room(span)
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
	for name: StringName in r.connectors:
		var k: Dictionary = r.connectors[name]
		if str(k["cap"]) == "threshold" and not open_doors.has(str(k["to"])):
			var door := Threshold.new()
			door.name = "Threshold_" + str(k["to"])
			door.to = str(k["to"])
			door.look = "door" if r.kind == "ledge" or String(name).begins_with("SNAP_door") else "glow"     # a ledge (its pishtaq) or a SNAP_door: a door piece stands there
			door.transform = r.xf.affine_inverse() * (k["xf"] as Transform3D)
			room.add_child(door)
	return room


## Puts a room from make_room into the area.
func enter_room(r: AreaPlan.Room, room: RoomTemplate) -> void:
	add_child(room)
	finish_entering(r, room)


## The rest of entering, once all of the room's parts are in the tree (the
## streamer adds a big room's parts over several frames, phase 5 step 4).
func finish_entering(r: AreaPlan.Room, room: RoomTemplate) -> void:
	relayer(room)
	if dormant:
		room.process_mode = Node.PROCESS_MODE_DISABLED
	_clear_recesses(r, room)
	rooms[r.slot_id] = room
	light_budget.add_room(room, r.slot_id)


## The rooms whose lights are on: the one you're in, and of those you can see
## into from it (the plan's sightlines) the ones whose first doorway out of
## your room is in front of you (the camera's view, widened by
## FACING_MARGIN_DEG either side so a turn lights a room before it shows). A
## room next door you face away from keeps
## only its lights that reach the doorway (value: the doorway's position), as
## they light your side of it. Empty (all) before the streamer knows.
const FACING_MARGIN_DEG: float = 15.0
## A point this far through the doorway counts too: standing in it, you see
## the room you face, not the one behind you.
const BEYOND_DOOR_M: float = 2.0
## Half a doorway's width (the kit's 3 m arch), for its jambs.
const DOOR_HALF: float = 1.5
## player room -> {slot: [first doorway (global), its jambs' axis, rooms away,
## the way through it (out of the player's room)]}.
var _first_doors: Dictionary = {}


func seen_rooms() -> Dictionary:
	if streamer == null or streamer.player_room == "":
		return {}
	var here: String = streamer.player_room
	var out: Dictionary = {here: true}
	var cam: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	if not _first_doors.has(here):
		_first_doors[here] = _doors_from(here)
	var doors: Dictionary = _first_doors[here]
	for s: String in plan.visible.get(here, PackedStringArray()):
		if cam == null or not doors.has(s) or _facing(cam, doors[s]):
			out[s] = true
		elif doors[s][2] == 1:
			out[s] = doors[s][0]
	return out


## Every room reachable from `here` by the plan's joints, with the doorway out
## of `here` its way starts through.
func _doors_from(here: String) -> Dictionary:
	var out: Dictionary = {}
	var todo: Array[String] = [here]
	while not todo.is_empty():
		var at: String = todo.pop_front()
		for e: Dictionary in plan.edges:
			var next: String = e["b"] if e["a"] == at else (e["a"] if e["b"] == at else "")
			if next == "" or next == here or out.has(next):
				continue
			if at == here:
				var xf: Transform3D = global_transform * (plan.room(here).connectors[e["a_conn"] if e["a"] == here else e["b_conn"]]["xf"] as Transform3D)
				out[next] = [xf.origin, xf.basis.x.normalized(), 1, -xf.basis.z.normalized()]
			else:
				out[next] = [out[at][0], out[at][1], int(out[at][2]) + 1, out[at][3]]
			todo.append(next)
	return out


## True if the doorway (its middle, a jamb, or a point BEYOND_DOOR_M through
## it, at mid-height) is within the camera's view: the angle out to the
## view's corners, widened (a light-well's doorways are above you, so not in
## plan alone).
static func _facing(cam: Camera3D, door: Array) -> bool:
	var at: Vector3 = cam.global_position
	var fwd: Vector3 = -cam.global_basis.z
	var aspect: float = cam.get_viewport().get_visible_rect().size.aspect() if cam.get_viewport() != null else 16.0 / 9.0
	var t: float = tan(deg_to_rad(cam.fov) * 0.5)
	var half: float = atan(t * sqrt(1.0 + aspect * aspect)) + deg_to_rad(FACING_MARGIN_DEG)
	var mid: Vector3 = (door[0] as Vector3) + Vector3(0, 1.5, 0)
	for p: Vector3 in [mid, mid - (door[1] as Vector3) * DOOR_HALF, mid + (door[1] as Vector3) * DOOR_HALF, mid + (door[3] as Vector3) * BEYOND_DOOR_M]:
		if fwd.angle_to(p - at) < half:
			return true
	return false


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


## Where a new visit starts: just inside the door you came through (arrive_from),
## else the root room's PlayerSpawn, or (a generated root) the middle of its
## first cell, facing in.
func spawn_transform() -> Transform3D:
	if _arrival != null:
		return global_transform * (_arrival as Transform3D)
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


## Asleep (phase 9, SeamlessPlaces: a place you're not in that stands where
## another is): its rooms and scenery stop processing, which takes their
## collision out of the world (CollisionObject3D's disable mode), so they
## don't stop you walking through the place you're in. Its streamer and light
## budget run on.
var dormant: bool = false


func set_dormant(on: bool) -> void:
	dormant = on
	for c: Node in get_children():
		if c == streamer or c == light_budget:
			continue
		c.process_mode = Node.PROCESS_MODE_DISABLED if on else Node.PROCESS_MODE_INHERIT


## While a background area's streamer builds its rooms, the save's changes
## read are its own (WorldState's area): returns what to put back.
func borrow_world_state() -> String:
	if active:
		return ""
	var ws: Node = get_node_or_null("/root/WorldState")
	if ws == null:
		return ""
	var was: String = ws.get("area_id")
	ws.set("area_id", recipe.id)
	return was


func return_world_state(was: String) -> void:
	if was == "":
		return
	var ws: Node = get_node_or_null("/root/WorldState")
	if ws != null:
		ws.set("area_id", was)


## The world static layer this area's collision is on (phase 9,
## SeamlessPlaces: each place that stands where another does has its own, so
## the player walks on the place it's in only, without taking the other out
## of the physics: putting thousands of bodies back took a 90 ms frame).
## 1: as everything.
var world_layer: int = 1


## Moves every body under `node` from the world static layer to world_layer,
## and what collides with it (props) to collide with that instead.
func relayer(node: Node) -> void:
	if world_layer == 1:
		return
	for n: Node in node.find_children("*", "CollisionObject3D", true, false):
		var c := n as CollisionObject3D
		if c.collision_layer & 1:
			c.collision_layer = (c.collision_layer & ~1) | world_layer
		if c.collision_mask & 1 and not c is Area3D:
			c.collision_mask = (c.collision_mask & ~1) | world_layer


## The scenery is cleared where an open door's vestibule runs into the bank
## (phase 9: a lit window of the bank's showed through its wall), as where
## the network's rooms stand.
func _vestibule_claims() -> Array:
	var out: Array = []
	for to: String in open_doors:
		var d: Array = plan.threshold(to)
		if d.is_empty():
			continue
		var xf: Transform3D = global_transform * ((d[0] as AreaPlan.Room).connectors[d[1]]["xf"] as Transform3D)
		var box: AABB = Vestibule.bounds()
		out.append({"xf": xf * Transform3D(Basis(), box.get_center()), "size": box.size})
		# ... and the wall bay in the doorway itself, through the face.
		out.append({"xf": xf * Transform3D(Basis(), Vector3(0, 1.8, -.7)), "size": Vector3(2.2, 3.0, 2.4)})
	return out


## Hides the bank's core cells an open door's vestibule runs through (the bake
## keeps the cells by a door slot as their own boxes, door_core_*): seen from
## the ledge, their faces stood in the open doorway.
func _open_cores(scenery: Node) -> void:
	if open_doors.is_empty() or scenery == null:
		return
	var boxes: Array[AABB] = []
	for to: String in open_doors:
		var d: Array = plan.threshold(to)
		if d.is_empty():
			continue
		var xf: Transform3D = global_transform * ((d[0] as AreaPlan.Room).connectors[d[1]]["xf"] as Transform3D)
		var b: AABB = Vestibule.bounds()
		boxes.append(xf * AABB(b.position + Vector3(0, .3, 0), b.size + Vector3(0, -.6, 1.6)))     # and through the face; not the storeys above or below
	for n: Node in scenery.find_children("door_core_*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var cell: AABB = mi.global_transform * mi.get_aabb()
		for b: AABB in boxes:
			if cell.grow(-.05).intersects(b):
				mi.visible = false
				break

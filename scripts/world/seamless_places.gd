class_name SeamlessPlaces
extends Node
## Places that share one frame and stream into each other without a loading
## screen (phase 9, one continuous world; docs/environment/phase-9-approval.md).
## The camp (rooms/camp/camp.tscn) and the Gorge do: the camp's gallery
## doorway opens onto the book-lined corridor that runs on into the
## Overlook's loggia, and they don't overlap, so both are drawn once both are
## built (your call: straight through, the camp looking out at the gorge).
##
## While you're in one, the other is built in the background: its files
## loaded and its pieces built once behind the start-up screen (warm), then
## the Gorge planned on a worker thread and built hidden a piece a frame
## (Area.background), or the camp instanced, and shown. Walking along the
## corridor past SWAP_Z makes the other the place you're in (`game.world`:
## the save, the HUD, the fall limit), and the two places' environments
## blend along it.
##
## A child of the game (scripts/main.gd), set up at the end of its _ready.

## Each place's neighbour through the corridor.
const NEIGHBOUR: Dictionary = {"camp": "gorge", "gorge": "camp"}
## The corridor (x, z): from the camp's gallery doorway to the loggia.
const CORRIDOR_X: Vector2 = Vector2(-4.0, 2.0)
const CAMP_END_Z: float = -13.2
const GORGE_END_Z: float = -18.4
## Past this (toward the Gorge) you're in the Gorge.
const SWAP_Z: float = -15.8
## The camp (rooms/camp/camp.tscn: its pieces.json boxes).
const CAMP_BOUNDS: AABB = AABB(Vector3(-11.0, -1.0, -13.2), Vector3(26.0, 20.0, 26.0))
## How much of the ambient light is gone in the corridor's middle, and which
## of the environment's values that is.
const CORRIDOR_DARK: float = .7
const DARKENED: Array[String] = ["ambient_light_energy", "volumetric_fog_ambient_inject"]
## The camp's door to the Gorge, which the corridor replaces.
const CAMP_DOOR: String = "Threshold_gorge"
const KIT_CAMP: String = "res://rooms/camp/camp.tscn"
const GORGE_RECIPE: String = "res://gen/recipes/gorge.tres"
const ROOT_ROOM: String = "res://rooms/gorge/overlook.tscn"

var game: Node
## The place you're not in, once built (an Area or the CampRoom); null before.
var neighbour: Node3D
var neighbour_id: String = ""
var place_id: String = ""
## Resources kept loaded (the warm-up's), so they stay in the cache.
var _keep: Array[Resource] = []
var _env_node: WorldEnvironment
var _env: Dictionary = {}          # place id -> Environment
var _mix: Environment
var _mix_props: Array[Dictionary] = []    # [{name, a, b}]: numbers and colours that differ
var _switches: Array[Dictionary] = []     # [{name, a, b}]: switches and modes that differ
var _side: int = -1
var _last_t: float = -1.0
var _plan: AreaPlan


## Whether `id` (the game's place: "camp" or an area id) has a neighbour here.
static func applies(id: String) -> bool:
	return NEIGHBOUR.has(id)


## Takes over: the place's door to its neighbour removed (the corridor
## replaces it), the neighbour warmed now (the start-up's wait), and built
## from the next frame.
func setup(main: Node, id: String) -> void:
	game = main
	place_id = id
	neighbour_id = NEIGHBOUR[id]
	var world: Node = game.get("world")
	_open_door(world)
	_take_environment(world, id)
	_warm(neighbour_id)
	_build.call_deferred()


## The camp's door to the Gorge goes (the Gorge's own door back was taken
## out of its recipe and bake).
func _open_door(world: Node) -> void:
	var door: Node = world.get_node_or_null(CAMP_DOOR) if world is CampRoom else null
	if door != null:
		door.free()


## Builds the neighbour's resources once and throws them away (behind the
## start-up screen): built for the first time, its meshes cost 18-35 ms a
## piece and its kit's batches 28 ms (phase 9 spike).
func _warm(id: String) -> void:
	var t0: int = Time.get_ticks_usec()
	if id == "gorge":
		var recipe: AreaRecipe = load(GORGE_RECIPE)
		_keep.append(recipe)
		for path: String in Array(recipe.scenery_pieces.generated) + Array(recipe.scenery_pieces.kit):
			var scene: PackedScene = load(path)
			_keep.append(scene)
			var n: Node = scene.instantiate()
			for c: Node in n.get_children():
				if c is MultiMeshInstance3D and c.has_meta("kit_buffer"):
					KitBatcher._fill(c as MultiMeshInstance3D)
			n.free()
		var root_room: PackedScene = load(ROOT_ROOM)
		_keep.append(root_room)
		root_room.instantiate().free()
	elif id == "camp":
		var camp: PackedScene = load(KIT_CAMP)
		_keep.append(camp)
		camp.instantiate().free()
	print("SeamlessPlaces: warmed %s in %.0f ms" % [id, (Time.get_ticks_usec() - t0) / 1000.0])


## Builds the neighbour in the background, hidden, and shows it.
func _build() -> void:
	if neighbour_id == "gorge":
		var recipe: AreaRecipe = load(GORGE_RECIPE)
		var seed_value: int = _area_seed(recipe)
		var task: int = WorkerThreadPool.add_task(func() -> void: _plan = AreaPlanner.plan(recipe, seed_value))
		while not WorkerThreadPool.is_task_completed(task):
			await get_tree().process_frame
		WorkerThreadPool.wait_for_task_completion(task)
		var area := Area.new()
		area.recipe = recipe
		area.background = true
		area.prepared_plan = _plan
		area.visible = false
		area.name = "Neighbour"
		game.add_child(area)
		while not area.is_built:
			await get_tree().process_frame
		area.streamer.target = game.get("player")
		neighbour = area
		_take_environment(area, "gorge")
		_shown = false
		_update_visibility()
	else:
		var camp: Node3D = (load(KIT_CAMP) as PackedScene).instantiate()
		camp.name = "Neighbour"
		_open_door(camp)
		camp.visible = false
		game.add_child(camp)
		neighbour = camp
		_take_environment(camp, "camp")
		camp.visible = true


## The seed an area plans from (Area.area_seed, before the area exists).
static func _area_seed(recipe: AreaRecipe) -> int:
	if Area.seed_override >= 0:
		return Area.seed_override
	var ws: Node = Engine.get_main_loop().root.get_node_or_null("/root/WorldState")
	var world_seed: int = int((ws.get("data") as Dictionary).get("world_seed", 1)) if ws != null else 1
	return AreaPlanner.area_seed_for(recipe, world_seed)


## A place's environment taken over by this node's own WorldEnvironment (two
## in the tree, the last one in wins): the place's own are switched off.
func _take_environment(place: Node, id: String) -> void:
	var env: Environment = (place as Area).environment() if place is Area else null
	for n: Node in place.find_children("*", "WorldEnvironment", true, false):
		var we := n as WorldEnvironment
		if env == null:
			env = we.environment if we.environment != null else we.get_meta("environment", null)
		if we.environment != null:
			we.set_meta("environment", we.environment)
			we.environment = null
	if place is Area:
		(place as Area).owns_environment = false
	if env == null:
		return
	_env[id] = env
	if _env_node == null:
		_env_node = WorldEnvironment.new()
		_env_node.name = "PlaceEnvironment"
		game.add_child(_env_node)
	_mix_props = []
	_last_t = -1.0
	_blend(_t())


func _process(_delta: float) -> void:
	var player: Node3D = game.get("player") if game != null else null
	if player == null or neighbour == null:
		return
	_update_visibility()
	var p: Vector3 = player.global_position
	var in_corridor: bool = p.x > CORRIDOR_X.x and p.x < CORRIDOR_X.y and p.z < CAMP_END_Z + 1.0 and p.z > GORGE_END_Z - 1.0
	# Along the corridor at SWAP_Z; elsewhere (fly mode, a respawn, a teleport)
	# by which side of it you're on.
	var want: String = place_id
	if in_corridor:
		want = "gorge" if p.z < SWAP_Z else "camp"
	elif p.z < GORGE_END_Z:
		want = "gorge"
	elif CAMP_BOUNDS.has_point(p):
		want = "camp"
	if want != place_id:
		_swap()
	_blend(_t())


## How far along the corridor toward the Gorge you are (0 in the camp, 1 in
## the Gorge).
func _t() -> float:
	var player: Node3D = game.get("player") if game != null else null
	if player == null:
		return 0.0 if place_id == "camp" else 1.0
	var p: Vector3 = player.global_position
	if p.x < CORRIDOR_X.x or p.x > CORRIDOR_X.y or p.z > CAMP_END_Z + 1.0 or p.z < GORGE_END_Z - 1.0:
		return 0.0 if place_id == "camp" else 1.0
	return clampf(inverse_lerp(CAMP_END_Z, GORGE_END_Z, p.z), 0.0, 1.0)


## The environment at `t` along the corridor: the camp's, the Gorge's, or a
## mix (each number and colour that differs, in between).
func _blend(t: float) -> void:
	if _env_node == null or absf(t - _last_t) < .002:
		return
	_last_t = t
	var a: Environment = _env.get("camp")
	var b: Environment = _env.get("gorge")
	var first: Environment = a if a != null else b
	if first == null:
		return
	# One Environment throughout, only the values that differ set: swapping the
	# resource, or setting its switches, restarted its GI (SDFGI), a 200 ms
	# frame at each end of the corridor.
	if _mix == null:
		_mix = first.duplicate()
		_env_node.environment = _mix
	if a == null or b == null:
		return
	if _mix_props.is_empty():
		_switches = []
		for prop: Dictionary in a.get_property_list():
			var name: String = prop["name"]
			if not (prop["usage"] & PROPERTY_USAGE_STORAGE) or a.get(name) == b.get(name):
				continue
			if prop["type"] in [TYPE_FLOAT, TYPE_COLOR]:
				_mix_props.append({"name": name, "a": a.get(name), "b": b.get(name)})
			elif prop["type"] in [TYPE_BOOL, TYPE_INT]:
				_switches.append({"name": name, "a": a.get(name), "b": b.get(name)})
		_side = -1
	t = clampf(t, 0.0, 1.0)
	for p: Dictionary in _mix_props:
		_mix.set(p["name"], lerp(p["a"], p["b"], t))
	# Darker toward the corridor's middle (your walk: a dark corridor between
	# the bright camp and gorge).
	var dark: float = 1.0 - CORRIDOR_DARK * sin(PI * t)
	for name: String in DARKENED:
		_mix.set(name, lerpf(a.get(name), b.get(name), t) * dark)
	var side: int = 0 if t < .5 else 1
	if side != _side:     # switches (a mode, on or off) as the nearer place, only when it changes
		_side = side
		for p: Dictionary in _switches:
			_mix.set(p["name"], p["a"] if side == 0 else p["b"])


## The neighbour becomes the place you're in, and the place you were in its
## neighbour: the game's world, its name (the tests and reports look for
## "Environment"), the save's area, the stats panel, the fall limit.
func _swap() -> void:
	var old: Node3D = game.get("world")
	var now: Node3D = neighbour
	old.name = "SwapOld"
	now.name = "Environment"
	old.name = "Neighbour"
	if old is Area:
		(old as Area).deactivate()
	if now is Area:
		(now as Area).activate()
	game.set("world", now)
	neighbour = old
	var swap_id: String = place_id
	place_id = neighbour_id
	neighbour_id = swap_id
	var player: Node = game.get("player")
	if now is Area:
		var area := now as Area
		game.set("scene_path", "area:" + area.recipe.id)
		player.set("fall_limit", area.recipe.fall_limit)
		player.set("respawn_point", area.spawn_transform().origin)
		if area.streamer != null:
			area.streamer.target = player
		var hud: Node = game.get("hud")
		if hud != null:
			(hud.get("zone_label") as Label).text = area.recipe.display_name.to_upper()     # until you step into one of its rooms
	else:
		game.set("scene_path", "camp")
		player.set("fall_limit", -8.0)
		var spawn: Node3D = now.get_node_or_null("PlayerSpawn")
		player.set("respawn_point", spawn.global_position if spawn != null else Vector3(0, .2, 11.5))
	var stats: Node = game.get("stats")
	if stats != null:
		stats.set("area", now as Area)
	print("SeamlessPlaces: now in %s" % place_id)


## From the camp the Gorge shows only through the gallery doorway, and drawn
## behind the camp's walls it cost the camp 0.8 ms GPU and 4,000 draw calls
## (phase 9): while you're in the camp it's shown only while the doorway is
## (nearly) in view, REVEAL_PER_FRAME pieces a frame (shown at once, a 7-10 ms
## frame), and hidden when you turn away. In the corridor, and from the Gorge
## (the camp is small), both are shown.
const DOORWAY: Array[Vector3] = [Vector3(-2.35, 2.2, -13.2), Vector3(0.35, 2.2, -13.2), Vector3(-2.35, 6.2, -13.2), Vector3(0.35, 6.2, -13.2)]
## How far past the view's edge the doorway counts as in view (degrees).
const VIEW_MARGIN_DEG: float = 25.0
const REVEAL_PER_FRAME: int = 6
var _shown: bool = true


func _update_visibility() -> void:
	var gorge: Area = (neighbour if place_id == "camp" else null) as Area
	if gorge == null or not gorge.is_built:
		return
	var player: Node3D = game.get("player")
	var want: bool = player.global_position.z < CAMP_END_Z + 1.0 or _doorway_in_view(player.get("camera") as Camera3D)
	if want == _shown:
		return
	_shown = want
	if want:
		gorge.reveal(REVEAL_PER_FRAME)
	else:
		gorge.conceal()


## Whether a corner of the gallery doorway is within the camera's view
## widened by VIEW_MARGIN_DEG.
static func _doorway_in_view(cam: Camera3D) -> bool:
	if cam == null:
		return true
	var vp: Viewport = cam.get_viewport()
	var aspect: float = vp.get_visible_rect().size.aspect() if vp != null else 16.0 / 9.0
	var half_v: float = deg_to_rad(cam.fov) * .5
	var half_h: float = atan(tan(half_v) * aspect)
	var limit: float = atan(sqrt(tan(half_v) ** 2 + tan(half_h) ** 2)) + deg_to_rad(VIEW_MARGIN_DEG)
	var forward: Vector3 = -cam.global_basis.z
	for c: Vector3 in DOORWAY:
		var to: Vector3 = c - cam.global_position
		if to.length() < .01 or forward.angle_to(to) < limit:
			return true
	return false

class_name SeamlessPlaces
extends Node
## The camp, the Gorge and the interiors behind its doors as one world you
## walk through without a loading screen (phase 9, one continuous world;
## docs/environment/phase-9-approval.md). A child of the game
## (scripts/main.gd), set up at the end of its _ready.
##
## Links (LINKS), each between two places:
## - the camp and the Gorge share one frame: the camp's gallery doorway
##   opens onto the corridor that runs on into the Overlook's loggia; they
##   don't overlap, so both are drawn (step 1, your call: straight through);
## - the Gorge and each interior (the Library Wing, the Lower Stacks) meet at
##   a door: the Gorge's threshold on a ledge (its pishtaq open) and the
##   interior's door back (Area.open_doors), joined by a Vestibule, a dog-leg
##   passage; the interior is placed so its door meets the vestibule's end.
##   They overlap in space (the interior inside the bank, and beyond), so
##   only the place you're in is shown and has collision (the other hidden
##   and dormant), and the change happens in the vestibule's middle, where
##   you see neither end (step 2).
##
## The place you're in and its neighbours (one link away) are kept: each
## neighbour warmed behind the start-up screen and built in the background
## (an area planned on a worker thread, then Area.background a piece a frame;
## the camp instanced). The place the game started in stands at the origin,
## the others where their links put them (`_frames`, in the Gorge's frame).
## Walking a link's middle makes the other end the place you're in
## (`game.world`: the save, the HUD, the fall limit); places no longer a link
## away go. The two places' environments blend along a link, darker in its
## middle.

const KIT_CAMP: String = "res://rooms/camp/camp.tscn"
const RECIPES: Dictionary = {"gorge": "res://gen/recipes/gorge.tres", "library": "res://gen/recipes/library_wing.tres",
	"lower_stacks": "res://gen/recipes/lower_stacks.tres"}
const ROOT_ROOM: String = "res://rooms/gorge/overlook.tscn"
## [a, b, kind]: "corridor" (the camp and the Gorge) or "door" (the Gorge and
## an interior, b).
const LINKS: Array = [["camp", "gorge", "corridor"], ["gorge", "library", "door"], ["gorge", "lower_stacks", "door"]]

## The corridor (x, z, the Gorge's frame): from the camp's gallery doorway to
## the loggia.
const CORRIDOR_X: Vector2 = Vector2(-4.0, 2.0)
const CAMP_END_Z: float = -13.2
const GORGE_END_Z: float = -18.4
## The camp (rooms/camp/camp.tscn: its pieces.json boxes).
const CAMP_BOUNDS: AABB = AABB(Vector3(-11.0, -1.0, -13.2), Vector3(26.0, 20.0, 26.0))
## The camp's door to the Gorge, which the corridor replaces.
const CAMP_DOOR: String = "Threshold_gorge"
## How much of the ambient light is gone in a link's middle, and which of the
## environment's values that is.
const LINK_DARK: float = .7
const DARKENED: Array[String] = ["ambient_light_energy", "volumetric_fog_ambient_inject"]
## From the camp the Gorge shows only through the gallery doorway: drawn
## behind the camp's walls it cost the camp 0.8 ms GPU and 4,000 draw calls.
## Shown while the doorway is (nearly) in view, REVEAL_PER_FRAME pieces a
## frame (shown at once, a 7-10 ms frame).
const DOORWAY: Array[Vector3] = [Vector3(-2.35, 2.2, -13.2), Vector3(0.35, 2.2, -13.2), Vector3(-2.35, 6.2, -13.2), Vector3(0.35, 6.2, -13.2)]
const VIEW_MARGIN_DEG: float = 25.0
const REVEAL_PER_FRAME: int = 6
## The camp's and the Gorge's world static layer: the interiors (on layer 1,
## with their props) stand where the Gorge's banks are, so the player walks
## on one or the other (_set_player_mask), and none leaves the physics.
const OPEN_LAYER: int = 1 << 8

var game: Node
## The place you're in ("camp" or an area id).
var place_id: String = ""
## Places built: id -> Node3D (the place you're in is game.world).
var places: Dictionary = {}
## Each place's frame in the Gorge's (camp and Gorge: identity).
var _frames: Dictionary = {}
var _boot_id: String = ""
## Interiors' vestibules: interior id -> Vestibule.
var vestibules: Dictionary = {}
var _building: Dictionary = {}
var _keep: Array[Resource] = []
var _tasks: Array[int] = []        # worker tasks running (_on_worker)
## The interiors' plans (an area id -> AreaPlan), made once behind the
## start-up screen (_plan_interiors) and kept: a plan is never changed.
var _plans: Dictionary = {}
var _env_node: WorldEnvironment
var _env: Dictionary = {}          # place id -> Environment
var _mix: Environment
var _pair: Array = []              # [a, b] the blend is between
var _mix_props: Array[Dictionary] = []
var _switches: Array[Dictionary] = []
var _side: int = -1
var _last_t: float = -1.0
var _gorge_shown: bool = true
var _waiting: bool = false


## The game's place ("camp" or an area id) is one of these.
static func applies(id: String) -> bool:
	return id == "camp" or RECIPES.has(id)


## The doors of area `id` walked through here (Area.open_doors), set before
## it's built.
static func open_doors_for(id: String) -> PackedStringArray:
	var out: PackedStringArray = []
	for l: Array in LINKS:
		if l[2] == "door" and (l[0] == id or l[1] == id):
			out.append(l[1] if l[0] == id else l[0])
	return out


## The places one link from `id`.
static func neighbours_of(id: String) -> Array[String]:
	var out: Array[String] = []
	for l: Array in LINKS:
		if l[0] == id:
			out.append(l[1])
		elif l[1] == id:
			out.append(l[0])
	return out


static func _link_kind(a: String, b: String) -> String:
	for l: Array in LINKS:
		if (l[0] == a and l[1] == b) or (l[0] == b and l[1] == a):
			return l[2]
	return ""


func setup(main: Node, id: String) -> void:
	game = main
	place_id = id
	_boot_id = id
	var world: Node3D = game.get("world")
	places[id] = world
	if id == "gorge":
		(world as Area).world_layer = OPEN_LAYER
		(world as Area).relayer(world)     # behind the start-up screen
	elif id == "camp":
		_relayer_camp(world)
	_set_player_mask()
	if id == "camp" or id == "gorge":
		_frames[id] = Transform3D()
	_open_door(world)
	_take_environment(world, id)
	_watch_lights(world)
	# The passages from where you start, now: a save made in one resumes
	# standing on it, before the place at its other end is built.
	if id == "gorge":
		for n: String in neighbours_of(id):
			if _link_kind(id, n) == "door" and not (world as Area).plan.threshold(n).is_empty():
				_add_vestibule(n)
	elif _link_kind(id, "gorge") == "door":
		_add_vestibule(id)
	_plan_interiors(world)
	for n: String in neighbours_of(id):
		_warm(n)
	_build_neighbours.call_deferred()


## The interiors planned now, on the main thread, behind the start-up screen
## (with the warm-up below, 550-600 ms): planned on a worker thread as you
## walked, the game stalled for up to 230 ms while the planner instantiated
## its rooms there (the frame gate). The Gorge's plan stays on the worker
## (planning it from the camp left the camp's frames as they were).
func _plan_interiors(world: Node3D) -> void:
	var t0: int = Time.get_ticks_usec()
	for id: String in RECIPES:
		if id == "gorge":
			continue
		if world is Area and (world as Area).recipe.id == id:
			_plans[id] = (world as Area).plan
			continue
		var recipe: AreaRecipe = load(RECIPES[id])
		_keep.append(recipe)
		_plans[id] = AreaPlanner.plan(recipe, _area_seed(recipe), Area.kept_variants(id))
		_keep_variants(recipe, _plans[id])
		var plan: AreaPlan = _plans[id]
		plan.checked = true     # here, behind the start-up screen, not as it's built
		for e: String in plan.check():
			push_warning("Area %s (seed %d): %s" % [id, plan.area_seed, e])
		# Its authored and baked rooms into the world once, hidden, and out: the
		# first time a scene's meshes enter the world costs once (R01's first
		# reading table, 75 ms as the Library built in the background).
		for r: AreaPlan.Room in plan.rooms:
			if r.scene != null:
				var warm: Node3D = r.scene.instantiate()
				warm.visible = false
				if warm is RoomTemplate:
					(warm as RoomTemplate).hold_restore = true     # the save untouched
				game.add_child(warm)
				warm.free()
	print("SeamlessPlaces: planned the interiors in %.0f ms" % ((Time.get_ticks_usec() - t0) / 1000.0))


## Where frame `f` (the Gorge's) stands in the world: the place the game
## started in at the origin.
func _placed(f: Transform3D) -> Transform3D:
	return (_frames[_boot_id] as Transform3D).affine_inverse() * f


func _open_door(world: Node) -> void:
	var door: Node = world.get_node_or_null(CAMP_DOOR) if world is CampRoom else null
	if door != null:
		door.free()


## A place's resources built once and thrown away (behind the start-up
## screen): built for the first time, the Gorge's meshes cost 18-35 ms a
## piece and its kit's batches 28 ms (phase 9 spike). An interior's rooms are
## warmed as it builds (Area._build_scenery).
func _warm(id: String) -> void:
	var t0: int = Time.get_ticks_usec()
	if id == "gorge":
		var recipe: AreaRecipe = load(RECIPES["gorge"])
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
	else:
		_keep.append(load(RECIPES[id]))
	print("SeamlessPlaces: warmed %s in %.0f ms" % [id, (Time.get_ticks_usec() - t0) / 1000.0])


func _build_neighbours() -> void:
	# The Gorge first: an interior's frame comes from its plan.
	var todo: Array[String] = neighbours_of(place_id)
	todo.sort_custom(func(a: String, b: String) -> bool: return a == "gorge" and b != "gorge")
	for n: String in todo:
		if not neighbours_of(place_id).has(n):
			continue     # you moved on meanwhile
		if not places.has(n) and not _building.has(n):
			_building[n] = true
			await _build(n)
			_building.erase(n)


## Builds place `id` in the background, hidden, and places it.
func _build(id: String) -> void:
	if id == "camp":
		# Built on a worker thread (the scene loaded at warm): on the main thread
		# it was a 0.5-1 s pause walking back into the Gorge.
		var scene: PackedScene = load(KIT_CAMP)
		var made: Array = [null]
		await _on_worker(func() -> void: made[0] = scene.instantiate())
		var camp: Node3D = made[0]
		_unlight(camp)
		camp.name = "Place_camp"
		_relayer_camp(camp)
		_open_door(camp)
		camp.transform = _placed(Transform3D())
		game.add_child(camp)
		places["camp"] = camp
		_take_environment(camp, "camp")
		return
	var recipe: AreaRecipe = load(RECIPES[id])
	var plan: AreaPlan = _plans.get(id)
	if plan == null:
		plan = await _plan_on_worker(recipe, _area_seed(recipe), Area.kept_variants(id))
		_keep_variants(recipe, plan)
	if id != place_id and not neighbours_of(place_id).has(id):
		return     # you moved on while it was planning
	# Its frame: the Gorge's door and the interior's door back meet at the
	# vestibule's ends. Started in an interior, the Gorge is placed by it.
	if id == "gorge":
		_frames["gorge"] = Transform3D()
		_frames["camp"] = Transform3D()
		if not _frames.has(place_id):
			_frames[place_id] = _interior_frame(plan, (places[place_id] as Area).plan, place_id)
	else:
		if not places.has("gorge") or (places["gorge"] as Area).plan.threshold(id).is_empty():
			return     # no door to it on this seed's ledges
		_frames[id] = _interior_frame((places["gorge"] as Area).plan, plan, id)
	var overlaps: bool = false     # every place stays awake, the player's mask choosing which it walks on
	var area := Area.new()
	area.recipe = recipe
	area.background = true
	area.prepared_plan = plan
	area.open_doors = open_doors_for(id)
	area.arrive_from = "gorge" if id != "gorge" else (place_id if place_id != "camp" else "")
	area.visible = false
	area.name = "Place_" + id
	area.transform = _placed(_frames[id])
	if id == "gorge":
		area.world_layer = OPEN_LAYER
	area.owns_environment = false
	game.add_child(area)
	if overlaps:
		area.set_dormant(true)
	while not area.is_built:
		await get_tree().process_frame
	if id != place_id and not neighbours_of(place_id).has(id):
		_free_slowly(area)     # you moved on while it was building
		return
	area.streamer.target = game.get("player")
	places[id] = area
	_watch_lights(area)
	_take_environment(area, id)
	_add_vestibule(id if id != "gorge" else place_id)
	if id == "gorge" and place_id == "camp":
		_gorge_shown = false
		_update_visibility()


func _plan_on_worker(recipe: AreaRecipe, seed_value: int, kept: Dictionary) -> AreaPlan:
	var out: Array = [null]
	await _on_worker(func() -> void: out[0] = AreaPlanner.plan(recipe, seed_value, kept))
	return out[0]


## Records the variants a plan picked in the save (Q5), on its own seed only.
static func _keep_variants(recipe: AreaRecipe, plan: AreaPlan) -> void:
	if Area.seed_override >= 0 or plan == null:
		return
	var ws: Node = Engine.get_main_loop().root.get_node_or_null("/root/WorldState")
	if ws != null:
		ws.call("keep_variants", recipe.id, plan.variants, recipe.version)


## Runs `job` on a worker thread, a frame at a time until it's done.
func _on_worker(job: Callable) -> void:
	var task: int = WorkerThreadPool.add_task(job)
	_tasks.append(task)
	while not WorkerThreadPool.is_task_completed(task):
		await get_tree().process_frame
	_tasks.erase(task)
	WorkerThreadPool.wait_for_task_completion(task)


## Quitting while a place is planned or built on a worker thread crashed
## the game at exit (the first seconds after start-up): its tasks finish first.
func _exit_tree() -> void:
	for task: int in _tasks:
		WorkerThreadPool.wait_for_task_completion(task)
	_tasks.clear()


## The interior's frame (in the Gorge's) for the Gorge's plan and the
## interior's: its door back meets the end of the vestibule from the
## Gorge's door to it, facing back along it.
static func _interior_frame(gorge_plan: AreaPlan, plan: AreaPlan, id: String) -> Transform3D:
	var g: Transform3D = _door_xf(gorge_plan, id)
	var i: Transform3D = _door_xf(plan, "gorge")
	return g * Vestibule.EXIT * Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO) * i.affine_inverse()


## A plan's threshold connector to `to`, in the plan's frame (-Z out through
## the door).
static func _door_xf(plan: AreaPlan, to: String) -> Transform3D:
	var d: Array = plan.threshold(to)
	if d.is_empty():
		push_warning("SeamlessPlaces: no door to %s" % to)
		return Transform3D()
	return ((d[0] as AreaPlan.Room).connectors[d[1]]["xf"] as Transform3D)


## The vestibule to interior `id`, placed by the Gorge's door, or, before the
## Gorge is built, by the interior's door back (a save made in the passage
## resumes standing on it; phase 9 step 3).
func _add_vestibule(id: String) -> void:
	if id == "camp" or vestibules.has(id) or not (places.has("gorge") or places.has(id)):
		return
	var v := Vestibule.new()
	v.name = "Vestibule_" + id
	if places.has("gorge"):
		v.transform = _placed(_door_xf((places["gorge"] as Area).plan, id))
	else:
		var interior := places[id] as Area
		v.transform = interior.transform * _door_xf(interior.plan, "gorge") * Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO) * Vestibule.EXIT.affine_inverse()
	game.add_child(v)
	vestibules[id] = v
	(v.get_node("Collision") as CollisionObject3D).collision_layer = 1 | OPEN_LAYER     # walked from either side


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
	_last_t = -1.0
	_pair = []


func _process(_delta: float) -> void:
	var player: Node3D = game.get("player") if game != null else null
	if player == null:
		return
	var p: Vector3 = player.global_position
	var want: String = place_id
	var pair: Array = [place_id, place_id]
	var t: float = 0.0
	var hold: bool = false
	# The corridor (the camp and the Gorge), or which side of it you're on
	# (fly mode, a respawn).
	if place_id == "camp" or place_id == "gorge":
		var corridor: float = _corridor_t(p)
		if corridor >= 0.0:
			pair = ["camp", "gorge"]
			t = corridor
			want = "gorge" if corridor >= .5 else "camp"
			# Past the camp's doorway the floor is the Gorge's: before it's
			# built (a save made in the corridor, the first seconds) you wait.
			hold = not places.has("gorge") and _gorge_local(p).z < CAMP_END_Z
		else:
			var g: Vector3 = _gorge_local(p)
			if g.z < GORGE_END_Z:
				want = "gorge"
			elif CAMP_BOUNDS.has_point(g):
				want = "camp"
	# A vestibule (the Gorge and an interior).
	for id: String in vestibules:
		if place_id != "gorge" and place_id != id:
			continue
		var vt: float = Vestibule.progress((vestibules[id] as Node3D).to_local(p))
		if vt >= 0.0:
			pair = ["gorge", id]
			t = vt
			want = id if vt >= .5 else "gorge"
	if want != place_id:
		if places.has(want) and (not places[want] is Area or (places[want] as Area).is_built):
			_end_wait()
			_swap(want)
		elif _link_kind(place_id, want) == "door" or hold:
			_wait()
	elif hold:
		_wait()
	elif _waiting:
		_end_wait()
	if pair[0] == pair[1]:
		t = 0.0
	_blend(pair, t)
	_update_visibility()


## How far along the corridor toward the Gorge (0..1), or -1 outside it.
func _corridor_t(p: Vector3) -> float:
	var g: Vector3 = _gorge_local(p)
	if g.x < CORRIDOR_X.x or g.x > CORRIDOR_X.y or g.z > CAMP_END_Z + 1.0 or g.z < GORGE_END_Z - 1.0 or g.y < 0.0 or g.y > 9.0:
		return -1.0
	return clampf(inverse_lerp(CAMP_END_Z, GORGE_END_Z, g.z), 0.0, 1.0)


## A world point in the Gorge's (and the camp's) frame.
func _gorge_local(p: Vector3) -> Vector3:
	if not _frames.has(_boot_id):
		return Vector3(0, -1000, 0)
	return (_frames[_boot_id] as Transform3D) * p


## The next place isn't built yet (a slow machine): you wait at the swap with
## a quiet "Loading…" note (your walk: subtle, not the old loading screen).
func _wait() -> void:
	if _waiting:
		return
	_waiting = true
	game.get("player").set("blocked", true)
	var hud: Node = game.get("hud")
	if hud != null:
		hud.call("notify", "Loading…")


func _end_wait() -> void:
	if not _waiting:
		return
	_waiting = false
	game.get("player").set("blocked", false)
	var hud: Node = game.get("hud")
	if hud != null:
		hud.call("notify", "")


## The environment at `t` between pair[0] and pair[1], darker in the middle.
## One Environment throughout, only the values that differ set: swapping the
## resource, or setting its switches, restarted its GI (SDFGI), a 200 ms frame.
func _blend(pair: Array, t: float) -> void:
	var a: Environment = _env.get(pair[0])
	var b: Environment = _env.get(pair[1])
	if a == null:
		a = b
	if b == null:
		b = a
	if a == null or _env_node == null:
		return
	if _mix == null:
		_mix = a.duplicate()
		_env_node.environment = _mix
	if pair != _pair:
		_pair = pair.duplicate()
		_mix_props = []
		_switches = []
		for prop: Dictionary in a.get_property_list():
			var name: String = prop["name"]
			if not (prop["usage"] & PROPERTY_USAGE_STORAGE):
				continue
			var va: Variant = a.get(name)
			var vb: Variant = b.get(name)
			if prop["type"] in [TYPE_FLOAT, TYPE_COLOR] and (va != vb or _mix.get(name) != va or name in DARKENED):
				_mix_props.append({"name": name, "a": va, "b": vb})
			elif prop["type"] in [TYPE_BOOL, TYPE_INT] and (va != vb or _mix.get(name) != va):
				_switches.append({"name": name, "a": va, "b": vb})
		_side = -1
		_last_t = -1.0
	if absf(t - _last_t) < .002:
		return
	_last_t = t
	t = clampf(t, 0.0, 1.0)
	var dark: float = 1.0 - LINK_DARK * sin(PI * t) if pair[0] != pair[1] else 1.0
	for p: Dictionary in _mix_props:
		var v: Variant = lerp(p["a"], p["b"], t)
		_mix.set(p["name"], v * dark if p["name"] in DARKENED else v)
	var side: int = 0 if t < .5 else 1
	if side != _side:
		_side = side
		for p: Dictionary in _switches:
			var want: Variant = p["a"] if side == 0 else p["b"]
			if _mix.get(p["name"]) != want:
				_mix.set(p["name"], want)


## The neighbour `id` becomes the place you're in.
## The place's lights leave the vestibules' layer out (Vestibule.LAYER).
static func _unlight(node: Node) -> void:
	for n: Node in node.find_children("*", "Light3D", true, false):
		var l := n as Light3D
		if not l.get_parent() is Vestibule:
			l.light_cull_mask &= ~Vestibule.LAYER


func _swap(id: String) -> void:
	var old: Node3D = game.get("world")
	var now: Node3D = places[id]
	var old_id: String = place_id
	old.name = "Place_" + old_id
	now.name = "Environment"
	if old is Area:
		(old as Area).deactivate()
	if id == "gorge" and _link_kind(old_id, id) == "door":
		(now as Area).reveal(REVEAL_PER_FRAME)     # shown at once, a 17 ms frame
	else:
		now.visible = true     # before activate: its floor wear is drawn once it's shown
	if now is Area:
		(now as Area).activate()
	if _link_kind(old_id, id) == "door":
		if old is Area and old_id == "gorge":
			(old as Area).conceal()
		else:
			old.visible = false
	game.set("world", now)
	place_id = id
	# The camp shows only beside the Gorge (an interior may stand where it is).
	if places.has("camp") and id != "camp":
		(places["camp"] as Node3D).visible = id == "gorge"
	_set_player_mask()
	var player: Node = game.get("player")
	if now is Area:
		var area := now as Area
		game.set("scene_path", "area:" + area.recipe.id)
		player.set("fall_limit", area.recipe.fall_limit + area.global_position.y)
		player.set("respawn_point", area.spawn_transform().origin)
		if area.streamer != null:
			area.streamer.target = player
		var hud: Node = game.get("hud")
		if hud != null:
			(hud.get("zone_label") as Label).text = area.recipe.display_name.to_upper()
	else:
		game.set("scene_path", "camp")
		player.set("fall_limit", -8.0 + now.global_position.y)
		var spawn: Node3D = now.get_node_or_null("PlayerSpawn")
		player.set("respawn_point", spawn.global_position if spawn != null else Vector3(0, .2, 11.5))
	var stats: Node = game.get("stats")
	if stats != null:
		stats.set("area", now as Area)
	# Places no longer a link away go (but the camp and the Gorge, the hub,
	# stay once built: building the camp again was the pause); new neighbours
	# are built.
	var keep: Array[String] = neighbours_of(id)
	keep.append_array([id, "camp", "gorge"])
	for other: String in places.keys():
		if not keep.has(other):
			_free_slowly(places[other])
			places.erase(other)
			_env.erase(other)
	for v: String in vestibules.keys():
		if not places.has(v):
			(vestibules[v] as Node).queue_free()
			vestibules.erase(v)
	_build_neighbours.call_deferred()
	print("SeamlessPlaces: now in %s" % place_id)


## From the camp the Gorge shows only while the gallery doorway is (nearly)
## in view, or you're in the corridor.
func _update_visibility() -> void:
	if place_id != "camp" or not places.has("gorge"):
		return
	var gorge: Area = places["gorge"] as Area
	if gorge == null or not gorge.is_built:
		return
	var player: Node3D = game.get("player")
	var want: bool = _gorge_local(player.global_position).z < CAMP_END_Z + 1.0 or _doorway_in_view(player.get("camera") as Camera3D)
	if want == _gorge_shown:
		return
	_gorge_shown = want
	if want:
		gorge.reveal(REVEAL_PER_FRAME)
	else:
		gorge.conceal()


func _doorway_in_view(cam: Camera3D) -> bool:
	if cam == null:
		return true
	var vp: Viewport = cam.get_viewport()
	var aspect: float = vp.get_visible_rect().size.aspect() if vp != null else 16.0 / 9.0
	var half_v: float = deg_to_rad(cam.fov) * .5
	var half_h: float = atan(tan(half_v) * aspect)
	var limit: float = atan(sqrt(tan(half_v) ** 2 + tan(half_h) ** 2)) + deg_to_rad(VIEW_MARGIN_DEG)
	var forward: Vector3 = -cam.global_basis.z
	var to_world: Transform3D = _placed(Transform3D())
	for c: Vector3 in DOORWAY:
		var to: Vector3 = to_world * c - cam.global_position
		if to.length() < .01 or forward.angle_to(to) < limit:
			return true
	return false


## A built neighbour of the place you're in (the first in LINKS), or null:
## for tests.
var neighbour: Node3D:
	get:
		for n: String in neighbours_of(place_id):
			if places.has(n) and (not places[n] is Area or (places[n] as Area).is_built):
				return places[n]
		return null


## The player walks on the Gorge's layer only in the camp and the Gorge (in
## an interior it stands where the Gorge's banks are).
func _set_player_mask() -> void:
	var player: CollisionObject3D = game.get("player")
	if player == null:
		return
	var ray: RayCast3D = player.get("ray")
	if place_id == "camp" or place_id == "gorge":
		player.collision_mask = (player.collision_mask & ~1) | OPEN_LAYER
	else:
		player.collision_mask = (player.collision_mask & ~OPEN_LAYER) | 1
	if ray != null:
		ray.collision_mask |= OPEN_LAYER


## The camp's world static bodies onto OPEN_LAYER.
static func _relayer_camp(camp: Node) -> void:
	for n: Node in camp.find_children("*", "CollisionObject3D", true, false):
		var c := n as CollisionObject3D
		if c.collision_layer & 1:
			c.collision_layer = (c.collision_layer & ~1) | OPEN_LAYER


## Nodes freed a frame when a place is let go (the Lower Stacks' 9,000 at once
## took a 240 ms frame; 250 a frame, 15 ms frames).
const FREE_PER_FRAME: int = 50


## Lets a place go: hidden and asleep at once, its nodes freed leaves first,
## FREE_PER_FRAME a frame.
func _free_slowly(place: Node) -> void:
	if place is Node3D:
		(place as Node3D).visible = false
	place.process_mode = Node.PROCESS_MODE_DISABLED
	var order: Array[Node] = []
	var stack: Array[Node] = [place]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		order.append(n)
		for c: Node in n.get_children():
			stack.append(c)
	order.reverse()     # children before their parents
	var done: int = 0
	for n: Node in order:
		if is_instance_valid(n):
			n.free()
		done += 1
		if done % FREE_PER_FRAME == 0:
			await get_tree().process_frame


## A place's lights leave the vestibules out now and as its rooms stream in.
func _watch_lights(place: Node) -> void:
	_unlight(place)
	if place is Area and (place as Area).streamer != null:
		var area := place as Area
		area.streamer.room_loaded.connect(func(slot: String) -> void:
			if area.rooms.has(slot):
				_unlight(area.rooms[slot]))

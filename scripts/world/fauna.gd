class_name Fauna
extends Node3D
## The animals of one place (phase 19, docs/npc/phase-19-design.md): finds where
## each kind can live in a room once the room is built, puts its animals there,
## ticks them while you are near, and frees them with the room.
##
## In an Area it follows the streamer (room_loaded / room_unloaded; every room
## at once when the area doesn't stream). In the camp or the lake the whole
## scene is one room, named by its place id. The animals are children of this
## node, not of their room, so a room taken apart in slices never takes a
## half-built animal with it.
##
## Everything is seeded by the world seed, the room's key and the kind: a room
## shows the same animals on every visit and in every process. Nothing is
## saved yet (phase 19 Q8: step 5 adds how plentiful each kind is).
##
## Costs (phase 19 Q12): sounding the water runs in BUDGET_MS a frame; animals
## further than SLEEP_DISTANCE from the camera aren't ticked (or drawn); at
## most MAX_THINKING simple animals and MAX_SWARMS swarms live at once.

const DEFS: Array[String] = ["res://actors/defs/goldfish.tres", "res://actors/defs/cave_barb.tres"]
const BUDGET_MS: float = 1.0
const SLEEP_DISTANCE: float = 30.0
## Per view: at most this many simple animals and swarms awake (the nearest;
## the rest are hidden and still).
const MAX_THINKING: int = 40
const MAX_SWARMS: int = 8
## Live in the place at once (rooms near you, awake or not).
const MAX_LIVE_THINKING: int = 80
const MAX_LIVE_SWARMS: int = 16
## Physics frames to wait after a room arrives, so its collision is in the space.
const SETTLE_FRAMES: int = 2
## The place's Fauna is in this group (the F3 panel finds it there).
const GROUP: StringName = &"fauna"

## The place id when the whole scene is one room ("camp", "lake").
var place_id: String = ""
var area: Area
var defs: Array[CreatureDef] = []
## Room slot -> [groups].
var groups: Dictionary = {}
## Slots waiting: {slot, node, type, state, bodies, at, wait}.
var _jobs: Array[Dictionary] = []
## Last tick's cost and counts, for the F3 panel and the gates.
var stats: Dictionary = {"tick_ms": 0.0, "worst_tick_ms": 0.0, "scan_ms": 0.0, "worst_scan_ms": 0.0, "thinking": 0, "swarms": 0, "awake": 0, "animals": 0}


## Gives `world` (an Area, or a place's root) its animals.
static func attach(world: Node3D, id: String = "") -> Fauna:
	var f := Fauna.new()
	f.name = "Fauna"
	f.place_id = id
	f.area = world as Area
	world.add_child(f)
	return f


func _ready() -> void:
	add_to_group(GROUP)
	for p: String in DEFS:
		var d: CreatureDef = load(p) as CreatureDef
		if d != null:
			defs.append(d)
			# Built now, while the place loads: the first build of a fish's
			# material costs tens of ms (its shader), a hitch if left to the room.
			FishBody.mesh(d)
			FishBody.material(d)
	if area != null:
		if area.streamer != null:
			area.streamer.room_loaded.connect(_on_room_loaded)
			area.streamer.room_unloaded.connect(_on_room_unloaded)
		for slot: String in area.rooms:
			_on_room_loaded(slot)
	else:
		_queue("", get_parent() as Node3D, place_id, "")


func _on_room_loaded(slot: String) -> void:
	var room: Node3D = area.rooms.get(slot) as Node3D
	var pr: AreaPlan.Room = area.plan.room(slot) if area.plan != null else null
	if room == null or pr == null:
		return
	var state: String = str(pr.grammar.get_meta("state", "")) if pr.grammar != null else ""
	_queue(slot, room, pr.room_type, state)


func _on_room_unloaded(slot: String) -> void:
	_jobs = _jobs.filter(func(j: Dictionary) -> bool: return j["slot"] != slot)
	for g: Node in groups.get(slot, []):
		if is_instance_valid(g):
			g.queue_free()
	groups.erase(slot)


func _queue(slot: String, node: Node3D, type: String, state: String) -> void:
	if node == null or not defs.any(func(d: CreatureDef) -> bool: return d.rooms.has(type)):
		return
	_on_room_unloaded(slot)
	_jobs.append({"slot": slot, "node": node, "type": type, "state": state, "bodies": null, "at": 0, "wait": SETTLE_FRAMES})


func _physics_process(_delta: float) -> void:
	for j: Dictionary in _jobs:
		j["wait"] = int(j["wait"]) - 1


func _process(delta: float) -> void:
	_work()
	var t0: int = Time.get_ticks_usec()
	var cam: Camera3D = get_viewport().get_camera_3d()
	var player: Node3D = get_tree().get_first_node_in_group("player") as Node3D
	if player == null and cam != null:
		player = cam.get_parent() as Node3D
	var feet: Vector3 = player.global_position if player != null else Vector3(0, -10000, 0)
	var moving: float = (player as CharacterBody3D).velocity.length() if player is CharacterBody3D else 0.0
	var eye: Vector3 = cam.global_position if cam != null else feet
	var awake: int = 0
	var thinking: int = 0
	var swarms: int = 0
	var animals: int = 0
	var near: Array = []     # [distance, group, swarm]
	for slot: String in groups:
		for g: Node in groups[slot]:
			var mmi := g as MultiMeshInstance3D
			if mmi == null or not is_instance_valid(mmi):
				continue
			var n: int = mmi.multimesh.instance_count
			animals += n
			if g is FishSchool:
				swarms += 1
			else:
				thinking += n
			var b: WaterBody = g.get("body")
			if b != null and b.bounds.grow(SLEEP_DISTANCE).has_point(eye):
				near.append([mmi.global_position.distance_to(eye), mmi, g is FishSchool])
			else:
				mmi.visible = false
	near.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var n_think: int = 0
	var n_swarm: int = 0
	for e: Array in near:
		var mmi: MultiMeshInstance3D = e[1]
		var n: int = mmi.multimesh.instance_count
		var ok: bool = (n_swarm < MAX_SWARMS) if e[2] else (n_think + n <= MAX_THINKING)
		mmi.visible = ok
		if not ok:
			continue
		if e[2]:
			n_swarm += 1
		else:
			n_think += n
		awake += n
		mmi.call("tick", delta, feet, moving)
	var ms: float = (Time.get_ticks_usec() - t0) / 1000.0
	stats["tick_ms"] = ms
	stats["worst_tick_ms"] = maxf(float(stats["worst_tick_ms"]), ms)
	stats["thinking"] = thinking
	stats["swarms"] = swarms
	stats["awake"] = awake
	stats["animals"] = animals


## Finds and sounds the water of waiting rooms within BUDGET_MS, and fills
## each room once its water is known.
func _work() -> void:
	if _jobs.is_empty():
		return
	var t0: int = Time.get_ticks_usec()
	var deadline: int = t0 + int(BUDGET_MS * 1000.0)
	while not _jobs.is_empty() and Time.get_ticks_usec() < deadline:
		var j: Dictionary = _jobs[0]
		if int(j["wait"]) > 0:
			break
		var node: Node3D = j["node"]
		if not is_instance_valid(node):
			_jobs.pop_front()
			continue
		if j["bodies"] == null:
			if j.get("scan") == null:
				j["scan"] = HabitatScan.begin(node)
			if not HabitatScan.step(j["scan"], deadline):
				break
			j["bodies"] = HabitatScan.finish(j["scan"])
			continue
		var bodies: Array = j["bodies"]
		var space: PhysicsDirectSpaceState3D = node.get_world_3d().direct_space_state
		while int(j["at"]) < bodies.size() and Time.get_ticks_usec() < deadline:
			if HabitatScan.sound(bodies[int(j["at"])], space, deadline):
				j["at"] = int(j["at"]) + 1
		if int(j["at"]) >= bodies.size():
			_jobs.pop_front()
			_populate(j)
	var ms: float = (Time.get_ticks_usec() - t0) / 1000.0
	stats["scan_ms"] = ms
	stats["worst_scan_ms"] = maxf(float(stats.get("worst_scan_ms", 0.0)), ms)


func _populate(j: Dictionary) -> void:
	var slot: String = j["slot"]
	var node: Node3D = j["node"]
	var key: String = (node as RoomTemplate).room_key() if node is RoomTemplate else str(j["type"])
	var out: Array = groups.get(slot, [])
	var ws: Node = get_node_or_null("/root/WorldState")
	var world_seed: int = int(ws.call("world_seed")) if ws != null else 1
	var bodies: Array = j["bodies"]
	for bi: int in bodies.size():
		var b: WaterBody = bodies[bi]
		for d: CreatureDef in defs:
			if d.habitat != "water" or not d.rooms.has(str(j["type"])):
				continue
			var abandoned: bool = str(j["state"]) == RoomGrammar.ABANDONED
			var places: int = b.deep_samples(d.min_depth).size()
			if places < 4 or b.area() < d.min_area:
				continue
			var rng := RandomNumberGenerator.new()
			rng.seed = hash([world_seed, key, bi, str(d.id)])
			if d.build == "swarm":
				if d.state == "kept" and abandoned:
					continue
				var schools: int = clampi(1 + int(b.area() / d.area_each), 1, d.max_groups)
				for s: int in schools:
					if int(stats["swarms"]) + _count(out, true) >= MAX_LIVE_SWARMS:
						break
					var n: int = rng.randi_range(d.group_size.x, d.group_size.y)
					var start: Vector3 = b.deep_samples(d.min_depth)[rng.randi() % places]
					var school := FishSchool.new()
					add_child(school)
					school.setup(d, b, n, rng.randi(), start)
					out.append(school)
			else:
				var survivor: bool = false
				var n: int = clampi(roundi(b.area() / d.area_each), d.group_size.x, d.group_size.y)
				if abandoned:
					if d.state != "kept" or rng.randf() >= d.survivor_chance:
						continue
					survivor = true
					n = 1
				elif d.state == "abandoned":
					continue
				n = mini(n, MAX_LIVE_THINKING - int(stats["thinking"]) - _count(out, false))
				if n <= 0:
					continue
				var pool := FishPool.new()
				add_child(pool)
				pool.setup(d, b, n, rng.randi(), survivor)
				pool.flow = _flow_of(b)
				out.append(pool)
	groups[slot] = out


static func _count(gs: Array, swarm: bool) -> int:
	var n: int = 0
	for g: Node in gs:
		if is_instance_valid(g) and (g is FishSchool) == swarm:
			n += 1 if swarm else (g as MultiMeshInstance3D).multimesh.instance_count
	return n


## The water's flow (m/s): its material's, the shader's default when unset.
static func _flow_of(b: WaterBody) -> Vector2:
	if b.material == "" or not ResourceLoader.exists(b.material.get_slice("::", 0)):
		return Vector2.ZERO
	var m := load(b.material) as ShaderMaterial if not b.material.contains("::") else null
	if m == null:
		return Vector2(0.0, 0.22)     # a scene's own water at the shader's defaults (the camp's stream)
	var f: Variant = m.get_shader_parameter("flow")
	return f as Vector2 if f != null else Vector2(0.0, 0.22)

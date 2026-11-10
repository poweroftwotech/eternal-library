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
## A room's job, a slice a frame: find its still water and sound it (fish),
## read its lights (flames for moths; flames and fungi make a roof light),
## look up for its roofs (glowworms and bats on the dark ones), then fill it.
##
## Everything is seeded by the world seed, the room's key and the kind: a room
## shows the same animals on every visit and in every process. Nothing is
## saved yet (phase 19 Q8: step 5 adds how plentiful each kind is).
##
## Costs (phase 19 Q12): the scans run in BUDGET_MS a frame; animals further
## than SLEEP_DISTANCE from the camera aren't ticked (or drawn); at most
## MAX_THINKING simple animals and MAX_SWARMS swarms are awake at once.

const DEFS: Array[String] = ["res://actors/defs/goldfish.tres", "res://actors/defs/cave_barb.tres",
	"res://actors/defs/candle_moth.tres", "res://actors/defs/glowworm.tres", "res://actors/defs/bat.tres", "res://actors/defs/cat.tres",
	"res://actors/defs/rat.tres", "res://actors/defs/gecko.tres"]
const BUDGET_MS: float = 1.0
const SLEEP_DISTANCE: float = 30.0
## Per view: at most this many simple animals and swarms awake (the nearest;
## the rest are hidden and still).
const MAX_THINKING: int = 64
const MAX_SWARMS: int = 8
## Live in the place at once (rooms near you, awake or not).
const MAX_LIVE_THINKING: int = 120
const MAX_LIVE_SWARMS: int = 40
## Physics frames to wait after a room arrives, so its collision is in the space.
const SETTLE_FRAMES: int = 2
## The place's Fauna is in this group (the F3 panel finds it there).
const GROUP: StringName = &"fauna"
## Roof scan: points looked up from, at most, per room.
const MAX_ROOF_STARTS: int = 600
## Bats: a roost needs this much roof over the floor (m), and roosts keep this
## far apart (m); glowworm colonies likewise.
const ROOST_APART: float = 8.0
const COLONY_APART: float = 6.0

## The place id when the whole scene is one room ("camp", "lake").
var place_id: String = ""
var area: Area
var defs: Array[CreatureDef] = []
## Room slot -> [groups].
var groups: Dictionary = {}
## Slots waiting: {slot, node, type, state, cells, wait, bodies, at, scan,
## lights, roofs}.
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
		if d == null:
			continue
		# The area's Animals setting: how many of this kind here.
		var amount: float = 1.0
		if area != null and area.recipe != null:
			amount = float(area.recipe.fauna.get(str(d.id), 1.0))
		if amount <= 0.0:
			continue
		d = d.scaled(amount)
		defs.append(d)
		# Built now, while the place loads: the first build of an animal's
		# material costs tens of ms (its shader), a hitch if left to the room.
		if d.habitat == "water":
			FishBody.mesh(d)
			FishBody.material(d)
		elif d.habitat == "wall_foot" or d.habitat == "wall_lamp":
			GroundBody.material(d)
		elif d.habitat == "lane":
			CatBody.material()
		else:
			AirBody.material(d)
	AirBody.moth_mesh()
	AirBody.bat_mesh()
	AirBody.worm_mesh()
	GroundBody.rat_mesh()
	GroundBody.gecko_mesh()
	GroundBody.hole_mesh()
	GroundBody.hole_material()
	if area != null:
		if area.streamer != null:
			area.streamer.room_loaded.connect(_on_room_loaded)
			area.streamer.room_unloaded.connect(_on_room_unloaded)
		for slot: String in area.rooms:
			_on_room_loaded(slot)
	else:
		_queue("", get_parent() as Node3D, place_id, "", [])


func _on_room_loaded(slot: String) -> void:
	var room: Node3D = area.rooms.get(slot) as Node3D
	var pr: AreaPlan.Room = area.plan.room(slot) if area.plan != null else null
	if room == null or pr == null:
		return
	var state: String = str(pr.grammar.get_meta("state", "")) if pr.grammar != null else ""
	var cells: Array = pr.floor_cells.keys() + pr.blocked_cells.keys()
	_queue(slot, room, pr.room_type, state, cells, pr.no_animals, pr.floor_cells.keys())


func _on_room_unloaded(slot: String) -> void:
	_jobs = _jobs.filter(func(j: Dictionary) -> bool: return j["slot"] != slot)
	for g: Node in groups.get(slot, []):
		if is_instance_valid(g):
			g.queue_free()
	groups.erase(slot)


## Whether kind `d` lives in a room of `type` in `state`.
static func lives_in(d: CreatureDef, type: String, state: String, kept_out: PackedStringArray = []) -> bool:
	if d.not_rooms.has(type) or kept_out.has(str(d.id)):
		return false
	var abandoned: bool = state == RoomGrammar.ABANDONED
	if d.any_abandoned and abandoned:
		return true
	if not (d.rooms.has(type) or d.rooms.has("*") or d.loose_rooms.has(type)):
		return false
	if d.state == "kept" and abandoned and d.build != "simple":
		return false     # (a kept pool's lone survivor is the simple kind's)
	if d.state == "abandoned" and not abandoned:
		return false
	return true


func _queue(slot: String, node: Node3D, type: String, state: String, cells: Array, kept_out: PackedStringArray = [], floor_cells: Array = []) -> void:
	if node == null or not defs.any(func(d: CreatureDef) -> bool: return lives_in(d, type, state, kept_out)):
		return
	_on_room_unloaded(slot)
	_jobs.append({"slot": slot, "node": node, "type": type, "state": state, "cells": cells, "floor": floor_cells, "out": kept_out, "wait": SETTLE_FRAMES,
		"bodies": null, "at": 0, "lights": null, "roofs": null})


func _needs(j: Dictionary, habitat: String) -> bool:
	for d: CreatureDef in defs:
		if d.habitat == habitat and lives_in(d, str(j["type"]), str(j["state"]), j["out"]):
			return true
	return false


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
			var band := g as CatBand
			if band != null and is_instance_valid(band):
				animals += band.count()
				thinking += band.count()
				if band.bounds.grow(SLEEP_DISTANCE).has_point(eye):
					near.append([_distance(band.bounds, eye), band, false])
				else:
					_show(band, false)
				continue
			var mmi := g as MultiMeshInstance3D
			if mmi == null or not is_instance_valid(mmi) or mmi.multimesh == null:
				continue
			var n: int = mmi.multimesh.instance_count
			var swarm: bool = _is_swarm(g)
			animals += n
			if swarm:
				swarms += 1
			else:
				thinking += n
			var box: AABB = _bounds(g)
			if box.grow(SLEEP_DISTANCE).has_point(eye):
				near.append([_distance(box, eye), mmi, swarm])
			else:
					_show(mmi, false)
	near.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var n_think: int = 0
	var n_swarm: int = 0
	for e: Array in near:
		var g: Node3D = e[1]
		var n: int = (g as CatBand).count() if g is CatBand else (g as MultiMeshInstance3D).multimesh.instance_count
		var ok: bool = (n_swarm < MAX_SWARMS) if e[2] else (n_think + n <= MAX_THINKING)
		_show(g, ok)
		if not ok:
			continue
		if e[2]:
			n_swarm += 1
		else:
			n_think += n
		awake += n
		g.call("tick", delta, feet, moving)
	var ms: float = (Time.get_ticks_usec() - t0) / 1000.0
	stats["tick_ms"] = ms
	stats["worst_tick_ms"] = maxf(float(stats["worst_tick_ms"]), ms)
	stats["thinking"] = thinking
	stats["swarms"] = swarms
	stats["awake"] = awake
	stats["animals"] = animals


static func _is_swarm(g: Node) -> bool:
	return not (g is FishPool or g is CatBand or g is RatPack or g is GeckoWall)


## A group's box (global): its water's, or its own.
static func _bounds(g: Node) -> AABB:
	var b: WaterBody = g.get("body") as WaterBody
	return b.bounds if b != null else g.get("bounds")


static func _distance(box: AABB, p: Vector3) -> float:
	return p.distance_to(Vector3(clampf(p.x, box.position.x, box.end.x), clampf(p.y, box.position.y, box.end.y), clampf(p.z, box.position.z, box.end.z)))


## Works through waiting rooms within BUDGET_MS, and fills each room once
## what it needs is known.
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
		if not is_instance_valid(node) or not node.is_inside_tree():
			_jobs.pop_front()
			continue
		var space: PhysicsDirectSpaceState3D = node.get_world_3d().direct_space_state
		# 1. The water.
		if j["bodies"] == null:
			if not _needs(j, "water"):
				j["bodies"] = []
				continue
			if j.get("scan") == null:
				j["scan"] = HabitatScan.begin(node)
			if not HabitatScan.step(j["scan"], deadline):
				break
			j["bodies"] = HabitatScan.finish(j["scan"])
			continue
		var bodies: Array = j["bodies"]
		if int(j["at"]) < bodies.size():
			while int(j["at"]) < bodies.size() and Time.get_ticks_usec() < deadline:
				if HabitatScan.sound(bodies[int(j["at"])], space, deadline):
					j["at"] = int(j["at"]) + 1
			continue
		# 2. The lights.
		if j["lights"] == null:
			j["lights"] = HabitatScan.lights(node) if (_needs(j, "flame") or _needs(j, "dark_roof") or _needs(j, "wall_lamp")) else {"flames": [], "glows": []}
			continue
		# 2b. The walked lanes and rest spots.
		if not j.has("graph"):
			j["graph"] = LaneGraph.begin(node, bodies, j["floor"], area.global_transform if area != null else Transform3D.IDENTITY) if _needs(j, "lane") else null
			continue
		if j["graph"] != null and not (j["graph"] as LaneGraph).step(space, deadline):
			break
		# 3. The roofs.
		if j["roofs"] == null:
			if not _needs(j, "dark_roof"):
				j["roofs"] = HabitatScan.RoofScan.new()
				continue
			j["roofs"] = _roof_starts(j)
		var roofs: HabitatScan.RoofScan = j["roofs"]
		if not HabitatScan.roof_step(roofs, space, deadline):
			break
		_jobs.pop_front()
		_populate(j)
	var ms: float = (Time.get_ticks_usec() - t0) / 1000.0
	stats["scan_ms"] = ms
	stats["worst_scan_ms"] = maxf(float(stats.get("worst_scan_ms", 0.0)), ms)


## Where to look up from: four points in each of the room's cells (an area
## room), and over its water (every place; the lake has nothing else).
func _roof_starts(j: Dictionary) -> HabitatScan.RoofScan:
	var floors := PackedVector3Array()
	var waters := PackedVector3Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([str(j["slot"]), str(j["type"]), "roofs"])
	if area != null:
		for c: Vector3i in j["cells"]:
			var centre: Vector3 = area.global_transform * CellGrid.cell_centre(c)
			for k: int in 4:
				var off := Vector3((k % 2) * 2.0 - 1.0, 0.0, float(k >> 1) * 2.0 - 1.0) * CellGrid.BAY * 0.25
				off += Vector3(rng.randf_range(-0.5, 0.5), 0.0, rng.randf_range(-0.5, 0.5))
				floors.append(centre + area.global_transform.basis * off + Vector3(0, 0.5, 0))
	for b: WaterBody in j["bodies"]:
		var step: int = maxi(1, b.samples.size() >> 7)
		for i: int in range(0, b.samples.size(), step):
			var s: Vector3 = b.samples[i]
			waters.append(Vector3(s.x, b.surface, s.z))
	var total: int = floors.size() + waters.size()
	var scan := HabitatScan.RoofScan.new()
	scan.starts = _thin(floors, floori(float(MAX_ROOF_STARTS * floors.size()) / maxi(total, 1)))
	scan.on_floor = scan.starts.size()
	scan.starts.append_array(_thin(waters, floori(float(MAX_ROOF_STARTS * waters.size()) / maxi(total, 1))))
	return scan


static func _thin(points: PackedVector3Array, most: int) -> PackedVector3Array:
	if points.size() <= most:
		return points
	var out := PackedVector3Array()
	var step: float = float(points.size()) / maxi(most, 1)
	for i: int in most:
		out.append(points[int(i * step)])
	return out


func _populate(j: Dictionary) -> void:
	var slot: String = j["slot"]
	var node: Node3D = j["node"]
	var key: String = (node as RoomTemplate).room_key() if node is RoomTemplate else str(j["type"])
	var out: Array = groups.get(slot, [])
	var ws: Node = get_node_or_null("/root/WorldState")
	var world_seed: int = int(ws.call("world_seed")) if ws != null else 1
	var type: String = str(j["type"])
	var abandoned: bool = str(j["state"]) == RoomGrammar.ABANDONED
	var bodies: Array = j["bodies"]
	var space: PhysicsDirectSpaceState3D = node.get_world_3d().direct_space_state
	for d: CreatureDef in defs:
		if not lives_in(d, type, str(j["state"]), j["out"]):
			continue
		match d.habitat:
			"water":
				for bi: int in bodies.size():
					var rng := RandomNumberGenerator.new()
					rng.seed = hash([world_seed, key, bi, str(d.id)])
					_fill_water(d, bodies[bi], rng, abandoned, out)
			"flame":
				var rng := RandomNumberGenerator.new()
				rng.seed = hash([world_seed, key, str(d.id)])
				_fill_flames(d, j, rng, abandoned, out)
			"dark_roof":
				var rng := RandomNumberGenerator.new()
				rng.seed = hash([world_seed, key, str(d.id)])
				if d.id == "bat":
					_fill_bats(d, j, rng, space, out)
				else:
					_fill_glowworms(d, j, rng, space, out)
			"lane":
				var rng := RandomNumberGenerator.new()
				rng.seed = hash([world_seed, key, str(d.id)])
				_fill_cats(d, j, rng, out)
			"wall_foot":
				var rng := RandomNumberGenerator.new()
				rng.seed = hash([world_seed, key, str(d.id)])
				_fill_rats(d, j, rng, space, out)
			"wall_lamp":
				var rng := RandomNumberGenerator.new()
				rng.seed = hash([world_seed, key, str(d.id)])
				_fill_geckos(d, j, rng, space, out)
	groups[slot] = out


func _fill_water(d: CreatureDef, b: WaterBody, rng: RandomNumberGenerator, abandoned: bool, out: Array) -> void:
	var places: int = b.deep_samples(d.min_depth).size()
	if places < 4 or b.area() < d.min_area:
		return
	if d.build == "swarm":
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
		return
	var survivor: bool = false
	var n: int = clampi(roundi(b.area() / d.area_each), d.group_size.x, d.group_size.y)
	if abandoned:
		if d.state != "kept" or rng.randf() >= d.survivor_chance:
			return
		survivor = true
		n = 1
	elif d.state == "abandoned":
		return
	n = mini(n, MAX_LIVE_THINKING - int(stats["thinking"]) - _count(out, false))
	if n <= 0:
		return
	var pool := FishPool.new()
	add_child(pool)
	pool.setup(d, b, n, rng.randi(), survivor)
	pool.flow = _flow_of(b)
	out.append(pool)


## Moths: a few at each burning flame; loose over the floor in its loose rooms.
func _fill_flames(d: CreatureDef, j: Dictionary, rng: RandomNumberGenerator, abandoned: bool, out: Array) -> void:
	var flames: Array = (j["lights"] as Dictionary)["flames"]
	var loose := PackedVector3Array()
	if d.loose_rooms.has(str(j["type"])) and area != null and not (j["cells"] as Array).is_empty():
		# Over the middle of the room (the court), not its corridors: the half
		# of its cells nearest their mean.
		var cells: Array = (j["cells"] as Array).duplicate()
		var mean := Vector3.ZERO
		for c: Vector3i in cells:
			mean += CellGrid.cell_centre(c)
		mean /= cells.size()
		cells.sort_custom(func(a: Vector3i, b: Vector3i) -> bool: return CellGrid.cell_centre(a).distance_to(mean) < CellGrid.cell_centre(b).distance_to(mean))
		cells = cells.slice(0, maxi(1, cells.size() >> 1))
		for k: int in d.loose_count:
			var c: Vector3i = cells[rng.randi() % cells.size()]
			loose.append(area.global_transform * CellGrid.cell_centre(c))
	if (flames.is_empty() and loose.is_empty()) or int(stats["swarms"]) + _count(out, true) >= MAX_LIVE_SWARMS:
		return
	var swarm := MothSwarm.new()
	add_child(swarm)
	swarm.setup(d, flames, loose, rng, abandoned)
	if swarm.multimesh == null:
		swarm.queue_free()
		return
	out.append(swarm)


## The dark roofs a kind will take: high enough, no flame near, far enough
## from fungi.
func _dark_roofs(d: CreatureDef, j: Dictionary) -> Array[Dictionary]:
	var lights: Dictionary = j["lights"]
	var found: Array[Dictionary] = []
	for r: Dictionary in (j["roofs"] as HabitatScan.RoofScan).roofs:
		if d.rock_only and not bool(r.get("rock", false)):
			continue
		if float(r["height"]) >= d.min_height and HabitatScan.is_dark(r["at"], lights, d.glow_gap, d.dark_radius):
			found.append(r)
	return found


## Up to `count` roof points from `roofs`, each at least `apart` m from the others.
static func _spread(roofs: Array[Dictionary], count: int, apart: float, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var picked: Array[Dictionary] = []
	var order: Array = MothSwarm._seeded_order(roofs, rng)
	for r: Dictionary in order:
		if picked.size() >= count:
			break
		var ok: bool = true
		for p: Dictionary in picked:
			if (p["at"] as Vector3).distance_to(r["at"]) < apart:
				ok = false
				break
		if ok:
			picked.append(r)
	return picked


## Glowworms: colonies round a few dark roof points, each worm on the roof
## right over its place, all of the room's in one colony object.
func _fill_glowworms(d: CreatureDef, j: Dictionary, rng: RandomNumberGenerator, space: PhysicsDirectSpaceState3D, out: Array) -> void:
	var dark: Array[Dictionary] = _dark_roofs(d, j)
	if dark.size() < 4 or int(stats["swarms"]) + _count(out, true) >= MAX_LIVE_SWARMS:
		return
	var centres: Array[Dictionary] = _spread(dark, d.max_groups, COLONY_APART, rng)
	var worms: Array = []
	for c: Dictionary in centres:
		var n: int = rng.randi_range(d.group_size.x, d.group_size.y)
		var near: Array = dark.filter(func(r: Dictionary) -> bool: return (r["at"] as Vector3).distance_to(c["at"]) < 6.0)
		for k: int in n:
			if worms.size() >= d.room_cap:
				break
			var base: Dictionary = near[rng.randi() % near.size()]
			var p: Vector3 = (base["at"] as Vector3) + Vector3(rng.randf_range(-2.0, 2.0), -0.6, rng.randf_range(-2.0, 2.0))
			var roof: Variant = HabitatScan.roof_over(space, p, 1.5)
			if roof == null:
				continue
			worms.append({"at": roof as Vector3, "length": rng.randf_range(0.04, 0.3)})
	if worms.size() < 4:
		return
	var colour: Color = d.glow_colour
	var glows: Array = (j["lights"] as Dictionary)["glows"]
	var best: float = INF
	for g: Dictionary in glows:
		var dist: float = (g["at"] as Vector3).distance_to(centres[0]["at"])
		if dist < best:
			best = dist
			colour = g["colour"]
	var colony := GlowColony.new()
	add_child(colony)
	colony.setup(d, worms, colour, rng)
	out.append(colony)


## Cats: one for every few soft places to lie in a lived-in room with ways to
## walk; one alone in a place that is all one room (the camp).
func _fill_cats(d: CreatureDef, j: Dictionary, rng: RandomNumberGenerator, out: Array) -> void:
	var g: LaneGraph = j.get("graph") as LaneGraph
	if g == null or g.home.size() < 2 or g.soft_found == 0:
		return
	var n: int = 1 if area == null else clampi(roundi(g.soft_found / d.area_each), d.group_size.x, d.group_size.y)
	n = mini(n, MAX_LIVE_THINKING - int(stats["thinking"]) - _count(out, false))
	if n <= 0:
		return
	var band := CatBand.new()
	add_child(band)
	band.setup(d, g, n, rng.randi())
	out.append(band)


## The room's meshes and their boxes, read once (geckos and rat holes sit on
## what you see of a wall, not on its collision).
func _boxes(j: Dictionary) -> Array:
	if not j.has("boxes"):
		j["boxes"] = GeckoWall.boxes_of(j["node"])
	return j["boxes"]


## Rats: a few runs along the foot of walls in a forgotten room, a hole at
## each end, the room's rats shared among them.
func _fill_rats(d: CreatureDef, j: Dictionary, rng: RandomNumberGenerator, space: PhysicsDirectSpaceState3D, out: Array) -> void:
	var cells: Array = j["floor"]
	if area == null or cells.is_empty():
		return
	var runs: Array[Dictionary] = RatPack.find_runs(space, cells, area.global_transform, rng, d.max_groups)
	var n: int = mini(rng.randi_range(d.group_size.x, d.group_size.y), MAX_LIVE_THINKING - int(stats["thinking"]) - _count(out, false))
	if runs.is_empty() or n <= 0:
		return
	var pack := RatPack.new()
	add_child(pack)
	pack.setup(d, runs, n, rng.randi(), _boxes(j))
	out.append(pack)


## Geckos: on the wall beside some of the room's burning lamps.
func _fill_geckos(d: CreatureDef, j: Dictionary, rng: RandomNumberGenerator, space: PhysicsDirectSpaceState3D, out: Array) -> void:
	var sites: Array[Dictionary] = []
	for f: Dictionary in MothSwarm._seeded_order((j["lights"] as Dictionary)["flames"], rng):
		if rng.randf() >= d.flame_share or sites.size() * d.group_size.y >= d.room_cap:
			continue
		var site: Variant = GeckoWall.find_site(space, f)
		if site != null:
			(site as Dictionary)["meshes"] = GeckoWall.near(_boxes(j), (site as Dictionary)["at"], 2.0)
			sites.append(site)
	if sites.is_empty() or int(stats["thinking"]) + _count(out, false) >= MAX_LIVE_THINKING:
		return
	var wall := GeckoWall.new()
	add_child(wall)
	wall.setup(d, sites, space, rng.randi())
	if wall.multimesh == null:
		wall.queue_free()
		return
	out.append(wall)


## Shown and awake, or hidden and still (a band's cats stop animating too).
static func _show(g: Node3D, on: bool) -> void:
	g.visible = on
	if g is CatBand:
		g.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED


## Bats: a few roosts on dark roofs high enough to hang from, apart.
func _fill_bats(d: CreatureDef, j: Dictionary, rng: RandomNumberGenerator, space: PhysicsDirectSpaceState3D, out: Array) -> void:
	var dark: Array[Dictionary] = _dark_roofs(d, j)
	if dark.is_empty():
		return
	var roosts: int = d.max_groups
	if d.kept_groups >= 0 and str(j["state"]) != RoomGrammar.ABANDONED:
		roosts = mini(roosts, d.kept_groups)
	for c: Dictionary in _spread(dark, roosts, ROOST_APART, rng):
		if int(stats["swarms"]) + _count(out, true) >= MAX_LIVE_SWARMS:
			break
		var at: Vector3 = c["at"]
		var spots: Array[Vector3] = []
		var n: int = rng.randi_range(d.group_size.x, d.group_size.y)
		for k: int in n * 2:
			if spots.size() >= n:
				break
			var p: Vector3 = at + Vector3(rng.randf_range(-0.8, 0.8), -0.5, rng.randf_range(-0.8, 0.8))
			var roof: Variant = HabitatScan.roof_over(space, p, 1.2)
			if roof != null:
				spots.append(roof as Vector3)
		if spots.size() < 3:
			continue
		var roost := BatRoost.new()
		add_child(roost)
		roost.setup(d, at, spots, _open_ways(space, at - Vector3(0, 1.0, 0)), rng)
		out.append(roost)


## The open ways from `p`, eight directions level with it: [{dir, reach}].
static func _open_ways(space: PhysicsDirectSpaceState3D, p: Vector3) -> Array:
	var ways: Array = []
	var q := PhysicsRayQueryParameters3D.new()
	q.collision_mask = HabitatScan.WORLD_MASK
	q.hit_back_faces = true
	for k: int in 8:
		var dir := Vector3(cos(k * TAU / 8.0), 0, sin(k * TAU / 8.0))
		q.from = p
		q.to = p + dir * 20.0
		var hit: Dictionary = space.intersect_ray(q)
		ways.append({"dir": dir, "reach": 20.0 if hit.is_empty() else p.distance_to(hit["position"])})
	return ways


static func _count(gs: Array, swarm: bool) -> int:
	var n: int = 0
	for g: Node in gs:
		if is_instance_valid(g) and _is_swarm(g) == swarm:
			n += 1 if swarm else ((g as CatBand).count() if g is CatBand else (g as MultiMeshInstance3D).multimesh.instance_count)
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

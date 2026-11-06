extends SceneTree
## Traces where you can walk in the Gorge or the camp for the map (phase 11
## step 2, Q6), from the built place: loads the game there (on its own, no
## seamless neighbour), waits until every piece is in, then casts rays down
## each column of a 0.5 m grid. A floor is a surface facing up with 1.7 m of
## headroom; the floors kept are those reachable from where you stand and
## from its doors, by steps of at most MAX_STEP (stairs are ramps to the
## player), so roofs and ledges you can't get to are left out.
##   godot --path . --script res://tools/map_trace.gd -- gorge|camp --no-seamless
## Writes gen/map/<place>_trace.tres, gen/map/<place>_ink.png and _pencil.png
## (what the map draws), and previews/p11_step2/<place>_trace.png: floors
## kept by height, floors left out in red. Run --import afterwards.
## Re-run after re-baking the place or changing its doors: the Strata Board flags
## that and runs this headless (the output is the same).

const STEP: float = 0.5
const HEADROOM: float = 1.7
const MAX_STEP: float = 0.45
const UP_NORMAL: float = 0.6
## Height above the floor of the sideways check between samples (waist, over kerbs).
const BODY: float = 0.9
const MAX_HITS: int = 16
const WASH := Color(0.47, 0.33, 0.16, 0.22)
const INK := Color("2a2017")
const PENCIL := Color("6f6350")
## A drop of more than this between neighbouring floors is drawn as an edge (a terrace).
const EDGE_DROP: float = 1.2

var game: Node


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var place: String = args[0] if args.size() > 0 else "gorge"
	var main_script: GDScript = load("res://scripts/main.gd")
	main_script.room_override = "camp" if place == "camp" else "area:" + place
	game = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	current_scene = game
	await settle()
	var world: Node3D = game.world
	var bounds: AABB = place_bounds(world, place)
	var seeds: Array[Vector3] = seed_points(world, place)
	print("map_trace %s: bounds %s, %d seeds" % [place, bounds, seeds.size()])
	var t0: int = Time.get_ticks_msec()
	var cols: Dictionary = cast(world, bounds)
	print("map_trace %s: cast %d columns in %d ms" % [place, cols["size"].x * cols["size"].y, Time.get_ticks_msec() - t0])
	var trace: MapTrace = reach(cols, seeds, world)
	trace.place = place
	trace.doors = doors_of(world)
	trace.source_stamp = MapTrace.stamp_of(place, StratumPlan.current().links)
	if place == "gorge":     # the way back to the camp is the corridor out of the Overlook's loggia, no door
		var mid: float = (SeamlessPlaces.CORRIDOR_X.x + SeamlessPlaces.CORRIDOR_X.y) * 0.5
		trace.doors.append({"at": Vector2(mid, SeamlessPlaces.GORGE_END_Z), "out": Vector2(0, 1), "kind": "threshold", "raw": "camp", "to": "camp"})
	write(trace, cols)
	quit()


## Frames until the place has every piece in: its streamer idle and its
## collision shapes stable for 90 frames.
func settle() -> void:
	var stable: int = 0
	var last: int = -1
	var stop_ms: int = Time.get_ticks_msec() + 120000
	while stable < 90 and Time.get_ticks_msec() < stop_ms:
		await physics_frame
		var a: Area = game.world as Area
		var n: int = game.world.find_children("*", "CollisionShape3D", true, false).size()
		if (a == null or (a.is_built and not a.streamer.busy())) and n == last:
			stable += 1
		else:
			stable = 0
		last = n
	print("map_trace: settled with %d collision shapes" % last)


## The place's extent in its own frame: an area's reserved space, the camp's meshes.
func place_bounds(world: Node3D, place: String) -> AABB:
	if world is Area:
		return (world as Area).recipe.placement.envelope
	var out := AABB()
	var first: bool = true
	for v: Node in world.find_children("*", "VisualInstance3D", true, false):
		var b: AABB = world.global_transform.affine_inverse() * ((v as VisualInstance3D).global_transform * (v as VisualInstance3D).get_aabb())
		out = b if first else out.merge(b)
		first = false
	return out.grow(1.0)


## Where you can stand (the spawn) and just inside each door, in the place's frame.
func seed_points(world: Node3D, place: String) -> Array[Vector3]:
	var out: Array[Vector3] = [world.to_local(game.player.global_position)]
	if world is Area:
		var plan: AreaPlan = (world as Area).plan
		for r: AreaPlan.Room in plan.rooms:
			for n: StringName in r.connectors:
				var k: Dictionary = r.connectors[n]
				if str(k["cap"]) == "threshold":
					var xf: Transform3D = k["xf"]
					out.append(xf.origin + xf.basis.z * 1.0 + Vector3.UP * 0.5)     # 1 m back in from the door
	for t: Node in world.find_children("*", "Threshold", true, false):
		var xf: Transform3D = world.global_transform.affine_inverse() * (t as Node3D).global_transform
		out.append(xf.origin + xf.basis.z * 1.0 + Vector3.UP * 0.5)
	return out


## The doors out of the place, in its frame: Thresholds (-Z out through the
## door) and sealed doors (-Z out of the room).
func doors_of(world: Node3D) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var inv: Transform3D = world.global_transform.affine_inverse()
	for n: Node in world.find_children("*", "Node3D", true, false):
		var kind: String = "threshold" if n is Threshold else "sealed" if n is SealedDoor else ""
		if kind == "":
			continue
		var xf: Transform3D = inv * (n as Node3D).global_transform
		var out_dir: Vector3 = -xf.basis.z
		var door: Dictionary = {"at": Vector2(xf.origin.x, xf.origin.z), "out": Vector2(out_dir.x, out_dir.z).normalized(), "kind": kind,
			"raw": str(n.name).trim_prefix("Threshold_") if kind == "threshold" else "", "to": (n as Threshold).to if kind == "threshold" else ""}
		out.append(door)
		print("map_trace: door %s %s at %s" % [kind, door["to"], door["at"]])
	return out


## Every column's floors: {size, origin, floors: Array (per column: Array of heights)}.
func cast(world: Node3D, bounds: AABB) -> Dictionary:
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var size := Vector2i(ceili(bounds.size.x / STEP), ceili(bounds.size.z / STEP))
	var origin := Vector2(bounds.position.x, bounds.position.z)
	var top: float = bounds.end.y + 2.0
	var bottom: float = bounds.position.y - 2.0
	var floors: Array = []
	floors.resize(size.x * size.y)
	var q := PhysicsRayQueryParameters3D.new()
	q.collision_mask = 1     # world_static: not props, water or the invisible blockers
	q.hit_back_faces = true
	var xf: Transform3D = world.global_transform
	for j: int in size.y:
		for i: int in size.x:
			var x: float = origin.x + (i + 0.5) * STEP
			var z: float = origin.y + (j + 0.5) * STEP
			var col: Array = []
			var y: float = top
			var ceiling: float = INF
			for _h: int in MAX_HITS:
				q.from = xf * Vector3(x, y, z)
				q.to = xf * Vector3(x, bottom, z)
				var hit: Dictionary = space.intersect_ray(q)
				if hit.is_empty():
					break
				var p: Vector3 = xf.affine_inverse() * (hit["position"] as Vector3)
				var n: Vector3 = xf.basis.inverse() * (hit["normal"] as Vector3)
				if n.y >= UP_NORMAL and ceiling - p.y >= HEADROOM:
					col.append(p.y)
				ceiling = p.y
				y = p.y - 0.02
			floors[j * size.x + i] = col
	return {"size": size, "origin": origin, "floors": floors}


## Flood fill from the seeds over floors a step apart: the reachable floor per column.
func reach(cols: Dictionary, seeds: Array[Vector3], world: Node3D) -> MapTrace:
	var size: Vector2i = cols["size"]
	var origin: Vector2 = cols["origin"]
	var floors: Array = cols["floors"]
	var trace := MapTrace.new()
	trace.origin = origin
	trace.step = STEP
	trace.size = size
	var height := PackedFloat32Array()
	height.resize(size.x * size.y)
	height.fill(NAN)
	var todo: Array[Vector3] = []     # (i, j, h)
	for s: Vector3 in seeds:
		var i: int = floori((s.x - origin.x) / STEP)
		var j: int = floori((s.z - origin.y) / STEP)
		if i < 0 or j < 0 or i >= size.x or j >= size.y:
			continue
		var best: float = NAN
		for h: float in floors[j * size.x + i]:
			if absf(h - s.y) < 1.2 and (is_nan(best) or absf(h - s.y) < absf(best - s.y)):
				best = h
		if not is_nan(best):
			todo.append(Vector3(i, j, best))
		else:
			print("map_trace: no floor under seed %s" % s)
	# Columns may hold several reachable floors (a bridge over a ledge); the
	# map keeps the highest, the fill visits each (i, j, h) once.
	var seen: Dictionary = {}
	# A step is only taken if nothing stands between the two samples at body
	# height (walls thinner than a sample, the invisible blockers).
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var xf: Transform3D = world.global_transform
	var q := PhysicsRayQueryParameters3D.new()
	q.collision_mask = 1 | 128     # world_static and player_blockers
	q.hit_back_faces = true
	while not todo.is_empty():
		var c: Vector3 = todo.pop_back()
		var key := Vector3i(int(c.x), int(c.y), roundi(c.z * 20.0))
		if seen.has(key):
			continue
		seen[key] = true
		var idx: int = int(c.y) * size.x + int(c.x)
		if is_nan(height[idx]) or c.z > height[idx]:
			height[idx] = c.z
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var ni: int = int(c.x) + d.x
			var nj: int = int(c.y) + d.y
			if ni < 0 or nj < 0 or ni >= size.x or nj >= size.y:
				continue
			for h: float in floors[nj * size.x + ni]:
				if absf(h - c.z) <= MAX_STEP and not seen.has(Vector3i(ni, nj, roundi(h * 20.0))):
					q.from = xf * Vector3(origin.x + (c.x + 0.5) * STEP, c.z + BODY, origin.y + (c.y + 0.5) * STEP)
					q.to = xf * Vector3(origin.x + (ni + 0.5) * STEP, h + BODY, origin.y + (nj + 0.5) * STEP)
					if space.intersect_ray(q).is_empty():
						todo.append(Vector3(ni, nj, h))
	var all_floors: int = 0
	for col: Array in floors:
		all_floors += col.size()
	trace.unreachable = all_floors - seen.size()
	trace.height = height
	return trace


func write(trace: MapTrace, cols: Dictionary) -> void:
	var size: Vector2i = trace.size
	var ink := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	var pencil := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	var preview := Image.create(size.x, size.y, false, Image.FORMAT_RGB8)
	preview.fill(Color(0.08, 0.09, 0.1))
	var lo: float = INF
	var hi: float = -INF
	for h: float in trace.height:
		if not is_nan(h):
			lo = minf(lo, h)
			hi = maxf(hi, h)
	var kept: int = 0
	for j: int in size.y:
		for i: int in size.x:
			var h: float = trace.height[j * size.x + i]
			if is_nan(h):
				if not (cols["floors"][j * size.x + i] as Array).is_empty():
					preview.set_pixel(i, j, Color(0.6, 0.15, 0.12))     # a floor you can't reach
				continue
			kept += 1
			preview.set_pixel(i, j, Color.from_hsv(0.1, 0.35, lerpf(0.35, 1.0, (h - lo) / maxf(hi - lo, 0.01))))
			var edge: bool = false
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n := Vector2i(i, j) + d
				if not trace.has_floor(n) or trace.height[n.y * size.x + n.x] < h - EDGE_DROP:
					edge = true
			if edge:
				ink.set_pixel(i, j, INK)
				if (i + j) % 2 == 0:
					pencil.set_pixel(i, j, PENCIL)
			else:
				ink.set_pixel(i, j, WASH)
	var tn: Vector2i = trace.tile_count()
	var k: int = trace.tile_samples()
	trace.tiles.resize(tn.x * tn.y)
	for j: int in size.y:
		for i: int in size.x:
			if not is_nan(trace.height[j * size.x + i]):
				trace.tiles[(j / k) * tn.x + i / k] = 1
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://gen/map"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://previews/p11_step2"))
	ink.save_png(MapTrace.ink_path(trace.place))
	pencil.save_png(MapTrace.pencil_path(trace.place))
	preview.save_png("res://previews/p11_step2/%s_trace.png" % trace.place)
	var err: Error = ResourceSaver.save(trace, MapTrace.path_of(trace.place))
	print("map_trace %s: %dx%d samples, %d floors kept, %d left out (unreachable); heights %.1f..%.1f m; %s (%s)" % [
		trace.place, size.x, size.y, kept, trace.unreachable, lo, hi, MapTrace.path_of(trace.place), error_string(err)])

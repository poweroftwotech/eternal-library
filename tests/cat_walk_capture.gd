extends SceneTree
## The cats where they live (phase 19 step 3), in the real game: counts, what
## each room's lanes came to, and pictures. Needs a display, not --headless;
## run `godot --headless --import` first, and pass --audio-driver Dummy.
##   godot --path . --resolution 1600x900 --audio-driver Dummy --script res://tests/cat_walk_capture.gd -- <out dir> [place ...] [--seed=N] [--max=N] [--count]
## place: camp (default), a scene path or area:<id>. In an area every room is
## visited. For each room with cats prints its lane points, rest spots, fish
## watching places and cats; for the first --max (3) cats of a place writes
## <place>_<slot>_<n>_rest.png (as found), _walk0..3.png (sent on a stroll,
## 0.7 s apart), _look.png (you beside it) and _run0..2.png (run at).
## --count: no pictures, only the counts (works with --headless).

var max_cats: int = 3
var count_only: bool = false


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var places: PackedStringArray = []
	var out_dir: String = ""
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--seed="):
			Area.seed_override = a.trim_prefix("--seed=").to_int()
		elif a.begins_with("--max="):
			max_cats = a.trim_prefix("--max=").to_int()
		elif a == "--count":
			count_only = true
		elif out_dir == "":
			out_dir = a
		else:
			places.append(a)
	if out_dir == "":
		out_dir = "user://cat_walk"
	if places.is_empty():
		places = ["camp"]
	DirAccess.make_dir_recursive_absolute(out_dir)
	var main_script: GDScript = load("res://scripts/main.gd")
	for place: String in places:
		main_script.room_override = place
		var game: Node = (load("res://main.tscn") as PackedScene).instantiate()
		root.add_child(game)
		game.hud.toast_time = 0
		game.hud.visible = false
		game.stats.visible = false
		game.player.blocked = true
		for _i: int in 20:
			await process_frame
		var tag: String = place.get_file().get_basename().replace("area:", "")
		var world: Node3D = game.world
		var shot: int = 0
		var total: int = 0
		var f: Fauna = world.get_node_or_null("Fauna") as Fauna
		if world is Area:
			var area: Area = world
			f = area.fauna
			for r: AreaPlan.Room in area.plan.rooms:
				var c: Vector3 = area.global_transform * r.xf * Vector3.ZERO
				if not r.floor_cells.is_empty():
					c = area.global_transform * CellGrid.cell_centre(r.floor_cells.keys()[0])
				game.player.teleport(c)
				await _settle(game, f)
				for g: Node in f.groups.get(r.slot_id, []):
					var band := g as CatBand
					if band == null:
						continue
					total += band.count()
					print("  %s %s %s: %d lane points, %d rest spots, %d fish places, %d cats; the first cat can reach %d points" % [tag, r.slot_id, r.room_type, band.graph.lane_points, band.graph.spots.size(), band.graph.watch.size(), band.count(), _reach(band)])
					shot = await _shoot(game, f, band, "%s/%s_%s" % [out_dir, tag, r.slot_id], shot)
		else:
			await _settle(game, f)
			for g: Node in (f.groups.get("", []) if f != null else []):
				var band := g as CatBand
				if band == null:
					continue
				total += band.count()
				print("  %s: %d lane points, %d rest spots, %d fish places, %d cats; the first cat can reach %d of %d points" % [tag, band.graph.lane_points, band.graph.spots.size(), band.graph.watch.size(), band.count(), _reach(band), band.graph.points.size()])
				shot = await _shoot(game, f, band, "%s/%s" % [out_dir, tag], shot)
		print("cat_walk_capture: %s: %d cats; %s" % [tag, total, f.stats if f != null else {}])
		game.queue_free()
		for _i: int in 3:
			await process_frame
	main_script.room_override = ""
	quit()


func _settle(game: Node, f: Fauna) -> void:
	for _i: int in 10:
		await process_frame
	var streamer: Variant = game.world.get("streamer")
	while streamer != null and streamer.busy():
		await process_frame
	for _i: int in 600:
		if f == null or f._jobs.is_empty():
			break
		await process_frame
	for _i: int in 20:
		await process_frame


func _shoot(game: Node, f: Fauna, band: CatBand, stem: String, shot: int) -> int:
	if count_only:
		return shot
	var cam: Camera3D = game.player.camera
	f.set_process(false)     # the test ticks the band itself: the player is where the test says
	for i: int in band.cats.size():
		if shot >= max_cats:
			break
		shot += 1
		var cat: Dictionary = band.cats[i]
		var body: CatBody = cat["body"]
		var far := Vector3(0, -1000, 0)
		await _run(band, far, 0.0, 0.5)
		await _snap(game, cam, body, "%s_%d_rest.png" % [stem, i])
		# Off on a stroll.
		cat["timer"] = 0.0
		cat["chain"] = false
		for k: int in 4:
			await _run(band, far, 0.0, 1.0 if k == 0 else 0.7)
			await _snap(game, cam, body, "%s_%d_walk%d.png" % [stem, i, k])
		# You, standing by it.
		var by: Vector3 = body.global_position - body.global_basis.z * 1.3 + body.global_basis.x * 0.9
		await _run(band, by, 0.0, 1.2)
		await _snap(game, cam, body, "%s_%d_look.png" % [stem, i], by + Vector3(0, 1.5, 0))
		# You, running at it.
		for k: int in 3:
			await _run(band, by, 6.0 if k == 0 else 0.0, 0.3 if k == 0 else 0.6)
			await _snap(game, cam, body, "%s_%d_run%d.png" % [stem, i, k])
	f.set_process(true)
	return shot


## Ticks the band for `seconds` with the player at `player`, moving at `speed`.
func _run(band: CatBand, player: Vector3, speed: float, seconds: float) -> void:
	var left: float = seconds
	while left > 0.0:
		await process_frame
		var dt: float = minf(1.0 / 60.0, left)
		band.visible = true
		band.process_mode = Node.PROCESS_MODE_INHERIT
		band.tick(dt, player, speed)
		left -= dt


func _snap(game: Node, cam: Camera3D, body: CatBody, path: String, eye: Variant = null) -> void:
	var at: Vector3 = body.global_position + Vector3(0, 0.18, 0)
	var from: Vector3 = eye as Vector3 if eye != null else _view(body, at)
	game.player.teleport(Vector3(from.x, at.y - 0.18, from.z))
	cam.global_position = from
	cam.look_at(at, Vector3.UP)
	cam.fov = 45.0
	await process_frame
	cam.global_position = from
	cam.look_at(at, Vector3.UP)
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(path)
	cam.position = Vector3(0, 1.62, 0)
	cam.fov = 75.0


## Somewhere 1.7 m off with a clear line to the cat, a little above it.
func _view(body: CatBody, at: Vector3) -> Vector3:
	var space: PhysicsDirectSpaceState3D = body.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.new()
	q.collision_mask = LaneGraph.WORLD
	for k: int in 16:
		# Three-quarter front first.
		var a: float = body.rotation.y + PI * 0.75 + k * TAU / 16.0
		var cand: Vector3 = at + Vector3(sin(a), 0, cos(a)) * -1.8 + Vector3(0, 0.75, 0)
		q.from = at
		q.to = cand
		var there: bool = space.intersect_ray(q).is_empty()
		q.from = cand
		q.to = at
		if there and space.intersect_ray(q).is_empty():
			return cand
	return at + Vector3(1.2, 0.8, 0)


## How many points the band's first cat can walk to.
func _reach(band: CatBand) -> int:
	var back: PackedInt32Array = band.graph.reach(int(band.cats[0]["node"]))
	var n: int = 0
	for b: int in back:
		if b >= 0:
			n += 1
	return n

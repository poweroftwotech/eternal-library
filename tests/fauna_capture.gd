extends SceneTree
## Pictures of the animals where they live (phase 19), in the real game, for
## the look. Needs a display, not --headless; run `godot --headless --import`
## first, and pass --audio-driver Dummy.
##   godot --path . --resolution 1600x900 --audio-driver Dummy --script res://tests/fauna_capture.gd -- <out dir> [place ...] [--seed=N] [--close] [--stats]
## place: camp, a scene path or area:<id> (every room is visited). For every
## group of animals Fauna puts in a room, stands the player at the water's edge
## nearest to it and looks at it from about 2.4 m (--close: 1.2 m), and writes
## <place>_<slot>_<group>.png; prints the place's animals, what ticking them
## cost and the frame's draw calls.

const DEFAULT: PackedStringArray = ["camp", "area:grand_study", "area:gardens", "area:mahaleh", "res://rooms/lake/landing.tscn"]


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var places: PackedStringArray = []
	var out_dir: String = ""
	var close: bool = false
	var stats: bool = false
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--seed="):
			Area.seed_override = a.trim_prefix("--seed=").to_int()
		elif a == "--stats":
			stats = true
		elif a == "--close":
			close = true
		elif out_dir == "":
			out_dir = a
		else:
			places.append(a)
	if out_dir == "":
		out_dir = "user://fauna_capture"
	if places.is_empty():
		places = DEFAULT
	DirAccess.make_dir_recursive_absolute(out_dir)
	var main_script: GDScript = load("res://scripts/main.gd")
	for place: String in places:
		main_script.room_override = place
		var game: Node = (load("res://main.tscn") as PackedScene).instantiate()
		root.add_child(game)
		game.hud.toast_time = 0
		game.hud.visible = false
		game.stats.visible = stats
		game.player.blocked = true
		for _i: int in 20:
			await process_frame
		var tag: String = place.get_file().get_basename().replace("area:", "")
		var world: Node3D = game.world
		if world is Area:
			var area: Area = world
			for r: AreaPlan.Room in area.plan.rooms:
				if r.room_type not in ["R03", "R04", "R06", "R07", "R09", "R11", "R21"]:
					continue
				var c: Vector3 = area.global_transform * r.xf * Vector3.ZERO
				if not r.floor_cells.is_empty():
					c = area.global_transform * CellGrid.cell_centre(r.floor_cells.keys()[0])
				game.player.teleport(c)
				await _settle(game, area.fauna)
				await _shoot(game, area.fauna, r.slot_id, "%s/%s_%s" % [out_dir, tag, r.slot_id], close)
		else:
			var f: Fauna = world.get_node_or_null("Fauna") as Fauna
			await _settle(game, f)
			await _shoot(game, f, "", "%s/%s" % [out_dir, tag], close)
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
	for _i: int in 30:
		await process_frame


func _shoot(game: Node, f: Fauna, slot: String, stem: String, close: bool) -> void:
	if f == null:
		print("  %s: no Fauna" % stem)
		return
	var gs: Array = f.groups.get(slot, [])
	print("  %s: %d groups, %s" % [stem.get_file(), gs.size(), f.stats])
	var cam: Camera3D = game.player.camera
	for gi: int in gs.size():
		var g: MultiMeshInstance3D = gs[gi]
		if not is_instance_valid(g):
			continue
		var at: Vector3 = _centre(g)
		var b: WaterBody = g.get("body")
		# Look down at them at about 45 degrees from a spot in open air.
		var back: float = 1.2 if close else 2.4
		var space: PhysicsDirectSpaceState3D = g.get_world_3d().direct_space_state
		var eye: Vector3 = Vector3(at.x, b.surface, at.z) + Vector3(0, back, 0.3)
		for k: int in 16:
			var d := Vector3(cos(k * TAU / 16.0), 0, sin(k * TAU / 16.0))
			var cand: Vector3 = Vector3(at.x, b.surface, at.z) + d * back * 0.8 + Vector3(0, back * 0.8, 0)
			var q := PhysicsRayQueryParameters3D.create(Vector3(at.x, b.surface + 0.05, at.z), cand, 1)
			q.hit_back_faces = true
			if space.intersect_ray(q).is_empty():
				eye = cand
				break
		if close:
			eye = Vector3(at.x, b.surface + 0.9, at.z + 0.35)     # nearly straight down over one fish
		game.player.teleport(eye - Vector3(0, 1.62, 0))
		game.player.camera.global_position = eye
		cam.look_at(at, Vector3.UP)
		cam.fov = 60.0
		for _i: int in 45:
			await process_frame
		await RenderingServer.frame_post_draw
		var path: String = "%s_%d_%s.png" % [stem, gi, g.get("def").id]
		root.get_viewport().get_texture().get_image().save_png(path)
		print("    %s: %d at %s, water %.2f, tick %.3f ms, draws %d -> %s" % [g.name, g.multimesh.instance_count, at.snapped(Vector3.ONE * 0.1), b.surface,
			f.stats["tick_ms"], Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), path])
		game.player.camera.position = Vector3(0, 1.62, 0)


func _centre(g: MultiMeshInstance3D) -> Vector3:
	if g is FishSchool:
		return g.global_position
	return g.global_transform * g.multimesh.get_instance_transform(0).origin     # one fish, not the middle of the pool (the fountain)

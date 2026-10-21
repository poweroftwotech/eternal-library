extends SceneTree
## GPU capture of the real game (main.tscn: player camera, HUD) walking the
## library wing, everything loaded at once (phase-4-design.md 8.1.8 step 1).
## Needs a display, not --headless; run `godot --headless --import` first.
##   godot --path . --resolution 1600x900 --script res://tests/area_capture.gd -- <out dir> [area seed] [frames]
## Writes area_<seed>_<view>.png for each view and prints, per view, the
## frame time over 120 frames with vsync off (mean, 99th percentile, worst),
## draw calls, objects and triangles in view:
##   plan      straight down from 5 m over the whole wing, orthographic, so
##             the vaults are above the camera and the floor plan shows
##   r01       where a visit starts, down R01's hall
##   east_door from R01's hall through the east door into its gallery
##   gallery   in the first grown gallery's entry bay, down its run
##   joint     in that gallery, looking back through the gallery-to-gallery door
##   baked     in the baked west gallery's entry bay, down its run
## Also writes area_<seed>_map.png (the plan's own map).

const TIMED_FRAMES: int = 120


func _initialize() -> void:
	call_deferred("capture")


func capture() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else "user://area"
	var area_seed: int = int(args[1]) if args.size() > 1 else 1
	var frames: int = int(args[2]) if args.size() > 2 else 100
	DirAccess.make_dir_recursive_absolute(out_dir)
	var main_script: GDScript = load("res://scripts/main.gd")
	main_script.room_override = "area:library"
	Area.seed_override = area_seed
	var t0: int = Time.get_ticks_usec()
	var game: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	var boot_ms: float = (Time.get_ticks_usec() - t0) / 1000.0
	await process_frame
	game.hud.toast_time = 0
	game.player.blocked = true     # hold each pose while lighting settles
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var area: Area = game.world
	var p: AreaPlan = area.plan
	print("area_capture: seed %d, %d rooms, boot (plan + build + wear) %.0f ms, %s" % [area_seed, p.rooms.size(), boot_ms, area.timings])
	p.draw_map().save_png("%s/area_%d_map.png" % [out_dir, area_seed])
	var views: Dictionary = poses(area)
	for view: String in views:
		var cam: Camera3D = game.player.camera
		if view == "plan":
			cam = plan_camera(area)
		else:
			game.player.teleport(views[view][0] - Vector3(0, 1.6, 0))
			game.look_toward(views[view][1])
		for i: int in frames:
			await process_frame
		var times: Array[float] = []
		var last: int = Time.get_ticks_usec()
		for i: int in TIMED_FRAMES:
			await process_frame
			var now: int = Time.get_ticks_usec()
			times.append((now - last) / 1000.0)
			last = now
		times.sort()
		var mean: float = times.reduce(func(a: float, b: float) -> float: return a + b, 0.0) / times.size()
		var vp: Viewport = root.get_viewport()
		var draws: int = vp.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)
		var objects: int = vp.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_OBJECTS_IN_FRAME)
		var tris: int = vp.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME)
		var path: String = "%s/area_%d_%s.png" % [out_dir, area_seed, view]
		var err: Error = vp.get_texture().get_image().save_png(path)
		print("  %s: frame %.2f ms mean, %.2f p99, %.2f worst; %d draw calls, %d objects, %d triangles; %s" % [view, mean,
			times[int(times.size() * 0.99) - 1], times[-1], draws, objects, tris, "saved " + path if err == OK else "FAILED " + error_string(err)])
		if view == "plan":
			cam.queue_free()
			game.player.camera.current = true
	main_script.room_override = ""
	quit()


## view -> [eye, look-at] in world space, found from the plan.
func poses(area: Area) -> Dictionary:
	var p: AreaPlan = area.plan
	var out: Dictionary = {"plan": []}
	var spawn: Transform3D = area.spawn_transform()
	out["r01"] = [spawn.origin + Vector3(0, 1.6, 0), spawn.origin + Vector3(0, 1.8, -20)]
	var east: Transform3D = p.room("reading_room").connectors[&"SNAP_door_east"]["xf"]
	out["east_door"] = [Vector3(5.0, 1.7, east.origin.z), east.origin - east.basis.z * 12.0 + Vector3(0, 0.6, 0)]
	for r: AreaPlan.Room in p.rooms:
		if r.slot_id.begins_with("gallery_") and r.kind == "generated":
			var g: GeneratedRoom = area.rooms[r.slot_id]
			var order: Array[Vector3i] = g.grid.run_order()
			out["gallery"] = [g.to_global(CellGrid.cell_centre(order[0]) + Vector3(0, 1.6, 1.2)),
				g.to_global(CellGrid.cell_centre(order[mini(4, order.size() - 1)]) + Vector3(0, 2.0, 0))]
			var entry: Transform3D = r.connectors[r.entry]["xf"]
			out["joint"] = [g.to_global(CellGrid.cell_centre(order[mini(1, order.size() - 1)]) + Vector3(0, 1.6, 0)),
				entry.origin - entry.basis.z * 8.0 + Vector3(0, 1.8, 0)]
			break
	var baked: Transform3D = p.room("stack_gallery_west").connectors[&"SNAP_entry"]["xf"]
	out["baked"] = [baked.origin + baked.basis.z * 1.0 + Vector3(0, 1.6, 0), baked.origin + baked.basis.z * 16.0 + Vector3(0, 2.0, 0)]
	return out


## An orthographic camera 5 m over the floor looking straight down, framing
## the whole wing: the vaults are behind its near plane, so the plan shows.
func plan_camera(area: Area) -> Camera3D:
	var b: AABB = area.plan.bounds()
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	var aspect: float = float(root.size.x) / root.size.y
	cam.size = maxf(b.size.z, b.size.x / aspect) + 4.0
	cam.near = 0.05
	cam.far = 20.0
	area.add_child(cam)
	cam.global_transform = Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(b.get_center().x, 5.0, b.get_center().z))
	cam.current = true
	return cam

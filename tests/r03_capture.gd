extends SceneTree
## GPU pictures of the R03 Hypostyle Stacks in the real game (phase-5-design.md
## 5.6.9). Needs a display, not --headless; run `godot --headless --import` first.
##   godot --path . --resolution 1920x1080 --script res://tests/r03_capture.gd -- <out dir> [area seed] [--preset=medium]
## Writes r03_<seed>_<view>.png and prints, per view, the draw calls (in view,
## and in all passes as the frame gate counts them against its 1,500 budget,
## architecture 8.2), objects and triangles drawn:
##   entry      from the entry bay, eye height, toward the landmark
##   diagonal   from a far corner bay across the hall to the landmark
##   aisle      low, along a row of bookcases
##   domes      looking up at the domes and arches
##   landmark   close on the landmark under its oculus
##   collapse   a collapsed bay: the rubble heap and the shaft its dome left (step 2)
##   cluster    a cluster of lanterns hanging from a dome (step 2)

func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var args: PackedStringArray = []
	for a: String in OS.get_cmdline_user_args():
		if not a.begins_with("--"):
			args.append(a)
	var out_dir: String = args[0] if args.size() > 0 else "user://r03"
	var area_seed: int = int(args[1]) if args.size() > 1 else 1
	DirAccess.make_dir_recursive_absolute(out_dir)
	var main_script: GDScript = load("res://scripts/main.gd")
	main_script.room_override = "area:lower_stacks"
	Area.seed_override = area_seed
	var game: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	game.hud.toast_time = 0
	game.hud.visible = false
	game.stats.visible = false
	game.player.blocked = true
	game.player.set_physics_process(false)
	var area: Area = game.world
	var hall: GeneratedRoom = area.rooms["hall"]
	var g: CellGrid = hall.grid
	var xs: Array = []
	var zs: Array = []
	var centre := Vector3i.ZERO
	for c: Vector3i in g.cells:
		xs.append(c.x)
		zs.append(c.z)
		if g.cells[c].get("ceiling_slot", "") == "cell:oculus":
			centre = c
	var far := Vector3i(xs.max() if absi(xs.max()) >= absi(xs.min()) else xs.min(), 0, zs.max())
	var case_cell: Vector3i = centre
	var case_axis := Vector3.RIGHT
	for k: String in g.props:
		if g.props[k]["slot"] == "dressing:case":
			var xf: Transform3D = g.props[k]["xf"]
			var at: Vector3i = AreaPlan.cell_of(xf * Vector3(2.0, 0.1, -2.0))
			case_cell = Vector3i(at.x, 0, at.z)
			case_axis = xf.basis.x.abs().round()
			break
	var side := Vector3(case_axis.z, 0, case_axis.x)
	var c0: Vector3 = CellGrid.cell_centre(centre)
	var views: Dictionary = {
		"entry": [CellGrid.cell_centre(Vector3i.ZERO) + Vector3(0, 1.7, 1.0), c0 + Vector3(0, 2.4, 0)],
		"diagonal": [CellGrid.cell_centre(far) + Vector3(0, 1.7, 0), c0 + Vector3(0, 2.0, 0)],
		"aisle": [CellGrid.cell_centre(case_cell) - case_axis * 3.8 + side * 1.0 + Vector3(0, 1.4, 0), CellGrid.cell_centre(case_cell) + case_axis * 6.0 + side * 1.0 + Vector3(0, 1.3, 0)],
		"domes": [CellGrid.cell_centre(Vector3i.ZERO) + Vector3(0, 1.6, -0.5), CellGrid.cell_centre(Vector3i(0, 0, 2)) + Vector3(0, 7.5, 0)],
		"landmark": [c0 + Vector3(4.5, 1.8, 4.5) * Vector3(1, 1, -1) * 0.8, c0 + Vector3(0, 2.0, 0)],
	}
	# Step 2: a collapsed bay (its heap and the shaft its dome left) and a lamp
	# cluster, each seen from a clear neighbouring bay, when the hall has one.
	for k: String in g.props:
		var slot: String = g.props[k]["slot"]
		if (slot != "dressing:rubble_heap" or views.has("collapse")) and (slot != "lamp:cluster" or views.has("cluster")):
			continue
		var at: Vector3 = (g.props[k]["xf"] as Transform3D) * (Vector3(2.0, 0.0, -2.0) if slot == "dressing:rubble_heap" else Vector3.ZERO)
		var cell := Vector3i(AreaPlan.cell_of(at + Vector3(0, 0.1, 0)).x, 0, AreaPlan.cell_of(at + Vector3(0, 0.1, 0)).z)
		for dir: int in CellGrid.ALL_SIDES:
			var n: Vector3i = CellGrid.neighbour(cell, dir)
			if g.cells.has(n) and not g.cells[n].get("blocked", false):
				var from: Vector3 = CellGrid.cell_centre(n) + (CellGrid.cell_centre(n) - CellGrid.cell_centre(cell)) * 0.25
				views["collapse" if slot == "dressing:rubble_heap" else "cluster"] = [from + Vector3(0, 1.6, 0), at + Vector3(0, 3.2 if slot == "dressing:rubble_heap" else 3.0, 0)]
				break
	var vp_rid: RID = root.get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp_rid, true)
	print("r03_capture: seed %d, hall %d x %d bays, %d modules, landmark %s" % [area_seed, xs.max() - xs.min() + 1, zs.max() - zs.min() + 1, hall.modules.size(), _landmark(hall)])
	for view: String in views:
		var v: Array = views[view]
		var eye: Vector3 = hall.to_global(v[0])
		game.player.global_position = eye - Vector3(0, game.player.camera.position.y, 0)
		game.look_toward(hall.to_global(v[1]))
		for _i: int in 90:
			await process_frame
		await RenderingServer.frame_post_draw
		var draws: int = RenderingServer.viewport_get_render_info(vp_rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)
		var total: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))     # all passes, as the frame gate counts
		var objects: int = RenderingServer.viewport_get_render_info(vp_rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_OBJECTS_IN_FRAME)
		var tris: int = RenderingServer.viewport_get_render_info(vp_rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)
		var path: String = "%s/r03_%d_%s.png" % [out_dir, area_seed, view]
		root.get_viewport().get_texture().get_image().save_png(path)
		print("  %s: draw calls %d in view, %d in all passes; objects %d, triangles %d k, gpu %.2f ms -> %s" % [view, draws, total, objects, tris / 1000,
			RenderingServer.viewport_get_measured_render_time_gpu(vp_rid), path])
	main_script.room_override = ""
	Area.seed_override = -1
	quit()


func _landmark(hall: Node) -> String:
	for s: VariantSocket in (hall as RoomTemplate).sockets():
		if s.socket_set != null and s.socket_set.resource_path.ends_with("hall_landmark.tres"):
			return s.picked_label()
	return "none"

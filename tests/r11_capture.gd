extends SceneTree
## GPU pictures of the R11 Cistern Archive in the real game (phase-5-design.md
## 5.6.9). Needs a display, not --headless; run `godot --headless --import` first.
##   godot --path . --resolution 1920x1080 --script res://tests/r11_capture.gd -- <out dir> [area seed] [--preset=medium]
## Walks into the Lower Stacks' cistern (the rooms stream in on the way) and
## writes r11_<seed>_<view>.png, printing the draw calls, objects and
## triangles of each view:
##   entry      from the entry bay down the causeway to the sealed door
##   door       close on the sealed bronze door and its lanterns
##   across     from the causeway across the water and the piers
##   wading     standing in a shallow bay, eye level over the water
##   platform   a platform of book crates from the nearest walkable bay

func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var args: PackedStringArray = []
	for a: String in OS.get_cmdline_user_args():
		if not a.begins_with("--"):
			args.append(a)
	var out_dir: String = args[0] if args.size() > 0 else "user://r11"
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
	var plan: AreaPlan.Room = null
	for r: AreaPlan.Room in area.plan.rooms:
		if r.slot_id.begins_with("cistern"):
			plan = r
	if plan == null:
		print("r11_capture: seed %d has no cistern" % area_seed)
		quit(1)
		return
	# Walk there a room at a time, so the streamer builds the way.
	for p: Vector3 in AreaTour.leg(area.plan, plan):
		game.player.global_position = area.to_global(p) + Vector3(0, 0.05, 0)
		for _i: int in 6:
			await process_frame
		while area.streamer.busy():
			await process_frame
	var room: GeneratedRoom = area.rooms.get(plan.slot_id)
	var g: CellGrid = plan.grid
	var zs: Array = []
	var shallow: Vector3i = Vector3i.MAX
	var deck: Vector3i = Vector3i.MAX
	for c: Vector3i in g.cells:
		zs.append(c.z)
		if g.cells[c]["floor_slot"] == "cell:basin" and not g.cells[c].get("blocked", false) and (shallow == Vector3i.MAX or c.z > shallow.z):
			shallow = c
	for k: String in g.props:
		if g.props[k]["slot"] == "dressing:case" and deck == Vector3i.MAX:
			var at: Vector3i = AreaPlan.cell_of((g.props[k]["xf"] as Transform3D) * Vector3(2.0, 0.1, -2.0))
			deck = Vector3i(at.x, 0, at.z)
	var far := Vector3i(0, 0, zs.max())
	var side_x: float = 1.0 if g.cells.has(Vector3i(1, 0, 1)) else -1.0
	var views: Dictionary = {
		"entry": [CellGrid.cell_centre(Vector3i.ZERO) + Vector3(0, 1.62, 1.2), CellGrid.cell_centre(far) + Vector3(0, 1.6, -2.0)],
		"door": [CellGrid.cell_centre(far) + Vector3(0, 1.62, 3.0), CellGrid.cell_centre(far) + Vector3(0, 1.3, -2.0)],
		"across": [CellGrid.cell_centre(Vector3i(0, 0, mini(1, far.z))) + Vector3(-side_x * 0.8, 1.62, 0), CellGrid.cell_centre(Vector3i(int(side_x) * 3, 0, mini(2, far.z))) + Vector3(0, 0.6, 0)],
	}
	if shallow != Vector3i.MAX:
		views["wading"] = [CellGrid.cell_centre(shallow) + Vector3(0, -0.9 + 1.62, 0), CellGrid.cell_centre(Vector3i(0, 0, shallow.z)) + Vector3(0, 0.4, 0)]
	if deck != Vector3i.MAX:
		views["platform"] = [CellGrid.cell_centre(Vector3i(0, 0, deck.z)) + Vector3(0, 1.62, 1.5), CellGrid.cell_centre(deck) + Vector3(0, 0.6, 0)]
	var vp_rid: RID = root.get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp_rid, true)
	var kinds: Dictionary = {}
	for c: Vector3i in g.cells:
		kinds[g.cells[c]["floor_slot"]] = int(kinds.get(g.cells[c]["floor_slot"], 0)) + 1
	print("r11_capture: seed %d, %s off %s, %d bays %s, %d modules" % [area_seed, plan.slot_id, plan.parent, g.cells.size(), kinds, room.modules.size()])
	for view: String in views:
		var v: Array = views[view]
		game.player.global_position = room.to_global(v[0]) - Vector3(0, game.player.camera.position.y, 0)
		game.look_toward(room.to_global(v[1]))
		for _i: int in 90:
			await process_frame
		await RenderingServer.frame_post_draw
		var total: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		var objects: int = RenderingServer.viewport_get_render_info(vp_rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_OBJECTS_IN_FRAME)
		var tris: int = RenderingServer.viewport_get_render_info(vp_rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)
		var path: String = "%s/r11_%d_%s.png" % [out_dir, area_seed, view]
		root.get_viewport().get_texture().get_image().save_png(path)
		print("  %s: draw calls %d in all passes; objects %d, triangles %d k, gpu %.2f ms -> %s" % [view, total, objects, tris / 1000,
			RenderingServer.viewport_get_measured_render_time_gpu(vp_rid), path])
	main_script.room_override = ""
	Area.seed_override = -1
	quit()

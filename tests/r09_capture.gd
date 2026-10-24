extends SceneTree
## GPU pictures of the R09 Light-Well Stair in the real game (phase-5-design.md
## 5.6.6). Needs a display, not --headless; run `godot --headless --import` first.
##   godot --path . --resolution 1920x1080 --script res://tests/r09_capture.gd -- <out dir> [area seed] [--preset=medium]
## Walks into the Lower Stacks' light-well (the cone, rev 2; rooms stream in
## on the way) and writes r09_<seed>_<view>.png, printing the draw calls,
## objects and triangles of each view:
##   up       from the floor by the wall, up the shaft to the oculus
##   across   from storey 1's landing across the shaft
##   lower    from the floor across the shaft to the first flight
##   stair    on the first flight, looking up the climb
##   niche    at a niche on the first flight (books, a tile panel or a sealed door)
##   down     from the top landing down the shaft to the pool
##   exit     from the top doorway's passage into the shaft

func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var args: PackedStringArray = []
	for a: String in OS.get_cmdline_user_args():
		if not a.begins_with("--"):
			args.append(a)
	var out_dir: String = args[0] if args.size() > 0 else "user://r09"
	var area_seed: int = int(args[1]) if args.size() > 1 else 6
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
	var plan: AreaPlan.Room = area.plan.room("lightwell_1")
	if plan == null:
		print("r09_capture: seed %d has no light-well" % area_seed)
		quit(1)
		return
	for p: Vector3 in AreaTour.leg(area.plan, plan):
		game.player.global_position = area.to_global(p) + Vector3(0, 0.05, 0)
		for _i: int in 6:
			await process_frame
		while area.streamer.busy():
			await process_frame
	var room: GeneratedRoom = area.rooms.get(plan.slot_id)
	var m: Dictionary = plan.grid.meta
	var c: Vector3 = m["centre"]
	var r0: float = float(m["radius"])
	var levels: int = m["levels"]
	var top: int = levels - 1
	# A point on storey j at angle t from its landing, radius rad, height z over its floor.
	var at := func(j: int, t: float, rad: float, z: float) -> Vector3:
		var a: float = RingGrammar.TURN * j + t
		return c + Vector3(sin(a) * rad, j * RingGrammar.STOREY + z, cos(a) * rad)
	var walk := func(j: int, t: float) -> float:
		return RingGrammar.face(r0 - 1.5 * j, RingGrammar.tread(r0 - 1.5 * j, t)) + RingGrammar.WALK
	var t1: float = RingGrammar.climb(r0).x + 1.0
	var z1: float = RingGrammar.tread(r0, t1)
	var tn: float = RingGrammar.step_middle(r0, RingGrammar.climb(r0).x + (RingGrammar.climb(r0).y - RingGrammar.climb(r0).x) * 1.5 / RingGrammar.bays(r0))
	var zn: float = RingGrammar.tread(r0, tn)
	var top_door: Array = m["doors"][1] if (m["doors"] as Array).size() > 1 else m["doors"][0]
	var door_t: float = TAU * RingGrammar.SIDE_TURN[top_door[1]] - RingGrammar.TURN * int(top_door[0])
	var edge: float = int(m["across"]) / 2 * CellGrid.BAY + CellGrid.BAY * 0.5
	var views: Dictionary = {
		"up": [at.call(0, PI, r0 - 3.0, 1.6), c + Vector3(0, top * RingGrammar.STOREY + 8.0, 0)],
		"lower": [at.call(0, PI * 0.5, r0 - 5.0, 1.6), at.call(0, PI * 1.5, r0, 1.8)],
		"across": [at.call(1, 0.0, walk.call(1, 0.0) - 0.3, 1.6), at.call(1, PI, r0 - 4.0, 0.5)],
		"stair": [at.call(0, t1, walk.call(0, t1) - 0.1, z1 + 1.6), at.call(0, t1 + 0.6, walk.call(0, t1 + 0.6) + 0.1, RingGrammar.tread(r0, t1 + 0.6) + 1.5)],
		"niche": [at.call(0, tn - 0.12, walk.call(0, tn) - 0.3, zn + 1.5), at.call(0, tn, walk.call(0, tn) + 1.0, zn + 1.0)],
		"down": [at.call(top, 0.0, RingGrammar.face(r0 - 1.5 * top, 0.0) - 0.7, 2.1), c + Vector3(0, 0, 0)],
		"exit": [at.call(int(top_door[0]), door_t, edge - 1.5, 1.6), at.call(int(top_door[0]), door_t, 0.0, 0.0)],
	}
	var vp_rid: RID = root.get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp_rid, true)
	print("r09_capture: seed %d, light-well r%d, %d levels, doors %s, %d modules" % [area_seed, int(r0), levels, m["doors"], room.modules.size()])
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
		var path: String = "%s/r09_%d_%s.png" % [out_dir, area_seed, view]
		root.get_viewport().get_texture().get_image().save_png(path)
		print("  %s: draw calls %d in all passes; objects %d, triangles %d k, gpu %.2f ms -> %s" % [view, total, objects, tris / 1000,
			RenderingServer.viewport_get_measured_render_time_gpu(vp_rid), path])
	main_script.room_override = ""
	Area.seed_override = -1
	quit()

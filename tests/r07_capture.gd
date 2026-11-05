extends SceneTree
## GPU pictures of the R07 Garden Court (phase 13) in the real game, on the
## Lower Stacks' test copy (gen/recipes/drafts/lower_stacks/garden_test.tres,
## tools/make_r07_draft.gd). Needs a display, not --headless; run
## `godot --headless --import` first.
##   godot --path . --resolution 1920x1080 --script res://tests/r07_capture.gd -- <out dir> [area seed] [--preset=medium]
## Walks to the garden (rooms stream in on the way) and writes r07_<seed>_<view>.png:
##   entry    in the entry corridor, looking up the main axis to the iwan
##   arrive   just inside the court, the same view
##   pool     beside the pool, looking down at it
##   iwan     in front of the iwan, looking into its hood
##   back     from the iwan's hood back down the garden to the entry
##   talar    in the west talar, down its colonnade
##   arcade   at the back of a west bay, looking out across the court
##   shade    under the south arcade, looking out into the sunlit court
##   across   from the east arcade, across the court
##   up       from the court, up the shaft to the sky
##   rise     from a corner of the court, slanting up the funnel to the hole
##   wide     from high over a quarter, the whole court
##   out      in the exit corridor behind the iwan

const DRAFT: String = "res://gen/recipes/drafts/%s/garden_test.tres"


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var args: PackedStringArray = []
	var area_name: String = "lower_stacks"
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--area="):
			area_name = a.trim_prefix("--area=")
		elif not a.begins_with("--"):
			args.append(a)
	var out_dir: String = args[0] if args.size() > 0 else "user://r07"
	var area_seed: int = int(args[1]) if args.size() > 1 else 1
	DirAccess.make_dir_recursive_absolute(out_dir)
	var ws: Node = root.get_node_or_null("/root/WorldState")
	ws.set("walk_area", area_name)
	ws.set("walk_recipe", DRAFT % area_name)
	var main_script: GDScript = load("res://scripts/main.gd")
	main_script.room_override = "area:" + area_name
	Area.seed_override = area_seed
	var game: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	game.hud.toast_time = 0
	game.hud.visible = false
	game.stats.visible = false
	game.player.blocked = true
	game.player.set_physics_process(false)
	var area: Area = game.world
	var plan: AreaPlan.Room = area.plan.room("garden_1")
	if plan == null:
		print("r07_capture: seed %d has no garden court" % area_seed)
		quit(1)
		return
	for p: Vector3 in AreaTour.leg(area.plan, plan):
		game.player.global_position = area.to_global(p) + Vector3(0, 0.05, 0)
		for _i: int in 6:
			await process_frame
		while area.streamer.busy():
			await process_frame
	var room: GeneratedRoom = area.rooms.get(plan.slot_id)
	var eye := Vector3(0, 1.6, 0)
	var views: Dictionary = {
		"entry": [Vector3(2, 0, -1.2) + eye, Vector3(2, 4.0, -34)],
		"arrive": [Vector3(2, 0, -13.5) + eye, Vector3(2, 5.0, -34)],
		"pool": [Vector3(6.8, 0, -17.0) + eye, Vector3(2, 0.6, -22)],
		"iwan": [Vector3(2, 0, -26.5) + eye, Vector3(2, 4.5, -35)],
		"back": [Vector3(2, 0, -32.8) + eye, Vector3(2, 2.5, 0)],
		"talar": [Vector3(-9.6, 0, -13.0) + eye, Vector3(-9.6, 3.0, -34)],
		"arcade": [Vector3(-10.8, 0, -18.0) + eye, Vector3(4, 2.0, -19)],
		"shade": [Vector3(-6, 0, -10.2) + eye, Vector3(0, 1.2, -23)],
		"across": [Vector3(13, 0, -22) + eye, Vector3(-10, 3.0, -22)],
		"up": [Vector3(2, 0, -17.5) + eye, Vector3(2, 34.0, -21)],
		"rise": [Vector3(-6, 0, -13.0) + eye, Vector3(5, 26.0, -24)],
		"pishtaq_side": [Vector3(-7, 0, -24) + eye, Vector3(-3.6, 12.0, -32.4)],     # walk 3: the gap beside the pishtaq's top
		"door": [Vector3(-1.5, 0, -14.5) + eye, Vector3(2.0, 4.0, -9.5)],      # walk 5: the entry door wall (z-fighting)
		"niches": [Vector3(-5.0, 0, -22) + eye, Vector3(-11.0, 4.5, -22)],   # walk 5: the side talar's niches
		"corner": [Vector3(-5.5, 0, -10.6) + eye, Vector3(-11.6, 1.2, -9.0)],       # walk 3: a talar corner in shade
		"wide": [Vector3(10, 10.0, -13.5), Vector3(-1, 0.0, -27)],
		"out": [Vector3(2, 0, -37.0) + eye, Vector3(2, 1.8, -44)],
		"fountain": [Vector3(5.2, 0, -19.6) + eye, Vector3(2, 0.9, -22)],
		"dapple": [Vector3(4, 7.0, -13), Vector3(-3.0, 0.0, -21.5)],      # the figs' leaf shade on the west beds
		"dapple_east": [Vector3(0, 7.0, -15), Vector3(7.5, 0.0, -24.0)],
	}
	# Step 2's life, wherever the seed put it: from the court toward each.
	var keys: Array[String] = ["takht", "sit_rug", "traces", "bench_1"]
	for pat: String in ["prop_shelves_*", "prop_vines_*"]:
		var found: Array[Node] = room.find_children(pat, "", true, false)
		if not found.is_empty():
			keys.append(String(found[0].name).trim_prefix("prop_"))
	for key: String in keys:
		var n: Node3D = room.find_child("prop_" + key, true, false) as Node3D
		if n == null:
			continue
		var at: Vector3 = room.to_local(n.global_position)
		var toward: Vector3 = Vector3(2, 0, -22) - at
		toward.y = 0.0
		var back: float = 2.6 if key in ["traces", "bench_1"] else 4.0
		views[key] = [at + toward.normalized() * back + eye, at + Vector3(0, 0.5, 0)]
	# After walk 5: the great tree, from the court and from under its crown.
	var tree: Node3D = room.find_child("prop_great_tree", true, false) as Node3D
	if tree != null:
		var at: Vector3 = room.to_local(tree.global_position)
		var toward: Vector3 = Vector3(2, 0, -18) - at
		toward.y = 0.0
		views["great_tree"] = [at + toward.normalized() * 9.0 + eye, at + Vector3(0, 3.2, 0)]
		views["under_tree"] = [at + toward.normalized() * 2.2 + eye, at + Vector3(0, 5.5, 0) - toward.normalized() * 1.5]
	var vp_rid: RID = root.get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp_rid, true)
	print("r07_capture: %s seed %d, garden court, %d modules" % [area_name, area_seed, room.modules.size()])
	# The room's lights (the brief: daylight only, no flames).
	for l: Node in room.find_children("*", "Light3D", true, false):
		var li := l as Light3D
		if li.visible and li.light_energy > 0.0:
			var owner_name: String = String(li.get_parent().get_parent().name) if li.get_parent().get_parent() != null else "?"
			print("  light %s in %s at %s colour %s energy %.2f shadow %s" % [li.name, owner_name, room.to_local(li.global_position).snapped(Vector3.ONE * 0.1),
				li.light_color.to_html(false), li.light_energy, li.shadow_enabled])
	for view: String in views:
		var v: Array = views[view]
		game.player.global_position = room.to_global(v[0]) - Vector3(0, game.player.camera.position.y, 0)
		game.look_toward(room.to_global(v[1]))
		for _i: int in 90:
			await process_frame
		await RenderingServer.frame_post_draw
		var total: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		var tris: int = RenderingServer.viewport_get_render_info(vp_rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)
		var path: String = "%s/r07_%d_%s.png" % [out_dir, area_seed, view]
		root.get_viewport().get_texture().get_image().save_png(path)
		print("  %s: draw calls %d; triangles %d k; gpu %.2f ms -> %s" % [view, total, tris / 1000,
			RenderingServer.viewport_get_measured_render_time_gpu(vp_rid), path])
	main_script.room_override = ""
	Area.seed_override = -1
	quit()

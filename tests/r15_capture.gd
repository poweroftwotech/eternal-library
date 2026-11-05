extends SceneTree
## GPU pictures of the R15 Fungus Terraces (phase 13 step 3) in the real game,
## on the Lower Stacks' test copy (gen/recipes/drafts/lower_stacks/terraces_test.tres,
## tools/make_r15_draft.gd). Needs a display, not --headless; run
## `godot --headless --import` first.
##   godot --audio-driver Dummy --path . --resolution 1920x1080 --script res://tests/r15_capture.gd -- <out dir> [area seed] [--area=<id>] [--live]
## Walks to the terraces (rooms stream in on the way) and writes r15_<seed>_<view>.png:
##   foot     at the entry door, up the slope to the top
##   landing  on the foot landing by the cascade's basin, up the stair
##   stair    halfway up the stair, on up it
##   cascade  beside the channel, up the falls
##   beds     at the front of a west bed, along its caps
##   across   from the west side of a middle terrace, across the room
##   back     at the back of a middle terrace, down the room
##   top      on the top landing, down the whole slope
##   far      on the top landing, at the far door and the spring
##   roof     from a middle terrace, up into the vault
##   wide     from high over the east beds, the whole room
##   passage  in the entry passage, in toward the foot
##   exit     on the top landing, into the far passage
##   shelter  from the foot's middle, at the shelter by the entry wall
##   worker_stoop, worker_kneel, worker_carry, patch_wild, patch_blight, bed_tools:
##            a few metres off the first of each this seed placed
##   slope    from the first terrace's west end, up the west beds

const DRAFT: String = "res://gen/recipes/drafts/%s/terraces_test.tres"


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
	var out_dir: String = args[0] if args.size() > 0 else "user://r15"
	var area_seed: int = int(args[1]) if args.size() > 1 else 1
	DirAccess.make_dir_recursive_absolute(out_dir)
	var ws: Node = root.get_node_or_null("/root/WorldState")
	ws.set("walk_area", area_name)
	# --live: the area's live recipe (step 5), not the test copy.
	if not OS.get_cmdline_user_args().has("--live"):
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
	var plan: AreaPlan.Room = area.plan.room("terraces_1")
	if plan == null:
		print("r15_capture: seed %d has no fungus terraces" % area_seed)
		quit(1)
		return
	for p: Vector3 in AreaTour.leg(area.plan, plan):
		game.player.global_position = area.to_global(p) + Vector3(0, 0.05, 0)
		for _i: int in 6:
			await process_frame
		while area.streamer.busy():
			await process_frame
	var room: GeneratedRoom = area.rooms.get(plan.slot_id)
	var meta: Dictionary = room.grid.meta
	var rows: int = meta["rows"]
	var rise: float = meta["rise"]
	var pass_cells: int = int(meta.get("pass", 0))
	var k: int = rows / 2                      # a middle terrace
	var top_y: float = (rows - 1) * rise
	var eye := Vector3(0, 1.6, 0)
	# A point on row z's floor: x across the room (-8..12, the stair about 2.7),
	# d into the row from its front edge (0..4).
	var at := func(z: int, x: float, d: float, up: float = 0.0) -> Vector3:
		return Vector3(x, z * rise + up, -4.0 * (z + pass_cells) - d)
	var views: Dictionary = {
		"foot": [at.call(0, 2.0, 0.8) + eye, at.call(rows - 1, 2.0, 2.0, 2.0)],
		"landing": [at.call(0, -2.5, 2.5) + eye, at.call(3, 2.7, 2.0, 1.0)],
		"stair": [at.call(k, 2.0, 3.2) + eye, at.call(k + 3, 2.0, 2.0, 1.2)],
		"cascade": [at.call(k, -1.6, 1.2) + eye, at.call(k + 2, -0.7, 1.0, 0.4)],
		"beds": [at.call(k, -2.0, 3.4) + eye, at.call(k, -7.0, 0.6, 0.2)],
		"across": [at.call(k, -6.5, 3.4) + eye, at.call(k + 1, 11.0, 2.0, 0.5)],
		"back": [at.call(k, -4.0, 3.6) + eye, at.call(0, 6.0, 0.5, -1.0)],
		"top": [at.call(rows - 1, 2.0, 1.0) + eye, at.call(0, 2.0, 0.0)],
		"far": [at.call(rows - 1, -3.0, 0.6) + eye, at.call(rows - 1, 1.5, 4.0, 2.0)],
		"roof": [at.call(k, 6.0, 2.0) + eye, at.call(k + 1, 2.0, 2.0, 9.0)],
		"wide": [at.call(1, 10.5, 0.5, 6.5), at.call(k + 1, -2.0, 2.0)],
		"passage": [at.call(0, 2.0, -6.0) + eye, at.call(3, 2.0, 2.0, 1.0)],
		"exit": [at.call(rows - 1, 2.0, 1.0) + eye, at.call(rows - 1, 2.0, 12.0, 1.4)],
		"shelter": [at.call(0, 2.0, 3.4) + eye, at.call(0, 8.5, 1.0, 0.8)],
		"slope": [at.call(1, 0.8, 3.6) + eye, at.call(rows - 1, -6.0, 2.0, 0.5)],
	}
	# Step 4's things, wherever this seed put them: a view a few metres off the
	# first of each, from the stair side and up a little.
	var prop_view := func(slot: String, back: Vector3) -> Array:
		for key: String in room.grid.props:
			var pr: Dictionary = room.grid.props[key]
			if str(pr.get("slot", "")) == slot:
				var o: Vector3 = (pr["xf"] as Transform3D).origin
				# From the room's middle side of it (x 2 is the stair).
				var s: float = signf(2.0 - o.x)
				return [o + Vector3(s * absf(back.x), back.y, back.z), o + Vector3(1.6, 0.4, -1.4)]
		return []
	for pair: Array in [["worker_stoop", Vector3(1.5, 2.0, 2.6)], ["worker_kneel", Vector3(1.5, 2.0, 2.6)], ["worker_carry", Vector3(-1.5, 2.0, 2.6)],
			["patch_wild", Vector3(3.5, 2.6, 1.5)], ["patch_blight", Vector3(3.5, 2.6, 1.5)], ["bed_tools", Vector3(2.0, 1.8, 2.5)]]:
		var pv: Array = prop_view.call("ft:" + pair[0], pair[1])
		if not pv.is_empty():
			views[pair[0]] = pv
	var vp_rid: RID = root.get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp_rid, true)
	print("r15_capture: %s seed %d, fungus terraces, %d storeys, %d rows, %d modules" % [area_name, area_seed, meta["storeys"], rows, room.modules.size()])
	var lights: int = 0
	for l: Node in room.find_children("*", "Light3D", true, false):
		var li := l as Light3D
		if li.visible and li.light_energy > 0.0:
			lights += 1
	print("  lights in the room: %d" % lights)
	for view: String in views:
		var v: Array = views[view]
		game.player.global_position = room.to_global(v[0]) - Vector3(0, game.player.camera.position.y, 0)
		game.look_toward(room.to_global(v[1]))
		for _i: int in 90:
			await process_frame
		await RenderingServer.frame_post_draw
		var total: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		var tris: int = RenderingServer.viewport_get_render_info(vp_rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)
		var path: String = "%s/r15_%d_%s.png" % [out_dir, area_seed, view]
		root.get_viewport().get_texture().get_image().save_png(path)
		print("  %s: draw calls %d; triangles %d k; gpu %.2f ms -> %s" % [view, total, tris / 1000,
			RenderingServer.viewport_get_measured_render_time_gpu(vp_rid), path])
	main_script.room_override = ""
	Area.seed_override = -1
	quit()

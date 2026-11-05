extends SceneTree
## GPU pictures of the R21 Bridge Hall (phase 12) in the real game, on the
## Lower Stacks' test copy (gen/recipes/drafts/lower_stacks/bridge_hall_test.tres,
## tools/make_r21_draft.gd). Needs a display, not --headless; run
## `godot --headless --import` first.
##   godot --path . --resolution 1920x1080 --script res://tests/r21_capture.gd -- <out dir> [area seed] [--preset=medium]
## Walks to the hall (rooms stream in on the way) and writes r21_<seed>_<view>.png:
##   passage  in the entry passage, at the bend, looking on toward the hall
##   mouth    in the passage's last cell, looking out into the hall
##   start    at the bridge's start, looking across to the far door
##   across   halfway over, looking at a long wall's facades
##   down     halfway over, looking down over the balustrade into the drop
##   up       halfway over, looking up at the roof
##   back     at the far end, looking back along the bridge
##   wide     from high in a corner of the hall, the whole of it

const DRAFT: String = "res://gen/recipes/drafts/lower_stacks/bridge_hall_test.tres"


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var args: PackedStringArray = []
	for a: String in OS.get_cmdline_user_args():
		if not a.begins_with("--"):
			args.append(a)
	var out_dir: String = args[0] if args.size() > 0 else "user://r21"
	var area_seed: int = int(args[1]) if args.size() > 1 else 1
	DirAccess.make_dir_recursive_absolute(out_dir)
	var ws: Node = root.get_node_or_null("/root/WorldState")
	ws.set("walk_area", "lower_stacks")
	ws.set("walk_recipe", DRAFT)
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
	var plan: AreaPlan.Room = area.plan.room("bridge_1")
	if plan == null:
		print("r21_capture: seed %d has no bridge hall" % area_seed)
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
	var n: int = m["bays"]
	var bx: float = int(m["bridge_x"]) * CellGrid.BAY + CellGrid.BAY * 0.5
	var z0: float = -2 * CellGrid.BAY                 # the hall's entry end
	var z1: float = z0 - n * CellGrid.BAY             # its far end
	var mid: float = (z0 + z1) * 0.5
	var hall: AABB = m["hall"]
	var entry: Array = m["entry_cells"]
	var eye := Vector3(0, 1.6, 0)
	var c_bend: Vector3 = CellGrid.cell_centre(entry[1])
	var c_last: Vector3 = CellGrid.cell_centre(entry[2])
	var wall_x: float = hall.position.x if bx - hall.position.x > hall.end.x - bx else hall.end.x
	var rise: int = int((m["bridge"] as Dictionary).get("rise", 0))
	var far_y: float = rise * CellGrid.BAY            # the far end's deck
	var ob: Dictionary = m.get("old_bridge", {})
	var ox: float = (ob["start"] as Transform3D).origin.x if not ob.is_empty() else bx
	var oy: float = (ob["start"] as Transform3D).origin.y if not ob.is_empty() else 0.0
	var side: float = signf(ox - bx)
	var views: Dictionary = {
		"passage": [Vector3(c_bend.x, 0, c_bend.z + 1.2) + eye, Vector3(c_last.x, 1.4, c_last.z)],
		"mouth": [Vector3(c_last.x, 0, c_last.z + 1.0) + eye, Vector3(bx, 0.5, mid)],
		"start": [Vector3(bx, 0, z0 - 0.5) + eye, Vector3(bx, far_y + 1.4, z1)],
		# Leaning over the balustrade on the older bridge's side (eye 2.4 m).
		"old": [Vector3(bx + side * 1.6, 2.4, z0 - 6.0), Vector3(ox, oy, mid - 4.0)],
		# On the older bridge's deck (out of reach: fly mode), looking back at its sealed door.
		"olddoor": [Vector3(ox - side * 0.5, oy + 1.7, z0 - 6.0), Vector3(ox, oy + 2.0, z0)],
		"oldfar": [Vector3(bx + side * 1.6, BridgeHallBridge.deck_at(BridgeHallBridge.plan(n, rise, BridgeHallBridge.PIT, false)["walk"], z1 + 12.0 - z0) + 2.4, z1 + 12.0), Vector3(ox, oy + 2.0, z1 + 1.0)],
		"across": [Vector3(bx, 0, mid) + eye, Vector3(wall_x, 3.0, mid)],
		"down": [Vector3(bx + 3.2, 0, mid) + eye, Vector3(bx + 3.6, -8.0, mid - 4.0)],
		"up": [Vector3(bx, 0, mid) + eye, Vector3(bx + 2.0, 14.0, mid - 3.0)],
		"back": [Vector3(bx, far_y, z1 + 0.5) + eye, Vector3(bx, 1.4, z0)],
		"wide": [Vector3(hall.end.x - 3.8 if wall_x < bx else hall.position.x + 3.8, 9.0, z0 - 1.0), Vector3(bx, -2.0, z1 + 4.0)],
	}
	# Step 3: the entry passage's mushrooms, from the passage's middle.
	await physics_frame
	await physics_frame
	await process_frame
	var mush: Node3D = room.find_child("PassageMushroom_0", true, false) as Node3D
	if mush != null:
		var at: Vector3 = room.to_local(mush.global_position)
		var from: Vector3 = Vector3(c_last.x, at.y, c_last.z)
		from += (from - at).normalized() * 0.6
		views["mushroom"] = [from + Vector3(0, 1.4, 0), at]
	# Step 3: the landing on its side deck, the herbs at the entry mouth, a
	# window's garden (each found by its node).
	var land: Node3D = room.find_child("LandingSeat", true, false) as Node3D
	if land != null:
		var at: Vector3 = room.to_local(land.global_position)
		views["landing"] = [Vector3(bx - (at.x - bx) * 0.15, 0, at.z + 4.5) + eye, at + Vector3(0, 0.4, -0.5)]
	var herb: Node3D = room.find_child("PassageHerb_1", true, false) as Node3D
	if herb != null:
		var at: Vector3 = room.to_local(herb.global_position)
		views["herb"] = [Vector3(bx, 0, z0 - 2.5) + eye, at]
	var pot: Node3D = room.find_child("SillPot_*", true, false) as Node3D
	if pot == null:
		pot = room.find_child("Ivy_*", true, false) as Node3D
	if pot != null:
		var at: Vector3 = room.to_local(pot.global_position)
		views["window"] = [Vector3(bx, 0, at.z) + eye, at]
	# Walked step 3: a close look at a window's ivy; the pit's walls and pool.
	var ivy: Node3D = room.find_child("Ivy_*", true, false) as Node3D
	if ivy != null:
		var at: Vector3 = room.to_local(ivy.global_position)
		views["ivy"] = [Vector3(lerpf(at.x, bx, 0.45), at.y + 0.5, at.z + 1.2), at + Vector3(0, -0.4, 0)]
	views["pitwall"] = [Vector3(bx + side * 1.6, 2.4, mid + 3.0), Vector3(wall_x, BridgeHallBridge.PIT + 2.0, mid - 3.0)]
	var fall: Node3D = room.find_child("waterfall_*", true, false) as Node3D
	if fall != null:
		var at: Vector3 = room.to_local(fall.global_position)
		var mx: float = (at.x + bx) * 0.5
		views["pool"] = [Vector3(mx, BridgeHallBridge.PIT + 4.0, at.z + 7.0), Vector3(at.x, BridgeHallBridge.PIT + 0.5, at.z)]
	var vp_rid: RID = root.get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp_rid, true)
	print("r21_capture: seed %d, bridge hall %d bays, rise %d, bridge column %d, %d modules" % [area_seed, n, rise, int(m["bridge_column"]), room.modules.size()])
	for view: String in views:
		var v: Array = views[view]
		game.player.global_position = room.to_global(v[0]) - Vector3(0, game.player.camera.position.y, 0)
		game.look_toward(room.to_global(v[1]))
		for _i: int in 90:
			await process_frame
		await RenderingServer.frame_post_draw
		var total: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		var tris: int = RenderingServer.viewport_get_render_info(vp_rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)
		var path: String = "%s/r21_%d_%s.png" % [out_dir, area_seed, view]
		root.get_viewport().get_texture().get_image().save_png(path)
		print("  %s: draw calls %d; triangles %d k; gpu %.2f ms -> %s" % [view, total, tris / 1000,
			RenderingServer.viewport_get_measured_render_time_gpu(vp_rid), path])
	# The same views again by a temporary work light in the hall, to judge the
	# structure while the lighting (step 3) is still plain.
	var fill := OmniLight3D.new()
	fill.omni_range = 40.0
	fill.light_energy = 1.6
	fill.light_color = Color(0.95, 0.95, 1.0)
	room.add_child(fill)
	fill.position = Vector3(bx, 4.0, mid)
	for view: String in ([] if OS.get_cmdline_user_args().has("--no-worklight") else ["start", "across", "back", "wide", "down", "up"]):
		var v: Array = views[view]
		game.player.global_position = room.to_global(v[0]) - Vector3(0, game.player.camera.position.y, 0)
		game.look_toward(room.to_global(v[1]))
		for _i: int in 30:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png("%s/r21_%d_%s_worklight.png" % [out_dir, area_seed, view])
	main_script.room_override = ""
	Area.seed_override = -1
	quit()

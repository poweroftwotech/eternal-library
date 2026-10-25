extends SceneTree
## GPU pictures of the Gorge area (phase-6-design.md 5.7.2): the baked gorge
## from the overlook, in the real game. Needs a display, not --headless; run
## `godot --headless --import` first.
##   godot --path . --resolution 1600x900 --script res://tests/gorge_capture.gd -- <out dir> [--preset=medium]
## Writes gorge_<view>.png and prints the area's boot time, what the batcher
## made, and per view the draw calls, objects, triangles and GPU time:
##   concept  the box-art framing (capture.gd vista_concept; compare_vista)
##   walls    zoomed on the near-left tier walls (capture.gd vista_walls)
##   right    across to the right-hand banks

const EYE: Vector3 = Vector3(-1, 2.25, -27.45)
const VIEWS: Dictionary = {
	"concept": [Vector3(5, -22, -178), 68.0],
	"walls": [Vector3(-46, 14, -84), 26.0],
	"right": [Vector3(70, -10, -150), 50.0],
}


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var args: PackedStringArray = []
	for a: String in OS.get_cmdline_user_args():
		if not a.begins_with("--"):
			args.append(a)
	var out_dir: String = args[0] if args.size() > 0 else "user://gorge"
	DirAccess.make_dir_recursive_absolute(out_dir)
	var main_script: GDScript = load("res://scripts/main.gd")
	main_script.room_override = "area:gorge"
	var t0: int = Time.get_ticks_usec()
	var game: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	var boot_ms: float = (Time.get_ticks_usec() - t0) / 1000.0
	game.hud.toast_time = 0
	game.hud.visible = false
	game.stats.visible = false
	game.player.blocked = true
	game.player.set_physics_process(false)
	var area: Area = game.world
	var kit: Node = area.get_node("Scenery/Kit")
	var instances: int = 0
	for b: Node in kit.get_children():
		if b is MultiMeshInstance3D:
			instances += (b as MultiMeshInstance3D).multimesh.instance_count
	print("gorge_capture: boot %.0f ms (scenery %.0f ms); %d batches, %d pieces' meshes" % [boot_ms, area.timings.get("scenery_ms", -1.0), kit.get_child_count(), instances])
	var vp_rid: RID = root.get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp_rid, true)
	for view: String in VIEWS:
		game.player.global_position = EYE
		game.player.camera.fov = VIEWS[view][1]
		game.look_toward(VIEWS[view][0])
		for _i: int in 90:
			await process_frame
		await RenderingServer.frame_post_draw
		var path: String = "%s/gorge_%s.png" % [out_dir, view]
		root.get_viewport().get_texture().get_image().save_png(path)
		print("  %s: draw calls %d; objects %d, triangles %d k, gpu %.2f ms -> %s" % [view,
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			RenderingServer.viewport_get_render_info(vp_rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_OBJECTS_IN_FRAME),
			RenderingServer.viewport_get_render_info(vp_rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME) / 1000,
			RenderingServer.viewport_get_measured_render_time_gpu(vp_rid), path])
	main_script.room_override = ""
	quit()

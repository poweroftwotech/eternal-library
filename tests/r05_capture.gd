extends SceneTree
## GPU pictures of the R05 Caravanserai in the real game (phase-5-design.md
## 5.6.7), the Lower Stacks' root. Needs a display, not --headless; run
## `godot --headless --import` first.
##   godot --path . --resolution 1920x1080 --script res://tests/r05_capture.gd -- <out dir> [area seed] [--preset=medium]
## Writes r05_<seed>_<view>.png, printing the draw calls, objects and
## triangles of each view (court frame: x -8..12, z -4..-24):
##   atlas    from the court's far end toward the gate (the atlas mock's view)
##   entry    from the gate passage into the court
##   arcade   along the west range's arches
##   cell     into a ground cell
##   hearth   by the hearth
##   stair    at the foot of the west stair, up the first flight
##   loggia   along the west range's loggia, upstairs
##   across   from the far range's loggia across the court to the gate
##   up       from the court up to the cavern's rock

const VIEWS: Dictionary = {
	"atlas": [Vector3(2, 1.7, -22.0), Vector3(2, 5.0, -4.0)],
	"entry": [Vector3(2, 1.6, -2.6), Vector3(2, 2.0, -20.0)],
	"arcade": [Vector3(-4.5, 1.6, -5.5), Vector3(-7.6, 1.8, -18.0)],
	"cell": [Vector3(-5.2, 1.6, -10.0), Vector3(-10.6, 0.9, -10.0)],
	"hearth": [Vector3(6.2, 1.6, -9.8), Vector3(2.0, 0.6, -14.0)],
	"stair": [Vector3(-7.3, 1.6, -2.85), Vector3(-2.0, 2.8, -2.85)],
	"loggia": [Vector3(-9.15, 5.7, -5.4), Vector3(-9.15, 5.3, -22.0)],
	"across": [Vector3(2.0, 5.7, -22.8), Vector3(2.0, 4.5, -4.0)],
	"up": [Vector3(2.0, 1.6, -19.0), Vector3(2.0, 15.0, -12.0)],
}


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var args: PackedStringArray = []
	for a: String in OS.get_cmdline_user_args():
		if not a.begins_with("--"):
			args.append(a)
	var out_dir: String = args[0] if args.size() > 0 else "user://r05"
	var area_seed: int = int(args[1]) if args.size() > 1 else 1
	var only: PackedStringArray = args[2].split(",") if args.size() > 2 else PackedStringArray()
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
	for _i: int in 10:
		await process_frame
	while area.streamer.busy():
		await process_frame
	var room: RoomTemplate = area.rooms.get("caravanserai")
	var vp_rid: RID = root.get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp_rid, true)
	print("r05_capture: seed %d, %d rooms live" % [area_seed, area.rooms.size()])
	for view: String in VIEWS:
		if not only.is_empty() and not only.has(view):
			continue
		var v: Array = VIEWS[view]
		game.player.global_position = room.to_global(v[0]) - Vector3(0, game.player.camera.position.y, 0)
		game.look_toward(room.to_global(v[1]))
		for _i: int in 90:
			await process_frame
		await RenderingServer.frame_post_draw
		var total: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		var objects: int = RenderingServer.viewport_get_render_info(vp_rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_OBJECTS_IN_FRAME)
		var tris: int = RenderingServer.viewport_get_render_info(vp_rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)
		var path: String = "%s/r05_%d_%s.png" % [out_dir, area_seed, view]
		root.get_viewport().get_texture().get_image().save_png(path)
		print("  %s: draw calls %d in all passes; objects %d, triangles %d k, gpu %.2f ms -> %s" % [view, total, objects, tris / 1000,
			RenderingServer.viewport_get_measured_render_time_gpu(vp_rid), path])
	main_script.room_override = ""
	Area.seed_override = -1
	quit()

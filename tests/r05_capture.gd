extends SceneTree
## GPU pictures of the R05 Caravanserai in the real game (phase-5-design.md
## 5.6.7), the Lower Stacks' root. Needs a display, not --headless; run
## `godot --headless --import` first.
##   godot --path . --resolution 1920x1080 --script res://tests/r05_capture.gd -- <out dir> [area seed] [--preset=medium]
## Writes r05_<seed>_<view>.png, printing the draw calls, objects and
## triangles of each view (from the court's edges, any size):
##   atlas    from the court's far end toward the gate (the atlas mock's view)
##   entry    from the gate passage into the court
##   arcade   along the west range's arches
##   cell     into a ground cell
##   hearth   by the hearth
##   stair    at the foot of the west stair, up the first flight
##   loggia   along the west range's loggia, upstairs (a 3 x 3: the far range's)
##   across   from the far range's loggia across the court to the gate
##   up       from the court up to the cavern's rock

## view -> [eye, look-at] in the court's frame, from its layout (the bake keeps
## it): x from w0 to w1 and z from z0 (the entry face) to z1 (the far face).
static func views(m: Dictionary) -> Dictionary:
	var h: int = m["h"]
	var top: int = m["top"]
	var w0: float = (-h + 1) * CellGrid.BAY
	var w1: float = h * CellGrid.BAY
	var z0: float = -CellGrid.BAY
	var z1: float = -top * CellGrid.BAY
	var cx: float = CellGrid.BAY * 0.5
	var cz: float = CellGrid.cell_centre(m["centre"]).z
	var stair: Transform3D = m["stair_frames"][0]
	var side_stairs: bool = (m["stair_corners"][0] as Vector3i).z != 0
	return {
		"atlas": [Vector3(cx, 1.7, z1 + 2.0), Vector3(cx, 5.0, z0)],
		"entry": [Vector3(cx, 1.6, z0 + 1.4), Vector3(cx, 2.0, z1 + 4.0)],
		"arcade": [Vector3(w0 + 3.5, 1.6, z0 - 1.5), Vector3(w0 + 0.4, 1.8, z1 + 6.0)],
		"cell": [Vector3(w0 + 2.8, 1.6, cz + 4.0), Vector3(w0 - 2.6, 0.9, cz + 4.0)],
		"hearth": [Vector3(cx + 4.2, 1.6, cz + 4.2), Vector3(cx, 0.6, cz)],
		"stair": [stair * Vector3(7.3, 1.6, -1.15), stair * Vector3(2.0, 2.8, -1.15)],
		"loggia": [Vector3(w0 + 1.4, 5.7, z1 - 1.15), Vector3(w1, 5.3, z1 - 1.15)] if side_stairs else [Vector3(w0 - 1.15, 5.7, z0 - 1.4), Vector3(w0 - 1.15, 5.3, z1 + 2.0)],
		"across": [Vector3(cx, 5.7, z1 + 1.2), Vector3(cx, 4.5, z0)],
		"up": [Vector3(cx, 1.6, z1 + 5.0), Vector3(cx, 15.0, cz + 2.0)],
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
	var layout: Dictionary = (room.get_meta("baked_from", {}) as Dictionary).get("layout", {})
	var all: Dictionary = views(layout)
	print("  court: %d x %d" % [layout["h"] * 2 - 1, layout["top"] - 1])
	for view: String in all:
		if not only.is_empty() and not only.has(view):
			continue
		var v: Array = all[view]
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

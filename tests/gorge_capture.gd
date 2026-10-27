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
##   stair    down the rock-cut stair to the landing by the left colossus
##   landing  from the landing toward the flight and the ledge (step 2)
##   ledge    from the ledge's end back along it
##   up       from the landing back up the stair to the balcony
## and, when the area has a span (step 3), from the plan:
##   span        from the ledge's corner out along the span
##   span_mid    from the middle on toward the far ledge
##   span_head   from the far ledge back toward the Overlook
##   span_side   from the ledge's west end back along it onto the span
##   span_under  from under its start up along the arcades
## and the near network (step 4): per link net_<link> (along it) and
## net_<link>_side; per ledge net_<ledge> (along it), _out (across the gorge)
## _under (its consoles from below) and _face (from the air in front);
## net_air (the whole, from the air).
## A view's third value is where you stand (default: the balcony).
##   (a second argument picks views: concept,stair)
##   (or `sweep`: at each stop on the walk, eight headings a little below
##   level and one straight over the edge, gorge_sweep_<stop>_<heading>.png;
##   for finding missing faces the balcony never showed)

const EYE: Vector3 = Vector3(-1, 2.25, -27.45)
const VIEWS: Dictionary = {
	"concept": [Vector3(5, -22, -178), 68.0],
	"walls": [Vector3(-46, 14, -84), 26.0],
	"right": [Vector3(70, -10, -150), 50.0],
	"stair": [Vector3(-18, -9, -62), 55.0],
	"landing": [Vector3(-28, -12, -74), 70.0, Vector3(-14.5, -8, -56)],
	"ledge": [Vector3(-19, -11, -70), 70.0, Vector3(-37, -12, -73)],
	"up": [Vector3(-7, 4, -29), 70.0, Vector3(-17, -8, -61)],
	# Bank 1 as a Persian hill town (phase 8 step 2)
	"b1_iwan": [Vector3(-54, -2, -64), 34.0],
	"b1_fall": [Vector3(-44, -72, -72), 66.0, Vector3(-12, -58, -78)],
	"b1_north": [Vector3(-80, -36, -60), 70.0, Vector3(-66, -18, -34)],
	"b1_garden": [Vector3(-50, -9, -66), 66.0, Vector3(-34, -2, -50)],
	"b1_monument": [Vector3(-56, -4, -80), 46.0],
	"b1_mon_close": [Vector3(-58, -6, -80), 68.0, Vector3(-18, -4, -98)],
	"b1_mon_garden": [Vector3(-60, -8, -80), 72.0, Vector3(-40, -12, -74)],
	"b1_shaft": [Vector3(-50, -6, -84), 64.0, Vector3(-26, 4, -76)],
	"b1_top": [Vector3(-52, 18, -80), 36.0],
	"b1_close": [Vector3(-52, -6, -66), 70.0, Vector3(-26, 0, -60)],
	"b1_low": [Vector3(-46, -78, -72), 72.0, Vector3(-14, -64, -64)],
	"b1_east": [Vector3(-50, -40, -80), 64.0, Vector3(-4, -30, -78)],
}
## The sweep's stops: where you stand.
const STOPS: Dictionary = {
	"stair": Vector3(-10.35, -2.9, -43.6),
	"landing": Vector3(-16, -8, -58),
	"flight": Vector3(-19.65, -10, -67.3),
	"corner": Vector3(-24.77, -12, -80.34),
	"ledge": Vector3(-32.21, -12, -77.42),
	"end": Vector3(-39.66, -12, -74.5),
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
	var only: PackedStringArray = args[1].split(",") if args.size() > 1 else PackedStringArray()
	var views: Dictionary = VIEWS.duplicate()
	var span: AreaPlan.Room = area.plan.room("span")
	if span != null and span.kind == "span" and span.span.get("ok", false):
		var s: Transform3D = span.xf
		var n: int = span.span["bays"]
		var low: float = -int(span.span["drop"]) * 4.0
		var head: Vector3 = s * Vector3(0, low, -n * 4.0 - 2.0)
		print("gorge_capture: span seed %d, %s, %d bays, %d storeys down" % [span.seed_value, span.span["kind"], n, span.span["drop"]])
		views["span"] = [s * Vector3(0, -2, -60), 70.0, s * Vector3(0, 0, 2)]
		views["span_mid"] = [head + Vector3(0, -1, 0), 70.0, s * Vector3(0, 0, -n * 2.0)]
		views["span_head"] = [s * Vector3(0, 1, 0), 70.0, head]
		views["span_side"] = [s * Vector3(0, -16, -n * 2.0), 70.0, STOPS["end"]]
		# From under its start (the camera only: the player's physics is off).
		views["span_under"] = [s * Vector3(0, -14, -n * 4.0), 80.0, s * Vector3(9, -46, -4)]
		# The last bays by the far bank, from the air beside them: what carries them.
		views["span_end"] = [s * Vector3(0, low - 10.0, -n * 4.0 + 14.0), 70.0, s * Vector3(26, low - 6.0, -n * 4.0 + 14.0)]
	# The near gorge's network (step 4): each link from its start along it and
	# from beside its middle; each ledge along it and out from it; the whole
	# from the air.
	for r: AreaPlan.Room in area.plan.rooms:
		if r.kind == "link":
			var s: Transform3D = r.xf
			var length: float = r.span["length"]
			var low: float = -int(r.span["drop"]) * 4.0
			var name: String = "net_" + r.slot_id
			print("gorge_capture: %s %s, %.0f m, %d storeys, from %s" % [r.slot_id, r.display_name, length, r.span["drop"], r.parent])
			views[name] = [s * Vector3(0, low * .5 + 1.0, -length), 70.0, s * Vector3(0, 0, -1.0)]
			views[name + "_side"] = [s * Vector3(0, low * .5, -length * .5), 70.0, s * Vector3(length * .45, low * .5 + 6.0, -length * .5)]
		elif r.kind == "ledge":
			var n: int = r.span["bays"]
			var name: String = "net_" + r.slot_id
			print("gorge_capture: %s on %s, %d bays" % [r.slot_id, r.span["slot"], n])
			views[name] = [r.xf * Vector3(n * 4.0, 1.0, -2.0), 70.0, r.xf * Vector3(.8, 0, -2.0)]
			views[name + "_out"] = [r.xf * Vector3(n * 2.0, -2.0, -40.0), 75.0, r.xf * Vector3(n * 2.0, 0, -1.2)]
			views[name + "_under"] = [r.xf * Vector3(n * 2.0, -1.0, 0.0), 70.0, r.xf * Vector3(n * 2.0 + 6.0, -6.0, -14.0)]
			views[name + "_face"] = [r.xf * Vector3(n * 2.0, -1.0, 0.0), 60.0, r.xf * Vector3(n * 2.0 - 5.0, -3.0, -16.0)]
	views["net_air"] = [Vector3(5, -40, -115), 75.0, Vector3(-8, 14, -45)]
	if only.has("sweep"):
		views = {}
		only = PackedStringArray()
		for stop: String in STOPS:
			var at: Vector3 = STOPS[stop]
			for k: int in 8:
				var dir := Vector3(sin(TAU * k / 8.0), -.25, -cos(TAU * k / 8.0))
				views["sweep_%s_%d" % [stop, k * 45]] = [at + Vector3(0, 1.7, 0) + dir * 20.0, 80.0, at]
			views["sweep_%s_down" % stop] = [at + Vector3(-6, -20, -6), 80.0, at]
	for view: String in views:
		if not only.is_empty() and not only.has(view):
			continue
		game.player.global_position = views[view][2] if (views[view] as Array).size() > 2 else EYE
		game.player.camera.fov = views[view][1]
		game.look_toward(views[view][0])
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

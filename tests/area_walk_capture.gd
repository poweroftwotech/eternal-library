extends SceneTree
## Frame log and frame gate of the real game walking an area (the library
## wing, or --area=<id>: the Lower Stacks, phase-5-design.md 5.6.3) while
## rooms stream (phase-4-design.md 8.1.7). Needs a display, not --headless;
## run `godot --headless --import` first.
##   godot --path . --resolution 1920x1080 --script res://tests/area_walk_capture.gd -- <out.csv> [area seed] [speed m/s] [--preset=medium] [--gate] [--area=<id>]
## The player walks (3.3 m/s, the game's speed) from the root room (AreaTour) out to every
## leaf gallery's far end and back, looking where it goes, with vsync off.
## Every frame is logged: its time, GPU time, the streamer's work, rooms
## live, loaded and unloaded, draw calls (all passes), shadowed lights, lights
## within reach, video memory and the room the player is in.
##
## --gate checks the base-spec frame target (Q7, revised; 8.1.7), measured
## here at the Medium preset, 1080p:
##   GPU time per frame: mean <= 3 ms, no frame over 4 ms;
##   CPU time per frame (the frame's wall time; the GPU is never the wait at
##   this speed): mean <= 4 ms, no frame over 8 ms;
##   per frame: draw calls <= 1500, triangles <= 3 M, shadowed lights <= 4,
##   lights within 35 m <= 48, video memory <= 6 GB.
## The 4x (GPU) and 2x (CPU) dev-to-RTX-3060 factors behind these are an
## estimate (architecture.md 8.2). Exits 1 if the gate fails.

const TARGET: Dictionary = {"gpu_mean": 3.0, "gpu_max": 4.0, "cpu_mean": 4.0, "cpu_max": 8.0,
	"draws": 1500, "tris": 3000000, "shadowed": 4, "lights": 48, "vram_mb": 6144.0}
## Lights this close to the camera count as "in reach" (the distance fade
## begins at 30 m and ends at 35 m).
const REACH_M: float = 35.0


func _initialize() -> void:
	call_deferred("capture")


func capture() -> void:
	var args: PackedStringArray = []
	for a: String in OS.get_cmdline_user_args():
		if not a.begins_with("--"):
			args.append(a)
	var gate: bool = OS.get_cmdline_user_args().has("--gate")
	var out: String = args[0] if args.size() > 0 else "user://p4_frames.csv"
	var area_seed: int = int(args[1]) if args.size() > 1 else 1
	var speed: float = float(args[2]) if args.size() > 2 else 3.3
	var main_script: GDScript = load("res://scripts/main.gd")
	var area_id: String = "library"
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--area="):
			area_id = a.trim_prefix("--area=")
	main_script.room_override = "area:" + area_id
	Area.seed_override = area_seed
	var t0: int = Time.get_ticks_usec()
	var game: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	var boot_ms: float = (Time.get_ticks_usec() - t0) / 1000.0
	game.hud.toast_time = 0
	game.stats.visible = false     # the panel would cost frames of its own
	game.player.blocked = true     # the script walks it
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var vp_rid: RID = root.get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp_rid, true)
	var area: Area = game.world
	var st: AreaStreamer = area.streamer
	var path: Array[Vector3] = AreaTour.tour(area.plan)
	# Start where the walk starts: a teleport makes the bounce light catch up
	# (one GPU frame of about 4.5 ms), which is not what walking costs.
	game.player.global_position = path[0] + Vector3(0, 0.05, 0)
	game.look_toward(path[1] + Vector3(0, 1.6, 0))
	for i: int in 60:     # settle the start
		await process_frame
	var lines: PackedStringArray = ["frame,ms,gpu_ms,stream_ms,live,loads,unloads,draw_calls,triangles,shadowed,lights,vram_mb,room,event"]
	var times: Array[float] = []
	var gpus: Array[float] = []
	var worst: Array = []      # [ms, line]
	var peak: Dictionary = {"draws": 0.0, "tris": 0.0, "shadowed": 0.0, "lights": 0.0, "vram_mb": 0.0}
	var seg: int = 0
	var pos: Vector3 = path[0]
	var last: int = Time.get_ticks_usec()
	var loads: int = st.stats["loads"]
	var unloads: int = st.stats["unloads"]
	var frame: int = 0
	var in_reach: int = 0
	# The light count below is the test's own work (a walk of every node in the
	# area): timed, and taken off the frame it lands in, so a big hall isn't
	# charged for it.
	var probe_us: int = 0
	var probe_max_ms: float = 0.0
	while seg < path.size() - 1:
		await process_frame
		var now: int = Time.get_ticks_usec()
		var ms: float = (now - last - probe_us) / 1000.0
		probe_us = 0
		last = now
		# Walk on by real time, as a player would.
		var step: float = speed * minf(ms, 50.0) / 1000.0
		while step > 0.0 and seg < path.size() - 1:
			var to: Vector3 = path[seg + 1] - pos
			if to.length() <= step:
				step -= to.length()
				pos = path[seg + 1]
				seg += 1
			else:
				pos += to.normalized() * step
				step = 0.0
		var ahead: Vector3 = path[mini(seg + 1, path.size() - 1)]
		game.player.global_position = pos + Vector3(0, 0.05, 0)
		if ahead.distance_to(pos) > 0.05:
			game.look_toward(ahead + Vector3(0, 1.6, 0))
		var event: String = ""
		if st.stats["loads"] != loads:
			event += "load "
		if st.stats["unloads"] != unloads:
			event += "unload"
		loads = st.stats["loads"]
		unloads = st.stats["unloads"]
		if frame % 15 == 0 or event != "":
			var probe_t0: int = Time.get_ticks_usec()
			var cam: Vector3 = game.player.camera.global_position
			in_reach = area.find_children("*", "Light3D", true, false).filter(func(l: Node) -> bool:
				return (l as Light3D).is_visible_in_tree() and (l as Light3D).global_position.distance_to(cam) < REACH_M).size()
			probe_us = Time.get_ticks_usec() - probe_t0
			probe_max_ms = maxf(probe_max_ms, probe_us / 1000.0)
		var gpu: float = RenderingServer.viewport_get_measured_render_time_gpu(vp_rid)
		var draws: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		var tris: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
		var shadowed: int = area.light_budget.casting()
		var vram: float = Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0
		var now_vals: Dictionary = {"draws": draws, "tris": tris, "shadowed": shadowed, "lights": in_reach, "vram_mb": vram}
		for k: String in peak:
			peak[k] = maxf(float(peak[k]), float(now_vals[k]))
		var line: String = "%d,%.3f,%.3f,%.3f,%d,%d,%d,%d,%d,%d,%d,%.0f,%s,%s" % [frame, ms, gpu, st.stats["last_frame_ms"], st.live_count(), loads, unloads,
			draws, tris, shadowed, in_reach, vram, st.player_room, event.strip_edges()]
		lines.append(line)
		times.append(ms)
		gpus.append(gpu)
		worst.append([ms, line])
		frame += 1
	var f: FileAccess = FileAccess.open(out, FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")
	f.close()
	var sorted: Array[float] = times.duplicate()
	sorted.sort()
	var mean: float = _mean(times)
	var gpu_mean: float = _mean(gpus)
	var gpu_max: float = gpus.max()
	var over_8: int = sorted.filter(func(t: float) -> bool: return t > 8.3).size()
	var over_16: int = sorted.filter(func(t: float) -> bool: return t > 16.7).size()
	var preset: String = GraphicsPreset.requested() if GraphicsPreset.requested() != "" else "project settings"
	print("area_walk_capture: %s seed %d, %d rooms, %s, %dx%d, boot %.0f ms; %d frames over %.0f m; frame %.2f ms mean, %.2f p99, %.2f worst; gpu %.2f ms mean, %.2f worst; %d over 8.3 ms, %d over 16.7 ms; peaks %s; built %d, unloaded %d; slowest streaming frame %.1f ms; wear regions up to %.0f ms (thread), upload up to %.1f ms (map %s); light count (not charged) up to %.1f ms; wrote %s" % [
		area_id, area_seed, area.plan.rooms.size(), preset, root.size.x, root.size.y, boot_ms, frame, AreaTour.length(path), mean, sorted[int(sorted.size() * 0.99) - 1], sorted[-1],
		gpu_mean, gpu_max, over_8, over_16, peak, st.stats["loads"], st.stats["unloads"], st.stats["max_frame_ms"], FloorWear.max_region_ms, FloorWear.max_upload_ms, FloorWear.map_image.get_size() if FloorWear.map_image != null else Vector2i.ZERO, probe_max_ms, out])
	worst.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	print("  worst frames (%s):" % lines[0])
	for w: Array in worst.slice(0, 8):
		print("    " + str(w[1]))
	var fails: PackedStringArray = []
	if gate:
		var checks: Array = [["gpu mean", gpu_mean, TARGET["gpu_mean"]], ["gpu worst", gpu_max, TARGET["gpu_max"]],
			["cpu mean", mean, TARGET["cpu_mean"]], ["cpu worst", sorted[-1], TARGET["cpu_max"]],
			["draw calls", peak["draws"], TARGET["draws"]], ["triangles", peak["tris"], TARGET["tris"]],
			["shadowed lights", peak["shadowed"], TARGET["shadowed"]], ["lights in reach", peak["lights"], TARGET["lights"]],
			["video memory MB", peak["vram_mb"], TARGET["vram_mb"]]]
		for c: Array in checks:
			if float(c[1]) > float(c[2]):
				fails.append("%s %.2f > %.2f" % [c[0], c[1], c[2]])
		print("area_walk_capture gate: %s" % ("PASS" if fails.is_empty() else "FAIL " + "; ".join(fails)))
	main_script.room_override = ""
	quit(1 if not fails.is_empty() else 0)


func _mean(values: Array[float]) -> float:
	return values.reduce(func(a: float, b: float) -> float: return a + b, 0.0) / maxf(values.size(), 1)

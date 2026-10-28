extends SceneTree
## What the camp (rooms/camp/camp.tscn, baked from kit pieces in phase 7)
## costs a frame (the camp rebuild's brief measured the code-built camp it
## replaced the same way). Needs a display, not --headless; run
## `godot --headless --import` first.
##   godot --path . --resolution 1920x1080 --script res://tests/camp_frame_capture.gd -- <out.csv> [--preset=medium] [--quick]
## Boots the real game in the camp, then at each of the
## camp's viewpoints settles, then turns once on the spot (VIEW_FRAMES
## frames), vsync off. Prints per viewpoint and overall: frame time (CPU) and
## GPU time, mean and worst; draw calls, triangles and lights within 35 m at
## their peak; and what the camp is made of (meshes, lights, particles,
## materials, how long it took to build).

## [name, feet, look-at at the start of the turn].
const VIEWS: Array = [
	["spawn (box-art framing)", Vector3(-1.05, .08, 9.2), Vector3(-1.1, 1.4, -2.4)],
	["hearth", Vector3(.5, .08, 6.6), Vector3(-1.3, .8, 4.4)],
	["archive", Vector3(.6, .08, -2.5), Vector3(.6, .4, -4.3)],
	["garden", Vector3(2.5, .08, -2.8), Vector3(2.5, 1.6, -8.0)],
	["gallery", Vector3(-1, 2.25, -11.1), Vector3(-1, 3.5, -20.0)],
]
const SETTLE_FRAMES: int = 60
const VIEW_FRAMES: int = 360
## --quick: a few frames a view (the scene breakdown only).
var quick: bool = OS.get_cmdline_user_args().has("--quick")
const REACH_M: float = 35.0


func _initialize() -> void:
	call_deferred("capture")


func capture() -> void:
	var out: String = "user://camp_frames.csv"
	for a: String in OS.get_cmdline_user_args():
		if not a.begins_with("--"):
			out = a
	var main_script: GDScript = load("res://scripts/main.gd")
	main_script.room_override = "camp"
	var t0: int = Time.get_ticks_usec()
	var game: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	var boot_ms: float = (Time.get_ticks_usec() - t0) / 1000.0
	game.hud.toast_time = 0
	game.hud.visible = false
	game.stats.visible = false
	game.player.blocked = true
	game.player.set_physics_process(false)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var vp_rid: RID = root.get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp_rid, true)
	# The Gorge, built behind the camp in the background (phase 9), is part of
	# what the camp costs once it's in: measured with it.
	if game.seamless != null:
		var stop: int = Time.get_ticks_msec() + 30000
		while game.seamless.neighbour == null and Time.get_ticks_msec() < stop:
			await process_frame
		for _i: int in 120:
			await process_frame
	var world: Node3D = game.world
	var lights: Array = world.find_children("*", "Light3D", true, false)
	var lines: PackedStringArray = ["view,frame,ms,gpu_ms,draw_calls,triangles,lights_in_reach,vram_mb"]
	var all_ms: Array[float] = []
	var all_gpu: Array[float] = []
	var summary: PackedStringArray = []
	var peak: Dictionary = {"draws": 0, "tris": 0, "lights": 0, "vram": 0.0}
	for v: Array in VIEWS:
		game.player.global_position = v[1]
		game.look_toward(v[2])
		var yaw0: float = game.player.rotation.y
		for _i: int in SETTLE_FRAMES:
			await process_frame
		var ms_v: Array[float] = []
		var gpu_v: Array[float] = []
		var vpeak: Dictionary = {"draws": 0, "tris": 0, "lights": 0}
		var last: int = Time.get_ticks_usec()
		for f: int in (10 if quick else VIEW_FRAMES):
			game.player.rotation.y = yaw0 + TAU * float(f) / VIEW_FRAMES
			await process_frame
			var now: int = Time.get_ticks_usec()
			var ms: float = (now - last) / 1000.0
			last = now
			var gpu: float = RenderingServer.viewport_get_measured_render_time_gpu(vp_rid)
			var draws: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
			var tris: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
			var vram: float = Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0
			var cam: Vector3 = game.player.camera.global_position
			var reach: int = 0
			if f % 30 == 0:
				reach = lights.filter(func(l: Node) -> bool: return (l as Light3D).is_visible_in_tree() and (l as Light3D).global_position.distance_to(cam) < REACH_M).size()
			ms_v.append(ms)
			gpu_v.append(gpu)
			vpeak["draws"] = maxi(vpeak["draws"], draws)
			vpeak["tris"] = maxi(vpeak["tris"], tris)
			vpeak["lights"] = maxi(vpeak["lights"], reach)
			peak["vram"] = maxf(peak["vram"], vram)
			lines.append("%s,%d,%.3f,%.3f,%d,%d,%d,%.0f" % [v[0], f, ms, gpu, draws, tris, reach, vram])
		all_ms.append_array(ms_v)
		all_gpu.append_array(gpu_v)
		for k: String in vpeak:
			peak[k] = maxi(peak[k], vpeak[k])
		summary.append("  %-24s frame %.2f ms mean, %.2f worst; gpu %.2f mean, %.2f worst; draw calls up to %d, triangles up to %d, lights in reach up to %d" % [
			v[0], _mean(ms_v), ms_v.max(), _mean(gpu_v), gpu_v.max(), vpeak["draws"], vpeak["tris"], vpeak["lights"]])
	var f: FileAccess = FileAccess.open(out, FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")
	f.close()
	var shadowed: int = lights.filter(func(l: Node) -> bool: return (l as Light3D).shadow_enabled).size()
	var meshes: Array = world.find_children("*", "MeshInstance3D", true, false)
	var multis: Array = world.find_children("*", "MultiMeshInstance3D", true, false)
	var particles: Array = world.find_children("*", "GPUParticles3D", true, false)
	var mats: Dictionary = {}
	for m: Node in meshes:
		var mi := m as MeshInstance3D
		if mi.mesh == null:
			continue
		for s: int in mi.mesh.get_surface_count():
			var mat: Material = mi.get_active_material(s)
			if mat != null:
				mats[mat.get_instance_id()] = true
	var preset: String = GraphicsPreset.requested() if GraphicsPreset.requested() != "" else "project settings"
	print("camp_frame_capture: %s, %s, %dx%d; built in %.0f ms; %d frames; frame %.2f ms mean, %.2f worst; gpu %.2f ms mean, %.2f worst; peaks: draw calls %d, triangles %d, lights in reach %d, video memory %.0f MB" % [
		"the camp", preset, root.size.x, root.size.y, boot_ms, all_ms.size(),
		_mean(all_ms), all_ms.max(), _mean(all_gpu), all_gpu.max(), peak["draws"], peak["tris"], peak["lights"], peak["vram"]])
	print("  made of: %d mesh instances, %d multimesh instances, %d materials, %d lights (%d with shadows), %d particle systems" % [
		meshes.size(), multis.size(), mats.size(), lights.size(), shadowed, particles.size()])
	for s: String in summary:
		print(s)
	# Where the triangles are: by the mesh node's name (its digits dropped).
	var tri_by: Dictionary = {}
	var count_by: Dictionary = {}
	for m: Node in meshes:
		var mi := m as MeshInstance3D
		if mi.mesh == null or not mi.is_visible_in_tree():
			continue
		var n: int = 0
		for s: int in mi.mesh.get_surface_count():
			var arr: Array = mi.mesh.surface_get_arrays(s)
			n += ((arr[Mesh.ARRAY_INDEX] as PackedInt32Array).size() if arr[Mesh.ARRAY_INDEX] != null else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
		var key: String = str(mi.get_parent().name).rstrip("0123456789_@") + "/" + str(mi.name).rstrip("0123456789_@")
		tri_by[key] = int(tri_by.get(key, 0)) + n
		count_by[key] = int(count_by.get(key, 0)) + 1
	for m: Node in multis:
		var mm: MultiMesh = (m as MultiMeshInstance3D).multimesh
		if mm == null or mm.mesh == null or not (m as Node3D).is_visible_in_tree():
			continue
		var per: int = 0
		for s: int in mm.mesh.get_surface_count():
			var arr: Array = mm.mesh.surface_get_arrays(s)
			per += ((arr[Mesh.ARRAY_INDEX] as PackedInt32Array).size() if arr[Mesh.ARRAY_INDEX] != null else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
		var key: String = "multimesh " + str(m.name).rstrip("0123456789_@") + " (%d tris x %d)" % [per, mm.instance_count]
		tri_by[key] = int(tri_by.get(key, 0)) + per * mm.instance_count
		count_by[key] = int(count_by.get(key, 0)) + 1
	var keys: Array = tri_by.keys()
	keys.sort_custom(func(a: String, b: String) -> bool: return tri_by[a] > tri_by[b])
	var total: int = 0
	for k: String in keys:
		total += int(tri_by[k])
	var casters: PackedStringArray = []
	for l: Node in lights:
		if (l as Light3D).shadow_enabled:
			casters.append("%s %s (%.0f m)" % [l.get_class(), l.name, (l as OmniLight3D).omni_range if l is OmniLight3D else ((l as SpotLight3D).spot_range if l is SpotLight3D else 0.0)])
	print("  shadowed lights: %s" % ", ".join(casters))
	print("  triangles in the scene: %d; the heaviest:" % total)
	for k: String in keys.slice(0, 15):
		print("    %9d  %4d x  %s" % [tri_by[k], count_by[k], k])
	print("  wrote %s" % out)
	main_script.room_override = ""
	quit()


func _mean(values: Array[float]) -> float:
	var t: float = 0.0
	for x: float in values:
		t += x
	return t / maxf(values.size(), 1)

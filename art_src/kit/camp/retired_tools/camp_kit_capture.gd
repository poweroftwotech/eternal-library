extends SceneTree
## The camp's kit pieces in place (phase 7): the real game in the old camp,
## everything the pieces of art_src/kit/camp/pieces.json replace taken out
## (tools/camp_cut.gd) and the kit pieces (kit/modules/camp/) put where they
## were, then the camp merged as usual. Retakes the views of a reports folder
## (as tests/report_capture.gd), for side-by-side pictures with today's.
## Needs a display; run `godot --headless --import` first.
##   godot --path . --resolution 1600x900 --script res://tests/camp_kit_capture.gd -- <out dir> --from=<reports dir> [--old]
## --old: the same, without swapping anything (today's camp, merged the same way).
## --no-gorge: without the gorge view (World.with_gorge), the camp by itself.

const Cut = preload("res://tools/camp_cut.gd")
const World = preload("res://scripts/world.gd")


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var out_dir: String = "user://camp_kit_capture"
	var old: bool = false
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--from="):
			ReportTool.folder_override = a.trim_prefix("--from=")
		elif a == "--old":
			old = true
		elif not a.begins_with("--"):
			out_dir = a
	DirAccess.make_dir_recursive_absolute(out_dir)
	OS.set_environment("ZFIGHT_NO_MERGE", "1")      # keep the pieces apart until they're cut out
	var main_script: GDScript = load("res://scripts/main.gd")
	main_script.room_override = "camp"
	if OS.get_cmdline_user_args().has("--no-gorge"):
		World.with_gorge = false
	var game: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	var world: Node3D = game.world
	var swapped: int = 0
	var kits: Array[Node3D] = []
	if not old:
		var pieces: Array = Cut.load_pieces()
		var taken: Dictionary = Cut.cut(world, world.art, pieces)
		for piece: Dictionary in pieces:
			var t: Dictionary = taken[piece["name"]]
			for mi: MeshInstance3D in t["meshes"]:
				mi.free()
			for it: Array in t["instances"]:
				(it[0] as MultiMeshInstance3D).multimesh.set_instance_transform(it[1], Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))
			for cs: CollisionShape3D in t["shapes"]:
				cs.disabled = true
			if piece.get("drop", false):
				continue
			var kit: Node3D = (load("res://kit/modules/camp/%s.tscn" % piece["name"]) as PackedScene).instantiate()
			kit.transform = Cut.frame(piece)
			kits.append(kit)
			swapped += 1
	world.art.merge_static_geometry()
	for kit: Node3D in kits:      # after the merge, which takes only the factory's meshes
		world.add_child(kit)
	game.hud.toast_time = 0
	game.hud.visible = false
	game.stats.visible = false
	game.player.blocked = true
	game.player.set_physics_process(false)
	var vp_rid: RID = root.get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp_rid, true)
	print("camp_kit_capture: %s, %d pieces swapped in" % ["today's camp" if old else "kit pieces in the camp", swapped])
	for r: Dictionary in ReportTool.read_all():
		var feet: Array = r["feet"]
		game.player.global_position = Vector3(feet[0], feet[1], feet[2])
		game.player.rotation.y = deg_to_rad(float(r["yaw_deg"]))
		game.player.camera.rotation.x = deg_to_rad(float(r.get("pitch_deg", 0.0)))
		game.player.camera.fov = float(r.get("fov", 68.0))
		for _i: int in 90:
			await process_frame
		var gpu: Array[float] = []
		for _i: int in 30:
			await process_frame
			gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(vp_rid))
		var path: String = "%s/%s.png" % [out_dir, r["id"]]
		root.get_viewport().get_texture().get_image().save_png(path)
		var mean: float = 0.0
		for g: float in gpu:
			mean += g / gpu.size()
		print("  %s: draw calls %d, triangles %d, gpu %.2f ms -> %s" % [r["id"], Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME), mean, path])
	main_script.room_override = ""
	quit()

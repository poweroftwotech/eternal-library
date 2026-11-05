extends SceneTree
## Re-takes the views you reported with the ` key (scripts/report_tool.gd), in the
## real game, for before-and-after pictures of a fix. Needs a display, not
## --headless; run `godot --headless --import` first.
##   godot --path . --resolution 1600x900 --script res://tests/report_capture.gd -- <out dir> [ids|last|all] [--from=<reports dir>]
## ids: report ids, comma-separated (default `last`). Boots each report's
## scene once (an area at the report's seed), stands the player where you
## stood, turns the camera as you had it, and writes <id>.png and prints the
## frame's draw calls and GPU time.

func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var args: PackedStringArray = []
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--from="):
			ReportTool.folder_override = a.trim_prefix("--from=")
		# --recipe=<area>:<draft name>: the Strata Board's Walk this seed on a draft copy.
		if a.begins_with("--recipe="):
			var parts: PackedStringArray = a.trim_prefix("--recipe=").split(":")
			var ws: Node = root.get_node_or_null("/root/WorldState")
			ws.set("walk_area", parts[0])
			ws.set("walk_recipe", "res://gen/recipes/drafts/%s/%s.tres" % [parts[0], parts[1]])
		if not a.begins_with("--"):
			args.append(a)
	var out_dir: String = args[0] if args.size() > 0 else "user://report_capture"
	var pick: String = args[1] if args.size() > 1 else "last"
	DirAccess.make_dir_recursive_absolute(out_dir)
	var all: Array[Dictionary] = ReportTool.read_all()
	var chosen: Array[Dictionary] = []
	if pick == "all":
		chosen = all
	elif pick == "last":
		if not all.is_empty():
			chosen = [all[-1]]
	else:
		var ids: PackedStringArray = pick.split(",")
		chosen.assign(all.filter(func(r: Dictionary) -> bool: return ids.has(str(r.get("id", "")))))
	if chosen.is_empty():
		print("report_capture: no reports to take (%d in %s)" % [all.size(), ReportTool.folder() + ReportTool.LOG_NAME])
		quit(1)
		return
	# One boot per scene and seed.
	var groups: Dictionary = {}
	for r: Dictionary in chosen:
		var key: String = "%s@%s" % [r.get("scene", "camp"), r.get("seed", -1)]
		if not groups.has(key):
			groups[key] = []
		(groups[key] as Array).append(r)
	var main_script: GDScript = load("res://scripts/main.gd")
	var vp_rid: RID = root.get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp_rid, true)
	for key: String in groups:
		var first: Dictionary = (groups[key] as Array)[0]
		main_script.room_override = str(first.get("scene", "camp"))
		Area.seed_override = int(first.get("seed", -1))
		var game: Node = (load("res://main.tscn") as PackedScene).instantiate()
		root.add_child(game)
		game.hud.toast_time = 0
		game.hud.visible = false
		game.stats.visible = false
		game.player.blocked = true
		game.player.set_physics_process(false)
		for r: Dictionary in groups[key]:
			var feet: Array = r["feet"]
			# In the place's own frame (phase 9: you may have walked into it
			# from another, which put it off the origin), then where this
			# boot put it.
			var to_here: Transform3D = (game.world as Node3D).global_transform * place_of(r).affine_inverse()
			game.player.global_position = to_here * Vector3(feet[0], feet[1], feet[2])
			game.player.rotation.y = deg_to_rad(float(r["yaw_deg"])) + to_here.basis.get_euler().y
			game.player.camera.rotation.x = deg_to_rad(float(r["pitch_deg"]))
			game.player.camera.fov = float(r.get("fov", 74.0))
			# --bright: a work light on the camera, to see what's in a dark spot.
			if OS.get_cmdline_user_args().has("--bright") and game.player.camera.get_node_or_null("WorkLight") == null:
				var wl := OmniLight3D.new()
				wl.name = "WorkLight"
				wl.omni_range = 40.0
				wl.light_energy = 4.0
				wl.omni_attenuation = 0.4
				game.player.camera.add_child(wl)
			# --hide=<part of a mesh name>: hide those meshes (which one is that?).
			for ua: String in OS.get_cmdline_user_args():
				if ua.begins_with("--hide="):
					for part: String in ua.trim_prefix("--hide=").split("+"):
						for hn: Node in root.find_children("*" + part + "*", "MeshInstance3D", true, false):
							(hn as MeshInstance3D).visible = false
			for _i: int in 90:
				await process_frame
			var streamer: Variant = game.world.get("streamer") if game.world != null else null
			while streamer != null and streamer.busy():
				await process_frame
			for _i: int in 20:
				await process_frame
			await RenderingServer.frame_post_draw
			var path: String = "%s/%s.png" % [out_dir, r["id"]]
			root.get_viewport().get_texture().get_image().save_png(path)
			# --burst=N: N more frames a sixth of a second apart (is the water running?).
			for ua: String in OS.get_cmdline_user_args():
				if ua.begins_with("--burst="):
					for bi: int in int(ua.trim_prefix("--burst=")):
						for _j: int in 10:
							await process_frame
						await RenderingServer.frame_post_draw
						root.get_viewport().get_texture().get_image().save_png("%s/%s_b%d.png" % [out_dir, r["id"], bi + 1])
			# --lights: what lights the spot (hall rework step 1, your walk's dark corner).
			if OS.get_cmdline_user_args().has("--lights"):
				var eye: Vector3 = game.player.camera.global_position
				var near: Array = []
				for n: Node in root.find_children("*", "Light3D", true, false):
					var l := n as Light3D
					var d: float = l.global_position.distance_to(eye)
					if d < 12.0:
						near.append([d, l])
				near.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
				var env: Environment = root.get_viewport().world_3d.environment if root.get_viewport().world_3d != null else null
				print("    ambient %s x %.2f; %d lights within 12 m:" % [env.ambient_light_color if env != null else "?", env.ambient_light_energy if env != null else -1.0, near.size()])
				for e: Array in near:
					var l: Light3D = e[1]
					print("      %5.1f m  %-12s on %-5s energy %.2f  state %s  %s" % [e[0], str(l.get_meta("light_profile", l.get_class())), l.is_visible_in_tree(), l.light_energy, l.get_meta("lamp_state", "-"), l.get_parent().get_parent().name])
			# --what: name the meshes in front of the camera (what is that thing?).
			if OS.get_cmdline_user_args().has("--what"):
				var cam: Camera3D = game.player.camera
				for rn: Node in root.find_children("terraces_*", "Node3D", true, false):
					print("      eye in %s: %s" % [rn.name, (rn as Node3D).to_local(cam.global_position)])
				var seen: Dictionary = {}
				for n: Node in root.find_children("*", "MeshInstance3D", true, false):
					var mi := n as MeshInstance3D
					if not mi.is_visible_in_tree():
						continue
					var c: Vector3 = mi.global_transform * mi.get_aabb().get_center()
					var d: float = c.distance_to(cam.global_position)
					# On the view ray (what the crosshair is on), whatever its size.
					var fwd: Vector3 = -cam.global_transform.basis.z
					for ua: String in OS.get_cmdline_user_args():
						if ua.begins_with("--at="):
							var xy: PackedStringArray = ua.trim_prefix("--at=").split(",")
							fwd = cam.project_ray_normal(Vector2(float(xy[0]), float(xy[1])))
					var box: AABB = mi.global_transform * mi.get_aabb()
					if d > 30.0 or box.grow(0.05).intersects_ray(cam.global_position, fwd) == null:
						continue
					var mkey: String = "%s/%s" % [mi.get_parent().name, mi.name]
					if not seen.has(mkey):
						seen[mkey] = true
						var mat: Material = mi.get_active_material(0)
						print("      %5.1f m  %s  mat %s" % [d, str(mi.get_path()).right(90), mat.resource_name if mat != null else "-"])
			print("  %s: %s at %s \"%s\": draw calls %d, triangles %.2f M, gpu %.2f ms -> %s" % [r["id"], r.get("scene", ""), feet, r.get("note", ""),
				Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000000.0,
				RenderingServer.viewport_get_measured_render_time_gpu(vp_rid), path])
		game.queue_free()
		for _i: int in 3:
			await process_frame
	main_script.room_override = ""
	Area.seed_override = -1
	quit()


## Where the place you were in stood when you reported (the origin for
## reports from before phase 9 step 3, which didn't record it).
static func place_of(r: Dictionary) -> Transform3D:
	var p: Array = r.get("place", [])
	if p.size() != 4:
		return Transform3D()
	var v: Callable = func(a: Array) -> Vector3: return Vector3(a[0], a[1], a[2])
	return Transform3D(Basis(v.call(p[0]), v.call(p[1]), v.call(p[2])), v.call(p[3]))

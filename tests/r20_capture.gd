extends SceneTree
## GPU pictures of the R20 Lake Landing (phase 18) in the real game
## (rooms/lake/landing.tscn). Needs a display, not --headless; run
## `godot --headless --import` first.
##   godot --path . --resolution 1920x1080 --script res://tests/r20_capture.gd -- <out dir> [world seed] [view,view,...]
## Writes r20_<seed>_<view>.png and prints, per view, draw calls, triangles,
## GPU time and the lights in reach.

const SCENE: String = "res://rooms/lake/landing.tscn"


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var args: PackedStringArray = []
	for a: String in OS.get_cmdline_user_args():
		if not a.begins_with("--"):
			args.append(a)
	var out_dir: String = args[0] if args.size() > 0 else "user://r20"
	var world_seed: int = int(args[1]) if args.size() > 1 else 1
	var only: PackedStringArray = args[2].split(",") if args.size() > 2 else PackedStringArray()
	DirAccess.make_dir_recursive_absolute(out_dir)
	var ws: Node = root.get_node_or_null("/root/WorldState")
	ws.data["world_seed"] = world_seed
	ws.data.erase("lake")
	var main_script: GDScript = load("res://scripts/main.gd")
	main_script.room_override = SCENE
	var game: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	game.hud.toast_time = 0
	game.hud.visible = false
	game.stats.visible = false
	game.player.blocked = true
	game.player.set_physics_process(false)
	var room: Node3D = game.world
	var eye := Vector3(0, 1.6, 0)
	var views: Dictionary = {
		"passage": [Vector3(0, 0, -2.5) + eye, Vector3(0, 1.0, -40)],
		"arrive": [Vector3(0, 0, -9.5) + eye, Vector3(6, -0.5, -60)],
		"steps": [Vector3(0, 0, -11.0) + eye, Vector3(0, -1.2, -22)],
		"across": [Vector3(0, -1.65, -17.6) + eye, Vector3(0, 2.0, -150)],
		"pier": [Vector3(8, 0, -17.0) + eye, Vector3(8, 0.5, -48)],
		"head": [Vector3(8, -0.9, -39.8) + eye, Vector3(40, 3.0, -140)],
		"harbour": [Vector3(8.0, 0, -26.0) + eye, Vector3(-14, 1.0, -13)],
		"boardwalk": [Vector3(-4.6, 0, -9.0) + eye, Vector3(-18, 1.2, -9.4)],
		"boathouse": [Vector3(-11.4, 0, -10.8) + eye, Vector3(-9.0, -0.6, -17.5)],
		"back": [Vector3(8, -0.9, -40.5) + eye, Vector3(0, 0.5, -8)],
		"out": [Vector3(10, 1.4, -70), Vector3(2, 0.5, -15)],
		"mid": [Vector3(0, 1.6, -80), Vector3(40, 3.0, -144)],
		"high": [Vector3(28, 16, -14), Vector3(-4, -1, -85)],
		"roof": [Vector3(0, 2.0, -60), Vector3(-10, 30.0, -95)],
	}
	for id: String in LakeLayout.LANDINGS:
		var f: Transform3D = LakeLayout.landing_frame(id)
		var out: Vector3 = -f.basis.z
		views["to_" + id] = [f.origin + out * 26.0 + Vector3(0, 1.2, 0), f.origin + Vector3(0, 4.0, 0)]
		if bool(LakeLayout.LANDINGS[id][3]):
			views["on_" + id] = [f * Vector3(1.5, 0, -3.6) + eye, f * Vector3(0, 2.0, 0)]
			views["from_" + id] = [f * Vector3(0, 0, -2.0) + eye, Vector3(4, 1.0, -20)]
	for id: String in LakeLayout.GROTTOS:
		var g: Transform3D = LakeLayout.landing_frame(id)
		var gy: float = float(LakeLayout.GROTTOS[id])
		views["in_" + id] = [g * Vector3(0.8, gy, -1.5) + eye, g * Vector3(0.0, gy + 1.6, LakeLayout.GROTTO_BACK)]
	views["lit_channel"] = [Vector3(8, -0.9, -40.0) + eye, Vector3(14, 1.0, -74)]
	views["dark_channel"] = [Vector3(-12, 0.4, -24) , Vector3(-36, 0.0, -50)]
	views["back_at_quay"] = [Vector3(4, 0.6, -50), Vector3(-2, 2.0, -10)]
	views["west"] = [Vector3(8, 0.0, -30) + eye, Vector3(-30, 2.0, -36)]
	views["terrace"] = [Vector3(8.6, 0, -13.2) + eye, Vector3(13.5, 0.3, -10.0)]
	var ferry: LakeFerry = room.get_node("Ferry") as LakeFerry
	var deck: Transform3D = ferry.body.global_transform
	views["deck"] = [deck * Vector3(-0.6, 0.3, 2.4) + eye, deck * Vector3(0.0, 1.2, -12.0)]
	views["ferry"] = [Vector3(4.0, 0, -38.2) + eye, deck.origin + Vector3(0, 1.0, 0)]
	var vp_rid: RID = root.get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp_rid, true)
	var lights: Array[Light3D] = []
	for l: Node in room.find_children("*", "Light3D", true, false):
		if (l as Light3D).visible:
			lights.append(l as Light3D)
	var shadowed: int = lights.filter(func(l: Light3D) -> bool: return l.shadow_enabled).size()
	print("r20_capture: world seed %d, %d lights (%d shadowed)" % [world_seed, lights.size(), shadowed])
	for _i: int in 5:      # the place settles (the ferry docks on its second frame)
		await process_frame
	for view: String in views:
		if not only.is_empty() and not only.has(view):
			continue
		var v: Array = views[view]
		if view == "deck" or view == "ferry":      # framed now: the ferry docks after the place is ready
			var dk: Transform3D = ferry.body.global_transform
			v = [dk * Vector3(-0.6, 0.3, 2.4) + eye, dk * Vector3(0.0, 1.2, -12.0)] if view == "deck" \
				else [dk * Vector3(-4.5, 1.6, 3.0), dk.origin + Vector3(0, 1.0, 0)]
		game.player.global_position = (v[0] as Vector3) - Vector3(0, game.player.camera.position.y, 0)
		game.look_toward(v[1])
		for _i: int in 100:
			await process_frame
		await RenderingServer.frame_post_draw
		var cam: Vector3 = game.player.camera.global_position
		var reach: int = 0
		for l: Light3D in lights:
			if l.is_visible_in_tree() and l.global_position.distance_to(cam) < LakeLife.FADE_BEGIN + LakeLife.FADE_LENGTH:
				reach += 1
		var total: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		var tris: int = RenderingServer.viewport_get_render_info(vp_rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)
		var path: String = "%s/r20_%d_%s.png" % [out_dir, world_seed, view]
		root.get_viewport().get_texture().get_image().save_png(path)
		print("  %s: draw calls %d; triangles %d k; gpu %.2f ms; lights in reach %d -> %s" % [view, total, tris / 1000,
			RenderingServer.viewport_get_measured_render_time_gpu(vp_rid), reach, path])
	main_script.room_override = ""
	quit()

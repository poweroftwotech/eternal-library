extends SceneTree
## What residents cost to draw and to animate (phase 21 step 1): the frame
## with none, then with COUNT of them walking on the spot in view. Needs a
## display, not --headless; run `godot --headless --import` first, and pass
## --audio-driver Dummy.
##   godot --path . --resolution 1920x1080 --audio-driver Dummy --script res://tests/resident_cost.gd -- [place] [--count=N] [--no-shadows]
## Prints, for each case, the viewport's measured CPU and GPU render time,
## the whole frame by the clock (vsync off), draw calls and triangles,
## averaged over FRAMES frames, and the difference a person makes.

const FRAMES: int = 240
const SETTLE: int = 90


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var place: String = "camp"
	var count: int = 20
	var shadows: bool = true
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--count="):
			count = a.trim_prefix("--count=").to_int()
		elif a == "--no-shadows":
			shadows = false
		else:
			place = a
	var main_script: GDScript = load("res://scripts/main.gd")
	main_script.room_override = place
	var game: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	game.hud.toast_time = 0
	game.player.blocked = true
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	for _i: int in 120:
		await process_frame
	var cam: Camera3D = game.player.camera
	var fwd: Vector3 = -cam.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var right: Vector3 = fwd.cross(Vector3.UP).normalized()
	var none: Dictionary = await _measure()
	var ids: Array = ResidentBody.OUTFITS.keys()
	var people: Array[ResidentBody] = []
	var per_row: int = 5
	for i: int in count:
		var body: ResidentBody = ResidentBody.dressed(str(ids[i % ids.size()]), i)
		game.world.add_child(body)
		@warning_ignore("integer_division")
		body.global_position = game.player.global_position + fwd * (3.0 + (i / per_row) * 1.4) + right * ((i % per_row) - (per_row - 1) * 0.5) * 1.1
		body.look_at(body.global_position - fwd, Vector3.UP)
		body.play("walk", 0.0, i * 0.13)
		if not shadows:
			for piece: String in body.pieces:
				(body.pieces[piece] as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		people.append(body)
	var with: Dictionary = await _measure()
	print("resident_cost: %s, %d people walking in view, shadows %s" % [place, count, "on" if shadows else "off"])
	print("                 cpu ms   gpu ms     frame ms   draw calls   triangles")
	for row: Array in [["none", none], ["with people", with]]:
		var m: Dictionary = row[1]
		print("  %-13s %7.2f  %7.2f   %9.2f   %10d   %9d" % [row[0], m["cpu"], m["gpu"], m["process"], m["draws"], m["tris"]])
	print("  each person:  %7.3f  %7.3f   %9.3f   %10.1f   %9d" % [(with["cpu"] - none["cpu"]) / count, (with["gpu"] - none["gpu"]) / count,
			(with["process"] - none["process"]) / count, float(with["draws"] - none["draws"]) / count, int((with["tris"] - none["tris"]) / count)])
	main_script.room_override = ""
	quit()


func _measure() -> Dictionary:
	for _i: int in SETTLE:
		await process_frame
	var vp: RID = root.get_viewport_rid()
	var cpu: float = 0.0
	var gpu: float = 0.0
	var process: float = 0.0
	var began: int = Time.get_ticks_usec()
	var draws: int = 0
	var tris: int = 0
	for _i: int in FRAMES:
		await process_frame
		cpu += RenderingServer.viewport_get_measured_render_time_cpu(vp) + RenderingServer.get_frame_setup_time_cpu()
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
		draws += int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
		tris += int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
	process = (Time.get_ticks_usec() - began) / 1000.0
	return {"cpu": cpu / FRAMES, "gpu": gpu / FRAMES, "process": process / FRAMES, "draws": draws / FRAMES, "tris": tris / FRAMES}

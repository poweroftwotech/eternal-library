extends SceneTree
## Pictures of the cat (phase 19 step 3), standing still in the real game for
## the look before it walks. Needs a display, not --headless; run `godot
## --headless --import` first, and pass --audio-driver Dummy.
##   godot --path . --resolution 1600x900 --audio-driver Dummy --script res://tests/cat_capture.gd -- <out dir> [place] [--ahead=M] [--turn=DEG]
## place: camp (default), a scene path or area:<id>. Six cats in a row in
## front of the player's spawn, each a pose and a coat; writes row.png (all),
## <pose>.png (each close, from the side and from the front three-quarter) and
## walk_0..3.png (one cat through its walk cycle, side on).

const POSES: Array = [["idle", 0.6], ["sit", 1.0], ["wash", 0.35], ["sleep", 1.0], ["walk", 0.3], ["startle", 0.42]]


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var out_dir: String = "user://cat_capture"
	var place: String = "camp"
	var ahead: float = 2.2
	var turn: float = 0.0
	var first: bool = true
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--ahead="):
			ahead = a.trim_prefix("--ahead=").to_float()
		elif a.begins_with("--turn="):
			turn = deg_to_rad(a.trim_prefix("--turn=").to_float())
		elif first:
			out_dir = a
			first = false
		else:
			place = a
	DirAccess.make_dir_recursive_absolute(out_dir)
	var main_script: GDScript = load("res://scripts/main.gd")
	main_script.room_override = place
	var game: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	game.hud.toast_time = 0
	game.hud.visible = false
	game.stats.visible = false
	game.player.blocked = true
	for _i: int in 60:
		await process_frame
	var cam: Camera3D = game.player.camera
	var fwd: Vector3 = -cam.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized().rotated(Vector3.UP, turn)
	var right: Vector3 = fwd.cross(Vector3.UP).normalized()
	var base: Vector3 = game.player.global_position + fwd * ahead
	var space: PhysicsDirectSpaceState3D = cam.get_world_3d().direct_space_state
	var cats: Array[CatBody] = []
	for i: int in POSES.size():
		var c := CatBody.new()
		game.world.add_child(c)
		var p: Vector3 = _floor(space, base + right * (i - (POSES.size() - 1) * 0.5) * 0.6)
		c.global_position = p
		# Side on to the camera, alternating which way they face.
		c.look_at(p + right * (1.0 if i % 2 == 0 else -1.0), Vector3.UP)
		c.set_coat([0, 1, 3, 2, 4, 5][i])     # the sleeper pale, so it shows in the shade
		c.hold(str(POSES[i][0]), float(POSES[i][1]))
		cats.append(c)
	await _shot(cam, base - fwd * 2.4 + Vector3(0, 0.75, 0), base + Vector3(0, 0.15, 0), 50.0, out_dir + "/row.png")
	for i: int in cats.size():
		var c: CatBody = cats[i]
		var at: Vector3 = c.global_position + Vector3(0, 0.18, 0)
		await _shot(cam, at - fwd * 1.0 + Vector3(0, 0.12, 0), at, 40.0, "%s/%s_side.png" % [out_dir, POSES[i][0]])
		var fq: Vector3 = (-c.global_basis.z * 0.7 - fwd * 0.6).normalized()
		await _shot(cam, at + fq * 0.95 + Vector3(0, 0.2, 0), at, 40.0, "%s/%s_front.png" % [out_dir, POSES[i][0]])
		# As the player sees it: standing height, looking down; and from behind.
		await _shot(cam, at - fwd * 1.3 + fq * 0.5 + Vector3(0, 1.4, 0), at, 30.0, "%s/%s_above.png" % [out_dir, POSES[i][0]])
		await _shot(cam, at - fq * 0.95 + Vector3(0, 0.25, 0), at, 40.0, "%s/%s_back.png" % [out_dir, POSES[i][0]])
	# The face, close: straight on and three-quarter (standing cats).
	for i: int in [0, 1, 4]:
		for o: CatBody in cats:
			o.visible = o == cats[i]
		var c: CatBody = cats[i]
		var ahead_c: Vector3 = -c.global_basis.z
		var face: Vector3 = c.global_position + ahead_c * 0.23 + Vector3(0, 0.275, 0)
		await _shot(cam, face + ahead_c * 0.42 + Vector3(0, 0.03, 0), face, 35.0, "%s/face_%d.png" % [out_dir, i])
		await _shot(cam, face + (ahead_c * 0.8 - fwd * 0.6).normalized() * 0.45 + Vector3(0, 0.1, 0), face, 35.0, "%s/face_%d_q.png" % [out_dir, i])
		await _shot(cam, face - fwd * 0.45 + Vector3(0, 0.02, 0), face - ahead_c * 0.03, 35.0, "%s/face_%d_s.png" % [out_dir, i])
	for o: CatBody in cats:
		o.visible = true
	var walker: CatBody = cats[4]
	for k: int in 4:
		walker.hold("walk", k * 0.25)
		var at: Vector3 = walker.global_position + Vector3(0, 0.16, 0)
		await _shot(cam, at - fwd * 0.95 + Vector3(0, 0.05, 0), at, 40.0, "%s/walk_%d.png" % [out_dir, k])
	print("cat_capture: %d cats at %s -> %s" % [cats.size(), base.snapped(Vector3.ONE * 0.1), out_dir])
	main_script.room_override = ""
	quit()


func _floor(space: PhysicsDirectSpaceState3D, p: Vector3) -> Vector3:
	var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, 1.5, 0), p - Vector3(0, 3.0, 0), 1)
	var hit: Dictionary = space.intersect_ray(q)
	return hit["position"] if not hit.is_empty() else p


func _shot(cam: Camera3D, eye: Vector3, at: Vector3, fov: float, path: String) -> void:
	cam.global_position = eye
	cam.look_at(at, Vector3.UP)
	cam.fov = fov
	for _i: int in 20:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(path)

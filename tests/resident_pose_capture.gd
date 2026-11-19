extends SceneTree
## Pictures of the residents' poses (phase 21 step 1): walking, sitting on a
## bench, cross-legged, kneeling, asleep, in short and long dress. Needs a
## display, not --headless; run `godot --headless --import` first, and pass
## --audio-driver Dummy.
##   godot --path . --resolution 1600x900 --audio-driver Dummy --script res://tests/resident_pose_capture.gd -- <out dir> [place] [--ahead=M] [--turn=DEG]
## A row in front of the player's spawn, each person a pose held still, with
## one plain lamp. Writes poses.png (the row), poses_side.png, poses_above.png
## and <n>_<outfit>_<pose>.png for each (front quarter and side).

const ROW: Array = [["lane_coat", "walk", 0.27], ["house_dress", "walk", 0.8], ["merchant", "sit_bench", 1.0], ["bazaar_gown", "sit_bench", 1.0],
		["hunter", "sit_floor", 1.0], ["copyist", "sit_floor", 1.0], ["scholar", "sit_knees", 1.0], ["house_dress", "sit_knees", 1.0], ["lane_coat", "sleep", 1.0]]
## The work poses (step 4), with `--row=work`.
const WORK_ROW: Array = [["scholar", "read_knees", 3.3], ["copyist", "read_floor", 1.0], ["hunter", "mend_floor", 1.0], ["house_dress", "stir", 0.5],
		["house_dress", "dip", 3.0], ["merchant", "weigh", 2.2], ["lamp_tender", "reach", 1.0], ["lane_coat", "eat_floor", 1.25], ["bazaar_gown", "eat_bench", 1.25],
		["house_dress", "walk_carry", 0.27]]
const SPACING: float = 1.15

var row: Array = ROW


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var out_dir: String = "user://resident_poses"
	var place: String = "camp"
	var ahead: float = 3.6
	var turn: float = 0.0
	var first: bool = true
	for a: String in OS.get_cmdline_user_args():
		if a == "--row=work":
			row = WORK_ROW
		elif a.begins_with("--ahead="):
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
	var people: Array[ResidentBody] = []
	for i: int in row.size():
		var p: Vector3 = _floor(space, base + right * (i - (row.size() - 1) * 0.5) * SPACING)
		var r: ResidentBody = ResidentBody.dressed(row[i][0], i)
		game.world.add_child(r)
		r.global_position = p
		var pose: String = row[i][1]
		# Walkers go along the row, sitters face the camera, sleepers lie across it.
		var face: Vector3 = right if pose == "walk" else (-fwd if pose != "sleep" else right)
		r.look_at(p + face, Vector3.UP)
		r.hold(pose, float(row[i][2]))
		people.append(r)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.86, 0.66)
	lamp.light_energy = 3.0
	lamp.omni_range = 11.0
	lamp.shadow_enabled = true
	game.world.add_child(lamp)
	lamp.global_position = base - fwd * 2.0 + Vector3(0, 2.8, 0) + right * 0.8
	var mid: Vector3 = base + Vector3(0, 0.7, 0)
	await _shot(cam, base - fwd * 6.2 + Vector3(0, 1.3, 0), mid, 55.0, out_dir + "/poses.png")
	await _shot(cam, base - fwd * 4.0 + Vector3(0, 3.6, 0), mid - Vector3(0, 0.4, 0), 70.0, out_dir + "/poses_above.png")
	await _shot(cam, base - fwd * 4.6 - right * 4.6 + Vector3(0, 1.4, 0), mid, 60.0, out_dir + "/poses_side.png")
	for i: int in people.size():
		var r: ResidentBody = people[i]
		for o: ResidentBody in people:
			o.visible = o == r
		var at: Vector3 = r.global_position + Vector3(0, 0.6, 0)
		var name: String = "%d_%s_%s" % [i, row[i][0], row[i][1]]
		await _shot(cam, at - fwd * 2.6 + right * 1.2 + Vector3(0, 0.7, 0), at, 45.0, "%s/%s.png" % [out_dir, name])
		await _shot(cam, at + right * 2.8 + Vector3(0, 0.3, 0), at, 45.0, "%s/%s_side.png" % [out_dir, name])
	print("resident_pose_capture: %d people at %s -> %s" % [people.size(), base.snapped(Vector3.ONE * 0.1), out_dir])
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

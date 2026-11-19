extends SceneTree
## Pictures of the residents' bodies (phase 21 step 1), standing still in the
## real game beside today's statues, for the look before they move. Needs a
## display, not --headless; run `godot --headless --import` first, and pass
## --audio-driver Dummy.
##   godot --path . --resolution 1600x900 --audio-driver Dummy --script res://tests/resident_capture.gd -- <out dir> [place] [--ahead=M] [--turn=DEG] [--light]
## place: camp (default), a scene path or area:<id>. A row in front of the
## player's spawn: a statue, three men, three women, a statue. Writes row.png,
## row_eye.png (from where you stand), and for the first man and woman
## front, side, back, quarter and face pictures. --light adds a plain lamp
## over the row (a dark place).

const STATUES: PackedStringArray = ["res://kit/modules/walls/qt_fig_stand.tscn", "res://kit/modules/walls/bz_keeper_a.tscn"]
const SPACING: float = 0.82


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var out_dir: String = "user://resident_capture"
	var place: String = "camp"
	var ahead: float = 3.0
	var turn: float = 0.0
	var light: bool = false
	var first: bool = true
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--ahead="):
			ahead = a.trim_prefix("--ahead=").to_float()
		elif a.begins_with("--turn="):
			turn = deg_to_rad(a.trim_prefix("--turn=").to_float())
		elif a == "--light":
			light = true
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
	var eye: Vector3 = cam.global_position
	var fwd: Vector3 = -cam.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized().rotated(Vector3.UP, turn)
	var right: Vector3 = fwd.cross(Vector3.UP).normalized()
	var base: Vector3 = game.player.global_position + fwd * ahead - fwd.cross(Vector3.UP).normalized() * 0.7
	var space: PhysicsDirectSpaceState3D = cam.get_world_3d().direct_space_state
	# The row: statue, men, women, statue; everyone faces the camera.
	var row: Array = [["lane_coat", 0], ["scholar", 1], ["merchant", 2], ["hunter", 3], ["lamp_tender", 0],
			["house_dress", 0], ["keeper", 4], ["bazaar_gown", 2], ["copyist", 1]]
	var people: Array[ResidentBody] = []
	var statues: Array[Node3D] = []
	for i: int in row.size():
		var p: Vector3 = _floor(space, base + right * (i - (row.size() - 1) * 0.5) * SPACING)
		var node: Node3D
		if row[i] is String:
			node = (load(row[i]) as PackedScene).instantiate() as Node3D
			game.world.add_child(node)
			node.global_position = p
			# The statues face their own +Z.
			node.look_at(p + fwd, Vector3.UP)
			statues.append(node)
		else:
			var r: ResidentBody = ResidentBody.dressed(row[i][0], row[i][1])
			game.world.add_child(r)
			r.global_position = p
			r.look_at(p - fwd, Vector3.UP)
			r.hold("idle", 0.3 * i)
			people.append(r)
			node = r
	var lamp: OmniLight3D = null
	if light:
		lamp = OmniLight3D.new()
		lamp.light_color = Color(1.0, 0.86, 0.66)
		lamp.light_energy = 3.0
		lamp.omni_range = 9.0
		lamp.shadow_enabled = true
		game.world.add_child(lamp)
		lamp.global_position = base - fwd * 1.6 + Vector3(0, 2.6, 0) + right * 0.8
	var mid: Vector3 = base + Vector3(0, 0.9, 0)
	await _shot(cam, base - fwd * 4.6 + Vector3(0, 1.2, 0), mid, 50.0, out_dir + "/row.png")
	await _shot(cam, eye, mid + Vector3(0, 0.3, 0), 70.0, out_dir + "/row_eye.png")
	await _shot(cam, base - fwd * 2.6 - right * 2.0 + Vector3(0, 1.3, 0), mid - right * 1.2, 50.0, out_dir + "/row_left.png")
	await _shot(cam, base - fwd * 2.6 + right * 2.0 + Vector3(0, 1.3, 0), mid + right * 1.2, 50.0, out_dir + "/row_right.png")
	for st: Node3D in statues:
		st.visible = false
	# From behind, and with the lamp out (what the glow thread gives).
	await _shot(cam, base + fwd * 4.6 + Vector3(0, 1.2, 0), mid, 50.0, out_dir + "/row_back.png")
	if lamp != null:
		lamp.visible = false
		await _shot(cam, base - fwd * 4.6 + Vector3(0, 1.2, 0), mid, 50.0, out_dir + "/row_dark.png")
		lamp.visible = true
	for i: int in people.size():
		var r: ResidentBody = people[i]
		var who: String = r.outfit
		for o: ResidentBody in people:
			o.visible = o == r
		var at: Vector3 = r.global_position + Vector3(0, 0.88, 0)
		var f: Vector3 = -r.global_basis.z
		var s: Vector3 = r.global_basis.x
		await _shot(cam, at + f * 2.5, at, 40.0, "%s/%s_front.png" % [out_dir, who])
		await _shot(cam, at + (f + s * 0.8).normalized() * 2.5 + Vector3(0, 0.4, 0), at, 40.0, "%s/%s_quarter.png" % [out_dir, who])
		await _shot(cam, at - (f + s * 0.6).normalized() * 2.5 + Vector3(0, 0.4, 0), at, 40.0, "%s/%s_back.png" % [out_dir, who])
		var head: Vector3 = r.global_position + Vector3(0, 1.6 * r.skeleton.get_bone_global_rest(r.skeleton.find_bone("head")).origin.y / 1.535, 0)
		await _shot(cam, head + (f + s * 0.5).normalized() * 0.8, head, 35.0, "%s/%s_face.png" % [out_dir, who])
	print("resident_capture: %d people at %s -> %s" % [people.size(), base.snapped(Vector3.ONE * 0.1), out_dir])
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

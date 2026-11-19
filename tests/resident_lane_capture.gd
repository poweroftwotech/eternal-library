extends SceneTree
## Pictures of the residents' test lane through a day (phase 21 step 2): the
## family's home at several bells, from inside and from the lane. Needs a
## display, not --headless; run `godot --headless --import` first, and pass
## --audio-driver Dummy.
##   godot --path . --resolution 1600x900 --audio-driver Dummy --script res://tests/resident_lane_capture.gd -- <out dir>
## Writes <when>_in.png (from just inside the door, to the back), <when>_back.png
## (the back room), <when>_lane.png (the door from the lane), with labels on.

const DRAFT: String = "res://gen/recipes/drafts/mahaleh/lane_test.tres"
## [name, bells since the first]
const WHEN: Array = [["1_cooking", 0.4], ["2_eating", 0.9], ["3_free", 1.7], ["4_door", 4.9], ["5_asleep", 5.5]]


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var out_dir: String = "user://resident_lane"
	for a: String in OS.get_cmdline_user_args():
		out_dir = a
	DirAccess.make_dir_recursive_absolute(out_dir)
	var ws: Node = root.get_node_or_null("/root/WorldState")
	ws.set("walk_area", "mahaleh")
	ws.set("walk_recipe", DRAFT)
	var main_script: GDScript = load("res://scripts/main.gd")
	main_script.room_override = "area:mahaleh"
	Area.seed_override = 1
	var game: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	current_scene = game
	game.hud.toast_time = 0
	game.hud.visible = false
	game.stats.visible = false
	game.player.blocked = true
	game.player.set_physics_process(false)
	for _i: int in 60:
		await process_frame
	var area: Area = game.world
	while area.streamer.busy():
		await process_frame
	for _i: int in 20:
		await process_frame
	var residents: Residents = get_first_node_in_group(Residents.GROUP) as Residents
	if residents == null or residents.households.is_empty():
		print("resident_lane_capture: nobody lives on the lane")
		quit(1)
		return
	residents.labels = true
	var h: Dictionary = residents.households[0]
	var spine: PackedVector3Array = (h["members"][0] as Resident).home["spine"]
	var cam: Camera3D = game.player.camera
	var clock: DayClock = DayClock.it()
	clock.paused = true
	var up := Vector3(0, 1.55, 0)
	var into: Vector3 = (spine[1] - spine[0]).normalized()
	for w: Array in WHEN:
		clock.time = float(w[1]) * DayClock.BELL_S
		clock.speed = 60.0       # (fast enough that a walk is skipped: they are there)
		for _i: int in 3:
			residents.advance(0.1, clock)
		clock.speed = 1.0
		# The player stands out of the picture, where the camera is.
		game.player.global_position = spine[1]
		await _shot(cam, spine[1] + up, spine[spine.size() - 1] + Vector3(0, 0.7, 0), 80.0, "%s/%s_in.png" % [out_dir, w[0]])
		if spine.size() > 3:
			await _shot(cam, spine[3] - into * 0.6 + up, spine[spine.size() - 1] + into * 1.2 + Vector3(0, 0.5, 0), 85.0, "%s/%s_back.png" % [out_dir, w[0]])
		await _shot(cam, spine[0] - into * 3.2 + up, spine[1] + Vector3(0, 1.1, 0), 70.0, "%s/%s_lane.png" % [out_dir, w[0]])
		print("  %s: %s" % [w[0], " | ".join(residents.roll())])
	print("resident_lane_capture: %d people -> %s" % [residents.people.size(), out_dir])
	main_script.room_override = ""
	quit()


func _shot(cam: Camera3D, eye: Vector3, at: Vector3, fov: float, path: String) -> void:
	cam.global_position = eye
	cam.look_at(at, Vector3.UP)
	cam.fov = fov
	for _i: int in 40:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(path)

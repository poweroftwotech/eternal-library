extends SceneTree
## Pictures of the residents' test lane for phase 21 step 3: the square, the
## stall, the hauz and the homes at chosen bells, with the overlay on or off.
## Needs a display, not --headless; run `godot --headless --import` first.
##   godot --path . --resolution 1600x900 --audio-driver Dummy --script res://tests/resident_step3_capture.gd -- <out dir> [--overlay] [--only=<name>]
## Each shot: the clock is set, the day is run forward RUN_S (people walk
## where the hour sends them), and the picture taken.

const DRAFT: String = "res://gen/recipes/drafts/mahaleh/lane_test.tres"
## [name, bell, seconds run before the picture, eye, look at, fov, and for a
## picture of someone on their way: their trade and the bell their block begins]
const SHOTS: Array = [
	["square_morning", 0.14, 30.0, Vector3(2.6, 3.4, -11.6), Vector3(-4.5, 0.6, -15.0), 80.0],
	["stall", 1.5, 60.0, Vector3(-1.2, 1.7, -11.8), Vector3(-6.5, 0.9, -15.5), 75.0],
	["stall_side", 1.5, 0.0, Vector3(-3.6, 1.6, -18.6), Vector3(-6.2, 0.9, -15.0), 75.0],
	["hauz_evening", 4.7, 90.0, Vector3(2.4, 1.7, -17.6), Vector3(-2.4, 0.5, -14.0), 75.0],
	["water", 1.9, 45.0, Vector3(2.6, 1.6, -11.6), Vector3(-0.6, 0.4, -14.0), 70.0],
	["lane_walk", 1.86, 12.0, Vector3(3.0, 1.6, -10.0), Vector3(10.5, 1.0, -17.5), 70.0, "cook", 1.86],
	["out_of_the_door", 0.3, 4.5, Vector3(-4.2, 1.6, -11.2), Vector3(-7.0, 1.0, -8.6), 75.0, "scholar", 0.3],
	["scholar_home", 0.6, 30.0, Vector3(-7.2, 1.6, -7.1), Vector3(-5.6, 0.5, -5.3), 95.0],
	["hunter_home", 0.4, 30.0, Vector3(4.6, 1.6, -17.2), Vector3(6.3, 0.5, -18.6), 95.0],
	["scholar_night", 5.5, 30.0, Vector3(-5.2, 1.6, -7.0), Vector3(-7.1, 0.2, -5.4), 95.0],
	["above", 1.5, 0.0, Vector3(-2.0, 17.0, -13.9), Vector3(-2.0, 0.0, -14.0), 80.0],
]


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var out_dir: String = "user://resident_step3"
	var overlay: bool = false
	var only: String = ""
	for a: String in OS.get_cmdline_user_args():
		if a == "--overlay":
			overlay = true
		elif a.begins_with("--only="):
			only = a.trim_prefix("--only=")
		else:
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
	var residents: Residents = get_first_node_in_group(Residents.GROUP) as Residents
	for _i: int in 900:
		await process_frame
		if residents != null and residents.settled():
			break
	if residents == null or residents.households.is_empty():
		print("resident_step3_capture: nobody lives on the lane")
		quit(1)
		return
	residents.heed_player = false
	residents.labels = overlay
	residents.show_overlay(overlay)
	var cam: Camera3D = game.player.camera
	var clock: DayClock = DayClock.it()
	clock.paused = true
	for s: Array in SHOTS:
		if only != "" and not str(s[0]).begins_with(only):
			continue
		# Everyone to where the hour has them, then the day run on from there.
		clock.time = float(s[1]) * DayClock.BELL_S
		if s.size() > 6:
			# Timed to one person: a second before their own block at s[7] begins.
			for p: Resident in residents.people:
				if p.trade == str(s[6]):
					clock.time = (float(s[7]) + p.shift) * DayClock.BELL_S - 1.0
		clock.speed = 60.0
		for _i: int in 3:
			residents.advance(0.1, clock)
		clock.speed = 1.0
		var left: float = float(s[2])
		while left > 0.0:
			clock.time += 0.1
			residents.advance(0.1, clock)
			left -= 0.1
		game.player.global_position = (s[3] as Vector3) - Vector3(0, 1.5, 0)
		cam.global_position = s[3]
		cam.look_at(s[4], Vector3.UP if absf(((s[4] as Vector3) - (s[3] as Vector3)).normalized().y) < 0.98 else Vector3.FORWARD)
		cam.fov = float(s[5])
		for _i: int in 40:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png("%s/%s%s.png" % [out_dir, s[0], "_overlay" if overlay else ""])
		print("  %s: %s" % [s[0], " | ".join(residents.roll())])
	print("resident_step3_capture: %d people -> %s" % [residents.people.size(), out_dir])
	main_script.room_override = ""
	quit()

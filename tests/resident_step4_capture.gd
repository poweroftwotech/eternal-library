extends SceneTree
## Pictures for phase 21 step 4: each trade at its work on the test lane, the
## homes' beds on any seed, and the People panel's pages. Needs a display, not
## --headless; run `godot --headless --import` first.
##   godot --path . --resolution 1600x900 --audio-driver Dummy --script res://tests/resident_step4_capture.gd -- <out dir> [--seed=N] [--homes] [--panel] [--only=<name>]
## Default: a picture of each of SHOTS, the camera set in front of the person.
## --homes: each lived-in home at night (by day with --day) from its door and from its back, with
##          a plain light at the camera (so the beds can be judged).
## --panel: the panel's three pages.

const DRAFT: String = "res://gen/recipes/drafts/mahaleh/lane_test.tres"
## [name, trade, the activity whose block is begun, seconds run on, camera:
## metres in front of them, to their right, up]
const SHOTS: Array = [
	["cook_stirring", "cook", "cook", 85.0, 0.2, 1.9, 1.3],
	["cook_at_the_water", "cook", "water", 45.0, 2.2, 1.3, 1.1],
	["cook_carrying_home", "cook", "cook", 5.0, 2.6, 0.8, 1.3],
	["family_eating", "cook", "eat", 45.0, 2.3, -1.2, 1.5],
	["scholar_reading", "scholar", "work", 30.0, 1.7, 0.9, 1.1],
	["scholar_eating", "scholar", "eat", 30.0, 1.7, 0.9, 1.1],
	["hunter_mending", "hunter", "work", 40.0, 1.8, 0.9, 1.2],
	["keeper_weighing", "stall keeper", "keep", 60.0, 2.4, 0.4, 1.4],
	["shopping", "cook", "shop", 40.0, 2.6, 1.6, 1.4],
	["tender_at_a_lamp", "lamp tender", "tend", 30.0, -2.8, 1.7, 1.5],
	["tender_walking", "lamp tender", "tend", 4.0, 3.0, 0.6, 1.4],
	["hunter_leaving", "hunter", "away", 7.0, 2.8, 0.8, 1.4],
]


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var out_dir: String = "user://resident_step4"
	var only: String = ""
	var seed_value: int = 1
	var homes: bool = false
	var panel: bool = false
	var day: bool = false
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.trim_prefix("--only=")
		elif a.begins_with("--seed="):
			seed_value = a.trim_prefix("--seed=").to_int()
		elif a == "--homes":
			homes = true
		elif a == "--day":
			day = true
		elif a == "--panel":
			panel = true
		else:
			out_dir = a
	DirAccess.make_dir_recursive_absolute(out_dir)
	var ws: Node = root.get_node_or_null("/root/WorldState")
	ws.set("walk_area", "mahaleh")
	ws.set("walk_recipe", DRAFT)
	var main_script: GDScript = load("res://scripts/main.gd")
	main_script.room_override = "area:mahaleh"
	Area.seed_override = seed_value
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
		print("resident_step4_capture: nobody lives on the lane")
		quit(1)
		return
	residents.heed_player = false
	var cam: Camera3D = game.player.camera
	var clock: DayClock = DayClock.it()
	clock.paused = true
	print("resident_step4_capture: seed %d, %d people: %s" % [seed_value, residents.people.size(),
			", ".join(residents.people.map(func(p: Resident) -> String: return "%s (%s)" % [p.given_name, p.trade]))])
	if panel:
		_settle(residents, clock, 1.5 * DayClock.BELL_S)
		cam.global_position = Vector3(2.6, 1.7, -11.6)
		cam.look_at(Vector3(-4.5, 0.9, -15.0), Vector3.UP)
		residents.panel.set_open(true)
		var pages: TabContainer = residents.panel.find_children("*", "TabContainer", true, false)[0] as TabContainer
		for i: int in pages.get_tab_count():
			pages.current_tab = i
			if i == 2:
				(residents.panel.get("_trade") as OptionButton).select(0)
				residents.panel.call("_show_table")
			for _f: int in 30:
				await process_frame
			await RenderingServer.frame_post_draw
			root.get_viewport().get_texture().get_image().save_png("%s/panel_%d_%s.png" % [out_dir, i, pages.get_tab_title(i).to_lower().replace(" ", "_")])
	elif homes:
		var light := OmniLight3D.new()
		light.light_energy = 1.4
		light.omni_range = 9.0
		light.shadow_enabled = false
		cam.add_child(light)
		_settle(residents, clock, (2.5 if day else 5.6) * DayClock.BELL_S)
		for h: Dictionary in residents.households:
			var scan: Dictionary = ((h["members"] as Array)[0] as Resident).home
			var spine: PackedVector3Array = scan["spine"]
			var front: Vector3 = spine[1]
			var back: Vector3 = spine[spine.size() - 1]
			var into: Vector3 = (back - front).normalized()
			print("  home %d (%s): %d people, beds %d" % [h["index"], h["kind"], (h["members"] as Array).size(),
					(h["spots"] as Array).filter(func(s: Dictionary) -> bool: return s["kind"] == "sleep").size()])
			await _shot(cam, front - into * 0.3 + Vector3(0, 2.1, 0), back + Vector3(0, 0.2, 0), 100.0, "%s/seed%d_home%d_%s_in%s.png" % [out_dir, seed_value, h["index"], h["kind"], "_day" if day else ""])
			await _shot(cam, back + into * 0.9 + Vector3(0, 2.1, 0), front + Vector3(0, 0.1, 0), 100.0, "%s/seed%d_home%d_%s_back%s.png" % [out_dir, seed_value, h["index"], h["kind"], "_day" if day else ""])
	else:
		for s: Array in SHOTS:
			if only != "" and not str(s[0]).begins_with(only):
				continue
			var who: Resident = null
			for p: Resident in residents.people:
				if p.trade == str(s[1]):
					who = p
			if who == null:
				continue
			var at: float = 0.0
			for row: Array in who.blocks:
				if str(row[1]) == str(s[2]):
					at = (float(row[0]) + who.shift) * DayClock.BELL_S
					break
			_settle(residents, clock, at - 2.0)
			var left: float = float(s[3]) + 2.0
			while left > 0.0:
				clock.time += 0.1
				residents.advance(0.1, clock)
				left -= 0.1
			var facing: Vector3 = -who.global_basis.z
			var right: Vector3 = who.global_basis.x
			var eye: Vector3 = who.global_position + facing * float(s[4]) + right * float(s[5])
			eye.y = who.floor_y + float(s[6])
			await _shot(cam, eye, who.global_position + Vector3(0, 0.75 if who.walking or who.body.anim.current_animation in ["idle", "weigh", "reach"] else 0.45, 0), 60.0,
					"%s/%s.png" % [out_dir, s[0]])
			print("  %s: %s, %s, playing %s, holding '%s'" % [s[0], who.given_name, who.describe(clock.bells()).get_slice("\n", 0), who.body.anim.current_animation, who.body.holding])
	main_script.room_override = ""
	quit()


# Everyone to where `time` has them (walks skipped).
func _settle(residents: Residents, clock: DayClock, time: float) -> void:
	clock.time = fposmod(time, DayClock.DAY_S)
	clock.speed = 60.0
	for _i: int in 3:
		residents.advance(0.1, clock)
	clock.speed = 1.0


func _shot(cam: Camera3D, eye: Vector3, at: Vector3, fov: float, path: String) -> void:
	cam.global_position = eye
	cam.look_at(at, Vector3.UP)
	cam.fov = fov
	for _i: int in 40:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(path)

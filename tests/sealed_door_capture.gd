extends SceneTree
## Captures every sealed door of an area (sealed doors, 2026-11-02): the real
## game in the area, standing 3 m before each door facing it. Needs a display;
## run `godot --headless --import` first.
##   godot --path . --resolution 1600x900 --script res://tests/sealed_door_capture.gd -- <out_prefix> <area id> --area-seed=1 --save=user://test/sealed.json --fresh
## Writes <out_prefix>_<n>.png and prints which room each door is in.

var main_script: GDScript = load("res://scripts/main.gd")


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var args: Array = Array(OS.get_cmdline_user_args()).filter(func(a: String) -> bool: return not a.begins_with("--"))
	var prefix: String = args[0]
	main_script.room_override = "area:" + str(args[1])
	var game: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	current_scene = game
	game.hud.toast_time = 0
	game.stats.visible = false
	await _frames(30)
	var area := game.world as Area
	area.streamer.target = game.player
	var shot: int = 0
	for r: AreaPlan.Room in area.plan.rooms:
		game.player.teleport(area.global_transform * r.xf.origin + Vector3(0, 1, 0))
		var stop: int = Time.get_ticks_msec() + 30000
		while (not area.rooms.has(r.slot_id) or area.streamer.busy()) and Time.get_ticks_msec() < stop:
			await process_frame
		var room: Node = area.rooms.get(r.slot_id)
		if room == null:
			continue
		for d: Node in room.find_children("*", "Node3D", true, false):
			if not d is SealedDoor:
				continue
			var at: Transform3D = (d as Node3D).global_transform
			game.player.blocked = true
			game.player.teleport(at * Vector3(0, .1, 3.0), at.basis.get_euler().y, -0.05)
			await _frames(90)
			root.get_viewport().get_texture().get_image().save_png("%s_%d.png" % [prefix, shot])
			var aimed: Object = game.player.ray.get_collider() if game.player.ray.is_colliding() else null
			print("sealed_door_capture: %d: %s (%s), the HUD says \"%s\"" % [shot, r.slot_id, room.get_path_to(d), game.prompt_for(aimed) if aimed != null and aimed.has_method("interaction_prompt") else ""])
			shot += 1
	print("sealed_door_capture: %d doors" % shot)
	quit()


func _frames(n: int) -> void:
	for _i: int in n:
		await process_frame

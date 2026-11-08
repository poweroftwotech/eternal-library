extends SceneTree
## GPU pictures of the Orosi Scriptorium's step 1 test room (phase 17, R08;
## tools/build_r08_test.gd): the orosi wall and the light it throws. Needs a
## display, not --headless; run `godot --headless --import` first.
##   godot --path . --resolution 1920x1080 --script res://tests/r08_glass_capture.gd -- <out dir> [palette|all]
##     [--recipe=grand_study:scriptorium_glass]  (through the area, as the Strata Board walks it)
## Writes r08_<palette>_<view>.png:
##   door     from the doorway, the whole hall and the wall
##   middle   halfway in, the wall and the patches on the floor and desks
##   floor    from the side, looking down across the patches
##   close    under the middle window, looking up at the glass
##   back     from the wall back to the door: how far the light reaches

const ROOM: String = "res://rooms/test/scriptorium_glass.tscn"
const VIEWS: Array = [
	["door", Vector3(6.0, 0.08, -0.8), Vector3(6.0, 2.6, -16.0), 70.0],
	["middle", Vector3(8.6, 0.08, -6.5), Vector3(5.0, 0.8, -14.5), 70.0],
	["floor", Vector3(11.0, 0.08, -11.0), Vector3(4.0, -1.0, -12.4), 75.0],
	["close", Vector3(6.6, 0.08, -13.4), Vector3(6.0, 4.4, -16.0), 70.0],
	["back", Vector3(6.0, 0.08, -14.8), Vector3(6.0, 0.6, 0.0), 75.0],
]


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var args: PackedStringArray = []
	var through_area: bool = false
	for a: String in OS.get_cmdline_user_args():
		# --recipe=<area>:<draft>: through the area, as the Strata Board's Walk
		# this seed does (grand_study:scriptorium_glass), not the bare room.
		if a.begins_with("--recipe="):
			var parts: PackedStringArray = a.trim_prefix("--recipe=").split(":")
			var ws: Node = root.get_node_or_null("/root/WorldState")
			ws.set("walk_area", parts[0])
			ws.set("walk_recipe", "res://gen/recipes/drafts/%s/%s.tres" % [parts[0], parts[1]])
			through_area = true
		elif not a.begins_with("--"):
			args.append(a)
	var out_dir: String = args[0] if args.size() > 0 else "user://r08"
	var which: String = args[1] if args.size() > 1 else "spectrum"
	var palettes: Array = OrosiGlass.PALETTES if which == "all" else [which]
	DirAccess.make_dir_recursive_absolute(out_dir)
	if not through_area:
		(load("res://scripts/main.gd") as GDScript).set("room_override", ROOM)
	for palette: String in palettes:
		OrosiWallSetup.palette_override = palette
		var game: Node = load("res://main.tscn").instantiate()
		root.add_child(game)
		for _i: int in 3:
			await process_frame
		game.player.blocked = true
		game.hud.toast_time = 0
		game.hud.visible = false
		for v: Array in VIEWS:
			game.player.teleport(v[1])
			game.player.camera.fov = v[3]
			game.look_toward(v[2])
			for _i: int in 90:
				await process_frame
			var path: String = out_dir.path_join("r08_%s_%s.png" % [palette, v[0]])
			root.get_viewport().get_texture().get_image().save_png(path)
			print("r08_glass_capture: ", path)
		game.queue_free()
		for _i: int in 3:
			await process_frame
	quit()

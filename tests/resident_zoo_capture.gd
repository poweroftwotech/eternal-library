extends SceneTree
## Pictures of the zoo's People pen (phase 21 step 1): everyone standing along
## the far wall, two walking, people on the bench, the cushions and the
## bedroll. Needs a display, not --headless; run `godot --headless --import`
## first, and pass --audio-driver Dummy.
##   godot --path . --resolution 1600x900 --audio-driver Dummy --script res://tests/resident_zoo_capture.gd -- <out dir>
## Writes pen_door.png (from the doorway), pen_seats.png, pen_sleep.png,
## pen_walk_0..3.png (the walkers, half a second apart) and pen_row.png.


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var out_dir: String = "user://resident_zoo"
	for a: String in OS.get_cmdline_user_args():
		out_dir = a
	DirAccess.make_dir_recursive_absolute(out_dir)
	var main_script: GDScript = load("res://scripts/main.gd")
	main_script.room_override = ZooRoom.SCENE
	var game: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	game.hud.toast_time = 0
	game.hud.visible = false
	game.stats.visible = false
	game.player.blocked = true
	for _i: int in 90:
		await process_frame
	var pen: Dictionary = {}
	for p: Dictionary in ZooRoom.PENS:
		if p["id"] == "people":
			pen = p
	var r: Rect2 = ZooRoom._span(pen)
	var c := Vector3(r.get_center().x, 0, r.get_center().y)
	var cam: Camera3D = game.player.camera
	var door := Vector3(r.end.x - 0.6, 1.6, c.z)
	await _shot(cam, door, c + Vector3(-1.5, 0.9, 0), 75.0, out_dir + "/pen_door.png")
	await _shot(cam, c + Vector3(-0.5, 1.6, 0), c + Vector3(-4.8, 0.9, 0), 75.0, out_dir + "/pen_row.png")
	await _shot(cam, c + Vector3(1.0, 1.5, 0.5), Vector3(c.x + 3.0, 0.5, r.position.y + 0.9), 60.0, out_dir + "/pen_seats.png")
	await _shot(cam, c + Vector3(0.5, 1.5, -1.5), c + Vector3(3.0, 0.3, 0), 60.0, out_dir + "/pen_cushions.png")
	await _shot(cam, c + Vector3(0.8, 1.5, 1.5), Vector3(c.x + 3.0, 0.2, r.end.y - 1.6), 60.0, out_dir + "/pen_sleep.png")
	for k: int in 4:
		await _shot(cam, c + Vector3(3.5, 1.5, 0), c + Vector3(-1.8, 0.8, 0), 70.0, "%s/pen_walk_%d.png" % [out_dir, k], 30)
	var people: int = game.world.find_children("*", "ResidentBody", true, false).size()
	print("resident_zoo_capture: %d people in the pen -> %s" % [people, out_dir])
	main_script.room_override = ""
	quit(0 if people == 16 else 1)


func _shot(cam: Camera3D, eye: Vector3, at: Vector3, fov: float, path: String, frames: int = 20) -> void:
	cam.global_position = eye
	cam.look_at(at, Vector3.UP)
	cam.fov = fov
	for _i: int in frames:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(path)

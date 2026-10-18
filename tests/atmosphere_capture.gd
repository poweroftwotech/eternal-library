extends SceneTree
## Offline viewport frames at deterministic simulation times; real engine rendering.
func _initialize() -> void:
	call_deferred("capture")
func capture() -> void:
	root.size = Vector2i(960,540)
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.player.blocked = true
	game.hud.visible = false
	game.world.set_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var args = OS.get_cmdline_user_args()
	var destination: String = args[0]
	DirAccess.make_dir_recursive_absolute(destination)
	var frames: int = int(args[1]) if args.size()>1 else 48
	var water_only: bool = args.size()>2 and args[2]=="water"
	if water_only:
		game.player.teleport(Vector3(1.2,.08,3.1))
		game.player.camera.fov = 66
		game.look_toward(Vector3(-.9,.02,.2))
	for i in range(4):
		game.world.elapsed = .8
		game.world._process(0)
		await process_frame
	for i in range(frames):
		var t: float = (4.0 if water_only else 2.0)+i/12.0
		if not water_only and i==frames/2:
			game.player.teleport(Vector3(1.2,.08,3.1))
			game.player.camera.fov = 66
			game.look_toward(Vector3(-.9,.02,.2))
		game.world.elapsed = t
		game.world._process(0)
		await process_frame
		await RenderingServer.frame_post_draw
		var error = root.get_texture().get_image().save_png(destination+"/frame_%03d.png" % i)
		if error!=OK:
			quit(error)
			return
		if i%12==0:
			print("Atmosphere frame %d/%d, simulation %.2fs" % [i,frames,t])
	game.queue_free()
	for i in range(3):
		await process_frame
	quit()

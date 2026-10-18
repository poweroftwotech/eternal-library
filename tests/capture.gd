extends SceneTree
## Actual game viewport capture. Requires an OpenGL display, not --headless.
func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.player.blocked = true
	game.hud.toast_time = 0
	var args = OS.get_cmdline_user_args()
	var mode: String = args[1] if args.size()>1 else "camp"
	if mode == "concept":
		# Matches design/Campfire in the Eternal Library.png framing (v0.11).
		game.player.teleport(Vector3(-1.05,.08,9.0))
		game.player.camera.position.y = 1.45
		game.player.camera.fov = 62
		game.look_toward(Vector3(-1.1,1.25,-2.4))
	elif mode == "water":
		# v0.12: looking down the irrigation channel toward the garden.
		game.player.teleport(Vector3(-.15,.08,.6))
		game.player.camera.fov = 60
		game.look_toward(Vector3(-.9,-.1,-4.0))
	elif mode == "paving":
		game.player.teleport(Vector3(1.2,.08,3.1))
		game.player.camera.fov = 66
		game.look_toward(Vector3(-.9,.02,.2))
	elif mode == "benchmark":
		game.player.teleport(Vector3(-.2,.08,8.7))
		game.player.camera.fov = 74
		game.look_toward(Vector3(-.4,2.1,-5.8))
	elif mode == "garden":
		game.player.teleport(Vector3(-1.9,.08,-1.2))
		game.look_toward(Vector3(-2.8,2.8,-8.0))
	elif mode == "archive":
		game.player.teleport(Vector3(8.3,.08,.9))
		game.look_toward(Vector3(9.2,2,-6.5))
		game.hud.zone_label.text = "THE DAMP ARCHIVE"
	elif mode == "gallery":
		game.player.teleport(Vector3(-1.0,2.25,-10.5))
		game.look_toward(Vector3(-.3,1.3,4.2))
	elif mode == "vista_concept":
		# Measured against the box art by tests/compare_vista.gd (section 8).
		game.player.teleport(Vector3(-1,2.25,-27.45))
		game.player.camera.fov = 68
		game.look_toward(Vector3(5,-22,-178))
		game.hud.zone_label.text = "THE ETERNAL LIBRARY · OVERLOOK"
	elif mode == "vista_portal":
		# Debug viewpoint (not reachable) by the throat gate off bank 5's top deck,
		# which the overlook cannot see.
		game.player.teleport(Vector3(-30,31.5,-166))
		game.player.camera.fov = 60
		game.look_toward(Vector3(-56,35,-175))
		game.hud.zone_label.text = "THE ETERNAL LIBRARY · ROCK GATE"
	elif mode == "vista_gate":
		# From the overlook itself, zoomed on the gate under the right colossus.
		game.player.teleport(Vector3(-1,2.25,-27.45))
		game.player.camera.fov = 22
		game.look_toward(Vector3(31,-13,-61))
		game.hud.zone_label.text = "THE ETERNAL LIBRARY · ROCK GATE"
	elif mode == "balcony":
		game.player.teleport(Vector3(-1,2.25,-27.45))
		game.look_toward(Vector3(5,-22,-178))
		game.hud.zone_label.text = "THE ETERNAL LIBRARY · OVERLOOK"
	elif mode == "vista_depth":
		game.player.teleport(Vector3(1.5,3.0,-27.55))
		game.look_toward(Vector3(3,-96,-178))
		game.hud.zone_label.text = "THE ETERNAL LIBRARY · LOWER TERRACES"
	elif mode == "vista_roof":
		game.player.teleport(Vector3(-1,2.25,-27.45))
		game.look_toward(Vector3(3,57,-180))
		game.hud.zone_label.text = "THE ETERNAL LIBRARY · CAVERN VAULT"
	elif mode == "detail":
		game.player.teleport(Vector3(-.05,.08,6.3))
		game.player.camera.fov = 65
		game.look_toward(Vector3(-2.2,.63,4.7))
	elif mode == "ceiling":
		game.player.teleport(Vector3(-1,.08,-3.1))
		game.look_toward(Vector3(-2,13,-6))
	elif mode == "cooking":
		game.player.teleport(Vector3(.5,.08,6.7))
		game.look_toward(game.world.hearth+Vector3(0,.95,0))
		game.inventory = {"root":1,"herb":1,"mushroom":1}
		game.hud.update_values(game.inventory,game.nourishment,game.warmth)
		game.show_pot()
	game.world.elapsed = 1.3
	# Volumetric fog / SSIL reproject over frames; 12 frames was not converged.
	var settle: int = int(args[2]) if args.size()>2 else 90
	for i in range(settle):
		await process_frame
	await RenderingServer.frame_post_draw
	var destination: String = args[0] if args.size() else "user://reading_garden.png"
	var result: Error = root.get_texture().get_image().save_png(destination)
	print("Viewport saved: %s (result=%d)" % [destination,result])
	print("Rendering: %s fps, %s visible draw calls, %s batched instances" % [Engine.get_frames_per_second(),Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),game.world.art.batch_count])
	game.queue_free()
	for i in range(8):
		await process_frame
	quit(result)

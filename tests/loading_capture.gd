extends SceneTree
## The travel loading panel (phase-4-design.md 8.1.8 step 4), on the GPU:
##   godot --path . --resolution 1600x900 --script res://tests/loading_capture.gd -- [out.png]
## Starts the game in R01, puts up the panel a travel shows, and saves a frame.

func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://loading.png"
	var main_script: GDScript = load("res://scripts/main.gd")
	main_script.room_override = "res://rooms/authored/reading_room.tscn"
	var game: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	for _i: int in 60:
		await process_frame
	game.hud.show_loading("Finding the way…")
	for _i: int in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	var err: Error = root.get_viewport().get_texture().get_image().save_png(out)
	print("loading_capture: %s (%s)" % [out, error_string(err)])
	main_script.room_override = ""
	quit(0 if err == OK else 1)

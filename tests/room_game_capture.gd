extends SceneTree
## GPU capture of the real game (main.tscn: player camera, HUD) in an authored
## room. Needs a display, not --headless; run `godot --headless --import` first.
##   godot --path . --resolution 1600x900 --script res://tests/room_game_capture.gd -- <out.png> [view] [frames] [room]
## Views: spawn (where the game starts), gallery (on the west gallery, looking
## across), iwan (in front of the iwan).

const VIEWS: Dictionary = {
	"spawn": [],
	"gallery": [Vector3(0.95, 4.2, -3.0), Vector3(8.0, 5.6, -12.0)],
	"iwan": [Vector3(6.0, 0.05, -15.5), Vector3(6.0, 2.6, -22.0)],
}


func _initialize() -> void:
	call_deferred("capture")


func capture() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://room_game.png"
	var view: Array = VIEWS.get(args[1] if args.size() > 1 else "spawn", [])
	var frames: int = int(args[2]) if args.size() > 2 else 120
	var main_script: GDScript = load("res://scripts/main.gd")
	main_script.room_override = args[3] if args.size() > 3 else "res://rooms/authored/reading_room.tscn"
	var game: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	game.hud.toast_time = 0
	if not view.is_empty():
		game.player.teleport(view[0])
		game.look_toward(view[1])
	game.player.blocked = true     # hold the pose while lighting settles
	for i: int in frames:
		await process_frame
	var img: Image = root.get_viewport().get_texture().get_image()
	var err: Error = img.save_png(out)
	print("room_game_capture: ", "saved " + out if err == OK else "FAILED " + error_string(err))
	main_script.room_override = ""
	quit(0 if err == OK else 1)

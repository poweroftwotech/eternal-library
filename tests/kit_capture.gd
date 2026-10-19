extends SceneTree
## GPU capture of the kit graybox room (needs a real display, not --headless).
##   godot --path . --resolution 1600x900 --script res://tests/kit_capture.gd -- <out.png> [entrance|gallery] [frames]
## Run `godot --headless --import` first, or pixel textures render white.

const VIEWS: Dictionary = {
	"entrance": [Vector3(2.0, 1.6, 2.6), Vector3(2.0, 3.6, -12.0), 70.0],
	"gallery": [Vector3(0.9, 1.5, -1.2), Vector3(3.6, 6.2, -8.5), 74.0],
}


func _initialize() -> void:
	call_deferred("capture")


func capture() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://kit_graybox.png"
	var view: Array = VIEWS.get(args[1] if args.size() > 1 else "entrance", VIEWS["entrance"])
	var frames: int = int(args[2]) if args.size() > 2 else 100
	var room: Node3D = (load("res://rooms/test/kit_graybox.tscn") as PackedScene).instantiate()
	root.add_child(room)
	var cam := Camera3D.new()
	cam.fov = view[2]
	room.add_child(cam)
	cam.look_at_from_position(view[0], view[1])
	cam.current = true
	for i: int in frames:
		await process_frame
	var img: Image = root.get_viewport().get_texture().get_image()
	var err: Error = img.save_png(out)
	print("kit_capture: ", "saved " + out if err == OK else "FAILED " + error_string(err))
	quit(0 if err == OK else 1)

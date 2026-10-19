extends SceneTree
## GPU capture of rooms/authored/reading_room.tscn (needs a real display, not --headless).
##   godot --path . --resolution 1600x900 --script res://tests/reading_room_capture.gd -- <out.png> [view] [frames] [seed]
## Views: entrance, iwan, gallery, stair, vault, end_gallery, table, recesses.
## seed: the room's preview_seed (default: as saved; "-" keeps it). A fifth argument
## "collapse" pins every recess to "collapsed" (to inspect settled spill);
## "seams" pins every wall-base seam to "rubble".
## Run `godot --headless --import` first.

const VIEWS: Dictionary = {
	"entrance": [Vector3(6.0, 1.7, -0.8), Vector3(6.0, 5.5, -20.0), 74.0],
	"iwan": [Vector3(6.0, 1.6, -12.0), Vector3(6.0, 3.6, -23.0), 70.0],
	"gallery": [Vector3(1.0, 5.8, -1.0), Vector3(9.0, 6.0, -14.0), 74.0],
	"stair": [Vector3(7.5, 1.7, -0.8), Vector3(11.0, 3.2, -11.0), 72.0],
	"vault": [Vector3(6.0, 1.7, -8.0), Vector3(6.0, 14.0, -13.0), 80.0],
	"end_gallery": [Vector3(6.0, 2.2, -13.0), Vector3(6.0, 4.6, 0.0), 72.0],
	"table": [Vector3(4.6, 1.9, -4.6), Vector3(3.0, 0.7, -6.8), 60.0],
	"recesses": [Vector3(6.5, 1.8, -10.0), Vector3(0.0, 2.6, -17.0), 66.0],
	"seam": [Vector3(3.6, 1.3, -3.2), Vector3(2.2, 0.15, -0.3), 64.0],
}


func _initialize() -> void:
	call_deferred("capture")


func capture() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://reading_room.png"
	var view: Array = VIEWS.get(args[1] if args.size() > 1 else "entrance", VIEWS["entrance"])
	var frames: int = int(args[2]) if args.size() > 2 else 100
	var room: RoomTemplate = (load("res://rooms/authored/reading_room.tscn") as PackedScene).instantiate()
	if args.size() > 3 and args[3] != "-":
		room.preview_seed = int(args[3])
	var pin_all: Dictionary = {"collapse": ["recess_library", "collapsed"], "seams": ["seam_debris", "rubble"]}
	if args.size() > 4 and pin_all.has(args[4]):
		var lib: SocketSet = load("res://kit/sockets/%s.tres" % pin_all[args[4]][0])
		var pins: Dictionary[String, int] = {}
		pins.assign(room.socket_pins)
		root.add_child(room)
		for s: VariantSocket in room.sockets():
			if s.socket_set == lib:
				pins[room.socket_key(s)] = lib.index_of(pin_all[args[4]][1])
		room.socket_pins = pins
		room.resolve_sockets(room.preview_seed)
	else:
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
	print("reading_room_capture: ", "saved " + out if err == OK else "FAILED " + error_string(err))
	quit(0 if err == OK else 1)

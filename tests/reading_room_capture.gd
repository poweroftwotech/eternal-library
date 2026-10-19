extends SceneTree
## GPU capture of rooms/authored/reading_room.tscn (needs a real display, not --headless).
##   godot --path . --resolution 1600x900 --script res://tests/reading_room_capture.gd -- <out.png> [view] [frames] [seed]
## Views: entrance, iwan, gallery, stair, vault, end_gallery, table, recesses, seam,
## soot, crown, west_stair, stair_foot, under_gallery, arcade, side_arch, roots, relief_floor, relief_wall, relief_damp, relief_lane.
## seed: the room's preview_seed (default: as saved; "-" keeps it). A fifth argument
## "collapse" pins every recess to "collapsed" (to inspect settled spill);
## "seams" pins every wall-base seam to "rubble"; "growth" pins seams to "fern"
## and every growth socket (polish B) to its heaviest pick; "decals" pins wall stains to "water stain", floor
## wear to "crack" and lamp soot to "soot"; "nodecals" pins all three to "nothing";
## "open_stairs" pins both stairs to the open wooden look; "damp" pins floor wear to "damp patch".
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
	"soot": [Vector3(3.2, 1.5, -6.0), Vector3(0.9, 3.85, -6.0), 60.0],     # gallery underside over a lantern
	"crown": [Vector3(6.0, 9.5, -9.0), Vector3(6.0, 14.6, -14.0), 50.0],  # vault crown over a chandelier
	"west_stair": [Vector3(5.2, 1.6, -15.5), Vector3(0.8, 2.0, -11.0), 70.0],  # side-on to the west stair
	"stair_foot": [Vector3(4.6, 1.5, -19.6), Vector3(1.4, 0.9, -15.0), 60.0],  # the west stair's foot newel (polish 1b)
	"under_gallery": [Vector3(0.75, 1.5, -0.75), Vector3(1.0, 2.3, -7.0), 70.0],    # along the west wall under the gallery (1c)
	"arcade": [Vector3(7.0, 1.6, -2.6), Vector3(1.0, 2.6, -5.0), 70.0],           # side-on to the west arcade (1c)
	"side_arch": [Vector3(5.5, 1.7, -10.0), Vector3(0.3, 2.7, -10.0), 66.0],        # the west side door arch (polish B)
	"roots": [Vector3(4.4, 1.5, -2.7), Vector3(0.0, 1.0, -2.1), 60.0],                # a lower west recess, close (polish B item 6)
	"relief_floor": [Vector3(7.6, 1.0, -1.2), Vector3(6.0, 0.0, -5.6), 64.0],        # low over the flags toward the floor lantern (polish C)
	"relief_wall": [Vector3(7.0, 1.8, -16.5), Vector3(11.9, 2.6, -21.5), 66.0],       # along the brick beside the iwan, lamp-lit (polish C)
	"relief_damp": [Vector3(8.2, 1.1, -3.8), Vector3(10.2, 0.0, -1.8), 60.0],         # a floor-wear socket toward the east hanging lantern (polish C)
	"relief_lane": [Vector3(4.1, 0.9, -2.6), Vector3(3.6, 0.0, -9.5), 62.0],          # low down the west walking lane toward the floor lantern (polish C item 9)
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
	# option -> [[set, entry], ...]: pin every socket of that set to that entry.
	var pin_all: Dictionary = {"collapse": [["recess_library", "collapsed"]], "seams": [["seam_debris", "rubble"]],
		"growth": [["seam_debris", "fern"], ["arch_growth", "heavy"], ["arch_growth_iwan", "heavy"], ["cornice_growth", "long curtain"],
			["parapet_growth", "strands"], ["parapet_growth_stair", "strands"], ["parapet_growth_stair_r", "strands"]],
		"decals": [["wall_stains", "water stain"], ["floor_wear", "crack"], ["lamp_soot", "soot"]],
		"nodecals": [["wall_stains", "nothing"], ["floor_wear", "nothing"], ["lamp_soot", "nothing"]],
		"damp": [["floor_wear", "damp patch"]],
		"open_stairs": [["stair_style", "open wood"]]}
	if args.size() > 4 and pin_all.has(args[4]):
		var pins: Dictionary[String, int] = {}
		pins.assign(room.socket_pins)
		root.add_child(room)
		for s: VariantSocket in room.sockets():
			for rule: Array in pin_all[args[4]]:
				if s.socket_set != null and s.socket_set.resource_path.ends_with("/%s.tres" % rule[0]):
					pins[room.socket_key(s)] = s.socket_set.index_of(rule[1])
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
	# Frame time over 240 frames with vsync off (one fps sample is noise).
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	for i: int in 30:
		await process_frame
	var t0: int = Time.get_ticks_usec()
	for i: int in 240:
		await process_frame
	print("reading_room_capture: frame time %.2f ms" % ((Time.get_ticks_usec() - t0) / 240000.0))
	quit(0 if err == OK else 1)

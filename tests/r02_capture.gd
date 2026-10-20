extends SceneTree
## GPU capture of R01 with the generated R02 Stack Gallery off its west door
## (ENVIRONMENT_PLAN.md phase 2; needs a real display, not --headless).
##   godot --path . --resolution 1600x900 --script res://tests/r02_capture.gd -- <out.png> [view] [seed] [options]
## Views (camera in corridor space: x across, -z down the run, from the door):
##   door      from R01's hall through the west door down the corridor
##   corridor  in the first bay, looking down the run
##   back      near the far end, looking back toward R01
##   joint     up at the vault end against R01's wall (the slice 1 risk)
##   plan      high above, looking down (pass "overlay" to see the grid marks)
##   plan_wide the same, higher and centred further out (for winding runs)
##   corner    seed 1: down the first stretch toward its right turn
##   groin     seed 1: up into that corner's groin vault
## Options (fourth argument, comma separated): overlay, straight=N
## (max_straight_bays for this capture).
## Run `godot --headless --import` first.

## view -> [from, to, fov, from/to in R01 space instead of corridor space]
const VIEWS: Dictionary = {
	"door": [Vector3(5.5, 1.7, -6.0), Vector3(-30.0, 2.2, -6.0), 66.0, true],
	"corridor": [Vector3(2.0, 1.7, -1.2), Vector3(2.0, 2.4, -40.0), 70.0, false],
	"back": [Vector3(2.0, 1.7, -30.0), Vector3(2.0, 2.4, 6.0), 70.0, false],
	"joint": [Vector3(2.0, 1.5, -3.6), Vector3(2.0, 5.0, 0.2), 74.0, false],
	"plan": [Vector3(2.0, 30.0, -14.0), Vector3(2.0, 0.0, -13.99), 70.0, false],
	"corner": [Vector3(2.0, 1.7, -5.0), Vector3(3.2, 3.2, -14.0), 70.0, false],   # seed 1: down the first stretch to the right turn
	"groin": [Vector3(2.0, 1.4, -11.0), Vector3(2.4, 6.0, -14.4), 80.0, false],  # seed 1: up into the corner's groin vault
	"plan_wide": [Vector3(-8.0, 46.0, -16.0), Vector3(-8.0, 0.0, -15.99), 70.0, false],
}


func _initialize() -> void:
	call_deferred("capture")


func capture() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://r02.png"
	var view: Array = VIEWS.get(args[1] if args.size() > 1 else "corridor", VIEWS["corridor"])
	var room: RoomTemplate = (load("res://rooms/test/reading_room_r02.tscn") as PackedScene).instantiate()
	var g: GeneratedRoom = room.get_node("StackGallery")
	if args.size() > 2 and args[2] != "-":
		g.gen_seed = int(args[2])
	var options: PackedStringArray = args[3].split(",") if args.size() > 3 else PackedStringArray()
	g.overlay = options.has("overlay")
	for o: String in options:
		if o.begins_with("straight="):
			var grammar: StackGalleryGrammar = (g.grammar as StackGalleryGrammar).duplicate()
			grammar.max_straight_bays = o.trim_prefix("straight=").to_int()
			g.grammar = grammar
	root.add_child(room)
	var cam := Camera3D.new()
	cam.fov = view[2]
	cam.far = 200.0
	room.add_child(cam)
	var from: Vector3 = view[0] if view[3] else g.to_global(view[0])
	var to: Vector3 = view[1] if view[3] else g.to_global(view[1])
	cam.look_at_from_position(from, to)
	cam.current = true
	for i: int in 100:
		await process_frame
	var img: Image = root.get_viewport().get_texture().get_image()
	var err: Error = img.save_png(out)
	print("r02_capture: seed %d, %d bays: " % [g.effective_seed(), g.bay_count()], "saved " + out if err == OK else "FAILED " + error_string(err))
	quit()

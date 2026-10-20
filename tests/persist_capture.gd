extends SceneTree
## Phase 3 step 2 GPU check: the same view before quitting and after a restart
## (needs a real display). Run in order, then compare with image_diff.gd:
##   godot --path . --resolution 1600x900 --script res://tests/persist_capture.gd -- save <out.png> --save=user://test/persist_gpu.json --fresh
##   godot --path . --resolution 1600x900 --script res://tests/persist_capture.gd -- load <out.png> --save=user://test/persist_gpu.json
## save: in R01, E knocks the west vase over and the east one is dropped and
## broken; once all is still, captures bay 4 and quits through the game.
## load: resumes, captures the same view.

var main_script: GDScript = load("res://scripts/main.gd")
const VIEW: Array = [Vector3(6.0, 3.4, -11.2), Vector3(6.0, 0.0, -17.2), 84.0]

var game: Node


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var mode: String = args[0]
	if mode == "save":
		main_script.room_override = "res://rooms/authored/reading_room.tscn"
	game = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	for _i: int in 30:
		await physics_frame
	var room: RoomTemplate = game.world
	if mode == "save":
		var west: WorldProp = room.get_node("Props/VaseIwanWest")
		var east: WorldProp = room.get_node("Props/VaseIwanEast")
		game.player.teleport(Vector3(2.2, 0.05, -15.0), 0.0, -0.62)
		for _i: int in 3:
			await physics_frame
		game.interact(west)
		east.global_position += Vector3(0, 1.4, 0)
		east.wake()
		for _i: int in 900:
			await physics_frame
			if WorldProp.awake_props.is_empty() and room.room_shards().all(func(s: Shards) -> bool: return s.all_frozen):
				break
	# The HUD and player camera stay out of it: a fixed camera on bay 4.
	game.hud.visible = false
	var cam := Camera3D.new()
	room.add_child(cam)
	cam.fov = VIEW[2]
	cam.look_at_from_position(VIEW[0], VIEW[1])
	cam.current = true
	for _i: int in 60:
		await process_frame
	var err: Error = root.get_viewport().get_texture().get_image().save_png(args[1])
	print("persist_capture %s: %s" % [mode, "saved " + args[1] if err == OK else "FAILED"])
	if mode == "save":
		game.save_and_quit()
	else:
		quit(0)

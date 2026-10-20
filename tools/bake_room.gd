extends SceneTree
## Bakes a generated room to a scene (ENVIRONMENT_PLAN.md 5.5.10).
##   godot --headless --path . --script res://tools/bake_room.gd -- [scene] [seed] [out] [node]
## scene: the scene holding the GeneratedRoom (default rooms/test/reading_room_r02.tscn);
## seed: its gen_seed (default: as saved); out: the .tscn to write (default
## rooms/baked/<room_id>_<seed>.tscn); node: the GeneratedRoom's path in the scene
## (default: the first one found). Also writes <out>_in_host.tscn, the scene with
## the baked room in the generated one's place, which the game can load:
##   godot --path . -- --room=res://rooms/baked/<room_id>_<seed>_in_host.tscn

const DEFAULT_SCENE: String = "res://rooms/test/reading_room_r02.tscn"


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var scene_path: String = args[0] if args.size() > 0 and args[0] != "-" else DEFAULT_SCENE
	var scene: Node = (load(scene_path) as PackedScene).instantiate()
	var g: GeneratedRoom = null
	if args.size() > 3:
		g = scene.get_node_or_null(args[3]) as GeneratedRoom
	else:
		for n: Node in scene.find_children("*", "Node3D", true, false):
			if n is GeneratedRoom:
				g = n
				break
	if g == null:
		push_error("bake_room: no GeneratedRoom in %s" % scene_path)
		quit(1)
		return
	if args.size() > 1 and args[1] != "-":
		g.gen_seed = int(args[1])
	root.add_child(scene)
	var out: String = args[2] if args.size() > 2 and args[2] != "-" else RoomBaker.default_path(g)
	var err: Error = RoomBaker.bake(g, out)
	if err != OK:
		push_error("bake_room: %s" % error_string(err))
		quit(1)
		return
	var host_scene: String = RoomBaker.write_host_scene(g, scene_path, out)
	print("bake_room: seed %d, %d modules -> %s%s" % [g.effective_seed(), g.modules.size(), out,
		(" and " + host_scene) if host_scene != "" else ""])
	quit(0)

extends SceneTree
## Bakes the caravanserai template (phase-5-design.md 5.6.7) to a scene, as an
## area's root: the gate's doorway is an exit, and a PlayerSpawn stands in the
## gate passage facing the court.
##   godot --headless --path . --script res://tools/bake_court.gd -- [grammar] [seed] [out]
## grammar: default gen/grammars/r05_court_5x5.tres; seed: 1; out:
## rooms/baked/caravanserai_<w>x<d>.tscn. The scene is yours to finish by hand
## afterwards (re-baking overwrites it).

const DEFAULT_GRAMMAR: String = "res://gen/grammars/r05_court_5x5.tres"


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var grammar := load(args[0] if args.size() > 0 and args[0] != "-" else DEFAULT_GRAMMAR) as CourtyardGrammar
	var seed_value: int = int(args[1]) if args.size() > 1 and args[1] != "-" else 1
	var out: String = args[2] if args.size() > 2 and args[2] != "-" else \
		"res://rooms/baked/caravanserai_%dx%d.tscn" % [grammar.court_w, grammar.court_d]
	var g := GeneratedRoom.new()
	g.name = "Caravanserai"
	g.room_id = "caravanserai"
	g.display_name = "The Caravanserai"
	g.root_room = true
	g.gen_seed = seed_value
	g.grammar = grammar
	root.add_child(g)
	var problems: PackedStringArray = g.grid.check() if g.grid != null else PackedStringArray(["no grid"])
	if not problems.is_empty() or g.modules.is_empty():
		push_error("bake_court: layout problems %s" % [problems])
		quit(1)
		return
	var baked: RoomTemplate = RoomBaker.build(g)
	var spawn := Marker3D.new()
	spawn.name = "PlayerSpawn"
	spawn.position = CellGrid.cell_centre(Vector3i.ZERO) + Vector3(0, 0.1, 0.6)     # in the gate passage, facing the court (-Z)
	baked.add_child(spawn)
	spawn.owner = baked
	var scene := PackedScene.new()
	var err: Error = scene.pack(baked)
	baked.free()
	if err == OK:
		err = ResourceSaver.save(scene, out)
	if err != OK:
		push_error("bake_court: %s" % error_string(err))
		quit(1)
		return
	print("bake_court: seed %d, %d modules -> %s" % [seed_value, g.modules.size(), out])
	quit(0)

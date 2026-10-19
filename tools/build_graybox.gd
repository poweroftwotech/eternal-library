extends SceneTree
## Writes rooms/test/kit_graybox.tscn: a 1 x 3 bay, two-storey vaulted room
## assembled only from kit wrapper scenes (ENVIRONMENT_PLAN.md phase 0).
##   godot --headless --path . --script res://tools/build_graybox.gd [-- --force]
## After the first run the scene is meant to be edited by hand in the Godot
## editor with the Kit dock; this refuses to overwrite it unless --force.

const OUT: String = "res://rooms/test/kit_graybox.tscn"
const MOD: String = "res://kit/modules/walls/"
const BAY: float = 4.0
const DEPTH: int = 3   # bays along -Z

var room: Node3D
var shell: Node3D


func _initialize() -> void:
	if ResourceLoader.exists(OUT) and not OS.get_cmdline_user_args().has("--force"):
		print("build_graybox: %s exists; edit it in the editor (or pass --force)." % OUT)
		quit()
		return
	room = Node3D.new()
	room.name = "KitGraybox"
	shell = Node3D.new()
	shell.name = "Shell"
	room.add_child(shell)
	shell.owner = room
	for k: int in DEPTH:
		var z: float = -k * BAY
		place("floor_4m", Vector3(0, 0, z), 0)
		place("vault_bay_4m", Vector3(0, BAY, z), 0)
		# West wall (x = 0) runs +Z from its origin with the interior facing +X: yaw -90.
		# East wall (x = 4) runs -Z from its origin with the interior facing -X: yaw +90.
		var west_low: String = "wall_shelfbay_4m" if k != 1 else "wall_plain_4m"
		place(west_low, Vector3(0, 0, z - BAY), -90)
		place("wall_shelfbay_4m", Vector3(BAY, 0, z), 90)
		place("gallery_slab_4m", Vector3(0, 0, z - BAY), -90)
		place("gallery_slab_4m", Vector3(BAY, 0, z), 90)
		place("wall_shelfbay_4m" if k % 2 == 0 else "wall_plain_4m", Vector3(0, BAY, z - BAY), -90)
		place("wall_plain_4m" if k % 2 == 0 else "wall_shelfbay_4m", Vector3(BAY, BAY, z), 90)
		place("lantern_hanging", Vector3(BAY * 0.5, 3.0, z - BAY * 0.5), 0)
	# South end (z = 0): arch entrance below, plain wall above, gable on top.
	place("wall_arch_3m", Vector3(0, 0, 0), 0)
	place("wall_plain_4m", Vector3(0, BAY, 0), 0)
	place("wall_gable_4m", Vector3(0, BAY, 0), 0)
	# North end (z = -12): faces back toward +Z, so it is turned 180 degrees.
	var zn: float = -DEPTH * BAY
	place("wall_shelfbay_4m", Vector3(BAY, 0, zn), 180)
	place("wall_shelfbay_4m", Vector3(BAY, BAY, zn), 180)
	place("wall_gable_4m", Vector3(BAY, BAY, zn), 180)
	for k: int in DEPTH + 1:
		for x: float in [0.0, BAY]:
			place("post_pier", Vector3(x, 0, -k * BAY), 0)
			place("post_pier", Vector3(x, BAY, -k * BAY), 0)
	add_environment()
	var packed := PackedScene.new()
	var err: Error = packed.pack(room)
	if err == OK:
		DirAccess.make_dir_recursive_absolute(OUT.get_base_dir())
		err = ResourceSaver.save(packed, OUT)
	print("build_graybox: ", "wrote " + OUT if err == OK else "FAILED " + error_string(err))
	room.free()
	quit(0 if err == OK else 1)


func place(module_name: String, pos: Vector3, yaw_deg: float) -> void:
	var packed: PackedScene = load(MOD + module_name + ".tscn")
	var node: Node3D = packed.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	node.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), pos)
	shell.add_child(node, true)
	node.owner = room


func add_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.03, 0.05, 0.06)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.45, 0.55, 0.62)
	env.ambient_light_energy = 0.35
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.glow_enabled = true
	env.glow_hdr_threshold = 1.0
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.012
	env.volumetric_fog_albedo = Color(0.7, 0.75, 0.8)
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	room.add_child(we)
	we.owner = room
	var fill := OmniLight3D.new()
	fill.name = "EntranceFill"
	fill.position = Vector3(2, 2.5, 1.5)
	fill.light_color = Color(1.0, 0.75, 0.45)
	fill.light_energy = 1.2
	fill.omni_range = 9.0
	room.add_child(fill)
	fill.owner = room

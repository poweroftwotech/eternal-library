extends SceneTree
## GPU capture of the R01 modules assembled into a 3 x 3 bay hall slice
## (iwan end, two storeys, 12 m vault, gallery and stair). Built in memory and
## never saved: rooms/authored/reading_room.tscn is built by hand (phase 1 step 2).
##   godot --path . --resolution 1600x900 --script res://tests/kit_r01_capture.gd -- <out.png> [hall|gallery|iwan] [frames]
## Run `godot --headless --import` first, or pixel textures render white.

const MOD: String = "res://kit/modules/walls/"
const BAY: float = 4.0
const VIEWS: Dictionary = {
	"hall": [Vector3(6.0, 1.7, -0.3), Vector3(6.0, 5.0, -12.0), 72.0],
	"gallery": [Vector3(0.9, 5.8, -1.0), Vector3(9.0, 6.5, -10.0), 74.0],
	"iwan": [Vector3(6.0, 1.6, -5.0), Vector3(6.0, 3.2, -14.0), 70.0],
}

var shell: Node3D


func _initialize() -> void:
	call_deferred("capture")


func capture() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://kit_r01.png"
	var view: Array = VIEWS.get(args[1] if args.size() > 1 else "hall", VIEWS["hall"])
	var frames: int = int(args[2]) if args.size() > 2 else 100
	var room := RoomTemplate.new()
	room.room_id = "r01_preview"
	shell = Node3D.new()
	shell.name = "Shell"
	room.add_child(shell)
	build()
	root.add_child(room)
	add_environment(room)
	var cam := Camera3D.new()
	cam.fov = view[2]
	room.add_child(cam)
	cam.look_at_from_position(view[0], view[1])
	cam.current = true
	for i: int in frames:
		await process_frame
	var img: Image = root.get_viewport().get_texture().get_image()
	var err: Error = img.save_png(out)
	print("kit_r01_capture: ", "saved " + out if err == OK else "FAILED " + error_string(err))
	quit(0 if err == OK else 1)


func build() -> void:
	var depth: int = 3
	for k: int in depth:
		var z: float = -k * BAY
		for x: float in [0.0, BAY, 2 * BAY]:
			place("floor_4m", Vector3(x, 0, z), 0)
		place("vault_hall_12m", Vector3(0, BAY, z), 0)
		for storey: int in 2:
			# West wall runs +Z from its origin (yaw -90); east wall runs -Z (yaw 90).
			place("wall_shelfbay_4m", Vector3(0, storey * BAY, z - BAY), -90)
			place("wall_shelfbay_4m", Vector3(3 * BAY, storey * BAY, z), 90)
		place("gallery_slab_4m", Vector3(3 * BAY, 0, z), 90)
		if k == 0:
			place("gallery_slab_4m", Vector3(0, 0, z - BAY), -90)
	# Stair up the west side over bays 1-2, arriving at the bay-0 gallery.
	place("stair_gallery_8m", Vector3(0, 0, -depth * BAY), -90)
	var zn: float = -depth * BAY
	place("wall_iwan_12m", Vector3(3 * BAY, 0, zn), 180)
	place("wall_gable_12m", Vector3(3 * BAY, BAY, zn), 180)
	for k: int in depth + 1:
		for x: float in [0.0, 3 * BAY]:
			place("post_pier_corbel", Vector3(x, 0, -k * BAY), 0)
			place("post_pier", Vector3(x, BAY, -k * BAY), 0)
	place("rug_runner", Vector3(6, 0, -6), 0)
	place("table_reading", Vector3(3.1, 0, -6), 0)
	place("table_reading", Vector3(8.9, 0, -6), 0)
	place("lantern_cluster", Vector3(6, 0, -6), 0)


func place(module_name: String, pos: Vector3, yaw_deg: float) -> void:
	var node: Node3D = (load(MOD + module_name + ".tscn") as PackedScene).instantiate()
	node.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), pos)
	shell.add_child(node, true)


func add_environment(room: Node3D) -> void:
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
	we.environment = env
	room.add_child(we)
	var fill := OmniLight3D.new()
	fill.position = Vector3(6, 2.5, 1.0)
	fill.light_color = Color(1.0, 0.75, 0.45)
	fill.light_energy = 1.2
	fill.omni_range = 10.0
	room.add_child(fill)

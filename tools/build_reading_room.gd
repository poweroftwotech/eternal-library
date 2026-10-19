extends SceneTree
## Drafts rooms/authored/reading_room.tscn (ENVIRONMENT_PLAN.md phase 1 step 2):
## the R01 Reading Room, 3 x 5 bays (12 x 20 m), two storeys under a 12 m
## vault, built only from kit wrapper scenes.
##   godot --headless --path . --script res://tools/build_reading_room.gd [-- --force]
## This is a starting point: after the first run, edit the scene by hand in the
## editor (Kit dock, Sockets panel). It refuses to overwrite unless --force.
##
## Layout (z = 0 is the entrance end, the iwan closes z = -20):
##   south  arch entrance in the middle bay, gable over the vault end
##   west   bay 1 side door; stair over bays 2-3 rising toward the entrance
##   east   mirror of the west (stair_gallery_8m_r so it also rises south)
##   gallery one U-shaped walk: side galleries over bays 0-1 joined along the
##          entrance wall by gallery_end_12m (corner slabs open their rails)
##   north  12 m iwan (two storeys) with the vault gable above
## Bays the stairs cover get plain walls (shelves would be hidden).

const OUT: String = "res://rooms/authored/reading_room.tscn"
const MOD: String = "res://kit/modules/walls/"
const BAY: float = 4.0
const BAYS: int = 5          # along -Z
const WIDTH: float = 12.0    # three bays along +X

var room: RoomTemplate
var groups: Dictionary = {}


func _initialize() -> void:
	if ResourceLoader.exists(OUT) and not OS.get_cmdline_user_args().has("--force"):
		print("build_reading_room: %s exists; edit it in the editor (or pass --force)." % OUT)
		quit()
		return
	room = RoomTemplate.new()
	room.name = "ReadingRoom"
	room.room_id = "reading_room"
	room.display_name = "The Reading Room"
	for g: String in ["Shell", "Sockets", "Props", "Dressing", "Lights", "Connectors"]:
		var n := Node3D.new()
		n.name = g
		room.add_child(n)
		n.owner = room
		groups[g] = n
	build_shell()
	build_dressing()
	pin_hidden_seams(room)
	build_lights()
	build_connectors()
	add_spawn()
	build_bounds()
	add_safety_floor()
	add_atmosphere()
	var packed := PackedScene.new()
	var err: Error = packed.pack(room)
	if err == OK:
		DirAccess.make_dir_recursive_absolute(OUT.get_base_dir())
		err = ResourceSaver.save(packed, OUT)
	print("build_reading_room: ", "wrote " + OUT if err == OK else "FAILED " + error_string(err))
	room.free()
	quit(0 if err == OK else 1)


func build_shell() -> void:
	# Lower storey of each side wall, bay 0 to 4 (both sides are mirror images).
	var side_low: Array[String] = ["wall_shelfbay_4m", "wall_arch_3m", "wall_plain_4m", "wall_plain_4m", "wall_shelfbay_4m"]
	for k: int in BAYS:
		var z: float = -k * BAY
		for x: float in [0.0, BAY, 2 * BAY]:
			place("Shell", "floor_4m", Vector3(x, 0, z), 0)
		place("Shell", "vault_hall_12m", Vector3(0, BAY, z), 0)
		# West wall runs +Z from its origin (yaw -90); east wall runs -Z (yaw 90).
		place("Shell", side_low[k], Vector3(0, 0, z - BAY), -90)
		place("Shell", side_low[k], Vector3(WIDTH, 0, z), 90)
		place("Shell", "wall_shelfbay_4m", Vector3(0, BAY, z - BAY), -90)
		place("Shell", "wall_shelfbay_4m", Vector3(WIDTH, BAY, z), 90)
		if k <= 1:   # bay 0 slabs open their rail at the corner onto the end gallery
			place("Shell", "gallery_slab_4m_open_end" if k == 0 else "gallery_slab_4m", Vector3(0, 0, z - BAY), -90)
			place("Shell", "gallery_slab_4m_open_start" if k == 0 else "gallery_slab_4m", Vector3(WIDTH, 0, z), 90)
	# Stairs: stair_gallery_8m rises along its local +X, the _r variant toward its
	# origin. West (yaw -90) and east _r (yaw 90) both rise toward the entrance.
	place("Shell", "stair_gallery_8m", Vector3(0, 0, -4 * BAY), -90)         # z -16 -> -8
	place("Shell", "stair_gallery_8m_r", Vector3(WIDTH, 0, -2 * BAY), 90)    # z -16 -> -8
	# South end: entrance arch below, plain wall and a shelf bay above, gable on top.
	place("Shell", "wall_plain_4m", Vector3(0, 0, 0), 0)
	place("Shell", "wall_arch_3m", Vector3(BAY, 0, 0), 0)
	place("Shell", "wall_plain_4m", Vector3(2 * BAY, 0, 0), 0)
	place("Shell", "wall_plain_4m", Vector3(0, BAY, 0), 0)
	place("Shell", "wall_shelfbay_4m", Vector3(BAY, BAY, 0), 0)
	place("Shell", "wall_plain_4m", Vector3(2 * BAY, BAY, 0), 0)
	place("Shell", "wall_gable_12m", Vector3(0, BAY, 0), 0)
	place("Shell", "gallery_end_12m", Vector3(0, 0, 0), 0)   # over the entrance arch
	# North end: the iwan faces back toward +Z, so it is turned 180 degrees.
	var zn: float = -BAYS * BAY
	place("Shell", "wall_iwan_12m", Vector3(WIDTH, 0, zn), 180)
	place("Shell", "wall_gable_12m", Vector3(WIDTH, BAY, zn), 180)
	# Piers on every side-wall joint; corbels carry the galleries, but not
	# where a stair runs past the pier (they would hit heads).
	for k: int in BAYS + 1:
		var z: float = -k * BAY
		place("Shell", "post_pier" if k == 3 else "post_pier_corbel", Vector3(0, 0, z), 0)
		place("Shell", "post_pier" if k == 3 else "post_pier_corbel", Vector3(WIDTH, 0, z), 0)
		place("Shell", "post_pier", Vector3(0, BAY, z), 0)
		place("Shell", "post_pier", Vector3(WIDTH, BAY, z), 0)


func build_dressing() -> void:
	place("Dressing", "rug_runner", Vector3(6, 0, -10), 0)
	for z: float in [-6.5, -13.5]:
		place("Dressing", "table_reading", Vector3(3.0, 0, z), 0)
		place("Dressing", "table_reading", Vector3(9.0, 0, z), 0)


func build_lights() -> void:
	place("Lights", "lantern_cluster", Vector3(6, 0, -6), 0)
	place("Lights", "lantern_cluster", Vector3(6, 0, -14), 0)
	# Hanging lanterns under the galleries (chain top tucks into the slab).
	for z: float in [-2.0, -6.0]:
		place("Lights", "lantern_hanging", Vector3(1.0, 0, z), 0)
		place("Lights", "lantern_hanging", Vector3(WIDTH - 1.0, 0, z), 0)
	# The iwan's single lamp, hung from its apex (7.45 m).
	place("Lights", "lantern_hanging", Vector3(6, 3.5, -21.5), 0)
	for fill: Array in FILLS:
		groups["Lights"].add_child(fill_light(fill))
		groups["Lights"].get_child(-1).owner = room


## Authored fills (step 4, ART_DIRECTION.md rule 4: never a black area): a
## warm glow low in the iwan (its apex lamp is 6 m up) and cool teal fills over
## the back half, the warm/cool split of the prototype's archive fill.
## [name, position, colour, energy, range]
const FILLS: Array = [
	["IwanGlow", Vector3(6, 2.4, -21.0), Color("ffcf8a"), 1.2, 5.0],
	["CoolFillWest", Vector3(2.0, 6.5, -14.0), Color("2c74e6"), 1.0, 9.0],
	["CoolFillEast", Vector3(10.0, 6.5, -14.0), Color("2c74e6"), 1.0, 9.0],
]


static func fill_light(spec: Array) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.name = spec[0]
	light.position = spec[1]
	light.light_color = spec[2]
	light.light_energy = spec[3]
	light.omni_range = spec[4]
	light.shadow_enabled = false
	return light


## Room-level door markers for the area assembler; -Z points out of the room.
func build_connectors() -> void:
	var doors: Array = [
		["SNAP_entrance", Vector3(6, 0, 0), 180.0],
		["SNAP_door_west", Vector3(0, 0, -6), 90.0],
		["SNAP_door_east", Vector3(WIDTH, 0, -6), -90.0],
	]
	for d: Array in doors:
		var m := Marker3D.new()
		m.name = d[0]
		m.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(d[2])), d[1])
		m.set_meta("snap_kind", "door")
		groups["Connectors"].add_child(m)
		m.owner = room
		m.add_to_group("room_connector", true)


## Room volume for streaming, music and aging later (no collision yet).
func build_bounds() -> void:
	var area := Area3D.new()
	area.name = "Bounds"
	area.collision_layer = 0
	area.collision_mask = 0
	area.monitoring = false
	area.monitorable = false
	var shape := CollisionShape3D.new()
	shape.name = "Volume"
	var box := BoxShape3D.new()
	box.size = Vector3(WIDTH, 15.0, BAYS * BAY + 3.3)
	shape.shape = box
	shape.position = Vector3(WIDTH / 2, 7.5, -(BAYS * BAY + 3.3) / 2)
	area.add_child(shape)
	room.add_child(area)
	area.owner = room
	shape.owner = room


## AGENTS.md 6: the side doors open onto nothing yet. Invisible catch floor
## 0.25 m under the kit floor; delete it once the room sits in an area.
func add_safety_floor() -> void:
	var body := StaticBody3D.new()
	body.name = "TempSafetyFloor"
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	shape.name = "Shape"
	var box := BoxShape3D.new()
	box.size = Vector3(60, 0.5, 60)
	shape.shape = box
	body.position = Vector3(WIDTH / 2, -0.5, -10)
	body.add_child(shape)
	room.add_child(body)
	body.owner = room
	shape.owner = room


## The room's look (phase 1 step 4): builds its own environment unless an area
## or the game world already supplies one.
func add_atmosphere() -> void:
	var atmo := Atmosphere.new()
	atmo.name = "Atmosphere"
	atmo.profile = load("res://kit/atmosphere/reading_room.tres")
	room.add_child(atmo)
	atmo.owner = room


func place(group: String, module_name: String, pos: Vector3, yaw_deg: float) -> void:
	var packed: PackedScene = load(MOD + module_name + ".tscn")
	var node: Node3D = packed.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	node.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), pos)
	groups[group].add_child(node, true)
	node.owner = room


## Where main.gd puts the player when the room is played on its own: inside
## the entrance on the runner, looking down the hall (-Z).
func add_spawn() -> void:
	var m := Marker3D.new()
	m.name = "PlayerSpawn"
	m.position = Vector3(WIDTH / 2, 0.05, -1.5)
	room.add_child(m)
	m.owner = room
	m.add_to_group("player_spawn", true)


## The plain walls behind the stairs (bays 2-3, both sides) are hidden by the
## masonry, so their wall-base seams are pinned to "nothing" in the room
## (weathering item 1; Validate Room flags them otherwise). Static so a patch
## script can apply it to an existing room.
const HIDDEN_SEAM_WALLS: Array[Vector3] = [Vector3(0, 0, -12), Vector3(0, 0, -16), Vector3(WIDTH, 0, -8), Vector3(WIDTH, 0, -12)]


static func pin_hidden_seams(target: RoomTemplate) -> int:
	var lib: SocketSet = load("res://kit/sockets/seam_debris.tres")
	var nothing: int = lib.index_of("nothing")
	var pins: Dictionary[String, int] = {}
	pins.assign(target.socket_pins)
	var count: int = 0
	for m: Node in target.get_node("Shell").get_children():
		var n := m as Node3D
		if n == null or not n.scene_file_path.ends_with("wall_plain_4m.tscn"):
			continue
		if not HIDDEN_SEAM_WALLS.any(func(p: Vector3) -> bool: return n.position.is_equal_approx(p)):
			continue
		pins["%s/Mesh/M_wall_plain_4m/SOCKET_seam_debris" % str(target.get_path_to(n))] = nothing
		count += 1
	target.socket_pins = pins
	return count

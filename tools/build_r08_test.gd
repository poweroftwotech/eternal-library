extends SceneTree
## Builds rooms/test/scriptorium_glass.tscn: the Orosi Scriptorium's step 1 test
## room (phase 17, R08). A plain 12 x 16 m hall, 6.4 m high, with the orosi wall
## at its far end and the moss garden behind it, a dark beamed ceiling, a few
## stand-in desks where the coloured light falls, and nothing else: it is for
## judging the glass and its light. Walk it with
##   godot --path . -- --room=res://rooms/test/scriptorium_glass.tscn
## or from the Strata Board: the Grand Study, copy scriptorium_glass, Walk this seed
## (gen/recipes/drafts/grand_study/scriptorium_glass.tres).
## Run: --headless --script res://tools/build_r08_test.gd

const OUT: String = "res://rooms/test/scriptorium_glass.tscn"
const WALL: String = "res://kit/modules/walls/sc_orosi_wall.tscn"
const GARDEN: String = "res://kit/modules/walls/sc_moss_garden.tscn"
const FLOOR: String = "res://kit/modules/walls/floor_4m.tscn"
const PLAIN: String = "res://kit/modules/walls/wall_plain_4m.tscn"
const ARCH: String = "res://kit/modules/walls/wall_arch_3m.tscn"
const RUG: String = "res://kit/modules/walls/rug_runner.tscn"
const ATMOSPHERE: String = "res://kit/atmosphere/reading_room.tres"
const W: float = 12.0
const LENGTH: float = 16.0
const HEIGHT: float = 6.4

var _room: Node3D
var _parent: Node


func _init() -> void:
	_room = (load("res://scripts/world/room_template.gd") as GDScript).new()
	_room.name = "ScriptoriumGlass"
	_room.set("room_id", "scriptorium_glass")
	_room.set("display_name", "Orosi Scriptorium (glass test)")
	_parent = _room
	# The hall in its own frame (the far wall's room face at Z 0, the entry at Z 16),
	# set back so the entry sits on the room's origin and the hall runs to -Z, as
	# an area's rooms do (AreaPlanner._scene_info).
	var hall := Node3D.new()
	hall.name = "Hall"
	hall.position = Vector3(0.0, 0.0, -LENGTH)
	_add(hall)
	_parent = hall
	_put(WALL, "OrosiWall", Transform3D.IDENTITY)
	_put(GARDEN, "MossGarden", Transform3D.IDENTITY)
	var setup := OrosiWallSetup.new()
	setup.name = "Glass"
	_add(setup)
	setup.wall = NodePath("../OrosiWall")
	# Floor cells (a cell spans X x..x+4, Z z-4..z).
	for i: int in 3:
		for j: int in 4:
			_put(FLOOR, "Floor_%d_%d" % [i, j], Transform3D(Basis.IDENTITY, Vector3(4.0 * i, 0.0, 4.0 * (j + 1))))
	# The long walls in two courses (the kit's plain wall is 4 m high).
	for j: int in 4:
		for course: int in 2:
			var y: float = 4.0 * course
			_put(PLAIN, "WallW_%d_%d" % [j, course], Transform3D(Basis(Vector3.UP, -PI / 2.0), Vector3(0.0, y, 4.0 * j)))
			_put(PLAIN, "WallE_%d_%d" % [j, course], Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(W, y, 4.0 * (j + 1))))
	for i: int in 3:
		for course: int in 2:
			var piece: String = ARCH if i == 1 and course == 0 else PLAIN     # the doorway in the middle
			_put(piece, "WallS_%d_%d" % [i, course], Transform3D(Basis.IDENTITY, Vector3(4.0 * i, 4.0 * course, LENGTH)))
	_ceiling()
	_desks()
	for k: int in 2:
		_put(RUG, "Rug_%d" % k, Transform3D(Basis.IDENTITY, Vector3(3.0 + 6.0 * k, 0.01, 8.0)))
	_parent = _room
	# The doorway, looking out (as the Reading Room's): where the area's door
	# back to the Gorge goes.
	var connectors := Node3D.new()
	connectors.name = "Connectors"
	_add(connectors)
	var entry := Marker3D.new()
	entry.name = "SNAP_entry"
	connectors.add_child(entry)
	entry.owner = _room
	entry.add_to_group("room_connector", true)
	entry.transform = Transform3D(Basis(Vector3.UP, PI), Vector3(W / 2.0, 0.0, 0.0))
	entry.set_meta("snap_kind", "door")
	var spawn := Marker3D.new()
	spawn.name = "PlayerSpawn"
	_add(spawn)
	spawn.add_to_group("player_spawn", true)
	spawn.position = Vector3(6.0, 0.05, -1.5)
	var atmo: Node = (load("res://scripts/world/atmosphere.gd") as GDScript).new()
	atmo.name = "Atmosphere"
	atmo.set("profile", load(ATMOSPHERE))
	_add(atmo)
	var packed := PackedScene.new()
	var err: Error = packed.pack(_room)
	if err == OK:
		err = ResourceSaver.save(packed, OUT)
	print("build_r08_test: %s -> %s" % [error_string(err), OUT])
	_room.free()
	quit()


func _add(n: Node) -> void:
	_parent.add_child(n)
	n.owner = _room


func _put(path: String, node_name: String, xform: Transform3D) -> Node3D:
	var n: Node3D = (load(path) as PackedScene).instantiate()
	n.name = node_name
	n.transform = xform
	_add(n)
	return n


func _box(node_name: String, size: Vector3, centre: Vector3, mat: String, collide: bool = false) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.name = node_name
	mi.position = centre
	mi.material_override = PxMaterial.get_or_create(mat)
	_add(mi)
	if collide:
		var body := StaticBody3D.new()
		body.name = node_name + "Body"
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		shape.shape = box
		body.position = centre
		_add(body)
		body.add_child(shape)
		shape.owner = _room


## A dark plank ceiling with beams across the hall every 1.3 m (the atlas's
## timber ceiling, as a stand-in until step 2).
func _ceiling() -> void:
	_box("Ceiling", Vector3(W, 0.2, LENGTH), Vector3(W / 2.0, HEIGHT + 0.1, LENGTH / 2.0), "persian_wood")
	var z: float = 0.65
	var k: int = 0
	while z < LENGTH:
		_box("Beam_%d" % k, Vector3(W, 0.3, 0.26), Vector3(W / 2.0, HEIGHT - 0.15, z), "wood")
		z += 1.3
		k += 1


## Stand-in copy desks (low boxes) where the light falls, and two by the door.
func _desks() -> void:
	var spots: Array[Vector3] = [Vector3(4.2, 0, 2.6), Vector3(7.8, 0, 2.6), Vector3(2.6, 0, 5.0), Vector3(6.0, 0, 5.4),
		Vector3(9.4, 0, 5.0), Vector3(4.2, 0, 11.5), Vector3(7.8, 0, 11.5)]
	for i: int in spots.size():
		var p: Vector3 = spots[i]
		_box("Desk_%d" % i, Vector3(1.2, 0.35, 0.55), p + Vector3(0, 0.175, 0), "persian_wood", true)
		_box("Book_%d" % i, Vector3(0.6, 0.04, 0.4), p + Vector3(0, 0.37, 0), "pages")

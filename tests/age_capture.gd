extends SceneTree
## Phase 3 step 4 GPU captures (needs a real display): R01 + stack gallery
## (seed 7) at years 0, 10 and 40, with one lantern over the west gallery
## tended (lit). Scratch save.
##   godot --path . --resolution 1600x900 --script res://tests/age_capture.gd -- <out_prefix>
## Writes <prefix>_hall_y0/_y10/_y40.png (from the entrance) and
## <prefix>_gallery_y0/_y40.png (down the gallery from R01's west door).

const HALL: Array = [Vector3(6.0, 2.2, -0.8), Vector3(6.0, 4.6, -20.0), 76.0]
const GALLERY: Array = [Vector3(1.0, 1.6, -6.0), Vector3(-12.0, 1.8, -6.0), 70.0]

var room: RoomTemplate
var cam: Camera3D
var ws: Node


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var prefix: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://age"
	ws = root.get_node("WorldState")
	ws.call("forget")
	GeneratedRoom.seed_override = 7
	room = (load("res://rooms/test/reading_room_r02.tscn") as PackedScene).instantiate()
	root.add_child(room)
	cam = Camera3D.new()
	room.add_child(cam)
	cam.current = true
	await frames(60)
	var socket: VariantSocket = room.get_node("Lights/lantern_hanging3").find_children("SOCKET_lamp_state*", "VariantSocket", true, false).front()
	room.tend_lamp(socket, "lit")
	await shot(HALL, prefix + "_hall_y0.png")
	await shot(GALLERY, prefix + "_gallery_y0.png")
	await age(10.0)
	await shot(HALL, prefix + "_hall_y10.png")
	await age(30.0)
	await shot(HALL, prefix + "_hall_y40.png")
	await shot(GALLERY, prefix + "_gallery_y40.png")
	var dark: int = 0
	var n: int = 0
	for r: RoomTemplate in [room, room.get_node("StackGallery") as RoomTemplate]:
		for s: VariantSocket in r.sockets():
			if s.mode == VariantSocket.Mode.STATE and s.socket_set != null and s.socket_set.index_of("lit") >= 0:
				n += 1
				dark += 1 if s.picked_label() == "dark" else 0
	print("age_capture: year 40, %d of %d lamps dark; the tended one is %s" % [dark, n, socket.picked_label()])
	GeneratedRoom.seed_override = -1
	quit(0)


func age(years: float) -> void:
	ws.call("advance_years", years)
	for r: RoomTemplate in [room, room.get_node("StackGallery") as RoomTemplate]:
		r.refresh_aging()
	await frames(10)


func frames(n: int) -> void:
	for _i: int in n:
		await process_frame


func shot(view: Array, path: String) -> void:
	cam.fov = view[2]
	cam.look_at_from_position(view[0], view[1])
	await frames(30)
	var err: Error = root.get_viewport().get_texture().get_image().save_png(path)
	print("age_capture: ", "saved " + path if err == OK else "FAILED " + error_string(err))

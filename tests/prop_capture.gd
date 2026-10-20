extends SceneTree
## Phase 3 slice 1 GPU captures (needs a real display, not --headless):
##   godot --path . --resolution 1600x900 --script res://tests/prop_capture.gd -- <out_prefix>
## In R01 (rooms/authored/reading_room.tscn, as saved) writes:
##   <prefix>_vases.png     bay 4 with both vases standing
##   <prefix>_falling.png   the west vase pushed (as E does), mid-fall
##   <prefix>_fallen.png    once it has come to rest
##   <prefix>_shards.png    the east vase dropped from 1.4 m, broken, at rest
##   <prefix>_table.png / _table_pushed.png   a reading table before and after its props are pushed off
## Then prints the frame time (240 frames, vsync off) with every prop frozen,
## and again with every prop removed. Run `godot --headless --import` first.

const ROOM: String = "res://rooms/authored/reading_room.tscn"
const VASE_VIEW: Array = [Vector3(6.0, 1.5, -18.9), Vector3(2.2, 0.45, -16.4), 58.0]
const SHARD_VIEW: Array = [Vector3(7.0, 1.4, -18.6), Vector3(9.8, 0.1, -16.4), 56.0]
const TABLE_VIEW: Array = [Vector3(5.6, 2.0, -3.4), Vector3(3.3, 0.6, -6.6), 60.0]

var room: RoomTemplate
var cam: Camera3D


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var prefix: String = args[0] if args.size() > 0 else "user://prop"
	room = (load(ROOM) as PackedScene).instantiate()
	root.add_child(room)
	cam = Camera3D.new()
	room.add_child(cam)
	cam.current = true
	await frames(100)
	var frozen_ms: float = await frame_time()
	var west: WorldProp = room.get_node("Props/VaseIwanWest")
	var east: WorldProp = room.get_node("Props/VaseIwanEast")
	await shot(VASE_VIEW, prefix + "_vases.png")
	west.push(Vector3(0, 0, -1.8 * west.mass), west.global_position + Vector3(0, 0.75, 0.2))
	await frames(16)
	await shot(VASE_VIEW, prefix + "_falling.png", 0)
	await settle()
	await shot(VASE_VIEW, prefix + "_fallen.png")
	east.global_position += Vector3(0, 1.4, 0)
	east.wake()
	await settle()
	await shot(SHARD_VIEW, prefix + "_shards.png")
	await shot(TABLE_VIEW, prefix + "_table.png")
	var table: Node = room.get_node("Dressing/table_reading")
	for p: Node in table.find_children("*", "WorldProp", true, false):
		var prop := p as WorldProp
		prop.push(Vector3(-1.6, 0, 0.3) * prop.mass, prop.global_position + Vector3(0.05, 0.06, 0))
	await settle()
	await shot(TABLE_VIEW, prefix + "_table_pushed.png")
	for p: Node in room.find_children("*", "WorldProp", true, false):
		p.queue_free()
	for p: Node in room.find_children("*", "Shards", true, false):
		p.queue_free()
	await frames(5)
	var none_ms: float = await frame_time()
	print("prop_capture: frame time %.2f ms with every prop frozen, %.2f ms with none" % [frozen_ms, none_ms])
	quit(0)


func frames(n: int) -> void:
	for _i: int in n:
		await process_frame


## Waits until no prop or shard is awake (or 10 s).
func settle() -> void:
	for _i: int in 600:
		await physics_frame
		var shards_moving: bool = room.find_children("*", "Shards", true, false).any(func(s: Node) -> bool: return not (s as Shards).all_frozen)
		if WorldProp.awake_props.is_empty() and not shards_moving:
			break
	await frames(10)


func shot(view: Array, path: String, wait: int = 20) -> void:
	cam.fov = view[2]
	cam.look_at_from_position(view[0], view[1])
	await frames(wait)
	var err: Error = root.get_viewport().get_texture().get_image().save_png(path)
	print("prop_capture: ", "saved " + path if err == OK else "FAILED " + error_string(err))


func frame_time() -> float:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	cam.fov = 74.0
	cam.look_at_from_position(Vector3(6.0, 1.7, -0.8), Vector3(6.0, 2.5, -20.0))
	await frames(30)
	var t0: int = Time.get_ticks_usec()
	await frames(240)
	return (Time.get_ticks_usec() - t0) / 240000.0

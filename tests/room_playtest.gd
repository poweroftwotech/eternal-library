extends SceneTree
## Phase 1 step 6 route audit: the real game (main.tscn, player.gd, HUD) in the
## reading room, driven by input actions like a person at the keyboard.
##   godot --headless --path . --script res://tests/room_playtest.gd
## Walks the hall into the iwan, climbs the west stair, rounds the U gallery to
## the east side and comes down the east stair, and checks the menu round trip.

var main_script: GDScript = load("res://scripts/main.gd")   # static room_override lives here
const ROOM: String = "res://rooms/authored/reading_room.tscn"
const GALLERY_Y: float = 4.15

var failures: PackedStringArray = []
var checks: int = 0
var game: Node
var player: CharacterBody3D
var lowest: float = INF


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures.append(what)


func run() -> void:
	main_script.room_override = ROOM
	game = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	for _i: int in 10:
		await physics_frame
	player = game.player
	check(game.in_room() and game.world is RoomTemplate, "main boots the reading room")
	check(game.hud.zone_label.text == "THE READING ROOM", "HUD names the room (%s)" % game.hud.zone_label.text)
	var spawn: Vector3 = game.world.get_node("PlayerSpawn").global_position
	check(player.global_position.distance_to(spawn) < 0.3 and player.is_on_floor(), "player stands on the spawn (%s)" % player.global_position)
	check(game.world.get_world_3d().environment != null, "the room's Atmosphere supplies the environment")

	# Hall: down the runner, step aside of the iwan centrepiece, into the alcove.
	await walk(PI * 0.0, func(p: Vector3) -> bool: return p.z < -17.5)
	await walk(PI * 0.5, func(p: Vector3) -> bool: return p.x < 4.0)
	var at: Vector3 = await walk(0.0, func(p: Vector3) -> bool: return p.z < -21.6)
	check(at.z < -21.4 and absf(at.y) < 0.1, "walk the hall into the iwan (%s)" % at)

	# West stair: from bay 4 up toward the entrance onto the west gallery...
	await walk(PI, func(p: Vector3) -> bool: return p.z > -18.5)
	await walk(PI * 0.5, func(p: Vector3) -> bool: return p.x < 0.95)
	at = await walk(PI, func(p: Vector3) -> bool: return p.z > -4.0)
	check(at.z > -5.0 and absf(at.y - GALLERY_Y) < 0.1, "west stair up to the gallery (%s)" % at)
	# ...round the U: west gallery, end gallery over the entrance, east gallery.
	await walk(PI, func(p: Vector3) -> bool: return p.z > -0.95)
	at = await walk(-PI * 0.5, func(p: Vector3) -> bool: return p.x > 11.05)
	check(at.x > 10.6 and absf(at.y - GALLERY_Y) < 0.1, "along the end gallery to the east corner (%s)" % at)
	at = await walk(0.0, func(p: Vector3) -> bool: return p.z < -7.6)
	check(at.z < -7.0 and absf(at.y - GALLERY_Y) < 0.1, "east gallery to the stair head (%s)" % at)
	# East stair (the mirrored one) back down to the floor in bay 4.
	at = await walk(0.0, func(p: Vector3) -> bool: return p.z < -17.0)
	check(at.z < -16.5 and absf(at.y) < 0.1, "down the east stair to the floor (%s)" % at)

	check(lowest > -0.3, "the player never dropped below the floor (lowest %.2f)" % lowest)
	game.show_menu()
	var actions: Array = game.hud.options.map(func(o: Dictionary) -> String: return o.action)
	check(actions.has("go_camp") and not actions.has("go_reading_room"), "menu offers the way back to the camp (%s)" % [actions])
	game.close_panel()
	main_script.room_override = ""
	print("room_playtest: %d checks, %d failures" % [checks, failures.size()])
	for f: String in failures:
		print("  FAIL ", f)
	quit(1 if not failures.is_empty() else 0)


## Face `yaw` (0 = -Z) and hold forward until `done`(position) or 12 s.
func walk(yaw: float, done: Callable) -> Vector3:
	player.rotation.y = yaw
	Input.action_press("forward")
	for _i: int in 720:
		await physics_frame
		lowest = minf(lowest, player.global_position.y)
		if done.call(player.global_position):
			break
	Input.action_release("forward")
	for _i: int in 12:     # let it come to rest
		await physics_frame
	return player.global_position

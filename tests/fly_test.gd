extends SceneTree
## Fly mode (V, player.gd set_flying): in the camp, flying goes where you look
## and through walls, rises and sinks on Space and C, never sets off a door
## (the gallery's door to the Gorge), and landing gives you gravity back. The
## save records that you were flying (main._on_saving).
##   godot --headless --path . --script res://tests/fly_test.gd

var game: Node
var checks: int = 0
var failures: PackedStringArray = []


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures.append(what)


func frames(n: int) -> void:
	for _i: int in n:
		await physics_frame


func run() -> void:
	(load("res://scripts/main.gd") as GDScript).set("room_override", "camp")
	game = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await frames(12)
	var player: CharacterBody3D = game.player
	check(InputMap.has_action("fly") and InputMap.has_action("fly_down"), "the fly keys are bound (V; C or Ctrl)")
	var said: Array[String] = []
	player.fly_status.connect(func(text: String) -> void: said.append(text))
	# Through the archive's west pier (x 4..6 at z 0, solid sandstone): walking stops at it, flying doesn't.
	player.teleport(Vector3(2.5, .08, 0.0), -PI / 2)     # facing +X
	Input.action_press("forward")
	await frames(90)
	Input.action_release("forward")
	check(player.global_position.x < 4.0, "walking stops at the pier (x %.2f)" % player.global_position.x)
	player.teleport(Vector3(2.5, .08, 0.0), -PI / 2)
	player.set_flying(true)
	await frames(2)
	check(not said.is_empty() and said[-1].begins_with("Flying"), "turning it on says so on the HUD (%s)" % [said])
	Input.action_press("forward")
	await frames(90)
	Input.action_release("forward")
	check(player.global_position.x > 6.5, "flying goes through walls (x %.2f)" % player.global_position.x)
	check(absf(player.global_position.y - .08) < .05, "level flight holds its height, no gravity (y %.2f)" % player.global_position.y)
	# Space rises, C sinks.
	var y0: float = player.global_position.y
	Input.action_press("jump")
	await frames(60)
	Input.action_release("jump")
	check(player.global_position.y > y0 + 4.0, "Space rises (%.2f to %.2f)" % [y0, player.global_position.y])
	var y1: float = player.global_position.y
	Input.action_press("fly_down")
	await frames(30)
	Input.action_release("fly_down")
	check(player.global_position.y < y1 - 2.0, "C sinks (%.2f to %.2f)" % [y1, player.global_position.y])
	# Looking up and pressing forward climbs: you go where you look.
	player.teleport(Vector3(0, 3, 6), 0.0, 0.8)
	Input.action_press("forward")
	await frames(30)
	Input.action_release("forward")
	check(player.global_position.y > 4.5 and player.global_position.z < 5.5, "forward goes where you look, up included (%s)" % player.global_position)
	# Through the gallery's doorway: the door to the Gorge doesn't see you.
	var door: Threshold = game.call("_door_to", "gorge")
	player.teleport(Vector3(-1, 2.3, -11.5), 0.0)
	Input.action_press("forward")
	await frames(90)
	Input.action_release("forward")
	check(door != null and not door.crossed and player.global_position.z < -14.5, "flying through the gallery's doorway doesn't set off its door (z %.2f, crossed %s)" % [player.global_position.z, door.crossed if door != null else "no door"])
	# The save notes you were flying.
	game.call("_on_saving")
	check(bool((game.ws().data.get("player", {}) as Dictionary).get("flying", false)), "the save records that you were flying")
	# Landing: gravity again, onto the hall floor.
	player.teleport(Vector3(2.0, 3.0, 6.0), 0.0)
	player.set_flying(false)
	await frames(90)
	check(player.is_on_floor() and player.global_position.y < .3, "landing falls back to the floor (%s)" % player.global_position)
	check(said[-1].begins_with("Landed"), "landing says so")
	print("fly_test: %d checks, %d failures" % [checks, failures.size()])
	for f: String in failures:
		print("  FAIL ", f)
	quit(1 if not failures.is_empty() else 0)

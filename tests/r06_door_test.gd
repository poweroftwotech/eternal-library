extends SceneTree
## The Domicile Quarter's house door (phase 14 step 3), on its own: placed turned,
## as a room places it. It must stop the player's capsule shut, let it through
## open, swing into the house whichever way it faces, and answer the interaction
## ray.
##   godot --audio-driver Dummy --headless --path . --script res://tests/r06_door_test.gd

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ", what)


func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var player := CharacterBody3D.new()
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 1.75
	shape.shape = capsule
	shape.position.y = 0.875
	player.add_child(shape)
	player.collision_layer = 0
	player.collision_mask = 1
	world.add_child(player)
	for yaw: float in [0.0, PI * 0.5, PI, -PI * 0.5]:
		await _one(world, player, yaw)
	print("r06_door_test: %s (%d checks, %d failures)" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(1 if failures > 0 else 0)


func _one(world: Node3D, player: CharacterBody3D, yaw: float) -> void:
	var name: String = "yaw %.1f" % yaw
	var door: HomeDoor = (load("res://gen/modules/quarter_door.tscn") as PackedScene).instantiate()
	var frame := Transform3D(Basis(Vector3.UP, yaw), Vector3(3.0, 0.0, -2.0))
	door.transform = frame
	world.add_child(door)
	await physics_frame
	await physics_frame
	# The line through the doorway, in the door's frame: lane (-Z) to house (+Z).
	var mid: Vector3 = frame * Vector3(0.62, 0.05, 0.0)
	var from: Vector3 = mid - frame.basis.z * 0.8
	var motion: Vector3 = frame.basis.z * 1.6
	check(door.interaction_prompt(Vector3.ZERO) == "Open the door", name + ": says open")
	check(_stopped(player, from, motion), name + ": shut, it stops the player")
	var eye: Vector3 = mid + Vector3(0, 1.5, 0) - frame.basis.z * 0.6
	var ray := PhysicsRayQueryParameters3D.create(eye, eye + frame.basis.z * 1.2, 2)
	var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(ray)
	check(hit.get("collider") == door, name + ": the interaction ray finds it")
	door.interact(player, Vector3.ZERO)
	for _i: int in 60:
		await physics_frame
	check(door.transform.is_equal_approx(frame), name + ": the body stays where the room put it")
	var tip: Vector3 = door.to_global(door.get_child(0).transform * Vector3(1.26, 0.0, 0.0))
	check((frame.affine_inverse() * tip).z > 1.0, name + ": it swings into the house")
	check(door.interaction_prompt(Vector3.ZERO) == "Shut the door", name + ": says shut")
	check(not _stopped(player, from, motion), name + ": open, the player walks through")
	door.interact(player, Vector3.ZERO)
	for _i: int in 60:
		await physics_frame
	check(_stopped(player, from, motion), name + ": shut again, it stops the player")
	door.queue_free()
	await physics_frame


func _stopped(player: CharacterBody3D, from: Vector3, motion: Vector3) -> bool:
	var params := PhysicsTestMotionParameters3D.new()
	params.from = Transform3D(Basis(), from)
	params.motion = motion
	return PhysicsServer3D.body_test_motion(player.get_rid(), params)

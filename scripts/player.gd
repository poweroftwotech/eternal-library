extends CharacterBody3D
signal interact_requested(target)
var camera: Camera3D
var ray: RayCast3D
var blocked: bool = true
var sensitivity: float = 0.0024
var invert_y: bool = false
var walking_speed: float = 3.7
var elapsed: float = 0.0
## Where a fall below the world puts you back (the camp default; rooms set their spawn).
var respawn_point: Vector3 = Vector3(0, 0.2, 11.5)

func _ready() -> void:
	name = "Player"
	collision_layer = 4
	collision_mask = 1
	floor_snap_length = 0.3
	var collider = CollisionShape3D.new()
	var capsule = CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 1.75
	collider.shape = capsule
	collider.position.y = 0.9
	add_child(collider)
	camera = Camera3D.new()
	camera.position.y = 1.62
	camera.fov = 74
	camera.far = 950.0
	add_child(camera)
	camera.current = true
	ray = RayCast3D.new()
	ray.target_position = Vector3(0, 0, -4.0)
	ray.collision_mask = 3
	ray.add_exception(self)
	camera.add_child(ray)

func _unhandled_input(event: InputEvent) -> void:
	if blocked or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * sensitivity)
		var factor: float = -1.0 if invert_y else 1.0
		camera.rotation.x = clampf(camera.rotation.x - event.relative.y * sensitivity * factor, -1.4, 1.4)
	if event.is_action_pressed("interact"):
		var target = get_target()
		if target != null:
			interact_requested.emit(target)

func _physics_process(delta: float) -> void:
	if blocked:
		velocity = Vector3.ZERO
		return
	if not is_on_floor():
		velocity.y -= 18.0 * delta
	elif Input.is_action_just_pressed("jump"):
		velocity.y = 5.1
	var input_vector = Input.get_vector("left", "right", "forward", "back")
	var direction = transform.basis * Vector3(input_vector.x, 0, input_vector.y)
	var speed: float = walking_speed * (1.6 if Input.is_action_pressed("sprint") else 1.0)
	velocity.x = move_toward(velocity.x, direction.x * speed, 24.0 * delta)
	velocity.z = move_toward(velocity.z, direction.z * speed, 24.0 * delta)
	move_and_slide()
	elapsed += delta
	# Minimal, subtle movement: no compulsory camera shake or strong head bob.
	if position.y < -8.0:
		position = respawn_point
		velocity = Vector3.ZERO

func get_target():
	if ray.is_colliding():
		var body = ray.get_collider()
		if body != null and body.has_method("get_interaction_id"):
			return body
	return null

func teleport(pose: Vector3, yaw: float = 0.0, pitch: float = 0.0) -> void:
	position = pose
	rotation.y = yaw
	camera.rotation.x = clampf(pitch, -1.4, 1.4)
	velocity = Vector3.ZERO

extends CharacterBody3D
signal interact_requested(target)
## Fly mode turned on or off, or its speed changed: a line for the HUD.
signal fly_status(text: String)
var camera: Camera3D
var ray: RayCast3D
var blocked: bool = true
var sensitivity: float = 0.0024
var invert_y: bool = false
var walking_speed: float = 3.7
## In shallow water (a floor kit_import marked "wade") you move at this share of your speed (phase 5 Q10).
var wade_speed_factor: float = 0.5
var wading: bool = false
var elapsed: float = 0.0
## Where a fall below the world puts you back (the camp default; rooms set their spawn).
var respawn_point: Vector3 = Vector3(0, 0.2, 11.5)
## Falling below this height puts you back at respawn_point (the area recipe can lower it).
var fall_limit: float = -8.0
## No-clip flight for finding faults (V): no gravity, no collision, no doors;
## you go where you look. Space rises, C or Ctrl sinks, Shift is 4x, the mouse
## wheel sets the speed (FLY_SPEEDS m/s).
var flying: bool = false
var fly_speed: float = 8.0
const FLY_SPEEDS := Vector2(1.0, 128.0)
var collider: CollisionShape3D

func _ready() -> void:
	name = "Player"
	# Layer 4 = player; collides with the world (1), props (3) and the walls only
	# the player meets (8, deep water): ENVIRONMENT_PLAN.md 6.4, phase-5-design.md 5.6.4.
	collision_layer = 1 << 3
	collision_mask = 1 | WorldProp.LAYER_PROPS | (1 << 7)
	floor_snap_length = 0.3
	collider = CollisionShape3D.new()
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
	ray.collision_mask = 1 | 2 | WorldProp.LAYER_PROPS     # world, interaction targets, props
	ray.add_exception(self)
	camera.add_child(ray)

func _unhandled_input(event: InputEvent) -> void:
	if blocked or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * sensitivity)
		var factor: float = -1.0 if invert_y else 1.0
		camera.rotation.x = clampf(camera.rotation.x - event.relative.y * sensitivity * factor, -1.4, 1.4)
	if event.is_action_pressed("fly"):
		set_flying(not flying)
		return
	if flying and event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		fly_speed = clampf(fly_speed * (1.25 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 0.8), FLY_SPEEDS.x, FLY_SPEEDS.y)
		fly_status.emit("Flying at %.0f m/s (wheel: speed, Shift: 4x)" % fly_speed)
	if event.is_action_pressed("interact"):
		var target = get_target()
		if target != null:
			interact_requested.emit(target)

func _physics_process(delta: float) -> void:
	if blocked:
		velocity = Vector3.ZERO
		return
	if flying:
		var input_fly: Vector2 = Input.get_vector("left", "right", "forward", "back")
		var heading: Vector3 = camera.global_basis * Vector3(input_fly.x, 0, input_fly.y)
		heading.y += (1.0 if Input.is_action_pressed("jump") else 0.0) - (1.0 if Input.is_action_pressed("fly_down") else 0.0)
		var fly: float = fly_speed * (4.0 if Input.is_action_pressed("sprint") else 1.0)
		velocity = velocity.lerp(heading.limit_length(1.0) * fly, minf(1.0, 10.0 * delta))
		position += velocity * delta
		return
	if not is_on_floor():
		velocity.y -= 18.0 * delta
	elif Input.is_action_just_pressed("jump"):
		velocity.y = 5.1
	var input_vector = Input.get_vector("left", "right", "forward", "back")
	var direction = transform.basis * Vector3(input_vector.x, 0, input_vector.y)
	var speed: float = walking_speed * (1.6 if Input.is_action_pressed("sprint") else 1.0) * (wade_speed_factor if wading else 1.0)
	velocity.x = move_toward(velocity.x, direction.x * speed, 24.0 * delta)
	velocity.z = move_toward(velocity.z, direction.z * speed, 24.0 * delta)
	var walk: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	move_and_slide()
	if not is_on_floor():
		wading = false
	elif get_slide_collision_count() > 0:     # standing still reports no collision: keep the last answer
		wading = on_wading_floor()
	bump_props(walk)
	elapsed += delta
	# Minimal, subtle movement: no compulsory camera shake or strong head bob.
	if position.y < fall_limit:
		position = respawn_point
		velocity = Vector3.ZERO

## Walking into a WorldProp wakes it and shoves it along (not props you stand on).
func bump_props(walk: Vector3) -> void:
	var speed: float = walk.length()
	if speed < 0.1:
		return
	var dir: Vector3 = walk / speed
	for i: int in get_slide_collision_count():
		var hit: KinematicCollision3D = get_slide_collision(i)
		var prop: WorldProp = hit.get_collider() as WorldProp
		if prop != null and hit.get_normal().y < 0.7 and -hit.get_normal().dot(dir) > 0.2:
			prop.bump(dir, speed, hit.get_position())

func get_target():
	if ray.is_colliding():
		var body = ray.get_collider()
		if body != null and (body.has_method("get_interaction_id") or body.has_method("interaction_prompt")):
			return body
	return null

## Where the interaction ray hits (the aimed point on the target).
func aim_point() -> Vector3:
	return ray.get_collision_point() if ray.is_colliding() else camera.global_position - camera.global_basis.z * 2.0

## Fly mode on or off (V). Landing leaves you where you are, falling.
func set_flying(on: bool) -> void:
	flying = on
	collider.set_deferred("disabled", on)     # through walls, and doors (thresholds) don't see you
	velocity = Vector3.ZERO
	wading = false
	fly_status.emit("Flying (no-clip) at %.0f m/s: Space up, C down, wheel for speed; V to land" % fly_speed if on else "Landed: walking again")

func teleport(pose: Vector3, yaw: float = 0.0, pitch: float = 0.0) -> void:
	position = pose
	rotation.y = yaw
	camera.rotation.x = clampf(pitch, -1.4, 1.4)
	velocity = Vector3.ZERO

## Standing on a floor in shallow water (the module's floor body carries "wade").
func on_wading_floor() -> bool:
	for i: int in get_slide_collision_count():
		var hit: KinematicCollision3D = get_slide_collision(i)
		var body: Object = hit.get_collider()
		if hit.get_normal().y > 0.7 and body != null and body.has_meta("wade"):
			return true
	return false

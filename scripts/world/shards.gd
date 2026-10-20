@tool
class_name Shards
extends Node3D
## The pieces of a broken WorldProp (ENVIRONMENT_PLAN.md 6.5.1). The scene
## holds the prop's broken module (each shard a mesh, assembled in place).
## On load every mesh becomes a small rigid body on the props layer with a
## convex hull. WorldProp.shatter() launches them with the prop's motion;
## each freezes once it has lain still, like a WorldProp, and they stay
## where they land (Q3: the mess is kept).

signal settled

## Mass of each piece (kg).
@export_range(0.01, 20.0, 0.01) var piece_mass: float = 0.5
## Empty = world/props/prop_settings.tres.
@export var settings: PropSettings

var pieces: Array[RigidBody3D] = []
var all_frozen: bool = false
var _still: Dictionary = {}     # piece -> seconds still


func _ready() -> void:
	if settings == null:
		settings = PropSettings.default()
	if pieces.is_empty() and not Engine.is_editor_hint():     # in the editor, leave the scene as authored
		_build()


func _build() -> void:
	var i: int = 0
	for inst: MeshInstance3D in WorldProp.meshes_under(self):
		if inst.mesh == null:
			continue
		var xf: Transform3D = WorldProp.relative(self, inst)
		var body := RigidBody3D.new()
		body.name = "Piece%d" % i
		body.mass = piece_mass
		body.collision_layer = WorldProp.LAYER_PROPS
		body.collision_mask = WorldProp.MASK
		body.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
		body.angular_damp = settings.roll_damp
		body.position = xf * inst.mesh.get_aabb().get_center()
		add_child(body, false, Node.INTERNAL_MODE_BACK)
		inst.get_parent().remove_child(inst)
		body.add_child(inst)
		inst.transform = body.transform.affine_inverse() * xf
		WorldProp.ensure_collision(body, "%s#%d" % [scene_file_path, i] if scene_file_path != "" else "")
		WorldProp.localize_materials(body)
		pieces.append(body)
		i += 1


## Sets every piece moving with the prop's motion plus a small outward kick
## from `centre` (global), seeded by position so a break is repeatable.
func launch(linear: Vector3, angular: Vector3, centre: Vector3) -> void:
	if pieces.is_empty():
		_build()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(centre.snappedf(0.01))
	all_frozen = false
	for body: RigidBody3D in pieces:
		var out: Vector3 = body.global_position - centre
		out = out.normalized() if out.length_squared() > 1e-6 else Vector3.UP
		body.freeze = false
		body.linear_velocity = linear + angular.cross(body.global_position - centre) + out * settings.shard_scatter * rng.randf()
		body.angular_velocity = angular + Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * 3.0
		_still[body] = 0.0


## Freezes every piece where it lies now.
func freeze_all() -> void:
	for body: RigidBody3D in pieces:
		body.linear_velocity = Vector3.ZERO
		body.angular_velocity = Vector3.ZERO
		body.freeze = true
	all_frozen = true


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or all_frozen or _still.is_empty():
		return
	var moving: int = 0
	for body: RigidBody3D in pieces:
		if body.freeze:
			continue
		if body.sleeping or (body.linear_velocity.length() < 0.04 and body.angular_velocity.length() < 0.1):
			_still[body] = float(_still[body]) + delta
			if float(_still[body]) >= settings.sleep_refreeze_s:
				body.freeze = true
				continue
		else:
			_still[body] = 0.0
		moving += 1
	if moving == 0:
		all_frozen = true
		settled.emit()

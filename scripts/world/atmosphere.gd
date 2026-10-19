@tool
class_name Atmosphere
extends Node
## A room's look (ENVIRONMENT_PLAN.md 4.2, phase 1 step 4). Put one under a
## RoomTemplate and give it an AtmosphereProfile (kit/atmosphere/*.tres).
##
## - Environment: when nothing else in the world supplies one, it adds an
##   internal WorldEnvironment built from the profile (never saved). Once areas
##   own the environment, they apply their profile and the room's is skipped.
## - Lamps: lit lanterns in the room sway gently (profile.lantern_sway), as the
##   prototype's atmosphere.gd did. Failing lamps keep LampState's flicker.
## - Time: tick(t) is deterministic, so captures can freeze the clock.

@export var profile: AtmosphereProfile:
	set(value):
		profile = value
		if is_inside_tree():
			_rebuild()
## Turn off when the area (or game world) supplies the environment.
@export var own_environment: bool = true:
	set(value):
		own_environment = value
		if is_inside_tree():
			_rebuild()
## Animate lantern sway in the editor too.
@export var animate_in_editor: bool = false

var time: float = 0.0
var _world_env: WorldEnvironment


func _ready() -> void:
	_rebuild()


func _exit_tree() -> void:
	_drop_environment()


func _process(delta: float) -> void:
	if Engine.is_editor_hint() and not animate_in_editor:
		return
	tick(time + delta)


## The environment this node built, or null (none needed or none allowed).
func environment() -> Environment:
	return _world_env.environment if is_instance_valid(_world_env) else null


func tick(t: float) -> void:
	time = t
	if profile == null or profile.lantern_sway <= 0.0:
		return
	for light: Light3D in lit_lanterns():
		var p: float = t + light.global_position.dot(Vector3(0.7, 1.3, 0.9))
		var base: float = light.get_meta("lamp_base_energy", light.light_energy)
		if not light.has_meta("lamp_base_energy"):
			light.set_meta("lamp_base_energy", base)
		light.light_energy = base * (1.0 + profile.lantern_sway * (sin(p * 2.3) + 0.55 * sin(p * 4.1)))


## Kit lights in this room whose lamp is lit (or has no state socket).
func lit_lanterns() -> Array[Light3D]:
	var out: Array[Light3D] = []
	var room: Node = get_parent()
	if room == null or not is_inside_tree():
		return out
	for n: Node in get_tree().get_nodes_in_group("kit_light"):
		if n is Light3D and room.is_ancestor_of(n) and str(n.get_meta("lamp_state", "lit")) == "lit":
			out.append(n as Light3D)
	return out


func _rebuild() -> void:
	_drop_environment()
	if profile == null or not own_environment:
		return
	if _environment_supplied():
		return     # an area, the game world or another room already owns the look
	_world_env = WorldEnvironment.new()
	_world_env.name = "AtmosphereEnvironment"
	_world_env.environment = profile.build_environment()
	add_child(_world_env, false, Node.INTERNAL_MODE_BACK)


## In the game: any environment already on the world. In the editor the 3D
## view's preview environment is always on the world (and steps aside once a
## WorldEnvironment enters the scene), so only a WorldEnvironment saved in the
## edited scene counts there.
func _environment_supplied() -> bool:
	if Engine.is_editor_hint():
		var edited: Node = get_tree().edited_scene_root
		return edited != null and not edited.find_children("*", "WorldEnvironment", true, true).is_empty()
	var world: World3D = get_viewport().find_world_3d() if get_viewport() != null else null
	return world != null and world.environment != null


func _drop_environment() -> void:
	if is_instance_valid(_world_env):
		remove_child(_world_env)
		_world_env.queue_free()
	_world_env = null

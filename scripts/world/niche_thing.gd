class_name NicheThing
extends StaticBody3D
## What the player's ray finds in a working niche (room rework step 2): a
## forage patch (hearthleaf, amberroot, shelf mushrooms, as the camp's) or a
## hearth's cooking pot. main.gd does the work, as it does for the camp's: a
## patch adds to the satchel and shrinks to a stub, the pot opens the cooking
## panel. A pot also marks a hearth: standing within WARM_REACH of it warms
## you, as the camp's fire does.
##
## Patches grow back when the room is next built (the camp's don't save
## either); nothing goes in the save.

const KINDS: Dictionary = {"herb": "hearthleaf", "root": "amberroot", "mushroom": "shelf mushrooms"}
## As the camp's fire (main.gd).
const WARM_REACH: float = 3.1

## "herb", "root", "mushroom" or "pot".
@export var kind: String = "herb"
## The patch's plants, shrunk to a stub when gathered.
@export var visual: NodePath
## A pot's fire light: it flickers as the camp's does.
@export var fire: NodePath

var taken: bool = false
var _fire: Light3D
var _base: float = 0.0
var _t: float = 0.0


func _ready() -> void:
	collision_layer = 2
	collision_mask = 0
	if kind == "pot":
		add_to_group("hearth")
	_fire = get_node_or_null(fire) as Light3D
	if _fire != null:
		_base = _fire.light_energy
		_t = global_position.x * 1.7 + global_position.z
	set_process(_fire != null)


func _process(delta: float) -> void:
	_t += delta
	var slow: float = sin(_t * 2.1) * .40 + sin(_t * 3.73 + .7) * .28 + sin(_t * 6.21 + 1.2) * .12
	_fire.light_energy = _base + slow * _base * .33
	_fire.light_color = Color("ff9d42").lerp(Color("ffd08a"), .48 + slow * .24)


func interaction_prompt(_hit: Vector3) -> String:
	return "Cook at the hearth" if kind == "pot" else "Gather " + str(KINDS.get(kind, kind))


## Gathers the patch: the kind, or "" (the pot, or already taken).
func take() -> String:
	if kind == "pot" or taken:
		return ""
	taken = true
	var v := get_node_or_null(visual) as Node3D
	if v != null:
		v.scale = Vector3.ONE * .16
	collision_layer = 0
	return kind


## Whether `at` (global) is warmed by a hearth in the tree.
static func warmed(tree: SceneTree, at: Vector3) -> bool:
	for n: Node in tree.get_nodes_in_group("hearth"):
		if (n as Node3D).global_position.distance_to(at) < WARM_REACH:
			return true
	return false

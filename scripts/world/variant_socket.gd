@tool
class_name VariantSocket
extends Node3D
## A variation point (ENVIRONMENT_PLAN.md 4.3). Instances one candidate from its
## SocketSet as an internal child, which is never saved into the scene; the pick
## comes from a seed, so the same seed always rebuilds the same room.
##
## Inside a RoomTemplate the room resolves its sockets (seed = room seed + this
## socket's path). Opened on its own, a socket previews with seed 0.

enum Mode { REPLACE, TOGGLE }

@export var socket_set: SocketSet:
	set(value):
		socket_set = value
		_editor_refresh()
@export var mode: Mode = Mode.REPLACE
## TOGGLE mode: chance that the picked candidate appears at all.
@export_range(0.0, 1.0, 0.01) var toggle_chance: float = 0.5
## Force one entry (index into the set); -1 lets the seed choose.
@export var pinned: int = -1:
	set(value):
		pinned = value
		_editor_refresh()
@export_tool_button("Next candidate") var next_action: Callable = _pin_next

var last_pick: int = -1
var _seed: int = 0
var _child: Node


func _ready() -> void:
	if room() == null:
		resolve(0)


## The RoomTemplate this socket belongs to, if any.
func room() -> Node:
	var p: Node = get_parent()
	while p != null:
		if p is RoomTemplate:
			return p
		p = p.get_parent()
	return null


func resolve(seed_value: int) -> int:
	_seed = seed_value
	clear()
	if socket_set == null or socket_set.entries.is_empty():
		last_pick = -1
		return -1
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var idx: int = pinned if pinned >= 0 and pinned < socket_set.entries.size() else socket_set.pick(rng)
	if mode == Mode.TOGGLE and rng.randf() > toggle_chance:
		idx = -1
	if idx >= 0 and socket_set.entries[idx].scene != null:
		_child = socket_set.entries[idx].scene.instantiate()
		_child.set_meta("seed", rng.randi())
		add_child(_child, false, Node.INTERNAL_MODE_BACK)
	last_pick = idx
	return idx


func clear() -> void:
	if is_instance_valid(_child):
		remove_child(_child)
		_child.queue_free()
	_child = null


func picked_label() -> String:
	if last_pick < 0 or socket_set == null:
		return "(none)"
	var e: SocketEntry = socket_set.entries[last_pick]
	return e.label if e.label != "" else e.scene.resource_path.get_file().get_basename()


func _pin_next() -> void:
	if socket_set == null or socket_set.entries.is_empty():
		return
	pinned = (maxi(pinned, last_pick) + 1) % socket_set.entries.size()


func _editor_refresh() -> void:
	if Engine.is_editor_hint() and is_inside_tree():
		resolve(_seed)

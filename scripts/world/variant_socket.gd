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
## Pin set by the owning room (RoomTemplate.socket_pins); wins over `pinned`.
var room_pin: int = -1
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


func resolve(seed_value: int, room_pin_value: int = -1) -> int:
	_seed = seed_value
	room_pin = room_pin_value
	clear()
	if socket_set == null or socket_set.entries.is_empty():
		last_pick = -1
		return -1
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var force: int = effective_pin()
	var idx: int = force if force >= 0 else socket_set.pick(rng)
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
	return entry_label(last_pick)


func _pin_next() -> void:
	if socket_set == null or socket_set.entries.is_empty():
		return
	pinned = (maxi(pinned, last_pick) + 1) % socket_set.entries.size()


func _editor_refresh() -> void:
	if Engine.is_editor_hint() and is_inside_tree():
		resolve(_seed, room_pin)


## The entry this socket is forced to (room pin first, then its own), or -1.
func effective_pin() -> int:
	var n: int = socket_set.entries.size() if socket_set != null else 0
	if room_pin >= 0 and room_pin < n:
		return room_pin
	if pinned >= 0 and pinned < n:
		return pinned
	return -1


func candidate_count() -> int:
	return socket_set.entries.size() if socket_set != null else 0


func entry_label(idx: int) -> String:
	if socket_set == null or idx < 0 or idx >= socket_set.entries.size():
		return "(none)"
	var e: SocketEntry = socket_set.entries[idx]
	if e == null:
		return "(empty)"
	if e.label != "":
		return e.label
	return e.scene.resource_path.get_file().get_basename() if e.scene != null else "(no scene)"

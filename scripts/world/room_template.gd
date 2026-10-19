@tool
class_name RoomTemplate
extends Node3D
## Root of an authored room (ENVIRONMENT_PLAN.md 4.2). Resolves every
## VariantSocket in the room from one seed: in the editor from preview_seed
## (change it, or press Reroll, to see other variants), at runtime from the
## area seed once areas exist (phase 4), otherwise from preview_seed.
##
## socket_pins holds this room's own picks for sockets that live inside
## instanced modules, keyed by socket path relative to the room. It is saved
## with the room, so pinning never needs Editable Children; the Kit dock's
## Sockets panel edits it. A room pin wins over the socket's own `pinned`.

@export var room_id: String = ""
## Shown in the HUD and menus when the room is played on its own.
@export var display_name: String = ""
@export var preview_seed: int = 1:
	set(value):
		preview_seed = value
		if Engine.is_editor_hint() and is_inside_tree():
			resolve_sockets(preview_seed)
@export_tool_button("Reroll sockets") var reroll_action: Callable = _reroll
## {socket path relative to this room: entry index}. Edit from the Kit dock.
@export var socket_pins: Dictionary[String, int] = {}:
	set(value):
		socket_pins = value
		if Engine.is_editor_hint() and is_inside_tree():
			resolve_sockets(_last_seed)
## Set by the area assembler before the room enters the tree; -1 = use preview_seed.
var area_seed: int = -1
var _last_seed: int = 1


func _ready() -> void:
	resolve_sockets(preview_seed if Engine.is_editor_hint() or area_seed < 0 else area_seed)


func sockets() -> Array[VariantSocket]:
	var out: Array[VariantSocket] = []
	_collect(self, out)
	return out


func socket_key(s: VariantSocket) -> String:
	return str(get_path_to(s))


## Returns {socket path: picked index}.
func resolve_sockets(seed_value: int) -> Dictionary:
	_last_seed = seed_value
	var picks: Dictionary = {}
	for s: VariantSocket in sockets():
		var key: String = socket_key(s)
		picks[key] = s.resolve(socket_seed(seed_value, key), socket_pins.get(key, -1))
	return picks


func socket_seed(seed_value: int, key: String) -> int:
	var rid: String = room_id if room_id != "" else String(name)
	return hash([seed_value, rid, key])


## Pins whose socket no longer exists (module renamed, moved or deleted).
func stale_pins() -> PackedStringArray:
	var out: PackedStringArray = []
	for key: String in socket_pins:
		if not get_node_or_null(NodePath(key)) is VariantSocket:
			out.append(key)
	return out


func _collect(node: Node, out: Array[VariantSocket]) -> void:
	for child: Node in node.get_children():
		if child is VariantSocket:
			out.append(child as VariantSocket)
		_collect(child, out)


func _reroll() -> void:
	preview_seed = randi() % 100000
	notify_property_list_changed()

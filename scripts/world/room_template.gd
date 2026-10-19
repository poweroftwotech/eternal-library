@tool
class_name RoomTemplate
extends Node3D
## Root of an authored room (ENVIRONMENT_PLAN.md 4.2). Resolves every
## VariantSocket in the room from one seed: in the editor from preview_seed
## (change it, or press Reroll, to see other variants), at runtime from the
## area seed once areas exist (phase 4), otherwise from preview_seed.

@export var room_id: String = ""
@export var preview_seed: int = 1:
	set(value):
		preview_seed = value
		if Engine.is_editor_hint() and is_inside_tree():
			resolve_sockets(preview_seed)
@export_tool_button("Reroll sockets") var reroll_action: Callable = _reroll
## Set by the area assembler before the room enters the tree; -1 = use preview_seed.
var area_seed: int = -1


func _ready() -> void:
	resolve_sockets(preview_seed if Engine.is_editor_hint() or area_seed < 0 else area_seed)


func sockets() -> Array[VariantSocket]:
	var out: Array[VariantSocket] = []
	_collect(self, out)
	return out


## Returns {socket path: picked index}.
func resolve_sockets(seed_value: int) -> Dictionary:
	var picks: Dictionary = {}
	var rid: String = room_id if room_id != "" else String(name)
	for s: VariantSocket in sockets():
		var key: String = str(get_path_to(s))
		picks[key] = s.resolve(hash([seed_value, rid, key]))
	return picks


func _collect(node: Node, out: Array[VariantSocket]) -> void:
	for child: Node in node.get_children():
		if child is VariantSocket:
			out.append(child as VariantSocket)
		_collect(child, out)


func _reroll() -> void:
	preview_seed = randi() % 100000
	notify_property_list_changed()

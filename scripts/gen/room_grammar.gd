@tool
class_name RoomGrammar
extends Resource
## Layout rules for one generated room type (ENVIRONMENT_PLAN.md 5.5.4); one
## subclass per type, one .tres per variant in gen/grammars/. A grammar only
## marks a CellGrid; RoomBuilder picks the modules from `rules`.

## Room styles: select ModuleRules rules (and later, socket conditions).
@export var styles: PackedStringArray = ["brick"]:
	set(value):
		styles = value
		emit_changed()
@export var rules: ModuleRules:
	set(value):
		if rules != null and rules.changed.is_connected(emit_changed):
			rules.changed.disconnect(emit_changed)
		rules = value
		if rules != null:
			rules.changed.connect(emit_changed)
		emit_changed()


## Fill `grid` (cells, edges, lamps). The entry door is the S side of cell
## (0, 0, 0), joined to the host. Every random choice comes from seed_value.
func layout(_grid: CellGrid, _seed_value: int) -> void:
	push_error("RoomGrammar.layout() is overridden by each room type")

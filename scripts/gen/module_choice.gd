@tool
class_name ModuleChoice
extends Resource
## One weighted kit module in a ModuleRule (ENVIRONMENT_PLAN.md 5.5.3).

## A wrapper scene from kit/modules/ (its root is a KitModule).
@export var scene: PackedScene:
	set(value):
		scene = value
		emit_changed()
## Relative pick weight. 0 disables the choice without deleting it.
@export_range(0.0, 100.0, 0.1) var weight: float = 1.0:
	set(value):
		weight = value
		emit_changed()

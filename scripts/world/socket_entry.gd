@tool
class_name SocketEntry
extends Resource
## One candidate in a SocketSet (ENVIRONMENT_PLAN.md 4.3).

@export var label: String = ""
@export var scene: PackedScene
## Relative pick weight. 0 disables the entry without deleting it.
@export_range(0.0, 100.0, 0.1) var weight: float = 1.0
## Free-form conditions for later phases (stratum, min age, faction ...).
@export var tags: PackedStringArray = []

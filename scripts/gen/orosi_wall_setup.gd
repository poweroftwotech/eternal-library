class_name OrosiWallSetup
extends Node
## Puts a glass palette on an sc_orosi_wall when the room starts (phase 17,
## R08; OrosiGlass.apply). The step 1 test room uses it; the Scriptorium's
## generator will pick the palette by seed.

## For pictures and tests: every wall takes this palette instead ("" = its own).
static var palette_override: String = ""

@export var wall: NodePath
@export var palette: String = "spectrum"


func _ready() -> void:
	var w: Node3D = get_node_or_null(wall) as Node3D
	if w == null:
		push_warning("OrosiWallSetup: no wall at %s" % wall)
		return
	OrosiGlass.apply(w, palette_override if palette_override != "" else palette)

class_name OrosiWallSetup
extends Node
## Puts a glass palette on an sc_orosi_wall when the room starts (phase 17,
## R08; OrosiGlass.apply). The step 1 test room sets `palette`; in the
## Scriptorium (gen/modules/sc_orosi.tscn) the generator puts its pick by seed
## on the module as meta "palette", which wins.

## For pictures and tests: every wall takes this palette instead ("" = its own).
static var palette_override: String = ""

@export var wall: NodePath
@export var palette: String = "spectrum"


func _ready() -> void:
	var w: Node3D = get_node_or_null(wall) as Node3D
	if w == null:
		push_warning("OrosiWallSetup: no wall at %s" % wall)
		return
	var pick: String = palette
	if get_parent() != null and get_parent().has_meta("palette"):
		pick = str(get_parent().get_meta("palette"))
	OrosiGlass.apply(w, palette_override if palette_override != "" else pick)

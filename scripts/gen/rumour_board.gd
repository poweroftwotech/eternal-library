class_name RumourBoard
extends StaticBody3D
## The R04 Grand Bazaar's board of rumours (phase 15 step 4): E reads what is
## pinned to it. Which notes show is settled by where the board stands, so a room
## built again from its seed shows the same ones. The texts are placeholders.

const LIVED: String = "res://kit/modules/walls/bz_rumour_board.tscn"
const OLD: String = "res://kit/modules/walls/bz_rumour_board_old.tscn"
const PLACEHOLDER: String = "[i]Placeholder text: replace or approve.[/i]\n\n"
const SHOWN: int = 3
const RUMOURS: PackedStringArray = [
	"Lamp oil is dear this month. Ask the copper seller why, and watch the keeper's face.",
	"Whoever took the Hollow Index from the third gallery: the reward stands, and so does the curse.",
	"Wanted: a guide for the lower stacks. Must have been there and come back. References from the living only.",
	"The fountain ran salt for an hour on the last bell. The water sellers say it did not.",
	"A carpet in the rug row shows a room nobody can find. The keeper will not sell it and will not say why.",
	"Bread is short because the mill road is shut. The mill road is shut because of what was on it.",
	"Lost: one grey cat, answers to nothing. Found: three grey cats. Please come and sort this out.",
	"They say a door has opened at the end of the east row. They say it was not there before.",
]
const FADED: PackedStringArray = [
	"Closed until the road is safe.",
	"Gone up with the others. Take what you need.",
	"The ink has run. Only the last line can be read: ...and do not wait for us.",
]

## The Forgotten City's board: a few sheets left, and nobody to read them.
@export var faded: bool = false


func _ready() -> void:
	collision_layer = 2     # only the interaction ray
	collision_mask = 0
	add_child((load(OLD if faded else LIVED) as PackedScene).instantiate())
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.6, 1.2, 0.12)
	shape.shape = box
	shape.position = Vector3(0.0, 1.52, -0.06)
	add_child(shape)


func interaction_prompt(_hit: Vector3) -> String:
	return "Read the board"


func interact(_actor: Node3D, _hit: Vector3) -> void:
	var list: PackedStringArray = FADED if faded else RUMOURS
	var first: int = absi(hash(global_position.snapped(Vector3.ONE * 0.01))) % list.size()
	var lines: PackedStringArray = []
	for i: int in mini(SHOWN, list.size()):
		lines.append(list[(first + i) % list.size()])
	var title: String = "What is left of the board" if faded else "The board of rumours"
	get_tree().current_scene.open_panel(title, PLACEHOLDER + "\n\n".join(lines), [{"text": "Step back", "action": "close"}], "book")

class_name HomeNote
extends StaticBody3D
## A note left out in a home of the Domicile Quarter (phase 14 step 4, Q5): E
## reads it, and it stays where it is. Which note is settled by where it lies, so
## a room built again from its seed shows the same one. The texts are placeholders.

const SHEET: String = "res://kit/modules/walls/qt_home_note.tscn"
const PLACEHOLDER: String = "[i]Placeholder text: replace or approve.[/i]\n\n"
const NOTES: Dictionary = {
	"scholar": [
		["A list, half crossed out", "Return the Hollow Index to the third gallery.\nAsk after the missing folios.\nOil.\nThe boy's lessons, if he comes back to them.\nOil again."],
		["A page of corrections", "The copyist has it \"the lamp is kept\". The older hand says \"the lamp keeps\". I have read it forty times tonight and I no longer think this is a mistake."],
		["A letter, unsent", "You asked what I do down here. I read, and then I walk home through the lanes and everyone's supper is on. That is all of it. I would not trade it."],
	],
	"family": [
		["Chalked on a slate", "Bread at the Hauz door before the second bell. Your sister has the good pot. Do NOT lend it to her again."],
		["A child's writing", "This is my house. This is my mother's house. This is the cat. The cat is not allowed. The cat lives here."],
		["A note by the hearth", "Gone for water. The lentils want another hour. If you let them catch again I will know."],
	],
	"hunter": [
		["A tally on hide", "Six in the lower snares. Two taken by something else, the wire bitten through. I have stopped setting the far line."],
		["Scratched on a board", "Owed: four skins to the tanner. Owed to me: a knife, a favour, and an explanation."],
		["A note tied with cord", "Whatever walks the cistern steps at night is not hungry. It takes nothing from the traps. It only moves them."],
	],
	"abandoned": [
		["A note under the dust", "We waited as long as the oil lasted. If you come back, the key is where it always was. There is nothing left to lock."],
		["A torn page", "Everyone on the lane has gone up. They say there is more light above. Nobody has come down to say so."],
		["Pinned to the wall", "Do not take the cloth down. She will want to find the house."],
	],
}

## Who wrote it: a key of NOTES.
@export var household: String = "abandoned"


func _ready() -> void:
	collision_layer = 2     # only the interaction ray: you walk over a note
	collision_mask = 0
	add_child((load(SHEET) as PackedScene).instantiate())
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.36, 0.1, 0.4)
	shape.shape = box
	add_child(shape)


func interaction_prompt(_hit: Vector3) -> String:
	return "Read the note"


func interact(_actor: Node3D, _hit: Vector3) -> void:
	var note: Array = _note()
	get_tree().current_scene.open_panel(note[0], PLACEHOLDER + str(note[1]), [{"text": "Leave it where it lies", "action": "close"}], "book")


func _note() -> Array:
	var list: Array = NOTES[household]
	var at: Vector3 = global_position.snapped(Vector3.ONE * 0.01)
	return list[absi(hash(at)) % list.size()]

@tool
class_name ItemDef
extends Resource
## Something that can go in the satchel (ENVIRONMENT_PLAN.md 6.2, 6.5.1).
## Data in items/**/*.tres. The satchel stores ids, never copies, so a quick
## slot or a book list refers to what the player owns.

enum Kind { LORE, INGREDIENT, TOOL }

## Unique across the game; the save stores it.
@export var id: StringName = &""
@export var display_name: String = ""
@export var kind: Kind = Kind.LORE
## Most of one kind the satchel holds in one stack (1 for unique things).
@export_range(1, 999) var stack_max: int = 1
## A one-of-a-kind thing (a lore book): the satchel holds it once.
@export var unique: bool = true
## Lore books: the spine on the shelf (the gilt band is added).
@export var spine_colour: Color = Color(0.2, 0.32, 0.5)
## Lore books: what Read shows (BBCode).
@export_multiline var text: String = ""

const ITEM_DIR: String = "res://items"
static var _by_id: Dictionary = {}


## The ItemDef with this id (scans res://items once), or null.
static func find(item_id: StringName) -> ItemDef:
	if _by_id.is_empty():
		_scan(ITEM_DIR)
	return _by_id.get(item_id)


static func _scan(dir_path: String) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	for sub: String in dir.get_directories():
		_scan(dir_path.path_join(sub))
	for f: String in dir.get_files():
		var file: String = f.trim_suffix(".remap")
		if file.ends_with(".tres"):
			var res: Resource = load(dir_path.path_join(file))
			if res is ItemDef and (res as ItemDef).id != &"":
				_by_id[(res as ItemDef).id] = res

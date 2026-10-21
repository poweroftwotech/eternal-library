class_name AreaGrow
extends Resource
## Generated rooms an AreaRecipe adds at free exits until it has enough rooms
## (phase-4-design.md 8.1.2 step 5).

@export var grammar: RoomGrammar
@export var rules: ModuleRules
@export var display_name: String = ""
## How many of these rooms to add (the seed picks within the range; the
## recipe's room_count still caps the area).
@export var count: Vector2i = Vector2i(2, 5)
## Slot ids are <slot_prefix>_<n> (gallery_1, gallery_2 …).
@export var slot_prefix: String = "gallery"
## Slots whose exits may sprout these rooms (empty: any generated room's exit,
## grown rooms included).
@export var from: PackedStringArray = []

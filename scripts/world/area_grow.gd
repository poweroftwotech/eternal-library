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
## Only on doors at least this many doorways in from the entrance (the new room
## would be this deep or deeper; 0: anywhere).
@export var min_depth: int = 0
## Always live once the area is, like a pinned AreaSlot: for rooms too big to
## build in a frame's budget while you walk (phase 5 step 3: the cistern,
## 2,000 nodes, took 5-6 ms to enter the tree).
@export var pinned: bool = false
## The areas of a stratum that share this room (phase 13 Q2: one Garden Court
## per stratum): the world seed picks one of them and only it grows the room.
## Empty: every area with this rule grows it. A plan made without a world seed
## (tools and tests that plan from an area seed) grows it wherever the rule is.
@export var one_of: PackedStringArray = []

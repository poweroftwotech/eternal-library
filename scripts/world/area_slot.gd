class_name AreaSlot
extends Resource
## A room an AreaRecipe always has (phase-4-design.md 8.1.1): an authored or
## baked scene, or a generated room, joined to its parent slot's connector.

enum SeedMode { FIXED, AREA }

## Unique in the area; becomes the room's room_id (so its save ids).
@export var slot_id: String = ""
## Shown in the HUD while the player is in this room ("" = the room's own).
@export var display_name: String = ""
## An authored or baked room. Leave empty for a generated one.
@export var scene: PackedScene
## Or one of several, rolled by the area seed (the caravanserai's three sizes).
@export var scene_choices: Array[PackedScene] = []
## How likely each choice is (empty, or all equal: equally likely, as before
## phase 10). A save keeps the choice its world made (Q5), whatever the weights
## say later.
@export var scene_weights: PackedFloat32Array = []
## Always this choice (an index into scene_choices; -1: rolled).
@export var pinned_choice: int = -1
## A generated room: its grammar and (optionally) rules overriding the grammar's.
@export var grammar: RoomGrammar
@export var rules: ModuleRules
## The slot this room joins ("" for the root, which sits at the area origin).
@export var parent: String = ""
## The parent's connector it joins (e.g. SNAP_door_west).
@export var connector: StringName = &""
## FIXED: an authored room keeps its preview_seed, a baked room the seed it was
## baked from, a generated room `fixed_seed`. AREA: derived from the area seed.
@export var seed_mode: SeedMode = SeedMode.AREA
@export var fixed_seed: int = 1
## Always live once the area is (phase-4-design.md 8.1.8 risks: the root room
## costs too much to stream in while you walk).
@export var pinned: bool = false
## Doors out of the area (phase-6-design.md 5.7.6): connector -> the area id
## it leads to. The first of them the room has (a scene choice's names
## differ) is a threshold: never grown from, its exit stub gone, crossing it
## travels; arriving from that area puts you just inside it.
@export var thresholds: Dictionary = {}

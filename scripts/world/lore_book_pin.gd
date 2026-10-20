@tool
class_name LoreBookPin
extends Resource
## A lore book placed on one shelf of a recess (ENVIRONMENT_PLAN.md 6.5.4),
## listed on the room (RoomTemplate.lore_books). The recess socket must be
## room-pinned to a shelf candidate, or Validate Room reports it.

## The recess socket's path in the room (as in socket_pins).
@export var socket: String = ""
## Shelf board, 0 = the lowest.
@export_range(0, 7) var level: int = 2
## Along the shelf, in socket space (-1.44 .. 1.44 on a 4 m shelf bay).
@export_range(-1.5, 1.5, 0.01) var x: float = 0.0
@export var item: ItemDef

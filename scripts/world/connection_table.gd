class_name ConnectionTable
extends Resource
## What may connect to what (phase 10 step 2): for a grow rule's room type
## (the column) and the type of the room whose door it would take (the row),
## allowed, preferred or never. A never door is skipped; a preferred one is
## PREFER_WEIGHT times as likely to come up first in the seeded order.
## Applies in every area. Only grow rules use it: a required room joins the
## door its recipe names.
##
## Only the pairs that aren't "allowed" are stored; an empty table changes
## nothing (the planner's order is exactly as it was before the table).

const PATH: String = "res://gen/rules/connections.tres"
const PREFER_WEIGHT: float = 3.0
const ALLOWED: String = "allowed"
const PREFERRED: String = "preferred"
const NEVER: String = "never"

## "<from>><to>" (e.g. "R03>R09") -> PREFERRED or NEVER.
@export var rules: Dictionary = {}

static var _default: ConnectionTable


## The game's table (PATH), or an empty one if there's no file.
static func default() -> ConnectionTable:
	if _default == null:
		_default = load(PATH) as ConnectionTable if ResourceLoader.exists(PATH) else ConnectionTable.new()
	return _default


## Drops the cached table (the Strata Board saved a new one).
static func drop_cache() -> void:
	_default = null


## Plans with `table` until drop_cache() (the Strata Board trying an unsaved edit).
static func use(table: ConnectionTable) -> void:
	_default = table


func rule(from_type: String, to_type: String) -> String:
	return str(rules.get("%s>%s" % [from_type, to_type], ALLOWED))


func is_empty() -> bool:
	return rules.is_empty()

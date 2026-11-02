class_name StratumPlan
extends Resource
## The stratum plan (phase 10 step 3): which places a stratum has and how
## they link, as data the Strata Board edits (gen/strata/stratum_1.tres).
## Shaped for several strata; the game has one.
##
## A place is an area (its recipe file) or the camp (a baked scene). A link is
## the camp–Gorge corridor or a door from a Gorge building into an area: the
## Gorge frontage slot it stands on (`at`). Only the frontage's door places
## (FrontageSlot.door_place, kept clear of buildings when the Gorge is baked)
## can take a door; apply_doors() sets each slot's door from the links.

const PATH: String = "res://gen/strata/stratum_1.tres"
const CORRIDOR: String = "corridor"
const DOOR: String = "door"

@export var id: String = "stratum_1"
@export var display_name: String = "Stratum 1"
## [{id, path}]: path a recipe (.tres, an area) or a scene (the camp).
@export var places: Array[Dictionary] = []
## [{a, b, kind (corridor | door), at (a door's frontage slot id)}].
@export var links: Array[Dictionary] = []

static var _current: StratumPlan


## The game's stratum (PATH).
static func current() -> StratumPlan:
	if _current == null:
		_current = load(PATH) as StratumPlan
	return _current


## Drops the cached plan (the Strata Board saved a new one).
static func drop_cache() -> void:
	_current = null


## Uses `plan` until drop_cache() (tests; the board trying an unsaved edit).
static func use(plan: StratumPlan) -> void:
	_current = plan


## Area id -> its recipe path (every place that isn't a scene).
func recipes() -> Dictionary:
	var out: Dictionary = {}
	for p: Dictionary in places:
		if str(p["path"]).get_extension() == "tres":
			out[str(p["id"])] = str(p["path"])
	return out


func path_of(place: String) -> String:
	for p: Dictionary in places:
		if str(p["id"]) == place:
			return str(p["path"])
	return ""


## [a, b, kind] for each link.
func triples() -> Array:
	return links.map(func(l: Dictionary) -> Array: return [str(l["a"]), str(l["b"]), str(l["kind"])])


## The frontage slot of the Gorge's door into `area` ("" = none).
func door_slot(area: String) -> String:
	for l: Dictionary in links:
		if str(l["kind"]) == DOOR and (str(l["b"]) == area or str(l["a"]) == area):
			return str(l.get("at", ""))
	return ""


## Sets every frontage slot's door from the links: the area behind it, or "".
func apply_doors(frontage: GorgeFrontage) -> void:
	var at: Dictionary = {}
	for l: Dictionary in links:
		if str(l["kind"]) == DOOR and str(l.get("at", "")) != "":
			at[str(l["at"])] = str(l["b"]) if str(l["a"]) == "gorge" else str(l["a"])
	for s: FrontageSlot in frontage.slots:
		if s != null:
			s.door = str(at.get(s.id, ""))

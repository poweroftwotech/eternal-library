class_name StratumPlan
extends Resource
## The stratum plan (phase 10 step 3): which places a stratum has and how
## they link, as data the Strata Board edits (gen/strata/stratum_1.tres).
## Shaped for several strata; the game has one.
##
## A place is an area (its recipe file) or the camp (a baked scene). A link is
## the camp–Gorge corridor or a door into an area: from a Gorge building (the
## Gorge frontage slot it stands on, `at`) or the camp's back door
## (`at` = CAMP_BACK_DOOR). Only the frontage's door places
## (FrontageSlot.door_place, kept clear of buildings when the Gorge is baked)
## can take a door; apply_doors() sets each slot's door from the links.
##
## Doors travel (door travel, 2026-11-01): you open the door and the place
## behind it loads as its own scene, arriving just inside its door back. A
## link marked "seamless" streams the two places into one world instead
## (phase 9, SeamlessPlaces); the camp–Gorge corridor always does.

const PATH: String = "res://gen/strata/stratum_1.tres"
const CORRIDOR: String = "corridor"
const DOOR: String = "door"
## The camp's back door (rooms/camp/camp.tscn's SNAP_exit_front, at the far
## end of the camp from the Gorge) as a link's `at`.
const CAMP_BACK_DOOR: String = "SNAP_exit_front"

@export var id: String = "stratum_1"
@export var display_name: String = "Stratum 1"
## [{id, path}]: path a recipe (.tres, an area) or a scene (the camp).
@export var places: Array[Dictionary] = []
## [{a, b, kind (corridor | door), at (a door's frontage slot id, or
## CAMP_BACK_DOOR), seamless (a door: streamed, not travelled; default false)}].
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


## Area id -> its recipe path (every place that isn't a scene, whose file is
## still there: a recipe deleted by hand can't take the menu or a door down).
func recipes() -> Dictionary:
	var out: Dictionary = {}
	for p: Dictionary in places:
		if str(p["path"]).get_extension() == "tres":
			if ResourceLoader.exists(str(p["path"])):
				out[str(p["id"])] = str(p["path"])
			else:
				push_warning("Stratum plan: %s's recipe %s is gone; the game leaves it out" % [p["id"], p["path"]])
	return out


## Place id -> its scene, for each place that is a fixed scene of its own
## other than the camp (phase 18 step 5: the Lake Landing).
func scenes() -> Dictionary:
	var out: Dictionary = {}
	for p: Dictionary in places:
		if str(p["path"]).get_extension() == "tscn" and str(p["id"]) != "camp" and ResourceLoader.exists(str(p["path"])):
			out[str(p["id"])] = str(p["path"])
	return out


## The place whose scene is `path` ("" = none).
func scene_place(path: String) -> String:
	for id: String in scenes():
		if scenes()[id] == path:
			return id
	return ""


func path_of(place: String) -> String:
	for p: Dictionary in places:
		if str(p["id"]) == place:
			return str(p["path"])
	return ""


## What a door to `place` calls it, mid-sentence: an area's display name
## ("the Lower Stacks"), "the camp".
func place_name(place: String) -> String:
	if place == "camp":
		return "the camp"
	for p: Dictionary in places:     # a place can name itself ("the Lake Landing")
		if str(p["id"]) == place and p.has("name"):
			return str(p["name"])
	var path: String = path_of(place)
	var shown: String = recipe_name(path)
	if shown == "":
		shown = place.capitalize()
	return "the " + shown.substr(4) if shown.begins_with("The ") else shown     # mid-sentence: "the Sanctum"


## Recipe path -> its display name, read once.
static var _names: Dictionary = {}
static var _names_lock := Mutex.new()


## A recipe's display name ("" = none), read from its file's own [resource]
## section, not loaded: loading a recipe pulls in all its rooms (0.7-1.3 s,
## every time, as the Gorge built each door ledge beside the camp).
static func recipe_name(path: String) -> String:
	_names_lock.lock()
	var known: Variant = _names.get(path)
	_names_lock.unlock()
	if known != null:
		return known
	var shown: String = ""
	if path.get_extension() == "tres" and FileAccess.file_exists(path):
		var text: String = FileAccess.get_file_as_string(path)
		var at: int = text.rfind("
[resource]")
		var re := RegEx.create_from_string("(?m)^display_name = \"(.*)\"$")
		var m: RegExMatch = re.search(text, at) if at >= 0 else null
		if m != null:
			shown = m.get_string(1).c_unescape()
	elif path.get_extension() == "res" and ResourceLoader.exists(path):
		var recipe: AreaRecipe = load(path) as AreaRecipe     # a binary recipe: no text to read
		shown = recipe.display_name if recipe != null else ""
	_names_lock.lock()
	_names[path] = shown
	_names_lock.unlock()
	return shown


## [a, b, kind] for each link.
func triples() -> Array:
	return links.map(func(l: Dictionary) -> Array: return [str(l["a"]), str(l["b"]), str(l["kind"])])


## Whether link `l` streams its two places into one world (SeamlessPlaces)
## rather than travelling between them.
static func is_seamless(l: Dictionary) -> bool:
	return str(l.get("kind", "")) == CORRIDOR or bool(l.get("seamless", false))


## [a, b, kind] for each seamless link.
func seamless_triples() -> Array:
	return links.filter(is_seamless).map(func(l: Dictionary) -> Array: return [str(l["a"]), str(l["b"]), str(l["kind"])])


## The door into `area`: where it stands (a Gorge frontage slot id, or
## CAMP_BACK_DOOR; "" = none).
func door_slot(area: String) -> String:
	var l: Dictionary = door_link(area)
	return str(l.get("at", ""))


## The door link into `area` ({} = none).
func door_link(area: String) -> Dictionary:
	for l: Dictionary in links:
		if str(l["kind"]) == DOOR and (str(l["b"]) == area or (str(l["a"]) == area and str(l["b"]) in ["gorge", "camp"])):
			return l
	return {}


## The place at the other end of `area`'s door link ("" = none).
func outside_of(area: String) -> String:
	var l: Dictionary = door_link(area)
	if l.is_empty():
		return ""
	return str(l["a"]) if str(l["b"]) == area else str(l["b"])


## The area behind the camp's back door ("" = none).
func camp_back_area() -> String:
	for l: Dictionary in links:
		if str(l["kind"]) == DOOR and str(l.get("at", "")) == CAMP_BACK_DOOR:
			return str(l["b"]) if str(l["a"]) == "camp" else str(l["a"])
	return ""


## Where a door of `area` its recipe says leads to `raw` (a threshold's "to")
## really leads: `raw` when that's a place `area` links to (the Gorge's doors,
## each to its own area), else the place its door link comes from (an
## interior's entrance, written "gorge" in its recipe, behind the camp's back
## door leads to the camp).
func door_target(area: String, raw: String) -> String:
	for l: Dictionary in links:
		if (str(l["a"]) == area and str(l["b"]) == raw) or (str(l["b"]) == area and str(l["a"]) == raw):
			return raw
	var outside: String = outside_of(area)
	return outside if outside != "" else raw


## Sets every frontage slot's door from the links: the area behind it, or "".
func apply_doors(frontage: GorgeFrontage) -> void:
	var at: Dictionary = {}
	for l: Dictionary in links:
		if str(l["kind"]) == DOOR and str(l.get("at", "")) != "" and "gorge" in [str(l["a"]), str(l["b"])]:
			at[str(l["at"])] = str(l["b"]) if str(l["a"]) == "gorge" else str(l["a"])
	for s: FrontageSlot in frontage.slots:
		if s != null:
			s.door = str(at.get(s.id, ""))

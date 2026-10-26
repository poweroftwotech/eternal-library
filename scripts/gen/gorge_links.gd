@tool
class_name GorgeLinks
extends Resource
## Every link the near network could have (phase-6-design.md 5.7.5, phase 6
## step 4): spans across and stairs along the cliffs between the frontage
## slots' connectors (and from the Overlook's corner), each solved once by
## ChasmLink with nothing else planned round it. gen/gorge/links.res, made
## by tools/gorge_links.gd from the frontage; the planner builds its tree
## from these (checking them against what it has planned by their boxes) and
## solves only the ones it keeps.
##
## A connector's id: "<slot id>:F:<bay>" (a ledge's front, that bay of the
## slot), "<slot id>:L:<k>" / ":R:<k>" (a ledge's left or right end, at the
## slot's bay boundary k), or "<room>:<connector>" for a recipe room's
## (the Overlook's corner).

## [{a: id, b: id, length: float, drop: int (storeys a is above b), turn_a:
## degrees off a's facing, boxes: Array[AABB] (area frame)}].
@export var entries: Array[Dictionary] = []
## The recipe rooms' connectors the table was made from: id -> Transform3D.
@export var fixed: Dictionary = {}


## A slot connector's frame in the area (-Z out of its ledge), as
## CliffLedgeGrammar places them; Transform3D() if the id isn't a slot's.
static func slot_connector(frontage: GorgeFrontage, id: String) -> Transform3D:
	var parts: PackedStringArray = id.split(":")
	if parts.size() != 3:
		return Transform3D()
	var slot: FrontageSlot = frontage.slot(parts[0])
	if slot == null:
		return Transform3D()
	var k: int = parts[2].to_int()
	match parts[1]:
		"F":
			return slot.xf * Transform3D(Basis(), Vector3(k * 4.0 + 2.0, 0, -4.0))
		"L":
			return slot.xf * Transform3D(Basis(Vector3.UP, PI * .5), Vector3(k * 4.0, 0, -2.0))
		"R":
			return slot.xf * Transform3D(Basis(Vector3.UP, -PI * .5), Vector3(k * 4.0, 0, -2.0))
	return Transform3D()


## A ledge's connector name (CliffLedgeGrammar) for a slot connector id, the
## ledge starting at bay `first` with n bays; "" if it isn't on that ledge.
static func ledge_connector(id: String, first: int, n: int) -> StringName:
	var parts: PackedStringArray = id.split(":")
	var k: int = parts[2].to_int()
	match parts[1]:
		"F":
			return StringName("SNAP_front_%d" % (k - first)) if k >= first and k < first + n else &""
		"L":
			return &"SNAP_end_l" if k == first else &""
		"R":
			return &"SNAP_end_r" if k == first + n else &""
	return &""


## The slot id of a slot connector id ("" for a recipe room's).
static func slot_of(id: String) -> String:
	var parts: PackedStringArray = id.split(":")
	return parts[0] if parts.size() == 3 else ""

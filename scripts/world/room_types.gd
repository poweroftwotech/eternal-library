class_name RoomTypes
extends RefCounted
## The room types of design/room-atlas.html (R01 Reading Room …), told apart
## by the grammar or scene file a room is made from. The connection table
## (ConnectionTable) and the Strata Board use them.

## By the start of the file name.
const BY_FILE: Dictionary = {"r01": "R01", "r02": "R02", "r03": "R03", "r04": "R04", "r05": "R05", "r06": "R06", "r09": "R09", "r10": "R10", "r07": "R07", "r11": "R11", "r15": "R15", "r17": "R17", "r21": "R21", "r08": "R08",
	"reading_room": "R01", "stack_gallery": "R02", "caravanserai": "R05", "overlook": "R10", "scriptorium": "R08"}
const NAMES: Dictionary = {"R01": "Reading Room", "R02": "Stack gallery", "R03": "Hypostyle hall", "R04": "Grand bazaar", "R05": "Caravanserai", "R06": "Domicile quarter",
	"R07": "Garden court", "R08": "Orosi scriptorium", "R09": "Light-well stair", "R10": "Chasm span", "R11": "Cistern", "R15": "Fungus terraces", "R17": "Ossuary", "R21": "Bridge hall"}


## The type of a room made from the grammar or scene at `path` ("" if none).
static func of_path(path: String) -> String:
	var file: String = path.get_file().get_basename()
	for k: String in BY_FILE:
		if file.begins_with(k):
			return BY_FILE[k]
	return ""


static func of_resource(res: Resource) -> String:
	return of_path(res.resource_path) if res != null else ""

@tool
class_name KitCatalog
extends Resource
## Index of every kit module (kit/catalog.tres). Built by tools/kit_catalog.gd;
## generators and the Kit dock query it. Do not edit by hand.

## One Dictionary per module: name, scene, family, shape, size_cells, edge, tags, weight.
@export var modules: Array[Dictionary] = []


func find(module_name: String) -> Dictionary:
	for entry: Dictionary in modules:
		if entry.get("name", "") == module_name:
			return entry
	return {}


func by_family(family: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry: Dictionary in modules:
		if entry.get("family", "") == family:
			out.append(entry)
	return out


## Modules of one shape whose tags include every tag in `required`.
func query(shape: String, required: PackedStringArray = []) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry: Dictionary in modules:
		if entry.get("shape", "") != shape:
			continue
		var tags: PackedStringArray = entry.get("tags", PackedStringArray())
		var ok: bool = true
		for t: String in required:
			if not tags.has(t):
				ok = false
				break
		if ok:
			out.append(entry)
	return out


func families() -> PackedStringArray:
	var out: PackedStringArray = []
	for entry: Dictionary in modules:
		var f: String = entry.get("family", "")
		if not out.has(f):
			out.append(f)
	out.sort()
	return out

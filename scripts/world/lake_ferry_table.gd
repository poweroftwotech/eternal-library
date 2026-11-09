class_name LakeFerryTable
extends Resource
## The ferry's destinations (phase 18 revised, brief R5): where the ferryman
## can take you. Each entry: "id", "name" (as the ferryman and the dock's
## board say it), "theme" (picks the dock style, LakeLayout.style_of: R1b) and
## "open" (offered by the ferryman). Doors at the docks stay sealed this
## phase (Q3); a later phase points them at the destination's area.
## The live table: res://gen/lake/ferry_table.tres.

const PATH: String = "res://gen/lake/ferry_table.tres"

@export var destinations: Array[Dictionary] = []


static func live() -> LakeFerryTable:
	return load(PATH) as LakeFerryTable


func entry(id: String) -> Dictionary:
	for d: Dictionary in destinations:
		if str(d.get("id", "")) == id:
			return d
	return {}


func open_ids() -> PackedStringArray:
	var out := PackedStringArray()
	for d: Dictionary in destinations:
		if bool(d.get("open", true)):
			out.append(str(d["id"]))
	return out

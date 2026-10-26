@tool
class_name GorgeFrontage
extends Resource
## The gorge's frontage slots (phase-6-design.md 5.7.3): where the near
## network's ledges may stand. gen/gorge/frontage.tres, seeded by
## tools/gorge_frontage.gd, then editable by hand.

@export var slots: Array[FrontageSlot] = []


func slot(id: String) -> FrontageSlot:
	for s: FrontageSlot in slots:
		if s != null and s.id == id:
			return s
	return null

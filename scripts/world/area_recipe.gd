class_name AreaRecipe
extends Resource
## A connected set of rooms, the unit of streaming and saving (architecture.md
## 2 and 2.1; phase-4-design.md 8.1.1). AreaPlanner turns a recipe and a seed
## into an AreaPlan; the Area node builds rooms from that plan.

## The area id: the save keeps this area's changes under areas[id].
@export var id: String = ""
## Shown in menus and the HUD.
@export var display_name: String = ""
## Raise when a change moves rooms, so old saves know (8.1.6).
@export var version: int = 1
@export var slots: Array[AreaSlot] = []
@export var grow: Array[AreaGrow] = []
## Rooms in the area, required slots included (x min, y max).
@export var room_count: Vector2i = Vector2i(6, 10)
## At most this many generated leaf rooms end in a plain wall; the rest keep
## their glowing exit arch (Q10).
@export var max_dead_ends: int = 1
## No straight line through doorways crosses more than this many rooms beyond
## the one it starts in (Q11; architecture.md 2.1).
@export var max_sight_depth: int = 2
@export var placement: AreaPlacement
@export var atmosphere: AtmosphereProfile
## A cavern area's scenery (phase-6-design.md 5.7.2): a scene the area adds
## once, before its rooms; not planned, never streamed (the baked gorge).
@export var scenery: PackedScene
## Below this height a falling player is put back at the spawn (the camp and
## the rooms: -8 m). The Gorge walks far below that, to its safety floor.
@export var fall_limit: float = -8.0
## A cavern area's walkable network (phase 6 step 4): ledges on the
## scenery's frontage slots joined by spans, planned after the slots.
@export var network: GorgeNetwork
## Every room sees every other (an open cavern: no walls between them),
## so no sightline limit applies and every room's lights may burn.
@export var open_sight: bool = false


func slot(slot_id: String) -> AreaSlot:
	for s: AreaSlot in slots:
		if s != null and s.slot_id == slot_id:
			return s
	return null

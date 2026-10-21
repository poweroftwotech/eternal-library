class_name AreaPlacement
extends Resource
## Where an area sits in its stratum (architecture.md 2.1; phase-4-design.md
## 8.1.9 item 2). A stratum plan fills these in once there is one; until then
## the recipe carries a hand-set placement.

## The area frame's origin in the stratum frame, in whole cells (x, z) and
## storeys (y) of 4 m.
@export var origin: Vector3i = Vector3i.ZERO
## The space reserved for the area, in the area frame. The planner builds
## nothing outside it, so areas planned side by side never overlap.
@export var envelope: AABB = AABB(Vector3(-122, -8, -144), Vector3(256, 32, 256))


## The area's origin in stratum metres.
func origin_m() -> Vector3:
	return Vector3(origin) * CellGrid.BAY

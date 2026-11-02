@tool
class_name FrontageSlot
extends Resource
## A place on the gorge's cliffs where a walkable piece may meet them
## (phase-6-design.md 5.7.3, phase 6 step 4): a straight run of a tier's
## faces toward the gorge at one storey, with room in front of it for a ledge
## one bay deep (clear of every tier, with headroom). Seeded once by
## tools/gorge_frontage.gd into gen/gorge/frontage.tres; yours to edit.

## Unique in the frontage ("b1_l5_e_s2", from the bank, tier level, face
## side, storey and run).
@export var id: String = ""
## The bank (1-8) whose tier the face is.
@export var bank: int = 1
## Which cliff: "left" (banks 1, 3: the balcony's left) or "right".
@export var cliff: String = "left"
## The slot's frame in the area: the face at floor height, -Z out over the
## gorge, +X along the face; cell k spans x 4k..4k+4, z 0..-4 (out).
@export var xf: Transform3D = Transform3D()
## Bays along the face.
@export var width: int = 2
## A place a door into an area can stand (phase 10 step 3): the Gorge's bake
## keeps the bank behind it clear for the passage (PersianTown._by_door).
@export var door_place: bool = false
## The area whose door stands here, or "": set from the stratum plan
## (StratumPlan.apply_doors), not stored here.
var door: String = ""


## The storey (AreaPlan cells) of the slot's floor.
func storey() -> int:
	return AreaPlan.cell_of(xf.origin).y

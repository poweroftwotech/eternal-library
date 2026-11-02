class_name SealedDoor
extends Node3D
## A doorway that leads nowhere yet (sealed doors, 2026-11-02): a plain shut
## door (OrnateDoor.plain) in the kit's 3 m wall arch, where the room
## grammars leave an exit nothing joined (gen/modules/exit_glow.tscn, the
## "stub:exit" slot). It used to be a warm glow 1.4 m past the wall with a
## blocker beyond it, and where the floor stopped at the wall (the light-well's
## gallery) you could drop through the gap in front of the blocker and out of
## the world. The door's wall stands in the arch itself.
##
## Later such a door may lead somewhere (another area, or another room of the
## same area); for now aiming at it says it won't open. In the frame of the
## exit connector: origin on the wall line at the floor, -Z out of the room.

## The leaves' face, out from the wall line (as Threshold.ARCHES["kit"]).
const FACE: float = 0.05

const ARCH: Array = [1.5, 1.8, 1.775]


func _ready() -> void:
	var door := OrnateDoor.make(ARCH[0], ARCH[1], ARCH[2], 0.0, true)
	door.name = "Leaves"
	door.position.z = FACE
	add_child(door)
	var wall := Leaf.new()
	wall.name = "Wall"
	wall.collision_layer = 1 | 2     # the world, and what the interaction ray finds
	wall.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.0 * ARCH[0] + 0.2, door.top(), OrnateDoor.THICK + 0.32)
	shape.shape = box
	shape.position = Vector3(0, door.top() * 0.5, FACE + 0.02 - box.size.z * 0.5)
	wall.add_child(shape)
	add_child(wall)


## The door's wall: what stops you, and what the interaction ray finds.
class Leaf extends StaticBody3D:
	func interaction_prompt(_hit: Vector3) -> String:
		return "The door won't open"

	func interact(_actor: Node3D, _hit: Vector3) -> void:
		pass

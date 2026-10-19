@tool
class_name SocketSet
extends Resource
## Shared list of candidates for a kind of variation point, e.g.
## kit/sockets/recess_library.tres for every shelf recess. Tune weights here once
## and every socket that uses the set changes (ENVIRONMENT_PLAN.md 4.3).
## An entry without a scene is a valid pick: "nothing" for REPLACE/SCATTER, and
## the normal case for STATE sets, whose labels are the states.

@export var entries: Array[SocketEntry] = []
## The slot every candidate must fit, in socket space (Godot axes: the room is
## -Z). Validate Room checks each candidate against it and the slot against the
## room's other modules. Size zero = not checked (e.g. STATE sets).
@export var slot_bounds: AABB = AABB()
## Where candidates may drop loose spill (fallen books, broken boards), in
## socket space. Spill settles onto whatever is below at runtime (ShelfFill),
## so Validate Room only checks that it has something to land on and that
## no other solid stands inside the zone. Size zero = no spill.
@export var spill_bounds: AABB = AABB()


## Weighted pick; returns an index into entries, or -1 if nothing is pickable.
func pick(rng: RandomNumberGenerator) -> int:
	var total: float = 0.0
	for e: SocketEntry in entries:
		if e != null:
			total += maxf(e.weight, 0.0)
	if total <= 0.0:
		return -1
	var roll: float = rng.randf() * total
	for i: int in entries.size():
		var e: SocketEntry = entries[i]
		if e == null or e.weight <= 0.0:
			continue
		roll -= e.weight
		if roll <= 0.0:
			return i
	return entries.size() - 1


func index_of(label: String) -> int:
	for i: int in entries.size():
		if entries[i] != null and entries[i].label == label:
			return i
	return -1

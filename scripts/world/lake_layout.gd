class_name LakeLayout
extends RefCounted
## Where things are in the Lake Landing (phase 18, R20): the numbers
## tools/kit_add_r20.py builds the cavern from, in Godot coordinates, shared by
## tools/build_lake.gd, LakeLife and LakeFerry.
##
## The entry door is at the origin and the passage runs to -Z. The cavern is an
## ellipse round CENTRE (RX across, RZ along); the quay is in its near cove, the
## far landings on its far shore.

## The water's surface.
const WATER: float = -1.2
## A stage the ferry comes alongside (pier head, landing quays).
const STAGE: float = -0.9
const CENTRE: Vector3 = Vector3(0.0, 0.0, -75.0)
const RX: float = 85.0
const RZ: float = 80.0
## Where the crack of daylight is in the roof over the Gardens landing
## (kit_add_r20.py prints it when it builds the cavern).
const CRACK: Vector3 = Vector3(-45.45, 22.03, -135.52)
## The far landings (kit_add_r20.py LANDINGS): id -> [angle psi in Blender's
## frame (degrees), facade half-width (m), name, a ferry stop?].
const LANDINGS: Dictionary = {
	"mahaleh": [60.0, 15.0, "the Mahaleh landing", true],
	"gardens": [125.0, 11.0, "the Gardens landing", true],
	"forgotten": [15.0, 11.0, "the Forgotten City landing", true],
	"dark": [160.0, 8.0, "a dark landing", false],
}
## Landings whose door is at the back of a natural grotto cut into the wall
## (walk 1), not behind a built facade (kit_add_r20.py GROTTOS): id -> the
## grotto's floor height. The door stands GROTTO_BACK in from the facade line.
const GROTTOS: Dictionary = {"gardens": 0.0, "forgotten": 0.0, "dark": -1.5}
const GROTTO_BACK: float = 12.0
## A landing quay's stage edge, out from the facade line (lk_landing_quay: Y 6).
const LANDING_STAGE_OUT: float = 6.0
## The pier head's stage edge (lk_pier_head at (6, 0, -36): Y 5 -> Z -41), its
## middle at X 8; the ferry lies off it toward -Z.
const PIER_STAGE: Vector3 = Vector3(8.0, 0.0, -41.0)


## A point on the ellipse at Blender angle psi (degrees), on the water's plane Y 0.
static func ellipse(psi: float) -> Vector3:
	var a: float = deg_to_rad(psi)
	return Vector3(CENTRE.x + RX * cos(a), 0.0, CENTRE.z - RZ * sin(a))


## Out of the lake (into the rock) at psi.
static func outward(psi: float) -> Vector3:
	var a: float = deg_to_rad(psi)
	return Vector3(cos(a) / RX, 0.0, -sin(a) / RZ).normalized()


## A landing's frame: origin on the facade line at the floor, +X along the
## facade, -Z out over the lake (toward the quay side of the cavern).
static func landing_frame(id: String) -> Transform3D:
	var psi: float = float(LANDINGS[id][0])
	var z: Vector3 = outward(psi)
	var x: Vector3 = Vector3.UP.cross(z).normalized()
	return Transform3D(Basis(x, Vector3.UP, z), ellipse(psi))


## Where the ferry's bow meets a stop, and the way out to open water from it
## (a unit vector on the water's plane): [dock point, out].
static func stop_dock(id: String) -> Array:
	if id == "quay":
		return [Vector3(PIER_STAGE.x, STAGE, PIER_STAGE.z), Vector3(0.0, 0.0, -1.0)]
	if DOCKS.has(id):
		var df: Transform3D = dock_frame(id)
		return [df * Vector3(0.0, STAGE, -DOCK_STAGE_OUT), -df.basis.z]
	var f: Transform3D = landing_frame(id)
	var out: Vector3 = -f.basis.z
	return [f.origin + out * LANDING_STAGE_OUT + Vector3(0.0, STAGE, 0.0), out]


## Revised phase step 2: the ferry runs, through the fog, to the docks.
const FERRY_RUNS: bool = true

## Revised phase (approval brief R1): the docks are dock chambers (lk_dock_a,
## tools/kit_add_r20.py dock_a) far from the harbour in the same scene, reached
## through the fog: id -> [frame origin, yaw, name]. A dock's frame: the house
## front along +X at Z 0, the landing quay's stage edge at Z -6, the water and
## its channel toward -Z. Step 2: the Mahaleh dock only.
const DOCKS: Dictionary = {
	"mahaleh": [Vector3(0.0, 0.0, -420.0), 0.0, "the Mahaleh dock"],
}
## The dock frame's stage edge (lk_landing_quay: Y 6).
const DOCK_STAGE_OUT: float = 6.0
## Each stop's channel out into the fog, in its own frame (the harbour's is the
## scene's): from just past the stage's approach run out to the fog's heart.
## The ferry leaves along one, is moved under the fog, comes in along another.
const HARBOUR_CHANNEL: Array[Vector3] = [Vector3(9.0, 0.0, -61.0), Vector3(12.0, 0.0, -68.0),
		Vector3(15.0, 0.0, -73.0)]     # the fog takes it at the bend, short of the low rock beyond
const DOCK_CHANNEL: Array[Vector3] = [Vector3(-1.0, 0.0, -28.0), Vector3(-7.0, 0.0, -38.0),
		Vector3(-19.0, 0.0, -47.0), Vector3(-30.0, 0.0, -51.0)]
## The harbour's middle (which place the player is in: the nearest of this
## and the docks' frames).
const HARBOUR_HEART: Vector3 = Vector3(0.0, 0.0, -40.0)


static func dock_frame(id: String) -> Transform3D:
	var d: Array = DOCKS[id]
	return Transform3D(Basis(Vector3.UP, float(d[1])), d[0])


## A stop's channel, world points on the water's plane, stage end first.
static func channel(id: String) -> PackedVector3Array:
	var out := PackedVector3Array()
	if id == "quay":
		for p: Vector3 in HARBOUR_CHANNEL:
			out.append(Vector3(p.x, WATER, p.z))
	else:
		var f: Transform3D = dock_frame(id)
		for p: Vector3 in DOCK_CHANNEL:
			var w: Vector3 = f * p
			out.append(Vector3(w.x, WATER, w.z))
	return out


## The place a world point is in: "quay" (the harbour) or a dock's id.
static func place_of(p: Vector3) -> String:
	var best: String = "quay"
	var dist: float = Vector2(p.x - HARBOUR_HEART.x, p.z - HARBOUR_HEART.z).length()
	for id: String in DOCKS:
		var o: Vector3 = dock_frame(id).origin
		var d: float = Vector2(p.x - o.x, p.z - o.z).length()
		if d < dist:
			best = id
			dist = d
	return best


## The ferry stops: the quay, then each dock.
static func stops() -> PackedStringArray:
	if not FERRY_RUNS:
		return PackedStringArray(["quay"])
	var out := PackedStringArray(["quay"])
	for id: String in DOCKS:
		out.append(id)
	return out


static func stop_name(id: String) -> String:
	if id == "quay":
		return "the quay"
	return str(DOCKS[id][2]) if DOCKS.has(id) else str(LANDINGS[id][2])

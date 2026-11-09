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
	var df: Transform3D = dock_frame(style_of(id))
	return [df * Vector3(0.0, STAGE, -DOCK_STAGE_OUT), -df.basis.z]


## Revised phase: the ferry runs, through the fog, to the docks.
const FERRY_RUNS: bool = true

## Revised phase (approval brief R1): the dock styles, each a dock chamber
## (lk_dock_a, tools/kit_add_r20.py dock_a) far from the harbour and from each
## other in the same scene, reached through the fog: style -> [frame origin,
## yaw, themes it suits, the landing dressing it wears (build_lake.gd)]. A
## dock is a look, not a place: a destination (the ferry table) lands at the
## style whose themes match its theme (R1b). A dock's frame: the house front
## along +X at Z 0, the landing quay's stage edge at Z -6, the water and its
## two channels toward -Z.
const STYLES: Dictionary = {
	"town": [Vector3(0.0, 0.0, -420.0), 0.0, ["town"], "mahaleh"],
	"garden": [Vector3(320.0, 0.0, -420.0), 0.0, ["garden"], "gardens"],
	"ruin": [Vector3(-320.0, 0.0, -420.0), 0.0, ["ruin"], "forgotten"],
	"default": [Vector3(0.0, 0.0, -760.0), 0.0, [], "default"],
}
## The dock frame's stage edge (lk_landing_quay: Y 6).
const DOCK_STAGE_OUT: float = 6.0
## Each stop's channel out into the fog, in its own frame (the harbour's is the
## scene's): from just past the stage's approach run out to the fog's heart.
## The ferry leaves along one, is moved under the fog, comes in along another.
const HARBOUR_CHANNEL: Array[Vector3] = [Vector3(9.8, 0.0, -58.5), Vector3(12.5, 0.0, -65.0),
		Vector3(15.0, 0.0, -73.0)]     # the fog takes it at the bend, short of the low rock beyond;
		# east of the middle (step 3) so the lantern boat can pass along the west wall
## A dock's two mouths (R1c): the ferry leaves by the west one (0) and comes
## in by the east one (1), so two docks of one style never cross paths.
const DOCK_CHANNELS: Array = [
	[Vector3(-1.0, 0.0, -28.0), Vector3(-7.0, 0.0, -38.0), Vector3(-19.0, 0.0, -47.0), Vector3(-30.0, 0.0, -51.0)],
	[Vector3(1.0, 0.0, -28.0), Vector3(7.0, 0.0, -38.0), Vector3(19.0, 0.0, -47.0), Vector3(30.0, 0.0, -51.0)],
]
const LEAVE: int = 0
const ENTER: int = 1
## The harbour's middle (which place the player is in: the nearest of this
## and the docks' frames).
const HARBOUR_HEART: Vector3 = Vector3(0.0, 0.0, -40.0)
## The world seed the style choice is fixed by (LakeFerry sets it).
static var world_seed: int = 1
static var _table: LakeFerryTable


static func table() -> LakeFerryTable:
	if _table == null:
		_table = LakeFerryTable.live()
	return _table


static func dock_frame(style: String) -> Transform3D:
	var d: Array = STYLES[style]
	return Transform3D(Basis(Vector3.UP, float(d[1])), d[0])


## The dock style a destination lands at (R1b): one whose themes hold its
## theme, picked by world seed and destination where several do (then fixed),
## else the plain default.
static func style_of(dest: String) -> String:
	if STYLES.has(dest):
		return dest
	var theme: String = str(table().entry(dest).get("theme", ""))
	var fits: Array[String] = []
	for s: String in STYLES:
		if theme in (STYLES[s][2] as Array):
			fits.append(s)
	if fits.is_empty():
		return "default"
	fits.sort()
	return fits[absi(hash("%d:%s" % [world_seed, dest])) % fits.size()]


## A stop's channel, world points on the water's plane, stage end first
## (a dock's: by its `mouth`, LEAVE or ENTER).
static func channel(id: String, mouth: int = LEAVE) -> PackedVector3Array:
	var out := PackedVector3Array()
	if id == "quay":
		for p: Vector3 in HARBOUR_CHANNEL:
			out.append(Vector3(p.x, WATER, p.z))
	else:
		var f: Transform3D = dock_frame(style_of(id))
		for p: Vector3 in (DOCK_CHANNELS[mouth] as Array):
			var w: Vector3 = f * p
			out.append(Vector3(w.x, WATER, w.z))
	return out


## The place a world point is in: "quay" (the harbour) or a dock style.
static func place_of(p: Vector3) -> String:
	var best: String = "quay"
	var dist: float = Vector2(p.x - HARBOUR_HEART.x, p.z - HARBOUR_HEART.z).length()
	for s: String in STYLES:
		var o: Vector3 = dock_frame(s).origin
		var d: float = Vector2(p.x - o.x, p.z - o.z).length()
		if d < dist:
			best = s
			dist = d
	return best


## The ferry stops: the quay, then each open destination in the ferry table.
static func stops() -> PackedStringArray:
	var out := PackedStringArray(["quay"])
	if FERRY_RUNS:
		out.append_array(table().open_ids())
	return out


static func stop_name(id: String) -> String:
	if id == "quay":
		return "the quay"
	return str(table().entry(id).get("name", id))

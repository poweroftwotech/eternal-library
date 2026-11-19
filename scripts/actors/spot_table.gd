class_name SpotTable
extends RefCounted
## Spots: where a resident does something (phase 21 step 2, Q3). A spot is a
## place, a facing and a pose. They are read from the furniture a room already
## has, by this one table: the file a prop was made from says what spots it
## gives. Nothing in the kit is re-marked.
##
## A spot: {kind, at (global, where the body's origin goes), yaw (the body's,
## global), pose ("" = the body's own floor pose, else an animation), top (a
## seat's height over the floor), node (the furniture), by (who has it, or
## null)}.
## Kinds: sleep, cook, eat, sit, work, door, stand.

## Prop file name (no extension) -> what it gives.
##   kind    the spot's kind
##   statue  the prop is one of the old posed figures: the spot is where it
##           stands, turned as it is, and the figure is hidden
##   seat    sit on top of it: on the floor pose if it is low, as on a bench
##           if its top is SEAT_BENCH or higher; turned to a table if one is
##           within TABLE_REACH (then it is an "eat" spot)
##   lie     lie along its longer side (pose sleep)
##   pose    an animation, for a statue's spot
##   trade   only for people of this trade
const BY_FILE: Dictionary = {
	"camp_bedroll": {"kind": "sleep", "lie": true},
	"court_contents_bedroll": {"kind": "sleep", "lie": true},
	"qt_fig_stir": {"kind": "cook", "statue": true, "pose": "sit_knees"},
	"qt_fig_read": {"kind": "work", "statue": true, "trade": "scholar"},
	"qt_fig_mend": {"kind": "work", "statue": true, "trade": "hunter"},
	"pouf": {"kind": "sit", "seat": true},
	"floor_cushion": {"kind": "sit", "seat": true},
	"garden_bench": {"kind": "sit", "seat": true},
}
## Files that are tables to eat at.
const TABLES: PackedStringArray = ["low_table"]
const TABLE_REACH: float = 1.4
const SEAT_BENCH: float = 0.38
## How high over a bedroll's own floor a sleeper's origin lies.
const LIE_LIFT: float = 0.1


## The spots of home `index` of a built quarter `room` (its plan's
## meta["homes"][index] is `home`), and the old figures standing in it:
## {spots: Array[Dictionary], statues: Array[Node3D], spine: PackedVector3Array
## (a clear way through it, lane to back, global)}.
static func scan_home(room: Node3D, index: int, home: Dictionary) -> Dictionary:
	var spots: Array[Dictionary] = []
	var statues: Array[Node3D] = []
	var tables: Array[Node3D] = []
	var things: Array[Node3D] = []
	var prefix: String = "prop_qt_item_%d_" % index
	for n: Node in room.find_children(prefix + "*", "Node3D", true, false):
		var file: String = n.scene_file_path.get_file().get_basename()
		if file == "":
			continue
		things.append(n as Node3D)
		if TABLES.has(file):
			tables.append(n as Node3D)
	for n: Node3D in things:
		var file: String = n.scene_file_path.get_file().get_basename()
		if not BY_FILE.has(file):
			continue
		var d: Dictionary = BY_FILE[file]
		var spot: Dictionary = {"kind": d["kind"], "at": n.global_position, "yaw": n.global_rotation.y, "pose": str(d.get("pose", "")), "top": 0.0,
				"node": n, "by": null, "trade": str(d.get("trade", ""))}
		if d.get("statue", false):
			# The old figures face their own +Z; a body faces its -Z.
			spot["yaw"] = n.global_rotation.y + PI
			statues.append(n)
		elif d.get("lie", false):
			var box: AABB = box_of(n)
			spot["at"] = Vector3(box.get_center().x, n.global_position.y + LIE_LIFT, box.get_center().z)
			spot["yaw"] = 0.0 if box.size.z >= box.size.x else PI * 0.5
			spot["pose"] = "sleep"
		elif d.get("seat", false):
			var box: AABB = box_of(n)
			spot["top"] = box.end.y - _floor_y(room, home)
			spot["at"] = Vector3(box.get_center().x, box.end.y - 0.02, box.get_center().z)
			spot["pose"] = "sit_bench" if float(spot["top"]) >= SEAT_BENCH else ""
			var table: Node3D = _nearest(tables, spot["at"], TABLE_REACH)
			if table != null:
				var to: Vector3 = table.global_position - (spot["at"] as Vector3)
				spot["yaw"] = atan2(-to.x, -to.z)
				spot["kind"] = "eat"
		spots.append(spot)
	# The home itself: its door (on the lane, facing out) and its floor.
	var walk: Array = home["walk"]
	var spine := PackedVector3Array()
	for p: Variant in walk:
		spine.append(room.to_global(p as Vector3))
	var out: Vector3 = spine[0] - spine[1]
	spots.append({"kind": "door", "at": spine[0], "yaw": atan2(-out.x, -out.z), "pose": "idle", "top": 0.0, "node": null, "by": null, "trade": ""})
	spots.append({"kind": "stand", "at": room.to_global(home["inside"] as Vector3), "yaw": atan2(-out.x, -out.z), "pose": "idle", "top": 0.0, "node": null,
			"by": null, "trade": ""})
	return {"spots": spots, "statues": statues, "spine": spine}


## Everything a node draws, as one box (global).
static func box_of(n: Node3D) -> AABB:
	var box := AABB(n.global_position, Vector3.ZERO)
	var first: bool = true
	var meshes: Array[Node] = n.find_children("*", "MeshInstance3D", true, false)
	if n is MeshInstance3D:
		meshes.append(n)
	for m: Node in meshes:
		var mi := m as MeshInstance3D
		var b: AABB = mi.global_transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


static func _floor_y(room: Node3D, home: Dictionary) -> float:
	return room.to_global(home["inside"] as Vector3).y


static func _nearest(nodes: Array[Node3D], at: Vector3, reach: float) -> Node3D:
	var best: Node3D = null
	var best_d: float = reach
	for n: Node3D in nodes:
		var d: float = Vector2(n.global_position.x - at.x, n.global_position.z - at.z).length()
		if d < best_d:
			best_d = d
			best = n
	return best

class_name AreaPlan
extends RefCounted
## The output of AreaPlanner (phase-4-design.md 8.1.1-8.1.2, 8.1.9): every room
## of an area as data, before any room is built. Rooms are placed in the area
## frame, joined door to door as a tree. Pure data apart from the cached scenes
## and grammars it names; the Area node builds rooms from it.
##
## Footprints are 3D (architecture.md 2.1): a room owns whole cells of the 4 m
## grid on every storey it reaches, in the CellGrid convention (cell (x, s, z)
## spans x 4x..4x+4, y 4s.., z -4z..-4z-4). No two rooms share a cell.
##
## Sightlines: rooms see each other through doorways. compute_sight() casts a
## fan of straight lines through every doorway on the floor storey's cells,
## passing only open edges inside a room and the doorway arches between rooms;
## a line may cross at most max_sight_depth rooms beyond the one it starts in,
## and every room on a line can see every other (the visible sets).

const BAY: float = CellGrid.BAY
## Half the width of an arch a line may pass (the kit's 3 m arches and doors).
const ARCH_HALF: float = 1.5
## Half the width of an open edge between two cells of one room.
const OPEN_HALF: float = 2.0
## Lines cast through each doorway: start points across the arch, angles.
const FAN_OFFSETS: int = 5
const FAN_ANGLES: int = 57
const FAN_MAX_DEG: float = 84.0
## A line stops after this many cells.
const MAX_LINE_CELLS: int = 64


## One room of the plan.
class Room:
	extends RefCounted
	var slot_id: String = ""
	var display_name: String = ""
	## "scene" (authored or baked) or "generated".
	var kind: String = "scene"
	var scene: PackedScene
	var grammar: RoomGrammar
	var rules: ModuleRules
	var seed_value: int = 1
	## Room frame -> area frame.
	var xf: Transform3D = Transform3D()
	## Floor storey (the storey of the room's origin).
	var storey: int = 0
	var parent: String = ""
	var parent_connector: StringName = &""
	## Its connector joined to the parent ("" for the root).
	var entry: StringName = &""
	## name -> {xf: Transform3D (area frame), storey: int, joined: "slot/connector" or "",
	## cap: "" (none needed or joined), "glow" (the glowing exit stub) or "open" (leads nowhere)}.
	var connectors: Dictionary = {}
	## Area cells it occupies, every storey: Vector3i -> true.
	var cells: Dictionary = {}
	## Its walkable cells on the floor storey (what sightlines cross): Vector3i -> true.
	var floor_cells: Dictionary = {}
	## Edges between its own floor cells a line may cross: area edge key -> half width.
	var sight: Dictionary = {}
	## Area-frame boxes later rooms' layouts keep out of.
	var blockers: Array[AABB] = []
	## {style group: entry index} the built room takes (inherited from its parent).
	var style_overrides: Dictionary = {}
	## A generated room's planned layout (room frame).
	var grid: CellGrid
	## A generated room: "exit" or "dead_end".
	var end_kind: String = ""
	## Nodes the built room drops (relative paths): a baked exit stub where a room joins.
	var drop_nodes: PackedStringArray = []
	## Doorways from the root.
	var depth: int = 0

	func children_count() -> int:
		var n: int = 0
		for name: StringName in connectors:
			if name != entry and str(connectors[name]["joined"]) != "":
				n += 1
		return n


var area_id: String = ""
var display_name: String = ""
var area_seed: int = 1
var recipe_version: int = 1
var room_count: Vector2i = Vector2i(6, 10)
var max_sight_depth: int = 2
var placement: AreaPlacement
var rooms: Array[Room] = []
var by_slot: Dictionary = {}
## Graph edges, parent first: [{a: slot, a_conn: StringName, b: slot, b_conn: StringName}].
var edges: Array[Dictionary] = []
## slot -> PackedStringArray of rooms visible from it (compute_sight).
var visible: Dictionary = {}
## Planning problems (a required room that doesn't fit, a sightline too deep).
var errors: PackedStringArray = []
## Planner counts: grow candidates tried and rejected, and why.
var stats: Dictionary = {}
## Milliseconds the planner took.
var plan_ms: float = 0.0


func room(slot_id: String) -> Room:
	return by_slot.get(slot_id)


func add_room(r: Room) -> void:
	rooms.append(r)
	by_slot[r.slot_id] = r


## Joins child `r` at its entry to `parent`'s connector `conn` (both must exist).
func join(r: Room, parent_room: Room, conn: StringName) -> void:
	r.parent = parent_room.slot_id
	r.parent_connector = conn
	r.depth = parent_room.depth + 1
	parent_room.connectors[conn]["joined"] = "%s/%s" % [r.slot_id, r.entry]
	parent_room.connectors[conn]["cap"] = ""
	r.connectors[r.entry]["joined"] = "%s/%s" % [parent_room.slot_id, conn]
	edges.append({"a": parent_room.slot_id, "a_conn": conn, "b": r.slot_id, "b_conn": r.entry})


## Undoes the last add_room + join (a grow candidate that was rejected).
func remove_last() -> void:
	var r: Room = rooms.pop_back()
	by_slot.erase(r.slot_id)
	if not edges.is_empty() and edges[-1]["b"] == r.slot_id:
		var e: Dictionary = edges.pop_back()
		var p: Room = room(e["a"])
		p.connectors[e["a_conn"]]["joined"] = ""
		p.connectors[e["a_conn"]]["cap"] = "glow" if String(e["a_conn"]).begins_with("SNAP_exit") else "open"


# --- cells -------------------------------------------------------------------------

## The area cell holding area point p (a point on a floor counts in that storey).
static func cell_of(p: Vector3) -> Vector3i:
	return Vector3i(floori(p.x / BAY), floori((p.y + 0.5) / BAY), floori(-p.z / BAY))


## Area-frame box of a cell, one storey tall.
static func cell_box(c: Vector3i) -> AABB:
	return AABB(Vector3(c.x * BAY, c.y * BAY, -c.z * BAY - BAY), Vector3(BAY, BAY, BAY))


## The CellGrid edge key between two neighbouring cells (same storey), or "".
static func key_between(a: Vector3i, b: Vector3i) -> String:
	for side: int in CellGrid.ALL_SIDES:
		if CellGrid.neighbour(a, side) == b:
			return CellGrid.key(a, side)
	return ""


## The room owning area cell c (any storey), or null.
func room_at_cell(c: Vector3i) -> Room:
	for r: Room in rooms:
		if r.cells.has(c):
			return r
	return null


## The room holding area point p, or null. A doorway belongs to neither room.
func room_at(p: Vector3) -> Room:
	return room_at_cell(cell_of(p))


## Area-frame bounds of every room's cells.
func bounds() -> AABB:
	var out := AABB()
	var first: bool = true
	for r: Room in rooms:
		for c: Vector3i in r.cells:
			out = cell_box(c) if first else out.merge(cell_box(c))
			first = false
	return out


# --- checks ------------------------------------------------------------------------

## Everything AreaPlan promises (8.1.2 step 9): a tree reaching every room from
## the root, room_count rooms, no shared cell in 3D, everything inside the
## envelope, every connector joined or capped, and no sightline deeper than
## max_sight_depth. Returns the problems (empty: sound).
func check(check_count: bool = true) -> PackedStringArray:
	var out: PackedStringArray = errors.duplicate()
	if rooms.is_empty():
		out.append("no rooms")
		return out
	# A tree: n - 1 edges, every room reached from the root through them.
	var roots: Array[Room] = rooms.filter(func(r: Room) -> bool: return r.parent == "")
	if roots.size() != 1:
		out.append("%d roots" % roots.size())
	if edges.size() != rooms.size() - 1:
		out.append("%d edges for %d rooms (a tree has %d)" % [edges.size(), rooms.size(), rooms.size() - 1])
	var seen: Dictionary = {}
	var todo: Array[String] = []
	if not roots.is_empty():
		todo.append(roots[0].slot_id)
	while not todo.is_empty():
		var s: String = todo.pop_back()
		if seen.has(s):
			out.append("%s is reached twice (a loop)" % s)
			continue
		seen[s] = true
		for e: Dictionary in edges:
			if e["a"] == s:
				todo.append(e["b"])
	if seen.size() != rooms.size():
		out.append("%d of %d rooms are reached from the root" % [seen.size(), rooms.size()])
	if check_count and (rooms.size() < room_count.x or rooms.size() > room_count.y):
		out.append("%d rooms, outside %d-%d" % [rooms.size(), room_count.x, room_count.y])
	# No two rooms in one cell, any storey.
	var owner: Dictionary = {}
	for r: Room in rooms:
		for c: Vector3i in r.cells:
			if owner.has(c):
				out.append("%s and %s both occupy cell %s" % [owner[c], r.slot_id, c])
			owner[c] = r.slot_id
	# Inside the envelope.
	if placement != null:
		var env: AABB = placement.envelope.grow(0.01)
		for r: Room in rooms:
			for c: Vector3i in r.cells:
				if not env.encloses(cell_box(c)):
					out.append("%s cell %s is outside the envelope %s" % [r.slot_id, c, placement.envelope])
					break
	# Every connector joined or capped.
	for r: Room in rooms:
		for name: StringName in r.connectors:
			var k: Dictionary = r.connectors[name]
			if str(k["joined"]) == "" and str(k["cap"]) != "glow":
				out.append("%s %s leads nowhere" % [r.slot_id, name])
	var sight: Dictionary = compute_sight()
	for v: String in sight["violations"]:
		out.append(v)
	return out


# --- sightlines (architecture.md 2.1) ------------------------------------------------

## Casts every doorway's fan (or only the doorway into room `only`): returns
## {violations: PackedStringArray, visible: {slot: PackedStringArray}, lines: int,
## deepest: int (most rooms on one line)}.
func compute_sight(only: String = "") -> Dictionary:
	var passes: Dictionary = {}       # area edge key -> half width
	var floor_owner: Dictionary = {}  # floor cell -> slot
	for r: Room in rooms:
		passes.merge(r.sight, true)
		for c: Vector3i in r.floor_cells:
			floor_owner[c] = r.slot_id
	var doors: Array[Dictionary] = []
	var violations: PackedStringArray = []
	for e: Dictionary in edges:
		var conn: Dictionary = room(e["a"]).connectors[e["a_conn"]]
		var xf: Transform3D = conn["xf"]
		var out_dir: Vector3 = -xf.basis.z.normalized()
		var a: Vector3i = cell_of(xf.origin - out_dir * BAY * 0.5)
		var b: Vector3i = cell_of(xf.origin + out_dir * BAY * 0.5)
		var k: String = key_between(a, b)
		if k == "":
			violations.append("doorway %s/%s is not on a cell edge" % [e["a"], e["a_conn"]])
			continue
		passes[k] = ARCH_HALF
		if only == "" or e["b"] == only:
			doors.append({"at": xf.origin, "out": out_dir, "storey": conn["storey"], "name": "%s/%s" % [e["a"], e["a_conn"]]})
	var seen: Dictionary = {}
	for r: Room in rooms:
		seen[r.slot_id] = {r.slot_id: true}
	var reported: Dictionary = {}
	var deepest: int = 0
	var lines: int = 0
	for d: Dictionary in doors:
		var o := Vector2(d["at"].x, -d["at"].z) / BAY
		var n := Vector2(d["out"].x, -d["out"].z).normalized()
		var along := Vector2(-n.y, n.x)
		for i: int in FAN_OFFSETS:
			var off: float = lerpf(-ARCH_HALF + 0.15, ARCH_HALF - 0.15, float(i) / (FAN_OFFSETS - 1)) / BAY
			for j: int in FAN_ANGLES:
				var dir: Vector2 = n.rotated(deg_to_rad(lerpf(-FAN_MAX_DEG, FAN_MAX_DEG, float(j) / (FAN_ANGLES - 1))))
				var start: Vector2 = o + along * off
				var fwd: Array[String] = _trace(start + n * 0.002, dir, d["storey"], passes, floor_owner)
				var back: Array[String] = _trace(start - n * 0.002, -dir, d["storey"], passes, floor_owner)
				back.reverse()
				var line: Array[String] = back + fwd
				var distinct: Dictionary = {}
				for s: String in line:
					distinct[s] = true
				lines += 1
				deepest = maxi(deepest, distinct.size())
				for s: String in distinct:
					(seen[s] as Dictionary).merge(distinct)
				if distinct.size() > max_sight_depth + 1:
					var label: String = " > ".join(_dedupe(line))
					if not reported.has(label):
						reported[label] = true
						violations.append("a line through %s crosses %d rooms (%s), more than %d beyond the first" % [d["name"], distinct.size(), label, max_sight_depth])
	var vis: Dictionary = {}
	for s: String in seen:
		var others: PackedStringArray = []
		for t: String in seen[s]:
			if t != s:
				others.append(t)
		others.sort()
		vis[s] = others
	if only == "":
		visible = vis
	return {"violations": violations, "visible": vis, "lines": lines, "deepest": deepest}


## Rooms a line from `p` (cell units: u = x / 4, v = -z / 4) along `dir` passes,
## in order, until a wall, a closed doorway or the end of the floor stops it.
func _trace(p: Vector2, dir: Vector2, storey: int, passes: Dictionary, floor_owner: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var c := Vector2i(floori(p.x), floori(p.y))
	var first: Variant = floor_owner.get(Vector3i(c.x, storey, c.y))
	if first == null:
		return out
	out.append(first)
	var step := Vector2i(int(signf(dir.x)), int(signf(dir.y)))
	var t_delta := Vector2(absf(1.0 / dir.x) if dir.x != 0.0 else INF, absf(1.0 / dir.y) if dir.y != 0.0 else INF)
	var t_max := Vector2(
		((c.x + (1 if step.x > 0 else 0)) - p.x) / dir.x if dir.x != 0.0 else INF,
		((c.y + (1 if step.y > 0 else 0)) - p.y) / dir.y if dir.y != 0.0 else INF)
	for _i: int in MAX_LINE_CELLS:
		var key: String
		var across: float
		var next: Vector2i = c
		if t_max.x < t_max.y:
			across = p.y + dir.y * t_max.x - c.y
			key = CellGrid.key(Vector3i(c.x, storey, c.y), CellGrid.Side.E if step.x > 0 else CellGrid.Side.W)
			next.x += step.x
			t_max.x += t_delta.x
		else:
			across = p.x + dir.x * t_max.y - c.x
			key = CellGrid.key(Vector3i(c.x, storey, c.y), CellGrid.Side.N if step.y > 0 else CellGrid.Side.S)
			next.y += step.y
			t_max.y += t_delta.y
		var half: float = float(passes.get(key, -1.0))
		if half < 0.0 or absf(across - 0.5) * BAY > half:
			break
		c = next
		var who: Variant = floor_owner.get(Vector3i(c.x, storey, c.y))
		if who == null:
			break
		if out[-1] != who:
			out.append(who)
	return out


static func _dedupe(line: Array[String]) -> Array[String]:
	var out: Array[String] = []
	for s: String in line:
		if out.is_empty() or out[-1] != s:
			out.append(s)
	return out


# --- reports -----------------------------------------------------------------------

## One line per room and edge, sorted: equal plans give equal signatures.
func signature() -> String:
	var lines: PackedStringArray = []
	for r: Room in rooms:
		lines.append("r %s %s seed %d at %s turn %d cells %d end %s styles %s" % [r.slot_id, r.kind, r.seed_value,
			r.xf.origin.snappedf(0.01), roundi(rad_to_deg(r.xf.basis.get_euler().y)), r.cells.size(), r.end_kind, r.style_overrides])
		if r.grid != null:
			lines.append("g %s %s" % [r.slot_id, r.grid.signature().sha256_text()])
	for e: Dictionary in edges:
		lines.append("e %s/%s %s/%s" % [e["a"], e["a_conn"], e["b"], e["b_conn"]])
	lines.sort()
	return "\n".join(lines)


## A top-down map of the floor storey: each room's cells in its own colour,
## doorways gold, `px` pixels per cell, north (-Z) up. The world map (architecture.md
## 2.1) is drawn from plans like this, not from geometry.
func draw_map(px: int = 12) -> Image:
	var b: AABB = bounds()
	var lo := Vector2i(floori(b.position.x / BAY) - 1, floori(-b.end.z / BAY) - 1)
	var hi := Vector2i(ceili(b.end.x / BAY) + 1, ceili(-b.position.z / BAY) + 1)
	var img := Image.create((hi.x - lo.x) * px, (hi.y - lo.y) * px, false, Image.FORMAT_RGB8)
	img.fill(Color(0.08, 0.09, 0.1))
	for i: int in rooms.size():
		var r: Room = rooms[i]
		var col := Color.from_hsv(fmod(i * 0.381966, 1.0), 0.45 if r.kind == "generated" else 0.25, 0.85)
		for c: Vector3i in r.floor_cells:
			var x: int = (c.x - lo.x) * px
			var y: int = (hi.y - 1 - c.z) * px
			img.fill_rect(Rect2i(x + 1, y + 1, px - 2, px - 2), col)
	for e: Dictionary in edges:
		var p: Vector3 = room(e["a"]).connectors[e["a_conn"]]["xf"].origin
		var x: int = int((p.x / BAY - lo.x) * px)
		var y: int = int((hi.y - (-p.z / BAY)) * px)
		img.fill_rect(Rect2i(x - 2, y - 2, 5, 5), Color(1.0, 0.8, 0.2))
	return img

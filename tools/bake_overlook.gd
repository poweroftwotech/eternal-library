extends SceneTree
## Builds the Gorge area's root room, the Overlook (phase-6-design.md 5.7.2,
## phase 6 step 2): what you can walk, round the baked gorge.
##   godot --headless --path . --script res://tools/bake_overlook.gd
## Writes rooms/gorge/overlook.tscn (yours to finish by hand afterwards;
## re-running overwrites it):
##   - the balcony's spawn, facing the gorge (the balcony itself, opened onto
##     the stair at its front-left corner, is in the baked gorge:
##     vista.gd walkable_overlook);
##   - the stair's head, the stair as a ramp over its steps with guards inside
##     its masonry parapets, the landing's top (vista_foreground.gd builds
##     what you see of them);
##   - balustrades round the landing but where the stair arrives and the way on
##     leaves; a stair flight down one storey from the landing's far side; a
##     corbelled ledge on piers round the south end of the left colossus's
##     pedestal, with balustrades and lamp posts, ending at a connector facing
##     bank 1 (step 3's span starts there);
##   - a sealed bronze door in the loggia's back wall, closing the passage
##     toward the camp (step 6 opens it), and a safety floor far below.

const OUT: String = "res://rooms/gorge/overlook.tscn"
const FOREGROUND = preload("res://scripts/vista_foreground.gd")
const VISTA = preload("res://scripts/vista.gd")
const CLIFF = preload("res://scripts/vista_cliff.gd")
const MOD: String = "res://kit/modules/"
## The overlook (capture.gd vista_concept): where you stand (your feet), what you face.
const EYE: Vector3 = Vector3(-1, 2.25, -27.45)
const FACING: Vector3 = Vector3(5, -22, -178)
const BALCONY_FLOOR: float = 2.18
const LANDING_HALF: float = 6.0
const GUARD_H: float = 3.0
## The ledge after the flight: bays on along the stair's line, then toward
## bank 1 (three on: with two, the west run passed under the colossus's plinth).
const ON_BAYS: int = 3
const WEST_BAYS: int = 4
## Piers carry the ledge down into the mist, one under each bay's corbel.
const PIER_SIZE: float = 1.6
const PIER_FOOT: float = -90.0

var room: RoomTemplate
var scenes: Dictionary = {}
var placed: int = 0
## Where balustrades end or meet (collected as they're placed; newels go on
## them once, those within NEWEL_MERGE of each other as one), and lamps.
var ends: Array[Vector3] = []
var lamps: Array[Vector3] = []
const NEWEL: float = .55
const NEWEL_MERGE: float = .7
## The stair's downhill direction; the newels square to it.
var flat_dir: Vector3


func _initialize() -> void:
	room = RoomTemplate.new()
	room.name = "Overlook"
	room.display_name = "The Overlook"
	room.off_grid = true     # it follows the diagonal stair, not the world's grid
	var spawn := Marker3D.new()
	spawn.name = "PlayerSpawn"
	add(room, spawn)
	spawn.transform = Transform3D(Basis.looking_at(Vector3(FACING.x - EYE.x, 0, FACING.z - EYE.z)), EYE)
	var collision := StaticBody3D.new()
	collision.name = "Collision"
	add(room, collision)
	var pieces := Node3D.new()
	pieces.name = "Pieces"
	add(room, pieces)
	var connectors := Node3D.new()
	connectors.name = "Connectors"
	add(room, connectors)

	# The stair's frame: `flat` downhill, `across` its width (vista_foreground.gd).
	var top: Vector3 = FOREGROUND.STAIR_TOP
	var landing: Vector3 = FOREGROUND.STAIR_LANDING
	var run := Vector3(landing.x - top.x, 0, landing.z - top.z)
	var flat: Vector3 = run.normalized()
	flat_dir = flat
	var across := Vector3(flat.z, 0, -flat.x)
	var length: float = Vector3(run.x, landing.y - top.y, run.z).length()
	var down: Vector3 = (landing - top).normalized()

	# Onto the stair: its head, level with the balcony's floor.
	var head: float = FOREGROUND.STAIR_HEAD
	var head_basis := Basis(Vector3.UP, atan2(flat.x, flat.z))
	ramp(collision, "stair_head", Vector3(top.x, FOREGROUND.STAIR_FLOOR - .3, top.z) - flat * head * .5, Vector3(FOREGROUND.STAIR_WIDTH, .6, head), head_basis)
	# The stair as a ramp through its step noses, and guards inside its
	# parapets, from the head to the landing's edge.
	var slope := Basis(across, down.cross(across).normalized(), -down)     # x across, z uphill
	var walk: float = FOREGROUND.STAIR_WIDTH - FOREGROUND.STAIR_PARAPET * 2.0
	ramp(collision, "stair_ramp", top.lerp(landing, .5) - slope.y * .2, Vector3(walk, .4, length), slope)
	# The east guard runs on along the head to the balcony's parapet; the
	# head's west half is under the balcony's floor, so the west one starts at
	# the first step.
	for side: float in [-1.0, 1.0]:
		var from: float = -head if side < 0.0 else 0.0
		var to: float = run.length()     # down to the stair's foot, as its balustrades
		var mid: Vector3 = top.lerp(landing, (from + to) * .5 / run.length())
		guard(collision, "stair_guard_%d" % side, mid + across * side * (walk * .5 + .2) + slope.y * (GUARD_H * .5 - .4),
			Vector3(.4, GUARD_H, (to - from) / run.length() * length), slope)
	# The landing (vista.gd turns its outline by -yaw: about +Y by yaw).
	var yaw: float = atan2(flat.x, flat.z)
	var land := Basis(Vector3.UP, yaw)          # its local +z is `flat`
	var land_xf := Transform3D(land, Vector3(landing.x, landing.y, landing.z))
	ramp(collision, "landing_top", land_xf * Vector3(0, -.3, 0), Vector3(LANDING_HALF * 2, .6, LANDING_HALF * 2), land)
	# Balustrades round the landing: 4 m pieces from corner to corner; the
	# near edge open where the stair arrives, the far edge where the flight leaves.
	for edge: int in 4:
		for k: int in 3:
			if (edge == 0 or edge == 2) and k == 1:
				continue          # 0: the near edge (the stair), 2: the far edge (the flight)
			var along: Transform3D = land_xf * _landing_edge(edge, k)
			piece(pieces, "walls/chasm_parapet_4m", along)
			joints(along)

	# The flight down a storey from the landing's far side, then the ledge.
	# Frame G: its -Z downhill (flat), X along the landing's local -x.
	var far_mid: Vector3 = land_xf * Vector3(0, 0, LANDING_HALF)
	var g_basis := Basis(Vector3.UP.cross(-flat).normalized(), Vector3.UP, -flat)
	var g := Transform3D(g_basis, far_mid - g_basis.x * 2.0)
	# Where the stair's balustrades cross the landing's near edge, and its
	# balustrades meet: one newel each.
	for side: float in [-1.0, 1.0]:
		var line_at: Vector3 = Vector3(top.x, landing.y, top.z) + across * side * (FOREGROUND.STAIR_WIDTH * .5 - FOREGROUND.STAIR_PARAPET + .18) + flat * (run.length() - LANDING_HALF)
		ends.append(line_at)
	piece(pieces, "walls/chasm_stair_flight", g)
	# The flight's balustrades' ends (kit_add_r10.py: 0.18 m in from its edges,
	# on the line through its step tops, 0.1 m under its top and its foot).
	for x: float in [.18, 3.82]:
		ends.append(g * Vector3(x, -.1, 0))
		ends.append(g * Vector3(x, -4.0, -8.0))
	var path: Dictionary = {}          # (i, j) cells of the ledge at the flight's foot (y -4 in G)
	for j: int in range(2, 2 + ON_BAYS):
		path[Vector2i(0, j)] = true
	for i: int in range(1, WEST_BAYS + 1):
		path[Vector2i(-i, 1 + ON_BAYS)] = true
	var foot := Vector3(0, -4.0, 0)
	for c: Vector2i in path:
		var cell := g * Transform3D(Basis(), Vector3(c.x * 4.0, 0, -c.y * 4.0) + foot)
		piece(pieces, "walls/cliff_ledge_4m", cell)
		# Its pier, from under the corbel (2.3 m under the walk) down into the mist.
		var under: Vector3 = cell * Vector3(2.0, -2.3, -2.0)
		pillar(pieces, "ledge_pier_%d_%d" % [c.x, c.y], Vector3(under.x, (under.y + PIER_FOOT) * .5, under.z), Vector3(PIER_SIZE, under.y - PIER_FOOT, PIER_SIZE), cell.basis)
	# Its open edges get balustrades (but the flight's foot); lamp posts on every
	# other bay's outer edge.
	var end: Vector2i = Vector2i(-WEST_BAYS, 1 + ON_BAYS)
	for c: Vector2i in path:
		for side: int in 4:
			var n: Vector2i = c + [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)][side]
			if path.has(n) or (c == Vector2i(0, 2) and side == 0):
				continue
			var xf: Transform3D = g * Transform3D(Basis(), Vector3(c.x * 4.0, 0, -c.y * 4.0) + foot) * _cell_edge(side)
			piece(pieces, "walls/chasm_parapet_4m", xf)
			joints(xf)
			if c == end and side == 3:
				# Step 3's span starts here: a connector, -Z out of the room.
				var conn := Marker3D.new()
				conn.name = "SNAP_exit_ledge"
				add(connectors, conn)
				conn.transform = Transform3D(xf.basis * Basis(Vector3.UP, PI), xf * Vector3(2.0, 0, 0))
			elif (c.x + c.y) % 2 == 0 and side != 3:
				lamps.append(xf * Vector3(0, 0, -.18))     # on the newel at the bay's start (mid-bay, it stood in the balusters)

	# The passage toward the camp: a sealed door in the loggia's back wall (step
	# 6 opens it; set back in the passage, the floor stopped short of it), a
	# wall over it and rock either side, filling the opening.
	var gate: Rect2 = CLIFF.PASSAGE
	var back: float = CLIFF.LOGGIA_BACK
	var left: float = gate.position.x + (gate.size.x - 4.0) * .5
	piece(pieces, "walls/wall_vault_door_4m", Transform3D(Basis(), Vector3(left, gate.position.y, back)))
	piece(pieces, "walls/wall_plain_4m", Transform3D(Basis(), Vector3(left, gate.position.y + 4.0, back)))
	# (The passage's brick walls fill its sides: rock there z-fought their faces.)
	newels(pieces)
	# A safety floor far below the near gorge (AGENTS.md 6).
	guard(collision, "safety_floor", Vector3(0, -60, -110), Vector3(260, 1, 220), Basis())

	var scene := PackedScene.new()
	var err: Error = scene.pack(room)
	if err == OK:
		err = ResourceSaver.save(scene, OUT)
	print("bake_overlook: %d pieces, %d collision shapes, connector at %s -> %s (%s)" % [placed, collision.get_child_count(),
		(connectors.get_child(0) as Node3D).position if connectors.get_child_count() > 0 else "none", OUT, error_string(err)])
	room.free()
	quit(0 if err == OK else 1)


## A balustrade piece's two ends (chasm_parapet_4m: x 0 .. 4, 0.18 m in).
func joints(xf: Transform3D) -> void:
	ends.append(xf * Vector3(0, 0, -.18))
	ends.append(xf * Vector3(4, 0, -.18))


## Square newels on the balustrades' joints, a lamp post on some.
func newels(pieces: Node) -> void:
	var groups: Array = []
	for p: Vector3 in ends:
		var found: bool = false
		for gr: Array in groups:
			if (gr[0] as Vector3).distance_to(p) < NEWEL_MERGE:
				gr.append(p)
				found = true
				break
		if not found:
			groups.append([p])
	# All the posts as one mesh, all the caps as another (one each was two
	# draw calls a newel).
	var turn := Basis(Vector3.UP, atan2(flat_dir.x, flat_dir.z))
	var post_box := BoxMesh.new()
	post_box.size = Vector3(NEWEL, 1.4, NEWEL)
	var cap_box := BoxMesh.new()
	cap_box.size = Vector3(NEWEL + .1, .1, NEWEL + .1)
	var posts := SurfaceTool.new()
	var caps := SurfaceTool.new()
	var n: int = 0
	for gr: Array in groups:
		var at := Vector3.ZERO
		for p: Vector3 in gr:
			at += p
		at /= gr.size()
		posts.append_from(post_box, 0, Transform3D(turn, at + Vector3(0, .45, 0)))
		caps.append_from(cap_box, 0, Transform3D(turn, at + Vector3(0, 1.2, 0)))
		for l: Vector3 in lamps:
			if l.distance_to(at) < NEWEL_MERGE:
				var post: Node3D = (load(MOD + "dressing/chasm_lamp_post.tscn") as PackedScene).instantiate()
				post.name = "chasm_lamp_post_%d" % n
				add(pieces, post)
				post.transform = Transform3D(Basis().scaled(Vector3.ONE * .6), at + Vector3(0, 1.25, 0))
				placed += 1
				break
		n += 1
	for m: Array in [["newel_posts", posts, "gorge_sandstone"], ["newel_caps", caps, "gorge_limestone"]]:
		var mesh := MeshInstance3D.new()
		mesh.name = m[0]
		mesh.mesh = (m[1] as SurfaceTool).commit()
		mesh.material_override = load("res://kit/materials/%s.tres" % m[2])
		add(pieces, mesh)

## An edge module's frame on the landing's side `edge` (0 near -z, 1 +x,
## 2 far +z, 3 -x), its k-th 4 m piece; -Z into the landing.
func _landing_edge(edge: int, k: int) -> Transform3D:
	var h: float = LANDING_HALF
	match edge:
		0:
			return Transform3D(Basis(Vector3.UP, PI), Vector3(h - k * 4.0, 0, -h))
		1:
			return Transform3D(Basis(Vector3.UP, PI * .5), Vector3(h, 0, h - k * 4.0))
		2:
			return Transform3D(Basis(), Vector3(-h + k * 4.0, 0, h))
	return Transform3D(Basis(Vector3.UP, -PI * .5), Vector3(-h, 0, -h + k * 4.0))


## An edge module's frame on a cell's side (0 the cell's +Z side, 1 +X, 2 -Z,
## 3 -X, in the cell's frame where it spans x 0..4, z -4..0); -Z into the cell.
func _cell_edge(side: int) -> Transform3D:
	match side:
		0:
			return Transform3D(Basis(), Vector3(0, 0, 0))
		1:
			return Transform3D(Basis(Vector3.UP, PI * .5), Vector3(4, 0, 0))
		2:
			return Transform3D(Basis(Vector3.UP, PI), Vector3(4, 0, -4))
	return Transform3D(Basis(Vector3.UP, -PI * .5), Vector3(0, 0, -4))


func piece(parent: Node, path: String, xf: Transform3D) -> void:
	var full: String = MOD + path + ".tscn"
	if not scenes.has(full):
		scenes[full] = load(full)
	var node: Node3D = (scenes[full] as PackedScene).instantiate()
	node.name = "%s_%d" % [path.get_file(), placed]
	add(parent, node)
	node.transform = xf
	placed += 1


## A walkable box: collision, and (with a material) its stone.
func box(collision: Node, pieces: Node, name: String, at: Vector3, size: Vector3, basis: Basis, material: String) -> void:
	ramp(collision, name, at, size, basis)
	var mesh := MeshInstance3D.new()
	mesh.name = name
	var shape := BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	mesh.material_override = load("res://kit/materials/%s.tres" % material)
	add(pieces, mesh)
	mesh.transform = Transform3D(basis, at)


## Stone only looked at (out of reach): no collision.
func pillar(pieces: Node, name: String, at: Vector3, size: Vector3, basis: Basis) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = name
	var shape := BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	mesh.material_override = load("res://kit/materials/gorge_sandstone.tres")
	add(pieces, mesh)
	mesh.transform = Transform3D(basis, at)


func ramp(collision: Node, name: String, at: Vector3, size: Vector3, basis: Basis) -> void:
	var shape := CollisionShape3D.new()
	shape.name = name
	var b := BoxShape3D.new()
	b.size = size
	shape.shape = b
	add(collision, shape)
	shape.transform = Transform3D(basis, at)


func guard(collision: Node, name: String, at: Vector3, size: Vector3, basis: Basis) -> void:
	ramp(collision, name, at, size, basis)


func add(parent: Node, node: Node) -> void:
	parent.add_child(node)
	node.owner = room

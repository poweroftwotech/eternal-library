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
##     ledge of span decks on arcades round the south end of the left
##     colossus's pedestal, with balustrades and lamp posts, running into bank
##     1's facade at a connector (a door into it later), and one on the corner
##     where it turns, facing across the gorge, where step 3's span starts;
##   - its piers in the group "blocker": what the planner keeps the network's
##     links clear of, as it does the kit pieces (AreaPlanner);
##   - the passage in the loggia's back wall open onto the camp's corridor (phase 9:
##     the bronze door and its threshold were phase 7's door to the camp), and
##     a safety floor far below.

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
## bank 1 (three on: with two, the west run passed under the colossus's plinth;
## five toward it, into its facade, which carries its end: walked, with four
## it stopped short of the wall on a pier on the terrace).
const ON_BAYS: int = 3
const WEST_BAYS: int = 5
## The ledge stands on the span's arcades (walked: on piers it looked like
## another bridge's): the on run on one arcade (ChasmGrammar._arcades, piers
## where they stand cleanly), the west run on one arch from that arcade's
## flank to the facade, its far foot on bank 1's terrace by the wall.
const ARCADE_HALF: float = 1.6
## How far the west arch's far foot reaches into the facade (past its farthest
## point across the arch, so no gap shows where the wall is oblique).
const ARCH_INTO_WALL: float = .3


var room: RoomTemplate
var scenes: Dictionary = {}
var placed: int = 0
## Where balustrades end or meet (collected as they're placed; newels go on
## them once, those within NEWEL_MERGE of each other as one), and lamps.
var ends: Array[Vector3] = []
var lamps: Array[Vector3] = []
## The span's grammar, for where a pier stands cleanly; the piers that found
## no place.
var chasm: ChasmGrammar = load("res://gen/grammars/r10_chasm.tres")
var unsupported: PackedStringArray = []
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
	# The landing, its flight and the ledge keep their own line (phase 8 step 3:
	# only the stair turned, to arrive centred on the camp's door).
	var line: Vector3 = FOREGROUND.landing_flat()
	flat_dir = line
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
	var yaw: float = atan2(line.x, line.z)
	var land := Basis(Vector3.UP, yaw)          # its local +z is `line`
	var land_xf := Transform3D(land, Vector3(landing.x, landing.y, landing.z))
	ramp(collision, "landing_top", land_xf * Vector3(0, -.3, 0), Vector3(LANDING_HALF * 2, .6, LANDING_HALF * 2), land)
	# Where the stair's balustrades cross the landing's near edge (landing x;
	# the stair meets it at an angle): one newel each, the edge open between.
	var inv: Transform3D = land_xf.affine_inverse()
	var crossing: Array[float] = []
	for side: float in [-1.0, 1.0]:
		var p0: Vector3 = Vector3(top.x, landing.y, top.z) + across * side * (FOREGROUND.STAIR_WIDTH * .5 - FOREGROUND.STAIR_PARAPET + .18)
		var z0: float = (inv * p0).z
		var at: Vector3 = p0 + flat * ((-LANDING_HALF - z0) / ((inv * (p0 + flat)).z - z0))
		ends.append(at)
		crossing.append((inv * at).x)
	var open_lo: float = minf(crossing[0], crossing[1]) - .25
	var open_hi: float = maxf(crossing[0], crossing[1]) + .25
	# Balustrades round the landing: 4 m pieces from corner to corner; the
	# near edge open where the stair arrives, the far edge where the flight leaves.
	for edge: int in [1, 2, 3]:
		for k: int in 3:
			if edge == 2 and k == 1:
				continue          # the far edge (the flight)
			var along: Transform3D = land_xf * _landing_edge(edge, k)
			piece(pieces, "walls/chasm_parapet_4m", along)
			joints(along)
	# The near edge (edge 0, its pieces running toward -x): stretched pieces
	# from each corner to the stair's opening.
	for run_x: Vector2 in [Vector2(LANDING_HALF, open_hi), Vector2(open_lo, -LANDING_HALF)]:
		var along := land_xf * Transform3D(Basis(Vector3.UP, PI) * Basis.from_scale(Vector3((run_x.x - run_x.y) / 4.0, 1, 1)), Vector3(run_x.x, 0, -LANDING_HALF))
		piece(pieces, "walls/chasm_parapet_4m", along)
		joints(along)

	# The flight down a storey from the landing's far side, then the ledge.
	# Frame G: its -Z downhill (line), X along the landing's local -x.
	var far_mid: Vector3 = land_xf * Vector3(0, 0, LANDING_HALF)
	var g_basis := Basis(Vector3.UP.cross(-line).normalized(), Vector3.UP, -line)
	var g := Transform3D(g_basis, far_mid - g_basis.x * 2.0)
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
		piece(pieces, "walls/chasm_deck_4m", g * Transform3D(Basis(), Vector3(c.x * 4.0, 0, -c.y * 4.0) + foot))
	# The on run's arcade, from the flight's foot to the corner's far edge (a
	# span's frame: -Z along the run, its centre line x = 0).
	var on_start: Transform3D = g * Transform3D(Basis(), foot + Vector3(2.0, 0, -8.0))
	var arcade: Dictionary = {"pieces": [], "piers": [], "boxes": [], "falls": []}
	var groups: Array[Dictionary] = [{"a": 0, "top": -ChasmGrammar.COURSE}]
	var rng := RandomNumberGenerator.new()
	if not chasm._arcades(arcade, on_start, chasm._near_tiers(on_start), groups, rng):
		unsupported.append("the on run's arcade")
	for p: Dictionary in arcade["pieces"]:
		place(pieces, p["scene"], on_start * (p["xf"] as Transform3D))
	for k: int in (arcade["piers"] as Array).size():
		var pr: Dictionary = arcade["piers"][k]
		pillar(pieces, "arcade_pier_%d" % k, on_start * (pr["at"] as Vector3), pr["size"], on_start.basis)
	# The west run's arch, from the arcade's flank (its centre line on the
	# cells' at z -18 in G) to bank 1's facade, stretched to reach it.
	var west_start := Transform3D(g.basis * ChasmGrammar.ARC_BASIS, g * (foot + Vector3(2.0 - ARCADE_HALF, 0, -(1 + ON_BAYS) * 4.0 - 2.0)))
	var wall: float = -1.0           # the facade's nearest point across the arch
	var wall_far: float = -1.0       # and its farthest
	var tiers: Array[Dictionary] = chasm._near_tiers(west_start)
	var sides: Array[float] = [-ARCADE_HALF, 0.0, ARCADE_HALF]
	for k: int in range(80, 500):
		var d: float = k * .05
		var hit: Array = sides.filter(func(x: float) -> bool: return GorgeGrammar.solid_at(tiers, west_start * Vector3(x, -1.5, -d)))
		if wall < 0.0 and not hit.is_empty():
			wall = d
		if hit.size() == sides.size():
			wall_far = d
			break
	if wall_far < 0.0:
		unsupported.append("the west run's arch (no facade within 25 m)")
	else:
		var arch_len: float = wall_far + ARCH_INTO_WALL
		var arc: Basis = Basis.from_scale(Vector3(1, 1, arch_len / 12.0)) * ChasmGrammar.ARC_BASIS
		place(pieces, MOD + "walls/aqueduct_upper_12m.tscn", west_start * Transform3D(arc, Vector3(0, -ChasmGrammar.COURSE, 0)))
		print("bake_overlook: the west arch reaches bank 1's facade at %.2f..%.2f m (%.2f stretched)" % [wall, wall_far, arch_len / 12.0])
	# Its open edges get balustrades (but the flight's foot, and the end in
	# bank 1's facade: a guard there, the wall's face is nothing to stop on);
	# lamp posts on every other bay's outer edge.
	var end: Vector2i = Vector2i(-WEST_BAYS, 1 + ON_BAYS)
	for c: Vector2i in path:
		for side: int in 4:
			var n: Vector2i = c + [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)][side]
			if path.has(n) or (c == Vector2i(0, 2) and side == 0):
				continue
			var xf: Transform3D = g * Transform3D(Basis(), Vector3(c.x * 4.0, 0, -c.y * 4.0) + foot) * _cell_edge(side)
			if c == Vector2i(0, 1 + ON_BAYS) and side == 1:
				# The corner's gorge side opens onto step 3's span, which runs
				# from here across to bank 2 (nearly the near aqueduct's line).
				var span := Marker3D.new()
				span.name = "SNAP_exit_span"
				add(connectors, span)
				span.transform = Transform3D(xf.basis * Basis(Vector3.UP, PI), xf * Vector3(2.0, 0, 0))
				lamps.append(xf * Vector3(0, 0, -.18))
				continue
			if c == end and side == 3:
				# Into bank 1's facade: a connector, -Z out of the room (a door
				# later), and a guard at the facade's nearest point.
				var conn := Marker3D.new()
				conn.name = "SNAP_exit_ledge"
				add(connectors, conn)
				conn.transform = Transform3D(xf.basis * Basis(Vector3.UP, PI), xf * Vector3(2.0, 0, 0))
				# (How far the end runs past the facade's nearest point: the guard
				# stands that far back into the bay.)
				var into: float = (WEST_BAYS * 4.0 + 2.0 - ARCADE_HALF) - wall if wall > 0.0 else 0.0
				guard(collision, "facade_guard", xf * Vector3(2.0, GUARD_H * .5, -maxf(into, 0.0) - .2), Vector3(4.0, GUARD_H, .4), xf.basis)
				print("bake_overlook: the ledge's end runs %.2f m past the facade's nearest point" % into)
				continue
			piece(pieces, "walls/chasm_parapet_4m", xf)
			joints(xf)
			if (c.x + c.y) % 2 == 0 and side != 3:
				lamps.append(xf * Vector3(0, 0, -.18))     # on the newel at the bay's start (mid-bay, it stood in the balusters)

	# The passage toward the camp: open since phase 9 (one continuous world: the
	# camp's corridor runs on into the loggia, SeamlessPlaces), a wall over it
	# and rock either side. (Its door connector went with the door: a connector
	# leading nowhere fails the plan's check.)
	var gate: Rect2 = CLIFF.PASSAGE
	var back: float = CLIFF.LOGGIA_BACK
	var left: float = gate.position.x + (gate.size.x - 4.0) * .5
	piece(pieces, "walls/wall_plain_4m", Transform3D(Basis(), Vector3(left, gate.position.y + 4.0, back)))
	# (The passage's brick walls fill its sides: rock there z-fought their faces.)
	# The landing and the stair are masonry cut down to the stair's base, 20 m
	# under the balcony (walked: they hung there on nothing): a broad pier under
	# the landing and one under the stair's middle, down to what they stand on.
	var grid: Array = []
	for i: int in [0, 1, -1, 2, -2]:
		for j: int in [0, 1, -1, 2, -2]:
			grid.append(Vector3(i, 0, j))
	support(pieces, "landing_pier", Vector3(landing.x, FOREGROUND.STAIR_BASE, landing.z), Vector2(2.5, 2.5), land, grid)
	var stair_mid: Vector3 = top.lerp(landing, .5)
	support(pieces, "stair_pier", Vector3(stair_mid.x, FOREGROUND.STAIR_BASE, stair_mid.z), Vector2(1.6, 1.6), land, grid)
	newels(pieces)
	# A safety floor far below the near gorge (AGENTS.md 6).
	guard(collision, "safety_floor", Vector3(0, -60, -110), Vector3(260, 1, 220), Basis())

	var scene := PackedScene.new()
	var err: Error = scene.pack(room)
	if err == OK:
		err = ResourceSaver.save(scene, OUT)
	if not unsupported.is_empty():
		print("bake_overlook: no clean place for %s" % [unsupported])
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
	place(parent, MOD + path + ".tscn", xf)


## A kit piece by its scene's full path.
func place(parent: Node, full: String, xf: Transform3D) -> void:
	var path: String = full.get_basename().trim_prefix(MOD)
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
	mesh.add_to_group(&"blocker", true)
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


## A pier under `top` (its half size across and along, turned by `basis`)
## down to what it stands on cleanly, at the first of `offsets` (in the
## basis) where one does. Whether one stood.
func support(pieces: Node, name: String, top: Vector3, half: Vector2, basis: Basis, offsets: Array) -> bool:
	for o: Vector3 in offsets:
		var p: Vector3 = top + basis * o
		var r: Dictionary = chasm.pier_under(p, Vector2.ONE * half.length())
		if r.is_empty():
			continue
		var foot: float = r["foot"]
		pillar(pieces, name, Vector3(p.x, (p.y + foot) * .5, p.z), Vector3(half.x * 2.0, p.y - foot, half.y * 2.0), basis)
		return true
	unsupported.append(name)
	return false

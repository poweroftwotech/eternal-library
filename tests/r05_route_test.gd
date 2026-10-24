extends SceneTree
## R05 route gate (phase-5-design.md 5.6.7), headless:
##   godot --headless --path . --script res://tests/r05_route_test.gd [-- seeds=N]
## The Lower Stacks' caravanserai (the baked 5 x 5 court, the area's root),
## seeds 1-3, every room built at once. The validator is clean. The real
## player's capsule (radius 0.35, height 1.8):
##   - walks from the gate to every open court cell and back round the hearth;
##   - steps into every ground cell through its arch and out again;
##   - climbs onto the hearth's platform;
##   - climbs the west stair to the upper storey (feet on the loggia floor),
##     walks the loggia through every upper cell and round the corners, and
##     comes down the east stair into the court, nothing catching it;
##   - walks out of the gate and each side door into the room beyond (or to
##     its stub) and back.
## And the upper arches' sills, the stair's divider and the stair halls' end
## walls stop a walk off the upper storey.

const RECIPE: String = "res://gen/recipes/lower_stacks.tres"
const SEEDS: int = 3
const SPEED: float = 6.0

var failures: PackedStringArray = []
var snags: int = 0
var checks: int = 0


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures.append(what)


func run() -> void:
	var seeds: int = SEEDS
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("seeds="):
			seeds = a.trim_prefix("seeds=").to_int()
	for s: int in range(1, seeds + 1):
		await walk_seed(s)
	Area.seed_override = -1
	print("r05_route_test: %d checks, %d failures" % [checks, failures.size()])
	for f: String in failures.slice(0, 40):
		print("  FAIL ", f)
	quit(1 if not failures.is_empty() else 0)


## Room point from a piece's Blender frame: X along, Y in from its face, z up.
static func at(xf: Transform3D, x: float, y: float, z: float = 0.0) -> Vector3:
	return xf * Vector3(x, z, -y)


func walk_seed(s: int) -> void:
	var tag: String = "lower stacks %d" % s
	Area.seed_override = s
	var area := Area.new()
	area.recipe = load(RECIPE)
	area.streaming = false
	root.add_child(area)
	for _i: int in 4:
		await physics_frame
	var plan: AreaPlan.Room = area.plan.room("caravanserai")
	var room: RoomTemplate = area.rooms["caravanserai"]
	var v: Dictionary = KitValidateRoom.run(room)
	check((v["errors"] as PackedStringArray).is_empty() and (v["warnings"] as PackedStringArray).is_empty(), "%s: the caravanserai validates clean (%s)" % [tag, v])
	var m: Dictionary = (room.get_meta("baked_from", {}) as Dictionary).get("layout", {})
	check(m.get("court", false), "%s: the bake keeps the court's layout" % tag)
	if not m.get("court", false):
		area.queue_free()
		return
	var h: int = m["h"]
	var top: int = m["top"]
	var centre: Vector3i = m["centre"]
	var well: Vector3i = m["well"]
	var g := func(p: Vector3) -> Vector3: return room.to_global(p)
	var body: CharacterBody3D = make_capsule(area)
	# The court: from the gate, row by row (serpentine), every open cell, each
	# leg breadth first round the hearth's fire and the well.
	var court: Array[Vector3] = [g.call(CellGrid.cell_centre(Vector3i.ZERO))]
	var at_cell := Vector3i(0, 0, 1)
	court.append(g.call(CellGrid.cell_centre(at_cell)))
	for z: int in range(1, top):
		var xs: Array = range(-h + 1, h)
		if z % 2 == 0:
			xs.reverse()
		for x: int in xs:
			var c := Vector3i(x, 0, z)
			if c == centre or c == well:
				continue
			for step: Vector3i in court_path(at_cell, c, h, top, [centre, well]):
				court.append(g.call(CellGrid.cell_centre(step)))
			at_cell = c
	body.global_position = court[0] + Vector3(0, 0.95, 0)
	await physics_frame
	var got: int = await follow(body, court)
	check(got == court.size(), "%s: from the gate through every open court cell (%d of %d points)" % [tag, got, court.size()])
	# Into every ground cell (its arch) and out.
	var bays: int = 0
	for z: int in range(0, top + 1):
		for x: int in range(-h, h + 1):
			var c := Vector3i(x, 0, z)
			var side: int = CourtyardGrammar.court_side(c, h, top)
			if side < 0 or c == Vector3i.ZERO or (m["stairs"] as Array).any(func(st: Array) -> bool: return st.has(c)):
				continue
			var xf: Transform3D = CellGrid.edge_transform(c, side)
			# From the court cell in front (beside the well when it stands there).
			var front: float = -0.5 if CellGrid.neighbour(c, side) == well else -2.0
			var way: Array[Vector3] = [g.call(at(xf, 2.0, front)), g.call(at(xf, 2.0, 0.8))]
			body.global_position = way[0] + Vector3(0, 0.95, 0)
			await physics_frame
			got = await follow(body, way)
			var back: Array[Vector3] = [way[0]]
			got += await follow(body, back)
			check(got == 3, "%s: into ground cell %s through its arch and out (%d of 3)" % [tag, c, got])
			bays += 1
	check(bays == 15, "%s: 15 ground cells and passages open to the court (%d)" % [tag, bays])
	# Onto the hearth's platform.
	var hearth: Vector3 = CellGrid.cell_centre(centre)
	var onto: Array[Vector3] = [g.call(hearth + Vector3(0, 0, 5.5)), g.call(hearth + Vector3(0, 0, 2.3))]
	body.global_position = onto[0] + Vector3(0, 0.95, 0)
	await physics_frame
	got = await follow(body, onto)
	var feet: float = room.to_local(body.global_position).y - 0.9
	check(got == 2 and absf(feet - 0.47) < 0.1, "%s: up onto the hearth's platform (%d of 2, feet %.2f)" % [tag, got, feet])
	# Up the west stair, round the loggia, down the east stair.
	var tour: Array[Vector3] = upper_tour(m)
	var route: Array[Vector3] = []
	for p: Vector3 in tour:
		route.append(g.call(p))
	body.global_position = route[0] + Vector3(0, 0.95, 0)
	await physics_frame
	snags = 0
	var up_to: int = 12            # the west stair's top landing
	got = await follow(body, route.slice(0, up_to))
	feet = room.to_local(body.global_position).y - 0.9
	check(got == up_to and absf(feet - 4.05) < 0.12, "%s: up the west stair to the upper storey (%d of %d points, feet %.2f)" % [tag, got, up_to, feet])
	got = await follow(body, route.slice(up_to))
	feet = room.to_local(body.global_position).y - 0.9
	check(got == route.size() - up_to and absf(feet) < 0.12, "%s: round the loggia and down the east stair to the court (%d of %d points, feet %.2f)" % [tag, got, route.size() - up_to, feet])
	check(snags == 0, "%s: nothing on the stairs or the loggia catches the capsule (%d frames held back)" % [tag, snags])
	# Out of every door into the room beyond (or to its stub) and back.
	for d: Array in m["doors"]:
		var c: Vector3i = d[0]
		var conn: StringName = StringName("SNAP_exit_" + CellGrid.key(c, d[1]))
		var joined: String = str(plan.connectors[conn]["joined"])
		var door: Transform3D = CellGrid.door_transform(c, d[1])
		var inside: Vector3i = CellGrid.neighbour(c, CourtyardGrammar.court_side(c, h, top))
		var way: Array[Vector3] = [g.call(CellGrid.cell_centre(inside)), g.call(CellGrid.cell_centre(c)),
			g.call(door.origin - door.basis.z * (2.5 if joined != "" else 0.2) + door.basis.z * 0.0)]
		if joined == "":
			way[2] = g.call(door.origin + door.basis.z * 0.6)       # up to the stub's blocker
		body.global_position = way[0] + Vector3(0, 0.95, 0)
		await physics_frame
		got = await follow(body, way)
		check(got == 3, "%s: out of the door at %s %s (%d of 3)" % [tag, c, "into " + joined.get_slice("/", 0) if joined != "" else "to its stub", got])
		var back: Array[Vector3] = way.duplicate()
		back.reverse()
		got = await follow(body, back)
		check(got == 3, "%s: and back into the court (%d of 3)" % [tag, got])
	# Nothing to fall off upstairs.
	var open_ways: PackedStringArray = await rails(body, room, m)
	check(open_ways.is_empty(), "%s: sills, the stair's divider and the halls' ends hold (%s)" % [tag, open_ways.slice(0, 8)])
	print("  %s: %d court points, %d cells, %d points upstairs, doors %s" % [tag, court.size(), bays, route.size(), m["doors"]])
	body.queue_free()
	area.queue_free()
	await process_frame
	await process_frame


## Court cells after `from` up to `to`, breadth first round `avoid`.
static func court_path(from: Vector3i, to: Vector3i, h: int, top: int, avoid: Array) -> Array[Vector3i]:
	var parent: Dictionary = {from: from}
	var todo: Array[Vector3i] = [from]
	while not todo.is_empty() and not parent.has(to):
		var c: Vector3i = todo.pop_front()
		for side: int in CellGrid.ALL_SIDES:
			var n: Vector3i = CellGrid.neighbour(c, side)
			if parent.has(n) or avoid.has(n) or absi(n.x) >= h or n.z <= 0 or n.z >= top:
				continue
			parent[n] = c
			todo.append(n)
	var out: Array[Vector3i] = []
	var c: Vector3i = to
	while c != from and parent.has(c):
		out.push_front(c)
		c = parent[c]
	return out


## Room-frame floor points: in through the west stair's arch, up both
## flights, through the SW corner, the loggia through every upper cell and
## round the far corners, the SE corner and down the east stair to the court.
static func upper_tour(m: Dictionary) -> Array[Vector3]:
	var h: int = m["h"]
	var top: int = m["top"]
	var stairs: Array = m["stairs"]
	var up := Vector3(0, 4.05, 0)
	var west: Transform3D = CellGrid.edge_transform(stairs[0][1], CellGrid.Side.N)
	var east: Transform3D = CellGrid.edge_transform(stairs[1][0], CellGrid.Side.N)
	var climb: Array = [[7.0, -1.0], [7.0, 1.15], [5.5, 1.15], [4.5, 1.15], [3.5, 1.15], [2.5, 1.15], [1.0, 1.15],
		[1.0, 2.75], [2.5, 2.75], [3.5, 2.75], [4.5, 2.75], [7.0, 2.75]]
	var out: Array[Vector3] = []
	for q: Array in climb:
		out.append(at(west, q[0], q[1], 0.0))
	# The stair's top is 4.05 m up: the climb's last points are on its flights,
	# so only the first floor points need a height (follow() keeps the feet).
	out.append(corner_point(m, Vector3i(-h, 0, 0), Vector2(0.6, 2.75)) + up)
	out.append(corner_point(m, Vector3i(-h, 0, 0), Vector2(1.15, 2.75)) + up)
	out.append(corner_point(m, Vector3i(-h, 0, 0), Vector2(1.15, 0.6)) + up)
	for c: Vector3i in m["upper"]:
		var g0 := Vector3i(c.x, 0, c.z)
		out.append(at(CellGrid.edge_transform(g0, CourtyardGrammar.court_side(g0, h, top)), 2.0, 1.15) + up)
		if c == Vector3i(-h, 1, top - 1):
			out.append(corner_point(m, Vector3i(-h, 0, top), Vector2(1.15, 1.15)) + up)
		if c == Vector3i(h - 1, 1, top):
			out.append(corner_point(m, Vector3i(h, 0, top), Vector2(1.15, 1.15)) + up)
	out.append(corner_point(m, Vector3i(h, 0, 0), Vector2(1.15, 0.6)) + up)
	out.append(corner_point(m, Vector3i(h, 0, 0), Vector2(1.15, 2.75)) + up)
	out.append(corner_point(m, Vector3i(h, 0, 0), Vector2(0.6, 2.75)) + up)
	var down: Array = climb.duplicate()
	down.reverse()
	for q: Array in down:
		out.append(at(east, 8.0 - q[0], q[1], 0.0))
	return out


## A point in a corner piece's frame (the grammar's: the edge whose start is
## the court's corner), given as in court_corner_upper_stair (the stair's arm
## from X = 0 in the back lane, the range's from Y = 0): swapped for the
## mirrored corner (court_corner_upper_stair_r).
static func corner_point(_m: Dictionary, corner: Vector3i, p: Vector2) -> Vector3:
	var inner := Vector3(corner.x * CellGrid.BAY + (CellGrid.BAY if corner.x < 0 else 0.0), 0.0,
		-corner.z * CellGrid.BAY - (CellGrid.BAY if corner.z == 0 else 0.0))
	var frame: int = -1
	for side: int in CellGrid.ALL_SIDES:
		if CellGrid.edge_ends(corner, side)[0].is_equal_approx(inner):
			frame = side
	var mirrored: bool = corner.z == 0 and (CellGrid.Side.E if corner.x < 0 else CellGrid.Side.W) == frame
	var q: Vector2 = Vector2(p.y, p.x) if mirrored else p
	return at(CellGrid.edge_transform(corner, frame), q.x, q.y)


func rails(body: CharacterBody3D, room: Node3D, m: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = []
	var h: int = m["h"]
	var top: int = m["top"]
	var stairs: Array = m["stairs"]
	var up := Vector3(0, 4.05 + 0.95 + 0.05, 0)
	# Every upper cell: out through its arch's sill into the court.
	for c: Vector3i in m["upper"]:
		var g0 := Vector3i(c.x, 0, c.z)
		var xf: Transform3D = CellGrid.edge_transform(g0, CourtyardGrammar.court_side(g0, h, top))
		var from: Vector3 = room.to_global(at(xf, 2.0, 1.15) + up)
		if await free_way(body, from, room.global_basis * (at(xf, 2.0, -1.5) - at(xf, 2.0, 1.15))):
			out.append("sill %s" % c)
	# The stairs' top landings: over the divider into the stairwell, and on
	# along the flight's lane past the hall's end is the corner (open), so
	# only the divider is tested; and the first flight's landing over the edge.
	for i: int in 2:
		var xf: Transform3D = CellGrid.edge_transform(stairs[0][1] if i == 0 else stairs[1][0], CellGrid.Side.N)
		var x_top: float = 7.0 if i == 0 else 1.0
		var from: Vector3 = room.to_global(at(xf, x_top, 2.75) + up)
		if await free_way(body, from, room.global_basis * (at(xf, x_top, 0.2) - at(xf, x_top, 2.75))):
			out.append("divider %d" % i)
		var x_mid: float = 4.0
		var mid: Vector3 = room.to_global(at(xf, x_mid, 2.75, 2.0 + 0.513 * (x_mid - 1.9 if i == 0 else 6.1 - x_mid)) + Vector3(0, 0.95 + 0.1, 0))
		if await free_way(body, mid, room.global_basis * (at(xf, x_mid, 0.4) - at(xf, x_mid, 2.75))):
			out.append("flight 2 edge %d" % i)
	return out


func free_way(body: CharacterBody3D, from: Vector3, motion: Vector3) -> bool:
	body.global_position = from
	await physics_frame
	var params := PhysicsTestMotionParameters3D.new()
	params.from = body.global_transform
	params.motion = motion
	return not PhysicsServer3D.body_test_motion(body.get_rid(), params)


func follow(body: CharacterBody3D, points: Array[Vector3]) -> int:
	var reached: int = 0
	for target: Vector3 in points:
		var ok: bool = false
		for _i: int in 360:
			var to: Vector3 = target - body.global_position
			to.y = 0.0
			if to.length() < 0.3:
				ok = true
				break
			var v: Vector3 = to.normalized() * minf(SPEED, to.length() * 30.0)
			body.velocity.x = v.x
			body.velocity.z = v.z
			body.velocity.y = 0.0 if body.is_on_floor() else body.velocity.y - 9.8 / 60.0
			body.move_and_slide()
			var real: Vector3 = body.get_real_velocity()
			if to.length() > 0.8 and v.length() > SPEED * 0.9 and Vector2(real.x, real.z).length() < SPEED * 0.5:
				snags += 1
			await physics_frame
		if not ok:
			break
		reached += 1
	for _i: int in 30:     # land before the feet are read
		body.velocity = Vector3(0, -3.0, 0)
		body.move_and_slide()
		if body.is_on_floor():
			break
		await physics_frame
	return reached


func make_capsule(parent: Node) -> CharacterBody3D:
	var body := CharacterBody3D.new()
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	shape.shape = capsule
	body.add_child(shape)
	body.collision_mask = 1
	parent.add_child(body)
	return body

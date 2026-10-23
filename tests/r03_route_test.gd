extends SceneTree
## R03 route gate (phase-5-design.md 5.6.2), headless:
##   godot --headless --path . --script res://tests/r03_route_test.gd [-- seeds=N]
## The Lower Stacks, seeds 1-5, every room built at once. The real player's
## capsule (radius 0.35, height 1.8) starts at the hall's spawn and walks a
## tour of every bay free of bookcases (the landmark's bay aside), out
## through every joined door into the gallery beyond, and back. Then, in every
## bay with a bookcase, it slides along the case on both sides
## (body_test_motion, not blocked), and straight across it is blocked. The
## validator is clean on the hall.

const RECIPE: String = "res://gen/recipes/lower_stacks.tres"
const SEEDS: int = 5
const SPEED: float = 8.0

var failures: PackedStringArray = []
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
	print("r03_route_test: %d checks, %d failures" % [checks, failures.size()])
	for f: String in failures.slice(0, 30):
		print("  FAIL ", f)
	quit(1 if not failures.is_empty() else 0)


func walk_seed(s: int) -> void:
	var tag: String = "lower stacks %d" % s
	Area.seed_override = s
	var area := Area.new()
	area.recipe = load(RECIPE)
	area.streaming = false
	root.add_child(area)
	for _i: int in 4:
		await physics_frame
	var hall: GeneratedRoom = area.rooms["hall"]
	var g: CellGrid = hall.grid
	var v: Dictionary = KitValidateRoom.run(hall)
	check((v["errors"] as PackedStringArray).is_empty() and (v["warnings"] as PackedStringArray).is_empty(), "%s: the hall validates clean (%s)" % [tag, v])
	var cases: Dictionary = {}        # cell -> long axis (room space, unit)
	for k: String in g.props:
		if g.props[k]["slot"] == "dressing:case":
			var xf: Transform3D = g.props[k]["xf"]
			var at: Vector3i = AreaPlan.cell_of(xf * Vector3(2.0, 0.1, -2.0))
			cases[Vector3i(at.x, 0, at.z)] = xf.basis.x.abs().round()
	var centre: Vector3i = Vector3i.MAX
	for c: Vector3i in g.cells:
		if g.cells[c].get("ceiling_slot", "") == "cell:oculus":
			centre = c
	var body: CharacterBody3D = make_capsule(area)
	body.global_position = area.spawn_transform().origin + Vector3(0, 0.95, 0)
	for _i: int in 3:
		await physics_frame
	# A tour of the clear bays: depth first from the entry, back out of each branch.
	var tour: Array[Vector3] = []
	var seen: Dictionary = {}
	_tour(g, Vector3i.ZERO, cases, centre, seen, tour, hall)
	var reached: int = await follow(body, tour)
	var clear_bays: int = g.cells.size() - cases.size() - 1
	check(reached == tour.size(), "%s: the capsule walks the tour of the clear bays (%d of %d points)" % [tag, reached, tour.size()])
	check(seen.size() >= clear_bays * 0.9, "%s: the tour covers the clear bays (%d of %d; the rest sit between bookcases)" % [tag, seen.size(), clear_bays])
	# Out through every joined door and back.
	var doors: int = 0
	for name: StringName in area.plan.room("hall").connectors:
		var conn: Dictionary = area.plan.room("hall").connectors[name]
		if str(conn["joined"]) == "":
			continue
		var door_xf: Transform3D = conn["xf"]
		var inside: Vector3 = door_xf.origin + door_xf.basis.z * 2.0     # connectors point -Z out of the room
		var outside: Vector3 = door_xf.origin - door_xf.basis.z * 2.5
		var path: Array[Vector3] = _path_to(g, AreaPlan.cell_of(hall.to_local(body.global_position)), AreaPlan.cell_of(hall.to_local(inside)), cases, centre, hall)
		path.append_array([inside, outside, inside])
		var got: int = await follow(body, path)
		check(got == path.size(), "%s: out through %s into %s and back (%d of %d)" % [tag, name, conn["joined"], got, path.size()])
		doors += 1
	check(doors >= 1, "%s: at least one door leads on (%d)" % [tag, doors])
	# Bookcases: passable along both sides, blocked straight across.
	var lanes_bad: PackedStringArray = []
	var crossings_open: PackedStringArray = []
	for c: Vector3i in cases:
		var along: Vector3 = cases[c]
		var across := Vector3(along.z, 0.0, along.x)
		var mid: Vector3 = hall.to_global(CellGrid.cell_centre(c)) + Vector3(0, 1.0, 0)
		for side: float in [-1.0, 1.0]:
			if await blocked(body, mid - along * 2.0 + across * side * 1.0, along * 4.0):
				lanes_bad.append("%s side %d" % [c, int(side)])
		if not await blocked(body, mid - across * 1.6, across * 3.2):
			crossings_open.append(str(c))
	check(lanes_bad.is_empty(), "%s: every bookcase can be passed along both sides (%s)" % [tag, lanes_bad.slice(0, 6)])
	check(crossings_open.is_empty(), "%s: no bookcase can be walked through (%s)" % [tag, crossings_open.slice(0, 6)])
	print("  %s: hall %d bays, %d cases, tour %d points, %d doors" % [tag, g.cells.size(), cases.size(), tour.size(), doors])
	area.queue_free()
	await process_frame
	await process_frame


## Depth-first tour points (hall bay centres, room space -> global) through
## bays without a case; returns to each bay after visiting its children.
func _tour(g: CellGrid, c: Vector3i, cases: Dictionary, centre: Vector3i, seen: Dictionary, out: Array[Vector3], hall: Node3D) -> void:
	seen[c] = true
	out.append(hall.to_global(CellGrid.cell_centre(c)))
	for side: int in CellGrid.ALL_SIDES:
		var n: Vector3i = CellGrid.neighbour(c, side)
		if g.cells.has(n) and not seen.has(n) and not cases.has(n) and n != centre:
			_tour(g, n, cases, centre, seen, out, hall)
			out.append(hall.to_global(CellGrid.cell_centre(c)))


## Bay centres from bay a to bay b through clear bays (breadth first).
func _path_to(g: CellGrid, a: Vector3i, b: Vector3i, cases: Dictionary, centre: Vector3i, hall: Node3D) -> Array[Vector3]:
	a = Vector3i(a.x, 0, a.z)
	b = Vector3i(b.x, 0, b.z)
	var parent: Dictionary = {a: a}
	var order: Array[Vector3i] = [a]
	var head: int = 0
	while head < order.size():
		var c: Vector3i = order[head]
		head += 1
		for side: int in CellGrid.ALL_SIDES:
			var n: Vector3i = CellGrid.neighbour(c, side)
			if g.cells.has(n) and not parent.has(n) and not cases.has(n) and n != centre:
				parent[n] = c
				order.append(n)
	var out: Array[Vector3] = []
	if not parent.has(b):
		return out
	var c: Vector3i = b
	while c != a:
		out.push_front(hall.to_global(CellGrid.cell_centre(c)))
		c = parent[c]
	return out


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
			await physics_frame
		if not ok:
			break
		reached += 1
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


func blocked(body: CharacterBody3D, at: Vector3, motion: Vector3) -> bool:
	body.global_position = at
	await physics_frame
	var params := PhysicsTestMotionParameters3D.new()
	params.from = body.global_transform
	params.motion = motion
	return PhysicsServer3D.body_test_motion(body.get_rid(), params)

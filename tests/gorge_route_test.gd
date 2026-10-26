extends SceneTree
## The Overlook's route gate (phase-6-design.md 5.7.2, phase 6 step 2), headless:
##   godot --headless --path . --script res://tests/gorge_route_test.gd
## The Gorge area, every room built at once, the baked gorge round it. The
## Overlook validates without errors. The real player's capsule (radius 0.35,
## height 1.8), from the spawn on the balcony: through the gap in the
## parapet, down the rock-cut stair, over the landing, down the flight and
## along the ledge round the colossus's pier to its end, nothing catching it,
## its feet on the ledge (12 m below the landing's... -12) at the end. And
## nowhere can it step off: the balcony's parapet, both sides of the stair,
## the landing's balustrades, the flight's cheeks, every open side of the
## ledge and its end hold (phase 6 Q4).

const RECIPE: String = "res://gen/recipes/gorge.tres"
const FOREGROUND = preload("res://scripts/vista_foreground.gd")
const EYE: Vector3 = Vector3(-1, 2.25, -27.45)
const LANDING_HALF: float = 6.0
const SPEED: float = 6.0
const ON_BAYS: int = 3
const WEST_BAYS: int = 4

var failures: PackedStringArray = []
var checks: int = 0
var snags: int = 0


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures.append(what)


func run() -> void:
	var area := Area.new()
	area.recipe = load(RECIPE)
	area.streaming = false
	root.add_child(area)
	for _i: int in 4:
		await physics_frame
	var room: RoomTemplate = area.rooms.get("overlook")
	check(room != null, "the Overlook is built")
	var v: Dictionary = KitValidateRoom.run(room)
	check((v["errors"] as PackedStringArray).is_empty(), "the Overlook validates without errors (%s)" % [v["errors"]])
	check(room.get_node_or_null("Connectors/SNAP_exit_ledge") != null, "the ledge ends at a connector for step 3's span")
	# The route, in the same frames as tools/bake_overlook.gd.
	var top: Vector3 = FOREGROUND.STAIR_TOP
	var landing: Vector3 = FOREGROUND.STAIR_LANDING
	var flat: Vector3 = Vector3(landing.x - top.x, 0, landing.z - top.z).normalized()
	var across := Vector3(flat.z, 0, -flat.x)
	var land := Transform3D(Basis(Vector3.UP, atan2(flat.x, flat.z)), landing)
	var far_mid: Vector3 = land * Vector3(0, 0, LANDING_HALF)
	var g_basis := Basis(Vector3.UP.cross(-flat).normalized(), Vector3.UP, -flat)
	var g := Transform3D(g_basis, far_mid - g_basis.x * 2.0)
	var cell := func(i: int, j: int) -> Vector3: return g * Vector3(i * 4.0 + 2.0, -4.0, -j * 4.0 - 2.0)
	# Along the balcony to behind its opening, then onto the stair's head.
	var head_mid: Vector3 = Vector3(top.x, FOREGROUND.STAIR_FLOOR, top.z) - flat * FOREGROUND.STAIR_HEAD * .5
	var route: Array[Vector3] = [EYE, Vector3(head_mid.x, 2.2, -27.4), head_mid]
	for d: float in [2.0, 10.0, 20.0, 28.0]:
		route.append(top + flat * d)
	route.append(landing)
	route.append(land * Vector3(0, 0, LANDING_HALF - 1.0))
	route.append(far_mid + flat * 4.0)
	var ledge: Array[Vector3] = []
	for j: int in range(2, 2 + ON_BAYS):
		ledge.append(cell.call(0, j))
	for i: int in range(1, WEST_BAYS + 1):
		ledge.append(cell.call(-i, 1 + ON_BAYS))
	route.append_array(ledge)
	var body: CharacterBody3D = make_capsule(area)
	body.global_position = EYE + Vector3(0, 0.95, 0)
	await physics_frame
	var got: int = await follow(body, route)
	var feet: float = body.global_position.y - 0.9
	check(got == route.size() and absf(feet - (landing.y - 4.0)) < 0.2,
		"from the balcony down the stair, over the landing, down the flight and along the ledge to its end (%d of %d points, feet %.2f)" % [got, route.size(), feet])
	check(snags == 0, "nothing on the way catches the capsule (%d frames held back)" % snags)
	# The player is put back at the spawn below the recipe's fall limit (the
	# camp's -8 m would have sent you back from the landing).
	check(area.recipe.fall_limit < feet - 2.0 and area.recipe.fall_limit > -60.0,
		"the walk's lowest point (%.1f) is well above the fall limit (%.1f), which is above the safety floor" % [feet, area.recipe.fall_limit])
	# Nowhere to step off.
	var off: Dictionary = {
		"the balcony's parapet": [Vector3(0, 2.2, -27.4), Vector3(0, 0, -3)],
		"the stair's left side": [top + flat * 15.0 - Vector3(0, 5.0, 0), across * 4.0],
		"the stair's right side": [top + flat * 15.0 - Vector3(0, 5.0, 0), -across * 4.0],
		"the landing's left side": [land * Vector3(4.5, 0, 2), land.basis.x * 3.0],
		"the landing's right side": [land * Vector3(-4.5, 0, 2), -land.basis.x * 3.0],
		"the landing's far corner": [land * Vector3(-4.5, 0, 4.5), land.basis.z * 3.0],
		"the flight's cheek": [far_mid + flat * 4.0 + Vector3(0, -2.0, 0), g_basis.x * 3.0],
		"the ledge's end": [ledge[-1], -g_basis.x * 3.0],
	}
	off["the stair head's west side"] = [head_mid, across * 3.0]
	off["the stair head's east side"] = [head_mid, -across * 3.0]
	# Every open side of every ledge bay (not toward the next bay, nor up the
	# flight from the first).
	var cells: Array[Vector2i] = []
	for j: int in range(2, 2 + ON_BAYS):
		cells.append(Vector2i(0, j))
	for i: int in range(1, WEST_BAYS + 1):
		cells.append(Vector2i(-i, 1 + ON_BAYS))
	var sides: Dictionary = {Vector2i(1, 0): g_basis.x, Vector2i(-1, 0): -g_basis.x, Vector2i(0, 1): -g_basis.z, Vector2i(0, -1): g_basis.z}
	for k: int in cells.size():
		for step: Vector2i in sides:
			if cells.has(cells[k] + step) or (cells[k] == Vector2i(0, 2) and step == Vector2i(0, -1)):
				continue
			off["ledge bay %s toward %s" % [cells[k], step]] = [ledge[k], (sides[step] as Vector3) * 3.0]
	var open: PackedStringArray = []
	for what: String in off:
		var from: Vector3 = (off[what][0] as Vector3) + Vector3(0, 0.95 + 0.05, 0)
		if await free_way(body, from, off[what][1]):
			open.append(what)
	check(open.is_empty(), "nowhere to step off (%s)" % [open])
	# The control: along the ledge the same probe must find the way open.
	var along: bool = await free_way(body, ledge[ON_BAYS] + Vector3(0, 1.0, 0), ledge[ON_BAYS + 1] - ledge[ON_BAYS])
	check(along, "the probe finds the way along the ledge open (so the closed ways above are real)")
	print("gorge_route_test: %d checks, %d failures" % [checks, failures.size()])
	for f: String in failures:
		print("  FAIL ", f)
	quit(1 if not failures.is_empty() else 0)


func follow(body: CharacterBody3D, points: Array[Vector3]) -> int:
	var reached: int = 0
	for target: Vector3 in points:
		var ok: bool = false
		for _i: int in 600:
			var to: Vector3 = target - body.global_position
			to.y = 0.0
			if to.length() < 0.3:
				ok = true
				break
			var v: Vector3 = to.normalized() * minf(SPEED, to.length() * 30.0)
			body.velocity.x = v.x
			body.velocity.z = v.z
			body.velocity.y = 0.0 if body.is_on_floor() else body.velocity.y - 9.8 / 60.0
			var before: Vector3 = body.global_position
			body.move_and_slide()
			if Vector2(body.global_position.x - before.x, body.global_position.z - before.z).length() < v.length() / 60.0 * 0.5:
				snags += 1
			await physics_frame
		if not ok:
			break
		reached += 1
	return reached


func free_way(body: CharacterBody3D, from: Vector3, motion: Vector3) -> bool:
	body.global_position = from
	await physics_frame
	var params := PhysicsTestMotionParameters3D.new()
	params.from = body.global_transform
	params.motion = motion
	return not PhysicsServer3D.body_test_motion(body.get_rid(), params)


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

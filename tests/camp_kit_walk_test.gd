extends SceneTree
## The camp baked from kit pieces (rooms/camp/camp.tscn, phase 7 step 2) can be
## walked: the real player's capsule (radius 0.35, height 1.8) follows the
## camp's routes from the spawn, round the hearth, through the garden arch,
## up the stair to the gallery and along the passage, and into the archive,
## standing on the pieces' collision all the way (never below the floor).
##   godot --headless --path . --script res://tests/camp_kit_walk_test.gd

const SCENE: String = "res://rooms/camp/camp.tscn"
const SPEED: float = 3.3
## [name, points (feet)].
const ROUTES: Array = [
	["spawn round the hearth, through the garden arch", [Vector3(-1.05, .1, 9.2), Vector3(1.0, .1, 6.5), Vector3(1.0, .1, 2.5), Vector3(-3.0, .1, 1.0), Vector3(-3.0, .1, -2.5)]],
	["hall to the stair, up to the gallery", [Vector3(1.0, .1, 2.5), Vector3(1.8, .1, -1.5), Vector3(2.5, .1, -2.8), Vector3(2.5, 2.3, -9.6), Vector3(0.5, 2.3, -11.0), Vector3(-1.0, 2.3, -11.1)]],
	["gallery to its doorway", [Vector3(-1.0, 2.3, -11.1), Vector3(-1.0, 2.3, -12.8)]],
	["gallery to its west wall (floored to the wall)", [Vector3(-1.0, 2.3, -11.1), Vector3(-8.6, 2.3, -11.0)]],
	["hall into the archive", [Vector3(6.5, .1, 3.0), Vector3(8.4, .1, 0.8), Vector3(8.4, .1, -4.0)]],
]

var failures: PackedStringArray = []
var checks: int = 0


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures.append(what)


func run() -> void:
	var camp: Node3D = (load(SCENE) as PackedScene).instantiate()
	root.add_child(camp)
	var body := CharacterBody3D.new()
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = .35
	capsule.height = 1.8
	shape.shape = capsule
	body.add_child(shape)
	body.collision_mask = 1
	camp.add_child(body)
	for _i: int in 3:
		await physics_frame
	for r: Array in ROUTES:
		var pts: Array = r[1]
		body.global_position = (pts[0] as Vector3) + Vector3(0, .95, 0)
		body.velocity = Vector3.ZERO
		var lowest: float = INF
		var reached: int = 0
		for p: Vector3 in pts.slice(1):
			var ok: bool = false
			for _f: int in 900:
				var to: Vector3 = p - body.global_position
				to.y = 0.0
				if to.length() < .3:
					ok = true
					break
				var v: Vector3 = to.normalized() * SPEED
				body.velocity = Vector3(v.x, 0.0 if body.is_on_floor() else body.velocity.y - 9.8 / 60.0, v.z)
				body.move_and_slide()
				lowest = minf(lowest, body.global_position.y - .95)
				await physics_frame
			if not ok:
				break
			reached += 1
		var feet: float = body.global_position.y - .95
		check(reached == pts.size() - 1, "%s: reached %d of %d points (stopped at %s)" % [r[0], reached, pts.size() - 1, body.global_position.snapped(Vector3.ONE * .01)])
		check(lowest > -.5, "%s: never below the floor (lowest feet %.2f)" % [r[0], lowest])
		check(absf(feet - (pts[-1] as Vector3).y) < .5 or reached < pts.size() - 1, "%s: ends at the right height (feet %.2f)" % [r[0], feet])
	# The gallery's doorway is the door to the Gorge (step 4): with no game
	# here to travel, the wall behind its trigger holds you.
	body.global_position = Vector3(-1.0, 2.3 + .95, -12.6)
	for _f: int in 120:
		body.velocity = Vector3(0, 0.0 if body.is_on_floor() else body.velocity.y - 9.8 / 60.0, -SPEED)
		body.move_and_slide()
		await physics_frame
	check(body.global_position.z > -14.0 and body.global_position.z < -12.5 and body.global_position.y > 2.5, "the gallery's doorway: its door's wall holds you in it (at %s)" % body.global_position.snapped(Vector3.ONE * .01))
	# The gallery's west end: its balustrade runs to the wall (report 2026-10-26_18-33-50).
	body.global_position = Vector3(-8.4, 2.3 + .95, -10.4)
	for _f: int in 120:
		body.velocity = Vector3(0, 0.0 if body.is_on_floor() else body.velocity.y - 9.8 / 60.0, SPEED)
		body.move_and_slide()
		await physics_frame
	check(body.global_position.y > 2.5, "the gallery's west end holds you on it (at %s)" % body.global_position.snapped(Vector3.ONE * .01))
	print("camp_kit_walk_test: %d checks, %d failures" % [checks, failures.size()])
	for f: String in failures:
		print("  FAIL ", f)
	quit(1 if not failures.is_empty() else 0)

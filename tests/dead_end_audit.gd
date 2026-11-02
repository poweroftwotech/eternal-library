extends SceneTree
## Dead ends (sealed doors, 2026-11-02), headless: every place an area's
## doorway leads nowhere, and whether the real player's capsule walking into
## it from 2 m out is stopped in the doorway or falls out of the world.
##   godot --headless --path . --script res://tests/dead_end_audit.gd -- --save=user://test/dead_end.json [--seeds=3] [area ids…]
## A dead end is an exit stub the room grammars leave where nothing joined
## (gen/modules/exit_glow.tscn, or a SealedDoor once they're sealed) or a
## connector the plan capped "open" (leads nowhere).

const SPEED: float = 3.0

var failures: PackedStringArray = []
var checks: int = 0


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures.append(what)


func run() -> void:
	var seeds: int = 3
	var ids: Array = []
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--seeds="):
			seeds = a.trim_prefix("--seeds=").to_int()
		elif not a.begins_with("--"):
			ids.append(a)
	if ids.is_empty():
		ids = StratumPlan.current().recipes().keys().filter(func(i: String) -> bool: return i != "gorge")
	var counts: Dictionary = {}
	for id: String in ids:
		for s: int in range(1, seeds + 1):
			var area := Area.new()
			area.recipe = load(StratumPlan.current().recipes()[id])
			area.streaming = false
			area.seed_override = s
			root.add_child(area)
			for _i: int in 3:
				await physics_frame
			var tag: String = "%s seed %d" % [id, s]
			var body: CharacterBody3D = _capsule(area)
			for _f: int in 2:
				await physics_frame
			var ends: Array = _dead_ends(area)
			counts[id] = int(counts.get(id, 0)) + ends.size()
			for e: Array in ends:
				_walk_in(body, e[0], "%s: %s" % [tag, e[1]])
			area.queue_free()
			await process_frame
	print("dead_end_audit: %d checks, %d failures; dead ends per area (all seeds) %s" % [checks, failures.size(), counts])
	for f: String in failures:
		print("  FAIL ", f)
	quit(1 if not failures.is_empty() else 0)


## [door frame (-Z out of the room, origin on the wall line at the floor), name]
## for each dead end in the area as built.
func _dead_ends(area: Area) -> Array:
	var out: Array = []
	for n: Node in area.find_children("*", "Node3D", true, false):
		var stub: bool = _is_sealed(n) or (n.get_scene_file_path().ends_with("/exit_glow.tscn") and not n.get_children().any(_is_sealed))
		if stub:
			out.append([(n as Node3D).global_transform, "stub %s" % area.get_path_to(n)])
	for r: AreaPlan.Room in area.plan.rooms:
		for name: StringName in r.connectors:
			var k: Dictionary = r.connectors[name]
			if str(k["joined"]) == "" and str(k["cap"]) == "open":
				out.append([area.global_transform * (k["xf"] as Transform3D), "open %s/%s" % [r.slot_id, name]])
	return out


## Walks from 2 m inside the doorway straight out through it for 3 s: the
## capsule must stay on the floor (not fall) and stop within 1.6 m past the
## wall line.
func _walk_in(body: CharacterBody3D, at: Transform3D, tag: String) -> void:
	body.velocity = Vector3.ZERO
	body.global_position = at * Vector3(0, .1, 2.0) + at.basis.y * .95
	var fwd: Vector3 = -at.basis.z
	for _i: int in 180:
		body.velocity = Vector3(fwd.x, 0, fwd.z) * SPEED + Vector3(0, 0.0 if body.is_on_floor() else body.velocity.y - 9.8 / 60.0, 0)
		body.move_and_slide()
	var local: Vector3 = at.affine_inverse() * body.global_position
	check(local.y > .5 and local.z > -1.6, "%s: walking out through it stops in the doorway (stopped %.2f m past the wall, %.2f up)" % [tag, -local.z, local.y - .95])


func _capsule(parent: Node) -> CharacterBody3D:
	var b := CharacterBody3D.new()
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	shape.shape = capsule
	b.add_child(shape)
	b.collision_mask = 1
	parent.add_child(b)
	return b


func _is_sealed(n: Node) -> bool:
	return n != null and n.get_script() != null and (n.get_script() as Script).get_global_name() == "SealedDoor"

extends SceneTree
## R10 Chasm Spans (phase-6-design.md 5.7.4, phase 6 step 3), headless:
##   godot --headless --path . --script res://tests/r10_span_test.gd [-- --seeds=20]
## The Gorge area plans clean with its main span off the Overlook's corner. Then
## for each of N seeds of each kind (a level bridge, a chain stepping down),
## the span solved from the Overlook's connector, built where the area's
## stands, and checked:
##   - it solves, of its kind (a chain's head one or more storeys lower);
##   - it joins both ends: it starts on the Overlook's connector, and the far
##     bank is right behind its head (its cliff or a terrace within two bays);
##   - nothing of it (walk, arcades, piers) is inside the gorge's tiers;
##   - nothing climbs steeper than the kit's stair (4 m in 8 m);
##   - every bay is carried, by an arcade standing on a pier or a pier of its
##     own (walked: a chain's flights by the far bank stood on nothing);
##   - the real player's capsule (radius 0.35, height 1.8) walks from the
##     Overlook's corner bay over it to the head and along the head to both
##     ends, nothing catching it, its feet on the head at the end;
##   - and nowhere can it step off: both sides of every bay and flight, the
##     head's front and back, and its ends (phase 6 Q4).

const RECIPE: String = "res://gen/recipes/gorge.tres"
const SPEED: float = 6.0
const STAIR_SLOPE: float = .5

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
	var seeds: int = 20
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--seeds="):
			seeds = a.trim_prefix("--seeds=").to_int()
	var area := Area.new()
	area.recipe = load(RECIPE)
	area.streaming = false
	root.add_child(area)
	for _i: int in 4:
		await physics_frame
	check(area.plan.check().is_empty(), "the Gorge plans clean (%s)" % [area.plan.check()])
	var planned: AreaPlan.Room = area.plan.room("span")
	# Since step 4 the area's main span is the near network's first link (a
	# ChasmLink to a ledge on bank 2, tests/gorge_network_test.gd); the
	# grammar's own spans below still grow from the same corner.
	check(planned != null and planned.kind == "link" and planned.parent == "overlook" and planned.parent_connector == &"SNAP_exit_span",
		"the span joins the Overlook's corner (SNAP_exit_span)")
	check(area.rooms.has("span"), "the area builds its span")
	var overlook: RoomTemplate = area.rooms["overlook"]
	var start: Transform3D = overlook.global_transform * (overlook.get_node("Connectors/SNAP_exit_span") as Node3D).transform
	check(planned != null and (planned.connectors[planned.entry]["xf"] as Transform3D).origin.distance_to(start.origin) < .01,
		"the span starts on the Overlook's connector")
	var grammar: ChasmGrammar = load("res://gen/grammars/r10_chasm.tres")
	var tiers: Array[Dictionary] = GorgeGrammar.new().keep_out(grammar.gorge_layout)
	var body: CharacterBody3D = make_capsule(area)
	var current: Node = area.rooms["span"]
	var kinds: Dictionary = {}
	for kind: String in ["bridge", "chain"]:
		for i: int in seeds:
			var seed_value: int = i * 7919 + 13
			var sp: Dictionary = grammar.solve(start, seed_value, kind)
			var tag: String = "%s seed %d" % [kind, seed_value]
			check(sp["ok"], "%s solves (%s)" % [tag, sp["why"]])
			if not sp["ok"]:
				continue
			kinds["%s/%d" % [kind, sp["drop"]]] = true
			check((sp["kind"] == "bridge") == (kind == "bridge") and (int(sp["drop"]) == 0) == (kind == "bridge"),
				"%s is a %s (%s, %d storeys down)" % [tag, kind, sp["kind"], sp["drop"]])
			layout_checks(sp, start, tiers, grammar, tag)
			current.queue_free()
			current = ChasmGrammar.build_room(sp)
			current.transform = start
			area.add_child(current)
			for _f: int in 2:
				await physics_frame
			walk_checks(sp, start, body, tag)
	check(kinds.size() >= 3, "the seeds give bridges and chains of more than one drop (%s)" % [kinds.keys()])
	print("r10_span_test: %d checks, %d failures (%d seeds a kind)" % [checks, failures.size(), seeds])
	for f: String in failures:
		print("  FAIL ", f)
	quit(1 if not failures.is_empty() else 0)


func layout_checks(sp: Dictionary, start: Transform3D, tiers: Array[Dictionary], grammar: ChasmGrammar, tag: String) -> void:
	var n: int = sp["bays"]
	var low: float = -int(sp["drop"]) * 4.0
	# The far bank is behind the head: its cliff or a terrace's deck edge
	# within two bays of one of its back connectors, from two storeys under
	# the walk to over your head.
	var reached: bool = false
	for name: StringName in sp["connectors"]:
		if not String(name).begins_with("SNAP_exit_far"):
			continue
		var c: Transform3D = sp["connectors"][name]
		for d: float in range(1, 9):
			for y: float in [-8.0, -6.0, -4.0, -2.0, .5, 2.0, 3.0]:
				if GorgeGrammar.solid_at(tiers, start * (c.origin - c.basis.z * d + Vector3(0, y, 0))):
					reached = true
	check(reached, "%s: the far bank stands behind its head" % tag)
	check((sp["connectors"][&"SNAP_entry"] as Transform3D).origin.is_zero_approx(), "%s starts on the Overlook's connector" % tag)
	# Nothing inside the tiers: the walk (and headroom), the arcades, the piers.
	var inside: PackedStringArray = []
	for w: Vector3 in sp["walk"]:
		for y: float in [-.5, 1.0, 3.0]:
			if GorgeGrammar.solid_at(tiers, start * (w + Vector3(0, y, 0))):
				inside.append("walk %s" % w)
	for b: AABB in sp["boxes"]:
		for k: int in 8:
			if GorgeGrammar.solid_at(tiers, start * b.grow(-.1).get_endpoint(k)):
				inside.append("arcade %s" % b)
	# A pier's shaft (above a terrace's deck edge, where it may stand) clear;
	# standing on a terrace, it stands well in from its edge.
	for p: Dictionary in sp["piers"]:
		var at: Vector3 = p["at"]
		var size: Vector3 = p["size"]
		var foot: float = at.y - size.y * .5
		for y: float in [foot + GorgeGrammar.DECK_EDGE_H + .1, at.y, foot + size.y - .1]:
			for corner: Vector2 in [Vector2(-.5, -.5), Vector2(.5, .5), Vector2(-.5, .5), Vector2(.5, -.5)]:
				if GorgeGrammar.solid_at(tiers, start * Vector3(at.x + corner.x * size.x, y, at.z + corner.y * size.z)):
					inside.append("pier %s" % at)
		if (start * Vector3(0, foot, 0)).y > grammar.pier_foot + .1:
			for corner: Vector2 in [Vector2(-1, -1), Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1)]:
				var c: Vector3 = Vector3(at.x + corner.x * (size.x * .5 + ChasmGrammar.EDGE_INSET), foot - .5, at.z + corner.y * (size.z * .5 + ChasmGrammar.EDGE_INSET))
				if not GorgeGrammar.solid_at(tiers, start * c):
					inside.append("pier %s on a terrace's edge" % at)
	check(inside.is_empty(), "%s keeps out of the gorge's tiers (%s)" % [tag, inside])
	# Every bay is carried: over an arcade (one that stands on a pier), or
	# within a bay of a pier of its own.
	var loose: PackedStringArray = []
	for w: Vector3 in sp["walk"]:
		var held: bool = false
		for b: AABB in sp["boxes"]:
			if w.x >= b.position.x - .1 and w.x <= b.end.x + .1 and w.z >= b.position.z - .1 and w.z <= b.end.z + .1 and b.end.y < w.y:
				held = true
		for p: Dictionary in sp["piers"]:
			if Vector2((p["at"] as Vector3).x - w.x, (p["at"] as Vector3).z - w.z).length() < 2.5:
				held = true
		if not held:
			loose.append("%s" % w)
	check(loose.is_empty(), "%s: every bay is carried by an arcade or a pier (%s)" % [tag, loose])
	# No climb steeper than the kit's stair along the run.
	var run: Array = (sp["walk"] as Array).filter(func(w: Vector3) -> bool: return absf(w.x) < .1 and w.z > -n * 4.0)
	run.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.z > b.z)
	var steepest: float = 0.0
	for k: int in range(1, run.size()):
		steepest = maxf(steepest, absf((run[k] as Vector3).y - (run[k - 1] as Vector3).y) / absf((run[k] as Vector3).z - (run[k - 1] as Vector3).z))
	check(steepest <= STAIR_SLOPE + .01, "%s climbs no steeper than the kit's stair (%.2f)" % [tag, steepest])
	check(is_equal_approx((run[-1] as Vector3).y, low) if not run.is_empty() else false, "%s's run ends at its head's height" % tag)


func walk_checks(sp: Dictionary, start: Transform3D, body: CharacterBody3D, tag: String) -> void:
	var n: int = sp["bays"]
	var low: float = -int(sp["drop"]) * 4.0
	var head: Vector2i = sp["head"]
	var route: Array[Vector3] = [start * Vector3(0, 0, 2)]      # the Overlook's corner bay
	for k: int in n:
		route.append(start * Vector3(0, 0, -k * 4.0 - 2.0))
	route.append(start * Vector3(0, low, -n * 4.0 - 2.0))
	route.append(start * Vector3(-head.x * 4.0, low, -n * 4.0 - 2.0))
	route.append(start * Vector3(head.y * 4.0, low, -n * 4.0 - 2.0))
	snags = 0
	body.velocity = Vector3.ZERO
	body.global_position = route[0] + Vector3(0, .95, 0)
	var got: int = follow(body, route)
	var feet: float = body.global_position.y - .9
	check(got == route.size() and absf(feet - (start.origin.y + low)) < .2,
		"%s: walked from the Overlook over the span to both ends of its head (%d of %d points, feet %.2f, head %.2f)" % [tag, got, route.size(), feet, start.origin.y + low])
	check(snags == 0, "%s: nothing on the way catches the capsule (%d steps held back)" % [tag, snags])
	# Nowhere to step off.
	var off: Dictionary = {}
	var x_side := start.basis.x
	var z_side := start.basis.z
	for w: Vector3 in sp["walk"]:
		var at: Vector3 = start * w
		if absf(w.z + n * 4.0 + 2.0) < .1:      # the head's row
			var i: int = roundi(w.x / 4.0)
			off["head %d's back" % i] = [at, -z_side * 3.0]
			if i != 0:
				off["head %d's front" % i] = [at, z_side * 3.0]
			if i == -head.x:
				off["head's left end"] = [at, -x_side * 3.0]
			if i == head.y:
				off["head's right end"] = [at, x_side * 3.0]
		else:
			off["bay at %.0f m, left" % -w.z] = [at, -x_side * 3.0]
			off["bay at %.0f m, right" % -w.z] = [at, x_side * 3.0]
	var open: PackedStringArray = []
	for what: String in off:
		if free_way(body, (off[what][0] as Vector3) + Vector3(0, 1.0, 0), off[what][1]):
			open.append(what)
	check(open.is_empty(), "%s: nowhere to step off (%s)" % [tag, open])
	var along: bool = free_way(body, start * Vector3(0, 1.0, -6.0), -z_side * 3.0)
	check(along, "%s: the probe finds the way along the span open (so the closed ways are real)" % tag)


## Steps the capsule through the points (physics stepped by hand: the scene is
## static, so no frame needs to pass between steps).
func follow(b: CharacterBody3D, points: Array[Vector3]) -> int:
	var reached: int = 0
	for target: Vector3 in points:
		var ok: bool = false
		for _i: int in 1200:
			var to: Vector3 = target - b.global_position
			to.y = 0.0
			if to.length() < 0.3:
				ok = true
				break
			var v: Vector3 = to.normalized() * minf(SPEED, to.length() * 30.0)
			b.velocity.x = v.x
			b.velocity.z = v.z
			b.velocity.y = 0.0 if b.is_on_floor() else b.velocity.y - 9.8 / 60.0
			var before: Vector3 = b.global_position
			b.move_and_slide()
			if Vector2(b.global_position.x - before.x, b.global_position.z - before.z).length() < v.length() / 60.0 * 0.5:
				snags += 1
		if not ok:
			break
		reached += 1
	return reached


func free_way(b: CharacterBody3D, from: Vector3, motion: Vector3) -> bool:
	b.global_position = from
	var params := PhysicsTestMotionParameters3D.new()
	params.from = b.global_transform
	params.motion = motion
	return not PhysicsServer3D.body_test_motion(b.get_rid(), params)


func make_capsule(parent: Node) -> CharacterBody3D:
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

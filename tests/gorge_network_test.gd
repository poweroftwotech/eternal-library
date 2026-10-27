extends SceneTree
## The near gorge's network (phase-6-design.md 5.7.5, phase 6 step 4), headless:
##   godot --headless --path . --script res://tests/gorge_network_test.gd [-- --seeds=20 --from=1]
## For each area seed, the Gorge built whole (every room, the baked gorge
## round it), and checked:
##   - it plans clean: a tree from the Overlook, every connector joined or
##     capped, 4-6 ledges, so every ledge is reached from the balcony (one
##     way to each); ledges on both cliffs;
##   - nothing overlaps: no two rooms but those joined share any of their
##     boxes, and no walk (or its headroom) is inside the gorge's tiers;
##   - every bay is carried: a link's by an arcade standing on a pier, a pier
##     or a corbel (a short level run by its ends: a lintel); a ledge's by its pier, or the consoles at both its sides;
##   - the gorge's pieces where the network stands are cleared;
##   - the real player's capsule (radius 0.35, height 1.8) walks every link
##     from the room before it to the one after, and every ledge end to end,
##     nothing catching it;
##   - and nowhere can it step off: the closed fronts, ends and backs of every
##     ledge, both sides of every link's bays, flights and end landings
##     (phase 6 Q4).
##   - (step 5) a ledge on every door's slot, its door bay's threshold live,
##     and the capsule walks from where you arrive there into the doorway
##     (the trigger) and no further.

const RECIPE: String = "res://gen/recipes/gorge.tres"
const FRONTAGE = preload("res://tools/gorge_frontage.gd")
const SPEED: float = 6.0

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
	var from: int = 1
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--seeds="):
			seeds = a.trim_prefix("--seeds=").to_int()
		if a.begins_with("--from="):
			from = a.trim_prefix("--from=").to_int()
	GorgeBackdrop.load_baked()     # the walks clear of the backdrop's masses too
	var recipe: AreaRecipe = load(RECIPE)
	var layout: GorgeLayout = load("res://gen/gorge/gorge_layout.tres")
	var tiers: Array[Dictionary] = GorgeGrammar.new().keep_out(layout)
	var counts: Dictionary = {}
	var plan_ms: Array[float] = []
	for s: int in range(from, from + seeds):
		var area := Area.new()
		area.recipe = recipe
		area.streaming = false
		area.seed_override = s
		root.add_child(area)
		for _i: int in 3:
			await physics_frame
		var tag: String = "seed %d" % s
		var p: AreaPlan = area.plan
		plan_ms.append(p.plan_ms)
		check(p.check().is_empty(), "%s plans clean (%s)" % [tag, p.check()])
		var ledges: Array = p.rooms.filter(func(r: AreaPlan.Room) -> bool: return r.kind == "ledge")
		var links: Array = p.rooms.filter(func(r: AreaPlan.Room) -> bool: return r.kind == "link")
		counts[ledges.size()] = int(counts.get(ledges.size(), 0)) + 1
		check(ledges.size() >= 4 and ledges.size() <= 6, "%s: 4-6 ledges (%d)" % [tag, ledges.size()])
		var cliffs: Dictionary = {}
		for r: AreaPlan.Room in ledges:
			cliffs[(recipe.network.frontage.slot(r.span["slot"]) as FrontageSlot).cliff] = true
		check(cliffs.size() == 2, "%s: ledges on both cliffs (%s)" % [tag, cliffs.keys()])
		check(p.room("span") != null and p.room("span").parent == "overlook", "%s: the main span leaves the Overlook" % tag)
		check(reached(p) == p.rooms.size(), "%s: every room is reached from the Overlook (%d of %d)" % [tag, reached(p), p.rooms.size()])
		check(int(area.timings.get("cleared", 0)) > 0, "%s: the gorge's pieces where the network stands are cleared" % tag)
		layout_checks(p, tiers, tag)
		var body: CharacterBody3D = make_capsule(area)
		for _f: int in 2:
			await physics_frame
		for r: AreaPlan.Room in links:
			walk_link(p, r, body, tag)
		for r: AreaPlan.Room in ledges:
			walk_ledge(r, body, tag)
		for fs: FrontageSlot in recipe.network.frontage.slots:
			if fs.door != "":
				walk_to_door(area, fs.door, body, tag)
		area.queue_free()
		await process_frame
	plan_ms.sort()
	print("gorge_network_test: %d checks, %d failures (%d seeds from %d); ledges per seed %s; plan ms median %.0f, worst %.0f" % [
		checks, failures.size(), seeds, from, counts, plan_ms[plan_ms.size() / 2], plan_ms[-1]])
	for f: String in failures:
		print("  FAIL ", f)
	quit(1 if not failures.is_empty() else 0)


## Whether a gallery's bay (walk centre w, its back on the wall at z 0) is
## clear of the tiers by the frontage's own samples (tools/gorge_frontage.gd:
## its back keeps 0.25 m off the wall, the link's walk test 1.8 m round the
## centre nicked a facade's corner).
func _bay_clear(xf: Transform3D, tiers: Array[Dictionary], w: Vector3) -> bool:
	for x: float in FRONTAGE.CLEAR_X:
		for z: float in FRONTAGE.CLEAR_Z:
			for y: float in FRONTAGE.CLEAR_Y.map(func(v: float) -> float: return minf(v, FRONTAGE.UNDER_DECK_H) if z > FRONTAGE.UNDER_DECK_Z else v):
				if GorgeGrammar.solid_at(tiers, xf * (w + Vector3(x - 2.0, y, z + 2.0))):
					return false
	return true


## Rooms reached from the root through the plan's joins.
func reached(p: AreaPlan) -> int:
	var seen: Dictionary = {p.rooms[0].slot_id: true}
	var todo: Array[String] = [p.rooms[0].slot_id]
	while not todo.is_empty():
		var at: String = todo.pop_back()
		for e: Dictionary in p.edges:
			if e["a"] == at and not seen.has(e["b"]):
				seen[e["b"]] = true
				todo.append(e["b"])
	return seen.size()


func layout_checks(p: AreaPlan, tiers: Array[Dictionary], tag: String) -> void:
	# Every box a box (none turned inside out by a sign slip).
	var bad: PackedStringArray = []
	for r: AreaPlan.Room in p.rooms:
		for x: AABB in r.blockers:
			if x.size.x < 0.0 or x.size.y < 0.0 or x.size.z < 0.0:
				bad.append("%s %s" % [r.slot_id, x])
	check(bad.is_empty(), "%s: every room's boxes have a size (%s)" % [tag, bad])
	# No overlap: rooms not joined to each other share no box.
	var joined: Dictionary = {}
	for e: Dictionary in p.edges:
		joined["%s|%s" % [e["a"], e["b"]]] = true
		joined["%s|%s" % [e["b"], e["a"]]] = true
	var clashes: PackedStringArray = []
	for i: int in p.rooms.size():
		for j: int in range(i + 1, p.rooms.size()):
			var a: AreaPlan.Room = p.rooms[i]
			var b: AreaPlan.Room = p.rooms[j]
			if joined.has("%s|%s" % [a.slot_id, b.slot_id]):
				continue
			for x: AABB in a.blockers:
				for y: AABB in b.blockers:
					if overlap(x.abs(), y.abs(), .05):
						clashes.append("%s/%s" % [a.slot_id, b.slot_id])
	check(clashes.is_empty(), "%s: no two rooms overlap (%s)" % [tag, clashes])
	var inside: PackedStringArray = []
	var loose: PackedStringArray = []
	for r: AreaPlan.Room in p.rooms:
		if r.kind != "link" and r.kind != "ledge":
			continue
		for w: Vector3 in r.span["walk"]:
			if not (ChasmLink._clear(r.xf, tiers, w) if r.kind == "link" else _bay_clear(r.xf, tiers, w)):
				inside.append("%s %s" % [r.slot_id, w])
		if r.kind == "link":
			# The level run's start: its first end, carried by the room there
			# (its walk points sit mid-cell, evenly along it).
			var level_walk: Array = (r.span["walk"] as Array).filter(func(w: Vector3) -> bool: return w.y > -.1)
			var start_z: float = NAN
			if level_walk.size() > 1:
				start_z = (level_walk[0] as Vector3).z + ((level_walk[0] as Vector3).z - (level_walk[1] as Vector3).z) * .5
			for w: Vector3 in r.span["walk"]:
				var held: bool = r.span.get("lintel", false)      # a short level run, carried by its ends
				for zz: Vector2 in r.span.get("spanned", []):
					if w.z >= zz.x - .1 and w.z <= zz.y + .1:
						held = true       # the last flight, from an arcade pier to the end's edge
				for b: AABB in r.span["boxes"]:
					if b.size.y > 6.0 and w.x >= b.position.x - .1 and w.x <= b.end.x + .1 and w.z >= b.position.z - .1 and w.z <= b.end.z + .1 and b.end.y < w.y:
						held = true       # an arcade (the walk boxes are 4.6 m tall)
				# On a flight (between storeys) its one pier holds its whole 8 m mass;
				# a landing between flights is carried by theirs, either side.
				var whole: bool = absf(w.y - roundf(w.y / 4.0) * 4.0) < .1
				var reach: float = 4.2 if not whole else (6.2 if w.y < -.1 else 2.6)
				for q: Dictionary in r.span["piers"]:
					if Vector2((q["at"] as Vector3).x - w.x, (q["at"] as Vector3).z - w.z).length() < reach:
						held = true
					# On the level run between its start and a pier a lintel apart
					# (ChasmLink.LINTEL): carried by both.
					var qz: float = (q["at"] as Vector3).z
					if w.y > -.1 and not is_nan(start_z) and w.z <= start_z and w.z >= qz and start_z - qz <= ChasmLink.LINTEL:
						held = true
				if not held:
					loose.append("%s %s" % [r.slot_id, w])
		else:
			var xs: Array[float] = []
			for bl: Dictionary in r.span.get("blocks", []):
				if absf((bl["at"] as Vector3).y - (-CliffLedgeGrammar.UNDER - CliffLedgeGrammar.CONSOLE[0].y * .5)) < .01:
					xs.append((bl["at"] as Vector3).x)
			for i: int in int(r.span["bays"]):
				var sides: int = 0
				for x: float in xs:
					if x > i * 4.0 - .05 and x < i * 4.0 + .6 or x > (i + 1) * 4.0 - .6 and x < (i + 1) * 4.0 + .05:
						sides += 1
				var on_pier: bool = (r.span["piers"] as Array).any(func(q: Dictionary) -> bool: return absf((q["at"] as Vector3).x - (i * 4.0 + 2.0)) < 1.0)
				if sides < 2 and not on_pier:
					loose.append("%s bay %d" % [r.slot_id, i])
	check(inside.is_empty(), "%s: no walk inside the gorge's tiers (%s)" % [tag, inside])
	check(loose.is_empty(), "%s: every bay is carried (%s)" % [tag, loose])


## From 2 m inside the room before a link, along it, to 2 m inside the one
## after; then no way off either side of it.
func walk_link(p: AreaPlan, r: AreaPlan.Room, body: CharacterBody3D, tag: String) -> void:
	var lk: Dictionary = r.span
	var s: Transform3D = r.xf
	var a: Transform3D = s * (lk["connectors"][&"SNAP_a"] as Transform3D)     # -Z into the room before (out of the link)
	var b: Transform3D = s * (lk["connectors"][&"SNAP_b"] as Transform3D)
	var pts: Array = (lk["walk"] as Array).duplicate()
	pts.append_array(lk.get("landings", []))
	pts.sort_custom(func(x: Vector3, y: Vector3) -> bool: return x.z > y.z)     # along the run (-Z) from the frame's start
	if lk.get("reversed", false):
		pts.reverse()
	var route: Array[Vector3] = [a * Vector3(0, 0, -2.0)]
	for w: Vector3 in pts:
		route.append(s * w)
	route.append(b * Vector3(0, 0, -2.0))
	snags = 0
	body.velocity = Vector3.ZERO
	body.global_position = route[0] + Vector3(0, .95, 0)
	var got: int = follow(body, route)
	var feet: float = body.global_position.y - .9
	check(got == route.size() and absf(feet - b.origin.y) < .25,
		"%s: walked %s (%s) from %s to the room after (%d of %d points, feet %.2f, end %.2f)" % [tag, r.slot_id, r.display_name, r.parent, got, route.size(), feet, b.origin.y])
	check(snags == 0, "%s: nothing on %s catches the capsule (%d steps held back)" % [tag, r.slot_id, snags])
	var open: PackedStringArray = []
	for w: Vector3 in pts:
		for side: float in [-1.0, 1.0]:
			# Onto a ledge's own floor is no way off (a link arriving at a
			# ledge's end runs along it: bank 4, phase 8).
			if on_ledge(p, s * w + s.basis.x.normalized() * side * 3.0):
				continue
			if free_way(body, s * w + Vector3(0, 1.0, 0), s.basis.x * side * 3.0):
				open.append("%s %s (world %s)" % [w, "right" if side > 0 else "left", (s * w).snapped(Vector3.ONE * .1)])
	check(open.is_empty(), "%s: nowhere to step off %s (%s)" % [tag, r.slot_id, open])


## Along a ledge from end to end; no way off its closed front, ends or back.
func walk_ledge(r: AreaPlan.Room, body: CharacterBody3D, tag: String) -> void:
	var lp: Dictionary = r.span
	var n: int = lp["bays"]
	var route: Array[Vector3] = [r.xf * Vector3(1.2, 0, -2), r.xf * Vector3(n * 4.0 - 1.2, 0, -2)]
	snags = 0
	body.velocity = Vector3.ZERO
	body.global_position = route[0] + Vector3(0, .95, 0)
	var got: int = follow(body, route)
	check(got == route.size() and snags == 0, "%s: walked %s end to end (%d of 2 points, %d steps held back)" % [tag, r.slot_id, got, snags])
	var off: Dictionary = {}
	var x: Vector3 = r.xf.basis.x
	var z: Vector3 = r.xf.basis.z
	for i: int in n:
		var c: Vector3 = r.xf * Vector3(i * 4.0 + 2.0, 0, -2)
		if not r.connectors.has(StringName("SNAP_front_%d" % i)):
			off["bay %d's front" % i] = [c, -z * 3.0]
		off["bay %d's back" % i] = [c, z * 3.0]
	if not r.connectors.has(&"SNAP_end_l"):
		off["left end"] = [r.xf * Vector3(2, 0, -2), -x * 3.0]
	if not r.connectors.has(&"SNAP_end_r"):
		off["right end"] = [r.xf * Vector3(n * 4.0 - 2, 0, -2), x * 3.0]
	var open: PackedStringArray = []
	for what: String in off:
		if free_way(body, (off[what][0] as Vector3) + Vector3(0, 1.0, 0), off[what][1]):
			open.append(what)
	check(open.is_empty(), "%s: nowhere to step off %s (%s)" % [tag, r.slot_id, open])


## From where you arrive through the door to `to` (Area.ARRIVE_IN inside it)
## straight at it: into its trigger, and stopped there.
func walk_to_door(area: Area, to: String, body: CharacterBody3D, tag: String) -> void:
	var door: Array = area.plan.threshold(to)
	check(not door.is_empty() and (door[0] as AreaPlan.Room).kind == "ledge", "%s: a ledge has the door to %s" % [tag, to])
	if door.is_empty():
		return
	var r: AreaPlan.Room = door[0]
	var at: Transform3D = r.connectors[door[1]]["xf"]
	var live: Node = area.rooms.get(r.slot_id)
	check(live != null and live.get_node_or_null("Threshold_" + to) is Threshold, "%s: %s has its threshold to %s" % [tag, r.slot_id, to])
	body.velocity = Vector3.ZERO
	body.global_position = at * Vector3(0, .1, Area.ARRIVE_IN) + Vector3(0, .95, 0)
	var fwd: Vector3 = -at.basis.z
	for _i: int in 180:
		body.velocity = Vector3(fwd.x, 0, fwd.z) * SPEED * .5 + Vector3(0, 0.0 if body.is_on_floor() else body.velocity.y - 9.8 / 60.0, 0)
		body.move_and_slide()
	var local: Vector3 = at.affine_inverse() * body.global_position
	check(local.z - .35 < Threshold.TRIGGER.end.z and local.z > 0.0 and absf(local.y - .95) < .3,
		"%s: walked from the arrival into the door to %s and no further (stopped %.2f m out, %.2f up)" % [tag, to, local.z, local.y - .95])


func follow(b: CharacterBody3D, points: Array[Vector3]) -> int:
	var reached_n: int = 0
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
		reached_n += 1
	return reached_n


## Whether p (feet height) is on a ledge's floor: x 0..bays x 4, z -4..0 in its frame.
func on_ledge(p: AreaPlan, at: Vector3) -> bool:
	for r: AreaPlan.Room in p.rooms:
		if r.kind != "ledge":
			continue
		var l: Vector3 = r.xf.affine_inverse() * at
		if l.x > -.1 and l.x < int(r.span["bays"]) * 4.0 + .1 and l.z > -4.1 and l.z < .1 and absf(l.y) < 1.0:
			return true
	return false


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


## Whether two boxes overlap by more than `by` on every axis (thin boxes
## too: AABB.grow would turn them inside out).
static func overlap(a: AABB, b: AABB, by: float) -> bool:
	for k: int in 3:
		if minf(a.end[k], b.end[k]) - maxf(a.position[k], b.position[k]) <= by:
			return false
	return true

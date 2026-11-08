extends SceneTree
## Phase 18 (revised step 2): the Lake Landing's ferry through the fog to the Mahaleh dock and back, in the real game, with physics.
##   godot --headless --path . --script res://tests/r20_ferry_test.gd -- ride --save=user://test/r20.json --fresh
##   godot --headless --path . --script res://tests/r20_ferry_test.gd -- save --save=user://test/r20.json --fresh
##   godot --headless --path . --script res://tests/r20_ferry_test.gd -- load --save=user://test/r20.json
## ride: walk from the passage down the pier onto the ferry, ask the ferryman
##       for each stop in turn and ride standing; the player must stay on the
##       deck the whole way and step off at each stop. Then ring the quay's
##       bell from the Mahaleh (the ferry comes empty), and wade off
##       the shelf into deep water: back on a safe point, never falling.
## save: board at the quay, ask for the Mahaleh, quit through the game's own
##       save-and-quit halfway across.
## load: a new process resumes on the quay's stage (Q9) with the ferry at the quay.

const SCENE: String = "res://rooms/lake/landing.tscn"

var main_script: GDScript = load("res://scripts/main.gd")
var failures: PackedStringArray = []
var checks: int = 0
var game: Node
var ferry: LakeFerry
var ws: Node
var rock_hits: PackedStringArray = []
var nearest_boat: float = 999.0


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures.append(what)
		print("  FAIL ", what)


func run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var mode: String = args[0] if args.size() > 0 else "ride"
	ws = root.get_node_or_null("WorldState")
	if mode != "load":
		main_script.room_override = SCENE
	game = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	current_scene = game
	for _i: int in 12:
		await physics_frame
	game.hud.toast_time = 0
	ferry = game.world.get_node_or_null("Ferry") as LakeFerry
	check(ferry != null, "the place is the Lake Landing with its ferry (%s)" % game.world)
	if ferry == null:
		finish(mode)
		return
	game.player.blocked = false
	match mode:
		"ride":
			await ride_mode()
		"save":
			await save_mode()
		_:
			await load_mode()
	finish(mode)


# ------------------------------------------------------------------ ride

func ride_mode() -> void:
	# The passage, the quay and the pier on foot (the real capsule, real collision).
	var route: Array[Vector3] = [Vector3(0, 0, -6), Vector3(0, 0, -9.5), Vector3(5.5, 0, -12.5), Vector3(8, 0, -17),
		Vector3(8, 0, -35.2), Vector3(8, -0.9, -40.2)]
	var ok: bool = await walk(route, "quay to the pier head")
	# The boardwalk behind the boathouses and back.
	ok = await walk([Vector3(8, -0.9, -39.0), Vector3(8, 0, -35.2), Vector3(8, 0, -17), Vector3(5.5, 0, -12.5), Vector3(0, 0, -9.5),
		Vector3(-5, 0, -8.6), Vector3(-17, 0, -8.6)], "up the pier and along the boardwalk") and ok
	ok = await walk([Vector3(-5, 0, -8.6), Vector3(5.5, 0, -12.5), Vector3(8, 0, -17), Vector3(8, 0, -35.2),
		Vector3(8, -0.9, -40.2)], "back to the pier head") and ok
	# Every trip, standing in the middle of the deck.
	var order: Array[String] = ["mahaleh", "quay"]     # revised phase step 2: one dock, through the fog
	for stop: String in order:
		await board()
		check(ferry.aboard(), "aboard at %s before asking for %s" % [ferry.at, stop])
		var from: String = ferry.at
		ferry.ask(stop)
		var r: Dictionary = await ride_until_docked(90.0)
		check(ferry.at == stop, "%s -> %s: the ferry arrived (at %s, phase %d)" % [from, stop, ferry.at, ferry.phase])
		check(int(r["off_deck"]) == 0, "%s -> %s: stayed on the deck (%d frames off, worst %.2f m)" % [from, stop, r["off_deck"], r["worst"]])
		check(ferry.aboard(), "%s -> %s: still aboard on arrival" % [from, stop])
		print("  %s -> %s: %.1f s, %d frames, worst drift %.2f m" % [from, stop, r["time"], r["frames"], r["worst"]])
		# Step off forward onto the stage.
		var d: Array = LakeLayout.stop_dock(stop)
		var stand: Vector3 = (d[0] as Vector3) - (d[1] as Vector3) * 1.2
		var off: bool = await walk([stand], "stepping off at %s" % stop)
		check(off and not ferry.aboard(), "stepped off at %s" % stop)
		# Up the landing's steps to its deck (the hidden ramps; there's no step-up).
		var up: bool = await walk([(d[0] as Vector3) - (d[1] as Vector3) * 5.0], "up the steps at %s" % stop)
		check(up and game.player.global_position.y > -0.15, "climbed to the deck at %s (y %.2f)" % [stop, game.player.global_position.y])
	check(rock_hits.is_empty(), "no rock in the ferry's way on any crossing (%d: %s)" % [rock_hits.size(), ", ".join(rock_hits.slice(0, 3))])
	if game.world.get_node("Life").get("_far_curve") != null:     # the lantern boat: step 3
		far_boat_clear()
	check(nearest_boat > 4.0, "the ferry never sails through the lantern boat (nearest %.1f m)" % nearest_boat)
	# A bell at the Mahaleh calls the empty ferry from the quay.
	var bell: Node = null
	for b: Node in game.world.find_children("*", "", true, false):
		if b.has_meta("stop") and str(b.get_meta("stop")) == "mahaleh":
			bell = b
	check(bell != null, "the Mahaleh landing has a bell")
	ferry.ring("mahaleh")
	var rr: Dictionary = await ride_until_docked(90.0)
	check(ferry.at == "mahaleh", "the bell brought the ferry to the Mahaleh (at %s)" % ferry.at)
	print("  bell quay -> mahaleh (empty): %.1f s" % rr["time"])
	# Wade off the shelf into the deep: back on a safe point.
	game.player.teleport(Vector3(0, -1.6, -17.0), 0.0)
	await physics_frame
	Input.action_press("forward")
	var lowest: float = 99.0
	var back: bool = false
	var was: Vector3 = game.player.global_position
	for _i: int in 60 * 12:
		await physics_frame
		var now: Vector3 = game.player.global_position
		lowest = minf(lowest, now.y)
		if now.distance_to(was) > 2.0:      # put back on a safe point
			Input.action_release("forward")
			for _j: int in 90:              # the fade, then standing
				await physics_frame
			now = game.player.global_position
			back = now.y > LakeLayout.WATER - 0.6 and game.player.is_on_floor()
			break
		was = now
	Input.action_release("forward")
	check(back, "wading off the shelf puts you back on shore (now %s)" % game.player.global_position)
	check(lowest > LakeLayout.WATER - 3.0, "wading never sinks far (lowest %.2f)" % lowest)


## Puts the player in the middle of the docked deck.
func board() -> void:
	var p: Vector3 = ferry.body.global_transform * Vector3(0.0, LakeFerry.DECK + 0.1, -1.0)
	game.player.teleport(p, ferry.body.global_rotation.y)
	for _i: int in 20:
		await physics_frame


func ride_until_docked(limit: float) -> Dictionary:
	var t: float = 0.0
	var frames: int = 0
	var off: int = 0
	var worst: float = 0.0
	var started: bool = false
	var start_local: Vector3 = ferry.body.global_transform.affine_inverse() * game.player.global_position
	while t < limit:
		await physics_frame
		t += 1.0 / Engine.physics_ticks_per_second
		frames += 1
		if ferry.moving():
			started = true
			# Walk 1's rock stacks and hanging rock stay out of the ferry's way:
			# nothing solid in the barge's box (hull to awning) out on the water.
			var far: Node3D = game.world.get_node_or_null("Life/FarBoat") as Node3D
			if far != null:
				nearest_boat = minf(nearest_boat, Vector2(far.global_position.x - ferry.body.global_position.x, far.global_position.z - ferry.body.global_position.z).length())
			if frames % 6 == 0 and ferry.phase == LakeFerry.Phase.CRUISE and ferry._s > 6.0 \
					and ferry._curve.get_baked_length() - ferry._s > 14.0:
				var hit: String = in_the_way(ferry.body.global_transform)
				if hit != "":
					rock_hits.append("%s -> %s at %s: %s" % [ferry.at, ferry.to, ferry.body.global_position, hit])
			if ferry.carrying:
				var local: Vector3 = ferry.body.global_transform.affine_inverse() * game.player.global_position
				worst = maxf(worst, Vector2(local.x - start_local.x, local.z - start_local.z).length())
				if OS.get_environment("R20_DRIFT") != "" and frames % 30 == 0:
					print("    drift leg %d phase %d: %.2f (local %s)" % [ferry._leg, ferry.phase, Vector2(local.x - start_local.x, local.z - start_local.z).length(), local])
				if not ferry.aboard():
					off += 1
		elif started:
			break
	return {"time": t, "frames": frames, "off_deck": off, "worst": worst}


## What solid thing (not the barge or the player) is inside a barge-sized box
## at `xform` (on the water), or "".
func in_the_way(xform: Transform3D) -> String:
	var box := BoxShape3D.new()
	box.size = Vector3(3.6, 3.6, 8.6)
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = box
	q.transform = Transform3D(xform.basis, Vector3(xform.origin.x, LakeLayout.WATER + 1.9, xform.origin.z))
	q.collision_mask = 1
	q.exclude = [ferry.body.get_rid(), (game.player as CollisionObject3D).get_rid()]
	var hits: Array[Dictionary] = game.player.get_world_3d().direct_space_state.intersect_shape(q, 4)
	for h: Dictionary in hits:
		var who: Node = h["collider"] as Node
		if not String(who.get_path()).contains("/Life/"):     # moving boats: LakeLife keeps the far one clear
			return str(who.get_path())
	return ""


## The far lantern boat's whole crossing (LakeLife._far_ferry) is clear water too.
func far_boat_clear() -> void:
	var life: Node = game.world.get_node("Life")
	var curve: Curve3D = life.get("_far_curve")
	var length: float = curve.get_baked_length()
	var bad: PackedStringArray = []
	var s: float = 8.0
	while s < length - 8.0:
		var p: Vector3 = curve.sample_baked(s)
		var dir: Vector3 = curve.sample_baked(s + 1.0) - p
		var hit: String = in_the_way(Transform3D(Basis(Vector3.UP, atan2(-dir.x, -dir.z)), p))
		if hit != "":
			bad.append("%.0f m: %s" % [s, hit])
		s += 2.0
	check(bad.is_empty(), "the far lantern boat's water is clear (%s)" % ", ".join(bad.slice(0, 3)))


## Walks the player through `points` (the real controller, "forward" held).
func walk(points: Array[Vector3], what: String) -> bool:
	for p: Vector3 in points:
		var t: float = 0.0
		var reached: bool = false
		while t < 12.0:
			var here: Vector3 = game.player.global_position
			var flat: Vector3 = Vector3(p.x - here.x, 0.0, p.z - here.z)
			if flat.length() < 0.45:
				reached = true
				break
			game.player.rotation.y = atan2(-flat.x, -flat.z)
			Input.action_press("forward")
			await physics_frame
			t += 1.0 / Engine.physics_ticks_per_second
		Input.action_release("forward")
		if not reached:
			check(false, "%s: stuck short of %s at %s" % [what, p, game.player.global_position])
			return false
	for _i: int in 10:
		await physics_frame
	return true


# ------------------------------------------------------------------ save/load

func save_mode() -> void:
	ws.data.erase("lake")
	await board()
	ferry.ask("mahaleh")
	var t: float = 0.0
	while t < 60.0 and not (ferry.phase == LakeFerry.Phase.CRUISE and ferry._leg == 0 and ferry._s > 10.0):     # before the fog (R4)
		await physics_frame
		t += 1.0 / Engine.physics_ticks_per_second
	check(ferry.phase == LakeFerry.Phase.CRUISE and ferry.aboard(), "halfway across, aboard (phase %d)" % ferry.phase)


func load_mode() -> void:
	check(ferry.at == "quay" and not ferry.moving(), "resumed: the ferry is at the quay (at %s)" % ferry.at)
	var p: Vector3 = game.player.global_position
	var d: Array = LakeLayout.stop_dock("quay")
	var stage: Vector3 = d[0]
	check(Vector2(p.x - stage.x, p.z - stage.z).length() < 2.0 and absf(p.y - stage.y) < 0.6,
		"resumed on the quay's stage (at %s, stage %s)" % [p, stage])
	check(not ferry.aboard(), "resumed off the boat")
	for _i: int in 60:
		await physics_frame
	check(game.player.global_position.y > LakeLayout.WATER - 0.5, "standing, not sinking (%s)" % game.player.global_position)


func finish(mode: String) -> void:
	print("r20_ferry_test %s: %d checks, %d failures" % [mode, checks, failures.size()])
	main_script.room_override = ""
	if mode == "save" and failures.is_empty() and game != null:
		game.save_and_quit()
	else:
		quit(1 if not failures.is_empty() else 0)

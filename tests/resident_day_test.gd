extends SceneTree
## A whole day on the residents' test lane, run fast with no display (phase 21
## steps 2-4): the day report. Steps the clock by hand, STEP_S of the day at a
## time, so people walk every step of their day as they would at speed 1.
##   godot --headless --audio-driver Dummy --path . --script res://tests/resident_day_test.gd [-- --quiet]
## Prints each person's day, change by change, and fails (exit 1) if anyone
## never slept, ate fewer than three times, a cook never cooked, anyone
## walked toward one spot for more than STUCK_S, the hearth was never lit or
## never put out, or the lamp stayed lit while everyone slept.

const DRAFT: String = "res://gen/recipes/drafts/mahaleh/lane_test.tres"
const STEP_S: float = 0.5
const STUCK_S: float = 70.0


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var quiet: bool = OS.get_cmdline_user_args().has("--quiet")
	var ws: Node = root.get_node_or_null("/root/WorldState")
	ws.set("walk_area", "mahaleh")
	ws.set("walk_recipe", DRAFT)
	var main_script: GDScript = load("res://scripts/main.gd")
	main_script.room_override = "area:mahaleh"
	Area.seed_override = 1
	var game: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	current_scene = game
	game.player.blocked = true
	for _i: int in 30:
		await process_frame
	var area: Area = game.world
	while area.streamer.busy():
		await process_frame
	var residents: Residents = get_first_node_in_group(Residents.GROUP) as Residents
	# (The people come when the room's walking surface is made.)
	for _i: int in 900:
		await process_frame
		if residents != null and residents.settled():
			break
	var fails: PackedStringArray = []
	if residents == null or residents.people.is_empty():
		print("resident_day_test: FAIL, nobody lives on the lane")
		quit(1)
		return
	residents.heed_player = false     # (you aren't in this day: resident_meet_test is where you stand in the way)
	var clock: DayClock = DayClock.it()
	clock.paused = true          # the test moves the day itself
	clock.speed = 1.0
	clock.time = 0.0
	var was: Dictionary = {}     # person -> the last line said of them
	var did: Dictionary = {}     # person -> {activity: times arrived}
	var worst: Dictionary = {}   # person -> longest walk (s)
	var hearth_lit: int = 0
	var hearth_out: int = 0
	var lamp_wrong: int = 0
	var far_off: float = 0.0
	var waits: int = 0
	var moves: Dictionary = {}     # every movement anyone settled into
	var carried: Dictionary = {}   # every thing seen in a hand
	var off_floor: int = 0
	var steps: int = int(DayClock.DAY_S / STEP_S)
	print("resident_day_test: %d people in %d homes; a day in %d steps" % [residents.people.size(), residents.households.size(), steps])
	for h: Dictionary in residents.households:
		print("  home %d (%s): %d spots (%s), %d hearth lights, %d lamp lights, door %s" % [h["index"], h["kind"], (h["spots"] as Array).size(),
				", ".join((h["spots"] as Array).map(func(s: Dictionary) -> String: return str(s["kind"]))), (h["hearth_lights"] as Array).size(),
				(h["lamp_lights"] as Array).size(), "found" if h["door"] != null else "MISSING"])
		if h["kind"] == "family" and (h["hearth_lights"] as Array).is_empty():
			fails.append("home %d has no hearth light" % h["index"])
		if h["door"] == null:
			fails.append("home %d has no door" % h["index"])
	for step: int in steps:
		clock.time = step * STEP_S
		residents.advance(STEP_S, clock)
		for p: Resident in residents.people:
			var line: String = ("going to " if p.walking else "") + p.doing
			if was.get(p) != line:
				was[p] = line
				if not quiet:
					print("  %-22s %-9s %s" % [Resident.bell_text(clock.bells()), p.given_name, line + ("" if p.walking else "  at %s" % p.global_position.snapped(Vector3.ONE * 0.1))])
				if not p.walking:
					var d: Dictionary = did.get_or_add(p, {})
					d[p.doing] = int(d.get(p.doing, 0)) + 1
					moves[p.body.anim.current_animation] = true
					if p.doing == "away" and (p.visible or not p.away):
						fails.append("%s is away but still seen" % p.given_name)
			worst[p] = maxf(float(worst.get(p, 0.0)), p.walked_s if p.walking else 0.0)
			if not p.walking and not p.spot.is_empty():
				# Arrived means there: at the spot, not held up short of it.
				var off: float = Vector2(p.global_position.x - p.stands_at().x, p.global_position.z - p.stands_at().z).length()
				far_off = maxf(far_off, off)
			if p.waiting_for != "":
				waits += 1
			if p.body.holding != "":
				carried[p.body.holding] = true
			# Walking is over the floor: never through a wall or a table.
			if p.walking and p.route.size() > 1 and not residents.ways.on(p.global_position + Vector3(0, 0.25, 0), 0.2):
				off_floor += 1
				if off_floor < 6:
					print("    (off the floor: %s at %s, going to %s)" % [p.given_name, p.global_position.snapped(Vector3.ONE * 0.01), p.doing])
		for h: Dictionary in residents.households:
			hearth_lit += 1 if h["hearth_on"] else 0
			hearth_out += 0 if h["hearth_on"] else 1
			var asleep: bool = (h["members"] as Array).all(func(m: Resident) -> bool: return m.doing == "sleep" and not m.walking)
			if asleep and h["lamp_on"]:
				lamp_wrong += 1
		if step % 400 == 0:
			await process_frame      # (lets the doors' tweens and the engine breathe)
	for p: Resident in residents.people:
		var d: Dictionary = did.get(p, {})
		print("  %s, %s: %s; longest walk %.0f s" % [p.given_name, p.trade, d, float(worst.get(p, 0.0))])
		if int(d.get("sleep", 0)) < 1:
			fails.append("%s never slept" % p.given_name)
		# Step 4: every trade's day. [trade, activity, at least this many arrivals]
		for need: Array in [["cook", "eat", 3], ["cook", "cook", 3], ["cook", "water", 3], ["cook", "shop", 1],
				["stall keeper", "eat", 3], ["stall keeper", "keep", 2], ["stall keeper", "hauz", 1],
				["lamp tender", "eat", 3], ["lamp tender", "tend", 4], ["lamp tender", "hauz", 1],
				["scholar", "eat", 3], ["scholar", "work", 3], ["scholar", "water", 1], ["scholar", "shop", 1], ["scholar", "hauz", 1],
				["hunter", "eat", 2], ["hunter", "away", 1], ["hunter", "work", 1], ["hunter", "shop", 1], ["hunter", "water", 1], ["hunter", "hauz", 1]]:
			if p.trade == need[0] and int(d.get(need[1], 0)) < int(need[2]):
				fails.append("%s (%s) did '%s' %d times, not %d" % [p.given_name, p.trade, need[1], int(d.get(need[1], 0)), need[2]])
		print("    walked %.0f m in the day" % p.walked_m)
		if float(worst.get(p, 0.0)) > STUCK_S:
			fails.append("%s walked %.0f s toward one spot" % [p.given_name, float(worst[p])])
	print("  furthest anyone stood from their spot: %.2f m; steps spent waiting for each other: %d" % [far_off, waits])
	print("  steps walked off the walking surface: %d" % off_floor)
	if off_floor > 0:
		fails.append("%d steps were walked off the walking surface" % off_floor)
	print("  movements seen: %s; carried: %s" % [", ".join(moves.keys()), ", ".join(carried.keys())])
	for want: String in ["stir", "dip", "weigh", "reach", "eat_floor", "eat_knees", "read_knees", "mend_floor", "sleep"]:
		if not moves.has(want):
			fails.append("nobody was ever seen to '%s'" % want)
	for want: String in ["jar", "basket"]:
		if not carried.has(want):
			fails.append("nobody carried a %s" % want)
	if far_off > 0.9:
		fails.append("someone stood %.1f m from their spot" % far_off)
	if hearth_lit == 0:
		fails.append("the hearth was never lit")
	if hearth_out == 0:
		fails.append("the hearth was never put out")
	if lamp_wrong > 0:
		fails.append("the lamp burned for %d steps while everyone slept" % lamp_wrong)
	print("  hearth lit %.0f%% of the day" % (100.0 * hearth_lit / maxi(hearth_lit + hearth_out, 1)))
	print("resident_day_test: %s" % ("PASS" if fails.is_empty() else "FAIL: " + "; ".join(fails)))
	main_script.room_override = ""
	quit(0 if fails.is_empty() else 1)

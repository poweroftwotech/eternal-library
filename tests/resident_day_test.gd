extends SceneTree
## A whole day on the residents' test lane, run fast with no display (phase 21
## step 2): the day report. Steps the clock by hand, STEP_S of the day at a
## time, so people walk every step of their day as they would at speed 1.
##   godot --headless --audio-driver Dummy --path . --script res://tests/resident_day_test.gd [-- --quiet]
## Prints each person's day, change by change, and fails (exit 1) if anyone
## never slept, ate fewer than three times, a cook never cooked, anyone
## walked toward one spot for more than STUCK_S, the hearth was never lit or
## never put out, or the lamp stayed lit while everyone slept.

const DRAFT: String = "res://gen/recipes/drafts/mahaleh/lane_test.tres"
const STEP_S: float = 0.5
const STUCK_S: float = 40.0


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
	for _i: int in 10:
		await process_frame
	var residents: Residents = get_first_node_in_group(Residents.GROUP) as Residents
	var fails: PackedStringArray = []
	if residents == null or residents.people.is_empty():
		print("resident_day_test: FAIL, nobody lives on the lane")
		quit(1)
		return
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
	var steps: int = int(DayClock.DAY_S / STEP_S)
	print("resident_day_test: %d people in %d homes; a day in %d steps" % [residents.people.size(), residents.households.size(), steps])
	for h: Dictionary in residents.households:
		print("  home %d (%s): %d spots (%s), %d hearth lights, %d lamp lights, door %s" % [h["index"], h["kind"], (h["spots"] as Array).size(),
				", ".join((h["spots"] as Array).map(func(s: Dictionary) -> String: return str(s["kind"]))), (h["hearth_lights"] as Array).size(),
				(h["lamp_lights"] as Array).size(), "found" if h["door"] != null else "MISSING"])
		if (h["hearth_lights"] as Array).is_empty():
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
			worst[p] = maxf(float(worst.get(p, 0.0)), p.walked_s if p.walking else 0.0)
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
		if int(d.get("eat", 0)) < 3:
			fails.append("%s ate %d times" % [p.given_name, int(d.get("eat", 0))])
		if p.trade == "cook" and int(d.get("cook", 0)) < 3:
			fails.append("%s cooked %d times" % [p.given_name, int(d.get("cook", 0))])
		if float(worst.get(p, 0.0)) > STUCK_S:
			fails.append("%s walked %.0f s toward one spot" % [p.given_name, float(worst[p])])
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

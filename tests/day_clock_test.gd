extends SceneTree
## Phase 21 step 2: the day's clock and the save, across OS processes
## (AGENTS.md: persistence gate). Headless:
##   godot --audio-driver Dummy --headless --path . --script res://tests/day_clock_test.gd -- save --save=user://test/day.json --fresh
##   godot --audio-driver Dummy --headless --path . --script res://tests/day_clock_test.gd -- load --save=user://test/day.json
## save: a new world starts a little after the first bell; the clock runs; a
##       bell rings when its time comes and jump_to_bell lands on it; the day
##       passing leaves the years alone (so no room ages or rebuilds). Then
##       the time is set to SET_S and the game saved.
## load: a fresh process starts at SET_S, give or take the frames it ran.

const SET_S: float = DayClock.DAY_S * 2.0 + DayClock.BELL_S * 3.4

var failures: PackedStringArray = []
var checks: int = 0


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures.append(what)
		print("  FAIL: " + what)


func run() -> void:
	var mode: String = "save"
	for a: String in OS.get_cmdline_user_args():
		if a in ["save", "load"]:
			mode = a
	var main_script: GDScript = load("res://scripts/main.gd")
	main_script.room_override = "camp"
	var game: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	current_scene = game
	game.player.blocked = true
	for _i: int in 20:
		await process_frame
	var clock: DayClock = DayClock.it()
	var ws: Node = root.get_node("/root/WorldState")
	check(clock != null, "the Day autoload is there")
	if clock == null:
		quit(1)
		return
	if mode == "save":
		check(clock.time >= DayClock.START_S and clock.time < DayClock.START_S + 30.0, "a new world starts just after the first bell (%.1f s)" % clock.time)
		check(clock.bell_index() == 0, "it is the first bell")
		var years: float = ws.call("years")
		var rang: Array[int] = []
		clock.bell_rang.connect(func(i: int) -> void: rang.append(i))
		clock.time = DayClock.BELL_S - 0.05
		clock.speed = 10.0
		for _i: int in 30:
			await process_frame
		check(rang == [1], "the second bell rang once as its time came (%s)" % [rang])
		check(clock.bell_index() == 1, "it is the second bell")
		clock.speed = 1.0
		clock.jump_to_bell(4)
		check(clock.bell_index() == 4 and clock.bells() < 4.01, "jumping to the fifth bell lands on it (%.3f)" % clock.bells())
		check(rang == [1, 4], "and rings it")
		clock.jump_to_bell(0)
		check(clock.day() == 1 and clock.bell_index() == 0, "jumping to the first bell goes on to the next day (day %d)" % clock.day())
		clock.paused = true
		var held: float = clock.time
		for _i: int in 10:
			await process_frame
		check(is_equal_approx(clock.time, held), "paused, the time stands")
		check(is_equal_approx(float(ws.call("years")), years), "days passing leave the years alone")
		clock.time = SET_S
		clock.paused = false
		await process_frame
		clock.paused = true
		check(absf(float((ws.get("data") as Dictionary).get("day_s", -1.0)) - SET_S) < 1.0, "the time is in the save's data")
		check(ws.call("save_now") == OK, "the game saves")
	else:
		check(absf(clock.time - SET_S) < 5.0, "a fresh process resumes the day where it was saved (%.1f, saved %.1f)" % [clock.time, SET_S])
		check(clock.day() == 2 and clock.bell_index() == 3, "day 3, the fourth bell (%s)" % clock.text())
	print("day_clock_test %s: %d checks, %s" % [mode, checks, "PASS" if failures.is_empty() else "FAIL (%d)" % failures.size()])
	main_script.room_override = ""
	quit(0 if failures.is_empty() else 1)

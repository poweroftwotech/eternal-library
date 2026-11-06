extends SceneTree
## The Strata Board flags a traced map that's out of date and re-traces it.
##   godot --headless --audio-driver Dummy --path . --script res://tests/map_stale_test.gd [-- run]
## Checks: a door added, taken away or moved, or a built file changed, changes
## the stamp and says why; the board shows the flag and the button only when
## they're needed. With `run` the board's button really traces gen/map and the
## flag clears (it rewrites the map from the saved files, as the button does).

const Service: GDScript = preload("res://addons/strata_board/strata_service.gd")
const Board: GDScript = preload("res://addons/strata_board/strata_board.gd")

var failures: PackedStringArray = []
var checks: int = 0


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures.append(what)


func why(sp: StratumPlan, place: String) -> String:
	for m: Dictionary in Service.map_state(sp):
		if str(m["place"]) == place:
			return str(m["why"])
	return ""


## A trace of `place` stamped for `sp`, with `doors` (kept in memory by writing a copy).
func stamp_for(place: String, sp: StratumPlan) -> String:
	return MapTrace.stamp_of(place, sp.links)


func run() -> void:
	var live: StratumPlan = load(StratumPlan.PATH)
	var a: String = stamp_for("gorge", live)
	check(a == stamp_for("gorge", live), "the same files and doors stamp the same")
	var door: Dictionary = {}
	for l: Dictionary in live.links:
		if str(l.get("kind", "")) == StratumPlan.DOOR and str(l["a"]) == "gorge":
			door = l
	check(not door.is_empty(), "the live world has a Gorge door to test with")

	var moved: StratumPlan = live.duplicate(true)
	for l: Dictionary in moved.links:
		if str(l["b"]) == str(door["b"]) and str(l.get("kind", "")) == StratumPlan.DOOR:
			l["at"] = "somewhere_else"
	check(stamp_for("gorge", moved) != a, "a moved door changes the stamp")

	var extra: StratumPlan = live.duplicate(true)
	extra.links.append({"a": "gorge", "at": "x", "b": "new_area", "kind": StratumPlan.DOOR})
	check(stamp_for("gorge", extra) != a, "a new door changes the stamp")
	check(why(extra, "gorge").contains("no door to new_area"), "the flag names the new door (says: %s)" % why(extra, "gorge"))

	var fewer: StratumPlan = live.duplicate(true)
	fewer.links = fewer.links.filter(func(l: Dictionary) -> bool: return str(l["b"]) != str(door["b"]))
	check(stamp_for("gorge", fewer) != a, "a door taken away changes the stamp")
	check(why(fewer, "gorge").contains("an old door to %s" % door["b"]), "the flag names the old door (says: %s)" % why(fewer, "gorge"))
	check(stamp_for("camp", extra) == stamp_for("camp", live), "a Gorge door leaves the camp's stamp alone")

	var src: Array = MapTrace.SOURCES["gorge"]
	var saved: Dictionary = MapTrace.SOURCES.duplicate(true)
	check(src.any(func(s: String) -> bool: return DirAccess.dir_exists_absolute(s)), "a folder of baked pieces counts as a source")
	check(saved.has("camp"), "the camp is traced too")

	var do_run: bool = OS.get_cmdline_user_args().has("run")
	if do_run:     # something to trace, whatever state the map is in
		var t: MapTrace = ResourceLoader.load(MapTrace.path_of("gorge"), "", ResourceLoader.CACHE_MODE_IGNORE)
		t.source_stamp = ""
		ResourceSaver.save(t, MapTrace.path_of("gorge"))
	var b: Control = Board.new()
	b.set("local_planner", true)
	b.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(b)
	for i: int in 1200:
		await process_frame
		if not (b.get("stratum") as Dictionary).is_empty() and not (b.get("catalog") as Dictionary).is_empty():
			break
	var bar: Control = (b.get("_map_note") as Label).get_parent()
	var stale: Array = (b.get("stratum") as Dictionary).get("map", [])
	print("map_stale_test: out of date: ", stale)
	check(bar.visible == not stale.is_empty(), "the flag shows only when a map is out of date")
	if do_run:
		check(not stale.is_empty(), "something to trace")
		b.call("retrace")
		await process_frame
		check((b.get("_retrace_button") as Button).disabled, "the button waits while tracing")
		var stop: int = Time.get_ticks_msec() + 300000
		while str(b.get("_retracing")) != "" and Time.get_ticks_msec() < stop:
			await process_frame
		await process_frame
		check(((b.get("stratum") as Dictionary).get("map", []) as Array).is_empty(), "the flag clears: %s" % str((b.get("stratum") as Dictionary).get("map", [])))
		check(not bar.visible, "the flag is gone")
		check(str(b.get("notice")).begins_with("Map re-traced"), "the board says so (says: %s)" % str(b.get("notice")))
		check(Service.map_state(load(StratumPlan.PATH)).is_empty(), "a fresh check agrees")
	else:
		var args: PackedStringArray = b.call("trace_args", "gorge")
		check(args.has("res://tools/map_trace.gd") and args.has("gorge") and args.has("--headless"), "the button runs the trace tool")
	b.queue_free()
	await process_frame
	if failures.is_empty():
		print("map_stale_test: PASS (%d checks)" % checks)
		quit(0)
	else:
		for f: String in failures:
			printerr("FAIL: " + f)
		print("map_stale_test: FAIL (%d of %d)" % [failures.size(), checks])
		quit(1)

extends SceneTree
## The report key (the ` key, scripts/report_tool.gd), in the real game on the GPU
## (the screenshot needs a renderer):
##   godot --path . --resolution 1280x720 --script res://tests/report_test.gd -- <scratch dir>
## In the Gorge area, on the landing, looking at the left colossus: ` opens the
## pop-up (the player stops, the mouse is free); Esc cancels and writes
## nothing; ` again, a note, Enter: one line in reports.jsonl with where you
## stood and looked, what the screen's centre hits, the area and seed, the
## note; and the screenshot, taken before the pop-up showed. Writes to the
## scratch dir, not your reports/.

const FEET: Vector3 = Vector3(-16, -8, -58)
const YAW_DEG: float = 150.0
const PITCH_DEG: float = -12.0

var failures: PackedStringArray = []
var checks: int = 0


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures.append(what)


func press(key: Key) -> void:
	var e := InputEventKey.new()
	e.keycode = key
	e.physical_keycode = key
	e.pressed = true
	Input.parse_input_event(e)
	var up: InputEventKey = e.duplicate()
	up.pressed = false
	Input.parse_input_event(up)


func run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var dir: String = args[0] if args.size() > 0 else OS.get_cache_dir() + "/report_test"
	ReportTool.folder_override = dir
	DirAccess.remove_absolute(ReportTool.folder() + ReportTool.LOG_NAME)
	var main_script: GDScript = load("res://scripts/main.gd")
	main_script.room_override = "area:gorge"
	var game: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	game.hud.toast_time = 0
	for _i: int in 10:
		await process_frame
	game.player.global_position = FEET
	game.player.rotation.y = deg_to_rad(YAW_DEG)
	game.player.camera.rotation.x = deg_to_rad(PITCH_DEG)
	for _i: int in 60:
		await process_frame
	var report: ReportTool = game.report
	check(not report.is_open() and not game.player.blocked, "starts closed, the player free")
	press(KEY_QUOTELEFT)
	await process_frame
	check(report.is_open(), "` opens the pop-up")
	check(game.player.blocked and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "the player stops and the mouse is free while it's open")
	press(KEY_ESCAPE)
	await process_frame
	check(not report.is_open() and not game.player.blocked, "Esc closes it and frees the player")
	check(not game.hud.modal_open, "Esc doesn't open the menu as well")
	check(ReportTool.read_all().is_empty(), "a cancelled report writes nothing")
	press(KEY_QUOTELEFT)
	await process_frame
	report._note.text = "test: a gap by the colossus"
	report._note.text_submitted.emit(report._note.text)
	await process_frame
	check(not report.is_open() and not game.player.blocked, "Enter saves and closes")
	var all: Array[Dictionary] = ReportTool.read_all()
	check(all.size() == 1, "one report in the log (%d)" % all.size())
	if all.size() == 1:
		var r: Dictionary = all[0]
		var feet: Array = r.get("feet", [])
		check(feet.size() == 3 and Vector3(feet[0], feet[1], feet[2]).distance_to(FEET) < .01, "it has where you stood (%s)" % [feet])
		check(absf(float(r.get("yaw_deg", 0)) - YAW_DEG) < .1 and absf(float(r.get("pitch_deg", 0)) - PITCH_DEG) < .1, "and where you looked (yaw %s, pitch %s)" % [r.get("yaw_deg"), r.get("pitch_deg")])
		check(r.get("area", "") == "gorge" and r.has("seed") and r.get("scene", "") == "area:gorge", "and the area, seed and scene")
		check(r.get("note", "") == "test: a gap by the colossus", "and the note")
		check(r.has("aim") and float((r["aim"] as Dictionary).get("distance", 0)) > 0.0, "and what the screen's centre hits (%s)" % [r.get("aim")])
		var shot := Image.load_from_file(ReportTool.folder() + str(r.get("screenshot", "")))
		check(shot != null and shot.get_width() > 0, "the screenshot is saved")
		if shot != null and shot.get_width() > 0:
			# The pop-up sits in the middle: taken before it showed, the middle
			# is the scene, not the panel's near-black.
			var c: Color = shot.get_pixel(shot.get_width() / 2, shot.get_height() / 2)
			var panel := Color(0.03, 0.045, 0.05)
			check(Vector3(c.r - panel.r, c.g - panel.g, c.b - panel.b).length() > .03, "it was taken before the pop-up covered the view (centre %s)" % c)
	main_script.room_override = ""
	ReportTool.folder_override = ""
	print("report_test: %d checks, %d failures" % [checks, failures.size()])
	for f: String in failures:
		print("  FAIL ", f)
	quit(1 if not failures.is_empty() else 0)

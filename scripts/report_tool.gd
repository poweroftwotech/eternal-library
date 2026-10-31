class_name ReportTool
extends CanvasLayer
## Reporting what you see, for Claude to look at (the ` key). Press it wherever
## something is wrong (a gap, a missing face, a light, anything): it keeps a
## screenshot of the frame as you saw it, then asks for an optional note
## (Enter saves, Esc cancels). Each report is one line of reports.jsonl:
## where you stood and looked (feet, eye, yaw, pitch, field of view, the
## camera's whole transform), what the centre of the screen hits, the scene,
## area seed and room, the window size and graphics preset, and the note.
## tests/report_capture.gd stands the camera there again to re-take the view
## (before and after a fix).
##
## In a run from the project the reports go in the project's reports/ folder
## (git-ignored); in an exported game, user://reports/.
##
## Layout: CanvasLayer → MarginContainer (full screen, centred) →
## CenterContainer → PanelContainer → VBoxContainer (AGENTS.md section 3).

## The backquote key (top left, under Esc). Not F9: run from the editor, the
## function keys belong to its debugger (F9 paused the game there).
const KEY: Key = KEY_QUOTELEFT
const LOG_NAME: String = "reports.jsonl"
## How far the centre-of-screen probe looks (the gorge is ~300 m across).
const PROBE_M: float = 600.0
const WIDTH: float = 560.0
const HEAD_COLOUR := Color("dfbd7b")
const HINT_COLOUR := Color("8a8a80")

## The game (main.gd), for the player, the world and the HUD.
var game: Node
## The HUD's theme, so the pop-up matches it.
var ui_theme: Theme

var _panel: Control
var _where: Label
var _note: LineEdit
var _pending: Dictionary = {}
var _shot: Image
var _was_blocked: bool = false
## Tests write their reports elsewhere (a folder path), so yours stay yours.
static var folder_override: String = ""


## The folder reports go in.
static func folder() -> String:
	if folder_override != "":
		return folder_override.trim_suffix("/") + "/"
	return ProjectSettings.globalize_path("user://reports/" if OS.has_feature("template") else "res://reports/")


## Every report so far, oldest first.
static func read_all() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var f := FileAccess.open(folder() + LOG_NAME, FileAccess.READ)
	if f == null:
		return out
	while not f.eof_reached():
		var line: String = f.get_line().strip_edges()
		if line.is_empty():
			continue
		var entry: Variant = JSON.parse_string(line)
		if entry is Dictionary:
			out.append(entry)
	return out


func _ready() -> void:
	layer = 6
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ui_theme != null:
		margin.theme = ui_theme
	add_child(margin)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(center)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.045, 0.05, 0.9)
	style.border_color = Color("7c724f")
	style.set_border_width_all(1)
	style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.custom_minimum_size.x = WIDTH
	panel.add_child(box)
	var head := Label.new()
	head.text = "REPORT  ·  `"
	head.add_theme_color_override("font_color", HEAD_COLOUR)
	box.add_child(head)
	_where = Label.new()
	_where.add_theme_color_override("font_color", HINT_COLOUR)
	_where.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_where)
	_note = LineEdit.new()
	_note.placeholder_text = "What's wrong here? (optional)"
	_note.text_submitted.connect(_on_submitted)
	box.add_child(_note)
	var hint := Label.new()
	hint.text = "Enter saves · Esc cancels"
	hint.add_theme_color_override("font_color", HINT_COLOUR)
	box.add_child(hint)
	_panel = panel
	panel.visible = false


func is_open() -> bool:
	return _panel.visible


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var key: InputEventKey = event
	if is_open():
		if key.keycode == KEY_ESCAPE:
			_close()
			get_viewport().set_input_as_handled()
	elif key.physical_keycode == KEY and not game.hud.modal_open:
		_open()
		get_viewport().set_input_as_handled()


func _open() -> void:
	# The frame as it was, before the pop-up covers it.
	_shot = get_viewport().get_texture().get_image()
	_pending = snapshot()
	_where.text = "%s · standing at %s, looking %s" % [_pending["scene"], _fmt(_pending["feet"]), _heading(float(_pending["yaw_deg"]), float(_pending["pitch_deg"]))]
	_was_blocked = game.player.blocked
	game.player.blocked = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_note.text = ""
	_panel.visible = true
	_note.grab_focus()


func _close() -> void:
	_panel.visible = false
	_note.release_focus()
	_pending = {}
	_shot = null
	game.player.blocked = _was_blocked
	if not game.hud.modal_open:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_submitted(text: String) -> void:
	_pending["note"] = text.strip_edges()
	var saved: String = save(_pending, _shot)
	_close()
	game.hud.notify("Report saved: %s" % saved if saved != "" else "The report could not be saved (see the log)")


## Where you are and what you look at, now.
func snapshot() -> Dictionary:
	var player: Node3D = game.player
	var camera: Camera3D = game.player.camera
	var xf: Transform3D = camera.global_transform
	var forward: Vector3 = -xf.basis.z
	var entry: Dictionary = {
		"time": Time.get_datetime_string_from_system(false, true),
		"scene": str(game.scene_path),
		"feet": _arr(player.global_position),
		"eye": _arr(xf.origin),
		"forward": _arr(forward),
		"yaw_deg": snappedf(rad_to_deg(player.rotation.y), .01),
		"pitch_deg": snappedf(rad_to_deg(camera.rotation.x), .01),
		"fov": camera.fov,
		"camera": [_arr(xf.basis.x), _arr(xf.basis.y), _arr(xf.basis.z), _arr(xf.origin)],
		"window": [DisplayServer.window_get_size().x, DisplayServer.window_get_size().y],
		"preset": GraphicsPreset.requested(),     # "" = the project settings
	}
	if game.player.get("flying"):
		entry["flying"] = true     # fly mode (V): the feet are wherever you hovered
	# Where the place you're in stands (phase 9: off the origin once you've
	# walked into it from another): a replay boots it at the origin.
	if game.world is Node3D:
		var place: Transform3D = (game.world as Node3D).global_transform
		entry["place"] = [_arr(place.basis.x), _arr(place.basis.y), _arr(place.basis.z), _arr(place.origin)]
	if game.world is Area:
		var area: Area = game.world
		entry["area"] = area.recipe.id
		entry["seed"] = area.plan.area_seed
		var room: AreaPlan.Room = area.room_at(player.global_position)
		if room != null:
			entry["room"] = room.slot_id
			entry["room_name"] = room.display_name
	var space: PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(xf.origin, xf.origin + forward * PROBE_M)
	query.exclude = [player.get_rid()]
	var hit: Dictionary = space.intersect_ray(query)
	if not hit.is_empty():
		entry["aim"] = {"point": _arr(hit["position"]), "normal": _arr(hit["normal"]),
			"distance": snappedf(xf.origin.distance_to(hit["position"]), .01),
			"collider": str((hit["collider"] as Node).get_path()) if hit["collider"] is Node else ""}
	return entry


## Appends the report and its screenshot; returns its id ("" if it failed).
static func save(entry: Dictionary, shot: Image) -> String:
	var dir: String = folder()
	DirAccess.make_dir_recursive_absolute(dir)
	var id: String = str(entry.get("time", "report")).replace(":", "-").replace(" ", "_")
	var n: int = 1
	while FileAccess.file_exists(dir + id + ".png"):
		n += 1
		id = "%s_%d" % [str(entry["time"]).replace(":", "-").replace(" ", "_"), n]
	entry["id"] = id
	if shot != null:
		entry["screenshot"] = id + ".png"
		shot.save_png(dir + id + ".png")
	var f := FileAccess.open(dir + LOG_NAME, FileAccess.READ_WRITE if FileAccess.file_exists(dir + LOG_NAME) else FileAccess.WRITE)
	if f == null:
		push_error("report_tool: can't write %s (%s)" % [dir + LOG_NAME, error_string(FileAccess.get_open_error())])
		return ""
	f.seek_end()
	f.store_line(JSON.stringify(entry))
	f.close()
	return id


func _arr(v: Vector3) -> Array:
	return [snappedf(v.x, .001), snappedf(v.y, .001), snappedf(v.z, .001)]


func _fmt(v: Array) -> String:
	return "(%.1f, %.1f, %.1f)" % [v[0], v[1], v[2]]


## "north-west, slightly down": compass from the yaw (-Z is north).
func _heading(yaw_deg: float, pitch_deg: float) -> String:
	var names: Array[String] = ["north", "north-west", "west", "south-west", "south", "south-east", "east", "north-east"]
	var compass: String = names[posmod(roundi(yaw_deg / 45.0), 8)]
	var tilt: String = "level" if absf(pitch_deg) < 10.0 else ("up" if pitch_deg > 0.0 else "down")
	return "%s, %s" % [compass, tilt]

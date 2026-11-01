@tool
extends EditorPlugin
## The Strata Board (phase 10) as a tab beside 2D, 3D and Script: the stratum,
## each area's recipe and what any world seed makes of it (strata_board.gd).
## Opening the tab reads the recipe files fresh.
##
## Walk this seed leaves a one-time request (WorldState.WALK_REQUEST) that the
## game takes as it starts: that area, that world seed, on a scratch save. Your
## own world is never touched. (Run arguments were not reliable: the editor's
## Customize Run Instances can replace them.)

const Board: GDScript = preload("res://addons/strata_board/strata_board.gd")
const WALK_REQUEST: String = "user://strata_walk_request.json"     # as WorldState.WALK_REQUEST

var _board: Control


func _enter_tree() -> void:
	_board = Board.new()
	_board.name = "StrataBoard"
	_board.set("ui_scale", EditorInterface.get_editor_scale())
	_board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_board.walk_requested.connect(_on_walk)
	EditorInterface.get_editor_main_screen().add_child(_board)
	_make_visible(false)


func _exit_tree() -> void:
	if _board != null:
		_board.queue_free()


func _has_main_screen() -> bool:
	return true


func _get_plugin_name() -> String:
	return "Strata"


func _get_plugin_icon() -> Texture2D:
	return EditorInterface.get_editor_theme().get_icon(&"GridContainer", &"EditorIcons")


func _make_visible(visible: bool) -> void:
	if _board == null:
		return
	var was: bool = _board.visible
	_board.visible = visible
	if visible and not was and _board.is_inside_tree() and _board.get("client") != null:
		_board.call("reload")


func _on_walk(area_id: String, world_seed: int) -> void:
	var f := FileAccess.open(WALK_REQUEST, FileAccess.WRITE)
	if f == null:
		push_warning("Strata Board: cannot write %s (%s)" % [WALK_REQUEST, error_string(FileAccess.get_open_error())])
		return
	f.store_string(JSON.stringify({"area": area_id, "world_seed": world_seed, "time": Time.get_unix_time_from_system()}))
	f.close()
	EditorInterface.play_main_scene()

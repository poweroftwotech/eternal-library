@tool
extends EditorPlugin
## Kit dock: pick a module, click in the 3D view to place it on the grid.
##
##   Click a module in the list  -> arms placement (a ghost follows the mouse)
##   Left click in the 3D view   -> place (undoable)
##   R / Shift+R                 -> rotate 90 degrees
##   Page Up / Page Down         -> up or down one 4 m storey
##   Hold Ctrl                   -> 2 m snap (half bay); hold Shift -> 0.5 m snap
##   Esc or right click          -> stop placing
##
## Modules go under the edited scene's "Shell" node if it has one, otherwise
## under the scene root.

const CATALOG_PATH: String = "res://kit/catalog.tres"
const BAY: float = 4.0

var _dock: VBoxContainer
var _filter: LineEdit
var _list: ItemList
var _status: Label
var _catalog: KitCatalog
var _shown: Array[Dictionary] = []
var _armed: Dictionary = {}
var _ghost: Node3D
var _yaw_steps: int = 0
var _storey: int = 0


func _enter_tree() -> void:
	_dock = _build_dock()
	add_control_to_dock(DOCK_SLOT_LEFT_BR, _dock)
	scene_changed.connect(_on_scene_changed)
	_reload_catalog()


func _exit_tree() -> void:
	_disarm()
	if scene_changed.is_connected(_on_scene_changed):
		scene_changed.disconnect(_on_scene_changed)
	remove_control_from_docks(_dock)
	_dock.queue_free()


# --- dock UI -----------------------------------------------------------------

func _build_dock() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.name = "Kit"
	_filter = LineEdit.new()
	_filter.placeholder_text = "Filter modules (name, family or tag)"
	_filter.clear_button_enabled = true
	_filter.text_changed.connect(func(_t: String) -> void: _fill_list())
	box.add_child(_filter)
	_list = ItemList.new()
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.fixed_icon_size = Vector2i(64, 64)
	_list.icon_mode = ItemList.ICON_MODE_LEFT
	_list.item_selected.connect(_on_item_selected)
	box.add_child(_list)
	var row := HBoxContainer.new()
	var refresh := Button.new()
	refresh.text = "Refresh catalog"
	refresh.tooltip_text = "Rebuild wrapper scenes and kit/catalog.tres from assets/kit (run after export_kit)."
	refresh.pressed.connect(_on_refresh)
	row.add_child(refresh)
	var validate := Button.new()
	validate.text = "Validate scene"
	validate.tooltip_text = "Check kit modules in the open scene: grid alignment, rotation, scale."
	validate.pressed.connect(_on_validate)
	row.add_child(validate)
	box.add_child(row)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.text = "Pick a module, then click in the 3D view.\nR rotate · PgUp/PgDn storey · Ctrl 2 m · Shift 0.5 m · Esc stop"
	box.add_child(_status)
	return box


func _reload_catalog() -> void:
	_catalog = null
	if ResourceLoader.exists(CATALOG_PATH):
		_catalog = ResourceLoader.load(CATALOG_PATH, "", ResourceLoader.CACHE_MODE_REPLACE) as KitCatalog
	_fill_list()


func _fill_list() -> void:
	_list.clear()
	_shown.clear()
	if _catalog == null:
		_status.text = "No kit/catalog.tres yet. Run tools/export_kit.bat, then press Refresh catalog."
		return
	var needle: String = _filter.text.strip_edges().to_lower()
	for entry: Dictionary in _catalog.modules:
		var hay: String = ("%s %s %s %s" % [entry["name"], entry["family"], entry["shape"], " ".join(entry["tags"])]).to_lower()
		if needle != "" and not hay.contains(needle):
			continue
		var idx: int = _list.add_item("%s\n%s · %s" % [entry["name"], entry["family"], entry["shape"]])
		_list.set_item_tooltip(idx, "%s\nedge: %s\ntags: %s" % [entry["scene"], entry["edge"], ", ".join(entry["tags"])])
		_shown.append(entry)
		EditorInterface.get_resource_previewer().queue_resource_preview(entry["scene"], self, "_on_preview", idx)


func _on_preview(_path: String, preview: Texture2D, _thumb: Texture2D, idx: Variant) -> void:
	if preview != null and int(idx) < _list.item_count:
		_list.set_item_icon(int(idx), preview)


func _on_refresh() -> void:
	_disarm()
	var builder := KitCatalogBuilder.new()
	builder.build()
	for line: String in builder.log_lines:
		print("Kit: ", line)
	EditorInterface.get_resource_filesystem().scan()
	_reload_catalog()
	_status.text = builder.log_lines[-1] if not builder.log_lines.is_empty() else "Catalog refreshed."


func _on_validate() -> void:
	var root: Node = EditorInterface.get_edited_scene_root()
	if root == null:
		_status.text = "Open a scene first."
		return
	var problems: PackedStringArray = KitValidate.scene(root)
	var count: int = KitValidate.count_modules(root)
	if problems.is_empty():
		_status.text = "Validate: %d modules, no problems." % count
	else:
		_status.text = "Validate: %d problem(s) in %d modules. See Output." % [problems.size(), count]
		for p: String in problems:
			push_warning("Kit validate: " + p)


# --- placement -----------------------------------------------------------------

func _on_item_selected(idx: int) -> void:
	_disarm()
	var root: Node = EditorInterface.get_edited_scene_root()
	if root == null or not root is Node3D:
		_status.text = "Open a 3D scene first."
		_list.deselect_all()
		return
	_armed = _shown[idx]
	_ghost = (load(_armed["scene"]) as PackedScene).instantiate()
	_ghost.name = "_kit_ghost"
	root.add_child(_ghost, false, Node.INTERNAL_MODE_BACK)   # internal: never saved
	_set_ghost_look(_ghost)
	EditorInterface.edit_node(root)       # make sure this plugin receives 3D input
	_update_status()


func _disarm() -> void:
	if is_instance_valid(_ghost):
		_ghost.get_parent().remove_child(_ghost)
		_ghost.free()
	_ghost = null
	_armed = {}
	if _list != null:
		_list.deselect_all()


func _on_scene_changed(_root: Node) -> void:
	_disarm()


func _set_ghost_look(node: Node) -> void:
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).transparency = 0.55
	if node is CollisionObject3D:
		(node as CollisionObject3D).collision_layer = 0
	for child: Node in node.get_children(true):
		_set_ghost_look(child)


func _handles(object: Object) -> bool:
	return not _armed.is_empty() and object is Node


func _forward_3d_gui_input(camera: Camera3D, event: InputEvent) -> int:
	if _armed.is_empty() or not is_instance_valid(_ghost):
		return AFTER_GUI_INPUT_PASS
	if event is InputEventMouseMotion:
		_move_ghost(camera, (event as InputEventMouseMotion).position, event as InputEventWithModifiers)
		return AFTER_GUI_INPUT_PASS
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_move_ghost(camera, mb.position, mb)
			_place()
			return AFTER_GUI_INPUT_STOP
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			_disarm()
			return AFTER_GUI_INPUT_STOP
	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		var key := event as InputEventKey
		match key.keycode:
			KEY_R:
				_yaw_steps = (_yaw_steps + (3 if key.shift_pressed else 1)) % 4
				_ghost.basis = Basis(Vector3.UP, _yaw_steps * PI / 2.0)
				_update_status()
				return AFTER_GUI_INPUT_STOP
			KEY_PAGEUP:
				_storey += 1
				_update_status()
				return AFTER_GUI_INPUT_STOP
			KEY_PAGEDOWN:
				_storey -= 1
				_update_status()
				return AFTER_GUI_INPUT_STOP
			KEY_ESCAPE:
				_disarm()
				_status.text = "Stopped placing."
				return AFTER_GUI_INPUT_STOP
	return AFTER_GUI_INPUT_PASS


func _snap_step(mods: InputEventWithModifiers) -> float:
	if mods != null and mods.shift_pressed:
		return 0.5
	if mods != null and mods.ctrl_pressed:
		return BAY * 0.5
	return 0.5 if _armed.get("shape", "") == "free" else BAY


func _move_ghost(camera: Camera3D, screen: Vector2, mods: InputEventWithModifiers) -> void:
	var origin: Vector3 = camera.project_ray_origin(screen)
	var dir: Vector3 = camera.project_ray_normal(screen)
	var plane := Plane(Vector3.UP, _storey * BAY)
	var hit: Variant = plane.intersects_ray(origin, dir)
	if hit == null:
		return
	var step: float = _snap_step(mods)
	var p: Vector3 = hit
	p.x = snappedf(p.x, step)
	p.z = snappedf(p.z, step)
	p.y = _storey * BAY
	_ghost.global_transform = Transform3D(Basis(Vector3.UP, _yaw_steps * PI / 2.0), p)


func _place() -> void:
	var root: Node = EditorInterface.get_edited_scene_root()
	if root == null:
		return
	var parent: Node3D = root.get_node_or_null("Shell") as Node3D
	if parent == null:
		parent = root as Node3D
	var node: Node3D = (load(_armed["scene"]) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	node.name = _armed["name"]
	node.transform = parent.global_transform.affine_inverse() * _ghost.global_transform
	var ur: EditorUndoRedoManager = get_undo_redo()
	ur.create_action("Place kit module %s" % _armed["name"], UndoRedo.MERGE_DISABLE, root)
	ur.add_do_method(parent, "add_child", node, true)
	ur.add_do_method(node, "set_owner", root)
	ur.add_do_reference(node)
	ur.add_undo_method(parent, "remove_child", node)
	ur.commit_action()
	_update_status()


func _update_status() -> void:
	if _armed.is_empty():
		return
	_status.text = "Placing %s · rotation %d° · storey %d\nClick to place · R rotate · PgUp/PgDn storey · Ctrl 2 m · Shift 0.5 m · Esc stop" % [
		_armed["name"], _yaw_steps * 90, _storey]

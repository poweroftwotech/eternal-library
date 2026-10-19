@tool
extends VBoxContainer
## Sockets section of the Kit dock (ENVIRONMENT_PLAN.md 4.3, phase 1 step 0).
##
## Top: the VariantSockets of the selected module (or of anything selected
## inside one). Bottom: every socket in the open RoomTemplate, with its pins.
## Prev / Next / Random / Pin write RoomTemplate.socket_pins through the editor
## undo history, so a pin is saved with the room and never needs Editable
## Children on the module.

var undo_redo: EditorUndoRedoManager

var _sel_title: Label
var _sel_rows: VBoxContainer
var _room_title: Label
var _room_rows: VBoxContainer
var _clear_all: Button
var _refresh_queued: bool = false


func _init() -> void:
	name = "Sockets"
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var head := Label.new()
	head.text = "Sockets"
	head.theme_type_variation = &"HeaderSmall"
	add_child(head)
	_sel_title = Label.new()
	_sel_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_sel_title)
	_sel_rows = VBoxContainer.new()
	add_child(_sel_rows)
	add_child(HSeparator.new())
	var room_bar := HBoxContainer.new()
	_room_title = Label.new()
	_room_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_room_title.clip_text = true
	room_bar.add_child(_room_title)
	_clear_all = Button.new()
	_clear_all.text = "Clear all pins"
	_clear_all.tooltip_text = "Remove every socket pin in this room, including pins whose module is gone (undoable)."
	_clear_all.pressed.connect(_on_clear_all)
	room_bar.add_child(_clear_all)
	add_child(room_bar)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_room_rows = VBoxContainer.new()
	_room_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_room_rows)
	add_child(scroll)


func _ready() -> void:
	EditorInterface.get_selection().selection_changed.connect(queue_refresh)
	if undo_redo != null:
		undo_redo.history_changed.connect(queue_refresh)
		undo_redo.version_changed.connect(queue_refresh)
	queue_refresh()


func _exit_tree() -> void:
	var sel: EditorSelection = EditorInterface.get_selection()
	if sel.selection_changed.is_connected(queue_refresh):
		sel.selection_changed.disconnect(queue_refresh)
	if undo_redo != null and undo_redo.history_changed.is_connected(queue_refresh):
		undo_redo.history_changed.disconnect(queue_refresh)
		undo_redo.version_changed.disconnect(queue_refresh)


## Rebuilds the rows once, after the current signal (rows may own the button
## that triggered the change).
func queue_refresh() -> void:
	if _refresh_queued:
		return
	_refresh_queued = true
	_refresh.call_deferred()


func _refresh() -> void:
	_refresh_queued = false
	if not is_inside_tree():
		return
	_clear_rows(_sel_rows)
	_clear_rows(_room_rows)
	var room: RoomTemplate = EditorInterface.get_edited_scene_root() as RoomTemplate
	if room == null:
		_sel_title.text = "Open a room (RoomTemplate root) to see and pin its sockets."
		_room_title.text = ""
		_clear_all.disabled = true
		return

	var picked: Array[VariantSocket] = []
	var focus: Node = _selection_focus(room)
	if focus == null:
		_sel_title.text = "Select a module to list its sockets."
	else:
		_collect(focus, picked)
		_sel_title.text = "%s: %s" % [focus.name, "%d socket(s)" % picked.size() if not picked.is_empty() else "no sockets"]
		for s: VariantSocket in picked:
			_sel_rows.add_child(_row(room, s, false))

	var all: Array[VariantSocket] = room.sockets()
	var stale: PackedStringArray = room.stale_pins()
	_room_title.text = "Room: %d sockets · %d pinned%s" % [
		all.size(), room.socket_pins.size(), " (%d stale)" % stale.size() if not stale.is_empty() else ""]
	_clear_all.disabled = room.socket_pins.is_empty()
	for s: VariantSocket in all:
		_room_rows.add_child(_row(room, s, true))
	for key: String in stale:
		_room_rows.add_child(_stale_row(room, key))


## The module (or free-standing socket) the user is working on, or null.
func _selection_focus(room: RoomTemplate) -> Node:
	var nodes: Array[Node] = EditorInterface.get_selection().get_selected_nodes()
	if nodes.is_empty():
		return null
	var node: Node = nodes[0]
	if node == room or not room.is_ancestor_of(node):
		return null
	var p: Node = node
	while p != null and p != room:
		if p is KitModule or p is VariantSocket:
			return p
		p = p.get_parent()
	return node


func _collect(node: Node, out: Array[VariantSocket]) -> void:
	if node is VariantSocket:
		out.append(node as VariantSocket)
		return
	for child: Node in node.get_children():
		_collect(child, out)


func _clear_rows(box: Container) -> void:
	for child: Node in box.get_children():
		box.remove_child(child)
		child.queue_free()


func _row(room: RoomTemplate, s: VariantSocket, with_path: bool) -> Control:
	var key: String = room.socket_key(s)
	var pin: int = room.socket_pins.get(key, -1)
	var n: int = s.candidate_count()
	var box := VBoxContainer.new()
	if with_path:
		var path := Button.new()
		path.flat = true
		path.alignment = HORIZONTAL_ALIGNMENT_LEFT
		path.clip_text = true
		path.text = _short(key)
		path.tooltip_text = "%s\nClick to select its module." % key
		path.pressed.connect(_select_owner.bind(room, s))
		box.add_child(path)
	var line := HBoxContainer.new()
	var pick := Label.new()
	pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pick.clip_text = true
	var how: String = "room pin" if pin >= 0 else ("module pin" if s.effective_pin() >= 0 else "seed")
	pick.text = "%s  (%d/%d, %s)" % [s.picked_label(), s.last_pick + 1, n, how]
	pick.tooltip_text = "%s\nset: %s" % [key, s.socket_set.resource_path if s.socket_set != null else "(none)"]
	line.add_child(pick)
	line.add_child(_button("PagePrevious", "Previous candidate (pins it)", n > 0, _on_step.bind(room, s, -1)))
	line.add_child(_button("PageNext", "Next candidate (pins it)", n > 0, _on_step.bind(room, s, 1)))
	line.add_child(_button("RandomNumberGenerator", "Random candidate by weight (pins it)", n > 1, _on_random.bind(room, s)))
	var pin_box := CheckBox.new()
	pin_box.text = "Pin"
	pin_box.tooltip_text = "Keep this candidate in this room whatever the seed. Untick to let the seed choose."
	pin_box.button_pressed = pin >= 0
	pin_box.disabled = n == 0
	pin_box.toggled.connect(_on_pin_toggled.bind(room, s))
	line.add_child(pin_box)
	box.add_child(line)
	return box


func _stale_row(room: RoomTemplate, key: String) -> Control:
	var line := HBoxContainer.new()
	var label := Label.new()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.clip_text = true
	label.text = "Missing: %s" % _short(key)
	label.tooltip_text = "%s\nPinned to entry %d, but no socket exists at this path (module renamed, moved or deleted)." % [key, room.socket_pins[key]]
	line.add_child(label)
	line.add_child(_button("Clear", "Remove this stale pin (undoable)", true, _set_pin.bind(room, key, -1)))
	return line


## `text` is an editor icon name when the editor theme has one, else the caption.
func _button(text: String, tip: String, enabled: bool, action: Callable) -> Button:
	var b := Button.new()
	var theme: Theme = EditorInterface.get_editor_theme()
	if theme != null and theme.has_icon(text, &"EditorIcons"):
		b.icon = theme.get_icon(text, &"EditorIcons")
	else:
		b.text = text
	b.tooltip_text = tip
	b.disabled = not enabled
	b.pressed.connect(action)
	return b


func _short(key: String) -> String:
	return key.trim_prefix("Shell/")


# --- actions (all undoable, all write RoomTemplate.socket_pins) ---------------

func _on_step(room: RoomTemplate, s: VariantSocket, delta: int) -> void:
	var n: int = s.candidate_count()
	var from: int = s.last_pick if s.last_pick >= 0 else (0 if delta > 0 else n)
	_set_pin(room, room.socket_key(s), posmod(from + delta, n))


func _on_random(room: RoomTemplate, s: VariantSocket) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var idx: int = s.last_pick
	for _i: int in 16:
		idx = s.socket_set.pick(rng)
		if idx != s.last_pick:
			break
	_set_pin(room, room.socket_key(s), idx)


func _on_pin_toggled(on: bool, room: RoomTemplate, s: VariantSocket) -> void:
	_set_pin(room, room.socket_key(s), maxi(s.last_pick, 0) if on else -1)


func _on_clear_all() -> void:
	var room: RoomTemplate = EditorInterface.get_edited_scene_root() as RoomTemplate
	if room == null or room.socket_pins.is_empty():
		return
	var empty: Dictionary[String, int] = {}
	_commit(room, empty, "Clear all socket pins")


## idx -1 removes the pin.
func _set_pin(room: RoomTemplate, key: String, idx: int) -> void:
	var pins: Dictionary[String, int] = {}
	pins.assign(room.socket_pins)
	if idx < 0:
		pins.erase(key)
	else:
		pins[key] = idx
	_commit(room, pins, "Pin socket %s" % _short(key) if idx >= 0 else "Unpin socket %s" % _short(key))


func _commit(room: RoomTemplate, pins: Dictionary[String, int], label: String) -> void:
	var old: Dictionary[String, int] = {}
	old.assign(room.socket_pins)
	if undo_redo == null:
		room.socket_pins = pins
		queue_refresh()
		return
	undo_redo.create_action(label, UndoRedo.MERGE_DISABLE, room)
	undo_redo.add_do_property(room, "socket_pins", pins)
	undo_redo.add_undo_property(room, "socket_pins", old)
	undo_redo.commit_action()


func _select_owner(room: RoomTemplate, s: VariantSocket) -> void:
	var target: Node = s
	var p: Node = s
	while p != null and p != room:
		if p.owner == room:     # first ancestor the room itself saves = selectable
			target = p
			break
		p = p.get_parent()
	var sel: EditorSelection = EditorInterface.get_selection()
	sel.clear()
	sel.add_node(target)
	EditorInterface.edit_node(target)

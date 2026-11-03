class_name MapPage
extends CanvasLayer
## The map (phase 11): M opens it and the game pauses. It draws what you have
## seen of a place (MapCanvas) and keeps it in the save (WorldState.map_*), as
## you enter rooms and see into others through their doorways.
##
## Layout: CanvasLayer → MarginContainer (full screen) → PanelContainer (the
## page's ground, its content margin the page margin) → VBoxContainer:
##   header (place name; the floor tabs), body (the places you know and the key;
##   the sheet), footer (keys). The sheet is a SubViewportContainer drawing the
##   MapCanvas at half resolution, doubled: it reads as pixels like the game.
##
## Step 1 draws the interiors; the Gorge and the camp come in step 2.

const PAPER: Texture2D = preload("res://assets/textures/map_paper.png")
const HEAD := Color("c8ac70")
const TEXT := Color("e6dcc3")
const HINT := Color("a99d80")
const PANEL_BG := Color("17262b")
const PANEL_BORDER := Color("7c724f")
const PICKED_BG := Color("294042")
## Seconds between looks at which room you are in.
const NOTE_EVERY: float = 0.25
const ZOOM_MIN: float = 1.2
const ZOOM_MAX: float = 12.0

## The game (main.gd).
var game: Node
var ui_theme: Theme
var canvas: MapCanvas
## The place shown, and the place you're in ("" outside an area).
var shown_id: String = ""
var here_id: String = ""
var _title: Label
var _tabs: HBoxContainer
var _places: VBoxContainer
var _since_note: float = 0.0
var _dragging: bool = false
var _was_blocked: bool = false


func _ready() -> void:
	layer = 11     # over the HUD (10)
	process_mode = Node.PROCESS_MODE_ALWAYS
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if ui_theme != null:
		margin.theme = ui_theme
	add_child(margin)
	var shade := PanelContainer.new()     # the page's ground, over the paused game
	shade.add_theme_stylebox_override("panel", _box(Color(0.047, 0.09, 0.106), Color(0, 0, 0, 0), 36))
	margin.add_child(shade)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 14)
	shade.add_child(page)
	# Header: the place's name, the floors.
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 24)
	page.add_child(header)
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", 0)
	header.add_child(names)
	names.add_child(_label("STRATUM 1  ·  MAP", 16, HINT))
	_title = _label("", 34, TEXT)
	names.add_child(_title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 8)
	_tabs.size_flags_vertical = Control.SIZE_SHRINK_END
	header.add_child(_tabs)
	# Body: places and key | the sheet.
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(body)
	var side_col := VBoxContainer.new()
	side_col.add_theme_constant_override("separation", 14)
	side_col.custom_minimum_size.x = 270
	body.add_child(side_col)
	var places_panel := _panel()
	side_col.add_child(places_panel)
	_places = VBoxContainer.new()
	_places.add_theme_constant_override("separation", 8)
	places_panel.add_child(_places)
	var key_panel := _panel()
	side_col.add_child(key_panel)
	var key := VBoxContainer.new()
	key.add_theme_constant_override("separation", 8)
	key_panel.add_child(key)
	key.add_child(_label("Key", 20, HEAD))
	for row: Array in [["room", "A room you've been in"], ["seen", "Seen through a doorway"], ["loose", "A way you haven't taken"],
			["door", "Door to another place"], ["shut", "A shut door"], ["you", "You"]]:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 10)
		var icon := KeyIcon.new()
		icon.kind = row[0]
		line.add_child(icon)
		line.add_child(_label(row[1], 17, TEXT))
		key.add_child(line)
	var sheet := SubViewportContainer.new()
	sheet.stretch = true
	sheet.stretch_shrink = 2
	sheet.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sheet.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sheet.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(sheet)
	var vp := SubViewport.new()
	vp.transparent_bg = true
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	sheet.add_child(vp)
	canvas = MapCanvas.new()
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.paper = PAPER
	canvas.font = ui_theme.default_font if ui_theme != null and ui_theme.default_font != null else ThemeDB.fallback_font
	canvas.gui_input.connect(_on_sheet_input)
	vp.add_child(canvas)
	# Footer: the keys.
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 28)
	page.add_child(footer)
	for k: Array in [["M", "close"], ["drag", "move"], ["wheel", "zoom"], ["C", "back to you"], ["Tab", "next floor"]]:
		footer.add_child(_label("[%s] %s" % k, 18, HINT))
	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(fill)
	footer.add_child(_label("The game is paused", 18, HINT))
	visible = false


func is_open() -> bool:
	return visible


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func open() -> void:
	if visible or game == null or game.hud.modal_open or (game.report != null and game.report.is_open()):
		return
	_note_room()
	_was_blocked = game.player.blocked
	game.player.blocked = true
	game.world.set_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	visible = true
	show_place(here_id if here_id != "" else (ws().map_places()[-1] if not ws().map_places().is_empty() else ""), true)


func close() -> void:
	if not visible:
		return
	visible = false
	game.player.blocked = _was_blocked
	game.world.set_process(true)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(delta: float) -> void:
	if visible or game == null or game.player == null:
		return
	_since_note += delta
	if _since_note >= NOTE_EVERY:
		_since_note = 0.0
		_note_room()


## The room you are in, and the rooms you see into from it, into the save.
func _note_room() -> void:
	var a: Area = _area_here()
	if a == null:
		here_id = ""
		return
	here_id = a.recipe.id
	var r: AreaPlan.Room = a.room_at(game.player.global_position)
	if r == null:
		return     # a doorway: neither room
	if a.plan.visible.is_empty():
		a.plan.compute_sight()
	var plan: AreaPlan = a.plan
	if ws().map_known(here_id).get("name", "") == "" or int(ws().map_known(here_id).get("recipe_version", -1)) != plan.recipe_version:
		ws().set_map_name(here_id, plan.recipe_version, a.recipe.display_name, plan.rooms[0].storey if not plan.rooms.is_empty() else 0)
	ws().map_note(here_id, plan.recipe_version, r.slot_id, plan.visible.get(r.slot_id, PackedStringArray()),
		func(s: String) -> Dictionary: return MapCanvas.sketch_of(plan.room(s)))


## The area you are standing in (the place loaded, or one SeamlessPlaces streams in).
func _area_here() -> Area:
	var candidates: Array = [game.world]
	if game.seamless != null:
		candidates.append_array((game.seamless.places as Dictionary).values())
	for n: Variant in candidates:
		if n is Area and is_instance_valid(n) and (n as Area).plan != null and (n as Area).room_at(game.player.global_position) != null:
			return n
	return game.world as Area


## Shows place `id` on the sheet; `centre_on_you` puts you (or its rooms) in the middle.
func show_place(id: String, centre_on_you: bool = false) -> void:
	shown_id = id
	var known: Dictionary = ws().map_known(id) if id != "" else {}
	canvas.place_id = id
	canvas.rooms = []
	canvas.note = ""
	canvas.you = {}
	_title.text = _place_title(id) if id != "" else "Nowhere yet"
	if id == "":
		canvas.note = "Nothing drawn yet: walk into a room."
	elif id == "gorge":
		canvas.note = "The Gorge goes on the map in step 2."
	else:
		var sketches: Dictionary = known.get("rooms", {})
		for slot: String in sketches:
			canvas.rooms.append(MapCanvas.sketch_from(slot, sketches[slot]))
		canvas.entered = _set_of(known.get("entered", []))
		canvas.seen = _set_of(known.get("seen", []))
		canvas.door_labels = _door_labels(id)
		var floors: Array[int] = canvas.storeys()
		canvas.storey = int(known.get("floor", 0))
		var a: Area = _area_here()
		if id == here_id and a != null:
			var local: Vector3 = a.to_local(game.player.global_position)
			var fwd: Vector3 = a.global_transform.basis.inverse() * -game.player.global_transform.basis.z
			canvas.you = {"pos": local, "dir": Vector2(fwd.x, fwd.z).normalized(), "storey": storey_of(a.plan, local)}
			if centre_on_you:
				canvas.storey = canvas.you["storey"]
		if not floors.is_empty() and not floors.has(canvas.storey):
			canvas.storey = floors[0]
		canvas.centre = Vector2(canvas.you["pos"].x, canvas.you["pos"].z) if not canvas.you.is_empty() and centre_on_you else canvas.middle()
	_fill_places()
	_fill_tabs()
	canvas.queue_redraw()


## The storey the map shows you on at area point `local`: the floor of the
## room you are in there (a cistern's sunk floor or a stair's landing
## counts as its room's), else the storey of the point.
static func storey_of(plan: AreaPlan, local: Vector3) -> int:
	var at: int = AreaPlan.cell_of(local).y
	var r: AreaPlan.Room = plan.room_at(local)
	if r == null:
		r = plan.room_at(local + Vector3(0, 3.0, 0))     # a floor sunk below its storey (the cistern's water)
	if r == null:
		return at
	var floors: Array = r.floor_cells.keys().map(func(c: Vector3i) -> int: return c.y)
	if floors.has(at):
		return at
	var best: int = r.storey
	for s: int in floors:
		if absi(s - at) < absi(best - at):
			best = s
	return best


func _set_floor(s: int) -> void:
	canvas.storey = s
	var known: Dictionary = ws().map_known(shown_id)
	if not known.is_empty():
		ws().set_map_floor(shown_id, int(known["recipe_version"]), s)
	_fill_tabs()
	canvas.queue_redraw()


func _fill_places() -> void:
	for c: Node in _places.get_children():
		c.queue_free()
	_places.add_child(_label("Places you know", 20, HEAD))
	for id: String in ws().map_places():
		var b := Button.new()
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size.y = 44
		b.text = _place_title(id) + ("\n  you are here" if id == here_id else "")
		b.add_theme_font_size_override("font_size", 20)
		if id == shown_id:
			b.add_theme_stylebox_override("normal", _box(PICKED_BG, HEAD, 8))
		b.pressed.connect(show_place.bind(id, id == here_id))
		_places.add_child(b)


func _fill_tabs() -> void:
	for c: Node in _tabs.get_children():
		c.queue_free()
	var floors: Array[int] = canvas.storeys()
	if floors.size() < 2:
		return
	var ground: int = int(ws().map_known(shown_id).get("ground", 0))
	for s: int in floors:
		var b := Button.new()
		b.text = floor_name(s - ground)
		b.custom_minimum_size.y = 44
		b.add_theme_font_size_override("font_size", 20)
		if s == canvas.storey:
			b.add_theme_stylebox_override("normal", _box(PICKED_BG, HEAD, 8))
		b.pressed.connect(_set_floor.bind(s))
		_tabs.add_child(b)


## A storey's name, counted from the place's entrance.
static func floor_name(up: int) -> String:
	const WORDS: Array[String] = ["", "One", "Two", "Three", "Four"]
	if up == 0:
		return "Ground floor"
	var n: int = absi(up)
	var count: String = WORDS[n] if n < WORDS.size() else str(n)
	return "%s floor%s %s" % [count, "" if n == 1 else "s", "up" if up > 0 else "down"]


func _on_sheet_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_RIGHT:
			_dragging = mb.pressed
		elif mb.pressed and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			var before: Vector2 = canvas.to_map(mb.position)
			canvas.zoom = clampf(canvas.zoom * (1.15 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.15), ZOOM_MIN, ZOOM_MAX)
			canvas.centre += before - canvas.to_map(mb.position)     # zoom about the pointer
			canvas.queue_redraw()
	elif event is InputEventMouseMotion and _dragging:
		canvas.centre -= (event as InputEventMouseMotion).relative / canvas.zoom
		canvas.queue_redraw()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("map") or event.is_action_pressed("ui_cancel"):
		close()
	elif event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).physical_keycode == KEY_TAB:
		var floors: Array[int] = canvas.storeys()
		if floors.size() > 1:
			_set_floor(floors[(floors.find(canvas.storey) + 1) % floors.size()])
	elif event is InputEventKey and event.pressed and (event as InputEventKey).physical_keycode == KEY_C:
		show_place(here_id, true)
	else:
		return
	get_viewport().set_input_as_handled()


## What each door to another place in place `id` says: "to the Gorge" once
## you have been there (the map knows its name), else "?".
func _door_labels(id: String) -> Dictionary:
	var out: Dictionary = {}
	var stratum: StratumPlan = StratumPlan.current()
	var sketches: Dictionary = ws().map_known(id).get("rooms", {})
	for slot: String in sketches:
		for door: Variant in (sketches[slot] as Dictionary).get("doors", []):
			if str(door["kind"]) == "threshold":
				var to: String = str(door.get("to", ""))
				var target: String = stratum.door_target(id, to)
				var shown: String = _place_title(target) if target == "camp" or ws().map_places().has(target) else ""
				out[to] = "to " + (("the " + shown.substr(4)) if shown.begins_with("The ") else shown) if shown != "" else "?"
	return out


## A place's name as the map wrote it down when you were there (no recipe
## is loaded for it: that pulled in all its rooms, 70 ms a place).
func _place_title(id: String) -> String:
	if id == "camp":
		return "The camp"
	var shown: String = str(ws().map_known(id).get("name", ""))
	return shown if shown != "" else id.capitalize()


static func _set_of(list: Array) -> Dictionary:
	var out: Dictionary = {}
	for s: Variant in list:
		out[str(s)] = true
	return out


func _label(text: String, font_size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", col)
	return l


func _panel() -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _box(PANEL_BG, PANEL_BORDER, 14))
	return p


static func _box(bg: Color, border: Color, pad: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(2 if border.a > 0.0 else 0)
	s.set_content_margin_all(pad)
	return s


func ws() -> Node:
	return get_node("/root/WorldState")


## A small drawing for a line of the key, in the sheet's ink and paper.
class KeyIcon:
	extends Control
	var kind: String = ""

	func _ready() -> void:
		custom_minimum_size = Vector2(34, 20)

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("d4bb8a"))
		var mid: Vector2 = size * 0.5
		match kind:
			"room":
				draw_rect(Rect2(3, 3, size.x - 6, size.y - 6), MapCanvas.WASH)
				draw_rect(Rect2(3, 3, size.x - 6, size.y - 6), MapCanvas.INK, false, 2.0)
			"seen":
				for side: Array in [[Vector2(3, 3), Vector2(size.x - 3, 3)], [Vector2(size.x - 3, 3), Vector2(size.x - 3, size.y - 3)],
						[Vector2(size.x - 3, size.y - 3), Vector2(3, size.y - 3)], [Vector2(3, size.y - 3), Vector2(3, 3)]]:
					draw_dashed_line(side[0], side[1], MapCanvas.PENCIL, 2.0, 4.0)
			"loose":
				draw_dashed_line(Vector2(4, mid.y), Vector2(20, mid.y), MapCanvas.INK, 2.0, 3.0)
				draw_arc(Vector2(25, mid.y), 5.0, 0.0, TAU, 16, MapCanvas.INK, 2.0)
			"door":
				draw_rect(Rect2(9, mid.y - 4, 16, 8), MapCanvas.INK)
			"shut":
				draw_rect(Rect2(7, mid.y - 5, 20, 10), MapCanvas.INK)
				draw_rect(Rect2(9, mid.y - 2, 16, 4), MapCanvas.SHUT)
			"you":
				draw_colored_polygon(PackedVector2Array([Vector2(26, mid.y), Vector2(12, mid.y - 7), Vector2(15, mid.y), Vector2(12, mid.y + 7)]), MapCanvas.RUST)

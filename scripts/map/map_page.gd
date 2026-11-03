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
## Interiors are drawn from their rooms (step 1); the Gorge and the camp from
## their traces (MapTrace, step 2), revealed a tile at a time as you walk.

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
## A traced place (the Gorge, the camp: MapTrace) shows the tiles within
## WALK_REVEAL m of where you walk in ink, and those within its SIGHT_REVEAL
## m in pencil (the Gorge is open: you see far down it; the camp has walls).
const WALK_REVEAL: float = 14.0
const SIGHT_REVEAL: Dictionary = {"gorge": 40.0}
## Its pixels a metre when you open it: a 0.5 m sample to whole pixels.
const TRACE_ZOOM: Dictionary = {"gorge": 2.0, "camp": 4.0}
## The whole stratum (step 3): what shown_id says when it's on the sheet,
## its pixels a metre when it opens, and how far it zooms out.
const STRATUM: String = "*stratum"
const STRATUM_ZOOM: float = 1.0
const STRATUM_ZOOM_MIN: float = 0.3
## A 3D half turn about Y, seen from above: a door back faces the door it meets.
const TURN := Transform2D(Vector2(-1, 0), Vector2(0, -1), Vector2.ZERO)
## Your marks' symbols, and how near (sheet pixels) a right-click picks one.
const SYMBOLS: Array[String] = ["star", "cross", "question", "lamp"]
const MARK_PICK: float = 7.0

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
## Traces (id -> MapTrace or null) and their images, loaded once.
var _traces: Dictionary = {}
var _ink: Dictionary = {}
var _pencil: Dictionary = {}
## The mark panel: its symbol buttons (symbol -> MarkButton), the note, Remove.
var _mark_panel: PanelContainer
var _symbol_buttons: Dictionary = {}
var _note: LineEdit
var _mark_remove: Button
## Where a right-click went down (a mark if it comes up there, not a drag).
var _right_from: Vector2 = Vector2.ZERO


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
			["door", "Door to another place"], ["shut", "A shut door"], ["you", "You"], ["mark", "Your mark"]]:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 10)
		var icon := KeyIcon.new()
		icon.kind = row[0]
		line.add_child(icon)
		line.add_child(_label(row[1], 17, TEXT))
		key.add_child(line)
	# The mark being placed or changed (right-click on the sheet).
	_mark_panel = _panel()
	_mark_panel.visible = false
	side_col.add_child(_mark_panel)
	var mark_box := VBoxContainer.new()
	mark_box.add_theme_constant_override("separation", 8)
	_mark_panel.add_child(mark_box)
	mark_box.add_child(_label("Your mark", 20, HEAD))
	var symbols := HBoxContainer.new()
	symbols.add_theme_constant_override("separation", 6)
	mark_box.add_child(symbols)
	for s: String in SYMBOLS:
		var b := MarkButton.new()
		b.symbol = s
		b.toggle_mode = true
		b.pressed.connect(_pick_symbol.bind(s))
		symbols.add_child(b)
		_symbol_buttons[s] = b
	_note = LineEdit.new()
	_note.placeholder_text = "A note (optional)"
	_note.max_length = 40
	_note.add_theme_font_size_override("font_size", 18)
	_note.text_submitted.connect(func(_t: String) -> void: _keep_mark())
	mark_box.add_child(_note)
	var acts := HBoxContainer.new()
	acts.add_theme_constant_override("separation", 6)
	mark_box.add_child(acts)
	for a: Array in [["Keep", _keep_mark], ["Remove", _remove_mark], ["Cancel", _end_mark]]:
		var b := Button.new()
		b.text = a[0]
		b.add_theme_font_size_override("font_size", 18)
		b.pressed.connect(a[1])
		acts.add_child(b)
		if a[0] == "Remove":
			_mark_remove = b
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
	for k: Array in [["M", "close"], ["drag", "move"], ["wheel", "zoom"], ["right-click", "mark"], ["C", "back to you"], ["Tab", "next floor"]]:
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


## The room you are in, and the rooms you see into from it, into the save;
## in a traced place, the tiles near you.
func _note_room() -> void:
	var traced: Array = _traced_here()
	if not traced.is_empty():
		here_id = traced[0]
		var t: MapTrace = trace_of(here_id)
		var local: Vector3 = (traced[1] as Node3D).to_local(game.player.global_position)
		var m := Vector2(local.x, local.z)
		ws().map_reveal(here_id, t.stamp(), _traced_name(traced[1]), t.tiles_near(m, WALK_REVEAL), t.tiles_near(m, float(SIGHT_REVEAL.get(here_id, WALK_REVEAL))))
		return
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


## The traced place you are in (the Gorge, the camp) and its node: [id, Node3D], or [].
func _traced_here() -> Array:
	var id: String = ""
	if game.seamless != null and game.seamless.place_id != "":
		id = game.seamless.place_id
	elif game.world is Area:
		id = (game.world as Area).recipe.id
	elif game.world is CampRoom:
		id = "camp"
	if id == "" or trace_of(id) == null or not is_instance_valid(game.world):
		return []
	return [id, game.world]


## The trace of place `id` (null: not a traced place), loaded once.
func trace_of(id: String) -> MapTrace:
	if not _traces.has(id):
		var path: String = MapTrace.path_of(id)
		_traces[id] = load(path) as MapTrace if ResourceLoader.exists(path) else null
		if _traces[id] != null:
			_ink[id] = load(MapTrace.ink_path(id))
			_pencil[id] = load(MapTrace.pencil_path(id))
	return _traces[id]


func _traced_name(place: Node3D) -> String:
	return (place as Area).recipe.display_name if place is Area else "The camp"


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
	_end_mark()
	var was: String = canvas.place_id if canvas.layers.is_empty() else STRATUM
	shown_id = id
	canvas.layers = []
	canvas.links = []
	canvas.note = ""
	canvas.use(layer_of(id))
	canvas.you = _you_in(id)
	_title.text = _place_title(id) if id != "" else "Nowhere yet"
	if id == "":
		canvas.note = "Nothing drawn yet: walk into a room."
	elif canvas.trace != null:
		if centre_on_you or was != id:
			canvas.zoom = float(TRACE_ZOOM.get(id, 2.0))     # a sample to a whole number of pixels
	else:
		var floors: Array[int] = canvas.storeys()
		if centre_on_you and not canvas.you.is_empty():
			canvas.storey = canvas.you["storey"]
		if not floors.is_empty() and not floors.has(canvas.storey):
			canvas.storey = floors[0]
		if was == STRATUM:
			canvas.zoom = 3.25
	canvas.centre = Vector2(canvas.you["pos"].x, canvas.you["pos"].z) if not canvas.you.is_empty() and centre_on_you else canvas.middle()
	_fill_places()
	_fill_tabs()
	canvas.queue_redraw()


## What the sheet needs to draw place `id` (MapCanvas.use): from the save
## alone, so a place you aren't in shows at once.
func layer_of(id: String) -> Dictionary:
	var known: Dictionary = ws().map_known(id) if id != "" else {}
	var rooms: Array[MapCanvas.Sketch] = []
	var layer: Dictionary = {"id": id, "name": _place_title(id), "rooms": rooms, "entered": {}, "seen": {}, "storey": int(known.get("floor", 0)),
		"trace": null, "ink": null, "pencil": null, "walked": {}, "sighted": {}, "door_labels": {}, "marks": marks_of(id)}
	var t: MapTrace = trace_of(id) if id != "" else null
	if t != null:
		var same: bool = str(known.get("trace", "")) == t.stamp()     # a re-trace tiles differently
		layer.merge({"trace": t, "ink": _ink[id], "pencil": _pencil[id], "walked": _set_of_ints(known.get("walked", []) if same else []),
			"sighted": _set_of_ints(known.get("sighted", []) if same else []), "door_labels": _trace_door_labels(id, t)}, true)
	elif id != "":
		var sketches: Dictionary = known.get("rooms", {})
		for slot: String in sketches:
			rooms.append(MapCanvas.sketch_from(slot, sketches[slot]))
		layer.merge({"entered": _set_of(known.get("entered", [])), "seen": _set_of(known.get("seen", [])), "door_labels": _door_labels(id)}, true)
	return layer


## Where you are in place `id` ({} = not there): {pos (its frame), dir (x, z), storey}.
func _you_in(id: String) -> Dictionary:
	if id == "" or id != here_id:
		return {}
	var place: Node3D = null
	var at_storey: Callable = func(_l: Vector3) -> int: return 0
	var traced: Array = _traced_here()
	if not traced.is_empty():
		place = traced[1]
	else:
		var a: Area = _area_here()
		if a == null:
			return {}
		place = a
		at_storey = func(l: Vector3) -> int: return storey_of(a.plan, l)
	var local: Vector3 = place.to_local(game.player.global_position)
	var fwd: Vector3 = place.global_transform.basis.inverse() * -game.player.global_transform.basis.z
	return {"pos": local, "dir": Vector2(fwd.x, fwd.z).normalized(), "storey": at_storey.call(local)}


## Every place you know at once, each where it lies (stratum_frames), the
## ones linked by a door joined by a line between the two doors; their
## names; you. `centre` (metres, the Gorge's frame) goes in the middle.
func show_stratum(centre: Variant = null) -> void:
	_end_mark()
	shown_id = STRATUM
	_title.text = "The whole stratum"
	var frames: Dictionary = stratum_frames()
	var layers: Array[Dictionary] = []
	for id: String in ws().map_places():
		if not frames.has(id):
			continue
		var layer: Dictionary = layer_of(id)
		layer["frame"] = frames[id]
		layer["storey"] = int(ws().map_known(id).get("ground", 0)) if layer["trace"] == null else 0
		canvas.use(layer)
		var ext: Rect2 = canvas.extent()
		layer["label_at"] = Vector2(ext.get_center().x, ext.position.y)
		layers.append(layer)
	canvas.layers = layers
	canvas.links = []
	for l: Array in StratumPlan.current().triples():
		if frames.has(l[0]) and frames.has(l[1]):
			var a: Variant = door_xf(l[0], l[1])
			var b: Variant = door_xf(l[1], l[0])
			if a != null and b != null:
				canvas.links.append([(frames[l[0]] as Transform2D) * (a as Transform2D).origin, (frames[l[1]] as Transform2D) * (b as Transform2D).origin])
	var you: Dictionary = _you_in(here_id)
	canvas.you = {} if you.is_empty() or not frames.has(here_id) else {
		"at": (frames[here_id] as Transform2D) * Vector2(you["pos"].x, you["pos"].z), "dir": (frames[here_id] as Transform2D).basis_xform(you["dir"])}
	if centre != null:
		canvas.centre = centre
	elif not canvas.you.is_empty():
		canvas.centre = canvas.you["at"]
	canvas.zoom = minf(canvas.zoom, STRATUM_ZOOM)
	_fill_places()
	_fill_tabs()
	canvas.queue_redraw()


## Where each place you know lies, in the Gorge's frame (x, z): the Gorge
## and the camp share it; a place behind a door is placed so its door back
## meets that door, through the vestibule from a Gorge door, as the
## continuous world places them (SeamlessPlaces._interior_frame). A place
## whose door back you haven't seen yet can't be placed.
func stratum_frames() -> Dictionary:
	var frames: Dictionary = {"gorge": Transform2D.IDENTITY, "camp": Transform2D.IDENTITY}
	var known: Array[String] = ws().map_places()
	var triples: Array = StratumPlan.current().triples()
	var grew: bool = true
	while grew:
		grew = false
		for l: Array in triples:
			for pair: Array in [[l[0], l[1]], [l[1], l[0]]]:
				var p: String = pair[0]
				var q: String = pair[1]
				if not frames.has(p) or frames.has(q) or not known.has(q):
					continue
				var dp: Variant = door_xf(p, q)
				var dq: Variant = door_xf(q, p)
				if dp == null or dq == null:
					continue
				var through: Transform2D = flat(Vestibule.EXIT) if p == "gorge" else Transform2D.IDENTITY
				frames[q] = (frames[p] as Transform2D) * (dp as Transform2D) * through * TURN * (dq as Transform2D).affine_inverse()
				grew = true
	return frames


## Place `id`'s door to place `to` in its frame, as a 2D frame (x, z; its y
## axis is the 3D +Z, into the room), or null if the map doesn't know it.
func door_xf(id: String, to: String) -> Variant:
	var stratum: StratumPlan = StratumPlan.current()
	var t: MapTrace = trace_of(id)
	if t != null:
		for d: Dictionary in t.doors:
			var target: String = str(d["to"]) if id == "camp" or str(d["raw"]) == "camp" else stratum.door_target(id, str(d["raw"]))
			if str(d["kind"]) == "threshold" and target == to:
				return xf_2d(d["at"], d["out"])
		return null
	var sketches: Dictionary = ws().map_known(id).get("rooms", {})
	for slot: String in sketches:
		for d: Variant in (sketches[slot] as Dictionary).get("doors", []):
			if str(d["kind"]) == "threshold" and stratum.door_target(id, str(d.get("to", ""))) == to:
				return xf_2d(Vector2(float(d["at"][0]), float(d["at"][1])), Vector2(float(d["out"][0]), float(d["out"][1])))
	return null


## A door's 3D frame seen from above: at its origin, -Z along `out`.
static func xf_2d(at: Vector2, out: Vector2) -> Transform2D:
	var o: Vector2 = out.normalized()
	return Transform2D(Vector2(-o.y, o.x), -o, at)


## A 3D frame turned about Y, seen from above (x, z).
static func flat(xf: Transform3D) -> Transform2D:
	return Transform2D(Vector2(xf.basis.x.x, xf.basis.x.z), Vector2(xf.basis.z.x, xf.basis.z.z), Vector2(xf.origin.x, xf.origin.z))


## Your marks on place `id`, for the sheet (MapCanvas.marks), each with its
## index in the save (`i`).
func marks_of(id: String) -> Array:
	var out: Array = []
	var all: Array = ws().map_marks()
	for i: int in all.size():
		var m: Dictionary = all[i]
		if str(m["place"]) == id:
			out.append({"at": Vector2(float(m["x"]), float(m["z"])), "storey": int(m["storey"]), "symbol": str(m["symbol"]), "note": str(m.get("note", "")), "i": i})
	return out


## Right-click on the sheet at `px`: change the mark there, or put a new one.
func _mark_at(px: Vector2) -> void:
	if shown_id == "" or shown_id == STRATUM:
		return
	_end_mark()
	var picked: int = -1
	for k: int in canvas.marks.size():
		var m: Dictionary = canvas.marks[k]
		if (canvas.trace != null or int(m["storey"]) == canvas.storey) and canvas.to_px(m["at"]).distance_to(px) <= MARK_PICK:
			picked = k
	if picked < 0:
		canvas.marks.append({"at": canvas.to_map(px), "storey": canvas.storey if canvas.trace == null else 0, "symbol": "star", "note": "", "i": -1})
		picked = canvas.marks.size() - 1
	canvas.picked_mark = picked
	var m: Dictionary = canvas.marks[picked]
	_pick_symbol(str(m["symbol"]))
	_note.text = str(m["note"])
	_mark_remove.visible = int(m["i"]) >= 0
	_mark_panel.visible = true
	_note.grab_focus()
	canvas.queue_redraw()


func _pick_symbol(symbol: String) -> void:
	for s: String in _symbol_buttons:
		(_symbol_buttons[s] as Button).set_pressed_no_signal(s == symbol)
	if canvas.picked_mark >= 0:
		canvas.marks[canvas.picked_mark]["symbol"] = symbol
		canvas.queue_redraw()


## Keeps the mark being placed or changed in the save.
func _keep_mark() -> void:
	if canvas.picked_mark < 0:
		return
	var m: Dictionary = canvas.marks[canvas.picked_mark]
	var kept: Dictionary = {"place": shown_id, "x": snappedf(m["at"].x, 0.01), "z": snappedf(m["at"].y, 0.01), "storey": int(m["storey"]),
		"symbol": str(m["symbol"]), "note": _note.text.strip_edges()}
	if int(m["i"]) >= 0:
		ws().set_map_mark(int(m["i"]), kept)
	else:
		ws().add_map_mark(kept)
	_end_mark()


func _remove_mark() -> void:
	if canvas.picked_mark >= 0 and int(canvas.marks[canvas.picked_mark]["i"]) >= 0:
		ws().remove_map_mark(int(canvas.marks[canvas.picked_mark]["i"]))
	_end_mark()


## Puts the mark panel away; the sheet shows the marks as saved.
func _end_mark() -> void:
	if _mark_panel == null:
		return
	_mark_panel.visible = false
	_note.release_focus()
	canvas.picked_mark = -1
	if canvas.layers.is_empty() and shown_id != "" and shown_id != STRATUM:
		canvas.marks = marks_of(shown_id)
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
	if not ws().map_places().is_empty():
		var all := Button.new()
		all.alignment = HORIZONTAL_ALIGNMENT_LEFT
		all.custom_minimum_size.y = 44
		all.text = "The whole stratum"
		all.add_theme_font_size_override("font_size", 20)
		if shown_id == STRATUM:
			all.add_theme_stylebox_override("normal", _box(PICKED_BG, HEAD, 8))
		all.pressed.connect(func() -> void: show_stratum())
		_places.add_child(all)
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
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_dragging = mb.pressed
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			if mb.pressed:
				_right_from = mb.position
			elif mb.position.distance_to(_right_from) < 4.0:
				_mark_at(mb.position)
		elif mb.pressed and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			var out: bool = mb.button_index == MOUSE_BUTTON_WHEEL_DOWN
			var lo: float = STRATUM_ZOOM_MIN if shown_id == STRATUM else ZOOM_MIN
			if out and canvas.zoom <= lo + 0.001 and shown_id != STRATUM and shown_id != "":
				# Out past a place: the whole stratum, about where you were looking.
				var frames: Dictionary = stratum_frames()
				if frames.has(shown_id):
					show_stratum((frames[shown_id] as Transform2D) * canvas.centre)
				return
			var before: Vector2 = canvas.to_map(mb.position)
			canvas.zoom = clampf(canvas.zoom * (1.0 / 1.15 if out else 1.15), lo, ZOOM_MAX)
			canvas.centre += before - canvas.to_map(mb.position)     # zoom about the pointer
			canvas.queue_redraw()
	elif event is InputEventMouseMotion and _dragging:
		canvas.centre -= (event as InputEventMouseMotion).relative / canvas.zoom
		canvas.queue_redraw()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if _mark_panel.visible and event.is_action_pressed("ui_cancel"):
		_end_mark()     # Esc puts the mark away, not the map
	elif _note.has_focus():
		return     # typing a note
	elif event.is_action_pressed("map") or event.is_action_pressed("ui_cancel"):
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
				out[to] = _door_says(stratum.door_target(id, to))
	return out


## What each door out of traced place `id` says (keyed by its connector's
## `to`): an area's doors lead where the stratum plan links them now.
func _trace_door_labels(id: String, t: MapTrace) -> Dictionary:
	var out: Dictionary = {}
	var stratum: StratumPlan = StratumPlan.current()
	for d: Dictionary in t.doors:
		if str(d["kind"]) != "threshold":
			continue
		var target: String = str(d["to"]) if id == "camp" or str(d["raw"]) == "camp" else stratum.door_target(id, str(d["raw"]))
		out[str(d["raw"])] = _door_says(target)
	return out


## "to the Gorge" once you have been to `target` (the camp: always), else "?".
func _door_says(target: String) -> String:
	if target != "camp" and not ws().map_places().has(target):
		return "?"
	var shown: String = _place_title(target)
	return "to " + (("the " + shown.substr(4)) if shown.begins_with("The ") else shown)


## A place's name as the map wrote it down when you were there (no recipe
## is loaded for it: that pulled in all its rooms, 70 ms a place).
func _place_title(id: String) -> String:
	if id == "camp":
		return "The camp"
	var shown: String = str(ws().map_known(id).get("name", ""))
	return shown if shown != "" else id.capitalize()


static func _set_of_ints(list: Array) -> Dictionary:
	var out: Dictionary = {}
	for t: Variant in list:
		out[int(t)] = true
	return out


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
			"mark":
				MapCanvas.draw_mark(self, mid, "star", MapCanvas.MARK)


## A mark's symbol to pick, drawn on a patch of the paper.
class MarkButton:
	extends Button
	var symbol: String = ""

	func _ready() -> void:
		custom_minimum_size = Vector2(52, 40)

	func _draw() -> void:
		var mid: Vector2 = size * 0.5
		draw_rect(Rect2(mid - Vector2(14, 12), Vector2(28, 24)), Color("d4bb8a"))
		MapCanvas.draw_mark(self, mid, symbol, MapCanvas.RUST if button_pressed else MapCanvas.MARK)

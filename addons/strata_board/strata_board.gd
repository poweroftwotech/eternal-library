@tool
extends VBoxContainer
## The Strata Board (phase 10, docs/environment/phase-10-approval.md; the
## mock: https://claude.ai/artifact/SMqnDsVcsPTSL8bCw9zD7Y). Step 1: look,
## don't edit. The stratum side-on, an area's recipe as a graph, the real
## planner's plan for one world seed (side-on and top-down) with its reasons,
## a 20-seed sweep, and Walk this seed.
##
## Everything it shows comes from the game's own planner, run by
## planner_client.gd (a headless process in the editor). Seeds here are world
## seeds, as in a save: each area's seed is AreaPlanner.area_seed_for(recipe,
## world seed), so a seed you see here is the world you get by typing it in.
##
## Layout (AGENTS.md 3): this VBox → header HBox, then a ScrollContainer → VBox
## of sections (PanelContainer → VBox). The stratum, recipe and plan pictures
## are drawn by StratumView, RecipeView and PlanView (custom _draw).

## Walk this seed: the plugin runs the game in `area_id` with `world_seed`.
signal walk_requested(area_id: String, world_seed: int)

const Client: GDScript = preload("res://addons/strata_board/planner_client.gd")
const SWEEP: int = 20
const AREA_FIRST: String = "lower_stacks"
const THUMB_PX: int = 4
const ORD: PackedStringArray = ["1st", "2nd", "3rd", "4th", "5th", "6th", "7th", "8th", "9th"]

const BG := Color("161925")
const PANEL := Color("1d2130")
const PANEL_2 := Color("242a3c")
const LINE := Color("343b52")
const FG := Color("e8e2d4")
const MUTED := Color("9a9fb3")
const BRASS := Color("d1a85a")
## Opaque (the tint over PANEL), so lines drawn behind a box don't show through it.
const BRASS_DIM := Color(0.227, 0.214, 0.214)
const TURQ := Color("5bbfb0")
const TURQ_DIM := Color(0.143, 0.203, 0.248)
const LAPIS := Color("7d9de0")
const BAD := Color("e37a6a")

## Editor scale (the plugin sets it); 1 in tests.
var ui_scale: float = 1.0
## Run the planner in this process (tests).
var local_planner: bool = false

var client: Node
var stratum: Dictionary = {}
var recipes: Dictionary = {}       # area id -> the service's recipe description
var area_id: String = ""
var world_seed: int = 1
var plan: Dictionary = {}          # the current seed's plan ({} while planning)
var sel: Dictionary = {}           # {panel: recipe | plan | stratum, id}
var sweep_base: int = 0            # 0: no sweep shown
var sweep_results: Dictionary = {} # world seed -> plan
var _sweep_ids: Array = []
var _plan_id: int = 0

var _seed_box: SpinBox
var _area_seed: Label
var _crumb: Label
var _sweep_button: Button
var _walk_button: Button
var _stratum_view: StratumView
var _recipe_view: RecipeView
var _recipe_note: Label
var _plan_head: Label
var _plan_view: PlanView
var _map: MapView
var _plan_status: RichTextLabel
var _sweep_panel: Control
var _sweep_bar: ProgressBar
var _sweep_flow: HFlowContainer
var _inspector: RichTextLabel
var _plan_box: Control


func _ready() -> void:
	client = Client.new()
	client.local = local_planner
	add_child(client)
	_build()
	reload()


## Reads the stratum and every recipe again from disk (hand edits since) and
## replans the current seed.
func reload() -> void:
	recipes.clear()
	plan = {}
	_clear_sweep()
	client.request({"cmd": "stratum"}, _on_stratum, true)


func _on_stratum(answer: Dictionary) -> void:
	if answer.has("error"):
		_set_status("[color=#%s]%s[/color]" % [BAD.to_html(false), answer["error"]])
		return
	stratum = answer
	for p: Dictionary in stratum["places"]:
		if str(p["kind"]) != "baked":
			client.request({"cmd": "recipe", "path": p["recipe"], "fresh": true}, _on_recipe.bind(str(p["id"])), true)
	if area_id == "":
		area_id = AREA_FIRST if _place(AREA_FIRST) != {} else str((stratum["places"] as Array)[0]["id"])
	_refresh()


func _on_recipe(answer: Dictionary, id: String) -> void:
	if answer.has("error"):
		push_warning("Strata Board: %s" % answer["error"])
		return
	recipes[id] = answer
	if id == area_id:
		_replan()
	_refresh()


# --- what the user does ---------------------------------------------------------

func open_area(id: String) -> void:
	if id == area_id or _place(id) == {}:
		return
	area_id = id
	sel = {}
	plan = {}
	_clear_sweep()
	_replan()
	_refresh()


func set_world_seed(s: int) -> void:
	s = maxi(s, 1)
	if s == world_seed and not plan.is_empty():
		return
	world_seed = s
	if _seed_box.value != s:
		_seed_box.set_value_no_signal(s)
	_replan()
	_refresh()


func start_sweep() -> void:
	if not _boardable():
		return
	if sweep_base != 0 and sweep_base == world_seed - (world_seed - 1) % SWEEP and _sweep_ids.is_empty():
		_clear_sweep()     # pressed again on a finished sweep of these seeds: hide it
		_refresh()
		return
	_clear_sweep()
	sweep_base = world_seed - (world_seed - 1) % SWEEP
	var path: String = recipes[area_id]["path"]
	for s: int in range(sweep_base, sweep_base + SWEEP):
		var id: int = client.request({"cmd": "plan", "path": path, "world_seed": s, "map_px": THUMB_PX}, _on_sweep_plan.bind(s))
		_sweep_ids.append(id)
	_refresh()


func _replan() -> void:
	if not recipes.has(area_id) or not _boardable():
		return
	if _plan_id != 0:
		client.cancel([_plan_id])
	plan = {}
	_plan_id = client.request({"cmd": "plan", "path": recipes[area_id]["path"], "world_seed": world_seed, "map_px": 0}, _on_plan.bind(area_id, world_seed), true)


func _on_plan(answer: Dictionary, id: String, s: int) -> void:
	_plan_id = 0
	if id != area_id or s != world_seed:
		return
	plan = answer
	_refresh()


func _on_sweep_plan(answer: Dictionary, s: int) -> void:
	sweep_results[s] = answer
	_sweep_ids.pop_front()
	_refresh_sweep()


func _clear_sweep() -> void:
	if client != null and not _sweep_ids.is_empty():
		client.cancel(_sweep_ids)
	_sweep_ids.clear()
	sweep_results.clear()
	sweep_base = 0


func select(s: Dictionary) -> void:
	sel = s
	if str(s.get("panel", "")) == "stratum":
		open_area(str(s["id"]))
	_refresh()


## An area with a recipe board (not the camp; the Gorge's ledges and spans
## get their own board later).
func _boardable() -> bool:
	return recipes.has(area_id) and not bool(recipes[area_id].get("network", false))


func _place(id: String) -> Dictionary:
	for p: Dictionary in stratum.get("places", []):
		if str(p["id"]) == id:
			return p
	return {}


# --- building the dock ------------------------------------------------------------

func _build() -> void:
	add_theme_constant_override("separation", int(8 * ui_scale))
	var bg := StyleBoxFlat.new()
	bg.bg_color = BG
	var header_panel := PanelContainer.new()
	var hstyle: StyleBoxFlat = bg.duplicate()
	hstyle.set_content_margin_all(10 * ui_scale)
	header_panel.add_theme_stylebox_override("panel", hstyle)
	add_child(header_panel)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", int(8 * ui_scale))
	header_panel.add_child(header)
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", 0)
	header.add_child(titles)
	_crumb = _label("Stratum 1", 12, MUTED)
	titles.add_child(_crumb)
	titles.add_child(_label("Strata Board", 22, FG))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	header.add_child(_label("WORLD SEED", 11, MUTED))
	var prev := _button("◀", func() -> void: set_world_seed(world_seed - 1))
	prev.tooltip_text = "Previous world seed"
	header.add_child(prev)
	_seed_box = SpinBox.new()
	_seed_box.min_value = 1
	_seed_box.max_value = 999999
	_seed_box.value = world_seed
	_seed_box.custom_minimum_size.x = 96 * ui_scale
	_seed_box.tooltip_text = "A world seed, as a save has: each area's seed comes from it."
	_seed_box.value_changed.connect(func(v: float) -> void: set_world_seed(int(v)))
	header.add_child(_seed_box)
	var next := _button("▶", func() -> void: set_world_seed(world_seed + 1))
	next.tooltip_text = "Next world seed"
	header.add_child(next)
	_area_seed = _label("", 12, MUTED)
	header.add_child(_area_seed)
	_sweep_button = _button("Sweep 20 seeds", start_sweep)
	_sweep_button.tooltip_text = "Plan the 20 world seeds around this one with the game's planner and mark each valid or not."
	header.add_child(_sweep_button)
	_walk_button = _button("Walk this seed", func() -> void: walk_requested.emit(area_id, world_seed))
	_walk_button.tooltip_text = "Run the game in this area with this world seed (a scratch save, never your own)."
	_style_primary(_walk_button)
	header.add_child(_walk_button)
	var reload_button := _button("Reload", reload)
	reload_button.tooltip_text = "Read the recipe files again (after a hand edit)."
	header.add_child(reload_button)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.add_theme_stylebox_override("panel", bg)
	add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side: String in ["left", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, int(12 * ui_scale))
	scroll.add_child(margin)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", int(12 * ui_scale))
	margin.add_child(body)

	_stratum_view = StratumView.new()
	_stratum_view.board = self
	body.add_child(_section("Stratum, side-on", "Click an area to open it. Heights are each area's reserved space; left to right is only for drawing.", _wide(_stratum_view)))

	var split := HSplitContainer.new()
	split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(split)
	var boards := VBoxContainer.new()
	boards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	boards.add_theme_constant_override("separation", int(12 * ui_scale))
	split.add_child(boards)

	var recipe_box := VBoxContainer.new()
	_recipe_view = RecipeView.new()
	_recipe_view.board = self
	recipe_box.add_child(_wide(_recipe_view))
	_recipe_note = _label("", 13, MUTED)
	_recipe_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	recipe_box.add_child(_recipe_note)
	var legend := HFlowContainer.new()
	legend.add_theme_constant_override("h_separation", int(16 * ui_scale))
	legend.add_child(_label("■ required room (a beat)", 12, BRASS))
	legend.add_child(_label("■ grow rule (the seed picks how many and where)", 12, TURQ))
	legend.add_child(_label("→ threshold to another area", 12, LAPIS))
	recipe_box.add_child(legend)
	boards.add_child(_section("Recipe", "What's authored: required rooms in the order they're placed, then grow rules in the order they run.", recipe_box))

	_plan_box = VBoxContainer.new()
	var plan_row := HBoxContainer.new()
	plan_row.add_theme_constant_override("separation", int(12 * ui_scale))
	_plan_view = PlanView.new()
	_plan_view.board = self
	var plan_wide: Control = _wide(_plan_view)
	plan_wide.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	plan_row.add_child(plan_wide)
	var map_box := VBoxContainer.new()
	map_box.add_child(_label("TOP-DOWN (north up) · click a room", 11, MUTED))
	_map = MapView.new()
	_map.board = self
	map_box.add_child(_map)
	plan_row.add_child(map_box)
	_plan_box.add_child(plan_row)
	_plan_status = RichTextLabel.new()
	_plan_status.bbcode_enabled = true
	_plan_status.fit_content = true
	_plan_status.scroll_active = false
	_plan_status.add_theme_color_override("default_color", MUTED)
	_plan_status.add_theme_font_size_override("normal_font_size", int(13 * ui_scale))
	_plan_box.add_child(_plan_status)
	var plan_section: Control = _section("Plan", "What the game's planner makes of the recipe. Left to right is distance from the entrance; up is storeys.", _plan_box)
	_plan_head = plan_section.get_meta("heading")
	boards.add_child(plan_section)

	var sweep_box := VBoxContainer.new()
	_sweep_bar = ProgressBar.new()
	_sweep_bar.max_value = SWEEP
	_sweep_bar.show_percentage = false
	_sweep_bar.custom_minimum_size.y = 6 * ui_scale
	sweep_box.add_child(_sweep_bar)
	_sweep_flow = HFlowContainer.new()
	_sweep_flow.add_theme_constant_override("h_separation", int(8 * ui_scale))
	_sweep_flow.add_theme_constant_override("v_separation", int(8 * ui_scale))
	sweep_box.add_child(_sweep_flow)
	_sweep_panel = _section("Seed sweep", "Twenty worlds, each planned and checked as the route test checks a plan. Click one to open it.", sweep_box)
	_sweep_panel.visible = false
	boards.add_child(_sweep_panel)

	_inspector = RichTextLabel.new()
	_inspector.bbcode_enabled = true
	_inspector.fit_content = true
	_inspector.scroll_active = false
	_inspector.selection_enabled = true
	_inspector.custom_minimum_size.x = 320 * ui_scale
	_inspector.add_theme_color_override("default_color", FG)
	_inspector.add_theme_font_size_override("normal_font_size", int(13 * ui_scale))
	_inspector.add_theme_font_size_override("bold_font_size", int(13 * ui_scale))
	var aside := _section("Inspector", "", _inspector)
	aside.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	split.add_child(aside)


func _section(title: String, hint: String, content: Control) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL
	style.border_color = LINE
	style.set_border_width_all(1)
	style.set_corner_radius_all(int(6 * ui_scale))
	style.set_content_margin_all(12 * ui_scale)
	panel.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", int(8 * ui_scale))
	panel.add_child(box)
	var head := HFlowContainer.new()
	head.add_theme_constant_override("h_separation", int(14 * ui_scale))
	var heading := _label(title, 17, FG)
	head.add_child(heading)
	if hint != "":
		var h := _label(hint, 12, MUTED)
		h.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(h)
	box.add_child(head)
	box.add_child(content)
	panel.set_meta("heading", heading)
	return panel


## A picture wider than the dock scrolls sideways on its own.
func _wide(view: Control) -> ScrollContainer:
	var s := ScrollContainer.new()
	s.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.add_child(view)
	return s


func _label(text: String, size: int, colour: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", int(size * ui_scale))
	l.add_theme_color_override("font_color", colour)
	return l


func _button(text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(on_press)
	return b


func _style_primary(b: Button) -> void:
	for state: String in ["normal", "hover", "pressed", "focus"]:
		var st := StyleBoxFlat.new()
		st.bg_color = BRASS if state != "hover" else BRASS.lightened(0.15)
		st.set_corner_radius_all(int(4 * ui_scale))
		st.set_content_margin_all(6 * ui_scale)
		b.add_theme_stylebox_override(state, st)
	for c: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, Color("1b1608"))


# --- refreshing ----------------------------------------------------------------------

func _refresh() -> void:
	if _seed_box == null:
		return
	var place: Dictionary = _place(area_id)
	_crumb.text = "Stratum 1 › %s" % str(place.get("name", area_id))
	_area_seed.text = "area seed %d" % int(plan["area_seed"]) if not plan.is_empty() and plan.has("area_seed") else ""
	_sweep_button.disabled = not _boardable()
	_sweep_button.text = "Hide sweep" if sweep_base != 0 and _sweep_ids.is_empty() and sweep_base == world_seed - (world_seed - 1) % SWEEP else "Sweep 20 seeds"
	_walk_button.disabled = not recipes.has(area_id)
	_stratum_view.refresh()
	_recipe_view.refresh()
	_recipe_note.text = _recipe_note_text()
	_recipe_note.visible = _recipe_note.text != ""
	_plan_box.visible = _boardable()
	_plan_head.text = "Plan for world seed %d" % world_seed if _boardable() else "Plan"
	_plan_view.refresh()
	_map.refresh()
	_set_status(_status_text())
	_inspector.text = _inspector_text()
	_refresh_sweep()


func _refresh_sweep() -> void:
	_sweep_panel.visible = sweep_base != 0
	if sweep_base == 0:
		return
	_sweep_bar.value = sweep_results.size()
	_sweep_bar.visible = sweep_results.size() < SWEEP
	for c: Node in _sweep_flow.get_children():
		c.queue_free()
	for s: int in range(sweep_base, sweep_base + SWEEP):
		var b := Button.new()
		b.custom_minimum_size = Vector2(150, 132) * ui_scale
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.expand_icon = true
		b.add_theme_font_size_override("font_size", int(12 * ui_scale))
		var r: Dictionary = sweep_results.get(s, {})
		if r.is_empty():
			b.text = "seed %d\nplanning…" % s
			b.disabled = true
		else:
			var valid: bool = bool(r.get("valid", false))
			b.text = "seed %d · %d rooms\n%s" % [s, (r.get("rooms", []) as Array).size(), "valid" if valid else "invalid"]
			b.icon = _png(str(r.get("map_png", "")))
			b.add_theme_color_override("font_color", FG if valid else BAD)
			b.tooltip_text = "valid" if valid else "\n".join(PackedStringArray(r.get("problems", [])))
			b.pressed.connect(set_world_seed.bind(s))
		var st := StyleBoxFlat.new()
		st.bg_color = PANEL_2
		st.border_color = BRASS if s == world_seed else LINE
		st.set_border_width_all(2 if s == world_seed else 1)
		st.set_corner_radius_all(int(4 * ui_scale))
		st.set_content_margin_all(6 * ui_scale)
		b.add_theme_stylebox_override("normal", st)
		b.add_theme_stylebox_override("disabled", st)
		_sweep_flow.add_child(b)


func _set_status(bb: String) -> void:
	_plan_status.text = bb


func _png(b64: String) -> Texture2D:
	if b64 == "":
		return null
	var img := Image.new()
	if img.load_png_from_buffer(Marshalls.base64_to_raw(b64)) != OK:
		return null
	return ImageTexture.create_from_image(img)


# --- words --------------------------------------------------------------------------

func _recipe_note_text() -> String:
	var place: Dictionary = _place(area_id)
	match str(place.get("kind", "")):
		"baked":
			return "%s is one baked scene from kit pieces. It has no recipe and no seed: it's the same in every world." % str(place.get("name", area_id))
		"scenery":
			return "%s: baked scenery and the Overlook, both fixed, and a network of ledges and spans the world seed picks. Its ledges and spans get their own board in a later phase; you can still walk any seed here." % str(place.get("name", area_id))
	if not recipes.has(area_id):
		return "Reading the recipe…"
	return ""


## Why a grow rule placed fewer rooms than it wanted, from the planner's own counts.
func grow_reasons(g: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = []
	var left: int = int(g["doors"]) - int(g["tried"]) - int(g["taken"])
	if int(g["doors"]) == 0:
		out.append("no free door on the rooms it may grow from")
	elif left <= 0:
		out.append("ran out of free doors (%d tried%s)" % [int(g["doors"]), ", %d taken first" % int(g["taken"]) if int(g["taken"]) > 0 else ""])
	if int(g["boxed_in"]) > 0:
		out.append("%d didn't fit (other rooms or the area's space)" % int(g["boxed_in"]))
	if int(g["too_short"]) > 0:
		out.append("%d came out too short" % int(g["too_short"]))
	if int(g["sightline"]) > 0:
		out.append("%d would see too deep through doorways (sightline)" % int(g["sightline"]))
	return out


func _grow_stats(prefix: String) -> Dictionary:
	for g: Dictionary in (plan.get("stats", {}) as Dictionary).get("grow", []):
		if str(g["prefix"]) == prefix:
			return g
	return {}


func _status_text() -> String:
	if not _boardable():
		return ""
	if plan.is_empty():
		return "Planning world seed %d…" % world_seed
	if plan.has("error"):
		return "[color=#%s]%s[/color]" % [BAD.to_html(false), plan["error"]]
	var recipe: Dictionary = recipes[area_id]
	var parts: PackedStringArray = []
	parts.append("%d rooms (the recipe wants %d–%d) · planned in %.0f ms" % [(plan["rooms"] as Array).size(), int(recipe["room_count"][0]), int(recipe["room_count"][1]), float(plan["plan_ms"])])
	for gd: Dictionary in recipe["grow"]:
		var g: Dictionary = _grow_stats(str(gd["prefix"]))
		if g.is_empty():
			continue
		var line: String = "%s: wanted %d, placed %d" % [gd["display_name"], int(g["want"]), int(g["added"])]
		if int(g["want"]) > int(g["rolled"]):
			line += " (rolled %d, raised to reach the area's minimum)" % int(g["rolled"])
		if int(g["added"]) < int(g["want"]):
			line = "[color=#%s]%s: %s[/color]" % [BRASS.to_html(false), line, "; ".join(grow_reasons(g))]
		parts.append(line)
	for p: Variant in plan.get("problems", []):
		parts.append("[color=#%s]%s[/color]" % [BAD.to_html(false), p])
	if bool(plan.get("valid", false)):
		parts.append("[color=#%s]The plan is valid: it checks clean as the route test checks it.[/color]" % TURQ.to_html(false))
	return "\n".join(parts)


func _kv(rows: Array) -> String:
	var out: PackedStringArray = []
	for r: Array in rows:
		out.append("[color=#%s]%s[/color]  %s" % [MUTED.to_html(false), r[0], r[1]])
	return "\n".join(out)


func _chip(text: String, colour: Color) -> String:
	return "[color=#%s][%s][/color]" % [colour.to_html(false), text]


func _room(slot: String) -> Dictionary:
	for r: Dictionary in plan.get("rooms", []):
		if str(r["slot_id"]) == slot:
			return r
	return {}


func _slot(slot: String) -> Dictionary:
	for s: Dictionary in recipes.get(area_id, {}).get("slots", []):
		if str(s["slot_id"]) == slot:
			return s
	return {}


func _grow_rule(prefix: String) -> Dictionary:
	for g: Dictionary in recipes.get(area_id, {}).get("grow", []):
		if str(g["prefix"]) == prefix:
			return g
	return {}


func _type(t: String, name: String) -> String:
	return "%s %s" % [t, name] if t != "" else "—"


func _inspector_text() -> String:
	var panel: String = str(sel.get("panel", ""))
	var id: String = str(sel.get("id", ""))
	var h: String = "[font_size=%d][b]%s[/b][/font_size]\n"
	var big: int = int(18 * ui_scale)
	if panel == "recipe" and id.begins_with("grow:"):
		var g: Dictionary = _grow_rule(id.trim_prefix("grow:"))
		if not g.is_empty():
			var st: Dictionary = _grow_stats(str(g["prefix"]))
			var from: String = ", ".join(PackedStringArray(g["from"])) if not (g["from"] as Array).is_empty() else "any room's free exit, grown rooms included"
			var rooms: PackedStringArray = []
			for r: Dictionary in plan.get("rooms", []):
				if str(r["grow"]) == str(g["prefix"]):
					rooms.append(str(r["slot_id"]))
			var text: String = _chip("grow rule", TURQ) + "\n" + h % [big, g["display_name"]]
			text += _kv([["Runs", "%s of %d" % [ORD[int(g["order"])], (recipes[area_id]["grow"] as Array).size()]],
				["Type", _type(str(g["type"]), str(g["type_name"]))], ["Count", "%d–%d" % [int(g["count"][0]), int(g["count"][1])]],
				["Grows from", from], ["Rooms", "%s_1, %s_2 …" % [g["prefix"], g["prefix"]]], ["Pinned", "yes" if bool(g["pinned"]) else "no"]])
			if not st.is_empty():
				text += "\n\n[b]World seed %d[/b]\n" % world_seed + _kv([["Rolled", str(int(st["rolled"]))], ["Wanted", str(int(st["want"]))],
					["Placed", "%d: %s" % [int(st["added"]), ", ".join(rooms) if not rooms.is_empty() else "none"]],
					["Doors seen", str(int(st["doors"]))], ["Tried", str(int(st["tried"]))]])
				if int(st["added"]) < int(st["want"]):
					text += "\n[color=#%s]Short: %s.[/color]" % [BRASS.to_html(false), "; ".join(grow_reasons(st))]
				if int(st["want"]) > int(st["rolled"]):
					text += "\n[color=#%s]The planner raised the count from %d to reach the area's minimum. Q4 (approved) stops this: a rule will never go past its own maximum.[/color]" % [MUTED.to_html(false), int(st["rolled"])]
			return text
	if panel == "recipe":
		var s: Dictionary = _slot(id)
		if not s.is_empty():
			var r: Dictionary = _room(id)
			var chips: String = _chip("required", BRASS)
			if bool(s["entrance_only"]):
				chips += " " + _chip("entrance only", LAPIS)
			if str(s["seed_mode"]) == "fixed":
				chips += " " + _chip("frozen", LAPIS)
			if bool(s["pinned"]):
				chips += " " + _chip("pinned", MUTED)
			var text: String = chips + "\n" + h % [big, s["display_name"]]
			var thresholds: PackedStringArray = []
			for k: String in s["thresholds"]:
				thresholds.append("%s → %s" % [k, s["thresholds"][k]])
			var variants: PackedStringArray = []
			for p: String in s["scenes"]:
				variants.append(p.get_file().get_basename() + ("  ← this seed" if str(r.get("scene", "")) == p and (s["scenes"] as Array).size() > 1 else ""))
			text += _kv([["Slot", s["slot_id"]], ["Type", _type(str(s["type"]), str(s["type_name"]))],
				["Made as", "authored or baked scene" if str(s["kind"]) == "scene" else str(s["kind"])],
				["Joins", "%s · %s" % [s["parent"], s["connector"]] if str(s["parent"]) != "" else "nothing: the entrance, at the area's origin"],
				["Doors out", "\n".join(thresholds) if not thresholds.is_empty() else "—"],
				["Seed", "fixed (%d)" % int(s["fixed_seed"]) if str(s["seed_mode"]) == "fixed" else "from the area seed"]])
			if not variants.is_empty():
				text += "\n\n[b]Variants[/b] (equal weights today; weights come in step 2)\n" + "\n".join(variants)
			if bool(s["entrance_only"]):
				text += "\n\n[color=#%s]Entrance only: its scene has no SNAP_entry, so nothing can lead into it (Q6).[/color]" % MUTED.to_html(false)
			text += "\n\n[b]World seed %d[/b]\n" % world_seed + (_kv([["Room", r["room_key"]], ["Cells", str(int(r["cells"]))]]) if not r.is_empty() else "not placed")
			return text
	if panel == "plan":
		var r: Dictionary = _room(id)
		if not r.is_empty():
			var doors: PackedStringArray = []
			for c: Dictionary in r["connectors"]:
				var what: String = str(c["joined"]) if str(c["joined"]) != "" else ("door to " + str(c["to"]) if str(c["cap"]) == "threshold" else ("glowing exit stub" if str(c["cap"]) == "glow" else str(c["cap"])))
				doors.append("%s: %s" % [c["name"], what])
			var text: String = (_chip("required", BRASS) if bool(r["required"]) else _chip("grown by " + str(r["grow"]), TURQ)) + "\n" + h % [big, r["display_name"]]
			text += _kv([["Slot", r["slot_id"]], ["Room key", r["room_key"]], ["Kind", r["kind"]], ["Type", _type(str(r["type"]), str(SERVICE_TYPE_NAMES.get(str(r["type"]), "")))],
				["Variant", str(r["scene"]).get_file().get_basename() if str(r["scene"]) != "" else "—"],
				["Joins", "%s · %s" % [r["parent"], r["parent_connector"]] if str(r["parent"]) != "" else "the entrance"],
				["Doorways in", str(int(r["depth"]))], ["Storey", str(int(r["storey"]))], ["Cells", str(int(r["cells"]))],
				["Ends", "plain wall (dead end)" if str(r["end_kind"]) == "dead_end" else "—"]])
			text += "\n\n[b]Doors[/b]\n" + "\n".join(doors)
			return text
	# The area.
	var place: Dictionary = _place(area_id)
	if not recipes.has(area_id):
		return h % [big, place.get("name", area_id)] + _recipe_note_text()
	var rc: Dictionary = recipes[area_id]
	var text: String = h % [big, rc["display_name"]]
	var env: Array = rc["envelope"]
	text += _kv([["Area id", rc["id"]], ["Recipe", str(rc["path"]).get_file()], ["Version", str(int(rc["version"]))],
		["Rooms", "%d–%d" % [int(rc["room_count"][0]), int(rc["room_count"][1])]], ["Required", str((rc["slots"] as Array).size())],
		["Grow rules", str((rc["grow"] as Array).size())], ["Dead ends", "at most %d" % int(rc["max_dead_ends"])],
		["Sightline", "at most %d rooms deep" % int(rc["max_sight_depth"])],
		["Space", "%.0f × %.0f × %.0f m, from %.0f m to %.0f m" % [float(env[3]), float(env[5]), float(env[4]), float(env[1]), float(env[1]) + float(env[4])]]])
	text += "\n\n[color=#%s]Select a room or grow rule in the recipe, or a room in the plan; its partner in the other view lights up. Nothing can be edited yet: editing comes in step 2.[/color]" % MUTED.to_html(false)
	return text


const SERVICE_TYPE_NAMES: Dictionary = {"R01": "Reading Room", "R02": "Stack gallery", "R03": "Hypostyle hall", "R05": "Caravanserai",
	"R09": "Light-well stair", "R10": "Chasm span", "R11": "Cistern"}


# --- pictures -------------------------------------------------------------------------

## What a picture's click hits: [Rect2, selection].
class View:
	extends Control
	var board: Node
	var hits: Array = []

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func s() -> float:
		return board.ui_scale

	func font() -> Font:
		return get_theme_default_font()

	## Text from `at` (its baseline); RIGHT: ending at `at`. A `width` > 0
	## shortens it with "…" to fit.
	func text(at: Vector2, t: String, size: int, colour: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1) -> void:
		var px: int = int(size * s())
		if width > 0.0 and font().get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > width:
			while t.length() > 1 and font().get_string_size(t + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > width:
				t = t.left(-1)
			t += "…"
		if align == HORIZONTAL_ALIGNMENT_RIGHT:
			at.x -= font().get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		draw_string(font(), at, t, HORIZONTAL_ALIGNMENT_LEFT, -1, px, colour)

	func box(r: Rect2, fill: Color, stroke: Color, width: float = 1.2, dashed: bool = false) -> void:
		draw_rect(r, fill)
		if not dashed:
			draw_rect(r, stroke, false, width * s())
			return
		var corners: PackedVector2Array = [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position]
		for i: int in 4:
			draw_dashed_line(corners[i], corners[i + 1], stroke, width * s(), 5.0 * s())

	func curve(a: Vector2, b: Vector2, colour: Color, dashed: bool = false) -> void:
		var pts: PackedVector2Array = []
		var mx: float = (a.x + b.x) * 0.5
		for i: int in 17:
			var t: float = i / 16.0
			pts.append(a.bezier_interpolate(Vector2(mx, a.y), Vector2(mx, b.y), b, t))
		if dashed:
			for i: int in range(0, pts.size() - 1, 2):
				draw_line(pts[i], pts[i + 1], colour, 1.4 * s())
		else:
			draw_polyline(pts, colour, 1.4 * s())
		draw_line(b, b + Vector2(-6, -4) * s(), colour, 1.4 * s())
		draw_line(b, b + Vector2(-6, 4) * s(), colour, 1.4 * s())

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			for h: Array in hits:
				if (h[0] as Rect2).has_point(event.position):
					board.select(h[1])
					accept_event()
					return
			board.select({})


## The stratum, side-on: each place a box of its reserved height, the links between them.
class StratumView:
	extends View
	const M_PER_PX: float = 0.62
	var _boxes: Dictionary = {}

	func refresh() -> void:
		var places: Array = board.stratum.get("places", [])
		var x: float = 90.0 * s()
		_boxes.clear()
		var top_m: float = 40.0
		var bottom_m: float = -180.0
		for p: Dictionary in places:
			top_m = maxf(top_m, float(p["y1"]))
			bottom_m = minf(bottom_m, float(p["y0"]))
		for p: Dictionary in places:
			var w: float = (260.0 if str(p["kind"]) == "scenery" else 140.0) * s()
			var y0: float = _y(float(p["y1"]), top_m)
			var y1: float = maxf(_y(float(p["y0"]), top_m), y0 + 18 * s())
			_boxes[str(p["id"])] = Rect2(x, y0, w, y1 - y0)
			x += w + 50.0 * s()
		set_meta("top_m", top_m)
		set_meta("bottom_m", bottom_m)
		custom_minimum_size = Vector2(x, _y(bottom_m, top_m) + 22 * s())
		hits.clear()
		for id: String in _boxes:
			hits.append([_boxes[id], {"panel": "stratum", "id": id}])
		queue_redraw()

	func _y(m: float, top_m: float) -> float:
		return 30.0 * s() + (top_m - m) * M_PER_PX * s()

	func _draw() -> void:
		if _boxes.is_empty():
			return
		var top_m: float = get_meta("top_m")
		var bottom_m: float = get_meta("bottom_m")
		var m: float = floorf(top_m / 50.0) * 50.0
		while m >= bottom_m:
			var y: float = _y(m, top_m)
			if m == 0.0:
				draw_line(Vector2(70 * s(), y), Vector2(size.x - 10, y), LINE, 1.0)
			else:
				draw_dashed_line(Vector2(70 * s(), y), Vector2(size.x - 10, y), LINE, 1.0, 3.0 * s())
			text(Vector2(8 * s(), y + 4 * s()), "0 m" if m == 0.0 else "%+.0f m" % m, 11, MUTED)
			m -= 50.0
		var order: Array = _boxes.keys()
		for l: Array in board.stratum.get("links", []):
			if not _boxes.has(l[0]) or not _boxes.has(l[1]):
				continue
			var a: Rect2 = _boxes[l[0]]
			var b: Rect2 = _boxes[l[1]]
			if a.position.x > b.position.x:
				var t: Rect2 = a
				a = b
				b = t
			var neighbours: bool = absi(order.find(l[0]) - order.find(l[1])) == 1
			var lo: float = maxf(a.position.y, b.position.y)
			var hi: float = minf(a.end.y, b.end.y)
			if neighbours and lo < hi:
				var y: float = minf(lo + 14 * s(), hi)
				draw_line(Vector2(a.end.x, y), Vector2(b.position.x, y), LAPIS, 2 * s())
				draw_circle(Vector2(a.end.x, y), 3.5 * s(), LAPIS)
				draw_circle(Vector2(b.position.x, y), 3.5 * s(), LAPIS)
			else:
				var p1 := Vector2(a.get_center().x, a.position.y)
				var p2 := Vector2(b.get_center().x, b.position.y)
				var pts: PackedVector2Array = []
				for i: int in 25:
					pts.append(p1.bezier_interpolate(Vector2(p1.x, 6 * s()), Vector2(p2.x, 6 * s()), p2, i / 24.0))
				draw_polyline(pts, LAPIS, 2 * s())
				draw_circle(p1, 3.5 * s(), LAPIS)
				draw_circle(p2, 3.5 * s(), LAPIS)
		for p: Dictionary in board.stratum.get("places", []):
			var id: String = str(p["id"])
			var r: Rect2 = _boxes[id]
			var open: bool = id == board.area_id
			box(r, BRASS_DIM if open else PANEL_2, BRASS if open else LINE, 1.5 if open else 1.0)
			text(r.position + Vector2(8, 16) * s(), str(p["name"]).trim_prefix("The "), 13, FG)
			var kind: String = {"recipe": "recipe + seed", "baked": "baked", "scenery": "scenery + ledges"}.get(str(p["kind"]), "")
			if r.size.y > 34 * s():
				text(r.position + Vector2(8, 31) * s(), "open" if open else kind, 11, MUTED)
		text(Vector2(size.x - 10 * s(), size.y - 6 * s()), "links in blue", 11, MUTED, HORIZONTAL_ALIGNMENT_RIGHT, 0)


## The recipe as a graph: required rooms (brass) a column after the room they
## join, grow rules (turquoise) a column after the rooms they grow from.
class RecipeView:
	extends View
	const NW: float = 190.0
	const NH: float = 50.0
	const CX: float = 225.0
	const LH: float = 62.0
	const LEFT: float = 150.0
	var nodes: Array = []     # {id, kind, data, col, storey, lane, rect}

	func refresh() -> void:
		nodes.clear()
		hits.clear()
		var rc: Dictionary = board.recipes.get(board.area_id, {})
		if rc.is_empty() or not board._boardable():
			custom_minimum_size = Vector2.ZERO
			queue_redraw()
			return
		var slots: Array = rc["slots"]
		var depth: Dictionary = {}
		var max_depth: int = 0
		for sl: Dictionary in slots:
			var d: int = 0
			var p: String = str(sl["parent"])
			while p != "" and d < 20:
				d += 1
				p = str(board._slot(p).get("parent", ""))
			depth[str(sl["slot_id"])] = d
			max_depth = maxi(max_depth, d)
		var gcol: Dictionary = {}
		for g: Dictionary in rc["grow"]:
			var c: int = max_depth + 1
			for f: String in g["from"]:
				if depth.has(f):
					c = maxi(c, int(depth[f]) + 1)
				else:
					for o: Dictionary in rc["grow"]:
						if o != g and f.begins_with(str(o["prefix"]) + "_") and gcol.has(str(o["prefix"])):
							c = maxi(c, int(gcol[str(o["prefix"])]) + 1)
			gcol[str(g["prefix"])] = c
		for sl: Dictionary in slots:
			var r: Dictionary = board._room(str(sl["slot_id"]))
			nodes.append({"id": str(sl["slot_id"]), "kind": "slot", "data": sl, "col": depth[str(sl["slot_id"])], "storey": int(r.get("storey", 0))})
		for g: Dictionary in rc["grow"]:
			var storey: int = 0
			for r: Dictionary in board.plan.get("rooms", []):
				if str(r["grow"]) == str(g["prefix"]):
					storey = int(r["storey"])
					break
			nodes.append({"id": "grow:" + str(g["prefix"]), "kind": "grow", "data": g, "col": gcol[str(g["prefix"])], "storey": storey})
		var used: Dictionary = {}
		var lanes: Dictionary = {}
		for n: Dictionary in nodes:
			var k: String = "%d:%d" % [n["col"], n["storey"]]
			n["lane"] = int(used.get(k, -1)) + 1
			used[k] = n["lane"]
			lanes[n["storey"]] = maxi(int(lanes.get(n["storey"], 1)), int(n["lane"]) + 1)
		var storeys: Array = lanes.keys()
		storeys.sort()
		storeys.reverse()
		var band_top: Dictionary = {}
		var y: float = 10.0
		for st: int in storeys:
			band_top[st] = y
			y += int(lanes[st]) * LH + 18.0
		var max_col: int = 0
		for n: Dictionary in nodes:
			max_col = maxi(max_col, int(n["col"]))
			n["rect"] = Rect2(Vector2(LEFT + int(n["col"]) * CX, float(band_top[n["storey"]]) + int(n["lane"]) * LH + 4.0) * s(), Vector2(NW, NH) * s())
			hits.append([n["rect"], {"panel": "recipe", "id": n["id"]}])
		set_meta("bands", [band_top, lanes])
		custom_minimum_size = Vector2(LEFT + (max_col + 1) * CX + 20.0, y) * s()
		queue_redraw()

	func _rect(id: String) -> Variant:
		for n: Dictionary in nodes:
			if n["id"] == id:
				return n["rect"]
		return null

	## The recipe node a selected plan room belongs to.
	func _lit() -> String:
		if str(board.sel.get("panel", "")) != "plan":
			return ""
		var r: Dictionary = board._room(str(board.sel["id"]))
		if r.is_empty():
			return ""
		return str(r["slot_id"]) if bool(r["required"]) else "grow:" + str(r["grow"])

	func _draw() -> void:
		if nodes.is_empty():
			return
		var bands: Array = get_meta("bands")
		for st: int in bands[0]:
			var top: float = float(bands[0][st])
			if st % 2 != 0:
				draw_rect(Rect2(Vector2(0, top - 4) * s(), Vector2(size.x, (int(bands[1][st]) * LH + 10) * s())), Color(PANEL_2, 0.5))
			text(Vector2(8, top + 16) * s(), "Storey %d" % st if st != 0 else "Storey 0", 11, MUTED)
		var rc: Dictionary = board.recipes[board.area_id]
		for n: Dictionary in nodes:
			if n["kind"] == "slot" and str(n["data"]["parent"]) != "":
				var a: Variant = _rect(str(n["data"]["parent"]))
				if a != null:
					curve(Vector2((a as Rect2).end.x, (a as Rect2).get_center().y), Vector2((n["rect"] as Rect2).position.x, (n["rect"] as Rect2).get_center().y), BRASS)
			elif n["kind"] == "grow":
				var from: Array = n["data"]["from"]
				var sources: PackedStringArray = []
				if from.is_empty():
					for o: Dictionary in nodes:
						if o["kind"] == "slot":
							sources.append(o["id"])
				for f: String in from:
					if _rect(f) != null:
						sources.append(f)
					else:
						for o: Dictionary in rc["grow"]:
							if f.begins_with(str(o["prefix"]) + "_") and not sources.has("grow:" + str(o["prefix"])):
								sources.append("grow:" + str(o["prefix"]))
				for src: String in sources:
					var a: Variant = _rect(src)
					if a != null and src != n["id"]:
						curve(Vector2((a as Rect2).end.x, (a as Rect2).get_center().y), Vector2((n["rect"] as Rect2).position.x, (n["rect"] as Rect2).get_center().y), TURQ, true)
		var lit: String = _lit()
		for n: Dictionary in nodes:
			var r: Rect2 = n["rect"]
			var selected: bool = (str(board.sel.get("panel", "")) == "recipe" and str(board.sel.get("id", "")) == n["id"]) or lit == n["id"]
			var d: Dictionary = n["data"]
			if n["kind"] == "slot":
				box(r, BRASS_DIM, FG if selected else BRASS, 2.0 if selected else 1.2)
				text(r.position + Vector2(10, 19) * s(), str(d["display_name"]), 13, FG, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 14 * s())
				var tags: PackedStringArray = [str(d["type"]) if str(d["type"]) != "" else str(d["kind"]), "baked/authored" if str(d["kind"]) == "scene" else str(d["kind"])]
				if (d["scenes"] as Array).size() > 1:
					tags.append("1 of %d variants" % (d["scenes"] as Array).size())
				if bool(d["entrance_only"]):
					tags.append("entrance only")
				if str(d["seed_mode"]) == "fixed":
					tags.append("frozen")
				text(r.position + Vector2(10, 37) * s(), " · ".join(tags), 11, MUTED, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 14 * s())
				var doors: Array = (d["thresholds"] as Dictionary).values()
				if not doors.is_empty():
					var y: float = r.get_center().y
					draw_line(Vector2(r.position.x, y), Vector2(r.position.x - 30 * s(), y), LAPIS, 2 * s())
					draw_line(Vector2(r.position.x - 30 * s(), y), Vector2(r.position.x - 24 * s(), y - 5 * s()), LAPIS, 2 * s())
					draw_line(Vector2(r.position.x - 30 * s(), y), Vector2(r.position.x - 24 * s(), y + 5 * s()), LAPIS, 2 * s())
					text(Vector2(r.position.x - 34 * s(), y - 8 * s()), str(board._place(str(doors[0])).get("name", doors[0])).trim_prefix("The "), 11, LAPIS, HORIZONTAL_ALIGNMENT_RIGHT, 0)
			else:
				box(r, TURQ_DIM, FG if selected else TURQ, 2.0 if selected else 1.2, true)
				text(r.position + Vector2(12, 19) * s(), str(d["display_name"]), 13, FG, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 50 * s())
				var c: Array = d["count"]
				var count: String = "%d×" % int(c[0]) if int(c[0]) == int(c[1]) else "%d–%d×" % [int(c[0]), int(c[1])]
				text(r.position + Vector2(12, 37) * s(), "runs %s · %s %s%s" % [ORD[int(d["order"])], count, d["type"], " · from any" if (d["from"] as Array).is_empty() else ""], 11, MUTED, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 16 * s())
				var st: Dictionary = board._grow_stats(str(d["prefix"]))
				if not st.is_empty():
					var short: bool = int(st["added"]) < int(st["want"])
					text(Vector2(r.end.x - 8 * s(), r.position.y + 15 * s()), "short" if short else "%d placed" % int(st["added"]), 10, BAD if short else TURQ, HORIZONTAL_ALIGNMENT_RIGHT, 0)


## One seed's plan, side-on: left to right is the route from the entrance (each
## room as wide as its longest run of cells), up is storeys.
class PlanView:
	extends View
	const B: float = 14.0
	const LH: float = 32.0
	const RH: float = 22.0
	const LEFT: float = 150.0
	var placed: Dictionary = {}     # slot -> {rect, room}

	func refresh() -> void:
		placed.clear()
		hits.clear()
		var rooms: Array = board.plan.get("rooms", [])
		if rooms.is_empty():
			custom_minimum_size = Vector2(0, 40 * s())
			queue_redraw()
			return
		var x: Dictionary = {}
		var lanes: Dictionary = {}   # storey -> [[x0, x1] per lane]
		var lane_of: Dictionary = {}
		for r: Dictionary in rooms:   # plan order: a parent before its children
			var p: String = str(r["parent"])
			var x0: float = float(x[p]) + float(_room_w(board._room(p))) + 1.0 if p != "" and x.has(p) else 0.0
			x[str(r["slot_id"])] = x0
			var st: int = int(r["storey"])
			var spans: Array = lanes.get(st, [])
			var lane: int = 0
			while lane < spans.size() and (spans[lane] as Array).any(func(sp: Array) -> bool: return x0 < float(sp[1]) + 1.0 and x0 + _room_w(r) > float(sp[0]) - 1.0):
				lane += 1
			if lane == spans.size():
				spans.append([])
			(spans[lane] as Array).append([x0, x0 + _room_w(r)])
			lanes[st] = spans
			lane_of[str(r["slot_id"])] = lane
		var storeys: Array = lanes.keys()
		storeys.sort()
		storeys.reverse()
		var band_top: Dictionary = {}
		var y: float = 10.0
		for st: int in storeys:
			band_top[st] = y
			y += (lanes[st] as Array).size() * LH + 18.0
		var max_x: float = 10.0
		for r: Dictionary in rooms:
			var id: String = str(r["slot_id"])
			var rect := Rect2(Vector2(LEFT + float(x[id]) * B, float(band_top[int(r["storey"])]) + int(lane_of[id]) * LH + 4.0) * s(), Vector2(_room_w(r) * B, RH) * s())
			placed[id] = {"rect": rect, "room": r}
			hits.append([rect, {"panel": "plan", "id": id}])
			max_x = maxf(max_x, float(x[id]) + _room_w(r))
		set_meta("bands", [band_top, lanes])
		custom_minimum_size = Vector2(LEFT + (max_x + 2.0) * B, y) * s()
		queue_redraw()

	func _room_w(r: Dictionary) -> int:
		return clampi(int(r.get("bays", 1)), 1, 16)

	func _lit(r: Dictionary) -> bool:
		if str(board.sel.get("panel", "")) == "plan":
			return str(board.sel["id"]) == str(r["slot_id"])
		if str(board.sel.get("panel", "")) != "recipe":
			return false
		var id: String = str(board.sel["id"])
		return ("grow:" + str(r["grow"])) == id if id.begins_with("grow:") else str(r["slot_id"]) == id

	func _draw() -> void:
		if placed.is_empty():
			return
		var bands: Array = get_meta("bands")
		for st: int in bands[0]:
			var top: float = float(bands[0][st])
			var bottom: float = top + (bands[1][st] as Array).size() * LH + 4.0
			draw_line(Vector2(LEFT - 8, bottom) * s(), Vector2(size.x / s(), bottom) * s(), LINE, 1.0)
			text(Vector2(8, top + 18) * s(), "Storey %d" % st, 11, MUTED)
		for id: String in placed:
			var r: Dictionary = placed[id]["room"]
			if str(r["parent"]) == "" or not placed.has(str(r["parent"])):
				continue
			var a: Rect2 = placed[str(r["parent"])]["rect"]
			var b: Rect2 = placed[id]["rect"]
			var colour: Color = BRASS if bool(r["required"]) else TURQ
			var mx: float = a.end.x + B * 0.5 * s()
			var pts: PackedVector2Array = [Vector2(a.end.x, a.get_center().y), Vector2(mx, a.get_center().y), Vector2(mx, b.get_center().y), Vector2(b.position.x, b.get_center().y)]
			draw_polyline(pts, colour, 1.6 * s())
		for id: String in placed:
			var r: Dictionary = placed[id]["room"]
			var rect: Rect2 = placed[id]["rect"]
			var req: bool = bool(r["required"])
			var lit: bool = _lit(r)
			box(rect, BRASS_DIM if req else TURQ_DIM, FG if lit else (BRASS if req else TURQ), 2.0 if lit else 1.2, not req)
			if str(r["type"]) == "R09":
				box(Rect2(rect.get_center().x - 4 * s(), rect.position.y - 16 * s(), 8 * s(), 16 * s()), TURQ_DIM, TURQ, 1.0)
			if str(r["type"]) == "R11":
				draw_rect(Rect2(rect.position.x + 3 * s(), rect.end.y - 6 * s(), rect.size.x - 6 * s(), 4 * s()), Color(LAPIS, 0.7))
			if str(r["end_kind"]) == "dead_end":
				draw_rect(Rect2(rect.end.x - 3 * s(), rect.position.y, 3 * s(), rect.size.y), MUTED)
			text(rect.position + Vector2(5, 15) * s(), id, 11, FG, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 6 * s())
			for c: Dictionary in r["connectors"]:
				if str(c["cap"]) == "threshold":
					var y: float = rect.get_center().y
					draw_line(Vector2(rect.position.x, y), Vector2(rect.position.x - 34 * s(), y), LAPIS, 2 * s())
					text(Vector2(rect.position.x - 38 * s(), y + 4 * s()), str(board._place(str(c["to"])).get("name", c["to"])).trim_prefix("The "), 11, LAPIS, HORIZONTAL_ALIGNMENT_RIGHT, 0)
					break


## The plan top-down (north up), drawn from the planner's cells: each room
## outlined and named, a room selected here or in the side-on view (or every
## room of a selected rule) lit, the rest dimmed. Higher storeys are drawn
## over lower ones and named with their storey. Gold squares are doorways.
class MapView:
	extends View

	func _ready() -> void:
		tooltip_text = "room"     # a tooltip at all; _get_tooltip says which room
	const FIT: float = 360.0
	const PAD: float = 8.0
	var px: float = 10.0
	var lo := Vector2i.ZERO
	var hi := Vector2i.ZERO
	var cell_owner: Dictionary = {}     # "x,y,z" -> slot (for drawing the outlines)
	var order: Array = []          # rooms, lowest storey first

	func refresh() -> void:
		hits.clear()
		cell_owner.clear()
		order = (board.plan.get("rooms", []) as Array).duplicate()
		order.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["storey"]) < int(b["storey"]))
		if order.is_empty():
			custom_minimum_size = Vector2(FIT, 40) * s()
			queue_redraw()
			return
		lo = Vector2i(1 << 30, 1 << 30)
		hi = Vector2i(-(1 << 30), -(1 << 30))
		for r: Dictionary in order:
			for c: Array in r.get("floor", []):
				lo = Vector2i(mini(lo.x, int(c[0])), mini(lo.y, int(c[2])))
				hi = Vector2i(maxi(hi.x, int(c[0])), maxi(hi.y, int(c[2])))
				cell_owner["%d,%d,%d" % [int(c[0]), int(c[1]), int(c[2])]] = str(r["slot_id"])
		var cells := Vector2(hi.x - lo.x + 1, hi.y - lo.y + 1)
		px = clampf(minf(FIT / cells.x, FIT / cells.y), 5.0, 18.0) * s()
		custom_minimum_size = cells * px + Vector2(PAD, PAD) * 2.0 * s()
		# Clicks: the highest storey's room first.
		for i: int in range(order.size() - 1, -1, -1):
			for c: Array in order[i].get("floor", []):
				hits.append([_cell(int(c[0]), int(c[2])), {"panel": "plan", "id": str(order[i]["slot_id"])}])
		queue_redraw()

	func _cell(x: int, z: int) -> Rect2:
		return Rect2(Vector2(PAD * s() + (x - lo.x) * px, PAD * s() + (hi.y - z) * px), Vector2(px, px))

	## Rooms lit by the selection ({} lit = nothing selected).
	func _lit() -> Dictionary:
		var out: Dictionary = {}
		var panel: String = str(board.sel.get("panel", ""))
		var id: String = str(board.sel.get("id", ""))
		for r: Dictionary in order:
			if (panel == "plan" and id == str(r["slot_id"])) or (panel == "recipe" and (id == str(r["slot_id"]) or id == "grow:" + str(r["grow"]))):
				out[str(r["slot_id"])] = true
		return out

	func _get_tooltip(at: Vector2) -> String:
		for h: Array in hits:
			if (h[0] as Rect2).has_point(at):
				var r: Dictionary = board._room(str(h[1]["id"]))
				return "%s (%s), storey %d" % [r.get("display_name", ""), r.get("slot_id", ""), int(r.get("storey", 0))]
		return ""

	func _draw() -> void:
		if order.is_empty():
			return
		draw_rect(Rect2(Vector2.ZERO, size), BG)
		var lit: Dictionary = _lit()
		var any: bool = not lit.is_empty()
		for r: Dictionary in order:
			var slot: String = str(r["slot_id"])
			var base: Color = BRASS if bool(r["required"]) else TURQ
			var fill: Color = PANEL.lerp(base, 0.75 if lit.has(slot) else (0.14 if any else 0.32))
			var edge: Color = FG if lit.has(slot) else BG
			for c: Array in r.get("floor", []):
				draw_rect(_cell(int(c[0]), int(c[2])), fill)
			# Outline where the next cell isn't this room's (on this storey).
			for c: Array in r.get("floor", []):
				var x: int = int(c[0])
				var y: int = int(c[1])
				var z: int = int(c[2])
				var rect: Rect2 = _cell(x, z)
				var w: float = (1.6 if lit.has(slot) else 1.0) * s()
				if cell_owner.get("%d,%d,%d" % [x, y, z + 1], "") != slot:
					draw_line(rect.position, Vector2(rect.end.x, rect.position.y), edge, w)
				if cell_owner.get("%d,%d,%d" % [x, y, z - 1], "") != slot:
					draw_line(Vector2(rect.position.x, rect.end.y), rect.end, edge, w)
				if cell_owner.get("%d,%d,%d" % [x - 1, y, z], "") != slot:
					draw_line(rect.position, Vector2(rect.position.x, rect.end.y), edge, w)
				if cell_owner.get("%d,%d,%d" % [x + 1, y, z], "") != slot:
					draw_line(Vector2(rect.end.x, rect.position.y), rect.end, edge, w)
		for d: Array in board.plan.get("doors", []):
			var at := Vector2(PAD * s() + (float(d[0]) - lo.x) * px, PAD * s() + (hi.y + 1 - float(d[1])) * px)
			draw_rect(Rect2(at - Vector2(2.5, 2.5) * s(), Vector2(5, 5) * s()), Color("e8c45a"))
		# Names at each room's middle, on a dark pill so they read over the cells.
		for r: Dictionary in order:
			var floor: Array = r.get("floor", [])
			if floor.is_empty():
				continue
			var mid := Vector2.ZERO
			for c: Array in floor:
				mid += _cell(int(c[0]), int(c[2])).get_center()
			mid /= floor.size()
			var name: String = str(r["slot_id"]) + ("  ↑%d" % int(r["storey"]) if int(r["storey"]) != 0 else "")
			var fs: int = int(10 * s())
			var tw: float = font().get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var slot: String = str(r["slot_id"])
			draw_rect(Rect2(mid - Vector2(tw * 0.5 + 3 * s(), 7 * s()), Vector2(tw + 6 * s(), 13 * s())), Color(BG, 0.85 if lit.has(slot) or not any else 0.55))
			draw_string(font(), mid + Vector2(-tw * 0.5, 4 * s()), name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, FG if lit.has(slot) or not any else MUTED)

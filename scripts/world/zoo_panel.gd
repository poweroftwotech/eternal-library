class_name ZooPanel
extends CanvasLayer
## The zoo's tuning panel (the zoo, step 3): pick an animal, move its
## settings, and the zoo respawns at once; pull a few triggers to see its
## behaviour; save the settings to the animal's file so the game uses them.
## F5 opens and closes it (the mouse is freed while it is open). Only the
## zoo has one (ZooRoom makes it).
##
## Settings change the animal's CreatureDef in memory. Save writes that file
## (actors/defs/<kind>.tres); Undo changes puts back what the file had when
## the zoo opened. Amount, the seed and the triggers are the zoo's own and
## are never saved.

## What can be tuned: [property (".x"/".y" a part of a pair), name, least,
## most, step, which habitats it is for ("" all)].
const FIELDS: Array = [
	["size.x", "Smallest (m)", 0.01, 2.0, 0.01, ""],
	["size.y", "Largest (m)", 0.01, 2.0, 0.01, ""],
	["group_size.x", "Fewest in a group", 0.0, 100.0, 1.0, ""],
	["group_size.y", "Most in a group", 1.0, 300.0, 1.0, ""],
	["max_groups", "Most groups in a room", 1.0, 12.0, 1.0, "water dark_roof wall_foot"],
	["room_cap", "Most in a room", 1.0, 1000.0, 1.0, "flame dark_roof wall_lamp"],
	["startle_radius", "You startle it within (m)", 0.0, 15.0, 0.1, "water dark_roof lane wall_foot wall_lamp"],
	["safe_radius", "Back once you are this far (m)", 0.0, 20.0, 0.1, "wall_foot wall_lamp"],
	["speed.x", "Usual speed (m/s)", 0.0, 6.0, 0.05, "water lane wall_foot wall_lamp"],
	["speed.y", "Fleeing speed (m/s)", 0.0, 10.0, 0.05, "water lane wall_foot wall_lamp"],
	["area_each", "Water (m2) for each fish", 0.2, 30.0, 0.1, "water"],
	["min_depth", "Least depth of water (m)", 0.0, 2.0, 0.01, "water"],
	["flame_share", "Share of lamps that have them", 0.0, 1.0, 0.05, "flame wall_lamp"],
	["min_height", "Least height of roof (m)", 1.0, 15.0, 0.1, "dark_roof"],
	["dark_radius", "No light within (m)", 0.0, 20.0, 0.5, "dark_roof"],
	["glow_gap", "Keeps this far from fungus (m)", 0.0, 10.0, 0.5, "dark_roof"],
	["area_each", "Soft things for each cat", 1.0, 20.0, 1.0, "lane"],
	["look_radius", "Looks at you within (m)", 0.0, 15.0, 0.1, "lane"],
	["crowd_radius", "Moves off when you are within (m)", 0.0, 3.0, 0.05, "lane"],
	["climb", "Runs this far up the wall (m)", 0.3, 5.0, 0.1, "wall_lamp"],
	["roam", "How often it leaves the wall", 0.0, 1.0, 0.05, "wall_foot"],
	["roam", "Share of its time on the wing", 0.0, 0.8, 0.05, "dark_roof"],
	["self_glow", "Shows in the dark", 0.0, 1.0, 0.02, "dark_roof wall_foot"],
	["wall_reach", "Wall within this far of the lamp (m)", 0.3, 4.0, 0.1, "wall_lamp"],
]
const WIDTH: int = 440

var fauna: Fauna
var zoo: Node3D
var kinds: Array[CreatureDef] = []
var kind: int = 0
## Kind id -> {property: value} as its file had them when the zoo opened.
var _before: Dictionary = {}
var _rows: VBoxContainer
var _pick: OptionButton
var _note: Label
var _amount: HSlider
var _amount_text: Label
var _wait: float = -1.0
var _lamps_out: bool = false
var _building: bool = false


func _ready() -> void:
	layer = 70
	process_mode = Node.PROCESS_MODE_ALWAYS
	for p: String in Fauna.DEFS:
		var d: CreatureDef = load(p) as CreatureDef
		if d == null:
			continue
		kinds.append(d)
		var was: Dictionary = {}
		for f: Array in FIELDS:
			var prop: String = str(f[0]).get_slice(".", 0)
			if prop == "size":
				was["length_m"] = d.length_m
				was["length_spread"] = d.length_spread
				continue
			was[prop] = d.get(prop)
		_before[str(d.id)] = was
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	var across := HBoxContainer.new()
	across.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(across)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = WIDTH
	across.add_child(panel)
	var pad := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 14)
	panel.add_child(pad)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	pad.add_child(column)
	column.add_child(_label("THE ZOO: ANIMAL SETTINGS   (F5 closes)", 17))
	_pick = OptionButton.new()
	for d: CreatureDef in kinds:
		_pick.add_item(d.display_name)
	_pick.item_selected.connect(func(i: int) -> void:
		kind = i
		_fill())
	column.add_child(_pick)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", 4)
	scroll.add_child(_rows)
	# The zoo's own: how many, which seed.
	column.add_child(HSeparator.new())
	var amount_row := HBoxContainer.new()
	amount_row.add_child(_label("Amount here (not saved)", 14))
	_amount = HSlider.new()
	_amount.min_value = 0.0
	_amount.max_value = 3.0
	_amount.step = 0.1
	_amount.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_amount.value_changed.connect(func(v: float) -> void:
		if _building:
			return
		fauna.amounts[str(kinds[kind].id)] = v
		_amount_text.text = "%d%%" % roundi(v * 100.0)
		_respawn_soon())
	amount_row.add_child(_amount)
	_amount_text = _label("100%", 14)
	_amount_text.custom_minimum_size.x = 52
	amount_row.add_child(_amount_text)
	column.add_child(amount_row)
	var seeds := HBoxContainer.new()
	seeds.add_child(_button("New seed", func() -> void:
		fauna.seed_bump += 1
		_say("Placed again with another seed (%d)." % fauna.seed_bump)
		fauna.respawn()))
	seeds.add_child(_button("Respawn", func() -> void:
		_say("Placed again.")
		fauna.respawn()))
	column.add_child(seeds)
	# Triggers.
	column.add_child(HSeparator.new())
	var toggles := HBoxContainer.new()
	toggles.add_child(_check("Ignore me", func(on: bool) -> void: fauna.ignore_player = on))
	toggles.add_child(_check("Slow motion", func(on: bool) -> void: Engine.time_scale = 0.25 if on else 1.0))
	toggles.add_child(_check("Overlay", func(on: bool) -> void: fauna.show_overlay(on)))
	column.add_child(toggles)
	var triggers := HBoxContainer.new()
	triggers.add_child(_button("Startle all", func() -> void:
		fauna.startle_all()
		_say("Startled every animal.")))
	triggers.add_child(_button("Lamps out / lit", _toggle_lamps))
	column.add_child(triggers)
	# The file.
	column.add_child(HSeparator.new())
	var files := HBoxContainer.new()
	files.add_child(_button("Save to its file", _save))
	files.add_child(_button("Undo changes", _undo))
	column.add_child(files)
	_note = _label("", 13)
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.custom_minimum_size.y = 40
	column.add_child(_note)
	_fill()
	set_open(false)


static func _label(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	return l


static func _button(text: String, pressed: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(pressed)
	return b


static func _check(text: String, toggled: Callable) -> CheckBox:
	var c := CheckBox.new()
	c.text = text
	c.focus_mode = Control.FOCUS_NONE
	c.toggled.connect(toggled)
	return c


func _say(text: String) -> void:
	_note.text = text


func set_open(on: bool) -> void:
	visible = on
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if on else Input.MOUSE_MODE_CAPTURED


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_F5:
		set_open(not visible)
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	# A slider being dragged: place the animals again once it has been still a moment.
	if _wait >= 0.0:
		_wait -= delta / maxf(Engine.time_scale, 0.01)
		if _wait < 0.0:
			fauna.respawn()


func _respawn_soon() -> void:
	_wait = 0.25


## A setting of the picked kind (a pair's part by ".x" / ".y").
static func value_of(d: CreatureDef, field: String) -> float:
	if field.begins_with("size."):
		# The smallest and largest an animal comes (m): its length and spread.
		return d.length_m * (d.length_spread.x if field.ends_with(".x") else d.length_spread.y)
	var v: Variant = d.get(field.get_slice(".", 0))
	if field.ends_with(".x"):
		return float(v.x)
	if field.ends_with(".y"):
		return float(v.y)
	return float(v)


static func set_value(d: CreatureDef, field: String, x: float) -> void:
	if field.begins_with("size."):
		var least: float = x if field.ends_with(".x") else d.length_m * d.length_spread.x
		var most: float = x if field.ends_with(".y") else d.length_m * d.length_spread.y
		most = maxf(most, least)
		d.length_m = (least + most) * 0.5
		d.length_spread = Vector2(least / d.length_m, most / d.length_m)
		return
	var prop: String = field.get_slice(".", 0)
	var v: Variant = d.get(prop)
	if field.ends_with(".x") or field.ends_with(".y"):
		var whole: bool = v is Vector2i
		if field.ends_with(".x"):
			v.x = roundi(x) if whole else x
		else:
			v.y = roundi(x) if whole else x
		d.set(prop, v)
	elif v is int:
		d.set(prop, roundi(x))
	else:
		d.set(prop, x)


## The rows for the picked kind.
func _fill() -> void:
	_building = true
	for c: Node in _rows.get_children():
		c.queue_free()
	var d: CreatureDef = kinds[kind]
	_rows.add_child(_label("%s (%s): lives by %s" % [d.display_name, d.local_name, FaunaOverlay.HABITATS.get(d.habitat, d.habitat)], 13))
	for f: Array in FIELDS:
		if str(f[5]) != "" and not str(f[5]).split(" ").has(d.habitat):
			continue
		if d.habitat == "lane" and str(f[0]) == "group_size.x":
			continue
		var field: String = f[0]
		var row := HBoxContainer.new()
		var name_label := _label(str(f[1]), 14)
		name_label.custom_minimum_size.x = 215
		name_label.clip_text = true
		row.add_child(name_label)
		var slider := HSlider.new()
		slider.min_value = f[2]
		slider.max_value = f[3]
		slider.step = f[4]
		slider.value = value_of(d, field)
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.focus_mode = Control.FOCUS_NONE
		row.add_child(slider)
		var shown := _label(_shown(slider.value, float(f[4])), 14)
		shown.custom_minimum_size.x = 52
		row.add_child(shown)
		slider.value_changed.connect(func(v: float) -> void:
			set_value(d, field, v)
			shown.text = _shown(v, float(f[4]))
			_say("Changed in the zoo only. Save to its file to keep it.")
			_respawn_soon())
		_rows.add_child(row)
	var amount: float = float(fauna.amounts.get(str(d.id), 1.0)) if fauna != null else 1.0
	_amount.value = amount
	_amount_text.text = "%d%%" % roundi(amount * 100.0)
	_building = false


static func _shown(v: float, step: float) -> String:
	return "%d" % roundi(v) if step >= 1.0 else ("%.1f" % v if step >= 0.1 else "%.2f" % v)


func _save() -> void:
	var d: CreatureDef = kinds[kind]
	var err: Error = ResourceSaver.save(d, d.resource_path)
	if err == OK:
		var was: Dictionary = _before[str(d.id)]
		for prop: String in was:
			was[prop] = d.get(prop)
		_say("Saved %s. The game uses these settings from now on." % d.resource_path)
	else:
		_say("Could not save %s (%s)." % [d.resource_path, error_string(err)])


func _undo() -> void:
	var d: CreatureDef = kinds[kind]
	var was: Dictionary = _before[str(d.id)]
	for prop: String in was:
		d.set(prop, was[prop])
	_fill()
	_say("%s is back to what its file has." % d.display_name)
	fauna.respawn()


## Every burning lamp in the zoo put out, or lit again (geckos leave a lamp
## that is out).
func _toggle_lamps() -> void:
	_lamps_out = not _lamps_out
	var n: int = 0
	for l: Node in zoo.find_children("*", "OmniLight3D", true, false):
		if HabitatScan.FLAME_PROFILES.has(str(l.get_meta("light_profile", ""))):
			(l as Light3D).visible = not _lamps_out
			l.set_meta("lamp_state", "dark" if _lamps_out else "lit")
			n += 1
	_say("%d lamps %s. Geckos leave within a second; a respawn places by the lamps that burn." % [n, "put out" if _lamps_out else "lit again"])


func _exit_tree() -> void:
	Engine.time_scale = 1.0
	# What was changed and not saved does not follow you into the game.
	for d: CreatureDef in kinds:
		var was: Dictionary = _before[str(d.id)]
		for prop: String in was:
			d.set(prop, was[prop])

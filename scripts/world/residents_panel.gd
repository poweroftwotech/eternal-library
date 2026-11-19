class_name ResidentsPanel
extends CanvasLayer
## The People panel (phase 21 steps 2-4): F6 opens and closes it; the mouse is
## freed while it is open. At the top the day's clock (pause, speed, jump to a
## bell), labels over people and the overlay (spots and ways, also on F4).
## Under it three pages:
##   Now         everyone, and what they are doing
##   A day       one person's whole day, with "now" marked
##   Timetables  a trade's timetable, edited row by row and saved
## Speed and pause are not saved; the time of day is; timetables are saved to
## gen/people/routines.tres when you press Save.

const SPEEDS: Array[float] = [1.0, 10.0, 30.0, 60.0]
const WIDTH: int = 470
const LIST_HEIGHT: int = 330
const NOW := Color(1.0, 0.85, 0.4)

var residents: Residents
var _clock_text: Label
var _roll: Label
var _pause: Button
var _speeds: Array[Button] = []
var _labels: CheckBox
var _overlay: CheckBox
var _tick: float = 0.0
var _person: OptionButton
var _day: VBoxContainer
var _trade: OptionButton
var _rows: VBoxContainer
var _saved: Label
var _people_seen: int = -1


func _ready() -> void:
	layer = 71
	process_mode = Node.PROCESS_MODE_ALWAYS
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)
	var across := HBoxContainer.new()
	across.alignment = BoxContainer.ALIGNMENT_END
	across.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(across)
	var down := VBoxContainer.new()
	down.alignment = BoxContainer.ALIGNMENT_BEGIN
	down.mouse_filter = Control.MOUSE_FILTER_IGNORE
	across.add_child(down)
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(WIDTH, 0)
	down.add_child(frame)
	var pad := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 12)
	frame.add_child(pad)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 8)
	pad.add_child(rows)
	var title := Label.new()
	title.text = "PEOPLE  (F6)"
	rows.add_child(title)
	_clock_text = Label.new()
	_clock_text.add_theme_font_size_override("font_size", 20)
	rows.add_child(_clock_text)
	# The clock's speed.
	var speed_row := HBoxContainer.new()
	speed_row.add_theme_constant_override("separation", 6)
	rows.add_child(speed_row)
	_pause = Button.new()
	_pause.text = "Pause"
	_pause.pressed.connect(_on_pause)
	speed_row.add_child(_pause)
	for s: float in SPEEDS:
		var b := Button.new()
		b.text = "%dx" % int(s)
		b.toggle_mode = true
		b.pressed.connect(_on_speed.bind(s))
		speed_row.add_child(b)
		_speeds.append(b)
	# Jump to a bell.
	var bell_row := HBoxContainer.new()
	bell_row.add_theme_constant_override("separation", 6)
	rows.add_child(bell_row)
	var to := Label.new()
	to.text = "Go to bell"
	bell_row.add_child(to)
	for i: int in DayClock.BELLS:
		var b := Button.new()
		b.text = str(i + 1)
		b.tooltip_text = DayClock.NAMES[i]
		b.pressed.connect(_on_bell.bind(i))
		bell_row.add_child(b)
	var ticks := HBoxContainer.new()
	ticks.add_theme_constant_override("separation", 14)
	rows.add_child(ticks)
	_labels = CheckBox.new()
	_labels.text = "Labels over people"
	_labels.toggled.connect(_on_labels)
	ticks.add_child(_labels)
	_overlay = CheckBox.new()
	_overlay.text = "Spots and ways  (F4)"
	_overlay.tooltip_text = "Every spot as a ring, named with who has it; the way each walker is taking; where people can walk."
	_overlay.toggled.connect(_on_overlay)
	ticks.add_child(_overlay)
	var pages := TabContainer.new()
	pages.custom_minimum_size = Vector2(WIDTH - 24, LIST_HEIGHT + 90)
	rows.add_child(pages)

	# Now: everyone.
	var now_page := ScrollContainer.new()
	now_page.name = "Now"
	now_page.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pages.add_child(now_page)
	_roll = Label.new()
	_roll.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_roll.custom_minimum_size = Vector2(WIDTH - 48, 0)
	_roll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	now_page.add_child(_roll)

	# A day: one person's.
	var day_page := VBoxContainer.new()
	day_page.name = "A day"
	day_page.add_theme_constant_override("separation", 6)
	pages.add_child(day_page)
	_person = OptionButton.new()
	_person.item_selected.connect(func(_i: int) -> void: _show_day())
	day_page.add_child(_person)
	var day_scroll := ScrollContainer.new()
	day_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	day_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	day_page.add_child(day_scroll)
	_day = VBoxContainer.new()
	_day.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_day.add_theme_constant_override("separation", 2)
	day_scroll.add_child(_day)

	# Timetables: a trade's, edited.
	var table_page := VBoxContainer.new()
	table_page.name = "Timetables"
	table_page.add_theme_constant_override("separation", 6)
	pages.add_child(table_page)
	_trade = OptionButton.new()
	for trade: String in RoutineBook.open().trades:
		_trade.add_item(trade.capitalize())
		_trade.set_item_metadata(_trade.item_count - 1, trade)
	_trade.item_selected.connect(func(_i: int) -> void: _show_table())
	table_page.add_child(_trade)
	var hint := Label.new()
	hint.text = "Each row starts at its bell and minute and lasts until the next. Changes show at once; Save keeps them."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 12)
	hint.custom_minimum_size = Vector2(WIDTH - 48, 0)
	table_page.add_child(hint)
	var table_scroll := ScrollContainer.new()
	table_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	table_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	table_page.add_child(table_scroll)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", 3)
	table_scroll.add_child(_rows)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 6)
	table_page.add_child(buttons)
	var add := Button.new()
	add.text = "Add a row"
	add.pressed.connect(_on_add_row)
	buttons.add_child(add)
	var first := Button.new()
	first.text = "As first written"
	first.tooltip_text = "This trade's timetable as it was before any change."
	first.pressed.connect(_on_first)
	buttons.add_child(first)
	var save := Button.new()
	save.text = "Save"
	save.tooltip_text = "Writes every trade's timetable to gen/people/routines.tres."
	save.pressed.connect(_on_save)
	buttons.add_child(save)
	_saved = Label.new()
	buttons.add_child(_saved)
	_show_table()
	_refresh()


func set_open(on: bool) -> void:
	visible = on
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if on else Input.MOUSE_MODE_CAPTURED
	if on:
		_labels.set_pressed_no_signal(residents.labels)
		_overlay.set_pressed_no_signal(residents.overlay != null and residents.overlay.visible)
		_refresh()


func _process(delta: float) -> void:
	if not visible:
		return
	_tick -= delta
	if _tick <= 0.0:
		_tick = 0.2
		_refresh()


func _refresh() -> void:
	var clock: DayClock = DayClock.it()
	if clock == null or _clock_text == null:
		return
	_clock_text.text = "%s   (day %d)" % [clock.text(), clock.day() + 1]
	_pause.text = "Run" if clock.paused else "Pause"
	for i: int in SPEEDS.size():
		_speeds[i].set_pressed_no_signal(is_equal_approx(clock.speed, SPEEDS[i]))
	var lines: PackedStringArray = residents.roll() if residents != null else PackedStringArray()
	_roll.text = "\n\n".join(lines) if not lines.is_empty() else "Nobody lives here yet."
	# The people's list, when who is here changes.
	var count: int = residents.people.size() if residents != null else 0
	if count != _people_seen:
		_people_seen = count
		_person.clear()
		for p: Resident in residents.people:
			_person.add_item("%s, %s" % [p.given_name, p.trade])
	_show_day()


## One person's day: a line a block, the present one marked.
func _show_day() -> void:
	for c: Node in _day.get_children():
		c.queue_free()
	if residents == null or _person.selected < 0 or _person.selected >= residents.people.size():
		return
	var p: Resident = residents.people[_person.selected]
	if not is_instance_valid(p):
		return
	var clock: DayClock = DayClock.it()
	var mine: float = fposmod(clock.bells() - p.shift, float(DayClock.BELLS))
	var at: int = p.blocks.size() - 1
	for i: int in p.blocks.size():
		if float(p.blocks[i][0]) <= mine:
			at = i
	for i: int in p.blocks.size():
		var row: Array = p.blocks[i]
		var line := Label.new()
		var when: String = Resident.bell_text(fposmod(float(row[0]) + p.shift, float(DayClock.BELLS)))
		line.text = "%s  %s  %s" % [">" if i == at else "   ", when, RoutineBook.ACTIVITIES.get(row[1], row[1])]
		if i == at:
			line.add_theme_color_override("font_color", NOW)
			line.text += "   (now: %s)" % p.describe(clock.bells()).get_slice("\n", 0)
		_day.add_child(line)
	var note := Label.new()
	note.text = "This person runs %+d s against the bells." % int(round(p.shift * DayClock.BELL_S))
	note.add_theme_font_size_override("font_size", 12)
	_day.add_child(note)


func _trade_now() -> String:
	return str(_trade.get_item_metadata(maxi(_trade.selected, 0)))


## The chosen trade's timetable as rows to edit.
func _show_table() -> void:
	for c: Node in _rows.get_children():
		c.queue_free()
	var book: RoutineBook = RoutineBook.open()
	var table: Array = book.of(_trade_now())
	for i: int in table.size():
		var row: Array = table[i]
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 4)
		var bell := OptionButton.new()
		for b: int in DayClock.BELLS:
			bell.add_item(DayClock.NAMES[b])
		var whole: int = clampi(int(float(row[0])), 0, DayClock.BELLS - 1)
		bell.select(whole)
		line.add_child(bell)
		var plus := Label.new()
		plus.text = "+"
		line.add_child(plus)
		var minutes := SpinBox.new()
		minutes.min_value = 0.0
		minutes.max_value = DayClock.BELL_S / 60.0 - 0.1
		minutes.step = 0.1
		minutes.suffix = "min"
		minutes.value = (float(row[0]) - whole) * DayClock.BELL_S / 60.0
		minutes.custom_minimum_size = Vector2(104, 0)
		line.add_child(minutes)
		var what := OptionButton.new()
		var k: int = 0
		for activity: String in RoutineBook.ACTIVITIES:
			what.add_item(RoutineBook.ACTIVITIES[activity])
			what.set_item_metadata(k, activity)
			if activity == str(row[1]):
				what.select(k)
			k += 1
		what.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(what)
		var gone := Button.new()
		gone.text = "x"
		gone.tooltip_text = "Take this row out."
		gone.disabled = table.size() <= 1
		line.add_child(gone)
		bell.item_selected.connect(func(_b: int) -> void: _on_when(row, bell, minutes))
		minutes.value_changed.connect(func(_v: float) -> void: _on_when(row, bell, minutes, false))
		what.item_selected.connect(func(n: int) -> void: row[1] = str(what.get_item_metadata(n)); _changed(false))
		gone.pressed.connect(func() -> void: table.erase(row); _changed(true))
		_rows.add_child(line)


func _on_when(row: Array, bell: OptionButton, minutes: SpinBox, redraw: bool = true) -> void:
	row[0] = float(bell.selected) + minutes.value * 60.0 / DayClock.BELL_S
	# (The rows are put in order when a bell is chosen, not at every turn of
	# the minutes: a row would jump from under the mouse.)
	_changed(redraw)


func _changed(redraw: bool) -> void:
	_saved.text = "not saved"
	if redraw:
		RoutineBook.open().tidy(_trade_now())
		_show_table()


func _on_add_row() -> void:
	var table: Array = RoutineBook.open().of(_trade_now())
	var last: Array = table[table.size() - 1]
	table.append([minf(float(last[0]) + 0.25, 5.95), "free"])
	_changed(true)


func _on_first() -> void:
	RoutineBook.open().reset(_trade_now())
	_changed(true)


func _on_save() -> void:
	var book: RoutineBook = RoutineBook.open()
	for trade: String in book.trades:
		book.tidy(trade)
	_saved.text = "saved" if book.save() == OK else "could not save"
	_show_table()


func _on_pause() -> void:
	var clock: DayClock = DayClock.it()
	clock.paused = not clock.paused
	_refresh()


func _on_speed(s: float) -> void:
	DayClock.it().speed = s
	_refresh()


func _on_bell(i: int) -> void:
	DayClock.it().jump_to_bell(i)
	_refresh()


func _on_labels(on: bool) -> void:
	residents.labels = on


func _on_overlay(on: bool) -> void:
	residents.show_overlay(on)

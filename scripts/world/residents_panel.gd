class_name ResidentsPanel
extends CanvasLayer
## The People panel (phase 21 steps 2-3): F6 opens and closes it; the mouse is
## freed while it is open. The day's clock (pause, speed, jump to a bell),
## labels over people, the overlay (spots and ways, also on F4), and a line
## for each person. Speed and pause are not saved; the time of day is.
##
## Later steps add: everyone off-stage, a person's whole day, and the
## timetables as sliders.

const SPEEDS: Array[float] = [1.0, 10.0, 30.0, 60.0]
const WIDTH: int = 430

var residents: Residents
var _clock_text: Label
var _roll: Label
var _pause: Button
var _speeds: Array[Button] = []
var _labels: CheckBox
var _overlay: CheckBox
var _tick: float = 0.0


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
	_labels = CheckBox.new()
	_labels.text = "Labels over people"
	_labels.toggled.connect(_on_labels)
	rows.add_child(_labels)
	_overlay = CheckBox.new()
	_overlay.text = "Spots and ways  (F4)"
	_overlay.tooltip_text = "Every spot as a ring, named with who has it; the way each walker is taking; where people can walk."
	_overlay.toggled.connect(_on_overlay)
	rows.add_child(_overlay)
	rows.add_child(HSeparator.new())
	_roll = Label.new()
	_roll.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_roll.custom_minimum_size = Vector2(WIDTH - 24, 0)
	rows.add_child(_roll)
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
	_roll.text = "\n".join(lines) if not lines.is_empty() else "Nobody lives here yet."


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

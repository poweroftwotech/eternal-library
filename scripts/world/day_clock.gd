class_name DayClock
extends Node
## The day (phase 21 step 2, docs/npc/phase-21-approval.md Q1, Q2): the
## autoload "Day". The Library has no sun; a day is kept by six bells. It lasts
## DAY_S real seconds at speed 1, each bell BELL_S after the one before, and
## the first bell is when people get up. The time is in the save
## (WorldState.data "day_s") and passes while the game runs.
##
## A bell rings as many strokes as its number, so you can count the hour.
## Residents (scripts/actors/resident.gd) read bells() for their timetables.
## The People panel (F6) changes `speed` and jumps to a bell; neither is saved.

signal bell_rang(index: int)

const DAY_S: float = 2880.0
const BELLS: int = 6
const BELL_S: float = DAY_S / BELLS
const NAMES: PackedStringArray = ["First bell", "Second bell", "Third bell", "Fourth bell", "Fifth bell", "Sixth bell"]
## A new world starts a little after the first bell.
const START_S: float = BELL_S * 0.25
## Seconds between a bell's strokes, and how loud (dB).
const STROKE_S: float = 1.7
const BELL_DB: float = -8.0
## Faster than this and a bell rings one stroke, not its number.
const FAST: float = 12.0
const BUS: String = "People"

## Seconds of day-time since the world began.
var time: float = START_S
## How fast it runs (1: as played; the panel's 10, 30, 60).
var speed: float = 1.0
var paused: bool = false
var _written: float = -1.0
var _strokes: int = 0
var _next_stroke: float = 0.0
var _voice: AudioStreamPlayer


## The autoload, found at run time (as SoundSystem.it()). Null outside the game.
static func it() -> DayClock:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("Day") as DayClock if tree != null else null


func _ready() -> void:
	_voice = AudioStreamPlayer.new()
	_voice.bus = BUS if AudioServer.get_bus_index(BUS) >= 0 else "Master"
	_voice.volume_db = BELL_DB
	_voice.max_polyphony = 4
	add_child(_voice)


func _process(delta: float) -> void:
	_sync()
	# The strokes still to ring keep real time, whatever the clock's speed.
	if _strokes > 0:
		_next_stroke -= delta
		if _next_stroke <= 0.0:
			_stroke()
	if paused:
		return
	var before: int = bell_index()
	time += delta * speed
	_store()
	if bell_index() != before:
		_ring(bell_index())


## The time in bells since the first bell: 0 up to (not including) 6.
func bells() -> float:
	return fposmod(time, DAY_S) / BELL_S


## Which bell rang last: 0 (the first) to 5.
func bell_index() -> int:
	return mini(int(bells()), BELLS - 1)


## Days since the world began.
func day() -> int:
	return int(time / DAY_S)


## "Third bell and 2:10" (minutes and seconds since it rang).
func text() -> String:
	var into: float = (bells() - bell_index()) * BELL_S
	return "%s and %d:%02d" % [NAMES[bell_index()], int(into / 60.0), int(into) % 60]


## Moves the day on to the next time bell `index` (0..5) rings, and rings it.
func jump_to_bell(index: int) -> void:
	var into: float = fposmod(time, DAY_S)
	var at: float = index * BELL_S
	time += at - into if at > into else at - into + DAY_S
	time += 0.01
	_store()
	_ring(index)


func _ring(index: int) -> void:
	_strokes = 1 if speed > FAST else index + 1
	_next_stroke = 0.0
	bell_rang.emit(index)


func _stroke() -> void:
	_strokes -= 1
	_next_stroke = STROKE_S
	var sound: SoundSystem = SoundSystem.it()
	var stream: AudioStream = sound.clip("bell") if sound != null else null
	if stream != null:
		_voice.stream = stream
		_voice.play()


# The save holds the time. Another save loaded, or a new world: take its time.
func _sync() -> void:
	var data: Dictionary = _data()
	if data.is_empty():
		return
	if not data.has("day_s"):
		time = START_S
		_store()
	elif not is_equal_approx(float(data["day_s"]), _written):
		time = float(data["day_s"])
		_written = time


func _store() -> void:
	var data: Dictionary = _data()
	if not data.is_empty():
		data["day_s"] = time
		_written = time


func _data() -> Dictionary:
	var ws: Node = get_tree().root.get_node_or_null("WorldState")
	return ws.get("data") as Dictionary if ws != null else {}

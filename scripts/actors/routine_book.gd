class_name RoutineBook
extends Resource
## The timetables of the trades (phase 21 step 4, Q4): one for each trade, as
## blocks of the day. Kept in one file, gen/people/routines.tres, which the
## People panel edits and saves. Everyone of a trade reads the same list, so a
## change shows at once.
##
## A timetable: [[bell, activity], ...] in order, the bell counted from the
## first (0.0) to just before the first again (6.0). The block before the
## first row is the last row's (the night runs round).

const PATH: String = "res://gen/people/routines.tres"
## What a block can be, and what the panel calls it.
const ACTIVITIES: Dictionary = {
	"sleep": "Sleep", "wake": "Get up", "eat": "Eat", "cook": "Cook", "work": "Work at home", "keep": "Keep the stall",
	"tend": "Tend the lamps", "water": "Fetch water", "shop": "Go to the stall", "hauz": "Sit at the hauz", "door": "Stand at the door",
	"sit": "Sit at home", "free": "Free time", "away": "Away from the lane",
}
## The timetables as first written (tools/make_routines.gd writes the file
## from these; the panel's "As first written" goes back to them).
const FIRST: Dictionary = {
	"cook": [[0.0, "wake"], [0.08, "water"], [0.2, "cook"], [0.7, "eat"], [1.1, "free"], [1.45, "shop"], [1.6, "free"], [1.86, "water"], [2.0, "cook"],
			[2.5, "eat"], [3.0, "free"], [3.86, "water"], [4.0, "cook"], [4.4, "eat"], [4.8, "door"], [5.0, "sleep"]],
	"stall keeper": [[0.15, "wake"], [0.3, "door"], [0.7, "eat"], [1.1, "keep"], [2.5, "eat"], [3.0, "keep"], [4.4, "eat"], [4.8, "hauz"], [5.05, "sleep"]],
	"lamp tender": [[0.1, "wake"], [0.22, "tend"], [0.7, "eat"], [1.1, "free"], [2.5, "eat"], [3.0, "hauz"], [3.6, "free"], [4.4, "eat"], [4.75, "tend"],
			[5.2, "sleep"]],
	"scholar": [[0.2, "wake"], [0.3, "water"], [0.42, "work"], [1.0, "eat"], [1.25, "work"], [1.7, "shop"], [1.85, "work"], [2.6, "eat"], [2.85, "work"],
			[4.3, "eat"], [4.55, "hauz"], [5.1, "sleep"]],
	"hunter": [[0.0, "wake"], [0.1, "eat"], [0.35, "away"], [3.3, "shop"], [3.45, "work"], [4.0, "water"], [4.15, "eat"], [4.5, "hauz"], [4.95, "sleep"]],
	"ossuary keeper": [[0.2, "wake"], [0.5, "eat"], [0.8, "work"], [2.5, "eat"], [2.9, "work"], [4.4, "eat"], [4.7, "free"], [5.1, "sleep"]],
}

## trade -> its timetable.
@export var trades: Dictionary = {}

static var _book: RoutineBook


## The one book: the file's, or the timetables as first written if there is none.
static func open() -> RoutineBook:
	if _book == null:
		if ResourceLoader.exists(PATH):
			_book = ResourceLoader.load(PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as RoutineBook
		if _book == null:
			_book = RoutineBook.new()
		for trade: String in FIRST:
			if not _book.trades.has(trade):
				_book.trades[trade] = (FIRST[trade] as Array).duplicate(true)
	return _book


## A trade's timetable (the list itself: change it and everyone follows).
func of(trade: String) -> Array:
	if not trades.has(trade):
		trades[trade] = [[0.2, "wake"], [1.0, "free"], [5.0, "sleep"]]
	return trades[trade]


## Puts a timetable's rows in order of time (after an edit).
func tidy(trade: String) -> void:
	var rows: Array = of(trade)
	for row: Array in rows:
		row[0] = clampf(snappedf(float(row[0]), 0.01), 0.0, 5.99)
	rows.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))


## A trade's timetable as it was first written (in place).
func reset(trade: String) -> void:
	var rows: Array = of(trade)
	rows.clear()
	rows.append_array((FIRST.get(trade, [[0.2, "wake"], [1.0, "free"], [5.0, "sleep"]]) as Array).duplicate(true))


func save() -> int:
	DirAccess.make_dir_recursive_absolute(PATH.get_base_dir())
	return ResourceSaver.save(self, PATH)

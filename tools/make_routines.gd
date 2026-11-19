extends SceneTree
## Writes the trades' timetables as first written to gen/people/routines.tres
## (phase 21 step 4). Run once, or to throw away every change made in the
## People panel:
##   godot --headless --path . --script res://tools/make_routines.gd


func _initialize() -> void:
	var book := RoutineBook.new()
	for trade: String in RoutineBook.FIRST:
		book.trades[trade] = (RoutineBook.FIRST[trade] as Array).duplicate(true)
	var err: int = book.save()
	print("make_routines: %d trades -> %s (%d)" % [book.trades.size(), RoutineBook.PATH, err])
	quit(err)

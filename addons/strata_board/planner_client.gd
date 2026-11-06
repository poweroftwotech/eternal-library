@tool
extends Node
## The Strata Board's way to the game's planner (strata_service.gd). In the
## editor it starts service_main.gd as a headless Godot process and writes
## requests on its stdin; answers come back on its stdout, read a frame at a
## time, so planning never stalls the editor. With `local` set (tests, the
## game) it calls the service in this process instead, one request a frame.
##
## request(req, callback): callback(answer: Dictionary) once the answer is in.
## Requests are answered in order; urgent ones go to the front of the queue.

const SERVICE: String = "res://addons/strata_board/service_main.gd"
const SERVICE_CLASS: String = "res://addons/strata_board/strata_service.gd"
const PREFIX: String = "@@sb "

## Run the service in this process (no pipe).
var local: bool = false

var _pipe: Dictionary = {}
var _out: String = ""
var _next_id: int = 1
var _waiting: Dictionary = {}     # id -> callback
var _queue: Array = []            # [id, request] not yet sent (local: not yet run)
var _busy: int = 0                # the id the service is on (one at a time)


func _ready() -> void:
	set_process(true)


func _exit_tree() -> void:
	stop()


## This Godot. On Windows the _console build is the one whose output always
## reaches a pipe.
static func godot_exe() -> String:
	var exe: String = OS.get_executable_path()
	var console: String = exe.get_basename() + "_console." + exe.get_extension()
	if not exe.get_basename().ends_with("_console") and FileAccess.file_exists(console):
		return console
	return exe


## Starts the service process if it isn't running.
func start() -> void:
	if local or running():
		return
	var exe: String = godot_exe()
	_pipe = OS.execute_with_pipe(exe, ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", SERVICE], false)
	_out = ""
	_busy = 0
	if _pipe.is_empty():
		push_warning("Strata Board: could not start the planner (%s)" % exe)


func running() -> bool:
	return not _pipe.is_empty() and OS.is_process_running(int(_pipe["pid"]))


func stop() -> void:
	if not _pipe.is_empty():
		if running():
			(_pipe["stdio"] as FileAccess).store_string("quit\n")
			(_pipe["stdio"] as FileAccess).flush()
		_pipe = {}
	_waiting.clear()
	_queue.clear()
	_busy = 0


## Sends a request; `urgent` puts it before every queued one. Returns its id.
func request(req: Dictionary, callback: Callable, urgent: bool = false) -> int:
	var id: int = _next_id
	_next_id += 1
	_waiting[id] = callback
	var item: Array = [id, req]
	if urgent:
		_queue.push_front(item)
	else:
		_queue.append(item)
	return id


## Drops queued requests whose id is in `ids` (a sweep that's been replaced).
func cancel(ids: Array) -> void:
	_queue = _queue.filter(func(item: Array) -> bool: return not ids.has(item[0]))
	for id: int in ids:
		if id != _busy:
			_waiting.erase(id)


func pending() -> int:
	return _queue.size() + (1 if _busy != 0 else 0)


func _process(_delta: float) -> void:
	if local:
		if not _queue.is_empty():
			var item: Array = _queue.pop_front()
			var answer: Dictionary = load(SERVICE_CLASS).call("handle", item[1])
			_answer(item[0], answer)
		return
	if _queue.is_empty() and _busy == 0:
		return
	if not running():
		if _busy != 0:     # it stopped (or crashed) on this one
			var lost: int = _busy
			_busy = 0
			_answer(lost, {"error": "the planner process stopped while planning this"})
		start()
		if not running():
			return
	var io: FileAccess = _pipe["stdio"]
	var got: String = io.get_as_text()
	(_pipe["stderr"] as FileAccess).get_as_text()     # drained, so the service never blocks on a full pipe
	if got != "":
		_out += got
		var lines: PackedStringArray = _out.split("\n")
		_out = lines[-1]
		for i: int in lines.size() - 1:
			var line: String = lines[i].strip_edges()
			if not line.begins_with(PREFIX):
				continue
			var answer: Variant = JSON.parse_string(line.trim_prefix(PREFIX))
			if answer is Dictionary:
				var id: int = int((answer as Dictionary).get("id", -1))
				if id == _busy:
					_busy = 0
				_answer(id, answer)
	if _busy == 0 and not _queue.is_empty():
		var item: Array = _queue.pop_front()
		_busy = item[0]
		var req: Dictionary = (item[1] as Dictionary).duplicate()
		req["id"] = item[0]
		io.store_string(JSON.stringify(req) + "\n")
		io.flush()


func _answer(id: int, answer: Dictionary) -> void:
	var cb: Variant = _waiting.get(id)
	_waiting.erase(id)
	if cb is Callable and (cb as Callable).is_valid():
		(cb as Callable).call(answer)

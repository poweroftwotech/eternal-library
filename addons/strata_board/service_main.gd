extends SceneTree
## The Strata Board's planner process (strata_service.gd): the board starts it
##   godot --headless --path <project> --script res://addons/strata_board/service_main.gd
## and writes one JSON request a line on its stdin; each answer is one line
## on stdout, "@@sb " + JSON with the request's id. Anything else on stdout
## (the engine's own lines) is not an answer. Ends on "quit" or end of input.

const PREFIX: String = "@@sb "
## By path, not class_name: a bare process may not have the class cache yet.
const Service: GDScript = preload("res://addons/strata_board/strata_service.gd")


func _initialize() -> void:
	var pending: String = ""
	while true:
		var chunk: String = OS.read_string_from_stdin(65536)
		if chunk == "":
			break     # the board went away
		pending += chunk
		var lines: PackedStringArray = pending.split("\n")
		pending = lines[-1]     # an unfinished line waits for the rest
		# A chunk's last newline doesn't come through: a last line that is
		# already a whole request is done.
		if JSON.parse_string(pending.strip_edges()) is Dictionary or pending.strip_edges() == "quit":
			lines.append("")
			pending = ""
		for i: int in lines.size() - 1:
			var line: String = lines[i].strip_edges()
			if line == "":
				continue
			if line == "quit":
				quit()
				return
			var req: Variant = JSON.parse_string(line)
			var answer: Dictionary = Service.handle(req) if req is Dictionary else {"error": "not JSON: %s" % line.left(80)}
			answer["id"] = (req as Dictionary).get("id", -1) if req is Dictionary else -1
			print(PREFIX + JSON.stringify(answer))
	quit()

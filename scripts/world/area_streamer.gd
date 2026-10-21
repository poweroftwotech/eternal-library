class_name AreaStreamer
extends Node
## Keeps the rooms near the player live and lets the rest go
## (phase-4-design.md 8.1.4, step 2). A child of the Area.
##
## Which rooms: within load_radius doorways of the player's room, every room
## the plan says is visible from it or from a room one doorway away, and the
## pinned rooms. A live room unloads once it is further than unload_radius
## doorways, out of sight, for unload_delay_s.
##
## Building a room is split into steps run within build_budget_ms a frame
## (at least one step a frame): make the node; build a generated room's
## modules off the tree; resolve its sockets off the tree in slices; then
## enter the tree in one call. Doorways onto rooms that aren't built yet are
## closed by DoorSeals.

enum RoomState { UNLOADED, STAND_IN, LIVE }
## A make, modules or enter step takes up to about this long once warm
## (step 2 measurements): one isn't started with less budget left.
const STEP_ESTIMATE_MS: float = 2.5

signal room_loaded(slot: String)
signal room_unloaded(slot: String)

var area: Area
var settings: StreamSettings
## What the player is (its position picks the room); null: stay where we started.
var target: Node3D
## slot -> RoomState.
var states: Dictionary = {}
## The room the player was last seen in.
var player_room: String = ""
## Seconds each live, unwanted room has been far away.
var away: Dictionary = {}
## Slots waiting to be built, nearest first.
var queue: Array[String] = []
## Doorway ("slot/connector" of the live side) -> its DoorSeal.
var seals: Dictionary = {}
## Work done: frames, max and last frame's streaming milliseconds, rooms
## loaded and unloaded, and per room {build_ms (all steps), steps, max_step_ms}.
var stats: Dictionary = {"frames": 0, "max_frame_ms": 0.0, "last_frame_ms": 0.0, "loads": 0, "unloads": 0, "rooms": {}}
var _check: float = 0.0
var _job: Dictionary = {}


## Builds what the player at `start_slot` needs, all at once (behind the
## start-up wait), then prepares every other room once off the tree and
## throws it away, so the first use of its scenes and resources happens now
## rather than while you walk.
func start(start_slot: String) -> void:
	player_room = start_slot
	for r: AreaPlan.Room in area.plan.rooms:
		states[r.slot_id] = RoomState.UNLOADED
	_refresh_queue()
	while not queue.is_empty():
		_job = _new_job(queue.pop_front())
		while not _job.is_empty():
			_step(-1)
	for r: AreaPlan.Room in area.plan.rooms:
		if states[r.slot_id] == RoomState.UNLOADED:
			var job: Dictionary = _new_job(r.slot_id)
			while job["stage"] != "enter":
				_run_stage(job, -1)
			(job["room"] as Node).free()
	_update_seals()
	stats = {"frames": 0, "max_frame_ms": 0.0, "last_frame_ms": 0.0, "loads": 0, "unloads": 0, "rooms": {}}     # count the walk, not the start


## True while a room is being built or taken apart, or one is waiting to be built.
func busy() -> bool:
	return not queue.is_empty() or not _job.is_empty() or not _leaving.is_empty()


func live_count() -> int:
	return states.values().filter(func(s: int) -> bool: return s == RoomState.LIVE).size()


func is_live(slot: String) -> bool:
	return states.get(slot, RoomState.UNLOADED) == RoomState.LIVE


## Doorways from `from` to every room.
func distances(from: String) -> Dictionary:
	var out: Dictionary = {from: 0}
	var todo: Array[String] = [from]
	while not todo.is_empty():
		var s: String = todo.pop_front()
		for e: Dictionary in area.plan.edges:
			for pair: Array in [[e["a"], e["b"]], [e["b"], e["a"]]]:
				if pair[0] == s and not out.has(pair[1]):
					out[pair[1]] = int(out[s]) + 1
					todo.append(pair[1])
	return out


## The rooms that should be live with the player in `from`: slot -> doorways away.
func wanted(from: String) -> Dictionary:
	var dist: Dictionary = distances(from)
	var out: Dictionary = {}
	for s: String in dist:
		if int(dist[s]) <= settings.load_radius:
			out[s] = dist[s]
	var seen_from: Array = [from]
	for s: String in dist:
		if int(dist[s]) == 1:
			seen_from.append(s)
	for s: String in seen_from:
		for v: String in area.plan.visible.get(s, PackedStringArray()):
			out[v] = dist.get(v, 99)
	for r: AreaPlan.Room in area.plan.rooms:
		if r.pinned:
			out[r.slot_id] = dist.get(r.slot_id, 99)
	return out


func _process(delta: float) -> void:
	var t0: int = Time.get_ticks_usec()
	_check -= delta
	if _check <= 0.0:
		_check = settings.check_interval_s
		_update_player_room()
		_refresh_queue()
		_unload_far(settings.check_interval_s)
	var deadline: int = t0 + int(settings.build_budget_ms * 1000.0)
	# An unload this frame counts against the budget; otherwise at least one step runs.
	var worked: bool = Time.get_ticks_usec() - t0 > int(settings.build_budget_ms * 500.0)
	var room_left: int = int(STEP_ESTIMATE_MS * 1000.0)
	while (not _job.is_empty() or not queue.is_empty()) and (not worked or Time.get_ticks_usec() + room_left < deadline or _job.get("stage", "") == "resolve"):
		if worked and Time.get_ticks_usec() >= deadline:
			break
		if _job.is_empty():
			_job = _new_job(queue.pop_front())
		_step(deadline)
		worked = true
	if not _leaving.is_empty():
		_take_apart(deadline)     # what budget is left, at least one piece
	var ms: float = (Time.get_ticks_usec() - t0) / 1000.0
	stats["frames"] += 1
	stats["last_frame_ms"] = ms
	stats["max_frame_ms"] = maxf(float(stats["max_frame_ms"]), ms)


func _update_player_room() -> void:
	if target == null or not is_instance_valid(target):
		return
	var r: AreaPlan.Room = area.room_at(target.global_position)
	if r != null:
		player_room = r.slot_id


## Queues every wanted room that isn't live or being built, nearest first.
func _refresh_queue() -> void:
	var want: Dictionary = wanted(player_room)
	var building: String = _job.get("slot", "")
	queue = []
	for s: String in want:
		if states.get(s, RoomState.UNLOADED) != RoomState.LIVE and s != building:
			queue.append(s)
	queue.sort_custom(func(a: String, b: String) -> bool: return int(want[a]) < int(want[b]) or (want[a] == want[b] and a < b))


func _unload_far(elapsed: float) -> void:
	var want: Dictionary = wanted(player_room)
	var dist: Dictionary = distances(player_room)
	for s: String in states.keys():
		if states[s] != RoomState.LIVE or want.has(s) or int(dist.get(s, 99)) <= settings.unload_radius:
			away.erase(s)
			continue
		away[s] = float(away.get(s, 0.0)) + elapsed
		if float(away[s]) >= settings.unload_delay_s:
			unload(s)


## Takes a live room out (its moving props saved where they are first). It
## stops counting as live at once, but leaves the tree a few pieces a frame
## within the build budget (_take_apart): removing and freeing a whole room
## at once cost up to about 8 ms in one frame on the GPU renderer. It is out
## of sight by then.
func unload(slot: String) -> void:
	var room: RoomTemplate = area.rooms.get(slot)
	if room == null:
		return
	var t0: int = Time.get_ticks_usec()
	room._flush_moving()
	var ws: Node = room.world_state()
	if ws != null and (ws.get("rooms") as Dictionary).get(room.room_key()) == room:
		(ws.get("rooms") as Dictionary).erase(room.room_key())
	area.rooms.erase(slot)
	room.name = "%s_leaving_%d" % [slot, stats["unloads"]]
	_leaving.append({"slot": slot, "room": room, "pieces": []})
	states[slot] = RoomState.UNLOADED
	away.erase(slot)
	stats["unloads"] += 1
	_update_seals()
	stats["max_unload_ms"] = maxf(float(stats.get("max_unload_ms", 0.0)), (Time.get_ticks_usec() - t0) / 1000.0)


## Rooms leaving the tree: [{slot, room, pieces}].
var _leaving: Array[Dictionary] = []


## Removes and frees pieces of leaving rooms until `deadline` (at least one): first
## every grandchild of the room (modules, props, sockets' holders), then its
## children, then the room. Returns true if any room is still leaving.
func _take_apart(deadline: int) -> bool:
	while not _leaving.is_empty():
		var job: Dictionary = _leaving[0]
		var room: Node = job["room"]
		var pieces: Array = job["pieces"]
		if pieces.is_empty():
			for c: Node in room.get_children():
				pieces.append_array(c.get_children())
			pieces.append_array(room.get_children())
			pieces.append(room)
		while not pieces.is_empty():
			var n: Node = pieces.pop_front()
			var last: bool = n == room
			if is_instance_valid(n):
				if n.get_parent() != null:
					n.get_parent().remove_child(n)
				n.free()     # now, inside the budget (queue_free left the cost to the end of the frame)
			if last:
				_leaving.pop_front()
				room_unloaded.emit(job["slot"])
				break
			if Time.get_ticks_usec() >= deadline:
				return true
		if Time.get_ticks_usec() >= deadline:
			break
	return not _leaving.is_empty()


func _new_job(slot: String) -> Dictionary:
	var r: AreaPlan.Room = area.plan.room(slot)
	return {"slot": slot, "plan": r, "stage": "make", "room": null, "ms": 0.0, "steps": 0, "max_step_ms": 0.0}


## One step of the current job, then the job ends if the room is live.
func _step(deadline: int) -> void:
	var t0: int = Time.get_ticks_usec()
	_run_stage(_job, deadline)
	var ms: float = (Time.get_ticks_usec() - t0) / 1000.0
	_job["ms"] += ms
	_job["steps"] += 1
	_job["max_step_ms"] = maxf(float(_job["max_step_ms"]), ms)
	stats["max_step"] = maxf(float(stats.get("max_step", 0.0)), ms)
	if ms >= float(stats.get("max_step", 0.0)):
		stats["max_step_where"] = "%s %s" % [_job["slot"], _job.get("last_stage", "")]
	if _job["stage"] == "done":
		stats["rooms"][_job["slot"]] = {"build_ms": _job["ms"], "steps": _job["steps"], "max_step_ms": _job["max_step_ms"]}
		_job = {}


func _run_stage(job: Dictionary, deadline: int) -> void:
	var r: AreaPlan.Room = job["plan"]
	job["last_stage"] = job["stage"]
	match job["stage"]:
		"make":
			job["room"] = area.make_room(r)
			job["stage"] = "modules" if r.kind == "generated" else "resolve_begin"
		"modules":
			(job["room"] as GeneratedRoom).build_planned_modules()
			job["stage"] = "resolve_begin"
		"resolve_begin":
			var room: RoomTemplate = job["room"]
			room.begin_resolve(r.seed_value)
			job["stage"] = "resolve"
		"resolve":
			var room: RoomTemplate = job["room"]
			if room.resolve_next(deadline):
				room.prepared = true
				job["stage"] = "enter"
		"enter":
			area.enter_room(r, job["room"])
			states[r.slot_id] = RoomState.LIVE
			away.erase(r.slot_id)
			stats["loads"] += 1
			_update_seals()
			job["stage"] = "done"
			room_loaded.emit(r.slot_id)


## A seal on every doorway with a live room on one side only.
func _update_seals() -> void:
	var need: Dictionary = {}
	for e: Dictionary in area.plan.edges:
		var a_live: bool = is_live(e["a"])
		var b_live: bool = is_live(e["b"])
		if a_live == b_live:
			continue
		var side: String = e["a"] if a_live else e["b"]
		var conn: StringName = e["a_conn"] if a_live else e["b_conn"]
		need["%s/%s" % [side, conn]] = area.plan.room(side).connectors[conn]["xf"]
	for k: String in seals.keys():
		if not need.has(k):
			(seals[k] as Node).queue_free()
			seals.erase(k)
	for k: String in need:
		if not seals.has(k):
			var seal: DoorSeal = DoorSeal.make(need[k])
			seal.name = "Seal_" + k.replace("/", "_")
			area.add_child(seal)
			seals[k] = seal

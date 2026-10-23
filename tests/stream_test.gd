extends SceneTree
## Gate for rooms loading as you walk (phase-4-design.md 8.1.7, step 2).
##   godot --headless --path . --script res://tests/stream_test.gd [-- seeds=N] [area=<id>]
## For area seeds 1-5 of the library wing and of the Lower Stacks (phase 5),
## a scripted walk from the root room (AreaTour) out to
## every leaf gallery and back, a cell at a time. At every cell: every room
## within 2 doorways, every room visible from here or one doorway on, and the root
## (pinned) is live; no doorway of this room or its neighbours is sealed.
## Each time the walk enters a new room and the unload delay has passed,
## nothing further than 3 doorways and out of sight is still live. An
## unloaded room leaves no node, awake prop, floor wear or WorldState entry.
## A lamp tended in the farthest gallery is still tended after that gallery
## has unloaded and loaded again. Prints the streaming work per frame and
## per room (headless, so CPU only).

## Both areas (phase-5-design.md 5.6.9); `area=<id>` runs one.
const RECIPES: Dictionary = {"library": "res://gen/recipes/library_wing.tres", "lower_stacks": "res://gen/recipes/lower_stacks.tres"}
const SEEDS: int = 5

var failures: PackedStringArray = []
var checks: int = 0
var area: Area
var target: Node3D
var unloaded_ok: bool = true
var unload_problems: PackedStringArray = []


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures.append(what)


func run() -> void:
	var seeds: int = SEEDS
	var areas: Array = RECIPES.keys()
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("seeds="):
			seeds = a.trim_prefix("seeds=").to_int()
		elif a.begins_with("area="):
			areas = [a.trim_prefix("area=")]
	for id: String in areas:
		for s: int in range(1, seeds + 1):
			await walk_seed(id, s)
	Area.seed_override = -1
	print("stream_test: %d checks, %d failures" % [checks, failures.size()])
	for f: String in failures:
		print("  FAIL ", f)
	quit(1 if not failures.is_empty() else 0)


func walk_seed(id: String, s: int) -> void:
	var tag: String = "%s seed %d" % [id, s]
	Area.seed_override = s
	area = Area.new()
	area.recipe = load(RECIPES[id])
	var settings := StreamSettings.new()
	settings.unload_delay_s = 0.4
	settings.check_interval_s = 0.05
	area.stream_settings = settings
	root.add_child(area)
	target = Node3D.new()
	root.add_child(target)
	target.global_position = area.spawn_transform().origin
	area.streamer.target = target
	unload_problems = []
	area.streamer.room_unloaded.connect(_on_unloaded)
	var p: AreaPlan = area.plan
	var st: AreaStreamer = area.streamer
	var want0: Dictionary = st.wanted(st.player_room)
	check(st.is_live(p.rooms[0].slot_id) and st.live_count() == want0.size() and want0.keys().all(func(k: String) -> bool: return st.is_live(k)),
		"%s: at the start exactly the wanted rooms are live (%d of %d; wanted %s)" % [tag, st.live_count(), p.rooms.size(), want0.keys()])
	# The farthest leaf: walked to first, a lamp tended there, checked again at the end.
	var leaves: Array[AreaPlan.Room] = []
	for r: AreaPlan.Room in p.rooms:
		if r.parent != "" and r.children_count() == 0:
			leaves.append(r)
	leaves.sort_custom(func(a: AreaPlan.Room, b: AreaPlan.Room) -> bool: return a.depth > b.depth or (a.depth == b.depth and a.slot_id < b.slot_id))
	var far: AreaPlan.Room = leaves[0]
	var tended: Dictionary = {}
	var bad_live: PackedStringArray = []
	var bad_far: PackedStringArray = []
	var sealed: PackedStringArray = []
	var steps: int = 0
	var max_live: int = 0
	var far_unloaded: bool = false
	var came_back: String = "not checked"
	var walks: Array = leaves + [far]
	for walk_i: int in walks.size():
		var leaf: AreaPlan.Room = walks[walk_i]
		var route: Array[Vector3] = AreaTour.leg(p, leaf)
		var back: Array[Vector3] = route.duplicate()
		back.reverse()
		var last_room: String = ""
		for pos: Vector3 in route + back:
			target.global_position = pos + Vector3(0, 0.95, 0)
			await settle()
			steps += 1
			var here: String = st.player_room
			var want: Dictionary = st.wanted(here)
			for w: String in want:
				if not st.is_live(w) or area.get_node_or_null(NodePath(w)) == null:
					bad_live.append("%s from %s" % [w, here])
			var near: Array = [here]
			var dist: Dictionary = st.distances(here)
			for k: String in dist:
				if int(dist[k]) == 1:
					near.append(k)
			for key: String in st.seals:
				if near.has(key.get_slice("/", 0)):
					sealed.append("%s while in %s" % [key, here])
			max_live = maxi(max_live, st.live_count())
			if here != last_room:
				last_room = here
				await wait_seconds(settings.unload_delay_s + settings.check_interval_s * 3.0)
				await settle()
				dist = st.distances(st.player_room)
				want = st.wanted(st.player_room)
				for k: String in st.states:
					if st.is_live(k) and not want.has(k) and int(dist.get(k, 99)) > settings.unload_radius:
						bad_far.append("%s live from %s" % [k, st.player_room])
			if leaf == far and here == far.slot_id and pos == route[-1]:
				if walk_i == 0:
					tended = tend_a_lamp(far.slot_id)
				elif not tended.is_empty():
					came_back = lamp_label(far.slot_id, tended["path"])
			if not tended.is_empty() and not st.is_live(far.slot_id):
				far_unloaded = true
	check(bad_live.is_empty(), "%s: every wanted room is live at every one of %d steps (%s)" % [tag, steps, bad_live.slice(0, 6)])
	check(bad_far.is_empty(), "%s: nothing far and out of sight stays live past the delay (%s)" % [tag, bad_far.slice(0, 6)])
	check(sealed.is_empty(), "%s: no seal on a doorway of the player's room or its neighbours (%s)" % [tag, sealed.slice(0, 6)])
	check(unload_problems.is_empty(), "%s: unloaded rooms leave nothing behind (%s)" % [tag, unload_problems.slice(0, 6)])
	check(st.stats["unloads"] > 0 or p.rooms.size() <= 5, "%s: rooms were unloaded on the walk (%d)" % [tag, st.stats["unloads"]])
	if tended.is_empty():
		check(false, "%s: found a lamp to tend in %s" % [tag, far.slot_id])
	else:
		# A hall whose galleries all open off it keeps every room within reach.
		var far_reach: int = st.distances(far.slot_id).values().max()
		if far_reach > settings.unload_radius:
			check(far_unloaded, "%s: %s unloaded while we were away" % [tag, far.slot_id])
		else:
			print("  %s: every room is within %d doorways of %s, so it never unloads" % [tag, far_reach, far.slot_id])
		check(came_back == tended["label"], "%s: the lamp tended in %s is still %s after it unloaded and came back (%s)" % [tag, far.slot_id, tended["label"], came_back])
	report(tag, st, max_live)
	area.streamer.room_unloaded.disconnect(_on_unloaded)
	target.queue_free()
	area.queue_free()
	await process_frame
	await process_frame


## Tends the first lamp socket in `slot` to the opposite of what it shows;
## returns {path, label}.
func tend_a_lamp(slot: String) -> Dictionary:
	var room: RoomTemplate = area.rooms.get(slot)
	if room == null:
		return {}
	for s: VariantSocket in room.sockets():
		if s.mode == VariantSocket.Mode.STATE and s.socket_set != null and s.socket_set.index_of("lit") >= 0 and s.socket_set.index_of("dark") >= 0:
			var label: String = "dark" if s.picked_label() == "lit" else "lit"
			room.tend_lamp(s, label)
			return {"path": room.socket_key(s), "label": label}
	return {}


func _on_unloaded(slot: String) -> void:
	await process_frame
	var key_prefix: String = slot + "@"
	if area.get_node_or_null(NodePath(slot)) != null:
		unload_problems.append("%s still a child" % slot)
	for prop: WorldProp in WorldProp.awake_props:
		if is_instance_valid(prop) and str(prop.get_meta("world_id", "")).begins_with(key_prefix):
			unload_problems.append("%s left an awake prop" % slot)
	for w: FloorWear in FloorWear._live:
		if is_instance_valid(w) and w.is_inside_tree() and str(w.get_parent().name) == slot:
			unload_problems.append("%s left its floor wear" % slot)
	for k: String in (root.get_node("/root/WorldState").get("rooms") as Dictionary):
		if k.begins_with(key_prefix):
			unload_problems.append("%s is still registered as a live room" % slot)


func report(tag: String, st: AreaStreamer, max_live: int) -> void:
	var worst: Array = []
	for slot: String in st.stats["rooms"]:
		var r: Dictionary = st.stats["rooms"][slot]
		worst.append("%s %.1f ms in %d steps (max %.1f)" % [slot, r["build_ms"], r["steps"], r["max_step_ms"]])
	print("  %s: %d rooms, at most %d live; built %d, unloaded %d; slowest streaming frame %.1f ms (slowest step %.1f ms: %s; slowest unload %.1f ms); wear regions up to %.0f ms on a thread" % [tag,
		area.plan.rooms.size(), max_live, st.stats["loads"], st.stats["unloads"], st.stats["max_frame_ms"], st.stats.get("max_step", 0.0), st.stats.get("max_step_where", ""), st.stats.get("max_unload_ms", 0.0), FloorWear.max_region_ms])
	print("    " + ", ".join(worst))


## Frames until the streamer has nothing queued or building and the wear map is done.
func settle() -> void:
	for i: int in 3:
		await process_frame
	for i: int in 600:
		if not area.streamer.busy() and not FloorWear.busy():
			return
		await process_frame


func wait_seconds(t: float) -> void:
	var until: int = Time.get_ticks_msec() + int(t * 1000.0)
	while Time.get_ticks_msec() < until:
		await process_frame


func lamp_label(slot: String, path: String) -> String:
	var room: RoomTemplate = area.rooms.get(slot)
	var sock: VariantSocket = room.get_node_or_null(NodePath(path)) if room != null else null
	return sock.picked_label() if sock != null else "no socket"

extends SceneTree
## Frame log of the real game walking the library wing while rooms stream
## (phase-4-design.md 8.1.7; step 2's first log, step 3's gate). Needs a
## display, not --headless; run `godot --headless --import` first.
##   godot --path . --resolution 1600x900 --script res://tests/area_walk_capture.gd -- <out.csv> [area seed] [speed m/s]
## The player walks (3.3 m/s, the game's speed) from R01's hall out to every
## leaf gallery's far end and back, looking where it goes, with vsync off.
## Every frame is logged: its time, the streamer's work, rooms live, loaded
## and unloaded, draw calls and the room the player is in. Prints the mean,
## 99th percentile and worst frame, how many frames went over 8.3 and 16.7
## ms, and the worst frames with what happened in them.

const STARTS: Dictionary = {
	&"SNAP_door_west": Vector3(1.5, 0.0, -6),
	&"SNAP_door_east": Vector3(10.5, 0.0, -6),
	&"SNAP_entrance": Vector3(6, 0.0, -1.5),
}


func _initialize() -> void:
	call_deferred("capture")


func capture() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://p4_frames.csv"
	var area_seed: int = int(args[1]) if args.size() > 1 else 1
	var speed: float = float(args[2]) if args.size() > 2 else 3.3
	var main_script: GDScript = load("res://scripts/main.gd")
	main_script.room_override = "area:library"
	Area.seed_override = area_seed
	var t0: int = Time.get_ticks_usec()
	var game: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	var boot_ms: float = (Time.get_ticks_usec() - t0) / 1000.0
	game.hud.toast_time = 0
	game.player.blocked = true     # the script walks it
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var area: Area = game.world
	var st: AreaStreamer = area.streamer
	var path: Array[Vector3] = tour(area.plan)
	for i: int in 60:     # settle the start
		await process_frame
	var lines: PackedStringArray = ["frame,ms,stream_ms,live,loads,unloads,draw_calls,room,event"]
	var times: Array[float] = []
	var worst: Array = []      # [ms, line]
	var seg: int = 0
	var pos: Vector3 = path[0]
	var last: int = Time.get_ticks_usec()
	var loads: int = st.stats["loads"]
	var unloads: int = st.stats["unloads"]
	var frame: int = 0
	while seg < path.size() - 1:
		await process_frame
		var now: int = Time.get_ticks_usec()
		var ms: float = (now - last) / 1000.0
		last = now
		# Walk on by real time, as a player would.
		var step: float = speed * minf(ms, 50.0) / 1000.0
		while step > 0.0 and seg < path.size() - 1:
			var to: Vector3 = path[seg + 1] - pos
			if to.length() <= step:
				step -= to.length()
				pos = path[seg + 1]
				seg += 1
			else:
				pos += to.normalized() * step
				step = 0.0
		var ahead: Vector3 = path[mini(seg + 1, path.size() - 1)]
		game.player.global_position = pos + Vector3(0, 0.05, 0)
		if ahead.distance_to(pos) > 0.05:
			game.look_toward(ahead + Vector3(0, 1.6, 0))
		var event: String = ""
		if st.stats["loads"] != loads:
			event += "load "
		if st.stats["unloads"] != unloads:
			event += "unload"
		loads = st.stats["loads"]
		unloads = st.stats["unloads"]
		var draws: int = root.get_viewport().get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)
		var line: String = "%d,%.3f,%.3f,%d,%d,%d,%d,%s,%s" % [frame, ms, st.stats["last_frame_ms"], st.live_count(), loads, unloads, draws, st.player_room, event.strip_edges()]
		lines.append(line)
		times.append(ms)
		worst.append([ms, line])
		frame += 1
	var f: FileAccess = FileAccess.open(out, FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")
	f.close()
	var sorted: Array[float] = times.duplicate()
	sorted.sort()
	var mean: float = sorted.reduce(func(a: float, b: float) -> float: return a + b, 0.0) / sorted.size()
	var over_8: int = sorted.filter(func(t: float) -> bool: return t > 8.3).size()
	var over_16: int = sorted.filter(func(t: float) -> bool: return t > 16.7).size()
	print("area_walk_capture: seed %d, %d rooms, boot %.0f ms; %d frames over %.0f m; frame %.2f ms mean, %.2f p99, %.2f worst; %d over 8.3 ms, %d over 16.7 ms; built %d, unloaded %d; slowest streaming frame %.1f ms; wear regions up to %.0f ms (thread), upload %.1f ms; wrote %s" % [
		area_seed, area.plan.rooms.size(), boot_ms, frame, length(path), mean, sorted[int(sorted.size() * 0.99) - 1], sorted[-1], over_8, over_16,
		st.stats["loads"], st.stats["unloads"], st.stats["max_frame_ms"], FloorWear.max_region_ms, FloorWear.last_upload_ms, out])
	worst.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	print("  worst frames (frame,ms,stream_ms,live,loads,unloads,draw_calls,room,event):")
	for w: Array in worst.slice(0, 8):
		print("    " + str(w[1]))
	main_script.room_override = ""
	quit()


func length(path: Array[Vector3]) -> float:
	var total: float = 0.0
	for i: int in path.size() - 1:
		total += path[i].distance_to(path[i + 1])
	return total


## Floor points from R01's hall out to every leaf's far end and back (cell
## centres; R01's door spots as in area_route_test).
func tour(p: AreaPlan) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for r: AreaPlan.Room in p.rooms:
		if r.parent == "" or r.children_count() > 0:
			continue
		var chain: Array[AreaPlan.Room] = []
		var at: AreaPlan.Room = r
		while at.parent != "":
			chain.push_front(at)
			at = p.room(at.parent)
		var start: Vector3 = STARTS[chain[0].parent_connector]
		var leg: Array[Vector3] = [start]
		for i: int in chain.size():
			var room: AreaPlan.Room = chain[i]
			var in_xf: Transform3D = room.connectors[room.entry]["xf"]
			var from: Vector3i = AreaPlan.cell_of(in_xf.origin + in_xf.basis.z * 2.0)
			var goal: Vector3i = Vector3i.MAX
			if i + 1 < chain.size():
				var out_xf: Transform3D = room.connectors[chain[i + 1].parent_connector]["xf"]
				goal = AreaPlan.cell_of(out_xf.origin + out_xf.basis.z * 2.0)
			for c: Vector3i in cell_path(room, from, goal):
				leg.append(AreaPlan.cell_box(c).get_center() * Vector3(1, 0, 1))
		var back: Array[Vector3] = leg.duplicate()
		back.reverse()
		out.append_array(leg + back)
	return out


func cell_path(r: AreaPlan.Room, from: Vector3i, to: Vector3i) -> Array[Vector3i]:
	var parent: Dictionary = {from: from}
	var order: Array[Vector3i] = [from]
	var head: int = 0
	while head < order.size():
		var c: Vector3i = order[head]
		head += 1
		for side: int in CellGrid.ALL_SIDES:
			var n: Vector3i = CellGrid.neighbour(c, side)
			if parent.has(n) or not r.floor_cells.has(n) or not r.sight.has(CellGrid.key(c, side)):
				continue
			parent[n] = c
			order.append(n)
	var goal: Vector3i = to if to != Vector3i.MAX else order[-1]
	if not parent.has(goal):
		return [from]
	var out: Array[Vector3i] = []
	var c: Vector3i = goal
	while c != from:
		out.push_front(c)
		c = parent[c]
	out.push_front(from)
	return out

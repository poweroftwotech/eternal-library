extends SceneTree
## Frame log and frame gate of the whole continuous world (phase 9 step 3):
## the real game from the camp, along the corridor onto the Overlook's
## loggia, through the Gorge's door into the Library Wing and back, through
## its door into the Lower Stacks and back, and back along the corridor into
## the camp. Needs a display, not --headless; run `godot --headless --import`
## first.
##   godot --path . --resolution 1920x1080 --script res://tests/world_walk_capture.gd -- <out.csv> [--preset=medium] [--gate] --save=user://test/world_walk.json --fresh
## Each leg is walked at the game's speed (3.3 m/s) by real time, looking
## where it goes, vsync off. Between legs the walk is cut (a teleport: across
## the Gorge from the loggia to a door's ledge has no short way on foot); the
## second after a cut, and any wait for a place to be built, are logged but
## not judged.
##
## --gate judges the frames walked:
##   in each place, its own budget at Medium 1080p: the interiors'
##   (tests/area_walk_capture.gd: GPU mean 3 ms, worst 4 ms; frame mean 4 ms;
##   1,500 draw calls, 3 M triangles), the Gorge's looser one
##   (StatsOverlay.AREA_BUDGETS: 2,600 draw calls, 4.5 M triangles), and the
##   camp by the Gorge's (it shows the Gorge through its doorway; your call,
##   2026-10-30);
##   at a swap (the frames from 0.5 s before to 1 s after the place you're in
##   changes): SWAP. Exits 1 if the gate fails.

const SPEED: float = 3.3
const SETTLE_FRAMES: int = 60
## Frame times off swaps (ms; the GPU has its own lines).
const PLACE: Dictionary = {"gpu_mean": 3.0, "gpu_max": 4.0, "cpu_mean": 4.0, "draws": 1500, "tris": 3000000}
const GORGE: Dictionary = {"gpu_mean": 3.0, "gpu_max": 4.5, "cpu_mean": 4.0, "draws": 2600, "tris": 4500000}
## Off swaps, no walked frame may take longer (a dropped frame at 60 Hz on
## the base spec, CPU at 2x: 8.3 ms here).
const CPU_MAX: float = 8.3
## At a swap: no frame over 50 ms, at most 3 over 16.7 ms (your call,
## 2026-10-30: proposed at 33 ms, two frames lost at 60 Hz; the swaps were
## 25-47 ms on the RTX 5090).
const SWAP: Dictionary = {"max_ms": 50.0, "over_16": 3}
const SWAP_BEFORE_S: float = .5
const SWAP_AFTER_S: float = 1.0
## The camp's gallery, the loggia beyond the corridor (the camp's frame,
## which the Gorge shares).
const GALLERY := Vector3(-1.0, 2.2, -10.0)
const LOGGIA := Vector3(-1.0, 2.2, -24.0)

var game: Node
var sp: SeamlessPlaces
var vp_rid: RID
var rows: Array[Dictionary] = []
var last_us: int = 0
var leg_name: String = ""
var settle: int = 0
var last_place: String = ""
var swaps: Array[Dictionary] = []     # {at (row index), from, to, t_us}
var _pipes_before: int = 0
var _stalls_before: int = 0


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var args: PackedStringArray = []
	for a: String in OS.get_cmdline_user_args():
		if not a.begins_with("--"):
			args.append(a)
	var gate: bool = OS.get_cmdline_user_args().has("--gate")
	var out: String = args[0] if args.size() > 0 else "user://world_walk.csv"
	var main_script: GDScript = load("res://scripts/main.gd")
	main_script.room_override = "camp"
	var t0: int = Time.get_ticks_usec()
	game = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	var boot_ms: float = (Time.get_ticks_usec() - t0) / 1000.0
	game.hud.toast_time = 0
	game.stats.visible = false
	game.player.blocked = true
	game.player.set_physics_process(false)     # the script walks it
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	vp_rid = root.get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp_rid, true)
	sp = game.seamless
	if sp == null:
		print("world_walk_capture: no SeamlessPlaces (is --no-seamless set?)")
		quit(1)
		return
	last_place = sp.place_id
	_pipes_before = _pipelines()
	_stalls_before = int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW))
	last_us = Time.get_ticks_usec()
	# 1. The camp's gallery, once the Gorge is built, along the corridor onto
	# the loggia.
	await cut("camp: gallery to loggia", [GALLERY], func() -> bool: return sp.places.has("gorge"))
	await walk([GALLERY, LOGGIA, LOGGIA + Vector3(0, 0, -3)])
	# 2-3. Each interior in the stratum plan, from its door's ledge and back.
	for id: String in SeamlessPlaces.recipes():
		if id == "gorge":
			continue
		var gorge := sp.places["gorge"] as Area
		var door: Array = gorge.plan.threshold(id)
		if door.is_empty():
			print("world_walk_capture: the Gorge has no door to %s on this seed" % id)
			continue
		var ledge: String = (door[0] as AreaPlan.Room).slot_id
		var on_ledge := func() -> bool: return gorge.rooms.has(ledge) and not gorge.streamer.busy()
		var ready := func() -> bool: return sp.places.has(id) and (sp.places[id] as Area).is_built and sp.vestibules.has(id)
		var v_at: Transform3D = sp._placed(SeamlessPlaces._door_xf(gorge.plan, id))
		var path: Array[Vector3] = []
		for p: Vector3 in [Vector3(0, 0, Area.ARRIVE_IN + 2.0), Vector3(0, 0, -4.5), Vector3(6, 0, -4.5), Vector3(6, 0, -9.0), Vector3(6, 0, -15.0)]:
			path.append(v_at * p)
		await cut("%s: in from the ledge" % id, [path[0]], func() -> bool: return on_ledge.call() and ready.call())
		await walk(path)
		var back: Array[Vector3] = path.duplicate()
		back.reverse()
		leg_name = "%s: back out" % id
		await walk(back)
	# 4. The loggia back along the corridor into the camp's gallery.
	await cut("camp: loggia to gallery", [LOGGIA + Vector3(0, 0, -3)], func() -> bool: return sp.places.has("camp"))
	await walk([LOGGIA + Vector3(0, 0, -3), LOGGIA, GALLERY, GALLERY + Vector3(0, 0, 4)])
	var fails: PackedStringArray = report(out, boot_ms)
	if gate:
		print("world_walk_capture gate: %s" % ("PASS" if fails.is_empty() else "FAIL " + "; ".join(fails)))
	main_script.room_override = ""
	quit(1 if gate and not fails.is_empty() else 0)


## Teleports to `at[0]` and waits until `ready` holds; the frames meanwhile
## and the next SETTLE_FRAMES aren't judged.
func cut(name: String, at: Array[Vector3], ready: Callable) -> void:
	leg_name = name
	place(at[0], at[0] + Vector3(0, 0, -1))
	var stop_ms: int = Time.get_ticks_msec() + 60000
	while not ready.call() and Time.get_ticks_msec() < stop_ms:
		await frame("wait")
	settle = SETTLE_FRAMES


## Walks the points at SPEED by real time, looking ahead.
func walk(points: Array[Vector3]) -> void:
	var pos: Vector3 = points[0]
	var seg: int = 0
	var ms: float = 0.0
	while seg < points.size() - 1:
		ms = await frame("settle" if settle > 0 else "walk")
		settle = maxi(settle - 1, 0)
		var step: float = SPEED * minf(ms, 50.0) / 1000.0
		while step > 0.0 and seg < points.size() - 1:
			var to: Vector3 = points[seg + 1] - pos
			if to.length() <= step:
				step -= to.length()
				pos = points[seg + 1]
				seg += 1
			else:
				pos += to.normalized() * step
				step = 0.0
		place(pos, points[mini(seg + 1, points.size() - 1)])


func place(pos: Vector3, ahead: Vector3) -> void:
	game.player.global_position = pos + Vector3(0, .05, 0)
	var d := Vector3(ahead.x - pos.x, 0, ahead.z - pos.z)
	if d.length() > .05:
		game.player.rotation.y = atan2(-d.x, -d.z)
		game.player.camera.rotation.x = 0.0


## One frame, logged. Its wall time (ms).
func frame(kind: String) -> float:
	await process_frame
	var now: int = Time.get_ticks_usec()
	var ms: float = (now - last_us) / 1000.0
	last_us = now
	var row: Dictionary = {"i": rows.size(), "us": now, "ms": ms, "gpu": RenderingServer.viewport_get_measured_render_time_gpu(vp_rid),
		"draws": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"tris": int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
		"vram": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
		"proc": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, "phys": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		"stream": _stream_ms(),
		"pipes": _pipelines() - _pipes_before, "stalls": int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW)) - _stalls_before, "nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"place": sp.place_id, "kind": kind, "leg": leg_name, "event": ""}
	_pipes_before += int(row["pipes"])
	_stalls_before += int(row["stalls"])
	if sp.place_id != last_place:
		row["event"] = "swap %s>%s" % [last_place, sp.place_id]
		swaps.append({"at": rows.size(), "from": last_place, "to": sp.place_id, "us": now})
		last_place = sp.place_id
	rows.append(row)
	return ms


## Writes the CSV and prints the summary; the gate's failures.
func report(out: String, boot_ms: float) -> PackedStringArray:
	var lines: PackedStringArray = ["frame,ms,gpu_ms,proc_ms,physics_ms,stream_ms,pipelines,pipelines_at_draw,nodes,draw_calls,triangles,vram_mb,place,kind,leg,event"]
	for r: Dictionary in rows:
		lines.append("%d,%.3f,%.3f,%.3f,%.3f,%.3f,%d,%d,%d,%d,%d,%.0f,%s,%s,%s,%s" % [r["i"], r["ms"], r["gpu"], r["proc"], r["phys"], r["stream"], r["pipes"], r["stalls"], r["nodes"], r["draws"], r["tris"], r["vram"], r["place"], r["kind"], r["leg"], r["event"]])
	var f: FileAccess = FileAccess.open(out, FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")
	f.close()
	# Frames near a swap belong to it, not to a place.
	var at_swap: Dictionary = {}
	for s: Dictionary in swaps:
		var frames: Array[Dictionary] = []
		for r: Dictionary in rows:
			if r["kind"] == "walk" and r["us"] >= s["us"] - SWAP_BEFORE_S * 1e6 and r["us"] <= s["us"] + SWAP_AFTER_S * 1e6:
				frames.append(r)
				at_swap[r["i"]] = true
		s["frames"] = frames
	var fails: PackedStringArray = []
	var preset: String = GraphicsPreset.requested() if GraphicsPreset.requested() != "" else "project settings"
	var walked: int = rows.filter(func(r: Dictionary) -> bool: return r["kind"] == "walk").size()
	print("world_walk_capture: %s, %dx%d, boot %.0f ms; %d frames (%d walked), %d swaps; wrote %s" % [preset, root.size.x, root.size.y, boot_ms, rows.size(), walked, swaps.size(), out])
	for id: String in ["camp"] + SeamlessPlaces.recipes().keys():
		var fr: Array = rows.filter(func(r: Dictionary) -> bool: return r["kind"] == "walk" and r["place"] == id and not at_swap.has(r["i"]))
		if fr.is_empty():
			continue
		var b: Dictionary = GORGE if id == "gorge" or id == "camp" else PLACE
		var ms: Array = fr.map(func(r: Dictionary) -> float: return r["ms"])
		var gpu: Array = fr.map(func(r: Dictionary) -> float: return r["gpu"])
		var vals: Dictionary = {"cpu_mean": _mean(ms), "cpu_max": ms.max(), "gpu_mean": _mean(gpu), "gpu_max": gpu.max(),
			"draws": fr.map(func(r: Dictionary) -> int: return r["draws"]).max(), "tris": fr.map(func(r: Dictionary) -> int: return r["tris"]).max()}
		print("  %-13s %5d frames: frame %.2f ms mean, %.2f worst; gpu %.2f mean, %.2f worst; draw calls up to %d, triangles up to %.2f M" % [
			id, fr.size(), vals["cpu_mean"], vals["cpu_max"], vals["gpu_mean"], vals["gpu_max"], vals["draws"], vals["tris"] / 1e6])
		for k: String in b:
			if float(vals[k]) > float(b[k]):
				fails.append("%s %s %.2f > %.2f" % [id, k, vals[k], b[k]])
		if float(vals["cpu_max"]) > CPU_MAX:
			fails.append("%s cpu_max %.2f > %.2f" % [id, vals["cpu_max"], CPU_MAX])
	for s: Dictionary in swaps:
		var fr: Array = s["frames"]
		if fr.is_empty():
			print("  swap %s > %s: during a cut (not judged)" % [s["from"], s["to"]])
			continue
		var ms: Array = fr.map(func(r: Dictionary) -> float: return r["ms"])
		var over: int = ms.filter(func(t: float) -> bool: return t > 16.7).size()
		var worst: Dictionary = fr[ms.find(ms.max())]
		print("  swap %s > %s: %d frames, worst %.1f ms (gpu %.2f, frame %d), %d over 16.7 ms, %d over 8.3 ms" % [s["from"], s["to"], fr.size(), ms.max(), worst["gpu"], worst["i"], over,
			ms.filter(func(t: float) -> bool: return t > 8.3).size()])
		if float(ms.max()) > SWAP["max_ms"]:
			fails.append("swap %s>%s worst %.1f ms > %.1f" % [s["from"], s["to"], ms.max(), SWAP["max_ms"]])
		if over > int(SWAP["over_16"]):
			fails.append("swap %s>%s %d frames over 16.7 ms > %d" % [s["from"], s["to"], over, SWAP["over_16"]])
	var worst_rows: Array = rows.filter(func(r: Dictionary) -> bool: return r["kind"] == "walk")
	worst_rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["ms"] > b["ms"])
	print("  worst walked frames:")
	for r: Dictionary in worst_rows.slice(0, 10):
		print("    frame %d %.1f ms gpu %.2f process %.1f physics %.1f stream %.1f pipelines %d (%d at draw) in %s (%s) %s" % [r["i"], r["ms"], r["gpu"], r["proc"], r["phys"], r["stream"], r["pipes"], r["stalls"], r["place"], r["leg"], r["event"]])
	return fails


func _mean(values: Array) -> float:
	return values.reduce(func(a: float, b: float) -> float: return a + b, 0.0) / maxf(values.size(), 1)


## Shader pipelines compiled since start, every kind (as area_walk_capture).
func _pipelines() -> int:
	return int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_CANVAS) + Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_MESH)
		+ Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SURFACE) + Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW)
		+ Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SPECIALIZATION))


## Every place's streamer's work this frame (a neighbour builds its rooms in
## the background too).
func _stream_ms() -> float:
	var ms: float = 0.0
	for p: Variant in sp.places.values():
		if p is Area and (p as Area).streamer != null and (p as Area).streamer.stats.has("last_frame_ms"):
			ms += float((p as Area).streamer.stats["last_frame_ms"])
			(p as Area).streamer.stats["last_frame_ms"] = 0.0     # counted once
	return ms

extends SceneTree
## Phase 18 step 5: frame log and frame gate of the Lake Landing in the real
## game. Needs a display, not --headless; run `godot --headless --import` first.
##   godot --path . --resolution 1920x1080 --script res://tests/r20_frame_gate.gd -- <out.csv> [--preset=medium] [--gate] --save=user://test/r20_frames.json --fresh
## Walks the harbour at the game's speed (3.3 m/s, by real time, looking where
## it goes, vsync off): the passage onto the quay, the boardwalk, the terrace,
## out along the pier. Then rides the ferry, standing on its deck facing the
## bow, to every stop in turn; at each dock walks both strips end to end and
## back aboard. Every frame is logged. The second after a cut (a teleport:
## stepping aboard, the fog's jump between docks) is logged, not judged.
##
## --gate judges the frames at the interiors' budget (tests/area_walk_capture.gd,
## Medium 1080p): GPU mean <= 3 ms, worst <= 4 ms; frame mean <= 4 ms, worst
## <= 8 ms; draw calls <= 1,500, triangles <= 3 M, shadowed lights <= 4,
## lights within 35 m <= 50. Exits 1 if the gate fails.

const SCENE: String = "res://rooms/lake/landing.tscn"
const TARGET: Dictionary = {"gpu_mean": 3.0, "gpu_max": 4.0, "cpu_mean": 4.0, "cpu_max": 8.0,
	"draws": 1500, "tris": 3000000, "shadowed": 4, "lights": 50}
const REACH_M: float = 35.0
const SPEED: float = 3.3
## Seconds after a cut not judged.
const SETTLE: float = 1.0

var game: Node
var ferry: LakeFerry
var vp_rid: RID
var lines: PackedStringArray = ["frame,ms,gpu_ms,draw_calls,triangles,shadowed,lights,where,judged"]
var times: Array[float] = []
var gpus: Array[float] = []
var worst: Array = []
var peak: Dictionary = {"draws": 0.0, "tris": 0.0, "shadowed": 0.0, "lights": 0.0}
var peak_where: Dictionary = {}
var frame: int = 0
var last_us: int = 0
var probe_us: int = 0
var cut_until_ms: int = 0
var lights: Array[Light3D] = []
var in_reach: int = 0
var shadowed: int = 0
var where: String = "harbour"


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var args: PackedStringArray = []
	for a: String in OS.get_cmdline_user_args():
		if not a.begins_with("--"):
			args.append(a)
	var gate: bool = OS.get_cmdline_user_args().has("--gate")
	var out: String = args[0] if args.size() > 0 else "user://r20_frames.csv"
	var main_script: GDScript = load("res://scripts/main.gd")
	main_script.room_override = SCENE
	game = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	current_scene = game
	game.hud.toast_time = 0
	game.stats.visible = false
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	vp_rid = root.get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp_rid, true)
	ferry = game.world.get_node_or_null("Ferry") as LakeFerry
	for l: Node in game.world.find_children("*", "Light3D", true, false):
		lights.append(l as Light3D)
	game.player.blocked = true
	for _i: int in 90:
		await process_frame
	last_us = Time.get_ticks_usec()
	# The harbour on foot.
	await stroll([Vector3(0, 0, -2.5), Vector3(0, 0, -9.0), Vector3(-6.0, 0, -9.0), Vector3(-12.0, 0, -8.6), Vector3(-6.0, 0, -9.0),
		Vector3(4.0, 0, -9.5), Vector3(12.8, 0, -12.5), Vector3(8.0, 0, -15.0), Vector3(8.0, 0, -39.0)])
	# Every stop by ferry, its dock's strips on foot.
	for stop: String in LakeLayout.stops():
		if stop == "quay":
			continue
		await ride(stop)
		var f: Transform3D = LakeLayout.dock_frame(LakeLayout.style_of(stop))
		where = "dock " + LakeLayout.style_of(stop)
		var west_end: float = 5.9 if LakeLayout.style_of(stop) == "ruin" else 17.6
		await stroll([f * Vector3(0, 0, -4.8), f * Vector3(0, 0, -2.3), f * Vector3(-west_end, 0, -2.3), f * Vector3(17.6, 0, -2.3), f * Vector3(0, 0, -2.3)])
	await ride("quay")
	report(out, gate)


## Walks the eye along `points` (world, floor height from the floor below) by real time.
func stroll(points: Array[Vector3]) -> void:
	var pos: Vector3 = floor_at(points[0])
	game.player.global_position = pos + Vector3(0, 0.05, 0)
	cut()
	for i: int in range(1, points.size()):
		var to: Vector3 = floor_at(points[i])
		while pos.distance_to(to) > 0.05:
			var ms: float = await sample()
			var step: float = SPEED * minf(ms, 50.0) / 1000.0
			var d: Vector3 = to - pos
			pos = to if d.length() <= step else pos + d.normalized() * step
			game.player.global_position = pos + Vector3(0, 0.05, 0)
			game.look_toward(to + Vector3(0, 1.6, 0) if pos.distance_to(to) > 0.3 else pos + d.normalized() + Vector3(0, 1.6, 0))


## Rides the ferry from where it lies to `stop`, standing on the deck facing the bow.
func ride(stop: String) -> void:
	where = "ferry to " + stop
	game.player.blocked = false
	var p: Vector3 = ferry.body.global_transform * Vector3(0.0, LakeFerry.DECK + 0.1, -1.0)
	game.player.teleport(p, ferry.body.global_rotation.y)
	cut()
	for _i: int in 10:
		await sample()
	ferry.ask(stop)
	var started: bool = false
	var t0: int = Time.get_ticks_msec()
	var phase: int = ferry.phase
	while Time.get_ticks_msec() - t0 < 180000:
		await sample()
		if ferry.moving():
			started = true
		elif started:
			break
		if ferry.phase != phase:
			if ferry.phase == LakeFerry.Phase.FOG or phase == LakeFerry.Phase.FOG:
				cut()     # under the fog the barge jumps to the far channel
			phase = ferry.phase
	for _i: int in 20:
		await sample()
	game.player.blocked = true


## The floor under `p` (the first surface facing up from 3 m above).
func floor_at(p: Vector3) -> Vector3:
	var space: PhysicsDirectSpaceState3D = game.world.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(Vector3(p.x, 3.0, p.z), Vector3(p.x, -6.0, p.z), 1)
	q.exclude = [game.player.get_rid()]
	var hit: Dictionary = space.intersect_ray(q)
	return hit["position"] if not hit.is_empty() else p


func cut() -> void:
	cut_until_ms = Time.get_ticks_msec() + int(SETTLE * 1000.0)


## One frame: logs it; its wall time (ms).
func sample() -> float:
	await process_frame
	var now: int = Time.get_ticks_usec()
	var ms: float = (now - last_us - probe_us) / 1000.0
	probe_us = 0
	last_us = now
	if frame % 15 == 0:
		var t0: int = Time.get_ticks_usec()
		var cam: Vector3 = game.player.camera.global_position
		in_reach = 0
		shadowed = 0
		for l: Light3D in lights:
			if l.is_visible_in_tree() and l.global_position.distance_to(cam) < REACH_M:
				in_reach += 1
				if l.shadow_enabled:
					shadowed += 1
		probe_us = Time.get_ticks_usec() - t0
	var gpu: float = RenderingServer.viewport_get_measured_render_time_gpu(vp_rid)
	var draws: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var tris: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	var judged: bool = Time.get_ticks_msec() >= cut_until_ms
	var line: String = "%d,%.3f,%.3f,%d,%d,%d,%d,%s,%s" % [frame, ms, gpu, draws, tris, shadowed, in_reach, where, "1" if judged else "0"]
	lines.append(line)
	if judged:
		times.append(ms)
		gpus.append(gpu)
		worst.append([ms, line])
		var now_vals: Dictionary = {"draws": draws, "tris": tris, "shadowed": shadowed, "lights": in_reach}
		for k: String in peak:
			if float(now_vals[k]) > float(peak[k]):
				peak[k] = float(now_vals[k])
				peak_where[k] = where
	frame += 1
	return ms


func report(out: String, gate: bool) -> void:
	var f: FileAccess = FileAccess.open(out, FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")
	f.close()
	var sorted: Array[float] = times.duplicate()
	sorted.sort()
	var mean: float = _mean(times)
	var gpu_mean: float = _mean(gpus)
	var gpu_sorted: Array[float] = gpus.duplicate()
	gpu_sorted.sort()
	var preset: String = GraphicsPreset.requested() if GraphicsPreset.requested() != "" else "project settings"
	print("r20_frame_gate: %s, %dx%d; %d frames judged of %d; frame %.2f ms mean, %.2f p99, %.2f worst; gpu %.2f ms mean, %.2f p99, %.2f worst; %d over 8.3 ms; peaks %s at %s; wrote %s" % [
		preset, root.size.x, root.size.y, times.size(), frame, mean, sorted[int(sorted.size() * 0.99) - 1], sorted[-1],
		gpu_mean, gpu_sorted[int(gpu_sorted.size() * 0.99) - 1], gpu_sorted[-1], sorted.filter(func(t: float) -> bool: return t > 8.3).size(), peak, peak_where, out])
	worst.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	print("  worst frames (%s):" % lines[0])
	for w: Array in worst.slice(0, 8):
		print("    " + str(w[1]))
	var fails: PackedStringArray = []
	if gate:
		var checks: Array = [["gpu mean", gpu_mean, TARGET["gpu_mean"]], ["gpu worst", gpu_sorted[-1], TARGET["gpu_max"]],
			["cpu mean", mean, TARGET["cpu_mean"]], ["cpu worst", sorted[-1], TARGET["cpu_max"]],
			["draw calls", peak["draws"], TARGET["draws"]], ["triangles", peak["tris"], TARGET["tris"]],
			["shadowed lights", peak["shadowed"], TARGET["shadowed"]], ["lights in reach", peak["lights"], TARGET["lights"]]]
		for c: Array in checks:
			if float(c[1]) > float(c[2]):
				fails.append("%s %.2f > %.2f" % [c[0], c[1], c[2]])
		print("r20_frame_gate gate: %s" % ("PASS" if fails.is_empty() else "FAIL " + "; ".join(fails)))
	(load("res://scripts/main.gd") as GDScript).room_override = ""
	quit(1 if not fails.is_empty() else 0)


func _mean(values: Array[float]) -> float:
	var s: float = 0.0
	for v: float in values:
		s += v
	return s / maxf(values.size(), 1.0)

extends SceneTree
## Does lighting jump when a room arrives? (phase-4-design.md 8.1.8 step 3.)
## Needs a display, not --headless; run `godot --headless --import` first.
##   godot --path . --resolution 1920x1080 --script res://tests/area_pop_capture.gd -- <out dir> [area seed] [arrivals] [--preset=medium]
## Walks the library wing as area_walk_capture does. Each time a room starts
## arriving, the player stops where they are: picture A at once, picture B
## 1.5 s after the room is in (time for bounce light to settle), picture C
## 1.5 s after that with nothing arriving (lamps sway and failing ones
## flicker, so B against C is the scene's own noise). A room's arrival pops
## if A against B differs clearly more than B against C. Prints both
## differences (mean 0-255 and the share of pixels off by more than 8, at
## quarter size) for each arrival, and saves A and B of the biggest change.

const SETTLE_FRAMES: int = 90
const SMALL := Vector2i(480, 270)


func _initialize() -> void:
	call_deferred("capture")


func capture() -> void:
	var args: PackedStringArray = []
	for a: String in OS.get_cmdline_user_args():
		if not a.begins_with("--"):
			args.append(a)
	var out_dir: String = args[0] if args.size() > 0 else "user://pop"
	var area_seed: int = int(args[1]) if args.size() > 1 else 2
	var arrivals: int = int(args[2]) if args.size() > 2 else 6
	DirAccess.make_dir_recursive_absolute(out_dir)
	var main_script: GDScript = load("res://scripts/main.gd")
	main_script.room_override = "area:library"
	Area.seed_override = area_seed
	var game: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	game.hud.toast_time = 0
	game.stats.visible = false
	game.hud.visible = false     # pictures of the world only
	game.player.blocked = true
	var area: Area = game.world
	var st: AreaStreamer = area.streamer
	var path: Array[Vector3] = AreaTour.tour(area.plan)
	game.player.global_position = path[0] + Vector3(0, 0.05, 0)
	for i: int in 60:
		await process_frame
	var seg: int = 0
	var pos: Vector3 = path[0]
	var seen: int = 0
	var worst: Array = [-1.0]
	var rows: PackedStringArray = []
	var was_busy: bool = st.busy()
	while seg < path.size() - 1 and seen < arrivals:
		await process_frame
		var step: float = 3.3 / 60.0
		while step > 0.0 and seg < path.size() - 1:
			var to: Vector3 = path[seg + 1] - pos
			if to.length() <= step:
				step -= to.length()
				pos = path[seg + 1]
				seg += 1
			else:
				pos += to.normalized() * step
				step = 0.0
		game.player.global_position = pos + Vector3(0, 0.05, 0)
		var ahead: Vector3 = path[mini(seg + 1, path.size() - 1)]
		if ahead.distance_to(pos) > 0.05:
			game.look_toward(ahead + Vector3(0, 1.6, 0))
		var busy: bool = not st.queue.is_empty() or not st._job.is_empty()
		if busy and not was_busy:
			var arriving: String = st._job.get("slot", st.queue[0] if not st.queue.is_empty() else "?")
			# The last picture showed the camera before this frame's move: hold the
			# streamer while two frames render standing still, then let the room come.
			st.set_process(false)
			await process_frame
			await process_frame
			var entered: bool = st.is_live(arriving)
			var a: Image = _grab()
			st.set_process(true)
			while not st.queue.is_empty() or not st._job.is_empty():
				await process_frame
			for i: int in SETTLE_FRAMES:
				await process_frame
			var b: Image = _grab()
			for i: int in SETTLE_FRAMES:
				await process_frame
			var c: Image = _grab()
			var ab: Vector2 = _diff(a, b)
			var bc: Vector2 = _diff(b, c)
			seen += 1
			rows.append("  %s%s arriving, seen from %s: A-B %.2f mean, %.1f%% of pixels; noise B-C %.2f mean, %.1f%%" % ["(already in) " if entered else "", arriving, st.player_room, ab.x, ab.y * 100.0, bc.x, bc.y * 100.0])
			if ab.x - bc.x > float(worst[0]):
				worst = [ab.x - bc.x, a, b, arriving]
			busy = false
		was_busy = busy
	print("area_pop_capture: seed %d, %d arrivals" % [area_seed, seen])
	for r: String in rows:
		print(r)
	if worst.size() > 1:
		(worst[1] as Image).save_png("%s/pop_%d_%s_before.png" % [out_dir, area_seed, worst[3]])
		(worst[2] as Image).save_png("%s/pop_%d_%s_after.png" % [out_dir, area_seed, worst[3]])
		print("  biggest change over noise: %s (%.2f); saved its before and after in %s" % [worst[3], worst[0], out_dir])
	main_script.room_override = ""
	quit()


func _grab() -> Image:
	return root.get_viewport().get_texture().get_image()


## (mean difference 0-255, share of pixels off by more than 8), at quarter size.
func _diff(a: Image, b: Image) -> Vector2:
	var x: Image = a.duplicate()
	var y: Image = b.duplicate()
	x.resize(SMALL.x, SMALL.y, Image.INTERPOLATE_BILINEAR)
	y.resize(SMALL.x, SMALL.y, Image.INTERPOLATE_BILINEAR)
	var total: float = 0.0
	var big: int = 0
	for j: int in SMALL.y:
		for i: int in SMALL.x:
			var ca: Color = x.get_pixel(i, j)
			var cb: Color = y.get_pixel(i, j)
			var d: float = (absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b)) / 3.0 * 255.0
			total += d
			if d > 8.0:
				big += 1
	return Vector2(total / (SMALL.x * SMALL.y), float(big) / (SMALL.x * SMALL.y))

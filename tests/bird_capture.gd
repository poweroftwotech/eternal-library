extends SceneTree
## Pictures of the nightingales (phase 20 step 1) for the look. Needs a
## display, not --headless; run `godot --headless --import` first.
##   godot --path . --resolution 1600x900 --audio-driver Dummy --script res://tests/bird_capture.gd -- <out dir> [place ...]
## place: zoo (default), camp, area:<id> (its R07 and R09 rooms). For the
## first bird of each garden writes <place>_<slot>_<shot>.png:
##   close   0.7 m off, level with it, a long lens: the model
##   sing    the same, singing (head up, beak open, throat out)
##   perch   from 3 m below and off: the bird on its branch in the garden
##   fly     mid-flight to another perch, from 4 m
##   room    the garden from 6 m up, every bird ringed by the overlay (F4)

const ROOM_TYPES: PackedStringArray = ["R07", "R09"]


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var out_dir: String = ""
	var places: PackedStringArray = []
	for a: String in OS.get_cmdline_user_args():
		if out_dir == "":
			out_dir = a
		else:
			places.append(a)
	if out_dir == "":
		out_dir = "user://birds"
	if places.is_empty():
		places = PackedStringArray(["zoo"])
	DirAccess.make_dir_recursive_absolute(out_dir)
	var main_script: GDScript = load("res://scripts/main.gd")
	for place: String in places:
		main_script.room_override = ZooRoom.SCENE if place == "zoo" else place
		var game: Node = (load("res://main.tscn") as PackedScene).instantiate()
		root.add_child(game)
		game.hud.toast_time = 0
		game.hud.visible = false
		game.stats.visible = false
		game.player.blocked = true
		for _i: int in 30:
			await process_frame
		var world: Node3D = game.world
		var tag: String = place.replace("area:", "")
		if world is Area:
			var area: Area = world
			for r: AreaPlan.Room in area.plan.rooms:
				if r.room_type not in ROOM_TYPES:
					continue
				game.player.teleport(area.global_transform * CellGrid.cell_centre(r.floor_cells.keys()[0]))
				await _settle(game, area.fauna, r.slot_id)
				if not area.fauna.groups.get(r.slot_id, []).any(func(g: Node) -> bool: return g is BirdBand):
					print("  %s %s: no nightingales" % [tag, r.slot_id])
				await _shoot(game, area.fauna, r.slot_id, "%s/%s_%s" % [out_dir, tag, r.slot_id])
		else:
			var f: Fauna = world.get_node_or_null("Fauna") as Fauna
			await _settle(game, f)
			for slot: String in f.groups:
				await _shoot(game, f, slot, "%s/%s_%s" % [out_dir, tag, slot if slot != "" else "all"])
		game.queue_free()
		for _i: int in 3:
			await process_frame
	main_script.room_override = ""
	quit()


## Until the place's rooms are built and the animals' director has filled
## `slot` (when given: it may not even be queued yet when the streamer goes
## quiet).
func _settle(game: Node, f: Fauna, slot: String = "") -> void:
	for _i: int in 10:
		await process_frame
	var streamer: Variant = game.world.get("streamer")
	while streamer != null and streamer.busy():
		await process_frame
	for _i: int in 900:
		if f == null or (f._jobs.is_empty() and (slot == "" or f.found.has(slot))):
			break
		await process_frame
	for _i: int in 20:
		await process_frame


func _shoot(game: Node, f: Fauna, slot: String, stem: String) -> void:
	for g: Node in f.groups.get(slot, []):
		if not g is BirdBand:
			continue
		var band := g as BirdBand
		f.ignore_player = true
		var b: Dictionary = band.birds[0]
		var body: BirdBody = b["body"]
		b["rest"] = 999.0
		b["bout"] = 0
		b["timer"] = 999.0
		# On the high perch furthest out from its plant's middle (the edge of
		# the crown, where it can be seen), facing across the camera.
		var edge: int = int(b["perch"])
		var out_most: float = -1.0
		for i: int in band.perches.size():
			var p: Dictionary = band.perches[i]
			var off: Vector3 = (p["at"] as Vector3) - (p["plant"] as Vector3)
			if float(p["height"]) > 4.5 or Vector2(off.x, off.z).length() > 1.8:
				continue     # (a low tree, not the figs round a shaft's lip)
			if _open(game, (p["at"] as Vector3) + Vector3(0, 0.06, 0), Vector3(off.x, 0, off.z).normalized() if off.length() > 0.01 else Vector3.RIGHT, 1.5) < 1.4:
				continue     # (no view of it from its open side)
			if p["high"] and Vector2(off.x, off.z).length() > out_most:
				out_most = Vector2(off.x, off.z).length()
				edge = i
		b["perch"] = edge
		b["state"] = BirdBand.PERCH
		body.global_position = band.perches[edge]["at"]
		var away: Vector3 = (band.perches[edge]["at"] as Vector3) - (band.perches[edge]["plant"] as Vector3)
		away.y = 0.0
		away = away.normalized() if away.length() > 0.01 else Vector3.RIGHT
		b["yaw"] = atan2(-away.z, away.x)     # side on to the camera
		body.rotation.y = float(b["yaw"])
		print("  %s: %d birds, %d perches; bird at %s (%.1f m out from its plant)" % [stem.get_file(), band.count(), band.perches.size(), body.global_position.snapped(Vector3.ONE * 0.01), out_most])
		var at: Vector3 = body.global_position + Vector3(0, 0.06, 0)
		var side: Vector3 = away     # (the perch was picked with that side open)
		await _frame(game, at + side * 0.7 + Vector3(0, 0.05, 0), at, 28.0, stem + "_close")
		var now: float = Time.get_ticks_msec() / 1000.0
		band._phrase(0, b, now)
		for _i: int in 8:
			await process_frame
		await _frame(game, at + side * 0.7 + Vector3(0, 0.05, 0), at, 28.0, stem + "_sing", false)
		var v: AudioStreamPlayer3D = b["voice"]
		if v != null:
			v.stop()
		band._end_phrase(b)
		b["bout"] = 0
		b["rest"] = 999.0
		await _frame(game, at + side * 2.6 + Vector3(0, -1.2, 0), at, 55.0, stem + "_perch")
		# Flight: to the farthest clear high perch within 10 m.
		var best: int = -1
		var far: float = 0.0
		for i: int in band.perches.size():
			var d: float = (band.perches[i]["at"] as Vector3).distance_to(body.global_position)
			if band.perches[i]["high"] and d < 10.0 and d > far and band._clear(body.global_position, band.perches[i]["at"]):
				best = i
				far = d
		if best >= 0:
			band._move_to(b, best, false)
			var dur: float = float((b["fly"] as Dictionary)["dur"])
			var mid: Vector3 = BirdBand._bezier(b["fly"], 0.5)
			game.player.camera.global_position = mid + side * 4.0
			var t0: int = Time.get_ticks_msec()
			while Time.get_ticks_msec() - t0 < int(dur * 500.0):
				await process_frame
			await _frame(game, body.global_position + side * 4.0 + Vector3(0, 0.5, 0), body.global_position, 40.0, stem + "_fly", false)
		f.show_overlay(true)
		await _frame(game, body.global_position + side * 6.0 + Vector3(0, 1.5, 0), body.global_position, 70.0, stem + "_room")
		f.show_overlay(false)
		return


## How far from `at` the way `dir` (and a little below it) is clear, up to `most`.
func _open(game: Node, at: Vector3, dir: Vector3, most: float) -> float:
	var space: PhysicsDirectSpaceState3D = game.get_viewport().world_3d.direct_space_state
	var worst: float = most
	for drop: float in [0.0, -0.45]:
		var to: Vector3 = at + (dir + Vector3(0, drop, 0)).normalized() * most
		var q := PhysicsRayQueryParameters3D.create(at, to, LaneGraph.WORLD)
		q.hit_back_faces = true
		var hit: Dictionary = space.intersect_ray(q)
		if not hit.is_empty():
			worst = minf(worst, at.distance_to(hit["position"]))
	return worst


func _frame(game: Node, eye: Vector3, at: Vector3, fov: float, path: String, settle: bool = true) -> void:
	# Kept on this side of any wall between it and the bird.
	var q := PhysicsRayQueryParameters3D.create(at, eye, LaneGraph.WORLD)
	q.hit_back_faces = true
	var hit: Dictionary = game.get_viewport().world_3d.direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		eye = at.lerp(hit["position"], 0.85)
	game.player.teleport(eye - Vector3(0, 1.62, 0))
	var cam: Camera3D = game.player.camera
	cam.global_position = eye
	cam.look_at(at, Vector3.UP)
	cam.fov = fov
	for _i: int in (40 if settle else 2):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(path + ".png")
	cam.position = Vector3(0, 1.62, 0)

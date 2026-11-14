extends SceneTree
## Pictures of the pigeons (phase 20 step 2) for the look. Needs a display,
## not --headless; run `godot --headless --import` first.
##   godot --path . --resolution 1600x900 --audio-driver Dummy --script res://tests/pigeon_capture.gd -- <out dir> [place ...]
## place: zoo (default), area:<id> (its R04, R05, R06 rooms; the Gorge's
## scenery). For the first flock of each room writes <place>_<slot>_<shot>.png:
##   ledge   a perched bird and its row, from 2.5 m in front and a little below
##   close   one perched bird from 0.9 m, side on (the model)
##   ground  the birds on the floor, from standing height
##   wheel   the flock circling, from below
##   room    the room with the overlay (F4)

const TYPES: PackedStringArray = ["R04", "R05", "R06"]


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
			var shot: int = 0
			if area.recipe != null and area.recipe.scenery != null:
				await _settle(game, area.fauna, Fauna.SCENERY)
				await _shoot(game, area.fauna, Fauna.SCENERY, "%s/%s_scenery" % [out_dir, tag])
			for r: AreaPlan.Room in area.plan.rooms:
				if r.room_type not in TYPES or shot >= 6 or r.slot_id in ["bazaar_2", "bazaar_3", "bazaar_4", "quarter_2", "quarter_3"]:
					continue
				game.player.teleport(area.global_transform * CellGrid.cell_centre(r.floor_cells.keys()[0]))
				await _settle(game, area.fauna, r.slot_id)
				if await _shoot(game, area.fauna, r.slot_id, "%s/%s_%s" % [out_dir, tag, r.slot_id]):
					shot += 1
		else:
			var f: Fauna = world.get_node_or_null("Fauna") as Fauna
			await _settle(game, f, "roost")
			await _shoot(game, f, "roost", "%s/%s_roost" % [out_dir, tag])
		game.queue_free()
		for _i: int in 3:
			await process_frame
	main_script.room_override = ""
	quit()


func _settle(game: Node, f: Fauna, slot: String) -> void:
	for _i: int in 10:
		await process_frame
	var streamer: Variant = game.world.get("streamer")
	while streamer != null and streamer.busy():
		await process_frame
	for _i: int in 1200:
		if f == null or (f._jobs.is_empty() and f.found.has(slot)):
			break
		await process_frame
	for _i: int in 20:
		await process_frame


func _shoot(game: Node, f: Fauna, slot: String, stem: String) -> bool:
	for g: Node in f.groups.get(slot, []):
		if not g is PigeonFlock:
			continue
		var flock := g as PigeonFlock
		f.ignore_player = true
		print("  %s: %d pigeons, %d perches, wheel r %.1f" % [stem.get_file(), flock.count(), flock.perches.size(), flock.wheel_radius])
		# A perched bird with the most perched birds near it (a row), lowest first.
		var best: int = -1
		var best_n: int = -1
		for i: int in flock.birds.size():
			var b: Dictionary = flock.birds[i]
			if int(b["state"]) != PigeonFlock.PERCH:
				continue
			var n: int = 0
			for o: Dictionary in flock.birds:
				if int(o["state"]) == PigeonFlock.PERCH and (o["pos"] as Vector3).distance_to(b["pos"]) < 1.5:
					n += 1
			if n > best_n:
				best_n = n
				best = i
		if best >= 0:
			var b: Dictionary = flock.birds[best]
			var at: Vector3 = (b["pos"] as Vector3) + Vector3(0, 0.12, 0)
			var face: Vector3 = flock.perches[int(b["perch"])]["face"]
			await _frame(game, at + face * 2.5 + Vector3(0, -0.5, 0), at, 45.0, stem + "_ledge")
			var side := Vector3(-face.z, 0, face.x)
			await _frame(game, at + side * 0.9 + face * 0.3, at, 35.0, stem + "_close")
		var walker: int = -1
		for i: int in flock.birds.size():
			if int(flock.birds[i]["state"]) == PigeonFlock.WALK:
				walker = i
				break
		if walker >= 0:
			var at: Vector3 = flock.birds[walker]["pos"]
			await _frame(game, at + Vector3(2.2, 1.5, 1.2), at + Vector3(0, 0.15, 0), 50.0, stem + "_ground")
		f.show_overlay(true)
		var mid := Vector3(flock.centre.x, flock.wheel_height, flock.centre.z)
		await _frame(game, flock.centre + Vector3(9.0, 3.0, 9.0), flock.centre, 70.0, stem + "_room")
		f.show_overlay(false)
		if flock.wheel_radius > 0.0:
			flock._take_off(1.0, false)
			var t0: int = Time.get_ticks_msec()
			while Time.get_ticks_msec() - t0 < 3500:
				await process_frame
			var states: PackedStringArray = []
			for b: Dictionary in flock.birds:
				states.append("%d@%s" % [int(b["state"]), (b["pos"] as Vector3).snapped(Vector3.ONE * 0.1)])
			print("    wheel at %.1f m round %s: %s" % [flock.wheel_height, flock.centre.snapped(Vector3.ONE * 0.1), ", ".join(states.slice(0, 5))])
			var low: Vector3 = flock.centre - Vector3(0, 4.0, 0)
			if flock.perches.any(func(p: Dictionary) -> bool: return p["ground"]):
				low = (flock.perches.filter(func(p: Dictionary) -> bool: return p["ground"])[0]["at"] as Vector3) + Vector3(0, 1.6, 0)
			await _frame(game, low, mid, 75.0, stem + "_wheel", false)
		return true
	print("  %s: no pigeons" % stem.get_file())
	return false


func _frame(game: Node, eye: Vector3, at: Vector3, fov: float, path: String, settle: bool = true) -> void:
	var q := PhysicsRayQueryParameters3D.create(at, eye, HabitatScan.WORLD_MASK)
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

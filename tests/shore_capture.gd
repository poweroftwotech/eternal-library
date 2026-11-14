extends SceneTree
## Pictures of the eels and newts (phase 20 step 3) for the look. Needs a
## display, not --headless; run `godot --headless --import` first.
##   godot --path . --resolution 1600x900 --audio-driver Dummy --script res://tests/shore_capture.gd -- <out dir> [place ...]
## place: zoo (default) or area:<id>. For the first eels and newts of each room
## writes <place>_<slot>_<shot>.png:
##   eel_hole   an eel's head out of its hole, from above the water in front
##   eel_swim   an eel sent to another hole, a few seconds out
##   newt       one newt from 0.5 m, side on
##   newts      the bank and its newts from standing height
##   room       the room with the overlay (F4)


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
		var f: Fauna = (world as Area).fauna if world is Area else world.get_node_or_null("Fauna") as Fauna
		if world is Area:
			var area: Area = world
			for r: AreaPlan.Room in area.plan.rooms:
				if not r.room_type in ["R07", "R09", "R11", "R15", "R20", "R21"]:
					continue
				game.player.teleport(area.global_transform * CellGrid.cell_centre(r.floor_cells.keys()[0]))
				await _settle(game, f, r.slot_id)
				await _shoot(game, f, r.slot_id, "%s/%s_%s" % [out_dir, tag, r.slot_id])
		else:
			for slot: String in ["stream", "pier", "cistern"]:
				await _settle(game, f, slot)
				await _shoot(game, f, slot, "%s/%s_%s" % [out_dir, tag, slot])
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


func _shoot(game: Node, f: Fauna, slot: String, stem: String) -> void:
	f.ignore_player = true
	var shot_eel: bool = false
	var shot_newt: bool = false
	for g: Node in f.groups.get(slot, []):
		if g is EelHoles and not shot_eel:
			shot_eel = true
			var e := g as EelHoles
			print("  %s: %d eels, %d holes" % [stem.get_file(), e.count(), e.holes.size()])
			var hole: Dictionary = e.holes[int(e.eels[0]["hole"])]
			var at: Vector3 = hole["at"]
			var n: Vector3 = hole["n"]
			await _frame(game, at + n * 0.9 + Vector3(0, e.body.surface - at.y + 0.5, 0), at + n * 0.1, 45.0, stem + "_eel_hole")
			e.eels[0]["timer"] = 0.0
			var t0: int = Time.get_ticks_msec()
			while Time.get_ticks_msec() - t0 < 4000:
				await process_frame
			var pos: Vector3 = e.eels[0]["pos"]
			print("    eel 0: %s at %s" % [e.doing(0), pos.snapped(Vector3.ONE * 0.01)])
			await _frame(game, pos + Vector3(0.4, e.body.surface - pos.y + 0.7, 0.4), pos, 50.0, stem + "_eel_swim", false)
		elif g is NewtBank and not shot_newt:
			shot_newt = true
			var nb := g as NewtBank
			print("  %s: %d newts, %d spots" % [stem.get_file(), nb.count(), nb.spots.size()])
			var pos: Vector3 = nb.newts[0]["pos"]
			var yaw: float = nb.newts[0]["yaw"]
			var side := Vector3(cos(yaw), 0, -sin(yaw))
			await _frame(game, pos + side * 0.45 + Vector3(0, 0.22, 0), pos + Vector3(0, 0.02, 0), 40.0, stem + "_newt")
			await _frame(game, pos + side * 2.2 + Vector3(0.4, 1.5, 0.4), pos, 60.0, stem + "_newts")
	if shot_eel or shot_newt:
		f.show_overlay(true)
		var box: AABB = Fauna._bounds(f.groups[slot][0])
		await _frame(game, box.get_center() + Vector3(4.0, 3.0, 4.0), box.get_center(), 70.0, stem + "_room")
		f.show_overlay(false)
	else:
		print("  %s: no eels or newts" % stem.get_file())


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

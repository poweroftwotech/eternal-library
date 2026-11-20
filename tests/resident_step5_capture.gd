extends SceneTree
## Pictures for phase 21 step 5: the live Mahaleh's people. Needs a display,
## not --headless; run `godot --headless --import` first.
##   godot --path . --resolution 1600x900 --audio-driver Dummy --script res://tests/resident_step5_capture.gd -- <out dir> [--seed=N]
## A quarter's lane at three times of day (morning meal, the working day,
## night), and a bazaar's shop with one of the quarter's people keeping it
## and anyone buying.

## [name, bells]
const TIMES: Array = [["morning", 0.85], ["day", 2.0], ["night", 5.6]]


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var out_dir: String = "user://resident_step5"
	var seed_value: int = 1
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--seed="):
			seed_value = a.trim_prefix("--seed=").to_int()
		else:
			out_dir = a
	DirAccess.make_dir_recursive_absolute(out_dir)
	var main_script: GDScript = load("res://scripts/main.gd")
	main_script.room_override = "area:mahaleh"
	Area.seed_override = seed_value
	var game: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	current_scene = game
	game.hud.toast_time = 0
	game.hud.visible = false
	game.stats.visible = false
	game.player.blocked = true
	game.player.set_physics_process(false)
	for _i: int in 60:
		await process_frame
	var area: Area = game.world
	var residents: Residents = get_first_node_in_group(Residents.GROUP) as Residents
	if residents == null:
		print("resident_step5_capture: the area has no Residents")
		quit(1)
		return
	residents.heed_player = false
	var cam: Camera3D = game.player.camera
	var clock: DayClock = DayClock.it()
	clock.paused = true
	var quarters: Array[AreaPlan.Room] = []
	for q: AreaPlan.Room in area.plan.rooms:
		if q.grid != null and q.grid.meta.has("homes"):
			quarters.append(q)
	for q: AreaPlan.Room in quarters.slice(0, 2):
		var homes: Array = q.grid.meta["homes"]
		game.player.global_position = q.xf * (homes[0]["door"] as Vector3) + Vector3(0, 0.2, 0)
		await _wait(area, residents, q.slot_id)
		var room: Node3D = area.rooms[q.slot_id]
		var route: Array = q.grid.meta.get("route", [])
		for t: Array in TIMES:
			_settle(residents, clock, float(t[1]) * DayClock.BELL_S)
			# In front of each of the quarter's people in turn (you beside the camera, so the room is lit).
			var k: int = 0
			for p: Resident in residents.people:
				if p.home_slot != q.slot_id or p.away or k >= 4:
					continue
				if str(t[0]) == "night" and k >= 1:
					continue
				await _person(game, cam, p, "%s/%s_%s_%d_%s_%s.png" % [out_dir, q.slot_id, t[0], k, p.trade.replace(" ", "_"), p.doing])
				k += 1
			print("  %s %s: %s" % [q.slot_id, t[0], ", ".join(residents.people.filter(func(p: Resident) -> bool: return p.home_slot == q.slot_id).map(
					func(p: Resident) -> String: return "%s %s%s" % [p.trade, p.doing, "" if str(p.spot.get("slot", p.home_slot)) == p.home_slot else " (in " + str(p.spot["slot"]) + ")"]))])
	print("resident_step5_capture: %d people, %d doorways joined, %d drawn, %d of them cheaply" % [residents.people.size(),
			residents.links.values().filter(func(l: RID) -> bool: return l.is_valid()).size(), residents.drawn, residents.cheap])
	main_script.room_override = ""
	quit()


# A picture of one person from in front and a little to their right.
func _person(game: Node, cam: Camera3D, p: Resident, path: String) -> void:
	var facing: Vector3 = -p.global_basis.z
	var right: Vector3 = p.global_basis.x
	var lying: bool = p.doing == "sleep"
	var chest: Vector3 = p.global_position + Vector3(0, 0.3 if lying else 1.1 - (p.global_position.y - p.floor_y), 0)
	var eye: Vector3 = chest + Vector3(0, 1.8, 0) + right * 0.8
	if not lying:
		# From in front if that is clear, else from whichever side is.
		var space: PhysicsDirectSpaceState3D = root.world_3d.direct_space_state
		var best: float = -1.0
		for turn: float in [25.0, -25.0, 70.0, -70.0, 120.0, -120.0, 180.0, 0.0]:
			var dir: Vector3 = facing.rotated(Vector3.UP, deg_to_rad(turn))
			var want: Vector3 = chest + dir * 3.0 + Vector3(0, 0.45, 0)
			var q := PhysicsRayQueryParameters3D.create(chest, want, 1 | (1 << 8) | WorldProp.LAYER_PROPS)
			var hit: Dictionary = space.intersect_ray(q)
			var clear: float = 3.0 if hit.is_empty() else chest.distance_to(hit["position"]) - 0.3
			if clear > best + 0.4:
				best = clear
				eye = chest + dir * clear + Vector3(0, 0.45, 0) * (clear / 3.0)
			if clear >= 2.9:
				break
	game.player.global_position = Vector3(eye.x, p.floor_y + 0.2, eye.z)
	for _i: int in 20:
		await process_frame
	await _shot(cam, eye, p.global_position + Vector3(0, 0.2 if lying else 0.9, 0), 75.0, path)


func _wait(area: Area, residents: Residents, slot: String) -> void:
	for _i: int in 1500:
		await process_frame
		if not area.streamer.busy() and residents.settled() and residents.households.any(func(h: Dictionary) -> bool: return h["slot"] == slot):
			break
	for _i: int in 30:
		await process_frame


# Everyone to where `time` has them (walks skipped).
func _settle(residents: Residents, clock: DayClock, time: float) -> void:
	clock.time = fposmod(time - 20.0, DayClock.DAY_S)
	clock.speed = 60.0
	for _i: int in 3:
		residents.advance(0.1, clock)
	clock.time = fposmod(time, DayClock.DAY_S)
	for _i: int in 3:
		residents.advance(0.1, clock)
	clock.speed = 1.0


func _shot(cam: Camera3D, eye: Vector3, at: Vector3, fov: float, path: String) -> void:
	cam.global_position = eye
	cam.look_at(at, Vector3.UP)
	cam.fov = fov
	for _i: int in 40:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(path)

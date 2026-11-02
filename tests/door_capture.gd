extends SceneTree
## Captures each interior's Gorge door (phase 10 step 3): the real game from
## the Gorge, standing on the door's ledge facing the doorway, then a few
## metres through the vestibule into the area. Needs a display, not
## --headless; run `godot --headless --import` first.
##   godot --path . --resolution 1600x900 --script res://tests/door_capture.gd -- <out_prefix> [area ids…] --save=user://test/door_capture.json --fresh
## Writes <out_prefix>_<id>_ledge.png and <out_prefix>_<id>_inside.png; prints
## where the interior stood and whether the walk through the doorway swapped
## the place you're in to it.

var game: Node
var sp: SeamlessPlaces


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var args: PackedStringArray = []
	for a: String in OS.get_cmdline_user_args():
		if not a.begins_with("--"):
			args.append(a)
	var prefix: String = args[0] if args.size() > 0 else "user://door"
	var ids: Array = Array(args.slice(1)) if args.size() > 1 else SeamlessPlaces.recipes().keys().filter(func(i: String) -> bool: return i != "gorge")
	var main_script: GDScript = load("res://scripts/main.gd")
	main_script.room_override = "area:gorge"
	game = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	game.hud.toast_time = 0
	game.stats.visible = false
	game.player.blocked = true
	sp = game.seamless
	var fails: int = 0
	for id: String in ids:
		var gorge := sp.places["gorge"] as Area
		var door: Array = gorge.plan.threshold(id)
		if door.is_empty():
			print("door_capture: the Gorge has no door to %s on this seed" % id)
			fails += 1
			continue
		var ledge: String = (door[0] as AreaPlan.Room).slot_id
		var v_at: Transform3D = sp._placed(SeamlessPlaces._door_xf(gorge.plan, id))
		await _until(func() -> bool: return gorge.rooms.has(ledge) and sp.places.has(id) and (sp.places[id] as Area).is_built and sp.vestibules.has(id))
		var on: Vector3 = v_at * Vector3(0, 0, Area.ARRIVE_IN + 2.0)
		_place(on, v_at * Vector3(0, 0, -4.0))
		await _frames(100)
		root.get_viewport().get_texture().get_image().save_png("%s_%s_ledge.png" % [prefix, id])
		# Through the vestibule's dog-leg into the area, as world_walk_capture walks it.
		for p: Vector3 in [Vector3(0, 0, -4.5), Vector3(6, 0, -4.5), Vector3(6, 0, -9.0), Vector3(6, 0, -15.0)]:
			_place(v_at * p, v_at * (p + Vector3(0, 0, -3.0)))
			await _frames(20)
		await _frames(100)
		root.get_viewport().get_texture().get_image().save_png("%s_%s_inside.png" % [prefix, id])
		var interior := sp.places[id] as Area
		print("door_capture: %s: ledge %s, interior at %s, you're in %s%s" % [id, ledge, interior.global_position.snapped(Vector3.ONE * .1), sp.place_id,
			"" if sp.place_id == id else " (expected %s)" % id])
		if sp.place_id != id:
			fails += 1
		# Back out onto the ledge.
		for p: Vector3 in [Vector3(6, 0, -9.0), Vector3(6, 0, -4.5), Vector3(0, 0, -4.5), Vector3(0, 0, Area.ARRIVE_IN + 2.0)]:
			_place(v_at * p, v_at * (p + Vector3(0, 0, 3.0)))
			await _frames(20)
		await _frames(30)
		if sp.place_id != "gorge":
			print("door_capture: %s: back on the ledge, you're in %s (expected gorge)" % [id, sp.place_id])
			fails += 1
	main_script.room_override = ""
	print("door_capture: %d doors, %d failures" % [ids.size(), fails])
	quit(1 if fails > 0 else 0)


func _place(pos: Vector3, ahead: Vector3) -> void:
	game.player.global_position = pos + Vector3(0, .05, 0)
	var d := Vector3(ahead.x - pos.x, 0, ahead.z - pos.z)
	if d.length() > .05:
		game.player.rotation.y = atan2(-d.x, -d.z)
		game.player.camera.rotation.x = 0.0


func _frames(n: int) -> void:
	for i: int in n:
		await process_frame


func _until(cond: Callable) -> void:
	var stop: int = Time.get_ticks_msec() + 90000
	while not cond.call() and Time.get_ticks_msec() < stop:
		await process_frame

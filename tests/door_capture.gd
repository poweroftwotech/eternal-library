extends SceneTree
## Captures each interior's Gorge door (door travel, 2026-11-01): the real
## game from the Gorge, on the door's ledge facing the closed door from a few
## metres out, then close enough that the HUD offers to open it; opens it and
## captures where you arrive in the area; opens its door back to the Gorge.
## With --camp-door=<area id>, that area is put behind the camp's back door
## (in memory only) and the camp's side is captured the same way first.
## Needs a display, not --headless; run `godot --headless --import` first.
##   godot --path . --resolution 1600x900 --script res://tests/door_capture.gd -- <out_prefix> [area ids…] [--camp-door=<id>] --save=user://test/door_capture.json --fresh
## Writes <out_prefix>_<id>_ledge.png, _prompt.png and _inside.png (and
## <out_prefix>_camp_*.png); prints what the HUD offered and where you arrived.

var game: Node
var fails: int = 0
var main_script: GDScript = load("res://scripts/main.gd")


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var args: PackedStringArray = []
	var camp_door: String = ""
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--camp-door="):
			camp_door = a.trim_prefix("--camp-door=")
		elif not a.begins_with("--"):
			args.append(a)
	var prefix: String = args[0] if args.size() > 0 else "user://door"
	var ids: Array = Array(args.slice(1)) if args.size() > 1 else StratumPlan.current().recipes().keys().filter(func(i: String) -> bool: return i != "gorge")
	if camp_door != "":
		var sp := StratumPlan.new()
		sp.places = StratumPlan.current().places.duplicate(true)
		for l: Dictionary in StratumPlan.current().links:
			sp.links.append({"a": "camp", "b": camp_door, "kind": StratumPlan.DOOR, "at": StratumPlan.CAMP_BACK_DOOR} if str(l["b"]) == camp_door else l.duplicate())
		StratumPlan.use(sp)
		ids.erase(camp_door)
		main_script.room_override = "camp"
		_start()
		await _frames(30)
		var door: Threshold = game.world.get_node_or_null("Threshold_" + camp_door)
		if door == null:
			print("door_capture: the camp has no back door to %s" % camp_door)
			fails += 1
		else:
			await _door(door.global_transform, "%s_camp" % prefix, camp_door)
			var back: Array = (game.world as Area).door_to("camp") if game.world is Area else []
			if not back.is_empty():
				await _open(_door_xf(back))
	main_script.room_override = "area:gorge"
	if not game is Node or not game.world is Area or (game.world as Area).recipe.id != "gorge":
		if game != null:
			game.queue_free()
			await process_frame
		_start()
	for id: String in ids:
		var gorge := game.world as Area
		var door: Array = gorge.door_to(id)
		if door.is_empty():
			print("door_capture: the Gorge has no door to %s on this seed" % id)
			fails += 1
			continue
		var ledge: String = (door[0] as AreaPlan.Room).slot_id
		gorge.streamer.target = game.player
		game.player.global_position = _door_xf(door) * Vector3(0, .1, Area.ARRIVE_IN + 4.0)
		await _until(func() -> bool: return gorge.rooms.has(ledge) and not gorge.streamer.busy())
		await _door(_door_xf(door), "%s_%s" % [prefix, id], id)
		if game.world is Area and (game.world as Area).recipe.id == id:
			var back: Array = (game.world as Area).door_to("gorge")
			if back.is_empty() or not await _open(_door_xf(back)) or (game.world as Area).recipe.id != "gorge":
				print("door_capture: %s: no way back to the Gorge" % id)
				fails += 1
				break
	main_script.room_override = ""
	print("door_capture: %d doors, %d failures" % [ids.size() + (1 if camp_door != "" else 0), fails])
	quit(1 if fails > 0 else 0)


func _start() -> void:
	game = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	current_scene = game     # a door reloads it (main.travel)
	_quiet()


func _quiet() -> void:
	game.hud.toast_time = 0
	game.stats.visible = false


## The door at `at` (-Z out through it): from ARRIVE_IN + 4 m out (_ledge),
## then ARRIVE_IN with the HUD's prompt (_prompt); opens it and captures
## where you arrive (_inside).
func _door(at: Transform3D, name: String, to: String) -> void:
	_face(at, Area.ARRIVE_IN + 4.0)
	await _frames(100)
	root.get_viewport().get_texture().get_image().save_png(name + "_ledge.png")
	_face(at, Area.ARRIVE_IN)
	game.player.blocked = false     # the HUD's prompt shows only while you can move
	await _frames(40)
	var aimed: Object = game.player.ray.get_collider() if game.player.ray.is_colliding() else null
	print("door_capture: %s: the HUD says \"%s\"" % [to, game.prompt_for(aimed) if aimed != null and aimed.has_method("interaction_prompt") else ""])
	root.get_viewport().get_texture().get_image().save_png(name + "_prompt.png")
	if not await _open(at):
		fails += 1
		return
	await _frames(100)
	root.get_viewport().get_texture().get_image().save_png(name + "_inside.png")
	var here: String = (game.world as Area).recipe.id if game.world is Area else "camp"
	print("door_capture: %s: arrived in %s at %s%s" % [to, here, game.player.global_position.snapped(Vector3.ONE * .1), "" if here == to else " (expected %s)" % to])
	if here != to:
		fails += 1
		return
	# The door you came through, from inside (_back).
	var back: Array = (game.world as Area).door_to(StratumPlan.current().outside_of(here))
	if not back.is_empty():
		_face(_door_xf(back), Area.ARRIVE_IN + 1.0)
		await _frames(60)
		root.get_viewport().get_texture().get_image().save_png(name + "_back.png")


## Opens the door at `at` as E does, standing before it; whether the game
## reloaded on the other side.
func _open(at: Transform3D) -> bool:
	_face(at, Area.ARRIVE_IN)
	await _frames(6)
	var aimed: Object = game.player.ray.get_collider() if game.player.ray.is_colliding() else null
	if aimed == null or not aimed.has_method("interaction_prompt"):
		print("door_capture: no door in front of you at %s" % at.origin.snapped(Vector3.ONE * .1))
		return false
	var old: Node = game
	game.interact(aimed)
	await _until(func() -> bool: return current_scene != null and current_scene != old and current_scene.get("world") != null)
	if current_scene == old:
		return false
	game = current_scene
	_quiet()
	game.player.blocked = true
	await _frames(20)
	return true


## Stands `out` metres out from the door at `at`, facing it.
func _face(at: Transform3D, out: float) -> void:
	game.player.blocked = true
	game.player.teleport(at * Vector3(0, .1, out), at.basis.get_euler().y, -0.05)


## A door [room, connector] of the area you're in, in the world.
func _door_xf(door: Array) -> Transform3D:
	return (game.world as Area).global_transform * ((door[0] as AreaPlan.Room).connectors[door[1]]["xf"] as Transform3D)


func _frames(n: int) -> void:
	for _i: int in n:
		await process_frame


func _until(cond: Callable) -> void:
	var stop_ms: int = Time.get_ticks_msec() + 30000
	while not cond.call() and Time.get_ticks_msec() < stop_ms:
		await process_frame

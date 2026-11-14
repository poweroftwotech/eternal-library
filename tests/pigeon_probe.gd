extends SceneTree
## Phase 20 step 2 probe: the pigeons a place gets, room by room (flocks,
## ledges, ground spots, room to wheel) and what finding them cost. Headless.
##   godot --headless --audio-driver Dummy --path . --script res://tests/pigeon_probe.gd -- [place ...]
## place: zoo, area:<id> (its R04, R05, R06 rooms and its scenery).

const TYPES: PackedStringArray = ["R04", "R05", "R06"]


func _initialize() -> void:
	call_deferred("run")


func _report(f: Fauna, slot: String, tag: String) -> void:
	for _i: int in 900:
		if f == null or (f._jobs.is_empty() and f.found.has(slot)):
			break
		await process_frame
	if f == null:
		print("  %s: no Fauna" % tag)
		return
	var flocks: int = 0
	for g: Node in f.groups.get(slot, []):
		if g is PigeonFlock:
			var fl := g as PigeonFlock
			flocks += 1
			print("  %s: flock of %d, %d ledges, %d ground, wheel r %.1f at %.1f m, centre %s" % [tag, fl.count(), PigeonFlock.ledges_of(fl.perches),
				fl.perches.size() - PigeonFlock.ledges_of(fl.perches), fl.wheel_radius, fl.wheel_height, fl.centre.snapped(Vector3.ONE * 0.1)])
	for note: Dictionary in (f.found.get(slot, {}) as Dictionary).get("notes", []):
		if str(note["text"]).begins_with("Pigeon"):
			print("    note: " + str(note["text"]))
	if flocks == 0 and not f.found.has(slot):
		print("  %s: not scanned (found %s)" % [tag, f.found.keys()])
	print("    perches %.1f ms, worst scan %.1f ms" % [float((f.found.get(slot, {}) as Dictionary).get("perch_ms", 0.0)), float(f.stats["worst_scan_ms"])])


func run() -> void:
	var places: PackedStringArray = OS.get_cmdline_user_args()
	if places.is_empty():
		places = PackedStringArray(["zoo"])
	var main_script: GDScript = load("res://scripts/main.gd")
	for place: String in places:
		main_script.room_override = ZooRoom.SCENE if place == "zoo" else place
		var game: Node = (load("res://main.tscn") as PackedScene).instantiate()
		root.add_child(game)
		game.player.blocked = true
		for _i: int in 30:
			await process_frame
		var world: Node3D = game.world
		print("== %s" % place)
		if world is Area:
			var area: Area = world
			if area.recipe != null and area.recipe.scenery != null:
				await _report(area.fauna, Fauna.SCENERY, "scenery")
			for r: AreaPlan.Room in area.plan.rooms:
				if r.room_type not in TYPES:
					continue
				game.player.teleport(area.global_transform * CellGrid.cell_centre(r.floor_cells.keys()[0]))
				for _i: int in 10:
					await process_frame
				while area.streamer != null and area.streamer.busy():
					await process_frame
				await _report(area.fauna, r.slot_id, "%s %s" % [r.slot_id, r.room_type])
		else:
			await _report(world.get_node_or_null("Fauna") as Fauna, "roost", "roost pen")
		game.queue_free()
		for _i: int in 3:
			await process_frame
	main_script.room_override = ""
	quit()

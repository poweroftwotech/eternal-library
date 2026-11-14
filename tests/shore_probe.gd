extends SceneTree
## Phase 20 step 3 probe: the eels and newts a place gets, room by room (and
## why not, from the notes) and what finding them cost. Headless.
##   godot --headless --audio-driver Dummy --path . --script res://tests/shore_probe.gd -- [place ...]
## place: zoo, area:<id> (its rooms with water: R07, R09, R11, R15, R20, R21), camp.

const TYPES: PackedStringArray = ["R07", "R09", "R11", "R15", "R20", "R21"]


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
	for g: Node in f.groups.get(slot, []):
		if g is EelHoles:
			var e := g as EelHoles
			print("  %s: %d eels, %d holes, water %.0f m2 at %.2f" % [tag, e.count(), e.holes.size(), e.body.area(), e.body.surface])
		elif g is NewtBank:
			var nb := g as NewtBank
			var wet: int = nb.spots.filter(func(s: Dictionary) -> bool: return s["wet"]).size()
			print("  %s: %d newts, %d spots (%d in the shallows)" % [tag, nb.count(), nb.spots.size(), wet])
	for note: Dictionary in (f.found.get(slot, {}) as Dictionary).get("notes", []):
		if str(note["text"]).begins_with("Spiny") or str(note["text"]).begins_with("Luristan"):
			print("    note (%s): %s at %s" % [tag, str(note["text"]), (note["at"] as Vector3).snapped(Vector3.ONE * 0.1)])
	if not f.found.has(slot):
		print("  %s: not scanned" % tag)
	print("    worst scan %.1f ms" % float(f.stats["worst_scan_ms"]))


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
			var fz: Fauna = world.get_node_or_null("Fauna") as Fauna
			for _i: int in 60:
				await process_frame
			if fz != null:
				for slot: String in fz.groups:
					await _report(fz, slot, slot if slot != "" else "place")
		game.queue_free()
		for _i: int in 3:
			await process_frame
	main_script.room_override = ""
	quit()

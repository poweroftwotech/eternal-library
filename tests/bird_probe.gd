extends SceneTree
## Phase 20 step 1 probe: how the plants a bird could perch on show up in a
## loaded room (node names, scene paths, mesh or batch). Headless is fine.
##   godot --headless --audio-driver Dummy --path . --script res://tests/bird_probe.gd -- [place ...]

const WORDS: PackedStringArray = ["tree", "shrub", "planter", "bed", "rose", "fig", "pomegranate", "cypress", "orchard", "ivy", "fern", "vine", "plant"]
const TYPES: PackedStringArray = ["R07", "R09"]


func _initialize() -> void:
	call_deferred("run")


var dump: bool = false


## The room's nightingales once Fauna has filled it: how many, their perches,
## what the scan cost.
func _birds(f: Fauna, slot: String) -> void:
	for _i: int in 600:
		if f == null or f._jobs.is_empty():
			break
		await process_frame
	if f == null:
		print("  no Fauna")
		return
	var n: int = 0
	for g: Node in f.groups.get(slot, []):
		if g is BirdBand:
			var band := g as BirdBand
			var highs: int = band.perches.filter(func(p: Dictionary) -> bool: return bool(p["high"])).size()
			print("  nightingales %d: %d perches (%d high, %d flowers), first at %s" % [band.count(), band.perches.size(), highs,
				band.perches.filter(func(p: Dictionary) -> bool: return bool(p["flower"])).size(), band.perches[0]["at"]])
			n += 1
	for note: Dictionary in (f.found.get(slot, {}) as Dictionary).get("notes", []):
		if str(note["text"]).begins_with("Nightingale"):
			print("  note: " + str(note["text"]))
	if n == 0:
		print("  no nightingales; found %s; job keys %s; defs %s" % [f.found.keys(), (f.found.get(slot, {}) as Dictionary).keys(),
			f.defs.map(func(d: CreatureDef) -> String: return str(d.id))])
	print("  worst scan %.1f ms, perches %.1f ms" % [float(f.stats["worst_scan_ms"]), float((f.found.get(slot, {}) as Dictionary).get("perch_ms", 0.0))])


func run() -> void:
	var places: PackedStringArray = []
	for a: String in OS.get_cmdline_user_args():
		if a == "--dump":
			dump = true
		else:
			places.append(a)
	if places.is_empty():
		places = PackedStringArray(["camp", "area:grand_study"])
	var main_script: GDScript = load("res://scripts/main.gd")
	for place: String in places:
		main_script.room_override = place
		var game: Node = (load("res://main.tscn") as PackedScene).instantiate()
		root.add_child(game)
		game.player.blocked = true
		for _i: int in 30:
			await process_frame
		var world: Node3D = game.world
		if world is Area:
			var area: Area = world
			for r: AreaPlan.Room in area.plan.rooms:
				if r.room_type not in TYPES:
					continue
				var c: Vector3 = area.global_transform * CellGrid.cell_centre(r.floor_cells.keys()[0])
				game.player.teleport(c)
				for _i: int in 10:
					await process_frame
				while area.streamer != null and area.streamer.busy():
					await process_frame
				for _i: int in 10:
					await process_frame
				var room: Node3D = area.rooms.get(r.slot_id) as Node3D
				print("== %s %s %s state '%s' no_animals %s" % [place, r.slot_id, r.room_type, str(r.grammar.get_meta("state", "")) if r.grammar != null else "", r.no_animals])
				await _birds(area.fauna, r.slot_id)
				if room != null and dump:
					_dump(room, room)
		else:
			print("== %s" % place)
			await _birds(world.get_node_or_null("Fauna") as Fauna, "")
			if dump:
				_dump(world, world)
		game.queue_free()
		for _i: int in 3:
			await process_frame
	quit()


func _dump(n: Node, top: Node) -> void:
	var counts: Dictionary = {}
	var stack: Array = [n]
	while not stack.is_empty():
		var at: Node = stack.pop_back()
		stack.append_array(at.get_children())
		if not (at is MeshInstance3D or at is MultiMeshInstance3D):
			continue
		var tag: String = _tag(at, top)
		if tag == "":
			continue
		var key: String = "%s | %s" % [at.get_class(), tag]
		if not counts.has(key):
			var g := at as GeometryInstance3D
			var box: AABB = g.global_transform * g.get_aabb()
			counts[key] = [0, box.size, str(at.get_path()).right(90)]
		counts[key][0] += 1
	for k: String in counts:
		print("  %3d  %s  size %s  e.g. %s" % [counts[k][0], k, counts[k][1], counts[k][2]])


## The first plant word in the node's name or scene path, or its ancestors'.
func _tag(n: Node, top: Node) -> String:
	var at: Node = n
	while at != null and at != top.get_parent():
		var s: String = (str(at.name) + " " + at.scene_file_path).to_lower()
		for w: String in WORDS:
			if s.contains(w):
				return "%s (%s)" % [w, str(at.name) if at.scene_file_path == "" else at.scene_file_path.get_file()]
		at = at.get_parent()
	return ""

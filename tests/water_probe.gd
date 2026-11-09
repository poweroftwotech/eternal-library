extends SceneTree
## Lists the still water HabitatScan finds in each place (phase 19 step 1):
## every body's room, size, surface, material, and once sounded, how many
## places a fish can be and how deep. Headless is fine (it needs physics, not
## the GPU).
##   godot --headless --audio-driver Dummy --path . --script res://tests/water_probe.gd -- [place ...]
## place: camp, a scene path (res://rooms/lake/landing.tscn) or area:<id>
## (every room of the area is visited). Default: the camp, the lake and the
## live areas.

const DEFAULT: PackedStringArray = ["camp", "res://rooms/lake/landing.tscn", "area:grand_study", "area:gardens", "area:mahaleh", "area:forgotten_city"]


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var places: PackedStringArray = PackedStringArray(OS.get_cmdline_user_args()).duplicate()
	if places.is_empty():
		places = DEFAULT
	var main_script: GDScript = load("res://scripts/main.gd")
	for place: String in places:
		main_script.room_override = place
		var game: Node = (load("res://main.tscn") as PackedScene).instantiate()
		root.add_child(game)
		game.player.blocked = true
		for _i: int in 10:
			await physics_frame
		var world: Node = game.world
		print("== %s" % place)
		if world is Area:
			var area: Area = world
			for r: AreaPlan.Room in area.plan.rooms:
				var c: Vector3 = area.global_transform * r.xf * Vector3.ZERO
				if not r.floor_cells.is_empty():
					c = area.global_transform * CellGrid.cell_centre(r.floor_cells.keys()[0])
				game.player.teleport(c)
				for _i: int in 5:
					await process_frame
				while area.streamer != null and area.streamer.busy():
					await process_frame
				for _i: int in 3:
					await physics_frame
				var room: Node = area.rooms.get(r.slot_id)
				if room != null:
					report("%s (%s%s)" % [r.slot_id, r.room_type, " abandoned" if r.grammar != null and r.grammar.get_meta("state", "") == RoomGrammar.ABANDONED else ""], room)
		else:
			report(place, world)
		game.queue_free()
		for _i: int in 3:
			await process_frame
	main_script.room_override = ""
	quit()


func report(label: String, room: Node) -> void:
	var space: PhysicsDirectSpaceState3D = (room as Node3D).get_world_3d().direct_space_state
	var t0: int = Time.get_ticks_usec()
	var bodies: Array[WaterBody] = HabitatScan.water_bodies(room)
	var scan_ms: float = (Time.get_ticks_usec() - t0) / 1000.0
	if bodies.is_empty():
		return
	print("  %s: %d bodies (scan %.1f ms)" % [label, bodies.size(), scan_ms])
	for b: WaterBody in bodies:
		var ts: int = Time.get_ticks_usec()
		while not HabitatScan.sound(b, space, Time.get_ticks_usec() + 1000000):
			pass
		print("    surface %.2f, %.1f x %.1f m (%.0f m2, %d tris), %d places, mean depth %.2f m, >=0.3 m: %d, >=0.6 m: %d, sound %.1f ms, %s" % [b.surface,
			b.bounds.size.x, b.bounds.size.z, b.area(), b.tris.size() / 3, b.samples.size(), b.mean_depth(), b.deep_samples(0.3).size(),
			b.deep_samples(0.6).size(), (Time.get_ticks_usec() - ts) / 1000.0, b.material.get_file() if b.material != "" else "(scene's own)"])

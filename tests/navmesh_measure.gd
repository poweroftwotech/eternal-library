extends SceneTree
## Phase 19 Q6's measurement: what a navigation mesh for one streamed room
## would cost, so the people phase starts with numbers. Nothing in the game
## uses one. Runs headless:
##   godot --headless --path . --audio-driver Dummy --script res://tests/navmesh_measure.gd -- [area:<id>] [slot ...]
## Default: area:mahaleh, its first Domicile Quarter, its first bazaar and its
## first other room. For each room and for two walkers (a person: 0.25 m
## radius, 1.75 m tall; a cat: 0.15 m, 0.3 m) prints: reading the room's
## collision shapes (must be on the main thread), the bake (can be on another
## thread), the polygons and the memory the mesh takes; and beside them the
## cat's lane graph for the same room (LaneGraph).

const WALKERS: Array = [["person", 0.25, 1.75, 0.25, 0.25], ["cat", 0.15, 0.3, 0.15, 0.15]]     # name, radius, height, climb, cell (each a whole number of cells)


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var place: String = "area:mahaleh"
	var slots: PackedStringArray = []
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("area:"):
			place = a
		else:
			slots.append(a)
	var main_script: GDScript = load("res://scripts/main.gd")
	main_script.room_override = place
	var game: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	game.hud.visible = false
	game.player.blocked = true
	for _i: int in 30:
		await process_frame
	var area: Area = game.world as Area
	if area == null:
		print("navmesh_measure: %s is not an area" % place)
		quit()
		return
	if slots.is_empty():
		var seen: Dictionary = {}
		for r: AreaPlan.Room in area.plan.rooms:
			var kind: String = r.room_type if r.room_type in ["R06", "R04"] else "other"
			if not seen.has(kind):
				seen[kind] = true
				slots.append(r.slot_id)
	for slot: String in slots:
		var r: AreaPlan.Room = area.plan.room(slot)
		if r == null:
			print("navmesh_measure: no room %s" % slot)
			continue
		game.player.teleport(area.global_transform * CellGrid.cell_centre(r.floor_cells.keys()[0]))
		for i: int in 900:
			await process_frame
			if i > 60 and not area.streamer.busy() and area.fauna._jobs.is_empty():
				break
		var room: Node3D = area.rooms.get(slot) as Node3D
		if room == null:
			print("navmesh_measure: %s isn't loaded" % slot)
			continue
		print("navmesh_measure: %s %s (%s), %d floor cells (%d m2), %d nodes" % [place, slot, r.room_type, r.floor_cells.size(), r.floor_cells.size() * 16, room.find_children("*", "", true, false).size()])
		for w: Array in WALKERS:
			var nm := NavigationMesh.new()
			nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
			nm.geometry_collision_mask = LaneGraph.WORLD
			nm.cell_size = float(w[4])
			nm.cell_height = float(w[4])
			nm.agent_radius = float(w[1])
			nm.agent_height = float(w[2])
			nm.agent_max_climb = float(w[3])
			var src := NavigationMeshSourceGeometryData3D.new()
			var t0: int = Time.get_ticks_usec()
			NavigationServer3D.parse_source_geometry_data(nm, src, room)
			var t1: int = Time.get_ticks_usec()
			NavigationServer3D.bake_from_source_geometry_data(nm, src)
			var t2: int = Time.get_ticks_usec()
			var polys: int = nm.get_polygon_count()
			var verts: int = nm.get_vertices().size()
			var indices: int = 0
			for p: int in polys:
				indices += nm.get_polygon(p).size()
			var bytes: int = verts * 12 + indices * 4
			print("  %s: read shapes %.1f ms (main thread), bake %.1f ms (can be threaded), %d polygons, %d vertices, about %.0f KB" % [w[0], (t1 - t0) / 1000.0, (t2 - t1) / 1000.0, polys, verts, bytes / 1024.0])
		for g: Node in area.fauna.groups.get(slot, []):
			var band := g as CatBand
			if band != null:
				var links: int = 0
				for l: PackedInt32Array in band.graph.links:
					links += l.size()
				print("  the cat's lane graph: %d points, %d joins, about %.0f KB" % [band.graph.points.size(), links / 2, (band.graph.points.size() * 12 + links * 4) / 1024.0])
		var t3: int = Time.get_ticks_usec()
		var again: LaneGraph = LaneGraph.build(room, room.get_world_3d().direct_space_state, [], r.floor_cells.keys(), area.global_transform)
		print("  building it: %.1f ms in all, spread at 1 ms a frame (%d points)" % [(Time.get_ticks_usec() - t3) / 1000.0, again.points.size()])
	main_script.room_override = ""
	quit()

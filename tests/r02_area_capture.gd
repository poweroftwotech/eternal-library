extends SceneTree
## GPU pictures of the Stack Galleries inside the real Lower Stacks area (stacks
## rework, 2026-11-04): the area's atmosphere and each gallery's mood tint,
## which r02_capture.gd (a gallery off R01) does not have. Needs a display,
## not --headless; run `godot --headless --import` first.
##   godot --path . --resolution 1920x1080 --script res://tests/r02_area_capture.gd -- <out dir> [area seed] [area id] [--preset=medium]
## For every gallery of the area, three views down its run from bays near the
## entry, the middle and the far end, named r02a_<seed>_<slot>_<near|mid|far>.png,
## each printed with its bay's abandon.

const EASE_FRAMES: int = 150      # the room tint eases in (Area._ease_room_glow)


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var args: PackedStringArray = []
	for a: String in OS.get_cmdline_user_args():
		if not a.begins_with("--"):
			args.append(a)
	var out_dir: String = args[0] if args.size() > 0 else "user://r02a"
	var area_seed: int = int(args[1]) if args.size() > 1 else 1
	var area_id: String = args[2] if args.size() > 2 else "lower_stacks"
	DirAccess.make_dir_recursive_absolute(out_dir)
	var main_script: GDScript = load("res://scripts/main.gd")
	main_script.room_override = "area:" + area_id
	Area.seed_override = area_seed
	var game: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	game.hud.toast_time = 0
	game.hud.visible = false
	game.stats.visible = false
	game.player.blocked = true
	game.player.set_physics_process(false)
	var area: Area = game.world
	for slot: String in area.rooms:
		var room := area.rooms[slot] as GeneratedRoom
		if room == null or not (room.grammar is StackGalleryGrammar) or room.grid == null:
			continue
		var g: CellGrid = room.grid
		var order: Array[Vector3i] = g.run_order()
		if order.size() < 4:
			continue
		var picks: Dictionary = {"near": 0, "mid": order.size() / 2 - 1, "far": order.size() - 3}
		for view: String in picks:
			var j: int = clampi(picks[view], 0, order.size() - 3)
			var c: Vector3i = order[j]
			var ahead: Vector3i = order[j + 2]
			var eye: Vector3 = room.to_global(CellGrid.cell_centre(c) + Vector3(0, 1.65, 0))
			var target: Vector3 = room.to_global(CellGrid.cell_centre(ahead) + Vector3(0, 1.5, 0))
			game.player.global_position = eye - Vector3(0, game.player.camera.position.y, 0)
			game.look_toward(target)
			for _i: int in EASE_FRAMES:
				await process_frame
			await RenderingServer.frame_post_draw
			var path: String = "%s/r02a_%d_%s_%s.png" % [out_dir, area_seed, slot, view]
			root.get_viewport().get_texture().get_image().save_png(path)
			print("r02_area_capture: %s %s bay %d of %d, abandon %.2f -> %s" % [slot, view, j, order.size(), float(g.cells[c].get("abandon", 0.0)), path])
		# Parts 3-4: a close look at the first of each feature (two breaches,
		# two puddles): recess pins face their wall, props from the corridor.
		var shots: Array = []
		var seen: Dictionary = {}
		for k: String in g.pins:
			var name: String = {"rock breach": "breach", "taghcheh": "taghcheh", "webbed shelves": "cobwebs"}.get(g.pins[k], "")
			if name != "" and int(seen.get(name, 0)) < (2 if name == "breach" else 1) and k.begins_with("edge_"):
				seen[name] = int(seen.get(name, 0)) + 1
				var e: Dictionary = g.edges[k.trim_prefix("edge_")]
				var centre: Vector3 = CellGrid.cell_centre(e["cell"])
				var out: Vector3 = (CellGrid.cell_centre(CellGrid.neighbour(e["cell"], e["side"])) - centre).normalized()
				var high: float = 2.4 if name == "cobwebs" else 1.3
				shots.append([name, centre - out * 1.4 + Vector3(0, 1.6, 0), centre + out * 2.0 + Vector3(0, high, 0)])
		for k: String in g.props:
			for pre: String in ["reading_", "keeper_", "roots_"]:
				if k.begins_with(pre) and not seen.has(pre):
					seen[pre] = 1
					var xf: Transform3D = g.props[k]["xf"]
					if pre == "roots_":
						shots.append(["roots", xf.origin + Vector3(1.8, -4.3, 0.6), xf.origin + Vector3(0, -1.2, 0)])
					else:     # from 2.2 m out into the corridor and a step along
						shots.append([pre.trim_suffix("_"), xf.origin - xf.basis.z * 2.2 + xf.basis.x * 1.2 + Vector3(0, 1.6, 0), xf.origin + Vector3(0, 0.5, 0)])
		var puddles: int = 0
		for k: String in g.props:
			if k.begins_with("puddle_") and puddles < 2:
				puddles += 1
				var at: Vector3 = (g.props[k]["xf"] as Transform3D).origin
				# From the far side of the bay's middle, looking down at it (the
				# puddle lies toward one wall).
				var cell := Vector3i(floori(at.x / CellGrid.BAY), 0, floori(-at.z / CellGrid.BAY))
				var centre: Vector3 = CellGrid.cell_centre(cell)
				var away: Vector3 = Vector3(centre.x - at.x, 0, centre.z - at.z).normalized()
				shots.append(["puddle", centre + away * 0.7 + Vector3(0, 1.65, 0), at])
		for i: int in shots.size():
			var s: Array = shots[i]
			game.player.global_position = room.to_global(s[1]) - Vector3(0, game.player.camera.position.y, 0)
			game.look_toward(room.to_global(s[2]))
			for _i: int in EASE_FRAMES:
				await process_frame
			await RenderingServer.frame_post_draw
			var spath: String = "%s/r02a_%d_%s_%s_%d.png" % [out_dir, area_seed, slot, s[0], i]
			root.get_viewport().get_texture().get_image().save_png(spath)
			print("r02_area_capture: %s %s -> %s" % [slot, s[0], spath])
	main_script.room_override = ""
	Area.seed_override = -1
	quit()

extends SceneTree
## GPU pictures of the R04 Grand Bazaar (phase 15) in the real game, on the
## Mahaleh's test copy (gen/recipes/drafts/mahaleh/bazaar_test.tres,
## tools/make_r04_draft.gd). Needs a display, not --headless; run
## `godot --headless --import` first.
##   godot --audio-driver Dummy --path . --resolution 1920x1080 --script res://tests/r04_capture.gd -- <out dir> [area seed] [draft: bazaar_test, bazaar_deserted]
## Writes r04_<seed>_<view>.png:
##   street    just inside the entry street, on toward the crossing
##   mouth     where the street meets the crossing, up at the dome
##   dome      the middle of the crossing, straight up
##   across    a corner of the crossing, over it to the far side
##   glass     the crossing's middle, at a side (the tall glass if there is one)
##   back      the far door, back along the route to the crossing
##   shop      in the first open shop, out to the street
##   shop_in   from the street, into that shop
##   shop_arch from the street, up at the top of its arch (where the vault meets it)
##   crowd, middle, rumours  across the crossing, at its middle, at the board
##   t_<trade> from the street into the first shop of that trade
##   i_<trade> inside it, at its counter and back wall
##   a_<trade>, b_<trade> inside it, at each side wall

const DRAFT: String = "res://gen/recipes/drafts/mahaleh/%s.tres"


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else "user://r04"
	var area_seed: int = int(args[1]) if args.size() > 1 else 1
	var draft: String = args[2] if args.size() > 2 else "bazaar_test"
	DirAccess.make_dir_recursive_absolute(out_dir)
	var ws: Node = root.get_node_or_null("/root/WorldState")
	ws.set("walk_area", "mahaleh")
	ws.set("walk_recipe", DRAFT % draft)
	var main_script: GDScript = load("res://scripts/main.gd")
	main_script.room_override = "area:mahaleh"
	Area.seed_override = area_seed
	var game: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	current_scene = game
	game.hud.toast_time = 0
	game.hud.visible = false
	game.stats.visible = false
	game.player.blocked = true
	game.player.set_physics_process(false)
	var area: Area = game.world
	for plan: AreaPlan.Room in area.plan.rooms:
		if not plan.slot_id.begins_with("bazaar_"):
			continue
		for p: Vector3 in AreaTour.leg(area.plan, plan):
			game.player.global_position = area.to_global(p) + Vector3(0, 0.05, 0)
			for _i: int in 6:
				await process_frame
			while area.streamer.busy():
				await process_frame
		var room: GeneratedRoom = area.rooms.get(plan.slot_id)
		var meta: Dictionary = plan.grid.meta
		var route: Array = meta["route"]
		var mid: Vector3 = meta["centre"]
		var eye := Vector3(0, 1.6, 0)
		print("r04_capture: streets %s, open shops %d, water %s" % [meta["streets"], (meta["shops"] as Array).size(), meta["jet"] != Vector3.ZERO])
		var lit: int = 0
		for l: Node in room.find_children("*", "Light3D", true, false):
			lit += 1
		print("  lights in room: ", lit)
		var views: Dictionary = {
			"street": [route[1] + eye, mid + Vector3(0, 3.0, 0)],
			"mouth": [mid + Vector3(0, 1.6, 10.0), mid + Vector3(0, 13.0, 0)],
			"dome": [mid + Vector3(3.0, 1.6, 3.0), mid + Vector3(-1.5, 18.0, -1.5)],
			"across": [mid + Vector3(-6.5, 1.6, 6.5), mid + Vector3(6.0, 8.0, -6.0)],
			"vault": [mid + Vector3(-5.5, 1.6, 5.5), mid + Vector3(1.0, 17.0, -1.0)],
			"glass_e": [mid + Vector3(-6.0, 1.6, 0), mid + Vector3(8.0, 8.0, 0)],
			"glass_w": [mid + Vector3(6.0, 1.6, 0), mid + Vector3(-8.0, 8.0, 0)],
			"glass_n": [mid + Vector3(0, 1.6, 6.0), mid + Vector3(0, 8.0, -8.0)],
			"back": [route[route.size() - 2] + eye, mid + Vector3(0, 5.0, 0)],
			"wall_n": [mid + Vector3(6.0, 1.6, -4.5), mid + Vector3(6.0, 1.4, -9.0)],
			"wall_e": [mid + Vector3(4.5, 1.6, 6.0), mid + Vector3(9.0, 1.4, 6.0)],
			"crowd": [mid + Vector3(-7.0, 1.6, 7.0), mid + Vector3(1.0, 1.4, -1.0)],
			"middle": [mid + Vector3(1.0, 1.6, 5.5), mid + Vector3(0, 1.0, 0)],
			"rumours": [(meta["board"] as Vector3) + (mid - meta["board"]).normalized() * 2.0 + eye, (meta["board"] as Vector3) + Vector3(0, 1.5, 0)],
		}
		if not (meta["shops"] as Array).is_empty():
			var inside: Vector3 = meta["shops"][0][0]
			var out: Vector3 = meta["shops"][0][1]
			views["shop"] = [inside + eye, out + eye]
			views["shop_in"] = [out + eye, inside + Vector3(0, 2.2, 0)]
			views["shop_arch"] = [out + eye, out.lerp(inside, 0.45) + Vector3(0, 4.0, 0)]
			# Each trade: from the street into it, and out of it from its middle.
			for s: Array in meta["shops"]:
				if not views.has("t_" + s[2]):
					views["t_" + s[2]] = [(s[1] as Vector3) + (s[1] - s[0]).normalized() * 1.2 + eye, (s[0] as Vector3) + Vector3(0, 1.1, 0)]
					var across: Vector3 = (s[0] - s[1]).normalized().cross(Vector3.UP)
					views["a_" + s[2]] = [(s[0] as Vector3) + across * 1.2 + (s[1] - s[0]).normalized() * 0.6 + eye, (s[0] as Vector3) - across * 2.0 + Vector3(0, 1.2, 0)]
					views["b_" + s[2]] = [(s[0] as Vector3) - across * 1.2 + (s[1] - s[0]).normalized() * 0.6 + eye, (s[0] as Vector3) + across * 2.0 + Vector3(0, 1.2, 0)]
					views["i_" + s[2]] = [(s[1] as Vector3).lerp(s[0], 0.72) + eye, (s[0] as Vector3) + (s[0] - s[1]).normalized() * 2.0 + Vector3(0, 1.4, 0)]
		for view: String in views:
			var at: Array = views[view]
			var cam: Camera3D = game.player.camera
			game.player.global_position = room.to_global(at[0]) - Vector3(0, 1.6, 0)
			for _i: int in 8:
				await process_frame
			while area.streamer.busy():
				await process_frame
			cam.global_position = room.to_global(at[0])
			cam.look_at(room.to_global(at[1]))
			for _i: int in 90:
				cam.global_position = room.to_global(at[0])
				cam.look_at(room.to_global(at[1]))
				await process_frame
			root.get_viewport().get_texture().get_image().save_png("%s/r04_%d_%s.png" % [out_dir, area_seed, view])
	quit()



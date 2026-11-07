extends SceneTree
## GPU pictures of the R17 Ossuary of Books (phase 16) in the real game, on the
## Mahaleh's test copy (gen/recipes/drafts/mahaleh/ossuary_test.tres,
## tools/make_r17_draft.gd). Needs a display, not --headless; run
## `godot --headless --import` first.
##   godot --audio-driver Dummy --path . --resolution 1920x1080 --script res://tests/r17_capture.gd -- <out dir> [area seed] [draft] [bright]
## Writes r17_<seed>_<view>.png:
##   bier_<n>  close over each bier
##   throat    the far end of the cave cell, on into the low passage
##   passage   along the first run toward the chamber
##   chamber   from the chamber's entry arm, at the shrine
##   across    the chamber's middle, along an arm
##   shrine    close to the shrine's niche
##   wall      a passage wall, straight on, for the niches
##   candle    close to the first niche candle
##   end       the last passage cell of the route, on along it
##   door, exit  in at the entry door; out along the last cells to the far door
##   stop_<n>  each dead end, from the cell before it

const DRAFT: String = "res://gen/recipes/drafts/mahaleh/%s.tres"


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else "user://r17"
	var area_seed: int = int(args[1]) if args.size() > 1 else 1
	var draft: String = args[2] if args.size() > 2 else "ossuary_test"
	var bright: bool = args.size() > 3 and args[3] == "bright"     # a lamp on the camera, to check the stonework
	DirAccess.make_dir_recursive_absolute(out_dir)
	var ws: Node = root.get_node_or_null("/root/WorldState")
	ws.set("path", "user://test/r17_capture.json")     # lighting the candle must not touch a real save
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
		if not plan.slot_id.begins_with("ossuary_"):
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
		var mid: Vector3 = meta["chamber"]
		var eye := Vector3(0, 1.6, 0)
		var lit: int = room.find_children("*", "Light3D", true, false).size()
		print("r17_capture: %d goods pieces, %d hosts in the scene" % [room.find_children("prop_os_item_*", "Node3D", true, false).size(), get_nodes_in_group("possession_host").size()])
		var life: Array = room.find_children("*", "Node3D", true, false).filter(func(x: Node) -> bool: return x is OssuaryLife)
		print("r17_capture: %d cells, far door %s, %d dead ends, %d lights, %d niche candles, %d candles moving" % [meta["cells"], meta["far_door"], (meta["stops"] as Array).size(), lit, (meta["candles"] as Array).size(), (life[0]._candles as Array).size() if not life.is_empty() else -1])
		var views: Dictionary = {
			"chamber": [mid + Vector3(0, 1.6, 4.8), mid + Vector3(0, 1.2, -4.0)],
			"across": [mid + Vector3(-1.5, 1.6, 1.5), mid + Vector3(5.5, 1.5, -0.2)],
			"shrine": [mid + Vector3(0.8, 1.6, -1.6), mid + Vector3(0, 0.9, -4.6)],
			"vault": [mid + Vector3(0, 1.6, 2.0), mid + Vector3(0, 3.6, -2.0)],
		}
		if route.size() > 3:
			views["door"] = [(route[0] as Vector3) + eye, (route[2] as Vector3) + eye]
			views["exit"] = [(route[route.size() - 3] as Vector3) + eye, (route[route.size() - 1] as Vector3) + eye]
			views["throat"] = [(route[1] as Vector3) + eye, (route[3] as Vector3) + eye]
			views["passage"] = [(route[2] as Vector3) + eye, (route[4] as Vector3) + eye]
			var w: Vector3 = route[3]
			var along: Vector3 = ((route[4] as Vector3) - w).normalized()
			var side: Vector3 = along.cross(Vector3.UP)
			views["wall"] = [w + side * 0.8 + Vector3(0, 1.3, 0), w - side * 2.0 + Vector3(0, 1.2, 0)]
			views["end"] = [(route[route.size() - 4] as Vector3) + eye, (route[route.size() - 2] as Vector3) + eye]
		if not (meta["candles"] as Array).is_empty():
			var spot: Vector3 = meta["candles"][0]
			var mine: Vector3 = spot
			views["candle"] = [mine + Vector3(0, 0.3, 0) + ((route[3] as Vector3) - spot).normalized() * 1.4, mine + Vector3(0, 0.15, 0)]
		var h: int = 0
		for host: Transform3D in meta.get("hosts", []):
			views["bier_%d" % h] = [host.origin + host.basis * Vector3(1.0, 0.75, 1.75), host.origin]
			h += 1
		var n: int = 0
		for s: Vector3 in meta["stops"]:
			views["stop_%d" % n] = [(meta["stop_from"][n] as Vector3) + eye, s + Vector3(0.0, 1.2, 0.0)]
			n += 1
		for what: String in meta.get("sights", {}):
			views["see_" + what] = meta["sights"][what]
		var lamp := OmniLight3D.new()
		lamp.omni_range = 14.0
		lamp.light_energy = 2.5 if bright else 0.0
		game.player.camera.add_child(lamp)
		for view: String in views:
			var at: Array = views[view]
			var cam: Camera3D = game.player.camera
			game.player.global_position = room.to_global(at[0]) - Vector3(0, 1.6, 0)
			for _i: int in 8:
				await process_frame
			while area.streamer.busy():
				await process_frame
			for _i: int in 60:
				cam.global_position = room.to_global(at[0])
				cam.look_at(room.to_global(at[1]))
				await process_frame
			root.get_viewport().get_texture().get_image().save_png("%s/r17_%d_%s.png" % [out_dir, area_seed, view])
		var vigil: Array[Node] = room.find_children("*", "ShrineCandle", true, false)
		print("r17_capture: prompt \"%s\"" % vigil[0].interaction_prompt(Vector3.ZERO))
		vigil[0].interact(game.player, Vector3.ZERO)
		print("r17_capture: prompt \"%s\", burning %.2f; sights %s" % [vigil[0].interaction_prompt(Vector3.ZERO), vigil[0].burning(), (meta.get("sights", {}) as Dictionary).keys()])
		for prop: WorldProp in room.world_props():
			if prop.item != null:
				var what: StringName = prop.item.id
				print("r17_capture: prompt \"%s\"" % prop.interaction_prompt(Vector3.ZERO))
				prop.interact(game.player, Vector3.ZERO)
				print("r17_capture: took %s: owned %s" % [what, ws.call("owns", what)])
		var at2: Array = views["shrine"]
		game.player.global_position = room.to_global(at2[0]) - Vector3(0, 1.6, 0)
		for _i: int in 40:
			game.player.camera.global_position = room.to_global(at2[0])
			game.player.camera.look_at(room.to_global(at2[1]))
			await process_frame
		root.get_viewport().get_texture().get_image().save_png("%s/r17_%d_vigil_lit.png" % [out_dir, area_seed])
	quit()

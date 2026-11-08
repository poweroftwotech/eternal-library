extends SceneTree
## GPU pictures of the Orosi Scriptorium's hall (phase 17 step 2), walked as the
## Strata Board does it: the Grand Study test copy (drafts/grand_study/
## scriptorium_test), one boot per area seed. Needs a display, not --headless;
## run `godot --headless --import` first.
##   godot --path . --resolution 1920x1080 --script res://tests/r08_hall_capture.gd -- <out dir> [seed,seed,...] [draft]
## (draft: a file in gen/recipes/drafts/grand_study, default scriptorium_test;
## another adds its name after "scriptorium_" to the pictures, e.g. forgotten_)
## Writes r08_hall_<seed>_<view>.png and prints each seed's length and palette:
##   door    from the doorway, the whole hall and the glass
##   middle  halfway in, across the rugs to the glass
##   side    the west wall: its niches and the side door
##   up      up at the niche wall, the cornice and the timber ceiling
##   back    from under the glass back to the door

const DRAFT: String = "res://gen/recipes/drafts/grand_study/%s.tres"


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else "user://r08_hall"
	var seeds: PackedStringArray = (args[1] if args.size() > 1 else "1").split(",")
	var draft: String = args[2] if args.size() > 2 else "scriptorium_test"
	DirAccess.make_dir_recursive_absolute(out_dir)
	var ws: Node = root.get_node_or_null("/root/WorldState")
	for sd: String in seeds:
		ws.set("walk_area", "grand_study")
		ws.set("walk_recipe", DRAFT % draft)
		Area.seed_override = int(sd)
		var game: Node = load("res://main.tscn").instantiate()
		root.add_child(game)
		for _i: int in 3:
			await process_frame
		game.player.blocked = true
		game.player.set_physics_process(false)
		game.hud.toast_time = 0
		game.hud.visible = false
		game.stats.visible = false
		var streamer: Variant = game.world.get("streamer") if game.world != null else null
		for _i: int in 30:
			await process_frame
		while streamer != null and streamer.busy():
			await process_frame
		var oro: Node3D = null
		for n: Node in root.find_children("prop_orosi", "Node3D", true, false):
			oro = n as Node3D
		if oro == null:
			print("r08_hall_capture: seed %s: no orosi wall (the scriptorium didn't grow)" % sd)
			game.queue_free()
			await process_frame
			continue
		var w: Vector3 = oro.global_position
		var basis: Basis = oro.global_basis
		# Hall frame: x across (the wall's +X), back toward the door (the wall's +Z).
		var across: Vector3 = basis.x
		var into: Vector3 = basis.z
		var entry: Vector3 = game.player.global_position
		var length: float = (entry - w).dot(into)
		var rows: int = roundi(length / CellGrid.BAY)
		var cx: Vector3 = w + across * 6.0
		print("r08_hall_capture: seed %s: %d rows (%.1f m), palette %s" % [sd, rows, rows * CellGrid.BAY, oro.get_meta("palette", "?")])
		var far: Vector3 = cx
		var near: Vector3 = cx + into * (rows * CellGrid.BAY)
		var views: Array = [
			["door", near - into * 0.8, far + Vector3(0, 2.6, 0), 70.0],
			["middle", cx + across * 2.6 + into * (rows * 2.0), cx - across * 1.0 + into * 1.5 + Vector3(0, 0.8, 0), 70.0],
			["side", near - into * 6.0 + across * 2.0, near - into * 6.0 - across * 6.0 + Vector3(0, 1.8, 0), 75.0],
			["up", near - into * (rows * 2.0) + across * 2.5, near - into * (rows * 2.0 - 2.0) - across * 6.0 + Vector3(0, 5.2, 0), 75.0],
			["back", far + into * 1.2, near + Vector3(0, 0.6, 0), 75.0],
		]
		# copyist: a kneeling figure close up, from the front-side (the desk side).
		var figs: Array[Node] = root.find_children("prop_copyist_*", "Node3D", true, false)
		if not figs.is_empty():
			var f: Node3D = figs[0] as Node3D
			var fp: Vector3 = f.global_position
			views.append(["copyist", fp - into * 1.6 + across * 1.2, fp + Vector3(0, 0.6, 0), 60.0])
		# far: the last row's aisle-side desk close up (step 4: under dust).
		var last: Node3D = null
		for n: Node in root.find_children("prop_desk_*_w1", "Node3D", true, false):
			if last == null or String(n.name) > String(last.name):
				last = n as Node3D
		if last != null:
			var dp: Vector3 = last.global_position - into * 0.6
			views.append(["far", dp + across * 1.4 + into * 1.0, dp + Vector3(0, 0.2, 0), 60.0])
		for v: Array in views:
			game.player.teleport(v[1] + Vector3(0, 0.05, 0))
			game.player.camera.fov = v[3]
			game.look_toward(v[2])
			for _i: int in 90:
				await process_frame
			var tag: String = "" if draft == "scriptorium_test" else draft.trim_prefix("scriptorium_") + "_"
			var path: String = out_dir.path_join("r08_hall_%s%s_%s.png" % [tag, sd, v[0]])
			root.get_viewport().get_texture().get_image().save_png(path)
			print("r08_hall_capture: ", path)
		game.queue_free()
		for _i: int in 3:
			await process_frame
	quit()

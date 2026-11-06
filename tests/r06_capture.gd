extends SceneTree
## GPU pictures of the R06 Domicile Quarter (phase 14) in the real game, on the
## Mahaleh's test copy (gen/recipes/drafts/mahaleh/quarter_test.tres,
## tools/make_r06_draft.gd). Needs a display, not --headless; run
## `godot --headless --import` first.
##   godot --audio-driver Dummy --path . --resolution 1920x1080 --script res://tests/r06_capture.gd -- <out dir> [area seed]
## Walks to each quarter of the seed (rooms stream in on the way) and writes
## r06_<seed>_<layout>_<view>.png:
##   entry     just inside the entry door, up the lane
##   mouth     where the lanes begin, on toward the landmark
##   landmark  on the lane about 12 m from the landmark, at it
##   far       at the far door, back over the roofs
##   arm       at the end of the side door's lane, back at the landmark
##   smoke     from above the roofs where the lanes begin, at the first chimney
##   home<n>_<kind>_in, _out  each home, door open: from behind the door to the
##             back wall, and from the lane at the door
## Each home is also walked with the player's capsule, door open, lane to back.
## and prints each plan from above. --draft=<name> takes another copy of the
## recipe, such as quarter_deserted. Also opens a note and checks the hearths.

const DRAFT: String = "res://gen/recipes/drafts/mahaleh/%s.tres"


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var args: PackedStringArray = []
	var draft: String = "quarter_test"
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--draft="):
			draft = a.trim_prefix("--draft=")
		elif not a.begins_with("--"):
			args.append(a)
	var out_dir: String = args[0] if args.size() > 0 else "user://r06"
	var area_seed: int = int(args[1]) if args.size() > 1 else 1
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
	var vp_rid: RID = root.get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp_rid, true)
	for plan: AreaPlan.Room in area.plan.rooms:
		if not plan.slot_id.begins_with("quarter_"):
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
		var side: Array = (meta["arms"] as Array)[0]
		var mark: Vector3 = meta["landmark"]
		var kind: String = meta["layout"]
		var eye := Vector3(0, 1.6, 0)
		var look: Vector3 = mark + Vector3(0, {"hauz": 0.6, "wind": 11.0}.get(kind, 6.0), 0)
		# The lane point about 12 m off: far enough to see it whole.
		var near: Vector3 = route[0]
		for p: Vector3 in route + side:
			if p.y < 1.0 and absf((p - mark).length() - 12.0) < absf((near - mark).length() - 12.0):
				near = p
		var views: Dictionary = {
			"entry": [route[1] + eye, route[3] + eye],
			"mouth": [route[int(meta["alley"]) + 1] + eye, look],
			"landmark": [near + eye, look],
			"far": [route[route.size() - 2] + eye, mark + Vector3(0, 8.0 if kind != "hauz" else 1.0, 0)],
			"arm": [side[side.size() - 2] + eye, look],
		}
		if not (meta["smoke"] as Array).is_empty():
			views["smoke"] = [(route[int(meta["alley"]) + 1] as Vector3) + Vector3(0, 13.0, 0), (meta["smoke"] as Array)[0] + Vector3(0, 1.5, 0)]
		for d: Node in room.find_children("*", "", true, false):
			if d is HomeDoor:
				(d as HomeDoor).set_open(true, true)
		await physics_frame
		await physics_frame
		var n: int = 0
		for h: Dictionary in meta["homes"]:
			views["home%d_%s_in" % [n, h["kind"]]] = [(h["front"] as Vector3) + eye, (h["back"] as Vector3) + Vector3(0, 1.1, 0)]
			views["home%d_%s_out" % [n, h["kind"]]] = [(h["door"] as Vector3) + eye, (h["inside"] as Vector3) + Vector3(0, 1.2, 0)]
			print("r06_capture: home %d %s %s: %s" % [n, h["kind"], "two rooms" if h["deep"] else "one room", _walk(game.player, room, h["walk"])])
			n += 1
		print("  emitters: ", room.find_children("*", "GPUParticles3D", true, false).size())
		var lit: int = 0
		for l: Node in room.find_children("*", "Light3D", true, false):
			if (l as Light3D).light_energy > 0.0:
				lit += 1
		var notes: Array = room.find_children("*", "HomeNote", false, false)
		for nn: Node in room.find_children("*", "", true, false):
			if nn is HomeNote:
				notes.append(nn)
		var pots: int = 0
		for nn: Node in room.find_children("*", "", true, false):
			if nn is NicheThing and (nn as NicheThing).kind == "pot":
				pots += 1
		var opened: String = "no note here"
		if not notes.is_empty():
			(notes[0] as HomeNote).interact(game.player, Vector3.ZERO)
			opened = "note opens: %s" % (game.modal_context == "book")
			game.close_panel()
			game.player.blocked = true
		print("r06_capture: %d notes (%s), %d working hearths, %d people outdoors" % [notes.size(), opened, pots, meta["people"]])
		print("r06_capture: seed %d %s (%s, off %s), %d modules, %d lights" % [area_seed, plan.slot_id, kind, plan.parent, room.modules.size(), lit])
		var depth: int = QuarterGrammar.DEPTH + int(meta["alley"])
		for z: int in range(depth - 1, -1, -1):
			var row: String = ""
			for x: int in range(-QuarterGrammar.HALF, QuarterGrammar.HALF + 1):
				var c0: Dictionary = plan.grid.cells.get(Vector3i(x, 0, z), {})
				var c1: Dictionary = plan.grid.cells.get(Vector3i(x, 1, z), {})
				row += " " if c0.is_empty() else ("." if not c0.get("no_map", false) or not c1.get("no_map", false) else "#")
			print("  ", row)
		for view: String in views:
			var v: Array = views[view]
			game.player.global_position = room.to_global(v[0]) - Vector3(0, game.player.camera.position.y, 0)
			game.look_toward(room.to_global(v[1]))
			for _i: int in 90:
				await process_frame
			await RenderingServer.frame_post_draw
			root.get_viewport().get_texture().get_image().save_png("%s/r06_%d_%s_%s.png" % [out_dir, area_seed, kind, view])
	quit()


## Pushes the player's capsule along the points; says where it stops, if it does.
func _walk(player: CharacterBody3D, room: Node3D, points: Array) -> String:
	var params := PhysicsTestMotionParameters3D.new()
	var lift := Vector3(0, 0.2, 0)
	for i: int in points.size() - 1:
		var a: Vector3 = room.to_global(points[i]) + lift
		var b: Vector3 = room.to_global(points[i + 1]) + lift
		var steps: int = ceili(a.distance_to(b) / 0.25)
		for s: int in steps:
			params.from = Transform3D(Basis(), a.lerp(b, float(s) / steps))
			params.motion = (b - a) / steps
			if PhysicsServer3D.body_test_motion(player.get_rid(), params):
				return "BLOCKED on leg %d, step %d of %d" % [i, s, steps]
	return "walks in"

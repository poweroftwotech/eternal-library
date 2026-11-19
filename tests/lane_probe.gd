extends SceneTree
## What the residents' test lane is made of (phase 21): its homes and the
## things in them, as the built room has them. Headless.
##   godot --headless --audio-driver Dummy --path . --script res://tests/lane_probe.gd [-- seed]

const DRAFT: String = "res://gen/recipes/drafts/mahaleh/lane_test.tres"


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var area_seed: int = 1
	for a: String in OS.get_cmdline_user_args():
		area_seed = a.to_int()
	var ws: Node = root.get_node_or_null("/root/WorldState")
	ws.set("walk_area", "mahaleh")
	ws.set("walk_recipe", DRAFT)
	var main_script: GDScript = load("res://scripts/main.gd")
	main_script.room_override = "area:mahaleh"
	Area.seed_override = area_seed
	var game: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	current_scene = game
	game.player.blocked = true
	for _i: int in 30:
		await process_frame
	var area: Area = game.world
	while area.streamer.busy():
		await process_frame
	print("lane_probe: rooms %s, player at %s" % [area.rooms.keys(), (game.player.global_position as Vector3).snapped(Vector3.ONE * 0.1)])
	for slot: String in area.rooms:
		var room: Node3D = area.rooms[slot]
		var plan: AreaPlan.Room = null
		for q: AreaPlan.Room in area.plan.rooms:
			if q.slot_id == slot:
				plan = q
		var homes: Array = plan.grid.meta.get("homes", [])
		print("  %s (%s): %d homes, %d children" % [slot, room.get_class(), homes.size(), room.get_child_count()])
		for i: int in homes.size():
			var h: Dictionary = homes[i]
			print("  home %d: %s deep=%s door %s inside %s" % [i, h["kind"], h["deep"], (room.to_global(h["door"]) as Vector3).snapped(Vector3.ONE * 0.1),
					(room.to_global(h["inside"]) as Vector3).snapped(Vector3.ONE * 0.1)])
		var shown: int = 0
		for n: Node in room.find_children("*", "Node3D", true, false):
			var name: String = n.name
			if (name.begins_with("prop_qt_item_") or name.begins_with("prop_qt_home") or name.contains("hauz") or name.contains("fig")) and shown < 70:
				shown += 1
				var n3 := n as Node3D
				print("    %s  [%s]  %s  at %s yaw %d  groups %s" % [name, n.get_class(), n.scene_file_path.get_file(), n3.global_position.snapped(Vector3.ONE * 0.01),
						int(rad_to_deg(n3.global_rotation.y)), n.get_groups()])
		# The lights of the first lived-in home, and what stands round each.
		for i: int in homes.size():
			if homes[i]["kind"] != "family":
				continue
			var inside: Vector3 = room.to_global(homes[i]["inside"])
			for n: Node in room.find_children("*", "Light3D", true, false):
				var light := n as Light3D
				if light.global_position.distance_to(inside) > 5.0:
					continue
				var parent: Node = light.get_parent()
				print("    light %s (energy %.2f, meta %s) under %s [%s]: siblings %s" % [room.get_path_to(light), light.light_energy, light.get_meta_list(),
						parent.name, parent.scene_file_path.get_file(), parent.get_children().map(func(c: Node) -> String: return "%s:%s" % [c.name, c.get_class()])])
	main_script.room_override = ""
	quit()

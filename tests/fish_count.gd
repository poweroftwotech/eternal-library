extends SceneTree
## Where the fish are, place by place (headless):
##   godot --headless --path . --audio-driver Dummy --script res://tests/fish_count.gd -- [place ...]
## place: camp, area:<id>, zoo. Prints each room's goldfish and cave barbs,
## which pools were sounded by sight, and the worst tick and placing frame.

func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var places: PackedStringArray = []
	for a: String in OS.get_cmdline_user_args():
		if not a.begins_with("--"):
			places.append(a)
	if places.is_empty():
		places = ["camp", "area:gorge", "area:mahaleh", "area:grand_study", "zoo"]
	var main_script: GDScript = load("res://scripts/main.gd")
	for place: String in places:
		main_script.room_override = ZooRoom.SCENE if place == "zoo" else place
		var game: Node = (load("res://main.tscn") as PackedScene).instantiate()
		root.add_child(game)
		game.player.blocked = true
		for i: int in 30:
			await process_frame
		var area: Area = game.world as Area
		var f: Fauna = area.fauna if area != null else game.world.get_node("Fauna")
		var stops: Array = [null]
		if area != null:
			stops = area.plan.rooms
		for r: Variant in stops:
			if r != null and not (r as AreaPlan.Room).floor_cells.is_empty():
				game.player.teleport(area.global_transform * CellGrid.cell_centre((r as AreaPlan.Room).floor_cells.keys()[0]))
			for i: int in 3000:
				await process_frame
				if i > 60 and (area == null or area.streamer == null or not area.streamer.busy()) and f._jobs.is_empty():
					break
		var kinds: Dictionary = {}
		var sight: int = 0
		for slot: String in f.groups:
			for g: Node in f.groups[slot]:
				if is_instance_valid(g) and str(g.get("def").id) in ["goldfish", "cave_barb"]:
					var k: String = (slot if slot != "" else place) + ":" + str(g.get("def").id)
					kinds[k] = int(kinds.get(k, 0)) + (g as MultiMeshInstance3D).multimesh.instance_count
					if (g.get("body") as WaterBody).by_sight:
						sight += 1
		print("fish_count: %s %s; %d groups in pools sounded by sight; tick worst %.2f ms, placing worst %.2f ms" % [place, kinds, sight, f.stats["worst_tick_ms"], f.stats["worst_scan_ms"]])
		game.queue_free()
		for i: int in 5:
			await process_frame
	main_script.room_override = ""
	quit()

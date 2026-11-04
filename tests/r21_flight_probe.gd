extends SceneTree
## Phase 12: what you stand on along the Bridge Hall's deck and flight. Loads
## the Lower Stacks' test copy at an area seed, then rays down from 1 m over
## each walk point (the deck bays and the flight's two halves) and prints the
## collider hit and how far under the walk point it is. A flight must hit
## its own steps, never the TempSafetyFloor.
##   godot --headless --path . --script res://tests/r21_flight_probe.gd -- [area seed]

const DRAFT: String = "res://gen/recipes/drafts/lower_stacks/bridge_hall_test.tres"


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var area_seed: int = int(args[0]) if args.size() > 0 else 2
	var ws: Node = root.get_node_or_null("/root/WorldState")
	ws.set("walk_area", "lower_stacks")
	ws.set("walk_recipe", DRAFT)
	var main_script: GDScript = load("res://scripts/main.gd")
	main_script.room_override = "area:lower_stacks"
	Area.seed_override = area_seed
	var game: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	game.player.blocked = true
	game.player.set_physics_process(false)
	var area: Area = game.world
	var plan: AreaPlan.Room = area.plan.room("bridge_1")
	if plan == null:
		print("r21_flight_probe: seed %d has no bridge hall" % area_seed)
		quit(1)
		return
	for p: Vector3 in AreaTour.leg(area.plan, plan):
		game.player.global_position = area.to_global(p) + Vector3(0, 0.05, 0)
		for _i: int in 6:
			await process_frame
		while area.streamer.busy():
			await process_frame
	for _i: int in 4:
		await physics_frame
	var room: GeneratedRoom = area.rooms.get(plan.slot_id)
	var bridge: BridgeHallBridge = room.find_children("*", "BridgeHallBridge", true, false)[0]
	var b: Dictionary = room.grid.meta["bridge"]
	var walk: Array = BridgeHallBridge.plan(int(b["bays"]), int(b.get("rise", 0)))["walk"]
	var space: PhysicsDirectSpaceState3D = bridge.get_world_3d().direct_space_state
	var bad: int = 0
	print("r21_flight_probe: seed %d, %d bays, rise %d" % [area_seed, int(b["bays"]), int(b.get("rise", 0))])
	for w: Vector3 in walk:
		var at: Vector3 = bridge.global_transform * w
		var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP, at + Vector3.DOWN * 12.0)
		var hit: Dictionary = space.intersect_ray(q)
		var what: String = "nothing"
		var under: float = INF
		if not hit.is_empty():
			var c: Node = hit["collider"]
			what = String(c.get_parent().name) + "/" + String(c.name)
			under = at.y - (hit["position"] as Vector3).y
		var ok: bool = absf(under) < 0.6 and not what.contains("TempSafetyFloor")
		if not ok:
			bad += 1
		print("  walk (%.1f, %.1f, %.1f): %s, %.2f m under %s" % [w.x, w.y, w.z, what, under, "" if ok else "  <- WRONG"])
	print("r21_flight_probe: %s" % ("pass" if bad == 0 else "%d wrong" % bad))
	main_script.room_override = ""
	Area.seed_override = -1
	quit(1 if bad > 0 else 0)

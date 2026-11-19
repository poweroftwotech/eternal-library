extends SceneTree
## The test lane's walking surface as a picture in text (phase 21 step 3): a
## character per half metre, '.' where a person can walk, with the doors (D),
## the homes' insides (0-3), the hauz (H) and anything asked for marked.
## Headless:
##   godot --headless --audio-driver Dummy --path . --script res://tests/lane_floor_probe.gd

const DRAFT: String = "res://gen/recipes/drafts/mahaleh/lane_test.tres"
const STEP: float = 0.5


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var ws: Node = root.get_node_or_null("/root/WorldState")
	ws.set("walk_area", "mahaleh")
	ws.set("walk_recipe", DRAFT)
	var main_script: GDScript = load("res://scripts/main.gd")
	main_script.room_override = "area:mahaleh"
	Area.seed_override = 1
	var game: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	current_scene = game
	game.player.blocked = true
	for _i: int in 30:
		await process_frame
	var area: Area = game.world
	while area.streamer.busy():
		await process_frame
	var residents: Residents = get_first_node_in_group(Residents.GROUP) as Residents
	var room: Node3D = area.rooms["entrance"]
	for _i: int in 600:
		await process_frame
		if residents.ways.ready_for(room):
			break
	var ways: WalkMap = residents.ways
	print("lane_floor_probe: surface ready %s, room at %s; reading the room %.1f ms (main thread), bake %.0f ms (off it)" % [ways.ready_for(room), room.global_position, ways.last_read_ms, ways.last_bake_ms])
	var marks: Dictionary = {}
	var plan: AreaPlan.Room = area.plan.rooms[0]
	var homes: Array = plan.grid.meta.get("homes", [])
	for i: int in homes.size():
		marks[_key(room.to_global(homes[i]["door"]))] = "D"
		marks[_key(room.to_global(homes[i]["inside"]))] = str(i)
	for n: Node in room.find_children("prop_qt_hauz", "Node3D", true, false):
		var box: AABB = SpotTable.box_of(n as Node3D)
		print("  hauz box %s size %s" % [box.position.snapped(Vector3.ONE * 0.01), box.size.snapped(Vector3.ONE * 0.01)])
		marks[_key(box.get_center())] = "H"
	for s: Dictionary in residents.commons:
		marks[_key(s["at"])] = str(s["kind"]).substr(0, 1).to_upper()
		print("  common spot %s at %s yaw %d pose %s" % [s["kind"], (s["at"] as Vector3).snapped(Vector3.ONE * 0.01), int(rad_to_deg(float(s["yaw"]))), s["pose"]])
	marks[_key(game.player.global_position)] = "P"
	for z: int in range(-64, 6):
		var line: String = ""
		for x: int in range(-32, 33):
			var p := Vector3(x * STEP, 0.1, z * STEP)
			var k := Vector2i(x, z)
			line += str(marks[k]) if marks.has(k) else ("." if ways.on(p, 0.1) else " ")
		if line.strip_edges() != "":
			print("%6.1f |%s" % [z * STEP, line])
	print("        x from -16 to 16")
	for h: Dictionary in residents.households:
		for m: Resident in h["members"]:
			print("  %s (%s, home %d): bed %s, at %s" % [m.given_name, m.trade, h["index"], not m.bed.is_empty(), m.global_position.snapped(Vector3.ONE * 0.01)])
	main_script.room_override = ""
	quit()


static func _key(p: Vector3) -> Vector2i:
	return Vector2i(roundi(p.x / STEP), roundi(p.z / STEP))

extends SceneTree
## Phase 3 step 2 persistence gate (ENVIRONMENT_PLAN.md 6.5.7): the real game
## (main.tscn) in R01 + the stack gallery, saved in one OS process and restored
## in a fresh one. Run the three modes in order (tests/persist_gate.sh does):
##   godot --headless --path . --script res://tests/persist_test.gd -- save --save=user://test/persist.json --fresh --gen-seed=7
##   godot --headless --path . --script res://tests/persist_test.gd -- load --save=user://test/persist.json
##   godot --headless --path . --script res://tests/persist_test.gd -- reverted --save=user://test/persist.json
## save:     knock the west vase over, break the east one, push a table prop
##           off, add one delta that matches nothing (a stale id), move the
##           player; quit through the game's own save-and-quit.
## load:     a new process resumes the same scene, seed and pose; every change
##           is where it was saved (1 cm, 1 degree), nothing wakes; the stale id
##           is kept but not applied. Then the janitor hook (revert_room) puts
##           everything back in place, and the game saves and quits.
## reverted: a third process finds no changes left and everything original.

var main_script: GDScript = load("res://scripts/main.gd")
const STACK_GALLERY: String = "res://rooms/test/reading_room_r02.tscn"
const EXPECT: String = "user://test/persist_expect.json"
const STALE_ID: String = "reading_room@1/Props/NoSuchVase"
const POSE := Vector3(6.0, 0.05, -10.0)
const POSE_YAW: float = 1.0

var failures: PackedStringArray = []
var checks: int = 0
var game: Node
var room: RoomTemplate
var ws: Node


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures.append(what)


func run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var mode: String = args[0] if args.size() > 0 else "save"
	ws = root.get_node_or_null("WorldState")
	check(ws != null, "the WorldState autoload is there")
	if ws == null:
		finish(mode, false)
		return
	if mode == "save":
		main_script.room_override = STACK_GALLERY
	game = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	for _i: int in 12:
		await physics_frame
	room = game.world as RoomTemplate
	match mode:
		"save":
			await save_mode()
		"load":
			await load_mode()
		"reverted":
			await reverted_mode()
	finish(mode, true)


func finish(mode: String, through_game: bool) -> void:
	print("persist_test %s: %d checks, %d failures" % [mode, checks, failures.size()])
	for f: String in failures:
		print("  FAIL ", f)
	if failures.is_empty() and through_game and mode != "reverted":
		game.save_and_quit()     # the game's own quit path writes the save
	else:
		quit(1 if not failures.is_empty() else 0)


func room_xf(n: Node3D) -> Transform3D:
	return room.global_transform.affine_inverse() * n.global_transform


func near(a: Transform3D, b: Transform3D) -> bool:
	return a.origin.distance_to(b.origin) < 0.01 and rad_to_deg(a.basis.get_rotation_quaternion().angle_to(b.basis.get_rotation_quaternion())) < 1.0


func first_table_prop() -> WorldProp:
	var props: Array[Node] = room.get_node("Dressing/table_reading").find_children("*", "WorldProp", true, false)
	return null if props.is_empty() else props[0] as WorldProp


func prop_by_id(id: String) -> WorldProp:
	for p: WorldProp in room.world_props():
		if p.get_meta("world_id", "") == id:
			return p
	return null


func wait_still(limit: int = 900) -> void:
	for _i: int in limit:
		await physics_frame
		if WorldProp.awake_props.is_empty() and room.room_shards().all(func(s: Shards) -> bool: return s.all_frozen):
			break


func save_mode() -> void:
	var west: WorldProp = room.get_node("Props/VaseIwanWest")
	var east: WorldProp = room.get_node("Props/VaseIwanEast")
	var table: WorldProp = first_table_prop()
	check(table != null, "a reading table has props")
	var west_id: String = west.get_meta("world_id", "")
	var east_id: String = east.get_meta("world_id", "")
	check(west_id == "reading_room@1/Props/VaseIwanWest", "the west vase's save id (%s)" % west_id)
	check(room.room_key() == "reading_room@1", "R01's room key is reading_room@1 (%s)" % room.room_key())
	await physics_frame
	var table_id: String = table.get_meta("world_id", "")
	check(table_id.begins_with("reading_room@1/Dressing/table_reading/") and table_id.contains("SOCKET_table_props#"), "a table prop's id is its socket path and spawn number (%s)" % table_id)
	var table_orig: Transform3D = room_xf(table)
	# West: E knocks it over. East: dropped, it breaks. Table: pushed off.
	game.player.teleport(Vector3(2.2, 0.05, -15.0), 0.0, -0.62)
	for _i: int in 3:
		await physics_frame
	game.interact(west)
	east.global_position += Vector3(0, 1.4, 0)
	east.wake()
	table.push(Vector3(-4.0, 0, 0) * table.mass, table.global_position + Vector3(0.05, 0.08, 0))
	await wait_still()
	check(str(ws.call("delta", west_id).get("s", "")) == "moved", "the knocked-over vase is saved as moved")
	check(str(ws.call("delta", east_id).get("s", "")) == "broken", "the broken vase is saved as broken")
	check(str(ws.call("delta", table_id).get("s", "")) == "moved", "the pushed table prop is saved as moved")
	var d: Dictionary = ws.call("delta", west_id)
	check(near(WorldStateData.xf(d.get("orig")), Transform3D(Basis(), Vector3(2.2, 0, -16.6))), "the delta remembers the vase's original place")
	ws.call("set_delta", STALE_ID, {"s": "moved", "xf": WorldStateData.arr(Transform3D()), "orig": WorldStateData.arr(Transform3D())})
	game.player.teleport(POSE, POSE_YAW)
	await physics_frame
	var shards: Array[Shards] = room.room_shards()
	check(shards.size() == 1, "one shard pile in the room (%d)" % shards.size())
	var expect: Dictionary = {
		"west": WorldStateData.arr(room_xf(west)), "west_id": west_id, "east_id": east_id,
		"shards": shards[0].pieces.map(func(b: RigidBody3D) -> Array: return WorldStateData.arr(room_xf(b))) if shards.size() == 1 else [],
		"table": WorldStateData.arr(room_xf(table)), "table_orig": WorldStateData.arr(table_orig), "table_id": table_id}
	DirAccess.make_dir_recursive_absolute("user://test")
	var f: FileAccess = FileAccess.open(EXPECT, FileAccess.WRITE)
	f.store_string(JSON.stringify(expect))
	f.close()


func load_mode() -> void:
	var expect: Variant = JSON.parse_string(FileAccess.get_file_as_string(EXPECT))
	check(expect is Dictionary, "the save run left its expectations")
	if not expect is Dictionary:
		return
	check(ws.get("loaded") == true, "the save file was read at start")
	check(game.scene_path == STACK_GALLERY, "the game resumes the saved scene (%s)" % game.scene_path)
	var g: GeneratedRoom = room.get_node_or_null("StackGallery")
	check(g != null and g.effective_seed() == 7, "and the saved gallery seed (%s)" % (g.effective_seed() if g != null else -1))
	check(Vector2(game.player.global_position.x - POSE.x, game.player.global_position.z - POSE.z).length() < 0.05 and absf(game.player.rotation.y - POSE_YAW) < 0.01,
		"and the player's place (%s)" % game.player.global_position)
	var west: WorldProp = room.get_node_or_null("Props/VaseIwanWest")
	check(west != null and west.freeze and near(room_xf(west), WorldStateData.xf(expect["west"])), "the west vase lies where it was knocked over")
	check(room.get_node_or_null("Props/VaseIwanEast") == null, "the east vase is gone")
	var shards: Array[Shards] = room.room_shards()
	var pieces_ok: bool = shards.size() == 1 and shards[0].pieces.size() == (expect["shards"] as Array).size()
	if pieces_ok:
		for i: int in shards[0].pieces.size():
			pieces_ok = pieces_ok and near(room_xf(shards[0].pieces[i]), WorldStateData.xf(expect["shards"][i])) and shards[0].pieces[i].freeze
	check(pieces_ok, "its %d shards lie where they fell, frozen" % (expect["shards"] as Array).size())
	var table: WorldProp = prop_by_id(expect["table_id"])
	check(table != null and near(room_xf(table), WorldStateData.xf(expect["table"])), "the table prop is where it was pushed")
	var stale: PackedStringArray = ws.call("stale_ids")
	check(stale == PackedStringArray([STALE_ID]), "only the planted id is stale, kept but not applied (%s)" % [stale])
	var before: Array = room.world_props().map(func(p: WorldProp) -> Transform3D: return p.global_transform)
	for _i: int in 120:
		await physics_frame
	var after: Array = room.world_props().map(func(p: WorldProp) -> Transform3D: return p.global_transform)
	check(WorldProp.awake_props.is_empty() and before == after, "nothing restored wakes, falls or jitters")
	if table != null:
		check(near(room_xf(table), WorldStateData.xf(expect["table"])), "the table socket's settle leaves the restored prop alone")

	# The janitor hook: put everything in R01 back as it was.
	var reverted: Array[String] = []
	ws.connect("reverted", func(id: String) -> void: reverted.append(id))
	var n: int = ws.call("revert_room", "reading_room@1")
	await physics_frame
	await physics_frame
	check(n == 4 and reverted.size() == 4, "revert_room puts back all 4 changes (%d, signals %d)" % [n, reverted.size()])
	west = room.get_node_or_null("Props/VaseIwanWest")
	check(west != null and west.freeze and near(room_xf(west), Transform3D(Basis(), Vector3(2.2, 0, -16.6))), "the west vase stands where it was placed")
	var east: WorldProp = room.get_node_or_null("Props/VaseIwanEast")
	check(east != null and east.breakable and near(room_xf(east), Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(9.8, 0, -16.6))), "the east vase is whole again, in its place (%s)" % (room_xf(east) if east != null else "missing"))
	check(room.room_shards().is_empty(), "its shards are gone")
	table = prop_by_id(expect["table_id"])
	check(table != null and near(room_xf(table), WorldStateData.xf(expect["table_orig"])), "the table prop is back on the table")
	check((ws.call("changed_ids", "") as PackedStringArray).is_empty(), "no changes are left in the save")
	if east != null:
		east.wake()     # the new vase is tracked: a nudge that changes nothing leaves no delta
		await wait_still()
		check((ws.call("changed_ids", "") as PackedStringArray).is_empty(), "a reverted prop that settles in place adds no delta")


func reverted_mode() -> void:
	var expect: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(EXPECT))
	check((ws.call("changed_ids", "") as PackedStringArray).is_empty(), "after a restart the save holds no changes")
	var west: WorldProp = room.get_node_or_null("Props/VaseIwanWest")
	var east: WorldProp = room.get_node_or_null("Props/VaseIwanEast")
	check(west != null and near(room_xf(west), Transform3D(Basis(), Vector3(2.2, 0, -16.6))), "the west vase stands in its place")
	check(east != null and room.room_shards().is_empty(), "the east vase is whole, no shards")
	for _i: int in 3:
		await physics_frame
	var table: WorldProp = prop_by_id(expect["table_id"])
	check(table != null and near(room_xf(table), WorldStateData.xf(expect["table_orig"])), "the table prop is on the table")

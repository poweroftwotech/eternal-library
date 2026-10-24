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
## age, age_again: the years (phase 3 step 4, below).
## area_save, area_load: the library wing (phase-4-design.md 8.1.8 step 4), or
##           with --area-id=lower_stacks the Lower Stacks (phase-5-design.md 5.6.9),
##           in their own save file; see area_save_mode.

var main_script: GDScript = load("res://scripts/main.gd")
const STACK_GALLERY: String = "res://rooms/test/reading_room_r02.tscn"
const EXPECT: String = "user://test/persist_expect.json"
const STALE_ID: String = "reading_room@1/Props/NoSuchVase"
const LORE_SOCKET: String = "Shell/wall_shelfbay_4m/Mesh/M_wall_shelfbay_4m/SOCKET_recess_fill"
const LORE_ID: String = "reading_room@1/" + LORE_SOCKET + "#lore:lore_hollow_index"
const POSE := Vector3(6.0, 0.05, -10.0)
const POSE_YAW: float = 1.0

var failures: PackedStringArray = []
var checks: int = 0
var game: Node
var room: RoomTemplate
var ws: Node
## The area in the area modes (room is then its root, R01, or the first room
## with shelves: the Lower Stacks' hall at the caravanserai's gate).
var area: Area


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
	elif mode == "area_save":
		main_script.room_override = "area:" + area_id()
	game = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	for _i: int in 12:
		await physics_frame
	room = game.world as RoomTemplate
	if game.world is Area:
		area = game.world as Area
		room = area.rooms.get(area.plan.rooms[0].slot_id)
		# The Lower Stacks' root is the caravanserai (phase 5 step 5), with no
		# shelves: the root's change goes in the first live room that has some
		# (the hall at its gate).
		if room != null and room.get_node_or_null("Props/VaseIwanWest") == null and room.find_children("*", "ShelfFill", true, false).is_empty():
			for r: AreaPlan.Room in area.plan.rooms:
				var live: RoomTemplate = area.rooms.get(r.slot_id)
				if live != null and not live.find_children("*", "ShelfFill", true, false).is_empty():
					room = live
					break
	match mode:
		"save":
			await save_mode()
		"load":
			await load_mode()
		"reverted":
			await reverted_mode()
		"age":
			await age_mode()
		"age_again":
			await age_again_mode()
		"area_save":
			await area_save_mode()
		"area_load":
			await area_load_mode()
	finish(mode, true)


func finish(mode: String, through_game: bool) -> void:
	print("persist_test %s: %d checks, %d failures" % [mode, checks, failures.size()])
	for f: String in failures:
		print("  FAIL ", f)
	if failures.is_empty() and through_game and mode != "age_again":
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
	# Step 3: pull the Hollow Index and take it; pull a gallery book off onto the floor.
	var fill: ShelfFill = fill_of(room, LORE_SOCKET)
	var li: int = fill.lore_index.get(&"lore_hollow_index", -1) if fill != null else -1
	check(li >= 0, "the entrance recess holds the lore book")
	if li >= 0:
		var lore: WorldProp = fill.pull(li)
		for _i: int in 30:
			await physics_frame
		game.interact(lore)
	check(ws.call("owns", &"lore_hollow_index") and str(ws.call("delta", LORE_ID).get("s", "")) == "taken", "the lore book is in the satchel and saved as taken")
	var g: GeneratedRoom = room.get_node("StackGallery")
	var dropped: Dictionary = await drop_a_book(g)
	var gbook_id: String = dropped.get("id", "")
	var gbook_xf: Array = dropped.get("xf", [])
	check(gbook_id.begins_with("stack_gallery_west@7/") and str(ws.call("delta", gbook_id).get("s", "")) == "moved", "the gallery book is saved, in the gallery's own room (%s)" % gbook_id)
	game.player.teleport(POSE, POSE_YAW)
	await physics_frame
	var shards: Array[Shards] = room.room_shards()
	check(shards.size() == 1, "one shard pile in the room (%d)" % shards.size())
	var expect: Dictionary = {
		"west": WorldStateData.arr(room_xf(west)), "west_id": west_id, "east_id": east_id,
		"shards": shards[0].pieces.map(func(b: RigidBody3D) -> Array: return WorldStateData.arr(room_xf(b))) if shards.size() == 1 else [],
		"table": WorldStateData.arr(room_xf(table)), "table_orig": WorldStateData.arr(table_orig), "table_id": table_id,
		"lore_index": li, "gbook_id": gbook_id, "gbook_xf": gbook_xf}
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
	# Step 3: the lore book stays taken and readable; the gallery book stays on the floor.
	var fill: ShelfFill = fill_of(room, LORE_SOCKET)
	check(fill != null and fill.hidden.has(int(expect["lore_index"])), "the lore book's slot is empty")
	check(fill != null and fill.book_at(fill.to_global(fill.built_transforms[int(expect["lore_index"])].origin)) != int(expect["lore_index"]), "and it can't be pulled again")
	check(ws.call("owns", &"lore_hollow_index"), "it is still in the satchel")
	game.show_book(&"lore_hollow_index")
	check(game.modal_context == "book" and game.hud.modal_open, "and Read opens it")
	game.close_panel()
	var gbook: WorldProp = null
	for p: WorldProp in g.world_props():
		if p.get_meta("world_id", "") == expect["gbook_id"]:
			gbook = p
	check(gbook != null and near(g.global_transform.affine_inverse() * gbook.global_transform, WorldStateData.xf(expect["gbook_xf"])), "the gallery book lies where it fell")
	check(gbook != null and (gbook.get_parent() as ShelfFill).hidden.has(int(gbook.get_meta("shelf_index"))), "and its shelf slot is empty")
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
	check(n == 4 and reverted.size() == 4, "revert_room puts back the 4 changes it can; the taken lore book stays taken (%d, signals %d)" % [n, reverted.size()])
	west = room.get_node_or_null("Props/VaseIwanWest")
	check(west != null and west.freeze and near(room_xf(west), Transform3D(Basis(), Vector3(2.2, 0, -16.6))), "the west vase stands where it was placed")
	var east: WorldProp = room.get_node_or_null("Props/VaseIwanEast")
	check(east != null and east.breakable and near(room_xf(east), Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(9.8, 0, -16.6))), "the east vase is whole again, in its place (%s)" % (room_xf(east) if east != null else "missing"))
	check(room.room_shards().is_empty(), "its shards are gone")
	table = prop_by_id(expect["table_id"])
	check(table != null and near(room_xf(table), WorldStateData.xf(expect["table_orig"])), "the table prop is back on the table")
	check(ws.call("changed_ids", "") == PackedStringArray([LORE_ID, expect["gbook_id"]]) or ws.call("changed_ids", "") == PackedStringArray([expect["gbook_id"], LORE_ID]), "left in the save: the taken lore book and the gallery book (%s)" % [ws.call("changed_ids", "")])
	if east != null:
		east.wake()     # the new vase is tracked: a nudge that changes nothing leaves no delta
		await wait_still()
		check((ws.call("changed_ids", "") as PackedStringArray).size() == 2, "a reverted prop that settles in place adds no delta")


func reverted_mode() -> void:
	var expect: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(EXPECT))
	check((ws.call("changed_ids", "reading_room@1") as PackedStringArray) == PackedStringArray([LORE_ID]), "after a restart R01 holds only the taken lore book")
	check(ws.call("owns", &"lore_hollow_index") and (ws.call("changed_ids", "stack_gallery_west@7") as PackedStringArray).size() == 1, "the satchel still has it; the gallery book is still down")
	var west: WorldProp = room.get_node_or_null("Props/VaseIwanWest")
	var east: WorldProp = room.get_node_or_null("Props/VaseIwanEast")
	check(west != null and near(room_xf(west), Transform3D(Basis(), Vector3(2.2, 0, -16.6))), "the west vase stands in its place")
	check(east != null and room.room_shards().is_empty(), "the east vase is whole, no shards")
	for _i: int in 3:
		await physics_frame
	var table: WorldProp = prop_by_id(expect["table_id"])
	check(table != null and near(room_xf(table), WorldStateData.xf(expect["table_orig"])), "the table prop is on the table")
	await tend_and_record(expect)


## Pulls a book off a gallery shelf and knocks it onto the floor; returns
## {id, xf} (xf in the gallery's frame) once it lies still, or {}.
func drop_a_book(g: RoomTemplate) -> Dictionary:
	var gfill: ShelfFill = null
	var gi: int = -1
	for f: ShelfFill in g.shelf_fills():
		for i: int in f.built_transforms.size():
			if f.book_levels[i] == 1 and f.built_transforms[i].basis.x.length() > 0.01:
				gfill = f
				gi = i
				break
		if gfill != null:
			break
	check(gfill != null, "%s has a shelf with books" % g.room_key())
	if gfill == null:
		return {}
	var gbook: WorldProp = gfill.pull(gi)
	for _i: int in 30:
		await physics_frame
	var actor := Node3D.new()
	g.add_child(actor)
	actor.global_position = gfill.to_global(Vector3(0, 0, -1.6))
	gbook.interact(actor, gbook.global_position)
	await wait_still()
	actor.queue_free()
	check(gbook.global_position.y < g.global_position.y + 0.3, "%s: the book lies on the floor (%s)" % [g.room_key(), gbook.global_position])
	return {"id": gbook.get_meta("world_id", ""), "xf": WorldStateData.arr(g.global_transform.affine_inverse() * gbook.global_transform)}


func fill_of(r: RoomTemplate, socket_path: String) -> ShelfFill:
	var s := r.get_node_or_null(socket_path) as VariantSocket
	if s == null:
		return null
	for n: Node in s.spawned():
		if n is ShelfFill:
			return n as ShelfFill
	return null


# --- step 4: the years (ENVIRONMENT_PLAN.md 6.5.6) --------------------------------
const TENDED: String = "Lights/lantern_hanging3"     # over the west gallery


## Lamp sockets of R01 and the gallery: {"<room_key>/<socket path>": socket}.
func lamp_sockets() -> Dictionary:
	var out: Dictionary = {}
	for r: RoomTemplate in [room, room.get_node("StackGallery") as RoomTemplate]:
		for s: VariantSocket in r.sockets():
			if s.mode == VariantSocket.Mode.STATE and s.socket_set != null and s.socket_set.index_of("lit") >= 0:
				out[r.room_key() + "/" + r.socket_key(s)] = s
	return out


## Non-lamp socket picks of both rooms.
func other_picks() -> Dictionary:
	var out: Dictionary = {}
	for r: RoomTemplate in [room, room.get_node("StackGallery") as RoomTemplate]:
		for s: VariantSocket in r.sockets():
			if s.mode != VariantSocket.Mode.STATE:
				out[r.room_key() + "/" + r.socket_key(s)] = s.last_pick
	return out


## Third process: at year 0, tend the gallery lantern (E until it's lit), and
## record every lamp's year-0 step and the other sockets' picks.
func tend_and_record(expect: Dictionary) -> void:
	var lamps: Dictionary = lamp_sockets()
	var socket: VariantSocket = room.get_node(TENDED).find_children("SOCKET_lamp_state*", "VariantSocket", true, false).front()
	var tend: LampTend = socket.get_children(true).filter(func(c: Node) -> bool: return c is LampTend).front()
	# From the gallery floor below it, aim at the glass with the real ray.
	game.player.teleport(Vector3(1.0, 4.2, tend.global_position.z + 1.2), 0.0)
	for _i: int in 3:
		await physics_frame
	game.look_toward(tend.global_position)
	for _i: int in 3:
		await physics_frame
	check(game.player.get_target() == tend, "from the gallery, the ray finds the lantern (%s)" % game.player.get_target())
	for _i: int in 2:
		if not tend.is_lit():
			game.interact(tend)
	if not tend.is_lit():
		game.interact(tend)
	check(tend.is_lit() and str(ws.call("delta", "reading_room@1/" + room.socket_key(socket)).get("s", "")) == "state", "E lit it, and the save remembers the tended lamp")
	var base: Dictionary = {}
	for id: String in lamps:
		base[id] = ["lit", "failing", "dark"].find((lamps[id] as VariantSocket).picked_label())
	expect["tended"] = "reading_room@1/" + room.socket_key(socket)
	expect["lamps_year0"] = base
	expect["others"] = other_picks()
	var f: FileAccess = FileAccess.open(EXPECT, FileAccess.WRITE)
	f.store_string(JSON.stringify(expect))
	f.close()


## Fourth process, started with --advance-years=40.
func age_mode() -> void:
	var expect: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(EXPECT))
	check(absf(float(ws.call("years")) - 40.0) < 0.01, "40 years have passed (%.2f)" % float(ws.call("years")))
	var lamps: Dictionary = lamp_sockets()
	var base: Dictionary = expect.get("lamps_year0", {})
	var forward: bool = true
	var dark: int = 0
	var untouched: int = 0
	var states: Dictionary = {}
	for id: String in lamps:
		var label: String = (lamps[id] as VariantSocket).picked_label()
		states[id] = label
		if id == expect["tended"] or room.is_ageless(lamps[id]):
			continue
		untouched += 1
		forward = forward and ["lit", "failing", "dark"].find(label) >= int(base.get(id, 0))
		if label == "dark":
			dark += 1
	check(base.size() == lamps.size() and lamps.size() >= 10, "the same %d lamps as at year 0" % lamps.size())
	check(forward, "every untouched lamp is where it was or further along lit → failing → dark")
	check(dark * 2 >= untouched, "at least half the untouched lamps have gone dark (%d of %d)" % [dark, untouched])
	check(states.get(expect["tended"], "") == "lit", "the tended lamp is still lit")
	var chandeliers: Array = lamps.keys().filter(func(id: String) -> bool: return room.is_ageless(lamps[id]))
	check(chandeliers.size() == 2 and chandeliers.all(func(id: String) -> bool: return states[id] == "lit"), "R01's ageless chandeliers are still lit")
	var was: Dictionary = expect.get("others", {})
	var now: Dictionary = other_picks()
	var changed: Array = now.keys().filter(func(k: String) -> bool: return not was.has(k) or int(was[k]) != int(now[k]))
	check(not now.is_empty() and was.size() == now.size() and changed.is_empty(), "no other socket changed: only lamps age (%s)" % [changed])
	check(ws.call("owns", &"lore_hollow_index"), "the satchel still holds the lore book")
	expect["lamps_year40"] = states
	var f: FileAccess = FileAccess.open(EXPECT, FileAccess.WRITE)
	f.store_string(JSON.stringify(expect))
	f.close()


## Fifth process, no --advance-years: still year 40, the same lamps.
func age_again_mode() -> void:
	var expect: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(EXPECT))
	check(absf(float(ws.call("years")) - 40.0) < 0.01, "a restart is still at year 40 (the clock is saved)")
	var lamps: Dictionary = lamp_sockets()
	var same: bool = true
	for id: String in lamps:
		same = same and expect["lamps_year40"].get(id, "") == (lamps[id] as VariantSocket).picked_label()
	check(same, "every lamp shows the same state as in the run that aged it")


# --- phase 4 step 4: the library wing remembers (phase-4-design.md 8.1.8) --------
const AREA_EXPECT: String = "user://test/persist_area_expect%s.json"


## The area the area modes walk (`--area-id=<id>`; not `--area=`, which would
## stop the load process resuming from the save).
func area_id() -> String:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--area-id="):
			return a.trim_prefix("--area-id=")
	return "library"


func area_expect() -> String:
	return AREA_EXPECT % ("" if area_id() == "library" else "_" + area_id())


## Sixth process (a fresh save, `--area-seed=N`): in the area's root room,
## knock R01's west vase over, or pull a book from one of the hall's shelves onto
## the floor; walk to the farthest gallery (F), tend a lamp and drop a book
## there; walk to the gallery furthest from it (Q) until F has unloaded. Then
## Let ten years pass, walk into a gallery that wasn't loaded (U), record its
## lamps at year 10 as this process streamed them in, walk back to Q and quit.
func area_save_mode() -> void:
	check(area != null and room != null, "the game starts in %s, its root room live" % area_id())
	if area == null or room == null:
		return
	fast_unloads()
	var p: AreaPlan = area.plan
	var st: AreaStreamer = area.streamer
	var ever_live: Dictionary = {}
	for s: String in st.states:
		if st.is_live(s):
			ever_live[s] = true
	st.room_loaded.connect(func(s: String) -> void: ever_live[s] = true)
	var root_change: Dictionary = await change_root()
	# F: the deepest leaf. Q: the room furthest from it (not the root).
	var far: AreaPlan.Room = null
	for r: AreaPlan.Room in p.rooms:
		# A leaf of the rooms that stream (a pinned cistern never unloads; the
		# gallery it grows from counts as a leaf), as stream_test picks them.
		var leaf: bool = p.rooms.all(func(c: AreaPlan.Room) -> bool: return c.parent != r.slot_id or c.pinned)
		if r.parent != "" and leaf and not r.pinned and (far == null or r.depth > far.depth or (r.depth == far.depth and r.slot_id < far.slot_id)):
			far = r
	var from_far: Dictionary = st.distances(far.slot_id)
	var quit_room: AreaPlan.Room = null
	for r: AreaPlan.Room in p.rooms:
		if r.parent != "" and not r.pinned and (quit_room == null or int(from_far[r.slot_id]) > int(from_far[quit_room.slot_id])):
			quit_room = r
	check(int(from_far[quit_room.slot_id]) > st.settings.unload_radius, "seed %d: a gallery %d doorways from %s, enough for it to unload" % [p.area_seed, int(from_far[quit_room.slot_id]), far.slot_id])
	await walk(AreaTour.leg(p, far))
	var f_room: RoomTemplate = area.rooms.get(far.slot_id)
	check(f_room != null and st.player_room == far.slot_id, "walked into %s" % far.slot_id)
	if f_room == null:
		return
	var tended: Dictionary = tend_first_lamp(f_room)
	check(not tended.is_empty(), "%s has a lamp to tend" % far.slot_id)
	var book: Dictionary = await drop_a_book(f_room)
	check(str(ws.call("delta", book.get("id", "")).get("s", "")) == "moved", "the book in %s is saved as moved (%s)" % [far.slot_id, book.get("id", "")])
	var far_year0: Dictionary = lamp_labels(f_room)
	await walk(AreaTour.between(p, far, quit_room))
	await until(func() -> bool: return not st.is_live(far.slot_id))
	check(not st.is_live(far.slot_id) and not area.rooms.has(far.slot_id), "%s unloaded once we were in %s" % [far.slot_id, quit_room.slot_id])
	# U: a gallery that isn't loaded, preferably one never loaded at all.
	var unseen: AreaPlan.Room = null
	for r: AreaPlan.Room in p.rooms:
		if r.parent == "" or r.pinned or r == far or st.is_live(r.slot_id):
			continue
		if unseen == null or (not ever_live.has(r.slot_id) and ever_live.has(unseen.slot_id)):
			unseen = r
	check(unseen != null, "a gallery other than %s isn't loaded" % far.slot_id)
	if unseen == null:
		return
	var u_year0: Dictionary = labels_off_tree(unseen.slot_id)
	game.on_choice("years")
	check(absf(float(ws.call("years")) - 10.0) < 0.01, "Let ten years pass: year 10 (%.2f)" % float(ws.call("years")))
	await walk(AreaTour.between(p, quit_room, unseen))
	var u_room: RoomTemplate = area.rooms.get(unseen.slot_id)
	check(u_room != null, "walked into %s, which wasn't loaded when the years passed" % unseen.slot_id)
	var u_year10: Dictionary = lamp_labels(u_room) if u_room != null else {}
	check(not u_year10.is_empty() and u_year10.size() == u_year0.size(), "%s: the same %d lamps as at year 0" % [unseen.slot_id, u_year10.size()])
	var aged: int = aged_forward(u_year0, u_year10, unseen.slot_id)
	print("  %s: %d of %d lamps aged in ten years" % [unseen.slot_id, aged, u_year10.size()])
	await walk(AreaTour.between(p, unseen, quit_room))
	await until(func() -> bool: return not st.is_live(far.slot_id))
	check(not st.is_live(far.slot_id), "%s is still unloaded as we quit" % far.slot_id)
	# What the save holds: the root's change where it lies as we quit (a book
	# may still settle against the clutter at a wall's foot after the drop),
	# and F's book as F's unload stored it.
	for prop: WorldProp in room.world_props():
		if prop.get_meta("world_id", "") == root_change.get("id", ""):
			root_change["xf"] = WorldStateData.arr(room_xf(prop))
	var stored: Dictionary = ws.call("delta", book.get("id", ""))
	check(stored.has("xf"), "%s's unload stored its book (%s)" % [far.slot_id, book.get("id", "")])
	if stored.has("xf"):
		book["xf"] = stored["xf"]
	var at: Vector3 = game.player.global_position
	var expect: Dictionary = {"seed": p.area_seed, "far": far.slot_id, "quit_room": quit_room.slot_id, "unseen": unseen.slot_id,
		"pos": [at.x, at.y, at.z], "yaw": game.player.rotation.y, "root_change": root_change,
		"tended": tended, "book": book, "far_year0": far_year0, "u_year0": u_year0, "u_year10": u_year10, "u_aged": aged}
	DirAccess.make_dir_recursive_absolute("user://test")
	var f: FileAccess = FileAccess.open(area_expect(), FileAccess.WRITE)
	f.store_string(JSON.stringify(expect))
	f.close()


## Seventh process: resumes in Q, where it quit; F loads only when walked to.
## Both changes are there, U shows the lamps the sixth process gave it at year
## 10, and F's untended lamps have aged too.
func area_load_mode() -> void:
	var expect: Variant = JSON.parse_string(FileAccess.get_file_as_string(area_expect()))
	check(expect is Dictionary, "the area save run left its expectations")
	check(area != null and room != null and area.recipe.id == area_id(), "the game resumes in %s" % area_id())
	if not expect is Dictionary or area == null or room == null:
		return
	fast_unloads()
	var p: AreaPlan = area.plan
	var st: AreaStreamer = area.streamer
	check(p.area_seed == int(expect["seed"]), "the same area (seed %d, saved %d)" % [p.area_seed, int(expect["seed"])])
	var pos: Vector3 = Vector3(expect["pos"][0], expect["pos"][1], expect["pos"][2])
	check(st.player_room == expect["quit_room"] and Vector2(game.player.global_position.x - pos.x, game.player.global_position.z - pos.z).length() < 0.05 and absf(game.player.rotation.y - float(expect["yaw"])) < 0.01,
		"back in %s, where we quit (%s in %s)" % [expect["quit_room"], game.player.global_position, st.player_room])
	check(not st.is_live(expect["far"]), "%s isn't loaded at the start" % expect["far"])
	check(absf(float(ws.call("years")) - 10.0) < 0.01, "still year 10")
	var rc: Dictionary = expect["root_change"]
	if rc.get("kind", "") == "vase":
		var west: WorldProp = room.get_node_or_null("Props/VaseIwanWest")
		check(west != null and west.freeze and near(room_xf(west), WorldStateData.xf(rc["xf"])), "R01's west vase lies where it was knocked over")
	else:
		check(book_lies(room, rc), "%s: the book pulled from a shelf lies where it fell, its slot empty" % room.room_key())
	var quit_room: AreaPlan.Room = p.room(expect["quit_room"])
	var unseen: AreaPlan.Room = p.room(expect["unseen"])
	var far: AreaPlan.Room = p.room(expect["far"])
	await walk(AreaTour.between(p, quit_room, unseen))
	var u_room: RoomTemplate = area.rooms.get(unseen.slot_id)
	var u_now: Dictionary = lamp_labels(u_room) if u_room != null else {}
	check(u_room != null and u_now == expect["u_year10"], "%s's lamps are as the run that let the years pass made them (%s, then %s)" % [unseen.slot_id, expect["u_year10"], u_now])
	await walk(AreaTour.between(p, unseen, far))
	var f_room: RoomTemplate = area.rooms.get(far.slot_id)
	check(f_room != null, "walked into %s" % far.slot_id)
	if f_room == null:
		return
	var tended: Dictionary = expect["tended"]
	var labels: Dictionary = lamp_labels(f_room)
	check(labels.get(tended["path"], "") == tended["label"], "%s: the tended lamp is still %s after ten years (%s)" % [far.slot_id, tended["label"], labels.get(tended["path"], "")])
	var untended: Dictionary = (expect["far_year0"] as Dictionary).duplicate()
	untended.erase(tended["path"])
	var now: Dictionary = labels.duplicate()
	now.erase(tended["path"])
	var aged: int = aged_forward(untended, now, far.slot_id)
	print("  %s: %d of %d untended lamps aged in ten years; %s: %d of %d" % [far.slot_id, aged, now.size(), unseen.slot_id, int(expect["u_aged"]), (expect["u_year10"] as Dictionary).size()])
	check(aged + int(expect["u_aged"]) > 0, "ten years aged at least one untended lamp in the galleries that weren't loaded")
	check(book_lies(f_room, expect["book"]), "%s: the book lies where it fell, its shelf slot empty" % far.slot_id)
	check((ws.call("stale_ids") as PackedStringArray).is_empty(), "no change in the area went stale (%s)" % [ws.call("stale_ids")])


## The root room's change: R01's west vase knocked over (E), or else a book
## pulled from a shelf (a hall's bookcase or wall recess) onto the floor.
## Returns {kind, id, xf (room frame)}.
func change_root() -> Dictionary:
	var west: WorldProp = room.get_node_or_null("Props/VaseIwanWest")
	if west == null:
		var book: Dictionary = await drop_a_book(room)
		check(str(ws.call("delta", book.get("id", "")).get("s", "")) == "moved", "%s: the book pulled from a shelf is saved as moved (%s)" % [room.room_key(), book.get("id", "")])
		book["kind"] = "book"
		return book
	game.player.teleport(room.to_global(Vector3(2.2, 0.05, -15.0)), room.global_rotation.y, -0.62)
	for _i: int in 3:
		await physics_frame
	game.interact(west)
	await wait_still()
	check(str(ws.call("delta", west.get_meta("world_id", "")).get("s", "")) == "moved", "R01's knocked-over vase is saved as moved")
	return {"kind": "vase", "id": west.get_meta("world_id", ""), "xf": WorldStateData.arr(room_xf(west))}


## The book `bk` ({id, xf} from drop_a_book) lies where it fell in room `r`, its shelf slot empty.
func book_lies(r: RoomTemplate, bk: Dictionary) -> bool:
	for prop: WorldProp in r.world_props():
		if prop.get_meta("world_id", "") == bk.get("id", ""):
			return near(r.global_transform.affine_inverse() * prop.global_transform, WorldStateData.xf(bk["xf"])) \
				and (prop.get_parent() as ShelfFill).hidden.has(int(prop.get_meta("shelf_index")))
	return false


## Short unload delays, so the test needn't wait 10 s per room.
func fast_unloads() -> void:
	area.streamer.settings.unload_delay_s = 0.4
	area.streamer.settings.check_interval_s = 0.05


## Teleports the player along floor points, letting the streamer catch up at each.
func walk(points: Array[Vector3]) -> void:
	for i: int in points.size():
		var to: Vector3 = area.to_global(points[i])
		var yaw: float = game.player.rotation.y
		if i + 1 < points.size():
			var d: Vector3 = area.to_global(points[i + 1]) - to
			if d.length() > 0.1:
				yaw = atan2(-d.x, -d.z)
		game.player.teleport(to + Vector3(0, 0.05, 0), yaw)
		var until_ms: int = Time.get_ticks_msec() + 80
		while Time.get_ticks_msec() < until_ms:
			await physics_frame
		await until(func() -> bool: return not area.streamer.busy() and not FloorWear.busy())


## Frames until `cond` holds (at most 10 s).
func until(cond: Callable) -> void:
	var stop_ms: int = Time.get_ticks_msec() + 10000
	while not cond.call() and Time.get_ticks_msec() < stop_ms:
		await process_frame


## {socket key: label} of a room's lamps.
func lamp_labels(r: RoomTemplate) -> Dictionary:
	var out: Dictionary = {}
	for s: VariantSocket in r.sockets():
		if s.mode == VariantSocket.Mode.STATE and s.socket_set != null and s.socket_set.index_of("lit") >= 0:
			out[r.socket_key(s)] = s.picked_label()
	return out


## A room's lamps as the streamer would build it now, off the tree.
func labels_off_tree(slot: String) -> Dictionary:
	var st: AreaStreamer = area.streamer
	var job: Dictionary = st._new_job(slot)
	while job["stage"] != "enter":
		st._run_stage(job, -1)
	var r: RoomTemplate = job["room"]
	var out: Dictionary = lamp_labels(r)
	r.free()
	return out


## Tends a room's first lamp to the opposite of what it shows; {path, label}.
func tend_first_lamp(r: RoomTemplate) -> Dictionary:
	for s: VariantSocket in r.sockets():
		if s.mode == VariantSocket.Mode.STATE and s.socket_set != null and s.socket_set.index_of("lit") >= 0 and s.socket_set.index_of("dark") >= 0:
			var label: String = "dark" if s.picked_label() == "lit" else "lit"
			r.tend_lamp(s, label)
			return {"path": r.socket_key(s), "label": label}
	return {}


## Checks every lamp is where it was or further along lit → failing → dark;
## returns how many moved on.
func aged_forward(before: Dictionary, after: Dictionary, what: String) -> int:
	var chain: Array = ["lit", "failing", "dark"]
	var forward: bool = before.size() == after.size()
	var moved: int = 0
	for k: String in after:
		var a: int = chain.find(str(before.get(k, "")))
		var b: int = chain.find(str(after[k]))
		forward = forward and a >= 0 and b >= a
		if b > a:
			moved += 1
	check(forward, "%s: every untended lamp is where it was or further along (%s, then %s)" % [what, before, after])
	return moved

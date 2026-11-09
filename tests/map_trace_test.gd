extends SceneTree
## Phase 11 step 2: the Gorge and the camp on the map (traced, MapTrace),
## saved in one OS process and restored in a fresh one (AGENTS.md:
## persistence gate). Runs the world as you play it (seamless).
##   godot --headless --path . --script res://tests/map_trace_test.gd -- save --save=user://test/map_trace.json --fresh
##   godot --headless --path . --script res://tests/map_trace_test.gd -- load --save=user://test/map_trace.json
## save: start in the camp, walk to its door to the Gorge, down the corridor
##       onto the Overlook and to two of the Gorge's doors. Tiles near where
##       you walked are walked, more of the Gorge only seen; the map opens on
##       the Gorge with you on it, its door to the camp named and the door to
##       the Lower Stacks "?"; the camp's door to the Gorge named.
## load: a new process resumes in the Gorge: the same tiles; the map draws
##       them. Run without --headless it also saves captures of the open map
##       (the Gorge, the camp) to previews/p11_step2/.
## lake_save, lake_load (phase 18 step 5): the Lake Landing, a place of its own:
##       start in its passage, stand on the pier's stage and on the town
##       dock; the map draws the town dock's ferry line and its name, not the
##       docks never seen; a new process resumes there with the same tiles
##       (and, not headless, a capture of the open map).

const EXPECT: String = "user://test/map_trace_expect.json"
const CAPTURES: String = "res://previews/p11_step2/"

var main_script: GDScript = load("res://scripts/main.gd")
var failures: PackedStringArray = []
var checks: int = 0
var game: Node
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
	if mode == "save":
		main_script.room_override = "camp"
	elif mode == "lake_save":
		main_script.room_override = "res://rooms/lake/landing.tscn"
	game = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	current_scene = game
	await wait(3.0)
	# The neighbour built in the background (the Gorge from the camp, the camp from the Gorge).
	var stop_ms: int = Time.get_ticks_msec() + 90000
	while game.seamless != null and Time.get_ticks_msec() < stop_ms:
		var other: String = "gorge" if game.seamless.place_id == "camp" else "camp"
		var n: Variant = game.seamless.places.get(other)
		if n != null and (not n is Area or (n as Area).is_built):
			break
		await physics_frame
	if mode == "save":
		await save_mode()
	elif mode == "lake_save":
		await lake_save_mode()
	elif mode == "lake_load":
		await lake_load_mode()
	else:
		await load_mode()
	finish(mode)


func save_mode() -> void:
	var camp: MapTrace = game.map.trace_of("camp")
	var gorge: MapTrace = game.map.trace_of("gorge")
	check(camp != null and gorge != null, "both places are traced")
	if camp == null or gorge == null:
		return
	await wait(0.4)
	check(game.map.here_id == "camp", "the map knows you're in the camp (%s)" % game.map.here_id)
	# The camp's door to the Gorge, the corridor, the Overlook, two Gorge doors.
	var door: Dictionary = gorge_door(camp, "gorge")
	await go(door["at"] - door["out"] * 2.0)
	await go(Vector2(-1.0, -16.0))
	await go(Vector2(-1.0, -24.0))
	check(game.seamless == null or game.seamless.place_id == "gorge", "down the corridor, you're in the Gorge (%s)" % (game.seamless.place_id if game.seamless != null else "-"))
	var spots: Array[Vector2] = [Vector2(-1.0, -24.0)]
	for to: String in ["library", "lower_stacks"]:
		var d: Dictionary = gorge_door(gorge, to)
		check(not d.is_empty(), "the Gorge has a door to %s" % to)
		if not d.is_empty():
			spots.append(d["at"] - d["out"] * 2.0)
			await go(spots[-1])
	check(game.map.here_id == "gorge", "the map knows you're in the Gorge (%s)" % game.map.here_id)
	var known: Dictionary = ws.call("map_known", "gorge")
	var walked: Array = known.get("walked", [])
	var sighted: Array = known.get("sighted", [])
	for s: Vector2 in spots:
		check(walked.has(gorge.tile_of(s)), "the tile at %s is walked" % s)
	check(not sighted.is_empty(), "more of the Gorge is only seen (%d tiles, %d walked)" % [sighted.size(), walked.size()])
	check(walked.size() < (gorge.tiles as PackedByteArray).count(1), "not all the Gorge is walked")
	for t: Variant in sighted:
		check(not walked.has(t), "tile %s is seen or walked, not both" % t)
	check(not (ws.call("map_known", "camp").get("walked", []) as Array).is_empty(), "some of the camp is walked")
	check(ws.call("map_places").has("camp") and ws.call("map_places").has("gorge"), "the map lists the camp and the Gorge")
	# Open on the Gorge.
	game.map.open()
	await process_frame
	var c: MapCanvas = game.map.canvas
	check(game.map.is_open() and game.map.shown_id == "gorge" and c.trace == gorge, "M opens the map on the Gorge, drawn from its trace")
	check(not c.you.is_empty(), "you are on it")
	check(c.walked.size() == walked.size(), "it draws the %d tiles walked" % walked.size())
	check(str(c.door_labels.get("camp", "")) == "to the camp", "the way back says \"to the camp\" (%s)" % c.door_labels.get("camp", ""))
	check(str(c.door_labels.get("lower_stacks", "")) == "?", "the door to the Lower Stacks, never been through, says \"?\" (%s)" % c.door_labels.get("lower_stacks", ""))
	game.map.show_place("camp")
	check(c.trace == camp and c.you.is_empty(), "the camp shows from the list, without you on it")
	check(str(c.door_labels.get("gorge", "")).to_lower() == "to the gorge", "its door says \"to the Gorge\" (%s)" % c.door_labels.get("gorge", ""))
	game.map.close()
	var f := FileAccess.open(EXPECT, FileAccess.WRITE)
	f.store_string(JSON.stringify({"gorge": walked, "camp": ws.call("map_known", "camp")["walked"]}))
	f.close()


func load_mode() -> void:
	var expect: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(EXPECT))
	await wait(0.4)
	check(game.map.here_id == "gorge", "a new process resumes in the Gorge (%s)" % game.map.here_id)
	for id: String in ["gorge", "camp"]:
		var t: MapTrace = game.map.trace_of(id)
		var got: Array = (ws.call("map_traced", id, t.stamp(), "") as Dictionary)["walked"].duplicate()
		var want: Array = (expect[id] as Array).map(func(v: Variant) -> int: return int(v))
		# Resuming notes the tiles where you stand again: those are already walked.
		got.sort()
		want.sort()
		check(got == want, "%s: the same %d tiles walked (%d)" % [id, want.size(), got.size()])
	game.map.open()
	await process_frame
	var c: MapCanvas = game.map.canvas
	check(game.map.is_open() and game.map.shown_id == "gorge" and c.trace != null and not c.walked.is_empty(), "the map opens on the Gorge and draws it")
	check(not c.you.is_empty(), "with you on it")
	if DisplayServer.get_name() != "headless":
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CAPTURES))
		for id: String in ["gorge", "camp"]:
			game.map.show_place(id, id == "gorge")
			for _i: int in 100:
				await process_frame
			var path: String = CAPTURES + "map_%s.png" % id
			var err: Error = root.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
			check(err == OK, "saved the capture %s" % path)
			print("map_trace_test: capture ", ProjectSettings.globalize_path(path))
	game.map.close()


func finish(mode: String) -> void:
	print("map_trace_test %s: %d checks, %d failures" % [mode, checks, failures.size()])
	for f: String in failures:
		print("  FAIL ", f)
	if failures.is_empty() and game != null:
		game.save_and_quit()
	else:
		quit(1 if not failures.is_empty() else 0)


## The door of trace `t` to `to` ({} = none).
func gorge_door(t: MapTrace, to: String) -> Dictionary:
	for d: Dictionary in t.doors:
		if str(d["raw"]) == to or str(d["to"]) == to:
			return d
	return {}


## Teleports the player onto the floor at (x, z) in the Gorge's frame (the
## camp shares it), and lets the world and the map catch up.
func go(m: Vector2) -> void:
	var space: PhysicsDirectSpaceState3D = game.player.get_world_3d().direct_space_state
	# The first floor facing up with headroom over it (not a cliff's overhang).
	var q := PhysicsRayQueryParameters3D.new()
	q.exclude = [game.player.get_rid()]
	q.hit_back_faces = true
	var top: float = 40.0
	var ceiling: float = INF
	var y: float = 1.0
	for _h: int in 16:
		q.from = Vector3(m.x, top, m.y)
		q.to = Vector3(m.x, -80.0, m.y)
		var hit: Dictionary = space.intersect_ray(q)
		if hit.is_empty():
			break
		var p: Vector3 = hit["position"]
		if (hit["normal"] as Vector3).y >= 0.6 and ceiling - p.y >= 1.7:
			y = p.y
			break
		ceiling = p.y
		top = p.y - 0.02
	game.player.teleport(Vector3(m.x, y + 0.05, m.y), game.player.rotation.y)
	await wait(1.5)


func wait(s: float) -> void:
	var stop_ms: int = Time.get_ticks_msec() + int(s * 1000.0)
	while Time.get_ticks_msec() < stop_ms:
		await physics_frame


const LAKE_EXPECT: String = "user://test/map_lake_expect.json"


func lake_save_mode() -> void:
	var t: MapTrace = game.map.trace_of("lake")
	check(t != null and t.lines.size() == LakeLayout.STYLES.size(), "the lake is traced, a ferry line to each dock (%d)" % (t.lines.size() if t != null else -1))
	if t == null:
		return
	await wait(0.6)
	check(game.map.here_id == "lake", "the map knows you're at the lake (%s)" % game.map.here_id)
	await go(Vector2(LakeLayout.PIER_STAGE.x, LakeLayout.PIER_STAGE.z + 1.4))
	var town: Vector3 = LakeLayout.dock_frame("town") * Vector3(10.0, 0.0, -1.5)
	await go(Vector2(town.x, town.z))
	game.map.open()
	await process_frame
	var c: MapCanvas = game.map.canvas
	check(game.map.is_open() and game.map.shown_id == "lake" and c.trace == t, "M opens the map on the lake, drawn from its trace")
	check(game.map._place_title("lake") == "The Lake Landing", "it is called the Lake Landing (%s)" % game.map._place_title("lake"))
	check(not c.you.is_empty(), "you are on it")
	for l: Dictionary in t.lines:
		var known: bool = c._knows(l["at_a"]) and c._knows(l["at_b"])
		check(known == (str(l["style"]) == "town"), "the ferry line to the %s dock is %s" % [l["style"], "drawn" if known else "not drawn"])
	var named: Array = c.trace_names.filter(func(n: Dictionary) -> bool: return c._knows(n["at"]))
	check(named.size() == 1, "one dock is named on the map (%s)" % [named])
	check(c.door_labels.has("EntryDoor"), "the passage's door is on the map (%s)" % [c.door_labels])
	game.map.close()
	var f := FileAccess.open(LAKE_EXPECT, FileAccess.WRITE)
	f.store_string(JSON.stringify({"lake": ws.call("map_known", "lake")["walked"]}))
	f.close()


func lake_load_mode() -> void:
	var expect: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(LAKE_EXPECT))
	await wait(0.6)
	check(game.map.here_id == "lake", "a new process resumes at the lake (%s)" % game.map.here_id)
	var t: MapTrace = game.map.trace_of("lake")
	var got: Array = (ws.call("map_traced", "lake", t.stamp(), "") as Dictionary)["walked"].duplicate()
	var want: Array = (expect["lake"] as Array).map(func(v: Variant) -> int: return int(v))
	got.sort()
	want.sort()
	check(got == want, "lake: the same %d tiles walked (%d)" % [want.size(), got.size()])
	game.map.open()
	await process_frame
	var c: MapCanvas = game.map.canvas
	check(game.map.is_open() and game.map.shown_id == "lake" and not c.walked.is_empty(), "the map opens on the lake and draws it")
	if DisplayServer.get_name() != "headless":
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CAPTURES))
		for zoom: float in [2.0, 0.5]:
			c.zoom = zoom
			c.centre = Vector2(LakeLayout.PIER_STAGE.x, LakeLayout.PIER_STAGE.z) if zoom > 1.0 else Vector2(0, -230)
			c.queue_redraw()
			for _i: int in 100:
				await process_frame
			var path: String = CAPTURES + "map_lake_%s.png" % ("near" if zoom > 1.0 else "far")
			var err: Error = root.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
			check(err == OK, "saved the capture %s" % path)
			print("map_trace_test: capture ", ProjectSettings.globalize_path(path))
	game.map.close()

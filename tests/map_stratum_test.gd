extends SceneTree
## Phase 11 step 3: the whole stratum and your marks, over three OS processes
## (AGENTS.md: persistence gate).
##   godot --headless --path . --script res://tests/map_stratum_test.gd -- stacks --save=user://test/map_stratum.json --fresh
##   godot --headless --path . --script res://tests/map_stratum_test.gd -- gorge --save=user://test/map_stratum.json
##   godot --headless --path . --script res://tests/map_stratum_test.gd -- load --save=user://test/map_stratum.json
## stacks: in the Lower Stacks, walk to the room with its door to the Gorge;
##         keep that door's frame (from the plan) for later.
## gorge:  start in the camp, down the corridor to the Gorge's door to the
##         Lower Stacks. The map places the Lower Stacks where the continuous
##         world would (SeamlessPlaces._interior_frame, from both plans), and
##         joins the three places by their doors. Put a lamp with a note on
##         the Gorge, a star on the camp, one more and take it away again.
## load:   a new process: both marks, their notes; the stratum the same. Run
##         without --headless it saves captures of the stratum and of the
##         Gorge with its mark to previews/p11_step3/.

const EXPECT: String = "user://test/map_stratum_expect.json"
const CAPTURES: String = "res://previews/p11_step3/"
const NOTE: String = "come back with light"

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
	var mode: String = args[0] if args.size() > 0 else "stacks"
	ws = root.get_node_or_null("WorldState")
	if mode == "stacks":
		main_script.room_override = "area:lower_stacks"
	elif mode == "gorge":
		main_script.room_override = "camp"
	game = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	current_scene = game
	await wait(3.0)
	var stop_ms: int = Time.get_ticks_msec() + 90000
	while game.seamless != null and Time.get_ticks_msec() < stop_ms:     # the neighbour, built in the background
		var other: String = "gorge" if game.seamless.place_id == "camp" else "camp"
		var n: Variant = game.seamless.places.get(other)
		if n != null and (not n is Area or (n as Area).is_built):
			break
		await physics_frame
	match mode:
		"stacks":
			await stacks_mode()
		"gorge":
			await gorge_mode()
		_:
			await load_mode()
	finish(mode)


func stacks_mode() -> void:
	var area: Area = game.world as Area
	check(area != null and area.recipe.id == "lower_stacks", "the game is in the Lower Stacks")
	if area == null:
		return
	var d: Array = area.plan.threshold("gorge")
	check(not d.is_empty(), "the Lower Stacks has a door to the Gorge")
	if d.is_empty():
		return
	for p: Vector3 in AreaTour.leg(area.plan, d[0]):
		game.player.teleport(area.to_global(p) + Vector3(0, 0.05, 0), game.player.rotation.y)
		await wait(0.4)
	check(game.map.door_xf("lower_stacks", "gorge") != null, "the map knows the Lower Stacks' door to the Gorge")
	var xf: Transform3D = (d[0] as AreaPlan.Room).connectors[d[1]]["xf"]
	save_expect({"stacks_door": var_to_str(xf)})


func gorge_mode() -> void:
	check(ws.call("map_places").has("lower_stacks"), "the map still knows the Lower Stacks, from the save")
	var gorge_trace: MapTrace = game.map.trace_of("gorge")
	var camp_trace: MapTrace = game.map.trace_of("camp")
	await go(door_in(camp_trace, "gorge"))
	await go(Vector2(-1.0, -16.0))
	await go(Vector2(-1.0, -24.0))
	await go(door_in(gorge_trace, "lower_stacks"))
	check(game.map.here_id == "gorge", "you're in the Gorge (%s)" % game.map.here_id)
	var gorge: Area = game.world as Area
	if gorge == null:
		check(false, "the Gorge is the world")
		return
	# Where the continuous world would put the Lower Stacks, from both plans.
	var expect: Dictionary = load_expect()
	var g: Array = gorge.plan.threshold("lower_stacks")
	var want: Transform3D = (g[0] as AreaPlan.Room).connectors[g[1]]["xf"] * Vestibule.EXIT * Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO) \
		* (str_to_var(expect["stacks_door"]) as Transform3D).affine_inverse()
	var frames: Dictionary = game.map.stratum_frames()
	check(frames.has("lower_stacks"), "the map can place the Lower Stacks")
	if frames.has("lower_stacks"):
		var got: Transform2D = frames["lower_stacks"]
		var w2: Transform2D = MapPage.flat(want)
		check(got.origin.distance_to(w2.origin) < 0.05 and got.x.distance_to(w2.x) < 0.01,
			"where the continuous world puts it (map %s, world %s)" % [got, w2])
		expect["stacks_frame"] = var_to_str(got)
	# Marks: a lamp with a note on the Gorge, a star on the camp, one taken away.
	var page: MapPage = game.map
	page.open()
	await process_frame
	page.show_place("gorge", true)
	await process_frame
	var mid: Vector2 = page.canvas.size * 0.5
	page._mark_at(mid + Vector2(12, 0))
	check(page._mark_panel.visible and page.canvas.picked_mark >= 0, "a right-click puts a mark and opens its panel")
	page._pick_symbol("lamp")
	page._note.text = NOTE
	page._keep_mark()
	page.show_place("camp")
	page._mark_at(page.canvas.size * 0.5)
	page._keep_mark()
	page._mark_at(page.canvas.size * 0.5 + Vector2(30, 30))
	page._keep_mark()
	check((ws.call("map_marks") as Array).size() == 3, "three marks kept")
	page._mark_at(page.canvas.size * 0.5 + Vector2(30, 30))
	check(page._mark_remove.visible, "a right-click on a mark picks it")
	page._remove_mark()
	var marks: Array = ws.call("map_marks")
	check(marks.size() == 2, "and Remove takes it away (%d left)" % marks.size())
	check(page.marks_of("gorge").size() == 1 and str(page.marks_of("gorge")[0]["note"]) == NOTE and str(page.marks_of("gorge")[0]["symbol"]) == "lamp", "the Gorge has the lamp with its note")
	check(page.marks_of("camp").size() == 1 and str(page.marks_of("camp")[0]["symbol"]) == "star", "the camp has the star")
	# The whole stratum.
	page.show_stratum()
	var ids: Array = page.canvas.layers.map(func(l: Dictionary) -> String: return l["id"])
	check(page.shown_id == MapPage.STRATUM and ids.has("camp") and ids.has("gorge") and ids.has("lower_stacks"), "the stratum shows the camp, the Gorge and the Lower Stacks (%s)" % [ids])
	check(page.canvas.links.size() == 2, "joined by the corridor and the Lower Stacks' door (%d links)" % page.canvas.links.size())
	check(not page.canvas.you.is_empty(), "with you on it")
	page.show_place("gorge", true)
	page.canvas.zoom = MapPage.ZOOM_MIN
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	wheel.position = page.canvas.size * 0.5
	page._on_sheet_input(wheel)
	check(page.shown_id == MapPage.STRATUM, "zooming out past a place shows the stratum")
	page.close()
	expect["links"] = page.canvas.links.size()
	save_expect(expect)


func load_mode() -> void:
	var expect: Dictionary = load_expect()
	var page: MapPage = game.map
	var marks: Array = ws.call("map_marks")
	check(marks.size() == 2, "a new process has both marks (%d)" % marks.size())
	check(page.marks_of("gorge").size() == 1 and str(page.marks_of("gorge")[0]["note"]) == NOTE, "the Gorge's lamp keeps its note")
	var frames: Dictionary = page.stratum_frames()
	var want: Transform2D = str_to_var(str(expect.get("stacks_frame", "Transform2D()")))
	check(frames.has("lower_stacks") and (frames["lower_stacks"] as Transform2D).origin.distance_to(want.origin) < 0.01, "the Lower Stacks lies where it did")
	page.open()
	await process_frame
	page.show_stratum()
	check(page.canvas.layers.size() == 3 and page.canvas.links.size() == int(expect.get("links", -1)), "the stratum draws the same three places and links")
	if DisplayServer.get_name() != "headless":
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CAPTURES))
		page.canvas.zoom = 0.8
		var ls: Transform2D = frames.get("lower_stacks", Transform2D.IDENTITY)
		page.canvas.centre = (ls.origin + Vector2(-1, -24)) * 0.5
		await capture("stratum")
		page.show_place("gorge", true)
		await capture("marks")
	page.close()


func capture(what: String) -> void:
	for _i: int in 100:
		await process_frame
	var path: String = CAPTURES + "%s.png" % what
	var err: Error = root.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	check(err == OK, "saved the capture %s" % path)
	print("map_stratum_test: capture ", ProjectSettings.globalize_path(path))


func finish(mode: String) -> void:
	print("map_stratum_test %s: %d checks, %d failures" % [mode, checks, failures.size()])
	for f: String in failures:
		print("  FAIL ", f)
	if failures.is_empty() and game != null:
		game.save_and_quit()
	else:
		quit(1 if not failures.is_empty() else 0)


func save_expect(d: Dictionary) -> void:
	var f := FileAccess.open(EXPECT, FileAccess.WRITE)
	f.store_string(JSON.stringify(d))
	f.close()


func load_expect() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(EXPECT)) if FileAccess.file_exists(EXPECT) else {}


## 2 m inside trace `t`'s door to `to`.
func door_in(t: MapTrace, to: String) -> Vector2:
	for d: Dictionary in t.doors:
		if str(d["raw"]) == to or str(d["to"]) == to:
			return d["at"] - d["out"] * 2.0
	check(false, "a door to %s" % to)
	return Vector2.ZERO


## Teleports the player onto the floor at (x, z) in the Gorge's frame (the
## camp shares it): the first floor down with headroom over it.
func go(m: Vector2) -> void:
	var space: PhysicsDirectSpaceState3D = game.player.get_world_3d().direct_space_state
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

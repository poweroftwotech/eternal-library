extends SceneTree
## Pictures of the animals where they live (phase 19), in the real game, for
## the look. Needs a display, not --headless; run `godot --headless --import`
## first, and pass --audio-driver Dummy.
##   godot --path . --resolution 1600x900 --audio-driver Dummy --script res://tests/fauna_capture.gd -- <out dir> [place ...] [--seed=N] [--close] [--stats] [--only=<id,id>] [--max=N] [--all-rooms]
## place: camp, a scene path or area:<id>. In an area, the rooms of the types
## animals live in are visited (--all-rooms: every room). For every group of
## animals Fauna puts in a room, shoots it and writes
## <place>_<slot>_<group>_<kind>.png; prints the place's animals, what ticking
## them cost and the frame's draw calls.
##   Fish: from the water's edge at about 2.4 m (--close: straight down, 0.9 m).
##   Moths: level with the flame, 1.6 m off. Glowworms: from under the roof.
##   Bats: hanging, from outside their startle range (a long lens); then with
##   the player walked under the roost, in flight 1 s and 2.5 s later (_fly1,
##   _fly2).
## --only: shoot only these kinds (ids). --max: at most N groups of a kind per
## place.

const DEFAULT: PackedStringArray = ["camp", "area:grand_study", "area:gardens", "area:mahaleh", "res://rooms/lake/landing.tscn"]
const ROOM_TYPES: PackedStringArray = ["R03", "R04", "R06", "R07", "R09", "R11", "R15", "R17", "R21"]

var only: PackedStringArray = []
var max_per_kind: int = 1000
var _shot: Dictionary = {}     # kind -> groups shot in this place


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var places: PackedStringArray = []
	var out_dir: String = ""
	var close: bool = false
	var stats: bool = false
	var all_rooms: bool = false
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--seed="):
			Area.seed_override = a.trim_prefix("--seed=").to_int()
		elif a == "--stats":
			stats = true
		elif a == "--close":
			close = true
		elif a == "--all-rooms":
			all_rooms = true
		elif a.begins_with("--only="):
			only = a.trim_prefix("--only=").split(",")
		elif a.begins_with("--max="):
			max_per_kind = a.trim_prefix("--max=").to_int()
		elif out_dir == "":
			out_dir = a
		else:
			places.append(a)
	if out_dir == "":
		out_dir = "user://fauna_capture"
	if places.is_empty():
		places = DEFAULT
	DirAccess.make_dir_recursive_absolute(out_dir)
	var main_script: GDScript = load("res://scripts/main.gd")
	for place: String in places:
		_shot.clear()
		main_script.room_override = place
		var game: Node = (load("res://main.tscn") as PackedScene).instantiate()
		root.add_child(game)
		game.hud.toast_time = 0
		game.hud.visible = false
		game.stats.visible = stats
		game.player.blocked = true
		for _i: int in 20:
			await process_frame
		var tag: String = place.get_file().get_basename().replace("area:", "")
		var world: Node3D = game.world
		if world is Area:
			var area: Area = world
			for r: AreaPlan.Room in area.plan.rooms:
				var abandoned: bool = r.grammar != null and str(r.grammar.get_meta("state", "")) == RoomGrammar.ABANDONED
				if not all_rooms and not abandoned and r.room_type not in ROOM_TYPES:
					continue
				var c: Vector3 = area.global_transform * r.xf * Vector3.ZERO
				if not r.floor_cells.is_empty():
					c = area.global_transform * CellGrid.cell_centre(r.floor_cells.keys()[0])
				game.player.teleport(c)
				await _settle(game, area.fauna)
				await _shoot(game, area.fauna, r.slot_id, "%s/%s_%s" % [out_dir, tag, r.slot_id], close)
		else:
			var f: Fauna = world.get_node_or_null("Fauna") as Fauna
			await _settle(game, f)
			await _shoot(game, f, "", "%s/%s" % [out_dir, tag], close)
		game.queue_free()
		for _i: int in 3:
			await process_frame
	main_script.room_override = ""
	quit()


func _settle(game: Node, f: Fauna) -> void:
	for _i: int in 10:
		await process_frame
	var streamer: Variant = game.world.get("streamer")
	while streamer != null and streamer.busy():
		await process_frame
	for _i: int in 600:
		if f == null or f._jobs.is_empty():
			break
		await process_frame
	for _i: int in 30:
		await process_frame


func _shoot(game: Node, f: Fauna, slot: String, stem: String, close: bool) -> void:
	if f == null:
		print("  %s: no Fauna" % stem)
		return
	var gs: Array = f.groups.get(slot, [])
	var kinds: PackedStringArray = []
	for g: Node in gs:
		if is_instance_valid(g):
			kinds.append(str(g.get("def").id))
	print("  %s: %d groups %s, %s" % [stem.get_file(), gs.size(), kinds, f.stats])
	for gi: int in gs.size():
		var g: MultiMeshInstance3D = gs[gi]
		if not is_instance_valid(g):
			continue
		var kind: String = str(g.get("def").id)
		if not only.is_empty() and not only.has(kind):
			continue
		if int(_shot.get(kind, 0)) >= max_per_kind:
			continue
		_shot[kind] = int(_shot.get(kind, 0)) + 1
		var path: String = "%s_%d_%s" % [stem, gi, kind]
		if g.get("body") != null:
			await _shoot_fish(game, f, g, path, close)
		elif g is BatRoost:
			await _shoot_bats(game, f, g as BatRoost, path)
		elif g is GlowColony:
			await _shoot_air(game, f, g, path, Vector3(0, -2.2, 0), 2.2, 60.0)
		else:
			var loose: bool = g is MothSwarm and (g.multimesh.get_instance_custom_data(0).a > 0.5)
			await _shoot_air(game, f, g, path, Vector3(0, 0.6 if loose else 0.15, 0), 3.5 if loose else 1.6, 60.0)


func _shoot_fish(game: Node, f: Fauna, g: MultiMeshInstance3D, path: String, close: bool) -> void:
	var at: Vector3 = _centre(g)
	var b: WaterBody = g.get("body")
	# Look down at them at about 45 degrees from a spot in open air.
	var back: float = 1.2 if close else 2.4
	var space: PhysicsDirectSpaceState3D = g.get_world_3d().direct_space_state
	var eye: Vector3 = Vector3(at.x, b.surface, at.z) + Vector3(0, back, 0.3)
	for k: int in 16:
		var d := Vector3(cos(k * TAU / 16.0), 0, sin(k * TAU / 16.0))
		var cand: Vector3 = Vector3(at.x, b.surface, at.z) + d * back * 0.8 + Vector3(0, back * 0.8, 0)
		if _clear(space, Vector3(at.x, b.surface + 0.05, at.z), cand):
			eye = cand
			break
	if close:
		eye = Vector3(at.x, b.surface + 0.9, at.z + 0.35)     # nearly straight down over one fish
	await _frame_at(game, f, g, eye, at, 60.0, path)


## Moths and glowworms: from `rise` off the focus (up or down), `back` m
## to the side, where the line to them is clear.
func _shoot_air(game: Node, f: Fauna, g: MultiMeshInstance3D, path: String, rise: Vector3, back: float, fov: float) -> void:
	var at: Vector3 = g.get("focus")
	var space: PhysicsDirectSpaceState3D = g.get_world_3d().direct_space_state
	var eye: Vector3 = at + rise + Vector3(back, 0, 0)
	for k: int in 16:
		var d := Vector3(cos(k * TAU / 16.0), 0, sin(k * TAU / 16.0))
		var cand: Vector3 = at + rise + d * back
		if _clear(space, at + rise.normalized() * 0.1, cand):
			eye = cand
			break
	await _frame_at(game, f, g, eye, at, fov, path)


func _shoot_bats(game: Node, f: Fauna, g: BatRoost, path: String) -> void:
	var at: Vector3 = g.focus
	var space: PhysicsDirectSpaceState3D = g.get_world_3d().direct_space_state
	var far: float = g.def.startle_radius + 1.5
	var eye: Vector3 = at - Vector3(0, 2.5, 0) + Vector3(far, 0, 0)
	for k: int in 16:
		var d := Vector3(cos(k * TAU / 16.0), 0, sin(k * TAU / 16.0))
		var cand: Vector3 = at - Vector3(0, 2.5, 0) + d * far
		if _clear(space, at - Vector3(0, 0.3, 0), cand):
			eye = cand
			break
	g.clock = -1.0
	await _frame_at(game, f, g, eye, at, 22.0, path)
	# Walk under them: they go.
	var under: Vector3 = at - Vector3(0, 3.0, 0)
	var near_eye: Vector3 = at - Vector3(0, 2.0, 0) + (eye - at).normalized() * 3.0
	near_eye.y = at.y - 2.0
	game.player.teleport(under - Vector3(0, 1.62, 0))
	for _i: int in 3:
		await process_frame
	game.player.camera.global_position = near_eye
	game.player.camera.look_at(at - Vector3(0, 0.8, 0), Vector3.UP)
	game.player.camera.fov = 70.0
	for t: Array in [[1.0, "_fly1"], [1.5, "_fly2"]]:
		await create_timer(float(t[0])).timeout
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png(path + str(t[1]) + ".png")
	print("    %s: bats flew (clock %.1f s)" % [g.name, g.clock])
	game.player.camera.position = Vector3(0, 1.62, 0)


func _frame_at(game: Node, f: Fauna, g: MultiMeshInstance3D, eye: Vector3, at: Vector3, fov: float, path: String) -> void:
	game.player.teleport(eye - Vector3(0, 1.62, 0))
	var cam: Camera3D = game.player.camera
	cam.global_position = eye
	cam.look_at(at, Vector3.UP if absf((at - eye).normalized().y) < 0.98 else Vector3.FORWARD)
	cam.fov = fov
	for _i: int in 45:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(path + ".png")
	print("    %s: %d at %s, tick %.3f ms, draws %d -> %s.png" % [g.name, g.multimesh.instance_count, at.snapped(Vector3.ONE * 0.1),
		f.stats["tick_ms"], Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), path])
	cam.position = Vector3(0, 1.62, 0)


func _clear(space: PhysicsDirectSpaceState3D, a: Vector3, b: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(a, b, 1)
	q.hit_back_faces = true
	return space.intersect_ray(q).is_empty()


func _centre(g: MultiMeshInstance3D) -> Vector3:
	if g is FishSchool:
		return g.global_position
	return g.global_transform * g.multimesh.get_instance_transform(0).origin     # one fish, not the middle of the pool (the fountain)

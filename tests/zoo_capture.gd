extends SceneTree
## The zoo (ZooRoom): what lives in each pen, and pictures. Run headless for
## the counts alone; with a display (after `godot --headless --import`) it
## also writes <out dir>/corridor.png and <pen>.png from each pen's doorway.
##   godot --path . --resolution 1600x900 --audio-driver Dummy --script res://tests/zoo_capture.gd -- <out dir> [--expect]
## --expect: exits 1 unless every pen holds the animals it is for (EXPECT).

const EXPECT: Dictionary = {"pool": ["goldfish"], "cistern": ["cave_barb"], "lamps": ["candle_moth", "gecko"], "vault": ["bat", "glowworm"], "home": ["cat"], "ruin": ["rat"]}


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var out_dir: String = "user://zoo"
	var expect: bool = false
	var overlay: bool = false
	for a: String in OS.get_cmdline_user_args():
		if a == "--expect":
			expect = true
		elif a == "--overlay":
			overlay = true
		elif not a.begins_with("--"):
			out_dir = a
	DirAccess.make_dir_recursive_absolute(out_dir)
	var main_script: GDScript = load("res://scripts/main.gd")
	main_script.room_override = ZooRoom.SCENE
	var game: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	game.hud.toast_time = 0
	game.hud.visible = false
	game.stats.visible = false
	game.player.blocked = true
	var zoo: ZooRoom = game.world as ZooRoom
	if zoo == null:
		print("zoo_capture: the game is not in the zoo (%s)" % game.world)
		quit(1)
		return
	for _i: int in 1800:
		await process_frame
		if _i > 30 and zoo.fauna != null and zoo.fauna._jobs.is_empty():
			break
	for _i: int in 30:
		await process_frame
	var missing: PackedStringArray = []
	for pen: Dictionary in zoo.pens:
		var kinds: Dictionary = {}
		for g: Node in zoo.fauna.groups.get(pen["slot"], []):
			if not is_instance_valid(g):
				continue
			var kind: String = str(g.get("def").id)
			kinds[kind] = int(kinds.get(kind, 0)) + ((g as CatBand).count() if g is CatBand else (g as MultiMeshInstance3D).multimesh.instance_count)
		print("  %s: %s" % [pen["slot"], kinds])
		for want: String in EXPECT.get(pen["slot"], []):
			if not kinds.has(want):
				missing.append("%s has no %s" % [pen["slot"], want])
	print("zoo_capture: %s; %s" % ["every pen holds its animals" if missing.is_empty() else "MISSING: " + ", ".join(missing), zoo.fauna.stats])
	if overlay:
		zoo.fauna.show_overlay(true)
	if DisplayServer.get_name() != "headless":
		var cam: Camera3D = game.player.camera
		await _shot(game, cam, Vector3(2.0, 1.6, 2.5), Vector3(2.0, 1.4, -20.0), out_dir + "/corridor.png")
		for p: Dictionary in ZooRoom.PENS:
			var r: Rect2 = ZooRoom._span(p)
			var left: bool = int(p["side"]) < 0
			var door := Vector3(r.end.x - 0.8 if left else r.position.x + 0.8, 1.6, r.get_center().y)
			var into := Vector3(r.get_center().x, float(p["height"]) * 0.3, r.get_center().y)
			await _shot(game, cam, door, into, "%s/%s%s.png" % [out_dir, p["id"], "_overlay" if overlay else ""])
	main_script.room_override = ""
	quit(1 if expect and not missing.is_empty() else 0)


func _shot(game: Node, cam: Camera3D, eye: Vector3, at: Vector3, path: String) -> void:
	game.player.teleport(eye - Vector3(0, 1.62, 0))
	for _i: int in 40:
		await process_frame
		cam.global_position = eye
		cam.look_at(at, Vector3.UP)
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(path)
	cam.position = Vector3(0, 1.62, 0)

extends SceneTree
## Close pictures of the zoo's animals (needs a display; run `godot --headless
## --import` first):
##   godot --path . --resolution 1600x900 --audio-driver Dummy --script res://tests/zoo_closeups.gd -- <out dir>
## Writes cat.png, gecko.png, goldfish.png, barb.png, rat.png (one out on the
## floor) and bats.png. The animals take no notice of the camera.

var game: Node
var out_dir: String = "previews/zoo"


func _initialize() -> void:
	call_deferred("run")


func shot(eye: Vector3, at: Vector3, file: String, fov: float = 45.0) -> void:
	game.player.teleport(Vector3(eye.x, 0.1, eye.z))
	for i: int in 50:
		await process_frame
		game.player.camera.global_position = eye
		game.player.camera.look_at(at, Vector3.UP)
		game.player.camera.fov = fov
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png("%s/%s" % [out_dir, file])


func run() -> void:
	for a: String in OS.get_cmdline_user_args():
		if not a.begins_with("--"):
			out_dir = a
	DirAccess.make_dir_recursive_absolute(out_dir)
	var main_script: GDScript = load("res://scripts/main.gd")
	main_script.room_override = ZooRoom.SCENE
	game = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	game.hud.visible = false
	game.stats.visible = false
	game.player.blocked = true
	var zoo: ZooRoom = game.world
	for i: int in 900:
		await process_frame
		if i > 30 and zoo.fauna._jobs.is_empty():
			break
	zoo.fauna.ignore_player = true
	for g: Node in zoo.fauna.groups.get("home", []):
		if g is CatBand:
			var p: Vector3 = ((g as CatBand).cats[0]["body"] as Node3D).global_position
			await shot(p + Vector3(1.1, 0.9, 1.1), p + Vector3(0, 0.15, 0), "cat.png")
	for g: Node in zoo.fauna.groups.get("lamps", []):
		if g is GeckoWall:
			var k: Dictionary = (g as GeckoWall).geckos[(g as GeckoWall).geckos.size() - 1]
			var p: Vector3 = k["home"]
			await shot(p + (k["normal"] as Vector3) * 1.0 + (k["side"] as Vector3) * 0.5, p, "gecko.png")
	await shot(Vector3(-6.0, 1.6, -3.2), Vector3(-6.0, 0.3, -6.0), "goldfish.png", 55.0)
	for g: Node in zoo.fauna.groups.get("cistern", []):
		if g is FishSchool:
			var p: Vector3 = (g as FishSchool).position
			await shot(Vector3(p.x + 1.2, 1.3, p.z + 1.2), p, "barb.png", 50.0)
			break
	for g: Node in zoo.fauna.groups.get("ruin", []):
		if g is RatPack:
			var pack := g as RatPack
			pack.tame = true
			game.player.teleport(Vector3(10.0, 0.1, -38.0))
			for i: int in 1500:
				await process_frame
				var out: Array = pack.rats.filter(func(r: Dictionary) -> bool: return float(r["out"]) > 1.0)
				if not out.is_empty():
					var p: Vector3 = pack.where(out[0])
					var n: Vector3 = pack.runs[int(out[0]["run"])]["normal"]
					game.player.camera.global_position = p + n * 0.9 + Vector3(0.3, 0.7, 0.3)
					game.player.camera.look_at(p, Vector3.UP)
					game.player.camera.fov = 45.0
					await process_frame
					break
			await RenderingServer.frame_post_draw
			root.get_viewport().get_texture().get_image().save_png("%s/rat.png" % out_dir)
	await shot(Vector3(6.0, 1.6, -22.0), Vector3(11.0, 8.0, -22.0), "bats.png", 70.0)
	main_script.room_override = ""
	quit()

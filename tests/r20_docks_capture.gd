extends SceneTree
## Phase 18 revised step 3: GPU pictures of every dock. The pier's ferry
## board, the flooded channel's board and the lantern boat at the quay, then
## a ride to each destination in the table: the dock from the deck on
## arrival, from its stage and from its water, and its lantern boat. Needs a
## display, not --headless; run `godot --headless --import` first.
##   godot --path . --resolution 1600x900 --script res://tests/r20_docks_capture.gd -- <out dir>
## Writes docks_<name>.png and prints draw calls and GPU time for each.

const SCENE: String = "res://rooms/lake/landing.tscn"
## Ride 1 of step 3: the views you reported at the Forgotten City dock
## (id, eye, forward), with the ferry lying there.
const REPORT_VIEWS: Array = [
	["floating_rocks", Vector3(-317.273, 0.754, -423.825), Vector3(-0.95, -0.166, -0.266)],
	["ferry_rail", Vector3(-320.097, 0.696, -427.144), Vector3(0.831, -0.469, 0.298)],
	["ferryman", Vector3(-320.43, 0.695, -431.186), Vector3(0.07, -0.235, -0.969)],
	["ferry_whole", Vector3(-319.886, 0.696, -432.397), Vector3(0.017, 0.08, 0.997)],
]

var game: Node
var ferry: LakeFerry
var life: Node
var out_dir: String


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else "user://r20_docks"
	DirAccess.make_dir_recursive_absolute(out_dir)
	var ws: Node = root.get_node_or_null("/root/WorldState")
	ws.data["world_seed"] = 1
	ws.data.erase("lake")
	var main_script: GDScript = load("res://scripts/main.gd")
	main_script.room_override = SCENE
	game = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	current_scene = game
	for _i: int in 20:
		await physics_frame
	game.hud.toast_time = 0
	game.hud.visible = false
	game.stats.visible = false
	game.player.blocked = false
	ferry = game.world.get_node("Ferry") as LakeFerry
	life = game.world.get_node("Life")
	# The quay: the pier's board, the dark channel's board, the lantern boat.
	game.player.set_flying(true)
	await look(Vector3(6.35, 1.6, -33.8), Vector3(6.35, 1.2, -37.2), "quay_ferry_board")
	await look(Vector3(-12.4, 0.2, -30.9), Vector3(-16.6, 0.0, -34.6), "quay_dark_board")
	await lantern_at("quay", 30.0)
	await look(Vector3(1.5, 0.4, -45.0), life.get("_far_boat").global_position, "quay_lantern_boat")
	for dest: String in ["mahaleh", "gardens", "forgotten"]:
		game.player.set_flying(false)
		await board()
		ferry.ask(dest)
		var t: float = 0.0
		while t < 120.0 and not (not ferry.moving() and ferry.at == dest):
			await physics_frame
			t += 1.0 / Engine.physics_ticks_per_second
		var style: String = LakeLayout.style_of(dest)
		await shot("%s_%s_deck" % [dest, style])
		if dest == "forgotten":
			for v: Array in REPORT_VIEWS:
				game.player.set_flying(true)
				var eye: Vector3 = v[1]
				await look(eye, eye + (v[2] as Vector3), "report_" + str(v[0]))
		var f: Transform3D = LakeLayout.dock_frame(style)
		game.player.set_flying(true)
		await look(f * Vector3(3.5, 0.7, -5.0), f * Vector3(-1.0, 2.5, 1.0), "%s_%s_front" % [dest, style])
		await look(f * Vector3(-6.0, 1.4, -27.0), f * Vector3(0.0, 2.0, 0.0), "%s_%s_water" % [dest, style])
		await look(f * Vector3(-5.9, 0.6, -5.6), f * Vector3(-5.9, 0.95, -2.6), "%s_%s_sign" % [dest, style])
		await lantern_at(style, 40.0)
		await look(f * Vector3(-4.5, 0.7, -5.6), life.get("_far_boat").global_position, "%s_%s_lantern_boat" % [dest, style])
		game.player.set_flying(false)
	main_script.room_override = ""
	quit()


## Puts the player in the middle of the docked deck, facing the bow.
func board() -> void:
	game.player.teleport(ferry.body.global_transform * Vector3(0.0, LakeFerry.DECK + 0.1, -1.0), ferry.body.global_rotation.y)
	for _i: int in 20:
		await physics_frame


## The lantern boat `t` seconds into a crossing through `place`.
func lantern_at(place: String, t: float) -> void:
	var seed_value: int = int(life.get("seed_value"))
	life.set("_far_clock", LakeLife.LANTERN_PERIOD * 5.0 + t - float(seed_value % 60))
	life.set("_far_round", 5)
	life.call("_lantern_route", place)
	for _i: int in 4:
		await process_frame
	var b: Node3D = life.get("_far_boat")
	print("  lantern boat at %s: %s, visible %s, clock %.1f round %d place %s seed %d ferry %s" % [place, b.global_position, b.visible, life.get("_far_clock"), life.get("_far_round"), life.get("_far_place"), life.get("seed_value"), (game.world.get_node("Ferry") as Node).get("place")])


## Flies the camera (the player's eye) to `eye` looking at `at` and takes a picture.
func look(eye: Vector3, at: Vector3, moment: String) -> void:
	var d: Vector3 = at - eye
	game.player.teleport(eye - Vector3(0.0, 1.62, 0.0), atan2(-d.x, -d.z), atan2(d.y, Vector2(d.x, d.z).length()))
	for _i: int in 40:
		await physics_frame
	await shot(moment)


func shot(moment: String) -> void:
	for _i: int in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var path: String = out_dir.path_join("docks_%s.png" % moment)
	root.get_viewport().get_texture().get_image().save_png(path)
	var vp_rid: RID = root.get_viewport().get_viewport_rid()
	var calls: int = RenderingServer.viewport_get_render_info(vp_rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)
	print("  %s: place %s, draw calls %d, gpu %.2f ms -> %s" % [moment, ferry.place, calls,
		RenderingServer.viewport_get_measured_render_time_gpu(vp_rid), path])

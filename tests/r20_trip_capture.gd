extends SceneTree
## Phase 18 revised step 2: GPU pictures of one ferry trip through the fog,
## the quay to the Mahaleh dock, seen standing on the deck facing the bow,
## then the dock from its stage and from its water. Needs a display, not
## --headless; run `godot --headless --import` first.
##   godot --path . --resolution 1600x900 --script res://tests/r20_trip_capture.gd -- <out dir>
## Writes trip_<moment>.png and prints draw calls and GPU time for each.

const SCENE: String = "res://rooms/lake/landing.tscn"

var game: Node
var ferry: LakeFerry
var out_dir: String


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else "user://r20_trip"
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
	# On the deck, a step aft of the middle, facing the bow.
	game.player.teleport(ferry.body.global_transform * Vector3(-0.4, LakeFerry.DECK + 0.1, 0.8), ferry.body.global_rotation.y, -0.05)
	for _i: int in 30:
		await physics_frame
	await shot("quay_deck")
	ferry.ask("mahaleh")
	var moments: Array = [
		["leaving", func() -> bool: return ferry._leg == 0 and ferry.phase == LakeFerry.Phase.CRUISE and ferry._s > 4.0],
		["fog_closing", func() -> bool: return ferry._leg == 0 and ferry.phase == LakeFerry.Phase.CRUISE and ferry._curve.get_baked_length() - ferry._s < 9.0],
		["in_fog", func() -> bool: return ferry.phase == LakeFerry.Phase.FOG and ferry._hold < 1.0],
		["emerging", func() -> bool: return ferry._leg == 1 and ferry._s > 10.0],
		["channel_in", func() -> bool: return ferry._leg == 1 and ferry._s > 24.0],
		["approach", func() -> bool: return ferry.phase == LakeFerry.Phase.ARRIVE and ferry._curve.get_baked_length() - ferry._s < 9.0],
		["docked", func() -> bool: return not ferry.moving() and ferry.at == "mahaleh"],
	]
	var t: float = 0.0
	var k: int = 0
	while k < moments.size() and t < 120.0:
		await physics_frame
		t += 1.0 / Engine.physics_ticks_per_second
		game.player.rotation.y = ferry.body.global_rotation.y      # keep facing the bow
		if (moments[k][1] as Callable).call():
			await shot(str(moments[k][0]))
			k += 1
	# The dock from its stage, and from out on its water (flying).
	var f: Transform3D = LakeLayout.dock_frame("mahaleh")
	game.player.teleport(f * Vector3(-1.5, -0.85, -5.3), f.basis.get_euler().y + PI + 0.1, 0.32)
	for _i: int in 40:
		await physics_frame
	await shot("dock_front")
	game.player.set_flying(true)
	game.player.teleport(f * Vector3(-6.0, 0.6, -27.0), f.basis.get_euler().y + PI + 0.15, 0.12)
	for _i: int in 40:
		await physics_frame
	await shot("dock_water")
	game.player.teleport(f * Vector3(1.0, 0.6, -14.0), f.basis.get_euler().y - 0.6, 0.0)
	for _i: int in 40:
		await physics_frame
	await shot("dock_channel")
	main_script.room_override = ""
	quit()


func shot(moment: String) -> void:
	for _i: int in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var path: String = out_dir.path_join("trip_%s.png" % moment)
	root.get_viewport().get_texture().get_image().save_png(path)
	var vp_rid: RID = root.get_viewport().get_viewport_rid()
	var calls: int = RenderingServer.viewport_get_render_info(vp_rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)
	print("  %s: at %s, place %s, draw calls %d, gpu %.2f ms -> %s" % [moment, ferry.body.global_position, ferry.place,
		calls, RenderingServer.viewport_get_measured_render_time_gpu(vp_rid), path])

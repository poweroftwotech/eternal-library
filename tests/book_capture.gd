extends SceneTree
## Phase 3 step 3 GPU captures through the real game, HUD included (needs a
## real display):
##   godot --path . --resolution 1600x900 --script res://tests/book_capture.gd -- <out_prefix>
## In R01, facing the entrance recess with the Hollow Index:
##   <prefix>_aim.png      the gilt spine highlighted, prompt "Pull out The Hollow Index"
##   <prefix>_pulled.png   pulled half out, prompt "Take The Hollow Index"
##   <prefix>_taken.png    the empty slot
##   <prefix>_satchel.png  J: the field notes with the satchel
##   <prefix>_read.png     Read: the book open
## Uses a scratch save (test runs never touch the player's).

var main_script: GDScript = load("res://scripts/main.gd")
var game: Node


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var prefix: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://book"
	main_script.room_override = "res://rooms/authored/reading_room.tscn"
	game = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	for _i: int in 30:
		await physics_frame
	var socket := game.world.get_node("Shell/wall_shelfbay_4m/Mesh/M_wall_shelfbay_4m/SOCKET_recess_fill") as VariantSocket
	var fill: ShelfFill = socket.spawned().filter(func(n: Node) -> bool: return n is ShelfFill).front()
	var li: int = fill.lore_index[&"lore_hollow_index"]
	var spine: Vector3 = fill.to_global(fill.built_transforms[li].origin + Vector3(0, 0, -0.1))
	game.player.teleport(Vector3(2.4, 0.05, spine.z), 0.0)     # clear of the arcade columns (x 1.4)
	for _i: int in 3:
		await physics_frame
	game.look_toward(spine)
	for _i: int in 3:
		await physics_frame
	game.look_toward(spine)     # again, from where the player settled
	await shot(prefix + "_aim.png")
	game.interact(game.player.get_target())
	for _i: int in 30:
		await physics_frame
	await shot(prefix + "_pulled.png")
	game.interact(game.player.get_target())
	await shot(prefix + "_taken.png")
	game.show_notes()
	await shot(prefix + "_satchel.png")
	game.on_choice("read:lore_hollow_index")
	await shot(prefix + "_read.png")
	quit(0)


func shot(path: String) -> void:
	for _i: int in 40:
		await process_frame
	var err: Error = root.get_viewport().get_texture().get_image().save_png(path)
	print("book_capture: ", "saved " + path if err == OK else "FAILED " + error_string(err))

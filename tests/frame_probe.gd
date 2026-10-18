extends SceneTree
## Layout helper for the concept framing (ART_DIRECTION.md backlog 5).
## godot --headless --script res://tests/frame_probe.gd -- u,v,y [u,v,y ...]
## For each screen fraction (u,v) of the concept camera, prints the world point
## where that pixel's ray meets the horizontal plane at height y. It also
## prints the screen fraction of a few existing camp anchors.

func _initialize() -> void:
	call_deferred("probe")

func probe() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.player.blocked = true
	game.player.teleport(Vector3(-1.05,.08,9.0))
	game.player.camera.position.y = 1.45
	game.player.camera.fov = 62
	game.look_toward(Vector3(-1.1,1.25,-2.4))
	root.size = Vector2i(1600,900)
	await process_frame
	var camera: Camera3D = game.player.camera
	var size: Vector2 = Vector2(1600,900)
	for arg: String in OS.get_cmdline_user_args():
		var parts: PackedStringArray = arg.split(",")
		var pixel: Vector2 = Vector2(float(parts[0]),float(parts[1]))*size
		var plane_y: float = float(parts[2])
		var origin: Vector3 = camera.project_ray_origin(pixel)
		var direction: Vector3 = camera.project_ray_normal(pixel)
		var t: float = (plane_y-origin.y)/direction.y
		print("screen %s y=%.2f -> world %s" % [arg, plane_y, str((origin+direction*t).snapped(Vector3.ONE*.01))])
	for anchor: Vector3 in [game.world.hearth+Vector3(0,.7,0),Vector3(-3.45,.54,5.4),Vector3(1.7,.09,5.8),Vector3(2.7,.25,4.6),Vector3(3.7,.3,5.0),Vector3(-5.0,2.5,2.6),Vector3(-4.3,.3,3.6),Vector3(8.6,.2,-3.0)]:
		print("anchor %s -> screen %s" % [str(anchor),str((camera.unproject_position(anchor)/size).snapped(Vector2.ONE*.01))])
	quit()

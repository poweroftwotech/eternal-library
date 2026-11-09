extends SceneTree
## One kind of animal on its own, close up on a plain floor under a work light
## (phase 19): does the model read? Needs a display.
##   godot --path . --resolution 1600x900 --audio-driver Dummy --script res://tests/creature_look.gd -- <out.png> [def id] [count]

func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://creature_look.png"
	var id: String = args[1] if args.size() > 1 else "goldfish"
	var count: int = int(args[2]) if args.size() > 2 else 6
	var def: CreatureDef = load("res://actors/defs/%s.tres" % id)
	var scene := Node3D.new()
	root.add_child(scene)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.15, 0.17, 0.2)
	env.environment.ambient_light_color = Color(0.6, 0.62, 0.66)
	env.environment.ambient_light_energy = 0.6
	scene.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-60, 30, 0)
	scene.add_child(sun)
	var floor_mesh := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(4, 4)
	floor_mesh.mesh = pm
	floor_mesh.position.y = -0.4
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.45, 0.42, 0.38)
	floor_mesh.material_override = fm
	scene.add_child(floor_mesh)
	var body := WaterBody.new()
	body.surface = 0.0
	body.bounds = AABB(Vector3(-1, -0.1, -1), Vector3(2, 0.1, 2))
	body.tris = PackedVector2Array([Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, -1), Vector2(1, 1), Vector2(-1, 1)])
	for x: int in 5:
		for z: int in 5:
			body.samples.append(Vector3(-0.6 + x * 0.3, -0.4, -0.6 + z * 0.3))
	var group: MultiMeshInstance3D
	if def.build == "swarm":
		var s := FishSchool.new()
		scene.add_child(s)
		s.setup(def, body, count, 7, Vector3.ZERO)
		group = s
	else:
		var p := FishPool.new()
		scene.add_child(p)
		p.setup(def, body, count, 7)
		group = p
	var cam := Camera3D.new()
	scene.add_child(cam)
	cam.position = Vector3(0, 0.55, 0.55)
	cam.look_at(Vector3(0, -0.15, 0))
	cam.fov = 50
	cam.current = true
	for _i: int in 30:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out)
	for i: int in group.multimesh.instance_count:
		print("  %d: %s" % [i, group.multimesh.get_instance_transform(i)])
	print("creature_look: %s x%d -> %s" % [id, count, out])
	quit()

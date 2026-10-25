extends SceneTree
## Bakes the gorge from kit pieces (phase-6-design.md 5.7.2, phase 6 step 1).
##   godot --headless --path . --script res://tools/bake_gorge.gd
## Writes, all yours to edit afterwards (re-baking overwrites them):
##   rooms/baked/gorge/bank_1.scn .. bank_8.scn, sanctum.scn, aqueducts.scn
##       GorgeGrammar's kit pieces, one scene per part of the gorge, each piece
##       its own instance;
##   rooms/baked/gorge/generated.scn
##       what stays generated, made once now by the gorge's own code
##       (vista.gd with its architecture switched off): the cavern, mist,
##       cascades, the far enclosure, the rock-cut stair and lamassu, the cliff
##       and loggia, the balcony, the lights (the lamp clusters from the kit's
##       lamps), the aqueducts' waterfalls and bank 4's rotunda, merged by
##       material as the camp merges its own;
##   rooms/baked/gorge/environment.tres
##       the camp's environment (fog, glow, grade), so the view matches;
##   rooms/baked/gorge.tscn
##       the scene the Gorge area adds: the environment, the generated part,
##       the kit parts under a KitBatcher (drawn in batches when it loads), and
##       a PlayerSpawn on the balcony facing the gorge;
##   rooms/gorge/overlook.tscn
##       the area's root room for now: the balcony's spawn (step 2 makes it
##       walkable).

const OUT_DIR: String = "res://rooms/baked/gorge/"
const MAIN: String = "res://rooms/baked/gorge.tscn"
const ROOT_ROOM: String = "res://rooms/gorge/overlook.tscn"
const LAYOUT: String = "res://gen/gorge/gorge_layout.tres"
## The overlook (capture.gd vista_concept): where you stand (your feet), what
## you face.
const EYE: Vector3 = Vector3(-1, 2.25, -27.45)
const FACING: Vector3 = Vector3(5, -22, -178)


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var t0: int = Time.get_ticks_usec()
	if OS.get_cmdline_user_args().has("--rebatch"):
		var parts: Array = ["bank_1", "bank_2", "bank_3", "bank_4", "bank_5", "bank_6", "bank_7", "bank_8", "sanctum", "aqueducts"]
		print("bake_gorge: rebatched %s" % rebatch(parts.filter(func(p: String) -> bool: return ResourceLoader.exists(OUT_DIR + p + ".scn"))))
		quit()
		return
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(ROOT_ROOM.get_base_dir())
	var environment: Environment = await camp_environment()
	ResourceSaver.save(environment, OUT_DIR + "environment.tres")
	# The kit parts.
	var layout: GorgeLayout = load(LAYOUT)
	var grammar := GorgeGrammar.new()
	var parts: Dictionary = {}
	for i: int in layout.banks.size():
		var b: PackedFloat32Array = layout.banks[i]
		parts["bank_%d" % (i + 1)] = grammar.bank(Vector2(b[0], b[1]), b[2], b[3], b[4], int(b[5]))
	parts["sanctum"] = grammar.sanctum(layout.sanctum)
	var aqueducts: Array[Dictionary] = []
	for a: PackedFloat32Array in layout.aqueducts:
		var falls: Array[int] = []
		for k: int in range(6, a.size()):
			falls.append(int(a[k]))
		aqueducts.append_array(grammar.aqueduct(Vector3(a[0], a[1], a[2]), Vector3(a[3], a[4], a[5]), falls))
	parts["aqueducts"] = aqueducts
	var counts: Dictionary = {}
	var extras: Array[Dictionary] = []
	var lamps := PackedVector3Array()
	for part: String in parts:
		counts[part] = save_part(part, parts[part], extras, lamps)
	# The generated part.
	var generated: Node3D = await generate(layout, extras, lamps)
	var generated_count: int = generated.find_children("*", "VisualInstance3D", true, false).size()
	save_scene(generated, OUT_DIR + "generated.scn")
	generated.free()
	# The batched kit, the scene the area adds, and its root room.
	var batched: Dictionary = rebatch(parts.keys())
	save_main()
	save_root_room()
	print("bake_gorge: %s; generated %d visuals; %d lamps; batched %s; %.1f s -> %s" % [counts, generated_count, lamps.size(), batched, (Time.get_ticks_usec() - t0) / 1000000.0, MAIN])
	quit()


## The camp's environment after every pass (the gorge has only ever been seen
## through it).
func camp_environment() -> Environment:
	var game: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	for _i: int in 3:
		await process_frame
	var environment: Environment = (game.world.environment as Environment).duplicate(true)
	game.queue_free()
	for _i: int in 3:
		await process_frame
	return environment


## One part's kit pieces as their own scene; collects its generated extras
## (waterfalls, the rotunda, lights) and lamps for the generated part.
func save_part(part: String, placements: Array[Dictionary], extras: Array[Dictionary], lamps: PackedVector3Array) -> int:
	var holder := Node3D.new()
	holder.name = part.to_pascal_case()
	var scenes: Dictionary = {}
	var placed: int = 0
	for p: Dictionary in placements:
		if not p.has("scene"):
			extras.append(p)
			continue
		var path: String = p["scene"]
		if path.ends_with("gorge_lamp.tscn"):
			lamps.append((p["xf"] as Transform3D).origin)
		elif path.contains("gorge_pavilion"):
			lamps.append((p["xf"] as Transform3D) * Vector3(0, 3.0, 0))
		if not scenes.has(path):
			scenes[path] = load(path)
		var node: Node3D = (scenes[path] as PackedScene).instantiate()
		node.transform = p["xf"]
		node.name = "%s_%d" % [path.get_file().get_basename(), placed]
		holder.add_child(node)
		node.owner = holder
		placed += 1
	for n: Node in holder.find_children("*", "VisualInstance3D", true, false):
		(n as VisualInstance3D).layers = 2     # the gorge's light layer, as vista.gd's
	save_scene(holder, OUT_DIR + part + ".scn")
	holder.free()
	return placed


## Runs the gorge's own code with its architecture switched off, plus the
## extras the kit parts asked for, into a node of its own.
func generate(layout: GorgeLayout, extras: Array[Dictionary], lamps: PackedVector3Array) -> Node3D:
	var vista_script: GDScript = load("res://scripts/vista.gd")
	var seeds := PackedInt32Array()
	for b: PackedFloat32Array in layout.banks:
		seeds.append(int(b[5]))
	vista_script.skip_banks = seeds
	vista_script.skip_bridges = true
	vista_script.skip_sanctum_tiers = true
	vista_script.extra_lamps = lamps
	var world_script: GDScript = load("res://scripts/world.gd")
	world_script.scenery_only = true
	var owner: Node3D = world_script.new()
	owner.name = "Generated"
	root.add_child(owner)
	owner.art = load("res://scripts/asset_factory.gd").new(owner)
	var vista: Object = vista_script.new(owner, owner.art)
	owner.vista = vista
	vista.build()
	owner.art.render_layer = 2
	for p: Dictionary in extras:
		if p.has("waterfall"):
			vista.waterfall(p["waterfall"], p["size"], false)
		elif p.has("rotunda"):
			vista.rotunda(p["rotunda"], p["radius"], p["height"])
		elif p.has("light"):
			owner.light(p["light"], p["color"], p["energy"], p["range"])
	owner.art.render_layer = 1
	owner.art.flush_batches()
	owner.art.merge_static_geometry()
	await process_frame
	# The merge hides what it merged; those copies aren't needed in the bake.
	for n: Node in owner.find_children("*", "MeshInstance3D", true, false):
		if not (n as MeshInstance3D).visible:
			n.free()
	# A plain node: world.gd as the saved root's script would build the camp on load.
	var out := Node3D.new()
	out.name = "Generated"
	for c: Node in owner.get_children():
		owner.remove_child(c)
		out.add_child(c)
	owner.queue_free()
	world_script.scenery_only = false
	adopt(out, out)
	return out


## Makes `owner` the owner of everything under `node` that a saved scene must
## hold: not the insides of instanced scenes (the lamassu), which load from
## their own files.
func adopt(node: Node, owner: Node) -> void:
	for c: Node in node.get_children():
		c.owner = owner
		if c.scene_file_path == "":
			adopt(c, owner)


## The kit parts batched (KitBatcher) into kit_batched.scn: the area loads 64
## MultiMeshes, not 61,000 pieces. Edit a part's scene, then rebatch
## (`-- --rebatch`).
func rebatch(parts: Array) -> Dictionary:
	var kit := KitBatcher.new()
	kit.name = "Kit"
	kit.batch_on_ready = false
	kit.render_layers = 2     # the gorge's light layer, as vista.gd's
	root.add_child(kit)
	for part: String in parts:
		kit.add_child((load(OUT_DIR + part + ".scn") as PackedScene).instantiate())
	var stats: Dictionary = kit.batch()
	for c: Node in kit.get_children():
		if not c is MultiMeshInstance3D:
			c.free()     # what's left of the pieces: anchors, kept for the walkable steps
		else:
			c.owner = kit
	root.remove_child(kit)
	save_scene(kit, OUT_DIR + "kit_batched.scn")
	kit.free()
	return stats


func save_main() -> void:
	var main := Node3D.new()
	main.name = "Gorge"
	var env := WorldEnvironment.new()
	env.name = "Environment"
	env.environment = load(OUT_DIR + "environment.tres")
	main.add_child(env)
	env.owner = main
	var generated: Node3D = (load(OUT_DIR + "generated.scn") as PackedScene).instantiate()
	main.add_child(generated)
	generated.owner = main
	var kit: Node = (load(OUT_DIR + "kit_batched.scn") as PackedScene).instantiate()
	main.add_child(kit)
	kit.owner = main
	var spawn := Marker3D.new()
	spawn.name = "PlayerSpawn"
	main.add_child(spawn)
	spawn.owner = main
	spawn.transform = Transform3D(Basis.looking_at(Vector3(FACING.x - EYE.x, 0, FACING.z - EYE.z)), EYE)
	save_scene(main, MAIN)
	main.free()


## The Gorge area's root room for step 1: only where you start, on the
## balcony (the balcony itself is in the generated part).
func save_root_room() -> void:
	var room := RoomTemplate.new()
	room.name = "Overlook"
	room.display_name = "The Overlook"
	var spawn := Marker3D.new()
	spawn.name = "PlayerSpawn"
	room.add_child(spawn)
	spawn.owner = room
	spawn.transform = Transform3D(Basis.looking_at(Vector3(FACING.x - EYE.x, 0, FACING.z - EYE.z)), EYE)
	save_scene(room, ROOT_ROOM)
	room.free()


func save_scene(node: Node, path: String) -> void:
	var scene := PackedScene.new()
	var err: Error = scene.pack(node)
	if err == OK:
		err = ResourceSaver.save(scene, path)
	if err != OK:
		push_error("bake_gorge: could not save %s (%s)" % [path, error_string(err)])

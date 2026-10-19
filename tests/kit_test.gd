extends SceneTree
## Phase 0 gate for the kit pipeline (ENVIRONMENT_PLAN.md section 10).
##   godot --headless --path . --script res://tests/kit_test.gd
## Checks the catalog, every wrapper scene, the graybox room, collision and a
## player-capsule route through the entrance arch. Exit code 1 on any failure.

const CATALOG: String = "res://kit/catalog.tres"
const GRAYBOX: String = "res://rooms/test/kit_graybox.tscn"
const STRUCTURAL: Array[int] = [KitModule.Shape.EDGE, KitModule.Shape.CELL, KitModule.Shape.POST]

var failures: PackedStringArray = []
var checks: int = 0


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures.append(what)


func run() -> void:
	var catalog: KitCatalog = load(CATALOG)
	check(catalog != null and catalog.modules.size() >= 9, "catalog has the 9 phase-0 modules")
	if catalog != null:
		for entry: Dictionary in catalog.modules:
			check_module(entry)
	check_wrapper_keeps_user_nodes()
	await check_graybox()
	print("kit_test: %d checks, %d failures" % [checks, failures.size()])
	for f: String in failures:
		print("  FAIL ", f)
	quit(1 if not failures.is_empty() else 0)


func check_module(entry: Dictionary) -> void:
	var name: String = entry["name"]
	var node: Node = (load(entry["scene"]) as PackedScene).instantiate()
	var module := node as KitModule
	check(module != null, "%s root is a KitModule" % name)
	if module == null:
		node.free()
		return
	check(module.get_node_or_null("Mesh") != null and module.get_node("Mesh").scene_file_path == module.source_glb,
		"%s has its .glb as the Mesh child" % name)
	var parts: Array[Node] = []
	collect(module, parts)
	var bodies: int = 0
	for n: Node in parts:
		if n is MeshInstance3D:
			var mesh: Mesh = (n as MeshInstance3D).mesh
			for i: int in mesh.get_surface_count():
				var mat: Material = mesh.surface_get_material(i)
				check(mat != null and mat.resource_path.begins_with("res://kit/materials/"),
					"%s/%s surface %d uses a kit library material" % [name, n.name, i])
		if n is StaticBody3D:
			bodies += 1
			check((n as StaticBody3D).collision_layer == 1, "%s collision is on layer 1" % name)
		if n is Node3D and n != module:
			check((n as Node3D).scale.is_equal_approx(Vector3.ONE), "%s/%s is unscaled" % [name, n.name])
	if module.shape in STRUCTURAL:
		check(bodies > 0, "%s (structural) has collision" % name)
	match name:
		"wall_shelfbay_4m":
			var sockets: Array = parts.filter(func(n: Node) -> bool: return n is VariantSocket and n.is_in_group("kit_socket"))
			check(sockets.size() == 1 and (sockets[0] as VariantSocket).socket_set != null,
				"shelf bay has a VariantSocket linked to its socket set")
			check(has_in_group(parts, "npc_anchor", "ANCHOR_browse"), "shelf bay has its NPC anchor")
		"wall_arch_3m":
			check(has_in_group(parts, "kit_snap", "SNAP_door"), "arch has its door connector")
		"lantern_hanging":
			var lights: int = parts.filter(func(n: Node) -> bool: return n is OmniLight3D).size()
			check(lights == 1, "lantern carries one OmniLight3D")
	node.free()


func has_in_group(parts: Array[Node], group: String, prefix: String) -> bool:
	for n: Node in parts:
		if String(n.name).begins_with(prefix) and n.is_in_group(group) and n is Marker3D:
			return true
	return false


func collect(node: Node, out: Array[Node]) -> void:
	out.append(node)
	for c: Node in node.get_children():
		collect(c, out)


## A node added to a wrapper by hand must survive a catalog refresh.
func check_wrapper_keeps_user_nodes() -> void:
	var path: String = "res://kit/modules/walls/wall_plain_4m.tscn"
	var original: String = FileAccess.get_file_as_string(path)
	var root: Node = (load(path) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	var extra := Node3D.new()
	extra.name = "UserExtra"
	root.add_child(extra)
	extra.owner = root
	var packed := PackedScene.new()
	packed.pack(root)
	ResourceSaver.save(packed, path)
	root.free()
	var builder := KitCatalogBuilder.new()
	builder.build()
	var again: Node = (ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE) as PackedScene).instantiate()
	check(again.get_node_or_null("UserExtra") != null, "catalog refresh keeps nodes added to a wrapper")
	check(again.get_node_or_null("Mesh") != null, "catalog refresh keeps the Mesh child")
	again.free()
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(original)
	f.close()
	ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE)


func check_graybox() -> void:
	var packed: PackedScene = load(GRAYBOX)
	check(packed != null, "graybox scene loads")
	if packed == null:
		return
	var room: Node3D = packed.instantiate()
	root.add_child(room)
	var problems: PackedStringArray = KitValidate.scene(room)
	for p: String in problems:
		print("  validate: ", p)
	check(problems.is_empty(), "graybox passes KitValidate (%d modules)" % KitValidate.count_modules(room))
	check_sockets(room)
	await physics_frame
	await physics_frame
	var space: PhysicsDirectSpaceState3D = room.get_world_3d().direct_space_state
	for k: int in 3:
		var hit: Dictionary = ray(space, Vector3(2, 3.0, -2 - k * 4), Vector3(2, -1, -2 - k * 4))
		check(not hit.is_empty() and absf((hit["position"] as Vector3).y) < 0.05, "floor collision in bay %d" % k)
	var wall: Dictionary = ray(space, Vector3(2, 1.0, -6), Vector3(-2, 1.0, -6))
	check(not wall.is_empty() and absf((wall["position"] as Vector3).x - 0.3) < 0.05, "west wall inner face at x = 0.3")
	var vault: Dictionary = ray(space, Vector3(2, 6, -6), Vector3(2, 14, -6))
	check(not vault.is_empty() and (vault["position"] as Vector3).y > 9.0, "vault crown above 9 m")
	# Player capsule (radius .35, height 1.8): through the arch is free, through a wall is blocked.
	var body := CharacterBody3D.new()
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	shape.shape = capsule
	body.add_child(shape)
	body.collision_mask = 1
	room.add_child(body)
	body.global_position = Vector3(2, 0.95, 2.5)
	await physics_frame
	check(not motion_blocked(body, Vector3(0, 0, -5)), "player capsule walks in through the entrance arch")
	body.global_position = Vector3(2, 0.95, -6)
	await physics_frame
	check(motion_blocked(body, Vector3(-3, 0, 0)), "player capsule is stopped by the west wall")
	room.queue_free()
	await process_frame


## Phase 1 sockets: deterministic per seed, varied across seeds, pinnable, and
## the picked dressing actually builds books.
func check_sockets(room: Node3D) -> void:
	var tmpl := room as RoomTemplate
	check(tmpl != null, "graybox root is a RoomTemplate")
	if tmpl == null:
		return
	var sockets: Array[VariantSocket] = tmpl.sockets()
	check(sockets.size() == 10, "graybox has 10 recess sockets (found %d)" % sockets.size())
	var a: Dictionary = tmpl.resolve_sockets(1)
	var b: Dictionary = tmpl.resolve_sockets(1)
	check(a == b, "same seed gives the same socket picks")
	var varied: bool = false
	for s: int in range(2, 8):
		if tmpl.resolve_sockets(s) != a:
			varied = true
	check(varied, "different seeds give different socket picks")
	var books: int = 0
	for s: VariantSocket in sockets:
		for c: Node in s.get_children(true):
			if c is ShelfFill and (c as ShelfFill).multimesh != null:
				books += (c as ShelfFill).multimesh.instance_count
	check(books > 300, "picked dressing builds books (%d)" % books)
	var first: VariantSocket = sockets[0]
	first.pinned = 2
	var pinned_ok: bool = true
	for s: int in range(1, 6):
		tmpl.resolve_sockets(s)
		pinned_ok = pinned_ok and first.last_pick == 2
	check(pinned_ok, "a pinned socket keeps its candidate across seeds")
	first.pinned = -1
	# Room pins (Kit dock Sockets panel): win over the seed and the module's own
	# pin, and go away cleanly.
	var key: String = tmpl.socket_key(first)
	var free_pick: int = tmpl.resolve_sockets(1)[key]
	var forced: int = (free_pick + 1) % first.candidate_count()
	tmpl.socket_pins = {key: forced}
	first.pinned = free_pick
	var room_pin_ok: bool = true
	for s: int in range(1, 6):
		room_pin_ok = room_pin_ok and tmpl.resolve_sockets(s)[key] == forced
	check(room_pin_ok, "a room pin wins over the seed and the module pin")
	first.pinned = -1
	tmpl.socket_pins = {}
	check(tmpl.resolve_sockets(1)[key] == free_pick, "clearing the room pin restores the seeded pick")
	tmpl.socket_pins = {"Shell/no_such_module/SOCKET": 0}
	check(tmpl.stale_pins().size() == 1, "a pin for a missing socket is reported stale")
	tmpl.socket_pins = {}
	tmpl.resolve_sockets(1)


func ray(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3) -> Dictionary:
	return space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 1))


func motion_blocked(body: CharacterBody3D, motion: Vector3) -> bool:
	var params := PhysicsTestMotionParameters3D.new()
	params.from = body.global_transform
	params.motion = motion
	return PhysicsServer3D.body_test_motion(body.get_rid(), params)

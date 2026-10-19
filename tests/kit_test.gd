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
	await check_stair_route()
	await check_stair_style()
	await check_gallery_style()
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
		"lantern_cluster":
			var lights: Array = parts.filter(func(n: Node) -> bool: return n is OmniLight3D)
			check(lights.size() == 1 and (lights[0] as Node).get_meta("light_profile", "") == "chandelier",
				"lantern cluster carries one chandelier light")
		"wall_iwan_12m":
			var sets: Array = parts.filter(func(n: Node) -> bool: return n is VariantSocket and (n as VariantSocket).socket_set != null) \
				.map(func(n: Node) -> String: return (n as VariantSocket).socket_set.resource_path.get_file())
			sets.sort()
			check(sets == ["arch_growth_iwan.tres", "iwan_centre.tres", "recess_library.tres", "seam_debris.tres", "seam_debris.tres"], "iwan has its back-wall recess, centrepiece, two flank seam sockets and arch growth (found %s)" % [sets])
			check(module.size_cells == Vector3i(3, 2, 0) and module.edge == "iwan", "iwan is a 3-bay, 2-storey edge")
		"stair_gallery_8m":
			check(has_in_group(parts, "kit_snap", "SNAP_stair_head") and has_in_group(parts, "kit_snap", "SNAP_stair_foot"),
				"stair has head and foot connectors")
		"stair_gallery_8m_r":
			var head: Array = parts.filter(func(n: Node) -> bool: return String(n.name).begins_with("SNAP_stair_head"))
			check(head.size() == 1 and (head[0] as Node3D).position.is_equal_approx(Vector3(0, 4.15, -0.95)),
				"reversed stair has its head at its origin end")
		"gallery_slab_4m_open_end", "gallery_slab_4m_open_start", "gallery_end_12m":
			# Polish 1c: the module keeps the rail as collision; the wooden look draws it.
			var look: Node = (load("res://kit/modules/dressing/gallery_wood_%s.tscn" % {"gallery_slab_4m_open_end": "open_end",
				"gallery_slab_4m_open_start": "open_start", "gallery_end_12m": "end"}[name]) as PackedScene).instantiate()
			var rail: Array = look.find_children("*rail*", "MeshInstance3D", true, false)
			var span: AABB = (rail[0] as MeshInstance3D).get_aabb() if not rail.is_empty() else AABB()
			var want: Vector2 = {"gallery_slab_4m_open_end": Vector2(0.0, 2.44), "gallery_slab_4m_open_start": Vector2(1.56, 4.0),
				"gallery_end_12m": Vector2(1.45, 10.55)}[name]
			check(absf(span.position.x - want.x) < 0.02 and absf(span.end.x - want.y) < 0.02,
				"%s rail spans x %.2f-%.2f (found %.2f-%.2f)" % [name, want.x, want.y, span.position.x, span.end.x])
			look.free()
		"table_reading":
			check(parts.filter(func(n: Node) -> bool: return n.is_in_group("npc_anchor")).size() == 6, "reading table has 6 seat anchors")
		"rug_runner":
			var rug: MeshInstance3D = parts.filter(func(n: Node) -> bool: return n is MeshInstance3D)[0]
			check(rug.mesh.surface_get_format(0) & Mesh.ARRAY_FORMAT_TEX_UV != 0, "rug runner keeps its UVs (rug map is UV-mapped)")
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
	var recess: int = sockets.filter(func(s: VariantSocket) -> bool: return s.socket_set != null and s.socket_set.resource_path.ends_with("recess_library.tres")).size()
	check(recess == 10, "graybox has 10 recess sockets (found %d)" % recess)
	check(sockets.size() == 42, "graybox has 42 sockets: 10 recesses, 3 lamp states, 5 wall seams, 6 gallery looks, 6 copings, 1 arch, 3 floors, 5 wall stains, 3 soot (found %d)" % sockets.size())
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


## Phase 1 step 1: a player capsule walks from the floor up stair_gallery_8m
## onto a gallery slab (move_and_slide with gravity, like the real player).
func check_stair_route() -> void:
	var rig := Node3D.new()
	root.add_child(rig)
	for x: float in [-4.0, 0.0, 4.0, 8.0]:
		var fl: Node3D = (load("res://kit/modules/walls/floor_4m.tscn") as PackedScene).instantiate()
		fl.position = Vector3(x, 0, 0)
		rig.add_child(fl)
	var stair: Node3D = (load("res://kit/modules/walls/stair_gallery_8m.tscn") as PackedScene).instantiate()
	rig.add_child(stair)
	var slab: Node3D = (load("res://kit/modules/walls/gallery_slab_4m.tscn") as PackedScene).instantiate()
	slab.position = Vector3(8, 0, 0)
	rig.add_child(slab)
	var body := CharacterBody3D.new()
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	shape.shape = capsule
	body.add_child(shape)
	body.collision_mask = 1
	rig.add_child(body)
	body.global_position = Vector3(-1.5, 0.95, -0.95)
	await physics_frame
	for _i: int in 360:
		body.velocity.x = 3.0
		body.velocity.y = 0.0 if body.is_on_floor() else body.velocity.y - 9.8 / 60.0
		body.move_and_slide()
		await physics_frame
		if body.global_position.x > 9.5:
			break
	var feet: Vector3 = body.global_position - Vector3(0, 0.9, 0)
	check(feet.x > 9.0 and absf(feet.y - 4.15) < 0.1,
		"player capsule climbs the gallery stair onto the slab (feet at %s)" % feet)
	rig.queue_free()
	await process_frame



## Item 4 and polish slice A: a gallery stair's look is a stair_style socket
## (stair_style_r on the reversed stair, mirrored so the railing stays on the
## open edge). The module keeps only what routes need: a ramp slab that is
## open underneath, an invisible rail strip and the snaps. Each look fills the
## footprint, starts at the foot snap and brings its railing on the open edge;
## masonry also brings the solid fill under the slab and claims the wall base.
func check_stair_style() -> void:
	for m: String in ["stair_gallery_8m", "stair_gallery_8m_r"]:
		var lib: SocketSet = load("res://kit/sockets/%s.tres" % ("stair_style_r" if m.ends_with("_r") else "stair_style"))
		var node: KitModule = (load("res://kit/modules/walls/%s.tscn" % m) as PackedScene).instantiate()
		root.add_child(node)
		var visible: Array[Node] = node.find_children(m + "*", "MeshInstance3D", true, false)
		check(visible.is_empty(), "%s has no visible mesh of its own (the look brings steps and railing)" % m)
		check(lowest_ramp_point_under(node, 6.5 if m == "stair_gallery_8m" else 1.5) > 2.5,
			"%s ramp is a slab, open underneath at the high end" % m)
		var sockets: Array[Node] = node.find_children("SOCKET_stair_style*", "VariantSocket", true, false)
		check(sockets.size() == 1, "%s has one stair_style socket" % m)
		if sockets.size() == 1:
			var s := sockets[0] as VariantSocket
			check(s.socket_set == lib and s.transform.is_equal_approx(Transform3D(Basis.IDENTITY, Vector3(4.0, 0.0, -0.95))),
				"%s socket uses %s, mid-footprint, unturned (%s)" % [m, lib.resource_path.get_file(), s.transform])
			check(lib.index_of("masonry") == 0 and lib.index_of("open wood") == 1, "%s set keeps the shared label order" % m)
			for label: String in ["masonry", "open wood"]:
				s.resolve(1, lib.index_of(label))
				await process_frame
				var box: AABB
				var low_end: float = 0.0     # x of the lowest step top: the foot
				var lowest: float = INF
				var rail_z: float = 0.0      # z of the railing mesh (the open edge is z -1.6)
				var bodies: int = 0
				var claims: int = 0
				for n: Node in s.get_children(true):
					bodies += n.find_children("*", "CollisionShape3D", true, false).size()
					claims += n.find_children("CLAIM_*", "Marker3D", true, false).filter(func(c: Node) -> bool: return c.has_meta("claim_box")).size()
					for mi: Node in n.find_children("*", "MeshInstance3D", true, false):
						var mesh_inst := mi as MeshInstance3D
						var b: AABB = mesh_inst.global_transform * mesh_inst.mesh.get_aabb()
						box = b if not box.has_volume() else box.merge(b)
						if String(mi.name).contains("rail") or String(mi.name).contains("parapet"):
							rail_z = b.get_center().z
						for p: Vector3 in mesh_inst.mesh.get_faces():
							var w: Vector3 = mesh_inst.global_transform * p
							if w.y > 0.1 and w.y < lowest:
								lowest = w.y
								low_end = w.x
				check(box.position.x > -0.03 and box.end.x < 8.03 and box.position.z > -1.63 and box.end.z < -0.29 and absf(box.position.y) < 0.01,
					"%s '%s' fills the stair footprint (%s)" % [m, label, box])
				var foot: float = 0.0 if m == "stair_gallery_8m" else 8.0
				check(absf(low_end - foot) < 0.5, "%s '%s' starts at the foot snap (lowest step at x %.2f)" % [m, label, low_end])
				check(rail_z < -1.4, "%s '%s' railing runs on the open edge (z %.2f)" % [m, label, rail_z])
				if label == "masonry":
					check_stone_balustrade(s, m)
				check((bodies > 0) == (label == "masonry"), "%s '%s' %s collision under the slab (%d shapes)" % [m, label, "has" if label == "masonry" else "has no", bodies])
				var want_claims: int = 2 if label == "masonry" else 1    # masonry: under + head (polish 1c)
				check(claims == want_claims, "%s '%s' claims %d boxes (%d)" % [m, label, want_claims, claims])
		node.queue_free()
	await process_frame


## Lowest ramp collision point straight down from 5 m at
## stair-run x (module space, lane centre). A wedge reaches the floor (0); a
## slab stops at its underside.
## Polish 1c: gallery looks. Each gallery module keeps only its slab and rail
## collision and has one gallery_style socket at its origin. Wood draws the old
## slab and rail without collision. Masonry adds an arcade on the column line
## (z -1.4) between the column points, with collision, springing at 1.85 m.
## The column points (post_gallery_column[_corner]) bring a column whose
## abacus is at 1.85 m and arches that reach the wall face.
func check_gallery_style() -> void:
	var cols: Dictionary = {"gallery_slab_4m": [0.0, 4.0], "gallery_slab_4m_open_end": [0.0, 2.6],
		"gallery_slab_4m_open_start": [1.4, 4.0], "gallery_end_12m": [1.4, 10.6]}
	var parts: Dictionary = {"gallery_slab_4m": "slab", "gallery_slab_4m_open_end": "open_end",
		"gallery_slab_4m_open_start": "open_start", "gallery_end_12m": "end"}
	for m: String in cols:
		var node: Node3D = (load("res://kit/modules/walls/%s.tscn" % m) as PackedScene).instantiate()
		root.add_child(node)
		var own: Array = node.find_children("*", "MeshInstance3D", true, false).filter(
			func(n: Node) -> bool: return not String(n.name).contains("corbels") and not in_socket(n))
		check(own.is_empty(), "%s draws nothing of its own but corbels (%d meshes)" % [m, own.size()])
		check(node.find_children("*", "CollisionShape3D", true, false).size() >= 2, "%s keeps slab and rail collision" % m)
		var sockets: Array[Node] = node.find_children("SOCKET_gallery_style*", "VariantSocket", true, false)
		check(sockets.size() == 1, "%s has one gallery_style socket" % m)
		if sockets.size() != 1:
			node.queue_free()
			continue
		var s := sockets[0] as VariantSocket
		check(s.socket_set != null and s.socket_set.resource_path.ends_with("gallery_style_%s.tres" % parts[m])
			and s.socket_set.style_group == "gallery_build" and s.socket_set.index_of("masonry") == 0
			and s.socket_set.index_of("wood") == 1 and s.transform.is_equal_approx(Transform3D.IDENTITY),
			"%s socket: gallery_style_%s at the origin, masonry then wood, group gallery_build" % [m, parts[m]])
		for label: String in ["masonry", "wood"]:
			s.resolve(1, s.socket_set.index_of(label))
			await process_frame
			var bodies: int = 0
			var arcade := AABB()
			for n: Node in s.get_children(true):
				bodies += n.find_children("*", "CollisionShape3D", true, false).size()
				for mi: Node in n.find_children("*spandrels*", "MeshInstance3D", true, false):
					var mesh_inst := mi as MeshInstance3D
					arcade = mesh_inst.global_transform * mesh_inst.mesh.get_aabb()
			check((bodies > 0) == (label == "masonry"), "%s '%s' %s collision (%d shapes)" % [m, label, "has" if label == "masonry" else "has no", bodies])
			if label == "masonry":
				var want: Array = cols[m]
				check(absf(arcade.position.x - want[0]) < 0.01 and absf(arcade.end.x - want[1]) < 0.01
					and absf(arcade.position.z + 1.6) < 0.01 and absf(arcade.end.z + 1.2) < 0.01
					and absf(arcade.position.y - 1.85) < 0.01 and absf(arcade.end.y - 3.85) < 0.01,
					"%s masonry arcade spans the column points x %.1f-%.1f on the column line, 1.85-3.85 m (%s)" % [m, want[0], want[1], arcade])
		node.queue_free()
	for m: String in ["post_gallery_column", "post_gallery_column_corner"]:
		var node: Node3D = (load("res://kit/modules/walls/%s.tscn" % m) as PackedScene).instantiate()
		root.add_child(node)
		var sockets: Array[Node] = node.find_children("SOCKET_gallery_support*", "VariantSocket", true, false)
		check(sockets.size() == 1 and (sockets[0] as VariantSocket).socket_set.style_group == "gallery_build",
			"%s has one gallery_support socket in group gallery_build" % m)
		if sockets.size() == 1:
			var s := sockets[0] as VariantSocket
			var at := Vector3(1.4 if m.ends_with("corner") else 0.0, 0.0, -1.4)
			check(s.global_position.is_equal_approx(at), "%s origin on the wall line, column socket at %s (%s)" % [m, at, s.global_position])
			s.resolve(1, s.socket_set.index_of("wood"))
			check(s.get_children(true).is_empty(), "%s 'wood' places nothing" % m)
			s.resolve(1, s.socket_set.index_of("masonry"))
			await process_frame
			var column := AABB()
			var arms := AABB()
			var bodies: int = 0
			for n: Node in s.get_children(true):
				bodies += n.find_children("*", "CollisionShape3D", true, false).size()
				for mi: Node in n.find_children("*", "MeshInstance3D", true, false):
					var mesh_inst := mi as MeshInstance3D
					var b: AABB = s.global_transform.affine_inverse() * mesh_inst.global_transform * mesh_inst.mesh.get_aabb()    # socket space
					if String(mi.name).contains("__column"):
						column = b
					elif String(mi.name).contains("__spandrels"):
						arms = b
			check(absf(column.end.y - 1.85) < 0.01 and absf(column.position.y) < 0.01 and column.size.x < 0.65,
				"%s column stands 0-1.85 m, at most 0.64 m wide (%s)" % [m, column])
			check(arms.end.z > 1.1 and absf(arms.position.y - 1.85) < 0.01 and bodies >= 2,
				"%s arch reaches the wall face (z %.2f) from the abacus, with collision" % [m, arms.end.z])
			if m.ends_with("corner"):
				check(arms.position.x < -1.1, "%s second arch reaches the -X wall (x %.2f)" % [m, arms.position.x])
		node.queue_free()
	await process_frame


## Polish 1b: the masonry railing is an open stone balustrade: one turned
## baluster per tread between a foot and a head newel, under a handrail, all on
## the open edge.
func check_stone_balustrade(s: VariantSocket, m: String) -> void:
	var parts: Dictionary = {}
	for n: Node in s.get_children(true):
		for mi: Node in n.find_children("*", "MeshInstance3D", true, false):
			for part: String in ["balusters", "handrail", "newels", "parapet"]:
				if String(mi.name).contains(part):
					parts[part] = mi
	check(not parts.has("parapet") and parts.has("balusters") and parts.has("handrail") and parts.has("newels"),
		"%s masonry has a balustrade, not a parapet (%s)" % [m, parts.keys()])
	if not parts.has("balusters"):
		return
	var mesh_inst := parts["balusters"] as MeshInstance3D
	var columns: Dictionary = {}     # 0.4 m tread index -> baluster (separate turned columns)
	var z_lo: float = INF
	for p: Vector3 in mesh_inst.mesh.get_faces():
		var w: Vector3 = mesh_inst.global_transform * p
		columns[int(floorf(w.x / 0.4))] = true
		z_lo = minf(z_lo, w.z)
	check(columns.size() == 18 and not columns.has(0) and not columns.has(19),
		"%s masonry has 18 balusters, one per tread clear of the newels (%d)" % [m, columns.size()])
	check(z_lo > -1.6, "%s masonry balusters stand on the open edge (z from %.2f)" % [m, z_lo])
	var newels := parts["newels"] as MeshInstance3D
	var nb: AABB = newels.global_transform * newels.mesh.get_aabb()
	check(nb.position.x < 0.01 and nb.end.x > 7.99, "%s masonry has a newel at the foot and the head (%s)" % [m, nb])


func lowest_ramp_point_under(node: Node, x: float) -> float:
	var low: float = INF
	for cs: Node in node.find_children("*", "CollisionShape3D", true, false):
		if not String(cs.get_parent().name).contains("ramp"):
			continue
		var faces: PackedVector3Array = ((cs as CollisionShape3D).shape as ConcavePolygonShape3D).get_faces()
		var xf: Transform3D = (cs as Node3D).global_transform
		for i: int in range(0, faces.size(), 3):
			var hit: Variant = Geometry3D.ray_intersects_triangle(Vector3(x, 5.0, -0.95), Vector3.DOWN,
				xf * faces[i], xf * faces[i + 1], xf * faces[i + 2])
			if hit != null:
				low = minf(low, (hit as Vector3).y)
	return low


## True for nodes a VariantSocket placed (its picked candidate), not the module's own.
func in_socket(n: Node) -> bool:
	var p: Node = n.get_parent()
	while p != null:
		if p is VariantSocket:
			return true
		p = p.get_parent()
	return false

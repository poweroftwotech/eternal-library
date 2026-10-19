extends SceneTree
## Phase 1 step 3 gate: socket sets and the STATE / SCATTER / REPLACE modes.
##   godot --headless --path . --script res://tests/socket_modes_test.gd

const SETS: Dictionary = {
	"recess_library": ["full shelves", "sparse shelves", "collapsed", "tile panel", "sealed door"],
	"iwan_centre": ["lectern", "reading tree", "fountain"],
	"lamp_state": ["lit", "failing", "dark"],
	"table_props": ["book stack", "open book", "pot", "oil lamp", "scroll", "inkwell"],
	"seam_debris": ["nothing", "rubble", "fallen brick", "crack tuft", "moss", "fern"],
	"rail_growth": ["nothing", "ivy"],
}

var failures: PackedStringArray = []
var checks: int = 0


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures.append(what)


func run() -> void:
	check_sets()
	await check_recess()
	await check_lamp()
	await check_scatter()
	await check_iwan()
	await check_edge_scatter()
	await check_seam_settle()
	await check_rail_ivy()
	print("socket_modes_test: %d checks, %d failures" % [checks, failures.size()])
	for f: String in failures:
		print("  FAIL ", f)
	quit(1 if not failures.is_empty() else 0)


func check_sets() -> void:
	for set_name: String in SETS:
		var set: SocketSet = load("res://kit/sockets/%s.tres" % set_name)
		check(set != null, "%s loads" % set_name)
		if set == null:
			continue
		var labels: Array = set.entries.map(func(e: SocketEntry) -> String: return e.label)
		check(labels == SETS[set_name], "%s entries are %s (found %s)" % [set_name, SETS[set_name], labels])
		for e: SocketEntry in set.entries:
			if set_name == "lamp_state" or e.label == "nothing":
				check(e.scene == null, "%s '%s' has no scene (a state or a gap)" % [set_name, e.label])
			else:
				check(e.scene != null and e.scene.can_instantiate(), "%s '%s' has a scene" % [set_name, e.label])


## Module wrapper in the tree, with its one socket of `set_name`.
func module_socket(path: String, set_name: String) -> Array:
	var node: Node3D = (load(path) as PackedScene).instantiate()
	root.add_child(node)
	await process_frame
	var found: Array[Node] = node.find_children("*", "VariantSocket", true, false)
	var socket: VariantSocket = null
	for s: Node in found:
		if (s as VariantSocket).socket_set != null and (s as VariantSocket).socket_set.resource_path.ends_with(set_name + ".tres"):
			socket = s
	check(socket != null, "%s has a %s socket" % [path.get_file(), set_name])
	return [node, socket]


func internal(socket: VariantSocket) -> Array[Node]:
	return socket.get_children(true).filter(func(n: Node) -> bool: return not socket.get_children().has(n))


func check_recess() -> void:
	var pair: Array = await module_socket("res://kit/modules/walls/wall_shelfbay_4m.tscn", "recess_library")
	var node: Node3D = pair[0]
	var socket: VariantSocket = pair[1]
	var mesh_names: Array = node.find_children("*", "MeshInstance3D", true, false).map(func(n: Node) -> String: return n.name)
	check(not mesh_names.has("wall_shelfbay_4m__shelves"), "shelf bay mesh no longer bakes boards")
	if socket != null:
		for i: int in socket.candidate_count():
			socket.resolve(3, i)
			var kids: Array[Node] = internal(socket)
			check(kids.size() == 1, "recess candidate '%s' instances one scene" % socket.entry_label(i))
			if i <= 2 and kids.size() == 1:
				check(kids[0].get_node_or_null("Boards") != null, "'%s' brings its own boards" % socket.entry_label(i))
	node.queue_free()
	await process_frame


func check_lamp() -> void:
	var pair: Array = await module_socket("res://kit/modules/walls/lantern_hanging.tscn", "lamp_state")
	var node: Node3D = pair[0]
	var socket: VariantSocket = pair[1]
	if socket == null:
		return
	check(socket.mode == VariantSocket.Mode.STATE, "lamp socket is in STATE mode (from Blender socket_mode)")
	var light: OmniLight3D = node.find_children("*", "OmniLight3D", true, false)[0]
	var glow: MeshInstance3D = node.find_children("*body*", "MeshInstance3D", true, false)[0]
	var emit_surface: int = -1
	for i: int in glow.mesh.get_surface_count():
		if glow.mesh.surface_get_material(i).resource_name.begins_with("emit_"):
			emit_surface = i
	socket.resolve(1, 0)
	var base: float = light.get_meta("lamp_base_energy", -1.0)
	check(light.visible and is_equal_approx(light.light_energy, base), "lit: light on at full energy")
	check(glow.get_surface_override_material(emit_surface) == null, "lit: glass glows")
	socket.resolve(1, 1)
	check(internal(socket).any(func(n: Node) -> bool: return n is LampState), "failing: a flicker node runs")
	await process_frame
	await process_frame
	check(light.visible and light.light_energy < base, "failing: light dimmed (%.2f < %.2f)" % [light.light_energy, base])
	socket.resolve(1, 2)
	check(not light.visible, "dark: light off")
	check(glow.get_surface_override_material(emit_surface) == LampState.dark_glass(), "dark: glass no longer glows")
	check(internal(socket).is_empty(), "dark: no flicker node left behind")
	socket.resolve(1, 0)
	check(light.visible and is_equal_approx(light.light_energy, base), "back to lit restores the light")
	node.queue_free()
	await process_frame


func check_scatter() -> void:
	var pair: Array = await module_socket("res://kit/modules/walls/table_reading.tscn", "table_props")
	var node: Node3D = pair[0]
	var socket: VariantSocket = pair[1]
	if socket == null:
		return
	check(socket.mode == VariantSocket.Mode.SCATTER, "table socket is in SCATTER mode")
	check(socket.scatter_count == Vector2i(2, 5) and socket.scatter_extent.is_equal_approx(Vector2(0.5, 1.9)),
		"scatter settings come from Blender (count %s, extent %s)" % [socket.scatter_count, socket.scatter_extent])
	check(is_equal_approx(socket.position.y, 0.78), "table socket sits on the table top")
	var sizes_ok: bool = true
	var spacing_ok: bool = true
	var inside_ok: bool = true
	for seed_value: int in range(1, 30):
		socket.resolve(seed_value)
		var items: Array[Node] = internal(socket)
		sizes_ok = sizes_ok and items.size() >= 2 and items.size() <= 5 and items.size() == socket.last_count
		for a: int in items.size():
			var pa: Vector3 = (items[a] as Node3D).position
			inside_ok = inside_ok and absf(pa.x) <= 0.5 and absf(pa.z) <= 1.9 and is_zero_approx(pa.y)
			for b: int in range(a + 1, items.size()):
				spacing_ok = spacing_ok and pa.distance_to((items[b] as Node3D).position) >= 0.35 - 0.001
	check(sizes_ok, "scatter places 2-5 items")
	check(inside_ok, "scatter items stay on the table top")
	check(spacing_ok, "scatter items keep 0.35 m apart")
	socket.resolve(11)
	var first: Array = internal(socket).map(func(n: Node) -> Transform3D: return (n as Node3D).transform)
	socket.resolve(11)
	var again: Array = internal(socket).map(func(n: Node) -> Transform3D: return (n as Node3D).transform)
	check(first == again, "same seed, same table layout")
	socket.resolve(11, 2)
	var pots: Array = internal(socket).map(func(n: Node) -> String: return n.scene_file_path.get_file())
	check(not pots.is_empty() and pots.all(func(p: String) -> bool: return p == "prop_pot.tscn"),
		"pinning a scatter socket makes every item that entry")
	node.queue_free()
	await process_frame


func check_iwan() -> void:
	var pair: Array = await module_socket("res://kit/modules/walls/wall_iwan_12m.tscn", "iwan_centre")
	var node: Node3D = pair[0]
	var socket: VariantSocket = pair[1]
	if socket != null:
		var seen: Dictionary = {}
		for seed_value: int in range(1, 40):
			seen[socket.resolve(seed_value)] = true
		check(seen.size() == 3, "iwan centrepiece varies over all three candidates by seed")
	node.queue_free()
	await process_frame


## Weathering item 1: wall-base seams (EDGE_SCATTER) on the plain wall.
func check_edge_scatter() -> void:
	var pair: Array = await module_socket("res://kit/modules/walls/wall_plain_4m.tscn", "seam_debris")
	var node: Node3D = pair[0]
	var socket: VariantSocket = pair[1]
	if socket == null:
		node.queue_free()
		return
	check(socket.mode == VariantSocket.Mode.EDGE_SCATTER and socket.settle, "seam socket is EDGE_SCATTER with settle (from Blender)")
	check(is_equal_approx(socket.edge_length, 2.3) and socket.position.is_equal_approx(Vector3(0.85, 0, -0.3)),
		"seam starts 0.85 m in on the wall face and runs 2.3 m (%s, %.2f)" % [socket.position, socket.edge_length])
	var on_line: bool = true
	var spaced: bool = true
	var gaps: bool = false
	for seed_value: int in range(1, 40):
		socket.resolve(seed_value)
		var items: Array[Node] = internal(socket)
		gaps = gaps or items.size() < socket.scatter_count.y
		for a: int in items.size():
			var p: Vector3 = (items[a] as Node3D).position
			on_line = on_line and p.x >= -0.001 and p.x <= socket.edge_length + 0.001 and p.z <= 0.001 and p.z >= -socket.edge_depth - 0.001
			for b: int in range(a + 1, items.size()):
				spaced = spaced and p.distance_to((items[b] as Node3D).position) >= socket.scatter_spacing - 0.001
	check(on_line, "seam items stay on the strip along the wall (x 0..length, out to edge_depth)")
	check(spaced, "seam items keep scatter_spacing apart")
	check(gaps, "\"nothing\" picks leave gaps (fewer items than spots on some seeds)")
	socket.resolve(5)
	var first: Array = internal(socket).map(func(n: Node) -> Transform3D: return (n as Node3D).transform)
	socket.resolve(5)
	check(first == internal(socket).map(func(n: Node) -> Transform3D: return (n as Node3D).transform), "same seed, same seam")
	node.queue_free()
	await process_frame


## Seam items rest on the floor, on a gallery slab in front of an upper wall,
## and vanish in front of an upper wall with nothing below.
func check_seam_settle() -> void:
	var rubble: int = (load("res://kit/sockets/seam_debris.tres") as SocketSet).index_of("rubble")
	for case: Array in [["floor", 0.0, true, 0.0], ["gallery", 4.0, true, 4.15], ["nothing below", 4.0, false, -1.0]]:
		var rig := Node3D.new()
		root.add_child(rig)
		var wall: Node3D = (load("res://kit/modules/walls/wall_plain_4m.tscn") as PackedScene).instantiate()
		wall.position = Vector3(0, case[1], 0)
		rig.add_child(wall)
		if case[2]:
			var under: Node3D = (load("res://kit/modules/walls/%s.tscn" % ("floor_4m" if case[0] == "floor" else "gallery_slab_4m")) as PackedScene).instantiate()
			rig.add_child(under)
		var socket: VariantSocket = wall.find_children("*", "VariantSocket", true, false)[0]
		socket.resolve(3, rubble)
		var placed: int = socket.last_count
		for _i: int in 4:
			await physics_frame
		var items: Array[Node] = internal(socket)
		if case[3] < 0.0:
			check(placed > 0 and items.is_empty() and socket.last_count == 0,
				"seam over nothing: %d items placed, all removed (left %d)" % [placed, items.size()])
		else:
			var heights: Array = items.map(func(n: Node) -> float: return (n as Node3D).global_position.y)
			check(not items.is_empty() and heights.all(func(y: float) -> bool: return absf(y - case[3]) < 0.02),
				"seam on %s: items rest at %.2f (%s)" % [case[0], case[3], heights])
		rig.queue_free()
		await process_frame


## Weathering item 2: ivy hangs from gallery rails; plant cards sway.
func check_rail_ivy() -> void:
	var pair: Array = await module_socket("res://kit/modules/walls/gallery_slab_4m.tscn", "rail_growth")
	var node: Node3D = pair[0]
	var socket: VariantSocket = pair[1]
	if socket != null:
		check(socket.mode == VariantSocket.Mode.EDGE_SCATTER and not socket.settle, "rail socket hangs (EDGE_SCATTER, no settle)")
		check(socket.position.is_equal_approx(Vector3(0.65, 5.0, -1.51)), "rail socket sits on the rail top centre line (%s)" % socket.position)
		var ivy: int = socket.socket_set.index_of("ivy")
		socket.resolve(2, ivy)
		var items: Array[Node] = internal(socket)
		check(not items.is_empty() and items.all(func(n: Node) -> bool: return n.scene_file_path.ends_with("plant_ivy_hang.tscn")),
			"pinned to ivy, the rail grows ivy (%d)" % items.size())
		var low: float = INF
		for n: Node in items:
			for m: Node in n.find_children("*", "MeshInstance3D", true, false):
				var box: AABB = (m as MeshInstance3D).global_transform * (m as MeshInstance3D).get_aabb()
				low = minf(low, box.position.y)
		check(low < 4.6 and low > 3.6, "ivy hangs down the gallery edge (lowest leaf %.2f)" % low)
	node.queue_free()
	for plant: String in ["plant_crack_tuft", "plant_fern", "plant_ivy_hang"]:
		var p: Node = (load("res://kit/modules/dressing/%s.tscn" % plant) as PackedScene).instantiate()
		var swaying: bool = false
		for m: Node in p.find_children("*", "MeshInstance3D", true, false):
			var mat: Material = (m as MeshInstance3D).mesh.surface_get_material(0)
			swaying = swaying or (mat is ShaderMaterial and (mat as ShaderMaterial).shader.resource_path.ends_with("kit_foliage.gdshader"))
		check(swaying, "%s cards use the swaying foliage material" % plant)
		p.free()
	await process_frame

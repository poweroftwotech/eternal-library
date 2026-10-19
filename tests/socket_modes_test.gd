extends SceneTree
## Phase 1 step 3 gate: socket sets and the STATE / SCATTER / REPLACE modes.
##   godot --headless --path . --script res://tests/socket_modes_test.gd

const SETS: Dictionary = {
	"recess_library": ["full shelves", "sparse shelves", "collapsed", "tile panel", "sealed door"],
	"iwan_centre": ["lectern", "reading tree", "fountain"],
	"lamp_state": ["lit", "failing", "dark"],
	"table_props": ["book stack", "open book", "pot", "oil lamp", "scroll", "inkwell"],
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
			if set_name == "lamp_state":
				check(e.scene == null, "lamp_state '%s' is a state, not a scene" % e.label)
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

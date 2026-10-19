extends SceneTree
## Phase 1 step 3 gate: socket sets and the STATE / SCATTER / REPLACE modes;
## weathering items 1-4 (edge scatter, settle, plants, decals, stair looks);
## polish B growth (arch, cornice and coping ivy, the masonry gate).
##   godot --headless --path . --script res://tests/socket_modes_test.gd

const SETS: Dictionary = {
	"recess_library": ["full shelves", "sparse shelves", "collapsed", "tile panel", "sealed door"],
	"iwan_centre": ["lectern", "reading tree", "fountain"],
	"lamp_state": ["lit", "failing", "dark"],
	"table_props": ["book stack", "open book", "pot", "oil lamp", "scroll", "inkwell"],
	"seam_debris": ["nothing", "rubble", "fallen brick", "crack tuft", "moss", "fern"],
	"rail_growth": ["nothing", "ivy"],
	"wall_stains": ["nothing", "water stain", "water stain b", "damp and moss"],
	"floor_wear": ["nothing", "crack", "crack b", "damp patch", "moss"],
	"lamp_soot": ["soot", "faint soot", "nothing"],
	"stair_style": ["masonry", "open wood"],
	"stair_style_r": ["masonry", "open wood"],
	"gallery_style_slab": ["masonry", "wood"],
	"gallery_style_open_end": ["masonry", "wood"],
	"gallery_style_open_start": ["masonry", "wood"],
	"gallery_style_end": ["masonry", "wood"],
	"gallery_support": ["masonry", "wood"],
	"gallery_support_corner": ["masonry", "wood"],
	"arch_growth": ["nothing", "light", "heavy"],
	"arch_growth_iwan": ["nothing", "light", "heavy"],
	"cornice_growth": ["nothing", "short curtain", "long curtain"],
	"parapet_growth": ["nothing", "strands"],
	"parapet_growth_stair": ["nothing", "strands"],
	"parapet_growth_stair_r": ["nothing", "strands"],
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
	await check_decals()
	await check_style_groups()
	await check_growth()
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
			if set_name == "lamp_state" or e.label == "nothing" or (set_name.begins_with("gallery_support") and e.label == "wood"):
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


## Weathering item 2 (plant cards sway); polish B item 4: no vines on the gallery
## rails. The rail_growth set stays for reuse, but no gallery module carries it.
func check_rail_ivy() -> void:
	for g: String in ["gallery_slab_4m", "gallery_slab_4m_open_end", "gallery_slab_4m_open_start", "gallery_end_12m"]:
		var node: Node3D = (load("res://kit/modules/walls/%s.tscn" % g) as PackedScene).instantiate()
		var rails: Array[Node] = node.find_children("*", "VariantSocket", true, false).filter(
			func(s: Node) -> bool: return (s as VariantSocket).socket_set != null and (s as VariantSocket).socket_set.resource_path.ends_with("/rail_growth.tres"))
		check(rails.is_empty(), "%s has no rail_growth socket (found %d)" % [g, rails.size()])
		node.free()
	for plant: String in ["plant_crack_tuft", "plant_fern", "plant_ivy_hang"]:
		var p: Node = (load("res://kit/modules/dressing/%s.tscn" % plant) as PackedScene).instantiate()
		var swaying: bool = false
		for m: Node in p.find_children("*", "MeshInstance3D", true, false):
			var mat: Material = (m as MeshInstance3D).mesh.surface_get_material(0)
			swaying = swaying or (mat is ShaderMaterial and (mat as ShaderMaterial).shader.resource_path.ends_with("kit_foliage.gdshader"))
		check(swaying, "%s cards use the swaying foliage material" % plant)
		p.free()
	await process_frame


## Weathering item 3: decal sets, scenes on the 32 texel/m rule, socket frames
## (wall stains upright and projecting into the wall, floor wear down, soot up)
## and the decal render layer on architecture only.
func check_decals() -> void:
	for set_name: String in ["wall_stains", "floor_wear", "lamp_soot"]:
		var set: SocketSet = load("res://kit/sockets/%s.tres" % set_name)
		check(set.decals and set.slot_is_item == (set_name != "lamp_soot"), "%s is a decal set (slot per item: %s)" % [set_name, set.slot_is_item])
		for e: SocketEntry in set.entries:
			if e.scene == null:
				continue
			var n: Node = e.scene.instantiate()
			var d := n.get_node_or_null("Decal") as Decal
			check(d != null and d.cull_mask == KitModule.DECAL_LAYER and d.texture_albedo != null,
				"%s '%s' is a Decal on the decal layer only" % [set_name, e.label])
			if d != null and d.texture_albedo != null:
				var px := Vector2(d.texture_albedo.get_width(), d.texture_albedo.get_height())
				check(px.is_equal_approx(Vector2(d.size.x, d.size.z) * 32.0), "%s '%s' is 32 texels/m (%s px over %s m)" % [set_name, e.label, px, d.size])
			n.free()
	# Wall stains: socket Y out of the wall (-Z), Z up; items unspun, image top up.
	var pair: Array = await module_socket("res://kit/modules/walls/wall_plain_4m.tscn", "wall_stains")
	var socket: VariantSocket = pair[1]
	if socket != null:
		check(socket.global_basis.y.is_equal_approx(Vector3(0, 0, -1)) and socket.global_basis.z.is_equal_approx(Vector3.UP),
			"wall stain socket faces the room with Z up (%s)" % socket.global_basis)
		check(not socket.scatter_spin and socket.scatter_count == Vector2i(0, 2), "wall stains: 0-2, unspun")
		var decals: Array[Decal] = await first_decals(socket, "water stain")
		check(not decals.is_empty(), "pinned to water stain, the wall gets a stain")
		for d: Decal in decals:
			check(d.global_basis.y.dot(Vector3(0, 0, -1)) > 0.99 and d.global_basis.z.dot(Vector3.UP) < -0.99,
				"the stain projects into the wall with its image top up (%s)" % d.global_basis)
			check(absf(d.global_position.z + 0.3) < 0.01 and d.global_position.y > 1.2 and d.global_position.y < 2.8,
				"the stain sits on the wall face, mid-wall (%s)" % d.global_position)
	pair[0].queue_free()
	pair = await module_socket("res://kit/modules/walls/floor_4m.tscn", "floor_wear")
	socket = pair[1]
	if socket != null:
		check(socket.scatter_spin, "floor wear turns at random")
		for d: Decal in await first_decals(socket, "crack"):
			check(d.global_basis.y.dot(Vector3.UP) > 0.99 and d.texture_normal != null, "a floor crack projects down and has a groove normal map")
	pair[0].queue_free()
	for lamp: String in ["lantern_hanging", "lantern_cluster"]:
		pair = await module_socket("res://kit/modules/walls/%s.tscn" % lamp, "lamp_soot")
		socket = pair[1]
		if socket != null:
			socket.resolve(1, socket.socket_set.index_of("soot"))
			var d: Decal = internal(socket)[0].get_node("Decal") if not internal(socket).is_empty() else null
			check(d != null and d.global_basis.y.dot(Vector3.DOWN) > 0.99, "%s soot projects up" % lamp)
			check(d != null and is_equal_approx(d.global_position.y, 4.0 if lamp == "lantern_hanging" else 14.6),
				"%s soot sits at the chain top (%s)" % [lamp, d.global_position if d != null else "none"])
		pair[0].queue_free()
	for m: String in ["walls/wall_plain_4m", "walls/floor_4m", "walls/vault_hall_12m", "walls/post_pier", "walls/table_reading",
			"walls/rug_runner", "walls/lantern_hanging", "dressing/recess_shelves", "dressing/iwan_lectern"]:
		var n: Node = (load("res://kit/modules/%s.tscn" % m) as PackedScene).instantiate()
		var meshes: Array[Node] = n.find_children("*", "MeshInstance3D", true, false)
		var structural: bool = (n as KitModule).shape != KitModule.Shape.FREE
		check(not meshes.is_empty() and meshes.all(func(x: Node) -> bool:
				return (((x as MeshInstance3D).layers & KitModule.DECAL_LAYER) != 0) == structural and ((x as MeshInstance3D).layers & 1) != 0),
			"%s meshes are %son the decal layer" % [m, "" if structural else "not "])
		n.free()
	await process_frame


## Decals a scatter socket places when pinned to `label`, trying seeds until
## the 0-2 count gives at least one.
func first_decals(socket: VariantSocket, label: String) -> Array[Decal]:
	var out: Array[Decal] = []
	for seed_value: int in range(1, 20):
		socket.resolve(seed_value, socket.socket_set.index_of(label))
		if socket.last_count > 0:
			break
	await process_frame
	for n: Node in internal(socket):
		var d := n.get_node_or_null("Decal") as Decal
		if d != null:
			out.append(d)
	return out


## Polish 1c: a room builds its stairs, galleries and columns alike. Every
## unpinned socket in the "gallery_build" style group takes the room's one
## pick, seeds still vary it, and a pin still wins over the group.
func check_style_groups() -> void:
	var room: RoomTemplate = (load("res://rooms/authored/reading_room.tscn") as PackedScene).instantiate()
	var pins: Dictionary[String, int] = {}
	for key: String in room.socket_pins:
		if not (key.contains("SOCKET_stair_style") or key.contains("SOCKET_gallery_")):
			pins[key] = room.socket_pins[key]
	room.socket_pins = pins
	root.add_child(room)
	var members: Array[VariantSocket] = room.sockets().filter(
		func(s: VariantSocket) -> bool: return s.socket_set != null and s.socket_set.style_group == "gallery_build")
	check(members.size() == 15, "reading room has 15 gallery_build sockets: 2 stairs, 5 galleries, 8 columns (%d)" % members.size())
	var seen: Dictionary = {}
	var stone_seed: int = -1
	for seed_value: int in range(1, 13):
		var picks: Dictionary = room.resolve_sockets(seed_value)
		var group: Dictionary = {}
		for s: VariantSocket in members:
			group[picks[room.socket_key(s)]] = true
		check(group.size() == 1, "seed %d builds stairs, galleries and columns alike (%s)" % [seed_value, group.keys()])
		seen.merge(group)
		if group.has(0) and stone_seed < 0:
			stone_seed = seed_value
	check(seen.has(0) and seen.has(1), "seeds vary the build (%s)" % [seen.keys()])
	var stair_key: String = "Shell/stair_gallery_8m/Mesh/M_stair_gallery_8m/SOCKET_stair_style"
	pins[stair_key] = 1
	room.socket_pins = pins
	var pinned: Dictionary = room.resolve_sockets(stone_seed)
	check(pinned[stair_key] == 1 and pinned["Shell/gallery_end_12m/Mesh/M_gallery_end_12m/SOCKET_gallery_style"] == 0,
		"a pin wins over the group; the rest keep the room's pick (seed %d)" % stone_seed)
	room.queue_free()
	await process_frame


## Polish B item 5: growth candidates are ivy cards on the swaying material (with
## a vine tube where they cling); coping strands grow only on the masonry look
## and hang plumb on the pitched stair coping; cornice curtains face the hall.
func check_growth() -> void:
	for set_name: String in ["arch_growth", "arch_growth_iwan", "cornice_growth", "parapet_growth", "parapet_growth_stair", "parapet_growth_stair_r"]:
		var set: SocketSet = load("res://kit/sockets/%s.tres" % set_name)
		for e: SocketEntry in set.entries:
			if e.scene == null:
				continue
			var n: Node = e.scene.instantiate()
			var mats: Array = n.find_children("*", "MeshInstance3D", true, false).map(
				func(m: Node) -> String: return (m as MeshInstance3D).mesh.surface_get_material(0).resource_name)
			var foliage: Array = n.find_children("*", "MeshInstance3D", true, false).filter(func(m: Node) -> bool:
				var mat: Material = (m as MeshInstance3D).mesh.surface_get_material(0)
				return mat is ShaderMaterial and (mat as ShaderMaterial).shader.resource_path.ends_with("kit_foliage.gdshader"))
			var clings: bool = not set_name.begins_with("parapet")
			check(mats.has("ivy_leaf") and not foliage.is_empty() and (mats.has("vine") or not clings),
				"%s '%s': swaying ivy cards%s (%s)" % [set_name, e.label, " and a vine" if clings else "", mats])
			n.free()
	# The masonry gate on a gallery module previewed on its own.
	var pair: Array = await module_socket("res://kit/modules/walls/gallery_slab_4m.tscn", "parapet_growth")
	var node: Node3D = pair[0]
	var growth: VariantSocket = pair[1]
	var look: VariantSocket = node.find_children("*", "VariantSocket", true, false).filter(
		func(s: Node) -> bool: return (s as VariantSocket).socket_set.resource_path.ends_with("gallery_style_slab.tres"))[0]
	if growth != null:
		check(growth.needs_look == "masonry" and growth.mode == VariantSocket.Mode.EDGE_SCATTER and not growth.scatter_spin,
			"coping socket: EDGE_SCATTER, no spin, gated on the masonry look")
		growth.scatter_count = Vector2i(2, 2)
		growth.pinned = growth.socket_set.index_of("strands")
		look.pinned = look.socket_set.index_of("masonry")
		look.resolve(3)
		check(internal(growth).size() == 2, "masonry look: strands hang from the coping (%d)" % internal(growth).size())
		look.pinned = look.socket_set.index_of("wood")
		look.resolve(3)
		check(internal(growth).is_empty(), "wood look: no strands (%d)" % internal(growth).size())
	node.queue_free()
	# Plumb strands on the pitched stair coping.
	for stair: String in ["stair_gallery_8m", "stair_gallery_8m_r"]:
		pair = await module_socket("res://kit/modules/walls/%s.tscn" % stair, "parapet_growth_stair" + ("_r" if stair.ends_with("_r") else ""))
		node = pair[0]
		growth = pair[1]
		look = node.find_children("*", "VariantSocket", true, false).filter(
			func(s: Node) -> bool: return (s as VariantSocket).socket_set.resource_path.contains("stair_style"))[0]
		if growth != null:
			var pitch: float = rad_to_deg(growth.global_basis.x.angle_to(Vector3(growth.global_basis.x.x, 0, growth.global_basis.x.z)))
			check(absf(pitch - 27.4) < 0.5, "%s coping socket is pitched with the stair (%.1f deg)" % [stair, pitch])
			growth.scatter_count = Vector2i(1, 1)
			growth.pinned = growth.socket_set.index_of("strands")
			look.pinned = look.socket_set.index_of("masonry")
			look.resolve(5)
			var items: Array[Node] = internal(growth)
			if items.size() == 1:
				var box := AABB()
				var first: bool = true
				for m: Node in items[0].find_children("*", "MeshInstance3D", true, false):
					var xf: Transform3D = (m as MeshInstance3D).global_transform
					for v: Vector3 in (m as MeshInstance3D).mesh.get_faces():
						box = AABB(xf * v, Vector3.ZERO) if first else box.expand(xf * v)
						first = false
				check(box.size.x < 0.75 and box.size.y > 0.45, "%s strands hang plumb (%.2f wide, %.2f tall)" % [stair, box.size.x, box.size.y])
			else:
				check(false, "%s: one strand item placed (%d)" % [stair, items.size()])
		node.queue_free()
	# Cornice curtains: the strip runs along the bay and -Z faces into the hall.
	var vault: Node3D = (load("res://kit/modules/walls/vault_hall_12m.tscn") as PackedScene).instantiate()
	root.add_child(vault)
	var cornices: Array = vault.find_children("*", "VariantSocket", true, false).filter(
		func(s: Node) -> bool: return (s as VariantSocket).socket_set.resource_path.ends_with("cornice_growth.tres"))
	check(cornices.size() == 2, "the hall vault has two cornice sockets (%d)" % cornices.size())
	for s: Node in cornices:
		var c := s as VariantSocket
		var inward: Vector3 = -c.global_basis.z
		var toward_centre: float = signf(6.0 - c.global_position.x)
		check(absf(c.global_position.y - 8.0 + 4.0) < 0.01 and inward.x * toward_centre > 0.99 and absf(c.global_basis.x.z) > 0.99,
			"cornice socket at the springing (%s) faces the hall (%s)" % [c.global_position, inward])
	vault.queue_free()
	await process_frame

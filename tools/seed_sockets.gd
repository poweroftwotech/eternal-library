extends SceneTree
## Creates the phase-1 dressing scenes and socket sets, or adds what is missing
## to existing ones (ENVIRONMENT_PLAN.md 4.3, phase 1 steps 0 and 3).
##   godot --headless --path . --script res://tools/seed_sockets.gd
## Additive: existing entries, weights and hand edits are kept; only missing
## dressing scenes, board children and set entries (matched by label) are
## added. Run it after exporting kit_dressing.blend, which provides the
## kit/modules/dressing/*.tscn candidates. After that, tune kit/sockets/*.tres
## and kit/dressing/*.tscn in the editor.

const ShelfFillScript: Script = preload("res://scripts/world/shelf_fill.gd")
const DRESS: String = "res://kit/modules/dressing/"
## Table props are WorldProps (phase 3 slice 1): pushable scenes wrapping the dressing glbs.
const PROPS: String = "res://props/"

var made: PackedStringArray = []


func _initialize() -> void:
	var full: String = dressing("recess_books_full", 0.92, false, "recess_shelves")
	var sparse: String = dressing("recess_books_sparse", 0.45, false, "recess_shelves")
	var fallen: String = dressing("recess_books_fallen", 0.9, true, "recess_shelves_broken")
	socket_set("recess_library", [
		["full shelves", full, 6.0], ["sparse shelves", sparse, 3.0], ["collapsed", fallen, 1.0],
		["tile panel", DRESS + "recess_tile_panel.tscn", 1.0], ["sealed door", DRESS + "recess_sealed_door.tscn", 0.7]])
	socket_set("iwan_centre", [
		["lectern", DRESS + "iwan_lectern.tscn", 1.0], ["reading tree", DRESS + "iwan_tree.tscn", 1.0],
		["fountain", DRESS + "iwan_fountain.tscn", 1.0]])
	# STATE set: labels are LampState states, no scenes.
	socket_set("lamp_state", [["lit", "", 6.0], ["failing", "", 2.0], ["dark", "", 1.0]])
	socket_set("table_props", [
		["book stack", PROPS + "prop_book_stack.tscn", 3.0], ["open book", PROPS + "prop_book_open.tscn", 2.0],
		["pot", PROPS + "prop_pot.tscn", 1.5], ["oil lamp", PROPS + "prop_oil_lamp.tscn", 1.0],
		["scroll", PROPS + "prop_scroll.tscn", 1.5], ["inkwell", PROPS + "prop_inkwell.tscn", 1.0]])
	# Recess depth; fallen books and boards spill up to 1.35 m into the room and settle.
	slot("recess_library", AABB(Vector3(-1.5, 0.0, -0.3), Vector3(3.0, 3.7, 0.6)), AABB(Vector3(-1.5, 0.0, -1.35), Vector3(3.0, 0.6, 1.05)))
	slot("iwan_centre", AABB(Vector3(-2.25, 0.0, -1.65), Vector3(4.5, 3.5, 3.3)))   # lectern rug is the widest
	slot("table_props", AABB(Vector3(-0.7, 0.0, -2.2), Vector3(1.4, 0.45, 4.4)))    # the table top
	# Weathering items 1-2: what gathers at a wall base (EDGE_SCATTER): debris and the
	# plants rooting in it; "nothing" keeps most spots bare.
	socket_set("seam_debris", [["nothing", "", 6.0], ["rubble", DRESS + "debris_rubble.tscn", 2.0],
		["fallen brick", DRESS + "debris_brick.tscn", 1.0], ["crack tuft", DRESS + "plant_crack_tuft.tscn", 2.0],
		["moss", DRESS + "plant_moss_cushion.tscn", 1.5], ["fern", DRESS + "plant_fern.tscn", 1.0]])
	slot("seam_debris", AABB(Vector3(-0.35, 0.0, -0.35), Vector3(0.7, 0.4, 0.7)))   # one item (fern is the tallest)
	# Item 2: ivy hanging from gallery rails (EDGE_SCATTER along the rail top).
	socket_set("rail_growth", [["nothing", "", 5.0], ["ivy", DRESS + "plant_ivy_hang.tscn", 2.0]])
	slot("rail_growth", AABB(Vector3(-0.35, -1.35, -0.3), Vector3(0.7, 1.4, 0.4)))   # one strand bunch, hanging
	# Item 3: decals (40 x 80 maps = 1.25 x 2.5 m on walls, 40 x 40 = 1.25 m on
	# floors). Wall sockets are turned so their Y comes out of the wall and Z
	# points up; the scene turns the Decal so the image top is up. Slots are one
	# decal (slot_is_item); Validate Room adds each socket's scatter_extent.
	var wall := Vector3(1.25, 0.4, 2.5)
	socket_set("wall_stains", [["nothing", "", 3.0],
		["water stain", decal("stain_water_a", wall, true), 2.0],
		["water stain b", decal("stain_water_b", wall, true), 2.0],
		["damp and moss", decal("stain_damp_moss", wall, true), 1.5]])
	slot("wall_stains", AABB(-wall * 0.5, wall), AABB(), true, true)
	var floor := Vector3(1.25, 0.3, 1.25)
	socket_set("floor_wear", [["nothing", "", 4.0],
		["crack", decal("crack_floor_a", floor, false, true), 2.0],
		["crack b", decal("crack_floor_b", floor, false, true), 2.0],
		["damp patch", decal("damp_floor", floor), 1.5],
		["moss", decal("moss_floor", floor), 1.0]])
	# Floor decals turn at random, so the slot is the circle a 1.25 m square sweeps.
	slot("floor_wear", AABB(Vector3(-0.885, -0.15, -0.885), Vector3(1.77, 0.3, 1.77)), AABB(), true, true)
	# Soot on whatever is above a lamp (the socket's Y points down).
	var plume := Vector3(1.25, 0.7, 1.25)   # clears the wall line from a lamp 1 m out
	socket_set("lamp_soot", [["soot", decal("soot_plume", plume), 3.0],
		["faint soot", decal("soot_plume", plume, false, false, 0.55, "soot_faint"), 2.0], ["nothing", "", 1.0]])
	slot("lamp_soot", AABB(-plume * 0.5, plume), AABB(), false, true)
	# Item 4: the look of a gallery stair. The stair module keeps the ramp, rail
	# and snaps, so a pick never changes routes. No slot: the module owns its
	# footprint (the steps have always run past the pier at the stair's middle).
	socket_set("stair_style", [["masonry", DRESS + "stair_steps_masonry.tscn", 2.0],
		["open wood", DRESS + "stair_steps_open.tscn", 1.0]])
	# The reversed stair's looks, mirrored (the railing stays on the open edge).
	# Same labels and order, so a pin means the same look on either stair.
	socket_set("stair_style_r", [["masonry", DRESS + "stair_steps_masonry_r.tscn", 2.0],
		["open wood", DRESS + "stair_steps_open_r.tscn", 1.0]])
	# Polish 1c: gallery looks (one set per gallery module) and the columns that
	# carry the masonry arcade (nothing under a wooden gallery). Same order as
	# the stairs, and one style group, so a room builds all of them alike.
	for part: String in ["slab", "open_end", "open_start", "end"]:
		socket_set("gallery_style_" + part, [["masonry", DRESS + "gallery_masonry_%s.tscn" % part, 2.0],
			["wood", DRESS + "gallery_wood_%s.tscn" % part, 1.0]])
	socket_set("gallery_support", [["masonry", DRESS + "gallery_column.tscn", 2.0], ["wood", "", 1.0]])
	socket_set("gallery_support_corner", [["masonry", DRESS + "gallery_column_corner.tscn", 2.0], ["wood", "", 1.0]])
	for set_name: String in ["stair_style", "stair_style_r", "gallery_style_slab", "gallery_style_open_end",
			"gallery_style_open_start", "gallery_style_end", "gallery_support", "gallery_support_corner"]:
		style_group(set_name, "gallery_build")
	# Polish B item 5: growth where it grows (dressing family, swaying ivy). Arch
	# growth is a REPLACE pick per arch (one set per arch size); the cornice and
	# parapet sets are EDGE_SCATTER items. Slots are Godot local (Y up, -Z the room).
	socket_set("arch_growth", [["nothing", "", 3.0], ["light", DRESS + "growth_arch_3m_light.tscn", 2.0],
		["heavy", DRESS + "growth_arch_3m_heavy.tscn", 1.0]])
	slot("arch_growth", AABB(Vector3(-1.47, 2.0, -0.3), Vector3(2.94, 1.82, 0.4)))   # between the piers, under a gallery soffit
	socket_set("arch_growth_iwan", [["nothing", "", 3.0], ["light", DRESS + "growth_arch_iwan_light.tscn", 2.0],
		["heavy", DRESS + "growth_arch_iwan_heavy.tscn", 1.0]])
	slot("arch_growth_iwan", AABB(Vector3(-3.05, 4.05, -0.4), Vector3(6.1, 3.92, 0.5)))  # under the gable
	socket_set("cornice_growth", [["nothing", "", 3.0], ["short curtain", DRESS + "growth_cornice_short.tscn", 2.0],
		["long curtain", DRESS + "growth_cornice_long.tscn", 1.5]])
	slot("cornice_growth", AABB(Vector3(-0.85, -2.45, -0.3), Vector3(1.7, 2.6, 0.38)))   # one curtain
	socket_set("parapet_growth", [["nothing", "", 4.0], ["strands", DRESS + "growth_parapet_strands.tscn", 2.0]])
	slot("parapet_growth", AABB(Vector3(-0.3, -2.6, -0.4), Vector3(0.65, 2.7, 0.55)))
	# The stair copings are pitched; their candidates hang plumb, so the slot
	# (socket space) leans down the slope one way or the other.
	socket_set("parapet_growth_stair", [["nothing", "", 4.0], ["strands", DRESS + "growth_parapet_stair.tscn", 2.0]])
	socket_set("parapet_growth_stair_r", [["nothing", "", 4.0], ["strands", DRESS + "growth_parapet_stair_r.tscn", 2.0]])
	slot("parapet_growth_stair", AABB(Vector3(-0.75, -1.2, -0.4), Vector3(1.05, 1.42, 0.55)))
	slot("parapet_growth_stair_r", AABB(Vector3(-0.35, -1.2, -0.4), Vector3(1.15, 1.42, 0.55)))
	print("seed_sockets: ", "; ".join(made) if not made.is_empty() else "nothing to do")
	quit()


## A ShelfFill scene (books) with the recess boards as a child instance, since
## the shelf-bay mesh no longer carries boards (step 3).
func dressing(scene_name: String, density: float, fallen: bool, boards: String) -> String:
	var path: String = "res://kit/dressing/%s.tscn" % scene_name
	var node: MultiMeshInstance3D
	if ResourceLoader.exists(path):
		node = (load(path) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
	else:
		node = ShelfFillScript.new()
		node.name = scene_name
		node.set("density", density)
		node.set("fallen", fallen)
	var changed: bool = not ResourceLoader.exists(path)
	if node.get_node_or_null("Boards") == null:
		var b: Node3D = (load(DRESS + boards + ".tscn") as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
		b.name = "Boards"
		node.add_child(b)
		b.owner = node
		changed = true
	if changed:
		var uid: int = KitCatalogBuilder.header_uid(path)
		var packed := PackedScene.new()
		packed.pack(node)
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		ResourceSaver.save(packed, path)
		if uid != ResourceUID.INVALID_ID:
			ResourceSaver.set_uid(path, uid)
		made.append("updated " + path)
	node.free()
	return path


## specs: [label, scene path or "", weight]. Adds entries whose label is missing.
func socket_set(set_name: String, specs: Array) -> void:
	var path: String = "res://kit/sockets/%s.tres" % set_name
	var set: SocketSet = load(path) if ResourceLoader.exists(path) else SocketSet.new()
	var added: PackedStringArray = []
	for spec: Array in specs:
		if set.index_of(spec[0]) >= 0:
			continue
		var e := SocketEntry.new()
		e.label = spec[0]
		e.scene = load(spec[1]) if spec[1] != "" else null
		e.weight = spec[2]
		set.entries.append(e)
		added.append(spec[0])
	if added.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var uid: int = KitCatalogBuilder.header_uid(path) if ResourceLoader.exists(path) else ResourceUID.INVALID_ID
	ResourceSaver.save(set, path)
	if uid != ResourceUID.INVALID_ID:
		ResourceSaver.set_uid(path, uid)
	made.append("%s += %s" % [path, ", ".join(added)])


## A decal scene kit/decals/<scene_name>.tscn (default: the map's name), unless
## it exists: a Node3D whose Decal marks only KitModule.DECAL_LAYER. `upright`
## turns the Decal half a turn about Y, so on a wall socket (Y out, Z up) the
## image top is up.
func decal(map: String, size: Vector3, upright: bool = false, normal: bool = false,
		alpha: float = 1.0, scene_name: String = "") -> String:
	var path: String = "res://kit/decals/%s.tscn" % (scene_name if scene_name != "" else map)
	if ResourceLoader.exists(path):
		return path
	var root := Node3D.new()
	root.name = path.get_file().get_basename()
	var d := Decal.new()
	d.name = "Decal"
	d.size = size
	d.texture_albedo = load("res://assets/textures/decals/%s.png" % map)
	if normal:
		d.texture_normal = load("res://assets/textures/decals/%s_normal.png" % map)
	d.modulate = Color(1, 1, 1, alpha)
	d.cull_mask = KitModule.DECAL_LAYER
	d.normal_fade = 0.8       # surfaces turned away from the decal don't smear
	d.upper_fade = 0.3
	d.lower_fade = 0.3
	if upright:
		d.rotation_degrees = Vector3(0, 180, 0)
	root.add_child(d)
	d.owner = root
	var packed := PackedScene.new()
	packed.pack(root)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	ResourceSaver.save(packed, path)
	root.free()
	made.append("wrote " + path)
	return path


## Sets the slot Validate Room checks candidates against, unless one is set.
## Puts a set in a style group (SocketSet.style_group) unless it already has one.
func style_group(set_name: String, group: String) -> void:
	var path: String = "res://kit/sockets/%s.tres" % set_name
	var set: SocketSet = load(path)
	if set == null or set.style_group != "":
		return
	set.style_group = group
	var uid: int = KitCatalogBuilder.header_uid(path)
	ResourceSaver.save(set, path)
	if uid != ResourceUID.INVALID_ID:
		ResourceSaver.set_uid(path, uid)
	made.append("%s style_group = %s" % [path, group])


func slot(set_name: String, bounds: AABB, spill: AABB = AABB(), item: bool = false, decals: bool = false) -> void:
	var path: String = "res://kit/sockets/%s.tres" % set_name
	var set: SocketSet = load(path)
	if set == null or set.slot_bounds.has_volume():
		return
	set.slot_bounds = bounds
	set.spill_bounds = spill
	set.slot_is_item = item
	set.decals = decals
	var uid: int = KitCatalogBuilder.header_uid(path)
	ResourceSaver.save(set, path)
	if uid != ResourceUID.INVALID_ID:
		ResourceSaver.set_uid(path, uid)
	made.append("%s slot_bounds = %s" % [path, bounds])

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
		["book stack", DRESS + "prop_book_stack.tscn", 3.0], ["open book", DRESS + "prop_book_open.tscn", 2.0],
		["pot", DRESS + "prop_pot.tscn", 1.5], ["oil lamp", DRESS + "prop_oil_lamp.tscn", 1.0],
		["scroll", DRESS + "prop_scroll.tscn", 1.5], ["inkwell", DRESS + "prop_inkwell.tscn", 1.0]])
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

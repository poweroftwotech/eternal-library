extends SceneTree
## Creates the phase-1 dressing scenes and socket sets if they don't exist yet.
##   godot --headless --path . --script res://tools/seed_sockets.gd
## After that, edit kit/sockets/*.tres and kit/dressing/*.tscn in the editor.

const ShelfFillScript: Script = preload("res://scripts/world/shelf_fill.gd")


func _initialize() -> void:
	var made: PackedStringArray = []
	var full: String = dressing("recess_books_full", 0.92, false, made)
	var sparse: String = dressing("recess_books_sparse", 0.45, false, made)
	var fallen: String = dressing("recess_books_fallen", 0.9, true, made)
	var path: String = "res://kit/sockets/recess_library.tres"
	if not ResourceLoader.exists(path):
		var set := SocketSet.new()
		for spec: Array in [["full shelves", full, 6.0], ["sparse shelves", sparse, 3.0], ["collapsed", fallen, 1.0]]:
			var e := SocketEntry.new()
			e.label = spec[0]
			e.scene = load(spec[1])
			e.weight = spec[2]
			set.entries.append(e)
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		ResourceSaver.save(set, path)
		made.append(path)
	print("seed_sockets: ", "created " + ", ".join(made) if not made.is_empty() else "nothing to do")
	quit()


func dressing(scene_name: String, density: float, fallen: bool, made: PackedStringArray) -> String:
	var path: String = "res://kit/dressing/%s.tscn" % scene_name
	if ResourceLoader.exists(path):
		return path
	var node: MultiMeshInstance3D = ShelfFillScript.new()
	node.name = scene_name
	node.set("density", density)
	node.set("fallen", fallen)
	var packed := PackedScene.new()
	packed.pack(node)
	node.free()
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	ResourceSaver.save(packed, path)
	made.append(path)
	return path

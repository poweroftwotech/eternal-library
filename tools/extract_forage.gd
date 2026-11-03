extends SceneTree
## Cuts the camp's forage patches (rooms/camp/camp.tscn, Gatherables/herb_a,
## root_a, mushroom_a) out as kit/dressing/forage_<kind>.tscn, so the working
## niches (room rework step 2) grow the same plants as the camp. Each patch is
## moved to the origin (its foot on the floor); its meshes and materials are
## embedded in the new scene.
##   godot --headless --path . --script res://tools/extract_forage.gd

const PATCHES: Dictionary = {"herb_a": "herb", "root_a": "root", "mushroom_a": "mushroom"}


func _initialize() -> void:
	var camp: Node = (load("res://rooms/camp/camp.tscn") as PackedScene).instantiate()
	for id: String in PATCHES:
		var src := camp.get_node("Gatherables/" + id) as Node3D
		var patch := src.duplicate() as Node3D
		patch.name = "forage_" + PATCHES[id]
		patch.transform = Transform3D.IDENTITY
		for m: Node in patch.find_children("*", "", true, false):
			m.owner = patch
		var packed := PackedScene.new()
		packed.pack(patch)
		var path: String = "res://kit/dressing/forage_%s.tscn" % PATCHES[id]
		var err: Error = ResourceSaver.save(packed, path)
		print("extract_forage: %s -> %s (%d nodes) %s" % [id, path, patch.find_children("*", "", true, false).size(), error_string(err)])
		patch.free()
	camp.free()
	quit()

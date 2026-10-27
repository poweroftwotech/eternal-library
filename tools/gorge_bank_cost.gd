extends SceneTree
## What each part of the gorge costs (phase 8 step 4: the cost check on bank 1
## before its rules are copied to the other banks). Builds the parts as
## tools/bake_gorge.gd does and, for each, counts what KitBatcher makes of it:
##   pieces     kit pieces placed
##   triangles  their triangles (every instance: a MultiMesh draws all of its
##              instances once any of it is in view)
##   meshes     distinct meshes (each one batch, so about one draw call per
##              surface for the whole gorge, however many banks use it)
##   only here  meshes no other part uses: the draw calls this part adds
##   lights     lights it asks the bake for
## and the triangles by kit family and the heaviest pieces of each bank.
##   godot --headless --path . --script res://tools/gorge_bank_cost.gd [-- --top=12]

const LAYOUT: String = "res://gen/gorge/gorge_layout.tres"

var _meshes: Dictionary = {}     # scene path -> [[signature, triangles, surfaces]]
var _signatures: Dictionary = {}


func _initialize() -> void:
	var top: int = 12
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--top="):
			top = int(a.trim_prefix("--top="))
	var layout: GorgeLayout = load(LAYOUT)
	var grammar := GorgeGrammar.new()
	var parts: Dictionary = {}
	for i: int in layout.banks.size():
		var b: PackedFloat32Array = layout.banks[i]
		parts["bank_%d" % (i + 1)] = grammar.bank(Vector2(b[0], b[1]), b[2], b[3], b[4], int(b[5]))
	var cliff_script: GDScript = load("res://scripts/vista_cliff.gd")
	parts["cliff"] = PersianTown.new(grammar).cliff(cliff_script.FACADES, cliff_script.FACE_Z - .3)
	# Per part: signature -> [triangles per instance, surfaces], instances.
	var used: Dictionary = {}
	var rows: Dictionary = {}
	for part: String in parts:
		var row: Dictionary = {"pieces": 0, "triangles": 0, "lights": 0, "sigs": {}, "by_family": {}, "by_scene": {}}
		for p: Dictionary in parts[part]:
			if p.has("light"):
				row["lights"] += 1
			if not p.has("scene"):
				continue
			var path: String = p["scene"]
			row["pieces"] += 1
			var family: String = path.get_base_dir().get_file()
			for m: Array in _scene_meshes(path):
				row["triangles"] += int(m[1])
				row["by_family"][family] = int(row["by_family"].get(family, 0)) + int(m[1])
				row["by_scene"][path.get_file()] = int(row["by_scene"].get(path.get_file(), 0)) + int(m[1])
				row["sigs"][m[0]] = int(m[2])
				if not used.has(m[0]):
					used[m[0]] = {}
				used[m[0]][part] = true
		rows[part] = row
	print("%-9s %7s %10s %7s %10s %7s" % ["part", "pieces", "triangles", "meshes", "only here", "lights"])
	for part: String in rows:
		var row: Dictionary = rows[part]
		var own: int = 0
		var surfaces: int = 0
		for s: String in row["sigs"]:
			surfaces += int(row["sigs"][s])
			if (used[s] as Dictionary).size() == 1:
				own += int(row["sigs"][s])
		print("%-9s %7d %9.2fM %7d %10d %7d" % [part, row["pieces"], row["triangles"] / 1e6, surfaces, own, row["lights"]])
	# Meshes only the old-style banks use: their batches go when those banks
	# are rebuilt in the Persian kit (whose meshes bank 1 already draws).
	var old_banks: Array[String] = []
	for part: String in rows:
		if part.begins_with("bank_") and int(part.trim_prefix("bank_")) not in GorgeGrammar.PERSIAN_BANKS:
			old_banks.append(part)
	var freed: int = 0
	for s: String in used:
		var only_old: bool = true
		for part: String in used[s]:
			only_old = only_old and part in old_banks
		if only_old:
			freed += int(rows[(used[s] as Dictionary).keys()[0]]["sigs"][s])
	print("\nsurfaces only the old-style banks (%s) use: %d (about %d draw calls with the depth pass), gone once they are rebuilt" % [", ".join(old_banks), freed, freed * 2])
	for part: String in ["bank_1", "bank_2", "cliff"]:
		var row: Dictionary = rows[part]
		print("\n%s by family: %s" % [part, _sorted(row["by_family"], 8)])
		print("%s heaviest: %s" % [part, _sorted(row["by_scene"], top)])
	quit()


## [[signature, triangles, surfaces]] for each mesh in a kit scene.
func _scene_meshes(path: String) -> Array:
	if _meshes.has(path):
		return _meshes[path]
	var out: Array = []
	var node: Node = (load(path) as PackedScene).instantiate()
	for n: Node in node.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (n as MeshInstance3D).mesh
		if mesh == null:
			continue
		var tris: int = 0
		for i: int in mesh.get_surface_count():
			var arrays: Array = mesh.surface_get_arrays(i)
			var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			tris += (index.size() if index.size() > 0 else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
		out.append([KitBatcher._signature(mesh, _signatures), tris, mesh.get_surface_count()])
	node.free()
	_meshes[path] = out
	return out


func _sorted(d: Dictionary, n: int) -> String:
	var keys: Array = d.keys()
	keys.sort_custom(func(a: Variant, b: Variant) -> bool: return int(d[a]) > int(d[b]))
	var bits: PackedStringArray = []
	for k: Variant in keys.slice(0, n):
		bits.append("%s %.0fk" % [k, int(d[k]) / 1000.0])
	return ", ".join(bits)

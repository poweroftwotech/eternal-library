extends SceneTree
## Cuts kit pieces out of the code-built camp (phase 7,
## docs/environment/camp-rebuild-approval.md): builds the old camp (unmerged,
## without its gorge view), takes each piece of art_src/kit/camp/pieces.json
## (tools/camp_cut.gd) and writes it to art_src/kit/camp/src/<name>.glb in
## the piece's own frame: one mesh per material (slot names camp_<camp
## material>), the colours of instanced books and leaves kept as vertex
## colours, and its static collision as *-convcolonly hulls. Then
## tools/kit_add_camp.py brings them into kit_camp.blend.
## Needs a display (not --headless: the dummy renderer keeps no mesh data).
##   godot --path . --script res://tools/camp_extract.gd [-- --only=a,b] [--list] [--force-materials]
## Also copies each camp material a piece uses into the kit's library
## (kit/materials/camp_<name>.tres), unless it's there already (yours to
## tweak) or --force-materials. --list only prints what each piece would take.

const Cut = preload("res://tools/camp_cut.gd")
const World = preload("res://scripts/world.gd")
const OUT_DIR: String = "res://art_src/kit/camp/src/"
const LIB_DIR: String = "res://kit/materials/"


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var only := PackedStringArray()
	for a: String in args:
		if a.begins_with("--only="):
			only = a.trim_prefix("--only=").split(",")
	var listing: bool = args.has("--list")
	var force_mats: bool = args.has("--force-materials")
	OS.set_environment("ZFIGHT_NO_MERGE", "1")
	World.with_gorge = false
	var world: Node3D = World.new()
	root.add_child(world)
	for _i: int in 2:
		await process_frame
	var pieces: Array = Cut.load_pieces()
	var taken: Dictionary = Cut.cut(world, world.art, pieces)
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var unnamed: Dictionary = {}      # material instance id -> its kit name
	for piece: Dictionary in pieces:
		var name: String = piece["name"]
		if not only.is_empty() and not only.has(name):
			continue
		if piece.get("drop", false):
			print("camp_extract: %-26s dropped: %d meshes, %d instances, %d hulls" % [name, (taken[name]["meshes"] as Array).size(), (taken[name]["instances"] as Array).size(), (taken[name]["shapes"] as Array).size()])
			continue
		var t: Dictionary = taken[name]
		var inv: Transform3D = Cut.frame(piece).affine_inverse()
		var groups: Dictionary = {}       # kit material name -> {material, parts: [[mesh, surface, xf, color]]}
		for mi: MeshInstance3D in t["meshes"]:
			for s: int in mi.mesh.get_surface_count():
				var m: Material = mi.material_override if mi.material_override != null else mi.mesh.surface_get_material(s)
				_add(groups, _kit_name(world.art, m, unnamed), m, [mi.mesh, s, inv * mi.global_transform, Color.WHITE])
		for it: Array in t["instances"]:
			var mmi: MultiMeshInstance3D = it[0]
			var mm: MultiMesh = mmi.multimesh
			var m: Material = mmi.material_override
			var c: Color = mm.get_instance_color(it[1]) if mm.use_colors else Color.WHITE
			for s: int in mm.mesh.get_surface_count():
				_add(groups, _kit_name(world.art, m if m != null else mm.mesh.surface_get_material(s), unnamed), m,
					[mm.mesh, s, inv * mmi.global_transform * mm.get_instance_transform(it[1]), c])
		var tris: int = 0
		var line: PackedStringArray = []
		for k: String in groups:
			var n: int = 0
			for part: Array in groups[k]["parts"]:
				n += _triangles(part[0], part[1])
			tris += n
			line.append("%s %d" % [k, n])
		print("camp_extract: %-26s %4d meshes, %5d instances, %3d hulls, %6d triangles: %s" % [name, (t["meshes"] as Array).size(),
			(t["instances"] as Array).size(), (t["shapes"] as Array).size(), tris, ", ".join(line)])
		if listing and args.has("--where=" + name):
			var at: Dictionary = {}
			for mi: MeshInstance3D in t["meshes"]:
				var c: Vector3 = (mi.global_transform * mi.get_aabb()).get_center()
				var key: Vector3 = (c / 2.0).floor() * 2.0
				at[key] = int(at.get(key, 0)) + 1
			print("  where (2 m cells): ", at)
		if listing:
			continue
		var scene := Node3D.new()
		scene.name = name + "_cut"     # not the piece's name: a material may be called that too
		for k: String in groups:
			var mi := MeshInstance3D.new()
			mi.name = name + "__" + k.trim_prefix("camp_")
			mi.mesh = _merge(groups[k]["parts"], k)
			scene.add_child(mi)
			mi.owner = scene
		var i: int = 0
		for cs: CollisionShape3D in t["shapes"]:
			var hull: ArrayMesh = _hull(cs.shape)
			if hull == null:
				continue
			var mi := MeshInstance3D.new()
			mi.name = "%s_%d-convcolonly" % [name, i]
			mi.mesh = hull
			mi.transform = inv * cs.global_transform
			scene.add_child(mi)
			mi.owner = scene
			i += 1
		var doc := GLTFDocument.new()
		var state := GLTFState.new()
		var err: Error = doc.append_from_scene(scene, state)
		if err == OK:
			err = doc.write_to_filesystem(state, ProjectSettings.globalize_path(OUT_DIR + name + ".glb"))
		print("  -> %s%s.glb %s" % [OUT_DIR, name, "" if err == OK else "FAILED " + error_string(err)])
		scene.free()
		for k: String in groups:
			_save_material(k, groups[k]["material"], force_mats)
	quit()


func _add(groups: Dictionary, k: String, m: Material, part: Array) -> void:
	if not groups.has(k):
		groups[k] = {"material": m, "parts": []}
	(groups[k]["parts"] as Array).append(part)


## camp_<the factory's name>; a material the factory didn't name (a pass made
## it, as the lantern's glass) is named by what it looks like, so equal ones share.
func _kit_name(art: Object, m: Material, unnamed: Dictionary) -> String:
	var n: String = Cut.material_name(art, m)
	if n != "":
		return n if n.begins_with("camp_") else "camp_" + n
	var sig: String = "none"
	if m is StandardMaterial3D:
		var s := m as StandardMaterial3D
		sig = "%s|%s|%s|%s|%s|%s|%s" % [s.albedo_color, s.albedo_texture.resource_path if s.albedo_texture != null else "",
			s.emission_enabled, s.emission, s.transparency, s.shading_mode, s.billboard_mode]
	if not unnamed.has(sig):
		unnamed[sig] = "camp_x%06x" % (hash(sig) & 0xffffff)
	return unnamed[sig]


func _triangles(mesh: Mesh, s: int) -> int:
	var arr: Array = mesh.surface_get_arrays(s)
	if arr.is_empty():
		return 0
	return ((arr[Mesh.ARRAY_INDEX] as PackedInt32Array).size() if arr[Mesh.ARRAY_INDEX] != null else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3


## One surface from the parts: their vertices in the piece's frame, normals
## turned with them, UVs (or none), and colours (the instance's, times the
## mesh's own if it has some); the material a plain one named `k` (the kit
## swaps in its library material by that name on import).
func _merge(parts: Array, k: String) -> ArrayMesh:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	for part: Array in parts:
		var arr: Array = (part[0] as Mesh).surface_get_arrays(part[1])
		if arr.is_empty():
			continue
		var xf: Transform3D = part[2]
		var nb: Basis = xf.basis.inverse().transposed()
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var n: Variant = arr[Mesh.ARRAY_NORMAL]
		var uv: Variant = arr[Mesh.ARRAY_TEX_UV]
		var c: Variant = arr[Mesh.ARRAY_COLOR]
		var base: int = verts.size()
		for i: int in v.size():
			verts.append(xf * v[i])
			norms.append((nb * (n as PackedVector3Array)[i]).normalized() if n != null else Vector3.UP)
			uvs.append((uv as PackedVector2Array)[i] if uv != null else Vector2.ZERO)
			cols.append(((c as PackedColorArray)[i] if c != null else Color.WHITE) * (part[3] as Color))
		var src: Variant = arr[Mesh.ARRAY_INDEX]
		var flip: bool = xf.basis.determinant() < 0.0
		if src != null:
			var si: PackedInt32Array = src
			for i: int in range(0, si.size(), 3):
				if flip:
					idx.append_array([base + si[i], base + si[i + 2], base + si[i + 1]])
				else:
					idx.append_array([base + si[i], base + si[i + 1], base + si[i + 2]])
		else:
			for i: int in range(0, v.size(), 3):
				if flip:
					idx.append_array([base + i, base + i + 2, base + i + 1])
				else:
					idx.append_array([base + i, base + i + 1, base + i + 2])
	var out := ArrayMesh.new()
	var a: Array = []
	a.resize(Mesh.ARRAY_MAX)
	a[Mesh.ARRAY_VERTEX] = verts
	a[Mesh.ARRAY_NORMAL] = norms
	a[Mesh.ARRAY_TEX_UV] = uvs
	a[Mesh.ARRAY_COLOR] = cols
	a[Mesh.ARRAY_INDEX] = idx
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
	var plain := StandardMaterial3D.new()
	plain.resource_name = k
	plain.vertex_color_use_as_albedo = true
	out.surface_set_material(0, plain)
	return out


## A convex hull's points as a closed mesh (the import builds the hull from
## its vertices): boxes, cylinders and convex shapes; null for others.
func _hull(shape: Shape3D) -> ArrayMesh:
	var pts := PackedVector3Array()
	if shape is BoxShape3D:
		var h: Vector3 = (shape as BoxShape3D).size * .5
		for sx: int in [-1, 1]:
			for sy: int in [-1, 1]:
				for sz: int in [-1, 1]:
					pts.append(Vector3(h.x * sx, h.y * sy, h.z * sz))
	elif shape is CylinderShape3D:
		var cy := shape as CylinderShape3D
		for k: int in 12:
			var a: float = TAU * k / 12.0
			for y: float in [-cy.height * .5, cy.height * .5]:
				pts.append(Vector3(cos(a) * cy.radius, y, sin(a) * cy.radius))
	elif shape is ConvexPolygonShape3D:
		pts = (shape as ConvexPolygonShape3D).points
	else:
		return null
	# A fan over the points: never drawn, only its vertices matter.
	var idx := PackedInt32Array()
	for i: int in range(1, pts.size() - 1):
		idx.append_array([0, i, i + 1])
	var a: Array = []
	a.resize(Mesh.ARRAY_MAX)
	a[Mesh.ARRAY_VERTEX] = pts
	a[Mesh.ARRAY_INDEX] = idx
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
	return out


func _save_material(k: String, m: Material, force: bool) -> void:
	var path: String = LIB_DIR + k + ".tres"
	if m == null or (ResourceLoader.exists(path) and not force):
		return
	var copy: Material = m.duplicate()
	copy.resource_name = k
	var err: Error = ResourceSaver.save(copy, path)
	print("  material %s %s" % [path, "saved" if err == OK else "FAILED " + error_string(err)])

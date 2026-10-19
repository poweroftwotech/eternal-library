extends SceneTree
## Coplanar-overlap (z-fighting) audit over everything actually rendered.
## godot --path . --script res://tests/zfight_audit.gd -- [max_report]
## Needs a real renderer (not --headless): the dummy renderer keeps no
## MultiMesh transforms.
## Two surfaces only flicker when they look different, so an "owner" is one
## draw unit: a merged static group (one material), a MultiMesh batch, or a
## standalone mesh. Overlaps inside one owner share a material and are skipped.

const PLANE_TOLERANCE: float = .003       # metres between planes that still fight
const MIN_OVERLAP: float = .002           # m2; ignore slivers
const MIN_TRIANGLE: float = .0004

var buckets: Dictionary = {}
var owner_names: Array = []
var material_names: Dictionary = {}
var two_sided: Array = []                # owner -> material renders both faces
var owner_material: Array = []           # owner -> material (same-material overlaps render identically)

func _initialize() -> void:
	call_deferred("go")

func go() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	for i in range(3):
		await process_frame
	for key in game.world.art.materials:
		material_names[game.world.art.materials[key]] = key
	var started: int = Time.get_ticks_msec()
	for node in game.find_children("*", "GeometryInstance3D", true, false):
		if not node.is_visible_in_tree():
			continue
		if node is MeshInstance3D and node.mesh:
			add_mesh(node.mesh, node.global_transform, register(node, node.mesh))
		elif node is MultiMeshInstance3D and node.multimesh and node.multimesh.mesh:
			var mm: MultiMesh = node.multimesh
			var owner: int = register(node, mm.mesh)
			for i in range(mm.instance_count):
				add_mesh(mm.mesh, node.global_transform * mm.get_instance_transform(i), owner)
	print("ZFIGHT collected %d buckets in %.1fs" % [buckets.size(), (Time.get_ticks_msec() - started) / 1000.0])
	var pairs: Dictionary = find_overlaps()
	var rows: Array = []
	for key in pairs:
		rows.append(pairs[key])
	rows.sort_custom(func(a, b): return a.area > b.area)
	var limit: int = int(OS.get_cmdline_user_args()[0]) if OS.get_cmdline_user_args().size() else 40
	var region: String = OS.get_cmdline_user_args()[1] if OS.get_cmdline_user_args().size() > 1 else "all"
	if region == "near":
		rows = rows.filter(func(r): return r.at.z > -35.0 and absf(r.at.x) < 20.0 and r.at.y > -2.0 and r.at.y < 20.0)
	print("ZFIGHT %d fighting owner pairs" % rows.size())
	for i in range(mini(limit, rows.size())):
		var r: Dictionary = rows[i]
		print("ZFIGHT %7.2f m2 x%-5d %-30s | %-30s at %s n %s" % [r.area, r.count, owner_names[r.a], owner_names[r.b], r.at.snapped(Vector3.ONE * .01), r.n.snapped(Vector3.ONE * .01)])
	game.queue_free()
	for i in 8:
		await process_frame
	quit()

func register(node: GeometryInstance3D, mesh: Mesh) -> int:
	var material: Material = node.material_override
	if material == null and mesh.get_surface_count() > 0:
		material = mesh.surface_get_material(0)
	var label: String = str(node.name).left(24)
	if material:
		label = str(node.name).left(10) + "/" + material_names.get(material, material.resource_name if material.resource_name != "" else "?")
		if node is MeshInstance3D and not str(node.name).begins_with("Merged"):
			var xf: Transform3D = node.global_transform
			label = material_names.get(material, "?") + " c" + str(xf.origin.snapped(Vector3.ONE * .01)) + " s" + str(xf.basis.get_scale().snapped(Vector3.ONE * .01))
	owner_names.append(label)
	two_sided.append(material is BaseMaterial3D and material.cull_mode == BaseMaterial3D.CULL_DISABLED)
	owner_material.append(material)
	return owner_names.size() - 1

func add_mesh(mesh: Mesh, xform: Transform3D, owner: int) -> void:
	for s in range(mesh.get_surface_count()):
		var arrays: Array = mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var count: int = index.size() if index.size() > 0 else verts.size()
		for t in range(0, count - 2, 3):
			var a: Vector3 = xform * verts[index[t] if index.size() else t]
			var b: Vector3 = xform * verts[index[t + 1] if index.size() else t + 1]
			var c: Vector3 = xform * verts[index[t + 2] if index.size() else t + 2]
			var cross: Vector3 = (b - a).cross(c - a)
			var area: float = cross.length() * .5
			if area < MIN_TRIANGLE:
				continue
			var n: Vector3 = cross / (area * 2.0)
			# Canonical orientation (largest component positive) for bucketing;
			# `side` keeps which way the face really points.
			var m: int = n.abs().max_axis_index()
			var side: int = 1
			if n[m] < 0.0:
				n = -n
				side = -1
			var key := Vector4i(roundi(n.x * 40), roundi(n.y * 40), roundi(n.z * 40), floori(n.dot(a) / PLANE_TOLERANCE))
			if not buckets.has(key):
				buckets[key] = []
			buckets[key].append([owner, a, b, c, n, side])

func find_overlaps() -> Dictionary:
	var pairs: Dictionary = {}
	for key: Vector4i in buckets:
		var here: Array = buckets[key]
		var near: Array = here.duplicate()
		var up := Vector4i(key.x, key.y, key.z, key.w + 1)
		if buckets.has(up):
			near.append_array(buckets[up])
		var owners: Dictionary = {}
		for tri in near:
			owners[tri[0]] = true
		if owners.size() < 2:
			continue
		var n: Vector3 = here[0][4]
		var u: Vector3 = n.cross(Vector3.UP if absf(n.y) < .9 else Vector3.RIGHT).normalized()
		var v: Vector3 = n.cross(u)
		var flat: Array = []
		for tri in near:
			var poly := PackedVector2Array([Vector2(tri[1].dot(u), tri[1].dot(v)), Vector2(tri[2].dot(u), tri[2].dot(v)), Vector2(tri[3].dot(u), tri[3].dot(v))])
			var box := Rect2(poly[0], Vector2.ZERO).expand(poly[1]).expand(poly[2])
			flat.append([tri[0], poly, box, tri[1], tri[5]])
		for i in range(here.size()):
			var a: Array = flat[i]
			for j in range(i + 1, flat.size()):
				var b: Array = flat[j]
				if a[0] == b[0] or owner_material[a[0]] == owner_material[b[0]] or not a[2].intersects(b[2]):
					continue
				# Back-to-back faces never fight: culling hides one of them.
				if a[4] != b[4] and not (two_sided[a[0]] or two_sided[b[0]]):
					continue
				var gap: float = absf(a[3].dot(n) - b[3].dot(n))
				if gap > PLANE_TOLERANCE:
					continue
				var overlap: float = 0.0
				var centre := Vector2.ZERO
				for piece in Geometry2D.intersect_polygons(a[1], b[1]):
					var pa: float = polygon_area(piece)
					overlap += pa
					var mid := Vector2.ZERO
					for q in piece:
						mid += q
					centre += mid / piece.size() * pa
				if overlap < MIN_OVERLAP:
					continue
				# One row per owner pair and plane: a pair can fight in several places
				# (both ends of a wall), and each needs its own fix.
				var pk := Vector3i(mini(a[0], b[0]), maxi(a[0], b[0]), hash(key))
				if not pairs.has(pk):
					var c2: Vector2 = centre / overlap
					pairs[pk] = {"a": pk.x, "b": pk.y, "area": 0.0, "at": u * c2.x + v * c2.y + n * a[3].dot(n), "n": n * a[4], "count": 0}
				pairs[pk].area += overlap
				pairs[pk].count += 1
	return pairs

func polygon_area(poly: PackedVector2Array) -> float:
	var s: float = 0.0
	for i in range(poly.size()):
		s += poly[i].cross(poly[(i + 1) % poly.size()])
	return absf(s) * .5

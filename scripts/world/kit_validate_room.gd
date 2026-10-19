@tool
class_name KitValidateRoom
extends RefCounted
## Room-level checks for Validate Room (ENVIRONMENT_PLAN.md 4.1, phase 1
## step 5), on top of KitValidate.scene()'s per-module grid rules:
##
## - Edge gaps: every perimeter edge of the cells a room's CELL modules occupy
##   (per storey, in 2 m segments) is closed by a closing EDGE module (wall,
##   recess, arch, door, iwan ...) or by a room connector marker. Galleries,
##   stairs and gables don't close an edge. Vault ends also need a gable.
## - Connectors: room connector markers sit on a cell-boundary line.
## - Socket fit: every candidate of a SocketSet with slot_bounds fits inside
##   it (error), and each socket's slot doesn't run into another module's
##   collision (warning: e.g. fallen books clipping a gallery slab).
##
## Returns {"errors": PackedStringArray, "warnings": PackedStringArray}.

const BAY: float = 4.0
const SEG: float = 2.0
## Edge signatures that don't close the room's boundary.
const NOT_CLOSING: PackedStringArray = ["", "gallery", "gallery_end", "stair", "gable"]
const SLOT_MARGIN: float = 0.03
const FILL_SEEDS: Array[int] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]

static var _fit_cache: Dictionary = {}     # set path -> PackedStringArray of misfits


static func run(root: Node) -> Dictionary:
	_fit_cache.clear()     # candidates may have changed since the last run
	var errors: PackedStringArray = []
	var warnings: PackedStringArray = []
	var modules: Array[KitModule] = []
	_modules(root, modules)
	_edge_gaps(root, modules, errors)
	_connectors(root, errors)
	_socket_fit(root, modules, errors, warnings)
	return {"errors": errors, "warnings": warnings}


# --- edges ---------------------------------------------------------------------

static func _edge_gaps(root: Node, modules: Array[KitModule], errors: PackedStringArray) -> void:
	var cells: Dictionary = {}       # Vector3i(storey, cx, cz) -> true
	var vault_cells: Dictionary = {}  # same key -> run axis (Vector3) of its vault
	var closing: Dictionary = {}      # segment key -> module label
	var gables: Dictionary = {}
	for m: KitModule in modules:
		var xf: Transform3D = _relative(root, m)
		var storey: int = roundi(xf.origin.y / BAY)
		if m.shape == KitModule.Shape.CELL:
			for c: Vector3i in _cells_of(m, xf, storey):
				cells[c] = true
				if m.tags.has("ceiling"):
					vault_cells[c] = xf.basis.z.normalized()
		elif m.shape == KitModule.Shape.EDGE:
			var n: int = maxi(m.size_cells.x, 1)
			var tall: int = maxi(m.size_cells.y, 1)
			for i: int in n * int(BAY / SEG):
				var a: Vector3 = xf.origin + xf.basis.x.normalized() * SEG * i
				var b: Vector3 = a + xf.basis.x.normalized() * SEG
				for s: int in range(storey, storey + tall):
					var key: String = _seg_key(s, a, b)
					if m.edge == "gable":
						gables[key] = str(root.get_path_to(m))
					elif not NOT_CLOSING.has(m.edge):
						closing[key] = str(root.get_path_to(m))
	for marker: Node in _connectors_of(root):
		var p: Vector3 = _relative(root, marker as Node3D).origin
		for key: String in _segments_through(p):
			closing[key] = "connector " + String(marker.name)
	for c: Vector3i in cells:
		for side: Array in _sides(c):
			var neighbour: Vector3i = side[2]
			if cells.has(neighbour):
				continue
			for seg: Array in _split(side[0], side[1]):
				var key: String = _seg_key(c.x, seg[0], seg[1])
				if not closing.has(key):
					errors.append("storey %d: open edge %s-%s (no wall, arch, door or connector)" % [c.x, _fmt(seg[0]), _fmt(seg[1])])
				if vault_cells.has(c) and not vault_cells.has(neighbour) and absf((seg[1] - seg[0]).normalized().dot(vault_cells[c])) < 0.01 \
						and not gables.has(key):
					errors.append("storey %d: vault end %s-%s has no gable" % [c.x, _fmt(seg[0]), _fmt(seg[1])])


## Cells a CELL module covers: local +X and -Z from its origin.
static func _cells_of(m: KitModule, xf: Transform3D, storey: int) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	for i: int in maxi(m.size_cells.x, 1):
		for j: int in maxi(m.size_cells.z, 1):
			var centre: Vector3 = xf * Vector3(BAY * (i + 0.5), 0, -BAY * (j + 0.5))
			out.append(Vector3i(storey, floori(centre.x / BAY), floori(centre.z / BAY)))
	return out


## [corner a, corner b, neighbour cell] for the four sides of cell c.
static func _sides(c: Vector3i) -> Array:
	var x0: float = c.y * BAY
	var z0: float = c.z * BAY
	return [
		[Vector3(x0, 0, z0), Vector3(x0 + BAY, 0, z0), Vector3i(c.x, c.y, c.z - 1)],
		[Vector3(x0, 0, z0 + BAY), Vector3(x0 + BAY, 0, z0 + BAY), Vector3i(c.x, c.y, c.z + 1)],
		[Vector3(x0, 0, z0), Vector3(x0, 0, z0 + BAY), Vector3i(c.x, c.y - 1, c.z)],
		[Vector3(x0 + BAY, 0, z0), Vector3(x0 + BAY, 0, z0 + BAY), Vector3i(c.x, c.y + 1, c.z)],
	]


static func _split(a: Vector3, b: Vector3) -> Array:
	var out: Array = []
	var d: Vector3 = (b - a).normalized() * SEG
	for i: int in int(BAY / SEG):
		out.append([a + d * i, a + d * (i + 1)])
	return out


## Order-free key of a 2 m segment on a storey (rounded to 5 cm).
static func _seg_key(storey: int, a: Vector3, b: Vector3) -> String:
	var p: Vector2 = Vector2(snappedf(a.x, 0.05), snappedf(a.z, 0.05))
	var q: Vector2 = Vector2(snappedf(b.x, 0.05), snappedf(b.z, 0.05))
	if q < p:
		var t: Vector2 = p
		p = q
		q = t
	return "%d|%.2f,%.2f|%.2f,%.2f" % [storey, p.x, p.y, q.x, q.y]


## The 2 m boundary segments a marker at p sits on (none if it is off-grid).
static func _segments_through(p: Vector3) -> PackedStringArray:
	var out: PackedStringArray = []
	var storey: int = roundi(p.y / BAY)
	if _on(p.x, BAY):
		var z0: float = floorf(p.z / SEG) * SEG
		out.append(_seg_key(storey, Vector3(p.x, 0, z0), Vector3(p.x, 0, z0 + SEG)))
	if _on(p.z, BAY):
		var x0: float = floorf(p.x / SEG) * SEG
		out.append(_seg_key(storey, Vector3(x0, 0, p.z), Vector3(x0 + SEG, 0, p.z)))
	return out


static func _connectors(root: Node, errors: PackedStringArray) -> void:
	for marker: Node in _connectors_of(root):
		var p: Vector3 = _relative(root, marker as Node3D).origin
		if _segments_through(p).is_empty():
			errors.append("connector %s at %s is not on a cell boundary (x or z a multiple of 4 m)" % [marker.name, p])


static func _connectors_of(root: Node) -> Array[Node]:
	var out: Array[Node] = []
	var holder: Node = root.get_node_or_null("Connectors")
	if holder != null:
		for c: Node in holder.get_children():
			if c is Node3D:
				out.append(c)
	return out


# --- sockets -------------------------------------------------------------------

static func _socket_fit(root: Node, modules: Array[KitModule], errors: PackedStringArray, warnings: PackedStringArray) -> void:
	var bodies: Array = []    # [module, room-space AABB]
	for m: KitModule in modules:
		for shape: Node in m.find_children("*", "CollisionShape3D", true, false):
			var cs := shape as CollisionShape3D
			if cs.shape != null and not cs.disabled:
				bodies.append([m, _relative(root, cs) * cs.shape.get_debug_mesh().get_aabb()])
	var checked_sets: Dictionary = {}
	var seen: Dictionary = {}     # one warning per (socket, module), not per collision shape
	for socket: Node in root.find_children("*", "VariantSocket", true, false):
		var s := socket as VariantSocket
		if s.socket_set == null or not s.socket_set.slot_bounds.has_volume():
			continue
		var path: String = s.socket_set.resource_path
		if not checked_sets.has(path):
			checked_sets[path] = true
			for misfit: String in candidate_misfits(s.socket_set):
				errors.append(misfit)
		var host: Node = _host_module(s)
		var slot: AABB = (_relative(root, s) * s.socket_set.slot_bounds).grow(-SLOT_MARGIN)
		for pair: Array in bodies:
			if pair[0] != host and slot.intersects(pair[1]) and not seen.has([s, pair[0]]):
				seen[[s, pair[0]]] = true
				warnings.append("socket %s: its %s slot runs into %s" % [
					str(root.get_path_to(host)) if host != null else str(root.get_path_to(s)),
					path.get_file().get_basename(), str(root.get_path_to(pair[0]))])


## Candidates of a set whose visual bounds leave the set's slot_bounds.
static func candidate_misfits(set: SocketSet) -> PackedStringArray:
	var path: String = set.resource_path
	if path != "" and _fit_cache.has(path):
		return _fit_cache[path]
	var out: PackedStringArray = []
	var slot: AABB = set.slot_bounds.grow(SLOT_MARGIN)
	for e: SocketEntry in set.entries:
		if e == null or e.scene == null:
			continue
		var node: Node = e.scene.instantiate()
		var box: AABB = visual_bounds(node)
		node.free()
		if box.has_volume() and not slot.encloses(box):
			out.append("%s '%s' (%s) does not fit its slot %s" % [path.get_file().get_basename(), e.label, _fmt_aabb(box), _fmt_aabb(set.slot_bounds)])
	if path != "":
		_fit_cache[path] = out
	return out


## Merged AABB of every mesh and multimesh under node, in node space. ShelfFill
## clutter is built with FILL_SEEDS seeds and merged (its spill varies by seed).
static func visual_bounds(node: Node) -> AABB:
	var box: AABB
	var first: bool = true
	var stack: Array[Array] = [[node, Transform3D.IDENTITY]]
	while not stack.is_empty():
		var item: Array = stack.pop_back()
		var n: Node = item[0]
		var xf: Transform3D = item[1]
		var local: AABB
		if n is ShelfFill:
			# Seeded clutter: measure the worst case over many seeds.
			for seed_value: int in FILL_SEEDS:
				(n as ShelfFill).build(seed_value)
				var b: AABB = transforms_bounds((n as ShelfFill).built_transforms)
				local = b if not local.has_volume() else local.merge(b)
		elif n is MultiMeshInstance3D and (n as MultiMeshInstance3D).multimesh != null:
			local = multimesh_bounds((n as MultiMeshInstance3D).multimesh)
		elif n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
			local = (n as MeshInstance3D).mesh.get_aabb()
		if local.has_volume() or local.size.length() > 0.0:
			box = xf * local if first else box.merge(xf * local)
			first = false
		for c: Node in n.get_children():
			stack.append([c, xf * (c as Node3D).transform if c is Node3D else xf])
	return box


static func _host_module(n: Node) -> Node:
	var p: Node = n.get_parent()
	while p != null:
		if p is KitModule:
			return p
		p = p.get_parent()
	return null


# --- shared ----------------------------------------------------------------------

static func _modules(node: Node, out: Array[KitModule]) -> void:
	for child: Node in node.get_children():
		if child is KitModule:
			out.append(child as KitModule)
			continue
		_modules(child, out)


static func _relative(root: Node, node: Node3D) -> Transform3D:
	var xf: Transform3D = node.transform
	var p: Node = node.get_parent()
	while p != null and p != root:
		if p is Node3D:
			xf = (p as Node3D).transform * xf
		p = p.get_parent()
	return xf


static func _on(v: float, step: float) -> bool:
	return absf(v - snappedf(v, step)) < 0.05


static func _fmt(p: Vector3) -> String:
	return "(%.1f, %.1f)" % [p.x, p.z]


static func _fmt_aabb(b: AABB) -> String:
	return "%s..%s" % [b.position.snappedf(0.01), b.end.snappedf(0.01)]


## Bounds of unit boxes placed by `xforms` (ShelfFill books). Computed on the
## CPU: MultiMesh.get_aabb() and instance transforms come from the rendering
## server and read back empty under the headless dummy renderer, which hid the
## fallen books from the tests (step 5, found in the editor).
static func transforms_bounds(xforms: Array[Transform3D]) -> AABB:
	if xforms.is_empty():
		return AABB()
	var unit := AABB(Vector3(-0.5, -0.5, -0.5), Vector3.ONE)
	var box: AABB = xforms[0] * unit
	for xf: Transform3D in xforms:
		box = box.merge(xf * unit)
	return box


## Other multimeshes: the renderer's bounds (empty when headless).
static func multimesh_bounds(mm: MultiMesh) -> AABB:
	return mm.get_aabb() if mm != null else AABB()

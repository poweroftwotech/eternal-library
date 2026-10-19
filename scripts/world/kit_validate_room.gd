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
## - Decal sockets: a decal box that reaches another architecture surface
##   facing it would stain that too (warning: a wall stain over a pier).
##
## Returns {"errors": PackedStringArray, "warnings": PackedStringArray}.

const BAY: float = 4.0
const SEG: float = 2.0
## Edge signatures that don't close the room's boundary.
const NOT_CLOSING: PackedStringArray = ["", "gallery", "gallery_end", "stair", "gable"]
const SLOT_MARGIN: float = 0.03
const FILL_SEEDS: Array[int] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
const SPILL_PROBES: Vector2i = Vector2i(7, 3)   # spill-zone probe grid (x, depth)
const SPILL_DROP: float = 12.0                  # how far below the zone spill may fall
const DECAL_FACING: float = 0.6                 # cos at which a surface takes a decal (normal_fade 0.8)
const DECAL_DEPTH: float = 0.1                  # surfaces this far off the decal's target are another surface

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
	var bodies: Array = []    # [module, room-space AABB, room-space transform, Shape3D]
	for m: KitModule in modules:
		for shape: Node in m.find_children("*", "CollisionShape3D", true, false):
			var cs := shape as CollisionShape3D
			if cs.shape != null and not cs.disabled:
				var xf: Transform3D = _relative(root, cs)
				bodies.append([m, xf * cs.shape.get_debug_mesh().get_aabb(), xf, cs.shape])
	var checked_sets: Dictionary = {}
	var seen: Dictionary = {}     # one warning per (socket, module), not per collision shape
	for socket: Node in root.find_children("*", "VariantSocket", true, false):
		var s := socket as VariantSocket
		if s.socket_set == null or not s.socket_set.slot_bounds.has_volume():
			continue
		if _pinned_to_nothing(root, s):
			continue      # the room (or socket) chose "nothing" here: no slot to check
		var path: String = s.socket_set.resource_path
		if not checked_sets.has(path):
			checked_sets[path] = true
			for misfit: String in candidate_misfits(s.socket_set):
				errors.append(misfit)
		var host: Node = _host_module(s)
		var label: String = str(root.get_path_to(host)) if host != null else str(root.get_path_to(s))
		var socket_xf: Transform3D = _relative(root, s)
		var local_slot: AABB = s.socket_set.slot_bounds
		if s.mode == VariantSocket.Mode.EDGE_SCATTER:
			# The strip items can reach: the line plus an item's footprint, out into
			# the room only (behind the line is the host wall).
			local_slot = AABB(Vector3(local_slot.position.x, local_slot.position.y, local_slot.position.z - s.edge_depth),
				Vector3(local_slot.size.x + s.edge_length, local_slot.size.y, s.edge_depth - local_slot.position.z))
		elif s.mode == VariantSocket.Mode.SCATTER and s.socket_set.slot_is_item:
			var reach := Vector3(s.scatter_extent.x, 0.0, s.scatter_extent.y)
			local_slot = AABB(local_slot.position - reach, local_slot.size + reach * 2.0)
		if s.socket_set.decals:
			_decal_probe(root, s, socket_xf, bodies, label, warnings, local_slot, host)
		elif s.settle and (s.mode == VariantSocket.Mode.SCATTER or s.mode == VariantSocket.Mode.EDGE_SCATTER):
			# Settling items rest on whatever is below (a gallery is fine) and vanish
			# if nothing is in reach, so only a solid inside the strip is a problem.
			_spill_probe(root, s, socket_xf, bodies, label, warnings, local_slot, true)
		else:
			var slot: AABB = (socket_xf * local_slot).grow(-SLOT_MARGIN)
			for item: Array in bodies:
				if item[0] != host and slot.intersects(item[1]) and not seen.has([s, item[0]]):
					seen[[s, item[0]]] = true
					warnings.append("socket %s: its %s slot runs into %s" % [label, path.get_file().get_basename(), str(root.get_path_to(item[0]))])
		if s.socket_set.spill_bounds.has_volume():
			_spill_probe(root, s, socket_xf, bodies, label, warnings, s.socket_set.spill_bounds)


## Spill settles on whatever is below it (ShelfFill.settle(), rays starting at
## the top of the spill zone), so probe the zone the same way against the
## modules' collision triangles. Warn if a column has nothing to land on, or
## if a probe starts inside another solid (a pier or column in the zone):
## spill there would rest inside it. Furniture whose top is above the zone is
## fine, spill lands under it.
static func _spill_probe(root: Node, s: VariantSocket, socket_xf: Transform3D, bodies: Array,
		label: String, warnings: PackedStringArray, zone: AABB, missing_ok: bool = false) -> void:
	var up: Vector3 = socket_xf.basis.y.normalized()
	var column: AABB = (socket_xf * zone).merge(socket_xf * AABB(zone.position - Vector3(0, SPILL_DROP, 0), zone.size))
	# The host counts here: spill may land on its own module (the iwan's alcove floor).
	var near: Array = bodies.filter(func(item: Array) -> bool: return column.intersects(item[1]))
	var inside: Dictionary = {}
	var nothing: int = 0
	for ix: int in SPILL_PROBES.x:
		for iz: int in SPILL_PROBES.y:
			var local := Vector3(lerpf(zone.position.x, zone.end.x, (ix + 0.5) / SPILL_PROBES.x), zone.end.y,
				lerpf(zone.position.z, zone.end.z, (iz + 0.5) / SPILL_PROBES.y))
			var from: Vector3 = socket_xf * local
			var best: float = INF       # distance down to the first surface
			for item: Array in near:
				var crossings_up: int = 0
				for tri: PackedVector3Array in _triangles(item):
					var hit: Variant = Geometry3D.ray_intersects_triangle(from, -up, tri[0], tri[1], tri[2])
					if hit != null:
						best = minf(best, from.distance_to(hit))
					if Geometry3D.ray_intersects_triangle(from, up, tri[0], tri[1], tri[2]) != null:
						crossings_up += 1
				if crossings_up % 2 == 1:     # odd crossings: the probe starts inside this solid
					inside[item[0]] = true
			if best > zone.end.y + SPILL_DROP:
				nothing += 1
	if nothing > 0 and not missing_ok:
		warnings.append("socket %s: %d of %d spill probes find nothing to land on" % [label, nothing, SPILL_PROBES.x * SPILL_PROBES.y])
	for body: Node in inside:
		warnings.append("socket %s: %s items would rest inside %s" % [label, s.socket_set.resource_path.get_file().get_basename(), str(root.get_path_to(body))])


## Decals mark only architecture (edge, cell and post modules), and only
## surfaces facing back along their projection (toward the socket's +Y). A
## decal is meant for one surface: the facing surface nearest the socket's own
## plane (its wall, its floor, the slab or vault over a lamp). Warn when the box
## a socket's decals can cover also reaches a facing surface of another module
## at a different depth: a floor crack climbing a stair tread, a wall stain
## over a pier face. Surfaces level with the target (two slabs meeting) are fine.
static func _decal_probe(root: Node, s: VariantSocket, socket_xf: Transform3D, bodies: Array,
		label: String, warnings: PackedStringArray, zone: AABB, _host: Node) -> void:
	var axis: Vector3 = socket_xf.basis.y.normalized()
	var box: AABB = (socket_xf * zone).grow(-SLOT_MARGIN)
	var hits: Array = []      # [module, depth along the axis from the socket]
	for item: Array in bodies:
		var m: KitModule = item[0]
		if m.shape == KitModule.Shape.FREE or not box.intersects(item[1]):
			continue
		for tri: PackedVector3Array in _triangles(item):
			# Collision faces wind so that the outward normal is -(b-a)x(c-a).
			var n: Vector3 = (tri[0] - tri[1]).cross(tri[2] - tri[0])
			if n.length_squared() < 1e-10:
				continue
			n = n.normalized()
			if n.dot(axis) >= DECAL_FACING and _tri_meets_box(tri, n, box):
				hits.append([m, axis.dot((tri[0] + tri[1] + tri[2]) / 3.0 - socket_xf.origin)])
	if hits.is_empty():
		return
	var target: Array = hits[0]
	for h: Array in hits:
		if absf(h[1]) < absf(target[1]):
			target = h
	var seen: Dictionary = {target[0]: true}    # the target's own curve (a vault) is one surface
	for h: Array in hits:
		if not seen.has(h[0]) and absf(h[1] - target[1]) > DECAL_DEPTH:
			seen[h[0]] = true
			warnings.append("socket %s: its %s decals would also mark %s (%.2f m off %s)" % [label,
				s.socket_set.resource_path.get_file().get_basename(), str(root.get_path_to(h[0])),
				absf(h[1] - target[1]), str(root.get_path_to(target[0]))])


## Triangle against an axis-aligned box: bounding boxes overlap and the
## triangle's plane passes through the box (enough for the flat faces here).
static func _tri_meets_box(tri: PackedVector3Array, n: Vector3, box: AABB) -> bool:
	var tb := AABB(tri[0], Vector3.ZERO).expand(tri[1]).expand(tri[2]).grow(0.001)
	if not tb.intersects(box):
		return false
	var half: Vector3 = box.size * 0.5
	var r: float = absf(n.x) * half.x + absf(n.y) * half.y + absf(n.z) * half.z
	return absf(n.dot(box.get_center() - tri[0])) <= r


## Room-space triangles of a body entry [module, aabb, transform, shape], cached.
static func _triangles(item: Array) -> Array[PackedVector3Array]:
	if item.size() > 4:
		return item[4]
	var faces: PackedVector3Array
	var shape: Shape3D = item[3]
	if shape is ConcavePolygonShape3D:
		faces = (shape as ConcavePolygonShape3D).get_faces()
	else:
		faces = shape.get_debug_mesh().get_faces()    # boxes and convex hulls: good enough for probes
	var xf: Transform3D = item[2]
	var out: Array[PackedVector3Array] = []
	for i: int in range(0, faces.size() - 2, 3):
		out.append(PackedVector3Array([xf * faces[i], xf * faces[i + 1], xf * faces[i + 2]]))
	item.append(out)
	return out


## Candidates of a set whose visual bounds leave the set's slot_bounds.
static func candidate_misfits(set: SocketSet) -> PackedStringArray:
	var path: String = set.resource_path
	if path != "" and _fit_cache.has(path):
		return _fit_cache[path]
	var out: PackedStringArray = []
	var slot: AABB = (set.slot_bounds.merge(set.spill_bounds) if set.spill_bounds.has_volume() else set.slot_bounds).grow(SLOT_MARGIN)
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
		elif n is Decal:
			local = AABB((n as Decal).size * -0.5, (n as Decal).size)
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


## True when the room's pin (or the socket's own) picks an entry without a
## scene, e.g. a seam hidden behind a stair pinned to "nothing".
static func _pinned_to_nothing(root: Node, s: VariantSocket) -> bool:
	var pin: int = s.pinned
	if root is RoomTemplate:
		pin = (root as RoomTemplate).socket_pins.get((root as RoomTemplate).socket_key(s), pin)
	return pin >= 0 and pin < s.socket_set.entries.size() and s.socket_set.entries[pin] != null \
		and s.socket_set.entries[pin].scene == null

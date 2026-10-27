class_name KitBatcher
extends Node3D
## Draws repeated kit pieces as MultiMeshes (phase-6-design.md 5.7.2). A baked
## scene keeps every piece as its own instance so it can be edited; when it
## loads, every MeshInstance3D under this node that shares a mesh, render
## layers and shadow setting with others becomes one instance of a
## MultiMeshInstance3D, and the pieces it came from are freed. The gorge's
## 61,000 pieces then cost tens of draw calls per batcher, as vista.gd's
## art.batch_mesh did.
##
## A mesh whose material takes its albedo from vertex colour (the gorge's lit
## windows) gets each instance's colour from its position, warm and varied in
## brightness, as vista.gd's windows were. Nodes in the group "no_batch", and
## everything under them, are left as they are; so are meshes with override
## materials.

## Batch as soon as the scene is in the tree.
@export var batch_on_ready: bool = true
## Render layers for every batch (0: each keeps its pieces' layers). The gorge
## sets 2, its light layer: a saved instance doesn't keep changes to its
## pieces' insides, so their own layers can't be relied on.
@export_flags_3d_render var render_layers: int = 0
## Batch per region of this size (metres; 0: one batch per mesh across the
## whole scene). Each batch is then culled on its own: as one batch spanning
## the gorge, every one of its instances was drawn whenever any was in view
## (phase 6 step 6: 9-15 million triangles in view).
@export var chunk_size: float = 0.0
## Only meshes with at least this many instances are split by region.
@export var chunk_min: int = 400
## Meshes smaller than detail_size across (metres) are drawn only within
## detail_range of the camera (0: always), and cast no shadow: lamps,
## balusters, figures.
@export var detail_range: float = 0.0
@export var detail_size: float = 1.6

## What the last batch() did: meshes in, MultiMeshes out.
var stats: Dictionary = {}


func _ready() -> void:
	if batch_on_ready:
		batch()
		return
	for c: Node in get_children():     # a saved batch: put its transforms back
		if c is MultiMeshInstance3D and c.has_meta("kit_buffer"):
			_fill(c)


static func _fill(node: MultiMeshInstance3D) -> void:
	node.multimesh.instance_count = int(node.get_meta("kit_count"))
	node.multimesh.buffer = node.get_meta("kit_buffer")


func batch() -> Dictionary:
	var to_local: Transform3D = global_transform.affine_inverse()
	var groups: Dictionary = {}
	var signatures: Dictionary = {}
	var batched: Array[Node] = []
	for n: Node in find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null or not mi.is_visible_in_tree() or _kept(mi):
			continue
		var layers: int = render_layers if render_layers != 0 else mi.layers
		var xf: Transform3D = to_local * mi.global_transform
		var key: String = "%s/%d/%d" % [_signature(mi.mesh, signatures), layers, mi.cast_shadow]
		if not groups.has(key):
			groups[key] = {"mesh": mi.mesh, "layers": layers, "shadow": mi.cast_shadow, "xfs": [], "tinted": _tinted(mi.mesh)}
		(groups[key]["xfs"] as Array).append(xf)
		batched.append(mi)
	# Meshes with many instances split by region (chunk_size), each part culled
	# on its own; the rest stay one batch each (every region a draw call).
	if chunk_size > 0.0:
		for key: String in groups.keys():
			var g: Dictionary = groups[key]
			if (g["xfs"] as Array).size() < chunk_min:
				continue
			groups.erase(key)
			for xf: Transform3D in g["xfs"]:
				var part: String = "%s/%s" % [key, Vector3i((xf.origin / chunk_size).floor())]
				if not groups.has(part):
					groups[part] = g.duplicate()
					groups[part]["xfs"] = []
				(groups[part]["xfs"] as Array).append(xf)
	var made: int = 0
	for key: String in groups:
		var g: Dictionary = groups[key]
		var xfs: Array = g["xfs"]
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.use_colors = g["tinted"]
		multi.mesh = g["mesh"]
		var buffer := PackedFloat32Array()
		for xf: Transform3D in xfs:
			var b: Basis = xf.basis
			buffer.append_array([b.x.x, b.y.x, b.z.x, xf.origin.x, b.x.y, b.y.y, b.z.y, xf.origin.y, b.x.z, b.y.z, b.z.z, xf.origin.z])
			if g["tinted"]:
				var c: Color = _window_tint(xf.origin)
				buffer.append_array([c.r, c.g, c.b, c.a])
		var node := MultiMeshInstance3D.new()
		node.name = "Batch_%d" % made
		node.multimesh = multi
		# The transforms are kept as data on the node too: a bake runs headless,
		# where a MultiMesh keeps none of them, and a saved scene restores them.
		node.set_meta("kit_count", xfs.size())
		node.set_meta("kit_buffer", buffer)
		_fill(node)
		node.layers = g["layers"]
		node.cast_shadow = g["shadow"]
		var across: float = (g["mesh"] as Mesh).get_aabb().size.length()     # 0 if unknown (headless): drawn at any range
		if detail_range > 0.0 and across > 0.0 and across < detail_size:
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF     # too small to show in the shadow maps
			node.visibility_range_end = detail_range
			node.visibility_range_end_margin = detail_range * .1
			node.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		add_child(node)
		made += 1
	for mi: Node in batched:
		_free_up(mi)
	stats = {"meshes": batched.size(), "batches": made}
	return stats


## Frees a batched mesh, and the piece it belonged to once nothing else is
## left in it. What hangs under the mesh (an imported piece's collision body,
## a "-col" mesh's) stays where it was, moved up to the mesh's parent.
func _free_up(mi: Node) -> void:
	var parent: Node = mi.get_parent()
	for c: Node in mi.get_children():
		var xf: Transform3D = (mi as Node3D).transform * (c as Node3D).transform if c is Node3D else Transform3D()
		mi.remove_child(c)
		parent.add_child(c)
		if c is Node3D:
			(c as Node3D).transform = xf
	mi.free()
	while parent != null and parent != self and parent.get_child_count() == 0:
		var up: Node = parent.get_parent()
		parent.free()
		parent = up


## A mesh's content (its surfaces' materials and vertices), so identical
## meshes from different pieces (a deck edge's slab in each of its variants,
## the arch frame shared by three bays) share one batch.
static func _signature(mesh: Mesh, known: Dictionary) -> String:
	var id: int = mesh.get_instance_id()
	if not known.has(id):
		var parts: Array = []
		for i: int in mesh.get_surface_count():
			var arrays: Array = mesh.surface_get_arrays(i)
			var material: Material = mesh.surface_get_material(i)
			parts.append([material.get_instance_id() if material != null else 0, hash(arrays[Mesh.ARRAY_VERTEX]), hash(arrays[Mesh.ARRAY_INDEX])])
		known[id] = str(hash(parts))
	return known[id]


func _kept(mi: MeshInstance3D) -> bool:
	for i: int in mi.get_surface_override_material_count():
		if mi.get_surface_override_material(i) != null:
			return true
	var n: Node = mi
	while n != null and n != self:
		if n.is_in_group("no_batch"):
			return true
		n = n.get_parent()
	return false


static func _tinted(mesh: Mesh) -> bool:
	for i: int in mesh.get_surface_count():
		var m := mesh.surface_get_material(i) as BaseMaterial3D
		if m != null and m.vertex_color_use_as_albedo:
			return true
	return false


## vista.gd's window tint: warm, its green and blue varied, its brightness
## 0.25-0.85; from the window's position, so it's the same every load.
static func _window_tint(p: Vector3) -> Color:
	var h := func(k: float) -> float: return fposmod(sin(p.x * 12.9898 + p.y * 78.233 + p.z * 37.719 + k) * 43758.5453, 1.0)
	# Walked (phase 6 step 3): not every window lit alike. About a quarter
	# dark (a room nobody's in), a third dim, the rest full; the average about
	# as before (0.55), so the gorge's light holds.
	var pick: float = h.call(4.0)
	var level: float = .07 if pick < .25 else (lerpf(.25, .4, h.call(3.0)) if pick < .58 else lerpf(.8, 1.0, h.call(3.0)))
	return Color(1.0, lerpf(.70, .94, h.call(1.0)), lerpf(.42, .70, h.call(2.0))) * level

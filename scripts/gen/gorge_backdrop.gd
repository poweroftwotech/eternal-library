class_name GorgeBackdrop
extends RefCounted
## The gorge's generated backdrop (tools/bake_gorge.gd: rooms/baked/gorge/
## generated.scn, the vista's masses merged by material: the rock and masonry
## round the Overlook, the cliff under the balcony, the enclosure), for what
## the network's walks keep clear of. The tiers' keep-out (GorgeGrammar)
## doesn't know it: walked (phase 6 step 4), a stair ran down hard against the
## blank mass beside the Overlook and a gallery's end ran into it. Loaded by
## the tools that place the slots and links (tools/gorge_frontage.gd,
## tools/gorge_links.gd); at run time nothing asks it.

const SCENE: String = "res://rooms/baked/gorge/generated.scn"
## [TriangleMesh, its inverse transform, its box (area frame)].
static var _meshes: Array = []


## Loads the backdrop once a session (meshes with a shader, the waterfalls,
## don't count).
static func load_baked() -> void:
	if not _meshes.is_empty():
		return
	var root: Node3D = (load(SCENE) as PackedScene).instantiate()
	for n: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null or not mi.visible or mi.material_override is ShaderMaterial or mi.get_parent().name == "TierCores":     # inside the tiers (keep-out has them)
			continue
		var xf: Transform3D = mi.transform
		var up: Node = mi.get_parent()
		while up is Node3D:
			xf = (up as Node3D).transform * xf
			up = up.get_parent()
		_meshes.append([mi.mesh.generate_triangle_mesh(), xf.affine_inverse(), xf * mi.mesh.get_aabb()])
	root.free()


static func loaded() -> bool:
	return not _meshes.is_empty()


## Whether the backdrop crosses the segment a-b (area frame).
static func hits(a: Vector3, b: Vector3) -> bool:
	for m: Array in _meshes:
		if not (m[2] as AABB).intersects_segment(a, b):
			continue
		var inv: Transform3D = m[1]
		if not (m[0] as TriangleMesh).intersect_segment(inv * a, inv * b).is_empty():
			return true
	return false


## Whether the backdrop crosses the box from lo to hi in frame xf: tested
## along lines across it, at its sides and middle, along x and along z.
static func crosses(xf: Transform3D, lo: Vector3, hi: Vector3) -> bool:
	for y: float in [lo.y, (lo.y + hi.y) * .5, hi.y]:
		for z: float in [lo.z, (lo.z + hi.z) * .5, hi.z]:
			if hits(xf * Vector3(lo.x, y, z), xf * Vector3(hi.x, y, z)):
				return true
		for x: float in [lo.x, (lo.x + hi.x) * .5, hi.x]:
			if hits(xf * Vector3(x, y, lo.z), xf * Vector3(x, y, hi.z)):
				return true
	return false

class_name GorgeScenery
extends RefCounted
## Clears the baked gorge's pieces where the walkable network stands
## (phase-6-design.md 5.7.5, phase 6 step 4). The scenery is baked once and
## drawn in batches; the network differs by seed, so when the area loads, the
## facade bays, lamps and terrace dressing whose bounds meet a network room's
## claims (its walk and headroom, its piers, the storey of faces behind a
## ledge) are hidden in their batches. Walls, tiers and decks stay: the
## planner keeps the network clear of those.

const REMOVABLE: PackedStringArray = ["gorge_bay_", "gorge_lamp", "gorge_banner_", "gorge_figure", "gorge_cypress_", "gorge_pavilion_"]


## Hides what meets the claims ([{xf: Transform3D, size: Vector3}], global:
## boxes centred on xf's origin, turned by its basis). How many pieces' meshes.
static func clear(kit: Node, claims: Array) -> int:
	if claims.is_empty():
		return 0
	var reach := AABB()
	for i: int in claims.size():
		var c: Dictionary = claims[i]
		var b: AABB = (c["xf"] as Transform3D) * AABB(-(c["size"] as Vector3) * .5, c["size"])
		reach = b if i == 0 else reach.merge(b)
	reach = reach.grow(6.0)
	# Each removable module's bounds (the union of its meshes, in its frame).
	var modules: Dictionary = {}
	var batches: Array[MultiMeshInstance3D] = []
	for n: Node in kit.find_children("*", "MultiMeshInstance3D", true, false):
		var mmi := n as MultiMeshInstance3D
		if mmi.multimesh == null or mmi.multimesh.mesh == null:
			continue
		var module: String = module_of(mmi.multimesh.mesh.resource_name)
		if module == "" or not Array(REMOVABLE).any(func(p: String) -> bool: return module.begins_with(p)):
			continue
		var aabb: AABB = mmi.multimesh.mesh.get_aabb()
		modules[module] = aabb if not modules.has(module) else (modules[module] as AABB).merge(aabb)
		batches.append(mmi)
	var hidden: int = 0
	for mmi: MultiMeshInstance3D in batches:
		var mm: MultiMesh = mmi.multimesh
		var bounds: AABB = modules[module_of(mm.mesh.resource_name)]
		var to_global: Transform3D = mmi.global_transform
		var buffer: PackedFloat32Array = mm.buffer
		var stride: int = 12 + (4 if mm.use_colors else 0) + (4 if mm.use_custom_data else 0)
		var changed: bool = false
		for i: int in mm.instance_count:
			var o: int = i * stride
			var at: Vector3 = to_global * Vector3(buffer[o + 3], buffer[o + 7], buffer[o + 11])
			if not reach.has_point(at):
				continue
			var basis := Basis(Vector3(buffer[o], buffer[o + 4], buffer[o + 8]), Vector3(buffer[o + 1], buffer[o + 5], buffer[o + 9]),
				Vector3(buffer[o + 2], buffer[o + 6], buffer[o + 10]))
			var xf: Transform3D = to_global * Transform3D(basis, Vector3(buffer[o + 3], buffer[o + 7], buffer[o + 11]))
			for c: Dictionary in claims:
				if boxes_meet(xf, bounds, c["xf"], (c["size"] as Vector3) * .5):
					for k: int in [0, 1, 2, 4, 5, 6, 8, 9, 10]:      # its basis to nothing: it draws nothing
						buffer[o + k] = 0.0
					hidden += 1
					changed = true
					break
		if changed:
			mm.buffer = buffer
			mmi.set_meta("network_cleared", true)
	return hidden


## The module a batched mesh came from: the kit names a module's meshes
## "<module>_<module>__<part>".
static func module_of(mesh_name: String) -> String:
	var i: int = mesh_name.find("__")
	if i < 0:
		return ""
	var prefix: String = mesh_name.substr(0, i)
	var module: String = prefix.substr(0, (prefix.length() - 1) / 2)
	return module if prefix == module + "_" + module else ""


## Whether a box (`bounds` in frame a) meets a box centred on b's origin with
## half extents `half` in b's frame (separating axes).
static func boxes_meet(a: Transform3D, bounds: AABB, b: Transform3D, half: Vector3) -> bool:
	var ca: Vector3 = a * bounds.get_center()
	var axes_a: Array[Vector3] = [a.basis.x, a.basis.y, a.basis.z]
	var ha: Vector3 = bounds.size * .5
	var axes_b: Array[Vector3] = [b.basis.x.normalized(), b.basis.y.normalized(), b.basis.z.normalized()]
	var d: Vector3 = b.origin - ca
	var tests: Array[Vector3] = []
	tests.append_array(axes_a)
	tests.append_array(axes_b)
	for u: Vector3 in axes_a:
		for v: Vector3 in axes_b:
			var w: Vector3 = u.cross(v)
			if w.length_squared() > 1e-6:
				tests.append(w)
	for axis: Vector3 in tests:
		var n: Vector3 = axis.normalized()
		var ra: float = absf(axes_a[0].dot(n)) * ha.x + absf(axes_a[1].dot(n)) * ha.y + absf(axes_a[2].dot(n)) * ha.z
		var rb: float = absf(axes_b[0].dot(n)) * half.x + absf(axes_b[1].dot(n)) * half.y + absf(axes_b[2].dot(n)) * half.z
		if absf(d.dot(n)) > ra + rb:
			return false
	return true


## The mist floor's glow (cavern.gd build_mist, baked) made `factor` times
## brighter, in this scenery only. Whether it was found.
static func lift_mist(scenery: Node, factor: float) -> bool:
	var fog := scenery.find_child("GorgeMistFloor", true, false) as FogVolume
	if fog == null or not (fog.material is FogMaterial):
		return false
	var mat := (fog.material as FogMaterial).duplicate() as FogMaterial
	mat.emission = mat.emission * factor
	fog.material = mat
	return true

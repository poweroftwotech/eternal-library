@tool
class_name KitValidate
extends RefCounted
## Checks kit modules placed in a scene (Kit dock "Validate scene", tests).
## Phase 0 rules: no scaling, rotation only about Y in 90 degree steps,
## structural modules on the 2 m half-bay grid and 0.5 m height steps,
## and no two identical modules stacked on the same spot.


static func count_modules(root: Node) -> int:
	return _modules(root).size()


static func scene(root: Node) -> PackedStringArray:
	var problems: PackedStringArray = []
	var seen: Dictionary = {}
	for m: KitModule in _modules(root):
		var xf: Transform3D = _relative(root, m)
		var label: String = str(root.get_path_to(m))
		var b: Basis = xf.basis
		if not b.get_scale().is_equal_approx(Vector3.ONE):
			problems.append("%s is scaled %s; modules must keep scale 1 (texel density)" % [label, b.get_scale()])
		var euler: Vector3 = b.get_euler()
		var yaw_deg: float = rad_to_deg(euler.y)
		if absf(euler.x) > 0.001 or absf(euler.z) > 0.001 or absf(yaw_deg - snappedf(yaw_deg, 90.0)) > 0.01:
			problems.append("%s rotation %s is not a 90 degree turn about Y" % [label, euler * 180.0 / PI])
		var p: Vector3 = xf.origin
		var step: float = 2.0 if m.shape != KitModule.Shape.FREE else 0.5
		if not _on_step(p.x, step) or not _on_step(p.z, step) or not _on_step(p.y, 0.5):
			problems.append("%s at %s is off the %.1f m grid" % [label, p, step])
		var key: String = "%s|%s|%d" % [m.scene_file_path, p.snappedf(0.01), roundi(yaw_deg)]
		if seen.has(key) and m.shape != KitModule.Shape.FREE:
			problems.append("%s duplicates %s at the same spot" % [label, seen[key]])
		seen[key] = label
	return problems


static func _on_step(v: float, step: float) -> bool:
	return absf(v - snappedf(v, step)) < 0.01


static func _relative(root: Node, node: Node3D) -> Transform3D:
	var xf: Transform3D = node.transform
	var p: Node = node.get_parent()
	while p != null and p != root:
		if p is Node3D:
			xf = (p as Node3D).transform * xf
		p = p.get_parent()
	return xf


static func _modules(root: Node) -> Array[KitModule]:
	var out: Array[KitModule] = []
	_collect(root, root, out)
	return out


static func _collect(node: Node, root: Node, out: Array[KitModule]) -> void:
	for child: Node in node.get_children():
		if child is KitModule:
			out.append(child as KitModule)
			continue          # a module's own children are its parts, not placements
		_collect(child, root, out)

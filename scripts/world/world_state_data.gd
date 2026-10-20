class_name WorldStateData
extends RefCounted
## Helpers for the save's JSON (ENVIRONMENT_PLAN.md 6.5.3), shared by the
## WorldState autoload and the rooms.


## A transform as 12 floats: basis columns x, y, z, then the origin.
static func arr(t: Transform3D) -> Array:
	var b: Basis = t.basis
	return [b.x.x, b.x.y, b.x.z, b.y.x, b.y.y, b.y.z, b.z.x, b.z.y, b.z.z, t.origin.x, t.origin.y, t.origin.z]


static func xf(a: Variant) -> Transform3D:
	if not a is Array or (a as Array).size() < 12:
		return Transform3D.IDENTITY
	return Transform3D(Basis(Vector3(a[0], a[1], a[2]), Vector3(a[3], a[4], a[5]), Vector3(a[6], a[7], a[8])),
		Vector3(a[9], a[10], a[11]))

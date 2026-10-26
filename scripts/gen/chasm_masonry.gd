class_name ChasmMasonry
extends RefCounted
## Stonework made to measure for the gorge's walkways (phase-6-design.md
## 5.7.5, phase 6 step 4), where the kit's 4 m pieces don't fit: a span that
## joins two ledges runs at any length, and meets a ledge at a slight angle.
## The gorge's materials map in world space (triplanar), so a made slab or
## plinth carries on seamlessly from the kit's paving and balustrades beside it.
##
## A plan (ChasmGrammar.solve/join, CliffLedgeGrammar.solve) lists, in its
## room's frame:
##   "slabs":  [{poly: PackedVector2Array (x, z), y}] walk slabs, paving on
##             top at y, 0.45 m deep, a faience fascia 0.3 m under it; walked
##             on (convex polygons)
##   "rails":  [{a: Vector3, b: Vector3}] balustrades along a line (the
##             plinth's middle, at walk height): a sandstone plinth, turned
##             balusters every half metre, a gold rail, and a guard 2 m high
##   "blocks": [{at: Vector3, size: Vector3, turn: float, mat: String}] stone
##             boxes (corbels, lintels), turned about +Y; looked at only
##   "guards": [{at, size, turn}] collision only (the cliff side of a ledge)
## build() adds them to a room: one mesh per material, one collision body.

const MAT: String = "res://kit/materials/%s.tres"
const SLAB: float = .45
const FASCIA: float = .3
## tools/kit_add_r10.py balustrade(): plinth 0.36 wide, 0.25 tall; rail.
const PLINTH: Vector2 = Vector2(.36, .25)
const RAIL: float = 1.1
const GUARD: float = 2.0
const BALUSTER_EVERY: float = .5
const BALUSTER: Array[Vector2] = [Vector2(.07, .25), Vector2(.11, .33), Vector2(.06, .5), Vector2(.09, .75), Vector2(.06, .95), Vector2(.08, 1.02)]

static var _baluster: ArrayMesh


static func slab(plan: Dictionary, poly: PackedVector2Array, y: float = 0.0, fascia: float = FASCIA) -> void:
	if not plan.has("slabs"):
		plan["slabs"] = []
	(plan["slabs"] as Array).append({"poly": poly, "y": y, "fascia": fascia})


static func rail(plan: Dictionary, a: Vector3, b: Vector3) -> void:
	if not plan.has("rails"):
		plan["rails"] = []
	(plan["rails"] as Array).append({"a": a, "b": b})


static func block(plan: Dictionary, at: Vector3, size: Vector3, turn: float = 0.0, mat: String = "gorge_sandstone") -> void:
	if not plan.has("blocks"):
		plan["blocks"] = []
	(plan["blocks"] as Array).append({"at": at, "size": size, "turn": turn, "mat": mat})


static func guard(plan: Dictionary, at: Vector3, size: Vector3, turn: float = 0.0) -> void:
	if not plan.has("guards"):
		plan["guards"] = []
	(plan["guards"] as Array).append({"at": at, "size": size, "turn": turn})


## The room's made stonework: meshes merged by material, balusters as one
## mesh, and a collision body for the slabs, the rails' guards and the guards.
static func build(room: Node3D, plan: Dictionary, extra_blocks: Array = []) -> void:
	var by_mat: Dictionary = {}       # material -> SurfaceTool
	var body := StaticBody3D.new()
	body.name = "MadeCollision"
	for s: Dictionary in plan.get("slabs", []):
		var poly: PackedVector2Array = s["poly"]
		var y: float = s["y"]
		_prism(_tool(by_mat, "gorge_sandstone"), poly, y - SLAB, y)
		_prism(_tool(by_mat, "gorge_faience"), _grown(poly, .02), y - SLAB - float(s.get("fascia", FASCIA)), y - SLAB)
		var shape := ConvexPolygonShape3D.new()
		var points: PackedVector3Array = []
		for p: Vector2 in poly:
			points.append(Vector3(p.x, y, p.y))
			points.append(Vector3(p.x, y - SLAB, p.y))
		shape.points = points
		_collide(body, shape, Transform3D())
	var balusters := SurfaceTool.new()
	balusters.begin(Mesh.PRIMITIVE_TRIANGLES)
	var any_baluster: bool = false
	for r: Dictionary in plan.get("rails", []):
		var a: Vector3 = r["a"]
		var b: Vector3 = r["b"]
		var length: float = Vector2(b.x - a.x, b.z - a.z).length()
		if length < .05:
			continue
		var turn: float = atan2(b.x - a.x, b.z - a.z)
		var basis := Basis(Vector3.UP, turn)       # +Z along the rail, X across
		var mid: Vector3 = (a + b) * .5
		_box(_tool(by_mat, "gorge_sandstone"), Transform3D(basis, mid + Vector3(0, PLINTH.y * .5, 0)), Vector3(PLINTH.x, PLINTH.y, length))
		_box(_tool(by_mat, "gorge_gold"), Transform3D(basis, mid + Vector3(0, RAIL - .04, 0)), Vector3(PLINTH.x + .04, .08, length))
		var n: int = maxi(1, roundi(length / BALUSTER_EVERY))
		for k: int in n:
			balusters.append_from(baluster(), 0, Transform3D(Basis(), a.lerp(b, (k + .5) / n)))
			any_baluster = true
		var g := BoxShape3D.new()
		g.size = Vector3(PLINTH.x, GUARD, length + .2)      # overlapping the next guard: no seam to slip through
		_collide(body, g, Transform3D(basis, mid + Vector3(0, GUARD * .5, 0)))
	for b: Dictionary in plan.get("blocks", []) + extra_blocks:
		_box(_tool(by_mat, b["mat"]), Transform3D(Basis(Vector3.UP, b["turn"]), b["at"]), b["size"])
	for g: Dictionary in plan.get("guards", []):
		var shape := BoxShape3D.new()
		shape.size = g["size"]
		_collide(body, shape, Transform3D(Basis(Vector3.UP, g["turn"]), g["at"]))
	for mat: String in by_mat:
		var mi: MeshInstance3D = _mesh(room, "made_" + mat.replace("#", "_"), (by_mat[mat] as SurfaceTool).commit(), load(MAT % mat.get_slice("#", 0)))
		if mat == "gorge_gold":       # the rails: their shadows don't show at the gorge's scale
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if any_baluster:
		_mesh(room, "made_balusters", balusters.commit(), load(MAT % "gorge_sandstone")).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if body.get_child_count() > 0:
		room.add_child(body)
	else:
		body.free()


## One turned baluster (tools/kit_add_r10.py balustrade()), its foot at the
## origin: the lathe profile from the plinth's top to under the rail.
static func baluster() -> ArrayMesh:
	if _baluster != null:
		return _baluster
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	const SEGS: int = 8
	for i: int in BALUSTER.size() - 1:
		var p0: Vector2 = BALUSTER[i]
		var p1: Vector2 = BALUSTER[i + 1]
		for s: int in SEGS:
			var a0: float = TAU * s / SEGS
			var a1: float = TAU * (s + 1) / SEGS
			var v00 := Vector3(cos(a0) * p0.x, p0.y, sin(a0) * p0.x)
			var v01 := Vector3(cos(a1) * p0.x, p0.y, sin(a1) * p0.x)
			var v10 := Vector3(cos(a0) * p1.x, p1.y, sin(a0) * p1.x)
			var v11 := Vector3(cos(a1) * p1.x, p1.y, sin(a1) * p1.x)
			# Flat faces, as the kit's lathed balusters (smooth ones read paler).
			var face: Vector3 = (v10 - v00).cross(v11 - v00).normalized()
			var mid: Vector3 = (v00 + v11) * .5
			if face.dot(Vector3(mid.x, 0, mid.z)) < 0.0:
				face = -face
			for v: Vector3 in [v00, v10, v11, v00, v11, v01]:
				st.set_normal(face)
				st.set_tangent(Plane(Vector3.UP.cross(face).normalized(), 1.0))      # for the normal map (the kit's glTF pieces have them)
				st.add_vertex(v)
	_baluster = st.commit()
	return _baluster


static func _tool(by_mat: Dictionary, mat: String) -> SurfaceTool:
	if not by_mat.has(mat):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		by_mat[mat] = st
	return by_mat[mat]


## A vertical prism over a convex polygon (x, z), from y0 to y1, every face
## out (the polygon either way round).
static func _prism(into: SurfaceTool, poly: PackedVector2Array, y0: float, y1: float) -> void:
	# Made on its own, indexed, and appended as the boxes are (unindexed faces
	# in a tool with the boxes' indexed ones went missing).
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts: PackedVector2Array = poly
	if _area(pts) > 0.0:
		pts = poly.duplicate()
		pts.reverse()
	var n: int = pts.size()
	for i: int in range(1, n - 1):
		for p: Vector2 in [pts[0], pts[i + 1], pts[i]]:      # the top, facing up (clockwise seen from the front, as Godot's)
			st.set_normal(Vector3.UP)
			st.set_tangent(Plane(Vector3.RIGHT, 1.0))
			st.set_uv(Vector2.ZERO)
			st.add_vertex(Vector3(p.x, y1, p.y))
		for p: Vector2 in [pts[0], pts[i], pts[i + 1]]:
			st.set_normal(Vector3.DOWN)
			st.set_tangent(Plane(Vector3.RIGHT, 1.0))
			st.set_uv(Vector2.ZERO)
			st.add_vertex(Vector3(p.x, y0, p.y))
	for i: int in n:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[(i + 1) % n]
		var out := Vector3(a.y - b.y, 0, b.x - a.x).normalized()
		for v: Vector3 in [Vector3(a.x, y0, a.y), Vector3(a.x, y1, a.y), Vector3(b.x, y1, b.y),
				Vector3(a.x, y0, a.y), Vector3(b.x, y1, b.y), Vector3(b.x, y0, b.y)]:
			st.set_normal(out)
			st.set_tangent(Plane(Vector3.UP, 1.0))
			st.set_uv(Vector2.ZERO)
			st.add_vertex(v)
	st.index()
	into.append_from(st.commit(), 0, Transform3D())


## Signed area in (x, z) (-: the order whose faces below show from outside).
static func _area(poly: PackedVector2Array) -> float:
	var s: float = 0.0
	for i: int in poly.size():
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % poly.size()]
		s += a.x * b.y - b.x * a.y
	return s * .5


## A convex polygon grown outward by d (each corner pushed along its bisector).
static func _grown(poly: PackedVector2Array, d: float) -> PackedVector2Array:
	var c := Vector2.ZERO
	for p: Vector2 in poly:
		c += p
	c /= poly.size()
	var out: PackedVector2Array = []
	for p: Vector2 in poly:
		out.append(p + (p - c).normalized() * d)
	return out


static func _box(st: SurfaceTool, xf: Transform3D, size: Vector3) -> void:
	var box := BoxMesh.new()
	box.size = size
	st.append_from(box, 0, xf)


static func _collide(body: StaticBody3D, shape: Shape3D, xf: Transform3D) -> void:
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.transform = xf
	body.add_child(cs)


static func _mesh(room: Node, name: String, mesh: Mesh, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	mi.mesh = mesh
	mi.material_override = material
	room.add_child(mi)
	return mi

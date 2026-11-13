class_name GroundBody
extends RefCounted
## The models of the small animals of the ground and the walls (phase 19 step
## 4), made in code like the fish and the moths: the rat and the wall gecko,
## each a unit long from nose to rump (rat) or nose to tail tip (gecko), nose
## at -Z, feet on y = 0, and the rat's hole in a wall. Flat faces with their
## own normals, lit like the world.
##
## A corner's COLOR is its part's colour index in red (0 body, 0.5 pale, 1
## dark) and, in green, what moves it (creature_crawler.gdshader): 0 the body,
## 0.5 a leg (blue: 0 or 1, which pair it steps with), 1 the tail. UV.y is how
## far along the animal a corner is (0 nose, 1 tail tip).

const SHADER: Shader = preload("res://shaders/creature_crawler.gdshader")

static var _meshes: Dictionary = {}
static var _materials: Dictionary = {}


## A rat: a faceted body fattest at the haunch, a wedge head, round ears, four
## feet, a long thin tail (as long again as the body).
static func rat_mesh() -> ArrayMesh:
	if _meshes.has("rat"):
		return _meshes["rat"]
	var b := _Builder.new()
	# Rings nose to rump: z, middle height, half width, half height.
	var rings: Array = [[-0.5, 0.1, 0.025, 0.025], [-0.36, 0.17, 0.12, 0.11], [-0.12, 0.23, 0.21, 0.19], [0.2, 0.27, 0.28, 0.25], [0.5, 0.2, 0.13, 0.13]]
	for i: int in rings.size() - 1:
		var r0: Array = rings[i]
		var r1: Array = rings[i + 1]
		var a: Array[Vector3] = _diamond(r0)
		var c: Array[Vector3] = _diamond(r1)
		for k: int in 8:
			var k1: int = (k + 1) % 8
			# The underside pale.
			var col := Color(0.5 if k >= 3 and k <= 4 else 0.0, 0.0, 0.0)
			b.quad(a[k], a[k1], c[k1], c[k], col, (float(r0[0]) + 0.5) / 1.9, (float(r1[0]) + 0.5) / 1.9)
	for s: float in [1.0, -1.0]:
		# Ears, pale skin.
		b.tri(Vector3(0.06 * s, 0.26, -0.32), Vector3(0.16 * s, 0.4, -0.27), Vector3(0.13 * s, 0.25, -0.2), Color(0.5, 0.0, 0.0), 0.1)
		# Eyes.
		b.tri(Vector3(0.075 * s, 0.2, -0.42), Vector3(0.105 * s, 0.225, -0.37), Vector3(0.1 * s, 0.18, -0.37), Color(1.0, 0.0, 0.0, 0.0), 0.05)
		# Feet: front and hind, stepping in opposite pairs.
		for leg: Array in [[-0.12, 0.0 if s > 0.0 else 1.0], [0.26, 1.0 if s > 0.0 else 0.0]]:
			var z: float = leg[0]
			var x: float = (0.15 if z < 0.0 else 0.22) * s
			var col := Color(0.5, 0.5, float(leg[1]))
			b.tri(Vector3(x, 0.09, z), Vector3(x + 0.05 * s, 0.0, z - 0.09), Vector3(x + 0.05 * s, 0.0, z + 0.03), col, (z + 0.5) / 1.9)
	# The tail: two thin blades crossed, so it shows from above and the side.
	var t0 := Vector3(0, 0.16, 0.48)
	var t1 := Vector3(0, 0.03, 1.4)
	var tail := Color(0.5, 1.0, 0.0)
	b.tri(t0 + Vector3(0.04, 0, 0), t0 - Vector3(0.04, 0, 0), t1, tail, 0.52, 1.0)
	b.tri(t0 + Vector3(0, 0.04, 0), t0 - Vector3(0, 0.04, 0), t1, tail, 0.52, 1.0)
	_meshes["rat"] = b.commit()
	return _meshes["rat"]


static func _diamond(r: Array) -> Array[Vector3]:
	var z: float = r[0]
	var y: float = r[1]
	var w: float = r[2]
	var h: float = r[3]
	# Eight sides: a rounded back, full flanks, a flat belly.
	return [Vector3(0, y + h, z), Vector3(w * 0.72, y + h * 0.62, z), Vector3(w, y - h * 0.1, z), Vector3(w * 0.7, y - h * 0.85, z),
		Vector3(0, y - h, z), Vector3(-w * 0.7, y - h * 0.85, z), Vector3(-w, y - h * 0.1, z), Vector3(-w * 0.72, y + h * 0.62, z)]


## A wall gecko, seen from over its back: a broad head, a narrow neck, a body,
## a tail to a point, four splayed legs with spread toes. Nearly flat.
static func gecko_mesh() -> ArrayMesh:
	if _meshes.has("gecko"):
		return _meshes["gecko"]
	var b := _Builder.new()
	# Outline nose to tail tip: z, half width, spine height, banded dark or not.
	var line: Array = [[-0.5, 0.0, 0.02, 0], [-0.43, 0.06, 0.05, 0], [-0.33, 0.07, 0.06, 0], [-0.26, 0.042, 0.05, 1], [-0.12, 0.072, 0.065, 0], [0.0, 0.075, 0.065, 1],
		[0.1, 0.055, 0.055, 0], [0.18, 0.036, 0.045, 1], [0.28, 0.026, 0.035, 0], [0.38, 0.016, 0.025, 1], [0.5, 0.0, 0.012, 0]]
	for i: int in line.size() - 1:
		var p: Array = line[i]
		var q: Array = line[i + 1]
		var tail: float = 1.0 if float(p[0]) >= 0.1 else 0.0
		var col := Color(float(p[3]), tail, 0.0)
		var v0: float = float(p[0]) + 0.5
		var v1: float = float(q[0]) + 0.5
		for s: float in [1.0, -1.0]:
			b.quad(Vector3(0, p[2], p[0]), Vector3(float(p[1]) * s, 0.008, p[0]), Vector3(float(q[1]) * s, 0.008, q[0]), Vector3(0, q[2], q[0]), col, v0, v1)
	for s: float in [1.0, -1.0]:
		# Eyes, on the head's edges.
		b.tri(Vector3(0.036 * s, 0.062, -0.4), Vector3(0.062 * s, 0.05, -0.37), Vector3(0.04 * s, 0.06, -0.345), Color(1.0, 0.0, 0.0, 0.0), 0.12)
		# Legs: out and forward (front), out and back (hind), a spread foot.
		for leg: Array in [[-0.2, -0.1, 0.0 if s > 0.0 else 1.0], [0.08, 0.1, 1.0 if s > 0.0 else 0.0]]:
			var z: float = leg[0]
			var sweep: float = leg[1]
			var col := Color(0.0, 0.5, float(leg[2]))
			var hip := Vector3(0.05 * s, 0.03, z)
			var knee := Vector3(0.13 * s, 0.035, z + sweep * 0.3)
			var foot := Vector3(0.19 * s, 0.006, z + sweep)
			var v: float = z + 0.5
			b.quad(hip + Vector3(0, 0, -0.018), knee + Vector3(0, 0, -0.016), knee + Vector3(0, 0, 0.016), hip + Vector3(0, 0, 0.018), col, v, v)
			b.quad(knee + Vector3(0, 0, -0.014), foot + Vector3(0, 0, -0.012), foot + Vector3(0, 0, 0.012), knee + Vector3(0, 0, 0.014), col, v, v)
			# Toes: a fan of three.
			for toe: float in [-0.05, 0.0, 0.05]:
				b.tri(foot + Vector3(0, 0, -0.012), foot + Vector3(0.05 * s, -0.003, toe + sweep * 0.2), foot + Vector3(0, 0, 0.012), Color(0.5, 0.5, float(leg[2])), v)
	_meshes["gecko"] = b.commit()
	return _meshes["gecko"]


## A rat's hole at the foot of a wall: a small dark arch with a broken rim.
## It faces +Z (out of the wall), its base on y = 0, a unit wide.
static func hole_mesh() -> ArrayMesh:
	if _meshes.has("hole"):
		return _meshes["hole"]
	var b := _Builder.new()
	var rim: Array[Vector3] = []
	var arch: Array[Vector3] = []
	var n: int = 7
	for k: int in n + 1:
		var a: float = PI * k / n
		# A ragged edge: the rim's radius wanders.
		var rag: float = 1.0 + 0.06 * sin(k * 2.3 + 0.7)
		rim.append(Vector3(cos(a) * 0.62 * rag, sin(a) * 0.95 * rag, 0.0))
		arch.append(Vector3(cos(a) * 0.5, sin(a) * 0.8, 0.012))
	for k: int in n:
		b.tri(Vector3.ZERO, rim[k], rim[k + 1], Color(0.5, 0.0, 0.0), 0.0)
		b.tri(Vector3(0, 0, 0.012), arch[k], arch[k + 1], Color(1.0, 0.0, 0.0), 0.0)
	_meshes["hole"] = b.commit()
	return _meshes["hole"]


## A kind's material: its three colours (the atlas's swatches: body, dark,
## pale) and how much it shows in the dark by itself.
static func material(def: CreatureDef) -> ShaderMaterial:
	if _materials.has(def.id):
		(_materials[def.id] as ShaderMaterial).set_shader_parameter("self_glow", def.self_glow)     # (the zoo's panel may have changed it)
		(_materials[def.id] as ShaderMaterial).set_shader_parameter("wing_share", def.roam)
		return _materials[def.id]
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("body_colour", def.palette[0] if def.palette.size() > 0 else Color(0.4, 0.35, 0.3))
	m.set_shader_parameter("dark_colour", def.palette[1] if def.palette.size() > 1 else Color(0.08, 0.07, 0.06))
	m.set_shader_parameter("pale_colour", def.palette[2] if def.palette.size() > 2 else Color(0.75, 0.65, 0.6))
	m.set_shader_parameter("self_glow", def.self_glow)
	m.set_shader_parameter("flat_body", 1.0 if def.habitat == "wall_lamp" else 0.0)
	_materials[def.id] = m
	return m


## The holes' material: nearly black inside, dark stone round it.
static func hole_material() -> ShaderMaterial:
	if _materials.has("hole"):
		return _materials["hole"]
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("body_colour", Color(0.1, 0.09, 0.08))
	m.set_shader_parameter("dark_colour", Color(0.004, 0.003, 0.003))
	m.set_shader_parameter("pale_colour", Color(0.075, 0.065, 0.055))
	m.set_shader_parameter("self_glow", 0.0)
	_materials["hole"] = m
	return m


## Collects flat triangles, each with its own normal.
class _Builder:
	extends RefCounted
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colours := PackedColorArray()
	var uvs := PackedVector2Array()

	func tri(a: Vector3, b: Vector3, c: Vector3, col: Color, v: float, v_last: float = -1.0) -> void:
		var n: Vector3 = (b - a).cross(c - a).normalized()
		if n.y < -0.001 or (absf(n.y) <= 0.001 and n.z < 0.0):
			n = -n
		var pts: Array[Vector3] = [a, b, c]
		for k: int in 3:
			verts.append(pts[k])
			normals.append(n)
			colours.append(col)
			uvs.append(Vector2(0.0, v_last if k == 2 and v_last >= 0.0 else v))

	func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color, v0: float, v1: float) -> void:
		var n: Vector3 = (b - a).cross(c - a).normalized()
		var out: Vector3 = (a + b + c + d) * 0.25
		# Outward: away from the body's middle line (x = 0, y about 0.15).
		if n.dot(Vector3(out.x, out.y - 0.12, 0.0)) < 0.0:
			n = -n
		var pts: Array[Vector3] = [a, b, c, a, c, d]
		var vs: Array[float] = [v0, v0, v1, v0, v1, v1]
		for k: int in 6:
			verts.append(pts[k])
			normals.append(n)
			colours.append(col)
			uvs.append(Vector2(0.0, vs[k]))

	func commit() -> ArrayMesh:
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_COLOR] = colours
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		return mesh

class_name EelBody
extends RefCounted
## The spiny eel's model and material (phase 20 step 3, C03), made in code. One
## unit long along -Z (the snout's tip at z -0.5, the tail's at +0.5): an
## instance's scale is its length. An eight-sided tube, thickest a third of the
## way back, a long fleshy snout, a low fin along the back and belly that runs
## into the pointed tail. UV.x runs snout to tail, UV.y round the body (0 the
## back, 1 the belly); creature_eel.gdshader colours it (mottled brown back,
## pale belly, a dark line through the eye) and bends it.
##
## Also the hole it lives in: a ragged dark disc facing +Z, a unit across.

const SHADER: Shader = preload("res://shaders/creature_eel.gdshader")
const HOLE_SHADER: Shader = preload("res://shaders/creature_crawler.gdshader")

static var _mesh: ArrayMesh
static var _hole: ArrayMesh
static var _materials: Dictionary = {}


static func mesh() -> ArrayMesh:
	if _mesh != null:
		return _mesh
	# Stations snout to tail: [z, half width, half height].
	var stations: Array = [[-0.5, 0.0, 0.0], [-0.47, 0.004, 0.004], [-0.43, 0.009, 0.009], [-0.39, 0.016, 0.017], [-0.33, 0.022, 0.024],
		[-0.22, 0.026, 0.03], [-0.08, 0.027, 0.031], [0.08, 0.025, 0.03], [0.22, 0.021, 0.027], [0.34, 0.015, 0.021], [0.43, 0.009, 0.014], [0.5, 0.0, 0.002]]
	var sides: int = 8
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in stations.size() - 1:
		var a: Array = stations[i]
		var b: Array = stations[i + 1]
		for k: int in sides:
			var t0: float = TAU * k / sides
			var t1: float = TAU * (k + 1) / sides
			var v0: float = 0.5 - 0.5 * cos(t0)     # (0 on the back, 1 under the belly)
			var v1: float = 0.5 - 0.5 * cos(t1)
			var p00 := Vector3(sin(t0) * float(a[1]), cos(t0) * float(a[2]), a[0])
			var p01 := Vector3(sin(t1) * float(a[1]), cos(t1) * float(a[2]), a[0])
			var p10 := Vector3(sin(t0) * float(b[1]), cos(t0) * float(b[2]), b[0])
			var p11 := Vector3(sin(t1) * float(b[1]), cos(t1) * float(b[2]), b[0])
			var u0: float = float(a[0]) + 0.5
			var u1: float = float(b[0]) + 0.5
			_tri(st, p00, p10, p11, Vector2(u0, v0), Vector2(u1, v0), Vector2(u1, v1))
			_tri(st, p00, p11, p01, Vector2(u0, v0), Vector2(u1, v1), Vector2(u0, v1))
	# The fins: a low ribbon along the back and the belly, from mid-body into
	# the tail's point (UV.y 0.02 / 0.98 marks them for the shader).
	for s: float in [1.0, -1.0]:
		var prev: Vector3 = Vector3.ZERO
		var prev_top: Vector3 = Vector3.ZERO
		for i: int in range(5, stations.size()):
			var a: Array = stations[i]
			var h: float = float(a[2])
			var fin: float = 0.012 if i < stations.size() - 1 else 0.004
			var base := Vector3(0, h * s, a[0])
			var top := Vector3(0, (h + fin) * s, float(a[0]) + 0.01)
			if i > 5:
				var vy: float = 0.02 if s > 0.0 else 0.98
				_tri(st, prev, base, top, Vector2(prev.z + 0.5, vy), Vector2(base.z + 0.5, vy), Vector2(top.z + 0.5, vy))
				_tri(st, prev, top, prev_top, Vector2(prev.z + 0.5, vy), Vector2(top.z + 0.5, vy), Vector2(prev_top.z + 0.5, vy))
			prev = base
			prev_top = top
	st.generate_normals()
	_mesh = st.commit()
	return _mesh


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ua: Vector2, ub: Vector2, uc: Vector2) -> void:
	st.set_uv(ua)
	st.add_vertex(a)
	st.set_uv(ub)
	st.add_vertex(b)
	st.set_uv(uc)
	st.add_vertex(c)


static func material(def: CreatureDef) -> ShaderMaterial:
	if _materials.has(def.id):
		return _materials[def.id]
	var m := ShaderMaterial.new()
	m.shader = SHADER
	var pal: PackedColorArray = def.palette
	if pal.size() >= 3:
		m.set_shader_parameter("dark_colour", pal[0])
		m.set_shader_parameter("body_colour", pal[1])
		m.set_shader_parameter("belly_colour", pal[2])
	m.set_shader_parameter("self_glow", def.self_glow)
	m.set_shader_parameter("glow_colour", def.glow_colour)
	_materials[def.id] = m
	return m


## A hole in stone: a ragged dark disc facing +Z, a unit across, its middle at
## the origin (creature_crawler's colours: rim dark stone, inside near black).
static func hole_mesh() -> ArrayMesh:
	if _hole != null:
		return _hole
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colours := PackedColorArray()
	var uvs := PackedVector2Array()
	var n: int = 9
	for k: int in n:
		var a0: float = TAU * k / n
		var a1: float = TAU * (k + 1) / n
		var rag0: float = 1.0 + 0.1 * sin(k * 2.3 + 0.7)
		var rag1: float = 1.0 + 0.1 * sin((k + 1) * 2.3 + 0.7)
		for ring: Array in [[0.5, 0.0, 0.5], [0.36, 0.008, 1.0]]:
			var r: float = ring[0]
			var z: float = ring[1]
			var col := Color(float(ring[2]), 0.0, 0.0)
			for p: Vector3 in [Vector3(0, 0, z), Vector3(cos(a0), sin(a0), 0) * r * rag0 + Vector3(0, 0, z), Vector3(cos(a1), sin(a1), 0) * r * rag1 + Vector3(0, 0, z)]:
				verts.append(p)
				normals.append(Vector3.BACK)
				colours.append(col)
				uvs.append(Vector2.ZERO)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colours
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	_hole = ArrayMesh.new()
	_hole.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return _hole


static func hole_material() -> ShaderMaterial:
	return GroundBody.hole_material()

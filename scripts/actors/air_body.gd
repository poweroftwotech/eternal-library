class_name AirBody
extends RefCounted
## The models of the animals of the air (phase 19 step 2), made in code like
## the fish (FishBody): a few triangles each, a unit long (nose at -Z, wings
## along x), scaled per animal. UV.x says how far out along a wing a corner
## is (0 at the body, 1 at the tip); UV.y is 1 on the glowworm's bead.

const MOTH_SHADER: Shader = preload("res://shaders/creature_moth.gdshader")
const BAT_SHADER: Shader = preload("res://shaders/creature_bat.gdshader")
const WORM_SHADER: Shader = preload("res://shaders/creature_glowworm.gdshader")

static var _meshes: Dictionary = {}
static var _materials: Dictionary = {}


## A moth: a thin body and two broad wings.
static func moth_mesh() -> ArrayMesh:
	if _meshes.has("moth"):
		return _meshes["moth"]
	var st := _Builder.new()
	# Body: a flat diamond.
	st.tri(Vector3(0, 0, -0.5), Vector3(0.08, 0, 0), Vector3(0, 0, 0.5), 0.0)
	st.tri(Vector3(0, 0, -0.5), Vector3(0, 0, 0.5), Vector3(-0.08, 0, 0), 0.0)
	for s: float in [1.0, -1.0]:
		var root_f := Vector3(0, 0, -0.3)
		var root_b := Vector3(0, 0, 0.25)
		var tip_f := Vector3(1.1 * s, 0, -0.15)
		var tip_b := Vector3(0.85 * s, 0, 0.4)
		st.quad(root_f, tip_f, tip_b, root_b, [0.0, 1.0, 1.0, 0.0])
	_meshes["moth"] = st.commit()
	return _meshes["moth"]


## A bat: a short body, two wings of three panels with a scalloped edge.
static func bat_mesh() -> ArrayMesh:
	if _meshes.has("bat"):
		return _meshes["bat"]
	var st := _Builder.new()
	st.tri(Vector3(0, 0, -0.5), Vector3(0.14, 0, -0.05), Vector3(0, 0, 0.5), 0.0)
	st.tri(Vector3(0, 0, -0.5), Vector3(0, 0, 0.5), Vector3(-0.14, 0, -0.05), 0.0)
	# Ears.
	st.tri(Vector3(0.05, 0, -0.45), Vector3(0.1, 0, -0.62), Vector3(0.12, 0, -0.4), 0.0)
	st.tri(Vector3(-0.05, 0, -0.45), Vector3(-0.12, 0, -0.4), Vector3(-0.1, 0, -0.62), 0.0)
	for s: float in [1.0, -1.0]:
		var edge: Array[Vector3] = [Vector3(0.12 * s, 0, -0.2), Vector3(0.6 * s, 0, -0.3), Vector3(1.05 * s, 0, -0.2), Vector3(1.5 * s, 0, 0.05)]
		var trail: Array[Vector3] = [Vector3(0.1 * s, 0, 0.3), Vector3(0.55 * s, 0, 0.22), Vector3(1.0 * s, 0, 0.3), Vector3(1.5 * s, 0, 0.05)]
		for k: int in 3:
			var u0: float = float(k) / 3.0
			var u1: float = float(k + 1) / 3.0
			st.quad(edge[k], edge[k + 1], trail[k + 1], trail[k], [u0, u1, u1, u0])
	_meshes["bat"] = st.commit()
	return _meshes["bat"]


## A glowworm: its silk thread hanging a unit down from the roof (two crossed
## strips, so it shows from any side), and its glowing bead at the end.
static func worm_mesh() -> ArrayMesh:
	if _meshes.has("worm"):
		return _meshes["worm"]
	var st := _Builder.new()
	var w: float = 0.5
	st.quad(Vector3(-w, 0, 0), Vector3(w, 0, 0), Vector3(w, -1, 0), Vector3(-w, -1, 0), [0.0, 0.0, 0.0, 0.0])
	st.quad(Vector3(0, 0, -w), Vector3(0, 0, w), Vector3(0, -1, w), Vector3(0, -1, -w), [0.0, 0.0, 0.0, 0.0])
	# The bead: a quad at the bottom that the shader turns to face the eye
	# (its corner in x, z: -1..1) and sizes so it never shrinks below a few
	# pixels, with a soft halo.
	var c := Vector3(0, -1, 0)
	st.quad(c + Vector3(-1, 0, -1), c + Vector3(1, 0, -1), c + Vector3(1, 0, 1), c + Vector3(-1, 0, 1), [0.0, 0.0, 0.0, 0.0], 1.0)
	_meshes["worm"] = st.commit()
	return _meshes["worm"]


static func material(def: CreatureDef) -> ShaderMaterial:
	if _materials.has(def.id):
		return _materials[def.id]
	var m := ShaderMaterial.new()
	match def.habitat:
		"flame":
			m.shader = MOTH_SHADER
			m.set_shader_parameter("wing_colour", def.palette[0] if def.palette.size() > 0 else Color(0.85, 0.8, 0.7))
			m.set_shader_parameter("body_colour", def.palette[1] if def.palette.size() > 1 else Color(0.5, 0.42, 0.3))
		_:
			if def.id == "bat":
				m.shader = BAT_SHADER
				m.set_shader_parameter("colour", def.palette[0] if def.palette.size() > 0 else Color(0.16, 0.12, 0.1))
				m.set_shader_parameter("self_glow", def.self_glow)
			else:
				m.shader = WORM_SHADER
	_materials[def.id] = m
	return m


## Collects triangles (both faces drawn by the shaders) into an ArrayMesh.
class _Builder:
	extends RefCounted
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()

	func tri(a: Vector3, b: Vector3, c: Vector3, u: float, v: float = 0.0) -> void:
		for p: Vector3 in [a, b, c]:
			verts.append(p)
			uvs.append(Vector2(u, v))

	func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, u: Array, v: float = 0.0) -> void:
		var pts: Array[Vector3] = [a, b, c, a, c, d]
		var us: Array = [u[0], u[1], u[2], u[0], u[2], u[3]]
		for k: int in 6:
			verts.append(pts[k])
			uvs.append(Vector2(float(us[k]), v))

	func commit() -> ArrayMesh:
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		var normals := PackedVector3Array()
		normals.resize(verts.size())
		normals.fill(Vector3.UP)
		arrays[Mesh.ARRAY_NORMAL] = normals
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		return mesh

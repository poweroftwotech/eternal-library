class_name FishBody
extends RefCounted
## A fish's model, skin and material, made from its CreatureDef (phase 19
## step 1). One unit long along -Z (nose at z -0.5, tail at +0.5): an
## instance's scale is its length. Six-sided body, forked tail, a small back
## fin; UV.x runs nose to tail and UV.y back to belly, so the skin is a side
## view: SKIN_LENGTH texels nose to tail, SKIN_ROWS from back to belly, one
## band per pattern. Made once per kind and kept.

const SHADER: Shader = preload("res://shaders/creature_fish.gdshader")
const CLEAR_SHADER: Shader = preload("res://shaders/creature_fish_clear.gdshader")
const SKIN_LENGTH: int = 16
const SKIN_ROWS: int = 8

static var _meshes: Dictionary = {}
static var _materials: Dictionary = {}


static func mesh(def: CreatureDef) -> ArrayMesh:
	if _meshes.has(def.id):
		return _meshes[def.id]
	var w: float = def.girth.x * 0.5
	var h: float = def.girth.y * 0.5
	# Stations nose to tail: [z, half width, half height].
	var stations: Array = [[-0.5, 0.0, 0.0], [-0.36, w * 0.75, h * 0.7], [-0.12, w, h], [0.14, w * 0.8, h * 0.78], [0.3, w * 0.42, h * 0.4], [0.37, w * 0.2, h * 0.22]]
	# Round the body: [x, y, v] on a unit section, back (v 0) to belly (v 1).
	var ring: Array = [[0.0, 1.0, 0.05], [0.85, 0.5, 0.3], [0.85, -0.5, 0.7], [0.0, -1.0, 0.95], [-0.85, -0.5, 0.7], [-0.85, 0.5, 0.3]]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in stations.size() - 1:
		var a: Array = stations[i]
		var b: Array = stations[i + 1]
		for k: int in ring.size():
			var r0: Array = ring[k]
			var r1: Array = ring[(k + 1) % ring.size()]
			var p00 := Vector3(r0[0] * a[1], r0[1] * a[2], a[0])
			var p01 := Vector3(r1[0] * a[1], r1[1] * a[2], a[0])
			var p10 := Vector3(r0[0] * b[1], r0[1] * b[2], b[0])
			var p11 := Vector3(r1[0] * b[1], r1[1] * b[2], b[0])
			var u0: float = a[0] + 0.5
			var u1: float = b[0] + 0.5
			_tri(st, p00, p10, p11, Vector2(u0, r0[2]), Vector2(u1, r0[2]), Vector2(u1, r1[2]))
			_tri(st, p00, p11, p01, Vector2(u0, r0[2]), Vector2(u1, r1[2]), Vector2(u0, r1[2]))
	# The forked tail: a flat fin from the root to two tips round a notch.
	var root_h: float = h * 0.22
	var fork: float = h * 1.15
	var rt := Vector3(0, root_h, 0.37)
	var rb := Vector3(0, -root_h, 0.37)
	var tt := Vector3(0, fork, 0.5)
	var tb := Vector3(0, -fork, 0.5)
	var notch := Vector3(0, 0, 0.45)
	var fv: Callable = func(p: Vector3) -> Vector2: return Vector2(p.z + 0.5, clampf(0.5 - p.y / (fork * 2.0), 0.05, 0.95))
	_tri(st, rt, tt, notch, fv.call(rt), fv.call(tt), fv.call(notch))
	_tri(st, rt, notch, rb, fv.call(rt), fv.call(notch), fv.call(rb))
	_tri(st, rb, notch, tb, fv.call(rb), fv.call(notch), fv.call(tb))
	# The back fin.
	var d0 := Vector3(0, h * 0.95, -0.14)
	var d1 := Vector3(0, h * 0.85, 0.12)
	var d2 := Vector3(0, h * 1.55, 0.02)
	_tri(st, d0, d2, d1, Vector2(0.36, 0.05), Vector2(0.52, 0.05), Vector2(0.62, 0.05))
	st.generate_normals()
	var m: ArrayMesh = st.commit()
	_meshes[def.id] = m
	return m


## The colour of the water a body is filled with (its material's deep tint,
## lifted; a plain sea-green when the material can't be read).
static func water_tint(b: WaterBody) -> Vector3:
	var c := Color(0.2, 0.36, 0.34)
	if b.material != "" and not b.material.contains("::") and ResourceLoader.exists(b.material):
		var m := load(b.material) as ShaderMaterial
		var deep: Variant = m.get_shader_parameter("deep_tint") if m != null else null
		if deep is Color:
			c = (deep as Color).lerp(Color(0.3, 0.5, 0.48), 0.35)
	return Vector3(c.r, c.g, c.b)


static func material(def: CreatureDef) -> ShaderMaterial:
	if _materials.has(def.id):
		return _materials[def.id]
	var m := ShaderMaterial.new()
	m.shader = SHADER
	if def.clarity > 0.0:
		m.shader = CLEAR_SHADER
		m.set_shader_parameter("clarity", def.clarity)
		m.render_priority = 10     # after the water
	m.set_shader_parameter("skin", ImageTexture.create_from_image(skin(def)))
	m.set_shader_parameter("patterns", float(def.patterns))
	m.set_shader_parameter("self_glow", def.self_glow)
	_materials[def.id] = m
	return m


## The side-view skin: one band of SKIN_ROWS per pattern, from the def's
## palette [body, accent, belly]: a darker back, the body colour (deeper or
## lighter by pattern), a pale belly, fins in the accent, an eye unless blind,
## pale patches by `patchiness`. Seeded by the kind, so it's always the same.
static func skin(def: CreatureDef) -> Image:
	var pal: PackedColorArray = def.palette if def.palette.size() >= 3 else PackedColorArray([Color("e8632a"), Color("f3b04a"), Color("f6e9d0")])
	var img := Image.create(SKIN_LENGTH, SKIN_ROWS * def.patterns, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(def.id))
	for p: int in def.patterns:
		var shade: float = [1.0, 0.82, 1.12, 0.94][p % 4]
		var body: Color = (pal[0] * shade).clamp() if p != 2 else pal[0].lerp(pal[1], 0.55)
		var patches: Dictionary = {}
		if def.patchiness > 0.0 and p % 2 == 1:
			for _i: int in roundi(def.patchiness * 6.0):
				var cx: int = rng.randi_range(3, SKIN_LENGTH - 5)
				var cy: int = rng.randi_range(0, SKIN_ROWS - 3)
				for dx: int in rng.randi_range(2, 4):
					for dy: int in rng.randi_range(1, 3):
						patches[Vector2i(cx + dx, cy + dy)] = true
		for x: int in SKIN_LENGTH:
			for y: int in SKIN_ROWS:
				var c: Color = body
				if y <= 1:
					c = body.darkened(0.25)
				elif y >= SKIN_ROWS - 2:
					c = pal[2]
				elif y == SKIN_ROWS - 3:
					c = body.lerp(pal[2], 0.5)
				if x >= SKIN_LENGTH - 2:
					c = pal[1].lerp(body, 0.35)     # the tail fin
				if patches.has(Vector2i(x, y)):
					c = pal[2]
				if (x + y) % 5 == 0 and x > 2 and x < SKIN_LENGTH - 3:
					c = c.lightened(0.06)     # scales catching the light, a texel at a time
				img.set_pixel(x, p * SKIN_ROWS + y, c)
		if not def.blind:
			img.set_pixel(2, p * SKIN_ROWS + 2, Color("141414"))
	return img


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ua: Vector2, ub: Vector2, uc: Vector2) -> void:
	st.set_uv(ua)
	st.add_vertex(a)
	st.set_uv(ub)
	st.add_vertex(b)
	st.set_uv(uc)
	st.add_vertex(c)

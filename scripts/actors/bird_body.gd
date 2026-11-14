class_name BirdBody
extends Node3D
## A small songbird's body (phase 20 step 1: the nightingale, C19), made in
## code: a few low-poly parts coloured per vertex, each on its own pivot so
## BirdBand can move them. Built at the real size of a 16 cm bird (metres),
## feet at the origin, beak toward -Z; BirdBand scales it per bird.
##
##   Head   turns in quick jerks, tilts up to sing; the lower beak (Jaw) opens
##   Tail   cocks up and fans (the nightingale's habit), spreads in flight
##   WingL/WingR  folded along the sides at rest; out and beating in flight
##   Throat swells while it sings
##
## The atlas's colours: warm brown above, a pale buff breast, a rufous tail, a
## big dark eye with a thin pale ring.

const SIZE: float = 0.16

static var _parts: Dictionary = {}
static var _material: StandardMaterial3D

var head: Node3D
var jaw: Node3D
var tail: Node3D
var wing_l: Node3D
var wing_r: Node3D
var throat: Node3D
var body: MeshInstance3D


func _init() -> void:
	var p: Dictionary = parts()
	body = _mesh(self, p["body"], Vector3(0, 0.05, 0))
	body.rotation.x = 0.22     # perched upright-ish: breast up, tail end down
	throat = _pivot(self, Vector3(0, 0.06, -0.027))
	_mesh(throat, p["throat"], Vector3.ZERO)
	head = _pivot(self, Vector3(0, 0.068, -0.03))
	_mesh(head, p["head"], Vector3(0, 0.011, -0.008))
	_mesh(head, p["beak"], Vector3(0, 0.011, -0.026))
	jaw = _pivot(head, Vector3(0, 0.008, -0.023))
	_mesh(jaw, p["jaw"], Vector3.ZERO)
	# The eyes: big and dark, each in a thin pale ring (their own small discs,
	# so they stay round and sharp on a head this small).
	for s: float in [1.0, -1.0]:
		var ring := _mesh(head, p["ring"], Vector3(0.0118 * s, 0.0135, -0.013))
		ring.rotation.y = s * PI * 0.5
		var eye := _mesh(head, p["eye"], Vector3(0.0124 * s, 0.0135, -0.013))
		eye.rotation.y = s * PI * 0.5
	tail = _pivot(self, Vector3(0, 0.047, 0.036))
	_mesh(tail, p["tail"], Vector3.ZERO)
	wing_l = _pivot(self, Vector3(0.018, 0.064, -0.018))
	_mesh(wing_l, p["wing"], Vector3.ZERO)
	wing_r = _pivot(self, Vector3(-0.018, 0.064, -0.018))
	var right := _mesh(wing_r, p["wing"], Vector3.ZERO)
	right.scale = Vector3(-1, 1, 1)
	for s: float in [1.0, -1.0]:
		_mesh(self, p["leg"], Vector3(0.008 * s, 0.0, -0.004))


func _pivot(parent: Node3D, at: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = at
	parent.add_child(n)
	return n


func _mesh(parent: Node3D, mesh: Mesh, at: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = at
	mi.material_override = material()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


## Folded (0) to spread and beating (1, with `beat` the wings' angle, -1..1).
func pose_wings(spread: float, beat: float) -> void:
	for side: int in 2:
		var w: Node3D = wing_l if side == 0 else wing_r
		var s: float = 1.0 if side == 0 else -1.0
		# Folded, a wing lies back along the body; spread, it swings out
		# sideways and beats up and down about the body's long axis.
		w.rotation = Vector3(0.0, s * spread * 1.45, s * (spread * beat * 1.1 + (1.0 - spread) * -0.12))


static func material() -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.vertex_color_use_as_albedo = true
		_material.vertex_color_is_srgb = true     # the atlas's swatches are sRGB
		_material.roughness = 0.95
		_material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _material


## The parts' meshes, made once.
static func parts() -> Dictionary:
	if not _parts.is_empty():
		return _parts
	var brown := Color("967652")     # (the atlas's 8a6e4e, a shade lighter: it sits in leaf shade)
	var dark := Color("5e4a35")
	var buff := Color("cfc1a6")     # (the atlas's efe3cc read as white in the court's sun)
	var breast := Color("bfa582")
	var rufous := Color("a8673a")
	var beak := Color("6e5444")
	var eye := Color("14100c")
	var ring := Color("e8dcc4")
	# Body: a slim egg, brown above, buff breast, paler belly.
	_parts["body"] = _egg(Vector3(0.036, 0.04, 0.084), func(n: Vector3, p: Vector3) -> Color:
		if n.y > 0.1:
			return brown.lerp(rufous, clampf(p.z * 14.0, 0.0, 0.45))     # warmer toward the rump
		return breast if n.y > -0.4 and p.z < 0.005 else buff)
	# The neck and throat: joins the head to the breast (no gap between).
	_parts["throat"] = _egg(Vector3(0.025, 0.032, 0.026), func(n: Vector3, _p: Vector3) -> Color: return brown if n.y > 0.25 and n.z > -0.3 else buff)
	# Head: smaller than the body's width, brown with a buff chin.
	_parts["head"] = _egg(Vector3(0.026, 0.027, 0.03), func(n: Vector3, _p: Vector3) -> Color:
		return buff if n.y < -0.35 else brown)
	_parts["eye"] = _disc(0.0038, eye)
	_parts["ring"] = _disc(0.0052, ring)
	_parts["beak"] = _cone(0.007, 0.016, beak)
	_parts["jaw"] = _cone(0.005, 0.013, beak.lightened(0.15))
	# Tail: long and rounded, the nightingale's warm rufous.
	_parts["tail"] = _fan(0.013, 0.034, 0.064, rufous, rufous.darkened(0.2))
	# Wing: a pointed blade, folded back along the side.
	_parts["wing"] = _blade(0.07, 0.028, dark, brown)
	_parts["leg"] = _stick(0.024, Color("9a7a68"))
	return _parts


## An ellipsoid of `size` (8 round, 5 up), coloured by `colour(normal, point)`.
static func _egg(size: Vector3, colour: Callable) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: int = 5
	var segs: int = 8
	var pts: Array = []
	for r: int in rings + 1:
		var lat: float = PI * float(r) / rings - PI * 0.5
		var row: Array = []
		for s: int in segs:
			var lon: float = TAU * float(s) / segs
			row.append(Vector3(cos(lat) * sin(lon), sin(lat), cos(lat) * cos(lon)))
		pts.append(row)
	for r: int in rings:
		for s: int in segs:
			var q: Array = [pts[r][s], pts[r][(s + 1) % segs], pts[r + 1][(s + 1) % segs], pts[r + 1][s]]
			for k: int in [0, 1, 2, 0, 2, 3]:
				var n: Vector3 = q[k]
				var p: Vector3 = n * size * 0.5
				st.set_color(colour.call(n, p))
				st.set_normal(n)
				st.add_vertex(p)
	return st.commit()


## A flat round disc facing +Z (turned to face sideways on the head).
static func _disc(radius: float, c: Color) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_color(c)
	st.set_normal(Vector3(0, 0, 1))
	for k: int in 8:
		var a: float = TAU * k / 8.0
		var b: float = TAU * (k + 1) / 8.0
		st.add_vertex(Vector3.ZERO)
		st.add_vertex(Vector3(cos(a), sin(a), 0) * radius)
		st.add_vertex(Vector3(cos(b), sin(b), 0) * radius)
	return st.commit()


## A cone along -Z: the beak.
static func _cone(radius: float, length: float, c: Color) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_color(c)
	var tip := Vector3(0, 0, -length)
	for k: int in 5:
		var a: float = TAU * k / 5.0
		var b: float = TAU * (k + 1) / 5.0
		st.add_vertex(Vector3(cos(a) * radius, sin(a) * radius * 0.7, 0))
		st.add_vertex(tip)
		st.add_vertex(Vector3(cos(b) * radius, sin(b) * radius * 0.7, 0))
	st.generate_normals()
	return st.commit()


## A tail: a fan from `root_w` wide to `tip_w` over `length` along +Z, closed
## and thick at the root (a bird's tail is a bundle of feathers, never a
## sheet: seen from the side a flat one read as a stick), thinning to the tip.
static func _fan(root_w: float, tip_w: float, length: float, c0: Color, c1: Color) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hr: float = 0.015     # thickness at the root (0.009 still read as a stick side on)
	var ht: float = 0.006     # at the tip
	var top: Array[Vector3] = [Vector3(-root_w * 0.5, hr * 0.5, 0), Vector3(root_w * 0.5, hr * 0.5, 0), Vector3(tip_w * 0.5, ht * 0.5, length), Vector3(-tip_w * 0.5, ht * 0.5, length)]
	var bot: Array[Vector3] = []
	for k: int in 4:
		var v: Vector3 = top[k]
		bot.append(Vector3(v.x, -v.y, v.z))
	var cols: Array[Color] = [c0, c0, c1, c1]
	var faces: Array = [[top, [0, 1, 2, 0, 2, 3]], [bot, [0, 2, 1, 0, 3, 2]]]
	for f: Array in faces:
		var pts: Array[Vector3] = f[0]
		for k: int in f[1]:
			st.set_color(cols[k])
			st.add_vertex(pts[k])
	# The sides and the tip end.
	for e: Array in [[0, 3], [1, 2], [3, 2], [0, 1]]:
		var a: int = e[0]
		var b: int = e[1]
		for v: Array in [[top[a], cols[a]], [bot[a], cols[a]], [bot[b], cols[b]], [top[a], cols[a]], [bot[b], cols[b]], [top[b], cols[b]]]:
			st.set_color((v[1] as Color).darkened(0.1))
			st.add_vertex(v[0])
	st.generate_normals()
	return st.commit()


## A wing: a pointed blade, root at the origin, `length` back along +Z when
## folded, `width` across, its outer edge paler (the coverts).
static func _blade(length: float, width: float, c0: Color, c1: Color) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var root_f := Vector3(0, 0, 0)
	var root_b := Vector3(0.002, -0.012, 0.012)
	var mid_f := Vector3(width * 0.45, 0.002, length * 0.45)
	var mid_b := Vector3(0.004, -0.018, length * 0.5)
	var tip := Vector3(width * 0.2, -0.01, length)
	for tri: Array in [[root_f, mid_f, mid_b, c1, c1, c0], [root_f, mid_b, root_b, c1, c0, c0], [mid_f, tip, mid_b, c1, c0, c0]]:
		for k: int in 3:
			st.set_color(tri[3 + k])
			st.add_vertex(tri[k])
	st.generate_normals()
	return st.commit()


## A leg: a thin upright stick from the foot to the body.
static func _stick(height: float, c: Color) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_color(c)
	var w: float = 0.0016
	for side: Array in [[Vector3(-w, 0, 0), Vector3(w, 0, 0)], [Vector3(0, 0, -w), Vector3(0, 0, w)]]:
		var a: Vector3 = side[0]
		var b: Vector3 = side[1]
		for v: Vector3 in [a, b, b + Vector3(0, height, 0), a, b + Vector3(0, height, 0), a + Vector3(0, height, 0)]:
			st.add_vertex(v)
		# Toes: a small forward fork.
	st.add_vertex(Vector3(0, 0.001, 0))
	st.add_vertex(Vector3(0.004, 0.001, -0.009))
	st.add_vertex(Vector3(-0.004, 0.001, -0.009))
	st.generate_normals()
	return st.commit()

class_name OrnateDoor
extends Node3D
## A door between places (ornate doors, 2026-11-01): a pair of lacquered
## cedar leaves filling a pointed arch to its crown, so it reads as special
## beside the plain doors of the kit. Gilt borders and a gilt meeting stile;
## on each leaf a sunken panel below and a gilt eight-pointed star (khatam)
## with a glowing turquoise boss above; rows of gilt studs; bronze ring pulls;
## over the springing a turquoise tympanum with gilt rays from a half sun and
## a glowing turquoise band; a thread of warm light under the leaves, as if
## lamps burned beyond.
##
## Built in code from the arch's three numbers (the kit's pointed(), see
## tools/kit_add_gorge.py), so one piece fits every opening: the Gorge's
## pishtaq, the kit's 3 m wall arch and the camp's back door. Its frame is the
## door's (Threshold's): x across, y up, -Z through the door; the leaves' face
## is at z = 0, their back at -THICK.

const THICK: float = 0.1
const BORDER: float = 0.09
const MAT_WOOD: Material = preload("res://kit/materials/persian_wood.tres")
const MAT_GOLD: StandardMaterial3D = preload("res://kit/materials/gorge_gold.tres")
const MAT_BRONZE: Material = preload("res://kit/materials/gorge_brass.tres")
const MAT_TILE: StandardMaterial3D = preload("res://kit/materials/gorge_tile.tres")
const MAT_PLANK: Material = preload("res://kit/materials/gorge_wood.tres")
const MAT_IRON: Material = preload("res://kit/materials/iron.tres")
const MAT_SILL: Material = preload("res://kit/materials/arch_stone.tres")
const ENAMEL := Color(0.25, 0.85, 0.8)
const SEAM := Color(1.0, 0.72, 0.38)

## The opening: half its width, the springing over the foot, the crown over
## the springing; the foot over y = 0.
var half: float = 1.5
var spring: float = 1.8
var rise: float = 1.775
var foot: float = 0.0
## A plain door (no gilt, no glow): a doorway that leads nowhere yet.
var plain: bool = false

var _st: Dictionary = {}     # Material -> SurfaceTool
static var _enamel: StandardMaterial3D
static var _seam: StandardMaterial3D
static var _gilt: StandardMaterial3D


static func make(h: float, s: float, r: float, f: float = 0.0, is_plain: bool = false) -> OrnateDoor:
	var d := OrnateDoor.new()
	d.half = h
	d.spring = s
	d.rise = r
	d.foot = f
	d.plain = is_plain
	return d


func _ready() -> void:
	_build()
	for m: Material in _st:
		var st: SurfaceTool = _st[m]
		var mi := MeshInstance3D.new()
		mi.name = "Door_" + (m.resource_name if m.resource_name != "" else "enamel")
		mi.mesh = st.commit()
		mi.material_override = m
		if m == _seam_mat():
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)


## The top of the crown, over y = 0.
func top() -> float:
	return foot + spring + rise


## Half the opening's width at height y (over y = 0).
func half_at(y: float) -> float:
	var o: PackedVector2Array = right_half(0.0, 24)
	for i: int in range(2, o.size() - 1):
		if y <= o[i + 1].y:
			return lerpf(o[i].x, o[i + 1].x, clampf((y - o[i].y) / maxf(o[i + 1].y - o[i].y, 0.0001), 0.0, 1.0))
	return half if y <= foot + spring else 0.0


## The right half of the outline, from the foot on the middle line round to
## the crown (x >= 0), `inset` in from the opening.
func right_half(inset: float, n: int = 10) -> PackedVector2Array:
	var c: float = (half * half - rise * rise) / (2.0 * half)
	var r: float = half - c - inset
	var a: float = atan2(rise, -c)
	var pts := PackedVector2Array([Vector2(0, foot + inset), Vector2(half - inset, foot + inset), Vector2(half - inset, foot + spring)])
	for i: int in range(1, n + 1):
		var p := Vector2(c + r * cos(a * i / n), foot + spring + r * sin(a * i / n))
		if p.x <= 0.0:
			break
		pts.append(p)
	pts.append(Vector2(0, _crown(inset)))
	return pts


func _crown(inset: float) -> float:
	var c: float = (half * half - rise * rise) / (2.0 * half)
	var r: float = half - c - inset
	return foot + spring + sqrt(maxf(r * r - c * c, 0.0))


func _build() -> void:
	if plain:
		_build_plain()
		return
	var front: float = 0.0
	# The leaves, a hair short of the crown each side of the stile.
	for side: float in [-1.0, 1.0]:
		_prism(_mirror(right_half(-0.04), side), -THICK, front, MAT_WOOD)
	var g0: float = front
	var g1: float = front + 0.03
	# Gilt border round each leaf, and the stile where they meet.
	for side: float in [-1.0, 1.0]:
		var o: PackedVector2Array = _mirror(right_half(0.0), side)
		for i: int in range(1, o.size() - 1):
			_bar(o[i], o[i + 1], BORDER, g0, g1, _gilt_mat(), true)
	_box(Vector3(-0.05, foot, g0), Vector3(0.05, _crown(0.0), g1 + 0.01), _gilt_mat())
	# The springing's rail and the tympanum above it: turquoise tile, gilt rays.
	var y_s: float = foot + spring
	_box(Vector3(-half, y_s - 0.07, g0), Vector3(half, y_s + 0.07, g1 + 0.005), _gilt_mat())
	_box(Vector3(-half + BORDER, y_s - 0.022, g1), Vector3(half - BORDER, y_s + 0.022, g1 + 0.012), _enamel_mat())
	for side: float in [-1.0, 1.0]:
		var tym := PackedVector2Array([Vector2(0, y_s + 0.07)])
		for p: Vector2 in right_half(BORDER):
			if p.y > y_s + 0.07 and p.x > 0.0:
				tym.append(p)
		tym.append(Vector2(half - BORDER, y_s + 0.07))
		tym.append(Vector2(0, _crown(BORDER)))
		_prism(_mirror(_hull(tym), side), g0, g0 + 0.012, MAT_TILE)
	var sun := Vector2(0, y_s + 0.07)
	var tip: float = _crown(BORDER)
	for i: int in 9:
		var ang: float = PI * (0.1 + 0.8 * i / 8.0)
		var dir := Vector2(cos(ang), sin(ang))
		var far: float = _reach(sun, dir, BORDER)
		_bar(sun + dir * 0.32, sun + dir * minf(far, tip), 0.045, g0, g1, _gilt_mat(), false)
	_disc(sun, 0.3, g0, g1 + 0.01, _gilt_mat(), 14, true)
	_disc(sun, 0.16, g1 + 0.01, g1 + 0.03, _enamel_mat(), 10, true)
	# Each leaf's panels: a sunken lower panel, a khatam star above.
	var w: float = half - BORDER - 0.05
	for side: float in [-1.0, 1.0]:
		var x0: float = side * 0.05
		var x1: float = side * (0.05 + w)
		var lo := Rect2(minf(x0, x1) + 0.12 * side * side, foot + 0.3, w - 0.24, (y_s - foot) * 0.32)
		_frame(lo, 0.05, g0, g1, _gilt_mat())
		var cx: float = (x0 + x1) * 0.5
		var cy: float = foot + 0.3 + (y_s - foot) * 0.32 + (y_s - 0.07 - (foot + 0.3 + (y_s - foot) * 0.32)) * 0.52
		var star_r: float = minf(w * 0.4, (y_s - foot) * 0.17)
		_star(Vector2(cx, cy), star_r, g0, g1 + 0.015, _gilt_mat())
		_disc(Vector2(cx, cy), star_r * 0.3, g1 + 0.015, g1 + 0.04, _enamel_mat(), 8, false)
		# Studs on the rails between the panels, and the ring pulls.
		for y: float in [foot + 0.16, foot + 0.3 + (y_s - foot) * 0.32 + 0.12]:
			var n: int = int(w / 0.2)
			for k: int in n:
				var x: float = minf(x0, x1) + (k + 0.5) * w / n
				_box(Vector3(x - 0.028, y - 0.028, g0), Vector3(x + 0.028, y + 0.028, g1 + 0.03), _gilt_mat())
		var ring_y: float = foot + minf(1.1, (y_s - foot) * 0.55)
		_disc(Vector2(side * 0.2, ring_y), 0.07, g0, g1 + 0.02, MAT_BRONZE, 8, false)
		_torus(Vector3(side * 0.2, ring_y - 0.1, g1 + 0.05), 0.11, 0.018, MAT_BRONZE)
	# Light under the leaves.
	_box(Vector3(-half + 0.06, foot, front + 0.002), Vector3(half - 0.06, foot + 0.012, front + 0.006), _seam_mat())


## A plain door (sealed doors, 2026-11-02): where a doorway leads nowhere yet.
## Weathered planks to the crown, three iron straps across with nail heads, an
## iron stile where the leaves meet, an iron lock plate and ring; nothing gilt
## and nothing lit, so it reads as a door, but not one of the ways between
## places.
func _build_plain() -> void:
	for side: float in [-1.0, 1.0]:
		_prism(_mirror(right_half(-0.04), side), -THICK, 0.0, MAT_PLANK)
	# The planks' joints: shallow grooves read as darker strips of iron-black.
	var n: int = int(half / 0.3)
	for k: int in range(1, n):
		var x: float = k * half / n
		for side: float in [-1.0, 1.0]:
			_box(Vector3(side * x - 0.012, foot, 0.0), Vector3(side * x + 0.012, maxf(foot, _y_at(x) - 0.05), 0.008), MAT_IRON)
	var y_s: float = foot + spring
	var straps: Array[float] = [foot + 0.35, foot + (y_s - foot) * 0.5, y_s - 0.15]
	for y: float in straps:
		_box(Vector3(-half, y - 0.07, 0.0), Vector3(half, y + 0.07, 0.03), MAT_IRON)
		for k: int in int(half / 0.25) * 2 + 1:
			var x: float = -half + 0.12 + k * 0.25
			if x > half - 0.1:
				break
			_box(Vector3(x - 0.03, y - 0.03, 0.03), Vector3(x + 0.03, y + 0.03, 0.05), MAT_IRON)
	_box(Vector3(-0.04, foot, 0.0), Vector3(0.04, _crown(0.0), 0.03), MAT_IRON)
	# The lock: a plate across the stile, a ring hanging from it.
	var lock_y: float = foot + minf(1.1, (y_s - foot) * 0.55)
	_box(Vector3(-0.12, lock_y - 0.16, 0.03), Vector3(0.12, lock_y + 0.12, 0.045), MAT_IRON)
	_torus(Vector3(0, lock_y - 0.2, 0.07), 0.09, 0.016, MAT_IRON)
	# A stone sill under the leaves, back into the wall (the floor can stop
	# short of the door where a gallery runs out).
	_box(Vector3(-half - 0.05, foot - 0.1, -0.45), Vector3(half + 0.05, foot + 0.06, 0.3), MAT_SILL)


## The arch's height over x (the outline's top at |x|).
func _y_at(x: float) -> float:
	var o: PackedVector2Array = right_half(0.0, 24)
	for i: int in range(2, o.size() - 1):
		if o[i + 1].x <= x:
			return lerpf(o[i].y, o[i + 1].y, clampf((o[i].x - x) / maxf(o[i].x - o[i + 1].x, 0.0001), 0.0, 1.0))
	return _crown(0.0)


## How far from `o` along `dir` the tympanum reaches, `inset` in from the arch.
func _reach(o: Vector2, dir: Vector2, inset: float) -> float:
	var d: float = 0.0
	while d < 4.0:
		var p: Vector2 = o + dir * (d + 0.02)
		if p.y > _crown(inset) or absf(p.x) > half_at(p.y) - inset:
			return d
		d += 0.02
	return d


func _mirror(pts: PackedVector2Array, side: float) -> PackedVector2Array:
	if side > 0:
		return pts
	var out := PackedVector2Array()
	for p: Vector2 in pts:
		out.append(Vector2(-p.x, p.y))
	return out


func _hull(pts: PackedVector2Array) -> PackedVector2Array:
	return Geometry2D.convex_hull(pts)


# --- geometry: flat-shaded triangles, a SurfaceTool per material --------------

func _surface(m: Material) -> SurfaceTool:
	if not _st.has(m):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_st[m] = st
	return _st[m]


## A triangle facing `n` (Godot's front faces wind clockwise seen from the front).
func _tri(m: Material, a: Vector3, b: Vector3, c: Vector3, n: Vector3) -> void:
	var st: SurfaceTool = _surface(m)
	if (b - a).cross(c - a).dot(n) > 0.0:
		var t: Vector3 = b
		b = c
		c = t
	for v: Vector3 in [a, b, c]:
		st.set_normal(n)
		st.set_uv(Vector2(v.x, v.y))
		st.add_vertex(v)


func _quad(m: Material, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3) -> void:
	_tri(m, a, b, c, n)
	_tri(m, a, c, d, n)


## `poly` (x, y) extruded from z0 to z1: its faces, back and sides.
func _prism(poly: PackedVector2Array, z0: float, z1: float, m: Material) -> void:
	if poly.size() < 3:
		return
	var idx: PackedInt32Array = Geometry2D.triangulate_polygon(poly)
	for i: int in range(0, idx.size(), 3):
		var a: Vector2 = poly[idx[i]]
		var b: Vector2 = poly[idx[i + 1]]
		var c: Vector2 = poly[idx[i + 2]]
		_tri(m, Vector3(a.x, a.y, z1), Vector3(b.x, b.y, z1), Vector3(c.x, c.y, z1), Vector3.BACK)
		_tri(m, Vector3(a.x, a.y, z0), Vector3(b.x, b.y, z0), Vector3(c.x, c.y, z0), Vector3.FORWARD)
	var mid := Vector2.ZERO
	for p: Vector2 in poly:
		mid += p / poly.size()
	for i: int in poly.size():
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % poly.size()]
		if a.distance_to(b) < 0.0001:
			continue
		var e: Vector2 = (b - a).normalized()
		var n2 := Vector2(e.y, -e.x)
		if n2.dot((a + b) * 0.5 - mid) < 0.0:
			n2 = -n2
		_quad(m, Vector3(a.x, a.y, z0), Vector3(b.x, b.y, z0), Vector3(b.x, b.y, z1), Vector3(a.x, a.y, z1), Vector3(n2.x, n2.y, 0))


## A bar `w` wide from a to b (inside the outline if `inward`: on its left
## going round it clockwise… either way, its centre line is pulled in by w/2).
func _bar(a: Vector2, b: Vector2, w: float, z0: float, z1: float, m: Material, inward: bool) -> void:
	var e: Vector2 = (b - a).normalized()
	var n2 := Vector2(-e.y, e.x)
	if inward:
		var mid := Vector2(0, foot + spring * 0.5)
		if n2.dot(mid - (a + b) * 0.5) < 0.0:
			n2 = -n2
		a += n2 * w * 0.5
		b += n2 * w * 0.5
		a -= e * w * 0.5
		b += e * w * 0.5
	var h: Vector2 = n2 * w * 0.5
	_prism(PackedVector2Array([a - h, b - h, b + h, a + h]), z0, z1, m)


func _box(lo: Vector3, hi: Vector3, m: Material) -> void:
	_prism(PackedVector2Array([Vector2(lo.x, lo.y), Vector2(hi.x, lo.y), Vector2(hi.x, hi.y), Vector2(lo.x, hi.y)]), lo.z, hi.z, m)


func _frame(r: Rect2, w: float, z0: float, z1: float, m: Material) -> void:
	_box(Vector3(r.position.x, r.position.y, z0), Vector3(r.end.x, r.position.y + w, z1), m)
	_box(Vector3(r.position.x, r.end.y - w, z0), Vector3(r.end.x, r.end.y, z1), m)
	_box(Vector3(r.position.x, r.position.y, z0), Vector3(r.position.x + w, r.end.y, z1), m)
	_box(Vector3(r.end.x - w, r.position.y, z0), Vector3(r.end.x, r.end.y, z1), m)


## A disc (a half disc, its flat side down, if `upper`) of `n` sides.
func _disc(o: Vector2, r: float, z0: float, z1: float, m: Material, n: int, upper: bool) -> void:
	var pts := PackedVector2Array()
	for i: int in n + (1 if upper else 0):
		var a: float = (PI * i / n) if upper else (TAU * i / n + PI / n)
		pts.append(o + Vector2(cos(a), sin(a)) * r)
	_prism(pts, z0, z1, m)


## An eight-pointed star: two squares, one turned 45°.
func _star(o: Vector2, r: float, z0: float, z1: float, m: Material) -> void:
	for turn: float in [0.0, PI / 4]:
		var sq := PackedVector2Array()
		for i: int in 4:
			var a: float = turn + PI / 4 + TAU * i / 4
			sq.append(o + Vector2(cos(a), sin(a)) * r)
		_prism(sq, z0, z1 + (0.008 if turn > 0 else 0.0), m)


## A ring pull hanging in the door's plane (its axis along Z).
func _torus(c: Vector3, r: float, tube: float, m: Material) -> void:
	var n: int = 12
	var k: int = 6
	for i: int in n:
		for j: int in k:
			var p: Array[Vector3] = []
			for d: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
				var a: float = TAU * (i + d.x) / n
				var b: float = TAU * (j + d.y) / k
				var ring := Vector3(cos(a), sin(a), 0)
				p.append(c + ring * (r + tube * cos(b)) + Vector3(0, 0, tube * sin(b)))
			var mid: Vector3 = (p[0] + p[1] + p[2] + p[3]) * 0.25
			var a0: float = TAU * (i + 0.5) / n
			var nrm: Vector3 = (mid - (c + Vector3(cos(a0), sin(a0), 0) * r)).normalized()
			_quad(m, p[0], p[1], p[2], p[3], nrm)


## Gold leaf: the Gorge's gold, catching a little light even in the dark so
## the pattern reads from across the gorge.
static func _gilt_mat() -> StandardMaterial3D:
	if _gilt == null:
		_gilt = MAT_GOLD.duplicate() as StandardMaterial3D
		_gilt.resource_name = "door_gilt"
		_gilt.metallic = 0.6
		_gilt.roughness = 0.4
		_gilt.emission_enabled = true
		_gilt.emission = Color(1.0, 0.78, 0.45)
		_gilt.emission_texture = MAT_GOLD.albedo_texture
		_gilt.emission_energy_multiplier = 0.15
	return _gilt


## Turquoise enamel: the Gorge's tile, glowing faintly through its pattern.
static func _enamel_mat() -> StandardMaterial3D:
	if _enamel == null:
		_enamel = MAT_TILE.duplicate() as StandardMaterial3D
		_enamel.resource_name = "door_enamel"
		_enamel.albedo_color = Color(0.7, 1.0, 0.95)
		_enamel.emission_enabled = true
		_enamel.emission = ENAMEL
		_enamel.emission_texture = MAT_TILE.albedo_texture
		_enamel.emission_energy_multiplier = 0.7
	return _enamel


static func _seam_mat() -> StandardMaterial3D:
	if _seam == null:
		_seam = StandardMaterial3D.new()
		_seam.resource_name = "door_seam"
		_seam.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_seam.albedo_color = SEAM
	return _seam

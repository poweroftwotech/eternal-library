class_name OrosiGlass
extends RefCounted
## The Orosi Scriptorium's glass (phase 17, R08): the pixel pictures of its
## three windows in each palette, and the light each window throws across the
## hall (a SpotLight3D carrying a picture of its glass, a "projector").
##
## tools/r08_glass.gd draws the pictures into assets/textures/px/ once; apply()
## puts a palette on an sc_orosi_wall module at run time.
##
## A window's glass: coloured diamond panes in the lower sash, round the
## mullions and the meeting rail, and a sunburst of rays and rings in the
## arch's head, in dark leading. The light behind it (tools/kit_add_r08.py's
## LIGHT_orosi) stands over the moss garden; its cone is opened just enough to
## take in the whole window, and its picture is the window seen from the light,
## so the coloured patches on the floor are the window's own panes.

const PALETTES: Array[String] = ["ruby_cobalt", "saffron_green", "spectrum"]
## Pane colours by palette: primary, secondary, accent, the fourth ring, and
## the pale panes round the edges.
const COLOURS: Dictionary = {
	"ruby_cobalt": [Color("a8243a"), Color("2a4fae"), Color("d9a530"), Color("7a2a6a"), Color("e6dcc4")],
	"saffron_green": [Color("e0a020"), Color("2f8a4a"), Color("c4682a"), Color("8ab040"), Color("e6dcc4")],
	"spectrum": [Color("c0392b"), Color("2f6fb0"), Color("e0b030"), Color("3a9a5a"), Color("e6dcc4")],
}
const LEAD: Color = Color("24170e")
const TEXELS_PER_M: float = 32.0
const PROJECTOR_SIZE: int = 256
const TEX_DIR: String = "res://assets/textures/px/"
const MATERIAL_DIR: String = "res://kit/materials/"
const WALL_SCENE: String = "res://kit/modules/walls/sc_orosi_wall.tscn"
## The window's sash, as fractions of its springing height (tools/kit_add_r08.py frame_bars).
const MEETING_RAIL: float = 0.42
const SPOT_EDGE: float = 0.05
## The far wall's two faces in its frame (tools/kit_add_r08.py: the room face on
## Blender Y 0, THICK 0.5 behind it).
const WALL_FRONT_Z: float = 0.0
const WALL_BACK_Z: float = -0.5


## The glass picture's file for a window kind ("mid" or "side") in a palette.
static func glass_path(kind: String, palette: String) -> String:
	return TEX_DIR + "sc_glass_%s_%s.png" % [kind, palette]


## The light picture's file for window `index` (0..2) in a palette.
static func projector_path(index: int, palette: String) -> String:
	return TEX_DIR + "sc_orosi_light_%d_%s.png" % [index, palette]


static func kind_of(index: int) -> String:
	return "mid" if index == 1 else "side"


## Draws a window's glass: `width` x `height` metres, its arch springing at
## `spring` metres over the sill (the window's outline is pointed() of
## tools/kit_add_r08.py; outside it the picture is clear). Image row 0 is the top.
static func draw(width: float, height: float, spring: float, palette: String) -> Image:
	var w: int = maxi(8, int(round(width * TEXELS_PER_M)))
	var h: int = maxi(8, int(round(height * TEXELS_PER_M)))
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c: Array = COLOURS[palette]
	var spring_px: float = spring * TEXELS_PER_M      # from the bottom
	var half_px: float = w / 2.0
	var cell: float = 9.0      # a diamond's half diagonal, in texels (about 0.28 m)
	for py: int in h:
		var zb: float = h - 1 - py + 0.5      # texels from the bottom
		for px: int in w:
			var x: float = px + 0.5
			var col: Color
			if zb <= spring_px:
				col = _sash(x, zb, w, spring_px, cell, c)
			else:
				col = _head(x - half_px, zb - spring_px, half_px, h - spring_px, c)
			img.set_pixel(px, py, col)
	# Clear everything outside the pointed head (the same curve the mesh uses).
	for py: int in h:
		var zb2: float = (h - 1 - py + 0.5) / TEXELS_PER_M
		if zb2 <= spring:
			continue
		var limit: float = _arch_half(width / 2.0, height - spring, zb2 - spring)
		for px: int in w:
			var xm: float = (px + 0.5) / TEXELS_PER_M - width / 2.0
			if absf(xm) > limit:
				img.set_pixel(px, py, Color(0, 0, 0, 0))
			elif absf(xm) > limit - 1.5 / TEXELS_PER_M:
				img.set_pixel(px, py, LEAD)
	return img


## The arch's half width at `z` over its springing (pointed(), a two-centred arch).
static func _arch_half(half: float, rise: float, z: float) -> float:
	var centre: float = (half * half - rise * rise) / (2.0 * half)
	var cr: float = half - centre
	if z >= rise:
		return 0.0
	return maxf(0.0, -centre + sqrt(maxf(0.0, cr * cr - z * z)))


## The lower sash: three lights between the mullions, each a field of diamonds
## in rings round its middle, a pale border, leading between.
static func _sash(x: float, z: float, w: int, spring_px: float, cell: float, c: Array) -> Color:
	var third: float = w / 3.0
	var col_i: int = clampi(int(x / third), 0, 2)
	var lx: float = x - col_i * third
	var rail: float = spring_px * MEETING_RAIL
	var lower: bool = z < rail
	var lz: float = z if lower else z - rail
	var fh: float = rail if lower else spring_px - rail
	# the wood: mullions, transom, rail, and the frame round the edge
	if lx < 1.5 or lx > third - 1.5 or z < 2.0 or absf(z - rail) < 1.5 or z > spring_px - 1.5:
		return LEAD
	# a pale border two texels in
	if lx < 4.0 or lx > third - 4.0 or lz < 4.0 or lz > fh - 4.0:
		if lx < 5.0 and lx >= 4.0 or lx <= third - 4.0 and lx > third - 5.0 or lz < 5.0 and lz >= 4.0 or lz <= fh - 4.0 and lz > fh - 5.0:
			return LEAD
		return c[4]
	# diamonds: rotate 45 degrees, a square grid, rings from the field's middle
	var cx: float = lx - third / 2.0
	var cz: float = lz - fh / 2.0
	var a: float = (cx + cz) / cell
	var b: float = (cx - cz) / cell
	var fa: float = a - floor(a)
	var fb: float = b - floor(b)
	if fa < 0.12 or fb < 0.12:
		return LEAD
	var ring: int = int(absf(floor(a) + 0.5) + absf(floor(b) + 0.5))
	return c[[2, 0, 1, 0, 3, 1][ring % 6]]


## The head: a sunburst from the middle of the springing line. A gold half-sun,
## then rings of rays in turn.
static func _head(x: float, z: float, half: float, rise: float, c: Array) -> Color:
	var r: float = sqrt(x * x + z * z)
	if z < 1.5:
		return LEAD      # the transom
	var sun: float = half * 0.28
	if absf(r - sun) < 0.8:
		return LEAD
	if r < sun:
		return c[2]
	var ang: float = atan2(z, x)      # 0 .. PI
	var rays: int = 12
	var t: float = ang / PI * rays
	if t - floor(t) < 0.1 * (sun / maxf(r, 1.0)) * 3.0 + 0.05:
		return LEAD
	var ring_w: float = (maxf(half, rise) - sun) / 3.0
	var ring: int = int((r - sun) / ring_w)
	var dr: float = (r - sun) - ring * ring_w
	if dr < 1.0:
		return LEAD
	var ray: int = int(t)
	var pick: int = (ray + ring) % 2
	if ring == 0:
		return c[0] if pick == 0 else c[1]
	if ring == 1:
		return c[3] if pick == 0 else c[2]
	return c[1] if pick == 0 else c[0]


## The spot angle (degrees) for a window's light: it takes in every corner of
## the glass, a degree to spare. Godot spreads the picture across the whole cone
## (its edges at the spot angle, through the light's shadow camera).
static func cone_for(light_xform: Transform3D, outline: PackedVector3Array) -> float:
	var axis: Vector3 = -light_xform.basis.z.normalized()
	var widest: float = 0.0
	for p: Vector3 in outline:
		widest = maxf(widest, axis.angle_to((p - light_xform.origin).normalized()))
	return minf(89.0, rad_to_deg(widest) + 1.0)


## The window as seen from its light: each texel of the light's square picture
## is a ray in the cone; where it passes the glass it takes the pane's colour
## (leading and wood are dark), elsewhere dark. A ray must also clear the
## opening at the wall's two faces: steep rays are cut by the 0.5 m of stone over
## the arch, as the middle light's real shadow cuts them (step 1 captures).
## `angle_deg` is the light's spot angle (cone_for). `outline` is the glass in
## the wall's frame (a flat face at constant z); `glass` the window's picture.
static func project(light_xform: Transform3D, angle_deg: float, outline: PackedVector3Array, glass: Image) -> Image:
	var n: int = PROJECTOR_SIZE
	var img := Image.create(n, n, false, Image.FORMAT_RGB8)
	var plane_z: float = outline[0].z
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	var poly := PackedVector2Array()
	for p: Vector3 in outline:
		poly.append(Vector2(p.x, p.y))
		lo = lo.min(Vector2(p.x, p.y))
		hi = hi.max(Vector2(p.x, p.y))
	var tan_a: float = tan(deg_to_rad(angle_deg))
	var b: Basis = light_xform.basis.orthonormalized()
	var o: Vector3 = light_xform.origin
	for py: int in n:
		for px: int in n:
			var u: float = ((px + 0.5) / n * 2.0 - 1.0) * tan_a
			var v: float = (1.0 - (py + 0.5) / n * 2.0) * tan_a
			var d: Vector3 = b * Vector3(u, v, -1.0)
			var col := Color(0, 0, 0)
			if absf(d.z) > 1e-6:
				var t: float = (plane_z - o.z) / d.z
				if t > 0.0:
					var hit: Vector3 = o + d * t
					var p2 := Vector2(hit.x, hit.y)
					var clear: bool = Geometry2D.is_point_in_polygon(p2, poly)
					for face_z: float in [WALL_FRONT_Z, WALL_BACK_Z]:
						var tf: float = (face_z - o.z) / d.z
						var hf: Vector3 = o + d * tf
						clear = clear and Geometry2D.is_point_in_polygon(Vector2(hf.x, hf.y), poly)
					if clear:
						var gu: float = (p2.x - lo.x) / (hi.x - lo.x)
						var gv: float = (p2.y - lo.y) / (hi.y - lo.y)
						var gx: int = clampi(int(gu * glass.get_width()), 0, glass.get_width() - 1)
						var gy: int = clampi(int((1.0 - gv) * glass.get_height()), 0, glass.get_height() - 1)
						var g: Color = glass.get_pixel(gx, gy)
						if g.a > 0.5 and g != LEAD:
							col = Color(g.r, g.g, g.b)
			if px < 2 or py < 2 or px >= n - 2 or py >= n - 2:
				col = Color(0, 0, 0)     # dark past the picture: Godot repeats its edge
			img.set_pixel(px, py, col)
	return img


## The glass's outline (its face's vertices) in `wall`'s frame.
static func outline_of(glass: MeshInstance3D, wall: Node3D) -> PackedVector3Array:
	var out := PackedVector3Array()
	var to_wall: Transform3D = wall.global_transform.affine_inverse() * glass.global_transform if glass.is_inside_tree() else _local_chain(glass, wall)
	var arrays: Array = glass.mesh.surface_get_arrays(0)
	var mid := Vector3.ZERO
	var pts: Array[Vector3] = []
	for v: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
		var p: Vector3 = to_wall * v
		if pts.any(func(q: Vector3) -> bool: return q.distance_to(p) < 0.001):
			continue
		pts.append(p)
		mid += p
	mid /= maxf(1.0, pts.size())
	# In order round the outline (the arch is star-shaped from its middle).
	pts.sort_custom(func(a: Vector3, b: Vector3) -> bool: return atan2(a.y - mid.y, a.x - mid.x) < atan2(b.y - mid.y, b.x - mid.x))
	for p: Vector3 in pts:
		out.append(p)
	return out


static func _local_chain(n: Node3D, top: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var cur: Node = n
	while cur != null and cur != top:
		if cur is Node3D:
			t = (cur as Node3D).transform * t
		cur = cur.get_parent()
	return t


## The wall's window glass meshes and lights, by window index.
static func parts(wall: Node3D) -> Dictionary:
	var glass: Dictionary = {}
	var lights: Dictionary = {}
	for n: Node in wall.find_children("*", "", true, false):
		var nm: String = String(n.name)
		if n is MeshInstance3D and nm.contains("glass"):
			glass[int(nm.right(1))] = n
		elif n is SpotLight3D and n.has_meta("window"):
			lights[int(n.get_meta("window"))] = n
	return {"glass": glass, "lights": lights}


## Puts `palette` on an sc_orosi_wall: each window's glass material and its
## light's picture, cone and shadow (every window light is shadowed: see below).
static func apply(wall: Node3D, palette: String) -> void:
	var p: Dictionary = parts(wall)
	for i: int in p["glass"]:
		var mi: MeshInstance3D = p["glass"][i]
		var mat_path: String = MATERIAL_DIR + "emit_sc_glass_%s_%s.tres" % [kind_of(i), palette]
		if ResourceLoader.exists(mat_path):
			mi.material_override = load(mat_path)
	for i: int in p["lights"]:
		var light: SpotLight3D = p["lights"][i]
		if p["glass"].has(i):
			light.spot_angle = cone_for(_local_chain(light, wall), outline_of(p["glass"][i], wall))
		# Even across the cone: the picture draws the window's edge, not the cone
		# (Godot dims by 1 - rim^(1/this), so a small value keeps the cone flat).
		light.spot_angle_attenuation = SPOT_EDGE
		var pic: String = projector_path(i, palette)
		if ResourceLoader.exists(pic):
			light.light_projector = load(pic)
		# Every window light casts shadows, always: Godot 4.7 doesn't keep a
		# shadowless spot light's picture in place (it is drawn with stale
		# placement left from earlier frames, so a patch appeared, vanished and
		# seemed to follow you: reports 2026-11-08_00-42-40 and 00-49-34..00-50-10).
		# LightBudget leaves "shadow_always" lights out of its ranking, which
		# would otherwise take the shadow off a far one.
		light.shadow_enabled = true
		light.shadow_opacity = 1.0
		light.set_meta("shadow_always", true)
		# Glass light is diffuse: no highlights.
		light.light_specular = 0.0
	# The glass's glow on the hall takes the palette's colours, mixed and softened.
	for n: Node in wall.find_children("LIGHT_orosi_bounce*", "OmniLight3D", true, false):
		(n as OmniLight3D).light_color = bounce_colour(palette)
		(n as OmniLight3D).light_specular = 0.1     # no glints on the glass or floor


## A palette's panes mixed (the four strong ones), pulled halfway to warm white.
static func bounce_colour(palette: String) -> Color:
	var c: Array = COLOURS[palette]
	var mix := Color(0, 0, 0)
	for k: int in 4:
		mix += c[k] as Color
	mix = mix / 4.0
	var top: float = maxf(mix.r, maxf(mix.g, mix.b))
	return (mix / top).lerp(Color(1.0, 0.9, 0.78), 0.5)

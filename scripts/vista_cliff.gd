extends RefCounted
## Exterior slice 6 (ART_DIRECTION.md section 8): the reading room is tunnelled
## into solid rock. A cliff face rises at the balcony's parapet line from the
## cavern floor into the vault, and the balcony becomes a loggia carved into it:
## rock cheeks at the sides, a rock back wall around the gallery passage, and a
## tall pointed iwan with a mosaic tympanum over the canopy. Higher up, a few
## lit rock-cut windows hint at more rooms inside. Render-only: the balcony's
## own collision and guards (vista.build_balcony) are untouched.
## Runs after vista_foreground.gd, before vista_light.gd.

const Cavern = preload("res://scripts/cavern.gd")

const FACE_Z: float = -28.45                 # just outside the front parapet and guard
const LOGGIA_X: Vector2 = Vector2(-7.55, 5.55)  # flush with the balcony slab's sides
const LOGGIA_FLOOR: float = 2.2
const LOGGIA_TOP: float = 9.1                # top of the canopy slab
const LOGGIA_BACK: float = -18.4             # behind the loggia's back bookcases
const PASSAGE: Rect2 = Rect2(-3.5, 2.2, 5.0, 5.3)  # x, y, w, h of the gallery opening
const CLIFF_X: Vector2 = Vector2(-160.0, 160.0)
const CLIFF_TOP: float = 74.0                # above the vault, which hides the rest
const RELIEF: float = 3.0                    # rough rock bulges up to ~6 m toward the gorge
const DRESSED: Rect2 = Rect2(-14.0, 0.0, 26.0, 23.0)  # flat quarried surround of the loggia
## Rock-cut windows: [x, sill y].
const WINDOWS: Array = [[-22.0, 16.0], [17.0, 13.0], [-34.0, 27.0], [9.0, 30.0], [30.0, 24.0], [-12.0, 38.0], [44.0, 35.0]]
const WINDOW_SIZE: Vector2 = Vector2(3.2, 5.0)

var vista
var world
var art
var cavern
var noise := FastNoiseLite.new()

func _init(owner) -> void:
	vista = owner
	world = owner.world
	art = owner.art
	cavern = Cavern.new(owner)
	noise.seed = 7741
	noise.frequency = .05

func build() -> void:
	var rock := SurfaceTool.new()
	rock.begin(Mesh.PRIMITIVE_TRIANGLES)
	face(rock)
	loggia_rock(rock)
	var previous: int = art.render_layer
	art.render_layer = 4
	var node: MeshInstance3D = art.mesh_node(rock.commit(), Vector3.ZERO, art.mat("gorge_roof"))
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	art.render_layer = previous
	iwan()
	for data: Array in WINDOWS:
		window(data[0], data[1])

## How far the rock stands proud of the face plane (toward the gorge, -Z).
## Zero on the dressed surround and around every window.
func relief(x: float, y: float) -> float:
	var r: float = RELIEF * (1.0 + noise.get_noise_2d(x, y)) + noise.get_noise_2d(x * 4.0, y * 4.0) * .8
	var flat: float = dressed_distance(x, y)
	return maxf(r, 0.0) * smoothstep(0.0, 5.0, flat)

func dressed_distance(x: float, y: float) -> float:
	var dx: float = maxf(DRESSED.position.x - x, x - DRESSED.end.x)
	var dy: float = y - DRESSED.end.y
	var d: float = maxf(maxf(dx, dy), 0.0)
	for data: Array in WINDOWS:
		var w: float = Vector2(x - data[0], (y - data[1] - WINDOW_SIZE.y * .5) * .7).length() - WINDOW_SIZE.y * .6
		d = minf(d, maxf(w, 0.0))
	return d

func face(surface: SurfaceTool) -> void:
	var xs: Array = []
	var x: float = CLIFF_X.x
	while x <= CLIFF_X.y + .01:
		xs.append(x)
		x += 2.0
	# The loggia's sides and top are exact grid lines, so its opening is a clean hole.
	for edge: float in [LOGGIA_X.x, LOGGIA_X.y]:
		if not xs.has(edge):
			xs.append(edge)
	xs.sort()
	var ys: Array = [LOGGIA_FLOOR, 4.5, 6.8, LOGGIA_TOP]
	while ys.back() < CLIFF_TOP:
		ys.append(ys.back() + 2.5)
	var points: Array = []
	for y: float in ys:
		var row: Array = []
		for px: float in xs:
			row.append(Vector3(px, y, FACE_Z - relief(px, y)))
		points.append(row)
	for j in range(ys.size() - 1):
		for i in range(xs.size() - 1):
			var mid := Vector2((xs[i] + xs[i + 1]) * .5, (ys[j] + ys[j + 1]) * .5)
			if mid.x > LOGGIA_X.x and mid.x < LOGGIA_X.y and mid.y < LOGGIA_TOP:
				continue
			quad(surface, [points[j][i], points[j][i + 1], points[j + 1][i + 1], points[j + 1][i]])

## Two triangles with one shared outward normal (toward the gorge).
func quad(surface: SurfaceTool, c: Array) -> void:
	var n: Vector3 = (c[1] - c[0]).cross(c[3] - c[0]).normalized()
	if n.z > 0.0:
		n = -n
	cavern.triangle(surface, [c[0], c[1], c[2]], [n, n, n])
	cavern.triangle(surface, [c[0], c[2], c[3]], [n, n, n])

func plane(surface: SurfaceTool, origin: Vector3, u: Vector3, v: Vector3, normal: Vector3) -> void:
	var c: Array = [origin, origin + u, origin + u + v, origin + v]
	cavern.triangle(surface, [c[0], c[1], c[2]], [normal, normal, normal])
	cavern.triangle(surface, [c[0], c[2], c[3]], [normal, normal, normal])

## Quarried rock cheeks, the soffit over the canopy, and the back wall with the
## gallery passage cut through it.
func loggia_rock(surface: SurfaceTool) -> void:
	var depth := Vector3(0, 0, LOGGIA_BACK - FACE_Z)
	var height := Vector3(0, LOGGIA_TOP - LOGGIA_FLOOR, 0)
	plane(surface, Vector3(LOGGIA_X.x, LOGGIA_FLOOR, FACE_Z), depth, height, Vector3.RIGHT)
	plane(surface, Vector3(LOGGIA_X.y, LOGGIA_FLOOR, FACE_Z), depth, height, Vector3.LEFT)
	var width := Vector3(LOGGIA_X.y - LOGGIA_X.x, 0, 0)
	plane(surface, Vector3(LOGGIA_X.x, LOGGIA_TOP, FACE_Z), width, depth, Vector3.DOWN)
	var back: float = LOGGIA_BACK
	var p: Rect2 = PASSAGE
	plane(surface, Vector3(LOGGIA_X.x, LOGGIA_FLOOR, back), Vector3(p.position.x - LOGGIA_X.x, 0, 0), height, Vector3.BACK)
	plane(surface, Vector3(p.end.x, LOGGIA_FLOOR, back), Vector3(LOGGIA_X.y - p.end.x, 0, 0), height, Vector3.BACK)
	plane(surface, Vector3(p.position.x, p.end.y, back), Vector3(p.size.x, 0, 0), Vector3(0, LOGGIA_TOP - p.end.y, 0), Vector3.BACK)

## A tall pointed iwan frames the loggia; its tympanum (mosaic) fills the arch
## above the canopy, with a faience band along the frame's top.
func iwan() -> void:
	var pier: float = 2.5
	var span: float = LOGGIA_X.y - LOGGIA_X.x + pier * 2.0
	var height: float = 17.8
	var start := Vector3(LOGGIA_X.x - pier, LOGGIA_FLOOR + height, FACE_Z - .9)
	art.extrude(vista.arch_bay(span, height, pier, true), 2.0, art.mat("limestone"), start)
	var tympanum: Node3D = vista.block(Vector3((LOGGIA_X.x + LOGGIA_X.y) * .5, LOGGIA_TOP + 5.5, FACE_Z - .05), Vector3(LOGGIA_X.y - LOGGIA_X.x, 11.0, .1), "mosaic")
	tympanum.name = "LoggiaTympanum"
	vista.block(Vector3(start.x + span * .5, start.y + .4, FACE_Z - 1.0), Vector3(span + 1.0, .8, 2.2), "exterior_faience")
	for side: float in [LOGGIA_X.x - 1.2, LOGGIA_X.y + 1.2]:
		vista.lamp(Vector3(side, 6.5, FACE_Z - 1.2), .35, true)
	# Short range: it lights the iwan and cliff, not the colossi and stair beyond.
	vista.big_light(Vector3(-1, 12.0, FACE_Z - 5.0), Color("ffb874"), 2.0, 14, 2 | 4)

## A small lit rock-cut window: pointed limestone frame on the dressed face,
## warm lamplight just behind.
func window(x: float, sill: float) -> void:
	var frame_span: float = WINDOW_SIZE.x + 1.2
	art.extrude(vista.arch_bay(frame_span, WINDOW_SIZE.y + 1.0, .6, true), .8, art.mat("limestone"), Vector3(x - frame_span * .5, sill + WINDOW_SIZE.y + 1.0, FACE_Z - .3))
	var glow := QuadMesh.new()
	glow.size = Vector2(WINDOW_SIZE.x - .4, WINDOW_SIZE.y - 1.0)
	var inner: MeshInstance3D = art.mesh_node(glow, Vector3(x, sill + glow.size.y * .5 + .1, FACE_Z - .1), art.mat("gorge_portal"))
	inner.rotation.y = PI
	vista.block(Vector3(x, sill - .15, FACE_Z - .6), Vector3(frame_span + .6, .3, 1.2), "limestone")

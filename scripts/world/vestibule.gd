class_name Vestibule
extends Node3D
## A dog-leg passage between a door of the gorge and the door of an interior
## area behind it (phase 9, one continuous world; SeamlessPlaces): in from the
## door, a turn, along, a turn back, on to the interior's door. From inside
## it you see neither end from the other, so the place you're in changes in
## its middle with nothing to notice, and the two places, which overlap in
## space, are never seen together. Brick walls and vault, stone paving, dark.
##
## In the door's frame (the gorge's threshold connector: the face at floor
## height, -Z through the door): CELLS, each a WIDTH square, HEIGHT tall.

const WIDTH: float = 3.0
const HEIGHT: float = 3.6
## The cells in order, (x, z) of their middles.
const CELLS: Array[Vector2] = [Vector2(0, -1.5), Vector2(0, -4.5), Vector2(3, -4.5), Vector2(6, -4.5), Vector2(6, -7.5)]
## Where it ends: the interior's door, its -Z on through (the exit's frame).
const EXIT := Transform3D(Basis(), Vector3(6, 0, -9))
const WALL: float = .3
const LAMP_ENERGY: float = .8
## How far short of the interior's door the passage stops: where both
## interiors' door walls start (their openings are the passage's own width
## and fought its walls inside them). Further short, 1.2 m, it left a slot
## either side open to the dark (your walk).
const EXIT_INSET: float = .3
## The floor a little over the storey line, where the bank's stone below has
## its top (your walk: the two flickered).
const FLOOR_UP: float = .015
## Its own render layer, lit only by its lamps: lit by the places either side,
## their lights changed at the swap in its middle (your walk: an abrupt change
## of light). The places' lights leave it out (SeamlessPlaces._unlight).
const LAYER: int = 1 << 10
## The gorge door's opening (gorge_door_open: DOOR_OPEN, BASE).
const DOOR_HALF: float = 1.15
const DOOR_TOP: float = 3.2
## The back of the gorge door's frame, out from the door's line (its back
## plate, gorge_door_open).
const FRAME_BACK: float = .25
const MAT: String = "res://kit/materials/%s.tres"


func _ready() -> void:
	var stone := SurfaceTool.new()
	stone.begin(Mesh.PRIMITIVE_TRIANGLES)
	var brick := SurfaceTool.new()
	brick.begin(Mesh.PRIMITIVE_TRIANGLES)
	var body := StaticBody3D.new()
	body.name = "Collision"
	add_child(body)
	var h: float = WIDTH * .5
	var posts: Dictionary = {}
	for i: int in CELLS.size():
		var c: Vector2 = CELLS[i]
		# The last cell stops EXIT_INSET short of the interior's door: its own
		# doorway (a wall's reveal, piers) reaches that far into the passage,
		# and the two fought there (your walk).
		var cut: float = EXIT_INSET if i == CELLS.size() - 1 else 0.0
		var zc: float = c.y + cut * .5
		var zs: float = WIDTH - cut
		_box(stone, body, Vector3(c.x, -.15 + FLOOR_UP, zc), Vector3(WIDTH, .3, zs))
		_box(brick, body, Vector3(c.x, HEIGHT + .15, zc), Vector3(WIDTH, .3, zs))
		if cut > 0.0:
			# The floor runs on to the door under the interior's own, 3 cm
			# lower (shortened, it left a gap to fall through).
			var zi: float = c.y - WIDTH * .5 + cut * .5
			_box(stone, body, Vector3(c.x, -.18, zi), Vector3(WIDTH, .3, cut))
		for side: Vector2 in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
			var beyond: Vector2 = c + side * WIDTH
			if CELLS.has(beyond):
				continue
			if i == 0 and side == Vector2(0, 1):
				continue     # the gorge's door
			if i == CELLS.size() - 1 and side == Vector2(0, -1):
				continue     # the interior's door
			var at := Vector3(c.x + side.x * (h + WALL * .5), HEIGHT * .5, (c.y if side.x == 0 else zc) + side.y * (h + WALL * .5))
			var size := Vector3(WALL if side.x != 0 else WIDTH, HEIGHT + .3, WALL if side.y != 0 else zs)
			_box(brick, body, at, size)
			# A post at each end of the wall, once (walls meeting at a corner,
			# overlapping, fought).
			var along := Vector2(-side.y, side.x) * (h + WALL * .5)
			var out: Vector2 = c + side * (h + WALL * .5)
			for corner: Vector2 in [out + along, out - along]:
				# Not past either door's plane (proud of the Reading Room's wall
				# or the cliff's face, they fought it).
				var e := Vector2(corner.x, clampf(corner.y, EXIT.origin.z + EXIT_INSET + WALL * .5, -WALL * .5))
				var key := Vector2i(roundi(e.x * 10.0), roundi(e.y * 10.0))
				if not posts.has(key):
					posts[key] = true
					_box(brick, body, Vector3(e.x, HEIGHT * .5, e.y), Vector3(WALL, HEIGHT + .3, WALL))
	# Round the gorge's door, the passage's end wall with the door's opening
	# (gorge_door_open: 2.3 m wide, its arch's crown 3.2 m up): from inside,
	# the pishtaq's back showed round it.
	# Its opening is the door's arch (a rectangle showed the arch's faceless
	# back in its corners, your walk): collision from boxes either side.
	# Out to the door's back plate (FRAME_BACK): stopped short of it, the slot
	# between showed the cave through the opening's sides (your walk).
	_arch_wall(brick, h, FRAME_BACK - .005, -.06 - WALL)
	for x: Array in [[-h, -DOOR_HALF], [DOOR_HALF, h]]:
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(x[1] - x[0], HEIGHT, WALL)
		cs.shape = shape
		cs.position = Vector3((x[0] + x[1]) * .5, HEIGHT * .5, -WALL * .5 - .06)
		body.add_child(cs)
	for part: Array in [["Paving", stone, "persian_stone"], ["Walls", brick, "persian_brick"]]:
		var mi := MeshInstance3D.new()
		mi.name = part[0]
		(part[1] as SurfaceTool).generate_tangents()
		mi.mesh = (part[1] as SurfaceTool).commit()
		mi.material_override = load(MAT % part[2])
		mi.layers = LAYER
		add_child(mi)
	# Two small warm lamps (one in each leg in from a door): dark between bright
	# places, not black (the interiors' ambient is low).
	for i: int in [1, 3]:
		var lamp := OmniLight3D.new()
		lamp.name = "Lamp_%d" % i
		lamp.light_color = Color(1.0, .78, .5)
		lamp.light_energy = LAMP_ENERGY
		lamp.omni_range = 5.0
		lamp.position = Vector3(CELLS[i].x, HEIGHT - .6, CELLS[i].y)
		lamp.light_cull_mask = LAYER
		add_child(lamp)


static func _box(st: SurfaceTool, body: StaticBody3D, at: Vector3, size: Vector3) -> void:
	var b := BoxMesh.new()
	b.size = size
	var arrays: Array = b.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for k: int in idx:
		st.set_uv(uvs[k])
		st.set_normal(normals[k])     # the box's own (generated, corners were smoothed: the brick's world-space projections blended)
		st.add_vertex(verts[k] + at)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	cs.position = at
	body.add_child(cs)


## How far along it a point (in its frame) is: 0 at the gorge's door, 1 at
## the interior's; -1 when not in it.
static func progress(local: Vector3) -> float:
	if local.y < -1.0 or local.y > HEIGHT + .5:
		return -1.0
	for i: int in CELLS.size():
		var c: Vector2 = CELLS[i]
		if absf(local.x - c.x) <= WIDTH * .5 + .05 and absf(local.z - c.y) <= WIDTH * .5 + .05:
			var along: float = .5
			if i == 0 or i == 1 or i == 4:
				along = clampf((c.y + WIDTH * .5 - local.z) / WIDTH, 0.0, 1.0)
			else:
				along = clampf((local.x - (c.x - WIDTH * .5)) / WIDTH, 0.0, 1.0)
			return (i + along) / CELLS.size()
	return -1.0


## What it takes up in its frame, walls and all, a little past its door.
static func bounds() -> AABB:
	var box := AABB(Vector3(CELLS[0].x, 0, CELLS[0].y), Vector3.ZERO)
	for c: Vector2 in CELLS:
		box = box.expand(Vector3(c.x, 0, c.y))
	var g: float = WIDTH * .5 + WALL
	# Behind the cliff's face (1.6 m in: arcade bays reach 1.2 m deep): the
	# bays beside the door stay.
	# Below the storey over the door (from 4 m): its walls and stone stay (your
	# walk: at 4.3 m they were cleared, a hole over the doors).
	return AABB(box.position - Vector3(g, .2, g), box.size + Vector3(2.0 * g, HEIGHT + .1, g + WIDTH * .5 - 1.6))


## The door's arch (gorge_door_open's DOOR_OPEN: half 1.15, springing 2.0 and
## rising 1.0 over its 0.2 m step), as points from the left springing over
## the crown to the right, (x, y).
static func _arch(n: int = 12) -> PackedVector2Array:
	var half: float = DOOR_HALF
	var spring: float = .2 + 2.0
	var rise: float = DOOR_TOP - spring
	# Two arcs centred on the springing line, meeting at the crown.
	var cx: float = (rise * rise - half * half) / (2.0 * half)
	var r: float = cx + half
	var pts := PackedVector2Array()
	for i: int in n + 1:
		var a0: float = PI
		var a1: float = atan2(rise, -cx)
		var a: float = lerpf(a0, a1, float(i) / n)
		pts.append(Vector2(cx + r * cos(a), spring + r * sin(a)))
	for i: int in range(n - 1, -1, -1):
		pts.append(Vector2(-pts[i].x, pts[i].y))
	return pts


## The end wall round the door, `h` either side, from z0 to z1 (z1 deeper),
## its opening the arch down to the floor: front, back and the opening's edge.
static func _arch_wall(st: SurfaceTool, h: float, z0: float, z1: float) -> void:
	var arch: PackedVector2Array = _arch()
	var poly := PackedVector2Array([Vector2(-h, 0), Vector2(-h, HEIGHT), Vector2(h, HEIGHT), Vector2(h, 0), Vector2(DOOR_HALF, 0)])
	for i: int in range(arch.size() - 1, -1, -1):
		poly.append(arch[i])
	poly.append(Vector2(-DOOR_HALF, 0))
	var tris: PackedInt32Array = Geometry2D.triangulate_polygon(poly)
	for face: Array in [[z0, Vector3(0, 0, 1)], [z1, Vector3(0, 0, -1)]]:
		for t: int in range(0, tris.size(), 3):
			var order: Array = [0, 1, 2] if face[1].z < 0.0 else [0, 2, 1]
			for k: int in order:
				var p: Vector2 = poly[tris[t + k]]
				st.set_normal(face[1])
				st.set_uv(Vector2(p.x, -p.y) / 2.0)
				st.add_vertex(Vector3(p.x, p.y, face[0]))
	# The opening's edge: the jambs and the arch's soffit.
	var edge := PackedVector2Array([Vector2(-DOOR_HALF, 0)])
	edge.append_array(arch)
	edge.append(Vector2(DOOR_HALF, 0))
	for i: int in edge.size() - 1:
		var a: Vector2 = edge[i]
		var b: Vector2 = edge[i + 1]
		var n := Vector3(b.y - a.y, -(b.x - a.x), 0).normalized()     # into the opening
		for v: Vector3 in [Vector3(a.x, a.y, z0), Vector3(b.x, b.y, z0), Vector3(b.x, b.y, z1), Vector3(a.x, a.y, z0), Vector3(b.x, b.y, z1), Vector3(a.x, a.y, z1)]:
			st.set_normal(n)
			st.set_uv(Vector2(v.z, v.y) / 2.0 + Vector2((a - b).length(), 0))
			st.add_vertex(v)

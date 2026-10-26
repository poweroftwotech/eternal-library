extends RefCounted
## Exterior slice 5, foreground framing (ART_DIRECTION.md section 8): two
## lamassu colossi on rock piers flank the near gorge and face the overlook
## (the right pier holds the rock-cut gate the overlook sees),
## and a monumental rock-cut stair runs diagonally down from the balcony's
## front-left corner to a landing at the left colossus's feet, giving the view
## the box art's off-axis lead-in. Everything stands outside the balcony
## guards (view only). Runs after the cavern, before vista_light.gd.

const Cavern = preload("res://scripts/cavern.gd")
const VistaLight = preload("res://scripts/vista_light.gd")

const COLOSSUS_SCALE: float = 4.0            # lamassu.glb is ~6.2 m tall -> ~25 m
const COLOSSUS_FLOOR: float = -6.0           # plinth level, below the balcony (2.2)
## [x, z, yaw]: yaw turns the face (+Z) in toward the gorge. The left one
## stood at (-30, -62) for the balcony's view; walked past, its plinth
## overlapped the stair's landing and the ledge (phase 6 step 2), so it moved
## clear of both.
const COLOSSI: Array = [[-34.0, -59.0, .5], [36.0, -66.0, -.5]]
const COLOSSUS_LIGHT_ENERGY: float = 2.5
const COLOSSUS_STONE: Color = Color("a39a8c")  # warm grey; plain limestone glared
## The gate the overlook sees: a rock-cut iwan in the right colossus's pier,
## like the tombs cut under the reliefs at Naqsh-e Rostam, facing the balcony.
const GATE_COLOSSUS: int = 1                 # index into COLOSSI
const GATE_SILL: float = -19.0               # iwan top (-7) tucks under the plinth course
const GATE_DEPTH: float = .8                 # quarried face at this fraction of the pier radius
const PIER_RADIUS: float = 9.0

## Just outside the balcony's front, its west balustrade clear of the iwan's
## west pier (x -10.05 .. -7.55; at -7 the pier stood on half the stair, at
## -4.7 the balustrade still ran into its corner).
const STAIR_TOP: Vector3 = Vector3(-4.2, 2.2, -29.2)
## The camp's stair (only seen from the balcony) stays where the box art
## wants it: moved east, it covered the mist floor (box art 0.82 -> 0.75).
const CAMP_STAIR_TOP: Vector3 = Vector3(-7.0, 2.2, -29.2)
const STAIR_LANDING: Vector3 = Vector3(-16.0, -8.0, -58.0)  # lower-left quadrant of the overlook view
const STAIR_STEPS: int = 14
const STAIR_WIDTH: float = 5.0
const STAIR_BASE: float = -20.0              # the stair is cut from one mass
## Walked (the Gorge area): balustrades on the stair's edges, the walk this
## far in from each side (the balustrade, 0.36 m, stands 5 cm proud of the
## steps' sides); a head block this long joins the balcony's floor
## (STAIR_FLOOR) to the first step, long enough that its slanted back edge
## reaches under the balcony's slab all along (at 1.25 its east corner fell
## 0.7 m short).
const STAIR_PARAPET: float = .31
const STAIR_HEAD: float = 2.2
const STAIR_FLOOR: float = 2.18

var vista
var world
var art

func _init(owner) -> void:
	vista = owner
	world = owner.world
	art = owner.art

func build() -> void:
	colossi()
	stair()
	parapet_carpets()

func colossi() -> void:
	var stone: StandardMaterial3D = art.mat("limestone").duplicate()
	stone.albedo_color = COLOSSUS_STONE
	art.materials["vista_colossus"] = stone
	# Carved recesses (beard, eyes, under the wings) read dark at distance.
	var crevice: StandardMaterial3D = art.mat("limestone").duplicate()
	crevice.albedo_color = COLOSSUS_STONE.darkened(.62)
	art.materials["vista_colossus_crevice"] = crevice
	var rock := SurfaceTool.new()
	rock.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cavern = Cavern.new(vista)
	for i in range(COLOSSI.size()):
		var data: Array = COLOSSI[i]
		var base := Vector3(data[0], COLOSSUS_FLOOR, data[1])
		var yaw: float = data[2]
		var cut: Dictionary = {}
		if i == GATE_COLOSSUS:
			var toward := Vector3(VistaLight.EYE.x - base.x, 0, VistaLight.EYE.z - base.z).normalized()
			var sill := Vector3(base.x, GATE_SILL, base.z) + toward * PIER_RADIUS * GATE_DEPTH
			cut = Cavern.quarry(sill, toward, COLOSSUS_FLOOR - .8)
			cavern.portal(sill, toward, "vista_colossus")
		# The gate's colossus stands on its rock pier; the other on its masonry
		# pedestal alone (the pier's rock reached out to the flight beside it).
		if i == GATE_COLOSSUS:
			cavern.column(rock, Vector2(base.x, base.z), PIER_RADIUS, -176.0, COLOSSUS_FLOOR - .8, cut)
		# A dressed plinth course over the rough pier. The plinth is longer than
		# the pier is wide, so (but where the gate is cut) a masonry pedestal
		# carries it up out of the mist, a faience band under its course.
		vista.prism(vista.tower_outline(Vector2(base.x, base.z), 6.0, 11.5, -yaw), COLOSSUS_FLOOR - 1.2, 1.2, art.mat("sandstone"))
		if i != GATE_COLOSSUS:
			vista.prism(vista.tower_outline(Vector2(base.x, base.z), 5.6, 11.1, -yaw), -176.0, COLOSSUS_FLOOR - 2.4 + 176.0, art.mat("sandstone"))
			vista.prism(vista.tower_outline(Vector2(base.x, base.z), 5.75, 11.25, -yaw), COLOSSUS_FLOOR - 2.4, 1.2, art.mat("exterior_faience"))
		var statue: Node3D = art.model("lamassu", base, yaw)
		statue.scale = Vector3.ONE * COLOSSUS_SCALE
		# Warm light from the terraces below catches the face and beard.
		var face := Vector3(sin(yaw), 0, cos(yaw))
		vista.big_light(base + face * 14.0 + Vector3.UP * 6.0, Color("ffb46e"), COLOSSUS_LIGHT_ENERGY, 34, VistaLight.EXTERIOR_MASK)
	var previous: int = art.render_layer
	art.render_layer = 4
	var node: MeshInstance3D = art.mesh_node(rock.commit(), Vector3.ZERO, art.mat("gorge_roof"))
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	art.render_layer = previous

func stair() -> void:
	var walkable: bool = vista.get_script().walkable_overlook
	var stair_top: Vector3 = STAIR_TOP if walkable else CAMP_STAIR_TOP
	var run := Vector3(STAIR_LANDING.x - stair_top.x, 0, STAIR_LANDING.z - stair_top.z)
	var flat: Vector3 = run.normalized()
	var tread: float = run.length() / STAIR_STEPS
	var rise: float = (stair_top.y - STAIR_LANDING.y) / STAIR_STEPS
	var yaw: float = atan2(flat.x, flat.z)
	var across := Vector3(flat.z, 0, -flat.x)
	# Reliefs go on the side the overlook can see.
	var middle: Vector3 = stair_top.lerp(STAIR_LANDING, .5)
	var shown: float = signf(across.dot(VistaLight.EYE - middle))
	if shown == 0.0:
		shown = 1.0
	for k in range(STAIR_STEPS):
		var top: float = stair_top.y - (k + 1) * rise
		var at: Vector3 = stair_top + flat * (k + .5) * tread
		var step: Node3D = vista.block(Vector3(at.x, (top + STAIR_BASE) * .5, at.z), Vector3(STAIR_WIDTH, top - STAIR_BASE, tread + .02), "sandstone")
		step.rotation.y = yaw
		# Stepped side walls clad in mosaic, a winged relief every third step
		# (walked, one sloped wall each side: up close the steps' blocks
		# stood apart with air between them).
		for side: float in [-1.0, 1.0]:
			if walkable:
				continue
			var wall: Node3D = vista.block(at + across * side * (STAIR_WIDTH * .5 + .35) + Vector3(0, top - at.y + .45, 0), Vector3(.7, .9, tread + .02), "mosaic")
			wall.rotation.y = yaw
		# (walked, none where the landing's balustrade meets the stair)
		if k % 3 == 1 and not (walkable and (k + 1.7) * tread > run.length() - 6.0):
			var panel := QuadMesh.new()
			panel.size = Vector2(tread * 2.4, 3.2)
			# Walked, on the parapet's outer face (the mosaic walls are gone).
			var out: float = STAIR_WIDTH * .5 + (.08 if walkable else .72)
			var relief: MeshInstance3D = art.mesh_node(panel, at + across * shown * out + Vector3(0, top - at.y - (2.9 if walkable else 1.9), 0), art.mat("wing_relief"))     # walked, lower: level-topped on a slope, its downhill corner rose above the balustrade
			relief.rotation.y = atan2(across.x * shown, across.z * shown)
	if walkable:
		# The head: one block from the balcony's floor to the first step (a slab
		# across the parapet's gap left air under it and beside it), its top 1.5
		# cm under the balcony's slab where they overlap (level, they flickered).
		var head_top: float = STAIR_FLOOR - .015
		var head: Node3D = vista.block(stair_top - flat * STAIR_HEAD * .5 + Vector3(0, (head_top + STAIR_BASE) * .5 - stair_top.y, 0),
			Vector3(STAIR_WIDTH + .1, head_top - STAIR_BASE, STAIR_HEAD), "sandstone")
		head.rotation.y = yaw
		# Balustrades as the landing's and the ledge's, from the head to the
		# landing's edge, on the line through the step tops; the east one also
		# along the head to the balcony's parapet (the west side of the head is
		# the balcony's own). Newels where they turn and end.
		# Down to the stair's foot on the landing (stopping at the landing's edge,
		# the last steps stood bare), a newel there.
		var end: float = run.length()
		var line := func(s: float) -> float: return stair_top.y - rise * .5 - rise / tread * s
		var ground := Vector3(stair_top.x, 0, stair_top.z)
		for side: float in [-1.0, 1.0]:
			var edge: Vector3 = ground + across * side * (STAIR_WIDTH * .5 - STAIR_PARAPET)
			vista.balustrade(edge + Vector3(0, line.call(0.0), 0), edge + flat * end + Vector3(0, line.call(end), 0), across * side)
			# Newels at the top (the landing's own stand at the foot): the west one
			# wide enough to close the gap to the balcony's side parapet, whose
			# end it caps.
			var start: Vector3 = edge + across * side * .18 + Vector3(0, line.call(0.0), 0)
			newel(edge + flat * end + across * side * .18 + Vector3(0, maxf(line.call(end), STAIR_LANDING.y), 0), yaw)
			if side < 0.0:
				newel(start, yaw)
			else:
				var parapet_end := Vector3(-7.3, STAIR_FLOOR, -28.35)
				var mid: Vector3 = (Vector3(start.x, STAIR_FLOOR, start.z) + parapet_end) * .5
				var span: float = Vector2(start.x - parapet_end.x, start.z - parapet_end.z).length() + .3     # its west end 0.1 m clear of the iwan pier
				newel(mid, atan2(start.x - parapet_end.x, start.z - parapet_end.z), Vector2(.55, span))
			if side < 0.0:
				vista.balustrade(edge - flat * STAIR_HEAD + Vector3(0, STAIR_FLOOR, 0), edge + Vector3(0, STAIR_FLOOR, 0), across * side, .3)
	# Landing near the left colossus's feet (walked, square: the notched
	# corners left the balustrade's corners over air).
	var outline: Callable = (func(r: float) -> PackedVector2Array: return square(Vector2(STAIR_LANDING.x, STAIR_LANDING.z), r, -yaw)) if walkable \
		else (func(r: float) -> PackedVector2Array: return vista.tower_outline(Vector2(STAIR_LANDING.x, STAIR_LANDING.z), r, r, -yaw))
	vista.prism(outline.call(6.0), STAIR_BASE, STAIR_LANDING.y - STAIR_BASE, art.mat("sandstone"))
	if walkable:
		# Paved as the ledges are (the faience's big tiles read as pixels up
		# close), the faience a fascia under the paving's edge.
		vista.prism(outline.call(6.02), STAIR_LANDING.y - .75, .3, art.mat("exterior_faience"))
	else:
		vista.prism(outline.call(6.4), STAIR_LANDING.y - .5, .52, art.mat("exterior_faience"))  # 2 cm above the landing top (was flush)
	# A kilim runner laid tread by tread (one sloped plane cut through the
	# step noses and filled the frame edge where it began beside the camera).
	for k in range(1, STAIR_STEPS):
		var piece := PlaneMesh.new()
		piece.size = Vector2(2.4, tread - .1)
		var at: Vector3 = stair_top + flat * (k + .5) * tread
		var rug: MeshInstance3D = art.mesh_node(piece, Vector3(at.x, stair_top.y - (k + 1) * rise + .03, at.z), art.mat("vista_carpet"))
		rug.rotation.y = yaw

## A corner of the stair's head at the balcony (side +1 west, -1 east): the
## outer face of its parapet, where the balcony's own parapet takes over.
static func head_corner(side: float) -> Vector3:
	var flat: Vector3 = Vector3(STAIR_LANDING.x - STAIR_TOP.x, 0, STAIR_LANDING.z - STAIR_TOP.z).normalized()
	var across := Vector3(flat.z, 0, -flat.x)
	return Vector3(STAIR_TOP.x, STAIR_FLOOR, STAIR_TOP.z) + across * side * (STAIR_WIDTH * .5 + .05) - flat * STAIR_HEAD

## A square post where a balustrade turns or ends (its foot on `at`).
## `size` is its plan (x across, z along `yaw`).
func newel(at: Vector3, yaw: float, size: Vector2 = Vector2(.5, .5)) -> void:
	var post: Node3D = vista.block(at + Vector3(0, .45, 0), Vector3(size.x, 1.4, size.y), "sandstone")
	post.rotation.y = yaw
	var cap: Node3D = vista.block(at + Vector3(0, 1.2, 0), Vector3(size.x + .1, .1, size.y + .1), "limestone")
	cap.rotation.y = yaw

## A plain square (tower_outline's corner order, without its notches).
func square(center: Vector2, r: float, turn: float) -> PackedVector2Array:
	var polygon := PackedVector2Array()
	for v: Vector2 in [Vector2(r, r), Vector2(-r, r), Vector2(-r, -r), Vector2(r, -r)]:
		polygon.append(center + v.rotated(turn))
	return polygon

func parapet_carpets() -> void:
	# More kilims thrown over the balcony parapet, like the existing one at
	# x = -3.2 (vista.balcony_details). They belong to the interior layer.
	# Walked, none: the parapet has no flat top for them to lie on (balusters
	# and a coping), so they floated.
	if vista.get_script().walkable_overlook:
		return
	var previous: int = art.render_layer
	art.render_layer = 1
	for x: float in [.9, 3.7]:
		var rug := QuadMesh.new()
		rug.size = Vector2(1.6, 1.15)
		art.mesh_node(rug, Vector3(x, 2.5, -27.76), art.mat("rug"))
		vista.block(Vector3(x, 2.94, -27.96), Vector3(1.6, .025, .8), "rug").rotation.z = -.012
	art.render_layer = previous

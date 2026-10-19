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
## [x, z, yaw]: yaw turns the face (+Z) in toward the gorge.
const COLOSSI: Array = [[-30.0, -62.0, .5], [36.0, -66.0, -.5]]
const COLOSSUS_LIGHT_ENERGY: float = 2.5
const COLOSSUS_STONE: Color = Color("a39a8c")  # warm grey; plain limestone glared
## The gate the overlook sees: a rock-cut iwan in the right colossus's pier,
## like the tombs cut under the reliefs at Naqsh-e Rostam, facing the balcony.
const GATE_COLOSSUS: int = 1                 # index into COLOSSI
const GATE_SILL: float = -19.0               # iwan top (-7) tucks under the plinth course
const GATE_DEPTH: float = .8                 # quarried face at this fraction of the pier radius
const PIER_RADIUS: float = 9.0

const STAIR_TOP: Vector3 = Vector3(-7.0, 2.2, -29.2)       # just outside the front-left guard
const STAIR_LANDING: Vector3 = Vector3(-16.0, -8.0, -58.0)  # lower-left quadrant of the overlook view
const STAIR_STEPS: int = 14
const STAIR_WIDTH: float = 5.0
const STAIR_BASE: float = -20.0              # the stair is cut from one mass

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
		cavern.column(rock, Vector2(base.x, base.z), PIER_RADIUS, -176.0, COLOSSUS_FLOOR - .8, cut)
		# A dressed plinth course over the rough pier.
		vista.prism(vista.tower_outline(Vector2(base.x, base.z), 6.0, 11.5, -yaw), COLOSSUS_FLOOR - 1.2, 1.2, art.mat("sandstone"))
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
	var run := Vector3(STAIR_LANDING.x - STAIR_TOP.x, 0, STAIR_LANDING.z - STAIR_TOP.z)
	var flat: Vector3 = run.normalized()
	var tread: float = run.length() / STAIR_STEPS
	var rise: float = (STAIR_TOP.y - STAIR_LANDING.y) / STAIR_STEPS
	var yaw: float = atan2(flat.x, flat.z)
	var across := Vector3(flat.z, 0, -flat.x)
	# Reliefs go on the side the overlook can see.
	var middle: Vector3 = STAIR_TOP.lerp(STAIR_LANDING, .5)
	var shown: float = signf(across.dot(VistaLight.EYE - middle))
	if shown == 0.0:
		shown = 1.0
	for k in range(STAIR_STEPS):
		var top: float = STAIR_TOP.y - (k + 1) * rise
		var at: Vector3 = STAIR_TOP + flat * (k + .5) * tread
		var step: Node3D = vista.block(Vector3(at.x, (top + STAIR_BASE) * .5, at.z), Vector3(STAIR_WIDTH, top - STAIR_BASE, tread + .02), "sandstone")
		step.rotation.y = yaw
		# Stepped side walls clad in mosaic, a winged relief every third step.
		for side: float in [-1.0, 1.0]:
			var wall: Node3D = vista.block(at + across * side * (STAIR_WIDTH * .5 + .35) + Vector3(0, top - at.y + .45, 0), Vector3(.7, .9, tread + .02), "mosaic")
			wall.rotation.y = yaw
		if k % 3 == 1:
			var panel := QuadMesh.new()
			panel.size = Vector2(tread * 2.4, 3.2)
			var relief: MeshInstance3D = art.mesh_node(panel, at + across * shown * (STAIR_WIDTH * .5 + .72) + Vector3(0, top - at.y - 1.9, 0), art.mat("wing_relief"))
			relief.rotation.y = atan2(across.x * shown, across.z * shown)
	# Landing near the left colossus's feet.
	vista.prism(vista.tower_outline(Vector2(STAIR_LANDING.x, STAIR_LANDING.z), 6.0, 6.0, -yaw), STAIR_BASE, STAIR_LANDING.y - STAIR_BASE, art.mat("sandstone"))
	vista.prism(vista.tower_outline(Vector2(STAIR_LANDING.x, STAIR_LANDING.z), 6.4, 6.4, -yaw), STAIR_LANDING.y - .5, .52, art.mat("exterior_faience"))  # 2 cm above the landing top (was flush)
	# A kilim runner laid tread by tread (one sloped plane cut through the
	# step noses and filled the frame edge where it began beside the camera).
	for k in range(1, STAIR_STEPS):
		var piece := PlaneMesh.new()
		piece.size = Vector2(2.4, tread - .1)
		var at: Vector3 = STAIR_TOP + flat * (k + .5) * tread
		var rug: MeshInstance3D = art.mesh_node(piece, Vector3(at.x, STAIR_TOP.y - (k + 1) * rise + .03, at.z), art.mat("vista_carpet"))
		rug.rotation.y = yaw

func parapet_carpets() -> void:
	# More kilims thrown over the balcony parapet, like the existing one at
	# x = -3.2 (vista.balcony_details). They belong to the interior layer.
	var previous: int = art.render_layer
	art.render_layer = 1
	for x: float in [.9, 3.7]:
		var rug := QuadMesh.new()
		rug.size = Vector2(1.6, 1.15)
		art.mesh_node(rug, Vector3(x, 2.5, -27.76), art.mat("rug"))
		vista.block(Vector3(x, 2.94, -27.96), Vector3(1.6, .025, .8), "rug").rotation.z = -.012
	art.render_layer = previous

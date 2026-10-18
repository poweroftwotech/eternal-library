extends RefCounted
## v0.12 camp recomposition toward design/Campfire in the Eternal Library.png
## (ART_DIRECTION.md backlog 5). Positions come from tests/frame_probe.gd:
## concept screen landmarks cast onto our floor from the `concept` camera.
##   left:    angled bookcase + ladder + hanging ivy, lantern on a book stack,
##            turquoise planter
##   right:   striped bedroll and leather pack on the rug
##   archive: glowing blue mushroom clusters
var world
var art
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

const BOOKCASE: Vector3 = Vector3(-6.1,0,1.7)
const BOOKCASE_YAW: float = -2.53          # front faces the concept camera
const BEDROLL: Vector3 = Vector3(2.75,0,3.75)
const PACK: Vector3 = Vector3(3.5,0,4.35)

func _init(owner, factory) -> void:
	world = owner
	art = factory
	rng.seed = 12012

func build() -> void:
	left_bookcase()
	lantern_stack()
	planter(Vector3(-4.2,0,2.75))
	# Concept lower-left: turquoise mosaic drum. Clad the provision slabs
	# (world.build_camp, set_dressing) in mosaic under their limestone tops.
	clad(Vector3(-3.45,0,5.4),Vector3(2.2,.54,1.4))
	clad(Vector3(-2.65,0,6.05),Vector3(1.4,.54,1.0))
	bedroll()
	pack()
	archive_fungi()

func left_bookcase() -> void:
	art.shelf(BOOKCASE,2.4,4.5,BOOKCASE_YAW)
	var basis: Basis = Basis(Vector3.UP,BOOKCASE_YAW)
	var front: Vector3 = basis*Vector3(0,0,-1)
	var right: Vector3 = basis*Vector3(1,0,0)
	art.ladder(BOOKCASE+front*.72+right*.55,4.3,BOOKCASE_YAW)
	# Ivy spilling over the top and down the front edge (concept left bookcase).
	var ivy: QuadMesh = QuadMesh.new()
	ivy.size = Vector2(.17,.19)
	for strand in range(7):
		var top: Vector3 = BOOKCASE+Vector3(0,4.55,0)+front*.5+right*rng.randf_range(-1.15,1.15)
		var length: int = rng.randi_range(6,16)
		for j in range(length):
			var p: Vector3 = top+Vector3(rng.randf_range(-.06,.06),-j*.13,0)+front*rng.randf_range(0,.08)
			var leaf_basis: Basis = Basis.from_euler(Vector3(rng.randf_range(-.5,.5),BOOKCASE_YAW+PI+rng.randf_range(-.6,.6),rng.randf_range(-.7,.7)))
			art.batch_mesh("camp_bookcase_ivy",ivy,art.mat("ivy_leaf"),Transform3D(leaf_basis,p),Color(rng.randf_range(.65,.9),rng.randf_range(.8,1),.7))

func lantern_stack() -> void:
	var stack: Vector3 = Vector3(-4.7,0,3.6)
	art.lying_books(stack,3,.4)
	world.lantern(stack+Vector3(0,.255,0))

## Turquoise glazed planter with a leafy shrub (concept: potted plant by the bookcase).
func planter(pose: Vector3) -> void:
	var profile: Array = [Vector2(0,0),Vector2(.22,0),Vector2(.30,.08),Vector2(.36,.40),Vector2(.40,.46),Vector2(.40,.50),Vector2(.35,.50),Vector2(.32,.44),Vector2(0,.42)]
	var pot = art.mesh_node(art.lathe(profile,32),pose,art.mat("glazed_ceramic"))
	pot.scale = Vector3.ONE*1.4
	art.cylinder(pose+Vector3(0,.6,0),.45,.02,art.mat("soil"))
	solid_cylinder(pose,.52,.7)
	var leaf: QuadMesh = QuadMesh.new()
	leaf.size = Vector2(.2,.3)
	for i in range(14):
		var a: float = i*2.4
		var tip: Vector3 = pose+Vector3(cos(a)*rng.randf_range(.15,.6),rng.randf_range(.9,1.7),sin(a)*rng.randf_range(.15,.6))
		art.segment(pose+Vector3(0,.6,0),tip,.012,art.mat("vine"))
		for k in range(3):
			var p: Vector3 = (pose+Vector3(0,.6,0)).lerp(tip,.55+k*.22)
			var leaf_basis: Basis = Basis.from_euler(Vector3(rng.randf_range(-1.2,-.2),a+rng.randf_range(-.5,.5),rng.randf_range(-.6,.6)))
			art.batch_mesh("camp_planter_leaves",leaf,art.mat("tree_leaf"),Transform3D(leaf_basis,p),Color(rng.randf_range(.7,.9),rng.randf_range(.85,1),.6))

func bedroll() -> void:
	leather_material()   # registers camp_leather for the straps
	art.model("bedroll",BEDROLL+Vector3(0,world.rug_center.y,0),-.12)

func pack() -> void:
	leather_material()   # registers camp_leather before the model asks for it
	var yaw: float = -.35
	var base: Vector3 = PACK+Vector3(0,world.rug_center.y,0)
	art.model("pack",base,yaw)
	var body: StaticBody3D = StaticBody3D.new()
	world.add_child(body)
	body.position = base+Vector3(0,.4,0)
	body.rotation.y = yaw
	var collider: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(.7,.8,.45)
	collider.shape = shape
	body.add_child(collider)

func archive_fungi() -> void:
	var glow: StandardMaterial3D = art.mat("glow")
	glow.albedo_color = Color("3f9fbf")
	glow.emission = Color("2fb8e0")
	glow.emission_energy_multiplier = 1.1
	# Damp moss mounds: glowing clusters (lit), plain clusters, and one under
	# each mushroom gatherable so nothing sprouts from bare paving.
	for data in [[Vector3(8.5,0,-3.1),.6,true],[Vector3(9.3,0,-4.4),.55,true],[Vector3(7.4,0,-5.6),.6,true],
			[Vector3(7.0,0,-2.4),.5,false],[Vector3(10.7,0,-2.6),.45,false],[Vector3(8.6,0,-7.6),.55,false],[Vector3(11.0,0,-7.2),.5,false]]:
		var center: Vector3 = data[0]
		var radius: float = data[1]
		mound(center,radius,.09)
		for i in range(7 if data[2] else 5):
			var a: float = rng.randf_range(0,TAU)
			var d: float = sqrt(rng.randf())*radius*.7
			var p: Vector3 = center+Vector3(cos(a)*d,.09*sqrt(maxf(0.0,1.0-pow(d/radius,2)))-.01,sin(a)*d*.8)
			art.mushroom(p,rng.randf_range(.35,.85),data[2] and i<5)
		if data[2]:
			var light = world.light(center+Vector3(0,.35,0),Color("3fb6e6"),.7,2.6)
			light.light_cull_mask = 1
	for id in world.gatherables:
		if world.gatherables[id].kind == "mushroom":
			mound(world.gatherables[id].visual.position*Vector3(1,0,1),.55,.06)
	rotting_log(Vector3(10.9,0,-4.6),.15)

## Low, irregular moss cushion over a darker soil rim.
func mound(center: Vector3, radius: float, height: float) -> void:
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radial_segments = 16
	sphere.rings = 6
	var soil = art.mesh_node(sphere,center,art.mat("soil"))
	soil.scale = Vector3(radius*1.15,height*.55,radius*.95)
	var moss = art.mesh_node(sphere,center,art.mat("moss"))
	moss.scale = Vector3(radius,height,radius*.8)
	moss.rotation.y = rng.randf_range(0,TAU)

## Fallen, moss-backed log with bracket fungi on its flank.
func rotting_log(center: Vector3, yaw: float) -> void:
	var log_node = art.cylinder(center+Vector3(0,.15,0),.15,1.7,art.mat("bark"))
	log_node.rotation = Vector3(PI/2,yaw,0)
	var moss = art.box(center+Vector3(0,.28,0),Vector3(.18,.05,1.4),art.mat("moss"))
	moss.rotation.y = yaw
	var along: Vector3 = Basis(Vector3.UP,yaw)*Vector3(0,0,1)
	var side: Vector3 = Basis(Vector3.UP,yaw)*Vector3(1,0,0)
	for i in range(9):
		var p: Vector3 = center+along*rng.randf_range(-.7,.7)+side*(-.14 if i%2 else .14)+Vector3(0,rng.randf_range(.1,.24),0)
		var bracket = art.cylinder(p,rng.randf_range(.05,.09),.022,art.mat("mushroom"))
		bracket.rotation.z = (-.25 if i%2 else .25)
		if i%3 == 0:
			art.mushroom(center+along*rng.randf_range(-.6,.6)+Vector3(0,.27,0),rng.randf_range(.3,.5),true)

func leather_material() -> StandardMaterial3D:
	if art.materials.has("camp_leather"):
		return art.materials["camp_leather"]
	var leather: StandardMaterial3D = art.mat("book_leather").duplicate()
	leather.vertex_color_use_as_albedo = false
	leather.albedo_color = Color(.95,.72,.55)
	art.materials["camp_leather"] = leather
	return leather

func solid_cylinder(pose: Vector3, radius: float, height: float) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	world.add_child(body)
	body.position = pose+Vector3(0,height*.5,0)
	var collider: CollisionShape3D = CollisionShape3D.new()
	var shape: CylinderShape3D = CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	collider.shape = shape
	body.add_child(collider)

## Mosaic skin on a slab's four sides, leaving a limestone top course and plinth.
func clad(base: Vector3, size: Vector3) -> void:
	var band: float = size.y-.16
	art.box(base+Vector3(0,.06+band*.5,0),Vector3(size.x+.03,band,size.z+.03),art.mat("mosaic"))
	art.box(base+Vector3(0,.03,0),Vector3(size.x+.06,.06,size.z+.06),art.mat("hearth_stone"))

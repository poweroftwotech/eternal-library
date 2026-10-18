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
	bedroll()
	pack()
	archive_glow()

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
	var y: float = world.rug_center.y+.23
	var roll = art.cylinder(BEDROLL+Vector3(0,y,0),.23,1.3,art.mat("linen"))
	roll.rotation = Vector3(0,-.12,PI/2)
	var leather: StandardMaterial3D = leather_material()
	for x in [-.4,.4]:
		var strap = art.cylinder(BEDROLL+Vector3(x*cos(.12),y,x*sin(.12)),.238,.07,leather)
		strap.rotation = roll.rotation
	# Rolled ends show the darker inner layers.
	for side in [-1,1]:
		var cap = art.cylinder(BEDROLL+Vector3(side*.655*cos(.12),y,side*.655*sin(.12)),.2,.012,art.mat("cloth"))
		cap.rotation = roll.rotation

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

func archive_glow() -> void:
	var glow: StandardMaterial3D = art.mat("glow")
	glow.albedo_color = Color("3f9fbf")
	glow.emission = Color("2fb8e0")
	glow.emission_energy_multiplier = 1.1
	for center in [Vector3(8.5,.02,-3.1),Vector3(9.3,.02,-4.4),Vector3(7.4,.02,-5.6)]:
		for i in range(7):
			var p: Vector3 = center+Vector3(rng.randf_range(-.35,.35),0,rng.randf_range(-.3,.3))
			art.mushroom(p,rng.randf_range(.35,.85),true)
		var light = world.light(center+Vector3(0,.35,0),Color("3fb6e6"),.7,2.6)
		light.light_cull_mask = 1

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

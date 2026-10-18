extends RefCounted
## v0.12 planting logic: nothing grows straight out of paving.
## Plants live in (a) the tree's raised planter, (b) kerbed soil beds around the
## rock outcrops and herb/root patches, or (c) thin tufts along paving joints.
## Runs after organic_pass (which places the outcrops and their plants).
var world
var art
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

const SOIL_TOP: float = .08          # covers garden slabs (top ~.04) and earth decals
const TREE: Vector3 = Vector3(-4.0,0,-6.2)
## organic_pass.rock_gardens() centres, with bed radii (x, z). The two east beds
## stay narrow so their kerbs clear the stair (x 1.6..3.4).
const ROCK_BEDS: Array = [
	[Vector3(-5.8,0,-3.8),Vector2(1.45,1.15)],[Vector3(-6.0,0,-7.6),Vector2(1.45,1.15)],
	[Vector3(-3.2,0,-7.8),Vector2(1.35,1.1)],[Vector3(-2.25,0,-5.8),Vector2(1.3,1.05)],
	[Vector3(4.25,0,-2.4),Vector2(.85,1.1)],[Vector3(4.15,0,-6.6),Vector2(.85,1.1)]]
## interior_pass.build_planted_joints() earth patches (garden ones only).
const SMALL_BEDS: Array = [Vector3(-4.8,0,-.8),Vector3(-7.5,0,-3.0),Vector3(-2.9,0,-5.0),Vector3(-2.8,0,-8.2)]
## Former loose clusters / ground-growth piles: now joint tufts.
const CRACKS: Array = [Vector3(-4.7,0,.4),Vector3(-3.9,0,1.25),Vector3(3.25,0,.7),Vector3(-5.5,0,2.1),
	Vector3(.35,0,-1.8),Vector3(-2.2,0,-2.5),Vector3(-4.8,0,.4),Vector3(3.1,0,.35),Vector3(-3.1,0,-2.0),
	Vector3(-2.2,0,-4.2),Vector3(-6.1,0,-4.8),Vector3(4.3,0,-1.0)]

func _init(owner, factory) -> void:
	world = owner
	art = factory
	rng.seed = 51515

func build() -> void:
	bed(TREE,Vector2(2.05,1.75),.34,true)
	for data in ROCK_BEDS:
		bed(data[0],data[1],.24,true)
	for p in SMALL_BEDS:
		bed(p,Vector2(.8,.68),.14,false)
	for id in world.gatherables:
		var data: Dictionary = world.gatherables[id]
		if data.kind != "mushroom":
			bed(data.visual.position*Vector3(1,0,1),Vector2(.72,.6),.12,false)
	for p in CRACKS:
		crack_tuft(p)

## Oval soil bed with a ring of worn kerb stones. Tall kerbs are solid.
func bed(center: Vector3, radii: Vector2, kerb: float, solid: bool) -> void:
	var soil: CylinderMesh = CylinderMesh.new()
	soil.top_radius = 1.0
	soil.bottom_radius = 1.0
	soil.height = SOIL_TOP
	soil.radial_segments = 28
	var node = art.mesh_node(soil,center+Vector3(0,SOIL_TOP*.5,0),art.mat("soil"))
	node.scale = Vector3(radii.x-.05,1,radii.y-.05)
	var circumference: float = TAU*sqrt((radii.x*radii.x+radii.y*radii.y)*.5)
	var count: int = maxi(8,int(circumference/.42))
	for i in range(count):
		var a: float = (i+rng.randf_range(-.08,.08))*TAU/count
		var p: Vector3 = center+Vector3(cos(a)*radii.x,kerb*.5,sin(a)*radii.y)
		var tangent: float = atan2(-radii.y*cos(a),-radii.x*sin(a))
		var length: float = circumference/count+.02
		var stone = art.worn_block(p,Vector3(length,kerb+rng.randf_range(-.02,.02),.2),art.mat("limestone"),.04,solid)
		stone.rotation.y = -tangent
	# Moss creeping over the kerb's inner edge reads as an old, watered bed.
	var leaf: QuadMesh = QuadMesh.new()
	leaf.size = Vector2(.1,.14)
	for i in range(int(count*1.5)):
		var a: float = rng.randf_range(0,TAU)
		var p: Vector3 = center+Vector3(cos(a)*(radii.x-.12),kerb*.85,sin(a)*(radii.y-.12))
		var basis: Basis = Basis.from_euler(Vector3(rng.randf_range(-1.2,-.4),rng.randf_range(0,TAU),rng.randf_range(-.5,.5)))
		art.batch_mesh("bed_edge_growth",leaf,art.mat("tree_leaf"),Transform3D(basis,p),Color(.72,.86,.5))

## A few grass blades and a moss line following one paving joint.
func crack_tuft(center: Vector3) -> void:
	var along: float = rng.randf_range(0,PI)
	var direction: Vector3 = Vector3(cos(along),0,sin(along))
	var length: float = rng.randf_range(.45,.8)
	var moss = art.box(center+Vector3(0,.035,0),Vector3(length,.012,.035),art.mat("moss"))
	moss.rotation.y = -along
	var blade: QuadMesh = QuadMesh.new()
	blade.size = Vector2(.05,.13)
	for i in range(rng.randi_range(7,12)):
		var t: float = rng.randf_range(-.5,.5)*length
		var p: Vector3 = center+direction*t+Vector3(rng.randf_range(-.02,.02),.075,rng.randf_range(-.02,.02))
		var basis: Basis = Basis.from_euler(Vector3(rng.randf_range(-.35,.35),rng.randf_range(0,TAU),rng.randf_range(-.35,.35)))
		art.batch_mesh("joint_tufts",blade,art.mat("leaf"),Transform3D(basis.scaled(Vector3.ONE*rng.randf_range(.6,1.1)),p),Color(.62,.78,.42))

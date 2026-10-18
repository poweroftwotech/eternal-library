extends RefCounted
## Small-scale geometry and foliage to make the prototype feel inhabited.
var world
var art
var rng = RandomNumberGenerator.new()

func _init(owner, factory) -> void:
	world = owner
	art = factory
	rng.seed = 34017

func build() -> void:
	build_roof()
	build_stonework()
	build_greenery()
	build_provisions()

func build_roof() -> void:
	# Every local area has a finite, visible roof; the garden is an interior lightwell.
	art.box(Vector3(2,8.55,6),Vector3(24.5,.35,12.6),art.mat("wood"),true)
	art.box(Vector3(-2,13.7,-6.3),Vector3(16.4,.6,14.5),art.mat("cave"),true)
	# Close the clerestory band between the lower room roofs and the garden vault.
	art.box(Vector3(-2.45,11.1,0),Vector3(15.3,5.8,.8),art.mat("brick"),true)
	art.box(Vector3(-2.45,11.1,-13.2),Vector3(15.3,5.8,.6),art.mat("brick"),true)
	art.box(Vector3(5.1,10.8,-6.5),Vector3(.45,6.2,13.2),art.mat("brick"),true)
	world.light(Vector3(-2,10.2,-5.6),Color("9aafa5"),1.2,10)
	for z in [-11.0,-6.2,-1.4]:
		# Curved stone ribs subdivide the ceiling into vaulted coffers.
		var points: Array = []
		var radii: Array = []
		for i in range(25):
			var a: float = PI*i/24
			points.append(Vector3(-2.2+cos(a)*7.14,7.98+sin(a)*5.22,z))
			radii.append(.19)
		art.tube(points,radii,art.mat("sandstone"),10)
	for x in [-8.8,4.8]:
		for z in [-11,-6,-1]:
			art.bevel_box(Vector3(x,6.4,z),Vector3(.8,12.8,.9),art.mat("brick"),.06)
	# Camp beams and small corner brackets retain a human-scale shelter.
	for z in [1.4,5.2,9.8]:
		for x in [-7.8,12.5]:
			art.segment(Vector3(x,6.7,z),Vector3(x+(1 if x<0 else -1)*1.4,8.1,z),.13,art.mat("wood"))
	for x in [-6.7,-2.5,1.8,6.1,10.4]:
		art.box(Vector3(x,8.3,5.8),Vector3(.14,.4,12),art.mat("wood"))

func build_stonework() -> void:
	world.organic.camp_paving()
	# Weathered cornices and narrow tile trim soften the large wall masses.
	for x in [-5.1,3.35,5.45,11.3]:
		for y in [.55,2.5,7.7]:
			art.bevel_box(Vector3(x,y,.12),Vector3(1.05,.16,1.2),art.mat("sandstone"),.035)
		art.box(Vector3(x,5.1,.66),Vector3(.12,3.9,.07),art.mat("brass"))

func build_greenery() -> void:
	var tree = Vector3(-4.0,0,-6.2)
	var points = [tree,tree+Vector3(-.65,1.1,.12),tree+Vector3(-.80,2.3,.28),tree+Vector3(-.27,3.7,-.10),tree+Vector3(.62,5.0,-.5),tree+Vector3(.95,6.0,-.7)]
	art.tube(points,[.66,.53,.40,.29,.17,.035],art.mat("bark"),16)
	for i in range(8):
		var a: float = i*TAU/8
		art.tube([tree+Vector3(0,.35,0),tree+Vector3(cos(a)*.75,.10,sin(a)*.75),tree+Vector3(cos(a)*1.8,.02,sin(a)*1.6)],[.22,.14,.015],art.mat("bark"),8)
	var leaf_mesh = QuadMesh.new()
	leaf_mesh.size = Vector2(.21,.32)
	for j in range(16):
		var a: float = j*TAU/16
		var tip = tree+Vector3(cos(a)*rng.randf_range(2.1,3.5),rng.randf_range(5.8,7.8),sin(a)*2.4)
		var origin: Vector3 = points[2+j%3]
		art.tube([origin,origin.lerp(tip,.3)+Vector3(-.18,.37,.1),origin.lerp(tip,.7)+Vector3(.12,.48,-.1),tip],[.16,.11,.055,.008],art.mat("bark"),8)
		for i in range(240):
			var p: Vector3 = tip+Vector3(rng.randfn(0,.62),rng.randfn(-.18,.42),rng.randfn(0,.52))
			var basis = Basis.from_euler(Vector3(rng.randf_range(-1.3,1.3),rng.randf_range(0,TAU),rng.randf_range(-.6,.6))).scaled(Vector3.ONE*rng.randf_range(.7,1.3))
			art.batch_mesh("tree_canopy",leaf_mesh,art.mat("tree_leaf"),Transform3D(basis,p),Color(rng.randf_range(.68,1),rng.randf_range(.75,1),.8))
	# Actual tendrils follow masonry; smaller leaves create dense, irregular curtains.
	var ivy = QuadMesh.new()
	ivy.size = Vector2(.18,.20)
	for anchor in [Vector3(-5.4,7.8,.65),Vector3(3.6,7.8,.65),Vector3(5.5,7.1,.68),Vector3(11.4,7.0,.65),Vector3(-7.55,6.1,3.2),Vector3(-7.55,5.9,6.2),Vector3(-6.8,5.4,-10.4)]:
		for j in range(9):
			var length: float = rng.randf_range(.8,4.9)
			var trail: Array = []
			var radii: Array = []
			var offset: float = (j-4)*.12
			for k in range(13):
				var t: float = k/12.0
				trail.append(anchor+Vector3(offset+sin(t*5+j)*.30,-t*length,sin(t*6+j)*.09))
				radii.append(.008*(1-t*.6))
			art.tube(trail,radii,art.mat("vine"),5)
			for k in range(int(length/.10)):
				var t: float = k*.10/length
				var p = anchor+Vector3(offset+sin(t*5+j)*.30,-t*length,.07+sin(t*6+j)*.09)
				p.x += (-1 if k%2 else 1)*rng.randf_range(.04,.14)
				var basis = Basis.from_euler(Vector3(rng.randf_range(-.4,.4),rng.randf_range(-.6,.6),sin(k*2.7)*.8)).scaled(Vector3.ONE*rng.randf_range(.7,1.5))
				art.batch_mesh("ivy_fine",ivy,art.mat("ivy_leaf"),Transform3D(basis,p),Color(rng.randf_range(.65,1),rng.randf_range(.7,1),.82))
	for i in range(80):
		var p = Vector3(rng.randf_range(-7.8,4),.055,rng.randf_range(-11,7.0))
		var basis = Basis.from_euler(Vector3(-PI/2,0,rng.randf_range(0,TAU))).scaled(Vector3.ONE*rng.randf_range(.45,.9))
		art.batch_mesh("leaf_litter",ivy,art.mat("ivy_leaf"),Transform3D(basis,p),Color(.7,.52,.26))

func build_provisions() -> void:
	# A fuller low still-life close to the player: food is visible as 3D objects.
	art.bowl(Vector3(-2.7,.56,5.02),1.15)
	for i in range(7):
		var p = Vector3(-2.7+rng.randf_range(-.20,.20),.79+rng.randf_range(0,.10),5.02+rng.randf_range(-.18,.18))
		fruit(p,.11,i%2==0)
	# A cut pomegranate with seeds, not simply a coloured sphere.
	var cut = Vector3(-3.65,.83,5.43)
	art.sphere(cut,Vector3(.27,.12,.27),art.mat("cut_fruit"))
	for i in range(22):
		var a: float = i*2.4
		var r: float = sqrt(float(i)/22)*.10
		art.sphere(cut+Vector3(cos(a)*r,.065,sin(a)*r),Vector3(.026,.02,.026),art.mat("pomegranate"))
	art.worn_block(Vector3(-2.65,.27,6.05),Vector3(1.4,.54,1.0),art.mat("limestone"),.07,true)
	art.bowl(Vector3(-2.6,.57,6.12),1.25)
	for i in range(8):
		var root = art.root_vegetable(Vector3(-2.8+(i%4)*.13,.76,6.03+(i/4)*.19),.72)
		root.rotation.y = rng.randf_range(-.4,.4)
	# A shallow tray of herbs with recognisable stems, leaves and tiny flowers.
	var herb_bowl = Vector3(-1.95,.57,5.94)
	art.bowl(herb_bowl,.85)
	var leaf = QuadMesh.new()
	leaf.size = Vector2(.07,.12)
	var petal_mat = StandardMaterial3D.new()
	petal_mat.albedo_color = Color("9d6d96")
	petal_mat.roughness = .7
	for i in range(19):
		var p = herb_bowl+Vector3(rng.randf_range(-.17,.17),.2,rng.randf_range(-.15,.15))
		var tip = p+Vector3(rng.randf_range(-.08,.08),rng.randf_range(.08,.24),rng.randf_range(-.06,.06))
		art.segment(p,tip,.005,art.mat("vine"))
		var herb_leaf = art.mesh_node(leaf,tip,art.mat("ivy_leaf"))
		herb_leaf.rotation = Vector3(-PI*.5+rng.randf_range(-.3,.3),rng.randf_range(0,TAU),rng.randf_range(-.5,.5))
		for side in [-1,1]:
			var extra = art.mesh_node(leaf,p+Vector3(side*.045,.08,.01),art.mat("ivy_leaf"))
			extra.rotation = Vector3(-1.0,side*.9,.3)
		if i%3==0:
			art.sphere(tip,Vector3(.035,.025,.035),petal_mat)
	# Extra cooking utensils, a folded cloth, crockery and lantern detail.
	var cloth = PlaneMesh.new()
	cloth.size = Vector2(.78,.52)
	art.mesh_node(cloth,Vector3(-4.18,.56,5.36),art.mat("cloth")).rotation.y = .3
	art.bowl(Vector3(-4.45,.57,5.63),.6)
	art.cylinder(Vector3(-3.2,.64,4.91),.07,.17,art.mat("ceramic"))
	art.segment(Vector3(-2.35,.12,5.3),Vector3(-1.8,.32,5.1),.035,art.mat("wood"))
	# Soup pieces make the filled pot legible when approached.
	for i in range(18):
		var a: float = i*2.4
		var p: Vector3 = world.hearth+Vector3(cos(a)*rng.randf_range(.1,.5),.956,sin(a)*rng.randf_range(.1,.5))
		if i%3:
			art.sphere(p,Vector3(.09,.026,.07),art.mat("cut_fruit"))
		else:
			art.mushroom(p,.24)

func fruit(pose: Vector3, radius: float, red: bool = false) -> void:
	art.sphere(pose,Vector3.ONE*radius*2,art.mat("pomegranate") if red else art.mat("fruit_skin"))
	art.segment(pose+Vector3(0,radius*.9,0),pose+Vector3(.015,radius*1.25,0),.008,art.mat("vine"))
	if red:
		for j in range(5):
			var a: float = j*TAU/5
			art.segment(pose+Vector3(cos(a)*radius*.24,radius*.9,sin(a)*radius*.24),pose+Vector3(cos(a)*radius*.39,radius*1.15,sin(a)*radius*.39),.009,art.mat("pomegranate"))

func curved_frond() -> ArrayMesh:
	var surface = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(10):
		for ij in [Vector2i(i,0),Vector2i(i+1,0),Vector2i(i,1),Vector2i(i,1),Vector2i(i+1,0),Vector2i(i+1,1)]:
			var t: float = ij.x/10.0
			var width: float = .18*sin(t*PI)+.006
			var x: float = (ij.y-.5)*width*2
			var y: float = sin(t*PI*.64)*.54
			var z: float = t*t*.53
			surface.set_uv(Vector2(ij.y,1-t))
			surface.set_normal(Vector3(0,-1.06*t,cos(t*PI*.64)*.54*PI*.64).normalized())
			surface.add_vertex(Vector3(x,y,z))
	return surface.commit()

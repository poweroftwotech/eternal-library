extends RefCounted
## Campfire visual benchmark: physical trim, local atmosphere and authored clutter.
var world
var art
var rng = RandomNumberGenerator.new()
func _init(owner, factory) -> void:
	world = owner
	art = factory
	rng.seed = 80814
func build() -> void:
	lighting()
	masonry()
	camp_detail()
	rug_fringe()

func lighting() -> void:
	world.environment.ambient_light_energy = .13
	world.environment.tonemap_exposure = 1.05
	world.environment.ssao_radius = .85
	world.environment.ssao_intensity = 1.25
	world.environment.ssil_intensity = 1.1
	world.environment.volumetric_fog_ambient_inject = .18
	# Cut broad fills so daylight and the hearth own the composition.
	for child in world.get_children():
		if child is OmniLight3D and child != world.fire_light and (child.light_cull_mask & 1) != 0:
			child.light_energy *= .65
		if child is SpotLight3D:
			child.position = Vector3(-2.6,12.4,-4.8)
			child.look_at(Vector3(-1.8,0,-4.8),Vector3.FORWARD)
			child.light_color = Color("fff0d2")
			child.light_energy = 27.0
			child.light_volumetric_fog_energy = 1.3
			child.spot_angle = 31
			child.light_size = .55
			child.shadow_blur = 1.7
	var daylight = world.light(Vector3(-2.5,3.1,-5.3),Color("ebead7"),1.6,9)
	daylight.light_cull_mask = 1
	var cold = world.light(Vector3(8.4,2.7,-3.0),Color("4da5cc"),4.3,9,true)
	cold.light_size = .65
	var rim = world.light(world.hearth+Vector3(-1.1,1.8,-.4),Color("ffba63"),1.5,4,true)
	rim.light_size = .18
	rim.set_meta("hearth_bounce",true)
	var fog = FogVolume.new()
	fog.position = Vector3(-2.5,5.2,-5.8)
	fog.size = Vector3(8,10,10)
	var material = FogMaterial.new()
	material.density = .006
	material.albedo = Color("d1cfba")
	fog.material = material
	world.add_child(fog)
	# Small reflection capture gives glazed vessels and metal a surrounding room.
	var probe = ReflectionProbe.new()
	probe.position = Vector3(-.5,2.8,3.4)
	probe.size = Vector3(19,10,22)
	probe.interior = true
	probe.box_projection = true
	probe.intensity = .65
	probe.max_distance = 25
	probe.cull_mask = 1
	world.add_child(probe)

func masonry() -> void:
	# Broken face stones articulate the thick entrance piers.
	var spring: float = world.arch_specs[0][2]
	for cx in [-5.05,3.25,5.4,11.3]:
		for row in range(int((spring-.25)/.25)+1):
			var y: float = .33+row*.25
			var stone = art.worn_block(Vector3(cx+rng.randf_range(-.02,.02),y,.67),Vector3(.78+rng.randf_range(-.07,.06),.235,.19),art.mat("limestone"),.038)
			stone.rotation.z = rng.randf_range(-.014,.014)
		for y in [.15,spring+.23]:
			art.worn_block(Vector3(cx,y,.59),Vector3(1.02,.20,.56),art.mat("limestone"),.055)
	# Individually varied voussoir faces; the existing arches remain structural.
	for spec in world.arch_specs:
		var data: Array = [spec[0]+Vector3(0,0,.62),spec[1],spec[2],spec[3]]
		for side in [-1,1]:
			for i in range(21):
				var t: float = (i+.5)/21.0
				var a: Vector2 = world.arch_point(data[1]+.1,data[2],data[3]+.1,t-.020)
				var b: Vector2 = world.arch_point(data[1]+.1,data[2],data[3]+.1,t+.020)
				var c: Vector2 = world.arch_point(data[1]+.36,data[2],data[3]+.36,t+.019)
				var d: Vector2 = world.arch_point(data[1]+.36,data[2],data[3]+.36,t-.019)
				a.x *= side
				b.x *= side
				c.x *= side
				d.x *= side
				art.extrude(PackedVector2Array([a,b,c,d]),rng.randf_range(.08,.14),art.mat("limestone"),data[0])

func ring(pose: Vector3, radius: float, thickness: float, material: Material, vertical: bool = false) -> void:
	var mesh = TorusMesh.new()
	mesh.inner_radius = radius-thickness
	mesh.outer_radius = radius+thickness
	mesh.rings = 48
	mesh.ring_segments = 8
	var node = art.mesh_node(mesh,pose,material)
	if vertical:
		node.rotation.x = PI*.5

func camp_detail() -> void:
	var hearth: Vector3 = world.hearth
	ring(hearth+Vector3(0,1.045,0),.692,.022,art.mat("iron_cook"))
	for i in range(16):
		var a: float = TAU*i/16
		art.sphere(hearth+Vector3(sin(a)*.673,.94,cos(a)*.673),Vector3.ONE*.028,art.mat("iron"))
	# Charcoal shards and ember seams remain visible below the belly of the pot.
	for i in range(28):
		var p = hearth+Vector3(rng.randf_range(-.65,.65),.12,rng.randf_range(-.57,.57))
		var coal = art.worn_block(p,Vector3(.13,.10,.20),art.mat("iron_cook"),.025)
		coal.rotation.y = rng.randf_range(0,TAU)
		if i%3==0:
			world.effect("flame",p+Vector3(0,.18,0),Vector2(.16,.4),i*.4)
	var mug = Vector3(2.2,.11,4.75)
	var profile = [Vector2(0,0),Vector2(.12,0),Vector2(.125,.23),Vector2(.12,.25),Vector2(.10,.25),Vector2(.095,.035),Vector2(0,.035)]
	art.mesh_node(art.lathe(profile,32),mug,art.mat("copper"))
	ring(mug+Vector3(.16,.14,0),.075,.012,art.mat("copper"),true)
	# Scatter crumbs, loose leaves and pale roots around the provision slab.
	for i in range(14):
		var p = Vector3(-4.1+rng.randf()*2,.56,5.1+rng.randf()*.6)
		art.sphere(p,Vector3(.025,.012,.04),art.mat("root"))
	art.lying_books(Vector3(-4.55,.02,4.1),4,.12)
	# Embers use actual emissive geometry; steam stays animated in world space.
	for i in range(14):
		var p = hearth+Vector3(rng.randf_range(-.45,.45),rng.randf_range(.45,1.9),rng.randf_range(-.35,.35))
		art.sphere(p,Vector3.ONE*rng.randf_range(.007,.014),art.mat("ember"))
	for i in range(6):
		world.effect("steam",hearth+Vector3(rng.randf_range(-.25,.25),1.17,rng.randf_range(-.25,.25)),Vector2(.38,.8),i*1.13)

func planting() -> void:
	var leaf = QuadMesh.new()
	leaf.size = Vector2(.10,.22)
	# Plants follow joints and edges rather than uniformly carpeting the route.
	for center in [Vector3(-4.8,.06,.4),Vector3(3.1,.06,.35),Vector3(-3.1,.06,-2),Vector3(-2.2,.06,-4.2),Vector3(-6.1,.06,-4.8),Vector3(4.3,.06,-1.0)]:
		for i in range(75):
			var p = center+Vector3(rng.randf_range(-.55,.55),rng.randf_range(.04,.21),rng.randf_range(-.4,.4))
			var basis = Basis.from_euler(Vector3(rng.randf_range(-.6,.6),rng.randf_range(0,TAU),rng.randf_range(-.9,.9)))
			art.batch_mesh("benchmark_ground_growth",leaf,art.mat("tree_leaf"),Transform3D(basis,p),Color(.72,.81,.46))
	for i in range(85):
		var p = Vector3(rng.randf_range(-6.5,4.0),.065,rng.randf_range(-3,6))
		var basis = Basis.from_euler(Vector3(-PI/2,0,rng.randf_range(0,TAU))).scaled(Vector3.ONE*rng.randf_range(.3,.7))
		art.batch_mesh("benchmark_fallen_leaves",leaf,art.mat("ivy_leaf"),Transform3D(basis,p),Color(.8,.52,.23))

func rug_fringe() -> void:
	var center = world.rug_center+Vector3(0,.005,0)
	var basis = Basis(Vector3.UP,-.11)
	for side in [-1,1]:
		for i in range(80):
			var x: float = -2.16+i*.055
			var length: float = rng.randf_range(.08,.16)
			var a = center+basis*Vector3(x,.005,side*1.6)
			var b = center+basis*Vector3(x+rng.randf_range(-.02,.02),.001,side*(1.6+length))
			art.segment(a,b,.007,art.mat("linen"))

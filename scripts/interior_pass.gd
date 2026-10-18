extends RefCounted
## Interior art direction: vaulted lightwell, articulated masonry, planted joints and objects.
var world
var art
var rng = RandomNumberGenerator.new()
var vault_segments: int = 0
var planting_beds: int = 0

func _init(owner, factory) -> void:
	world = owner
	art = factory
	rng.seed = 50173

func build() -> void:
	build_vault()
	build_arch_surrounds()
	build_planted_joints()
	build_reading_objects()
	build_water_detail()

func build_vault() -> void:
	var surface = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var z_edges = [-13.2,-9.0,-7.6,-2.9,.05]
	for i in range(32):
		var t0: float = PI*i/32
		var t1: float = PI*(i+1)/32
		var a = Vector2(-2.2+cos(t0)*7.2,8.0+sin(t0)*5.3)
		var b = Vector2(-2.2+cos(t1)*7.2,8.0+sin(t1)*5.3)
		var middle_x: float = (a.x+b.x)*.5
		for j in range(z_edges.size()-1):
			if middle_x> -4.8 and middle_x< -.8 and j==2:
				continue
			var normal = Vector3(-cos((t0+t1)*.5)/7.2,-sin((t0+t1)*.5)/5.3,0).normalized()
			var p = Vector3(a.x,a.y,z_edges[j])
			var q = Vector3(b.x,b.y,z_edges[j])
			var r = Vector3(a.x,a.y,z_edges[j+1])
			var u = Vector3(b.x,b.y,z_edges[j+1])
			art.add_triangle(surface,p,q,r,normal,[Vector2.ZERO,Vector2.RIGHT,Vector2.UP])
			art.add_triangle(surface,q,u,r,normal,[Vector2.RIGHT,Vector2.ONE,Vector2.UP])
			vault_segments += 1
	art.mesh_node(surface.commit(),Vector3.ZERO,art.mat("vault_plaster"))
	# A recessed eight-pointed glazed lantern, enclosed by the solid roof above.
	var center = Vector3(-2.9,12.96,-5.1)
	var polygon = PackedVector2Array()
	var border: Array = []
	var radii: Array = []
	for i in range(17):
		var a: float = TAU*(i%16)/16
		var radius: float = 1.0 if i%2==0 else .76
		var p = Vector2(cos(a)*1.9*radius,sin(a)*2.3*radius)
		if i<16:
			polygon.append(p)
		border.append(center+Vector3(p.x,-.06,-p.y))
		radii.append(.10)
	var glass = StandardMaterial3D.new()
	glass.albedo_color = Color("c3d9cd")
	glass.emission_enabled = true
	glass.emission = Color("c1d8c6")
	glass.emission_energy_multiplier = 1.3
	var panel = art.extrude(polygon,.06,glass,center)
	panel.rotation.x = -PI*.5
	art.tube(border,radii,art.mat("limestone"),10)
	for i in range(8):
		var a: float = TAU*i/8
		art.segment(center+Vector3(0,-.12,0),center+Vector3(cos(a)*1.82,-.12,sin(a)*2.20),.025,art.mat("brass"))
	art.cylinder(center-Vector3(0,.17,0),.20,.08,art.mat("brass"))
	# Lift the plaster and ribs with soft reflected light below the lightwell.
	world.light(Vector3(-3,10.7,-5.2),Color("dce0c2"),1.8,12)
	var fog = FogVolume.new()
	fog.position = Vector3(-2.1,6.3,-6)
	fog.size = Vector3(13.6,11.0,12.2)
	var fog_material = FogMaterial.new()
	fog_material.density = .003
	fog_material.albedo = Color("b5bfac")
	fog.material = fog_material
	world.add_child(fog)

func build_arch_surrounds() -> void:
	for data in world.arch_specs:
		var origin: Vector3 = data[0]
		for offset in [.03,.21,.48]:
			for side in [-1,1]:
				var path: Array = []
				var widths: Array = []
				for i in range(37):
					var p: Vector2 = world.arch_point(data[1]+offset,data[2],data[3]+offset,i/36.0)
					path.append(origin+Vector3(side*p.x,p.y,.65+offset*.15))
					widths.append(.045 if offset<.4 else .065)
				art.tube(path,widths,art.mat("limestone"),10)
		for side in [-1,1]:
			for y in [.25,data[2]-.25]:
				art.worn_block(origin+Vector3(side*(data[1]+.22),y,.15),Vector3(.83,.24,1.25),art.mat("limestone"),.045)
	# Small arches support the gallery; taller openings remain clear of the stair.
	for x in [-5.55,-3.05,-.55]:
		world.arch(Vector3(x,0,-9.72),1.02,.42,1.18,.15)
	for i in range(12):
		var x: float = -6.7+i*.65
		var profile = [Vector2(0,0),Vector2(.09,0),Vector2(.09,.11),Vector2(.055,.18),Vector2(.07,.5),Vector2(.045,.72),Vector2(.08,.84),Vector2(.09,.92),Vector2(0,.92)]
		art.mesh_node(art.lathe(profile,12),Vector3(x,2.3,-9.57),art.mat("limestone"))

func build_garden_floor() -> void:
	# Broken slab groups read as paths rather than a uniformly tiled courtyard.
	for side in [-1,1]:
		for row in range(8):
			var z: float = -.6-row*1.10
			var x: float = (-3.3 if side<0 else .50)+rng.randf_range(-.14,.12)
			if side>0 and z< -3.0:
				x = .40
			var slab = art.worn_block(Vector3(x,.005,z),Vector3(rng.randf_range(1.15,1.6),.075,rng.randf_range(.92,1.02)),art.mat("floor_stone"),.025)
			slab.rotation.y = rng.randf_range(-.045,.045)
	# Flat rubble is grouped at roots and borders, away from the stair lane.
	for center in [Vector3(-4,0,-6.2),Vector3(-7.9,0,-2.2),Vector3(4.0,0,-1.5)]:
		for i in range(12):
			var a: float = i*2.4
			var radius: float = rng.randf_range(.55,1.35)
			var p: Vector3 = center+Vector3(cos(a)*radius,.015,sin(a)*radius)
			var block_node = art.worn_block(p,Vector3(rng.randf_range(.18,.48),.09,rng.randf_range(.14,.4)),art.mat("hearth_stone"),.02)
			block_node.rotation.y = a

func earth(p: Vector3, size: Vector2) -> void:
	planting_beds += 1
	var mesh = PlaneMesh.new()
	mesh.size = size
	var node = art.mesh_node(mesh,p,art.mat("earth_patch"))
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func build_planted_joints() -> void:
	earth(Vector3(-4,.051,-6.2),Vector2(4.5,3.3))
	for id in world.gatherables:
		var data: Dictionary = world.gatherables[id]
		if data.kind!="mushroom":
			earth(data.visual.position+Vector3(0,.004,0),Vector2(1.3,1.05))
	for p in [Vector3(-4.8,.05,-.8),Vector3(3.8,.05,.1),Vector3(-7.5,.05,-3.0),Vector3(-2.9,.05,-5.0),Vector3(-2.8,.05,-8.2)]:
		earth(p,Vector2(1.45,1.2))
		var leaf = QuadMesh.new()
		leaf.size = Vector2(.12,.29)
		for j in range(22):
			var angle: float = j*2.4
			var q: Vector3 = p+Vector3(cos(angle)*rng.randf_range(.08,.48),rng.randf_range(.08,.2),sin(angle)*rng.randf_range(.08,.48))
			var basis = Basis.from_euler(Vector3(rng.randf_range(-.8,.8),angle,rng.randf_range(-.4,.4)))
			art.batch_mesh("crack_growth",leaf,art.mat("tree_leaf"),Transform3D(basis,q),Color(.83,1.0,.65))
	# Vines trace the arch and branch sideways over the stone instead of only hanging.
	for side in [-1,1]:
		var path: Array = []
		for i in range(25):
			var t: float = i/24.0
			var spec: Array = world.arch_specs[0]
			var p: Vector2 = world.arch_point(spec[1]+.28,spec[2],spec[3]+.28,t)
			path.append(Vector3(-1+side*p.x,p.y,.86))
		vine(path)

func vine(path: Array) -> void:
	var radii: Array = []
	for i in range(path.size()):
		radii.append(.009)
	art.tube(path,radii,art.mat("vine"),6)
	var leaf = QuadMesh.new()
	leaf.size = Vector2(.16,.20)
	for i in range(path.size()-1):
		for j in range(7):
			var p: Vector3 = path[i].lerp(path[i+1],j/7.0)+Vector3(rng.randf_range(-.17,.17),rng.randf_range(-.12,.12),rng.randf_range(-.03,.08))
			var basis = Basis.from_euler(Vector3(rng.randf_range(-.4,.4),rng.randf_range(-.5,.5),rng.randf_range(-.9,.9)))
			art.batch_mesh("clinging_ivy",leaf,art.mat("ivy_leaf"),Transform3D(basis,p),Color(.85,1.0,.76))

func build_reading_objects() -> void:
	for p in [Vector3(-6.7,.02,1.1),Vector3(-6.6,.78,-3.3),Vector3(3.2,.05,6.2),Vector3(10.0,.03,-7.8)]:
		art.lying_books(p,rng.randi_range(2,4),rng.randf_range(-.4,.4))
	# Rolled sheets and small vessels break up the shelf rhythm close to the camp.
	for i in range(5):
		var node = art.cylinder(Vector3(-6.9+i*.11,.40,1.0),.045,.47,art.mat("pages"))
		node.rotation = Vector3(PI*.5,0,.11)
	# A proper deep wooden ladle replaces the flattened spoon silhouette.
	var profile = [Vector2(0,0),Vector2(.10,.01),Vector2(.14,.05),Vector2(.12,.09),Vector2(.08,.10),Vector2(0,.045)]
	var ladle = art.mesh_node(art.lathe(profile,20),world.hearth+Vector3(.7,.46,.76),art.mat("wood"))
	ladle.rotation.z = -.2

func build_water_detail() -> void:
	# Raised upstream water spills over a small lip into the original shallow channel.
	var water = ShaderMaterial.new()
	water.shader = load("res://shaders/water.gdshader")
	var plane = PlaneMesh.new()
	plane.size = Vector2(.82,1.5)
	art.mesh_node(plane,Vector3(-.88,.17,-2.0),water)
	for side in [-1,1]:
		art.worn_block(Vector3(-.88+side*.55,.12,-2.0),Vector3(.24,.26,1.6),art.mat("limestone"),.035)
	var face = QuadMesh.new()
	face.size = Vector2(.82,.22)
	var cascade = ShaderMaterial.new()
	cascade.shader = load("res://shaders/interior_cascade.gdshader")
	art.mesh_node(face,Vector3(-.88,.06,-1.24),cascade)
	world.light(Vector3(-.9,1.0,-1),Color("a4d1c9"),.35,4)

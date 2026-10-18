extends RefCounted
## Compact, connected library gorge: tier footprints deliberately change at each level.
var world
var art
var rng = RandomNumberGenerator.new()
var extent: float = 0
var bank_count: int = 0
var tier_count: int = 0
var shelf_bays: int = 0
var window_count: int = 0
var bridge_count: int = 0
var waterfall_count: int = 0
var max_tier_height: float = 0
var profile_variation: float = 0
var arch_mesh: Mesh
var ledges: Array = []

func _init(owner, factory) -> void:
	world = owner
	art = factory
	rng.seed = 728311

func block(p: Vector3, size: Vector3, material: String = "sandstone", solid: bool = false) -> Node3D:
	return art.box(p,size,art.mat(material),solid)

func exterior_materials() -> void:
	# Exterior variants leave the v0.5 interior material/lighting calibration intact.
	var gold = art.mat("brass").duplicate()
	gold.albedo_color = Color("c6a66b")
	gold.metallic = .25
	gold.roughness = .55
	art.materials["vista_gold"] = gold
	var blue = art.mat("exterior_faience")
	blue.uv1_triplanar = true
	blue.uv1_world_triplanar = true
	blue.uv1_scale = Vector3.ONE*.13
	blue.normal_scale = 1.3
	blue.metallic = .12
	var dome = art.mat("tile").duplicate()
	dome.albedo_color = Color("8ab8b9")
	dome.uv1_scale = Vector3.ONE*.12
	dome.metallic = .08
	dome.metallic_specular = .35
	art.materials["vista_dome"] = dome
	var windows = art.mat("lit_window").duplicate()
	windows.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
	windows.emission_energy_multiplier = .38
	windows.emission = Color("e9bd77")
	art.materials["vista_window"] = windows
	var lamp = StandardMaterial3D.new()
	lamp.albedo_color = Color("ffd6a1")
	lamp.emission_enabled = true
	lamp.emission = Color("ffc379")
	lamp.emission_energy_multiplier = 2.6
	art.materials["vista_lamp"] = lamp

func build_balcony() -> void:
	# Unbroken walking surface from gallery through a short vaulted passage.
	block(Vector3(-1,2,-17.4),Vector3(4.4,.4,8.8),"paving",true)
	for x in [-3.3,1.3]:
		block(Vector3(x,4.6,-17.5),Vector3(.4,5.2,9),"brick",true)
		block(Vector3(x,3.0,-17.5),Vector3(.46,.65,9),"tile")
	block(Vector3(-1,7.25,-17.5),Vector3(5,.5,9),"sandstone",true)
	for z in [-14,-17,-20.2]:
		world.arch(Vector3(-1,2.2,z),1.8,1.8,2.1,.22)
	for z in [-15.6,-19.6]:
		world.lantern(Vector3(-2.9,4.5,z))
	block(Vector3(-1,1.8,-24.0),Vector3(13,.8,8.6),"sandstone",true)
	block(Vector3(-1,2.21,-24),Vector3(12.6,.035,8),"tile")
	# Ceiling and columns frame the view while keeping the player underground.
	block(Vector3(-1,8.8,-23.8),Vector3(14,.6,10),"cave",true)
	for x in [-7.0,5.0]:
		for z in [-20.7,-27.4]:
			block(Vector3(x,5.0,z),Vector3(.55,5.7,.65),"sandstone",true)
			block(Vector3(x,2.6,z),Vector3(.9,.7,.95),"tile")
			block(Vector3(x,7.6,z),Vector3(.85,.3,.95),"vista_gold")
	for z in [-20.7,-27.4]:
		world.arch(Vector3(-1,2.2,z),5.7,3.0,2.7,.26)
	# Solid stone parapets and a continuous guard prevent falling or jumping out.
	block(Vector3(-1,2.56,-28.1),Vector3(13,.7,.5),"sandstone",true)
	for x in [-7.3,5.3]:
		block(Vector3(x,2.56,-24.1),Vector3(.45,.7,8.5),"sandstone",true)
		block(Vector3(x,3.25,-24.1),Vector3(.24,.18,8.5),"vista_gold")
		guard(Vector3(x,4.0,-24.1),Vector3(.4,3.8,8.5))
	guard(Vector3(-1,4,-28.1),Vector3(13,3.8,.4))
	block(Vector3(-1,3.25,-28.1),Vector3(13,.08,.12),"limestone")
	for x in range(-7,6):
		block(Vector3(x,2.72,-27.79),Vector3(.55,.42,.035),"tile")
	world.lantern(Vector3(-6.4,3.9,-26.4))
	world.lantern(Vector3(4.4,3.9,-26.4))
	world.light(Vector3(-1,6,-23.6),Color("92b9c2"),1.6,13)
	world.interaction("vista","Survey the Eternal Library",Vector3(-1,3.4,-27.8),Vector3(5,1.8,.25))
	# A small lectern and pots reward noticing the foreground rather than only the vista.
	var lectern = block(Vector3(2.4,3,-26.2),Vector3(.8,.13,.55),"wood")
	lectern.rotation.x = .24
	block(Vector3(2.4,2.62,-26.2),Vector3(.2,.8,.24),"sandstone")
	block(Vector3(2.4,3.12,-26.2),Vector3(.56,.08,.4),"pages").rotation.x = .24
	art.vase(Vector3(-6.2,2.23,-22.4),1.2)
	art.vase(Vector3(4.2,2.23,-22.4),1.0)

func guard(p: Vector3, size: Vector3) -> void:
	var body = StaticBody3D.new()
	body.position = p
	var collision = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	world.add_child(body)

func balcony_details() -> void:
	# Carved stone caps and turned balusters soften the former dark horizontal bar.
	for x in range(-7,6):
		art.bevel_box(Vector3(x,2.95,-28.06),Vector3(.91,.12,.66),art.mat("limestone"),.035)
		var profile = [Vector2(0,0),Vector2(.11,0),Vector2(.07,.08),Vector2(.12,.18),Vector2(.055,.28),Vector2(.06,.44),Vector2(.10,.49),Vector2(0,.49)]
		art.mesh_node(art.lathe(profile,12),Vector3(x+.46,2.76,-28.1),art.mat("limestone"))
	for x in [-6.8,-3.7,1.7,4.8]:
		art.bevel_box(Vector3(x,2.89,-28.0),Vector3(.42,.64,.7),art.mat("exterior_faience"),.04)
		art.bevel_box(Vector3(x,3.24,-28.0),Vector3(.56,.12,.8),art.mat("limestone"),.025)
	# The rug is folded over the parapet and continues onto the terrace floor.
	var rug = QuadMesh.new()
	rug.size = Vector2(2.1,1.2)
	art.mesh_node(rug,Vector3(-3.2,2.52,-27.76),art.mat("rug"))
	var fold = block(Vector3(-3.2,2.94,-27.96),Vector3(2.1,.025,.8),"rug")
	fold.rotation.z = .012
	art.lying_books(Vector3(-5.7,3.06,-27.9),4,.42)
	art.vase(Vector3(4.45,2.96,-27.85),.45)
	for side in [-1,1]:
		var x: float = -1+side*5.9
		for z in [-21.1,-27.0]:
			fluted_column(Vector3(x,2.3,z),.35,5.8)
			panel(Vector3(x-side*.04,5.8,z+.36),Vector2(.75,1.15),"wing_relief")
	# Decorated soffit, physically attached to the canopy. No sky above the player.
	for x in range(-6,5,2):
		for z in [-22.0,-24.0,-26.0]:
			block(Vector3(x,8.43,z),Vector3(1.8,.07,1.8),"exterior_faience")
	for x in [-6.4,4.4]:
		world.light(Vector3(x,5.7,-26.3),Color("ffd09b"),2.5,9)
	# A few hanging leaves frame the city without blocking the route.
	for side in [-1,1]:
		for strand in range(5):
			var path: Array = []
			var radii: Array = []
			for i in range(7):
				var p = Vector3(-1+side*(5.5+strand*.16)+sin(i*.8)*.1,8.2-i*.26-strand*.12,-27.2)
				path.append(p)
				radii.append(.023)
				if i>1:
					art.sphere(p+Vector3(side*.09,0,.03),Vector3(.18,.11,.055),art.mat("leaf"))
			art.tube(path,radii,art.mat("vine"),6)

func fluted_column(base: Vector3, radius: float, height: float) -> void:
	art.cylinder(base+Vector3(0,height*.5,0),radius,height,art.mat("sandstone"),null,radius*.85)
	for i in range(8):
		var angle: float = TAU*i/8
		art.cylinder(base+Vector3(cos(angle)*radius*.83,height*.48,sin(angle)*radius*.83),radius*.18,height*.9,art.mat("vista_gold"))
	for y in [.10,height-.15]:
		art.cylinder(base+Vector3(0,y,0),radius*1.65,.25,art.mat("exterior_faience"))
		art.cylinder(base+Vector3(0,y+.14,0),radius*1.8,.08,art.mat("vista_gold"))

func window(p: Vector3, size: Vector2, yaw: float = 0) -> void:
	var quad = QuadMesh.new()
	quad.size = Vector2.ONE
	# Local scaling is essential: world-axis scaling squashes side-facing windows.
	var basis: Basis = Basis(Vector3.UP,yaw)*Basis.from_scale(Vector3(size.x,size.y,1))
	art.batch_mesh("vista_windows",quad,art.mat("vista_window"),Transform3D(basis,p),Color(1,rng.randf_range(.70,.94),rng.randf_range(.42,.70))*rng.randf_range(.25,.85))
	window_count += 1

func panel(p: Vector3, size: Vector2, material: String) -> void:
	var quad = QuadMesh.new()
	quad.size = size
	art.mesh_node(quad,p,art.mat(material))

func dome(base: Vector3, radius: float, height: float) -> void:
	var profile = [Vector2(0,0),Vector2(radius,0),Vector2(radius*1.04,height*.1),Vector2(radius*.94,height*.42),Vector2(radius*.60,height*.76),Vector2(radius*.12,height*.96),Vector2(0,height)]
	art.mesh_node(art.lathe(profile,32),base,art.mat("vista_dome"))
	for i in range(16):
		var a: float = TAU*i/16
		var path: Array = []
		var radii: Array = []
		for point in profile.slice(1):
			path.append(base+Vector3(cos(a)*point.x*1.012,point.y,sin(a)*point.x*1.012))
			radii.append(radius*.014)
		art.tube(path,radii,art.mat("vista_gold"),6)
	art.cylinder(base+Vector3(0,height+1.4,0),radius*.025,3,art.mat("vista_gold"),null,0)

func pavilion(p: Vector3, size: float) -> void:
	for side in [-1,1]:
		for depth in [-1,1]:
			art.cylinder(p+Vector3(side*size*.45,1.8,depth*size*.45),.12,3.6,art.mat("vista_gold"))
	var roof = [Vector2(0,3.2),Vector2(size*.72,3.2),Vector2(size*.62,3.5),Vector2(size*.3,3.9),Vector2(0,5.0)]
	art.mesh_node(art.lathe(roof,4),p,art.mat("tapestry_0")).rotation.y = PI*.25
	lamp(p+Vector3(0,3.0,0),.3)

func reader(p: Vector3, yaw: float) -> void:
	# Tiny static robed silhouettes are scale markers, not a new NPC system.
	var mesh = CylinderMesh.new()
	mesh.top_radius = .22
	mesh.bottom_radius = .37
	mesh.height = 1.25
	mesh.radial_segments = 7
	art.batch_mesh("vista_readers",mesh,art.mat("cloth"),Transform3D(Basis(Vector3.UP,yaw),p+Vector3.UP*.7))
	var head = SphereMesh.new()
	head.radius = .19
	head.height = .4
	head.radial_segments = 8
	head.rings = 4
	art.batch_mesh("vista_reader_heads",head,art.mat("sandstone"),Transform3D(Basis.IDENTITY,p+Vector3.UP*1.5))

func lamp(p: Vector3, size: float) -> void:
	art.batch_box("vista_lamps",p,Vector3(size,size*1.6,size),art.mat("vista_lamp"))

func mist(p: Vector3, size: Vector3, density: float, color: Color) -> void:
	var fog = FogVolume.new()
	fog.shape = RenderingServer.FOG_VOLUME_SHAPE_ELLIPSOID
	fog.position = p
	fog.size = size
	var material = FogMaterial.new()
	material.density = density
	material.albedo = color
	material.emission = color*.035
	fog.material = material
	world.add_child(fog)

func crag(base: Vector3, radius: float, height: float, material: Material) -> void:
	var surface = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array = []
	for ring in range(6):
		var row: Array = []
		var t: float = ring/5.0
		for i in range(11):
			var a: float = TAU*i/10
			var r: float = radius*(.025+pow(t,.63))*rng.randf_range(.72,1.23)
			row.append(Vector3(cos(a)*r+sin(t*4)*radius*.16,t*height+rng.randf_range(-1,1)*t,sin(a)*r))
		row[10] = row[0]
		rings.append(row)
	for ring in range(5):
		for i in range(10):
			for index in [Vector2i(i,ring),Vector2i(i+1,ring),Vector2i(i,ring+1),Vector2i(i+1,ring),Vector2i(i+1,ring+1),Vector2i(i,ring+1)]:
				var p: Vector3 = rings[index.y][index.x]
				surface.set_uv(Vector2(p.x+p.z,p.y)*.07)
				surface.add_vertex(p)
	surface.generate_normals()
	art.mesh_node(surface.commit(),base,material)

func waterfall(p: Vector3, size: Vector2) -> void:
	waterfall_count += 1
	# A bent ribbon splits into strands; its foot fades into a local spray volume.
	var material = ShaderMaterial.new()
	material.shader = load("res://shaders/waterfall.gdshader")
	material.set_shader_parameter("seed",float(waterfall_count)*7.13)
	for layer in range(2):
		var surface = SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for y in range(28):
			for x in range(10):
				for corner in [Vector2i(0,0),Vector2i(1,0),Vector2i(0,1),Vector2i(1,0),Vector2i(1,1),Vector2i(0,1)]:
					var uv = Vector2(float(x+corner.x)/10,float(y+corner.y)/28)
					var spread: float = 1+pow(uv.y,3)*.5
					var point = Vector3((uv.x-.5)*size.x*spread,-uv.y*size.y,sin(uv.y*4)*2.7+pow(uv.y,2)*5+layer*.55)
					surface.set_uv(uv)
					surface.set_normal(Vector3.FORWARD)
					surface.add_vertex(point)
		art.mesh_node(surface.commit(),p,material)
	prism(outline(Vector2(p.x,p.z-1.5),size.x*.5+2.5,3,0.0,0.0),p.y-.5,.8,art.mat("exterior_faience"))
	mist(p-Vector3.UP*(size.y*.91)+Vector3(0,0,6),Vector3(size.x*3,size.y*.18,27),.018,Color("b9d5d9"))
	world.light(p+Vector3(0,-size.y*.22,10),Color("9bc7db"),4,size.y*.55)

func build() -> void:
	exterior_materials()
	gorge_materials()
	# The sheltered balcony belongs to the interior light layer.
	art.render_layer = 1
	build_balcony()
	balcony_details()
	art.render_layer = 2
	build_enclosure()
	# Eight overlapping banks form one continuous inhabited gorge.
	for data in [
		[-78,-84,37,36,25,1],[88,-103,43,40,12,2],
		[-65,-140,32,37,39,3],[67,-163,37,42,35,4],
		[-76,-204,43,41,29,5],[83,-223,41,41,46,6],
		[-39,-262,43,36,48,7],[60,-277,48,39,53,8]]:
		bank(Vector2(data[0],data[1]),data[2],data[3],data[4],data[5])
	sanctum(Vector3(8,-13,-252))
	bridge(Vector3(-37,-19,-89),Vector3(41,-26,-116),4.2)
	bridge(Vector3(-29,-58,-141),Vector3(34,-63,-172),3.8)
	bridge(Vector3(-37,-105,-91),Vector3(38,-100,-133),4.0)
	bridge(Vector3(-26,-20,-211),Vector3(30,-12,-231),3.6)
	bridge(Vector3(-32,-132,-192),Vector3(36,-124,-222),3.5)
	bridge(Vector3(-47,14,-205),Vector3(-11,8,-249),3.0)
	waterfall(Vector3(-35,-18.4,-88),Vector2(4.8,94))
	waterfall(Vector3(40,-25.4,-114),Vector2(6,121))
	waterfall(Vector3(8,-12.4,-228),Vector2(12,148))
	waterfall(Vector3(-29,-57.4,-140),Vector2(4.5,101))
	mist(Vector3(4,-151,-163),Vector3(90,55,218),.018,Color("9bbbc4"))
	mist(Vector3(8,38,-258),Vector3(33,64,43),.007,Color("bdd8db"))
	world.light(Vector3(0,35,-90),Color("9cbfc5"),3.5,100)
	world.light(Vector3(7,53,-230),Color("a9c9d1"),5.0,103)
	var bounce = DirectionalLight3D.new()
	bounce.name = "ExteriorVaultBounce"
	bounce.rotation_degrees = Vector3(-39,-28,0)
	bounce.light_color = Color("a6bac1")
	bounce.light_energy = .9
	bounce.shadow_enabled = true
	bounce.directional_shadow_max_distance = 330
	bounce.light_angular_distance = 1.0
	bounce.shadow_blur = 1.5
	bounce.light_cull_mask = 2
	bounce.light_volumetric_fog_energy = .1
	world.add_child(bounce)
	art.render_layer = 1

func gorge_materials() -> void:
	# Inset shelves carry true book scale; the old repeating building-facade atlas
	# is not used on the banks. The masonry and arches are actual geometry.
	var shelves = art.mat("gorge_books").duplicate()
	shelves.uv1_triplanar = false
	shelves.uv1_world_triplanar = false
	shelves.uv1_scale = Vector3.ONE
	shelves.albedo_color = Color("e1d5bd")
	shelves.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	shelves.alpha_scissor_threshold = .45
	shelves.emission_enabled = true
	shelves.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
	shelves.emission_texture = shelves.albedo_texture
	shelves.emission = Color("d3b488")
	shelves.emission_energy_multiplier = .15
	art.materials["gorge_shelves"] = shelves
	var stone = art.mat("sandstone").duplicate()
	stone.albedo_color = Color("8b9c9c")
	stone.uv1_scale = Vector3.ONE*.21
	art.materials["gorge_stone"] = stone
	var pier = art.mat("exterior_faience").duplicate()
	pier.uv1_scale = Vector3.ONE*.25
	art.materials["gorge_pier"] = pier
	var back = art.mat("stack_atlas").duplicate()
	back.uv1_scale = Vector3.ONE*.11
	back.albedo_color = Color("8c8b88")
	art.materials["gorge_background"] = back
	var warm = art.mat("lit_window").duplicate()
	warm.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
	warm.emission_energy_multiplier = 1.8
	warm.emission = Color("ffca81")
	warm.vertex_color_use_as_albedo = false
	art.materials["gorge_portal"] = warm

func outline(center: Vector2, rx: float, rz: float, phase: float, turn: float) -> PackedVector2Array:
	var polygon = PackedVector2Array()
	for i in range(12):
		var a: float = TAU*i/12
		var variation: float = 1+.055*sin(i*2.1+phase)+.035*cos(i*3.0-phase)
		var v: Vector2 = Vector2(cos(a)*rx,sin(a)*rz)*variation
		polygon.append(center+v.rotated(turn))
	return polygon

func prism(polygon: PackedVector2Array, bottom: float, height: float, material: Material) -> MeshInstance3D:
	# Existing audited extrusion supplies outward walls and both horizontal caps.
	var node = art.extrude(polygon,height,material,Vector3(0,bottom+height*.5,0))
	node.rotation.x = PI*.5
	return node

func bank(center: Vector2, rx: float, rz: float, top: float, seed_value: int) -> void:
	bank_count += 1
	extent = maxf(extent,absf(center.y)+rz)
	var local = RandomNumberGenerator.new()
	local.seed = seed_value*8329
	var bottom: float = -176
	var level: int = 0
	var last_rx: float = rx
	while bottom<top-.05:
		var h: float = minf(top-bottom,local.randf_range(8.3,11.7))
		var t: float = (bottom+176)/(top+176)
		# Broad, non-monotonic ledges: expanding landings alternate with setbacks.
		var sx: float = rx*(1.09-.22*t+.15*sin(level*1.71+seed_value))
		var sz: float = rz*(1.02-.16*t+.12*cos(level*1.29+seed_value))
		var offset = Vector2(sin(level*.87+seed_value)*rx*.10,cos(level*.72+seed_value)*rz*.09)
		var turn: float = .13*sin(level*.69+seed_value)
		var polygon = outline(center+offset,sx,sz,seed_value,turn)
		prism(polygon,bottom,h,art.mat("gorge_stone"))
		profile_variation = maxf(profile_variation,absf(last_rx-sx))
		max_tier_height = maxf(max_tier_height,h)
		var deck = outline(center+offset,sx+2.2,sz+2.2,seed_value,turn)
		prism(deck,bottom+h-.5,.65,art.mat("exterior_faience"))
		prism(deck,bottom+h-.83,.20,art.mat("vista_gold"))
		var occupied: bool = level%3==seed_value%3
		ledge_edges(deck,bottom+h,occupied,seed_value)
		facades(polygon,bottom,h,seed_value+level)
		ledges.append({"center":center+offset,"height":bottom+h,"rx":sx,"rz":sz})
		tier_count += 1
		last_rx = sx
		bottom += h
		level += 1
	# A few roof lanterns/pavilions interrupt the silhouette, rather than a dome
	# capping every repeated vertical shaft.
	if seed_value in [1,4,7]:
		pavilion(Vector3(center.x,top+.2,center.y),7.5)
		if seed_value==4:
			rotunda(Vector3(center.x-4,top,center.y+5),5.4,9.5)

func facades(polygon: PackedVector2Array, bottom: float, height: float, style: int) -> void:
	for i in range(polygon.size()):
		var a = polygon[i]
		var b = polygon[(i+1)%polygon.size()]
		var direction: Vector2 = (b-a).normalized()
		var normal = Vector3(direction.y,0,-direction.x)
		var center: Vector2 = (a+b)*.5
		var toward_gorge = Vector3(-center.x,0,0).normalized()
		# Back faces merge into the adjacent bank/enclosure and need no windows.
		if normal.dot(toward_gorge)<.05 and normal.z<.35:
			continue
		var length: float = a.distance_to(b)
		var bays: int = maxi(1,int(length/4.2))
		var yaw: float = atan2(normal.x,normal.z)
		var row_count: int = 2 if height>8.5 else 1
		for j in range(bays):
			var v: Vector2 = a.lerp(b,(j+.5)/bays)
			for row in range(row_count):
				var base = Vector3(v.x,bottom+.28+row*height/row_count,v.y)+normal*.09
				arcade(base,yaw,style+j+row)
		# Slim projecting supports break up the shelf face and join cornices.
		for v in [a,b]:
			var pier = block(Vector3(v.x,bottom+height*.5,v.y)+normal*.21,Vector3(.42,height,.65),"gorge_pier")
			pier.rotation.y = yaw
		if bottom> -110 and (i+style)%9==0:
			var at = Vector3(center.x,bottom+height*.70,center.y)+normal*3.5
			world.light(at,Color("ffc790"),4.0,18)

func arcade(base: Vector3, yaw: float, style: int) -> void:
	if arch_mesh==null:
		var source = art.extrude(arcade_outline(),.43,art.mat("sandstone"),Vector3.ZERO)
		arch_mesh = source.mesh
		source.free()
	var basis = Basis(Vector3.UP,yaw)
	art.batch_mesh("gorge_arch_frames",arch_mesh,art.mat("sandstone"),Transform3D(basis,base))
	var quad = QuadMesh.new()
	quad.size = Vector2.ONE
	var shelf_pose: Vector3 = base+Vector3.UP*2.1-basis.z*.04
	art.batch_mesh("gorge_shelf_insets",quad,art.mat("gorge_shelves"),Transform3D(basis*Basis.from_scale(Vector3(2.75,4.2,1)),shelf_pose))
	if style%7==0:
		window(base+Vector3.UP*2.3+basis.z*.04,Vector2(.86,2.65),yaw)
	lamp(base+basis.x*1.62+Vector3.UP*2.56+basis.z*.42,.12)
	shelf_bays += 1

func arcade_outline() -> PackedVector2Array:
	# Both halves are two-centred pointed curves, matching the inset alpha mask.
	var polygon = PackedVector2Array([Vector2(-1.65,0),Vector2(-1.65,2.2)])
	for i in range(1,25):
		polygon.append(pointed_top(1.65,2.1,i/24.0))
	polygon.append(Vector2(1.65,0))
	polygon.append(Vector2(1.37,0))
	polygon.append(Vector2(1.37,2.2))
	for i in range(1,25):
		polygon.append(pointed_top(1.37,1.82,1-i/24.0))
	polygon.append(Vector2(-1.37,0))
	return polygon

func pointed_top(radius: float, rise: float, u: float) -> Vector2:
	var center: float = (radius*radius-rise*rise)/(2*radius)
	var cr: float = radius-center
	var angle: float = atan2(rise,-center)
	var t: float = 1-absf(2*u-1)
	var side: float = -1.0 if u<.5 else 1.0
	return Vector2(side*(center+cr*cos(angle*t)),2.2+cr*sin(angle*t))

func ledge_edges(polygon: PackedVector2Array, y: float, occupied: bool, style: int) -> void:
	for i in range(polygon.size()):
		var a = Vector3(polygon[i].x,y,polygon[i].y)
		var b = Vector3(polygon[(i+1)%polygon.size()].x,y,polygon[(i+1)%polygon.size()].y)
		var normal = Vector3((b-a).z,0,-(b-a).x).normalized()
		var center: Vector3 = (a+b)*.5
		if normal.dot(Vector3(-center.x,0,0).normalized())<.05 and normal.z<.35:
			continue
		var count: int = maxi(2,int(a.distance_to(b)/2.2))
		beam(a+Vector3.UP*1.15,b+Vector3.UP*1.15,Vector2(.10,.11),"vista_gold")
		beam(a-Vector3.UP*.20,b-Vector3.UP*.20,Vector2(.16,.18),"vista_gold")
		for j in range(count):
			var p: Vector3 = a.lerp(b,(j+.5)/count)
			art.batch_box("gorge_balusters",p+Vector3.UP*.55,Vector3(.17,1.1,.17),art.mat("sandstone"))
			if j%3==0:
				lamp(p+Vector3.UP*1.37,.14)
		if occupied and i%3==style%3:
			reader(center-normal*.9+Vector3.UP*.45,atan2(normal.x,normal.z))
			if i%2==0:
				pavilion(center-normal*4+Vector3.UP*.2,4.3)
		if style%4==i%4:
			var quad = QuadMesh.new()
			quad.size = Vector2(2.0,3.3)
			var banner = art.mesh_node(quad,center-Vector3.UP*2.15+normal*.3,art.mat("tapestry_%d" % (style%3)))
			banner.rotation.y = atan2(normal.x,normal.z)

func beam(a: Vector3, b: Vector3, cross_section: Vector2, material: String) -> Node3D:
	var direction: Vector3 = (b-a).normalized()
	var across: Vector3 = direction.cross(Vector3.UP).normalized()
	var up: Vector3 = across.cross(direction).normalized()
	var node = block((a+b)*.5,Vector3(a.distance_to(b),cross_section.x,cross_section.y),material)
	node.basis = Basis(direction,up,across)
	return node

func rotunda(p: Vector3, radius: float, height: float) -> void:
	var polygon = outline(Vector2(p.x,p.z),radius,radius,0,0)
	prism(polygon,p.y,height,art.mat("gorge_pier"))
	for i in range(12):
		var a: float = TAU*i/12
		var normal = Vector3(sin(a),0,cos(a))
		window(p+normal*(radius+.08)+Vector3.UP*(height*.53),Vector2(1.1,height*.53),a)
		fluted_column(p+normal*(radius+.3),.24,height)
	prism(outline(Vector2(p.x,p.z),radius+1,radius+1,0,0),p.y+height,.6,art.mat("exterior_faience"))
	dome(p+Vector3.UP*(height+.6),radius+1.2,radius*.95)
	world.light(p+Vector3(0,height*.55,radius+4),Color("ffce91"),7,25)

func sanctum(p: Vector3) -> void:
	# A wide terraced apse grows out of the rear banks, with a single domed crown.
	for i in range(9):
		var y: float = p.y-44+i*10.5
		var rx: float = 38-i*2.8
		var rz: float = 26-i*1.9
		var polygon = outline(Vector2(p.x,p.z-i*.7),rx,rz,.4,0)
		prism(polygon,y,10.5,art.mat("gorge_pier"))
		facades(polygon,y,10.5,i+2)
		var deck = outline(Vector2(p.x,p.z-i*.7),rx+1.5,rz+1.5,.4,0)
		prism(deck,y+10,.7,art.mat("exterior_faience"))
		ledge_edges(deck,y+10.7,i%2==0,2)
	rotunda(p+Vector3(0,50,-4),9.4,10)
	var quad = QuadMesh.new()
	quad.size = Vector2(7.2,12)
	art.mesh_node(quad,p+Vector3(0,6,18.2),art.mat("gorge_portal"))
	for side in [-1,1]:
		fluted_column(p+Vector3(side*5.1,0,19),.65,15)
		var hanging = QuadMesh.new()
		hanging.size = Vector2(4.3,9)
		art.mesh_node(hanging,p+Vector3(side*12,5,20),art.mat("wing_relief"))
	world.light(p+Vector3(0,9,28),Color("ffd397"),11,47)

func bridge(a: Vector3, b: Vector3, width: float) -> void:
	bridge_count += 1
	var forward = (b-a).normalized()
	var across = forward.cross(Vector3.UP).normalized()
	var up = across.cross(forward).normalized()
	var basis = Basis(forward,up,across)
	var length: float = a.distance_to(b)
	beam(a,b,Vector2(.8,width),"sandstone")
	beam(a-Vector3.UP*.7,b-Vector3.UP*.7,Vector2(.6,width+.2),"exterior_faience")
	for side in [-1,1]:
		beam(a+across*side*width*.5+Vector3.UP*1.15,b+across*side*width*.5+Vector3.UP*1.15,Vector2(.10,.12),"vista_gold")
		for i in range(int(length/2.5)):
			var p: Vector3 = a.lerp(b,(i+.5)/int(length/2.5))+across*side*width*.5
			art.batch_box("gorge_balusters",p+Vector3.UP*.55,Vector3(.17,1.1,.17),art.mat("sandstone"))
			if i%3==0:
				lamp(p+Vector3.UP*1.38,.16)
	for i in range(int(length/9)):
		reader(a.lerp(b,(i+.5)/int(length/9))+Vector3.UP*.45,atan2(forward.x,forward.z))
	var spans: int = maxi(2,int(length/24))
	for i in range(spans):
		var start: Vector3 = a.lerp(b,float(i)/spans)
		var end: Vector3 = a.lerp(b,float(i+1)/spans)
		for side in [-1,1]:
			var spandrel = art.extrude(bridge_spandrel(start.distance_to(end)),.7,art.mat("sandstone"),start+across*side*(width*.5-.35))
			spandrel.basis = basis
		if i>0:
			# Tapered, banded bridge support merges with the lower archive depths.
			var bottom: float = -177
			for part in range(4):
				var h: float = (start.y-bottom)/4
				var polygon = outline(Vector2(start.x,start.z),3.5-part*.45,width*.65-part*.2,i,0)
				prism(polygon,bottom+part*h,h,art.mat("gorge_background"))
				prism(outline(Vector2(start.x,start.z),4.0-part*.45,width*.7-part*.2,i,0),bottom+(part+1)*h-.6,.6,art.mat("exterior_faience"))
	for point in [a,b]:
		var polygon = outline(Vector2(point.x,point.z),4.3,4.3,0,0)
		prism(polygon,point.y-.6,.6,art.mat("exterior_faience"))
		pavilion(point+Vector3(1.5,.15,-2),3.5)

func bridge_spandrel(length: float) -> PackedVector2Array:
	var polygon = PackedVector2Array()
	for j in range(25):
		var t: float = j/24.0
		polygon.append(Vector2(t*length,-12+sin(PI*t)*10.4))
	polygon.append(Vector2(length,-.42))
	polygon.append(Vector2(0,-.42))
	return polygon

func build_enclosure() -> void:
	# A short, bent perimeter is hidden behind merging banks; it is never a
	# kilometre-wide rectangular box. All vertical boundary faces hold collections.
	art.render_layer = 4
	var path = [Vector2(-147,-35),Vector2(-151,-109),Vector2(-141,-189),Vector2(-111,-270),Vector2(-55,-308),Vector2(15,-323),Vector2(82,-309),Vector2(137,-267),Vector2(151,-190),Vector2(149,-106),Vector2(144,-35)]
	for i in range(path.size()-1):
		var a: Vector2 = path[i]
		var b: Vector2 = path[i+1]
		var center: Vector2 = (a+b)*.5
		var dir: Vector2 = (b-a).normalized()
		var inward = Vector3(-dir.y,0,dir.x)
		var wall = block(Vector3(center.x,-50,center.y),Vector3(a.distance_to(b)+2,263,13),"gorge_background")
		wall.rotation.y = -atan2(dir.y,dir.x)
		for row in range(17):
			var y: float = -175+row*15.0+(i%3)*2
			var aa = Vector3(a.x,y,a.y)+inward*7.5
			var bb = Vector3(b.x,y,b.y)+inward*7.5
			beam(aa,bb,Vector2(.55,3.7),"exterior_faience")
			for bay in range(int(a.distance_to(b)/5)):
				var v: Vector2 = a.lerp(b,(bay+.5)/int(a.distance_to(b)/5))
				window(Vector3(v.x,y+5,v.y)+inward*6.6,Vector2(.65,2),atan2(inward.x,inward.z))
	# The cliff beneath the player's balcony is also occupied library.
	block(Vector3(0,-88,-24),Vector3(300,180,9),"gorge_background")
	prism(outline(Vector2(0,-180),150,150,.1,0),-184,8,art.mat("gorge_background"))
	var material = art.mat("cave").duplicate()
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	art.materials["gorge_roof"] = material
	var surface = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var points: Array = []
	var noise = FastNoiseLite.new()
	noise.seed = 31921
	noise.frequency = .03
	for z in range(25):
		var row: Array = []
		for x in range(25):
			var px: float = -158+x*13.2
			var pz: float = -26-z*13
			row.append(Vector3(px,55+21*sqrt(maxf(0,1-pow(px/165,2)))+noise.get_noise_2d(px,pz)*11,pz))
		points.append(row)
	for z in range(24):
		for x in range(24):
			for ij in [Vector2i(x,z),Vector2i(x,z+1),Vector2i(x+1,z),Vector2i(x+1,z),Vector2i(x,z+1),Vector2i(x+1,z+1)]:
				var p: Vector3 = points[ij.y][ij.x]
				surface.set_uv(Vector2(p.x,p.z)*.03)
				surface.add_vertex(p)
	surface.generate_normals()
	art.mesh_node(surface.commit(),Vector3.ZERO,material)
	for i in range(32):
		var x: float = rng.randf_range(-143,143)
		var z: float = rng.randf_range(-70,-307)
		var y: float = 55+21*sqrt(maxf(0,1-pow(x/165,2)))+noise.get_noise_2d(x,z)*11
		var h: float = rng.randf_range(7,20)
		crag(Vector3(x,y-h,z),rng.randf_range(3,7),h,material)
	art.render_layer = 2
	world.light(Vector3(-30,46,-105),Color("8aaab7"),4,82)
	world.light(Vector3(38,49,-216),Color("9fc0cb"),4,100)

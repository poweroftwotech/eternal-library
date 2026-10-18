extends Node3D
## Authored reading garden: physical surfaces, original props and material assets.
const Factory = preload("res://scripts/asset_factory.gd")
const Interaction = preload("res://scripts/interactable.gd")
var art
var fire_light: OmniLight3D
var effects: Array = []
var gatherables: Dictionary = {}
var elapsed: float = 0.0
var hearth = Vector3(-1.3,0,4.4)
var rug_center: Vector3 = Vector3(2.0,.085,4.9)
## [pose, radius, spring, rise, thickness]. Shared by the masonry, surround
## and ivy passes. v0.12: lower springing + higher rise = sharper pointed apex.
var arch_specs: Array = [[Vector3(-1,0,0),3.8,2.6,5.0,.45],[Vector3(8.4,0,0),2.55,2.6,4.1,.42]]
var environment: Environment
var vista
var organic
var atmosphere
var interior_pass
var library_dressing
const Dressing = preload("res://scripts/set_dressing.gd")
const Vista = preload("res://scripts/vista.gd")

func _ready() -> void:
	art = Factory.new(self)
	organic = preload("res://scripts/organic_pass.gd").new(self,art)
	build_lighting()
	build_architecture()
	build_camp()
	build_garden()
	build_archive()
	build_gatherables()
	Dressing.new(self,art).build()
	vista = Vista.new(self,art)
	vista.build()
	library_dressing = preload("res://scripts/library_dressing.gd").new(self,art)
	library_dressing.build()
	interior_pass = preload("res://scripts/interior_pass.gd").new(self,art)
	interior_pass.build()
	preload("res://scripts/benchmark_pass.gd").new(self,art).build()
	preload("res://scripts/camp_composition.gd").new(self,art).build()
	preload("res://scripts/arch_pass.gd").new(self,art).build()
	organic.build()
	preload("res://scripts/planting_pass.gd").new(self,art).build()
	preload("res://scripts/art_direction.gd").new(self,art).build()
	art.merge_static_geometry()
	art.flush_batches()
	atmosphere = preload("res://scripts/atmosphere.gd").new(self)
	atmosphere.build()

func box(pose: Vector3, size: Vector3, material: String = "sandstone", solid: bool = false) -> Node3D:
	return art.box(pose,size,art.mat(material),solid)

func build_lighting() -> void:
	var world_environment = WorldEnvironment.new()
	environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("080f17")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("77949c")
	environment.ambient_light_energy = .30
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_exposure = 1.15
	environment.ssao_enabled = true
	environment.ssao_radius = .6
	environment.ssao_intensity = 1.5
	environment.ssil_enabled = true
	environment.ssil_intensity = .7
	environment.glow_enabled = true
	environment.glow_intensity = .45
	environment.glow_hdr_threshold = 1.5
	environment.fog_enabled = true
	environment.fog_light_color = Color("3d647a")
	environment.fog_light_energy = .5
	environment.fog_density = .0012
	environment.fog_height = -65
	environment.fog_height_density = .015
	environment.volumetric_fog_enabled = true
	environment.volumetric_fog_density = .0011
	environment.volumetric_fog_length = 260
	environment.volumetric_fog_albedo = Color("819aa0")
	environment.volumetric_fog_ambient_inject = .5
	world_environment.environment = environment
	add_child(world_environment)
	var garden_light = SpotLight3D.new()
	garden_light.position = Vector3(-2.9,12.6,-5.1)
	add_child(garden_light)
	garden_light.look_at(Vector3(-3.0,0,-6.0),Vector3.FORWARD)
	garden_light.light_color = Color("e4e8c1")
	garden_light.light_energy = 10.5
	garden_light.spot_range = 28
	garden_light.spot_angle = 38
	garden_light.spot_attenuation = .7
	garden_light.shadow_enabled = true
	garden_light.light_size = 1.25
	garden_light.shadow_blur = 2
	garden_light.light_projector = load("res://assets/textures/dapple.png")
	fire_light = light(hearth+Vector3(0,.24,0),Color("ffad55"),3.0,10,true)
	# Low-energy fills suggest reflected light without flattening the room.
	light(Vector3(-3,1.0,6.0),Color("d09b63"),1.1,7)
	light(hearth+Vector3(0,1.5,1.0),Color("f3bb78"),.45,4.5)   # weak: unshadowed fill washed out fire shadows
	light(Vector3(1,4.4,2.0),Color("a4b4aa"),.7,10)
	light(Vector3(-2,4.0,-7),Color("dfdfbd"),2.8,14)
	light(Vector3(-6,3.5,-7.8),Color("d5c9a0"),1.6,10)
	light(Vector3(1,6,-3.5),Color("bacdc7"),1.4,12)
	light(Vector3(8.2,3,-4.0),Color("74b7c6"),3.0,10)
	light(Vector3(9,.65,-5),Color("41aca4"),1.0,4)

func light(pose: Vector3, color: Color, energy: float, distance: float, shadow: bool = false) -> OmniLight3D:
	var node = OmniLight3D.new()
	node.position = pose
	node.light_color = color
	node.light_energy = energy
	node.omni_range = distance
	node.omni_attenuation = 1.2
	node.shadow_enabled = shadow
	node.shadow_blur = 1.4
	add_child(node)
	return node

func build_architecture() -> void:
	# Ground and enclosing walls form one navigable, compact authored space.
	box(Vector3(2,-.32,-.5),Vector3(24,.4,27),"soil",true)
	box(Vector3(2,-.12,6),Vector3(24,.24,12),"floor_grout",true)
	box(Vector3(-4.55,-.1,-6),Vector3(6.9,.2,12),"floor_grout",true)
	box(Vector3(2.3,-.1,-6),Vector3(5.2,.2,12),"floor_grout",true)
	box(Vector3(9.2,-.07,-5),Vector3(8.6,.14,10),"paving",true)
	box(Vector3(-10.1,7,0),Vector3(.5,16,27),"brick",true)
	box(Vector3(14.1,7,0),Vector3(.5,16,27),"brick",true)
	box(Vector3(2,4.5,12.2),Vector3(24,10,.4),"plaster",true)
	box(Vector3(-6.4,4,-13.2),Vector3(7.2,8,.4),"brick",true)
	box(Vector3(7.4,4,-13.2),Vector3(13.2,8,.4),"brick",true)
	box(Vector3(-1,7.3,-13.2),Vector3(3.6,2,.4),"brick",true)
	arch(Vector3(-1,2.2,-13.2),1.8,1.8,2.2,.22)
	# Main garden opening and a second, colder archive opening in the same wall.
	for spec in arch_specs:
		arch(spec[0],spec[1],spec[2],spec[3],spec[4])
	for data in [[-7.5,5.0],[4.0,2.0],[12.8,2.4]]:
		var x: float = data[0]
		var w: float = data[1]
		# Sandstone piers; arch_pass.gd adds courses and the inset mosaic panel.
		box(Vector3(x,3.8,0),Vector3(w,7.6,1.0),"sandstone",true)
		box(Vector3(x,1.05,.53),Vector3(w,.75,.1),"tile")
		box(Vector3(x,7.5,0),Vector3(w+.15,.24,1.2),"sandstone")
	# Stone joints, plinths and weathered dado give the walls physical relief.
	for x in [-5.0,3.2,5.4,11.3]:
		box(Vector3(x,.3,.03),Vector3(.95,.6,1.3),"sandstone",true)
		for row in range(5):
			box(Vector3(x,.8+row*.45,.12),Vector3(.72,.43,1.02),"sandstone")
	for z in [2.5,7.4,11.5]:
		for x in [-9.5,13.5]:
			box(Vector3(x,4.2,z),Vector3(.5,8.4,.7),"wood")
		box(Vector3(2,8.1,z),Vector3(24,.38,.45),"wood")
	# Shelter roof over the camp, with long gaps near the garden entrance.
	box(Vector3(2,8.35,7.5),Vector3(24,.3,9),"wood")
	for x in [-8,-4,0,4,8,12]:
		box(Vector3(x,8.2,6),Vector3(.18,.38,12),"wood")
	# Back gallery with a real return route and a reachable stair.
	box(Vector3(-1.2,2.0,-11.2),Vector3(12,.4,3.8),"sandstone",true)
	for x in [-6.8,-4.3,-1.8,.7]:
		box(Vector3(x,1,-9.9),Vector3(.36,2,.5),"brick",true)
		box(Vector3(x,2.8,-9.6),Vector3(.11,1.3,.12),"sandstone")
	box(Vector3(-2.9,3.4,-9.6),Vector3(8.2,.14,.2),"sandstone")
	var gallery_guard = StaticBody3D.new()
	gallery_guard.position = Vector3(-2.9,2.8,-9.6)
	var guard_collision = CollisionShape3D.new()
	var guard_shape = BoxShape3D.new()
	guard_shape.size = Vector3(8.2,1.3,.15)
	guard_collision.shape = guard_shape
	gallery_guard.add_child(guard_collision)
	add_child(gallery_guard)
	for x in [-5.5,2.5]:
		art.shelf(Vector3(x,2.2,-12.6),2.3,3.0,PI)
	# Upper stacks imply a larger interior above the reachable gallery.
	box(Vector3(-1.1,12.0,-14.4),Vector3(15,12,.55),"brick")
	for x in [-5.7,-1.1,3.5]:
		art.shelf(Vector3(x,7.6,-13.7),4.4,7.4,PI)
		box(Vector3(x-2.25,11.2,-13.3),Vector3(.25,8,.8),"sandstone")
	box(Vector3(-1.1,7.5,-13.5),Vector3(15,.35,1.2),"sandstone")
	box(Vector3(-1.0,17.0,-7),Vector3(15,.4,16),"brick")
	build_stairs(Vector3(2.5,0,-3.4),1.8,5.9,2.2)
	# A small brick-lined irrigation channel reveals water from the garden.
	for side in [-1,1]:
		for z in range(-11,1):
			box(Vector3(-.9+side*.65,.015,z+.5),Vector3(.2,.22,.96),"sandstone")
	var water_material = ShaderMaterial.new()
	water_material.shader = load("res://shaders/water.gdshader")
	var water_plane = PlaneMesh.new()
	water_plane.size = Vector2(1.1,11.4)
	art.mesh_node(water_plane,Vector3(-.9,-.04,-5.7),water_material)
	drifting_leaves(Vector3(-.9,-.03,-11.1),11.0)
	# Shallow channel: a player can step through it without a swim system.
	box(Vector3(-.9,-.22,-5.7),Vector3(1.1,.1,11.4),"soil",true)
	for z in [-3,-7]:
		box(Vector3(-.9,.09,z),Vector3(1.65,.18,.8),"sandstone",true)

func arch_point(radius: float, spring: float, rise: float, t: float) -> Vector2:
	if rise < radius:
		# Low canopy spans use an ellipse instead of a pointed arc that folds over.
		return Vector2(radius*cos(t*PI*.5),spring+rise*sin(t*PI*.5))
	var center: float = (radius*radius-rise*rise)/(2*radius)
	var circle_radius: float = radius-center
	var angle: float = atan2(rise,-center)*t
	return Vector2(center+circle_radius*cos(angle),spring+circle_radius*sin(angle))

func arch(pose: Vector3, radius: float, spring: float, rise: float, thickness: float) -> void:
	var steps: int = 24
	var top: float = maxf(spring+rise+thickness+.25,8.3 if absf(pose.z)<.01 else 0)
	for side in [-1,1]:
		var outer_curve: Array = []
		for i in range(steps):
			var t0: float = (i+.04)/steps
			var t1: float = (i+.96)/steps
			var a: Vector2 = arch_point(radius,spring,rise,t0)
			var b: Vector2 = arch_point(radius,spring,rise,t1)
			var c: Vector2 = arch_point(radius+thickness,spring,rise+thickness,t1)
			var d: Vector2 = arch_point(radius+thickness,spring,rise+thickness,t0)
			a.x *= side
			b.x *= side
			c.x *= side
			d.x *= side
			var stone = art.extrude(PackedVector2Array([a,b,c,d]),1.1,art.mat("limestone" if pose.z>=-20 else "arch_stone"),pose)
			stone.name = "ArchStone"
		for i in range(steps+1):
			var v: Vector2 = arch_point(radius+thickness,spring,rise+thickness,float(i)/steps)
			v.x *= side
			outer_curve.append(v)
		outer_curve.append(Vector2(0,top))
		outer_curve.append(Vector2(side*(radius+thickness),top))
		art.extrude(PackedVector2Array(outer_curve),.85,art.mat("mosaic"),pose)
		var rows: int = maxi(1,int(ceil(spring/.43)))
		for row in range(rows):
			box(pose+Vector3(side*(radius+thickness*.5),spring*(row+.5)/rows,0),Vector3(thickness,spring/rows-.015,1.1),"limestone" if pose.z>=-20 else "arch_stone")

func build_stairs(start: Vector3, width: float, run: float, rise: float) -> void:
	var count: int = 13
	for i in range(count):
		var h: float = rise*(i+1)/count
		art.worn_block(start+Vector3(0,h*.5,-run*(i+.5)/count),Vector3(width,h,run/count+.01),art.mat("limestone"),.035)
	# A continuous physical ramp avoids first-person snagging on individual risers.
	var collider = CollisionShape3D.new()
	var ramp = ConvexPolygonShape3D.new()
	ramp.points = PackedVector3Array([Vector3(-width/2,-.05,0),Vector3(width/2,-.05,0),Vector3(-width/2,0,0),Vector3(width/2,0,0),Vector3(-width/2,-.05,-run),Vector3(width/2,-.05,-run),Vector3(-width/2,rise,-run),Vector3(width/2,rise,-run)])
	collider.shape = ramp
	var body = StaticBody3D.new()
	add_child(body)
	body.position = start
	body.add_child(collider)
	for side in [-1,1]:
		for i in [0,4,8,12]:
			var y: float = rise*i/count
			box(start+Vector3(side*(width*.5+.07),y+.5,-run*i/count),Vector3(.12,1,.12),"sandstone")
		art.segment(start+Vector3(side*(width*.5+.07),1,0),start+Vector3(side*(width*.5+.07),rise+1,-run),.065,art.mat("sandstone"))

func build_camp() -> void:
	art.shelf(Vector3(-8.4,0,4.1),5.8,6.4,-PI/2)
	art.shelf(Vector3(-8.4,0,9.6),4.6,5.7,-PI/2)
	art.ladder(Vector3(-7.4,0,2.9),5.8,-PI/2)
	# v0.12: jars, bedroll and pack moved to camp_composition.gd (concept layout).
	var rug_mesh = PlaneMesh.new()
	rug_mesh.size = Vector2(4.4,3.2)
	var rug = art.mesh_node(rug_mesh,rug_center,art.mat("rug"))
	rug.rotation.y = -.11
	# Hearth ring: chipped masonry, split fuel and independently lit embers.
	for i in range(12):
		var a: float = i*TAU/12
		if i == 3:
			continue   # open front (concept): the fire faces the camp
		var stone = art.worn_block(hearth+Vector3(cos(a)*.95,.16,sin(a)*.85),Vector3(art.rng.randf_range(.40,.49),art.rng.randf_range(.27,.33),art.rng.randf_range(.34,.42)),art.mat("hearth_stone"),.055,true)
		stone.rotation.y = -a
	# v0.12: authored star-fire logs (tools/build_props.py) replace the box logs.
	art.model("fire_logs",hearth)
	for i in range(18):
		art.sphere(hearth+Vector3(art.rng.randf_range(-.45,.45),.24,art.rng.randf_range(-.36,.36)),Vector3(.1,.07,.12),art.mat("ember"))
	# v0.12: authored cauldron (tools/build_props.py): belly, lip, legs, handles.
	art.model("cauldron",hearth)
	art.model("stew",hearth+Vector3(0,.92,0))
	for i in range(10):
		var angle: float = i*2.4
		art.sphere(hearth+Vector3(cos(angle)*.42,.95,sin(angle)*.42),Vector3(.1,.025,.07),art.mat("root") if i%2 else art.mat("leaf"))
	interaction("pot","Cook",hearth+Vector3(0,.75,0),Vector3(1.45,.9,1.35))
	# A low provision slab: recognisable ingredients and pottery.
	var slab = Vector3(-3.45,.27,5.4)
	art.worn_block(slab,Vector3(2.2,.54,1.4),art.mat("limestone"),.085,true)
	art.bowl(slab+Vector3(-.6,.29,.25),1.25)
	art.bowl(slab+Vector3(.25,.29,.25),1.0)
	for i in range(4):
		art.root_vegetable(slab+Vector3(-.8+i*.13,.6,.20),.6)
	for i in range(3):
		art.mushroom(slab+Vector3(.08+i*.15,.49,.15),.5)
	art.bowl(slab+Vector3(.55,.29,-.4),.7)
	# Wooden ladle, mug and stacked travelling books.
	art.model("ladle",hearth)   # carved ladle leaning on the rim (build_props.py)
	art.cylinder(Vector3(3.9,.14,4.3),.10,.26,art.mat("brass"))
	for i in range(3):
		var book = box(Vector3(-5.6,.08+i*.13,4.4),Vector3(.65,.12,.48),"book")
		book.rotation.y = i*.15
	lantern(Vector3(-3.35,.56,4.8))
	# Sprite effects remain world-space objects, not a painted screenshot backdrop.
	# v0.12: GPU particle flames and rising embers replace the flat flame cards.
	fire_particles(hearth+Vector3(0,.14,-.05),Vector3(.55,.03,.3),40,.6,Vector2(.24,.36),Vector2(.3,.6),Color(.65,.42,.2),Color(.55,.15,.04,0))
	fire_particles(hearth+Vector3(0,.3,0),Vector3(.35,.1,.3),26,2.4,Vector2(.03,.03),Vector2(.35,.8),Color(3.0,1.4,.4),Color(1.2,.25,.05,0),true)
	for i in range(8):
		effect("steam",hearth+Vector3(art.rng.randf_range(-.25,.25),1.15,art.rng.randf_range(-.2,.2)),Vector2(.42,.64),i*.71)

func lantern(pose: Vector3) -> void:
	var metal = art.mat("brass")
	var base = [Vector2(0,0),Vector2(.15,0),Vector2(.18,.025),Vector2(.18,.055),Vector2(.13,.09),Vector2(.11,.12),Vector2(0,.12)]
	art.mesh_node(art.lathe(base,40),pose,metal)
	var cap = [Vector2(0,.46),Vector2(.15,.46),Vector2(.17,.48),Vector2(.13,.51),Vector2(.10,.54),Vector2(.07,.58),Vector2(.065,.61),Vector2(0,.61)]
	art.mesh_node(art.lathe(cap,40),pose,metal)
	var glass = StandardMaterial3D.new()
	glass.albedo_color = Color(.40,.31,.17,.055)
	glass.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = .22
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	var globe = [Vector2(.08,.11),Vector2(.12,.17),Vector2(.13,.30),Vector2(.10,.44),Vector2(.09,.46)]
	art.mesh_node(art.lathe(globe,32),pose,glass)
	for side in [-1,1]:
		art.tube([pose+Vector3(side*.14,.06,0),pose+Vector3(side*.20,.13,0),pose+Vector3(side*.20,.38,0),pose+Vector3(side*.12,.54,0)],[.018,.018,.018,.018],metal,8)
	for y in [.16,.40]:
		var hoop = TorusMesh.new()
		hoop.inner_radius = .125
		hoop.outer_radius = .135
		hoop.rings = 32
		hoop.ring_segments = 6
		art.mesh_node(hoop,pose+Vector3(0,y,0),metal)
	var handle = TorusMesh.new()
	handle.inner_radius = .10
	handle.outer_radius = .112
	handle.rings = 32
	handle.ring_segments = 6
	art.mesh_node(handle,pose+Vector3(0,.69,0),metal).rotation.x = PI/2
	var flame = StandardMaterial3D.new()
	flame.albedo_color = Color("ffe7ab")
	flame.emission_enabled = true
	flame.emission = Color("ffd27d")
	flame.emission_energy_multiplier = 1.2
	art.sphere(pose+Vector3(0,.24,0),Vector3(.055,.17,.055),flame)
	var lamp = light(pose+Vector3(0,.27,0),Color("ffc679"),1.8,4,true)
	lamp.light_size = .12
	lamp.set_meta("lantern",true)

func effect(kind: String, pose: Vector3, size: Vector2, phase: float) -> void:
	var mesh = QuadMesh.new()
	mesh.size = size
	var material = StandardMaterial3D.new()
	material.albedo_texture = load("res://assets/textures/%s.png" % kind)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR if kind=="steam" else BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var node = art.mesh_node(mesh,pose,material)
	node.set_meta("dynamic",true)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	effects.append({"node":node,"kind":kind,"origin":pose,"phase":phase,"material":material})

func build_garden() -> void:
	var tree = Vector3(-4.0,0,-6.2)
	var tree_body = StaticBody3D.new()
	tree_body.position = tree+Vector3(0,1.6,0)
	var tree_collision = CollisionShape3D.new()
	var tree_shape = CylinderShape3D.new()
	tree_shape.radius = .48
	tree_shape.height = 3.2
	tree_collision.shape = tree_shape
	tree_body.add_child(tree_collision)
	add_child(tree_body)
	# Bench and a small still-life make the garden feel previously inhabited.
	box(Vector3(-6.4,.65,-3.3),Vector3(2.5,.18,.7),"wood",true)
	for side in [-1,1]:
		box(Vector3(-6.4+side*.85,.3,-3.3),Vector3(.18,.6,.65),"sandstone",true)
	art.vase(Vector3(-6.8,0,-1.0),.8)
	box(Vector3(-6.0,.79,-3.3),Vector3(.40,.08,.3),"book")


func build_archive() -> void:
	box(Vector3(9.2,7.6,-5.0),Vector3(8.3,.3,10.3),"wood",true)
	box(Vector3(9.2,3.8,-9.9),Vector3(8.3,7.6,.3),"brick",true)
	art.shelf(Vector3(6.0,0,-4.5),7.1,6.5,-PI/2)
	art.shelf(Vector3(12.5,0,-4.5),7.1,6.5,PI/2)
	art.shelf(Vector3(9.2,0,-9.3),5.5,6.5,PI)
	art.ladder(Vector3(11.7,0,-5.2),5.6,PI/2)
	box(Vector3(5.0,4,-6.5),Vector3(.35,8,13),"brick",true)
	# Archive fungi grow from moss mounds and a rotting log (camp_composition.archive_fungi).
	for i in range(10):
		var book = box(Vector3(art.rng.randf_range(7,11),.08,art.rng.randf_range(-8,-3)),Vector3(.35,.10,.52),"book")
		book.rotation.y = art.rng.randf_range(-PI,PI)
	lantern(Vector3(10.7,.15,-7.2))

func build_gatherables() -> void:
	for item in [
		{"id":"herb_a","kind":"herb","position":Vector3(-3.0,.05,-2.8)},
		{"id":"herb_b","kind":"herb","position":Vector3(-5.6,.05,-7.6)},
		{"id":"root_a","kind":"root","position":Vector3(.6,.05,-4.3)},
		{"id":"root_b","kind":"root","position":Vector3(-6.7,.05,-5.0)},
		{"id":"mushroom_a","kind":"mushroom","position":Vector3(8.2,.05,-2.3)},
		{"id":"mushroom_b","kind":"mushroom","position":Vector3(9.8,.05,-6.0)}]:
		var visual = Node3D.new()
		visual.set_meta("dynamic",true)
		add_child(visual)
		visual.position = item.position
		if item.kind == "mushroom":
			for i in range(3):
				art.mushroom(Vector3((i-1)*.25,0,.1*(i%2)),.8,false,visual)
		elif item.kind == "root":
			for i in range(3):
				art.root_vegetable(Vector3((i-1)*.15,.1,0),.65,visual)
			art.sphere(Vector3(0,.2,0),Vector3(.3,.3,.3),art.mat("leaf"),visual)
		else:
			for i in range(7):
				var a: float = i*TAU/7
				art.segment(Vector3.ZERO,Vector3(cos(a)*.2,.35,sin(a)*.2),.012,art.mat("bark"),visual)
				var quad = QuadMesh.new()
				quad.size = Vector2(.16,.35)
				var leaf = art.mesh_node(quad,Vector3(cos(a)*.16,.30,sin(a)*.16),art.mat("leaf"),visual)
				leaf.rotation = Vector3(.2,a,.5)
		var labels: Dictionary = {"root":"Gather amberroot","herb":"Gather hearthleaf","mushroom":"Gather shelf mushrooms"}
		var body = interaction(item.id,labels[item.kind],item.position+Vector3(0,.35,0),Vector3(.85,.7,.85))
		gatherables[item.id] = {"kind":item.kind,"visual":visual,"body":body,"taken":false}

func interaction(id: String, title: String, pose: Vector3, size: Vector3) -> StaticBody3D:
	var body = Interaction.new()
	body.name = id
	body.configure(id,title,size)
	add_child(body)
	body.position = pose
	return body

func harvest(id: String) -> String:
	if not gatherables.has(id) or gatherables[id].taken:
		return ""
	var data: Dictionary = gatherables[id]
	data.taken = true
	data.visual.scale = Vector3.ONE*.16
	data.body.collision_layer = 0
	return data.kind

func _process(delta: float) -> void:
	elapsed += delta
	if atmosphere != null:
		atmosphere.tick(elapsed)
	for effect_data in effects:
		var node: Node3D = effect_data.node
		var phase: float = elapsed + effect_data.phase
		if effect_data.kind == "flame":
			node.scale = Vector3(1+sin(phase*9)*.12,1+sin(phase*13)*.18,1)
			node.position.x = effect_data.origin.x+sin(phase*7)*.035
		else:
			var t: float = fposmod(phase*.35,1.0)
			node.position = effect_data.origin+Vector3((sin(phase*.9)*.22+.18)*t,t*1.5,cos(phase*.7)*.16*t)
			node.scale = Vector3(.6+t*1.5,.65+t*.9,1)
			effect_data.material.albedo_color.a = sin(t*PI)*.30*(1-t*.7)

## Additive billboard particles for the hearth. Flames: short-lived, buoyant,
## shrinking flame.png cards. Embers (sparks = true): tiny, long-lived, turbulent.
func fire_particles(pose: Vector3, extents: Vector3, amount: int, lifetime: float, size: Vector2, speed: Vector2, hot: Color, cool: Color, sparks: bool = false) -> GPUParticles3D:
	var process: ParticleProcessMaterial = ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = extents
	process.direction = Vector3.UP
	process.spread = 25.0 if sparks else 10.0
	process.initial_velocity_min = speed.x
	process.initial_velocity_max = speed.y
	process.gravity = Vector3(0,.4 if sparks else .9,0)
	process.scale_min = .7
	process.scale_max = 1.3
	var shrink: Curve = Curve.new()
	shrink.add_point(Vector2(0,.6 if not sparks else 1.0))
	shrink.add_point(Vector2(.35,1.0))
	shrink.add_point(Vector2(1,0))
	var shrink_texture: CurveTexture = CurveTexture.new()
	shrink_texture.curve = shrink
	process.scale_curve = shrink_texture
	var ramp: Gradient = Gradient.new()
	ramp.set_color(0,hot)
	ramp.set_color(1,cool)
	var ramp_texture: GradientTexture1D = GradientTexture1D.new()
	ramp_texture.gradient = ramp
	process.color_ramp = ramp_texture
	if sparks:
		process.turbulence_enabled = true
		process.turbulence_noise_strength = 1.4
		process.turbulence_noise_scale = 2.0
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.vertex_color_use_as_albedo = true
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	if not sparks:
		material.albedo_texture = load("res://assets/textures/flame.png")
	var quad: QuadMesh = QuadMesh.new()
	quad.size = size
	quad.material = material
	var particles: GPUParticles3D = GPUParticles3D.new()
	particles.amount = amount
	particles.lifetime = lifetime
	particles.preprocess = lifetime*2.0
	particles.process_material = process
	particles.draw_pass_1 = quad
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particles.visibility_aabb = AABB(Vector3(-1,-.3,-1),Vector3(2,2.5,2))
	particles.position = pose
	particles.set_meta("dynamic",true)
	add_child(particles)
	return particles

## A few fallen leaves riding the channel current (matches the shader's flow).
func drifting_leaves(source: Vector3, length: float) -> void:
	var process: ParticleProcessMaterial = ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(.32,0,.05)
	process.direction = Vector3(0,0,1)
	process.spread = 4.0
	process.initial_velocity_min = .18
	process.initial_velocity_max = .26
	process.gravity = Vector3.ZERO
	process.particle_flag_rotate_y = true
	process.angle_min = -180.0
	process.angle_max = 180.0
	process.angular_velocity_min = -12.0
	process.angular_velocity_max = 12.0
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_texture = load("res://assets/textures/px/ivy_leaf.png")
	material.albedo_color = Color(.85,.58,.28)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(.13,.13)
	quad.orientation = PlaneMesh.FACE_Y
	quad.material = material
	var particles: GPUParticles3D = GPUParticles3D.new()
	particles.amount = 9
	particles.lifetime = length/.22
	particles.preprocess = particles.lifetime
	particles.process_material = process
	particles.draw_pass_1 = quad
	particles.local_coords = false
	particles.visibility_aabb = AABB(Vector3(-1,-.2,-.5),Vector3(2,.5,length+1))
	particles.position = source
	particles.set_meta("dynamic",true)
	add_child(particles)

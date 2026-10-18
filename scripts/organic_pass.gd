extends RefCounted
## Individually fractured flagstones and clustered, rooted garden growth.
var world
var art
var rng = RandomNumberGenerator.new()
var paving: StandardMaterial3D
var moss: StandardMaterial3D
var stone_count: int = 0
var planting_count: int = 0

func _init(owner, factory) -> void:
	world = owner
	art = factory
	rng.seed = 90142
	paving = art.mat("floor_stone").duplicate()
	paving.vertex_color_use_as_albedo = true
	paving.normal_scale = .50
	paving.uv1_scale = Vector3.ONE*.75
	moss = art.mat("moss").duplicate()
	moss.vertex_color_use_as_albedo = true
	moss.albedo_color = Color(.68,.75,.48)

func triangle(s: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, tint: Color, desired: Vector3) -> void:
	var normal = (b-a).cross(c-a).normalized()
	if normal.dot(desired)<0:
		normal = -normal
	s.set_color(tint)
	art.add_triangle(s,a,b,c,normal,[Vector2(a.x,a.z),Vector2(b.x,b.z),Vector2(c.x,c.z)])

func fragment(poly: PackedVector2Array, depth: float, tone: Color, tilt: Vector2, hollow: float) -> ArrayMesh:
	# Rings resolve a chipped shoulder, rough fracture sides and a depressed top.
	var surface = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var center = Vector2.ZERO
	for p in poly:
		center += p
	center /= poly.size()
	var low: Array[Vector3] = []
	var shoulder: Array[Vector3] = []
	var top: Array[Vector3] = []
	for p in poly:
		var slope: float = p.dot(tilt)
		var chip: float = rng.randf_range(.018,.055)
		var inset = p.move_toward(center,chip)
		var height: float = rng.randf_range(-.009,.009)
		low.append(Vector3(p.x,-depth,p.y))
		shoulder.append(Vector3(p.x,slope-chip*.65-.012,p.y))
		top.append(Vector3(inset.x,slope+height,inset.y))
	var c = Vector3(center.x,center.dot(tilt)-hollow,center.y)
	for i in range(poly.size()):
		var j: int = (i+1)%poly.size()
		var outward = Vector3((poly[i]+poly[j]).x*.5-center.x,0,(poly[i]+poly[j]).y*.5-center.y).normalized()
		var face_tone = tone.darkened(rng.randf_range(.10,.25))
		triangle(surface,low[i],low[j],shoulder[i],face_tone,outward)
		triangle(surface,low[j],shoulder[j],shoulder[i],face_tone,outward)
		triangle(surface,shoulder[i],shoulder[j],top[i],tone.lightened(.07),outward+Vector3.UP)
		triangle(surface,shoulder[j],top[j],top[i],tone.lightened(.07),outward+Vector3.UP)
		triangle(surface,c,top[i],top[j],tone,Vector3.UP)
		triangle(surface,Vector3(center.x,-depth,center.y),low[j],low[i],face_tone,Vector3.DOWN)
	surface.generate_tangents()
	return surface.commit()

func outline(size: Vector2) -> PackedVector2Array:
	var x: float = size.x*.5
	var z: float = size.y*.5
	var cut: float = minf(x,z)*rng.randf_range(.12,.32)
	# Unequal corners and recessed mid-edge bites break the repeated octagon.
	return PackedVector2Array([
		Vector2(-x+cut,-z+rng.randf_range(0,.025)),Vector2(x-cut*.5,-z),
		Vector2(x,-z+cut*1.2),Vector2(x-rng.randf_range(0,.035),z*.05),
		Vector2(x,z-cut*.65),Vector2(x-cut*1.6,z),
		Vector2(-x+cut*.8,z-rng.randf_range(0,.03)),Vector2(-x,z-cut),
		Vector2(-x+rng.randf_range(.005,.04),-z*.22),Vector2(-x,-z+cut*.6)])

func flagstone(pose: Vector3, size: Vector2, broken: bool = false, solid: bool = true) -> Node3D:
	stone_count += 1
	var node = StaticBody3D.new() if solid else Node3D.new()
	world.add_child(node)
	node.position = pose
	node.name = "WeatheredFlagstone_%d" % stone_count
	var tone = Color.WHITE.darkened(rng.randf_range(.02,.24))
	if stone_count%7==0:
		tone = tone*Color(.90,.96,1.0)
	var tilt = Vector2(rng.randf_range(-.025,.025),rng.randf_range(-.025,.025))
	var poly = outline(size)
	var pieces: Array[PackedVector2Array] = [poly]
	if broken:
		# Two actual solids separated by a jagged crack, not a line painted on top.
		var x: float = size.x*.5
		var z: float = size.y*.5
		var cut: float = size.x*rng.randf_range(-.18,.15)
		var crack = PackedVector2Array()
		for t in [-1.0,-.57,-.13,.34,.72,1.0]:
			crack.append(Vector2(cut+rng.randf_range(-.055,.055)*size.x,t*z))
		var left = PackedVector2Array([poly[0]])
		for v in crack:
			left.append(v-Vector2(.009,0))
		for k in [6,7,8,9]:
			left.append(poly[k])
		var right = PackedVector2Array([crack[0]+Vector2(.009,0),poly[1],poly[2],poly[3],poly[4],poly[5]])
		for k in range(crack.size()-1,0,-1):
			right.append(crack[k]+Vector2(.009,0))
		pieces = [left,right]

	for shape in pieces:
		var mesh = fragment(shape,.18,tone,tilt,rng.randf_range(.006,.025))
		art.mesh_node(mesh,Vector3.ZERO,paving,node)
	# Low, continuous convex collision surface bridges small chips and fracture gaps.
	# It follows the slab tilt without trapping the character capsule in cracks.
	if solid:
		var collider = CollisionShape3D.new()
		var collision = ConvexPolygonShape3D.new()
		var vertices = PackedVector3Array()
		for v in poly:
			vertices.append(Vector3(v.x,v.dot(tilt)-.012,v.y))
			vertices.append(Vector3(v.x,-.18,v.y))
		collision.points = vertices
		collider.shape = collision
		node.add_child(collider)
	return node

func camp_paving() -> void:
	var z: float = -.05
	var row: int = 0
	while z<8.8:
		var length: float = rng.randf_range(.68,1.24)
		var x: float = -7.0-rng.randf_range(0,.45)
		while x<6.2:
			var width: float = rng.randf_range(.65,1.55)
			var p = Vector3(x+width*.5,rng.randf_range(.018,.065),z+length*.5)
			var near_hearth: bool = Vector2(p.x-world.hearth.x,p.z-world.hearth.z).length()<1.22
			var under_rug: bool = absf(p.x-world.rug_center.x)<2.4 and absf(p.z-world.rug_center.z)<1.8
			if under_rug:
				p.y = .024
			if not near_hearth:
				var block = flagstone(p,Vector2(width-.045,length-.045),rng.randf()<.24,not under_rug)
				block.rotation.y = rng.randf_range(-.015,.015)
			x += width
		z += length
		row += 1

func build() -> void:
	garden_paths()
	rock_gardens()
	shelf_life()

func garden_paths() -> void:
	for side in [-1,1]:
		for row in range(10):
			var z: float = -.55-row*.89
			var x: float = (-3.0 if side<0 else .48)+sin(row*1.6)*.13
			var p = Vector3(x,rng.randf_range(.025,.08),z)
			flagstone(p,Vector2(rng.randf_range(.90,1.40),rng.randf_range(.73,.85)),row%3==0)
	# Low broken apron extends through the doorway into the garden.
	for x in [-6.3,-5.2,-4.2,1.7,2.7,3.7]:
		for z in [-.5,-1.4,-2.3]:
			flagstone(Vector3(x,.03+rng.randf()*.025,z),Vector2(.84,.80),rng.randf()<.4)
	# Worn capstones dress the water margins; existing channel collision remains.
	for side in [-1,1]:
		for i in range(18):
			var z: float = -.4-i*.56
			if absf(z+3)<.55 or absf(z+7)<.55:
				continue
			flagstone(Vector3(-.9+side*.67,.135,z),Vector2(.32,.51),i%4==0,false)

func rock_mesh(size: Vector3) -> ArrayMesh:
	var s = SurfaceTool.new()
	s.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array = []
	var sectors: int = 16
	var levels: int = 8
	for j in range(levels+1):
		var ring: Array = []
		var latitude: float = PI*j/levels
		for i in range(sectors):
			var angle: float = TAU*i/sectors
			var wobble: float = rng.randf_range(.87,1.12) if j>0 and j<levels else 1.0
			var v = Vector3(cos(angle)*sin(latitude)*wobble,cos(latitude),sin(angle)*sin(latitude)*wobble)*size*.5
			v.x += sin(latitude*1.8)*size.x*.10
			if j>0 and j<levels:
				v.y += rng.randf_range(-.07,.07)*size.y
			ring.append(v)
		rings.append(ring)
	for j in range(levels):
		for i in range(sectors):
			var k: int = (i+1)%sectors
			var a: Vector3 = rings[j][i]
			var b: Vector3 = rings[j][k]
			var c: Vector3 = rings[j+1][i]
			var d: Vector3 = rings[j+1][k]
			var desired = ((a+b+c+d)*.25/size).normalized()
			var tone = Color(.84,.85,.77).darkened(rng.randf_range(0,.07))
			if j<3 and (i+j)%4!=0:
				tone = tone.lerp(Color(.46,.57,.30),.35)
			if j>0:
				triangle(s,a,b,c,tone,desired)
			if j<levels-1:
				triangle(s,b,d,c,tone,desired)
	s.generate_tangents()
	return s.commit()

func boulder(pose: Vector3, size: Vector3) -> void:
	var mesh = rock_mesh(size)
	var node = art.mesh_node(mesh,pose-Vector3(0,size.y*.48,0),paving)
	node.rotation.y = rng.randf_range(-.65,.65)
	if size.y>.25:
		var body = StaticBody3D.new()
		world.add_child(body)
		body.transform = node.transform
		var c = CollisionShape3D.new()
		c.shape = mesh.create_convex_shape()
		body.add_child(c)

func rock_gardens() -> void:
	var centers = [Vector3(-5.8,.08,-3.8),Vector3(-6.0,.10,-7.6),Vector3(-3.2,.08,-7.8),Vector3(-2.25,.07,-5.8),Vector3(4.25,.06,-2.4),Vector3(4.15,.08,-6.6)]
	for k in range(centers.size()):
		var center: Vector3 = centers[k]
		for i in range(9):
			var a: float = i*2.4+k
			var radius: float = sqrt(float(i)/9)*.9
			var h: float = rng.randf_range(.14,.48)*(1-radius*.4)
			var p = center+Vector3(cos(a)*radius,h,sin(a)*radius*.72)
			boulder(p,Vector3(rng.randf_range(.45,1.03),h+.12,rng.randf_range(.4,.82)))
			cluster(p+Vector3(.18,-h*.75,.1),rng.randf_range(.25,.48),17)
		# Fallen fragments form a diminishing skirt at each outcrop.
		for i in range(12):
			var a: float = i*2.4
			var p = center+Vector3(cos(a)*rng.randf_range(.9,1.35),-.03,sin(a)*rng.randf_range(.8,1.15))
			flagstone(p,Vector2(rng.randf_range(.12,.35),rng.randf_range(.10,.3)),false,false)
			if i%3==0:
				cluster(p+Vector3(0,.055,0),.25,8)
	# Root fingers visibly meet the planted outcrops.
	for i in range(7):
		var a: float = i*TAU/7
		var start = Vector3(-4,.13,-6.2)
		var end = start+Vector3(cos(a)*rng.randf_range(1.6,2.4),-.10,sin(a)*rng.randf_range(1.3,1.9))
		art.tube([start,start.lerp(end,.35)+Vector3(.1,.11,0),start.lerp(end,.75)+Vector3(-.1,.04,.1),end],[.12,.08,.04,.008],art.mat("bark"),8)
	# Narrow tufts live in specific joints, keeping the central lane readable.
	for p in [Vector3(-4.7,.07,.4),Vector3(-3.9,.07,1.25),Vector3(3.25,.07,.7),Vector3(-5.5,.07,2.1),Vector3(.35,.07,-1.8),Vector3(-2.2,.07,-2.5)]:
		cluster(p,.30,17)

func cluster(pose: Vector3, radius: float, count: int) -> void:
	planting_count += 1
	# Layered moss cushions, curved fern fronds, small woody stems and broad leaves.
	var leaf = QuadMesh.new()
	leaf.size = Vector2(.13,.24)
	var frond = load("res://scripts/set_dressing.gd").new(world,art).curved_frond()
	for i in range(count):
		var a: float = i*2.399
		var r: float = radius*sqrt(rng.randf())
		var base = pose+Vector3(cos(a)*r,0,sin(a)*r)
		var height: float = rng.randf_range(.12,.40)
		if i%3==0:
			var scale: float = rng.randf_range(.38,.92)
			art.batch_mesh("clustered_ferns",frond,art.mat("fern"),Transform3D(Basis(Vector3.UP,a).scaled(Vector3.ONE*scale),base),Color(.72,.87,.57))
		else:
			var tip = base+Vector3(cos(a)*height*.6,height,sin(a)*height*.6)
			art.segment(base,tip,.004,art.mat("vine"))
			for side in [-1,1]:
				var basis = Basis.from_euler(Vector3(-.55,a,side*.75)).scaled(Vector3.ONE*rng.randf_range(.65,1.2))
				art.batch_mesh("garden_shrub_leaves",leaf,art.mat("ivy_leaf"),Transform3D(basis,base.lerp(tip,.65)+Vector3(side*.04,0,0)),Color(.73,.88,.55))
			art.batch_mesh("garden_shrub_tips",leaf,art.mat("tree_leaf"),Transform3D(Basis.from_euler(Vector3(-.8,a,.3)),tip),Color(.85,.93,.63))

func shelf_life() -> void:
	# Distinct still-life clusters interrupt the large front collection wall.
	for p in [Vector3(-6.7,0,1.1),Vector3(-7.35,0,3.0),Vector3(11.4,0,-7.5)]:
		art.lying_books(p,5,rng.randf_range(-.4,.4))
		art.vase(p+Vector3(.50,0,.2),.32)
	art.ladder(Vector3(-6.45,0,1.2),5.3,PI)
	for p in [Vector3(-5.3,1.3,.85),Vector3(3.6,1.1,.9),Vector3(-7.4,.7,-3.4)]:
		cluster(p,.25,12)
	# Short, irregular trailing growth breaks up the rear book wall and gallery edge.
	var ivy = QuadMesh.new()
	ivy.size = Vector2(.15,.22)
	for anchor in [Vector3(-6.5,6.7,-12.2),Vector3(-3.5,6.0,-12.2),Vector3(1.0,6.5,-12.2),Vector3(-5.8,3.4,-9.4),Vector3(-2.4,3.4,-9.4)]:
		for strand in range(4):
			var path: Array = []
			var radii: Array = []
			var length: float = rng.randf_range(.65,1.9)
			for j in range(13):
				var t: float = j/12.0
				var pos = anchor+Vector3((strand-1.5)*.17+sin(t*4+strand)*.15,-t*length,.12+sin(t*PI)*.18)
				path.append(pos)
				radii.append(.007)
				for side in [-1,1]:
					var basis = Basis.from_euler(Vector3(rng.randf_range(-.5,.3),rng.randf_range(-.4,.4),side*.6)).scaled(Vector3.ONE*rng.randf_range(.7,1.3))
					art.batch_mesh("gallery_trailing_ivy",ivy,art.mat("ivy_leaf"),Transform3D(basis,pos+Vector3(side*.08,0,.02)),Color(.71,.83,.49))
			art.tube(path,radii,art.mat("vine"),5)

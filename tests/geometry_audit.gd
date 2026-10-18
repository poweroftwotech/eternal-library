extends SceneTree
## Checks actual triangle winding against normals, including both extrusion windings.
var failures: Array[String] = []
var checks: int = 0
var triangles: int = 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		push_error(message)

func facing_is_consistent(mesh: Mesh) -> bool:
	var okay: bool = true
	for surface in range(mesh.get_surface_count()):
		var a = mesh.surface_get_arrays(surface)
		var v = a[Mesh.ARRAY_VERTEX]
		var n = a[Mesh.ARRAY_NORMAL]
		var indices = a[Mesh.ARRAY_INDEX]
		var count: int = indices.size() if indices != null and indices.size()>0 else v.size()
		for i in range(0,count,3):
			var k = [indices[i],indices[i+1],indices[i+2]] if indices != null and indices.size()>0 else [i,i+1,i+2]
			var face: Vector3 = -(v[k[1]]-v[k[0]]).cross(v[k[2]]-v[k[0]])
			if face.length_squared()<.00000001:
				continue
			triangles += 1
			var supplied: Vector3 = (n[k[0]]+n[k[1]]+n[k[2]]).normalized()
			if face.normalized().dot(supplied)<.5:
				okay = false
	return okay

func _initialize() -> void:
	call_deferred("audit")

func audit() -> void:
	var stage = Node3D.new()
	root.add_child(stage)
	var art = load("res://scripts/asset_factory.gd").new(stage)
	var polygon = PackedVector2Array([Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)])
	for order in range(2):
		var node = art.extrude(polygon,1,art.mat("arch_stone"),Vector3.ZERO)
		check(facing_is_consistent(node.mesh),"Extrusion winding agrees with outward normals, order %d" % order)
		var a = node.mesh.surface_get_arrays(0)
		var caps_ok: bool = true
		for i in range(a[Mesh.ARRAY_VERTEX].size()):
			var n: Vector3 = a[Mesh.ARRAY_NORMAL][i]
			var p: Vector3 = a[Mesh.ARRAY_VERTEX][i]
			if absf(n.z)>.9 and n.z*p.z<0:
				caps_ok = false
		check(caps_ok,"Both extrusion caps point out of the solid, order %d" % order)
		polygon.reverse()
	check(facing_is_consistent(art.lathe([Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(.8,1.1),Vector2(.7,.2),Vector2(0,.2)],24)),"Hollow lathe winding agrees with inner and outer normals")
	check(facing_is_consistent(art.tube([Vector3.ZERO,Vector3(.2,1,0),Vector3(.3,2,.2)],[.4,.3,.1],art.mat("bark")).mesh),"Branch tube winding agrees with its supplied normals")
	var box = art.bevel_box(Vector3.ZERO,Vector3(1,.3,1),art.mat("stone_surface"))
	check(facing_is_consistent(box.get_child(0).mesh),"Beveled pavers have outward faces and normals")
	var worn = art.worn_block(Vector3.ZERO,Vector3(1,.16,.8),art.mat("floor_stone"),.035)
	check(facing_is_consistent(worn.get_child(0).mesh),"Worn stones have consistent cut corners, chamfers and cap normals")
	var organic = load("res://scripts/organic_pass.gd").new(stage,art)
	var stones_ok: bool = true
	var collision_ok: bool = true
	var fractures_ok: bool = true
	var relief_ok: bool = true
	for i in range(18):
		var fractured: bool = i%2==0
		var stone = organic.flagstone(Vector3.ZERO,Vector2(.6+i*.05,.7+(i%4)*.12),fractured)
		var pieces: int = 0
		var collisions: int = 0
		var low_top: float = 100
		var high_top: float = -100
		for child in stone.get_children():
			if child is MeshInstance3D:
				pieces += 1
				stones_ok = facing_is_consistent(child.mesh) and stones_ok
				var arrays = child.mesh.surface_get_arrays(0)
				for v in arrays[Mesh.ARRAY_VERTEX]:
					if v.y>-.10:
						low_top = minf(low_top,v.y)
						high_top = maxf(high_top,v.y)
			elif child is CollisionShape3D:
				collisions += 1
				collision_ok = collision_ok and child.shape is ConvexPolygonShape3D
		fractures_ok = fractures_ok and pieces==(2 if fractured else 1)
		collision_ok = collision_ok and collisions==1
		relief_ok = relief_ok and high_top-low_top>.015
	check(facing_is_consistent(organic.rock_mesh(Vector3(1.1,.55,.85))),"Irregular garden rocks have outward faces and consistent normals")
	check(stones_ok,"Varied fractured slabs have consistent top, shoulder, side and bottom normals")
	check(fractures_ok,"Fractured paving is two separate mesh pieces")
	check(collision_ok,"Paving has one continuous convex collision surface across cracks")
	check(relief_ok,"Every sampled flagstone has non-flat sculpted relief")
	var dressing = load("res://scripts/set_dressing.gd").new(stage,art)
	check(facing_is_consistent(dressing.curved_frond()),"Curved frond normals follow the leaf bend")
	# Exercise the actual instance builder with a side-facing shelf book.
	art.book_instance(Vector3.ZERO,Vector3(.14,.60,.44),Color.WHITE,Basis(Vector3.UP,PI*.5))
	var paper: Transform3D = art.batches.book_pages.instances.back().transform
	check(absf(paper.basis.x.length()-.012)<.0001 and absf(paper.basis.z.length()-.44*.79)<.0001,"Side-facing book paper retains its local thickness and depth")
	var vista = load("res://scripts/vista.gd").new(stage,art)
	vista.exterior_materials()
	vista.window(Vector3.ZERO,Vector2(2,5),PI*.5)
	var side_window: Transform3D = art.batches.vista_windows.instances.back().transform
	check(absf(side_window.basis.x.length()-2)<.0001 and absf(side_window.basis.y.length()-5)<.0001 and absf(side_window.basis.z.length()-1)<.0001,"Side-facing exterior windows preserve local width, height and depth")
	check(absf(side_window.basis.x.x)<.0001 and absf(side_window.basis.z.z)<.0001,"Exterior window orientation follows the facade rotation")
	for pointed in [false,true]:
		var bay: PackedVector2Array = vista.arch_bay(11,19,1.2,pointed)
		var ok: bool = Geometry2D.triangulate_polygon(bay).size()==(bay.size()-2)*3
		check(ok and facing_is_consistent(art.extrude(bay,2.5,art.mat("sandstone"),Vector3.ZERO).mesh),"%s arch bays triangulate and keep outward faces and arch-reveal normals" % ("Pointed portal" if pointed else "Round aqueduct"))
	var niche = art.extrude(vista.arcade_outline(),.43,art.mat("sandstone"),Vector3.ZERO)
	check(facing_is_consistent(niche.mesh),"Book arcade frames have outward front, back and arch-reveal normals")
	var footprint: PackedVector2Array = vista.outline(Vector2(2,-60),23,31,.7,.17)
	check(Geometry2D.triangulate_polygon(footprint).size()==30,"Irregular twelve-sided terrace footprint triangulates without self-intersections")
	var tier = vista.prism(footprint,-10,9,art.mat("sandstone"))
	check(facing_is_consistent(tier.mesh),"Faceted bank prisms retain outward cap and wall normals")
	check(absf(tier.transform.basis.z.y+1)<.001,"Horizontal terrace caps are rotated onto the vertical building axis")
	var stepped: PackedVector2Array = vista.tower_outline(Vector2(2,-60),23,31,.17)
	check(Geometry2D.triangulate_polygon(stepped).size()==30 and Geometry2D.is_polygon_clockwise(stepped)==Geometry2D.is_polygon_clockwise(footprint),"Notched tower footprint triangulates and winds like the terrace outline")
	check(facing_is_consistent(vista.prism(stepped,-10,9,art.mat("sandstone")).mesh),"Notched tower prisms keep outward cap and wall normals")
	var builder = load("res://scripts/world.gd").new()
	builder.art = art
	for data in [[3.8,3.0,4.5,.45],[2.55,3.0,3.65,.42],[1.8,1.8,2.1,.22],[5.7,3.0,2.7,.26]]:
		var previous = Vector2(data[0],data[1])
		var monotonic: bool = true
		for i in range(1,101):
			var point: Vector2 = builder.arch_point(data[0],data[1],data[2],i/100.0)
			if point.x>previous.x+.0001 or point.y<previous.y-.0001:
				monotonic = false
			previous = point
		check(monotonic and absf(previous.x)<.001,"Arch curve rises to its apex without folding, radius %s" % data[0])
		builder.arch(Vector3.ZERO,data[0],data[1],data[2],data[3])
	var arches_ok: bool = true
	for node in stage.get_children():
		if node is MeshInstance3D and str(node.name).begins_with("ArchStone"):
			arches_ok = facing_is_consistent(node.mesh) and arches_ok
	check(arches_ok,"All generated arch stones have consistent front, back, and reveal faces")
	check(art.mat("arch_stone").cull_mode==BaseMaterial3D.CULL_BACK,"Arch correctness uses back-face culling")
	art.box(Vector3.ZERO,Vector3.ONE,art.mat("sandstone"))
	art.render_layer = 2
	art.box(Vector3(3,0,0),Vector3.ONE,art.mat("sandstone"))
	art.render_layer = 1
	art.merge_static_geometry()
	var layers: Array = []
	for node in stage.get_children():
		if node is MeshInstance3D and str(node.name).begins_with("MergedStatic_") and node.material_override==art.mat("sandstone"):
			layers.append(node.layers)
	check(layers.has(1) and layers.has(2),"Merging retains separate light layers for the same material")
	builder.free()
	stage.free()
	if failures.is_empty():
		print("PASS: %d geometry checks; %d nondegenerate triangles audited." % [checks,triangles])
		quit(0)
	else:
		print("FAIL: ",failures)
		quit(1)

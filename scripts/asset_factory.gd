extends RefCounted
## Original reusable geometry and textured materials. Coordinates are in metres.
var root: Node3D
var rng = RandomNumberGenerator.new()
var materials: Dictionary = {}
var batches: Dictionary = {}
var unit_box = BoxMesh.new()
var batch_count: int = 0
# Allows exterior bounce lighting without changing the interior.
var render_layer: int = 1
var bevel_meshes: Dictionary = {}
## v0.11 art direction: pixel-art maps from tools/pixel_materials.py replace the
## legacy maps when present. Set false to compare against the v0.10 look.
const USE_PIXEL_MATERIALS: bool = true
const PX_DIR: String = "res://assets/textures/px/"
var px_manifest: Dictionary = {}
var texel_density: float = 32.0

func _init(parent: Node3D) -> void:
	root = parent
	rng.seed = 7331
	unit_box.size = Vector3.ONE
	if USE_PIXEL_MATERIALS and FileAccess.file_exists(PX_DIR+"manifest.json"):
		var data = JSON.parse_string(FileAccess.get_file_as_string(PX_DIR+"manifest.json"))
		if data is Dictionary:
			px_manifest = data.get("materials",{})
			texel_density = float(data.get("texel_density",32))
		# Part 2 (tools/pixel_materials_ext.gd): props, fabrics, books, foliage.
		if FileAccess.file_exists(PX_DIR+"manifest_ext.json"):
			var ext = JSON.parse_string(FileAccess.get_file_as_string(PX_DIR+"manifest_ext.json"))
			if ext is Dictionary:
				px_manifest.merge(ext.get("materials",{}),true)

func mat(name: String) -> StandardMaterial3D:
	if materials.has(name):
		return materials[name]
	if name == "cauldron_iron":
		# Concept pot: dark hammered iron with crisp highlights, not firelit brown.
		var iron: StandardMaterial3D = mat("iron_cook").duplicate()
		iron.albedo_color = Color(.36,.35,.34)
		iron.metallic = .6
		iron.roughness = .7
		materials[name] = iron
		return iron
	var result = StandardMaterial3D.new()
	result.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	result.roughness = 1.0
	result.metallic_specular = .65
	if ResourceLoader.exists("res://assets/textures/%s.png" % name):
		result.albedo_texture = load("res://assets/textures/%s.png" % name)
		if ResourceLoader.exists("res://assets/textures/%s_normal.png" % name):
			result.normal_enabled = true
			result.normal_texture = load("res://assets/textures/%s_normal.png" % name)
			result.normal_scale = .75
			result.roughness_texture = load("res://assets/textures/%s_rough.png" % name)
			result.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	if name in ["sandstone", "brick", "plaster", "paving", "wood", "bark", "soil", "tile", "stone_surface", "cave", "moss", "vine", "cloth", "arch_stone", "mosaic", "stack_atlas", "library_facade", "floor_stone", "limestone", "hearth_stone", "vault_plaster", "floor_grout"]:
		result.uv1_triplanar = true
		result.uv1_world_triplanar = true
		var scale: float = {"sandstone": 0.52, "brick": 0.65, "plaster": 0.65, "paving": 0.4,
			"wood": 0.55, "bark": 0.7, "soil": 0.85, "tile": 0.55}.get(name,.7)
		result.uv1_scale = Vector3.ONE * scale
	if name in ["floor_stone","limestone","hearth_stone","vault_plaster","floor_grout"]:
		result.uv1_scale = Vector3.ONE*.85
	if name == "iron_cook":
		result.metallic = .32
		result.roughness = 1.0
	if name in ["glazed_ceramic","earthenware"]:
		result.roughness = 1.0
	if name == "book_gilt":
		result.albedo_color = Color("b38a4d")
		result.metallic = .30
		result.roughness = .64
	if name == "book_leather":
		result.vertex_color_use_as_albedo = true
	if name == "earth_patch":
		result.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		result.cull_mode = BaseMaterial3D.CULL_DISABLED
		result.roughness = 1.0
	if name == "stack_atlas":
		result.uv1_scale = Vector3.ONE*.17
	if name == "library_facade":
		result.uv1_scale = Vector3.ONE/20.0
		result.emission_enabled = true
		result.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
		result.emission_texture = load("res://assets/textures/library_facade_emission.png")
		result.emission = Color("e8b774")
		result.emission_energy_multiplier = 1.0
	if name == "mosaic":
		result.roughness = .75
		result.metallic = .18
	if name == "iron":
		result.albedo_color = Color(.75,.78,.80)
		result.metallic = 0.30
		result.roughness = .73
	if name in ["book", "pages", "leaf", "grass", "ivy_leaf", "tree_leaf", "fern"]:
		result.vertex_color_use_as_albedo = true
	if name in ["leaf", "grass", "ivy_leaf", "tree_leaf", "fern"]:
		result.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		result.alpha_scissor_threshold = 0.45
		result.cull_mode = BaseMaterial3D.CULL_DISABLED
		result.roughness = 1.0
		result.albedo_color = Color(.65,.73,.61)
		result.backlight_enabled = true
		result.backlight = Color(0.025, 0.035, 0.01)
		if name in ["ivy_leaf", "tree_leaf", "fern"]:
			result.albedo_color = Color(.9,.94,.88)
			result.backlight = Color(.13,.17,.06)
	if name in ["fruit_skin", "pomegranate", "cut_fruit"]:
		result.roughness = 1.0
	if name == "copper":
		result.metallic = .65
		result.roughness = .6
	if name == "cave":
		result.uv1_scale = Vector3.ONE*.025
	if name == "lit_window":
		result.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		result.cull_mode = BaseMaterial3D.CULL_DISABLED
		result.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		result.emission_enabled = true
		result.emission_texture = result.albedo_texture
		result.emission = Color(1,.8,.5)
		result.emission_energy_multiplier = .12
		result.vertex_color_use_as_albedo = true
	if name == "tile":
		result.roughness = .72
		result.metallic = .18
	if name == "brass":
		result.albedo_color = Color("987145")
		result.metallic = 0.7
		result.roughness = 0.43
	if name == "linen":
		result.albedo_color = Color("8e8061")
		result.albedo_texture = load("res://assets/textures/rug.png")
	if name == "soup":
		result.albedo_color = Color("885627")
		result.roughness = 0.2
	if name == "glow":
		result.albedo_color = Color("53aaa4")
		result.emission_enabled = true
		result.emission = Color("1c797d")
		result.emission_energy_multiplier = .65
	if name == "ember":
		result.albedo_color = Color("b85114")
		result.emission_enabled = true
		result.emission = Color("dc5814")
		result.emission_energy_multiplier = 1.5
	apply_pixel_maps(result,name)
	materials[name] = result
	return result

## Uniform-texel-density pixel maps (ART_DIRECTION.md, rule 1). World-mapped
## materials get uv1_scale = density / tile size; the scale is stored as meta so
## art_direction.gd can restore it on duplicated materials that overrode it.
func apply_pixel_maps(result: StandardMaterial3D, name: String) -> void:
	if not px_manifest.has(name):
		return
	var info: Dictionary = px_manifest[name]
	result.albedo_texture = load(PX_DIR+name+".png")
	if info.get("mapping","world") == "card":
		# Foliage alpha cards keep their tint, alpha scissor and backlight; only
		# the map and filtering change. Cards are about 64 texels/m (documented exception).
		result.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS_ANISOTROPIC
		return
	result.albedo_color = Color.WHITE
	result.roughness = 1.0
	result.roughness_texture = load(PX_DIR+name+"_rough.png")
	result.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	result.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS_ANISOTROPIC
	if info.get("mapping","world") == "world":
		var size: Array = info.get("size",[32,32])
		var scale = Vector3(texel_density/float(size[0]),texel_density/float(size[1]),texel_density/float(size[0]))
		result.uv1_triplanar = true
		result.uv1_world_triplanar = true
		result.uv1_scale = scale
		result.set_meta("px_scale",scale)
		result.normal_enabled = true
		result.normal_texture = load(PX_DIR+name+"_normal.png")
		result.normal_scale = .55
	else:
		# Lathe/plane UVs: authored at roughly 32 texels/m. These meshes have no
		# tangents, so normal mapping stays off.
		result.uv1_triplanar = false
		result.uv1_world_triplanar = false
		result.uv1_scale = Vector3.ONE
		result.normal_enabled = false

func box(pose: Vector3, size: Vector3, material: Material, solid: bool = false, parent: Node3D = null) -> Node3D:
	var node: Node3D = StaticBody3D.new() if solid else Node3D.new()
	(root if parent == null else parent).add_child(node)
	node.position = pose
	var mesh = MeshInstance3D.new()
	mesh.mesh = unit_box
	mesh.layers = render_layer
	mesh.scale = size
	mesh.material_override = material
	# Only hairline trims skip shadows; props need them to sit on the floor.
	if not solid and size.length() < .08:
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(mesh)
	if solid:
		var collider = CollisionShape3D.new()
		var shape = BoxShape3D.new()
		shape.size = size
		collider.shape = shape
		node.add_child(collider)
	return node

func bevel_box(pose: Vector3, size: Vector3, material: Material, bevel: float = .035, solid: bool = false, parent: Node3D = null) -> Node3D:
	var node: Node3D = StaticBody3D.new() if solid else Node3D.new()
	(root if parent == null else parent).add_child(node)
	node.position = pose
	var key: String = str(size)+str(bevel)
	if not bevel_meshes.has(key):
		var surface = SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		var half: Vector3 = size*.5
		var inset: float = minf(bevel,minf(half.x,minf(half.y,half.z))*.7)
		for axis in range(3):
			var u: int = (axis+1)%3
			var v: int = (axis+2)%3
			for side in [-1,1]:
				var us = [-half[u],-half[u]+inset,half[u]-inset,half[u]]
				var vs = [-half[v],-half[v]+inset,half[v]-inset,half[v]]
				for a in range(3):
					for b in range(3):
						var order = [Vector2i(a,b),Vector2i(a+1,b),Vector2i(a,b+1),Vector2i(a+1,b),Vector2i(a+1,b+1),Vector2i(a,b+1)]
						if side == 1:
							order.reverse()
						for ij in order:
							var p = Vector3.ZERO
							p[axis] = side*half[axis]
							p[u] = us[ij.x]
							p[v] = vs[ij.y]
							var inside = p.clamp(-half+Vector3.ONE*inset,half-Vector3.ONE*inset)
							var normal = (p-inside).normalized()
							surface.set_normal(normal)
							surface.set_uv(Vector2(float(ij.x)/3,float(ij.y)/3))
							surface.add_vertex(inside+normal*inset)
		bevel_meshes[key] = surface.commit()
	var visual = mesh_node(bevel_meshes[key],Vector3.ZERO,material,node)
	if solid:
		var collider = CollisionShape3D.new()
		var shape = BoxShape3D.new()
		shape.size = size
		collider.shape = shape
		node.add_child(collider)
	return node

func worn_block(pose: Vector3, size: Vector3, material: Material, bevel: float = .045, solid: bool = false) -> Node3D:
	var node: Node3D = StaticBody3D.new() if solid else Node3D.new()
	root.add_child(node)
	node.position = pose
	var h: Vector3 = size*.5
	bevel = minf(bevel,h.y*.6)
	var cut: float = minf(size.x,size.z)*rng.randf_range(.10,.19)
	var outline = [Vector2(-h.x+cut,-h.z),Vector2(h.x-cut*.8,-h.z),Vector2(h.x,-h.z+cut),Vector2(h.x,h.z-cut*.7),Vector2(h.x-cut,h.z),Vector2(-h.x+cut*.8,h.z),Vector2(-h.x,h.z-cut),Vector2(-h.x,-h.z+cut*.75)]
	var rings: Array = []
	for level in range(4):
		var ring: Array = []
		var inset: float = bevel if level in [0,3] else 0.0
		var y: float = [h.y,h.y-bevel,-h.y+bevel,-h.y][level]
		for v in outline:
			var p = Vector3(v.x,y,v.y)
			p.x = move_toward(p.x,0,inset)
			p.z = move_toward(p.z,0,inset)
			ring.append(p)
		rings.append(ring)
	var surface = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(8):
		var j: int = (i+1)%8
		for cap in [0,3]:
			var a: Vector3 = rings[cap][i]
			var b: Vector3 = rings[cap][j]
			add_triangle(surface,Vector3(0,a.y,0),a,b,Vector3.UP if cap==0 else Vector3.DOWN,[Vector2.ZERO,Vector2(a.x,a.z),Vector2(b.x,b.z)])
		for level in range(3):
			var a: Vector3 = rings[level][i]
			var b: Vector3 = rings[level][j]
			var c: Vector3 = rings[level+1][i]
			var d: Vector3 = rings[level+1][j]
			var outward = Vector3((a.x+b.x)*.5,0,(a.z+b.z)*.5).normalized()
			if level==0:
				outward = (outward+Vector3.UP).normalized()
			elif level==2:
				outward = (outward+Vector3.DOWN).normalized()
			add_triangle(surface,a,b,c,outward,[Vector2(a.x,a.z),Vector2(b.x,b.z),Vector2(c.x,c.z)])
			add_triangle(surface,b,d,c,outward,[Vector2(b.x,b.z),Vector2(d.x,d.z),Vector2(c.x,c.z)])
	mesh_node(surface.commit(),Vector3.ZERO,material,node)
	if solid:
		var collision = CollisionShape3D.new()
		var shape = BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		node.add_child(collision)
	return node

func tube(points: Array, radii: Array, material: Material, sides: int = 12) -> MeshInstance3D:
	var surface = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(points.size()-1):
		for j in range(sides):
			for ij in [Vector2i(i,j),Vector2i(i,j+1),Vector2i(i+1,j),Vector2i(i,j+1),Vector2i(i+1,j+1),Vector2i(i+1,j)]:
				var index: int = ij.x
				var tangent: Vector3 = (points[mini(index+1,points.size()-1)]-points[maxi(index-1,0)]).normalized()
				var ref = Vector3.FORWARD if absf(tangent.dot(Vector3.UP))>.9 else Vector3.UP
				var u = tangent.cross(ref).normalized()
				var v = u.cross(tangent).normalized()
				var a: float = TAU*ij.y/sides
				var normal = u*cos(a)+v*sin(a)
				surface.set_normal(normal)
				surface.set_uv(Vector2(float(ij.y)/sides,float(index)/2))
				surface.add_vertex(points[index]+normal*float(radii[index]))
	return mesh_node(surface.commit(),Vector3.ZERO,material)

func batch_box(key: String, pose: Vector3, size: Vector3, material: Material, yaw: float = 0.0, color: Color = Color.WHITE) -> void:
	var basis = Basis(Vector3.UP,yaw)*Basis.from_scale(size)
	batch_mesh(key, unit_box, material, Transform3D(basis, pose), color)

func batch_mesh(key: String, mesh: Mesh, material: Material, transform: Transform3D, color: Color = Color.WHITE) -> void:
	if not batches.has(key):
		batches[key] = {"mesh": mesh, "material": material, "instances": [], "layers": render_layer}
	batches[key].instances.append({"transform": transform, "color": color})

func flush_batches() -> void:
	for key in batches:
		var data: Dictionary = batches[key]
		var multi = MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.use_colors = true
		multi.mesh = data.mesh
		multi.instance_count = data.instances.size()
		for i in range(data.instances.size()):
			multi.set_instance_transform(i, data.instances[i].transform)
			multi.set_instance_color(i, data.instances[i].color)
		var instance = MultiMeshInstance3D.new()
		instance.name = "Instances_" + key
		instance.multimesh = multi
		instance.material_override = data.material
		instance.layers = data.layers
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if key.contains("windows") or key in ["grass", "leaves", "ivy", "book_pages"] else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		root.add_child(instance)
		batch_count += data.instances.size()
	batches.clear()

func merge_static_geometry() -> void:
	# Merge static geometry by material; collision and dynamic props remain intact.
	var groups: Dictionary = {}
	for node in root.find_children("*","MeshInstance3D",true,false):
		if node.mesh == null or node.material_override is ShaderMaterial:
			continue
		var ancestor = node
		var dynamic: bool = false
		while ancestor != root and ancestor != null:
			if ancestor.has_meta("dynamic"):
				dynamic = true
				break
			ancestor = ancestor.get_parent()
		if dynamic:
			continue
		var key: String = "%s_%s_%s" % [node.material_override.get_instance_id(),node.cast_shadow,node.layers]
		if not groups.has(key):
			var surface = SurfaceTool.new()
			surface.begin(Mesh.PRIMITIVE_TRIANGLES)
			groups[key] = {"surface":surface,"material":node.material_override,"shadow":node.cast_shadow,"layers":node.layers}
		for index in range(node.mesh.get_surface_count()):
			# Standardize indexed and unindexed source meshes before combining them.
			var source = SurfaceTool.new()
			source.create_from(node.mesh,index)
			source.index()
			groups[key].surface.append_from(source.commit(),0,root.global_transform.affine_inverse()*node.global_transform)
		node.visible = false
	for key in groups:
		var data: Dictionary = groups[key]
		data.surface.generate_tangents()
		var node = mesh_node(data.surface.commit(),Vector3.ZERO,data.material)
		node.name = "MergedStatic_"+key
		node.cast_shadow = data.shadow
		node.layers = data.layers

func mesh_node(mesh: Mesh, pose: Vector3, material: Material, parent: Node3D = null) -> MeshInstance3D:
	var node = MeshInstance3D.new()
	node.mesh = mesh
	node.layers = render_layer
	node.material_override = material
	(root if parent == null else parent).add_child(node)
	node.position = pose
	return node

## Authored glTF prop (tools/build_props.py). Each surface becomes its own
## node using the pixel material named by the Blender material, so props keep
## 32 texels/m and merge with the rest of the static geometry.
func model(model_name: String, pose: Vector3, yaw: float = 0.0, parent: Node3D = null) -> Node3D:
	var group: Node3D = Node3D.new()
	(root if parent == null else parent).add_child(group)
	group.position = pose
	group.rotation.y = yaw
	var scene: Node = load("res://assets/models/%s.glb" % model_name).instantiate()
	for source in scene.find_children("*","MeshInstance3D",true,false):
		var mesh: Mesh = source.mesh
		for i in range(mesh.get_surface_count()):
			var single: ArrayMesh = ArrayMesh.new()
			single.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,mesh.surface_get_arrays(i))
			var surface_material: Material = mesh.surface_get_material(i)
			var node: MeshInstance3D = mesh_node(single,Vector3.ZERO,mat(surface_material.resource_name if surface_material else "wood"),group)
			node.transform = source.transform
	scene.free()
	return group

func sphere(pose: Vector3, size: Vector3, material: Material, parent: Node3D = null) -> MeshInstance3D:
	var mesh = SphereMesh.new()
	mesh.radial_segments = 24
	mesh.rings = 12
	var node = mesh_node(mesh, pose, material, parent)
	node.scale = size
	return node

func cylinder(pose: Vector3, radius: float, height: float, material: Material, parent: Node3D = null, top: float = -1) -> MeshInstance3D:
	var mesh = CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius if top < 0 else top
	mesh.height = height
	mesh.radial_segments = 32
	return mesh_node(mesh, pose, material, parent)

func segment(a: Vector3, b: Vector3, radius: float, material: Material, parent: Node3D = null, top: float = -1) -> MeshInstance3D:
	var node = cylinder((a + b) * 0.5, radius, a.distance_to(b), material, parent, top)
	node.quaternion = Quaternion(Vector3.UP, (b - a).normalized())
	return node

func lathe(profile: Array, segments: int = 48) -> ArrayMesh:
	var surface = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(profile.size() - 1):
		for j in range(segments):
			for ij in [Vector2i(i,j), Vector2i(i+1,j), Vector2i(i,j+1), Vector2i(i,j+1), Vector2i(i+1,j), Vector2i(i+1,j+1)]:
				var p: Vector2 = profile[ij.x]
				var theta: float = ij.y * TAU / segments
				var tangent: Vector2 = (profile[i+1]-profile[i]).normalized()
				# Preserve hard rim/base edges; smooth only adjacent gentle profile bends.
				var neighbor_index: int = i-1 if ij.x==i else i+1
				if neighbor_index>=0 and neighbor_index<profile.size()-1:
					var neighbor: Vector2 = (profile[neighbor_index+1]-profile[neighbor_index]).normalized()
					if tangent.dot(neighbor)>.7:
						tangent = (tangent+neighbor).normalized()
				surface.set_normal(Vector3(sin(theta)*tangent.y, -tangent.x, cos(theta)*tangent.y))
				surface.set_uv(Vector2(float(ij.y)/segments, float(ij.x)/(profile.size()-1)))
				surface.add_vertex(Vector3(sin(theta)*p.x, p.y, cos(theta)*p.x))
	return surface.commit()

func add_triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, normal: Vector3, uvs: Array) -> void:
	# Godot front faces are clockwise. Keep winding and shading normals consistent.
	var points = [a,b,c]
	var coords = uvs.duplicate()
	if -(b-a).cross(c-a).dot(normal) < 0:
		points = [a,c,b]
		coords = [uvs[0],uvs[2],uvs[1]]
	for i in range(3):
		surface.set_normal(normal)
		surface.set_uv(coords[i])
		surface.add_vertex(points[i])

func extrude(polygon: PackedVector2Array, depth: float, material: Material, pose: Vector3, parent: Node3D = null) -> MeshInstance3D:
	var surface = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var indices = Geometry2D.triangulate_polygon(polygon)
	for side in [-1,1]:
		for t in range(0,indices.size(),3):
			var a: Vector2 = polygon[indices[t]]
			var b: Vector2 = polygon[indices[t+1]]
			var c: Vector2 = polygon[indices[t+2]]
			add_triangle(surface,Vector3(a.x,a.y,side*depth*.5),Vector3(b.x,b.y,side*depth*.5),Vector3(c.x,c.y,side*depth*.5),Vector3(0,0,side),[a,b,c])
	var area: float = 0
	for i in range(polygon.size()):
		area += polygon[i].cross(polygon[(i+1)%polygon.size()])
	var along: float = 0
	for i in range(polygon.size()):
		var a: Vector2 = polygon[i]
		var b: Vector2 = polygon[(i+1)%polygon.size()]
		var edge: Vector2 = b-a
		var normal = Vector3(edge.y,-edge.x,0).normalized()*signf(area)
		var vertices = [Vector3(a.x,a.y,-depth*.5),Vector3(b.x,b.y,-depth*.5),Vector3(a.x,a.y,depth*.5),Vector3(b.x,b.y,depth*.5)]
		var uv = [Vector2(along,0),Vector2(along+edge.length(),0),Vector2(along,depth),Vector2(along+edge.length(),depth)]
		add_triangle(surface,vertices[0],vertices[1],vertices[2],normal,[uv[0],uv[1],uv[2]])
		add_triangle(surface,vertices[1],vertices[3],vertices[2],normal,[uv[1],uv[3],uv[2]])
		along += edge.length()
	surface.generate_tangents()
	return mesh_node(surface.commit(),pose,material,parent)

func bowl(pose: Vector3, scale_value: float = 1.0, parent: Node3D = null) -> Node3D:
	var profile = [Vector2(0,0.01),Vector2(0.16,0.01),Vector2(0.24,0.09),Vector2(0.3,0.22),Vector2(0.32,0.25),Vector2(0.3,0.26),Vector2(0.275,0.21),Vector2(0.20,0.09),Vector2(0,0.055)]
	var node = mesh_node(lathe(profile),pose,mat("glazed_ceramic"),parent)
	node.scale = Vector3.ONE*scale_value
	return node

func vase(pose: Vector3, scale_value: float = 1.0) -> Node3D:
	var profile = [Vector2(0,0),Vector2(.26,0),Vector2(.42,.22),Vector2(.49,.62),Vector2(.40,.95),Vector2(.24,1.17),Vector2(.25,1.24),Vector2(.21,1.26),Vector2(.19,1.18),Vector2(.34,.91),Vector2(.39,.6),Vector2(.32,.2),Vector2(0,.08)]
	var node = mesh_node(lathe(profile),pose,mat("earthenware"))
	node.scale = Vector3.ONE*scale_value
	return node

func mushroom(pose: Vector3, scale_value: float = 1, glowing: bool = false, parent: Node3D = null) -> Node3D:
	var group = Node3D.new()
	(root if parent == null else parent).add_child(group)
	group.position = pose
	group.scale = Vector3.ONE*scale_value
	cylinder(Vector3(0,.15,0),.055,.3,mat("pages"),group,.04)
	var profile = [Vector2(0,.19),Vector2(.23,.19),Vector2(.28,.22),Vector2(.24,.29),Vector2(.15,.35),Vector2(0,.37)]
	mesh_node(lathe(profile,16),Vector3.ZERO,mat("glow") if glowing else mat("mushroom"),group)
	return group

func root_vegetable(pose: Vector3, scale_value: float = 1, parent: Node3D = null) -> Node3D:
	var group = Node3D.new()
	(root if parent==null else parent).add_child(group)
	group.position = pose
	group.scale = Vector3.ONE*scale_value
	group.rotation_degrees.z = 73
	var profile = [Vector2(.006,0),Vector2(.038,.07),Vector2(.065,.13),Vector2(.061,.17),Vector2(.092,.23),Vector2(.087,.27),Vector2(.119,.34),Vector2(.11,.38),Vector2(.128,.43),Vector2(.065,.49),Vector2(0,.50)]
	mesh_node(lathe(profile,16),Vector3.ZERO,mat("root"),group)
	segment(Vector3(0,0,0),Vector3(.025,-.10,.018),.008,mat("root"),group,.002)
	return group

func book_instance(pose: Vector3, size: Vector3, color: Color, rotation: Basis) -> void:
	batch_mesh("books",unit_box,mat("book_leather"),Transform3D(rotation*Basis.from_scale(size),pose),color)
	batch_mesh("book_pages",unit_box,mat("pages"),Transform3D(rotation*Basis.from_scale(Vector3(.012,size.y*.84,size.z*.79)),pose+rotation*Vector3(size.x*.5+.016,0,.015)))
	# Raised leather bindings, cover lips and a small gilt title cartouche.
	for side in [-1,1]:
		batch_mesh("book_cover_lips",unit_box,mat("book_leather"),Transform3D(rotation*Basis.from_scale(Vector3(.018,size.y*1.025,size.z*1.04)),pose+rotation*Vector3(side*size.x*.5,0,0)),color)
	batch_mesh("book_title",unit_box,mat("book_gilt"),Transform3D(rotation*Basis.from_scale(Vector3(size.x*.54,size.y*.10,.012)),pose+rotation*Vector3(0,size.y*.10,-size.z*.5-.009)))
	for band in [-.39,-.19,.36]:
		batch_mesh("book_binding_ribs",unit_box,mat("book_leather"),Transform3D(rotation*Basis.from_scale(Vector3(size.x*.98,.018,.022)),pose+rotation*Vector3(0,size.y*band,-size.z*.5-.007)),color)
	for y in [-.34,.27]:
		batch_mesh("book_gilt",unit_box,mat("book_gilt"),Transform3D(rotation*Basis.from_scale(Vector3(size.x*.86,.014,.009)),pose+rotation*Vector3(0,size.y*y,-size.z*.5-.006)))

func lying_books(pose: Vector3, count: int, yaw: float = 0) -> void:
	var palette = [Color(.65,.35,.24),Color(.25,.47,.48),Color(.68,.55,.31),Color(.36,.40,.26)]
	for i in range(count):
		var rotation = Basis(Vector3.UP,yaw+rng.randf_range(-.14,.14))
		var p: Vector3 = pose+Vector3(0,.04+i*.085,0)
		batch_mesh("lying_covers",unit_box,mat("book_leather"),Transform3D(rotation*Basis.from_scale(Vector3(.5,.083,.35)),p),palette[i%palette.size()])
		batch_mesh("lying_pages",unit_box,mat("pages"),Transform3D(rotation*Basis.from_scale(Vector3(.47,.053,.325)),p+Vector3(.006,0,-.005)))

func shelf(pose: Vector3, width: float, height: float, yaw: float = 0) -> void:
	var group = Node3D.new()
	root.add_child(group)
	group.position = pose
	group.rotation.y = yaw
	box(Vector3(0,height*.5,.48),Vector3(width,height,.12),mat("wood"),true,group)
	for side in [-1,1]:
		box(Vector3(side*width*.5,height*.5,0),Vector3(.18,height,1.08),mat("wood"),true,group)
		box(Vector3(side*width*.5,height*.5,-.53),Vector3(.08,height,.09),mat("brass"),false,group)
	var row_count: int = int(height/.75)
	var colors = [Color(.40,.54,.55),Color(.67,.37,.26),Color(.67,.58,.35),Color(.32,.39,.37),Color(.55,.44,.37)]
	for row in range(row_count+1):
		var y: float = .13 + row*.75
		box(Vector3(0,y,0),Vector3(width,.13,1.08),mat("wood"),false,group)
		if row == row_count:
			continue
		var x: float = -width*.5+.2
		while x < width*.5-.2:
			if rng.randf()<.17 and x<width*.5-.85:
				var local = Vector3(x+.25,y+.075,-.16)
				lying_books(group.transform*local,rng.randi_range(2,4),yaw)
				x += .62
				continue
			var w: float = rng.randf_range(.08,.25)
			var h: float = rng.randf_range(.29,.66)
			var d: float = rng.randf_range(.33,.56)
			var local = Vector3(x,y+.075+h*.5,rng.randf_range(-.28,-.11))
			var rotation: Basis = group.basis*Basis.from_euler(Vector3(0,rng.randf_range(-.06,.06),rng.randf_range(-.20,.20)))
			book_instance(group.transform*local,Vector3(w,h,d),colors[rng.randi_range(0,colors.size()-1)],rotation)
			x += w+rng.randf_range(.008,.07)

func ladder(pose: Vector3, height: float, yaw: float = 0) -> void:
	var group = Node3D.new()
	root.add_child(group)
	group.position = pose
	group.rotation = Vector3(-.1,yaw,0)
	for side in [-1,1]:
		box(Vector3(side*.37,height*.5,0),Vector3(.09,height,.1),mat("wood"),false,group)
	for i in range(int(height/.35)):
		box(Vector3(0,.2+i*.35,0),Vector3(.8,.075,.13),mat("wood"),false,group)

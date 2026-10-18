extends RefCounted
## Deterministic atmosphere clock shared by lighting, foliage, ripples and captures.
var world
var foliage_materials: Array[ShaderMaterial] = []
var water_materials: Array[ShaderMaterial] = []
var lanterns: Array = []
var garden_light: SpotLight3D
var hearth_bounce: OmniLight3D
var garden_origin: Vector3
var garden_energy: float = 26.0
var garden_aim: Vector3 = Vector3(-1.8,0,-4.8)
var fire_energy: float = 2.75
var time: float = 0.0

func _init(owner) -> void:
	world = owner

func build() -> void:
	var foliage_names = ["tree_leaf","ivy_leaf","fern","leaf","grass"]
	var replacements: Dictionary = {}
	for name in foliage_names:
		if not world.art.materials.has(name):
			continue
		var source: StandardMaterial3D = world.art.materials[name]
		var material = ShaderMaterial.new()
		material.shader = load("res://shaders/foliage_wind.gdshader")
		material.set_shader_parameter("leaf_texture",source.albedo_texture)
		material.set_shader_parameter("tint",source.albedo_color)
		material.set_shader_parameter("wind_strength",.065 if name=="tree_leaf" else .035)
		replacements[source] = material
		foliage_materials.append(material)
	for node in world.find_children("*","GeometryInstance3D",true,false):
		if not node.visible:
			continue
		if replacements.has(node.material_override):
			node.material_override = replacements[node.material_override]
			# GPU wind deformation participates in the real shadow pass.
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if node.material_override is ShaderMaterial:
			var material: ShaderMaterial = node.material_override
			if material.shader.resource_path in ["res://shaders/water.gdshader","res://shaders/interior_cascade.gdshader"]:
				if not water_materials.has(material):
					water_materials.append(material)
	for node in world.get_children():
		if node is Light3D and node.position.z> -20 and node.light_cull_mask==1048575:
			node.light_cull_mask = 1
		if node is SpotLight3D:
			garden_light = node
			garden_origin = node.position
			garden_energy = node.get_meta("base_energy",garden_energy)
			garden_aim = node.get_meta("aim",garden_aim)
		if node is OmniLight3D and node.has_meta("lantern"):
			lanterns.append({"node":node,"origin":node.position,"energy":node.light_energy,"phase":node.position.dot(Vector3(.7,1.3,.9))})
		if node is OmniLight3D and node.has_meta("hearth_bounce"):
			hearth_bounce = node
	fire_energy = world.fire_light.get_meta("base_energy",fire_energy)
	world.fire_light.light_size = .05   # small source: crisp, dancing shadows
	world.fire_light.shadow_blur = .55
	world.fire_light.omni_attenuation = 1.6   # bright near the hearth, falls off fast
	world.fire_light.omni_range = 9.0
	streambed()
	tick(0)

func streambed() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = 10113
	# Shallow textured bed now remains visible through the water film.
	world.art.box(Vector3(-.9,-.20,-5.7),Vector3(1.08,.055,11.4),world.art.mat("hearth_stone"))
	for i in range(95):
		var p = Vector3(-.9+rng.randf_range(-.46,.46),-.143+rng.randf_range(-.008,.008),rng.randf_range(-11.3,-.15))
		var mesh = SphereMesh.new()
		mesh.radial_segments = 10
		mesh.rings = 5
		var rock = world.art.mesh_node(mesh,p,world.art.mat("floor_stone") if i%3 else world.art.mat("hearth_stone"))
		rock.scale = Vector3(rng.randf_range(.065,.18),rng.randf_range(.025,.055),rng.randf_range(.07,.21))
		rock.rotation.y = rng.randf_range(0,TAU)
	# Soft bounce catches ripples without a luminous water surface.
	var bounce = world.light(Vector3(-.9,.9,-2.2),Color("c5cfb2"),.25,3.0)
	bounce.light_specular = .15

func tick(t: float) -> void:
	time = t
	var slow: float = sin(t*2.1)*.40+sin(t*3.73+.7)*.28+sin(t*6.21+1.2)*.12
	world.fire_light.light_energy = fire_energy+slow*fire_energy*.33
	world.fire_light.position = world.hearth+Vector3(sin(t*2.8)*.13,.23+sin(t*4.1)*.025,cos(t*2.17)*.09)
	world.fire_light.light_color = Color("ff9d42").lerp(Color("ffd08a"),.48+slow*.24)
	if hearth_bounce != null:
		hearth_bounce.light_energy = .88+slow*.32
		hearth_bounce.position = world.hearth+Vector3(-1.1+sin(t*1.9)*.075,1.65+cos(t*2.7)*.035,-.4+sin(t*2.2)*.07)
	for data in lanterns:
		var p: float = t+data.phase
		data.node.light_energy = data.energy*(.95+sin(p*2.3)*.045+sin(p*4.1)*.025)
		data.node.position = data.origin+Vector3(sin(p*1.7)*.018,sin(p*3.1)*.008,cos(p*1.3)*.012)
	if garden_light != null:
		garden_light.position = garden_origin+Vector3(sin(t*.17)*.12,0,cos(t*.13)*.10)
		garden_light.look_at(garden_aim+Vector3(sin(t*.23)*.45,0,cos(t*.19)*.25),Vector3.FORWARD)
		garden_light.light_energy = garden_energy*(1.0+sin(t*.27)*.04)
	for material in foliage_materials:
		material.set_shader_parameter("simulation_time",t)
	for material in water_materials:
		material.set_shader_parameter("simulation_time",t)

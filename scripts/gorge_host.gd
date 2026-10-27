extends Node3D
## What the gorge's code (scripts/vista.gd and its parts) builds into: the
## few helpers it borrows from its first home, the code-built camp
## (scripts/world.gd, retired in phase 7 step 4), unchanged. tools/bake_gorge.gd
## runs vista.gd into one of these.
const Interaction = preload("res://scripts/interactable.gd")
var art
var vista

func box(pose: Vector3, size: Vector3, material: String = "sandstone", solid: bool = false) -> Node3D:
	return art.box(pose,size,art.mat(material),solid)

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

func arch_point(radius: float, spring: float, rise: float, t: float) -> Vector2:
	if rise < radius:
		# Low canopy spans use an ellipse instead of a pointed arc that folds over.
		return Vector2(radius*cos(t*PI*.5),spring+rise*sin(t*PI*.5))
	var center: float = (radius*radius-rise*rise)/(2*radius)
	var circle_radius: float = radius-center
	var angle: float = atan2(rise,-center)*t
	return Vector2(center+circle_radius*cos(angle),spring+circle_radius*sin(angle))

## `jambs` false: the arch springs from columns of its own (the Gorge's loggia,
## where jambs beside the columns made two supports).
## `top` (above `pose`), when given, is where the arch's spandrels end: up to
## a ceiling (the Gorge's loggia: your walk, they stopped short of it).
func arch(pose: Vector3, radius: float, spring: float, rise: float, thickness: float, jambs: bool = true, top_at: float = 0.0) -> void:
	var steps: int = 24
	var top: float = top_at if top_at > 0.0 else maxf(spring+rise+thickness+.25,8.3 if absf(pose.z)<.01 else 0)
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
		if not jambs:
			continue
		var rows: int = maxi(1,int(ceil(spring/.43)))
		for row in range(rows):
			# 2 cm wider each side: the inner face stands proud of the wall end it
			# lines (flush, they z-fought in the doorway reveals).
			box(pose+Vector3(side*(radius+thickness*.5),spring*(row+.5)/rows,0),Vector3(thickness+.04,spring/rows-.015,1.1),"limestone" if pose.z>=-20 else "arch_stone")

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

func interaction(id: String, title: String, pose: Vector3, size: Vector3) -> StaticBody3D:
	var body = Interaction.new()
	body.name = id
	body.configure(id,title,size)
	add_child(body)
	body.position = pose
	return body

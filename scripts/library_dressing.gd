extends RefCounted
## Dense built-in collections and woven art; clear paths and doorways remain usable.
var world
var art
var case_count: int = 0
var art_count: int = 0

func _init(owner, factory) -> void:
	world = owner
	art = factory

func build() -> void:
	# Every camp perimeter is a collection wall, including the wall behind arrival.
	for x in [-6.8,-2.2,2.4,7.0,11.6]:
		art.shelf(Vector3(x,0,11.65),4.3,7.5)
	for z in [3.1,8.8]:
		art.shelf(Vector3(13.35,0,z),5.4,7.4,PI/2)
	case_panel(Vector3(-8.7,6.4,5.7),11.4,1.6,-PI/2)
	# Collections cover the masonry beside the main openings. The centre pier
	# carries the concept mosaic panel (arch_pass.gd) instead of a hanging.
	art.shelf(Vector3(-7.65,.5,.69),4.0,6.7,PI)
	art.shelf(Vector3(12.75,.5,.69),1.9,6.7,PI)
	# The former centre-pier hanging now faces the camp from the back wall.
	hanging(Vector3(2.0,3.9,11.97),1.32,4.4,PI,0)
	# Garden collections run up to the vault instead of ending at a low bare wall.
	for z in [-3.2,-8.6]:
		art.shelf(Vector3(-9.2,0,z),5.1,6.7,-PI/2)
	case_panel(Vector3(-9.45,6.7,-6.5),12.3,6.3,-PI/2)
	for x in [-5.7,2.5]:
		case_panel(Vector3(x,.12,-12.9),2.2,1.9,PI)
	case_panel(Vector3(-1.4,6.5,-12.65),14.2,6.8,PI)
	for x in [-5.5,2.7]:
		case_panel(Vector3(x,5.2,-12.65),3.7,1.3,PI)
	# Above the eastern archive wall: books and inset art, all below the vault.
	for z in [-3.2,-8.8]:
		case_panel(Vector3(4.72,6.5,z),5.2,6.5,PI/2)
	for z in [-2.0,-6.2,-10.5]:
		hanging(Vector3(4.76,3.6,z),1.6,4.5,-PI/2,1 if z< -4 else 2)
	# The high front clerestory is also a collection gallery, visible when looking up.
	case_panel(Vector3(-2.5,8.3,-.52),14.2,4.8,0)
	# Canopy coffers use smaller decorative fields rather than bare timber expanses.
	for x in [-5.9,-1.8,2.3,6.4,10.5]:
		for z in [3.2,7.4,10.6]:
			art.box(Vector3(x,8.13,z),Vector3(3.7,.025,2.7),art.mat("mosaic"))
	# The passage has shallow collections; its central walking lane remains 3.2m wide.
	for z in [-15.5,-18.8]:
		case_panel(Vector3(-3.03,2.25,z),2.8,3.6,-PI/2)
		case_panel(Vector3(1.03,2.25,z),2.8,3.6,PI/2)
	# Tapestries and shelves on the sheltered balcony's back faces.
	for x in [-5.0,3.0]:
		case_panel(Vector3(x,2.25,-20.2),2.4,4.7,PI)
	for x in [-6.15,4.15]:
		hanging(Vector3(x,5.5,-20.65),1.2,3.8,0,2)
	world.light(Vector3(-5,5.7,3.0),Color("e1c18b"),.8,8)
	world.light(Vector3(4,5.6,4.0),Color("c9c6a8"),1.0,9)

func case_panel(pose: Vector3, width: float, height: float, yaw: float) -> void:
	case_count += 1
	var basis = Basis(Vector3.UP,yaw)
	var panel = art.box(pose+basis*Vector3(0,height*.5,0),Vector3(width,height,.22),art.mat("stack_atlas"))
	panel.rotation.y = yaw
	for x in [-width*.5,width*.5]:
		var frame = art.box(pose+basis*Vector3(x,height*.5,-.17),Vector3(.12,height,.18),art.mat("wood"))
		frame.rotation.y = yaw
	for i in range(int(height/.75)+1):
		var shelf = art.box(pose+basis*Vector3(0,i*.75,-.15),Vector3(width,.075,.22),art.mat("wood"))
		shelf.rotation.y = yaw
	for y in [.06,height-.06]:
		var trim = art.box(pose+basis*Vector3(0,y,-.28),Vector3(width,.055,.055),art.mat("brass"))
		trim.rotation.y = yaw

func hanging(pose: Vector3, width: float, height: float, yaw: float, variant: int) -> void:
	art_count += 1
	var material = art.mat("tapestry_%d" % variant)
	material.normal_enabled = true
	material.normal_texture = load("res://assets/textures/cloth_normal.png")
	material.normal_scale = .85
	material.roughness = .8
	var mesh = QuadMesh.new()
	mesh.size = Vector2(width,height)
	var panel = art.mesh_node(mesh,pose,material)
	panel.rotation.y = yaw
	var basis = Basis(Vector3.UP,yaw)
	for x in [-width*.5,width*.5]:
		var frame = art.bevel_box(pose+basis*Vector3(x,0,.025),Vector3(.07,height+.14,.09),art.mat("brass"),.018)
		frame.rotation.y = yaw
	for y in [-height*.5,height*.5]:
		var frame = art.bevel_box(pose+basis*Vector3(0,y,.025),Vector3(width+.14,.07,.09),art.mat("brass"),.018)
		frame.rotation.y = yaw

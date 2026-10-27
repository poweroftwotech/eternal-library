extends SceneTree
## Builds rooms/test/persian_gallery.tscn (phase 8 step 1): every piece of the
## Persian kit arranged in small scenes against a cliff, lit by the gorge's
## own environment and the pieces' own lights, to judge the kit before it
## goes into the gorge. Open it in the editor, or capture it on the GPU with
## tests/persian_gallery_capture.gd.
##   godot --headless --path . --script res://tools/build_persian_gallery.gd
## Godot frame: walls face +Z, the cliff's face is at z = -6, the ground y = 0.
##   x -82..-68  a great fall from a spillway on a rock 30 m tall
##   x -54..-30  two houses (plaster and lime), a lit bed under a shaft of light
##   x -18..18   a monument: arcades, the portal, dome, minarets, a lumen-lit garden
##   x  20..54   the carved cliff: doors, windows, a rock path, the great iwan
##                and its garden lit by a lumen stone
##   x  60..86   a dark garden: giant and jelly fungi, fungal beds, glow moss

const OUT: String = "res://rooms/test/persian_gallery.tscn"
const KIT: String = "res://kit/modules/persian/%s.tscn"
const DRESSING: String = "res://kit/modules/dressing/%s.tscn"
const VistaLight: GDScript = preload("res://scripts/vista_light.gd")

var gallery: Node3D


func _init() -> void:
	gallery = Node3D.new()
	gallery.name = "PersianGallery"
	_environment()
	_ground()
	_houses()
	_monument()
	_carved()
	_dark_garden()
	_fall()
	var packed := PackedScene.new()
	packed.pack(gallery)
	var err: Error = ResourceSaver.save(packed, OUT)
	print("build_persian_gallery: %s (%s)" % [OUT, error_string(err)])
	quit(0 if err == OK else 1)


func _own(node: Node, parent: Node = null) -> Node:
	(parent if parent else gallery).add_child(node)
	node.owner = gallery
	return node


func put(piece: String, pos: Vector3, yaw_deg: float = 0.0, parent: Node = null) -> Node3D:
	var path: String = (DRESSING % piece) if piece.begins_with("gorge_") else (KIT % piece)
	var node: Node3D = (load(path) as PackedScene).instantiate()
	node.position = pos
	node.rotation_degrees.y = yaw_deg
	_own(node, parent)
	return node


func _group(name: String) -> Node3D:
	var g := Node3D.new()
	g.name = name
	return _own(g) as Node3D


func _box(name: String, size: Vector3, pos: Vector3, material: String) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.name = name
	node.mesh = mesh
	node.position = pos
	node.material_override = load("res://kit/materials/%s.tres" % material)
	_own(node)


func _environment() -> void:
	var env := WorldEnvironment.new()
	env.name = "Environment"
	env.environment = load("res://rooms/baked/gorge/environment.tres")
	_own(env)
	# The gorge's bounce light off the vault (vista.gd ExteriorVaultBounce).
	var bounce := DirectionalLight3D.new()
	bounce.name = "VaultBounce"
	bounce.rotation_degrees = Vector3(-39, -28, 0)
	bounce.light_color = VistaLight.VAULT_BOUNCE_COLOR
	bounce.light_energy = VistaLight.VAULT_BOUNCE_ENERGY
	bounce.shadow_enabled = true
	bounce.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	bounce.light_volumetric_fog_energy = 0.1
	_own(bounce)


func _ground() -> void:
	_box("Ground", Vector3(200, 1, 90), Vector3(0, -0.5, 10), "persian_stone")
	_box("Cliff", Vector3(200, 60, 20), Vector3(0, 30, -16), "cave_rock")


## Edge pieces along a face from x0, `pieces` per storey (bottom first).
func facade(g: Node3D, x0: float, z: float, storeys: Array, y0: float = 0.0) -> void:
	for s: int in storeys.size():
		for i: int in storeys[s].size():
			if storeys[s][i] != "":
				put(storeys[s][i], Vector3(x0 + i * 4.0, y0 + s * 4.0, z), 0.0, g)


## A house's two end walls, `depth` m deep behind its face.
func ends(g: Node3D, x0: float, x1: float, z: float, depth: float, pieces: Array, y0: float = 0.0) -> void:
	for s: int in pieces.size():
		for k: int in int(depth / 4.0):
			put(pieces[s], Vector3(x0, y0 + s * 4.0, z - depth + k * 4.0), -90.0, g)
			put(pieces[s], Vector3(x1, y0 + s * 4.0, z - k * 4.0), 90.0, g)


func roof(g: Node3D, x0: float, bays: int, z: float, depth: float, y: float, parapet: String) -> void:
	for i: int in bays:
		for k: int in int(depth / 4.0):
			put("persian_roof", Vector3(x0 + i * 4.0, y, z - k * 4.0), 0.0, g)
		put(parapet, Vector3(x0 + i * 4.0, y, z), 0.0, g)
	put("persian_parapet_corner", Vector3(x0 - 0.2, y, z - 0.2), 0.0, g)
	put("persian_parapet_corner", Vector3(x0 + bays * 4.0 - 0.2, y, z - 0.2), 0.0, g)


func _houses() -> void:
	var g: Node3D = _group("Houses")
	facade(g, -54, -2, [["persian_wall_plaster_door", "persian_wall_plaster_window", "persian_wall_plaster"],
			["persian_wall_plaster_window_dark", "persian_wall_plaster_window", "persian_wall_plaster_window"]])
	ends(g, -54, -42, -2, 4, ["persian_wall_plaster", "persian_wall_plaster"])
	roof(g, -54, 3, -2, 4, 8, "persian_parapet")
	put("persian_windcatcher", Vector3(-44, 8, -4.5), 0.0, g)
	put("persian_lamp_bracket", Vector3(-50.9, 3.0, -2), 0.0, g)
	facade(g, -40, -3, [["persian_wall_lime_window", "persian_wall_lime_door"],
			["persian_wall_lime_window_dark", "persian_wall_lime_window"]])
	ends(g, -40, -32, -3, 4, ["persian_wall_lime", "persian_wall_lime"])
	roof(g, -40, 2, -3, 4, 8, "persian_parapet_lime")
	put("persian_lamp_bracket", Vector3(-35.0, 3.0, -3), 0.0, g)
	# a lit garden under a shaft of natural light
	put("persian_bed", Vector3(-46, 0, 5), 0.0, g)
	put("persian_bed", Vector3(-40, 0, 5), 0.0, g)
	put("persian_pomegranate", Vector3(-43, 0, 8), 0.0, g)
	for x: float in [-49.5, -36.5]:
		put("gorge_cypress_6", Vector3(x, 0, 5), 0.0, g)
	var shaft := LightShaft.new()
	shaft.name = "LightShaft"
	shaft.position = Vector3(-43, 46, 5)
	shaft.height = 46.0
	shaft.radius = 8.0
	shaft.energy = 10.0
	shaft.haze = 0.2
	_own(shaft, g)


func _monument() -> void:
	var g: Node3D = _group("Monument")
	var x0: float = -14.0
	var z: float = 2.0
	facade(g, x0, z, [["persian_wall_brick_arcade", "persian_wall_brick_arcade_dark", "", "", "", "persian_wall_brick_arcade", "persian_wall_brick_arcade"],
			["persian_wall_brick_arcade_dark", "persian_wall_brick_orosi", "", "", "", "persian_wall_brick_orosi", "persian_wall_brick_arcade"]])
	put("persian_portal", Vector3(-6, 0, z), 0.0, g)
	for i: int in [0, 1, 5, 6]:
		put("persian_crown", Vector3(x0 + i * 4.0, 8, z), 0.0, g)
	ends(g, x0, 14, z, 8, ["persian_wall_brick", "persian_wall_brick"])
	for k: int in 2:
		put("persian_plinth", Vector3(x0, 0, z - 8 + k * 4.0), -90.0, g)
		put("persian_plinth", Vector3(14, 0, z - k * 4.0), 90.0, g)
	for i: int in 7:
		for k: int in 2:
			if k == 0 and i >= 2 and i <= 4:
				continue     # the portal's hood is here: the roof starts behind it
			put("persian_roof", Vector3(x0 + i * 4.0, 8, z - k * 4.0), 0.0, g)
	put("persian_dome", Vector3(0, 8, -4), 0.0, g)
	put("persian_minaret", Vector3(-16.5, 0, 1), 0.0, g)
	put("persian_minaret", Vector3(16.5, 0, 1), 0.0, g)
	# a chahar bagh lit by two lumen stones
	put("persian_pool", Vector3(0, 0, 11), 0.0, g)
	put("persian_fountain", Vector3(0, 0, 11), 0.0, g)
	for x: float in [-5.0, 5.0]:
		for zz: float in [8.5, 13.5]:
			put("persian_bed", Vector3(x, 0, zz), 0.0, g)
	for zz: float in [6.0, 9.5, 13.0, 16.5]:
		put("gorge_cypress_6", Vector3(-8.5, 0, zz), 0.0, g)
		put("gorge_cypress_6", Vector3(8.5, 0, zz), 0.0, g)
	put("persian_lumen_post", Vector3(-3, 0, 5.5), 0.0, g)
	put("persian_lumen_post", Vector3(3, 0, 5.5), 0.0, g)


func _carved() -> void:
	var g: Node3D = _group("Carved")
	# Carved pieces stand with their front at the rock's face and bury their
	# depth in it (in the gorge the rock must stay behind their fronts); here
	# the cliff is a box, so they stand out from it by their depth.
	var face: float = -6.0 + 1.8
	put("persian_carved_door", Vector3(22, 0, face), 0.0, g)
	put("persian_carved_window", Vector3(25, 1.2, face + 0.4), 0.0, g)
	put("persian_carved_door_dark", Vector3(29, 0, face), 0.0, g)
	put("persian_carved_window_dark", Vector3(32, 1.2, face + 0.4), 0.0, g)
	for i: int in 4:
		put("persian_rock_path", Vector3(20 + i * 4.0, 6, face), 0.0, g)
	put("persian_carved_door", Vector3(24, 6, face), 0.0, g)
	put("persian_carved_window_dark", Vector3(29, 7.2, face + 0.4), 0.0, g)
	put("persian_carved_window", Vector3(22, 12.5, face + 0.4), 0.0, g)
	put("persian_carved_window", Vector3(31, 13.5, face + 0.4), 0.0, g)
	put("persian_glowmoss", Vector3(35, 4.5, -6), 0.0, g)
	# the great iwan (8 m deep), its lumen stone over the spring, its garden
	put("persian_iwan_great", Vector3(45, 0, 2), 0.0, g)
	put("persian_lumen_post", Vector3(45, 0, -0.6), 0.0, g)
	put("persian_pool", Vector3(45, 0, 11), 0.0, g)
	put("persian_fountain", Vector3(45, 0, 11), 0.0, g)
	put("persian_bed", Vector3(40.5, 0, 11), 90.0, g)
	put("persian_bed", Vector3(49.5, 0, 11), 90.0, g)
	for x: float in [38.5, 51.5]:
		for zz: float in [5.0, 9.0, 13.0, 17.0]:
			put("gorge_cypress_6", Vector3(x, 0, zz), 0.0, g)
	put("persian_pomegranate", Vector3(42, 0, 17), 0.0, g)
	put("persian_pomegranate", Vector3(48, 0, 17), 0.0, g)
	# where the stone's light ends, the fungi begin
	put("persian_fungus_small", Vector3(56, 0, 6), 0.0, g)
	put("persian_fungus_cluster", Vector3(55, 0, 13), 0.0, g)


func _dark_garden() -> void:
	var g: Node3D = _group("DarkGarden")
	put("persian_fungus_giant_9", Vector3(64, 0, -2), 0.0, g)
	put("persian_fungus_giant_6", Vector3(83, 0, 1), 0.0, g)
	put("persian_fungus_giant_6", Vector3(68, 0, 9), 140.0, g)
	put("persian_fungus_jelly", Vector3(71, 0, 2), 0.0, g)
	put("persian_fungus_jelly", Vector3(79, 0, -3), 60.0, g)
	put("persian_fungus_small", Vector3(76, 0, 9), 0.0, g)
	for p: Vector3 in [Vector3(66, 0, 4), Vector3(81, 0, 6), Vector3(73, 0, -4)]:
		put("persian_fungus_cluster", p, 0.0, g)
	put("persian_bed_fungal", Vector3(73, 0, 5.5), 0.0, g)
	put("persian_bed_fungal", Vector3(73, 0, 9.5), 0.0, g)
	put("persian_channel", Vector3(71, 0, 13), 0.0, g)
	for p: Vector3 in [Vector3(66, 3, -6), Vector3(74, 5, -6), Vector3(82, 2.5, -6), Vector3(78, 9, -6)]:
		put("persian_glowmoss", p, 0.0, g)


func _fall() -> void:
	var g: Node3D = _group("GreatFall")
	_box("FallRock", Vector3(20, 30, 10), Vector3(-75, 15, -11), "cave_rock")
	put("persian_spillway_great", Vector3(-81, 26, -6), 0.0, g)
	var fall := GreatFall.new()
	fall.name = "Fall"
	fall.position = Vector3(-75, 27.0, -3.8)
	fall.width = 7.5
	fall.height = 27.0
	fall.arc_out = 2.5
	_own(fall, g)
	put("persian_pool", Vector3(-75, 0, 3), 90.0, g)

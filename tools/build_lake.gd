extends SceneTree
## Builds rooms/lake/landing.tscn: the Lake Landing (phase 18, R20), a place
## of its own (docs/environment/phase-18-approval.md, Q1). The entry door at the
## origin, a short cave passage to -Z, the quay in the cavern's near cove with
## its water steps, wading shelf, boardwalk, boathouses and lantern pier, the
## black lake (about 170 x 160 m) and four landings on its far shore. Pieces from
## art_src/kit/kit_lake.blend (tools/kit_add_r20.py) and the Persian kit.
##
## What changes by world seed (moored boats, which boathouses are lit, the
## fisher's place) is chosen at run time by LakeLife; the ferry is LakeFerry.
## Walk it with
##   godot --path . -- --room=res://rooms/lake/landing.tscn
## Run: --headless --script res://tools/build_lake.gd

const OUT: String = "res://rooms/lake/landing.tscn"
const K: String = "res://kit/modules/walls/"
const P: String = "res://kit/modules/persian/"
const ATMOSPHERE: String = "res://kit/atmosphere/lake_landing.tres"
const W: float = LakeLayout.WATER

var _room: Node3D
var _parent: Node3D


func _init() -> void:
	_room = (load("res://scripts/world/room_template.gd") as GDScript).new()
	_room.name = "LakeLanding"
	_room.set("room_id", "lake_landing")
	_room.set("display_name", "Lake Landing")
	_passage()
	_cavern()
	_quay()
	_pier()
	_boathouses()
	_water()
	_drips()
	# Revised phase step 2: the docks, far off in the same scene, reached
	# through the fog (step 2: the Mahaleh's; the rest in step 3).
	for style: String in LakeLayout.STYLES:
		_dock(style)
	_markers()
	_parent = _room
	var ferry := LakeFerry.new()
	ferry.name = "Ferry"
	_add(ferry)
	var life := LakeLife.new()
	life.name = "Life"
	_add(life)
	var spawn := Marker3D.new()
	spawn.name = "PlayerSpawn"
	_add(spawn)
	spawn.add_to_group("player_spawn", true)
	spawn.position = Vector3(0.0, 0.05, -2.5)
	var atmo: Node = (load("res://scripts/world/atmosphere.gd") as GDScript).new()
	atmo.name = "Atmosphere"
	atmo.set("profile", load(ATMOSPHERE))
	_add(atmo)
	var packed := PackedScene.new()
	var err: Error = packed.pack(_room)
	if err == OK:
		err = ResourceSaver.save(packed, OUT)
	print("build_lake: %s -> %s" % [error_string(err), OUT])
	_room.free()
	quit()


# ------------------------------------------------------------------ helpers

func _group(node_name: String, under: Node3D = null) -> Node3D:
	var n := Node3D.new()
	n.name = node_name
	(under if under != null else _room).add_child(n)
	n.owner = _room
	_parent = n
	return n


func _add(n: Node) -> void:
	_parent.add_child(n)
	n.owner = _room


func _put(path: String, node_name: String, xform: Transform3D) -> Node3D:
	var n: Node3D = (load(path) as PackedScene).instantiate()
	n.name = node_name
	n.transform = xform
	_add(n)
	return n


func _at(x: float, y: float, z: float, yaw: float = 0.0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw), Vector3(x, y, z))


func _marker(node_name: String, group: String, xform: Transform3D, meta: Dictionary = {}) -> Marker3D:
	var m := Marker3D.new()
	m.name = node_name
	m.transform = xform
	_add(m)
	m.add_to_group(group, true)
	for k: String in meta:
		m.set_meta(k, meta[k])
	return m


func _box_body(node_name: String, size: Vector3, xform: Transform3D) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.transform = xform
	body.collision_layer = 1
	body.collision_mask = 0
	_add(body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	shape.owner = _room


# ------------------------------------------------------------------ the place

## The entry door (the Gorge's door in step 5; sealed for now) and 8 m of
## cave passage to the mouth in the back wall.
func _passage() -> void:
	_group("Passage")
	_put(K + "wall_arch_3m.tscn", "EntryWall", _at(-2.0, 0.0, 0.0))
	var door := SealedDoor.new()
	door.name = "EntryDoor"
	door.transform = _at(0.0, 0.0, 0.0, PI)
	_add(door)
	# The passage pieces sit 1 cm down: their floors run out under the quay
	# paving (harbour walks 2 and 3: z-fighting).
	_put(K + "bh_cave_straight.tscn", "Cave_0", _at(-2.0, -0.01, 0.0))
	_put(K + "bh_cave_straight.tscn", "Cave_1", _at(-2.0, -0.01, -4.0))
	_put(K + "bh_cave_mouth.tscn", "Mouth", _at(-2.0, -0.01, -8.0))
	# The passage is a place you can stand: a floor under the arch's threshold.
	_box_body("PassageFloor", Vector3(4.0, 0.3, 8.0), _at(0.0, -0.15, -4.0))


func _cavern() -> void:
	_group("Cavern")
	# Revised phase step 1: the low harbour chamber after the Ali-Sadr pictures
	# (lk_harbour: layered limestone roof, bed, boulders, stalactites, a lit
	# channel out to the south-east and a dark one to the west).
	_put(K + "lk_harbour.tscn", "Harbour", Transform3D.IDENTITY)
	# Walk 2: off the pier the harbour is lit by glowing fungi, a colour to
	# each part (amber east, violet south-west, lime west, teal at the lit
	# channel), on rock ledges in lk_harbour (kit_add_r20.py H_GLOW).
	# Fog filling each channel past its bend: the ferry will go into it (step 2).
	_channel_fog("LitFog", Vector3(30.0, W + 3.0, -88.0), Vector3(34.0, 8.0, 22.0), 0.785)
	_channel_fog("DarkFog", Vector3(-40.0, W + 1.5, -60.0), Vector3(16.0, 4.0, 26.0), 0.35)
	_put(K + "lk_back_wall.tscn", "BackWall", _at(-55.0, 0.0, -8.0))


## A bank of fog in a channel, thick enough to hide where it ends.
func _channel_fog(node_name: String, at: Vector3, size: Vector3, yaw: float) -> void:
	var fog := FogVolume.new()
	fog.name = node_name
	fog.size = size
	fog.transform = Transform3D(Basis(Vector3.UP, yaw), at)
	var fm := FogMaterial.new()
	fm.density = 0.5
	fm.albedo = Color(0.42, 0.48, 0.6)
	fm.edge_fade = 0.6
	fog.material = fm
	_add(fog)


## The quay (X -6..10, Z -7..-16), its steps in X -2..2, the wading shelf in
## front, the boardwalk west to the boathouses, the step and corner lanterns.
func _quay() -> void:
	_group("Quay")
	_put(K + "lk_quay.tscn", "Quay", _at(-6.0, 0.0, -8.0))
	_put(K + "lk_shelf.tscn", "Shelf", _at(-6.0, 0.0, -16.0))
	for i: int in 3:
		_put(K + "lk_boardwalk_4m.tscn", "Boardwalk_%d" % i, _at(-18.0 + 4.0 * i, 0.0, -8.0))
	_put(K + "lk_lantern_post.tscn", "StepLanternW", _at(-2.75, 0.0, -12.0))
	_put(K + "lk_lantern_post.tscn", "StepLanternE", _at(2.75, 0.0, -12.0, PI))
	_put(K + "lk_lantern_post.tscn", "CornerLantern", _at(9.55, 0.0, -15.55, PI / 2.0))
	_put(K + "lk_lantern_post.tscn", "BoardwalkLantern", _at(-12.0, 0.0, -7.25, PI / 2.0))
	_put(K + "lk_crates.tscn", "QuayCrates", _at(4.6, 0.0, -9.0, 0.3))
	_terrace()


## Walk 1 ("a resting/hearth area", "fishing areas"): a stone terrace off the
## quay's east end (X 10..16, Z -8..-14) with a working hearth (it warms you
## and you can cook at it, as a stacks niche's), bedrolls and a fishing spot.
func _terrace() -> void:
	_put(K + "lk_terrace.tscn", "Terrace", _at(10.0, 0.0, -8.0))
	_put("res://kit/dressing/niche_hearth.tscn", "Hearth", _at(12.8, 0.0, -11.0, PI))
	_put("res://kit/modules/camp/camp_bedroll.tscn", "Bedroll", _at(15.0, 0.0, -10.2, PI / 2.0))
	_put("res://kit/modules/camp/camp_bedroll.tscn", "Bedroll2", _at(15.1, 0.0, -12.0, PI / 2.0 + 0.15))
	_put(K + "lk_crates.tscn", "TerraceCrates", _at(10.5, 0.0, -8.7, -0.2))
	_fishing("TerraceFishing", _at(12.2, 0.0, -14.0))
	_marker("SafeTerrace", "lake_safe", _at(12.8, 0.05, -13.0))


## A fishing spot (lk_fishing_spot: stool, rod, line in the water): its
## water toward its -Z. Group fishing_spot, for fishing later.
func _fishing(node_name: String, xform: Transform3D) -> void:
	var n: Node3D = _put(K + "lk_fishing_spot.tscn", node_name, xform)
	n.add_to_group("fishing_spot", true)


## The pier off the quay's east bay (X 7..9) out to Z -36, its head and stage
## (Z -36..-41), its lanterns and the bell for the ferry.
func _pier() -> void:
	_group("Pier")
	for j: int in 5:
		_put(K + "lk_pier_4m.tscn", "Pier_%d" % j, _at(7.0, 0.0, -16.0 - 4.0 * j))
	_put(K + "lk_pier_head.tscn", "PierHead", _at(6.0, 0.0, -36.0))
	_put(K + "lk_lantern_post.tscn", "PierLantern_0", _at(8.9, 0.0, -20.0))
	_put(K + "lk_lantern_post.tscn", "PierLantern_1", _at(7.1, 0.0, -25.0, PI))
	_put(K + "lk_lantern_post.tscn", "PierLantern_2", _at(8.9, 0.0, -30.0))
	_put(K + "lk_lantern_post.tscn", "PierLantern_3", _at(7.1, 0.0, -34.8, PI))
	_put(K + "lk_lantern_post.tscn", "HeadLanternW", _at(6.15, 0.0, -37.8, PI))
	_put(K + "lk_lantern_post.tscn", "HeadLanternE", _at(9.85, 0.0, -37.8))
	var bell: Node3D = _put(K + "lk_bell.tscn", "Bell", _at(9.7, 0.0, -36.4, PI / 2.0))
	bell.add_to_group("lake_bell", true)
	bell.set_meta("stop", "quay")
	_fishing("PierFishing", _at(7.02, 0.0, -28.0, PI / 2.0))
	# Step 3 (the brief's story line): the ferry's board at the pier head (its
	# words, where the ferry goes, from the ferry table: LakeFerry), and the
	# dark channel's, out of the water at its half-flooded mouth.
	_board("FerryBoard", _at(6.35, 0.0, -37.2, PI), "", 1.0, 40, 0.7)     # four names: a low notice board under the pier-head lamp
	_board("DarkBoard", _at(-16.6, W - 0.5, -34.6, -2.29), "Flooded.\nNo passage.")


## Three boathouses on piles off the boardwalk (X -18..-6, Z -10..-18), their
## doors on the boardwalk, open to the lake. Which are lit is LakeLife's.
func _boathouses() -> void:
	_group("Boathouses")
	for i: int in 3:
		var b: Node3D = _put(K + "lk_boathouse.tscn", "Boathouse_%d" % i, _at(-18.0 + 4.0 * i, 0.0, -10.0))
		b.add_to_group("lake_boathouse", true)
	# Walk 4: flat roofs used as store decks (deck top 3.04 m), a different
	# load on each: module x 0..4 -> Godot x, module y 0..8 -> Godot -z.
	var top: float = 3.04
	_put(K + "lk_crates.tscn", "RoofCrates_0", _at(-17.6, top, -11.0, 0.2))
	_put(K + "lk_traps.tscn", "RoofTraps_0", _at(-16.2, top, -15.6, 1.1))
	_put(K + "lk_nets.tscn", "RoofNets_1", _at(-13.0, top, -12.0, PI / 2.0))
	_put(K + "lk_crates.tscn", "RoofCrates_1", _at(-13.5, top, -16.4, -0.3))
	_put(K + "lk_crates.tscn", "RoofCrates_2", _at(-9.4, top, -13.2, 1.7))
	_put(K + "lk_traps.tscn", "RoofTraps_2", _at(-8.2, top, -10.9, -0.6))


## Harbour walk 4 ("occasional water drips around the area"): seep water
## dripping from the roof (StackDrips: a thin line of drops, splashes where
## they land), mostly over open water, a few onto the quay. Each drop falls
## from the roof found straight above it in the harbour's rock.
func _drips() -> void:
	_group("Drips")
	var harbour: Node = _room.get_node("Cavern/Harbour")
	var rock := harbour.find_child("lk_harbour__rock", true, false) as MeshInstance3D
	var xf: Transform3D = Transform3D.IDENTITY
	var n: Node = rock
	while n != _room:
		if n is Node3D:
			xf = (n as Node3D).transform * xf
		n = n.get_parent()
	var faces: PackedVector3Array = rock.mesh.get_faces()
	for i: int in faces.size():
		faces[i] = xf * faces[i]
	var spots: Array[Vector3] = [Vector3(5.6, 0.0, -10.2), Vector3(-4.8, 0.0, -14.6), Vector3(12.6, 0.0, -9.4),
			Vector3(-1.2, 0.0, -9.6)]
	var rng := RandomNumberGenerator.new()
	rng.seed = 2018
	var tries: int = 0
	while spots.size() < 18 and tries < 400:
		tries += 1
		var p := Vector3(rng.randf_range(-24.0, 22.0), W, rng.randf_range(-52.0, -2.0))
		if p.x > -21.0 and p.x < 16.0 and p.z > -19.0:
			continue                    # the quay strip: its own spots above
		if p.x > 4.5 and p.x < 11.5 and p.z > -43.0:
			continue                    # the pier and its boats
		spots.append(p)
	var k: int = 0
	for p: Vector3 in spots:
		var roof: float = INF
		for i: int in range(0, faces.size(), 3):
			var hit: Variant = Geometry3D.ray_intersects_triangle(p, Vector3.UP, faces[i], faces[i + 1], faces[i + 2])
			if hit != null:
				roof = minf(roof, (hit as Vector3).y)
		var fall: float = roof - p.y
		if fall < 1.5 or fall > 10.0:
			continue
		var d := StackDrips.new()
		d.name = "Drip_%d" % k
		d.position = p
		d.drop_height = fall - 0.1
		d.drops = 2
		d.splashes = 4
		d.radius = 0.15
		_add(d)
		k += 1
	print("build_lake: %d drips" % k)


func _water() -> void:
	_group("Water")
	var mi := MeshInstance3D.new()
	mi.name = "Lake"
	var plane := PlaneMesh.new()
	plane.size = Vector2(104.0, 110.0)
	mi.mesh = plane
	mi.position = Vector3(0.0, W, -49.0)
	mi.material_override = load("res://kit/materials/lake_water.tres")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add(mi)
	# Low mist over the water, thickest at the surface.
	var mist := FogVolume.new()
	mist.name = "Mist"
	mist.size = Vector3(100.0, 3.6, 106.0)
	mist.position = Vector3(0.0, W + 1.2, -49.0)
	var fm := FogMaterial.new()
	fm.density = 0.085
	fm.albedo = Color(0.5, 0.62, 0.74)
	fm.height_falloff = 0.9
	fm.edge_fade = 0.25
	mist.material = fm
	_add(mist)


# ------------------------------------------------------------------ the landings

## The pieces of a landing's facade, storey by storey: [y, first u, pieces];
## "arch" is the sealed door (kit arch + SealedDoor), "" a gap.
const FACADES: Dictionary = {
	"mahaleh": [
		[0.0, -14.0, ["persian_wall_plaster_window", "persian_wall_plaster_window_dark", "persian_wall_plaster", "arch",
			"persian_wall_plaster_door", "persian_wall_plaster_window", "persian_wall_lime_window2"]],
		[4.0, -12.0, ["persian_wall_plaster_window2", "persian_wall_banai_window2", "persian_wall_plaster_window",
			"persian_wall_tile_window", "persian_wall_plaster_window2_dark", "persian_wall_plaster_window"]],
		[8.0, -8.0, ["persian_wall_banai_window", "persian_wall_plaster_window2", "persian_wall_lime_window", "persian_wall_plaster"]],
	],
	"gardens": [
		[0.0, -10.0, ["persian_wall_lime", "persian_wall_lime_window_dark", "arch", "persian_wall_lime_window_dark", "persian_wall_lime"]],
		[4.0, -8.0, ["persian_wall_lime_window2_dark", "persian_wall_lime", "persian_wall_lime", "persian_wall_lime_window2_dark"]],
	],
	"forgotten": [
		[0.0, -10.0, ["persian_wall_rock", "persian_wall_rock_window_dark", "arch", "persian_wall_rock_window_dark", "persian_wall_rock"]],
		[4.0, -6.0, ["persian_wall_rock_window_dark", "", "persian_wall_rock"]],
	],
	"dark": [
		[0.0, -6.0, ["persian_wall_rock", "persian_wall_rock_door_dark", "persian_wall_rock"]],
	],
	# Step 3: the plain cave dock's door in a short dressed wall.
	"default": [
		[0.0, -6.0, ["persian_wall_rock", "arch", "persian_wall_rock"]],
	],
}


## A dock (revised phase step 2): the dock chamber (lk_dock_a) in the dock's
## frame, its water, mist and the fog in its channel, and the landing's
## dressing (its house front, quay, bell) standing in it. Hidden while you are
## elsewhere (LakeFerry.set_place).
func _dock(id: String) -> void:
	var f: Transform3D = LakeLayout.dock_frame(id)
	var root := _group("Dock_" + id, _group_or("Docks"))
	root.transform = f
	_put(K + "lk_dock_a.tscn", "Rock", Transform3D.IDENTITY)
	var mi := MeshInstance3D.new()
	mi.name = "Water"
	var plane := PlaneMesh.new()
	plane.size = Vector2(74.0, 74.0)
	mi.mesh = plane
	mi.position = Vector3(-10.0, W, -26.0)
	mi.material_override = load("res://kit/materials/lake_water.tres")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add(mi)
	var mist := FogVolume.new()
	mist.name = "Mist"
	mist.size = Vector3(72.0, 3.6, 72.0)
	mist.position = Vector3(-10.0, W + 1.2, -26.0)
	var fm := FogMaterial.new()
	fm.density = 0.085
	fm.albedo = Color(0.5, 0.62, 0.74)
	fm.height_falloff = 0.9
	fm.edge_fade = 0.25
	mist.material = fm
	_add(mist)
	# The fog filling each channel past its bend, as the harbour's.
	for m: int in 2:
		var ch: Array = LakeLayout.DOCK_CHANNELS[m]
		var last: Vector3 = ch[-1]
		var prev: Vector3 = ch[-2]
		_channel_fog("ChannelFog_%d" % m, Vector3(last.x + 2.0 * signf(last.x), W + 3.0, last.z), Vector3(22.0, 8.0, 26.0), atan2(-(last - prev).x, -(last - prev).z))
	_parent = root
	_landing(str(LakeLayout.STYLES[id][3]), root, true)
	_parent = root
	_dock_life(id)
	# The painted board naming the destination this dock serves (LakeFerry.dress
	# sets its words), on a post at the stage's west corner, read from the water.
	_parent = root
	_board("Sign", Transform3D(Basis(), Vector3(-5.9, 0.0, -2.6)), "")
	_parent = _room


## A painted board on a post, its words (Label3D) toward -Z of `xform`.
func _board(node_name: String, xform: Transform3D, words: String, tall: float = 0.62, font: int = 56, low: float = 1.54) -> Node3D:
	var root := Node3D.new()
	root.name = node_name
	root.transform = xform
	_add(root)
	var wood: Material = load("res://kit/materials/persian_wood.tres")
	var post := MeshInstance3D.new()
	post.name = "Post"
	var pm := BoxMesh.new()
	pm.size = Vector3(0.12, low + 0.04 + tall, 0.12)
	post.mesh = pm
	post.position = Vector3(0.0, (low + 0.04 + tall) * 0.5, 0.0)
	post.material_override = wood
	root.add_child(post)
	post.owner = _room
	var board := MeshInstance3D.new()
	board.name = "Board"
	var bm := BoxMesh.new()
	bm.size = Vector3(1.9, tall, 0.06)
	board.mesh = bm
	board.position = Vector3(0.0, low + tall * 0.5, -0.09)
	board.material_override = wood
	root.add_child(board)
	board.owner = _room
	var label := Label3D.new()
	label.name = "Words"
	label.text = words
	label.font_size = font
	label.outline_size = 0
	label.pixel_size = 0.0045
	label.modulate = Color(0.93, 0.84, 0.62)
	label.width = 1.8 / 0.0045
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Label3D reads from its +Z side: turned to read from the water (-Z).
	label.transform = Transform3D(Basis(Vector3.UP, PI), Vector3(0.0, low + tall * 0.5, -0.13))
	root.add_child(label)
	label.owner = _room
	return root


func _landing(id: String, root: Node3D, dock: bool = false) -> void:
	var f: Transform3D = root.transform
	_parent = root
	var stop: bool = dock or bool(LakeLayout.LANDINGS[id][3])
	var sunk: float = 0.0 if stop else -0.7
	_put(K + "lk_landing_quay.tscn", "Quay", Transform3D(Basis(Vector3.RIGHT, deg_to_rad(2.5) if not stop else 0.0), Vector3(-5.0, sunk, 0.0)))
	var turned := Basis(Vector3.UP, PI)
	var grotto: bool = not dock and LakeLayout.GROTTOS.has(id)
	if grotto:
		# Walk 1: the door stands at the back of a natural grotto cut into the
		# cavern wall (lk_cavern: its rock walls and floor collide).
		var gy: float = float(LakeLayout.GROTTOS[id])
		var back: float = LakeLayout.GROTTO_BACK - 0.25
		_put(K + "wall_arch_3m.tscn", "Arch", _at(-2.0, gy, back))
		var gdoor := SealedDoor.new()
		gdoor.name = "Door"
		gdoor.transform = Transform3D(turned, Vector3(0.0, gy, back))
		_add(gdoor)
	for storey: Array in ([] if grotto else FACADES[id]):
		var y: float = storey[0]
		var u: float = storey[1]
		for piece: String in storey[2]:
			if piece == "arch":
				_put(K + "wall_arch_3m.tscn", "Arch", _at(u, y, 0.0))
				var door := SealedDoor.new()
				door.name = "Door"
				door.transform = Transform3D(turned, Vector3(u + 2.0, y, 0.0))
				_add(door)
			elif piece != "":
				# The Persian walls' room side is -Z: turned, their street face looks at the lake.
				_put(P + piece + ".tscn", "%s_%d_%d" % [piece.trim_prefix("persian_wall_"), int(y), int(u)], Transform3D(turned, Vector3(u + 4.0, y, 0.0)))
			u += 4.0
		# A cornice along the top of each storey (the piece carries its own 3.45 m
		# rise: it is placed at the storey's foot; step 4 found it floating a storey up).
		var top: float = y + 4.0
		var u0: float = storey[1]
		for k: int in (storey[2] as Array).size():
			if (storey[2] as Array)[k] != "":
				_put(P + "persian_cornice.tscn", "Cornice_%d_%d" % [int(top), k], Transform3D(turned, Vector3(u0 + 4.0 * k + 4.0, y, 0.0)))
	# The facade stops you where its walls are (they are scenery): the ground
	# storey either side of the door.
	var half: float = float(LakeLayout.LANDINGS[id][1]) if LakeLayout.LANDINGS.has(id) else 6.0
	if not grotto:
		_box_body("FacadeW", Vector3(half - 2.0, 4.0, 0.6), Transform3D(Basis.IDENTITY, Vector3(-(half + 2.0) / 2.0, 2.0 + sunk, 0.3)))
		_box_body("FacadeE", Vector3(half - 2.0, 4.0, 0.6), Transform3D(Basis.IDENTITY, Vector3((half + 2.0) / 2.0, 2.0 + sunk, 0.3)))
	match id:
		"mahaleh":
			_put(K + "lk_lantern_post.tscn", "LanternW", _at(-4.4, 0.0, -2.2))
			_put(K + "lk_lantern_post.tscn", "LanternE", _at(4.4, 0.0, -2.2, PI))
			_put(P + "persian_lamp_bracket.tscn", "DoorLamp", Transform3D(turned, Vector3(0.0, 3.4, -0.05)))
			_put(P + "persian_dome_small.tscn", "Dome", Transform3D(turned, Vector3(2.0, 12.0, 4.0)))
			_put(P + "persian_awning.tscn", "Awning", Transform3D(turned, Vector3(10.0, 3.0, 0.0)))
			var who: Array = [["bz_fig_a", -3.0, -1.4, 0.4], ["bz_fig_c", -2.2, -1.8, -0.6], ["bz_fig_e", 3.4, -1.2, 2.6], ["qt_fig_sit", 4.3, -0.6, PI]]
			for w: Array in who:
				_put(K + str(w[0]) + ".tscn", str(w[0]), _at(float(w[1]), 0.0, float(w[2]), float(w[3])))
			_put(K + "lk_crates.tscn", "Crates", _at(-4.4, 0.0, -0.9, 0.2))
			_marker("BoatW", "lake_boat_slot", _at(-7.2, W, -4.2, PI / 2.0 + 0.1), {"always": true, "lantern": true})
			_marker("BoatE", "lake_boat_slot", _at(7.4, W, -3.8, PI / 2.0 - 0.15), {"always": true})
			_glow_points([Vector3(-12.0, 2.2, -0.1), Vector3(6.0, 2.2, -0.1), Vector3(-10.0, 6.2, -0.1), Vector3(-6.0, 6.2, -0.1),
				Vector3(-2.0, 6.2, -0.1), Vector3(6.0, 6.2, -0.1), Vector3(-6.0, 10.2, -0.1), Vector3(-2.0, 10.2, -0.1), Vector3(2.0, 10.2, -0.1)])
		"gardens":
			var shaft := LightShaft.new()
			shaft.name = "Daylight"
			# The crack is in the lake's frame; the landing's root is turned.
			if dock:
				# Step 3: a thin fall of daylight from a crack high in the alcove
				# over the garden front.
				shaft.transform = Transform3D(Basis.IDENTITY, Vector3(-1.0, 0.0, -1.5))
				shaft.height = 18.0
				shaft.radius = 6.0     # step 4: 4.5 / 9 hardly showed
				shaft.energy = 14.0
			else:
				shaft.transform = Transform3D(Basis.IDENTITY, f.affine_inverse() * LakeLayout.CRACK)
				shaft.height = LakeLayout.CRACK.y + 0.5
				shaft.radius = 9.0
				shaft.energy = 14.0
			shaft.haze = 0.07
			_add(shaft)
			_put(P + "persian_bed.tscn", "BedW", _at(-3.4, 0.0, -1.3))
			_put(P + "persian_bed.tscn", "BedE", _at(3.4, 0.0, -1.3))
			_put(P + "persian_pomegranate.tscn", "TreeW", _at(-4.3, 0.0, -0.5))
			_put(P + "persian_pomegranate.tscn", "TreeE", _at(4.6, 0.0, -0.6, 1.3))
			# A lamp by the door at the grotto's back, so its mouth reads from the water.
			_put(P + "persian_lamp_bracket.tscn", "DoorLamp", Transform3D(turned, Vector3(2.6, 3.0, -0.05 if dock else LakeLayout.GROTTO_BACK - 0.3)))
			_marker("Boat", "lake_boat_slot", _at(-7.0, W, -3.6, PI / 2.0), {"always": true})
		"default":
			# Step 3: the plain cave dock, for a destination no style suits.
			_put(K + "lk_lantern_post.tscn", "LanternW", _at(-4.4, 0.0, -2.2))
			_put(K + "lk_lantern_post.tscn", "LanternE", _at(4.4, 0.0, -2.2, PI))
			_put(K + "lk_crates.tscn", "Crates", _at(-4.2, 0.0, -0.9, 0.2))
			_put(K + "lk_traps.tscn", "Traps", _at(6.5, 0.0, -1.5, 0.7))
			_marker("Boat", "lake_boat_slot", _at(7.2, W, -4.0, PI / 2.0 - 0.1), {"always": true})
		"forgotten":
			_put(K + "lk_lantern_post.tscn", "Lantern", _at(3.9, 0.0, -2.0, PI))
			# Ride 1 of step 3: the heap lay over the steps and stage (it was placed
			# for the old sunk landing); on the dock it lies on the strip west of the
			# quay, on its own level, and nothing stands behind the house front.
			_put(K + "lk_rubble.tscn", "Rubble", _at(-12.0, 0.0, 0.3, 0.0) if dock else _at(-5.0, 0.0, -2.5, 0.2))
			if not dock:
				_put(K + "lk_rubble.tscn", "RubbleIn", _at(-0.5, 0.0, 6.5, -0.4))
			_fishing("Fishing", _at(-5.0, 0.0, -1.2, PI / 2.0))
		"dark":
			_put(K + "lk_rubble.tscn", "Rubble", _at(-3.0, sunk, -2.8, 0.5))
			var boat: Node3D = _put(K + "lk_boat.tscn", "SunkBoat", Transform3D(
				Basis(Vector3.UP, 1.2) * Basis(Vector3.RIGHT, deg_to_rad(16.0)) * Basis(Vector3.BACK, deg_to_rad(28.0)), Vector3(2.0, W - 0.35, -5.5)))
			boat.set_meta("sunk", true)
	if stop:
		var bell: Node3D = _put(K + "lk_bell.tscn", "Bell", _at(4.3, 0.0, -1.0, PI))
		bell.add_to_group("lake_bell", true)
		bell.set_meta("stop", "quay" if not dock else "")
		if dock:
			bell.set_meta("style", String(root.name).trim_prefix("Dock_"))
		_marker("Safe", "lake_safe", _at(0.0, LakeLayout.STAGE + 0.05, -4.6))
	_parent = _room


func _group_or(node_name: String) -> Node3D:
	var n: Node3D = _room.get_node_or_null(node_name) as Node3D
	return n if n != null else _group(node_name)


## Lit windows on a landing: the water doubles them (LakeLife streaks).
func _glow_points(points: Array) -> void:
	for i: int in points.size():
		_marker("Window_%d" % i, "lake_reflect", Transform3D(Basis.IDENTITY, points[i]), {"color": Color(1.0, 0.72, 0.42), "strength": 0.55})


## Moored boats' places (LakeLife picks some by seed), and where a fall into
## the water puts you back.
func _markers() -> void:
	_group("Markers")
	var slots: Array = [
		[6.05, -21.5, 0.0], [6.05, -28.5, 0.05], [6.05, -33.4, -0.04], [9.95, -24.0, 0.0], [9.95, -31.6, 0.06],
		[-12.4, -21.2, PI / 2.0 + 0.1], [-3.6, -21.8, -0.2], [-15.45, -14.6, 0.0], [-11.45, -14.6, 0.0], [-7.45, -14.6, 0.0],
	]
	for i: int in slots.size():
		var s: Array = slots[i]
		_marker("BoatSlot_%d" % i, "lake_boat_slot", _at(float(s[0]), W, float(s[1]), float(s[2])),
			{"lantern": i in [1, 3, 5, 6], "inside": i >= 7})
	_marker("SafeSteps", "lake_safe", _at(0.0, 0.05, -11.0))
	_marker("SafeShelf", "lake_safe", _at(-4.0, W - 0.4, -16.5))
	_marker("SafeStage", "lake_safe", _at(8.0, LakeLayout.STAGE + 0.05, -39.6))
	_marker("SafeBoardwalk", "lake_safe", _at(-12.0, 0.05, -8.6))


# ------------------------------------------------------------------ dock life (step 4)

const DR: String = "res://kit/modules/dressing/"


## Step 4: what each dock may hold, shown or not by world seed (LakeLife._seeded):
## a group in "lake_seeded" stays with `chance`; of those sharing a `one_of`,
## exactly one stays. Moored boats' extra places by seed (pool: the style).
func _dock_life(style: String) -> void:
	if style != "ruin":     # the strips either side, lit at their ends (the ruin keeps to its fungi)
		_put(K + "lk_lantern_post.tscn", "StripLanternW", _at(-11.2, 0.0, -2.75, -PI / 2.0))
		_put(K + "lk_lantern_post.tscn", "StripLanternE", _at(11.2, 0.0, -2.75, -PI / 2.0))
	match style:
		"town":
			# A fisher mending at one end of the strip or the other, his gear by him.
			for side: Array in [["FisherW", -8.8, -0.4], ["FisherE", 8.6, 0.4]]:
				var g: Node3D = _seeded(str(side[0]), _at(float(side[1]), 0.0, -1.7, PI + float(side[2])), 1.0, "town_fisher")
				_put(K + "qt_fig_mend.tscn", "Fisher", Transform3D.IDENTITY)
				_put(K + "lk_nets.tscn", "Nets", _at(1.3, 0.0, 0.6, PI / 2.0))     # edge-on to the water
				_put(K + "lk_traps.tscn", "Traps", _at(-1.4, 0.0, 0.7, 1.1))
				_parent = g.get_parent() as Node3D
			_seeded("Pots", _at(-13.5, 0.0, -0.9, 0.4), 0.6)
			_put(DR + "prop_pot.tscn", "Pot", Transform3D.IDENTITY)
			_put(DR + "prop_pot.tscn", "Pot2", _at(0.6, 0.0, 0.2, 1.0))
			_parent = _parent.get_parent() as Node3D
			_seeded("Crates2", _at(13.0, 0.0, -1.0, -0.3), 0.6)
			_put(K + "lk_crates.tscn", "Crates", Transform3D.IDENTITY)
			_parent = _parent.get_parent() as Node3D
			_slots(style, [[-12.3, -4.1, PI / 2.0 + 0.05], [12.3, -4.1, PI / 2.0 - 0.08]], 2)     # 4.4 m boats beside the fixed ones at x 7.2
		"garden":
			# Beds and pots along the strip, a gardener with a jar, a line in the water.
			var beds: Array = [["BedW2", "garden_planter", -8.4, -1.2, 0.0], ["BedW3", "garden_planter_wild", -12.6, -1.3, 0.1],
				["ShrubE", "garden_shrub", 8.6, -1.0, 0.0], ["BedE2", "garden_planter", 12.4, -1.2, -0.1], ["ShrubW", "garden_shrub", -15.8, -1.0, 0.7]]
			for b: Array in beds:
				_seeded(str(b[0]), _at(float(b[2]), 0.0, float(b[3]), float(b[4])), 0.65)
				_put(DR + str(b[1]) + ".tscn", "Bed", Transform3D.IDENTITY)
				_parent = _parent.get_parent() as Node3D
			_seeded("Gardener", _at(-6.6, 0.0, -1.9, PI - 0.5), 0.5)
			_put(K + "qt_fig_jar.tscn", "Figure", Transform3D.IDENTITY)
			_parent = _parent.get_parent() as Node3D
			_seeded("Line", _at(-9.6, 0.0, -2.55), 0.5)
			_fishing("Fishing", Transform3D.IDENTITY)
			_parent = _parent.get_parent() as Node3D
			_slots(style, [[7.2, -4.1, PI / 2.0 - 0.1], [12.3, -4.1, PI / 2.0 + 0.1]], 1)
		"ruin":
			# Nobody: a boat sunk at its mooring, broken jars, fallen stone.
			for side: Array in [["SunkW", -8.4, -5.0, 1.2], ["SunkE", 8.8, -5.4, -1.9]]:
				var sunk: Node3D = _seeded(str(side[0]), _at(float(side[1]), 0.0, float(side[2]), float(side[3])), 1.0, "ruin_sunk")
				var boat: Node3D = _put(K + "lk_boat.tscn", "Boat", Transform3D(
					Basis(Vector3.RIGHT, deg_to_rad(14.0)) * Basis(Vector3.BACK, deg_to_rad(26.0)), Vector3(0.0, W - 0.35, 0.0)))
				boat.set_meta("sunk", true)
				_parent = sunk.get_parent() as Node3D
			_seeded("Jars", _at(6.4, 0.0, -1.0, 0.6), 0.7)
			_put(DR + "prop_vase_floor_broken.tscn", "Jar", Transform3D.IDENTITY)
			_put(DR + "prop_vase_floor_broken.tscn", "Jar2", _at(0.7, 0.0, 0.3, 2.0))
			_parent = _parent.get_parent() as Node3D
			_seeded("Fallen", _at(8.6, 0.0, -1.6, 0.9), 0.7)
			_put(DR + "debris_rubble.tscn", "Rubble", Transform3D.IDENTITY)
			_parent = _parent.get_parent() as Node3D
		"default":
			_seeded("Sitter", _at(-9.0, 0.0, -1.3, PI + 0.3), 0.5)
			_put(K + "qt_fig_sit.tscn", "Figure", Transform3D.IDENTITY)
			_parent = _parent.get_parent() as Node3D
			_slots(style, [[-7.2, -4.1, PI / 2.0 + 0.1], [12.3, -4.1, PI / 2.0]], 1)


## A seeded group at `xform` under the current parent; it becomes the parent.
func _seeded(node_name: String, xform: Transform3D, chance: float, one_of: String = "") -> Node3D:
	var up: Node3D = _parent
	var g := Node3D.new()
	g.name = node_name
	g.transform = xform
	_add(g)
	g.add_to_group("lake_seeded", true)
	g.set_meta("chance", chance)
	if one_of != "":
		g.set_meta("one_of", one_of)
	_parent = g
	assert(up != null)
	return g


## Extra moored boats' places at a dock: up to `most` of them by seed.
func _slots(style: String, spots: Array, most: int) -> void:
	for i: int in spots.size():
		var s: Array = spots[i]
		_marker("BoatSeed_%d" % i, "lake_boat_slot", _at(float(s[0]), W, float(s[1]), float(s[2])), {"pool": style, "most": most})

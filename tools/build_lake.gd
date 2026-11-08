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
	for id: String in LakeLayout.DOCKS:
		_dock(id)
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
	# The fog filling the channel past its bend, as the harbour's.
	var last: Vector3 = LakeLayout.DOCK_CHANNEL[-1]
	var prev: Vector3 = LakeLayout.DOCK_CHANNEL[-2]
	_channel_fog("ChannelFog", Vector3(last.x + 2.0, W + 3.0, last.z), Vector3(22.0, 8.0, 26.0), atan2(-(last - prev).x, -(last - prev).z))
	_parent = root
	_landing(id, root)


func _landing(id: String, root: Node3D) -> void:
	var f: Transform3D = root.transform
	_parent = root
	var stop: bool = bool(LakeLayout.LANDINGS[id][3])
	var sunk: float = 0.0 if stop else -0.7
	_put(K + "lk_landing_quay.tscn", "Quay", Transform3D(Basis(Vector3.RIGHT, deg_to_rad(2.5) if not stop else 0.0), Vector3(-5.0, sunk, 0.0)))
	var turned := Basis(Vector3.UP, PI)
	if LakeLayout.GROTTOS.has(id):
		# Walk 1: the door stands at the back of a natural grotto cut into the
		# cavern wall (lk_cavern: its rock walls and floor collide).
		var gy: float = float(LakeLayout.GROTTOS[id])
		var back: float = LakeLayout.GROTTO_BACK - 0.25
		_put(K + "wall_arch_3m.tscn", "Arch", _at(-2.0, gy, back))
		var gdoor := SealedDoor.new()
		gdoor.name = "Door"
		gdoor.transform = Transform3D(turned, Vector3(0.0, gy, back))
		_add(gdoor)
	for storey: Array in ([] if LakeLayout.GROTTOS.has(id) else FACADES[id]):
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
		# A cornice along the top of each storey.
		var top: float = y + 4.0
		var u0: float = storey[1]
		for k: int in (storey[2] as Array).size():
			if (storey[2] as Array)[k] != "":
				_put(P + "persian_cornice.tscn", "Cornice_%d_%d" % [int(top), k], Transform3D(turned, Vector3(u0 + 4.0 * k + 4.0, top, 0.0)))
	# The facade stops you where its walls are (they are scenery): the ground
	# storey either side of the door.
	var half: float = float(LakeLayout.LANDINGS[id][1])
	if not LakeLayout.GROTTOS.has(id):
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
			_put(P + "persian_lamp_bracket.tscn", "DoorLamp", Transform3D(turned, Vector3(2.6, 3.0, LakeLayout.GROTTO_BACK - 0.3)))
			_marker("Boat", "lake_boat_slot", _at(-7.0, W, -3.6, PI / 2.0), {"always": true})
		"forgotten":
			_put(K + "lk_lantern_post.tscn", "Lantern", _at(3.9, 0.0, -2.0, PI))
			_put(K + "lk_rubble.tscn", "Rubble", _at(-5.0, 0.0, -2.5, 0.2))
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
		bell.set_meta("stop", id)
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

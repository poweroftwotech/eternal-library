class_name ZooRoom
extends RoomTemplate
## The zoo (after phase 19): a test place where every animal is a few steps
## away. A corridor with pens off both sides; each pen gives one habitat its
## ideal conditions and counts as a room of its own to the animals' director
## (Fauna), with a room type and a state, so the game's real placement rules
## run unchanged. It is built in code from plain boxes in the kit's materials
## and a few kit props, so a pen is a dozen lines (PENS and its _pen_* maker).
##
## In it: F4 the overlay (FaunaOverlay), F5 the tuning panel (ZooPanel).
## Get there: the Strata Board's "Walk the zoo", or run the game with
## --room=zoo. It is not part of the world and nothing in it is saved.
##
## A new animal: put it in a pen that already suits it, or add a pen: a row
## in PENS and a _pen_<id> function that builds what it needs.
##
## Laid out on the world's 4 m cells (CellGrid): the corridor is the column
## x = 0, the pens three cells square on either side.

const SCENE: String = "res://rooms/test/zoo.tscn"
const MAT: String = "res://kit/materials/%s.tres"
const KIT: String = "res://kit/modules/dressing/%s.tscn"
const CELL: float = 4.0
const WALL: float = 0.3
## Player blockers (deep water's edge): the layer the game uses for them.
const BLOCKERS: int = 1 << 7
## The pens: id, name on its sign, who it is for, room type and state the
## animals' rules see, side (-1 left, 1 right), first cell along the corridor,
## height (m), wall and roof material.
const PENS: Array[Dictionary] = [
	{"id": "pool", "name": "Tended pool", "for": "Goldfish", "type": "R05", "state": "", "side": -1, "z": 0, "height": 4.0, "wall": "persian_plaster", "roof": "vault_plaster"},
	{"id": "cistern", "name": "Dark cistern", "for": "Cave barbs", "type": "R11", "state": "", "side": 1, "z": 0, "height": 3.0, "wall": "limestone", "roof": "limestone"},
	{"id": "lamps", "name": "Lamp wall", "for": "Candle moths, wall geckos", "type": "R01", "state": "", "side": -1, "z": 4, "height": 4.0, "wall": "persian_plaster", "roof": "vault_plaster"},
	{"id": "vault", "name": "Rock vault", "for": "Bats, glowworms", "type": "R02", "state": "", "side": 1, "z": 4, "height": 9.0, "wall": "cave_rock", "roof": "cave_rock"},
	{"id": "home", "name": "Lived-in room", "for": "Cats (and what lamps and a pool bring)", "type": "R06", "state": "", "side": -1, "z": 8, "height": 4.0, "wall": "quarter_plaster_clay", "roof": "vault_plaster"},
	{"id": "ruin", "name": "Forgotten room", "for": "Rats", "type": "R02", "state": "abandoned", "side": 1, "z": 8, "height": 4.0, "wall": "limestone", "roof": "limestone"},
]
## How many cells the corridor runs.
const LENGTH: int = 12

## What Fauna is given: [{slot, node, type, state, cells}].
var pens: Array[Dictionary] = []
var fauna: Fauna
var panel: ZooPanel
var _waters: Array[ShaderMaterial] = []
var _water_time: float = 0.0


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_corridor()
	for p: Dictionary in PENS:
		var node := Node3D.new()
		node.name = str(p["id"])
		add_child(node)
		_shell(node, p)
		call("_pen_" + str(p["id"]), node, p)
		var cells: Array = []
		for cx: int in 3:
			for cz: int in 3:
				cells.append(Vector3i(_x0(p) + cx, 0, int(p["z"]) + cz))
		pens.append({"slot": str(p["id"]), "node": node, "type": str(p["type"]), "state": str(p["state"]), "cells": cells})
	var spawn := Marker3D.new()
	spawn.name = "PlayerSpawn"
	spawn.position = Vector3(CELL * 0.5, 0.1, 1.0)
	add_child(spawn)
	var air := Atmosphere.new()
	air.name = "Atmosphere"
	air.profile = load("res://kit/atmosphere/reading_room.tres")
	add_child(air)
	super._ready()
	fauna = Fauna.attach(self, "zoo")
	panel = ZooPanel.new()
	panel.name = "Panel"
	panel.fauna = fauna
	panel.zoo = self
	add_child(panel)


## The pens, for the animals' director.
func fauna_pens() -> Array[Dictionary]:
	return pens


## A pen's first cell across (its lowest x).
static func _x0(p: Dictionary) -> int:
	return -3 if int(p["side"]) < 0 else 1


## A pen's box: its low corner (x, z) and its far corner, in metres.
static func _span(p: Dictionary) -> Rect2:
	var x: float = _x0(p) * CELL
	var z1: float = -float(p["z"]) * CELL
	return Rect2(x, z1 - 3.0 * CELL, 3.0 * CELL, 3.0 * CELL)


# --- the building --------------------------------------------------------------

## A box of `size` centred at `at`, drawn in a kit material, solid.
func _box(parent: Node3D, size: Vector3, at: Vector3, material: String, solid: bool = true, layer: int = 1) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.position = at
	if material != "":
		mi.material_override = load(MAT % material)
	else:
		mi.visible = false
	parent.add_child(mi)
	if solid:
		var body := StaticBody3D.new()
		body.collision_layer = layer
		body.collision_mask = 0
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		shape.shape = box
		body.add_child(shape)
		mi.add_child(body)
	return mi


## A wall from `a` to `b` (x, z), `height` tall from `base`.
func _wall(parent: Node3D, a: Vector2, b: Vector2, height: float, material: String, base: float = 0.0) -> void:
	var mid: Vector2 = (a + b) * 0.5
	var along: bool = absf(b.x - a.x) > absf(b.y - a.y)
	var length: float = a.distance_to(b)
	var size := Vector3(length if along else WALL, height, WALL if along else length)
	_box(parent, size, Vector3(mid.x, base + height * 0.5, mid.y), material)


func _corridor() -> void:
	var node := Node3D.new()
	node.name = "Corridor"
	add_child(node)
	var length: float = LENGTH * CELL
	_box(node, Vector3(CELL, 0.4, length + 4.0), Vector3(CELL * 0.5, -0.2, -length * 0.5 + 2.0), "floor_stone")
	_box(node, Vector3(CELL, 0.3, length + 4.0), Vector3(CELL * 0.5, 4.15, -length * 0.5 + 2.0), "vault_plaster")
	_wall(node, Vector2(0, 4.0), Vector2(CELL, 4.0), 4.0, "persian_plaster")
	_wall(node, Vector2(0, -length), Vector2(CELL, -length), 4.0, "persian_plaster")
	# Its side walls: only where no pen stands (the pens bring their own).
	for side: int in [-1, 1]:
		var x: float = 0.0 if side < 0 else CELL
		var taken: Array[int] = []
		for p: Dictionary in PENS:
			if int(p["side"]) == side:
				for k: int in 3:
					taken.append(int(p["z"]) + k)
		for cz: int in range(-1, LENGTH):
			if not taken.has(cz):
				_wall(node, Vector2(x, -cz * CELL), Vector2(x, -(cz + 1) * CELL), 4.0, "persian_plaster")
	# Even light down its length; it is no flame, so it draws no moths.
	for k: int in LENGTH / 2:
		_light(node, Vector3(CELL * 0.5, 3.4, -(k * 2 + 1) * CELL), Color(1.0, 0.95, 0.85), 1.4, 9.0, "daylight")


## A pen's floor, roof and walls, with a doorway onto the corridor in the
## middle cell, and its sign over the door.
func _shell(node: Node3D, p: Dictionary) -> void:
	var r: Rect2 = _span(p)
	var h: float = p["height"]
	var wall: String = p["wall"]
	if str(p["id"]) != "cistern":     # (the cistern lays its own floor round its basin)
		_box(node, Vector3(r.size.x, 0.4, r.size.y), Vector3(r.get_center().x, -0.2, r.get_center().y), "floor_stone")
	_box(node, Vector3(r.size.x, 0.3, r.size.y), Vector3(r.get_center().x, h + 0.15, r.get_center().y), str(p["roof"]))
	var left: bool = int(p["side"]) < 0
	var far_x: float = r.position.x if left else r.end.x
	var door_x: float = r.end.x if left else r.position.x
	_wall(node, Vector2(far_x, r.position.y), Vector2(far_x, r.end.y), h, wall)
	_wall(node, Vector2(r.position.x, r.position.y), Vector2(r.end.x, r.position.y), h, wall)
	_wall(node, Vector2(r.position.x, r.end.y), Vector2(r.end.x, r.end.y), h, wall)
	# The corridor side: a wall each side of a 3 m doorway, and over it.
	var mid: float = r.get_center().y
	_wall(node, Vector2(door_x, r.position.y), Vector2(door_x, mid - 1.5), h, wall)
	_wall(node, Vector2(door_x, mid + 1.5), Vector2(door_x, r.end.y), h, wall)
	if h > 2.6:
		_wall(node, Vector2(door_x, mid - 1.5), Vector2(door_x, mid + 1.5), h - 2.6, wall, 2.6)
	var sign := Label3D.new()
	sign.text = "%s\n%s" % [str(p["name"]).to_upper(), p["for"]]
	sign.font_size = 40
	sign.pixel_size = 0.0045
	sign.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sign.outline_size = 12
	sign.modulate = Color(0.98, 0.9, 0.7)
	sign.position = Vector3(door_x + (1.0 if left else -1.0), 3.2, mid)
	node.add_child(sign)


## A light of a kind the animals' rules read (HabitatScan: a flame profile
## draws moths and geckos and keeps bats off; "daylight" is only light; a glow
## profile is a fungus).
func _light(parent: Node3D, at: Vector3, colour: Color, energy: float, reach: float, profile: String) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = colour
	l.light_energy = energy
	l.omni_range = reach
	l.shadow_enabled = false
	l.position = at
	l.set_meta("light_profile", profile)
	parent.add_child(l)
	return l


## A lamp on a wall: a small bracket and flame, and its light. `out`: the way
## out of the wall.
func _wall_lamp(parent: Node3D, at: Vector3, out: Vector3) -> void:
	var bracket: MeshInstance3D = _box(parent, Vector3(0.12, 0.05, 0.12) + out.abs() * 0.2, at + out * 0.14 - Vector3(0, 0.1, 0), "brass", false)
	bracket.name = "lamp_bracket"
	var flame: MeshInstance3D = _box(parent, Vector3(0.05, 0.1, 0.05), at + out * 0.26, "", false)
	flame.visible = true
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color(1.0, 0.8, 0.45)
	flame.material_override = glow
	_light(parent, at + out * 0.3, Color(1.0, 0.72, 0.4), 1.6, 6.5, "sconce")


## A kit prop set down with its middle over `at` and its base on it, turned
## `yaw` (its own origin may be anywhere).
func _prop(parent: Node3D, scene: String, at: Vector3, yaw: float = 0.0) -> Node3D:
	var n: Node3D = (load(KIT % scene) as PackedScene).instantiate() as Node3D
	n.name = scene
	parent.add_child(n)
	n.rotation.y = yaw
	var box := AABB()
	var first: bool = true
	for m: Node in n.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		var b: AABB = (n.global_transform.affine_inverse() * mi.global_transform) * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	var centre: Vector3 = n.basis * Vector3(box.get_center().x, box.position.y, box.get_center().z)
	n.position = at - centre
	return n


## A pool: still water `depth` deep with its surface at `top`, in a basin of
## its own (a floor under it, a low rim round it when it stands on the floor).
func _pool(parent: Node3D, r: Rect2, top: float, depth: float, water: String, rim: bool) -> void:
	var c := Vector3(r.get_center().x, 0, r.get_center().y)
	if rim:
		_box(parent, Vector3(r.size.x, 0.05, r.size.y), c + Vector3(0, top - depth + 0.025, 0), "floor_stone")
		var h: float = top + 0.08
		for e: Array in [[Vector2(r.position.x, r.position.y), Vector2(r.end.x, r.position.y)], [Vector2(r.position.x, r.end.y), Vector2(r.end.x, r.end.y)],
				[Vector2(r.position.x, r.position.y), Vector2(r.position.x, r.end.y)], [Vector2(r.end.x, r.position.y), Vector2(r.end.x, r.end.y)]]:
			_wall(parent, e[0], e[1], h, "limestone")
	var mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(r.size.x - (WALL if rim else 0.0), r.size.y - (WALL if rim else 0.0))
	mi.mesh = plane
	mi.name = "water"
	mi.position = c + Vector3(0, top, 0)
	mi.material_override = load(MAT % water)
	if not _waters.has(mi.material_override):
		_waters.append(mi.material_override as ShaderMaterial)
	parent.add_child(mi)


# --- the pens --------------------------------------------------------------------

## Goldfish: a lit, tended hauz with a rim to stand at.
func _pen_pool(node: Node3D, p: Dictionary) -> void:
	var r: Rect2 = _span(p)
	_pool(node, Rect2(r.get_center() - Vector2(3.5, 2.5), Vector2(7.0, 5.0)), 0.45, 0.45, "hauz_water", true)
	for k: int in 2:
		_light(node, Vector3(r.get_center().x - 2.5 + k * 5.0, 3.3, r.get_center().y), Color(1.0, 0.96, 0.88), 1.8, 9.0, "daylight")


## Cave barbs: deep dark water. A walk round a sunk basin; an unseen wall at
## its edge (the game's deep-water blocker) keeps you out.
func _pen_cistern(node: Node3D, p: Dictionary) -> void:
	var r: Rect2 = _span(p)
	var basin := Rect2(r.position + Vector2(2.5, 2.5), r.size - Vector2(5.0, 5.0))
	_box(node, Vector3(r.size.x, 0.4, r.size.y), Vector3(r.get_center().x, -2.0, r.get_center().y), "limestone")
	# The walk: four slabs round the basin, from its floor up to the room's.
	for e: Rect2 in [Rect2(r.position, Vector2(r.size.x, 2.5)), Rect2(Vector2(r.position.x, r.end.y - 2.5), Vector2(r.size.x, 2.5)),
			Rect2(Vector2(r.position.x, r.position.y + 2.5), Vector2(2.5, r.size.y - 5.0)), Rect2(Vector2(r.end.x - 2.5, r.position.y + 2.5), Vector2(2.5, r.size.y - 5.0))]:
		_box(node, Vector3(e.size.x, 1.8, e.size.y), Vector3(e.get_center().x, -0.9, e.get_center().y), "floor_stone")
	_pool(node, basin, -0.25, 1.55, "cistern_water", false)
	for e: Array in [[Vector2(basin.position.x, basin.position.y), Vector2(basin.end.x, basin.position.y)], [Vector2(basin.position.x, basin.end.y), Vector2(basin.end.x, basin.end.y)],
			[Vector2(basin.position.x, basin.position.y), Vector2(basin.position.x, basin.end.y)], [Vector2(basin.end.x, basin.position.y), Vector2(basin.end.x, basin.end.y)]]:
		var a: Vector2 = e[0]
		var b: Vector2 = e[1]
		var along: bool = absf(b.x - a.x) > absf(b.y - a.y)
		_box(node, Vector3(a.distance_to(b) if along else 0.1, 2.0, 0.1 if along else a.distance_to(b)), Vector3((a.x + b.x) * 0.5, 1.0, (a.y + b.y) * 0.5), "", true, BLOCKERS)
	# A faint fungus glow, so the water can be seen; no flame, no daylight.
	_light(node, Vector3(r.get_center().x, 2.2, r.get_center().y), Color(0.45, 0.85, 0.8), 0.9, 9.0, "fungus")


## Moths and geckos: burning lamps on open flat walls.
func _pen_lamps(node: Node3D, p: Dictionary) -> void:
	var r: Rect2 = _span(p)
	var far_x: float = r.position.x + WALL * 0.5
	for k: int in 4:
		_wall_lamp(node, Vector3(far_x, 1.7, r.position.y + 1.8 + k * 2.8), Vector3(1, 0, 0))
	for k: int in 3:
		_wall_lamp(node, Vector3(r.position.x + 2.5 + k * 3.5, 1.7, r.position.y + WALL * 0.5), Vector3(0, 0, 1))
		_wall_lamp(node, Vector3(r.position.x + 2.5 + k * 3.5, 1.7, r.end.y - WALL * 0.5), Vector3(0, 0, -1))


## Bats and glowworms: a high, dark, natural rock roof. A fungus glow low
## down, far from the roof, so you can see your way.
func _pen_vault(node: Node3D, p: Dictionary) -> void:
	var r: Rect2 = _span(p)
	_light(node, Vector3(r.get_center().x, 0.5, r.get_center().y), Color(0.4, 0.8, 0.9), 0.7, 6.0, "fungus")


## Cats: somewhere lived in. Rugs, cushions, a bench and a bedroll to lie on,
## walked lanes between them, a small hauz to watch, a few lamps.
func _pen_home(node: Node3D, p: Dictionary) -> void:
	var r: Rect2 = _span(p)
	var c: Vector2 = r.get_center()
	# (rugs a hair over the floor: lying in it, the two flicker)
	_prop(node, "rug_kilim_grand", Vector3(c.x - 2.0, 0.012, c.y - 2.5))
	_prop(node, "rug_herati_small", Vector3(c.x + 3.0, 0.012, c.y + 3.5))
	_prop(node, "rug_gabbeh_small", Vector3(c.x - 3.5, 0.012, c.y + 3.5), PI * 0.5)
	for k: int in 4:
		_prop(node, "floor_cushion", Vector3(r.position.x + 1.0, 0, r.position.y + 1.5 + k * 1.3), k * 0.7)
	_prop(node, "garden_bench", Vector3(c.x + 1.0, 0, r.position.y + 0.9))
	_prop(node, "court_contents_bedroll", Vector3(r.position.x + 1.4, 0, r.end.y - 1.6))
	_pool(node, Rect2(Vector2(c.x + 1.5, c.y - 4.0), Vector2(3.0, 2.4)), 0.4, 0.4, "hauz_water", true)
	for at: Vector3 in [Vector3(r.position.x + WALL * 0.5, 1.7, c.y), Vector3(c.x, 1.7, r.end.y - WALL * 0.5)]:
		_wall_lamp(node, at, Vector3(1, 0, 0) if at.x < c.x - 1.0 else Vector3(0, 0, -1))
	_light(node, Vector3(c.x, 3.3, c.y), Color(1.0, 0.93, 0.8), 1.2, 9.0, "daylight")
	# The lanes people have walked: a loop round the room and a way to the door.
	var wear := FloorWear.new()
	wear.name = "FloorWear"
	wear.rect = Rect2(r.position, r.size)
	wear.y_range = Vector2(-0.5, 0.5)
	var loop := PackedVector2Array([Vector2(c.x - 4.5, c.y - 0.5), Vector2(c.x - 4.5, c.y + 1.5), Vector2(c.x - 0.5, c.y + 1.5), Vector2(c.x + 4.5, c.y + 1.5),
		Vector2(c.x + 4.5, c.y - 0.8), Vector2(c.x + 0.5, c.y - 0.8), Vector2(c.x - 0.5, c.y + 1.5)])
	var door_x: float = r.end.x if int(p["side"]) < 0 else r.position.x
	var paths: Array[PackedVector2Array] = [loop, PackedVector2Array([Vector2(c.x + 4.5, c.y + 0.3), Vector2(door_x, c.y)])]
	wear.paths = paths
	node.add_child(wear)


## Rats: nobody tidies here. Long bare walls and a thin cold light.
func _pen_ruin(node: Node3D, p: Dictionary) -> void:
	var r: Rect2 = _span(p)
	_light(node, Vector3(r.get_center().x, 3.2, r.get_center().y), Color(0.6, 0.7, 0.95), 1.0, 10.0, "daylight")


## The pens' water moves as the game's does: its shader's clock is run here
## (an Area runs it for its rooms; nothing else would in the zoo).
func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_water_time += delta
	for m: ShaderMaterial in _waters:
		m.set_shader_parameter("simulation_time", _water_time)

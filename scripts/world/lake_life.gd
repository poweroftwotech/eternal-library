class_name LakeLife
extends Node3D
## The Lake Landing's life (phase 18, R20): what changes by world seed and
## what moves.
##
## - The water's clock (lake_water.tres) and every lantern's reflection painted
##   on the water (Q7, shaders/lake_streak.gdshader): one streak under each light
##   of the place, moving with the ferry's, and under each lit window marked on
##   the far landings ("lake_reflect").
## - Moored boats (Q2): the landings' always, and four to six of the harbour's
##   places by seed, one or two with a lantern; they rock at their moorings.
## - The boathouses: one to three lit by seed, the fisher mending nets at a lit
##   one's door with his traps.
## - Now and then a lantern boat crosses far out between the Mahaleh and the
##   Forgotten City's landings.
## - The water's edge (Q5): wade the shelf to your knees; step past it (or off
##   any edge) and you are back on the nearest steps, with a splash and a fade.
## - Every light fades out past FADE_BEGIN, so from the quay the far landings are
##   points of glowing glass, and from a landing the quay is.

const FADE_BEGIN: float = 48.0
const FADE_LENGTH: float = 14.0
## Feet this far under the surface: you've stepped into deep water.
const DEEP: float = 0.85
const STREAK_SHADER: Shader = preload("res://shaders/lake_streak.gdshader")
const WATER_MATERIAL: ShaderMaterial = preload("res://kit/materials/lake_water.tres")
const BOAT: String = "res://kit/modules/walls/lk_boat.tscn"
## The boat's floorboards sit 0.2 m under its origin: lift it so the lake
## plane stays under them (no water inside the hull).
const FREEBOARD: float = 0.24

var seed_value: int = 1
var _rng := RandomNumberGenerator.new()
var _t: float = 0.0
## [light or marker (Node3D), streak (MeshInstance3D)]
var _streaks: Array = []
var _streak_materials: Array[ShaderMaterial] = []
## [boat (Node3D), rest (Transform3D), phase]
var _boats: Array = []
var _far_boat: Node3D
var _far_curve: Curve3D
var _far_light: OmniLight3D
var _far_clock: float = 0.0
var _fade: ColorRect
var _resetting: bool = false
var _splash: CPUParticles3D


func _ready() -> void:
	var ws: Node = get_node_or_null("/root/WorldState")
	seed_value = int(ws.call("world_seed")) if ws != null else 1
	_rng.seed = hash("lake_landing:%d" % seed_value)
	_moor_boats()
	_boathouses()
	_far_ferry()
	_wet_structures()
	var pier: Node = owner.get_node_or_null("Pier") if owner != null else null
	if pier != null:
		for l: Node in pier.find_children("*", "Light3D", true, false):
			(l as Light3D).light_energy *= PIER_LIGHT_SCALE
		# Walk 6: their panes glow lower and warmer to match.
		var dim_glass: StandardMaterial3D = null
		for mi: Node in pier.find_children("*glass*", "MeshInstance3D", true, false):
			var m: MeshInstance3D = mi as MeshInstance3D
			var src: StandardMaterial3D = m.get_active_material(0) as StandardMaterial3D
			if src == null or not src.resource_path.get_file().begins_with("emit_lantern"):
				continue
			if dim_glass == null:
				dim_glass = src.duplicate() as StandardMaterial3D
				dim_glass.albedo_color = Color(0.62, 0.36, 0.15)
			m.material_override = dim_glass
	# Lights: fade with distance; the two lanterns over the water steps cast shadows.
	for light: Light3D in _lights():
		light.distance_fade_enabled = true
		light.distance_fade_begin = FADE_BEGIN
		light.distance_fade_length = FADE_LENGTH
		light.distance_fade_shadow = FADE_BEGIN * 0.5
		if _under(light, "StepLantern"):
			light.shadow_enabled = true
	# The cavern's shell is one great mesh: in a shadow map it would be drawn
	# whole into every face. It is the outside of everything, so it casts none.
	var shell: Node = owner.get_node_or_null("Cavern") if owner != null else null
	if shell != null:
		for mi: Node in shell.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_make_streaks()
	_build_fade()
	_reach_fog.call_deferred()


## The lake is 170 m across: carry the volumetric fog the whole way so the
## far air is haze, not black.
func _reach_fog() -> void:
	var env: Environment = get_viewport().world_3d.environment if get_viewport().world_3d != null else null
	if env == null:
		var we: WorldEnvironment = (owner if owner != null else get_parent()).find_child("*Environment*", true, false) as WorldEnvironment
		env = we.environment if we != null else null
	if env != null:
		env.volumetric_fog_length = 160.0
		env.volumetric_fog_detail_spread = 1.6


## Has an ancestor whose name begins with `prefix`.
func _under(n: Node, prefix: String) -> bool:
	var a: Node = n.get_parent()
	while a != null:
		if String(a.name).begins_with(prefix):
			return true
		a = a.get_parent()
	return false


## The place's lights (the kit's, the ferry's, the moored boats').
func _lights() -> Array[Light3D]:
	var out: Array[Light3D] = []
	var room: Node = owner if owner != null else get_parent()
	for n: Node in room.find_children("*", "Light3D", true, false):
		if n is OmniLight3D or n is SpotLight3D:
			if not (n.get_parent() is LightShaft):
				out.append(n as Light3D)
	return out


# ------------------------------------------------------------------ boats

func _moor_boats() -> void:
	var room: Node = owner if owner != null else get_parent()
	var harbour: Array[Node3D] = []
	var inside: Array[Node3D] = []
	for n: Node in get_tree().get_nodes_in_group("lake_boat_slot"):
		if not room.is_ancestor_of(n):
			continue
		var m := n as Node3D
		if bool(m.get_meta("always", false)):
			_moor(m, bool(m.get_meta("lantern", false)))
		elif bool(m.get_meta("inside", false)):
			inside.append(m)
		else:
			harbour.append(m)
	_shuffle(harbour)
	var count: int = _rng.randi_range(4, 6)
	var lanterns: int = _rng.randi_range(1, 2)
	for m: Node3D in harbour.slice(0, count):
		var lit: bool = lanterns > 0 and bool(m.get_meta("lantern", false))
		if lit:
			lanterns -= 1
		_moor(m, lit)
	_shuffle(inside)
	for m: Node3D in inside.slice(0, _rng.randi_range(1, 2)):
		_moor(m, false)


func _shuffle(a: Array) -> void:
	for i: int in range(a.size() - 1, 0, -1):
		var j: int = _rng.randi_range(0, i)
		var tmp = a[i]
		a[i] = a[j]
		a[j] = tmp


func _moor(slot: Node3D, lantern: bool) -> void:
	var boat: Node3D = (load(BOAT) as PackedScene).instantiate() as Node3D
	boat.name = "Boat_" + String(slot.name)
	slot.get_parent().add_child(boat)
	boat.transform = slot.transform.translated(Vector3(0.0, FREEBOARD, 0.0))
	WorldProp.localize_materials(boat)     # it rocks: its texture rides with it
	if lantern:
		_boat_lantern(boat, Vector3(0.0, 0.0, 1.85))
	_boats.append([boat, boat.transform, _rng.randf() * TAU])


## A lantern on a short pole at the boat's stern (its +Z), with its light.
func _boat_lantern(boat: Node3D, at: Vector3) -> OmniLight3D:
	var pole := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(0.05, 1.5, 0.05)
	pole.mesh = pm
	pole.material_override = PxMaterial.get_or_create("persian_wood")
	pole.position = at + Vector3(0.0, 0.75, 0.0)
	boat.add_child(pole)
	var glass := MeshInstance3D.new()
	var gm := BoxMesh.new()
	gm.size = Vector3(0.16, 0.24, 0.16)
	glass.mesh = gm
	glass.material_override = PxMaterial.get_or_create("emit_lantern")
	glass.position = at + Vector3(0.0, 1.38, -0.12)
	boat.add_child(glass)
	var light := OmniLight3D.new()
	light.name = "Lantern"
	light.light_color = Color(1.0, 0.7, 0.36)
	light.light_energy = 1.0
	light.omni_range = 5.0
	light.omni_attenuation = 1.3
	light.position = glass.position
	light.add_to_group("kit_light")
	boat.add_child(light)
	return light


## Harbour walk 5 ("give the pier and landing a more wet look"): the quay,
## pier, boathouses and dock landings use wet copies of their stone and wood,
## set as surface overrides so the shared kit materials stay dry elsewhere.
## Stone (kit_px_world) gets the shader's wetness (darker, glossy patches);
## wood (StandardMaterial3D) is darkened and made glossier.
const WET_GROUPS: Array[String] = ["Quay", "Pier", "Boathouses", "Docks"]
const STONE_WETNESS: float = 0.8
const WOOD_WETNESS: float = 0.55
## Walk 6 ("the pier lights a bit dimmer"): the pier's lanterns at this share.
const PIER_LIGHT_SCALE: float = 0.55
static var _wet: Dictionary = {}


func _wet_structures() -> void:
	if owner == null:
		return
	for g: String in WET_GROUPS:
		var root: Node = owner.get_node_or_null(g)
		if root == null:
			continue
		for n: Node in root.find_children("*", "MeshInstance3D", true, false):
			var mi: MeshInstance3D = n as MeshInstance3D
			if mi.mesh == null or mi.material_override != null:
				continue
			for s: int in mi.mesh.get_surface_count():
				var wet: Material = _wet_copy(mi.get_active_material(s))
				if wet != null:
					mi.set_surface_override_material(s, wet)


func _wet_copy(mat: Material) -> Material:
	if mat == null:
		return null
	var key: String = mat.resource_path if mat.resource_path != "" else str(mat.get_instance_id())
	if _wet.has(key):
		return _wet[key]
	var file: String = mat.resource_path.get_file()
	var wet: Material = null
	if file.begins_with("emit_") or file.contains("water") or file.contains("glass"):
		wet = null
	elif mat is ShaderMaterial and (mat as ShaderMaterial).shader != null \
			and (mat as ShaderMaterial).shader.resource_path == "res://shaders/kit_px_world.gdshader":
		wet = mat.duplicate()
		(wet as ShaderMaterial).set_shader_parameter("wetness", STONE_WETNESS)
	elif mat is StandardMaterial3D and (mat as StandardMaterial3D).emission_enabled == false \
			and (mat as StandardMaterial3D).transparency == BaseMaterial3D.TRANSPARENCY_DISABLED \
			and (mat as StandardMaterial3D).albedo_texture != null:
		# Walk 6 ("too smooth; wet but also rough"): wood moves onto the
		# px_world shader, so it gets the same wet patches as the stone (glossy
		# where water stands, its own rough grain between) and a deeper grain.
		var src: StandardMaterial3D = mat as StandardMaterial3D
		var w := ShaderMaterial.new()
		w.shader = load("res://shaders/kit_px_world.gdshader")
		w.set_shader_parameter("texture_albedo", src.albedo_texture)
		w.set_shader_parameter("texture_roughness", src.roughness_texture)
		w.set_shader_parameter("texture_normal", src.normal_texture)
		w.set_shader_parameter("uv1_scale", src.uv1_scale)
		w.set_shader_parameter("uv1_blend_sharpness", 4.0)
		w.set_shader_parameter("normal_scale", 1.6)
		w.set_shader_parameter("specular", 0.6)
		w.set_shader_parameter("rough_variation", 0.2)
		w.set_shader_parameter("wetness", WOOD_WETNESS)
		w.set_shader_parameter("albedo_scale", Vector3(0.85, 0.82, 0.8))
		wet = w
	_wet[key] = wet
	return wet


func _boathouses() -> void:
	var houses: Array[Node3D] = []
	for n: Node in get_tree().get_nodes_in_group("lake_boathouse"):
		houses.append(n as Node3D)
	if houses.is_empty():
		return
	houses.sort_custom(func(a: Node3D, b: Node3D) -> bool: return String(a.name) < String(b.name))
	var lit: Array[bool] = []
	for _i: int in houses.size():
		lit.append(_rng.randf() < 0.55)
	if not lit.has(true):
		lit[_rng.randi_range(0, houses.size() - 1)] = true
	var cold_glass: Material = PxMaterial.get_or_create("iron")
	var fisher_at: int = -1
	for i: int in houses.size():
		var h: Node3D = houses[i]
		h.set_meta("lit", lit[i])
		if lit[i]:
			if fisher_at < 0 or _rng.randf() < 0.4:
				fisher_at = i
			continue
		for l: Node in h.find_children("*", "Light3D", true, false):
			(l as Light3D).visible = false
			l.remove_from_group("kit_light")
		for mi: Node in h.find_children("*", "MeshInstance3D", true, false):
			if String(mi.name).to_lower().contains("lamp_glass"):
				(mi as MeshInstance3D).material_override = cold_glass
	# The fisher at a lit boathouse's door, on the boardwalk, his nets and traps by him.
	var h: Node3D = houses[fisher_at]
	var base: Transform3D = h.transform
	var parent: Node = h.get_parent()
	_place(parent, "res://kit/modules/walls/qt_fig_mend.tscn", "Fisher", base * Transform3D(Basis(Vector3.UP, 0.5), Vector3(2.4, 0.0, 2.35)))
	_place(parent, "res://kit/modules/walls/lk_nets.tscn", "Nets", base * Transform3D(Basis.IDENTITY, Vector3(0.6, 0.0, 2.6)))
	_place(parent, "res://kit/modules/walls/lk_traps.tscn", "Traps", base * Transform3D(Basis(Vector3.UP, 1.1), Vector3(3.6, 0.0, 2.6)))


func _place(parent: Node, path: String, node_name: String, xform: Transform3D) -> Node3D:
	var n: Node3D = (load(path) as PackedScene).instantiate() as Node3D
	n.name = node_name
	parent.add_child(n)
	n.transform = xform
	return n


## The lantern boat (step 3, the brief's motion line): a small boat, a rower
## and a lantern, coming out of one channel's fog and rowing across into
## another, in whichever place you are in. In the harbour it comes in from
## the ferry's channel and goes on into the dark flooded one, its lantern
## dimming as the roof comes down; at a dock it comes in by the east mouth
## and goes out by the west. A crossing every two minutes; between them it is
## away in the fog. It lies still while the ferry is near (rowing on if it is
## on the ferry's line).
const LANTERN_PERIOD: float = 120.0
const LANTERN_ROW: float = 75.0
## Its way through a dock, in the dock's frame: in by the east channel, along
## its outer bank, across the chamber just past the berth's run (the one place
## it crosses the ferry's line), out along the west channel's outer bank.
const LANTERN_DOCK_WAY: Array[Vector3] = [Vector3(29.0, 0.0, -46.0), Vector3(21.0, 0.0, -45.0), Vector3(11.5, 0.0, -36.5),
	Vector3(5.5, 0.0, -26.5), Vector3(0.0, 0.0, -23.0), Vector3(-5.5, 0.0, -26.5), Vector3(-8.5, 0.0, -34.5),
	Vector3(-18.5, 0.0, -42.0), Vector3(-29.0, 0.0, -46.0)]
## In the harbour: in down the west side of the ferry's channel (the ferry keeps
## east of its middle), across the water south of the pier head, into the dark channel.
const LANTERN_HARBOUR_WAY: Array[Vector3] = [Vector3(15.0, 0.0, -82.0), Vector3(11.0, 0.0, -74.0), Vector3(8.0, 0.0, -66.0),
	Vector3(5.3, 0.0, -58.0), Vector3(3.0, 0.0, -52.0), Vector3(-3.0, 0.0, -47.0), Vector3(-5.0, 0.0, -41.0),
	Vector3(-11.0, 0.0, -38.5), Vector3(-20.0, 0.0, -39.0), Vector3(-25.0, 0.0, -41.0),
	Vector3(-31.0, 0.0, -46.5)]     # north of the violet ledge's rocks, into the dark channel under its low roof
var _far_place: String = ""
var _far_round: int = -1


func _far_ferry() -> void:
	if not LakeLayout.FERRY_RUNS:
		return
	_far_boat = (load(BOAT) as PackedScene).instantiate() as Node3D
	_far_boat.name = "FarBoat"
	add_child(_far_boat)
	var who: Node3D = (load("res://kit/modules/walls/qt_fig_sit.tscn") as PackedScene).instantiate() as Node3D
	who.position = Vector3(0.0, -0.2, 0.6)
	_far_boat.add_child(who)
	WorldProp.localize_materials(_far_boat)
	_far_light = _boat_lantern(_far_boat, Vector3(0.0, 0.0, -1.7))
	_far_light.omni_range = 6.0
	_far_light.light_energy = 1.2
	_far_boat.visible = false
	_lantern_route("quay")


## The lantern boat's way through `place` ("quay" or a dock style).
func _lantern_route(place: String) -> void:
	_far_place = place
	var pts: Array[Vector3] = []
	if place == "quay":
		pts = LANTERN_HARBOUR_WAY
	else:
		var f: Transform3D = LakeLayout.dock_frame(place)
		for p: Vector3 in LANTERN_DOCK_WAY:
			pts.append(f * p)
	_far_curve = Curve3D.new()
	_far_curve.bake_interval = 1.0
	for i: int in pts.size():
		var a: Vector3 = pts[maxi(i - 1, 0)]
		var b: Vector3 = pts[mini(i + 1, pts.size() - 1)]
		var hd: Vector3 = (b - a) * 0.2
		_far_curve.add_point(Vector3(pts[i].x, LakeLayout.WATER, pts[i].z), -hd, hd)


func _far_tick(delta: float) -> void:
	var ferry_node: Node = owner.get_node_or_null("Ferry") if owner != null else null
	var ferry: Node3D = (owner.get_node_or_null("Ferry/Barge") if owner != null else null) as Node3D
	# It lies still while the ferry is near, unless it is on the ferry's line:
	# then it rows on, quicker, out of the way.
	var pace: float = 1.0
	if ferry != null and _far_boat.visible and ferry.global_position.distance_to(_far_boat.global_position) <= 14.0:
		pace = 0.0
		var line: Curve3D = ferry_node.get("_curve") as Curve3D if bool(ferry_node.call("moving")) else null
		if line != null and line.get_baked_length() > 0.0:
			var on: Vector3 = line.get_closest_point(_far_boat.global_position)
			if Vector2(on.x - _far_boat.global_position.x, on.z - _far_boat.global_position.z).length() < 6.0:
				pace = 2.0
	_far_clock += delta * pace
	var clock: float = _far_clock + float(seed_value % 60)
	var round_: int = int(clock / LANTERN_PERIOD)
	var t: float = fmod(clock, LANTERN_PERIOD)
	# A new crossing goes through the place you are in now.
	var here: String = str(ferry_node.get("place")) if ferry_node != null else "quay"
	if round_ != _far_round or (here != _far_place and t >= LANTERN_ROW):
		_far_round = round_
		if here != "" and here != _far_place:
			_lantern_route(here)
	if t >= LANTERN_ROW or here != _far_place:
		_far_boat.visible = false
		_far_light.visible = false
		return
	_far_boat.visible = true
	var k: float = smoothstep(0.0, 1.0, t / LANTERN_ROW) * 0.8 + 0.2 * t / LANTERN_ROW
	var length: float = _far_curve.get_baked_length()
	var s: float = k * length
	var pos: Vector3 = _far_curve.sample_baked(s)
	var ahead: Vector3 = _far_curve.sample_baked(minf(s + 2.0, length))
	var dir: Vector3 = ahead - pos
	var yaw: float = _far_boat.rotation.y
	if dir.length() > 0.05:
		yaw = atan2(-dir.x, -dir.z)
	_far_boat.transform = Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.BACK, 0.02 * sin(_t * 0.9)),
		pos + Vector3(0.0, FREEBOARD + 0.03 * sin(_t * 1.1), 0.0))
	# Into the dark channel the rower turns the lantern down.
	var dim: float = 1.0 - smoothstep(length - 14.0, length - 2.0, s) if _far_place == "quay" else 1.0
	_far_light.visible = dim > 0.02
	_far_light.light_energy = 1.2 * dim


# ------------------------------------------------------------------ reflections

func _make_streaks() -> void:
	var room: Node = owner if owner != null else get_parent()
	var sources: Array[Node3D] = []
	for l: Light3D in _lights():
		if l.visible:
			sources.append(l)
	for n: Node in get_tree().get_nodes_in_group("lake_reflect"):
		if room.is_ancestor_of(n):
			sources.append(n as Node3D)
	var quad := ArrayMesh.new()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	var verts := PackedVector3Array()
	var idx := PackedInt32Array()
	var rows: int = 12
	for k: int in rows + 1:
		var z: float = float(k) / rows
		verts.append(Vector3(-0.5, 0.0, z))
		verts.append(Vector3(0.5, 0.0, z))
	for k: int in rows:
		var i: int = k * 2
		idx.append_array([i, i + 1, i + 2, i + 1, i + 3, i + 2])
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_INDEX] = idx
	quad.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	for src: Node3D in sources:
		var mat := ShaderMaterial.new()
		mat.shader = STREAK_SHADER
		var colour: Color = (src as Light3D).light_color if src is Light3D else src.get_meta("color", Color(1.0, 0.72, 0.42))
		var strength: float = 0.9 * (src as Light3D).light_energy if src is Light3D else float(src.get_meta("strength", 0.5))
		mat.set_shader_parameter("color", colour)
		mat.set_shader_parameter("strength", strength)
		var mi := MeshInstance3D.new()
		mi.name = "Streak"
		mi.mesh = quad
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.extra_cull_margin = 32.0
		add_child(mi)
		_streaks.append([src, mi])
		_streak_materials.append(mat)
	_place_streaks()


func _place_streaks() -> void:
	for pair: Array in _streaks:
		var src: Node3D = pair[0]
		var mi: MeshInstance3D = pair[1]
		if not is_instance_valid(src):
			mi.visible = false
			continue
		var p: Vector3 = src.global_position
		mi.global_position = Vector3(p.x, LakeLayout.WATER + 0.015, p.z)
		mi.visible = src.is_visible_in_tree() and p.y > LakeLayout.WATER


# ------------------------------------------------------------------ each frame

func _process(delta: float) -> void:
	_t += delta
	WATER_MATERIAL.set_shader_parameter("simulation_time", _t)
	for m: ShaderMaterial in _streak_materials:
		m.set_shader_parameter("simulation_time", _t)
	for b: Array in _boats:
		var boat: Node3D = b[0]
		var rest: Transform3D = b[1]
		var ph: float = b[2]
		var roll: float = deg_to_rad(1.4) * sin(_t * 0.85 + ph)
		var pitch: float = deg_to_rad(0.7) * sin(_t * 0.6 + ph * 1.7)
		boat.transform = Transform3D(rest.basis * Basis(Vector3.BACK, roll) * Basis(Vector3.RIGHT, pitch),
			rest.origin + Vector3(0.0, 0.035 * sin(_t * 1.05 + ph), 0.0))
	if _far_boat != null:
		_far_tick(delta)
	_place_streaks()


func _physics_process(_delta: float) -> void:
	if _resetting:
		return
	var game: Node = get_tree().current_scene
	var p: Node3D = game.get("player") as Node3D if game != null and "player" in game else null
	if p == null or bool(p.get("flying")):
		return
	if p.global_position.y < LakeLayout.WATER - DEEP:
		_back_to_shore(p)


## Fell in deep water: a splash, a quick fade, then the nearest steps.
func _back_to_shore(p: Node3D) -> void:
	_resetting = true
	var fell: Vector3 = p.global_position
	_splash_at(Vector3(fell.x, LakeLayout.WATER, fell.z))
	var best: Node3D = null
	for n: Node in get_tree().get_nodes_in_group("lake_safe"):
		var m := n as Node3D
		if best == null or m.global_position.distance_squared_to(fell) < best.global_position.distance_squared_to(fell):
			best = m
	var tw: Tween = create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.3)
	tw.tween_callback(func() -> void:
		if best != null and p.has_method("teleport"):
			var to: Vector3 = best.global_position
			var away: Vector3 = to - fell
			var yaw: float = atan2(-away.x, -away.z) if Vector2(away.x, away.z).length() > 0.1 else p.rotation.y
			p.call("teleport", to, yaw)
		var game: Node = get_tree().current_scene
		var hud: Object = game.get("hud") if game != null and "hud" in game else null
		if hud != null:
			hud.call("notify", "Cold, black water. You haul yourself out at the steps."))
	tw.tween_interval(0.25)
	tw.tween_property(_fade, "color:a", 0.0, 0.6)
	tw.tween_callback(func() -> void: _resetting = false)


func _splash_at(at: Vector3) -> void:
	if _splash == null:
		_splash = CPUParticles3D.new()
		_splash.name = "Splash"
		_splash.one_shot = true
		_splash.emitting = false
		_splash.amount = 40
		_splash.lifetime = 1.1
		_splash.explosiveness = 0.95
		_splash.direction = Vector3.UP
		_splash.spread = 35.0
		_splash.initial_velocity_min = 1.5
		_splash.initial_velocity_max = 3.6
		_splash.gravity = Vector3(0.0, -9.0, 0.0)
		_splash.scale_amount_min = 0.04
		_splash.scale_amount_max = 0.09
		var qm := QuadMesh.new()
		qm.size = Vector2(1.0, 1.0)
		var sm := StandardMaterial3D.new()
		sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		sm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		sm.albedo_color = Color(0.62, 0.68, 0.78, 0.7)
		qm.material = sm
		_splash.mesh = qm
		add_child(_splash)
	_splash.global_position = at
	_splash.restart()


func _build_fade() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color(0.0, 0.0, 0.02, 0.0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_fade)

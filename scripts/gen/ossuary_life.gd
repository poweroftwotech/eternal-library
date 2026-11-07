class_name OssuaryLife
extends Node3D
## The R17 Ossuary of Books' air (phase 16 step 2). OssuaryGrammar puts this
## (slot os:life) at the room's origin; on _ready it finds the room's candles
## and adds the threads of dust falling from the vault (grid.meta "dust").
## Each frame the candles gutter, and the nearest flames lean away as you pass,
## as if you had stirred the air (the brief's Q5). No collision; the only
## lights are the candles the room already has.

## How close you stir a flame, and how far it leans, in radians.
const STIR_REACH: float = 2.4
const STIR_LEAN: float = 0.55
## Flames further than this aren't worth moving.
const FLAME_REACH: float = 18.0
const THREAD_TOP: float = 2.7

static var _thread_mat: StandardMaterial3D

## {light, base, flames: [MeshInstance3D], pivots: [Vector3], phase, stir}
var _candles: Array[Dictionary] = []
var _t: float = 0.0
var _owned: Dictionary = {}     # a piece whose flames a light already moves


func _ready() -> void:
	set_process(false)
	_build()


func _build() -> void:
	await get_tree().process_frame
	var room: GeneratedRoom = _room()
	if room == null or room.grid == null or not room.grid.meta.has("ossuary"):
		return
	for at: Vector3 in room.grid.meta.get("dust", []):
		var p: GPUParticles3D = _thread()
		p.position = at + Vector3(0.0, THREAD_TOP, 0.0) - position
		add_child(p)
	# The bodies on the biers: marked for possession, which isn't built yet (Q2).
	for at: Transform3D in room.grid.meta.get("hosts", []):
		var host := Marker3D.new()
		host.name = "PossessionHost"
		host.transform = transform.affine_inverse() * at
		add_child(host)
		host.add_to_group("possession_host")
	for light: Node in room.find_children("*", "OmniLight3D", true, false):
		var kind: String = str(light.get_meta("light_profile", ""))
		if kind == "ossuary_lantern":     # its light sits in its cage: its frame would blot out the vault
			for m: Node in light.get_parent().find_children("*", "MeshInstance3D", true, false):
				(m as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if kind in ["candle", "ossuary_candle", "ossuary_lantern", "ossuary_shrine"]:
			_add_candle(light as OmniLight3D)
	set_process(not _candles.is_empty())


func _add_candle(light: OmniLight3D) -> void:
	var flames: Array[MeshInstance3D] = []
	var pivots: Array[Vector3] = []
	var owner_piece: Node = light.get_parent()
	var found: Array = [] if _owned.has(owner_piece) else owner_piece.find_children("*flame*", "MeshInstance3D", true, false)
	_owned[owner_piece] = true
	for m: Node in found:
		var mesh := m as MeshInstance3D
		flames.append(mesh)
		var box: AABB = mesh.get_aabb()
		pivots.append(box.position + Vector3(box.size.x * 0.5, 0.0, box.size.z * 0.5))
	_candles.append({"light": light, "base": light.light_energy, "flames": flames, "pivots": pivots,
		"phase": float(light.get_instance_id() % 997), "stir": 0.0})


func _process(delta: float) -> void:
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		return
	_t += delta
	var eye: Vector3 = cam.global_position
	for c: Dictionary in _candles:
		var light := c["light"] as OmniLight3D
		if not is_instance_valid(light):
			continue
		var at: Vector3 = light.global_position
		var far: float = at.distance_to(eye)
		if far > FLAME_REACH:
			continue
		var ph: float = c["phase"]
		# A slow breath, a quick tremble, and now and then a dip.
		var wave: float = sin(_t * 1.7 + ph) * 0.5 + sin(_t * 7.3 + ph * 0.61) * 0.3 + sin(_t * 13.1 + ph * 1.3) * 0.2
		var dip: float = sin(_t * 0.9 + ph * 2.1) * sin(_t * 2.3 + ph * 0.7)
		var k: float = 0.86 + 0.12 * wave
		if dip > 0.8:
			k *= 1.0 - (dip - 0.8) * 2.2
		var stir: float = c["stir"]
		var want: float = clampf(1.0 - Vector2(at.x - eye.x, at.z - eye.z).length() / STIR_REACH, 0.0, 1.0)
		stir = move_toward(stir, want, delta * (3.0 if want > stir else 0.8))
		c["stir"] = stir
		light.light_energy = float(c["base"]) * k * (1.0 - 0.3 * stir)
		var away := Vector3(at.x - eye.x, 0.0, at.z - eye.z)
		var axis: Vector3 = Vector3.UP.cross(away).normalized() if away.length() > 0.01 else Vector3.RIGHT
		var flames: Array[MeshInstance3D] = c["flames"]
		var pivots: Array[Vector3] = c["pivots"]
		for i: int in flames.size():
			var f: MeshInstance3D = flames[i]
			if not is_instance_valid(f):
				continue
			var local: Vector3 = (f.global_transform.affine_inverse().basis * axis).normalized()
			var lean: float = STIR_LEAN * stir + 0.06 * sin(_t * 5.0 + ph + i * 1.7)
			var turn := Basis(local, lean).scaled(Vector3(1.0, 0.8 + 0.25 * k, 1.0))
			var p: Vector3 = pivots[i]
			f.transform = (c.get_or_add("rest_%d" % i, f.transform) as Transform3D) * Transform3D(turn, p - turn * p)


## A thin thread of dust falling from the vault: a few pale grains, slow.
static func _thread() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "DustThread"
	var quad := QuadMesh.new()
	quad.size = Vector2(0.007, 0.016)
	quad.material = _thread_material()
	p.draw_pass_1 = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.amount = 40
	p.lifetime = 7.0
	p.randomness = 0.5
	p.preprocess = 7.0
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = Vector3(0.07, 0.0, 0.07)
	m.direction = Vector3.DOWN
	m.spread = 3.0
	m.gravity = Vector3(0.0, -0.05, 0.0)
	m.initial_velocity_min = 0.22
	m.initial_velocity_max = 0.42
	m.scale_min = 0.6
	m.scale_max = 1.3
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0))
	fade.set_color(1, Color(1, 1, 1, 0))
	fade.add_point(0.15, Color(1, 1, 1, 1))
	fade.add_point(0.8, Color(1, 1, 1, 0.7))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	m.color_ramp = ramp
	p.process_material = m
	p.visibility_range_end = 16.0
	p.visibility_aabb = AABB(Vector3(-0.5, -3.0, -0.5), Vector3(1.0, 3.2, 1.0))
	return p


static func _thread_material() -> StandardMaterial3D:
	if _thread_mat == null:
		_thread_mat = StandardMaterial3D.new()
		_thread_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_thread_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_thread_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		_thread_mat.vertex_color_use_as_albedo = true
		_thread_mat.albedo_color = Color(0.5, 0.5, 0.45, 0.4)
		_thread_mat.disable_receive_shadows = true
	return _thread_mat


func _room() -> GeneratedRoom:
	var n: Node = get_parent()
	while n != null and not n is GeneratedRoom:
		n = n.get_parent()
	return n as GeneratedRoom


static func warm() -> Array[GPUParticles3D]:
	return [_thread()]

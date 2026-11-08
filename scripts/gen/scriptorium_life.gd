class_name ScriptoriumLife
extends Node3D
## The R08 Orosi Scriptorium's life (phase 17 step 4). ScriptoriumGrammar puts
## this (slot sc:life) at the room's origin; on _ready it finds the room's
## lights. Each frame:
##   - the moss behind the glass swells and fades over about half a minute (the
##     brief's Q8), and the glass, its window lights (the coloured patches),
##     its glow on the hall and the moss's own light with it;
##   - the desk lamps' flames flicker, as the camp's fire does.
## In the Forgotten version (meta "forgotten") the moss is dimmer, so the glass
## glows faintly: the one bright thing left in a dead room. No collision.

## The swell: two slow waves, about 31 s and 13 s; how far the light moves.
const SWELL_SLOW: float = 31.0
const SWELL_FAST: float = 13.0
const SWELL_LIGHT: float = 0.22
const SWELL_GLASS: float = 0.15
## The Forgotten version's moss, as a share of the tended one's.
const FORGOTTEN_MOSS: float = 0.4
## Lamps further than this from the camera aren't worth flickering.
const FLICKER_REACH: float = 20.0

## {light, base}
var _moss: Array[Dictionary] = []
var _lamps: Array[Dictionary] = []
var _glass: Array[GeometryInstance3D] = []
var _dim: float = 1.0
var _t: float = 0.0


func _ready() -> void:
	set_process(false)
	_build()


func _build() -> void:
	await get_tree().process_frame
	var room: Node = _room()
	if room == null:
		return
	_dim = FORGOTTEN_MOSS if bool(get_meta("forgotten", false)) else 1.0
	for n: Node in room.find_children("*", "Light3D", true, false):
		var light := n as Light3D
		var kind: String = str(light.get_meta("light_profile", ""))
		if light.has_meta("window") or kind.begins_with("orosi") or kind == "lumenmoss":
			_moss.append({"light": light, "base": light.light_energy})
		elif kind == "desk":
			_lamps.append({"light": light, "base": light.light_energy, "phase": light.global_position.x * 1.7 + light.global_position.z})
	for n: Node in room.find_children("*glass*", "GeometryInstance3D", true, false):
		var g := n as GeometryInstance3D
		if g.material_override is ShaderMaterial:
			_glass.append(g)
	# A stable start: the swell picks up where the room's position puts it, so
	# two scriptoriums don't breathe together.
	_t = absf(global_position.x * 0.37 + global_position.z * 0.21)
	_apply()
	set_process(true)


func _process(delta: float) -> void:
	_t += delta
	_apply()


func _apply() -> void:
	var s: float = swell(_t)
	# Lights and glass can be freed under us (the room streamed out, or the
	# light budget's): check before the cast.
	for m: Dictionary in _moss:
		if is_instance_valid(m["light"]):
			(m["light"] as Light3D).light_energy = float(m["base"]) * _dim * (1.0 + s * SWELL_LIGHT)
	for gv: Variant in _glass:
		if not is_instance_valid(gv):
			continue
		(gv as GeometryInstance3D).set_instance_shader_parameter("swell", (1.0 + s * SWELL_GLASS) * lerpf(1.0, _dim, 0.7))
	var cam: Camera3D = get_viewport().get_camera_3d()
	for l: Dictionary in _lamps:
		if not is_instance_valid(l["light"]):
			continue
		var light: Light3D = l["light"]
		if cam != null and cam.global_position.distance_to(light.global_position) > FLICKER_REACH:
			continue
		var t: float = _t + float(l["phase"])
		var f: float = sin(t * 2.1) * .40 + sin(t * 3.73 + .7) * .28 + sin(t * 6.21 + 1.2) * .12
		light.light_energy = float(l["base"]) * (1.0 + f * 0.22)


## The moss's breath at time `t`: -1..1, slow and uneven.
static func swell(t: float) -> float:
	return sin(t * TAU / SWELL_SLOW) * 0.7 + sin(t * TAU / SWELL_FAST + 1.3) * 0.3


func _room() -> Node:
	var n: Node = get_parent()
	while n != null and not n is GeneratedRoom:
		n = n.get_parent()
	return n

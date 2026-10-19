@tool
class_name LampState
extends Node
## Lamp states for STATE sockets (ENVIRONMENT_PLAN.md 4.3): "lit", "failing"
## or "dark", applied to every OmniLight3D/SpotLight3D and every glowing
## ("emit_*") surface under a lamp module. A failing lamp returns an instance of
## this node, which the socket keeps as an internal child: it flickers the
## lights each frame (dim, with brief drop-outs).

const STATES: PackedStringArray = ["lit", "failing", "dark"]

static var _dim: Dictionary = {}     # emit material -> dimmed copy
static var _dark: StandardMaterial3D

var lights: Array[Light3D] = []
var phase: float = 0.0
var _t: float = 0.0


## Returns a flicker node for "failing" (the caller adds it), else null.
static func apply(target: Node, state: String) -> LampState:
	if target == null:
		return null
	var found_lights: Array[Light3D] = []
	var meshes: Array[MeshInstance3D] = []
	_collect(target, found_lights, meshes)
	for light: Light3D in found_lights:
		if not light.has_meta("lamp_base_energy"):
			light.set_meta("lamp_base_energy", light.light_energy)
		var base: float = light.get_meta("lamp_base_energy")
		light.visible = state != "dark"
		light.set_meta("lamp_state", state)   # Atmosphere sways only "lit" lamps
		light.light_energy = base * (0.55 if state == "failing" else 1.0)
	for inst: MeshInstance3D in meshes:
		for i: int in inst.mesh.get_surface_count():
			var mat: Material = inst.mesh.surface_get_material(i)
			if mat == null or not mat.resource_name.begins_with("emit_"):
				continue
			match state:
				"dark":
					inst.set_surface_override_material(i, dark_glass())
				"failing":
					inst.set_surface_override_material(i, dimmed(mat))
				_:
					inst.set_surface_override_material(i, null)
	if state != "failing" or found_lights.is_empty():
		return null
	var flicker := LampState.new()
	flicker.name = "Flicker"
	flicker.lights = found_lights
	flicker.phase = float(target.get_instance_id() % 997)
	return flicker


func _process(delta: float) -> void:
	_t += delta
	var wave: float = sin(_t * 11.0 + phase) * sin(_t * 4.3 + phase * 0.37)
	var k: float = 0.08 if wave < -0.82 else 0.5 + 0.18 * wave
	for light: Light3D in lights:
		if is_instance_valid(light):
			light.light_energy = float(light.get_meta("lamp_base_energy", 1.0)) * k


static func _collect(node: Node, out_lights: Array[Light3D], out_meshes: Array[MeshInstance3D]) -> void:
	if node is OmniLight3D or node is SpotLight3D:
		out_lights.append(node as Light3D)
	elif node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		out_meshes.append(node as MeshInstance3D)
	for child: Node in node.get_children():
		if not child is VariantSocket:
			_collect(child, out_lights, out_meshes)


static func dimmed(mat: Material) -> Material:
	if not _dim.has(mat):
		var copy: Material = mat.duplicate()
		if copy is BaseMaterial3D:
			var b := copy as BaseMaterial3D
			b.emission_energy_multiplier *= 0.35
			b.albedo_color = b.albedo_color.darkened(0.35)
		_dim[mat] = copy
	return _dim[mat]


static func dark_glass() -> StandardMaterial3D:
	if _dark == null:
		_dark = StandardMaterial3D.new()
		_dark.resource_name = "lamp_dark_glass"
		_dark.albedo_color = Color(0.13, 0.1, 0.07)
		_dark.roughness = 0.4
	return _dark

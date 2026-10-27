@tool
class_name GreatFall
extends Node3D
## A great waterfall (phase-8-design.md 8.5), reusable anywhere: set the
## width and height and it builds itself in the editor and at run time. It
## pours from this node's origin along -Y, its sheet across X, arcing out
## toward +Z: an opaque core, a wider veil behind it, a bank of mist where it
## lands and a cool light on the spray. Place it at a persian_spillway's
## ANCHOR_fall lip (its -Y Blender face is Godot +Z, so the fall faces +Z too).
##
## Cost: two ribbon meshes (about 900 triangles), one fog volume, one
## shadowless light; transparency overdraw is the real cost, kept down by
## the veil's narrow alpha and the core's opacity.

@export var width: float = 6.0:
	set(value):
		width = value
		_rebuild()
@export var height: float = 40.0:
	set(value):
		height = value
		_rebuild()
## How far the water arcs out from the lip by the foot (m).
@export var arc_out: float = 3.0:
	set(value):
		arc_out = value
		_rebuild()
@export var seed_value: float = 1.0:
	set(value):
		seed_value = value
		_rebuild()
## Mist and light at the foot (off where the foot is hidden or far below).
@export var mist: bool = true:
	set(value):
		mist = value
		_rebuild()
@export var light_energy: float = 2.0:
	set(value):
		light_energy = value
		_rebuild()

const SHADER: Shader = preload("res://shaders/great_fall.gdshader")
const COLUMNS: int = 10
const ROWS: int = 24


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	for child: Node in get_children():
		if child.has_meta("great_fall_part"):
			child.free()
	_ribbon(width, 0.0, false)
	_ribbon(width * 1.5, -0.35, true)
	if mist:
		_mist()


## One bent ribbon `w` wide, `back` metres behind the core, its foot spread wider.
func _ribbon(w: float, back: float, is_veil: bool) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for y: int in ROWS:
		for x: int in COLUMNS:
			for corner: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
				var uv := Vector2(float(x + corner.x) / COLUMNS, float(y + corner.y) / ROWS)
				var spread: float = 1.0 + pow(uv.y, 2.0) * 0.45
				# A parabola: the water leaves the lip level and drops away.
				var out: float = arc_out * (1.0 - pow(1.0 - uv.y, 2.0)) + back
				surface.set_uv(uv)
				surface.set_normal(Vector3.BACK)
				surface.add_vertex(Vector3((uv.x - 0.5) * w * spread, -uv.y * height, out))
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("seed", seed_value * 7.13 + (3.1 if is_veil else 0.0))
	material.set_shader_parameter("veil", 1.0 if is_veil else 0.0)
	material.set_shader_parameter("length_m", height)
	if is_veil:
		material.render_priority = -1
	var node := MeshInstance3D.new()
	node.name = "Veil" if is_veil else "Core"
	node.mesh = surface.commit()
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_own(node)


func _mist() -> void:
	var fog := FogVolume.new()
	fog.name = "Mist"
	fog.shape = RenderingServer.FOG_VOLUME_SHAPE_ELLIPSOID
	fog.size = Vector3(width * 3.5, maxf(6.0, height * 0.22), width * 3.0)
	fog.position = Vector3(0, -height + fog.size.y * 0.25, arc_out + width * 0.4)
	var material := FogMaterial.new()
	material.density = 0.05
	material.albedo = Color("c9dde3")
	material.emission = Color("9bc7db") * 0.04
	material.edge_fade = 0.6
	fog.material = material
	_own(fog)
	var light := OmniLight3D.new()
	light.name = "SprayLight"
	light.light_color = Color("9bc7db")
	light.light_energy = light_energy
	light.omni_range = maxf(8.0, width * 2.5)
	light.shadow_enabled = false
	light.position = Vector3(0, -height * 0.85, arc_out + width * 0.6)
	_own(light)


func _own(node: Node) -> void:
	node.set_meta("great_fall_part", true)
	add_child(node)

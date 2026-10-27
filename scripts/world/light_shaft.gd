@tool
class_name LightShaft
extends Node3D
## A shaft of the unexplained natural light falling through a crack in a
## cavern roof (phase-8-design.md 8.4), reusable anywhere: a spot light
## pointing down whose beam shows in the volumetric fog, and a cone of haze
## that makes the shaft visible from afar. Green gardens grow where one
## lands. The node sits at the crack; the light falls along -Y.
##
## Cost: one shadowless spot light and one fog volume.

@export var height: float = 60.0:
	set(value):
		height = value
		_rebuild()
@export var radius: float = 9.0:     ## the pool of light where it lands
	set(value):
		radius = value
		_rebuild()
@export var color: Color = Color(0.86, 0.92, 1.0):
	set(value):
		color = value
		_rebuild()
@export var energy: float = 6.0:
	set(value):
		energy = value
		_rebuild()
@export var haze: float = 0.035:
	set(value):
		haze = value
		_rebuild()


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	for child: Node in get_children():
		if child.has_meta("light_shaft_part"):
			child.free()
	var spot := SpotLight3D.new()
	spot.name = "Beam"
	spot.light_color = color
	spot.light_energy = energy
	spot.spot_range = height * 1.15
	spot.spot_angle = rad_to_deg(atan(radius / height)) * 1.15
	spot.spot_attenuation = 0.4
	spot.spot_angle_attenuation = 1.6
	spot.light_volumetric_fog_energy = 6.0
	spot.shadow_enabled = false
	spot.rotation = Vector3(-PI / 2, 0, 0)
	spot.set_meta("light_far", true)           # LightBudget: seen from far, so not faded with distance
	_own(spot)
	var fog := FogVolume.new()
	fog.name = "Haze"
	fog.shape = RenderingServer.FOG_VOLUME_SHAPE_CONE
	fog.size = Vector3(radius * 2.0, height, radius * 2.0)
	fog.position = Vector3(0, -height * 0.5, 0)
	# A cone FogVolume points up (+Y): its point at the crack, its base on
	# the ground where the light lands (flipped, it was a thin point there).
	var material := FogMaterial.new()
	material.density = haze
	material.albedo = color
	material.emission = color * 0.06
	material.edge_fade = 0.8
	fog.material = material
	_own(fog)


func _own(node: Node) -> void:
	node.set_meta("light_shaft_part", true)
	add_child(node)

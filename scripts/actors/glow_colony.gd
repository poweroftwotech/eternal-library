class_name GlowColony
extends MultiMeshInstance3D
## The glowworms of one room (phase 19 step 2), one MultiMesh: points of light
## hanging on threads from dark roofs, pulsing slowly, in the area's fungus
## colour. Run near them and they go dark, a few at a time, then light again
## one by one over half a minute.

## You count as running above this (m/s; walking is 3.7, running 5.9).
const RUN_SPEED: float = 4.6
## Running this close (m, to their box) puts them out.
const NOTICE: float = 12.0
## How fast they go dark, and how long before all glow again (s).
const DARKEN_S: float = 0.8
const RELIGHT_S: float = 28.0

var def: CreatureDef
var bounds: AABB
var focus: Vector3
var darkness: float = 0.0


## `worms`: [{at: on the roof (global), length: thread (m)}].
func setup(d: CreatureDef, worms: Array, colour: Color, rng: RandomNumberGenerator) -> void:
	def = d
	name = "%s_%d" % [d.id, rng.randi() & 0xffff]
	top_level = true
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bounds = AABB(worms[0]["at"], Vector3.ZERO)
	for w: Dictionary in worms:
		bounds = bounds.expand(w["at"])
	bounds = bounds.grow(0.5)
	position = bounds.get_center()
	focus = worms[0]["at"]
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = AirBody.worm_mesh()
	mm.instance_count = worms.size()
	var width: float = d.length_m * 0.25
	for i: int in worms.size():
		var w: Dictionary = worms[i]
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(width, float(w["length"]), width)), (w["at"] as Vector3) - position))
		mm.set_instance_custom_data(i, Color(rng.randf(), rng.randf_range(0.1, 0.95), rng.randf(), 0.0))
	multimesh = mm
	material_override = AirBody.material(d)
	custom_aabb = AABB(bounds.position - position - Vector3(0, 0.5, 0), bounds.size + Vector3(0, 0.5, 0))
	set_instance_shader_parameter("glow", Vector3(colour.r, colour.g, colour.b))


func tick(delta: float, player: Vector3, moving: float) -> void:
	var near: bool = bounds.grow(NOTICE).has_point(player + Vector3(0, 1.0, 0))
	var was: float = darkness
	if near and moving > RUN_SPEED:
		darkness = minf(1.0, darkness + delta / DARKEN_S)
	else:
		darkness = maxf(0.0, darkness - delta / RELIGHT_S)
	if darkness != was:
		set_instance_shader_parameter("dark", darkness)

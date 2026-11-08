class_name OrosiWallSetup
extends Node
## Puts a glass palette on an sc_orosi_wall when the room starts (phase 17,
## R08; OrosiGlass.apply). The step 1 test room sets `palette`; in the
## Scriptorium (gen/modules/sc_orosi.tscn) the generator puts its pick by seed
## on the module as meta "palette", which wins.

## For pictures and tests: every wall takes this palette instead ("" = its own).
static var palette_override: String = ""

@export var wall: NodePath
@export var palette: String = "spectrum"
## Dust motes drifting in the glass light (_dust).
@export var dust: bool = true

const DUST_AMOUNT: int = 420


func _ready() -> void:
	var w: Node3D = get_node_or_null(wall) as Node3D
	if w == null:
		push_warning("OrosiWallSetup: no wall at %s" % wall)
		return
	var pick: String = palette
	if get_parent() != null and get_parent().has_meta("palette"):
		pick = str(get_parent().get_meta("palette"))
	OrosiGlass.apply(w, palette_override if palette_override != "" else pick)
	if dust:
		w.add_child.call_deferred(_dust())


## Dust drifting in front of the glass (Motion in the brief): fine motes in a
## box over the far part of the hall, lit as everything else is, so they show
## only where the windows' light falls, and take its colours. One emitter.
static func _dust() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "Dust"
	var quad := QuadMesh.new()
	quad.size = Vector2(0.016, 0.016)
	var mat := StandardMaterial3D.new()
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.albedo_color = Color(0.75, 0.72, 0.66)
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 1.0
	quad.material = mat
	p.draw_pass_1 = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.amount = DUST_AMOUNT
	p.lifetime = 14.0
	p.preprocess = 14.0
	p.randomness = 1.0
	# Wall frame: X 0..12 along the wall, the hall toward +Z.
	p.position = Vector3(6.0, 3.0, 4.0)
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = Vector3(5.6, 2.8, 3.8)
	m.gravity = Vector3(0.0, -0.006, 0.0)
	m.direction = Vector3.UP
	m.spread = 180.0
	m.initial_velocity_min = 0.01
	m.initial_velocity_max = 0.05
	m.turbulence_enabled = true
	m.turbulence_noise_strength = 0.4
	m.turbulence_noise_scale = 4.0
	m.turbulence_influence_min = 0.03
	m.turbulence_influence_max = 0.1
	m.scale_min = 0.5
	m.scale_max = 1.3
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0))
	fade.set_color(1, Color(1, 1, 1, 0))
	fade.add_point(0.15, Color(1, 1, 1, 0.55))
	fade.add_point(0.8, Color(1, 1, 1, 0.4))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	m.color_ramp = ramp
	p.process_material = m
	p.visibility_aabb = AABB(Vector3(-6.5, -3.5, -4.5), Vector3(13.0, 7.0, 9.0))
	return p

class_name StackDrips
extends Node3D
## Seep water dripping from the Stack Galleries' vault into a puddle (stacks
## rework part 3, your note: drips and small pools of water here and there).
## Sits at the puddle's centre on the floor; on _ready, after a seeded few
## frames (so a gallery's drips don't all arrive on one frame), it adds a thin
## line of drops from drop_height and small splashes on the water. Particles
## only: no collision, no lights. The emitters use ConeDrips' sphere-shaped
## process material, so PipelineWarm's warm() already covers their shaders.

@export var drop_height: float = 4.6
@export var radius: float = 0.22
@export var drops: int = 3
@export var splashes: int = 6


func _ready() -> void:
	_build()


func _build() -> void:
	var wait: int = 1 + absi(hash(get_path())) % 12
	for _i: int in wait:
		await get_tree().process_frame
		if not is_inside_tree():
			return
	var fall := ConeDrips._falling(ConeDrips._drop_mesh(), drops, drop_height)
	fall.name = "Drops"
	fall.position = Vector3(0.0, drop_height, 0.0)
	fall.visibility_aabb = AABB(Vector3(-1, -drop_height - 0.5, -1), Vector3(2, drop_height + 1.0, 2))
	var fm: ParticleProcessMaterial = fall.process_material
	fm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	fm.emission_sphere_radius = radius
	fm.emission_shape_scale = Vector3(1, 0.0, 1)
	add_child(fall)
	var sp := ConeDrips._splashes()
	sp.name = "Splashes"
	sp.position = Vector3(0.0, 0.012, 0.0)
	sp.amount = splashes
	sp.visibility_aabb = AABB(Vector3(-1, -0.2, -1), Vector3(2, 1.0, 2))
	(sp.process_material as ParticleProcessMaterial).emission_sphere_radius = radius
	add_child(sp)

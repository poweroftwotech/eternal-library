@tool
class_name ShelfFill
extends MultiMeshInstance3D
## Books for a shelf recess as one MultiMesh (ENVIRONMENT_PLAN.md 4.3 SHELF_FILL).
## Origin = the recess socket (recess centre, floor level, wall boundary). The
## default shelf levels match M_wall_shelfbay_4m. Seeded by the socket via the
## "seed" meta, so a room rebuilds the same books every time.

## Top surface of each shelf board, in metres above the floor.
@export var shelf_levels: PackedFloat32Array = [0.17, 0.59, 1.01, 1.43]
@export var half_width: float = 1.44
## z of the shelf back (books stand against it) and the shelf front.
@export var back_z: float = 0.22
@export var front_z: float = -0.24
@export_range(0.0, 1.0, 0.01) var density: float = 0.9
## Collapsed recess: most books lie on the floor and spill into the room.
@export var fallen: bool = false
@export var palette: PackedColorArray = [
	Color(0.48, 0.17, 0.13), Color(0.17, 0.25, 0.42), Color(0.42, 0.29, 0.12), Color(0.18, 0.36, 0.29),
	Color(0.54, 0.42, 0.17), Color(0.29, 0.16, 0.29), Color(0.64, 0.33, 0.23), Color(0.78, 0.71, 0.54)]

static var _material: StandardMaterial3D


func _ready() -> void:
	build(int(get_meta("seed", 7)))


func build(seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var xforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	var keep: float = density * (0.25 if fallen else 1.0)
	for level: float in shelf_levels:
		var x: float = -half_width
		while x < half_width - 0.05:
			var w: float = rng.randf_range(0.04, 0.09)
			var h: float = rng.randf_range(0.24, 0.36)
			var d: float = rng.randf_range(0.17, 0.23)
			if rng.randf() > keep:
				x += w * rng.randf_range(1.0, 4.0)
				continue
			var lean: float = 0.0 if rng.randf() > 0.08 else rng.randf_range(-0.25, 0.25)
			var basis := Basis(Vector3.FORWARD, lean).scaled(Vector3(w, h, d))
			xforms.append(Transform3D(basis, Vector3(x + w * 0.5, level + h * 0.5, back_z - d * 0.5)))
			colors.append(palette[rng.randi() % palette.size()] * rng.randf_range(0.8, 1.15))
			x += w + 0.004
	if fallen:
		for i: int in rng.randi_range(25, 45):
			var w: float = rng.randf_range(0.14, 0.24)
			var t: float = rng.randf_range(0.03, 0.07)
			var d: float = rng.randf_range(0.18, 0.26)
			var p := Vector3(rng.randf_range(-half_width, half_width), t * 0.5 + rng.randf() * 0.12 * float(i % 3),
				rng.randf_range(front_z - 0.9, back_z - 0.1))
			var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(w, t, d))
			xforms.append(Transform3D(basis, p))
			colors.append(palette[rng.randi() % palette.size()] * rng.randf_range(0.7, 1.0))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	mm.mesh = box
	mm.instance_count = xforms.size()
	for i: int in xforms.size():
		mm.set_instance_transform(i, xforms[i])
		mm.set_instance_color(i, colors[i])
	multimesh = mm
	material_override = book_material()


static func book_material() -> StandardMaterial3D:
	if _material == null:
		var base: Material = PxMaterial.get_or_create("book_leather")
		_material = (base.duplicate() if base != null else StandardMaterial3D.new()) as StandardMaterial3D
		_material.vertex_color_use_as_albedo = true
		_material.resource_name = "book_leather_tinted"
	return _material

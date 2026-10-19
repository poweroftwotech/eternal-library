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
## Collapsed recess: most books lie on the floor and spill into the room. Spill
## in front of the wall face settles onto whatever is below it after the first
## physics frames: the hall floor, a gallery slab, a stair, or the floor of
## the storey below for an upper recess with nothing in front (step 4.0 of the
## weathering slice). Child meshes named "*__spill*" (broken boards) settle too.
@export var fallen: bool = false
## Wall face in socket space (the room is -Z): only spill in front of it settles.
@export var face_z: float = -0.3
## Spill rays start this high above the socket floor and reach this far down.
@export var settle_from: float = 0.65
@export var settle_drop: float = 12.0
@export var palette: PackedColorArray = [
	Color(0.48, 0.17, 0.13), Color(0.17, 0.25, 0.42), Color(0.42, 0.29, 0.12), Color(0.18, 0.36, 0.29),
	Color(0.54, 0.42, 0.17), Color(0.29, 0.16, 0.29), Color(0.64, 0.33, 0.23), Color(0.78, 0.71, 0.54)]

static var _material: StandardMaterial3D
## Instance transforms of the last build(), kept on the CPU: MultiMesh data
## lives in the rendering server and reads back empty under the headless
## dummy renderer, so Validate Room measures these instead.
var built_transforms: Array[Transform3D] = []
## Spill instance index -> height of its origin above the surface it rests on.
var spill_rest: Dictionary[int, float] = {}


func _ready() -> void:
	build(int(get_meta("seed", 7)))
	if fallen:
		_settle_when_ready()


func build(seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var xforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	var keep: float = density * (0.25 if fallen else 1.0)
	spill_rest.clear()
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
		# Inset by a rotated book's reach (<= 0.18 m) so spill stays inside the opening.
		var reach: float = half_width - 0.18
		for i: int in rng.randi_range(25, 45):
			var w: float = rng.randf_range(0.14, 0.24)
			var t: float = rng.randf_range(0.03, 0.07)
			var d: float = rng.randf_range(0.18, 0.26)
			# Draw order x, height, z as before, so existing seeds keep their layout.
			var px: float = rng.randf_range(-reach, reach)
			var rest: float = t * 0.5 + rng.randf() * 0.12 * float(i % 3)
			var p := Vector3(px, rest, rng.randf_range(front_z - 0.9, back_z - 0.1))
			var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(w, t, d))
			spill_rest[xforms.size()] = rest
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
	built_transforms = xforms
	material_override = book_material()


static func book_material() -> StandardMaterial3D:
	if _material == null:
		var base: Material = PxMaterial.get_or_create("book_leather")
		_material = (base.duplicate() if base != null else StandardMaterial3D.new()) as StandardMaterial3D
		_material.vertex_color_use_as_albedo = true
		_material.resource_name = "book_leather_tinted"
	return _material


## Bodies join the physics space only after a physics step, so wait two.
func _settle_when_ready() -> void:
	if not is_inside_tree():
		return
	await get_tree().physics_frame
	await get_tree().physics_frame
	if is_inside_tree():
		settle()


## Rests spill in front of the wall face on the first surface below it.
## Returns how many items moved.
func settle() -> int:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var moved: int = 0
	for i: int in spill_rest:
		var xf: Transform3D = built_transforms[i]
		if xf.origin.z > face_z:
			continue      # still inside the recess
		var y: Variant = _surface_below(space, xf.origin.x, xf.origin.z)
		if y == null:
			continue
		xf.origin.y = float(y) + spill_rest[i]
		built_transforms[i] = xf
		multimesh.set_instance_transform(i, xf)
		moved += 1
	for mesh: MeshInstance3D in spill_meshes():
		var box: AABB = global_transform.affine_inverse() * mesh.global_transform * mesh.get_aabb()
		var centre: Vector3 = box.get_center()
		if centre.z > face_z:
			continue
		var y: Variant = _surface_below(space, centre.x, centre.z)
		if y == null:
			continue
		mesh.global_position += global_basis.y.normalized() * (float(y) - box.position.y)
		moved += 1
	return moved


## Meshes under this fill named "*__spill*" (floor-lying parts of a candidate).
func spill_meshes() -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for n: Node in find_children("*__spill*", "MeshInstance3D", true, false):
		out.append(n as MeshInstance3D)
	return out


## Socket-space height of the first collision surface below (x, z), or null.
func _surface_below(space: PhysicsDirectSpaceState3D, x: float, z: float) -> Variant:
	var from: Vector3 = global_transform * Vector3(x, settle_from, z)
	var to: Vector3 = global_transform * Vector3(x, -settle_drop, z)
	var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 1))
	return to_local(hit["position"]).y if not hit.is_empty() else null

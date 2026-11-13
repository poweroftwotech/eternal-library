class_name BlobShadow
extends RefCounted
## The soft shadow under a small animal (shaders/creature_shadow.gdshader): a
## flat quad just off the floor or wall it is on. Drawn, not cast: small
## animals cast no real shadows (phase 19 Q12). A cat has one of its own (a
## MultiMesh of one); a room's rats or geckos share one (`many`, then
## `place` each one as its animal moves). Give the MultiMesh a custom_aabb:
## it starts with every shadow hidden, so its own box is empty and it would
## never be drawn. (A plain MeshInstance3D with this material did not draw
## at all in tests, 2026-11-13; the MultiMesh does.)

const SHADER: Shader = preload("res://shaders/creature_shadow.gdshader")

static var _material: ShaderMaterial
static var _quad: PlaneMesh


static func material() -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = SHADER
		_material.render_priority = 1     # after see-through things it lies on (a rug's fringe, a cushion): they would paint over it
	return _material


## A unit quad facing up (1 m by 1 m; scale it to the shadow's size).
static func quad() -> PlaneMesh:
	if _quad == null:
		_quad = PlaneMesh.new()
		_quad.size = Vector2.ONE
	return _quad




## `count` shadows in one MultiMesh, all hidden until placed.
static func many(count: int) -> MultiMeshInstance3D:
	var mmi := MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = quad()
	mm.instance_count = count
	for i: int in count:
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ZERO), Vector3.ZERO))
	mmi.multimesh = mm
	mmi.material_override = material()
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mmi


## Puts shadow `i` at `at` (in the MultiMesh's own space) on a surface whose
## normal is `up`, its long side along `ahead`, `size` m (across, along).
## Zero size hides it.
static func place(shadows: MultiMeshInstance3D, i: int, at: Vector3, up: Vector3, ahead: Vector3, size: Vector2) -> void:
	if size == Vector2.ZERO:
		shadows.multimesh.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ZERO), Vector3.ZERO))
		return
	var z: Vector3 = (ahead - up * ahead.dot(up)).normalized()
	if z == Vector3.ZERO:
		z = up.cross(Vector3.RIGHT).normalized()
	var x: Vector3 = up.cross(z).normalized()
	shadows.multimesh.set_instance_transform(i, Transform3D(Basis(x * size.x, up, z * size.y), at))

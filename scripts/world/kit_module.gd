@tool
class_name KitModule
extends Node3D
## Root of a kit module wrapper scene (kit/modules/<family>/<name>.tscn).
##
## The child is the imported .glb; the exported fields below are filled from the
## Blender custom properties by tools/kit_catalog.gd and drive generators and the
## Kit dock. Add Godot-only extras (particles, sounds, sockets) as children of
## this node; the catalog tool never removes them.
##
## Conventions (ENVIRONMENT_PLAN.md 3.1): 4 m bays and storeys; origin at floor
## level. An edge module runs along +X from the origin with its interior facing
## -Z; a cell occupies +X and -Z from the origin; a post is centred on a corner.

const BAY: float = 4.0
const STOREY: float = 4.0
## Render layer 20: meshes of edge, cell and post modules (the architecture)
## are on it as well as layer 1; weathering decals project only onto it, so
## rugs, tables, lanterns and dressing never take a stain.
const DECAL_LAYER: int = 1 << 19

enum Shape { EDGE, CELL, POST, FREE }

@export var shape: Shape = Shape.FREE:
	set(value):
		shape = value
		_refresh_outline()
@export var family: String = ""
## Cells along X, storeys along Y, cells along -Z.
@export var size_cells: Vector3i = Vector3i.ZERO:
	set(value):
		size_cells = value
		_refresh_outline()
## Edge signature for EDGE modules: solid, recess, opening_3m, door, gallery, ...
@export var edge: String = ""
@export var tags: PackedStringArray = []
## Relative pick weight for generators.
@export_range(0.0, 100.0, 0.1) var weight: float = 1.0
@export var source_glb: String = ""
## Draw the grid footprint in the editor.
@export var show_outline: bool = true:
	set(value):
		show_outline = value
		_refresh_outline()

var _outline: MeshInstance3D


func _ready() -> void:
	_refresh_outline()


static func shape_from_string(text: String) -> Shape:
	match text:
		"edge":
			return Shape.EDGE
		"cell":
			return Shape.CELL
		"post":
			return Shape.POST
	return Shape.FREE


## Footprint in metres, for snapping and validation.
func footprint() -> AABB:
	var sx: float = maxf(size_cells.x, 0) * BAY
	var sy: float = maxf(size_cells.y, 0) * STOREY
	var sz: float = maxf(size_cells.z, 0) * BAY
	match shape:
		Shape.CELL:
			return AABB(Vector3(0, 0, -sz), Vector3(sx, sy, sz))
		Shape.EDGE:
			return AABB(Vector3(0, 0, -0.3), Vector3(sx, sy, 0.6))
		Shape.POST:
			return AABB(Vector3(-0.5, 0, -0.5), Vector3(1, sy, 1))
	return AABB()


func _refresh_outline() -> void:
	if not is_inside_tree() or not Engine.is_editor_hint():
		return
	if _outline != null:
		_outline.queue_free()
		_outline = null
	if not show_outline or shape == Shape.FREE:
		return
	var box: AABB = footprint()
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	var y: float = 0.02
	var corners: Array[Vector3] = [
		Vector3(box.position.x, y, box.position.z), Vector3(box.end.x, y, box.position.z),
		Vector3(box.end.x, y, box.end.z), Vector3(box.position.x, y, box.end.z)]
	for i: int in 4:
		mesh.surface_add_vertex(corners[i])
		mesh.surface_add_vertex(corners[(i + 1) % 4])
	if shape == Shape.EDGE:      # interior arrow
		mesh.surface_add_vertex(Vector3(box.get_center().x, y, 0))
		mesh.surface_add_vertex(Vector3(box.get_center().x, y, -1.0))
	mesh.surface_end()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.3, 0.9, 1.0)
	mat.no_depth_test = true
	_outline = MeshInstance3D.new()
	_outline.mesh = mesh
	_outline.material_override = mat
	_outline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_outline, false, Node.INTERNAL_MODE_BACK)   # internal: never saved

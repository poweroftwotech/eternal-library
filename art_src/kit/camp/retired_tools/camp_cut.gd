extends RefCounted
## Cuts the code-built camp (scripts/world.gd and its passes) into kit pieces
## (phase 7, docs/environment/camp-rebuild-approval.md). Used by
## tools/camp_extract.gd, which writes the pieces, and by
## tests/camp_kit_capture.gd, which hides what they replace in the old camp.
##
## The pieces are listed in art_src/kit/camp/pieces.json, each:
##   name        the kit piece (M_<name> in kit_camp.blend)
##   anchor      [x, y, z] in the camp: the piece's origin (its foot)
##   yaw         degrees about Y (the piece's -Z faces where the camp's did)
##   boxes       [[x0, y0, z0, x1, y1, z1], ...] in the camp: a mesh is the
##               piece's if the middle of its bounds is in one; a multimesh
##               instance if its origin is
##   include     optional: only meshes of these camp materials ("FLOOR": the floor's)
##   exclude     optional: never these (FLOOR is always left out unless included)
##   drop        optional: true for what a change to the camp covered up (the
##               space under the gallery): cut, but never made into a piece
## A mesh goes to the first piece that claims it. Animated parts (the
## world's "dynamic" nodes: flames, steam, gatherables), particles, lights
## and shader materials but the leaves' wind (water) aren't cut: the camp's
## bake keeps them.

const LAYOUT: String = "res://art_src/kit/camp/pieces.json"
## The floor's materials, left to the floor's own pieces.
const FLOOR: PackedStringArray = ["floor_grout", "paving", "soil", "floor_stone", "camp_paving"]
## The leaves the camp moves in the wind (atmosphere.gd).
const FOLIAGE: PackedStringArray = ["tree_leaf", "ivy_leaf", "fern", "leaf", "grass"]
const WIND: String = "res://shaders/foliage_wind.gdshader"


static func load_pieces() -> Array:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT))
	return (data as Dictionary).get("pieces", []) if data is Dictionary else []


## The piece's frame in the camp.
static func frame(piece: Dictionary) -> Transform3D:
	var a: Array = piece["anchor"]
	return Transform3D(Basis(Vector3.UP, deg_to_rad(float(piece.get("yaw", 0.0)))), Vector3(a[0], a[1], a[2]))


static func boxes(piece: Dictionary) -> Array[AABB]:
	var out: Array[AABB] = []
	for b: Array in piece["boxes"]:
		var lo := Vector3(minf(b[0], b[3]), minf(b[1], b[4]), minf(b[2], b[5]))
		var hi := Vector3(maxf(b[0], b[3]), maxf(b[1], b[4]), maxf(b[2], b[5]))
		out.append(AABB(lo, hi - lo))
	return out


## The camp factory's name for a material ("" if it made none by that object).
## The leaves' wind material (atmosphere.gd swaps the factory's tree_leaf,
## ivy_leaf, fern, leaf and grass for one each) is foliage_<that name>.
static func material_name(art: Object, m: Material) -> String:
	if m == null:
		return ""
	if is_foliage(m):
		var tex: Variant = (m as ShaderMaterial).get_shader_parameter("leaf_texture")
		for k: String in FOLIAGE:
			if art.materials.has(k) and (art.materials[k] as StandardMaterial3D).albedo_texture == tex:
				return "foliage_" + k
	for k: String in art.materials:
		if art.materials[k] == m:
			return k
	# A pass's copy of one (organic_pass's paving is floor_stone's, retinted):
	# <its name>_v<a short hash of what differs>.
	if m is StandardMaterial3D and (m as StandardMaterial3D).albedo_texture != null:
		var s := m as StandardMaterial3D
		for k: String in art.materials:
			if art.materials[k] is StandardMaterial3D and (art.materials[k] as StandardMaterial3D).albedo_texture == s.albedo_texture:
				return "%s_v%04x" % [k, hash([s.albedo_color, s.uv1_scale, s.vertex_color_use_as_albedo, s.normal_scale, s.roughness]) & 0xffff]
	return str(m.resource_name)


## A floor material, or a pass's copy of one.
static func is_floor(mat_name: String) -> bool:
	for f: String in FLOOR:
		if mat_name == f or mat_name.begins_with(f + "_v"):
			return true
	return false

static func is_foliage(m: Material) -> bool:
	return m is ShaderMaterial and (m as ShaderMaterial).shader != null and (m as ShaderMaterial).shader.resource_path == WIND


static func is_dynamic(world: Node, n: Node) -> bool:
	var a: Node = n
	while a != null and a != world:
		if a.has_meta("dynamic"):
			return true
		a = a.get_parent()
	return false


## Whether a mesh (or instance) of material `mat_name` centred at `p` is the piece's.
static func takes(piece: Dictionary, regions: Array[AABB], mat_name: String, p: Vector3) -> bool:
	var inc: Array = piece.get("include", [])
	if not inc.is_empty() and not inc.has(mat_name) and not (inc.has("FLOOR") and is_floor(mat_name)):
		return false
	if (piece.get("exclude", []) as Array).has(mat_name) or (inc.is_empty() and is_floor(mat_name)):
		return false
	for r: AABB in regions:
		if r.has_point(p):
			return true
	return false


## What each piece takes from the built camp: {piece name: {meshes:
## [MeshInstance3D], instances: [[MultiMeshInstance3D, index]], shapes:
## [CollisionShape3D]}}. Collision shapes of static bodies go with the piece
## whose boxes hold their middle (floor bodies too, unless a piece's
## include leaves them out).
static func cut(world: Node3D, art: Object, pieces: Array) -> Dictionary:
	var out: Dictionary = {}
	var regions: Dictionary = {}
	for piece: Dictionary in pieces:
		out[piece["name"]] = {"meshes": [], "instances": [], "shapes": []}
		regions[piece["name"]] = boxes(piece)
	for n: Node in world.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null or not mi.is_visible_in_tree() or is_dynamic(world, mi) or (mi.material_override is ShaderMaterial and not is_foliage(mi.material_override)):
			continue
		var m: Material = mi.material_override if mi.material_override != null else (mi.mesh.surface_get_material(0) if mi.mesh.get_surface_count() > 0 else null)
		var at: Vector3 = (mi.global_transform * mi.get_aabb()).get_center()
		var name: String = material_name(art, m)
		for piece: Dictionary in pieces:
			if takes(piece, regions[piece["name"]], name, at):
				(out[piece["name"]]["meshes"] as Array).append(mi)
				break
	for n: Node in world.find_children("*", "MultiMeshInstance3D", true, false):
		var mmi := n as MultiMeshInstance3D
		var mm: MultiMesh = mmi.multimesh
		if mm == null or not mmi.is_visible_in_tree() or (mmi.material_override is ShaderMaterial and not is_foliage(mmi.material_override)):
			continue
		var name: String = material_name(art, mmi.material_override)
		for i: int in mm.instance_count:
			var at: Vector3 = mmi.global_transform * mm.get_instance_transform(i).origin
			for piece: Dictionary in pieces:
				if takes(piece, regions[piece["name"]], name, at):
					(out[piece["name"]]["instances"] as Array).append([mmi, i])
					break
	for n: Node in world.find_children("*", "CollisionShape3D", true, false):
		var cs := n as CollisionShape3D
		if not cs.get_parent() is StaticBody3D or cs.get_parent() is Area3D or cs.shape == null or is_dynamic(world, cs):
			continue
		if cs.get_parent().get_script() != null:
			continue      # an interaction (the pot, gatherables): the bake keeps those
		var at: Vector3 = cs.global_position
		for piece: Dictionary in pieces:
			var inc: Array = piece.get("include", [])
			if not inc.is_empty() and not piece.get("collision", false):
				continue
			if regions[piece["name"]].any(func(r: AABB) -> bool: return r.has_point(at)):
				(out[piece["name"]]["shapes"] as Array).append(cs)
				break
	return out

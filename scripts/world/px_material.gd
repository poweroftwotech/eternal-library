class_name PxMaterial
extends RefCounted
## Shared pixel-material library for kit modules (ENVIRONMENT_PLAN.md 3.3).
##
## Materials live as editable resources in res://kit/materials/<name>.tres.
## The first time a name is requested the material is built from the pixel maps
## in assets/textures/px (same rules as asset_factory.gd apply_pixel_maps) and
## saved; after that the .tres is the source of truth, so tweaking it in the
## Inspector changes every module that uses it.

const PX_DIR: String = "res://assets/textures/px/"
const LIB_DIR: String = "res://kit/materials/"
## Glow colours for slot names starting with "emit_". Unknown emit_ names use amber.
const EMIT_COLORS: Dictionary = {
	"emit_lantern": Color(1.0, 0.72, 0.38),
	"emit_glass_cool": Color(0.62, 0.86, 1.0),
	"emit_fungus": Color(0.31, 0.82, 0.75),
}

static var _manifest: Dictionary = {}
static var _density: float = 32.0


static func manifest() -> Dictionary:
	if _manifest.is_empty():
		for file: String in ["manifest.json", "manifest_ext.json"]:
			var path: String = PX_DIR + file
			if not FileAccess.file_exists(path):
				continue
			var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
			if data is Dictionary:
				_manifest.merge(data.get("materials", {}), true)
				if data.has("texel_density"):
					_density = float(data["texel_density"])
	return _manifest


static func has_material(mat_name: String) -> bool:
	return mat_name.begins_with("emit_") or manifest().has(mat_name) or ResourceLoader.exists(LIB_DIR + mat_name + ".tres")


## Returns the shared library material, creating and saving it if needed.
## Returns null for names that have neither a .tres nor pixel maps.
static func get_or_create(mat_name: String) -> Material:
	var path: String = LIB_DIR + mat_name + ".tres"
	if ResourceLoader.exists(path):
		return load(path)
	var built: StandardMaterial3D = build(mat_name)
	if built == null:
		return null
	DirAccess.make_dir_recursive_absolute(LIB_DIR)
	built.resource_name = mat_name
	var err: Error = ResourceSaver.save(built, path)
	if err != OK:
		push_warning("PxMaterial: could not save %s (%s); using an embedded copy." % [path, error_string(err)])
		return built
	return ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE)


static func build(mat_name: String) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS_ANISOTROPIC
	if mat_name.begins_with("emit_"):
		var glow: Color = EMIT_COLORS.get(mat_name, Color(1.0, 0.72, 0.38))
		result.albedo_color = glow
		result.emission_enabled = true
		result.emission = glow
		result.emission_energy_multiplier = 2.5
		result.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		return result
	var info: Dictionary = manifest().get(mat_name, {})
	if info.is_empty():
		return null
	result.albedo_texture = load(PX_DIR + mat_name + ".png")
	result.roughness = 1.0
	result.metallic_specular = 0.65
	var mapping: String = info.get("mapping", "world")
	if mapping == "card":
		result.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		result.cull_mode = BaseMaterial3D.CULL_DISABLED
		return result
	result.roughness_texture = load(PX_DIR + mat_name + "_rough.png")
	result.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	if mapping == "world":
		var size: Array = info.get("size", [32, 32])
		var scale := Vector3(_density / float(size[0]), _density / float(size[1]), _density / float(size[0]))
		result.uv1_triplanar = true
		result.uv1_world_triplanar = true
		result.uv1_scale = scale
		result.set_meta("px_scale", scale)
		result.normal_enabled = true
		result.normal_texture = load(PX_DIR + mat_name + "_normal.png")
		result.normal_scale = 0.55
	return result


## Magenta stand-in for slot names with no material, so mistakes are visible.
static func missing() -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = Color(1, 0, 1)
	result.resource_name = "MISSING"
	return result

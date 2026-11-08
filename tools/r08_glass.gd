extends SceneTree
## Writes the Orosi Scriptorium's glass (phase 17, R08; scripts/gen/orosi_glass.gd):
##   assets/textures/px/sc_glass_<mid|side>_<palette>.png   each window's glass
##   kit/materials/emit_sc_glass_<mid|side>[_<palette>].tres its material
##   kit/materials/emit_sc_lumenmoss.tres (+ px map)         the warm moss behind
##   assets/textures/px/sc_orosi_light_<0..2>_<palette>.png  each window's light picture,
##     read from the imported wall (kit/modules/walls/sc_orosi_wall.tscn), so run
##     this again after tools/export_kit.bat kit_scriptorium.blend, then --import.
## Run: --headless --script res://tools/r08_glass.gd

## Each window kind's size: half width, springing, rise (tools/kit_add_r08.py WINDOWS).
const KINDS: Dictionary = {"mid": [1.6, 3.2, 1.95], "side": [1.4, 3.0, 1.75]}
const DEFAULT_PALETTE: String = "spectrum"
const MOSS_SRC: String = "res://assets/textures/px/persian_glowmoss.png"
const MOSS_DST: String = "res://assets/textures/px/sc_lumenmoss.png"


func _init() -> void:
	for kind: String in KINDS:
		var k: Array = KINDS[kind]
		for palette: String in OrosiGlass.PALETTES:
			var img: Image = OrosiGlass.draw(k[0] * 2.0, k[1] + k[2], k[1], palette)
			img.save_png(ProjectSettings.globalize_path(OrosiGlass.glass_path(kind, palette)))
			_material("emit_sc_glass_%s_%s" % [kind, palette], OrosiGlass.glass_path(kind, palette))
		_material("emit_sc_glass_%s" % kind, OrosiGlass.glass_path(kind, DEFAULT_PALETTE))
	_moss()
	var made: int = _projectors()
	print("r08_glass: glass for %d palettes, %d light pictures" % [OrosiGlass.PALETTES.size(), made])
	quit()


func _material(mat_name: String, tex: String) -> void:
	var text: String = """[gd_resource type="ShaderMaterial" format=3]

[ext_resource type="Shader" path="res://shaders/sc_orosi_glass.gdshader" id="1_shader"]
[ext_resource type="Texture2D" path="%s" id="2_glass"]

[resource]
resource_name = "%s"
render_priority = 0
shader = ExtResource("1_shader")
shader_parameter/glass_tex = ExtResource("2_glass")
""" % [tex, mat_name]
	var f := FileAccess.open(OrosiGlass.MATERIAL_DIR + mat_name + ".tres", FileAccess.WRITE)
	f.store_string(text)
	f.close()


## The glowmoss's teal turned to the lumen's warm white-gold.
func _moss() -> void:
	var img := Image.load_from_file(ProjectSettings.globalize_path(MOSS_SRC))
	img.convert(Image.FORMAT_RGBA8)
	for y: int in img.get_height():
		for x: int in img.get_width():
			var c: Color = img.get_pixel(x, y)
			var v: float = maxf(c.r, maxf(c.g, c.b))
			img.set_pixel(x, y, Color(v, v * 0.86, v * 0.55, c.a))
	img.save_png(ProjectSettings.globalize_path(MOSS_DST))
	var text: String = """[gd_resource type="StandardMaterial3D" format=3]

[ext_resource type="Texture2D" path="%s" id="1_moss"]

[resource]
resource_name = "emit_sc_lumenmoss"
cull_mode = 2
shading_mode = 0
albedo_color = Color(0.9, 0.82, 0.6, 1)
albedo_texture = ExtResource("1_moss")
emission_enabled = true
emission = Color(1, 0.88, 0.6, 1)
emission_energy_multiplier = 0.9
uv1_scale = Vector3(0.5, 0.5, 0.5)
uv1_triplanar = true
texture_filter = 2
""" % MOSS_DST
	var f := FileAccess.open(OrosiGlass.MATERIAL_DIR + "emit_sc_lumenmoss.tres", FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _projectors() -> int:
	if not ResourceLoader.exists(OrosiGlass.WALL_SCENE):
		print("r08_glass: no wall at %s yet; export the kit, then run again" % OrosiGlass.WALL_SCENE)
		return 0
	var wall: Node3D = (load(OrosiGlass.WALL_SCENE) as PackedScene).instantiate()
	var p: Dictionary = OrosiGlass.parts(wall)
	var made: int = 0
	for i: int in p["lights"]:
		if not p["glass"].has(i):
			push_warning("r08_glass: light %d has no glass" % i)
			continue
		var light: SpotLight3D = p["lights"][i]
		var outline: PackedVector3Array = OrosiGlass.outline_of(p["glass"][i], wall)
		var xform: Transform3D = OrosiGlass._local_chain(light, wall)
		var angle: float = OrosiGlass.cone_for(xform, outline)
		for palette: String in OrosiGlass.PALETTES:
			var glass := Image.load_from_file(ProjectSettings.globalize_path(OrosiGlass.glass_path(OrosiGlass.kind_of(i), palette)))
			var pic: Image = OrosiGlass.project(xform, angle, outline, glass)
			pic.save_png(ProjectSettings.globalize_path(OrosiGlass.projector_path(i, palette)))
			made += 1
		print("r08_glass: window %d cone %.1f deg, %d outline points" % [i, angle, outline.size()])
	wall.free()
	return made

extends SceneTree
## Turns the card (foliage) library materials into swaying ShaderMaterials
## (weathering slice item 2):
##   godot --headless --path . --script res://tools/seed_foliage.gd
## kit/materials/<name>.tres for tree_leaf, leaf, ivy_leaf and fern become
## ShaderMaterials on shaders/kit_foliage.gdshader with the pixel map as
## leaf_texture. Additive: a material that already is a ShaderMaterial (e.g.
## tuned in the Inspector) is left alone. Keeps each file's UID.

const SHADER: String = "res://shaders/kit_foliage.gdshader"
## name -> [wind strength, tint]
const CARDS: Dictionary = {
	"tree_leaf": [0.065, Color(1, 1, 1)],
	"leaf": [0.035, Color(0.62, 0.78, 0.42)],     # grass blades (prototype's crack tufts)
	"ivy_leaf": [0.03, Color(1, 1, 1)],
	"fern": [0.03, Color(1, 1, 1)],
}


func _initialize() -> void:
	var made: PackedStringArray = []
	for card: String in CARDS:
		var path: String = PxMaterial.LIB_DIR + card + ".tres"
		if ResourceLoader.exists(path) and load(path) is ShaderMaterial:
			continue
		var uid: int = KitCatalogBuilder.header_uid(path) if ResourceLoader.exists(path) else ResourceUID.INVALID_ID
		var m := ShaderMaterial.new()
		m.resource_name = card
		m.shader = load(SHADER)
		m.set_shader_parameter("leaf_texture", load(PxMaterial.PX_DIR + card + ".png"))
		m.set_shader_parameter("wind_strength", CARDS[card][0])
		m.set_shader_parameter("tint", CARDS[card][1])
		ResourceSaver.save(m, path)
		if uid != ResourceUID.INVALID_ID:
			ResourceSaver.set_uid(path, uid)
		made.append(card)
	print("seed_foliage: ", "made " + ", ".join(made) if not made.is_empty() else "nothing to do")
	quit()

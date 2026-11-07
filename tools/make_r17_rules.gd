extends SceneTree
## Writes the R17 Ossuary of Books' module rules (gen/rules/r17_ossuary.tres) and
## grammar (gen/grammars/r17_ossuary.tres): the light-well's door, post and exit
## stub rules, and one rule per os:* slot of OssuaryGrammar.
##   godot --audio-driver Dummy --headless --path . --script res://tools/make_r17_rules.gd

const W: String = "res://kit/modules/walls/os_%s.tscn"
const SLOTS: PackedStringArray = ["straight", "bend", "tee", "cross", "end", "bier", "throat", "chamber", "plug", "candle", "lantern", "glow", "glow_small", "shrine",
	"item_long_body_a", "item_long_body_b", "item_long_old_a", "item_long_old_b", "item_long_books", "item_long_books_old", "item_long_bundles", "item_long_bundles_old",
	"item_upper_a", "item_upper_b", "item_upper_c", "item_upper_old_a", "item_upper_old_b", "item_upper_old_c",
	"item_nook_row", "item_nook_stack", "item_nook_bundle", "item_bier", "item_bier_old", "item_bier_rag", "shrine_old",
	"item_long_rag_a", "item_long_rag_b", "item_long_slump_a", "item_long_slump_b", "item_spill_a", "item_spill_b", "item_rock_low", "item_rock_high",
	"item_offer_cloth", "item_offer_bowl", "item_offer_flowers", "item_offer_tray", "item_web_a", "item_web_b"]
## Slots filled by another room's piece.
const SCENES: Dictionary = {"cave": "res://kit/modules/walls/bh_cave_straight.tscn", "life": "res://gen/modules/ossuary_life.tscn",
	"fog": "res://kit/modules/fx/ossuary_ground_fog.tscn", "puddle_a": "res://gen/modules/ossuary_puddle_a.tscn", "puddle_b": "res://gen/modules/ossuary_puddle_b.tscn",
	"vigil": "res://gen/modules/ossuary_vigil.tscn", "lore_laying_out": "res://gen/modules/ossuary_lore_laying_out.tscn",
	"lore_roll_of_candles": "res://gen/modules/ossuary_lore_roll_of_candles.tscn", "lore_those_who_wait": "res://gen/modules/ossuary_lore_those_who_wait.tscn"}


func _initialize() -> void:
	_scenes()
	var base: ModuleRules = load("res://gen/rules/r09_lightwell.tres")
	var rules := ModuleRules.new()
	var list: Array[ModuleRule] = []
	for r: ModuleRule in base.rules:
		if not r.slot.begins_with("cone:"):
			list.append(r.duplicate(true))
	for name: String in SLOTS:
		if not _add(list, name, W % name):
			quit(1)
			return
	for name: String in SCENES:
		if not _add(list, name, SCENES[name]):
			quit(1)
			return
	rules.rules = list
	var err: int = ResourceSaver.save(rules, "res://gen/rules/r17_ossuary.tres")
	var g := OssuaryGrammar.new()
	g.styles = PackedStringArray(["rock", "ossuary"])
	g.rules = load("res://gen/rules/r17_ossuary.tres")
	# Cold in the dark, so the flames are the only warmth (your walk of step 4).
	g.mood_tint = Color(0.45, 0.58, 0.8, 0.8)
	g.ambient_scale = 0.8
	err = maxi(err, ResourceSaver.save(g, "res://gen/grammars/r17_ossuary.tres"))
	print("make_r17_rules: %d rules, saved (%d)" % [list.size(), err])
	quit(err)


func _add(list: Array[ModuleRule], name: String, path: String) -> bool:
	var rule := ModuleRule.new()
	rule.slot = "os:" + name
	var ch := ModuleChoice.new()
	ch.scene = load(path)
	ch.weight = 1.0
	if ch.scene == null:
		push_error("make_r17_rules: missing %s" % path)
		return false
	var choices: Array[ModuleChoice] = [ch]
	rule.choices = choices
	list.append(rule)
	return true


## The things you can touch: a kit piece under the script that works it.
func _scenes() -> void:
	for letter: String in ["a", "b"]:
		var puddle: Node = (load("res://kit/dressing/stack_puddle_drip_%s.tscn" % letter) as PackedScene).instantiate()
		(puddle.get_node("Drips") as StackDrips).drop_height = 2.75    # the vault here
		var packed := PackedScene.new()
		packed.pack(puddle)
		ResourceSaver.save(packed, "res://gen/modules/ossuary_puddle_%s.tscn" % letter)
		puddle.free()
	_pack(ShrineCandle.new(), "ShrineCandle", "vigil", "res://gen/modules/ossuary_vigil.tscn")
	for book: String in OssuaryGrammar.LORE:
		var prop := WorldProp.new()
		prop.mass = 0.5
		prop.item = load("res://items/lore/lore_%s.tres" % book)
		_pack(prop, "LoreBook", "lore_book", "res://gen/modules/ossuary_lore_%s.tscn" % book)


func _pack(root_node: Node3D, name: String, piece: String, path: String) -> void:
	root_node.name = name
	var kit: Node = (load("res://kit/modules/walls/os_%s.tscn" % piece) as PackedScene).instantiate()
	root_node.add_child(kit)
	kit.owner = root_node
	var scene := PackedScene.new()
	scene.pack(root_node)
	ResourceSaver.save(scene, path)
	root_node.free()

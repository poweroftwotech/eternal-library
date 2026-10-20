extends SceneTree
## Creates the phase 2 generator data (ENVIRONMENT_PLAN.md 5.5.3-5.5.4) when it
## is missing:
##   godot --headless --path . --script res://tools/seed_gen.gd
## gen/rules/r02_brick.tres (ModuleRules) and gen/grammars/r02_stack_gallery.tres
## (StackGalleryGrammar). Additive: an existing rules file only gains rules for
## slots it doesn't cover yet (your weights stay), and an existing grammar is
## never touched. Tune both in the Inspector.

const WALLS: String = "res://kit/modules/walls/"
const RULES: String = "res://gen/rules/r02_brick.tres"
const GRAMMAR: String = "res://gen/grammars/r02_stack_gallery.tres"


func _initialize() -> void:
	var wanted: Array[ModuleRule] = [
		rule("edge:solid", [["wall_shelfbay_4m", 8.0], ["wall_plain_4m", 2.0]]),
		rule("edge:opening", [["wall_arch_3m", 1.0]]),
		rule("edge:door", [["wall_arch_3m", 1.0]]),
		rule("gable", [["wall_gable_4m", 1.0]]),
		rule("cell:floor", [["floor_4m", 1.0]]),
		rule("cell:ceiling", [["vault_bay_4m", 1.0]]),
		rule("post", [["post_pier", 1.0]]),
		rule("lamp", [["lantern_hanging", 1.0]]),
		rule("cell:ceiling_cross", [["vault_cross_4m", 1.0]]),     # slice 2: corridor corners
		# Slice 2: the two walls meeting at a turn's inner corner. A shelf bay's back
		# reaches 0.55 m behind its wall line, into the other wall's recess.
		rule("edge:solid_corner", [["wall_plain_4m", 1.0]]),
	]
	var rules: ModuleRules = load(RULES) if ResourceLoader.exists(RULES) else ModuleRules.new()
	var list: Array[ModuleRule] = rules.rules.duplicate()
	var added: int = 0
	for r: ModuleRule in wanted:
		if rules.rule_for(r.slot, r.styles) == null:
			list.append(r)
			added += 1
	if added > 0:
		rules.rules = list
		save(rules, RULES)
	if not ResourceLoader.exists(GRAMMAR):
		var g := StackGalleryGrammar.new()
		g.styles = PackedStringArray(["brick"])
		g.rules = load(RULES)
		save(g, GRAMMAR)
	quit()


func rule(slot: String, choices: Array) -> ModuleRule:
	var r := ModuleRule.new()
	r.slot = slot
	r.styles = PackedStringArray(["brick"])
	var list: Array[ModuleChoice] = []
	for c: Array in choices:
		var choice := ModuleChoice.new()
		choice.scene = load(WALLS + String(c[0]) + ".tscn")
		choice.weight = c[1]
		list.append(choice)
	r.choices = list
	return r


func save(res: Resource, path: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var err: Error = ResourceSaver.save(res, path)
	print("seed_gen: ", ("wrote " if err == OK else "FAILED %s " % error_string(err)) + path)

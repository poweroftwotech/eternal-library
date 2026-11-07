extends SceneTree
## Writes the R04 Grand Bazaar's module rules (gen/rules/r04_bazaar.tres) and
## grammar (gen/grammars/r04_bazaar.tres): the light-well's door, post and exit
## stub rules, and one rule per bz:* slot of BazaarGrammar.
##   godot --audio-driver Dummy --headless --path . --script res://tools/make_r04_rules.gd

const W: String = "res://kit/modules/walls/bz_%s.tscn"
const SLOTS: PackedStringArray = ["floor", "vault", "vault_eye", "rib", "shop_open", "shop_shut", "upper", "end",
	"cross", "side_open", "side_closed", "trade_rugs", "trade_copper", "trade_lamps", "trade_books", "trade_spices",
	"trade_curios", "trade_food", "awning_a", "awning_b", "shut_bar", "shut_crates", "pennants",
	"upper_broken", "pennants_rag", "keeper_a", "keeper_b", "keeper_c", "fig_a", "fig_b", "fig_c", "fig_d", "fig_e", "fig_f", "fig_g",
	"fig_h", "group_talk", "group_ring", "group_haggle", "fountain", "fountain_dry", "story", "story_bare", "shut_hooks", "shut_dust",
	"bare", "awning_rag_a", "awning_rag_b"]
## Slots whose scene is a script of its own, not a kit piece.
const SCENES: Dictionary = {"life": "res://gen/modules/bazaar_life.tscn", "rumours": "res://gen/modules/bazaar_rumours.tscn",
	"rumours_old": "res://gen/modules/bazaar_rumours_old.tscn"}


func _initialize() -> void:
	var base: ModuleRules = load("res://gen/rules/r09_lightwell.tres")
	var rules := ModuleRules.new()
	var list: Array[ModuleRule] = []
	for r: ModuleRule in base.rules:
		if not r.slot.begins_with("cone:"):
			list.append(r.duplicate(true))
	for name: String in SLOTS:
		var rule := ModuleRule.new()
		rule.slot = "bz:" + name
		var ch := ModuleChoice.new()
		ch.scene = load(W % name)
		ch.weight = 1.0
		if ch.scene == null:
			push_error("make_r04_rules: missing %s" % (W % name))
			quit(1)
			return
		var choices: Array[ModuleChoice] = [ch]
		rule.choices = choices
		list.append(rule)
	for name: String in SCENES:
		var rule := ModuleRule.new()
		rule.slot = "bz:" + name
		var ch := ModuleChoice.new()
		ch.scene = load(SCENES[name])
		ch.weight = 1.0
		var choices: Array[ModuleChoice] = [ch]
		rule.choices = choices
		list.append(rule)
	rules.rules = list
	var err: int = ResourceSaver.save(rules, "res://gen/rules/r04_bazaar.tres")
	var g := BazaarGrammar.new()
	g.styles = PackedStringArray(["rock", "bazaar"])
	g.rules = load("res://gen/rules/r04_bazaar.tres")
	# Saffron gold (the brief): daylight on yellow brick.
	g.mood_tint = Color(1.0, 0.86, 0.56, 0.25)
	err = maxi(err, ResourceSaver.save(g, "res://gen/grammars/r04_bazaar.tres"))
	print("make_r04_rules: %d rules, saved (%d)" % [list.size(), err])
	quit(err)

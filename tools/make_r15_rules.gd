extends SceneTree
## Writes the R15 Fungus Terraces' module rules (gen/rules/r15_fungus_terraces.tres)
## and grammar (gen/grammars/r15_fungus_terraces.tres): the light-well's door,
## post and exit stub rules, and one rule per ft:* slot of FungusTerracesGrammar.
##   godot --audio-driver Dummy --headless --path . --script res://tools/make_r15_rules.gd

const W: String = "res://kit/modules/walls/%s.tscn"
const D: String = "res://kit/modules/dressing/%s.tscn"
## slot -> [[scene, weight], ...]
const SLOTS: Dictionary = {
	"ft:foot": [[W % "ft_foot", 1.0]],
	"ft:top": [[W % "ft_top", 1.0]],
	"ft:row_0": [[W % "ft_row_0", 1.0]],
	"ft:row_1": [[W % "ft_row_1", 1.0]],
	"ft:row_2": [[W % "ft_row_2", 1.0]],
	"ft:cave": [[W % "bh_cave_straight", 1.0]],     # the passages (walk 1), the Bridge Hall's
	# Step 4: the life (FungusTerracesGrammar._place_life).
	"ft:patch_tended": [[D % "ft_patch_tended", 1.0]],
	"ft:patch_wild": [[D % "ft_patch_wild", 1.0]],
	"ft:patch_blight": [[D % "ft_patch_blight", 1.0]],
	"ft:worker_stoop": [[D % "ft_worker_stoop", 1.0]],
	"ft:worker_kneel": [[D % "ft_worker_kneel", 1.0]],
	"ft:worker_carry": [[D % "ft_worker_carry", 1.0]],
	"ft:bed_tools": [[D % "ft_bed_tools", 1.0]],
	"ft:shelter": [[D % "ft_shelter", 1.0]],
	"ft:life": [["res://gen/modules/terraces_life.tscn", 1.0]],
}


func _initialize() -> void:
	var base: ModuleRules = load("res://gen/rules/r09_lightwell.tres")
	var rules := ModuleRules.new()
	var list: Array[ModuleRule] = []
	for r: ModuleRule in base.rules:
		if not r.slot.begins_with("cone:"):
			list.append(r.duplicate(true))
	for slot: String in SLOTS:
		var rule := ModuleRule.new()
		rule.slot = slot
		var choices: Array[ModuleChoice] = []
		for c: Array in SLOTS[slot]:
			var ch := ModuleChoice.new()
			ch.scene = load(c[0])
			ch.weight = c[1]
			if ch.scene == null:
				push_error("make_r15_rules: missing %s" % c[0])
				quit(1)
				return
			choices.append(ch)
		rule.choices = choices
		list.append(rule)
	rules.rules = list
	var err: int = ResourceSaver.save(rules, "res://gen/rules/r15_fungus_terraces.tres")
	var g := FungusTerracesGrammar.new()
	g.styles = PackedStringArray(["rock", "fungus_terraces"])
	g.rules = load("res://gen/rules/r15_fungus_terraces.tres")
	# Violet (the brief: no room has it yet); a little bloom off the caps.
	g.mood_tint = Color(0.82, 0.66, 1.0, 0.35)
	g.glow_bloom = 0.12
	g.glow_intensity = 1.0
	g.glow_threshold = 0.85
	err = maxi(err, ResourceSaver.save(g, "res://gen/grammars/r15_fungus_terraces.tres"))
	print("make_r15_rules: %d rules, saved (%d)" % [list.size(), err])
	quit(err)

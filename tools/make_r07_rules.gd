extends SceneTree
## Writes the R07 Garden Court's module rules (gen/rules/r07_garden.tres) and
## grammar (gen/grammars/r07_garden.tres): the caravanserai's rules (its ring
## pieces, door and exit stub) and one rule per garden:* slot of
## GardenCourtGrammar (phase 13 step 1).
##   godot --headless --path . --script res://tools/make_r07_rules.gd

const W: String = "res://kit/modules/walls/%s.tscn"
const P: String = "res://kit/modules/persian/%s.tscn"
const DR: String = "res://kit/modules/dressing/%s.tscn"
## slot -> [[scene, weight], ...]
const SLOTS: Dictionary = {
	"garden:iwan": [[W % "garden_iwan", 1.0]],
	"garden:shaft": [[W % "garden_shaft_5x5", 1.0]],
	"garden:pool": [[DR % "garden_pool", 1.0]],
	"garden:rill": [[W % "garden_rill_4m", 1.0]],
	"garden:bed": [[W % "garden_bed_4m", 1.0]],
	"garden:talar": [[W % "garden_talar_bay", 1.0]],
	"garden:talar_door": [[W % "garden_talar_door", 1.0]],
	"garden:talar_corner": [[W % "garden_talar_corner", 1.0]],
	"garden:corridor": [[W % "garden_corridor_4m", 1.0]],
	"garden:tree_orchard": [[P % "persian_pomegranate", 1.0]],
	# Step 2: the life (props) and the wild state.
	"garden:life": [["res://gen/modules/garden_life.tscn", 1.0]],
	"garden:pool_dry": [[DR % "garden_pool_dry", 1.0]],
	"garden:rill_dry": [[W % "garden_rill_dry_4m", 1.0]],
	"garden:bed_wild": [[W % "garden_bed_wild_4m", 1.0]],
	"garden:bed_clip": [[W % "garden_bed_clip_4m", 1.0]],
	"garden:bed_clip_wild": [[W % "garden_bed_clip_wild_4m", 1.0]],
	"garden:talar_vines": [[DR % "garden_talar_vines", 1.0]],
	"garden:column": [[DR % "garden_column", 1.0]],
	"garden:column_ivy": [[DR % "garden_column_ivy_0", 1.0], [DR % "garden_column_ivy_1", 1.0]],
	"garden:planter": [[DR % "garden_planter", 1.0]],
	"garden:planter_wild": [[DR % "garden_planter_wild", 1.0]],
	"garden:shrub": [[DR % "garden_shrub", 1.0]],
	"garden:tree_old": [[DR % "garden_tree_old", 1.0]],
	"garden:tree_old_wild": [[DR % "garden_tree_old_wild", 1.0]],
	"garden:shelves": [[DR % "garden_niche_shelves", 1.0]],
	"garden:bench": [[DR % "garden_bench", 1.0]],
	"garden:traces": [[DR % "garden_traces", 1.0]],
	"garden:traces_old": [[DR % "garden_traces_old", 1.0]],
	"landmark:takht": [[DR % "landmark_takht", 1.0]],
	"garden:rug": [[DR % "rug_garden_small", 1.0]],
	"garden:cushion": [[DR % "floor_cushion", 1.0]],
	"garden:tray": [[DR % "tray_table", 1.0]],
	"garden:rubble": [[DR % "debris_rubble", 1.0]],
	"garden:vase_broken": [[DR % "prop_vase_floor_broken", 1.0]],
}


func _initialize() -> void:
	var base: ModuleRules = load("res://gen/rules/r05_court.tres")
	var rules := ModuleRules.new()
	var list: Array[ModuleRule] = []
	for r: ModuleRule in base.rules:
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
				push_error("make_r07_rules: missing %s" % c[0])
				quit(1)
				return
			choices.append(ch)
		rule.choices = choices
		list.append(rule)
	rules.rules = list
	var err: int = ResourceSaver.save(rules, "res://gen/rules/r07_garden.tres")
	var g := GardenCourtGrammar.new()
	g.styles = PackedStringArray(["brick", "court"])
	g.rules = load("res://gen/rules/r07_garden.tres")
	# Warm daylight white with blossom (the brief: warmer than the light-well's
	# green-gold and the Gorge's cool daylight); bloom nearly off (your walk: the sunlit court was blinding).
	g.glow_bloom = 0.02
	g.glow_intensity = 0.5
	g.glow_threshold = 1.6
	g.mood_tint = Color(1.0, 0.94, 0.9, 0.3)
	g.mood_tint = Color(1.0, 0.95, 0.88, 0.6)
	g.lamps_dark = true     # daylight only: the bays' reading lamps stay dark
	err = maxi(err, ResourceSaver.save(g, "res://gen/grammars/r07_garden.tres"))
	# Gone wild (Q5) is the room's State setting (RoomGrammar.state_options), not a file.
	print("make_r07_rules: %d rules, saved (%d)" % [list.size(), err])
	quit(err)

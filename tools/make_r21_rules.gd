extends SceneTree
## Writes the R21 Bridge Hall's module rules (gen/rules/r21_bridge_hall.tres)
## and grammar (gen/grammars/r21_bridge_hall.tres): the light-well's door,
## post and exit stub rules, and one rule per bh:* slot of BridgeHallGrammar.
##   godot --headless --path . --script res://tools/make_r21_rules.gd

const W: String = "res://kit/modules/walls/%s.tscn"
const P: String = "res://kit/modules/persian/%s.tscn"
## slot -> [[scene, weight], ...]
const SLOTS: Dictionary = {
	"bh:cave_straight": [[W % "bh_cave_straight", 1.0]],
	"bh:cave_bend": [[W % "bh_cave_bend", 1.0]],
	"bh:mouth": [[W % "bh_cave_mouth", 1.0]],
	"bh:old_door": [[P % "persian_carved_door_dark", 1.0]],
	"bh:roof_6": [[W % "bh_roof_5x6", 1.0]],
	"bh:roof_7": [[W % "bh_roof_5x7", 1.0]],
	"bh:roof_8": [[W % "bh_roof_5x8", 1.0]],
	"bh:pit_6": [[W % "bh_pit_5x6", 1.0]],
	"bh:pit_7": [[W % "bh_pit_5x7", 1.0]],
	"bh:pit_8": [[W % "bh_pit_5x8", 1.0]],
	"bh:bridge": [["res://gen/modules/bh_bridge.tscn", 1.0]],
	# The long walls, by storey: carved rock low down, dark windows just under
	# the deck, facades on the deck's storey and the one over it, rock at the top.
	"bh:wall_low": [[P % "persian_wall_rock", 3.0], [P % "persian_wall_rock_window_dark", 1.0]],
	"bh:wall_under": [[P % "persian_wall_rock_window_dark", 2.0], [P % "persian_wall_rock", 1.0], [P % "persian_wall_rock_door_dark", 0.5]],
	"bh:front_rock_lit": [[P % "persian_wall_rock_window", 1.0]],
	"bh:front_rock_dark": [[P % "persian_wall_rock_window_dark", 2.0], [P % "persian_wall_rock", 1.0], [P % "persian_wall_rock_door_dark", 0.4]],
	"bh:front_plaster_lit": [[P % "persian_wall_plaster_window", 1.0], [P % "persian_wall_plaster_window2", 1.0]],
	"bh:front_plaster_dark": [[P % "persian_wall_plaster_window_dark", 1.0], [P % "persian_wall_plaster_window2_dark", 1.0], [P % "persian_wall_plaster", 0.6], [P % "persian_wall_plaster_door", 0.3]],
	"bh:front_tile_lit": [[P % "persian_wall_tile_window", 1.0], [P % "persian_wall_tile_window2", 1.0]],
	"bh:front_tile_dark": [[P % "persian_wall_tile_window_dark", 1.0], [P % "persian_wall_tile_window2_dark", 1.0], [P % "persian_wall_tile", 0.6], [P % "persian_wall_tile_door", 0.3]],
	"bh:front_banai_lit": [[P % "persian_wall_banai_window", 1.0], [P % "persian_wall_banai_window2", 1.0]],
	"bh:front_banai_dark": [[P % "persian_wall_banai_window_dark", 1.0], [P % "persian_wall_banai_window2_dark", 1.0], [P % "persian_wall_banai", 0.6], [P % "persian_wall_banai_door", 0.3]],
	"bh:front_brick_lit": [[P % "persian_wall_brick_orosi", 1.0], [P % "persian_wall_brick_arcade", 1.0]],
	"bh:front_brick_dark": [[P % "persian_wall_brick_arcade_dark", 1.0], [P % "persian_wall_brick", 1.0]],
	"bh:moss": [[P % "persian_glowmoss", 1.0]],
	"bh:wall_top": [[P % "persian_wall_rock", 2.0], [P % "persian_wall_rock_window_dark", 1.0]],
}


func _initialize() -> void:
	# The end walls (step 2): the mouth in bay 1 or 3 on the entry's storey or the
	# far door's, the older bridge's door over or under the deck.
	var slots: Dictionary = SLOTS.duplicate()
	for h: int in [1, 3]:
		for v: String in ["lv_hi", "lv_lo", "up_lo", "dn_hi"]:
			slots["bh:end_c%d_%s" % [h, v]] = [[W % ("bh_end_wall_c%d_%s" % [h, v]), 1.0]]
	var base: ModuleRules = load("res://gen/rules/r09_lightwell.tres")
	var rules := ModuleRules.new()
	var list: Array[ModuleRule] = []
	for r: ModuleRule in base.rules:
		if not r.slot.begins_with("cone:"):
			list.append(r.duplicate(true))
	for slot: String in slots:
		var rule := ModuleRule.new()
		rule.slot = slot
		var choices: Array[ModuleChoice] = []
		for c: Array in slots[slot]:
			var ch := ModuleChoice.new()
			ch.scene = load(c[0])
			ch.weight = c[1]
			if ch.scene == null:
				push_error("make_r21_rules: missing %s" % c[0])
				quit(1)
				return
			choices.append(ch)
		rule.choices = choices
		list.append(rule)
	rules.rules = list
	var err: int = ResourceSaver.save(rules, "res://gen/rules/r21_bridge_hall.tres")
	var g := BridgeHallGrammar.new()
	g.styles = PackedStringArray(["brick", "bridge_hall"])
	g.rules = load("res://gen/rules/r21_bridge_hall.tres")
	# Silver-white mist, not blue (Q5: the galleries next door are blue); bloom
	# off the lit windows and the glowing pool.
	g.mood_tint = Color(0.86, 0.9, 0.94, 0.35)
	g.glow_bloom = 0.1
	g.glow_intensity = 1.0
	g.glow_threshold = 0.85
	err = maxi(err, ResourceSaver.save(g, "res://gen/grammars/r21_bridge_hall.tres"))
	print("make_r21_rules: %d rules, saved (%d)" % [list.size(), err])
	quit(err)

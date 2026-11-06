extends SceneTree
## Writes the R06 Domicile Quarter's module rules (gen/rules/r06_quarter.tres)
## and grammar (gen/grammars/r06_quarter.tres): the light-well's door, post and
## exit stub rules, and one rule per qt:* slot of QuarterGrammar.
##   godot --audio-driver Dummy --headless --path . --script res://tools/make_r06_rules.gd

const W: String = "res://kit/modules/walls/qt_%s.tscn"
## Slots filled from elsewhere: the room's life, the doors, the homes' furniture.
const D: String = "res://kit/modules/dressing/%s.tscn"
const R: String = "res://kit/dressing/%s.tscn"
var SCENES: Dictionary = {
	"qt:life": "res://gen/modules/quarter_life.tscn",
	"qt:home_door": "res://gen/modules/quarter_door.tscn",
	"qt:home_door_ajar": "res://gen/modules/quarter_door_ajar.tscn",
	"qt:x_books": R % "recess_books_full", "qt:x_books_untidy": R % "recess_books_untidy",
	"qt:x_hearth": R % "recess_hearth", "qt:x_pantry": D % "wall_pantry", "qt:x_herbs": R % "recess_herbs",
	"qt:x_books_webbed": R % "recess_books_webbed",
	"qt:x_traps": "res://gen/modules/quarter_traps.tscn", "qt:x_nets": "res://gen/modules/quarter_nets.tscn",
	"qt:x_shelves_broken": D % "recess_shelves_broken", "qt:x_cobwebs": D % "stack_cobwebs",
	"qt:x_rug_kilim": D % "rug_kilim_small", "qt:x_rug_gabbeh": D % "rug_gabbeh_small",
	"qt:x_reading_table": D % "low_reading_table", "qt:x_low_table": D % "low_table", "qt:x_cushion": D % "floor_cushion",
	"qt:x_pouf": D % "pouf", "qt:x_bed": D % "niche_bed", "qt:x_log": D % "niche_log", "qt:x_seat": D % "floor_seat",
	"qt:x_book_stack": D % "prop_book_stack", "qt:x_scroll": D % "prop_scroll", "qt:x_inkwell": D % "prop_inkwell",
	"qt:x_book_open": D % "prop_book_open", "qt:x_pot": D % "prop_pot", "qt:x_lamp": D % "prop_oil_lamp",
	"qt:x_vase": D % "prop_vase_floor", "qt:x_vase_broken": D % "prop_vase_floor_broken", "qt:x_rubble": D % "debris_rubble",
	"qt:x_tuft": D % "plant_crack_tuft", "qt:x_candles_spent": D % "stack_candles_spent",
	"qt:x_hearth_cold": D % "wall_hearth", "qt:x_books_fallen": R % "recess_books_fallen",
	"qt:x_fern": D % "plant_fern", "qt:x_moss": D % "plant_moss_cushion", "qt:x_ivy": D % "plant_ivy_hang",
	"qt:note_scholar": "res://gen/modules/quarter_note_scholar.tscn", "qt:note_family": "res://gen/modules/quarter_note_family.tscn",
	"qt:note_hunter": "res://gen/modules/quarter_note_hunter.tscn", "qt:note_abandoned": "res://gen/modules/quarter_note_abandoned.tscn",
	"qt:x_bedroll": "res://kit/modules/camp/camp_bedroll.tscn", "qt:x_pack": "res://kit/modules/camp/camp_pack.tscn",
}


func _slots() -> PackedStringArray:
	var out: PackedStringArray = ["pier", "pier_cap", "roof", "lane", "lane_plain", "stair", "lane_high", "gate", "sabat", "hauz",
		"rock_wall", "rock_wall_b", "rock_wall_lit", "rock_wall_top", "cavern", "glow",
		"rock_low", "rock_low_b", "rock_low_top", "cavern_neck_2", "cavern_neck_3", "badgir", "bath", "bath_portal", "pigeon",
		"door_lamp", "washing_a", "washing_b", "cloth", "chimney", "g_home_r", "g_home_c", "home_1", "home_2", "home_hides",
		"fig_stand", "fig_jar", "fig_sit", "fig_read", "fig_stir", "fig_mend", "rags"]
	for t: String in ["r", "c"]:
		for w: int in [2, 4]:
			out.append("cap_%s_%d" % [t, w])
			for k: String in ["door", "lit", "dark", "blank"]:
				out.append("g_%s_%s_%d" % [k, t, w])
			for k: String in ["lit", "dark", "blank"]:
				out.append("u_%s_%s_%d" % [k, t, w])
	return out


func _initialize() -> void:
	var base: ModuleRules = load("res://gen/rules/r09_lightwell.tres")
	var rules := ModuleRules.new()
	var list: Array[ModuleRule] = []
	for r: ModuleRule in base.rules:
		if not r.slot.begins_with("cone:"):
			list.append(r.duplicate(true))
	for name: String in _slots():
		var rule := ModuleRule.new()
		rule.slot = "qt:" + name
		var ch := ModuleChoice.new()
		ch.scene = load(W % name)
		ch.weight = 1.0
		if ch.scene == null:
			push_error("make_r06_rules: missing %s" % (W % name))
			quit(1)
			return
		var choices: Array[ModuleChoice] = [ch]
		rule.choices = choices
		list.append(rule)
	for slot: String in SCENES:
		var extra := ModuleRule.new()
		extra.slot = slot
		var lc := ModuleChoice.new()
		lc.scene = load(SCENES[slot])
		lc.weight = 1.0
		if lc.scene == null:
			push_error("make_r06_rules: missing %s" % SCENES[slot])
			quit(1)
			return
		var lcs: Array[ModuleChoice] = [lc]
		extra.choices = lcs
		list.append(extra)
	rules.rules = list
	var err: int = ResourceSaver.save(rules, "res://gen/rules/r06_quarter.tres")
	var g := QuarterGrammar.new()
	g.styles = PackedStringArray(["rock", "quarter"])
	g.rules = load("res://gen/rules/r06_quarter.tres")
	# Rose clay at dusk, muted (the brief): the walls carry the colour, the air
	# between them is cool, and only the windows are warm.
	g.mood_tint = Color(0.7, 0.66, 0.78, 0.4)
	err = maxi(err, ResourceSaver.save(g, "res://gen/grammars/r06_quarter.tres"))
	print("make_r06_rules: %d rules, saved (%d)" % [list.size(), err])
	quit(err)

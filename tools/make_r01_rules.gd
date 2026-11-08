extends SceneTree
## Writes gen/rules/r01_reading.tres and the four Reading Room versions
## (gen/grammars/r01_reading_*.tres), and four drafts of Grand Study to walk
## them in. Run once; after that the files are edited by hand or on the board.
##   godot --headless --audio-driver Dummy --path . --script res://tools/make_r01_rules.gd

const WALLS: String = "res://kit/modules/walls/%s.tscn"
const DRESSING: String = "res://kit/modules/dressing/%s.tscn"


func _initialize() -> void:
	call_deferred("run")


func rule(slot: String, path: String) -> ModuleRule:
	var c := ModuleChoice.new()
	c.scene = load(path)
	var r := ModuleRule.new()
	r.slot = slot
	r.choices = [c] as Array[ModuleChoice]
	return r


func run() -> void:
	var out := ModuleRules.new()
	var list: Array[ModuleRule] = []
	for p: Array in [["edge:solid", WALLS % "wall_shelfbay_4m"], ["edge:plain", WALLS % "wall_plain_4m"], ["edge:door", WALLS % "wall_arch_3m"],
			["cell:floor", WALLS % "floor_4m"], ["cell:vault", WALLS % "vault_hall_12m"], ["edge:iwan", WALLS % "wall_iwan_12m"],
			["edge:gable_12m", WALLS % "wall_gable_12m"], ["edge:gallery_end", WALLS % "gallery_end_12m"], ["edge:gallery_slab", WALLS % "gallery_slab_4m"],
			["edge:gallery_open_end", WALLS % "gallery_slab_4m_open_end"], ["edge:gallery_open_start", WALLS % "gallery_slab_4m_open_start"],
			["edge:gallery_stair", WALLS % "stair_gallery_8m"], ["edge:gallery_stair_r", WALLS % "stair_gallery_8m_r"],
			["post", WALLS % "post_pier_corbel"], ["post:pier", WALLS % "post_pier"], ["gallery:column", WALLS % "post_gallery_column"],
			["gallery:corner", WALLS % "post_gallery_column_corner"], ["gallery:corner_r", WALLS % "post_gallery_column_corner_r"],
			["lamp:cluster", WALLS % "lantern_cluster"], ["lamp:hanging", WALLS % "lantern_hanging"],
			["dressing:table", DRESSING % "low_reading_table"], ["dressing:seat", DRESSING % "floor_seat"], ["dressing:pouf", DRESSING % "pouf"],
			["dressing:tray", DRESSING % "tray_table"], ["dressing:vase", "res://props/prop_vase_floor.tscn"],
			["dressing:rug_hall", "res://gen/modules/rr_rug_hall.tscn"], ["dressing:rug_nook", "res://gen/modules/rr_rug_nook.tscn"],
			["stub:exit", "res://gen/modules/exit_glow.tscn"]]:
		list.append(rule(p[0], p[1]))
	var stacks: ModuleRules = load("res://gen/rules/r02_brick.tres")
	for s: String in ["dressing:rubble", "dressing:puddle", "fx:ground_fog"]:
		var r: ModuleRule = stacks.rule_for(s, PackedStringArray(["brick"]))
		if r == null:
			r = stacks.rule_for(s, PackedStringArray())
		if r == null:
			printerr("no stacks rule for ", s)
			continue
		list.append(r.duplicate(true))
	out.rules = list
	print("G rules ", ResourceSaver.save(out, "res://gen/rules/r01_reading.tres"))
	var rules: ModuleRules = load("res://gen/rules/r01_reading.tres")
	for v: Array in [["masonry", "masonry", 0], ["wood", "wood", 1]]:
		var g := ReadingRoomGrammar.new()
		g.variant_name = v[1]
		g.rules = rules
		var fixed: Dictionary[String, int] = {"gallery_build": int(v[2])}
		g.fixed_styles = fixed
		var a := LoreBookPin.new()
		a.socket = "Shell/edge_-1_0_0_W/Mesh/M_wall_shelfbay_4m/SOCKET_recess_fill"
		a.level = 3
		a.x = 0.35
		a.item = load("res://items/lore/lore_hollow_index.tres")
		var b := LoreBookPin.new()
		b.socket = "Shell/prop_upper_w_0/Mesh/M_wall_shelfbay_4m/SOCKET_recess_fill"
		b.level = 2
		b.x = -0.4
		b.item = load("res://items/lore/lore_lamps_remember.tres")
		var pins: Array[LoreBookPin] = [a, b]
		g.lore_books = pins
		print("G ", v[0], " ", ResourceSaver.save(g, "res://gen/grammars/r01_reading_%s.tres" % v[0]))
	var base: AreaRecipe = load("res://gen/recipes/grand_study.tres")
	DirAccess.make_dir_recursive_absolute("res://gen/recipes/drafts/grand_study")
	for v: String in ["masonry", "wood", "masonry_left", "wood_left"]:
		var d: AreaRecipe = base.duplicate(false)
		var s := AreaSlot.new()
		s.slot_id = "entrance"
		s.display_name = "The Reading Room"
		# Abandoned is the room's State setting (RoomGrammar.state_options), not a file.
		s.grammar = load("res://gen/grammars/r01_reading_%s.tres" % v.trim_suffix("_left"))
		if v.ends_with("_left"):
			s.tweaks = {"state": RoomGrammar.ABANDONED}
		s.pinned = true
		var slots: Array[AreaSlot] = [s]
		d.slots = slots
		var st := AreaGrow.new()
		st.grammar = load("res://gen/grammars/r02_stack_gallery.tres")
		st.slot_prefix = "stacks"
		st.display_name = "The Library Stacks"
		st.from = PackedStringArray(["entrance"])
		st.count = Vector2i(4, 4)
		var grow: Array[AreaGrow] = [st]
		d.grow = grow
		d.max_dead_ends = 0
		print("G draft ", v, " ", ResourceSaver.save(d, "res://gen/recipes/drafts/grand_study/r01_%s.tres" % v))
	quit(0)

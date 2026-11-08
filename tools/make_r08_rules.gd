extends SceneTree
## Writes the R08 Orosi Scriptorium's pieces for the generator (phase 17 step 2):
##   gen/modules/sc_orosi.tscn                  the orosi wall, the moss garden behind
##                                              it and the glass setup (palette from
##                                              the module's meta, set by the grammar)
##   gen/rules/r08_scriptorium.tres             one rule per sc:* slot, the rugs, the
##                                              floor and the exit stub
##   gen/grammars/r08_scriptorium.tres          ScriptoriumGrammar
##   gen/recipes/drafts/grand_study/scriptorium_test.tres
##                                              the Grand Study test copy (Q6): the
##                                              scriptorium first, stacks off its doors
##   godot --audio-driver Dummy --headless --path . --script res://tools/make_r08_rules.gd

const WALLS: String = "res://kit/modules/walls/%s.tscn"
const ORO: String = "res://gen/modules/sc_orosi.tscn"
const DRESSING: String = "res://kit/modules/dressing/%s.tscn"
const COPY: String = "res://gen/modules/sc_copy.tscn"
const LIFE: String = "res://gen/modules/scriptorium_life.tscn"


func _initialize() -> void:
	call_deferred("run")


func rule(slot: String, path: String) -> ModuleRule:
	var c := ModuleChoice.new()
	c.scene = load(path)
	if c.scene == null:
		push_error("make_r08_rules: missing %s" % path)
	var r := ModuleRule.new()
	r.slot = slot
	r.choices = [c] as Array[ModuleChoice]
	return r


func run() -> void:
	var err: int = _orosi_module()
	err = maxi(err, _script_module(COPY, "ScCopy", StaticBody3D.new(), load("res://scripts/world/scriptorium_copy.gd")))
	err = maxi(err, _script_module(LIFE, "ScriptoriumLife", Node3D.new(), load("res://scripts/gen/scriptorium_life.gd")))
	var list: Array[ModuleRule] = []
	for p: Array in [["sc:wall", WALLS % "sc_niche_wall_4m"], ["sc:door", WALLS % "sc_door_wall_4m"], ["sc:ceiling", WALLS % "sc_ceiling_12m"],
			["sc:orosi", ORO], ["cell:floor", WALLS % "floor_4m"], ["stub:exit", "res://gen/modules/exit_glow.tscn"],
			["sc:desk", DRESSING % "sc_copy_desk"], ["sc:desk_lamp", DRESSING % "sc_copy_desk_lamp"],
			["sc:copyist_write", DRESSING % "sc_copyist_write"], ["sc:copyist_read", DRESSING % "sc_copyist_read"],
			["sc:desk_left", DRESSING % "sc_copy_desk_left"], ["sc:desk_dust", DRESSING % "sc_copy_desk_dust"],
			["sc:desk_dust_lamp", DRESSING % "sc_copy_desk_dust_lamp"], ["sc:copy", COPY], ["sc:life", LIFE]]:
		list.append(rule(p[0], p[1]))
	for d: String in ScriptoriumGrammar.RUGS:
		list.append(rule("rug:" + d, "res://kit/modules/dressing/rug_%s_grand.tscn" % d))
	var rules := ModuleRules.new()
	rules.rules = list
	err = maxi(err, ResourceSaver.save(rules, "res://gen/rules/r08_scriptorium.tres"))
	var g := ScriptoriumGrammar.new()
	g.styles = PackedStringArray(["scriptorium"])
	g.rules = load("res://gen/rules/r08_scriptorium.tres")
	err = maxi(err, ResourceSaver.save(g, "res://gen/grammars/r08_scriptorium.tres"))
	err = maxi(err, _draft("scriptorium_test", {}))
	err = maxi(err, _draft("scriptorium_forgotten", {"state": "forgotten"}))
	print("make_r08_rules: %d rules, saved (%d)" % [list.size(), err])
	quit(err)


func _orosi_module() -> int:
	var root := Node3D.new()
	root.name = "ScOrosi"
	var wall: Node3D = (load(WALLS % "sc_orosi_wall") as PackedScene).instantiate()
	wall.name = "Wall"
	root.add_child(wall)
	wall.owner = root
	var garden: Node3D = (load(WALLS % "sc_moss_garden") as PackedScene).instantiate()
	garden.name = "Garden"
	root.add_child(garden)
	garden.owner = root
	var setup := OrosiWallSetup.new()
	setup.name = "Glass"
	setup.wall = NodePath("../Wall")
	root.add_child(setup)
	setup.owner = root
	var packed := PackedScene.new()
	var err: int = packed.pack(root)
	if err == OK:
		err = ResourceSaver.save(packed, ORO)
	root.free()
	return err


## The Grand Study test copies: the scriptorium is the first room (its entry is
## the door back to the Gorge), short stack galleries grow off its side doors.
## `tweaks` set the room's State (scriptorium_forgotten: the Forgotten version).
func _draft(file: String, tweaks: Dictionary) -> int:
	var base: AreaRecipe = load("res://gen/recipes/grand_study.tres")
	var d: AreaRecipe = base.duplicate(false)
	var s := AreaSlot.new()
	s.slot_id = "entrance"
	s.display_name = "The Orosi Scriptorium"
	s.grammar = load("res://gen/grammars/r08_scriptorium.tres")
	s.tweaks = tweaks
	s.pinned = true
	d.slots = [s] as Array[AreaSlot]
	var st := AreaGrow.new()
	st.grammar = load("res://gen/grammars/r02_stack_gallery.tres")
	st.slot_prefix = "stacks"
	st.display_name = "The Library Stacks"
	st.from = PackedStringArray(["entrance"])
	st.count = Vector2i(2, 2)
	d.grow = [st] as Array[AreaGrow]
	d.room_count = Vector2i(1, 3)
	d.max_dead_ends = 0
	DirAccess.make_dir_recursive_absolute("res://gen/recipes/drafts/grand_study")
	return ResourceSaver.save(d, "res://gen/recipes/drafts/grand_study/%s.tres" % file)


## A one-node module scene: `node` named `node_name` with `script`.
func _script_module(path: String, node_name: String, node: Node, script: Script) -> int:
	node.name = node_name
	node.set_script(script)
	var packed := PackedScene.new()
	var err: int = packed.pack(node)
	if err == OK:
		err = ResourceSaver.save(packed, path)
	node.free()
	return err

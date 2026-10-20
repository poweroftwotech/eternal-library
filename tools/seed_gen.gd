extends SceneTree
## Creates the phase 2 generator data (ENVIRONMENT_PLAN.md 5.5.3-5.5.4) when it
## is missing:
##   godot --headless --path . --script res://tools/seed_gen.gd
## gen/rules/r02_brick.tres (ModuleRules) and gen/grammars/r02_stack_gallery.tres
## (StackGalleryGrammar). Additive: an existing rules file only gains rules for
## slots it doesn't cover yet (your weights stay), and an existing grammar only
## gains a lamp_lit_by_distance curve if it has none. Tune both in the Inspector.
##
## Slice 3 also writes, when missing: kit/sockets/collapse_rubble.tres and two
## Godot-only modules in gen/modules/: rubble_strip (a SCATTER socket of rubble
## along a collapsed bay's wall) and exit_glow (the lit room beyond an exit
## door that nothing has joined yet, with a blocker).

const WALLS: String = "res://kit/modules/walls/"
const DRESS: String = "res://kit/modules/dressing/"
const RULES: String = "res://gen/rules/r02_brick.tres"
const GRAMMAR: String = "res://gen/grammars/r02_stack_gallery.tres"
const RUBBLE_SET: String = "res://kit/sockets/collapse_rubble.tres"
const RUBBLE_STRIP: String = "res://gen/modules/rubble_strip.tscn"
const EXIT_GLOW: String = "res://gen/modules/exit_glow.tscn"


func _initialize() -> void:
	seed_rubble()
	seed_exit_glow()
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
		# Slice 3: a collapsed bay's walls are always recesses (pinned to collapsed),
		# with a strip of rubble at their feet; an exit nothing has joined glows.
		rule("edge:recess", [["wall_shelfbay_4m", 1.0]]),
		rule("dressing:rubble", [[RUBBLE_STRIP, 1.0]]),
		rule("stub:exit", [[EXIT_GLOW, 1.0]]),
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
	var g: StackGalleryGrammar = load(GRAMMAR) if ResourceLoader.exists(GRAMMAR) else null
	if g == null:
		g = StackGalleryGrammar.new()
		g.styles = PackedStringArray(["brick"])
		g.rules = load(RULES)
		g.lamp_lit_by_distance = lit_curve()
		save(g, GRAMMAR)
	elif g.lamp_lit_by_distance == null:
		g.lamp_lit_by_distance = lit_curve()
		save(g, GRAMMAR)
	quit()


## 0.9 at the entry, falling straight to 0.35 at 12 bays (5.5.4).
func lit_curve() -> Curve:
	var c := Curve.new()
	c.max_domain = 12.0
	c.add_point(Vector2(0.0, 0.9), 0.0, -0.55 / 12.0, Curve.TANGENT_LINEAR, Curve.TANGENT_LINEAR)
	c.add_point(Vector2(12.0, 0.35), -0.55 / 12.0, 0.0, Curve.TANGENT_LINEAR, Curve.TANGENT_LINEAR)
	return c


## kit/sockets/collapse_rubble.tres and gen/modules/rubble_strip.tscn: a FREE
## module placed on a collapsed bay's wall line (edge frame: +X along the wall,
## -Z into the bay) with a SCATTER socket 0.55-1.15 m out from the wall, clear of the
## piers at the bay ends.
func seed_rubble() -> void:
	if not ResourceLoader.exists(RUBBLE_SET):
		var set := SocketSet.new()
		for spec: Array in [["rubble", "debris_rubble", 3.0], ["fallen brick", "debris_brick", 2.0]]:
			var e := SocketEntry.new()
			e.label = spec[0]
			e.scene = load(DRESS + String(spec[1]) + ".tscn")
			e.weight = spec[2]
			set.entries.append(e)
		set.slot_bounds = AABB(Vector3(-0.25, 0.0, -0.2), Vector3(0.5, 0.2, 0.4))   # one piece
		set.slot_is_item = true
		save(set, RUBBLE_SET)
	if ResourceLoader.exists(RUBBLE_STRIP):
		return
	var m := KitModule.new()
	m.name = "rubble_strip"
	m.family = "gen"
	m.tags = PackedStringArray(["stone", "debris"])
	var s := VariantSocket.new()
	s.name = "SOCKET_rubble"
	s.socket_set = load(RUBBLE_SET)
	s.mode = VariantSocket.Mode.SCATTER
	s.scatter_count = Vector2i(10, 16)
	s.scatter_extent = Vector2(1.2, 0.3)
	s.scatter_spacing = 0.22
	s.position = Vector3(2.0, 0.0, -0.85)
	m.add_child(s)
	s.owner = m
	pack(m, RUBBLE_STRIP)


## gen/modules/exit_glow.tscn, in the frame of an exit connector (origin at the
## door's centre on the wall line, -Z out of the room): a warm emissive card
## 1.4 m beyond the wall that fills the arch from any angle in the corridor,
## a warm shadowed light that throws the arch's shape into the last bay, and
## a blocker 0.7-1.1 m out so the player can't walk off the grid.
func seed_exit_glow() -> void:
	if ResourceLoader.exists(EXIT_GLOW):
		return
	var m := KitModule.new()
	m.name = "exit_glow"
	m.family = "gen"
	m.tags = PackedStringArray(["light", "stub"])
	var card := MeshInstance3D.new()
	card.name = "Glow"
	var quad := QuadMesh.new()
	quad.size = Vector2(6.0, 6.5)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color.BLACK
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.64, 0.34)
	mat.emission_energy_multiplier = 0.65
	mat.roughness = 1.0
	quad.material = mat
	card.mesh = quad
	card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	card.position = Vector3(0.0, 2.75, -1.4)     # a QuadMesh faces +Z: back into the room
	var light := OmniLight3D.new()
	light.name = "Light"
	light.light_color = Color(1.0, 0.76, 0.48)
	light.light_energy = 1.3
	light.omni_range = 7.0
	light.shadow_enabled = true
	light.position = Vector3(0.0, 2.2, -1.0)
	var body := StaticBody3D.new()
	body.name = "Blocker"
	var shape := CollisionShape3D.new()
	shape.name = "Shape"
	var box := BoxShape3D.new()
	box.size = Vector3(3.6, 4.0, 0.4)
	shape.shape = box
	shape.position = Vector3(0.0, 2.0, -0.9)
	for n: Node in [card, light, body]:
		m.add_child(n)
		n.owner = m
	body.add_child(shape)
	shape.owner = m
	pack(m, EXIT_GLOW)


func pack(m: Node, path: String) -> void:
	var scene := PackedScene.new()
	scene.pack(m)
	save(scene, path)
	m.free()


## choices: [[module name in kit/modules/walls/ or a res:// path, weight], ...]
func rule(slot: String, choices: Array) -> ModuleRule:
	var r := ModuleRule.new()
	r.slot = slot
	r.styles = PackedStringArray(["brick"])
	var list: Array[ModuleChoice] = []
	for c: Array in choices:
		var choice := ModuleChoice.new()
		var path: String = String(c[0]) if String(c[0]).begins_with("res://") else WALLS + String(c[0]) + ".tscn"
		choice.scene = load(path)
		choice.weight = c[1]
		list.append(choice)
	r.choices = list
	return r


func save(res: Resource, path: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var err: Error = ResourceSaver.save(res, path)
	print("seed_gen: ", ("wrote " if err == OK else "FAILED %s " % error_string(err)) + path)

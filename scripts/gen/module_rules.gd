@tool
class_name ModuleRules
extends Resource
## Edge, cell and post slots to weighted kit modules, per style
## (ENVIRONMENT_PLAN.md 5.5.3; gen/rules/*.tres). The grammar decides what an
## edge is; these rules decide which module fills it. The first matching rule
## wins, so put style-specific rules before general ones.

@export var rules: Array[ModuleRule] = []:
	set(value):
		for r: ModuleRule in rules:
			if r != null and r.changed.is_connected(emit_changed):
				r.changed.disconnect(emit_changed)
		rules = value
		for r: ModuleRule in rules:
			if r != null and not r.changed.is_connected(emit_changed):
				r.changed.connect(emit_changed)
		emit_changed()


func rule_for(slot: String, styles: PackedStringArray) -> ModuleRule:
	for r: ModuleRule in rules:
		if r != null and r.matches(slot, styles):
			return r
	return null


## The module for one slot; null if no rule covers it.
func pick(slot: String, styles: PackedStringArray, rng: RandomNumberGenerator) -> PackedScene:
	var r: ModuleRule = rule_for(slot, styles)
	return r.pick(rng) if r != null else null


## Problems: rules without a slot or choices, and modules whose KitModule shape
## doesn't fit their slot (a floor offered for a wall).
func check() -> PackedStringArray:
	var out: PackedStringArray = []
	for i: int in rules.size():
		var r: ModuleRule = rules[i]
		if r == null:
			out.append("rule %d is empty" % i)
			continue
		if r.slot.strip_edges() == "":
			out.append("rule %d has no slot" % i)
			continue
		if r.choices.is_empty():
			out.append("rule %d (%s): no choices" % [i, r.slot])
		for c: ModuleChoice in r.choices:
			if c == null or c.scene == null:
				out.append("rule %d (%s): a choice has no scene" % [i, r.slot])
				continue
			var inst: Node = c.scene.instantiate()
			var m := inst as KitModule
			if m == null:
				out.append("rule %d (%s): %s is not a kit module" % [i, r.slot, c.scene.resource_path])
			elif m.shape != ModuleRule.shape_of(r.slot):
				out.append("rule %d (%s): %s is a %s module" % [i, r.slot, c.scene.resource_path, KitModule.Shape.keys()[m.shape]])
			inst.free()
	return out

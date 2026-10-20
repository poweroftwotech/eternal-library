@tool
class_name ModuleRule
extends Resource
## Which kit modules may fill one kind of slot in a generated room, for rooms
## with the given styles (ENVIRONMENT_PLAN.md 5.5.3).

## Slots RoomBuilder asks for, and the module shape each one takes.
const SLOT_SHAPES: Dictionary = {
	"edge:solid": KitModule.Shape.EDGE, "edge:solid_corner": KitModule.Shape.EDGE, "edge:opening": KitModule.Shape.EDGE,
	"edge:door": KitModule.Shape.EDGE, "gable": KitModule.Shape.EDGE,
	"cell:floor": KitModule.Shape.CELL, "cell:ceiling": KitModule.Shape.CELL, "cell:ceiling_cross": KitModule.Shape.CELL,
	"post": KitModule.Shape.POST, "lamp": KitModule.Shape.FREE,
}

@export_enum("edge:solid", "edge:solid_corner", "edge:opening", "edge:door", "gable", "cell:floor", "cell:ceiling", "cell:ceiling_cross", "post", "lamp")
var slot: String = "edge:solid":
	set(value):
		slot = value
		emit_changed()
## The rule applies when the room has every one of these styles (empty = any room).
@export var styles: PackedStringArray = []:
	set(value):
		styles = value
		emit_changed()
@export var choices: Array[ModuleChoice] = []:
	set(value):
		for c: ModuleChoice in choices:
			if c != null and c.changed.is_connected(emit_changed):
				c.changed.disconnect(emit_changed)
		choices = value
		for c: ModuleChoice in choices:
			if c != null and not c.changed.is_connected(emit_changed):
				c.changed.connect(emit_changed)
		emit_changed()


func matches(slot_name: String, room_styles: PackedStringArray) -> bool:
	if slot_name != slot:
		return false
	for s: String in styles:
		if not room_styles.has(s):
			return false
	return true


## Weighted pick; null if nothing is pickable.
func pick(rng: RandomNumberGenerator) -> PackedScene:
	var total: float = 0.0
	for c: ModuleChoice in choices:
		if c != null and c.scene != null:
			total += maxf(c.weight, 0.0)
	if total <= 0.0:
		return null
	var roll: float = rng.randf() * total
	var last: PackedScene = null
	for c: ModuleChoice in choices:
		if c == null or c.scene == null or c.weight <= 0.0:
			continue
		last = c.scene
		roll -= c.weight
		if roll <= 0.0:
			return c.scene
	return last

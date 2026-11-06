extends SceneTree
## The Reading Room joins an area like any room (2026-11-05): a way in, side
## doors that are exits, a glow on the ones nothing joins. Reads no live area.
##   godot --headless --audio-driver Dummy --path . --script res://tests/r01_join_test.gd
## Checks: as an entrance its door back is its entry and rooms grow from its
## side doors; as a required room it joins by its entry; a joined door loses
## its glow; the board offers it deeper in.

const Service: GDScript = preload("res://addons/strata_board/strata_service.gd")
const ROOM: String = "res://rooms/authored/reading_room.tscn"
const WEST: StringName = &"SNAP_exit_0_0_1_W"
const EAST: StringName = &"SNAP_exit_3_0_1_W"

var failures: PackedStringArray = []
var checks: int = 0


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures.append(what)


func rule(prefix: String, grammar: String, from: Array, count: Vector2i) -> AreaGrow:
	var g := AreaGrow.new()
	g.slot_prefix = prefix
	g.grammar = load(grammar)
	g.from = PackedStringArray(from)
	g.count = count
	return g


func recipe(slots: Array[AreaSlot], grow: Array[AreaGrow]) -> AreaRecipe:
	var r := AreaRecipe.new()
	r.id = "r01_join"
	r.placement = AreaPlacement.new()
	r.placement.envelope.size.y = 48.0
	r.room_count = Vector2i(1, 10)
	r.max_dead_ends = 0
	r.slots = slots
	r.grow = grow
	return r


func slot(id: String, parent: String, conn: StringName) -> AreaSlot:
	var s := AreaSlot.new()
	s.slot_id = id
	s.parent = parent
	s.connector = conn
	s.scene = load(ROOM)
	return s


func run() -> void:
	var entries: Array = (Service.catalog()["scenes"] as Array).filter(func(c: Dictionary) -> bool: return str(c["path"]) == ROOM)
	check(entries.size() == 1 and not bool(entries[0]["entrance_only"]), "the board offers the Reading Room deeper in")

	# As an entrance.
	var grown: int = 0
	var root_slot: AreaSlot = slot("entrance", "", &"")
	root_slot.thresholds = {&"SNAP_entry": "gorge"}
	var r: AreaRecipe = recipe([root_slot] as Array[AreaSlot], [rule("stacks", "res://gen/grammars/r02_stack_gallery.tres", ["entrance"], Vector2i(1, 2))] as Array[AreaGrow])
	for w: int in range(1, 21):
		var p: AreaPlan = AreaPlanner.plan_world(r, w)
		check(p.errors.is_empty() and p.check().is_empty(), "entrance plans clean (world %d): %s %s" % [w, p.errors, p.check()])
		var t: Array = p.threshold("gorge")
		check(not t.is_empty() and t[1] == &"SNAP_entry", "its door back is its entry (world %d)" % w)
		var room: AreaPlan.Room = p.room("entrance")
		for door: StringName in [WEST, EAST]:
			var joined: bool = str(room.connectors[door]["joined"]) != ""
			check(room.drop_nodes.has("Dressing/prop_exit_" + String(door).trim_prefix("SNAP_exit_")) == joined, "%s keeps its glow only if unjoined (world %d)" % [door, w])
		grown += 1 if p.rooms.size() > 1 else 0
	check(grown >= 16, "rooms grow from its side doors (%d of 20 worlds)" % grown)

	# Deeper in: a hall, then the Reading Room at one of its doors.
	var joined_at: int = 0
	var hall := AreaSlot.new()
	hall.slot_id = "entrance"
	hall.grammar = load("res://gen/grammars/r03_hypostyle.tres")
	for w: int in range(1, 21):
		var probe: AreaPlan = AreaPlanner.plan_world(recipe([hall] as Array[AreaSlot], [] as Array[AreaGrow]), w)
		var doors: Array = probe.room("entrance").connectors.keys().filter(func(n: StringName) -> bool:
			var k: Dictionary = probe.room("entrance").connectors[n]
			return String(n).begins_with("SNAP_exit") and str(k["cap"]) == "glow")
		if doors.is_empty():
			continue
		var d: AreaRecipe = recipe([hall, slot("reading", "entrance", doors[0])] as Array[AreaSlot],
				[rule("stacks", "res://gen/grammars/r02_stack_gallery.tres", ["reading"], Vector2i(1, 1))] as Array[AreaGrow])
		var p: AreaPlan = AreaPlanner.plan_world(d, w)
		var room: AreaPlan.Room = p.room("reading")
		if room != null and p.errors.is_empty() and p.check().is_empty():
			joined_at += 1
			check(str(room.connectors[&"SNAP_entry"]["joined"]) != "", "it joins by its entry (world %d)" % w)
	check(joined_at >= 10, "the Reading Room fits deeper in (%d of 20 worlds)" % joined_at)

	if failures.is_empty():
		print("r01_join_test: PASS (%d checks)" % checks)
		quit(0)
	else:
		for f: String in failures:
			printerr("FAIL: " + f)
		print("r01_join_test: FAIL (%d of %d)" % [failures.size(), checks])
		quit(1)

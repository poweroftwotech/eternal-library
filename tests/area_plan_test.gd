extends SceneTree
## Gate for the area planner (phase-4-design.md 8.1.7, 8.1.9).
##   godot --headless --path . --script res://tests/area_plan_test.gd [-- seeds=N map=<dir>]
## For area seeds 1-20 of gen/recipes/library_wing.tres: AreaPlan.check()
## passes (a tree, 6-9 rooms, no shared cell in 3D, inside the envelope, no
## sightline deeper than 2 rooms beyond the first, every exit joined or
## capped); planning twice gives the same plan; the baked gallery sits on R01's
## west door; every generated room has min_bays; R01's room key is
## reading_room@1. Hand-made plans: four rooms in a straight line are rejected,
## three pass; two rooms stacked one storey apart don't overlap, on one storey
## they do. Option map=<dir> writes each seed's plan map as a PNG.
## The Lower Stacks (phase-5-design.md 5.6.9), seeds 1-20: the plan checks
## clean with its room_count, planning twice gives the same plan, and the
## generated hall is the root at the origin, sees every room joined to it,
## and has a bay a walk goes round for each case, heap and the landmark.

const RECIPE: String = "res://gen/recipes/library_wing.tres"
const LOWER_STACKS: String = "res://gen/recipes/lower_stacks.tres"
const SEEDS: int = 20

var failures: PackedStringArray = []
var checks: int = 0


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures.append(what)


func run() -> void:
	var seeds: int = SEEDS
	var map_dir: String = ""
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("seeds="):
			seeds = a.trim_prefix("seeds=").to_int()
		elif a.begins_with("map="):
			map_dir = a.trim_prefix("map=")
	var recipe: AreaRecipe = load(RECIPE)
	var grammar: StackGalleryGrammar = load("res://gen/grammars/r02_stack_gallery.tres")
	var counts: Dictionary = {}
	var totals: Dictionary = {"tried": 0, "boxed_in": 0, "too_short": 0, "sightline": 0}
	var slowest: float = 0.0
	var dead_ends: int = 0
	for s: int in range(1, seeds + 1):
		var p: AreaPlan = AreaPlanner.plan(recipe, s)
		var tag: String = "area seed %d" % s
		var problems: PackedStringArray = p.check()
		check(problems.is_empty(), "%s: the plan checks clean (%s)" % [tag, problems])
		var again: AreaPlan = AreaPlanner.plan(recipe, s)
		check(again.signature() == p.signature(), "%s: planning twice gives the same plan" % tag)
		var west: AreaPlan.Room = p.room("stack_gallery_west")
		check(west != null and west.kind == "scene" and west.parent == "reading_room" and west.parent_connector == &"SNAP_door_west" \
			and west.seed_value == 7, "%s: the baked gallery (seed 7) sits on R01's west door" % tag)
		var r01: AreaPlan.Room = p.room("reading_room")
		check(r01 != null and "%s@%d" % [r01.slot_id, r01.seed_value] == "reading_room@1" and r01.xf == Transform3D(),
			"%s: R01 is the root at the origin, room key reading_room@1" % tag)
		var short: PackedStringArray = []
		for r: AreaPlan.Room in p.rooms:
			if r.kind == "generated" and r.grid.run_order().size() < grammar.min_bays:
				short.append("%s %d bays" % [r.slot_id, r.grid.run_order().size()])
			if r.end_kind == "dead_end":
				dead_ends += 1
		check(short.is_empty(), "%s: every generated room has at least %d bays (%s)" % [tag, grammar.min_bays, short])
		var hall: AreaPlan.Room = p.room_at(Vector3(6, 0.9, -10))
		check(hall != null and hall.slot_id == "reading_room", "%s: a point in R01's hall is in reading_room" % tag)
		check(p.visible.get("reading_room", PackedStringArray()).has("stack_gallery_west"), "%s: R01 sees into the west gallery" % tag)
		counts[p.rooms.size()] = int(counts.get(p.rooms.size(), 0)) + 1
		for k: String in totals:
			totals[k] += int(p.stats.get(k, 0))
		slowest = maxf(slowest, p.plan_ms)
		print("  %s: %d rooms, deepest line %d rooms, %d lines, %.0f ms, rejected %s" % [tag, p.rooms.size(), p.stats["deepest"], p.stats["lines"], p.plan_ms, p.stats])
		if map_dir != "":
			DirAccess.make_dir_recursive_absolute(map_dir)
			p.draw_map().save_png("%s/area_plan_seed_%d.png" % [map_dir, s])
	print("  room counts over %d seeds: %s; dead ends %d; slowest plan %.0f ms; grow tries %s" % [seeds, counts, dead_ends, slowest, totals])
	check(counts.keys().all(func(n: int) -> bool: return n >= 6 and n <= 9), "every seed has 6-9 rooms (%s)" % [counts])
	lower_stacks(seeds)
	hand_made()
	print("area_plan_test: %d checks, %d failures" % [checks, failures.size()])
	for f: String in failures:
		print("  FAIL ", f)
	quit(1 if not failures.is_empty() else 0)


func lower_stacks(seeds: int) -> void:
	var recipe: AreaRecipe = load(LOWER_STACKS)
	var counts: Dictionary = {}
	for s: int in range(1, seeds + 1):
		var tag: String = "lower stacks %d" % s
		var p: AreaPlan = AreaPlanner.plan(recipe, s)
		var problems: PackedStringArray = p.check()
		check(problems.is_empty(), "%s: the plan checks clean (%s)" % [tag, problems])
		check(AreaPlanner.plan(recipe, s).signature() == p.signature(), "%s: planning twice gives the same plan" % tag)
		var hall: AreaPlan.Room = p.rooms[0]
		check(hall.slot_id == "hall" and hall.kind == "generated" and hall.parent == "" and hall.xf == Transform3D(),
			"%s: the generated hall is the root at the origin" % tag)
		var joined: Array = p.rooms.filter(func(r: AreaPlan.Room) -> bool: return r.parent == "hall").map(func(r: AreaPlan.Room) -> String: return r.slot_id)
		var sees: PackedStringArray = p.visible.get("hall", PackedStringArray())
		check(not joined.is_empty() and joined.all(func(id: String) -> bool: return sees.has(id)), "%s: the hall sees every room joined to it (%s; sees %s)" % [tag, joined, sees])
		var stand: int = hall.grid.props.values().filter(func(pr: Dictionary) -> bool: return pr["slot"] in ["dressing:case", "dressing:rubble_heap", "landmark"]).size()
		check(hall.blocked_cells.size() == stand, "%s: a bay to walk round for each case, heap and the landmark (%d of %d)" % [tag, hall.blocked_cells.size(), stand])
		counts[p.rooms.size()] = int(counts.get(p.rooms.size(), 0)) + 1
	print("  lower stacks room counts over %d seeds: %s" % [seeds, counts])
	check(counts.keys().all(func(n: int) -> bool: return n >= recipe.room_count.x and n <= recipe.room_count.y), "every Lower Stacks seed has %d-%d rooms (%s)" % [recipe.room_count.x, recipe.room_count.y, counts])


## Synthetic plans: straight lines of rooms, and stacked rooms.
func hand_made() -> void:
	# Rooms two cells long in a row along +X, doorways between them, all in one
	# straight line: 4 rooms are 3 beyond the first.
	for n: int in [3, 4]:
		var p: AreaPlan = line_plan(n, 0)
		var v: PackedStringArray = p.compute_sight()["violations"]
		if n == 4:
			check(not v.is_empty(), "four rooms in a straight line are rejected (max 2 beyond the first)")
		else:
			check(v.is_empty(), "three rooms in a straight line pass (%s)" % [v])
	# Stacked: same x/z, one storey apart: no overlap. Same storey: overlap.
	for dy: int in [1, 0]:
		var p := AreaPlan.new()
		p.room_count = Vector2i(1, 9)
		var a: AreaPlan.Room = box_room("low", Vector3i(0, 0, 0), 2)
		var b: AreaPlan.Room = box_room("high", Vector3i(0, dy, 0), 2)
		p.add_room(a)
		p.add_room(b)
		var overlaps: Array = Array(p.check(false)).filter(func(s: String) -> bool: return s.contains("both occupy"))
		if dy == 1:
			check(overlaps.is_empty(), "two rooms stacked one storey apart don't overlap (%s)" % [overlaps])
		else:
			check(not overlaps.is_empty(), "two rooms on one storey in the same cells overlap")


## A room of `length` cells along +X from cell `at`, one storey tall, open inside.
func box_room(slot: String, at: Vector3i, length: int) -> AreaPlan.Room:
	var r := AreaPlan.Room.new()
	r.slot_id = slot
	r.storey = at.y
	for i: int in length:
		var c := Vector3i(at.x + i, at.y, at.z)
		r.cells[c] = true
		r.floor_cells[c] = true
		if i > 0:
			r.sight[CellGrid.key(c, CellGrid.Side.W)] = AreaPlan.OPEN_HALF
	return r


## `n` two-cell rooms joined end to end along +X, every doorway on one line.
func line_plan(n: int, _unused: int) -> AreaPlan:
	var p := AreaPlan.new()
	p.max_sight_depth = 2
	var prev: AreaPlan.Room = null
	for i: int in n:
		var r: AreaPlan.Room = box_room("r%d" % i, Vector3i(i * 2, 0, 0), 2)
		# Door on the W side of this room's first cell; -Z out of the room before is +X.
		var entry_xf := Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(i * 2 * 4, 0, -2))
		r.entry = &"in"
		r.connectors[&"in"] = {"xf": entry_xf, "storey": 0, "joined": "", "cap": ""}
		p.add_room(r)
		if prev != null:
			prev.connectors[&"out"] = {"xf": entry_xf, "storey": 0, "joined": "", "cap": ""}
			p.join(r, prev, &"out")
		prev = r
	return p

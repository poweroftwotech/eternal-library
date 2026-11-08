extends SceneTree
## Phase 17 step 5: the Orosi Scriptorium in the live areas (Q6, Q7):
##   the Grand Study      tended, off the red hall or a reading room, grown last
##                        (28 of 40 worlds, no other room lost; grown after the
##                        reading rooms it fitted in 40 but took stacks' doors);
##   the Forgotten City   the Forgotten version, grown last off any free door,
##                        where the other forgotten rooms are (moved there
##                        2026-11-08: the Forgotten Wing isn't on the stratum
##                        plan; REMOVE takes it out of that recipe).
## At most one a world in each area (the recipes are placeholders: zero cost).
## Adds the grow rule (or replaces one made before), bumps each recipe's
## version once, then reports over WORLDS worlds where it fits and how the
## other grown rooms fare before and after.
##   godot --headless --path . --script res://tools/make_r08_live.gd [-- --dry]

const GRAMMAR: String = "res://gen/grammars/r08_scriptorium.tres"
const PREFIX: String = "scriptorium"
const WORLDS: int = 40
const AREAS: Dictionary = {
	"grand_study": {"from": ["GrandHall", "ReadingRoomA_1", "ReadingRoomB_1"], "after": "oldStacks", "tweaks": {},
		"others": ["ReadingRoomA_1", "ReadingRoomB_1", "Gardens_1", "Caravan_1", "oldStacks_1", "RoomAStacks_1", "RoomAStacks_2_1"]},
	"forgotten_city": {"from": [], "after": "ossuary", "tweaks": {"state": "abandoned"},
		"others": ["readinga_1", "stacks_1", "stacks_2", "readingb_1", "oldGarden_1", "Old_City_1", "old_Market_1", "ossuary_1"]},
}
## Areas the scriptorium is taken out of (version bumped once).
const REMOVE: PackedStringArray = ["forgotten_wing"]


func _initialize() -> void:
	var dry: bool = OS.get_cmdline_user_args().has("--dry")
	var err: int = OK
	for id: String in REMOVE:
		var path: String = "res://gen/recipes/%s.tres" % id
		var live: AreaRecipe = load(path)
		var kept: Array[AreaGrow] = []
		for g: AreaGrow in live.grow:
			if g != null and g.slot_prefix != PREFIX:
				kept.append(g)
		if kept.size() != live.grow.size():
			live.grow = kept
			live.version += 1
			if not dry:
				err = maxi(err, ResourceSaver.save(live, path))
			print("make_r08_live: %s version %d, the scriptorium taken out%s" % [id, live.version, " (dry run)" if dry else ""])
	for id: String in AREAS:
		var cfg: Dictionary = AREAS[id]
		var path: String = "res://gen/recipes/%s.tres" % id
		var live: AreaRecipe = load(path)
		var had: bool = live.grow.any(func(x: AreaGrow) -> bool: return x != null and x.slot_prefix == PREFIX)
		var grows: Array[AreaGrow] = []
		for g: AreaGrow in live.grow:
			if g != null and g.slot_prefix != PREFIX:
				grows.append(g)
		var old: AreaRecipe = live.duplicate(true)
		old.grow = grows.duplicate()
		var t := AreaGrow.new()
		t.grammar = load(GRAMMAR)
		t.display_name = "The Orosi Scriptorium"
		t.count = Vector2i(1, 1)
		t.slot_prefix = PREFIX
		t.from = PackedStringArray(cfg["from"])
		t.tweaks = (cfg["tweaks"] as Dictionary).duplicate()
		var at: int = grows.size()
		for i: int in grows.size():
			if grows[i].slot_prefix == cfg["after"]:
				at = i + 1
		grows.insert(at, t)
		live.grow = grows
		if not had:
			live.version += 1
		if not dry:
			err = maxi(err, ResourceSaver.save(live, path))
		print("make_r08_live: %s version %d, the scriptorium grown after '%s'%s" % [id, live.version, cfg["after"], " (dry run)" if dry else ""])
		_report(id, old, live, cfg["others"])
	quit(err)


func _report(id: String, before: AreaRecipe, after: AreaRecipe, others: Array) -> void:
	var placed: int = 0
	var hosts: Dictionary = {}
	var palettes: Dictionary = {}
	var problems: int = 0
	var counts_before: Dictionary = {}
	var counts_after: Dictionary = {}
	for w: int in range(1, WORLDS + 1):
		var pa: AreaPlan = AreaPlanner.plan_world(after, w)
		var pb: AreaPlan = AreaPlanner.plan_world(before, w)
		var room: AreaPlan.Room = pa.room(PREFIX + "_1")
		if room != null:
			placed += 1
			var host: String = str(room.grid.meta.get("host_type", "?")) if room.grid != null else "?"
			var glass: String = "?"
			if room.grid != null and room.grid.props.has("orosi"):
				glass = str((room.grid.props["orosi"]["meta"] as Dictionary).get("palette", "?"))
			hosts[host] = int(hosts.get(host, 0)) + 1
			palettes[host + " " + glass] = int(palettes.get(host + " " + glass, 0)) + 1
		for o: String in others:
			counts_before[o] = int(counts_before.get(o, 0)) + (1 if pb.room(o) != null else 0)
			counts_after[o] = int(counts_after.get(o, 0)) + (1 if pa.room(o) != null else 0)
		if not pa.check().is_empty():
			problems += 1
			print("  %s world %d plan problems: %s" % [id, w, pa.check()])
	print("make_r08_live: %s: the scriptorium in %d of %d worlds; off %s; glass by host %s; %d worlds with plan problems" % [id, placed, WORLDS, hosts, palettes, problems])
	for o: String in others:
		print("  %s %s: %d -> %d of %d worlds" % [id, o, counts_before[o], counts_after[o], WORLDS])

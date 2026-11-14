extends SceneTree
## Phase 19 step 5: the animals' tables and the save, across OS processes
## (AGENTS.md: persistence gate). Headless:
##   godot --audio-driver Dummy --headless --path . --script res://tests/fauna_test.gd -- save [place] --save=user://test/fauna.json --fresh
##   godot --audio-driver Dummy --headless --path . --script res://tests/fauna_test.gd -- load [place] --save=user://test/fauna.json
## place: area:mahaleh (default, area seed SEED) or camp.
## save: a new world. Every kind has a level (FaunaTable) and it is the one
##       its world seed draws; the animals a place is known by are at least
##       common; the limits hold; the animals of each room are counted. Then
##       one kind's level is changed (as hunting or a food web will later)
##       and the game saved.
## load: a fresh process reads the same levels from the save, the changed one
##       included; rooms hold the same animals as before for every kind left
##       alone, and more or fewer of the changed kind; the camp's cat is the
##       same cat.

const SEED: int = 2
## The kind whose level the test changes, per place.
const CHANGED: Dictionary = {"camp": "goldfish"}
const CHANGED_AREA: String = "gecko"

var main_script: GDScript = load("res://scripts/main.gd")
var failures: PackedStringArray = []
var checks: int = 0
var game: Node
var fauna: Fauna
var place_arg: String = "area:mahaleh"


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures.append(what)


func run() -> void:
	var mode: String = "save"
	for a: String in OS.get_cmdline_user_args():
		if a == "save" or a == "load":
			mode = a
		elif not a.begins_with("--"):
			place_arg = a
	Area.seed_override = SEED
	main_script.room_override = place_arg
	game = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	current_scene = game
	game.player.blocked = true
	for _i: int in 20:
		await physics_frame
	var area: Area = game.world as Area
	fauna = area.fauna if area != null else game.world.get_node_or_null("Fauna") as Fauna
	check(fauna != null, "%s has its animals' director" % place_arg)
	if fauna == null:
		finish(mode)
		return
	# Walk the place: each room of an area in turn, so their animals arrive.
	if area != null:
		for r: AreaPlan.Room in area.plan.rooms.slice(0, 6):
			if r.floor_cells.is_empty():
				continue
			game.player.teleport(area.global_transform * CellGrid.cell_centre(r.floor_cells.keys()[0]))
			await settle(area)
	else:
		await settle(null)
	var ws: Node = root.get_node("WorldState")
	var levels: Dictionary = ws.call("fauna_levels", fauna.place)
	var counts: Dictionary = count()
	var kinds: PackedStringArray = []
	for d: String in Fauna.DEFS:
		kinds.append(str((load(d) as CreatureDef).id))
	for kind: String in kinds:
		check(FaunaTable.LEVELS.has(str(levels.get(kind, ""))), "%s has a level in %s (%s)" % [kind, fauna.place, levels.get(kind, "none")])
	check(int(fauna.stats["awake"]) >= 0 and _awake_thinking() <= Fauna.MAX_THINKING, "at most %d thinking animals awake (%d)" % [Fauna.MAX_THINKING, _awake_thinking()])
	var changed: String = str(CHANGED.get(fauna.place, CHANGED_AREA))
	var expect_path: String = "user://test/fauna_expect_%s.json" % fauna.place
	if mode == "save":
		for kind: String in kinds:
			check(str(levels.get(kind, "")) == FaunaTable.roll(int(ws.call("world_seed")), fauna.place, kind), "%s's level is the one this world draws" % kind)
		for kind: String in FaunaTable.KNOWN_BY.get(fauna.place, []):
			check(FaunaTable.LEVELS.find(str(levels.get(kind, ""))) <= 1, "%s is known by its %s: at least common (%s)" % [fauna.place, kind, levels.get(kind, "")])
		var total: int = 0
		for slot: String in counts:
			for kind: String in counts[slot]:
				total += int(counts[slot][kind])
		check(total > 0, "%s has animals (%d)" % [fauna.place, total])
		var was: String = str(levels.get(changed, "common"))
		var now: String = "very_scarce" if was != "very_scarce" else "abundant"
		ws.call("set_fauna_level", fauna.place, changed, now)
		var saved: Dictionary = (ws.call("fauna_levels", fauna.place) as Dictionary).duplicate()
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://test"))
		var f := FileAccess.open(expect_path, FileAccess.WRITE)
		f.store_string(JSON.stringify({"levels": saved, "counts": counts, "changed": changed, "was": was, "now": now, "cat": ws.call("fauna_one", fauna.place, "cat")}))
		f.close()
		check(ws.call("save_now") == OK, "the game saves")
		print("fauna_test: %s levels %s; %s %s -> %s; %d animals in %d rooms" % [fauna.place, levels, changed, was, now, total, counts.size()])
	else:
		var expect: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(expect_path))
		for kind: String in kinds:
			check(str(levels.get(kind, "")) == str((expect["levels"] as Dictionary).get(kind, "?")), "%s's level came back from the save (%s, saved %s)" % [kind, levels.get(kind, ""), (expect["levels"] as Dictionary).get(kind, "?")])
		check(str(levels.get(changed, "")) == str(expect["now"]), "the changed level held: %s is %s" % [changed, expect["now"]])
		var same: int = 0
		var differ: PackedStringArray = []
		var before: int = 0
		var after: int = 0
		for slot: String in expect["counts"]:
			if not counts.has(slot):
				continue
			var a: Dictionary = expect["counts"][slot]
			var b: Dictionary = counts[slot]
			for kind: String in kinds:
				if kind == changed:
					before += int(a.get(kind, 0))
					after += int(b.get(kind, 0))
				elif int(a.get(kind, 0)) == int(b.get(kind, 0)):
					same += 1
				else:
					differ.append("%s %s %d -> %d" % [slot, kind, int(a.get(kind, 0)), int(b.get(kind, 0))])
		check(differ.is_empty(), "every room holds the same animals as before, kinds left alone (%d the same; differ: %s)" % [same, differ])
		var fewer: bool = FaunaTable.amount(str(expect["now"])) < FaunaTable.amount(str(expect["was"]))
		check(before == 0 or (after < before if fewer else after > before), "%s went %s -> %s: %d before, %d now" % [changed, expect["was"], expect["now"], before, after])
		var cat: Dictionary = expect["cat"]
		if not cat.is_empty():
			var now_cat: Dictionary = ws.call("fauna_one", fauna.place, "cat")
			check(int(now_cat.get("coat", -1)) == int(cat["coat"]), "the camp's cat is the same cat (coat %s)" % cat["coat"])
		print("fauna_test: %s levels %s; %s %d -> %d" % [fauna.place, levels, changed, before, after])
	finish(mode)


## Slot -> {kind: how many}.
func count() -> Dictionary:
	var out: Dictionary = {}
	for slot: String in fauna.groups:
		var kinds: Dictionary = {}
		for g: Node in fauna.groups[slot]:
			if not is_instance_valid(g):
				continue
			var kind: String = str(g.get("def").id)
			var n: int = int(g.call("count")) if g.has_method("count") else (g as MultiMeshInstance3D).multimesh.instance_count
			kinds[kind] = int(kinds.get(kind, 0)) + n
		out[slot if slot != "" else "place"] = kinds
	return out


func _awake_thinking() -> int:
	var n: int = 0
	for slot: String in fauna.groups:
		for g: Node in fauna.groups[slot]:
			if is_instance_valid(g) and not Fauna._is_swarm(g) and (g as Node3D).visible:
				n += int(g.call("count")) if g.has_method("count") else (g as MultiMeshInstance3D).multimesh.instance_count
	return n


func settle(area: Area) -> void:
	for _i: int in 10:
		await process_frame
	while area != null and area.streamer != null and area.streamer.busy():
		await process_frame
	for _i: int in 1200:
		if fauna._jobs.is_empty():
			break
		await process_frame
	for _i: int in 10:
		await process_frame


func finish(mode: String) -> void:
	main_script.room_override = ""
	if failures.is_empty():
		print("fauna_test %s: PASS (%d checks)" % [mode, checks])
		quit(0)
	else:
		for f: String in failures:
			print("  FAIL: " + f)
		print("fauna_test %s: FAIL (%d of %d checks)" % [mode, failures.size(), checks])
		quit(1)

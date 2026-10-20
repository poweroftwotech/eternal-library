extends SceneTree
## Gate for Bake to scene (ENVIRONMENT_PLAN.md 5.5.10, phase 2 slice 4).
##   godot --headless --path . --script res://tests/r02_bake_test.gd
## For several seeds (alcoves, a collapsed bay, corners, a dead end) it builds
## rooms/test/reading_room_r02.tscn, bakes the StackGallery, then loads the
## baked scene under a fresh R01 in the generated room's place and checks it
## is the same room: a plain RoomTemplate, the same transform, modules, socket
## picks, connectors, fills and wear map, Validate Room clean, nothing left
## marked generated. Also the _in_host scene, and that the baked file holds
## module instances only (no spawned socket content).
## Persistence gate (AGENTS.md 6), in two processes:
##   ... --script res://tests/r02_bake_test.gd -- save   (bakes seed 7)
##   ... --script res://tests/r02_bake_test.gd -- load   (checks it against a fresh build)

const SCENE: String = "res://rooms/test/reading_room_r02.tscn"
const HOST: String = "res://rooms/authored/reading_room.tscn"
const OUT: String = "user://bake_test"
## Written by the "save" run, checked by the "load" run (separate processes).
const SAVED: String = "user://bake_persist/gallery_7.tscn"
## [seed, end_kind]: 7 has three alcoves, 4 a collapsed bay, 1 and 12 turn.
const CASES: Array = [[7, ""], [4, ""], [1, ""], [12, ""], [3, "dead_end"]]

var failures: PackedStringArray = []
var checks: int = 0


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures.append(what)


func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	# Persistence (AGENTS.md 6): "save" bakes in this process, "load" checks the
	# file against a fresh live build in a new one.
	var mode: String = OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else ""
	if mode == "save":
		await save_persist()
		quit(0 if failures.is_empty() else 1)
		return
	if mode == "load":
		if FileAccess.file_exists(SAVED):
			await bake_case(7, "", SAVED)
		else:
			check(false, "%s exists (run with -- save first)" % SAVED)
	else:
		for case: Array in CASES:
			await bake_case(case[0], case[1])
	print("r02_bake_test: %d checks, %d failures" % [checks, failures.size()])
	for f: String in failures:
		print("  FAIL ", f)
	quit(1 if not failures.is_empty() else 0)


func bake_case(s: int, end_kind: String, baked_file: String = "") -> void:
	var tag: String = "seed %d%s%s" % [s, (" " + end_kind) if end_kind != "" else "", (" from " + baked_file) if baked_file != "" else ""]
	# The live room.
	var room: RoomTemplate = (load(SCENE) as PackedScene).instantiate()
	var g: GeneratedRoom = room.get_node("StackGallery")
	g.gen_seed = s
	if end_kind != "":
		var grammar: StackGalleryGrammar = (g.grammar as StackGalleryGrammar).duplicate()
		grammar.end_kind = end_kind
		g.grammar = grammar
	root.add_child(room)
	await process_frame
	var live: Dictionary = describe(g)
	var path: String = "%s/gallery_%d%s.tscn" % [OUT, s, end_kind]
	var host_path: String = baked_file.get_basename() + "_in_host.tscn"
	if baked_file != "":
		path = baked_file      # baked by tools/bake_room.gd in another process
	else:
		check(RoomBaker.bake(g, path) == OK, "%s: bakes to %s" % [tag, path])
		host_path = RoomBaker.write_host_scene(g, SCENE, path)
	room.queue_free()
	await process_frame

	# The file: a RoomTemplate of module instances, nothing generated or spawned.
	var text: String = FileAccess.get_file_as_string(path)
	check(not text.contains("generated") and not text.contains("@"), "%s: nothing in the file is marked generated or auto-named" % tag)
	check(not text.contains("parent=\"Shell/") and not text.contains("parent=\"Dressing/") and text.contains("instance=ExtResource"), "%s: the file holds module instances, not their spawned content" % tag)
	check(text.count("[node ") < 400, "%s: compact (%d nodes, %d bytes)" % [tag, text.count("[node "), text.length()])

	# The baked room under a fresh R01, where the generated one was.
	var host: RoomTemplate = (load(HOST) as PackedScene).instantiate()
	var baked: Node = (load(path) as PackedScene).instantiate()
	check(baked is RoomTemplate and not baked is GeneratedRoom, "%s: the baked root is a plain RoomTemplate" % tag)
	host.add_child(baked)
	root.add_child(host)
	await process_frame
	var b := baked as RoomTemplate
	check(b.room_id == "stack_gallery_west" and b.preview_seed == s, "%s: room_id and seed kept (%s, %d)" % [tag, b.room_id, b.preview_seed])
	var got: Dictionary = describe(b)
	for k: String in live:
		check(str(got[k]) == str(live[k]), "%s: same %s as the live room (%s)" % [tag, k, diff(live[k], got[k])])
	var v: Dictionary = KitValidateRoom.run(b)
	check((v["errors"] as PackedStringArray).is_empty() and (v["warnings"] as PackedStringArray).is_empty(), "%s: the baked room validates clean (%s)" % [tag, v])
	check(KitValidate.scene(b).is_empty(), "%s: baked modules on the grid (%s)" % [tag, KitValidate.scene(b)])
	var rv: Dictionary = KitValidateRoom.run(host)
	check((rv["errors"] as PackedStringArray).is_empty() and host.sockets().size() == 106, "%s: R01 unchanged beside it (%s, %d sockets)" % [tag, rv["errors"], host.sockets().size()])
	check(b.find_children("*", "", true, false).all(func(n: Node) -> bool: return not n.has_meta("generated")), "%s: no node marked generated" % tag)
	host.queue_free()
	await process_frame

	# The host scene the game can load.
	check(host_path != "" and FileAccess.file_exists(host_path), "%s: wrote the host scene (%s)" % [tag, host_path])
	if host_path != "":
		var pair: Node = (load(host_path) as PackedScene).instantiate()
		var inner: Node = pair.get_node_or_null("StackGallery")
		check(pair is RoomTemplate and inner is RoomTemplate and not inner is GeneratedRoom, "%s: the host scene is R01 with the baked gallery" % tag)
		root.add_child(pair)
		await process_frame
		check(str(describe(inner as RoomTemplate)["modules"]) == str(live["modules"]), "%s: the host scene shows the same gallery" % tag)
		pair.queue_free()
		await process_frame
	print("  %s: %d modules, %d sockets, %d failures so far" % [tag, (live["modules"] as PackedStringArray).size(), (live["picks"] as Dictionary).size(), failures.size()])


## What must match between the live and the baked room. Read in the tree,
## after both rooms resolved.
func describe(r: RoomTemplate) -> Dictionary:
	var modules: PackedStringArray = []
	for holder: String in ["Shell", "Dressing"]:
		var h: Node = r.get_node_or_null(holder)
		for m: Node in h.get_children() if h != null else []:
			if m.scene_file_path != "":
				modules.append("%s/%s %s %s" % [holder, m.name, m.scene_file_path.get_file(), (m as Node3D).transform.origin.snappedf(0.01)])
	modules.sort()
	var picks: Dictionary = {}
	for s: VariantSocket in r.sockets():
		picks[r.socket_key(s)] = [s.last_pick, s.last_count]
	var connectors: PackedStringArray = []
	for c: Node in r.get_node("Connectors").get_children():
		connectors.append("%s %s %s %s" % [c.name, (c as Node3D).transform.origin.snappedf(0.01), c.get_meta("host_closes", false), c.is_in_group("room_connector")])
	connectors.sort()
	var fills: PackedStringArray = []
	for l: Node in r.get_node("Lights").get_children() if r.has_node("Lights") else []:
		if l is OmniLight3D:
			fills.append("%s %s %.2f" % [l.name, (l as Node3D).transform.origin.snappedf(0.01), (l as OmniLight3D).light_energy])
	fills.sort()
	FloorWear.rebuild_now()
	return {
		"transform": r.global_transform,
		"modules": modules,
		"picks": picks,
		"connectors": connectors,
		"fills": fills,
		"wear rect": FloorWear.map_rect,
		"wear map": hash(FloorWear.map_image.get_data()) if FloorWear.map_image != null else 0,
		"safety floor": r.has_node("TempSafetyFloor"),
	}


## A short note of how two values differ (first differing entry).
func diff(a: Variant, b: Variant) -> String:
	if a is Dictionary and b is Dictionary:
		for k: Variant in a:
			if not (b as Dictionary).has(k) or str(b[k]) != str(a[k]):
				return "%s: %s vs %s (%d vs %d entries)" % [k, a[k], (b as Dictionary).get(k), (a as Dictionary).size(), (b as Dictionary).size()]
		return "%d vs %d entries" % [(a as Dictionary).size(), (b as Dictionary).size()]
	if a is PackedStringArray and b is PackedStringArray:
		for i: int in mini(a.size(), b.size()):
			if a[i] != b[i]:
				return "%s vs %s" % [a[i], b[i]]
		return "%d vs %d entries" % [a.size(), b.size()]
	return "%s vs %s" % [a, b]


## The "save" half of the persistence gate: bake seed 7 (and its host scene).
func save_persist() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVED.get_base_dir()))
	var room: RoomTemplate = (load(SCENE) as PackedScene).instantiate()
	var g: GeneratedRoom = room.get_node("StackGallery")
	g.gen_seed = 7
	root.add_child(room)
	await process_frame
	var ok: bool = RoomBaker.bake(g, SAVED) == OK and RoomBaker.write_host_scene(g, SCENE, SAVED) != ""
	check(ok, "baked seed 7 to %s" % SAVED)
	print("r02_bake_test save: %s" % ("wrote " + SAVED if ok else "FAILED"))
	room.queue_free()
	await process_frame

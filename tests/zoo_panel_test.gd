extends SceneTree
## The zoo's tuning panel (ZooPanel). Headless:
##   godot --headless --audio-driver Dummy --path . --script res://tests/zoo_panel_test.gd
## With a display it also writes previews/zoo/panel.png.
## Checks: a setting changed on the panel respawns the zoo with it (more
## rats, no geckos at amount 0, bigger cats); Startle all sends the cats off;
## Ignore me keeps the rats out with you beside them; Undo puts the file's
## values back; Save writes the file and a fresh load reads the new value
## (the file is then put back as it was).

var failures: PackedStringArray = []
var checks: int = 0
var zoo: ZooRoom


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures.append(what)


func count(kind: String) -> int:
	var n: int = 0
	for slot: String in zoo.fauna.groups:
		for g: Node in zoo.fauna.groups[slot]:
			if is_instance_valid(g) and not g.is_queued_for_deletion() and str(g.get("def").id) == kind:
				n += (g as CatBand).count() if g is CatBand else (g as MultiMeshInstance3D).multimesh.instance_count
	return n


func settle() -> void:
	for i: int in 1800:
		await process_frame
		if i > 30 and zoo.fauna._jobs.is_empty():
			break
	for _i: int in 10:
		await process_frame


func pick(kind: String) -> CreatureDef:
	for i: int in zoo.panel.kinds.size():
		if str(zoo.panel.kinds[i].id) == kind:
			zoo.panel._pick.select(i)
			zoo.panel._pick.item_selected.emit(i)
			return zoo.panel.kinds[i]
	return null


## Moves the picked kind's slider for `field` to `v`, as a drag would.
func slide(field: String, v: float) -> bool:
	var d: CreatureDef = zoo.panel.kinds[zoo.panel.kind]
	var at: int = 0
	for f: Array in ZooPanel.FIELDS:
		if str(f[5]) != "" and not str(f[5]).split(" ").has(d.habitat):
			continue
		if d.habitat == "lane" and str(f[0]) == "group_size.x":
			continue
		at += 1
		if str(f[0]) == field:
			var rows: Array[Node] = zoo.panel._rows.get_children().filter(func(n: Node) -> bool: return not n.is_queued_for_deletion())
			((rows[at] as HBoxContainer).get_child(1) as HSlider).value = v
			return true
	return false


func run() -> void:
	var main_script: GDScript = load("res://scripts/main.gd")
	main_script.room_override = ZooRoom.SCENE
	var game: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	game.hud.visible = false
	game.player.blocked = true
	zoo = game.world as ZooRoom
	check(zoo != null and zoo.panel != null, "the zoo has its panel")
	if zoo == null:
		finish()
		return
	await settle()
	zoo.panel.set_open(true)
	# Rats: more in a group.
	var rats: int = count("rat")
	var rat: CreatureDef = pick("rat")
	check(slide("group_size.x", 20.0) and slide("group_size.y", 20.0), "the rat has group sliders")
	await create_timer(0.5).timeout
	await settle()
	check(count("rat") == 20 and count("rat") != rats, "20 rats after the sliders (were %d, now %d)" % [rats, count("rat")])
	# Geckos: amount 0.
	pick("gecko")
	zoo.panel._amount.value = 0.0
	await create_timer(0.5).timeout
	await settle()
	check(count("gecko") == 0, "no geckos at amount 0%% (%d)" % count("gecko"))
	zoo.panel._amount.value = 1.0
	# Cats: twice as long.
	var cat: CreatureDef = pick("cat")
	var was_length: float = cat.length_m
	slide("size.x", was_length * 2.0)
	slide("size.y", was_length * 2.0)
	await create_timer(0.5).timeout
	await settle()
	var band: CatBand = null
	for g: Node in zoo.fauna.groups.get("home", []):
		if g is CatBand and not g.is_queued_for_deletion():
			band = g as CatBand
	check(band != null and ((band.cats[0]["body"] as Node3D).scale.x > was_length * 2.0 / CatBand.MODEL_LENGTH * 0.95), "the cats are twice as big")
	# Startle all.
	if band != null:
		zoo.fauna.startle_all()
		check(band.cats.all(func(c: Dictionary) -> bool: return int(c["state"]) == CatBand.STARTLE), "Startle all startles the cats")
	if DisplayServer.get_name() != "headless":
		game.player.teleport(Vector3(-6.0, 0.1, -38.0), PI * 0.25)
		for _i: int in 60:
			await process_frame
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://previews/zoo"))
		root.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://previews/zoo/panel.png"))
	# Undo.
	zoo.panel._undo()
	check(is_equal_approx(cat.length_m, was_length), "Undo puts the cat's length back (%.2f)" % cat.length_m)
	# Ignore me: stand in the ruin; rats still come out.
	zoo.fauna.ignore_player = true
	game.player.teleport(Vector3(10.0, 0.1, -38.0))
	await settle()
	var out: bool = false
	for _i: int in 900:
		await process_frame
		for g: Node in zoo.fauna.groups.get("ruin", []):
			if g is RatPack and (g as RatPack).rats.any(func(r: Dictionary) -> bool: return int(r["state"]) == RatPack.RUN or int(r["state"]) == RatPack.SNIFF):
				out = true
		if out:
			break
	check(out, "with Ignore me on, rats are out with you in their room")
	zoo.fauna.ignore_player = false
	# Save: writes the file; a fresh read has it; then the file is put back.
	pick("rat")
	var path: String = rat.resource_path
	var text: String = FileAccess.get_file_as_string(path)
	slide("startle_radius", 6.5)
	zoo.panel._save()
	var read: String = FileAccess.get_file_as_string(path)
	check(read.contains("startle_radius = 6.5"), "Save writes the rat's file (startle_radius = 6.5)")
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()
	check(FileAccess.get_file_as_string(path) == text, "the test put the file back")
	zoo.panel.set_open(false)
	main_script.room_override = ""
	finish()


func finish() -> void:
	if failures.is_empty():
		print("zoo_panel_test: PASS (%d checks)" % checks)
		quit(0)
	else:
		for f: String in failures:
			print("  FAIL: " + f)
		print("zoo_panel_test: FAIL (%d of %d checks)" % [failures.size(), checks])
		quit(1)

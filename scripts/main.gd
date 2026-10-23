extends Node3D
const World = preload("res://scripts/world.gd")
const Player = preload("res://scripts/player.gd")
const Hud = preload("res://scripts/hud.gd")
var world
var player
var hud
## Live performance and streaming stats (F3 or the controls menu).
var stats: StatsOverlay
var inventory: Dictionary = {"mushroom":0,"root":0,"herb":0}
var nourishment: float = 80
var warmth: float = 65
var prepared_meal: String = ""
var meals_eaten: int = 0
var visited_gallery: bool = false
var visited_balcony: bool = false
var mute: bool = false
var audio: AudioStreamPlayer
var elapsed: float = 0
var modal_context: String = ""

## Authored rooms you can visit instead of the code-built camp (ENVIRONMENT_PLAN.md
## phase 1 step 6). Pick one with `-- --room=<res path>` or from the Esc menu.
const READING_ROOM: String = "res://rooms/authored/reading_room.tscn"
## R01 with a generated R02 Stack Gallery off its west door (ENVIRONMENT_PLAN.md
## phase 2). `-- --gen-seed=N` (or the menu's reseed) picks the corridor.
const STACK_GALLERY: String = "res://rooms/test/reading_room_r02.tscn"
## Areas you can walk (phase-4-design.md 8.1.3): `-- --area=<id>` or the Esc
## menu; "area:<id>" wherever a room path goes (room_override, the save's scene).
const AREAS: Dictionary = {"library": "res://gen/recipes/library_wing.tres"}
const AREA_PREFIX: String = "area:"
## Set by the menu before a reload; survives reload_current_scene().
static var room_override: String = ""
## The first boot of this process resumes from the save (ENVIRONMENT_PLAN.md 6.5.3, Q4).
static var booted: bool = false
## What this boot loaded: a room scene path, or "camp".
var scene_path: String = "camp"
var resuming: bool = false

func _ready() -> void:
	install_inputs()
	var preset: String = GraphicsPreset.requested()
	if preset != "" and not GraphicsPreset.apply(get_viewport(), preset):
		push_warning("main: no graphics preset '%s'" % preset)
	resuming = not booted and ws().loaded and room_override == "" and not Array(OS.get_cmdline_user_args()).any(func(a: String) -> bool: return a.begins_with("--room=") or a.begins_with("--area="))
	booted = true
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--gen-seed=") and GeneratedRoom.seed_override < 0:
			GeneratedRoom.seed_override = arg.trim_prefix("--gen-seed=").to_int()
		if arg.begins_with("--area-seed=") and Area.seed_override < 0:
			Area.seed_override = arg.trim_prefix("--area-seed=").to_int()
	if resuming and GeneratedRoom.seed_override < 0:
		GeneratedRoom.seed_override = int(ws().data.get("gen_seed_override", -1))
	if resuming and Area.seed_override < 0:
		Area.seed_override = int(ws().data.get("area_seed_override", -1))
	var room_path: String = requested_room()
	if resuming:
		var saved: String = str(ws().data.get("scene", ""))
		if str(ws().data.get("area", "")) != "":
			saved = AREA_PREFIX + str(ws().data["area"])     # an area wins over the scene (8.1.6)
		room_path = saved if saved != "camp" and _exists(saved) else ""
	scene_path = room_path if room_path != "" else "camp"
	ws().saving.connect(_on_saving)
	if room_path.is_empty():
		world = World.new()
	elif room_path.begins_with(AREA_PREFIX):
		world = Area.new()
		world.recipe = load(AREAS[room_path.trim_prefix(AREA_PREFIX)])
		var saved_pos: Array = (ws().data.get("player", {}) as Dictionary).get("pos", [])
		if resuming and saved_pos.size() == 3:
			world.start_point = Vector3(saved_pos[0], saved_pos[1], saved_pos[2])     # build the rooms around you first
			world.start_room = str(ws().data.get("room", ""))
	else:
		world = (load(room_path) as PackedScene).instantiate()
	world.name = "Environment"
	add_child(world)
	player = Player.new()
	add_child(player)
	player.walking_speed = 3.3
	player.camera.fov = 68
	if in_room():
		var spawn: Node3D = world.get_node_or_null("PlayerSpawn")
		var pose: Transform3D = spawn.global_transform if spawn != null else Transform3D(Basis(), Vector3(0, .1, 0))
		if world is Area:
			pose = (world as Area).spawn_transform()
		player.teleport(pose.origin, pose.basis.get_euler().y)
		player.respawn_point = pose.origin
	else:
		# v0.11: spawn on the concept-art framing (see tests/capture.gd 'concept').
		player.teleport(Vector3(-1.05,.08,9.2))
		look_toward(Vector3(-1.1,1.4,-2.4))
	var pose: Dictionary = ws().data.get("player", {})
	if resuming and (pose.get("pos", []) as Array).size() == 3:
		var p: Array = pose["pos"]
		player.teleport(Vector3(p[0], p[1], p[2]), float(pose.get("yaw", 0.0)), float(pose.get("pitch", 0.0)))
	player.blocked = false
	if world is Area and (world as Area).streamer != null:
		(world as Area).streamer.target = player
	player.interact_requested.connect(interact)
	for k: String in inventory:     # the satchel's ingredients come from the save
		inventory[k] = ws().item_count(StringName(k))
	hud = Hud.new()
	add_child(hud)
	hud.choice_selected.connect(on_choice)
	stats = StatsOverlay.new()
	stats.ui_theme = hud.theme
	stats.area = world as Area
	stats.visible = StatsOverlay.saved_visible()
	add_child(stats)
	audio = AudioStreamPlayer.new()
	audio.stream = load("res://assets/reading_garden_tar.ogg")
	if audio.stream is AudioStreamOggVorbis:
		audio.stream.loop = true
	audio.volume_db = -14
	add_child(audio)
	# Headless runs (CI gate, tests) have no listener; a playing Ogg there was
	# intermittently still held by the audio thread at quit ("2 resources still
	# in use at exit"). The stream stays loaded so music tests still apply.
	if DisplayServer.get_name() != "headless":
		audio.play()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	hud.update_values(inventory,nourishment,warmth)
	hud.notify("WASD explore  ·  E interact  ·  J field notes  ·  Esc menu")
	if in_room():
		hud.zone_label.text = room_title()

## "" = the camp. The menu's choice wins over the command line.
func requested_room() -> String:
	if room_override != "":
		return "" if room_override == "camp" else room_override
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--room=") or arg.begins_with("--area="):
			var path: String = arg.trim_prefix("--room=") if arg.begins_with("--room=") else AREA_PREFIX + arg.trim_prefix("--area=")
			if _exists(path):
				return path
			push_warning("main: no room or area at %s, starting the camp" % path)
	return ""

## A room scene that exists, or "area:<id>" of a known area.
func _exists(path: String) -> bool:
	return AREAS.has(path.trim_prefix(AREA_PREFIX)) if path.begins_with(AREA_PREFIX) else ResourceLoader.exists(path)

func in_room() -> bool:
	return world is RoomTemplate or world is Area

func room_title() -> String:
	if world is Area:
		var r: AreaPlan.Room = (world as Area).room_at(player.global_position) if player != null else null
		if r != null and (world as Area).rooms.has(r.slot_id):
			var shown: String = ((world as Area).rooms[r.slot_id] as RoomTemplate).display_name
			return (shown if shown != "" else r.slot_id).to_upper()
		return (world as Area).recipe.display_name.to_upper()
	var title: String = (world as RoomTemplate).display_name
	return (title if title != "" else String(world.name)).to_upper()

## Generated rooms in the current room (the stack gallery off R01).
func generated_rooms() -> Array[GeneratedRoom]:
	var out: Array[GeneratedRoom] = []
	if world is Node:
		for n: Node in (world as Node).find_children("*", "GeneratedRoom", true, false):
			out.append(n as GeneratedRoom)
	return out

## Saves, covers the screen while the next place is built, then goes there.
func travel(path: String) -> void:
	ws().save_now()
	room_override = path
	if hud != null:
		close_panel()
		player.blocked = true
		hud.show_loading("Finding the way…" if path != "camp" else "Back to the camp…")
		for _i: int in 2:     # let the panel reach the screen: the build blocks the frame
			await get_tree().process_frame
	get_tree().reload_current_scene()

## Just before every save: where the player is, so the next start resumes there.
func _on_saving() -> void:
	ws().data["scene"] = scene_path
	ws().data["gen_seed_override"] = GeneratedRoom.seed_override
	ws().data["area_seed_override"] = Area.seed_override
	ws().data["area"] = (world as Area).recipe.id if world is Area else ""
	# The room you were last in, even from a doorway: the start-up builds around it.
	ws().data["room"] = (world as Area).streamer.player_room if world is Area and (world as Area).streamer != null else ""
	for k: String in inventory:     # ingredients the cooking pot spent
		if int(inventory[k]) > 0:
			ws().satchel()["stacks"][k] = int(inventory[k])
		else:
			ws().satchel()["stacks"].erase(k)
	if player != null and is_instance_valid(player):
		var p: Vector3 = player.global_position
		ws().data["player"] = {"pos": [p.x, p.y, p.z], "yaw": player.rotation.y, "pitch": player.camera.rotation.x}

## Shows or hides the stats panel and remembers it (user://settings.cfg, not the save).
func toggle_stats() -> void:
	stats.visible = not stats.visible
	StatsOverlay.save_visible(stats.visible)

## Saves, then quits (the menu's Quit and closing the window).
func save_and_quit() -> void:
	ws().save_now()
	get_tree().quit()

func install_inputs() -> void:
	var actions = {"forward":[KEY_W,KEY_UP],"back":[KEY_S,KEY_DOWN],"left":[KEY_A,KEY_LEFT],"right":[KEY_D,KEY_RIGHT],"interact":[KEY_E],"jump":[KEY_SPACE],"sprint":[KEY_SHIFT],"notes":[KEY_J],"fullscreen":[KEY_F11],"stats":[KEY_F3]}
	for action in actions:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key in actions[action]:
			var event = InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action,event)

func look_toward(target: Vector3) -> void:
	var direction: Vector3 = player.camera.global_position.direction_to(target)
	player.rotation.y = atan2(-direction.x,-direction.z)
	player.camera.rotation.x = asin(direction.y)

func interact(target) -> void:
	if target.has_method("interact"):     # WorldProp and later room interactables (ENVIRONMENT_PLAN.md 6.5.1)
		var item: ItemDef = target.item if target is WorldProp else null
		target.interact(player, player.aim_point())
		if item != null and ws().owns(item.id):
			hud.notify("Took %s.  J — read it in your satchel." % item.display_name)
		return
	if in_room():
		return
	var id: String = target.get_interaction_id()
	if id == "pot":
		show_pot()
	elif id == "vista":
		visited_gallery = true
		hud.notify("Towers, bridges, and thousands of warm windows. The cavern roof closes over the Eternal Library.")
	else:
		var kind: String = world.harvest(id)
		if not kind.is_empty():
			inventory[kind] += 1
			ws().set_count(kind, inventory[kind])
			hud.notify("Gathered " + {"mushroom":"shelf mushrooms","root":"amberroot","herb":"hearthleaf"}[kind])
			hud.update_values(inventory,nourishment,warmth)

## HUD prompt for what the player aims at: room interactables say it themselves.
func prompt_for(target) -> String:
	if target == null:
		return ""
	if target.has_method("interaction_prompt"):
		return target.interaction_prompt(player.aim_point())
	return target.title

func open_panel(title: String, text: String, options: Array, context: String = "menu") -> void:
	player.blocked = true
	world.set_process(false)
	modal_context = context
	hud.open(title,text,options)

func close_panel() -> void:
	player.blocked = false
	world.set_process(true)
	modal_context = ""
	hud.close()

func show_pot() -> void:
	if not prepared_meal.is_empty():
		var name_text: String = "Amberroot & hearthleaf broth" if prepared_meal == "broth" else "Roasted shelf mushrooms"
		open_panel("A meal by the fire",name_text+" is ready.\n\nTake a quiet moment to eat before setting out again.",[{"text":"Eat the meal","action":"eat"},{"text":"Leave it for later","action":"close"}],"pot")
		return
	var text: String = "[color=#dfbd7b]Choose what to prepare.[/color]\n\nShelf mushrooms: %d    Amberroot: %d    Hearthleaf: %d\n\nRoasting makes a simple nourishing meal. Amberroot and hearthleaf make a more sustaining, warming broth." % [inventory.mushroom,inventory.root,inventory.herb]
	open_panel("At the cooking pot",text,[
		{"text":"Roast shelf mushrooms  ·  1 mushroom","action":"roast","disabled":inventory.mushroom<1},
		{"text":"Simmer amberroot broth  ·  1 root + 1 herb","action":"broth","disabled":inventory.root<1 or inventory.herb<1},
		{"text":"Return to the fire","action":"close"}],"pot")

func cook(recipe: String) -> bool:
	if not prepared_meal.is_empty():
		return false
	if recipe == "roast" and inventory.mushroom>0:
		inventory.mushroom -= 1
		prepared_meal = "roast"
	elif recipe == "broth" and inventory.root>0 and inventory.herb>0:
		inventory.root -= 1
		inventory.herb -= 1
		prepared_meal = "broth"
	else:
		return false
	hud.update_values(inventory,nourishment,warmth)
	return true

func eat() -> bool:
	if prepared_meal.is_empty():
		return false
	nourishment = minf(100,nourishment+(40 if prepared_meal=="broth" else 25))
	warmth = minf(100,warmth+(25 if prepared_meal=="broth" else 8))
	prepared_meal = ""
	meals_eaten += 1
	hud.update_values(inventory,nourishment,warmth)
	return true

func show_notes() -> void:
	if in_room():
		open_panel("Field notes","[color=#dfbd7b]%s[/color]\nA two-storey hall of shelf recesses under a tiled vault. Stairs at the far end of each side climb to a gallery that runs round to the entrance wall. A tiled iwan closes the hall; what stands in it changes from visit to visit.\n\nVases and the things on the tables can be pushed (E) or walked into; a vase that falls hard breaks. The library remembers what you knock over, even after you quit.\n\nEsc → Return to the camp." % room_title().capitalize() + satchel_text(),satchel_options(),"notes")
		return
	open_panel("Field notes","[color=#dfbd7b]The reading garden[/color]\nA cooking fire, a tree growing through the archive, and a stair to the upper gallery. Water still follows the old irrigation channel.\n\n[color=#dfbd7b]Ingredients[/color]\nAmberroot grows beside the garden's water. Filling.\nHearthleaf grows in sunny patches. Aromatic and warming.\nShelf mushrooms grow in the damp archive. Good roasted.\n\n[color=#dfbd7b]A route worth trying[/color]\nThe stairs east of the tree lead to the upper bookshelves. Follow the lamp-lit doorway through the gallery to the balcony. The Eternal Library continues far below the cavern roof." + satchel_text(),satchel_options(),"notes")

## The satchel section of the field notes (ENVIRONMENT_PLAN.md 6.5.8 step 3).
func satchel_text() -> String:
	var books: Array[ItemDef] = ws().owned_items()
	var text: String = "

[color=#dfbd7b]Satchel[/color]
"
	if books.is_empty():
		return text + "No books yet. Some shelves hold one worth taking: look for a gilt band on the spine."
	for book: ItemDef in books:
		text += "%s
" % book.display_name
	return text.strip_edges(false, true)

func satchel_options() -> Array:
	var options: Array = []
	for book: ItemDef in ws().owned_items():
		if book.kind == ItemDef.Kind.LORE:
			options.append({"text":"Read: %s" % book.display_name,"action":"read:%s" % book.id})
	options.append({"text":"Close notes","action":"close"})
	return options

## A lore book from the satchel, open to read.
func show_book(item_id: StringName) -> void:
	var book: ItemDef = ItemDef.find(item_id)
	if book == null or not ws().owns(item_id):
		show_notes()
		return
	open_panel(book.display_name, book.text, [{"text":"Back to the notes","action":"notes"},{"text":"Close","action":"close"}], "book")

func show_menu() -> void:
	var trips: Array = [{"text":"Return to the camp","action":"go_camp"}] if in_room() else [{"text":"Visit the reading room","action":"go_reading_room"}]
	if world is Area:
		trips.append({"text":"Reseed the library wing (seed %d, %d rooms)" % [(world as Area).plan.area_seed, (world as Area).plan.rooms.size()],"action":"reseed_area"})
	else:
		trips.append({"text":"Walk the library wing","action":"go_area"})
		if not in_room() or generated_rooms().is_empty():
			trips.append({"text":"Visit the stack gallery","action":"go_stack_gallery"})
		else:
			trips.append({"text":"Reseed the stack gallery (seed %d)" % generated_rooms()[0].effective_seed(),"action":"reseed"})
	var options: Array = [{"text":"Resume exploring","action":"close"}]
	options.append_array(trips)
	if in_room():
		# Test hook for a future janitor (NPC or event): puts every changed thing back.
		options.append({"text":"Tidy up (janitor test: %d changed)" % ws().changed_ids().size(),"action":"tidy"})
		# Test hook for the world clock (ENVIRONMENT_PLAN.md 6.5.6): untended lamps age.
		options.append({"text":"Let ten years pass (now year %d)" % int(ws().years()),"action":"years"})
	options.append_array([
		{"text":"Controls & settings","action":"controls"},
		{"text":"Begin another outing","action":"restart"},
		{"text":"Forget this library (start the world over)","action":"forget"},
		{"text":"Quit","action":"quit"}])
	var text: String = "A moment by the shelves."
	if world is Area and (world as Area).streamer != null:
		var s: AreaStreamer = (world as Area).streamer
		text += "\n[color=#8a8a80]live: %d of %d rooms · built %d, unloaded %d · slowest streaming frame %.1f ms[/color]" % [s.live_count(), (world as Area).plan.rooms.size(), s.stats["loads"], s.stats["unloads"], s.stats["max_frame_ms"]]
	open_panel(room_title().capitalize() if in_room() else "The reading garden",text,options,"menu")

func show_controls() -> void:
	open_panel("Controls & settings","WASD / arrows — walk\nMouse — look\nE — gather, cook, push\nShift — run     Space — jump\nJ — field notes     Esc — menu\nF11 — fullscreen     F3 — performance stats\n\nMovement pauses while a panel is open.",[
		{"text":"Mouse sensitivity: %.4f — cycle" % player.sensitivity,"action":"sensitivity"},
		{"text":"Invert look: %s" % ("On" if player.invert_y else "Off"),"action":"invert"},
		{"text":"Music: %s" % ("Off" if mute else "On"),"action":"mute"},
		{"text":"Performance stats: %s  (F3)" % ("On" if stats.visible else "Off"),"action":"stats"},
		{"text":"Back","action":"menu"}],"controls")

func on_choice(action: String) -> void:
	if action.begins_with("read:"):
		show_book(StringName(action.trim_prefix("read:")))
		return
	match action:
		"close": close_panel()
		"menu": show_menu()
		"controls": show_controls()
		"sensitivity":
			player.sensitivity = .0012 if player.sensitivity > .003 else player.sensitivity+.0012
			show_controls()
		"invert":
			player.invert_y = not player.invert_y
			show_controls()
		"mute":
			mute = not mute
			audio.volume_db = -80 if mute else -14
			show_controls()
		"stats":
			toggle_stats()
			show_controls()
		"restart":
			open_panel("Another outing?","Start again with an empty satchel and fresh ingredients in the garden?",[{"text":"Begin again","action":"restart_confirm"},{"text":"Keep this outing","action":"menu"}],"restart")
		"restart_confirm":
			for k: String in inventory:
				ws().set_count(k, 0)     # an empty satchel of ingredients; lore books stay
			get_tree().reload_current_scene()
		"notes": show_notes()
		"go_reading_room": travel(READING_ROOM)
		"go_stack_gallery": travel(STACK_GALLERY)
		"go_area": travel(AREA_PREFIX + "library")
		"reseed_area":
			Area.seed_override = randi() % 100000
			travel(AREA_PREFIX + "library")
		"reseed":
			GeneratedRoom.seed_override = randi() % 100000
			travel(room_override if room_override != "" else requested_room())
		"go_camp": travel("camp")
		"quit": save_and_quit()
		"forget":
			open_panel("Forget this library?","Everything you moved, broke or took is put back, and the save is deleted. This can't be undone.",[{"text":"Forget it all","action":"forget_confirm"},{"text":"Keep this library","action":"menu"}],"forget")
		"forget_confirm":
			ws().forget()
			room_override = scene_path
			get_tree().reload_current_scene()
		"years":
			ws().advance_years(10.0)
			for key: String in ws().rooms.keys():
				ws().rooms[key].refresh_aging()
			if world is Area and (world as Area).streamer != null:
				(world as Area).streamer.restart_job()     # a half-built room would mix two years
			# Rooms that aren't loaded store nothing about age: they're built at the new year.
			ws().save_now()
			close_panel()
			hud.notify("Ten years pass. It is year %d; untended lamps have had time to fail." % int(ws().years()))
		"tidy":
			# Everywhere in this area: a room that isn't loaded just drops its changes.
			var n: int = ws().revert_room("")
			close_panel()
			hud.notify("Tidied: %d thing%s put back where it stood." % [n, "" if n == 1 else "s"])
		"roast", "broth":
			if cook(action):
				show_pot()
		"eat":
			if eat():
				close_panel()
				hud.notify("A good meal, and another path to explore.")

func _process(delta: float) -> void:
	if player == null or hud == null or player.blocked:
		return
	elapsed += delta
	var target = player.get_target()
	hud.set_prompt(prompt_for(target))
	if in_room():
		if world is Area and (world as Area).room_at(player.global_position) != null:
			hud.zone_label.text = room_title()     # the room you're in (a doorway keeps the last one)
		# No hearth or cold archive here; only the slow nourishment drain.
		nourishment = maxf(0,nourishment-delta*.013)
		hud.update_values(inventory,nourishment,warmth)
		return
	var cold: bool = player.position.x > 5 and player.position.z < 0
	hud.zone_label.text = "THE DAMP ARCHIVE" if cold else "THE READING GARDEN"
	if player.position.z < -20:
		hud.zone_label.text = "THE ETERNAL LIBRARY · OVERLOOK"
		if not visited_balcony:
			visited_balcony = true
			hud.notify("The Eternal Library. Towers and bridges disappear into the depths.")
	# Deliberately gentle pressure for this visual exploration milestone; no death.
	nourishment = maxf(0,nourishment-delta*.013)
	if player.position.distance_to(world.hearth) < 3.1:
		warmth = minf(100,warmth+delta*.9)
	elif cold:
		warmth = maxf(0,warmth-delta*.18)
	hud.update_values(inventory,nourishment,warmth)
	if player.position.y > 1.8 and player.position.z < -9.3 and not visited_gallery:
		visited_gallery = true
		hud.notify("The upper gallery. Your camp is still there, below the arches.")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if hud.modal_open:
			close_panel()
		else:
			show_menu()
	elif event.is_action_pressed("notes"):
		if modal_context == "notes":
			close_panel()
		else:
			show_notes()
	elif event.is_action_pressed("stats"):
		toggle_stats()
	elif event.is_action_pressed("fullscreen"):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		ws().save_now()     # closing the window keeps the world (ENVIRONMENT_PLAN.md 6.5.3)
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and hud != null and not hud.modal_open:
		show_menu()

func _exit_tree() -> void:
	if is_instance_valid(audio):
		audio.stop()

## The WorldState autoload (the save). Looked up at run time: test scripts
## compile main.gd before autoload names exist.
func ws():
	return get_node("/root/WorldState")

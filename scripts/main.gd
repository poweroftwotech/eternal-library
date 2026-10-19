extends Node3D
const World = preload("res://scripts/world.gd")
const Player = preload("res://scripts/player.gd")
const Hud = preload("res://scripts/hud.gd")
var world
var player
var hud
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
## Set by the menu before a reload; survives reload_current_scene().
static var room_override: String = ""

func _ready() -> void:
	install_inputs()
	var room_path: String = requested_room()
	if room_path.is_empty():
		world = World.new()
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
		player.teleport(pose.origin, pose.basis.get_euler().y)
		player.respawn_point = pose.origin
	else:
		# v0.11: spawn on the concept-art framing (see tests/capture.gd 'concept').
		player.teleport(Vector3(-1.05,.08,9.2))
		look_toward(Vector3(-1.1,1.4,-2.4))
	player.blocked = false
	player.interact_requested.connect(interact)
	hud = Hud.new()
	add_child(hud)
	hud.choice_selected.connect(on_choice)
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
		if arg.begins_with("--room="):
			var path: String = arg.trim_prefix("--room=")
			if ResourceLoader.exists(path):
				return path
			push_warning("main: no room at %s, starting the camp" % path)
	return ""

func in_room() -> bool:
	return world is RoomTemplate

func room_title() -> String:
	var title: String = (world as RoomTemplate).display_name
	return (title if title != "" else String(world.name)).to_upper()

func travel(path: String) -> void:
	room_override = path
	get_tree().reload_current_scene()

func install_inputs() -> void:
	var actions = {"forward":[KEY_W,KEY_UP],"back":[KEY_S,KEY_DOWN],"left":[KEY_A,KEY_LEFT],"right":[KEY_D,KEY_RIGHT],"interact":[KEY_E],"jump":[KEY_SPACE],"sprint":[KEY_SHIFT],"notes":[KEY_J],"fullscreen":[KEY_F11]}
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
	var id: String = target.get_interaction_id()
	if in_room():
		return     # authored rooms get interactable props in phase 3 (WorldProp)
	if id == "pot":
		show_pot()
	elif id == "vista":
		visited_gallery = true
		hud.notify("Towers, bridges, and thousands of warm windows. The cavern roof closes over the Eternal Library.")
	else:
		var kind: String = world.harvest(id)
		if not kind.is_empty():
			inventory[kind] += 1
			hud.notify("Gathered " + {"mushroom":"shelf mushrooms","root":"amberroot","herb":"hearthleaf"}[kind])
			hud.update_values(inventory,nourishment,warmth)

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
		open_panel("Field notes","[color=#dfbd7b]%s[/color]\nA two-storey hall of shelf recesses under a tiled vault. Stairs at the far end of each side climb to a gallery that runs round to the entrance wall. A tiled iwan closes the hall; what stands in it changes from visit to visit.\n\nNothing to gather here yet. Esc → Return to the camp." % room_title().capitalize(),[{"text":"Close notes","action":"close"}],"notes")
		return
	open_panel("Field notes","[color=#dfbd7b]The reading garden[/color]\nA cooking fire, a tree growing through the archive, and a stair to the upper gallery. Water still follows the old irrigation channel.\n\n[color=#dfbd7b]Ingredients[/color]\nAmberroot grows beside the garden's water. Filling.\nHearthleaf grows in sunny patches. Aromatic and warming.\nShelf mushrooms grow in the damp archive. Good roasted.\n\n[color=#dfbd7b]A route worth trying[/color]\nThe stairs east of the tree lead to the upper bookshelves. Follow the lamp-lit doorway through the gallery to the balcony. The Eternal Library continues far below the cavern roof.",[{"text":"Close notes","action":"close"}],"notes")

func show_menu() -> void:
	var trip: Dictionary = {"text":"Return to the camp","action":"go_camp"} if in_room() else {"text":"Visit the reading room","action":"go_reading_room"}
	open_panel(room_title().capitalize() if in_room() else "The reading garden","A moment by the shelves.",[
		{"text":"Resume exploring","action":"close"},
		trip,
		{"text":"Controls & settings","action":"controls"},
		{"text":"Begin another outing","action":"restart"},
		{"text":"Quit","action":"quit"}],"menu")

func show_controls() -> void:
	open_panel("Controls & settings","WASD / arrows — walk\nMouse — look\nE — gather, cook, examine\nShift — run     Space — jump\nJ — field notes     Esc — menu\nF11 — fullscreen\n\nMovement pauses while a panel is open.",[
		{"text":"Mouse sensitivity: %.4f — cycle" % player.sensitivity,"action":"sensitivity"},
		{"text":"Invert look: %s" % ("On" if player.invert_y else "Off"),"action":"invert"},
		{"text":"Music: %s" % ("Off" if mute else "On"),"action":"mute"},
		{"text":"Back","action":"menu"}],"controls")

func on_choice(action: String) -> void:
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
		"restart":
			open_panel("Another outing?","Start again with an empty satchel and fresh ingredients in the garden?",[{"text":"Begin again","action":"restart_confirm"},{"text":"Keep this outing","action":"menu"}],"restart")
		"restart_confirm": get_tree().reload_current_scene()
		"go_reading_room": travel(READING_ROOM)
		"go_camp": travel("camp")
		"quit": get_tree().quit()
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
	hud.set_prompt(target.title if target != null else "")
	if in_room():
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
	elif event.is_action_pressed("fullscreen"):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and hud != null and not hud.modal_open:
		show_menu()

func _exit_tree() -> void:
	if is_instance_valid(audio):
		audio.stop()

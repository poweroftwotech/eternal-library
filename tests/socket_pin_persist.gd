extends SceneTree
## Persistence gate for room socket pins (AGENTS.md 6): save in one process,
## check in a fresh one.
##   godot --headless --path . --script res://tests/socket_pin_persist.gd -- save
##   godot --headless --path . --script res://tests/socket_pin_persist.gd -- load
## "save" pins two graybox sockets to a non-seeded candidate, packs the room
## and writes user://socket_pin_persist.tscn plus the expected picks.
## "load" opens that file and checks the pins and picks came back, and that the
## file needed no Editable Children ([editable] entries).

const GRAYBOX: String = "res://rooms/test/kit_graybox.tscn"
const OUT_SCENE: String = "user://socket_pin_persist.tscn"
const OUT_EXPECT: String = "user://socket_pin_persist.json"


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var ok: bool = false
	if args.has("save"):
		ok = save_room()
	elif args.has("load"):
		ok = load_room()
	else:
		print("socket_pin_persist: pass -- save or -- load")
	quit(0 if ok else 1)


func save_room() -> bool:
	var room: RoomTemplate = (load(GRAYBOX) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	get_root().add_child(room)
	var free: Dictionary = room.resolve_sockets(room.preview_seed)
	var sockets: Array[VariantSocket] = room.sockets()
	var pins: Dictionary[String, int] = {}
	for s: VariantSocket in [sockets[0], sockets[3]]:
		var key: String = room.socket_key(s)
		pins[key] = (int(free[key]) + 1) % s.candidate_count()
	room.socket_pins = pins
	var expect: Dictionary = room.resolve_sockets(room.preview_seed)
	var packed := PackedScene.new()
	if packed.pack(room) != OK or ResourceSaver.save(packed, OUT_SCENE) != OK:
		print("socket_pin_persist: FAIL could not save ", OUT_SCENE)
		return false
	var f: FileAccess = FileAccess.open(OUT_EXPECT, FileAccess.WRITE)
	f.store_string(JSON.stringify({"pins": pins, "picks": expect}))
	f.close()
	print("socket_pin_persist: saved %d pins -> %s" % [pins.size(), ProjectSettings.globalize_path(OUT_SCENE)])
	return true


func load_room() -> bool:
	var expect: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OUT_EXPECT))
	var text: String = FileAccess.get_file_as_string(OUT_SCENE)
	var room: RoomTemplate = (load(OUT_SCENE) as PackedScene).instantiate()
	get_root().add_child(room)   # _ready resolves from preview_seed
	var fails: PackedStringArray = []
	if text.contains("[editable"):
		fails.append("saved room needed Editable Children")
	if room.socket_pins.size() != (expect["pins"] as Dictionary).size():
		fails.append("pins saved %d, restored %d" % [(expect["pins"] as Dictionary).size(), room.socket_pins.size()])
	for s: VariantSocket in room.sockets():
		var key: String = room.socket_key(s)
		if int(expect["picks"][key]) != s.last_pick:
			fails.append("%s: expected pick %d, got %d" % [key, int(expect["picks"][key]), s.last_pick])
	for key: String in expect["pins"]:
		if room.socket_pins.get(key, -1) != int(expect["pins"][key]):
			fails.append("%s: pin not restored" % key)
	print("socket_pin_persist: %d sockets, %d pins, %d failures" % [room.sockets().size(), room.socket_pins.size(), fails.size()])
	for line: String in fails:
		print("  FAIL ", line)
	return fails.is_empty()

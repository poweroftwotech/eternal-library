extends Node
## The world's save (ENVIRONMENT_PLAN.md 6.5.3), autoloaded as WorldState.
##
## It holds only differences from the original world (deltas), never a copy
## of it: every room is rebuilt from its scene and seed, then its deltas are
## laid on top. So the original is always there underneath, and dropping a
## delta puts a thing back as it was. Each delta also records the thing's
## original transform (in its room's frame) and its scene, so that a later
## "janitor" (an NPC or an event that tidies up) can put things back while the
## room is loaded: revert(id), revert_room(room_key), changed_ids(room_key),
## and the reverted signal.
##
## One JSON file per slot (user://saves/slot0.json). User args: --save=<path>
## uses another file (tests always do), --fresh ignores the file on disk until
## the first save overwrites it.

## A delta was dropped and its thing put back as it was.
signal reverted(id: String)
## Emitted just before writing: main fills in the scene and player pose,
## rooms record props that are still moving.
signal saving

const VERSION: int = 2
const DEFAULT_PATH: String = "user://saves/slot0.json"
## The area every room outside an Area belongs to (phase 3 saves used only
## this one), and the first AreaRecipe's id (phase-4-design.md 8.1.6).
const DEFAULT_AREA: String = "library"
## Seconds after a change before it is written.
const SAVE_DELAY: float = 1.0

var path: String = DEFAULT_PATH
var data: Dictionary = {}
## Whether a save file was read at start (main resumes from it).
var loaded: bool = false
## Live rooms by room key (RoomTemplate.room_key()).
var rooms: Dictionary = {}
var _applied: Dictionary = {}     # ids a live room found and applied
var _dirty: bool = false
var _timer: float = 0.0
var _age_rules: AgeRules


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var fresh: bool = false
	# Test scripts and headless gates never touch the player's slot unless told to.
	if OS.get_cmdline_args().has("--script") or DisplayServer.get_name() == "headless":
		path = "user://test/scratch.json"
		fresh = true
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for arg: String in args:
		if arg.begins_with("--save="):
			path = arg.trim_prefix("--save=")
			fresh = args.has("--fresh")
		elif arg == "--fresh":
			fresh = true
	data = blank()
	if not fresh:
		loaded = load_save()
	for arg: String in args:
		if arg.begins_with("--advance-years="):     # tests and checks: years pass at start
			advance_years(arg.trim_prefix("--advance-years=").to_float())


func blank() -> Dictionary:
	# area/room: where the player is when inside an Area ("" elsewhere: the camp
	# or a test scene, which `scene` names); area_seed_override as gen_seed_override.
	return {"version": VERSION, "world_seed": 1, "clock_days": 0.0, "scene": "", "player": {},
		"area": "", "room": "", "area_seed_override": -1,
		"gen_seed_override": -1, "inventory": {}, "areas": {DEFAULT_AREA: {"recipe_version": 1, "deltas": {}, "spawned": []}}}


## Reads the save. A version 1 save (phase 3) is read as version 2: it was
## never in an area, and its changes are already under areas.library.
func load_save() -> bool:
	if not FileAccess.file_exists(path):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	var version: int = int((parsed as Dictionary).get("version", 0)) if parsed is Dictionary else 0
	if version != VERSION and version != 1:
		push_warning("WorldState: %s is not a version 1 or %d save; starting a new world" % [path, VERSION])
		return false
	data = blank()
	data.merge(parsed as Dictionary, true)
	data["version"] = VERSION
	return true


## Writes the save now (to <path>.tmp, then renamed over the old file).
func save_now() -> Error:
	saving.emit()
	_dirty = false
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var tmp: String = path + ".tmp"
	var file: FileAccess = FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		push_warning("WorldState: cannot write %s (%s)" % [tmp, error_string(FileAccess.get_open_error())])
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	var err: Error = DirAccess.rename_absolute(tmp, path)
	if err != OK:
		push_warning("WorldState: cannot replace %s (%s)" % [path, error_string(err)])
	return err


func mark_dirty() -> void:
	_dirty = true
	_timer = SAVE_DELAY


func _process(delta: float) -> void:
	if _dirty:
		_timer -= delta
		if _timer <= 0.0:
			save_now()


## Starts a new world: forgets every change and deletes the save file.
func forget() -> void:
	data = blank()
	_applied.clear()
	_dirty = false
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


# --- deltas --------------------------------------------------------------------

## Which area's changes rooms read and write (8.1.6): an Area sets it before
## any room enters; everything else is in DEFAULT_AREA.
var area_id: String = DEFAULT_AREA


## An Area is about to build its rooms: their changes live under areas[id]. A
## recipe newer than the save's keeps every delta whose room key still exists.
func enter_area(id: String, recipe_version: int) -> void:
	area_id = id
	var bucket: Dictionary = area_bucket()
	if int(bucket.get("recipe_version", recipe_version)) < recipe_version:
		push_warning("WorldState: area %s was saved with recipe version %d, now %d; moved rooms' changes go stale" % [id, int(bucket["recipe_version"]), recipe_version])
	bucket["recipe_version"] = recipe_version


## The Area left the tree: rooms outside areas use DEFAULT_AREA again.
func leave_area() -> void:
	area_id = DEFAULT_AREA


## This area's part of the save, created if it isn't there yet.
func area_bucket() -> Dictionary:
	var areas: Dictionary = data["areas"]
	if not areas.has(area_id):
		areas[area_id] = {"recipe_version": 1, "deltas": {}, "spawned": []}
	return areas[area_id]


func deltas() -> Dictionary:
	return area_bucket()["deltas"]


func delta(id: String) -> Dictionary:
	return deltas().get(id, {})


func set_delta(id: String, d: Dictionary) -> void:
	deltas()[id] = d
	_applied[id] = true
	mark_dirty()


## Drops a delta without touching the live world (the thing is back as it was).
func clear_delta(id: String) -> void:
	if deltas().has(id):
		deltas().erase(id)
		mark_dirty()


## Ids of everything changed in a room ("" = everywhere): a janitor's to-do list.
func changed_ids(room_key: String = "") -> PackedStringArray:
	var out: PackedStringArray = []
	for id: String in deltas():
		if room_key == "" or id.begins_with(room_key + "/"):
			out.append(id)
	return out


## Puts one thing back as it was: the live room (if loaded) restores it in
## place, and the delta is dropped. Returns whether there was anything to undo.
func revert(id: String) -> bool:
	if not deltas().has(id):
		return false
	if str(deltas()[id].get("s", "")) == "taken":
		return false     # it's in the satchel: putting it back would make two (6.5.9)
	var room: Node = rooms.get(room_key_of(id))
	if room != null and is_instance_valid(room):
		room.call("revert_thing", id)
	deltas().erase(id)
	_applied.erase(id)
	mark_dirty()
	reverted.emit(id)
	return true


## Puts everything in a room back; returns how many things were reverted.
func revert_room(room_key: String) -> int:
	var n: int = 0
	for id: String in changed_ids(room_key):
		if revert(id):
			n += 1
	return n


static func room_key_of(id: String) -> String:
	return id.get_slice("/", 0)


# --- the world clock and aging (ENVIRONMENT_PLAN.md 6.5.6) ------------------------
# The clock only moves when told to in phase 3 (the Esc menu, --advance-years).
# Aging stores nothing: each socket draws a fixed number from its id, and the
# rules turn years into how far along its chain it has gone.

## Years since the world began.
func years() -> float:
	return float(data.get("clock_days", 0.0)) / 365.0


func advance_years(n: float) -> void:
	data["clock_days"] = float(data.get("clock_days", 0.0)) + n * 365.0
	mark_dirty()


func age_rules() -> AgeRules:
	if _age_rules == null:
		_age_rules = AgeRules.default()
	return _age_rules


## The fixed draw (0..1) a thing ages by: the same in every process.
func age_draw(id: String) -> float:
	var h: int = hash([int(data.get("world_seed", 1)), id, "age"])
	return float(posmod(h, 1000003)) / 1000003.0


# --- the satchel (ENVIRONMENT_PLAN.md 6.5.1: Inventory) ---------------------------
# {"stacks": {id: count}, "owned": [unique ids]}. Ids only, never copies.

func satchel() -> Dictionary:
	var inv: Dictionary = data["inventory"]
	if not inv.has("stacks"):
		inv["stacks"] = {}
	if not inv.has("owned"):
		inv["owned"] = []
	return inv


## Adds one (or `count`) of an item. A unique item is held once; returns
## false if it was already there.
func add_item(item: ItemDef, count: int = 1) -> bool:
	if item == null:
		return false
	var inv: Dictionary = satchel()
	if item.unique:
		if (inv["owned"] as Array).has(String(item.id)):
			return false
		(inv["owned"] as Array).append(String(item.id))
	else:
		var have: int = int(inv["stacks"].get(String(item.id), 0))
		inv["stacks"][String(item.id)] = mini(have + count, item.stack_max)
	mark_dirty()
	return true


func owns(item_id: StringName) -> bool:
	return (satchel()["owned"] as Array).has(String(item_id))


func item_count(item_id: StringName) -> int:
	return 1 if owns(item_id) else int(satchel()["stacks"].get(String(item_id), 0))


## Sets a stacked item's count (the camp's cooking pot spends ingredients).
func set_count(item_id: StringName, count: int) -> void:
	if count <= 0:
		satchel()["stacks"].erase(String(item_id))
	else:
		satchel()["stacks"][String(item_id)] = count
	mark_dirty()


## Unique items in the order they were taken.
func owned_items() -> Array[ItemDef]:
	var out: Array[ItemDef] = []
	for item_id: Variant in satchel()["owned"]:
		var def: ItemDef = ItemDef.find(StringName(str(item_id)))
		if def != null:
			out.append(def)
	return out


# --- live rooms ------------------------------------------------------------------

func register_room(room: Node) -> void:
	var key: String = room.call("room_key")
	rooms[key] = room
	room.tree_exiting.connect(func() -> void:
		if rooms.get(key) == room:
			rooms.erase(key))


func note_applied(id: String) -> void:
	_applied[id] = true


## Deltas in a live room that matched nothing there (the room was edited and
## the thing renamed or removed). They are kept in the save, never applied.
func stale_ids() -> PackedStringArray:
	var out: PackedStringArray = []
	for id: String in deltas():
		if rooms.has(room_key_of(id)) and not _applied.has(id):
			out.append(id)
	return out


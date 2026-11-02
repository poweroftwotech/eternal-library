extends RefCounted
## The game side of the Strata Board (phase 10): describes the stratum and an
## area's recipe, and plans a recipe for a seed with the game's own
## AreaPlanner, all as plain data (JSON-safe dictionaries) for the board.
##
## The editor can't run the planner itself: the grammars and RoomTemplate are
## not @tool scripts, so in the editor they load as placeholders. The board
## runs this in its own headless process (service_main.gd) and talks to it
## over a pipe; tests call handle() directly.

## The places that aren't areas (no recipe).
const CAMP_NAME: String = "The Reading Garden camp"
## By path: an autoload's name isn't known while a --script compiles.
const WORLD_STATE: GDScript = preload("res://scripts/world/world_state.gd")
const GRAMMARS: String = "res://gen/grammars"
const SCENE_DIRS: Array = ["res://rooms/authored", "res://rooms/baked"]
## A save checks these world seeds for rooms the edit would move.
const MOVED_WORLDS: int = 20
## Named copies of an area's recipe to try things on: <DRAFTS>/<area id>/<name>.tres.
## The game only plays them through Walk this seed; Make live puts one in the game.
const DRAFTS: String = "res://gen/recipes/drafts"
## Where a new area's recipe is written.
const RECIPES_DIR: String = "res://gen/recipes"
## Tests: copies kept here instead, and live recipes read and written at these
## paths (area id -> path) instead of the stratum plan's; the stratum plan read
## and written at stratum_path, new areas' recipes written in recipes_dir.
static var drafts_dir: String = DRAFTS
static var live_paths: Dictionary = {}
static var stratum_path: String = StratumPlan.PATH
static var recipes_dir: String = RECIPES_DIR


## Tests: point copies, live recipes, the stratum plan and new recipes at
## scratch paths; scratch("", {}) undoes it.
static func scratch(drafts: String, live: Dictionary, stratum: String = "", new_recipes: String = "") -> void:
	drafts_dir = drafts if drafts != "" else DRAFTS
	live_paths = live
	stratum_path = stratum if stratum != "" else StratumPlan.PATH
	recipes_dir = new_recipes if new_recipes != "" else RECIPES_DIR
	StratumPlan.drop_cache()


## One request: {cmd: "stratum" | "recipe" | "plan" | "save" | "make_live" | ..., ...}. Returns the answer,
## or {error: why}.
static func handle(req: Dictionary) -> Dictionary:
	match str(req.get("cmd", "")):
		"stratum":
			return stratum()
		"recipe":
			var recipe: AreaRecipe = _load_recipe(str(req.get("path", "")), bool(req.get("fresh", false)))
			return describe(recipe) if recipe != null else {"error": "no recipe at %s" % req.get("path", "")}
		"plan":
			# With `desc`, the board's unsaved edit of the recipe; with
			# `connections`, of the connection table.
			var recipe: AreaRecipe = build(req["desc"]) if req.has("desc") else _load_recipe(str(req.get("path", "")), false)
			if recipe == null:
				return {"error": "no recipe at %s" % req.get("path", req.get("desc", {}).get("path", ""))}
			if req.has("connections"):
				ConnectionTable.use(_table(req["connections"]))
			var out: Dictionary = plan(recipe, int(req.get("world_seed", 1)), int(req.get("map_px", 10)))
			if req.has("connections"):
				ConnectionTable.drop_cache()
			return out
		"catalog":
			return catalog()
		"connections":
			ConnectionTable.drop_cache()
			return {"rules": ConnectionTable.default().rules.duplicate(), "types": RoomTypes.NAMES.duplicate(),
				"mtime": _mtime(ConnectionTable.PATH), "weight": ConnectionTable.PREFER_WEIGHT}
		"save":
			return save(req["desc"], str(req.get("to", "")), int(req.get("mtime", 0)), bool(req.get("force", false)), str(req.get("as", "")))
		"make_live":
			return make_live(str(req.get("path", "")))
		"delete_draft":
			return delete_draft(str(req.get("path", "")))
		"add_area":
			return add_area(str(req.get("name", "")), str(req.get("from", "")), str(req.get("at", "")))
		"set_door":
			return set_door(str(req.get("area", "")), str(req.get("at", "")))
		"remove_area":
			return remove_area(str(req.get("area", "")))
		"layout":
			return layout(int(req.get("world_seed", 1)))
		"save_connections":
			return save_connections(req.get("rules", {}), int(req.get("mtime", 0)), bool(req.get("force", false)))
	return {"error": "unknown request %s" % req.get("cmd", "")}


## What a room can be made from, for the board's type pickers: generated
## rooms' grammars and authored or baked scenes, each with its room type;
## a scene with no SNAP_entry can only be an area's entrance (Q6).
static func catalog() -> Dictionary:
	var grammars: Array = []
	for f: String in DirAccess.get_files_at(GRAMMARS):
		var path: String = GRAMMARS.path_join(f.trim_suffix(".remap"))
		var type: String = RoomTypes.of_path(path)
		if type != "" and f.ends_with(".tres") and not (load(path) is ChasmGrammar):
			grammars.append({"path": path, "type": type, "type_name": RoomTypes.NAMES.get(type, "")})
	var scenes: Array = []
	for dir: String in SCENE_DIRS:
		for f: String in DirAccess.get_files_at(dir):
			var path: String = dir.path_join(f.trim_suffix(".remap"))
			var type: String = RoomTypes.of_path(path)
			if type != "" and f.ends_with(".tscn") and not f.contains("_in_host"):
				scenes.append({"path": path, "type": type, "type_name": RoomTypes.NAMES.get(type, ""), "entrance_only": not _has_entry(path)})
	return {"grammars": grammars, "scenes": scenes, "types": RoomTypes.NAMES.duplicate()}


## An AreaRecipe from a description as describe() gives it, edited on the
## board: the file's recipe with its rooms, grow rules and limits replaced.
## Its placement, atmosphere, scenery and network stay as they are, and so do
## each room's and rule's other fields (its module rules, doors out of the
## area), found by `orig`, the id it had when described. The file's recipe
## itself isn't changed.
static func build(desc: Dictionary) -> AreaRecipe:
	var base: AreaRecipe = _load_recipe(str(desc.get("path", "")), false)
	if base == null:
		return null
	var r: AreaRecipe = base.duplicate(false)
	var slots: Array[AreaSlot] = []
	for d: Dictionary in desc.get("slots", []):
		var was: AreaSlot = base.slot(str(d.get("orig", "")))
		var s: AreaSlot = was.duplicate(false) if was != null else AreaSlot.new()
		s.slot_id = str(d["slot_id"])
		s.display_name = str(d.get("display_name", ""))
		s.parent = str(d.get("parent", ""))
		s.connector = StringName(str(d.get("connector", "")))
		s.pinned = bool(d.get("pinned", false))
		var scenes: Array = d.get("scenes", [])
		if str(d.get("kind", "")) == "scene" and not scenes.is_empty():
			var choices: Array[PackedScene] = []
			for p: String in scenes:
				choices.append(load(p) as PackedScene)
			s.scene = choices[0]
			s.scene_choices = choices if choices.size() > 1 else ([] as Array[PackedScene])
			var w: Array = d.get("weights", [])
			s.scene_weights = PackedFloat32Array(w) if w.size() == choices.size() and choices.size() > 1 \
				and not w.all(func(x: Variant) -> bool: return is_equal_approx(float(x), float(w[0]))) else PackedFloat32Array()
			s.pinned_choice = int(d.get("pinned_choice", -1)) if choices.size() > 1 else -1
			s.grammar = null
			s.rules = null
		else:
			var g: RoomGrammar = load(str(d.get("grammar", ""))) as RoomGrammar
			if was == null or was.grammar != g:
				s.rules = null     # module rules belong to a grammar
			s.grammar = g
			s.scene = null
			s.scene_choices = []
			s.scene_weights = PackedFloat32Array()
			s.pinned_choice = -1
		var thresholds: Dictionary = {}
		var th: Dictionary = d.get("thresholds", {})
		for k: String in th:
			thresholds[StringName(k)] = str(th[k])
		s.thresholds = thresholds
		slots.append(s)
	r.slots = slots
	var grow: Array[AreaGrow] = []
	for d: Dictionary in desc.get("grow", []):
		var was: AreaGrow = null
		for g: AreaGrow in base.grow:
			if g != null and g.slot_prefix == str(d.get("orig", "")):
				was = g
		var g: AreaGrow = was.duplicate(false) if was != null else AreaGrow.new()
		g.slot_prefix = str(d["prefix"])
		g.display_name = str(d.get("display_name", ""))
		var gram: RoomGrammar = load(str(d.get("grammar", ""))) as RoomGrammar
		if was == null or was.grammar != gram:
			g.rules = null
		g.grammar = gram
		var c: Array = d.get("count", [1, 1])
		g.count = Vector2i(int(c[0]), int(c[1]))
		g.from = PackedStringArray(d.get("from", []))
		g.min_depth = int(d.get("min_depth", 0))
		g.pinned = bool(d.get("pinned", false))
		grow.append(g)
	r.grow = grow
	var rc: Array = desc.get("room_count", [base.room_count.x, base.room_count.y])
	r.room_count = Vector2i(int(rc[0]), int(rc[1]))
	r.max_dead_ends = int(desc.get("max_dead_ends", base.max_dead_ends))
	r.max_sight_depth = int(desc.get("max_sight_depth", base.max_sight_depth))
	return r


## How many of the worlds in `worlds` a change from recipe `old` to `new`
## (and from the table `old_table` to the current one) would move rooms in:
## each world planned as it is, then again with the change, keeping the
## variants its save recorded (Q5), as the game would.
static func moved(old: AreaRecipe, new: AreaRecipe, worlds: Array, old_table: ConnectionTable = null) -> Array:
	var out: Array = []
	var new_table: ConnectionTable = ConnectionTable.default()
	for w: int in worlds:
		if old_table != null:
			ConnectionTable.use(old_table)
		var before: AreaPlan = AreaPlanner.plan(old, AreaPlanner.area_seed_for(old, w))
		ConnectionTable.use(new_table)
		var after: AreaPlan = AreaPlanner.plan(new, AreaPlanner.area_seed_for(new, w), before.variants)
		if before.signature() != after.signature():
			out.append(w)
	return out


## Writes an edited recipe (to `to`, or its own file; with `as_name`, to a new
## named copy, never over one). Refuses if the file changed on disk since the
## board read it (`mtime`), unless `force`. When an edit of a live recipe moves
## rooms in any of world seeds 1-20, raises the version, so saves made before
## know their rooms moved; a copy's version only matters at make_live.
static func save(desc: Dictionary, to: String, mtime: int, force: bool, as_name: String = "") -> Dictionary:
	var path: String = str(desc.get("path", ""))
	if as_name != "":
		to = draft_path(str(desc.get("id", "")), as_name)
		if to == "":
			return {"error": "a copy needs a name with a letter or digit in it"}
		if FileAccess.file_exists(to):
			return {"error": "there is already a copy called \"%s\"" % draft_name(to)}
	elif not force and mtime != 0 and _mtime(path) != mtime:
		return {"conflict": "%s changed on disk since the board read it (a hand edit?)" % path}
	var problem: String = _check(desc)
	if problem != "":
		return {"error": problem}
	var base: AreaRecipe = _load_recipe(path, true)
	var edited: AreaRecipe = build(desc)
	var target: String = to if to != "" else path
	var worlds: Array = []
	if not is_draft(target):
		worlds = moved(base, edited, range(1, MOVED_WORLDS + 1))
	edited.version = base.version + (1 if not worlds.is_empty() else 0)
	if is_draft(target):
		DirAccess.make_dir_recursive_absolute(target.get_base_dir())
	var err: Error = ResourceSaver.save(edited, target)
	if err != OK:
		return {"error": "cannot write %s (%s)" % [target, error_string(err)]}
	edited.take_over_path(target)
	return {"saved": target, "version": edited.version, "moved": worlds, "of": MOVED_WORLDS, "mtime": _mtime(target),
		"desc": describe(edited), "draft": is_draft(target), "drafts": drafts(edited.id)}


## Puts the copy at `path` in the game: it becomes the area's live recipe,
## its version raised if that moves rooms in world seeds 1-20 (as a save would).
## The live recipe before is kept as a copy, so nothing is lost.
static func make_live(path: String) -> Dictionary:
	if not is_draft(path) or not FileAccess.file_exists(path):
		return {"error": "no copy at %s" % path}
	var draft: AreaRecipe = _load_recipe(path, true)
	var live_path: String = str(live_paths.get(draft.id, _stratum_plan().recipes().get(draft.id, ""))) if draft != null else ""
	if live_path == "":
		return {"error": "%s isn't a copy of an area in the stratum" % path}
	var live: AreaRecipe = _load_recipe(live_path, true)
	var keep: String = draft_path(draft.id, "live v%d before %s" % [live.version, draft_name(path)])
	var n: int = 2
	while FileAccess.file_exists(keep):
		keep = draft_path(draft.id, "live v%d before %s %d" % [live.version, draft_name(path), n])
		n += 1
	DirAccess.make_dir_recursive_absolute(keep.get_base_dir())
	var err: Error = DirAccess.copy_absolute(ProjectSettings.globalize_path(live_path), ProjectSettings.globalize_path(keep))
	if err != OK:
		return {"error": "cannot keep the live recipe as %s (%s)" % [keep, error_string(err)]}
	var made: AreaRecipe = build(describe(draft))
	var worlds: Array = moved(live, made, range(1, MOVED_WORLDS + 1))
	made.version = live.version + (1 if not worlds.is_empty() else 0)
	err = ResourceSaver.save(made, live_path)
	if err != OK:
		return {"error": "cannot write %s (%s)" % [live_path, error_string(err)]}
	made.take_over_path(live_path)
	return {"saved": live_path, "kept": keep, "from": path, "was": live.version, "version": made.version, "moved": worlds,
		"of": MOVED_WORLDS, "desc": describe(made), "drafts": drafts(made.id)}


## Deletes the copy at `path` (only ever a copy, never a live recipe).
static func delete_draft(path: String) -> Dictionary:
	if not is_draft(path) or not FileAccess.file_exists(path):
		return {"error": "no copy at %s" % path}
	var id: String = path.get_base_dir().get_file()
	var err: Error = DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if err != OK:
		return {"error": "cannot delete %s (%s)" % [path, error_string(err)]}
	return {"deleted": path, "drafts": drafts(id)}


## The copies of area `id`: [{name, path, mtime}], by name.
static func drafts(id: String) -> Array:
	var dir: String = "%s/%s" % [drafts_dir, id]
	var out: Array = []
	if id == "" or not DirAccess.dir_exists_absolute(dir):
		return out
	for f: String in DirAccess.get_files_at(dir):
		if f.get_extension() == "tres":
			out.append({"name": draft_name(f), "path": "%s/%s" % [dir, f], "mtime": _mtime("%s/%s" % [dir, f])})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a["name"]) < str(b["name"]))
	return out


## Where a copy called `name` of area `id` lives ("" = no usable name).
static func draft_path(id: String, name: String) -> String:
	var re := RegEx.create_from_string("[^a-z0-9]+")
	var slug: String = re.sub(name.strip_edges().to_lower(), "_", true).trim_prefix("_").trim_suffix("_")
	return "%s/%s/%s.tres" % [drafts_dir, id, slug] if slug != "" and id != "" else ""


static func draft_name(path: String) -> String:
	return path.get_file().get_basename().replace("_", " ")


static func is_draft(path: String) -> bool:
	return path.begins_with(drafts_dir + "/")


## Writes the connection table. Every interior whose rooms it moves (in
## world seeds 1-20) gets its version raised.
static func save_connections(rules: Dictionary, mtime: int, force: bool) -> Dictionary:
	if not force and mtime != 0 and _mtime(ConnectionTable.PATH) != mtime:
		return {"conflict": "%s changed on disk since the board read it (a hand edit?)" % ConnectionTable.PATH}
	ConnectionTable.drop_cache()
	var old_table: ConnectionTable = ConnectionTable.default()
	var table: ConnectionTable = _table(rules)
	ConnectionTable.use(table)
	var bumped: Dictionary = {}
	var recipe_paths: Dictionary = _stratum_plan().recipes()
	for id: String in recipe_paths:
		var recipe: AreaRecipe = _load_recipe(recipe_paths[id], true)
		if recipe == null or recipe.grow.is_empty():
			continue
		var worlds: Array = moved(recipe, recipe, range(1, MOVED_WORLDS + 1), old_table)
		if not worlds.is_empty():
			bumped[id] = {"moved": worlds, "version": recipe.version + 1}
	ConnectionTable.use(old_table)
	for id: String in bumped:
		var recipe: AreaRecipe = _load_recipe(recipe_paths[id], false)
		recipe.version = int(bumped[id]["version"])
		var e: Error = ResourceSaver.save(recipe, recipe.resource_path)
		if e != OK:
			return {"error": "cannot write %s (%s)" % [recipe.resource_path, error_string(e)]}
	var err: Error = ResourceSaver.save(table, ConnectionTable.PATH)
	ConnectionTable.drop_cache()
	if err != OK:
		return {"error": "cannot write %s (%s)" % [ConnectionTable.PATH, error_string(err)]}
	return {"saved": ConnectionTable.PATH, "bumped": bumped, "of": MOVED_WORLDS, "mtime": _mtime(ConnectionTable.PATH)}


## Why an edited description can't be saved ("" = it can).
static func _check(desc: Dictionary) -> String:
	var ids: Dictionary = {}
	var roots: int = 0
	for d: Dictionary in desc.get("slots", []):
		var id: String = str(d.get("slot_id", ""))
		if id == "" or ids.has(id):
			return "two rooms are called \"%s\"" % id if id != "" else "a room has no name"
		ids[id] = true
		if str(d.get("parent", "")) == "":
			roots += 1
		if str(d.get("kind", "")) == "scene" and (d.get("scenes", []) as Array).is_empty():
			return "%s has no scene" % id
		if str(d.get("kind", "")) != "scene" and not ResourceLoader.exists(str(d.get("grammar", ""))):
			return "%s has no grammar" % id
	if roots != 1:
		return "the area needs exactly one entrance (has %d)" % roots
	for d: Dictionary in desc.get("slots", []):
		var parent: String = str(d.get("parent", ""))
		if parent != "" and not ids.has(parent):
			return "%s joins %s, which isn't in the recipe" % [d["slot_id"], parent]
	var prefixes: Dictionary = {}
	for d: Dictionary in desc.get("grow", []):
		var pre: String = str(d.get("prefix", ""))
		if pre == "" or prefixes.has(pre) or ids.has(pre):
			return "two rules or rooms are called \"%s\"" % pre if pre != "" else "a grow rule has no name"
		prefixes[pre] = true
		var c: Array = d.get("count", [0, 0])
		if int(c[0]) < 0 or int(c[1]) < int(c[0]):
			return "%s: count %d-%d" % [pre, int(c[0]), int(c[1])]
	return ""


static func _table(rules: Dictionary) -> ConnectionTable:
	var t := ConnectionTable.new()
	for k: String in rules:
		if str(rules[k]) in [ConnectionTable.PREFERRED, ConnectionTable.NEVER]:
			t.rules[k] = str(rules[k])
	return t


static func _mtime(path: String) -> int:
	return FileAccess.get_modified_time(path) if FileAccess.file_exists(path) else 0


## The stratum plan (StratumPlan, gen/strata/stratum_1.tres): [{id, name, kind
## (baked | scenery | recipe), recipe, y0, y1 (reserved height, m), drafts
## (its named copies), door (the Gorge door place it's reached by)}], links
## [[a, b, kind]], door_places [{id, bank, cliff, storey, width, area (the area
## whose door it is, or "")}].
static func stratum() -> Dictionary:
	var sp: StratumPlan = _stratum_plan()
	var places: Array = []
	for p: Dictionary in sp.places:
		var id: String = str(p["id"])
		var path: String = str(p["path"])
		if path.get_extension() != "tres":
			places.append({"id": id, "name": CAMP_NAME if id == "camp" else id, "kind": "baked", "recipe": path,
				"y0": SeamlessPlaces.CAMP_BOUNDS.position.y, "y1": SeamlessPlaces.CAMP_BOUNDS.end.y})
			continue
		var recipe: AreaRecipe = _load_recipe(path, false)
		if recipe == null:
			places.append({"id": id, "name": id, "kind": "missing", "recipe": path, "y0": 0.0, "y1": 0.0})
			continue
		var env: AABB = recipe.placement.envelope if recipe.placement != null else AreaPlacement.new().envelope
		places.append({"id": id, "name": recipe.display_name, "kind": "scenery" if recipe.network != null else "recipe",
			"recipe": path, "y0": env.position.y, "y1": env.end.y, "drafts": drafts(id), "door": sp.door_slot(id) if id != "gorge" else ""})
	var door_places: Array = []
	var gorge: AreaRecipe = _load_recipe(sp.path_of("gorge"), false)
	if gorge != null and gorge.network != null:
		sp.apply_doors(gorge.network.frontage)
		for s: FrontageSlot in gorge.network.frontage.slots:
			if s != null and s.door_place:
				door_places.append({"id": s.id, "bank": s.bank, "cliff": s.cliff, "storey": s.storey(), "width": s.width, "area": s.door})
	return {"places": places, "links": sp.triples(), "door_places": door_places, "default_area": WORLD_STATE.DEFAULT_AREA,
		"mtime": _mtime(stratum_path), "path": stratum_path}


## The stratum plan read fresh from its file (a hand edit since), and the one
## the game code uses (StratumPlan.current) from now on in this process.
static func _stratum_plan() -> StratumPlan:
	var sp: StratumPlan = ResourceLoader.load(stratum_path, "", ResourceLoader.CACHE_MODE_IGNORE) as StratumPlan
	if sp == null:
		return StratumPlan.new()
	sp.take_over_path(stratum_path)
	StratumPlan.use(sp)
	return sp


## Adds an area called `area_name`, its recipe a copy of area `from`'s (a new
## file, version 1), behind the free Gorge door place `at` ("" = the first
## free one).
static func add_area(area_name: String, from: String, at: String) -> Dictionary:
	var sp: StratumPlan = _stratum_plan()
	var id: String = _slug(area_name.strip_edges().trim_prefix("The ").trim_prefix("the "))
	if id == "":
		return {"error": "an area needs a name with a letter or digit in it"}
	if sp.path_of(id) != "" or id in ["camp", "gorge"]:
		return {"error": "there is already an area called \"%s\"" % id}
	var src: String = str(sp.recipes().get(from, ""))
	var from_recipe: AreaRecipe = _load_recipe(src, false)
	if from_recipe == null or from_recipe.network != null:
		return {"error": "a new area starts as a copy of an interior's recipe (not %s)" % from}
	if at == "":
		at = _free_door(sp)
		if at == "":
			return {"error": "every Gorge door place has an area behind it"}
	var problem: String = _door_problem(sp, at, id)
	if problem != "":
		return {"error": problem}
	var path: String = "%s/%s.tres" % [recipes_dir, id]
	if FileAccess.file_exists(path):
		return {"error": "%s already exists" % path}
	var text: String = _set_resource_field(FileAccess.get_file_as_string(src), "id", "\"%s\"" % id)
	text = _set_resource_field(text, "display_name", JSON.stringify(area_name.strip_edges()))
	text = _set_resource_field(text, "version", "1")
	DirAccess.make_dir_recursive_absolute(recipes_dir)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return {"error": "cannot write %s (%s)" % [path, error_string(FileAccess.get_open_error())]}
	f.store_string(text)
	f.close()
	sp.places.append({"id": id, "path": path})
	sp.links.append({"a": "gorge", "b": id, "kind": StratumPlan.DOOR, "at": at})
	var out: Dictionary = _write_stratum(sp, true)
	out["added"] = id
	out["recipe_path"] = path
	return out


## Moves area `id`'s Gorge door to the free door place `at`.
static func set_door(id: String, at: String) -> Dictionary:
	var sp: StratumPlan = _stratum_plan()
	if sp.path_of(id) == "" or id in ["camp", "gorge"]:
		return {"error": "no area %s to give a door" % id}
	var problem: String = _door_problem(sp, at, id)
	if problem != "":
		return {"error": problem}
	var found: bool = false
	for l: Dictionary in sp.links:
		if str(l["kind"]) == StratumPlan.DOOR and (str(l["b"]) == id or str(l["a"]) == id):
			l["at"] = at
			found = true
	if not found:
		sp.links.append({"a": "gorge", "b": id, "kind": StratumPlan.DOOR, "at": at})
	return _write_stratum(sp, true)


## Takes area `id` out of the stratum (its links too). Its recipe file stays.
static func remove_area(id: String) -> Dictionary:
	if id in ["camp", "gorge"]:
		return {"error": "the %s can't be removed" % id}
	var sp: StratumPlan = _stratum_plan()
	if sp.path_of(id) == "":
		return {"error": "no area %s" % id}
	var had_door: bool = sp.door_slot(id) != ""
	sp.places = sp.places.filter(func(p: Dictionary) -> bool: return str(p["id"]) != id)
	sp.links = sp.links.filter(func(l: Dictionary) -> bool: return str(l["a"]) != id and str(l["b"]) != id)
	return _write_stratum(sp, had_door)


## Why area `id` can't have its door at `at` ("" = it can).
static func _door_problem(sp: StratumPlan, at: String, id: String) -> String:
	var gorge: AreaRecipe = _load_recipe(sp.path_of("gorge"), false)
	var slot: FrontageSlot = gorge.network.frontage.slot(at) if gorge != null and gorge.network != null else null
	if slot == null:
		return "no Gorge frontage slot %s" % at
	if not slot.door_place:
		return "%s isn't a door place (the Gorge's bake keeps only door places clear)" % at
	for l: Dictionary in sp.links:
		if str(l["kind"]) == StratumPlan.DOOR and str(l.get("at", "")) == at and str(l["b"]) != id and str(l["a"]) != id:
			return "%s is %s's door" % [at, l["b"] if str(l["a"]) == "gorge" else l["a"]]
	return ""


static func _free_door(sp: StratumPlan) -> String:
	var gorge: AreaRecipe = _load_recipe(sp.path_of("gorge"), false)
	if gorge == null or gorge.network == null:
		return ""
	for s: FrontageSlot in gorge.network.frontage.slots:
		if s != null and s.door_place and _door_problem(sp, s.id, "") == "":
			return s.id
	return ""


## Writes the stratum plan. A change to the Gorge's doors changes where its
## walkways run in every world (a door pulls a ledge to it), so the Gorge's
## version goes up.
static func _write_stratum(sp: StratumPlan, doors_changed: bool) -> Dictionary:
	var err: Error = ResourceSaver.save(sp, stratum_path)
	if err != OK:
		return {"error": "cannot write %s (%s)" % [stratum_path, error_string(err)]}
	sp.take_over_path(stratum_path)
	StratumPlan.use(sp)
	var gorge_change: Array = []
	var gorge_path: String = str(live_paths.get("gorge", sp.path_of("gorge")))
	if doors_changed:
		var text: String = FileAccess.get_file_as_string(gorge_path)
		var was: int = maxi(_resource_field(text, "version").to_int(), 1)
		var f := FileAccess.open(gorge_path, FileAccess.WRITE)
		if f != null:
			f.store_string(_set_resource_field(text, "version", str(was + 1)))
			f.close()
			gorge_change = [was, was + 1]
	var out: Dictionary = stratum()
	out["saved"] = stratum_path
	out["gorge_version"] = gorge_change
	out["gorge_path"] = gorge_path
	return out


## A field's value text in a .tres file's [resource] section ("" = not set).
static func _resource_field(text: String, key: String) -> String:
	var at: int = text.find("\n[resource]\n")
	if at < 0:
		return ""
	for line: String in text.substr(at).split("\n"):
		if line.begins_with(key + " = "):
			return line.trim_prefix(key + " = ")
	return ""


## The .tres text with `key = value` set in its [resource] section (added
## after `script = ...` if missing).
static func _set_resource_field(text: String, key: String, value: String) -> String:
	var at: int = text.find("\n[resource]\n")
	if at < 0:
		return text
	var head: String = text.substr(0, at)
	var lines: PackedStringArray = text.substr(at).split("\n")
	for i: int in lines.size():
		if lines[i].begins_with(key + " = "):
			lines[i] = "%s = %s" % [key, value]
			return head + "\n".join(lines)
	for i: int in lines.size():
		if lines[i].begins_with("script = "):
			lines.insert(i + 1, "%s = %s" % [key, value])
			break
	return head + "\n".join(lines)


static func _slug(s: String) -> String:
	var re := RegEx.create_from_string("[^a-z0-9]+")
	return re.sub(s.strip_edges().to_lower(), "_", true).trim_prefix("_").trim_suffix("_")


## The stratum from above for world seed `world_seed`: the Gorge's plan and
## each interior's, the interiors placed by their doors as the game places
## them (SeamlessPlaces._interior_frame), in the Gorge's frame (m). Each area's
## floor cells as quads [x0, z0, ... x3, z3, floor y]; overlaps between two
## interiors' cells (any storey). The Gorge plans in about 5 s.
static func layout(world_seed: int) -> Dictionary:
	var sp: StratumPlan = _stratum_plan()
	var gorge: AreaRecipe = _load_recipe(sp.path_of("gorge"), false)
	var gp: AreaPlan = AreaPlanner.plan(gorge, AreaPlanner.area_seed_for(gorge, world_seed))
	var areas: Array = [{"id": "gorge", "name": gorge.display_name, "quads": _quads(gp, Transform3D()), "error": ""}]
	var placed: Dictionary = {}     # id -> [plan, frame]
	var recipe_paths: Dictionary = sp.recipes()
	for id: String in recipe_paths:
		if id == "gorge":
			continue
		var recipe: AreaRecipe = _load_recipe(recipe_paths[id], false)
		if recipe == null:
			continue
		var ip: AreaPlan = AreaPlanner.plan(recipe, AreaPlanner.area_seed_for(recipe, world_seed))
		if gp.threshold(id).is_empty() or ip.threshold("gorge").is_empty():
			areas.append({"id": id, "name": recipe.display_name, "quads": [],
				"error": "no door to it from the Gorge in this world" if gp.threshold(id).is_empty() else "no door back to the Gorge"})
			continue
		var frame: Transform3D = SeamlessPlaces._interior_frame(gp, ip, id)
		placed[id] = [ip, frame]
		var door: Vector3 = SeamlessPlaces._door_xf(gp, id).origin
		areas.append({"id": id, "name": recipe.display_name, "quads": _quads(ip, frame), "door": [door.x, door.z], "error": ""})
	var overlaps: Array = []
	var ids: Array = placed.keys()
	for i: int in ids.size():
		for j: int in range(i + 1, ids.size()):
			var n: int = _shared_cells(placed[ids[i]], placed[ids[j]])
			if n > 0:
				overlaps.append({"a": ids[i], "b": ids[j], "cells": n})
	var camp: AABB = SeamlessPlaces.CAMP_BOUNDS
	return {"world_seed": world_seed, "areas": areas, "overlaps": overlaps,
		"camp": [camp.position.x, camp.position.z, camp.end.x, camp.end.z]}


static func _quads(p: AreaPlan, frame: Transform3D) -> Array:
	var out: Array = []
	for r: AreaPlan.Room in p.rooms:
		for c: Vector3i in r.floor_cells:
			var b: AABB = AreaPlan.cell_box(c)
			var q: Array = []
			for k: Vector3 in [b.position, b.position + Vector3(b.size.x, 0, 0), b.position + Vector3(b.size.x, 0, b.size.z), b.position + Vector3(0, 0, b.size.z)]:
				var w: Vector3 = frame * k
				q.append_array([w.x, w.z])
			q.append((frame * b.position).y)
			out.append(q)
	return out


## How many of plan a's cells (any storey) have their middle inside one of
## plan b's ([plan, frame] each).
static func _shared_cells(a: Array, b: Array) -> int:
	var to_b: Transform3D = (b[1] as Transform3D).affine_inverse() * (a[1] as Transform3D)
	var b_cells: Dictionary = {}
	for r: AreaPlan.Room in (b[0] as AreaPlan).rooms:
		b_cells.merge(r.cells)
	var n: int = 0
	for r: AreaPlan.Room in (a[0] as AreaPlan).rooms:
		for c: Vector3i in r.cells:
			if b_cells.has(AreaPlan.cell_of(to_b * AreaPlan.cell_box(c).get_center())):
				n += 1
	return n


## A recipe as the board draws it.
static func describe(recipe: AreaRecipe) -> Dictionary:
	var env: AABB = recipe.placement.envelope if recipe.placement != null else AreaPlacement.new().envelope
	var out: Dictionary = {"id": recipe.id, "display_name": recipe.display_name, "path": recipe.resource_path,
		"mtime": _mtime(recipe.resource_path), "version": recipe.version, "room_count": [recipe.room_count.x, recipe.room_count.y], "max_dead_ends": recipe.max_dead_ends,
		"max_sight_depth": recipe.max_sight_depth, "envelope": [env.position.x, env.position.y, env.position.z, env.size.x, env.size.y, env.size.z],
		"open_sight": recipe.open_sight, "network": recipe.network != null, "slots": [], "grow": []}
	for s: AreaSlot in recipe.slots:
		if s == null:
			continue
		var scenes: Array = []
		for scene: PackedScene in s.scene_choices if not s.scene_choices.is_empty() else ([s.scene] if s.scene != null else []):
			scenes.append(scene.resource_path)
		var kind: String = "scene" if not scenes.is_empty() else ("span" if s.grammar is ChasmGrammar else "generated")
		var type: String = RoomTypes.of_path(scenes[0] if not scenes.is_empty() else (s.grammar.resource_path if s.grammar != null else ""))
		var thresholds: Dictionary = {}
		for k: StringName in s.thresholds:
			thresholds[String(k)] = str(s.thresholds[k])
		(out["slots"] as Array).append({"slot_id": s.slot_id, "display_name": s.display_name, "kind": kind, "type": type,
			"type_name": RoomTypes.NAMES.get(type, ""), "scenes": scenes, "grammar": s.grammar.resource_path if s.grammar != null else "",
			"parent": s.parent, "connector": String(s.connector), "seed_mode": "fixed" if s.seed_mode == AreaSlot.SeedMode.FIXED else "area",
			"orig": s.slot_id, "weights": Array(s.scene_weights), "pinned_choice": s.pinned_choice,
			"fixed_seed": s.fixed_seed, "pinned": s.pinned, "thresholds": thresholds,
			# Q6: a scene with no SNAP_entry can only be the area's entrance (its root).
			"entrance_only": kind == "scene" and scenes.all(func(p: String) -> bool: return not _has_entry(p))})
	for i: int in recipe.grow.size():
		var g: AreaGrow = recipe.grow[i]
		if g == null:
			continue
		var type: String = RoomTypes.of_path(g.grammar.resource_path if g.grammar != null else "")
		(out["grow"] as Array).append({"prefix": g.slot_prefix, "display_name": g.display_name, "type": type, "type_name": RoomTypes.NAMES.get(type, ""),
			"grammar": g.grammar.resource_path if g.grammar != null else "", "count": [g.count.x, g.count.y],
			"orig": g.slot_prefix, "min_depth": g.min_depth, "from": Array(g.from), "pinned": g.pinned, "order": i})
	return out


## The plan for world seed `world_seed`: what AreaPlanner makes of the recipe,
## and the same checks as the game (AreaPlan.check, as area_route_test's
## "the plan checks clean"). map_px > 0 adds the top-down map as a PNG.
static func plan(recipe: AreaRecipe, world_seed: int, map_px: int = 10) -> Dictionary:
	var area_seed: int = AreaPlanner.area_seed_for(recipe, world_seed)
	var p: AreaPlan = AreaPlanner.plan(recipe, area_seed)
	var problems: PackedStringArray = p.check()
	var prefixes: PackedStringArray = []
	for g: AreaGrow in recipe.grow:
		if g != null:
			prefixes.append(g.slot_prefix)
	var rooms: Array = []
	for r: AreaPlan.Room in p.rooms:
		var lo := Vector2i(1 << 30, 1 << 30)
		var hi := Vector2i(-(1 << 30), -(1 << 30))
		for c: Vector3i in r.floor_cells:
			lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.z))
			hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.z))
		var connectors: Array = []
		var names: Array = r.connectors.keys()
		names.sort()
		for name: StringName in names:
			var k: Dictionary = r.connectors[name]
			connectors.append({"name": String(name), "joined": str(k["joined"]), "cap": str(k["cap"]), "to": str(k.get("to", "")),
				"storey": int(k["storey"])})
		var prefix: String = ""     # the grow rule that made it (<prefix>_<n>)
		for pre: String in prefixes:
			if recipe.slot(r.slot_id) == null and r.slot_id.begins_with(pre + "_") and r.slot_id.trim_prefix(pre + "_").is_valid_int():
				prefix = pre
		rooms.append({"slot_id": r.slot_id, "display_name": r.display_name, "kind": r.kind, "parent": r.parent,
			"parent_connector": String(r.parent_connector), "entry": String(r.entry), "storey": r.storey, "depth": r.depth,
			"seed": r.seed_value, "room_key": "%s@%d" % [r.slot_id, r.seed_value], "end_kind": r.end_kind,
			"scene": r.scene.resource_path if r.scene != null else "", "grammar": r.grammar.resource_path if r.grammar != null else "",
			"type": RoomTypes.of_path(r.scene.resource_path if r.scene != null else (r.grammar.resource_path if r.grammar != null else "")),
			"grow": prefix, "required": recipe.slot(r.slot_id) != null, "cells": r.floor_cells.size(),
			"bays": maxi(hi.x - lo.x, hi.y - lo.y) + 1 if not r.floor_cells.is_empty() else 1, "connectors": connectors,
			"floor": r.floor_cells.keys().map(func(c: Vector3i) -> Array: return [c.x, c.y, c.z])})
	# Doorways between rooms, for the top-down map: [x, z] in cells (z north).
	var doors: Array = []
	for e: Dictionary in p.edges:
		var at: Vector3 = (p.room(e["a"]).connectors[e["a_conn"]]["xf"] as Transform3D).origin
		doors.append([at.x / AreaPlan.BAY, -at.z / AreaPlan.BAY])
	var out: Dictionary = {"area_id": recipe.id, "world_seed": world_seed, "area_seed": area_seed, "rooms": rooms,
		"problems": Array(problems), "valid": problems.is_empty(), "stats": _json_safe(p.stats), "plan_ms": p.plan_ms,
		"signature": p.signature().sha256_text(), "doors": doors}
	if map_px > 0 and not p.rooms.is_empty():
		out["map_png"] = Marshalls.raw_to_base64(p.draw_map(map_px).save_png_to_buffer())
	return out


static func _load_recipe(path: String, fresh: bool) -> AreaRecipe:
	if path == "" or not ResourceLoader.exists(path):
		return null
	# Fresh: re-read from disk (a hand edit since), and that copy is the cached
	# one from now on; its grammars and scenes stay cached. (Replacing in the
	# cache would try to reload the recipe's scripts.)
	if not fresh:
		return load(path) as AreaRecipe
	var r: AreaRecipe = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as AreaRecipe
	if r != null:
		r.take_over_path(path)
	return r


static func _has_entry(scene_path: String) -> bool:
	var state: SceneState = (load(scene_path) as PackedScene).get_state()
	for i: int in state.get_node_count():
		if state.get_node_name(i) == &"SNAP_entry" and String(state.get_node_path(i, true)).ends_with("Connectors"):
			return true
	return false


## Vector2i and the like as arrays, so the answer survives JSON.
static func _json_safe(v: Variant) -> Variant:
	if v is Dictionary:
		var out: Dictionary = {}
		for k: Variant in v:
			out[str(k)] = _json_safe(v[k])
		return out
	if v is Array:
		return (v as Array).map(func(x: Variant) -> Variant: return _json_safe(x))
	if v is Vector2i or v is Vector3i or v is Vector2 or v is Vector3:
		return str(v)
	return v

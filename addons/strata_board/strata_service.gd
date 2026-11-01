extends RefCounted
## The game side of the Strata Board (phase 10): describes the stratum and an
## area's recipe, and plans a recipe for a seed with the game's own
## AreaPlanner, all as plain data (JSON-safe dictionaries) for the board.
##
## The editor can't run the planner itself: the grammars and RoomTemplate are
## not @tool scripts, so in the editor they load as placeholders. The board
## runs this in its own headless process (service_main.gd) and talks to it
## over a pipe; tests call handle() directly.

## Room types by the grammar or scene file name they're made from
## (design/room-atlas.html).
const TYPE_BY_FILE: Dictionary = {"r02": "R02", "r03": "R03", "r05": "R05", "r09": "R09", "r10": "R10", "r11": "R11",
	"reading_room": "R01", "stack_gallery": "R02", "caravanserai": "R05", "overlook": "R10"}
const TYPE_NAMES: Dictionary = {"R01": "Reading Room", "R02": "Stack gallery", "R03": "Hypostyle hall", "R05": "Caravanserai",
	"R09": "Light-well stair", "R10": "Chasm span", "R11": "Cistern"}
## The places that aren't areas (no recipe).
const CAMP_NAME: String = "The Reading Garden camp"
## By path: an autoload's name isn't known while a --script compiles.
const WORLD_STATE: GDScript = preload("res://scripts/world/world_state.gd")


## One request: {cmd: "stratum" | "recipe" | "plan", ...}. Returns the answer,
## or {error: why}.
static func handle(req: Dictionary) -> Dictionary:
	match str(req.get("cmd", "")):
		"stratum":
			return stratum()
		"recipe":
			var recipe: AreaRecipe = _load_recipe(str(req.get("path", "")), bool(req.get("fresh", false)))
			return describe(recipe) if recipe != null else {"error": "no recipe at %s" % req.get("path", "")}
		"plan":
			var recipe: AreaRecipe = _load_recipe(str(req.get("path", "")), false)
			if recipe == null:
				return {"error": "no recipe at %s" % req.get("path", "")}
			return plan(recipe, int(req.get("world_seed", 1)), int(req.get("map_px", 10)))
	return {"error": "unknown request %s" % req.get("cmd", "")}


## The places and the links between them (today SeamlessPlaces' tables; step 3
## moves them to a data file): [{id, name, kind (baked | scenery | recipe),
## recipe, y0, y1 (reserved height, m)}], links [[a, b, kind]].
static func stratum() -> Dictionary:
	var places: Array = [{"id": "camp", "name": CAMP_NAME, "kind": "baked", "recipe": SeamlessPlaces.KIT_CAMP,
		"y0": SeamlessPlaces.CAMP_BOUNDS.position.y, "y1": SeamlessPlaces.CAMP_BOUNDS.end.y}]
	for id: String in SeamlessPlaces.RECIPES:
		var recipe: AreaRecipe = load(SeamlessPlaces.RECIPES[id])
		var env: AABB = recipe.placement.envelope if recipe.placement != null else AreaPlacement.new().envelope
		places.append({"id": id, "name": recipe.display_name, "kind": "scenery" if recipe.network != null else "recipe",
			"recipe": SeamlessPlaces.RECIPES[id], "y0": env.position.y, "y1": env.end.y})
	return {"places": places, "links": SeamlessPlaces.LINKS.duplicate(true), "default_area": WORLD_STATE.DEFAULT_AREA}


## A recipe as the board draws it.
static func describe(recipe: AreaRecipe) -> Dictionary:
	var env: AABB = recipe.placement.envelope if recipe.placement != null else AreaPlacement.new().envelope
	var out: Dictionary = {"id": recipe.id, "display_name": recipe.display_name, "path": recipe.resource_path,
		"version": recipe.version, "room_count": [recipe.room_count.x, recipe.room_count.y], "max_dead_ends": recipe.max_dead_ends,
		"max_sight_depth": recipe.max_sight_depth, "envelope": [env.position.x, env.position.y, env.position.z, env.size.x, env.size.y, env.size.z],
		"open_sight": recipe.open_sight, "network": recipe.network != null, "slots": [], "grow": []}
	for s: AreaSlot in recipe.slots:
		if s == null:
			continue
		var scenes: Array = []
		for scene: PackedScene in s.scene_choices if not s.scene_choices.is_empty() else ([s.scene] if s.scene != null else []):
			scenes.append(scene.resource_path)
		var kind: String = "scene" if not scenes.is_empty() else ("span" if s.grammar is ChasmGrammar else "generated")
		var type: String = _type_of(scenes[0] if not scenes.is_empty() else (s.grammar.resource_path if s.grammar != null else ""))
		var thresholds: Dictionary = {}
		for k: StringName in s.thresholds:
			thresholds[String(k)] = str(s.thresholds[k])
		(out["slots"] as Array).append({"slot_id": s.slot_id, "display_name": s.display_name, "kind": kind, "type": type,
			"type_name": TYPE_NAMES.get(type, ""), "scenes": scenes, "grammar": s.grammar.resource_path if s.grammar != null else "",
			"parent": s.parent, "connector": String(s.connector), "seed_mode": "fixed" if s.seed_mode == AreaSlot.SeedMode.FIXED else "area",
			"fixed_seed": s.fixed_seed, "pinned": s.pinned, "thresholds": thresholds,
			# Q6: a scene with no SNAP_entry can only be the area's entrance (its root).
			"entrance_only": kind == "scene" and scenes.all(func(p: String) -> bool: return not _has_entry(p))})
	for i: int in recipe.grow.size():
		var g: AreaGrow = recipe.grow[i]
		if g == null:
			continue
		var type: String = _type_of(g.grammar.resource_path if g.grammar != null else "")
		(out["grow"] as Array).append({"prefix": g.slot_prefix, "display_name": g.display_name, "type": type, "type_name": TYPE_NAMES.get(type, ""),
			"grammar": g.grammar.resource_path if g.grammar != null else "", "count": [g.count.x, g.count.y],
			"from": Array(g.from), "pinned": g.pinned, "order": i})
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
			"type": _type_of(r.scene.resource_path if r.scene != null else (r.grammar.resource_path if r.grammar != null else "")),
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
	# Fresh: re-read from disk (a hand edit since); its grammars and scenes stay cached.
	return ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE if fresh else ResourceLoader.CACHE_MODE_REUSE) as AreaRecipe


static func _type_of(path: String) -> String:
	var file: String = path.get_file().get_basename()
	for k: String in TYPE_BY_FILE:
		if file.begins_with(k):
			return TYPE_BY_FILE[k]
	return ""


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

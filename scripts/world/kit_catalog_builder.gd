@tool
class_name KitCatalogBuilder
extends RefCounted
## Creates or updates one wrapper scene per imported module and rebuilds
## kit/catalog.tres. Used by tools/kit_catalog.gd (headless) and the Kit dock's
## Refresh button. Existing wrapper scenes keep every node you added; only the
## KitModule fields and the .glb child are refreshed.

const KIT_DIR: String = "res://assets/kit/"
const MODULE_DIR: String = "res://kit/modules/"
const CATALOG_PATH: String = "res://kit/catalog.tres"
const KitModuleScript: Script = preload("res://scripts/world/kit_module.gd")

var log_lines: PackedStringArray = []


func build() -> KitCatalog:
	log_lines.clear()
	var catalog := KitCatalog.new()
	for glb: String in _find_glbs(KIT_DIR):
		var entry: Dictionary = _wrap(glb)
		if not entry.is_empty():
			catalog.modules.append(entry)
	catalog.modules.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a["family"]) + str(a["name"]) < str(b["family"]) + str(b["name"]))
	DirAccess.make_dir_recursive_absolute(CATALOG_PATH.get_base_dir())
	# Only rewrite the catalog when its contents change, and keep its UID when it does.
	var err: Error = OK
	var old: KitCatalog = ResourceLoader.load(CATALOG_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as KitCatalog if ResourceLoader.exists(CATALOG_PATH) else null
	if old == null or var_to_str(old.modules) != var_to_str(catalog.modules):
		var uid: int = _header_uid(CATALOG_PATH) if old != null else ResourceUID.INVALID_ID
		err = ResourceSaver.save(catalog, CATALOG_PATH)
		if err == OK and uid != ResourceUID.INVALID_ID:
			ResourceSaver.set_uid(CATALOG_PATH, uid)
	if err != OK:
		log_lines.append("ERROR saving catalog: %s" % error_string(err))
	log_lines.append("catalog: %d modules" % catalog.modules.size())
	return catalog


func _find_glbs(dir: String) -> PackedStringArray:
	var out: PackedStringArray = []
	var da := DirAccess.open(dir)
	if da == null:
		return out
	for sub: String in da.get_directories():
		out.append_array(_find_glbs(dir.path_join(sub)))
	for f: String in da.get_files():
		if f.get_extension() == "glb":
			out.append(dir.path_join(f))
	return out


func _wrap(glb_path: String) -> Dictionary:
	var packed: PackedScene = load(glb_path)
	if packed == null:
		log_lines.append("ERROR: cannot load %s (import it first)" % glb_path)
		return {}
	var probe: Node = packed.instantiate()
	var kit: Dictionary = probe.get_meta("kit", {})
	var warnings: PackedStringArray = probe.get_meta("kit_warnings", PackedStringArray())
	probe.free()
	if kit.is_empty():
		log_lines.append("ERROR: %s has no kit meta (was it imported with tools/kit_import.gd?)" % glb_path)
		return {}
	var family: String = kit["family"]
	var module_name: String = kit["name"]
	var scene_path: String = MODULE_DIR.path_join(family).path_join(module_name + ".tscn")
	var root: KitModule
	var created: bool = false
	if ResourceLoader.exists(scene_path):
		var existing: Node = (load(scene_path) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
		root = existing as KitModule
		if root == null:
			existing.free()
			log_lines.append("ERROR: %s root is not a KitModule; left untouched" % scene_path)
			return {}
	else:
		root = KitModuleScript.new()
		root.name = module_name
		created = true
	var before: Array = [root.shape, root.family, root.size_cells, root.edge, root.tags, root.source_glb]
	root.shape = KitModule.shape_from_string(kit["shape"])
	root.family = family
	root.size_cells = kit["size_cells"]
	root.edge = kit["edge"]
	root.tags = kit["tags"]
	root.source_glb = glb_path
	var changed: bool = created or before != [root.shape, root.family, root.size_cells, root.edge, root.tags, root.source_glb]
	if created:
		root.weight = kit["weight"]   # after creation the Inspector value wins
	var mesh_node: Node = root.get_node_or_null("Mesh")
	if mesh_node == null or mesh_node.scene_file_path != glb_path:
		changed = true
		if mesh_node != null:
			root.remove_child(mesh_node)
			mesh_node.free()
		mesh_node = packed.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
		mesh_node.name = "Mesh"
		root.add_child(mesh_node)
		root.move_child(mesh_node, 0)
		mesh_node.owner = root
	# Unchanged wrappers are not re-saved, so the editor's UIDs and your edits
	# don't churn on every export. Changed ones keep their existing UID.
	var err: Error = OK
	if changed:
		var uid: int = ResourceLoader.get_resource_uid(scene_path) if not created else ResourceUID.INVALID_ID
		var out := PackedScene.new()
		err = out.pack(root)
		if err == OK:
			DirAccess.make_dir_recursive_absolute(scene_path.get_base_dir())
			err = ResourceSaver.save(out, scene_path)
		if err == OK and uid != ResourceUID.INVALID_ID:
			ResourceSaver.set_uid(scene_path, uid)
	root.free()
	if err != OK:
		log_lines.append("ERROR saving %s: %s" % [scene_path, error_string(err)])
		return {}
	log_lines.append("%s %s%s" % ["created" if created else ("updated" if changed else "unchanged"), scene_path,
		("  WARN: " + "; ".join(warnings)) if not warnings.is_empty() else ""])
	return {
		"name": module_name, "scene": scene_path, "family": family, "shape": kit["shape"],
		"size_cells": kit["size_cells"], "edge": kit["edge"], "tags": kit["tags"], "weight": kit["weight"],
	}


## UID from a text resource's header. ResourceLoader.get_resource_uid returns
## -1 for .tres files in headless --script runs (the UID cache isn't loaded).
static func _header_uid(path: String) -> int:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ResourceUID.INVALID_ID
	var m: RegExMatch = RegEx.create_from_string("uid=\"(uid://[a-z0-9]+)\"").search(f.get_line())
	return ResourceUID.text_to_id(m.get_string(1)) if m != null else ResourceUID.INVALID_ID

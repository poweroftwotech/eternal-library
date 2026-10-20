class_name RoomBaker
extends RefCounted
## Bake to scene (ENVIRONMENT_PLAN.md 5.5.10): writes a GeneratedRoom's live
## build as a plain RoomTemplate scene of owned kit module instances, which
## resolves to the same picks and can be finished by hand in the editor.
##
## The root keeps the generated node's name, room_id, seed (as preview_seed)
## and transform relative to its parent, so instanced under the host in its
## place it lands on the join. Grammar pins become socket_pins (the room's own
## pins win) and inherited style groups become style_pins.


## rooms/baked/<room_id>_<seed>.tscn
static func default_path(room: GeneratedRoom) -> String:
	return "res://rooms/baked/%s_%d.tscn" % [_room_id(room), room.effective_seed()]


## Saves the baked room to `path`.
static func bake(room: GeneratedRoom, path: String) -> Error:
	if room.grid == null or room.modules.is_empty():
		push_error("RoomBaker: %s has no build to bake (generate first)" % room.name)
		return ERR_UNCONFIGURED
	var baked: RoomTemplate = build(room)
	var scene := PackedScene.new()
	var err: Error = scene.pack(baked)
	baked.free()
	if err != OK:
		return err
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	return ResourceSaver.save(scene, path)


## The baked room as an unsaved node tree (every node owned by the root).
static func build(room: GeneratedRoom) -> RoomTemplate:
	var out := RoomTemplate.new()
	out.name = room.name
	out.room_id = _room_id(room)
	out.display_name = room.display_name
	out.preview_seed = room.effective_seed()
	out.transform = room.transform
	var pins: Dictionary[String, int] = {}
	for key: String in room.generated_pins:
		pins[key] = int(room.generated_pins[key])
	for key: String in room.socket_pins:
		pins[key] = room.socket_pins[key]
	out.socket_pins = pins
	var styles: Dictionary[String, int] = {}
	for group: String in room.style_overrides:
		styles[group] = int(room.style_overrides[group])
	for group: String in room.style_pins:
		styles[group] = room.style_pins[group]
	out.style_pins = styles
	out.set_meta("baked_from", {
		"grammar": room.grammar.resource_path if room.grammar != null else "",
		"rules": room.rules.resource_path if room.rules != null else "",
		"seed": room.effective_seed(),
		"modules": room.modules.size(),
	})
	for child: Node in room.get_children():
		_copy(child, out, out)
	return out


## Writes `<path minus .tscn>_in_host.tscn`: the scene the generated room was
## placed in, with the generated node swapped for the baked one. Needs the
## host scene's root to be an instance (reading_room_r02.tscn inherits
## reading_room.tscn). Returns the path written, or "".
static func write_host_scene(room: GeneratedRoom, host_scene: String, baked_path: String) -> String:
	var host: RoomTemplate = room.host_room()
	var packed := load(host_scene) as PackedScene
	if host == null or packed == null or packed.get_state().get_node_instance(0) == null:
		push_warning("RoomBaker: %s has no inherited host scene; skipping the host scene" % room.name)
		return ""
	var base: String = packed.get_state().get_node_instance(0).resource_path
	var out: String = baked_path.get_basename() + "_in_host.tscn"
	var text: String = "\n".join([
		"[gd_scene format=3]",
		"",
		"[ext_resource type=\"PackedScene\" path=\"%s\" id=\"1_host\"]" % base,
		"[ext_resource type=\"PackedScene\" path=\"%s\" id=\"2_baked\"]" % baked_path,
		"",
		"[node name=\"%s\" instance=ExtResource(\"1_host\")]" % host.name,
		"",
		"[node name=\"%s\" parent=\"%s\" instance=ExtResource(\"2_baked\")]" % [room.name, host.get_path_to(room.get_parent())],
		"",
	])
	var f := FileAccess.open(out, FileAccess.WRITE)
	if f == null:
		return ""
	f.store_string(text)
	f.close()
	return out


## Copies `node` under `parent`: a module (any node from a scene file) is
## re-instantiated from its scene, a holder of modules is rebuilt around its
## copied children, and anything else is duplicated whole. Overlay and socket
## spawns are internal, so they never come along.
static func _copy(node: Node, parent: Node, root: Node) -> void:
	var copy: Node
	if node.scene_file_path != "":
		copy = (load(node.scene_file_path) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
		copy.name = node.name
		if node is Node3D:
			(copy as Node3D).transform = (node as Node3D).transform
		parent.add_child(copy)
		copy.owner = root
		return
	if _holds_scenes(node):
		copy = Node3D.new() if node is Node3D else Node.new()
		copy.name = node.name
		if node is Node3D:
			(copy as Node3D).transform = (node as Node3D).transform
		parent.add_child(copy)
		copy.owner = root
		for child: Node in node.get_children():
			_copy(child, copy, root)
		return
	copy = node.duplicate(Node.DUPLICATE_SIGNALS | Node.DUPLICATE_GROUPS | Node.DUPLICATE_SCRIPTS)
	parent.add_child(copy)
	_own(copy, root)


static func _holds_scenes(node: Node) -> bool:
	for child: Node in node.get_children():
		if child.scene_file_path != "" or _holds_scenes(child):
			return true
	return false


static func _own(node: Node, root: Node) -> void:
	node.owner = root
	if node.has_meta("generated"):
		node.remove_meta("generated")
	for child: Node in node.get_children():
		_own(child, root)


static func _room_id(room: GeneratedRoom) -> String:
	return room.room_id if room.room_id != "" else String(room.name)

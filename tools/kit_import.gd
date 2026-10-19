@tool
extends EditorScenePostImport
## Post-import for kit modules (ENVIRONMENT_PLAN.md 3.3). Set as the default
## scene import script in project.godot [importer_defaults]; it ignores any
## scene outside res://assets/kit/.
##
## 1. Swaps every surface material for the shared PxMaterial by slot name.
## 2. Puts generated collision on layer 1 (world static).
## 3. Turns SNAP_/SOCKET_/LIGHT_/ANCHOR_ empties into Marker3D / lights.
## 4. Copies the module's Blender custom properties into meta "kit" on the root.

const KIT_DIR: String = "res://assets/kit/"
const LIGHT_PROFILES: Dictionary = {
	"lantern": {"color": Color(1.0, 0.71, 0.36), "energy": 1.3, "range": 6.0, "attenuation": 1.2, "shadow": false},
	"brazier": {"color": Color(1.0, 0.55, 0.25), "energy": 2.0, "range": 7.0, "attenuation": 1.0, "shadow": true},
	"cold": {"color": Color(0.66, 0.86, 1.0), "energy": 1.0, "range": 6.0, "attenuation": 1.2, "shadow": false},
}
const PREFIXES: Array[String] = ["SNAP_", "SOCKET_", "LIGHT_", "ANCHOR_"]

var _warnings: PackedStringArray = []


func _post_import(scene: Node) -> Object:
	var source: String = get_source_file()
	if not source.begins_with(KIT_DIR):
		return scene
	_warnings.clear()
	var module_root: Node = _find_module_root(scene)
	var extras: Dictionary = _extras(module_root)
	var kit: Dictionary = {
		"name": source.get_file().get_basename(),
		"source": source,
		"family": str(extras.get("kit_family", source.get_base_dir().get_file())),
		"shape": str(extras.get("kit_shape", "free")),
		"size_cells": _vec3i(extras.get("size_cells", [0, 0, 0])),
		"edge": str(extras.get("edge", "")),
		"tags": PackedStringArray(str(extras.get("tags", "")).split(",", false)),
		"weight": float(extras.get("weight", 1.0)),
	}
	scene.set_meta("kit", kit)
	var nodes: Array[Node] = []
	_collect(scene, nodes)
	var has_collision: bool = false
	for node: Node in nodes:
		if node is MeshInstance3D:
			_fix_materials(node as MeshInstance3D)
		elif node is StaticBody3D:
			var body := node as StaticBody3D
			body.collision_layer = 1
			body.collision_mask = 0
			has_collision = true
		if node is Node3D and not (node as Node3D).scale.is_equal_approx(Vector3.ONE):
			_warnings.append("%s has scale %s (modules must not be scaled)" % [node.name, (node as Node3D).scale])
	for node: Node in nodes:
		for prefix: String in PREFIXES:
			if String(node.name).begins_with(prefix):
				_convert_empty(node, prefix, scene)
				break
	if kit["shape"] in ["edge", "cell", "post"] and not has_collision:
		_warnings.append("structural module has no collision; name a mesh child '*-col' in Blender")
	for w: String in _warnings:
		push_warning("kit_import %s: %s" % [kit["name"], w])
	scene.set_meta("kit_warnings", _warnings.duplicate())
	return scene


func _collect(node: Node, out: Array[Node]) -> void:
	out.append(node)
	for child: Node in node.get_children():
		_collect(child, out)


## The exported glb has the M_* empty as the only child of the import root.
func _find_module_root(scene: Node) -> Node:
	for child: Node in scene.get_children():
		if String(child.name).begins_with("M_"):
			return child
	return scene


func _extras(node: Node) -> Dictionary:
	if node.has_meta("extras") and node.get_meta("extras") is Dictionary:
		return node.get_meta("extras")
	return {}


func _vec3i(value: Variant) -> Vector3i:
	if value is Array and (value as Array).size() >= 3:
		return Vector3i(int(value[0]), int(value[1]), int(value[2]))
	return Vector3i.ZERO


func _fix_materials(inst: MeshInstance3D) -> void:
	var mesh: Mesh = inst.mesh
	if mesh == null:
		return
	for i: int in mesh.get_surface_count():
		var current: Material = mesh.surface_get_material(i)
		var slot: String = current.resource_name if current != null else ""
		slot = _clean_name(slot)
		var lib: Material = PxMaterial.get_or_create(slot) if slot != "" else null
		if lib == null:
			_warnings.append("%s surface %d: no pixel material named '%s'" % [inst.name, i, slot])
			lib = PxMaterial.missing()
		mesh.surface_set_material(i, lib)
	if inst.get_surface_override_material_count() > 0:
		for i: int in inst.get_surface_override_material_count():
			inst.set_surface_override_material(i, null)
	if mesh.get_surface_count() > 0 and _clean_name(str(mesh.surface_get_material(0).resource_name)).begins_with("emit_"):
		inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Blender appends .001 to duplicate names; Godot may turn the dot into "_".
func _clean_name(raw: String) -> String:
	var result: String = raw
	var cut: int = result.find("__")
	if cut > 0:
		result = result.substr(0, cut)
	var rx := RegEx.create_from_string("[._]\\d{3}$")
	return rx.sub(result, "")


func _convert_empty(node: Node, prefix: String, scene: Node) -> void:
	var parent: Node = node.get_parent()
	if parent == null or not node is Node3D:
		return
	var kind: String = _clean_name(String(node.name).substr(prefix.length()))
	var extras: Dictionary = _extras(node)
	var replacement: Node3D
	match prefix:
		"LIGHT_":
			var profile: Dictionary = LIGHT_PROFILES.get(kind, LIGHT_PROFILES["lantern"])
			if not LIGHT_PROFILES.has(kind):
				_warnings.append("unknown light profile '%s', using lantern" % kind)
			var light := OmniLight3D.new()
			light.light_color = profile["color"]
			light.light_energy = profile["energy"]
			light.omni_range = profile["range"]
			light.omni_attenuation = profile["attenuation"]
			light.shadow_enabled = profile["shadow"]
			light.set_meta("light_profile", kind)
			replacement = light
		"SOCKET_":
			var socket := VariantSocket.new()
			var set_name: String = str(extras.get("socket_set", kind))
			var set_path: String = "res://kit/sockets/%s.tres" % set_name
			if ResourceLoader.exists(set_path):
				socket.socket_set = load(set_path)
			else:
				_warnings.append("socket %s: no socket set at %s" % [kind, set_path])
			replacement = socket
		_:
			replacement = Marker3D.new()
	replacement.name = prefix + kind
	replacement.transform = (node as Node3D).transform
	for key: Variant in extras:
		replacement.set_meta(StringName(str(key)), extras[key])
	replacement.set_meta("kit_kind", kind)
	var group: String = {"SNAP_": "kit_snap", "SOCKET_": "kit_socket", "LIGHT_": "kit_light", "ANCHOR_": "npc_anchor"}[prefix]
	parent.add_child(replacement, true)
	parent.move_child(replacement, node.get_index())
	replacement.owner = scene
	replacement.add_to_group(group, true)
	parent.remove_child(node)
	node.free()

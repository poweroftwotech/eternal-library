@tool
extends EditorScenePostImport
## Post-import for kit modules (ENVIRONMENT_PLAN.md 3.3). Set as the default
## scene import script in project.godot [importer_defaults]; it ignores any
## scene outside res://assets/kit/.
##
## 1. Swaps every surface material for the shared PxMaterial by slot name.
## 2. Puts generated collision on layer 1 (world static).
## 3. Turns SNAP_/SOCKET_/LIGHT_/ANCHOR_/CLAIM_ empties into Marker3D / lights.
##    CLAIM_ (polish slice A): a box, centred on the empty, whose size comes from
##    the Blender property claim_size [x, y, z]; stored as meta "claim_box"
##    (Godot axes). RoomTemplate clears other sockets' items inside it.
## 4. Copies the module's Blender custom properties into meta "kit" on the root.
## 5. Puts the meshes of edge, cell and post modules on KitModule.DECAL_LAYER too.

const KIT_DIR: String = "res://assets/kit/"
const LIGHT_PROFILES: Dictionary = {
	"lantern": {"color": Color(1.0, 0.71, 0.36), "energy": 1.3, "range": 6.0, "attenuation": 1.2, "shadow": false},
	"brazier": {"color": Color(1.0, 0.55, 0.25), "energy": 2.0, "range": 7.0, "attenuation": 1.0, "shadow": true},
	"chandelier": {"color": Color(1.0, 0.74, 0.42), "energy": 2.2, "range": 10.0, "attenuation": 1.0, "shadow": true, "size": 0.35},
	"cold": {"color": Color(0.66, 0.86, 1.0), "energy": 1.0, "range": 6.0, "attenuation": 1.2, "shadow": false},
	"cluster": {"color": Color(1.0, 0.72, 0.38), "energy": 2.0, "range": 8.5, "attenuation": 1.1, "shadow": false},
	# The light-well (phase 5 step 4): sunlight down the shaft from the oculus, a
	# spot pointing down whose beam shows in the volumetric fog, and soft fills
	# for the light it bounces round the cone. "far": they skip LightBudget's
	# distance fade (the oculus is 20 m and more over the floor). A marker's
	# Blender properties "range", "spot_angle" and "energy" override these.
	"shaft": {"color": Color(1.0, 0.95, 0.86), "energy": 8.0, "range": 30.0, "attenuation": 0.35, "shadow": false, "spot": 15.0, "spot_falloff": 2.0, "fog": 4.0, "far": true},
	"bounce": {"color": Color(0.84, 0.87, 0.92), "energy": 0.55, "range": 12.0, "attenuation": 0.8, "shadow": false, "fog": 0.0, "far": true},
}
const PREFIXES: Array[String] = ["SNAP_", "SOCKET_", "LIGHT_", "ANCHOR_", "CLAIM_", "FOG_"]
## Physics layer 8: walls only the player collides with (project layer names).
const PLAYER_BLOCKERS: int = 1 << 7

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
			if kit["shape"] in ["edge", "cell", "post"]:
				(node as MeshInstance3D).layers |= KitModule.DECAL_LAYER
		elif node is StaticBody3D:
			var body := node as StaticBody3D
			body.collision_layer = 1
			body.collision_mask = 0
			has_collision = true
			# Phase 5 step 3 (Q10): a "*wade_stop-colonly" mesh is a wall only the
			# player meets (deep water); a water module's floor slows the player.
			if String(body.name).contains("wade_stop") or String(body.get_parent().name).contains("wade_stop"):
				body.collision_layer = PLAYER_BLOCKERS
			elif (kit["tags"] as PackedStringArray).has("water"):
				body.set_meta("wade", true)
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
	var first: String = _clean_name(str(mesh.surface_get_material(0).resource_name)) if mesh.get_surface_count() > 0 else ""
	if first.begins_with("emit_") or first.ends_with("water"):     # glass and the water's surface cast no shadow
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
			var light: Light3D
			var reach: float = float(extras.get("range", profile["range"]))
			if profile.has("spot"):
				var spot := SpotLight3D.new()
				spot.spot_range = reach
				spot.spot_attenuation = profile["attenuation"]
				spot.spot_angle = float(extras.get("spot_angle", profile["spot"]))
				spot.spot_angle_attenuation = profile.get("spot_falloff", 1.0)     # >1: the pool of light fades faster to its edge
				light = spot
			else:
				var omni := OmniLight3D.new()
				omni.omni_range = reach
				omni.omni_attenuation = profile["attenuation"]
				light = omni
			light.light_color = profile["color"]
			light.light_energy = float(extras.get("energy", profile["energy"]))
			if profile.has("fog"):
				light.light_volumetric_fog_energy = profile["fog"]
			if profile.get("far", false):
				light.set_meta("light_far", true)
			light.shadow_enabled = profile["shadow"]
			# Soft source: frame posts close to the light would otherwise throw hard
			# metre-wide bands across a vault.
			light.light_size = profile.get("size", 0.0)
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
			# Optional Blender properties: socket_mode (replace|toggle|scatter|state|edge_scatter),
			# scatter_count [min, max], scatter_extent [half x, half depth], scatter_spacing,
			# edge_length, edge_depth, scatter_spin (0/1), settle (0/1), settle_max_drop, needs_look.
			var modes: Dictionary = {"replace": VariantSocket.Mode.REPLACE, "toggle": VariantSocket.Mode.TOGGLE,
				"scatter": VariantSocket.Mode.SCATTER, "state": VariantSocket.Mode.STATE,
				"edge_scatter": VariantSocket.Mode.EDGE_SCATTER}
			var mode_name: String = str(extras.get("socket_mode", "replace"))
			if not modes.has(mode_name):
				_warnings.append("socket %s: unknown socket_mode '%s'" % [kind, mode_name])
			socket.mode = modes.get(mode_name, VariantSocket.Mode.REPLACE)
			if extras.get("scatter_count") is Array:
				socket.scatter_count = Vector2i(int(extras["scatter_count"][0]), int(extras["scatter_count"][1]))
			if extras.get("scatter_extent") is Array:
				socket.scatter_extent = Vector2(float(extras["scatter_extent"][0]), float(extras["scatter_extent"][1]))
			for key: String in ["edge_length", "edge_depth", "settle_max_drop"]:
				if extras.has(key):
					socket.set(key, float(extras[key]))
			if extras.has("scatter_spin"):
				socket.scatter_spin = bool(int(extras["scatter_spin"]))
			if extras.has("settle"):
				socket.settle = bool(int(extras["settle"]))
			if extras.has("scatter_spacing"):
				socket.scatter_spacing = float(extras["scatter_spacing"])
			if extras.has("needs_look"):
				socket.needs_look = str(extras["needs_look"])
			replacement = socket
		"FOG_":
			# A FogVolume (a cylinder): Blender properties fog_size [x, y, z] and
			# density (the light-well's haze, so its shaft of light shows).
			var fog := FogVolume.new()
			fog.shape = RenderingServer.FOG_VOLUME_SHAPE_CYLINDER
			var fs: Array = extras.get("fog_size", [4.0, 4.0, 4.0])
			fog.size = Vector3(float(fs[0]), float(fs[2]), float(fs[1]))     # Blender y/z -> Godot z/y
			var fm := FogMaterial.new()
			fm.density = float(extras.get("density", 0.04))
			fm.albedo = Color(0.9, 0.92, 0.95)
			fog.material = fm
			replacement = fog
		_:
			replacement = Marker3D.new()
	replacement.name = prefix + kind
	replacement.transform = (node as Node3D).transform
	if replacement is SpotLight3D:
		replacement.transform.basis = replacement.transform.basis * Basis(Vector3.RIGHT, -PI / 2.0)     # the marker's down: -Z to -Y
	for key: Variant in extras:
		replacement.set_meta(StringName(str(key)), extras[key])
	replacement.set_meta("kit_kind", kind)
	if prefix == "CLAIM_" and extras.get("claim_size") is Array:
		var sz: Array = extras["claim_size"]
		replacement.set_meta("claim_box", Vector3(float(sz[0]), float(sz[2]), float(sz[1])))   # Blender y/z -> Godot z/y
	var group: String = {"SNAP_": "kit_snap", "SOCKET_": "kit_socket", "LIGHT_": "kit_light", "ANCHOR_": "npc_anchor", "CLAIM_": "kit_claim", "FOG_": "kit_fog"}[prefix]
	parent.add_child(replacement, true)
	parent.move_child(replacement, node.get_index())
	replacement.owner = scene
	replacement.add_to_group(group, true)
	parent.remove_child(node)
	node.free()

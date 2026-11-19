class_name ResidentsOverlay
extends Node3D
## The people's overlay (phase 21 step 3): F4, with the animals'. Drawn over
## the world, through walls:
##   - the rim of each room's walking surface (grey);
##   - every spot as a ring with a tick the way a body faces there, coloured
##     by kind, named, with who has it now;
##   - each walker's way still to go, and a red ring round whoever is waiting
##     for someone to move.

const COLOURS: Dictionary = {"sleep": Color(0.55, 0.6, 1.0), "cook": Color(1.0, 0.55, 0.2), "eat": Color(1.0, 0.85, 0.3), "sit": Color(0.6, 0.9, 0.5),
		"work": Color(0.9, 0.5, 0.9), "door": Color(0.85, 0.85, 0.85), "stand": Color(0.6, 0.6, 0.6), "water": Color(0.35, 0.7, 1.0),
		"bench": Color(0.4, 0.95, 0.8), "buy": Color(1.0, 0.7, 0.7), "keep": Color(1.0, 0.4, 0.4)}
const RIM := Color(0.75, 0.78, 0.8, 0.45)
const WAY := Color(1.0, 0.95, 0.4)
const WAIT := Color(1.0, 0.25, 0.2)
const SPOT_RADIUS: float = 0.16
## Spots' names are shown within this far of the camera.
const NAME_REACH: float = 14.0

var residents: Residents
var _fixed: MeshInstance3D
var _moving: MeshInstance3D
var _labels: Array[Label3D] = []
var _used: int = 0
var _points := PackedVector3Array()
var _colours := PackedColorArray()
var _seen: int = -1
var _legend: CanvasLayer


func _ready() -> void:
	top_level = true
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true
	mat.disable_fog = true
	for k: int in 2:
		var mi := MeshInstance3D.new()
		mi.mesh = ImmediateMesh.new()
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.extra_cull_margin = 16000.0
		add_child(mi)
		if k == 0:
			_fixed = mi
		else:
			_moving = mi
	_legend = CanvasLayer.new()
	_legend.layer = 61
	add_child(_legend)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	_legend.add_child(margin)
	var down := VBoxContainer.new()
	down.alignment = BoxContainer.ALIGNMENT_END
	down.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(down)
	var text := Label.new()
	text.text = "PEOPLE (F4): rings are spots, named with who has them. Yellow: a way being walked. Red ring: waiting for someone to move. Grey: where people can walk."
	text.add_theme_font_size_override("font_size", 14)
	text.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	text.add_theme_constant_override("outline_size", 6)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	down.add_child(text)


func set_on(on: bool) -> void:
	visible = on
	_legend.visible = on
	if on:
		_seen = -1


func _process(_delta: float) -> void:
	if not visible or residents == null:
		return
	# The fixed part: again whenever the homes change.
	var stamp: int = hash([residents.households.size(), residents.commons.size(), residents.settled()])
	if stamp != _seen:
		_seen = stamp
		_points.clear()
		_colours.clear()
		var rooms: Dictionary = {}
		for h: Dictionary in residents.households:
			rooms[h["room"]] = true
		for room: Variant in rooms:
			if not is_instance_valid(room):
				continue
			var rim: PackedVector3Array = residents.ways.outline(room as Node3D)
			var floor_y: float = (room as Node3D).global_position.y
			for i: int in range(0, rim.size(), 2):
				# (Not the roofs: a surface is made wherever someone could stand.)
				if absf(rim[i].y - floor_y) > 1.2:
					continue
				_line(rim[i], rim[i + 1], RIM)
		for s: Dictionary in _spots():
			var c: Color = COLOURS.get(s["kind"], Color.WHITE)
			var at: Vector3 = s["at"]
			_ring(at, SPOT_RADIUS, c)
			_line(at, at + Basis(Vector3.UP, float(s["yaw"])) * Vector3(0, 0, -0.4), c)
		_commit(_fixed)
	# The moving part.
	_points.clear()
	_colours.clear()
	_used = 0
	var cam: Camera3D = get_viewport().get_camera_3d()
	var eye: Vector3 = cam.global_position if cam != null else Vector3.ZERO
	for s: Dictionary in _spots():
		var at: Vector3 = s["at"]
		if at.distance_to(eye) > NAME_REACH:
			continue
		var who: Variant = s["by"]
		var text: String = str(s["kind"])
		if who != null and is_instance_valid(who):
			text += ": " + (who as Resident).given_name
		_label(at + Vector3(0, 0.25, 0), text, COLOURS.get(s["kind"], Color.WHITE))
	for p: Resident in residents.people:
		if not is_instance_valid(p) or not p.walking:
			continue
		var from: Vector3 = p.global_position + Vector3(0, 0.1, 0)
		for q: Vector3 in p.route:
			_line(from, q + Vector3(0, 0.1, 0), WAY)
			from = q + Vector3(0, 0.1, 0)
		if p.waiting_for != "":
			_ring(p.global_position + Vector3(0, 0.05, 0), 0.45, WAIT)
	_commit(_moving)
	for i: int in range(_used, _labels.size()):
		_labels[i].visible = false


func _spots() -> Array:
	var out: Array = []
	for h: Dictionary in residents.households:
		out.append_array(h["spots"])
	out.append_array(residents.commons)
	return out


func _line(a: Vector3, b: Vector3, c: Color) -> void:
	_points.append(a)
	_points.append(b)
	_colours.append(c)
	_colours.append(c)


func _ring(at: Vector3, radius: float, c: Color) -> void:
	var n: int = 20
	for k: int in n:
		var a0: float = TAU * k / n
		var a1: float = TAU * (k + 1) / n
		_line(at + Vector3(cos(a0), 0, sin(a0)) * radius, at + Vector3(cos(a1), 0, sin(a1)) * radius, c)


func _commit(mi: MeshInstance3D) -> void:
	var im := mi.mesh as ImmediateMesh
	im.clear_surfaces()
	if _points.is_empty():
		return
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	for i: int in _points.size():
		im.surface_set_color(_colours[i])
		im.surface_add_vertex(_points[i])
	im.surface_end()


func _label(at: Vector3, text: String, c: Color) -> void:
	if _used >= _labels.size():
		var l := Label3D.new()
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.fixed_size = true
		l.pixel_size = 0.0007
		l.font_size = 30
		l.outline_size = 10
		add_child(l)
		_labels.append(l)
	var label: Label3D = _labels[_used]
	_used += 1
	label.visible = true
	label.text = text
	label.modulate = c
	label.global_position = at

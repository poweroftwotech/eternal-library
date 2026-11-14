class_name FaunaOverlay
extends Node3D
## The animals' overlay (the zoo, step 2): where animals can live in the
## rooms round you and why not, and what each animal is doing. A child of the
## place's Fauna; F4 turns it on and off anywhere in the game (or start with
## --fauna-overlay). It reads what Fauna kept of each room's scan
## (Fauna.found) and the live groups; it changes nothing.
##
## Markers (small crosses) stand where the placement rules looked:
##   green   a place an animal took or can take
##   red     a place refused
##   amber   a burning lamp; grey a light that is no flame; teal a fungus glow
##   yellow  a rest spot; blue a fish-watching place or still water
##   orange  a rat run and its holes
## Look at a marker and the bottom of the screen says what it is and, for
## each kind, why it was taken or refused. Look at none and it sums up the
## room you stand in: who lives there, and why each other kind does not.
## Over each thinking animal: what it is doing; round it, the distance at
## which you startle it (red) and, for cats, at which it looks at you (pale).

const GOOD := Color(0.35, 1.0, 0.45)
const BAD := Color(1.0, 0.32, 0.28)
const LAMP := Color(1.0, 0.72, 0.25)
const PLAIN := Color(0.7, 0.72, 0.75)
const GLOW := Color(0.3, 0.9, 0.85)
const REST := Color(1.0, 0.92, 0.3)
const WATER := Color(0.35, 0.65, 1.0)
const RUN := Color(1.0, 0.55, 0.15)
const LANE := Color(0.3, 0.75, 0.4, 0.55)
const STARTLE := Color(1.0, 0.3, 0.3)
const LOOK := Color(0.85, 0.85, 1.0)
## A marker is "looked at" within this angle of the screen's middle (rad) and
## this far (m).
const AIM_ANGLE: float = 0.07
const AIM_REACH: float = 45.0
const CAT_STATES: PackedStringArray = ["resting", "strolling", "startled", "trotting away"]
const RAT_STATES: PackedStringArray = ["in its hole", "running along the wall", "sniffing", "bolting", "crossing the room", "nosing about"]
const GECKO_STATES: PackedStringArray = ["clinging", "darting", "running up the wall", "out of reach", "coming down"]
const HABITATS: Dictionary = {"water": "still water", "flame": "a burning lamp", "dark_roof": "a dark roof", "lane": "ways to walk and soft things to lie on",
	"wall_foot": "a clear run along the foot of a wall", "wall_lamp": "an open flat wall by a burning lamp"}

var fauna: Fauna
## [{at, colour, text}]: what the bottom line can describe.
var markers: Array[Dictionary] = []
var _seen: int = -1
var _fixed: MeshInstance3D
var _moving: MeshInstance3D
var _labels: Array[Label3D] = []
var _used: int = 0
var _layer: CanvasLayer
var _aim: Label
var _points := PackedVector3Array()
var _colours := PackedColorArray()


func _ready() -> void:
	top_level = true
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
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
	_layer = CanvasLayer.new()
	_layer.layer = 60
	add_child(_layer)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	_layer.add_child(margin)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(column)
	var legend := _text("ANIMALS OVERLAY (F4)   green: taken   red: refused   amber: lamp   grey: other light   teal: fungus   yellow: rest spot   blue: water   orange: rat run", 15)
	legend.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(legend)
	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(gap)
	_aim = _text("", 19)
	_aim.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_aim)
	# Leave the HUD's bottom row (the satchel) clear.
	var foot := Control.new()
	foot.custom_minimum_size.y = 150
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(foot)


static func _text(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(1.0, 0.96, 0.85))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 6)
	return l


func set_on(on: bool) -> void:
	visible = on
	_layer.visible = on
	set_process(on)
	_seen = -1


func _process(_delta: float) -> void:
	if fauna == null:
		return
	if _seen != fauna.found_version:
		_seen = fauna.found_version
		_rebuild()
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		return
	_points.clear()
	_colours.clear()
	_used = 0
	_animals()
	# What you are looking at.
	var eye: Vector3 = cam.global_position
	var ahead: Vector3 = -cam.global_basis.z
	var best: int = -1
	var best_dot: float = cos(AIM_ANGLE)
	for i: int in markers.size():
		var to: Vector3 = (markers[i]["at"] as Vector3) - eye
		var dist: float = to.length()
		if dist > AIM_REACH or dist < 0.2:
			continue
		var d: float = to.dot(ahead) / dist
		if d > best_dot:
			best_dot = d
			best = i
	if best >= 0:
		_aim.text = markers[best]["text"]
		_cross(markers[best]["at"], Color.WHITE, 0.22)
	else:
		_aim.text = _summary(_room_at(eye))
	for i: int in range(_used, _labels.size()):
		_labels[i].visible = false
	_commit(_moving)


# --- drawing -------------------------------------------------------------------

func _line(a: Vector3, b: Vector3, c: Color) -> void:
	_points.append(a)
	_points.append(b)
	_colours.append(c)
	_colours.append(c)


func _cross(at: Vector3, c: Color, r: float = 0.1) -> void:
	for axis: Vector3 in [Vector3.RIGHT, Vector3.UP, Vector3.BACK]:
		_line(at - axis * r, at + axis * r, c)


func _ring(at: Vector3, radius: float, c: Color) -> void:
	var n: int = 40
	for k: int in n:
		var a0: float = TAU * k / n
		var a1: float = TAU * (k + 1) / n
		_line(at + Vector3(cos(a0), 0, sin(a0)) * radius, at + Vector3(cos(a1), 0, sin(a1)) * radius, c)


func _mark(at: Vector3, c: Color, text: String, r: float = 0.1) -> void:
	_cross(at, c, r)
	markers.append({"at": at, "colour": c, "text": text})


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


func _label(at: Vector3, text: String, c: Color = Color(1, 1, 1)) -> void:
	if _used >= _labels.size():
		var l := Label3D.new()
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.fixed_size = true
		l.pixel_size = 0.0008
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


# --- the rooms: where animals can live ---------------------------------------------

func _rebuild() -> void:
	markers.clear()
	_points.clear()
	_colours.clear()
	for slot: String in fauna.found:
		_room(fauna.found[slot])
	_commit(_fixed)
	_points.clear()
	_colours.clear()


func _kinds(habitat: String) -> Array[CreatureDef]:
	var out: Array[CreatureDef] = []
	for d: CreatureDef in fauna.defs:
		if d.habitat == habitat:
			out.append(d)
	return out


func _lives(d: CreatureDef, j: Dictionary) -> bool:
	return Fauna.lives_in(d, str(j["type"]), str(j["state"]), j["out"])


func _room(j: Dictionary) -> void:
	if not is_instance_valid(j["node"]):
		return
	var slot: String = j["slot"]
	var groups: Array = fauna.groups.get(slot, [])
	var abandoned: bool = str(j["state"]) == RoomGrammar.ABANDONED
	# Still water.
	for b: WaterBody in (j["bodies"] if j["bodies"] != null else []):
		var box: AABB = b.bounds
		var y: float = b.surface + 0.03
		var c: Array[Vector3] = [Vector3(box.position.x, y, box.position.z), Vector3(box.end.x, y, box.position.z), Vector3(box.end.x, y, box.end.z), Vector3(box.position.x, y, box.end.z)]
		for k: int in 4:
			_line(c[k], c[(k + 1) % 4], WATER)
		var lines: PackedStringArray = ["Still water: %.0f m2, about %.2f m deep where fish can swim" % [b.area(), b.mean_depth()]]
		for d: CreatureDef in _kinds("water"):
			var why: String = "yes"
			if not _lives(d, j):
				why = "no, its rules keep it out of this kind of room"
			elif b.deep_samples(d.min_depth).size() < 4:
				why = "no, too shallow (needs %.2f m)" % d.min_depth
			elif b.area() < d.min_area:
				why = "no, too small (needs %.0f m2)" % d.min_area
			elif abandoned and d.build == "simple":
				why = "a forgotten pool: at most one survivor, by chance"
			lines.append("%s: %s" % [d.display_name, why])
		_mark(Vector3(box.get_center().x, y, box.get_center().z), WATER, "\n".join(lines), 0.2)
	# Lights.
	var lights: Dictionary = j["lights"] if j["lights"] != null else {}
	var moths: PackedVector3Array = []
	for g: Node in groups:
		if is_instance_valid(g) and g is MothSwarm:
			moths.append_array((g as MothSwarm).used)
	for f: Dictionary in lights.get("flames", []):
		var lines: PackedStringArray = ["A burning lamp"]
		for d: CreatureDef in _kinds("flame"):
			if not _lives(d, j):
				lines.append("%s: no, its rules keep it out of this kind of room" % d.display_name)
			elif moths.has(f["at"]):
				lines.append("%s: here" % d.display_name)
			else:
				lines.append("%s: none by chance (%d lamps in 100 have them)" % [d.display_name, roundi(d.flame_share * 100.0)])
		for note: Dictionary in j.get("notes", []):
			if not bool(note["ok"]) and (note["at"] as Vector3).is_equal_approx(f["at"]):
				lines.append(str(note["text"]))
		_mark(f["at"], LAMP, "\n".join(lines), 0.14)
	for note: Dictionary in j.get("notes", []):
		if bool(note["ok"]):
			_mark(note["at"], GOOD, str(note["text"]), 0.12)
	for f: Dictionary in lights.get("others", []):
		_mark(f["at"], PLAIN, "A light that is no flame (daylight, a window): it draws no moths, and keeps bats and glowworms off the roofs near it", 0.12)
	for f: Dictionary in lights.get("glows", []):
		_mark(f["at"], GLOW, "A fungus glow: glowworms keep away from it and take its colour; bats don't mind it", 0.12)
	# Roofs.
	var roofs: HabitatScan.RoofScan = j["roofs"] as HabitatScan.RoofScan
	if roofs != null:
		for r: Dictionary in roofs.roofs:
			var lines: PackedStringArray = ["Roof, %.1f m over the floor, %s" % [float(r["height"]), "natural rock" if bool(r.get("rock", false)) else "built"]]
			var taken: bool = false
			for d: CreatureDef in _kinds("dark_roof"):
				var why: String = _roof_why(d, r, lights) if _lives(d, j) else "its rules keep it out of this kind of room"
				taken = taken or why == ""
				lines.append("%s: %s" % [d.display_name, "can hang here" if why == "" else "no, " + why])
			_mark((r["at"] as Vector3) - Vector3(0, 0.05, 0), GOOD if taken else BAD, "\n".join(lines), 0.07)
	# Ways to walk.
	var graph: LaneGraph = j.get("graph") as LaneGraph
	if graph != null:
		var home: Dictionary = {}
		for i: int in graph.home:
			home[i] = true
		var up := Vector3(0, 0.04, 0)
		for i: int in graph.points.size():
			if not home.has(i):
				continue
			for k: int in graph.links[i]:
				if k > i:
					_line(graph.points[i] + up, graph.points[k] + up, LANE)
		for s: int in graph.spots:
			_mark(graph.points[s] + Vector3(0, 0.08, 0), REST, "A rest spot: a cat may sleep, sit or wash here", 0.12)
		for w: Dictionary in graph.watch:
			_mark(graph.points[int(w["node"])] + Vector3(0, 0.08, 0), WATER, "A fish-watching place: a cat sits here and looks at the water", 0.12)
	# What moved in.
	for g: Node in groups:
		if not is_instance_valid(g):
			continue
		if g is RatPack:
			for run: Dictionary in (g as RatPack).runs:
				var a: Vector3 = (run["a"] as Vector3) + Vector3(0, 0.05, 0)
				var b: Vector3 = (run["b"] as Vector3) + Vector3(0, 0.05, 0)
				_line(a, b, RUN)
				_mark(a, RUN, "A rat hole (an end of a %.1f m run)" % a.distance_to(b), 0.1)
				_mark(b, RUN, "A rat hole (an end of a %.1f m run)" % a.distance_to(b), 0.1)
				_mark((a + b) * 0.5, RUN, "A rat run, %.1f m along the foot of this wall; %d rats share this room's %d runs" % [a.distance_to(b), (g as RatPack).rats.size(), (g as RatPack).runs.size()], 0.1)
		elif g is BatRoost:
			_mark((g as BatRoost).centre, GOOD, "A bat roost: %d bats. They take flight when you come within %.0f m" % [(g as BatRoost).multimesh.instance_count, (g as BatRoost).def.startle_radius], 0.2)


## Why kind `d` won't take roof `r` ("" when it will).
func _roof_why(d: CreatureDef, r: Dictionary, lights: Dictionary) -> String:
	if d.rock_only and not bool(r.get("rock", false)):
		return "only on natural rock"
	if float(r["height"]) < d.min_height:
		return "too low (needs %.1f m)" % d.min_height
	var at: Vector3 = r["at"]
	for key: String in ["flames", "others"]:
		for f: Dictionary in lights.get(key, []):
			var dist: float = (f["at"] as Vector3).distance_to(at)
			if dist < d.dark_radius:
				return "%s %.1f m away (needs %.0f m of dark)" % ["a lamp burns" if key == "flames" else "a light is", dist, d.dark_radius]
	for f: Dictionary in lights.get("glows", []):
		var dist: float = (f["at"] as Vector3).distance_to(at)
		if dist < d.glow_gap:
			return "a fungus glows %.1f m away (keeps %.0f m off)" % [dist, d.glow_gap]
	return ""


# --- the room you stand in -----------------------------------------------------------

## The room (its kept job) that `p` is in, or null.
func _room_at(p: Vector3) -> Variant:
	if fauna.found.size() == 1:
		return fauna.found.values()[0]
	var local: Vector3 = fauna._frame().affine_inverse() * p
	var cx: int = floori(local.x / CellGrid.BAY)
	var cz: int = floori(-local.z / CellGrid.BAY)
	var best: Variant = null
	var best_dy: float = 3.5
	for slot: String in fauna.found:
		var j: Dictionary = fauna.found[slot]
		for c: Vector3i in j["cells"]:
			if c.x == cx and c.z == cz and absf(c.y * CellGrid.BAY - local.y + 1.0) < best_dy:
				best_dy = absf(c.y * CellGrid.BAY - local.y + 1.0)
				best = j
	return best


func _summary(room: Variant) -> String:
	if room == null:
		return "Look at a marker to see what it is. (No room with animals' places here: a corridor, or its scan is not done.)"
	var j: Dictionary = room
	var slot: String = j["slot"]
	var here: Dictionary = {}
	for g: Node in fauna.groups.get(slot, []):
		if is_instance_valid(g):
			var kind: String = str(g.get("def").id)
			here[kind] = int(here.get(kind, 0)) + Fauna.size_of(g)
	var have: PackedStringArray = []
	var lack: PackedStringArray = []
	for d: CreatureDef in fauna.defs:
		if here.has(str(d.id)):
			have.append("%s %d" % [d.display_name, here[str(d.id)]])
		else:
			lack.append("%s: %s" % [d.display_name, _absent(d, j)])
	var name_shown: String = slot if slot != "" else fauna.place
	var state: String = "forgotten" if str(j["state"]) == RoomGrammar.ABANDONED else "lived-in"
	return "%s (%s, %s)   HERE: %s\nNOT HERE   %s" % [name_shown.to_upper(), j["type"], state, ", ".join(have) if not have.is_empty() else "nothing", "   ".join(lack) if not lack.is_empty() else "-"]


## Why kind `d` has nobody in room `j`.
func _absent(d: CreatureDef, j: Dictionary) -> String:
	var abandoned: bool = str(j["state"]) == RoomGrammar.ABANDONED
	if not _lives(d, j):
		if d.state == "abandoned" and not abandoned:
			return "only in forgotten rooms"
		if d.state == "kept" and abandoned:
			return "only in lived-in rooms"
		return "kept out of this kind of room"
	var lights: Dictionary = j["lights"] if j["lights"] != null else {}
	match d.habitat:
		"water":
			return "no still water" if (j["bodies"] as Array).is_empty() else "its water is too small, too shallow, or forgotten"
		"flame":
			return "no burning lamp" if (lights.get("flames", []) as Array).is_empty() else "no lamp picked, by chance"
		"wall_lamp":
			return "no burning lamp" if (lights.get("flames", []) as Array).is_empty() else "no lamp with an open flat wall was picked"
		"dark_roof":
			var roofs: HabitatScan.RoofScan = j["roofs"] as HabitatScan.RoofScan
			if roofs == null or roofs.roofs.is_empty():
				return "no roof found"
			for r: Dictionary in roofs.roofs:
				if _roof_why(d, r, lights) == "":
					return "roofs it could take, but too few together"
			return "no roof that is %s%.1f m up and %.0f m from any light" % ["rock, " if d.rock_only else "", d.min_height, d.dark_radius]
		"lane":
			var g: LaneGraph = j.get("graph") as LaneGraph
			if g == null or g.home.size() < 2:
				return "nowhere to walk"
			if g.soft_found == 0:
				return "nothing soft to lie on (a rug, cushion, bench, bedroll)"
			return "too few soft things (%d; one cat for every %.0f)" % [g.soft_found, d.area_each]
		"wall_foot":
			return "no clear run of %.0f m along the foot of a wall" % RatPack.MIN_RUN
	return "needs %s" % HABITATS.get(d.habitat, d.habitat)


# --- the animals: what each is doing ----------------------------------------------------

func _animals() -> void:
	for slot: String in fauna.groups:
		for g: Node in fauna.groups[slot]:
			if not is_instance_valid(g) or not (g as Node3D).visible:
				continue
			if g is CatBand:
				for cat: Dictionary in (g as CatBand).cats:
					var body: CatBody = cat["body"]
					var at: Vector3 = body.global_position
					var doing: String = CAT_STATES[int(cat["state"])]
					if int(cat["state"]) == CatBand.REST:
						doing += " (%s, %.0f s more)" % [body.anim.current_animation, maxf(float(cat["timer"]), 0.0)]
					_label(at + Vector3(0, 0.55, 0), "Cat: " + doing)
					_ring(at + Vector3(0, 0.03, 0), (g as CatBand).def.startle_radius, STARTLE)
					_ring(at + Vector3(0, 0.03, 0), (g as CatBand).def.look_radius, LOOK)
			elif g is BirdBand:
				var band := g as BirdBand
				for p: Dictionary in band.perches:
					_ring(p["at"], 0.08, LOOK if p["high"] else STARTLE)
				for i: int in band.birds.size():
					var bird: Dictionary = band.birds[i]
					var at: Vector3 = (bird["body"] as Node3D).global_position
					var doing: String = ["perched", "flying", "at the flowers"][int(bird["state"])]
					if band.singer == i:
						doing = "singing (%d phrases left)" % int(bird["bout"])
					elif int(bird["bout"]) > 0:
						doing += ", in a bout (%d left)" % int(bird["bout"])
					elif float(bird["wary"]) > 0.0:
						doing += ", wary %.0f s" % float(bird["wary"])
					_label(at + Vector3(0, 0.3, 0), "Nightingale: " + doing)
					_ring(at, band.def.startle_radius, STARTLE)
			elif g is RatPack:
				var pack := g as RatPack
				for rat: Dictionary in pack.rats:
					var at: Vector3 = pack.where(rat)
					var state: int = rat["state"]
					if state == RatPack.IN:
						_label(at + Vector3(0, 0.25, 0), "Rat in its hole (%.0f s)" % maxf(float(rat["timer"]), 0.0), Color(0.75, 0.75, 0.75))
						continue
					_label(at + Vector3(0, 0.3, 0), "Rat: " + RAT_STATES[state])
					_ring(at + Vector3(0, 0.03, 0), pack.def.startle_radius, STARTLE)
			elif g is GeckoWall:
				var wall := g as GeckoWall
				for gecko: Dictionary in wall.geckos:
					if bool(gecko["gone"]):
						_label(gecko["home"], "Gecko gone (its lamp is out)", Color(0.75, 0.75, 0.75))
						continue
					var at: Vector3 = (gecko["at"] as Vector3) + (gecko["normal"] as Vector3) * 0.05
					_label(at + Vector3(0, 0.12, 0), "Gecko: " + GECKO_STATES[int(gecko["state"])])
					_ring(at, wall.def.startle_radius, STARTLE)
			elif g is BatRoost:
				var roost := g as BatRoost
				var doing: String = "hanging" if roost.clock < 0.0 else ("in flight" if roost.clock < BatRoost.AWAY_S else "away; back once you have been %.0f m off for %.0f s" % [BatRoost.RETURN_DISTANCE, BatRoost.RETURN_S])
				_label(roost.centre - Vector3(0, 0.8, 0), "Bats: " + doing)
				_ring(roost.centre - Vector3(0, 1.6, 0), roost.def.startle_radius, STARTLE)
			elif g is FishPool:
				var pool := g as FishPool
				_label(Vector3(pool.body.bounds.get_center().x, pool.body.surface + 0.5, pool.body.bounds.get_center().z),
					"%s: %d; they scatter within %.1f m" % [pool.def.display_name, pool.multimesh.instance_count, pool.def.startle_radius])

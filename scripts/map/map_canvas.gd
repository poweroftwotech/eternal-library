class_name MapCanvas
extends Control
## The sheet of the map (phase 11): one place, one storey, drawn from the
## sketches of its rooms (sketch_of: a room of its AreaPlan, architecture.md
## 2.1, as the save keeps it once you have seen it) on the old paper of the
## mock. Drawing needs no plan, so a place you are not in shows at once.
## MapPage draws it at half resolution and doubles it, so its lines are pixels
## like the rest of the game.
##
## Rooms you have entered are drawn in wavering ink with a brown wash and their
## names; rooms you have only seen into, in dashed pencil. A doorway into a
## room you haven't entered gets a dotted stub and an open circle (a way not
## taken); a door to another place a solid block and its name ("?" until you
## have been there); a door that won't open a shut-door mark. North (-Z) is up.
##
## Your marks (step 3) are drawn in a blue-black ink with their notes. The
## whole stratum (step 3) draws every place you know at once, each through
## its frame (where it lies in the Gorge's), joined by its doors.

const INK := Color("2a2017")
const PENCIL := Color("6f6350")
const RUST := Color("8b2a1a")
const WASH := Color(0.47, 0.33, 0.16, 0.22)
const SHUT := Color("8a6a3a")
const GHOST := Color(0.43, 0.39, 0.31, 0.3)
const PAPER_HALO := Color(0.87, 0.79, 0.61, 0.85)
## Your marks: a blue-black ink, apart from the map's own.
const MARK := Color("24365c")
const BAY: float = CellGrid.BAY
## Half an arch's opening (the kit's 3 m arches and doors).
const DOOR_HALF: float = 1.5
## Neighbour offsets and their edge's corners (cell-local, in bays: x east, z north).
const SIDES: Array[Vector3i] = [Vector3i(0, 0, 1), Vector3i(0, 0, -1), Vector3i(1, 0, 0), Vector3i(-1, 0, 0)]

var paper: Texture2D
var font: Font
var font_size: int = 12
## The place drawn, and its rooms you have seen (none: `note` is shown instead).
var place_id: String = ""
var rooms: Array[Sketch] = []
## slot -> true.
var entered: Dictionary = {}
var seen: Dictionary = {}
var storey: int = 0
## The map point (metres: area X, Z) at the middle of the sheet, and pixels a metre.
var centre: Vector2 = Vector2.ZERO
var zoom: float = 3.25
## Where you stand ({} = not in this place): {pos: Vector3 (area frame), dir: Vector2 (X, Z)}.
var you: Dictionary = {}
## A threshold's `to` -> what its door says ("to the Gorge", or "?").
var door_labels: Dictionary = {}
## Said in the middle of the sheet when there is nothing to draw.
var note: String = ""
## A traced place (the Gorge, the camp) is drawn from its trace's images
## instead of rooms: the tiles walked (index -> true) in ink, those only
## seen in pencil, and the doors on walked tiles.
var trace: MapTrace
var trace_ink: Texture2D
var trace_pencil: Texture2D
var walked: Dictionary = {}
var sighted: Dictionary = {}
## Your marks on the place drawn: {at: Vector2 (metres), storey, symbol, note};
## the one picked (being placed or changed), or -1.
var marks: Array = []
var picked_mark: int = -1
## The whole stratum (MapPage.show_stratum): each place you know as a layer
## (MapPage.layer_of, with its `frame` in the Gorge's and where its name
## goes), the links between their doors ([Vector2, Vector2]), and you
## ({at, dir} in the Gorge's frame). Empty: one place.
var layers: Array[Dictionary] = []
var links: Array = []
## Where the place drawn lies: its metres to the sheet's (the Gorge's).
var frame: Transform2D = Transform2D.IDENTITY
var _named: bool = true
## Trace images as drawn smaller than their pixels (_shrunk): Texture2D -> CanvasTexture.
var _smooth: Dictionary = {}


## Metres of the place drawn (through its `frame`, on the stratum) to sheet pixels.
func to_px(m: Vector2) -> Vector2:
	return (frame * m - centre) * zoom + size * 0.5


func to_map(px: Vector2) -> Vector2:
	return (px - size * 0.5) / zoom + centre


## The storeys with a room you have entered or seen, lowest first.
func storeys() -> Array[int]:
	var out: Array[int] = []
	if not layers.is_empty():
		return out     # the stratum: each place on its ground floor
	for r: Sketch in rooms:
		if entered.has(r.slot_id) or seen.has(r.slot_id):
			for c: Vector3i in r.floor_cells:
				if not out.has(c.y):
					out.append(c.y)
	out.sort()
	return out


## What you have walked of the place `use` put on the sheet, in the sheet's
## metres (through its frame): the walked tiles, or the entered rooms on this storey.
func extent() -> Rect2:
	var pts: Array[Vector2] = []
	if trace != null:
		for t: int in walked:
			var r: Rect2 = trace.tile_rect(t)
			pts.append_array([r.position, r.end])
	else:
		for r: Sketch in rooms:
			if entered.has(r.slot_id):
				for c: Vector3i in r.floor_cells:
					if c.y == storey:
						pts.append_array([Vector2(c.x * BAY, -c.z * BAY - BAY), Vector2(c.x * BAY + BAY, -c.z * BAY)])
	var out := Rect2()
	for k: int in pts.size():
		var p: Vector2 = frame * pts[k]
		out = Rect2(p, Vector2.ZERO) if k == 0 else out.expand(p)
	return out


## The middle of the rooms you have entered on this storey (metres), or ZERO.
func middle() -> Vector2:
	var sum := Vector2.ZERO
	var n: int = 0
	if trace != null:
		for t: int in walked:
			sum += trace.tile_rect(t).get_center()
			n += 1
		return sum / n if n > 0 else Vector2.ZERO
	for r: Sketch in rooms:
		if entered.has(r.slot_id):
			for c: Vector3i in r.floor_cells:
				if c.y == storey:
					sum += _cell_centre(c)
					n += 1
	return sum / n if n > 0 else Vector2.ZERO


## Puts one place on the sheet (MapPage.layer_of): its rooms or trace, what
## you know of it, its marks and where it lies (`frame`).
func use(layer: Dictionary) -> void:
	place_id = layer["id"]
	rooms = layer["rooms"]
	entered = layer["entered"]
	seen = layer["seen"]
	storey = layer["storey"]
	trace = layer["trace"]
	trace_ink = layer["ink"]
	trace_pencil = layer["pencil"]
	walked = layer["walked"]
	sighted = layer["sighted"]
	door_labels = layer["door_labels"]
	marks = layer["marks"]
	frame = layer.get("frame", Transform2D.IDENTITY)


func _draw() -> void:
	if paper != null:
		draw_texture_rect(paper, Rect2(Vector2.ZERO, size), false)
	if not layers.is_empty():
		_draw_stratum()
		return
	frame = Transform2D.IDENTITY
	if trace == null and rooms.is_empty():
		_text_at(size * 0.5, note, PENCIL, 0.0, font_size + 2)
		return
	_draw_place(true)
	if not you.is_empty() and (trace != null or int(you["storey"]) == storey):
		_draw_you(Vector2(you["pos"].x, you["pos"].z), you["dir"])


## Every place you know where it lies, joined by its doors; their names; you.
func _draw_stratum() -> void:
	for l: Array in links:
		draw_dashed_line(to_px(l[0]), to_px(l[1]), INK, 1.0, 3.0)
	for layer: Dictionary in layers:
		use(layer)
		_draw_place(false)
	frame = Transform2D.IDENTITY
	for layer: Dictionary in layers:     # over the place, clear of its drawing
		_text_at(to_px(layer["label_at"]) - Vector2(0, font_size), layer["name"], INK, 0.0, font_size + 2)
	if not you.is_empty():
		_draw_you(you["at"], you["dir"])


## The place `use` put on the sheet: its rooms (or trace) and its marks.
## `named`: its rooms' names and its doors' labels (not on the stratum).
func _draw_place(named: bool) -> void:
	_named = named
	if trace != null:
		_draw_trace()
	elif not rooms.is_empty():
		_draw_rooms()
	_draw_marks()


func _draw_rooms() -> void:
	var owner: Dictionary = {}     # floor cell on this storey -> room
	for r: Sketch in rooms:
		for c: Vector3i in r.floor_cells:
			if c.y == storey or c.y == storey - 1:
				owner[c] = r
	_draw_ghost(owner)
	var shown: Array[Sketch] = []
	for r: Sketch in rooms:
		if (entered.has(r.slot_id) or seen.has(r.slot_id)) and r.floor_cells.keys().any(func(c: Vector3i) -> bool: return c.y == storey):
			shown.append(r)
	for r: Sketch in shown:
		if entered.has(r.slot_id):
			for c: Vector3i in r.floor_cells:
				if c.y == storey:
					_quad(Vector2(c.x * BAY, -c.z * BAY - BAY), Vector2(BAY, BAY), WASH, true)
	# Pencil first, ink over it.
	for r: Sketch in shown:
		if not entered.has(r.slot_id):
			_draw_room(r, owner, false)
	for r: Sketch in shown:
		if entered.has(r.slot_id):
			_draw_room(r, owner, true)
	# A name once a storey (grown rooms share one: "The Lower Galleries"), on the biggest.
	var named: Dictionary = {}
	for r: Sketch in shown:
		if entered.has(r.slot_id):
			var key: String = r.name
			if not named.has(key) or _cells_here(r) > _cells_here(named[key]):
				named[key] = r
	if _named:
		for r: Sketch in named.values():
			_draw_name(r)


## A traced place: the tiles seen in pencil, those walked in ink over them,
## a tile at a time from the trace's images; the doors on walked tiles. Its
## frame only moves it (the Gorge's and the camp's are the stratum's own).
func _draw_trace() -> void:
	var view := Rect2(frame.affine_inverse() * to_map(Vector2.ZERO), size / zoom)
	for pass_ink: bool in [false, true]:
		for t: int in (walked if pass_ink else sighted):
			if pass_ink == false and walked.has(t):
				continue
			var r: Rect2 = trace.tile_rect(t)
			if not view.intersects(r):
				continue
			draw_texture_rect_region(_shrunk(trace_ink if pass_ink else trace_pencil), Rect2(to_px(r.position), r.size * zoom), trace.tile_pixels(t))
	for d: Dictionary in trace.doors:
		if walked.has(trace.tile_of(d["at"])):
			_door_mark({"mid": d["at"], "out": d["out"], "kind": d["kind"], "to": d["raw"]}, true)


## A trace image as drawn: its own pixels while a sample is a pixel or more;
## smaller (the stratum), mipmapped, so its lines fade rather than drop out.
func _shrunk(tex: Texture2D) -> Texture2D:
	if zoom * trace.step >= 1.0:
		return tex
	if not _smooth.has(tex):
		var ct := CanvasTexture.new()
		ct.diffuse_texture = tex
		ct.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		_smooth[tex] = ct
	return _smooth[tex]


## Your marks on this place (on this storey: a traced place has one), and
## the one being placed or changed, ringed.
func _draw_marks() -> void:
	for i: int in marks.size():
		var m: Dictionary = marks[i]
		if trace == null and int(m["storey"]) != storey:
			continue
		var at: Vector2 = to_px(m["at"])
		draw_mark(self, at, str(m["symbol"]), MARK)
		if i == picked_mark:
			draw_arc(at, 8.0, 0.0, TAU, 20, RUST, 1.0)
		if str(m.get("note", "")) != "" and font != null:
			var w: float = font.get_string_size(str(m["note"]), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			_text_at(at + Vector2(9.0 + w * 0.5, 0.0), str(m["note"]), MARK, 0.0, font_size)


## A mark's symbol, about 10 px across, centred on `c` (also the mark
## buttons' and the key's).
static func draw_mark(ci: CanvasItem, c: Vector2, symbol: String, col: Color) -> void:
	match symbol:
		"star":
			var pts := PackedVector2Array()
			for k: int in 10:
				pts.append(c + Vector2.from_angle(-PI / 2 + k * PI / 5) * (5.5 if k % 2 == 0 else 2.3))
			ci.draw_colored_polygon(pts, col)
		"cross":
			ci.draw_line(c + Vector2(-4, -4), c + Vector2(4, 4), col, 2.0)
			ci.draw_line(c + Vector2(-4, 4), c + Vector2(4, -4), col, 2.0)
		"question":
			ci.draw_arc(c + Vector2(0, -1.5), 3.0, -PI, PI * 0.5, 10, col, 1.5)
			ci.draw_line(c + Vector2(0, 1.5), c + Vector2(0, 3.0), col, 1.5)
			ci.draw_rect(Rect2(c + Vector2(-0.75, 4.2), Vector2(1.5, 1.5)), col)
		"lamp":
			ci.draw_circle(c + Vector2(0, -1), 3.0, col)
			ci.draw_rect(Rect2(c + Vector2(-1, 2), Vector2(2, 2.5)), col)
			ci.draw_line(c + Vector2(-3, 5), c + Vector2(3, 5), col, 1.5)


## A rect of the place (metres) on the sheet, through its frame.
func _quad(a: Vector2, s: Vector2, col: Color, filled: bool) -> void:
	var pts := PackedVector2Array([to_px(a), to_px(a + Vector2(s.x, 0)), to_px(a + s), to_px(a + Vector2(0, s.y))])
	if filled:
		draw_colored_polygon(pts, col)
	else:
		pts.append(pts[0])
		draw_polyline(pts, col, 1.0)


## The entered rooms of the storey below, faint, to tell where you are.
func _draw_ghost(owner: Dictionary) -> void:
	for c: Vector3i in owner:
		var r: Sketch = owner[c]
		if c.y != storey - 1 or not entered.has(r.slot_id):
			continue
		for i: int in SIDES.size():
			if owner.get(c + SIDES[i]) != r:
				var e: Array[Vector2] = _edge(c, i)
				draw_line(to_px(e[0]), to_px(e[1]), GHOST, 1.0)


func _draw_room(r: Sketch, owner: Dictionary, ink: bool) -> void:
	var doors: Dictionary = _doorways(r)
	for c: Vector3i in r.floor_cells:
		if c.y != storey:
			continue
		for i: int in SIDES.size():
			var n: Vector3i = c + SIDES[i]
			if owner.get(n) == r:
				continue
			var other: Sketch = owner.get(n)
			if not ink and other != null and entered.has(other.slot_id):
				continue     # the ink of the room next door draws this wall
			var e: Array[Vector2] = _edge(c, i)
			var door: Dictionary = doors.get(_ekey(c, n), {})
			if door.is_empty():
				_wall(e[0], e[1], ink)
				continue
			var mid: Vector2 = (e[0] + e[1]) * 0.5
			var along: Vector2 = (e[1] - e[0]).normalized()
			var out: Vector2 = Vector2(SIDES[i].x, -SIDES[i].z)     # map Z grows south
			_wall(e[0], mid - along * DOOR_HALF, ink)
			_wall(mid + along * DOOR_HALF, e[1], ink)
			for s: float in [-DOOR_HALF, DOOR_HALF]:     # jambs
				var j: Vector2 = mid + along * s
				draw_line(to_px(j - out * 0.35), to_px(j + out * 0.35), INK if ink else PENCIL, 1.0)
	# What lies through each doorway, where the doorway really is (a
	# threshold may stand off the cell edge its room's wall is on).
	for door: Dictionary in doors.values():
		_door_mark(door, ink)
	if ink:
		for c: Vector3i in r.blocked_cells:
			if c.y == storey:
				_quad(Vector2(c.x * BAY + 0.9, -c.z * BAY - BAY + 0.9), Vector2(BAY - 1.8, BAY - 1.8), INK, false)


## What lies through a doorway: a way not taken, a door to another place, a shut door.
func _door_mark(door: Dictionary, ink: bool) -> void:
	var col: Color = INK if ink else PENCIL
	var mid: Vector2 = door["mid"]
	var out: Vector2 = door["out"]
	var along := Vector2(-out.y, out.x)
	match str(door["kind"]):
		"joined":
			var other: String = door["other"]
			if entered.has(other) or (not ink and seen.has(other)):
				return
			var tip: Vector2 = mid + out * BAY * 0.9
			draw_dashed_line(to_px(mid), to_px(tip), col, 1.0, 2.0)
			draw_arc(to_px(tip + out * 0.6), maxf(2.0, 0.6 * zoom), 0.0, TAU, 12, col, 1.0)
		"threshold":
			if not ink:
				return
			_block(mid, along, 1.4, 0.75, INK)
			if _named:
				var label: String = str(door_labels.get(door["to"], "?"))
				_text_at(to_px(mid + out * BAY * 0.75), label, INK if label != "?" else PENCIL, 0.0, font_size)
		"sealed":
			if not ink:
				return
			_block(mid, along, 1.4, 0.75, INK)
			_block(mid, along, 1.1, 0.35, SHUT)


## A filled bar across a doorway: half `len` along the wall, half `thick` across.
func _block(mid: Vector2, along: Vector2, len: float, thick: float, col: Color) -> void:
	var across := Vector2(-along.y, along.x)
	var pts := PackedVector2Array([
		to_px(mid - along * len - across * thick), to_px(mid + along * len - across * thick),
		to_px(mid + along * len + across * thick), to_px(mid - along * len + across * thick)])
	draw_colored_polygon(pts, col)


## A wall: ink wavers like a pen line (the same way every time, from where it
## is), pencil is dashed.
func _wall(a: Vector2, b: Vector2, ink: bool) -> void:
	if not ink:
		draw_dashed_line(to_px(a), to_px(b), PENCIL, 1.0, 3.0)
		return
	var n: int = maxi(1, int((b - a).length() * zoom / 5.0))
	var pts := PackedVector2Array()
	for k: int in n + 1:
		var m: Vector2 = a.lerp(b, float(k) / n)
		pts.append(to_px(m) + _jitter(m))
	draw_polyline(pts, INK, 1.5)


func _jitter(m: Vector2) -> Vector2:
	var key := Vector2i(roundi(m.x * 4.0), roundi(m.y * 4.0))
	var h: int = hash(key)
	return Vector2(float(h & 0xff) / 255.0 - 0.5, float((h >> 8) & 0xff) / 255.0 - 0.5) * 0.9


func _cells_here(r: Sketch) -> int:
	return r.floor_cells.keys().filter(func(c: Vector3i) -> bool: return c.y == storey).size()


func _draw_name(r: Sketch) -> void:
	var name_text: String = r.name
	if name_text == "" or font == null:
		return
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	var sum := Vector2.ZERO
	var n: int = 0
	for c: Vector3i in r.floor_cells:
		if c.y == storey:
			var m: Vector2 = _cell_centre(c)
			sum += m
			n += 1
			lo = lo.min(m)
			hi = hi.max(m)
	var box: Vector2 = (hi - lo + Vector2(BAY, BAY)) * zoom
	var w: float = font.get_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var turn: float = -PI / 2 if w > box.x - 4.0 and box.y > box.x else 0.0
	_text_at(to_px(sum / n), name_text, INK, turn, font_size)


func _draw_you(at: Vector2, dir: Vector2) -> void:
	var base: Array[Vector2] = [Vector2(6, 0), Vector2(-4.5, -4.5), Vector2(-2, 0), Vector2(-4.5, 4.5)]
	var angle: float = dir.angle()
	var c: Vector2 = to_px(at)
	var pts := PackedVector2Array()
	for p: Vector2 in base:
		pts.append(c + p.rotated(angle))
	draw_colored_polygon(pts, RUST)


func _text_at(p: Vector2, text: String, col: Color, turn: float, fs: int) -> void:
	if font == null or text == "":
		return
	var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_set_transform(p.round(), turn)
	var at: Vector2 = Vector2(-w * 0.5, fs * 0.35).round()
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 2, PAPER_HALO)     # lifts it off what's under it
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	draw_set_transform_matrix(Transform2D.IDENTITY)


## Doorways of room `r` on this storey: the cell edge they stand on -> the door.
func _doorways(r: Sketch) -> Dictionary:
	var out: Dictionary = {}
	for door: Dictionary in r.doors:
		if int(door["storey"]) == storey:
			out[door["edge"]] = door
	return out


## One room as the map keeps it: what drawing it needs, no more.
class Sketch:
	extends RefCounted
	var slot_id: String = ""
	var name: String = ""
	## Walkable cells (any storey) and the ones a walk goes round: Vector3i -> true.
	var floor_cells: Dictionary = {}
	var blocked_cells: Dictionary = {}
	## {mid: Vector2 (map metres), out: Vector2, storey: int, edge: String, kind:
	## joined | threshold | sealed, other (joined: its slot), to (threshold: its place)}.
	var doors: Array[Dictionary] = []


## Room `r` of a plan as the save keeps it (JSON).
static func sketch_of(r: AreaPlan.Room) -> Dictionary:
	var doors: Array = []
	for conn_name: StringName in r.connectors:
		var k: Dictionary = r.connectors[conn_name]
		var xf: Transform3D = k["xf"]
		var dir: Vector3 = -xf.basis.z.normalized()
		var door: Dictionary = {"at": [snappedf(xf.origin.x, 0.01), snappedf(xf.origin.z, 0.01)],
			"out": [snappedf(dir.x, 0.001), snappedf(dir.z, 0.001)], "storey": int(k["storey"])}
		var joined: String = str(k["joined"])
		if joined != "":
			door["kind"] = "joined"
			door["other"] = joined.get_slice("/", 0)
		elif str(k["cap"]) == "threshold":
			door["kind"] = "threshold"
			door["to"] = str(k.get("to", ""))
		else:
			door["kind"] = "sealed"
		doors.append(door)
	var cells: Array = r.floor_cells.keys().map(func(c: Vector3i) -> Array: return [c.x, c.y, c.z])
	var blocked: Array = r.blocked_cells.keys().map(func(c: Vector3i) -> Array: return [c.x, c.y, c.z])
	var shown: String = r.display_name if r.display_name != "" else str(RoomTypes.NAMES.get(r.room_type, ""))
	return {"name": shown, "cells": cells, "blocked": blocked, "doors": doors}


## A sketch the save kept, ready to draw.
static func sketch_from(slot: String, d: Dictionary) -> Sketch:
	var s := Sketch.new()
	s.slot_id = slot
	s.name = str(d.get("name", ""))
	for c: Variant in d.get("cells", []):
		s.floor_cells[Vector3i(int(c[0]), int(c[1]), int(c[2]))] = true
	for c: Variant in d.get("blocked", []):
		s.blocked_cells[Vector3i(int(c[0]), int(c[1]), int(c[2]))] = true
	for raw: Variant in d.get("doors", []):
		var door: Dictionary = (raw as Dictionary).duplicate()
		var mid := Vector2(float(raw["at"][0]), float(raw["at"][1]))
		var out := Vector2(float(raw["out"][0]), float(raw["out"][1])).normalized()
		var s_y: int = int(raw["storey"])
		var at3 := Vector3(mid.x, s_y * BAY, mid.y)
		var out3 := Vector3(out.x, 0.0, out.y) * BAY * 0.5
		door["mid"] = mid
		door["out"] = out
		door["storey"] = s_y
		door["edge"] = _ekey(AreaPlan.cell_of(at3 - out3), AreaPlan.cell_of(at3 + out3))
		s.doors.append(door)
	return s


## Corners (metres) of cell c's side i.
func _edge(c: Vector3i, i: int) -> Array[Vector2]:
	var x0: float = c.x * BAY
	var x1: float = x0 + BAY
	var zn: float = -c.z * BAY - BAY     # north edge (map Z)
	var zs: float = -c.z * BAY
	match i:
		0:
			return [Vector2(x0, zn), Vector2(x1, zn)]
		1:
			return [Vector2(x0, zs), Vector2(x1, zs)]
		2:
			return [Vector2(x1, zn), Vector2(x1, zs)]
	return [Vector2(x0, zn), Vector2(x0, zs)]


static func _ekey(a: Vector3i, b: Vector3i) -> String:
	var sa: String = str(a)
	var sb: String = str(b)
	return sa + "|" + sb if sa < sb else sb + "|" + sa


static func _cell_centre(c: Vector3i) -> Vector2:
	return Vector2(c.x * BAY + BAY * 0.5, -c.z * BAY - BAY * 0.5)

@tool
class_name CliffLedgeGrammar
extends RoomGrammar
## Ledges on the gorge's cliffs (phase-6-design.md 5.7.5, phase 6 step 4): a
## strip of 2-5 bays along a frontage slot, one bay deep, its back on the
## cliff's face: a gallery on a pier under each bay where one stands cleanly
## (in the mist, or well on a terrace, a corbel over it: as the Overlook's
## ledge), and where none does, carried by the cliff itself on stepped stone
## consoles at that bay's joints (corbel courses running back into the face,
## each a step shallower than the one above; walked, the user chose piers
## where they stand: 2 m out from the face, where the tiers' terraces step
## out below, many find no clean footing). The face behind is the ledge's own
## (windows and tiled panels); the gorge's bays there and in the storey under
## the walk, and whatever else of the gorge stands where the ledge and its
## piers go, are cleared when the area loads (the plan's "claims").
##
## A balustrade runs along the front and across both ends (stopping short of
## the face; an invisible guard keeps you off the face's sills), with square
## newels at its joints and lamp posts on some. Connectors: one on each bay's
## front (a span across), one at each end (a stair along the cliff); the
## planner opens the ones it joins. A slot with a door (step 5) has it in
## the ledge's middle bay: gorge_bay_doorway, the guard open in front of it,
## and a THRESHOLD_<area> connector in the face (-Z into the cliff).
##
## Output (at, solve): a plan in the ledge's frame (cell i spans x 4i..4i+4,
## z 0..-4, -Z out over the gorge), built by ChasmGrammar.build_room.

## The ledge's length in bays (seeded in range, as the slot allows).
@export var bays: Vector2i = Vector2i(2, 5):
	set(value):
		bays = value
		emit_changed()
## Facade bays behind the ledge: a window, else a tiled panel, else plain.
@export_range(0.0, 1.0, 0.01) var window_chance: float = .6:
	set(value):
		window_chance = value
		emit_changed()
@export_range(0.0, 1.0, 0.01) var panel_chance: float = .25:
	set(value):
		panel_chance = value
		emit_changed()
## A window's lamp beside it, this often.
@export_range(0.0, 1.0, 0.01) var wall_lamp_chance: float = .4:
	set(value):
		wall_lamp_chance = value
		emit_changed()
## For where piers stand cleanly (ChasmGrammar.pier_under).
@export var chasm: ChasmGrammar:
	set(value):
		chasm = value
		emit_changed()

const MOD: String = "res://kit/modules/"
const BAY: float = 4.0
## The walk slab's faience fascia (the kit ledge's), and the slab and fascia
## together under the walk.
const FASCIA: float = .3
const UNDER: float = .75
## A console's courses under the fascia: (depth out from the face, height),
## top down; CONSOLE_W wide.
const CONSOLE: Array[Vector2] = [Vector2(3.7, .5), Vector2(2.9, .6), Vector2(2.1, .6), Vector2(1.3, .7), Vector2(.6, .85)]
const CONSOLE_W: float = .7
## The end balustrades stop this far from the face (clear of the face's
## window frames); the guard covers the gap.
const END_GAP: float = .85
const GUARD_DEPTH: float = .6
## The guard's gap in front of a door (along its bay): the doorway's lit card.
const DOOR_GAP := Vector2(.7, 3.3)
## Headroom over the walk kept to the ledge.
const HEADROOM: float = 3.6
## A bay's pier, 1.6 m square, from under its corbel (the kit ledge's
## stepped pendant: COURSES, top down, width and height) to where it stands
## cleanly, at the first of PIER_OFFSETS (along the bay, out from the face)
## where one does.
const PIER: float = 1.6
const COURSES: Array[Vector2] = [Vector2(2.6, .4), Vector2(1.6, .5), Vector2(.8, .65)]
const PIER_OFFSETS: Array[Vector2] = [Vector2(0, 0), Vector2(.6, 0), Vector2(-.6, 0), Vector2(0, -.6), Vector2(0, .6), Vector2(.6, -.6), Vector2(-.6, -.6)]
## Where piers stand, once a session: point -> ChasmGrammar.pier_under's answer.
static var _pier_cache: Dictionary = {}


func layout(_grid: CellGrid, _seed_value: int) -> void:
	pass     # a ledge isn't laid out on a CellGrid: AreaPlanner places it


## The ledge on `slot` for a seed: its length and place along the slot
## seeded. See at().
func solve(slot: FrontageSlot, seed_value: int, open: Array = []) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, slot.id, "ledge"])
	var n: int = rng.randi_range(bays.x, mini(bays.y, slot.width))
	if n < bays.x:
		return {"ok": false, "why": "slot %s is too short" % slot.id, "slot": slot.id}
	return at(slot, rng.randi_range(0, slot.width - n), n, seed_value, open)


## The ledge of n bays from bay `first` of `slot`, its connectors in `open`
## left open (joined). {ok, why, slot, first, bays, xf (the ledge's frame in
## the area), pieces, piers, joints, lamps, connectors {name: xf}, walk,
## boxes, claims, slabs, rails, blocks, guards} (all but xf in the ledge's
## frame). Deterministic: called again with the joined connectors, it gives
## the same ledge.
func at(slot: FrontageSlot, first: int, n: int, seed_value: int, open: Array = []) -> Dictionary:
	var xf: Transform3D = slot.xf * Transform3D(Basis(), Vector3(first * BAY, 0, 0))
	var out: Dictionary = {"ok": true, "why": "", "slot": slot.id, "first": first, "bays": n, "xf": xf,
		"pieces": [], "piers": [], "joints": [], "lamps": [], "falls": [], "connectors": {}, "walk": [], "boxes": [], "claims": []}
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, slot.id, first, "facade"])
	var w: float = n * BAY
	var door_bay: int = n / 2 if slot.door != "" else -1
	var deep: float = 0.0
	for c: Vector2 in CONSOLE:
		deep += c.y
	ChasmMasonry.slab(out, PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, -BAY), Vector2(0, -BAY)]), 0.0, FASCIA)
	for i: int in n:
		var at_x: float = i * BAY
		(out["walk"] as Array).append(Vector3(at_x + 2, 0, -2))
		var front := StringName("SNAP_front_%d" % i)
		out["connectors"][front] = Transform3D(Basis(), Vector3(at_x + 2, 0, -BAY))
		if not open.has(front):
			_piece(out, "walls/chasm_parapet_4m", Transform3D(Basis(), Vector3(at_x, 0, 0)) * ChasmGrammar._cell_edge(2))
		(out["joints"] as Array).append(Vector3(at_x, 0, -BAY + .18))
		(out["joints"] as Array).append(Vector3(at_x + BAY, 0, -BAY + .18))
		# The face behind: the slot's door (its middle bay), a window (with its
		# lamp, some), a tiled panel, or plain.
		var bay := Transform3D(Basis(Vector3.UP, PI), Vector3(at_x + BAY, 0, 0))
		var pick: float = rng.randf()
		if i == door_bay:
			_piece(out, "walls/gorge_bay_doorway", bay)
			out["connectors"][StringName("THRESHOLD_" + slot.door)] = Transform3D(Basis(Vector3.UP, PI), Vector3(at_x + BAY * .5, 0, 0))
			out["door"] = slot.door
		elif pick < window_chance:
			_piece(out, "walls/gorge_bay_window", bay)
			if rng.randf() < wall_lamp_chance:
				_piece(out, "dressing/gorge_lamp", Transform3D(bay.basis, bay * Vector3(3.62, 2.76, .42)))
		elif pick < window_chance + panel_chance:
			_piece(out, "walls/gorge_bay_panel", bay)
	# Each bay on a pier where one stands cleanly (a corbel over it, as the
	# Overlook's ledge), and consoles where one doesn't: at each joint (or
	# just in from an end) beside a bay with no pier.
	var held: Dictionary = _piers(xf, n)
	for i: int in held:
		var p: Vector3 = held[i]       # the pier's top middle (ledge frame), its foot in y
		var y: float = -UNDER
		for c: Vector2 in COURSES:
			ChasmMasonry.block(out, Vector3(p.x, y - c.y * .5, p.z), Vector3(c.x, c.y, c.x))
			y -= c.y
		if y - p.y > .1:
			(out["piers"] as Array).append({"at": Vector3(p.x, (y + p.y) * .5, p.z), "size": Vector3(PIER, y - p.y, PIER)})
			(out["boxes"] as Array).append(AABB(Vector3(p.x - PIER * .5, p.y, p.z - PIER * .5), Vector3(PIER, y - p.y, PIER)))
			(out["claims"] as Array).append({"at": Vector3(p.x, (y + p.y) * .5, p.z), "size": Vector3(PIER, y - p.y, PIER)})
	for k: int in n + 1:
		if (k == 0 or held.has(k - 1)) and (k == n or held.has(k)):
			continue
		var x: float = clampf(k * BAY, CONSOLE_W * .5 + .1, w - CONSOLE_W * .5 - .1)
		var y: float = -UNDER
		for c: Vector2 in CONSOLE:
			ChasmMasonry.block(out, Vector3(x, y - c.y * .5, -c.x * .5), Vector3(CONSOLE_W, c.y, c.x))
			y -= c.y
	(out["boxes"] as Array).append(AABB(Vector3(0, -UNDER - deep, -BAY), Vector3(w, UNDER + deep + HEADROOM, BAY)))
	# The ends: a balustrade from the front's corner back toward the face, or
	# a connector along the cliff.
	var ends: Dictionary = {&"SNAP_end_l": [0.0, PI * .5, .18], &"SNAP_end_r": [w, -PI * .5, w - .18]}
	for name: StringName in ends:
		var e: Array = ends[name]
		out["connectors"][name] = Transform3D(Basis(Vector3.UP, e[1]), Vector3(e[0], 0, -2))
		if not open.has(name):
			ChasmMasonry.rail(out, Vector3(e[2], 0, -BAY + .18), Vector3(e[2], 0, -END_GAP))
			(out["joints"] as Array).append(Vector3(e[2], 0, -END_GAP))
	# Lamp posts: the front's two corners and every other joint between.
	for i: int in range(0, n + 1, 2):
		(out["lamps"] as Array).append(Vector3(i * BAY, 0, -BAY + .18))
	if n % 2 == 1:
		(out["lamps"] as Array).append(Vector3(w, 0, -BAY + .18))
	# The guard off the face's sills, but in front of the door.
	var spans: Array[Vector2] = [Vector2(0, w)]
	if door_bay >= 0:
		spans = [Vector2(0, door_bay * BAY + DOOR_GAP.x), Vector2(door_bay * BAY + DOOR_GAP.y, w)]
	for s: Vector2 in spans:
		if s.y - s.x > .05:
			ChasmMasonry.guard(out, Vector3((s.x + s.y) * .5, 1.0, -GUARD_DEPTH * .5), Vector3(s.y - s.x, 3.0, GUARD_DEPTH))
	# What of the gorge clears off: the storey of faces behind (its bays, their
	# lamps), the storey under the walk where the consoles go, and whatever
	# stands where the walk and its headroom are.
	(out["claims"] as Array).append({"at": Vector3(w * .5, 2.0, -1.7), "size": Vector3(w - .2, 3.8, 4.6)})
	(out["claims"] as Array).append({"at": Vector3(w * .5, -2.0, -1.7), "size": Vector3(w - .2, 3.8, 4.6)})
	return out


func _piece(out: Dictionary, path: String, xf: Transform3D) -> void:
	(out["pieces"] as Array).append({"scene": MOD + path + ".tscn", "xf": xf})


## The bays whose piers stand cleanly: {i: the pier's top middle (ledge
## frame, under its corbel), with its foot as y}.
func _piers(xf: Transform3D, n: int) -> Dictionary:
	var c: ChasmGrammar = chasm if chasm != null else load("res://gen/grammars/r10_chasm.tres")
	var top: float = -UNDER
	for course: Vector2 in COURSES:
		top -= course.y
	var out: Dictionary = {}
	c.clears_dressing = true      # what a pier meets on a terrace is cleared (claims)
	for i: int in n:
		for off: Vector2 in PIER_OFFSETS:
			var local := Vector3(i * BAY + 2.0 + off.x, top, -2.0 + off.y)
			var p: Vector3 = xf * local
			var key: Vector3 = p.snapped(Vector3.ONE * .01)
			if not _pier_cache.has(key):
				_pier_cache[key] = c.pier_under(p, Vector2.ONE * PIER * .5)
			var r: Dictionary = _pier_cache[key]
			if not r.is_empty():
				out[i] = Vector3(local.x, float(r["foot"]) - xf.origin.y, local.z)
				break
	c.clears_dressing = false
	return out

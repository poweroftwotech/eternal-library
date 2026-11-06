@tool
class_name StackGalleryGrammar
extends RoomGrammar
## R02 Stack Gallery (design/room-atlas.html; ENVIRONMENT_PLAN.md 5.5.4): a
## corridor one bay wide, walls of shelf recesses under a barrel vault, lamps
## every few bays. The run walks the grid from the entry door and turns left or
## right; a corner cell takes a groin vault (slot cell:ceiling_cross).
##
## The walk never puts a cell beside one of its own (other than the cells it
## joins) or beside the host, so every wall has the corridor on one side only.
##
## Slice 3 features, each rolled on its own key: side passages into one-cell
## alcoves, collapsed bays, lamps on corners with their state by distance from
## the entry, cool fill lights, and an exit door at the far end.

## Total bays on the run, corners included (the seed picks a length in this range).
@export_range(1, 64) var min_bays: int = 6:
	set(value):
		min_bays = value
		emit_changed()
@export_range(1, 64) var max_bays: int = 12:
	set(value):
		max_bays = value
		emit_changed()
## The longest straight stretch (bays between corners, or from the entry):
## the walk turns once it has gone this far. The atlas: "no more than 6
## straight bays without a feature".
@export_range(1, 64) var max_straight_bays: int = 6:
	set(value):
		max_straight_bays = value
		emit_changed()
## No turn until a stretch is at least this long.
@export_range(1, 64) var min_straight_bays: int = 2:
	set(value):
		min_straight_bays = value
		emit_changed()
## Chance to turn at each bay between min_straight_bays and max_straight_bays.
@export_range(0.0, 1.0, 0.01) var turn_chance: float = 0.35:
	set(value):
		turn_chance = value
		emit_changed()
## A lamp hangs on every Nth bay (0 = none).
@export_range(0, 16) var lamp_every_bays: int = 2:
	set(value):
		lamp_every_bays = value
		emit_changed()
## Lamp origin above the floor: lantern_hanging's 1 m chain then meets the
## vault crown (intrados about 6.0 m, barrel and groin alike).
@export var lamp_height: float = 2.0:
	set(value):
		lamp_height = value
		emit_changed()
## Far end: a dead end (wall and gable) or an exit door with a connector for
## a later room.
@export_enum("dead_end", "exit") var end_kind: String = "dead_end":
	set(value):
		end_kind = value
		emit_changed()

@export_group("Features")
## Per bay side: the wall becomes an arch (an `opening` edge) into a one-bay
## dead-end alcove, where the grid has room for one.
@export_range(0.0, 1.0, 0.01) var side_passage_chance: float = 0.11:
	set(value):
		side_passage_chance = value
		emit_changed()
## Chance that an alcove has its own lamp (the atlas mock: 0.6).
@export_range(0.0, 1.0, 0.01) var alcove_lamp_chance: float = 0.6:
	set(value):
		alcove_lamp_chance = value
		emit_changed()
## What an alcove holds (room rework step 2, your walk of 2026-11-02: niches so
## the stacks aren't only corridors), by relative weight: a hearth to sit and
## cook by, a garden bed, a larder with mushrooms on a log, a woven hanging
## (art), or "empty". Each is slot dressing:niche_<kind>.
@export var niche_weights: Dictionary = {"hearth": 1.0, "garden": 1.0, "larder": 1.0, "art": 1.0, "empty": 0.0}:
	set(value):
		niche_weights = value
		emit_changed()
## Per bay: a collapsed bay. Both side walls are shelf recesses pinned to
## "collapsed", with rubble (slot dressing:rubble) along their feet.
@export_range(0.0, 1.0, 0.01) var collapse_chance: float = 0.08:
	set(value):
		collapse_chance = value
		emit_changed()

@export_group("Abandonment")
## Stacks rework (2026-11-04, your proposal "tended near people, abandoned far
## out"): each bay's abandon value (grid.cells[c]["abandon"], 0 kept .. 1
## abandoned) climbs from the room it opens off (grid.meta "abandon_start",
## set by the area planner; a gallery off a gallery carries on from its far
## end) by 1 over this many bays. 0 = off: every bay kept.
@export_range(0, 64) var abandon_over_bays: int = 0:
	set(value):
		abandon_over_bays = value
		emit_changed()
## Below this abandon a shelf recess keeps its own pick (mostly full shelves);
## above it, more and more of them are untidy, then abandoned.
@export_range(0.0, 1.0, 0.01) var untidy_from: float = 0.2:
	set(value):
		untidy_from = value
		emit_changed()
## Share of shelf recesses that hold something else instead (RECESS_VARIETY:
## a tile panel, a sealed door, a wall hearth, herb shelf or pantry).
@export_range(0.0, 1.0, 0.01) var recess_variety: float = 0.12:
	set(value):
		recess_variety = value
		emit_changed()
const RECESS_VARIETY: Dictionary = {"tile panel": 1.0, "sealed door": 0.7, "hearth niche": 0.4, "herb niche": 0.4, "pantry niche": 0.4}

@export_group("Damp and rock")
## Stacks rework part 3 (your note: the stacks are caves carved into solid
## rock; drips and small pools; low fog where abandoned). Share of shelf
## recesses at full abandon where the brick lining has fallen and the rock
## shows ("rock breach", with a rubble strip at its foot).
@export_range(0.0, 1.0, 0.01) var rock_breach_chance: float = 0.0:
	set(value):
		rock_breach_chance = value
		emit_changed()
## Chance a straight bay holds a puddle with drips from the vault, at full
## abandon (it rises from puddle_from).
@export_range(0.0, 1.0, 0.01) var puddle_chance: float = 0.0:
	set(value):
		puddle_chance = value
		emit_changed()
@export_range(0.0, 1.0, 0.01) var puddle_from: float = 0.3:
	set(value):
		puddle_from = value
		emit_changed()
## Part 4: keepers' signs where the stacks are kept (a book cart, a pile of
## books and a cushion), cobwebs and roots where they are not, and a landmark
## or two per gallery (a taghcheh wall, a reading corner). 0 turns each off.
@export_range(0.0, 1.0, 0.01) var keeper_chance: float = 0.0:
	set(value):
		keeper_chance = value
		emit_changed()
@export_range(0.0, 1.0, 0.01) var keeper_until: float = 0.35:
	set(value):
		keeper_until = value
		emit_changed()
@export_range(0.0, 1.0, 0.01) var cobweb_chance: float = 0.0:
	set(value):
		cobweb_chance = value
		emit_changed()
@export_range(0.0, 1.0, 0.01) var roots_chance: float = 0.0:
	set(value):
		roots_chance = value
		emit_changed()
@export var landmarks: bool = false:
	set(value):
		landmarks = value
		emit_changed()
## Low ground fog on every bay at or past this abandon (1.01: none).
@export_range(0.0, 1.01, 0.01) var ground_fog_from: float = 1.01:
	set(value):
		ground_fog_from = value
		emit_changed()
## Collapsed bays happen only out where the stacks are abandoned: the chance is
## collapse_chance scaled by abandon (x2 at 1). Off when abandon_over_bays is 0.

@export_group("Wall lights")
## Stacks rework part 2 (your note: fewer lights hung from the ceiling): no
## lanterns down the corridor. Every wall_light_every-th pier between two bays
## carries a light by the bay's abandon (light:sconce where the stacks are
## kept; light:torch, light:candles or light:stool further in; light:glowcaps,
## spent candles or a guttering torch where they are abandoned), and alcove
## lamps hang from the alcove's vault (lamp origin on the floor: the rules'
## lamp is a cluster of glowing roots).
@export var wall_lights: bool = false:
	set(value):
		wall_lights = value
		emit_changed()
@export_range(1, 8) var wall_light_every: int = 2:
	set(value):
		wall_light_every = value
		emit_changed()
## Chance that a pier between the lit ones has something unlit or small at its
## foot where the stacks are past half abandoned (spent candles, glowcaps).
@export_range(0.0, 1.0, 0.01) var pier_dressing_chance: float = 0.3:
	set(value):
		pier_dressing_chance = value
		emit_changed()
## The cool fills' colour where the stacks are abandoned (fill_colour where
## they are kept): the blue of the far stacks.
@export var fill_colour_far: Color = Color(0.36, 0.62, 0.64):
	set(value):
		fill_colour_far = value
		emit_changed()
## Abandon below which the room's mood tint (blue) is not felt (tint_at).
@export_range(0.0, 1.0, 0.01) var tint_from: float = 0.3:
	set(value):
		tint_from = value
		emit_changed()
## Pier face: how far a pier stands out from the wall line into the corridor.
const PIER_OUT: float = 0.48

@export_group("Lamps")
## Every corner gets a lamp too, as well as every lamp_every_bays-th bay.
@export var lamp_on_corners: bool = true:
	set(value):
		lamp_on_corners = value
		emit_changed()
## Chance that a lamp is lit, by bays from the entry (x, 0 to 12 bays; past
## the end the last value holds): the darkness says how far out you are.
## Empty: 0.9 at the entry falling straight to 0.35 at 12 bays.
@export var lamp_lit_by_distance: Curve:
	set(value):
		if lamp_lit_by_distance != null and lamp_lit_by_distance.changed.is_connected(emit_changed):
			lamp_lit_by_distance.changed.disconnect(emit_changed)
		lamp_lit_by_distance = value
		if lamp_lit_by_distance != null:
			lamp_lit_by_distance.changed.connect(emit_changed)
		emit_changed()
## Of the lamps that are not lit, the share still guttering (failing, a
## flicker) rather than dark.
@export_range(0.0, 1.0, 0.01) var lamp_failing_share: float = 0.3:
	set(value):
		lamp_failing_share = value
		emit_changed()

@export_group("Cool fills")
## A cool, shadowless fill light on every Nth bay (0 = none): the atlas's
## teal archive light, which is all that is left where the lamps are dark.
@export_range(0, 16) var fill_every_bays: int = 3:
	set(value):
		fill_every_bays = value
		emit_changed()
@export var fill_colour: Color = Color(0.36, 0.62, 0.64):
	set(value):
		fill_colour = value
		emit_changed()
@export_range(0.0, 8.0, 0.01) var fill_energy: float = 0.6:
	set(value):
		fill_energy = value
		emit_changed()
@export_range(0.5, 30.0, 0.1) var fill_range: float = 7.0:
	set(value):
		fill_range = value
		emit_changed()
## Fill height above the floor (the vault crown is at about 6.0 m).
@export var fill_height: float = 4.6:
	set(value):
		fill_height = value
		emit_changed()

## Gallery lengths a room can ask for, in bays (min, max). Long is the grammar's own.
const LENGTHS: Dictionary = {"short": Vector2i(3, 4), "medium": Vector2i(5, 7)}

## Walks tried before settling for the longest: a walk can box itself in.
const ATTEMPTS: int = 8


func tweak_fields() -> Array[Dictionary]:
	return [
		{"key": "length", "label": "Length", "tip": "How long the gallery runs (a bay is 4 m).", "options": [
			{"label": "Long (%d-%d bays)" % [min_bays, max_bays], "value": ""},
			{"label": "Medium (%d-%d bays)" % [LENGTHS["medium"].x, LENGTHS["medium"].y], "value": "medium"},
			{"label": "Short (%d-%d bays)" % [LENGTHS["short"].x, LENGTHS["short"].y], "value": "short"}]},
		{"key": "abandon_start", "label": "Starts at", "tip": "How abandoned the first bay is, 0 kept to 1 abandoned. Blank: carries on from the room before.",
			"default": "carry on", "min": 0.0, "max": 1.0},
		{"key": "abandon_over_bays", "label": "Bays to abandoned", "tip": "Bays from kept to fully abandoned: fewer decays faster.",
			"default": abandon_over_bays, "min": 1, "max": 64},
		{"key": "tint", "label": "Blue strength", "tip": "How blue the far stacks turn, 0 none to 1 fully.", "default": mood_tint.a, "min": 0.0, "max": 1.0},
		{"key": "tint_from", "label": "Blue from", "tip": "The abandon value where the blue begins.", "default": tint_from, "min": 0.0, "max": 1.0},
		{"key": "ground_fog_from", "label": "Fog from", "tip": "The abandon value where ground fog begins. Above 1: no fog.", "default": ground_fog_from, "min": 0.0, "max": 1.01},
		{"key": "decay", "label": "Decay", "tip": "Scales rock breaks, puddles, cobwebs and roots: 0 none, 1 as usual, 3 the most.", "default": 1.0, "min": 0.0, "max": 3.0},
	]


func tweaked(tweaks: Dictionary) -> RoomGrammar:
	if tweaks.is_empty():
		return self
	var g: StackGalleryGrammar = duplicate(false)
	g.set_meta("source_path", source_path())
	if LENGTHS.has(str(tweaks.get("length", ""))):
		var bays: Vector2i = LENGTHS[str(tweaks["length"])]
		g.min_bays = bays.x
		g.max_bays = bays.y
	if tweaks.has("abandon_over_bays"):
		g.abandon_over_bays = int(tweaks["abandon_over_bays"])
	if tweaks.has("tint"):
		var strength: float = float(tweaks["tint"])
		# The fills turn blue with the air, so no blue means none from them either.
		g.fill_colour_far = fill_colour.lerp(fill_colour_far, clampf(strength / maxf(mood_tint.a, 0.01), 0.0, 1.0))
		g.mood_tint = Color(mood_tint, strength)
	if tweaks.has("tint_from"):
		g.tint_from = float(tweaks["tint_from"])
	if tweaks.has("ground_fog_from"):
		g.ground_fog_from = float(tweaks["ground_fog_from"])
	if tweaks.has("decay"):
		var k: float = float(tweaks["decay"])
		g.rock_breach_chance = clampf(rock_breach_chance * k, 0.0, 1.0)
		g.puddle_chance = clampf(puddle_chance * k, 0.0, 1.0)
		g.cobweb_chance = clampf(cobweb_chance * k, 0.0, 1.0)
		g.roots_chance = clampf(roots_chance * k, 0.0, 1.0)
	return g


func layout(grid: CellGrid, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, "length"])
	var want: int = rng.randi_range(mini(min_bays, max_bays), maxi(min_bays, max_bays))
	var best: Array = []
	for attempt: int in ATTEMPTS:
		var path: Array = walk(grid, want, hash([seed_value, "layout", attempt]))
		if path.size() > best.size():
			best = path
		if best.size() >= want:
			break
	if best.size() < mini(min_bays, max_bays) and not grid.quiet:
		push_warning("StackGalleryGrammar: the run stops after %d bays (min_bays %d): the space is boxed in" % [best.size(), min_bays])
	mark(grid, best, seed_value)


## One walk from the entry; returns [[cell, dir], ...], where dir is the
## direction the run leaves the cell (into the next cell, or past the end).
func walk(grid: CellGrid, want: int, seed_value: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var taken: Dictionary = {}
	var start := Vector3i.ZERO
	if not grid.is_free(start):
		return []
	var dir := Vector3i(0, 0, 1)
	var path: Array = [[start, dir]]
	taken[start] = true
	var straight: int = 1          # bays in the current stretch
	while path.size() < want:
		var cur: Vector3i = path[-1][0]
		var next: Vector3i = cur + dir
		var may_turn: bool = straight >= min_straight_bays
		var must_turn: bool = straight >= max_straight_bays
		var turn: bool = must_turn or (may_turn and rng.randf() < turn_chance)
		if turn and path.size() + 1 >= want:
			# A corner would be the last bay. A free turn waits; a forced one takes
			# one more bay past the corner if max_bays allows, else the run ends.
			if not must_turn:
				turn = false
			elif want < max_bays:
				want += 1
			else:
				break
		if not turn and not fits(grid, taken, next, cur):
			turn = may_turn         # blocked ahead: turn if the rules allow, else stop
			if not turn or path.size() + 1 >= want:
				break
		if not turn:
			path.append([next, dir])
			taken[next] = true
			straight += 1
			continue
		if not may_turn:
			break                   # must turn before it may (min > max): stop here
		# The next cell becomes the corner; the run leaves it to one side.
		var sides: Array[Vector3i] = [Vector3i(-dir.z, 0, dir.x), Vector3i(dir.z, 0, -dir.x)]
		if rng.randf() < 0.5:
			sides.reverse()
		var turned: bool = false
		for side: Vector3i in sides:
			if fits(grid, taken, next, cur) and fits(grid, taken.merged({next: true}), next + side, next):
				path.append([next, side])
				taken[next] = true
				dir = side
				straight = 0
				turned = true
				break
		if not turned:
			break
	return path


## True if `c` can join the run after `prev`: free of the host, and no cell
## of the run (or the host) beside it except `prev`.
func fits(grid: CellGrid, taken: Dictionary, c: Vector3i, prev: Vector3i) -> bool:
	if taken.has(c) or not grid.is_free(c):
		return false
	for side: int in CellGrid.ALL_SIDES:
		var n: Vector3i = CellGrid.neighbour(c, side)
		if n == prev:
			continue
		if taken.has(n) or not grid.is_free(n):
			return false
	return true


## Cells, edges, features and lamps for a walked path. Every feature roll is
## keyed by what it decides (seed, feature, cell, side), so changing one knob
## leaves the other features where they were.
func mark(grid: CellGrid, path: Array, seed_value: int) -> void:
	if path.is_empty():
		return
	var taken: Dictionary = {}
	for i: int in path.size():
		var c: Vector3i = path[i][0]
		var out: Vector3i = path[i][1]
		var into: Vector3i = Vector3i(0, 0, 1) if i == 0 else path[i - 1][1]
		var corner: bool = out != into
		grid.add_cell(c, "corner" if corner else "floor", Vector3i.ZERO if corner else out.abs(), i)
		taken[c] = true
	var start: float = float(grid.meta.get("abandon_start", 0.0))
	for i: int in path.size():
		grid.cells[path[i][0]]["abandon"] = abandon_at(start, i)
	if abandon_over_bays > 0:
		grid.meta["abandon_end"] = abandon_at(start, path.size())
	var exit_side: int = exit_side_for(grid, path, taken)
	if exit_side >= 0:
		taken[CellGrid.neighbour(path[-1][0], exit_side)] = true    # kept free for the next room
	for i: int in path.size():
		var c: Vector3i = path[i][0]
		for side: int in CellGrid.ALL_SIDES:
			var n: Vector3i = CellGrid.neighbour(c, side)
			if i == 0 and side == CellGrid.Side.S:
				grid.set_edge(c, side, CellGrid.Mark.DOOR, not grid.root)
			elif (i > 0 and n == path[i - 1][0]) or (i + 1 < path.size() and n == path[i + 1][0]):
				grid.set_edge(c, side, CellGrid.Mark.OPEN)
			elif i + 1 == path.size() and side == exit_side:
				grid.set_edge(c, side, CellGrid.Mark.DOOR)
			else:
				grid.set_edge(c, side, CellGrid.Mark.SOLID, false, inner_corner(path, i, side))
	if exit_side >= 0:
		# Until a room joins here (phase 4), the exit shows a lit room beyond and
		# blocks the way (slot stub:exit, in the door connector's frame).
		grid.props["exit_" + CellGrid.key(path[-1][0], exit_side)] = {"slot": "stub:exit",
			"xf": CellGrid.door_transform(path[-1][0], exit_side)}
	var behind: Dictionary = {}     # cells an alcove's back wall faces
	for i: int in range(1, path.size()):
		add_alcoves(grid, path[i][0], taken, behind, seed_value)
	for i: int in range(1, path.size()):
		maybe_collapse(grid, path[i][0], seed_value)
	add_landmarks(grid, seed_value)
	neglect_shelves(grid, seed_value)
	place_lamps(grid, seed_value)
	place_fills(grid)
	add_keepers(grid, seed_value)
	add_damp(grid, seed_value)


## The side of the last bay that becomes the exit door: straight on if a room
## could be built there, else either side; -1 for a dead end.
func exit_side_for(grid: CellGrid, path: Array, taken: Dictionary) -> int:
	if (grid.end_kind if grid.end_kind != "" else end_kind) != "exit":
		return -1
	var last: Vector3i = path[-1][0]
	var dir: Vector3i = path[-1][1]
	for d: Vector3i in [dir, Vector3i(-dir.z, 0, dir.x), Vector3i(dir.z, 0, -dir.x)]:
		if fits(grid, taken, last + d, last):
			return side_of(d)
	if not grid.quiet:
		push_warning("StackGalleryGrammar: no room for an exit beyond bay %d; the run ends in a dead end" % (path.size() - 1))
	return -1


## The two walls of a straight bay (across its barrel), or none for a corner.
static func side_walls(grid: CellGrid, c: Vector3i) -> Array[int]:
	var run: Vector3i = grid.cells[c]["run"]
	var out: Array[int] = []
	if run.x != 0:
		out.assign([CellGrid.Side.S, CellGrid.Side.N])
	elif run.z != 0:
		out.assign([CellGrid.Side.W, CellGrid.Side.E])
	return out


## Side passages: a plain solid side wall of a straight bay may open (an arch,
## edge mark `opening`) into a one-cell alcove, if nothing else of the room is
## beside that cell. The alcove's barrel runs out from the bay, so its vault
## ends (and takes a gable) at the arch and at its back wall. Its two side
## walls meet the corridor's wall line, so they ask for edge:solid_corner.
## Two alcoves never back onto the same cell (`behind`): their back walls'
## shelf recesses would meet in its corner (Lower Stacks seed 3).
func add_alcoves(grid: CellGrid, c: Vector3i, taken: Dictionary, behind: Dictionary, seed_value: int) -> void:
	if grid.cells[c]["kind"] != "floor":
		return
	for side: int in side_walls(grid, c):
		var e: Dictionary = grid.edge(c, side)
		if e["mark"] != CellGrid.Mark.SOLID or e["slot"] != "":
			continue
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([seed_value, "passage", CellGrid.cell_name(c), side])
		if rng.randf() >= side_passage_chance:
			continue
		var a: Vector3i = CellGrid.neighbour(c, side)
		if not fits(grid, taken, a, c):
			continue
		var out: Vector3i = a - c
		if behind.has(a + out):
			continue
		behind[a + out] = true
		taken[a] = true
		grid.add_cell(a, "alcove", out.abs(), grid.cells[c]["bay"])
		grid.set_edge(c, side, CellGrid.Mark.OPENING)
		var niche: String = pick_niche(rng)
		# A niche's back wall is plain brick (no door or shelves behind a fire).
		var back_slot: String = "edge:plain" if niche != "" else ""
		for s: int in CellGrid.ALL_SIDES:
			var n: Vector3i = CellGrid.neighbour(a, s)
			if n == c:
				continue
			grid.set_edge(a, s, CellGrid.Mark.SOLID, false, back_slot if n == a + out else "edge:solid_corner")
		if niche != "":
			# No seam debris at the feet of a niche's walls: it would land in the furniture.
			for s: int in CellGrid.ALL_SIDES:
				if CellGrid.neighbour(a, s) != c:
					grid.pins["edge_" + CellGrid.key(a, s)] = "nothing"
			# Local -Z toward the alcove's back wall (grid +z is room -Z).
			var back := Vector3(out.x, 0, -out.z)
			grid.props["niche_" + CellGrid.cell_name(a)] = {"slot": "dressing:niche_" + niche,
				"xf": Transform3D(Basis.looking_at(back), CellGrid.cell_centre(a))}
			if niche == "hearth":
				grid.cells[a]["blocked"] = true     # its fire stands mid-alcove: walks stop short of it
		# A hearth's fire and an art niche's tray lamp light their niche; the
		# garden and the larder hang a lamp (plants grow by light, and you need
		# to see the mushrooms); an empty alcove may have one.
		if niche in ["garden", "larder"] or (niche == "" and rng.randf() < alcove_lamp_chance):
			grid.lamps[a] = 0.0 if wall_lights else lamp_height
			if niche != "":
				grid.pins["lamp_" + CellGrid.cell_name(a)] = "lit"     # a niche is kept: place_lamps leaves it lit


## The niche an alcove holds (room rework step 2), by niche_weights; "" for
## none (the empty dead end it was before).
func pick_niche(rng: RandomNumberGenerator) -> String:
	var total: float = 0.0
	for k: String in niche_weights:
		total += float(niche_weights[k])
	var roll: float = rng.randf() * total
	for k: String in niche_weights:
		roll -= float(niche_weights[k])
		if roll < 0.0:
			return "" if k == "empty" else k
	return ""


## A collapsed bay: a straight bay whose two side walls are both plain solid
## walls (no alcove, door or inner corner). They ask for edge:recess (a shelf
## recess, never a blank wall) and pin it to "collapsed"; a rubble strip lies
## along each one (dressing:rubble, placed on the wall line like the wall).
func maybe_collapse(grid: CellGrid, c: Vector3i, seed_value: int) -> void:
	if grid.cells[c]["kind"] != "floor":
		return
	var walls: Array[int] = side_walls(grid, c)
	for side: int in walls:
		var e: Dictionary = grid.edge(c, side)
		if e["mark"] != CellGrid.Mark.SOLID or e["slot"] != "":
			return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, "collapse", CellGrid.cell_name(c)])
	var chance: float = collapse_chance if abandon_over_bays <= 0 else collapse_chance * 2.0 * float(grid.cells[c].get("abandon", 0.0))
	if rng.randf() >= chance:
		return
	grid.cells[c]["kind"] = "collapsed"
	for side: int in walls:
		var k: String = CellGrid.key(c, side)
		grid.edges[k]["slot"] = "edge:recess"
		grid.pins["edge_" + k] = "collapsed"
		grid.props["rubble_" + k] = {"slot": "dressing:rubble", "xf": CellGrid.edge_transform(c, side)}


## Stacks rework part 2 (your note: a slight blue tint where the stacks feel
## abandoned): mood_tint eases in with the abandon of the bay you stand in,
## from nothing at tint_from to all of it at 1.
func tint_at(grid: CellGrid, local: Vector3) -> Color:
	if abandon_over_bays <= 0 or grid == null:
		return mood_tint
	var c := Vector3i(floori(local.x / CellGrid.BAY), 0, floori(-local.z / CellGrid.BAY))
	var a: float = float(grid.cells[c].get("abandon", 0.0)) if grid.cells.has(c) else 0.0
	return Color(mood_tint.r, mood_tint.g, mood_tint.b, mood_tint.a * smoothstep(tint_from, 1.0, a))


## abandon at bay i of a run that starts at `start`.
func abandon_at(start: float, i: int) -> float:
	if abandon_over_bays <= 0:
		return 0.0
	return clampf(start + float(i) / float(abandon_over_bays), 0.0, 1.0)


## Every shelf recess (a solid wall with no slot yet, which the rules fill
## with a shelf recess or plain brick) is pinned to a tall bookcase filling
## the arch: "stack shelves" where the stacks are kept, then more and more
## "untidy shelves" and "abandoned shelves" by a roll against the bay's
## abandon past untidy_from, so the change is gradual and every seed differs;
## recess_variety of them hold something else. Pins on a plain wall match
## nothing and are harmless.
func neglect_shelves(grid: CellGrid, seed_value: int) -> void:
	if abandon_over_bays <= 0:
		return
	for c: Vector3i in grid.cells:
		var a: float = float(grid.cells[c].get("abandon", 0.0))
		for side: int in CellGrid.ALL_SIDES:
			var k: String = CellGrid.key(c, side)
			if not grid.edges.has(k) or grid.edges[k]["mark"] != CellGrid.Mark.SOLID or grid.pins.has("edge_" + k):
				continue
			if grid.edges[k]["slot"] not in ["", "edge:recess"]:
				continue
			var rng := RandomNumberGenerator.new()
			rng.seed = hash([seed_value, "neglect", k])
			if rng.randf() < recess_variety:
				grid.pins["edge_" + k] = _pick(rng, RECESS_VARIETY)
				continue
			var t: float = maxf(0.0, a - untidy_from) / (1.0 - untidy_from)     # 0 .. 1 past the threshold
			if rng.randf() < cobweb_chance * smoothstep(0.55, 1.0, a) and grid.cells[c]["kind"] == "floor":
				grid.pins["edge_" + k] = "webbed shelves"
				grid.edges[k]["slot"] = "edge:recess"     # a shelf recess, never a plain wall
				continue
			# Not across from a reading corner: its rubble strip would spill under the bench.
			if rng.randf() < rock_breach_chance * t * t and grid.cells[c]["kind"] == "floor" \
					and grid.cells[c].get("landmark", "") != "reading":
				grid.pins["edge_" + k] = "rock breach"
				grid.edges[k]["slot"] = "edge:recess"
				grid.props["rubble_" + k] = {"slot": "dressing:rubble", "xf": CellGrid.edge_transform(c, side)}
				continue
			var r: float = rng.randf()
			if r < t * t:
				grid.pins["edge_" + k] = "abandoned shelves"
			elif r < minf(1.0, t * 1.6):
				grid.pins["edge_" + k] = "untidy shelves"
			else:
				grid.pins["edge_" + k] = "stack shelves"


## Weighted pick from {label: weight}.
static func _pick(rng: RandomNumberGenerator, weights: Dictionary) -> String:
	var total: float = 0.0
	for k: String in weights:
		total += float(weights[k])
	var roll: float = rng.randf() * total
	for k: String in weights:
		roll -= float(weights[k])
		if roll < 0.0:
			return k
	return weights.keys()[-1]


## Lamps on every lamp_every_bays-th bay of the run and on every corner
## (alcove lamps come with the alcove), then each one's state by its distance
## from the entry (lamp_lit_by_distance), pinned through grid.pins so the
## grammar never reaches inside the lamp's socket.
func place_lamps(grid: CellGrid, seed_value: int) -> void:
	if wall_lights:
		place_wall_lights(grid, seed_value)
	for c: Vector3i in (grid.run_order() if not wall_lights else [] as Array[Vector3i]):
		var i: int = grid.cells[c]["bay"]
		var every: bool = lamp_every_bays > 0 and i % lamp_every_bays == lamp_every_bays - 1
		if every or (lamp_on_corners and grid.cells[c]["kind"] == "corner"):
			grid.lamps[c] = lamp_height
	for c: Vector3i in grid.lamps:
		if grid.pins.get("lamp_" + CellGrid.cell_name(c), "") == "lit" and grid.props.has("niche_" + CellGrid.cell_name(c)):
			continue
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([seed_value, "lamp_lit", CellGrid.cell_name(c)])
		var state: String = "lit"
		if rng.randf() >= lit_chance(grid.cells[c]["bay"]):
			state = "failing" if rng.randf() < lamp_failing_share else "dark"
		grid.pins["lamp_" + CellGrid.cell_name(c)] = state


## The piers between consecutive bays of a straight stretch: on every
## wall_light_every-th one, a light by the bay's abandon, on the two walls in
## turn; on the others, now and then, spent candles or glowcaps at the foot
## where the stacks are past half abandoned. Each light's state is pinned
## (lit, failing or dark) by a roll against its abandon.
func place_wall_lights(grid: CellGrid, seed_value: int) -> void:
	var order: Array[Vector3i] = grid.run_order()
	# Bays beside a light of their own (glow roots in an alcove, a niche's fire
	# or tray lamp): no flame on the piers next to them, so the plant shines
	# through (walk 2 of part 2).
	var glow_bays: Dictionary = {}
	for c: Vector3i in grid.cells:
		if (grid.cells[c]["kind"] == "alcove" and (grid.lamps.has(c) or grid.props.has("niche_" + CellGrid.cell_name(c)))) \
				or grid.cells[c].get("landmark", "") == "reading":     # a reading corner has its table lamp
			glow_bays[int(grid.cells[c]["bay"])] = true
	var turn: int = 0
	for i: int in order.size() - 1:
		var c: Vector3i = order[i]
		var nxt: Vector3i = order[i + 1]
		if grid.cells[c]["kind"] == "corner" or grid.cells[nxt]["kind"] == "corner":
			continue
		var walls: Array[int] = side_walls(grid, c)
		if walls.size() < 2:
			continue
		var a: float = float(grid.cells[c].get("abandon", 0.0))
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([seed_value, "wall_light", CellGrid.cell_name(c)])
		# Every wall_light_every-th pier, on the two walls in turn: pools of
		# light with shadow between (walk 2: "too many artificial lights").
		var lit: bool = i % wall_light_every == wall_light_every - 1
		var b: int = int(grid.cells[c]["bay"])
		var near_glow: bool = glow_bays.has(b - 1) or glow_bays.has(b) or glow_bays.has(b + 1) or glow_bays.has(b + 2)
		var side: int = walls[turn % 2]
		if lit:
			turn += 1
		var at_side: int = -1
		for s: int in [side, walls[0] if side == walls[1] else walls[1]]:
			if grid.edge(c, s)["mark"] != CellGrid.Mark.OPEN and grid.edge(nxt, s)["mark"] != CellGrid.Mark.OPEN:
				at_side = s
				break
		if at_side < 0:
			continue
		var kind: String = ""
		var r: float = rng.randf()
		if lit:
			if a < 0.3:
				kind = "sconce"
			elif a < 0.65:
				kind = "torch" if r < 0.55 else ("candles" if r < 0.85 else "stool")
			else:
				kind = "glowcaps" if r < 0.6 else ("torch" if r < 0.75 else "candles_spent")
		elif a > 0.5 and r < pier_dressing_chance:
			kind = "glowcaps" if rng.randf() < 0.4 * a else "candles_spent"
		# Where the stacks turn blue, the blue has a source (walk 3): a fill bay
		# without a flame grows glowcaps, and the fill sits at them.
		if (kind == "" or kind == "candles_spent") and a >= tint_from and fill_every_bays > 0 \
				and int(grid.cells[c]["bay"]) % fill_every_bays == fill_every_bays - 1:
			kind = "glowcaps"
		if near_glow and kind in ["sconce", "torch", "candles", "stool", "candles_spent"]:
			kind = ""
		if kind == "":
			continue
		var centre: Vector3 = CellGrid.cell_centre(c)
		var out: Vector3 = (CellGrid.cell_centre(CellGrid.neighbour(c, at_side)) - centre).normalized()
		var along: Vector3 = (CellGrid.cell_centre(nxt) - centre).normalized()
		var at: Vector3 = centre + out * (CellGrid.BAY * 0.5 - PIER_OUT) + along * CellGrid.BAY * 0.5
		var key: String = "light_" + CellGrid.cell_name(c)
		grid.props[key] = {"slot": "light:" + kind, "xf": Transform3D(Basis.looking_at(-out), at)}
		if kind in ["sconce", "torch", "candles", "stool"]:
			var state: String = "lit"
			var keep: float = lerpf(1.0, 0.7, a)     # spooky, never pitch dark
			if rng.randf() >= keep:
				state = "failing" if rng.randf() < lamp_failing_share else "dark"
			grid.pins["prop_" + key] = state
		elif kind == "glowcaps":
			grid.pins["prop_" + key] = "lit"     # fungus glows steadily, never flickers out


## Recess front: how far from a bay's centre a shelf recess's front stands.
const RECESS_FRONT: float = 1.78


## A floor bay's plain shelf-recess walls (solid, nothing pinned or placed
## there yet), in side order.
func recess_walls(grid: CellGrid, c: Vector3i) -> Array[int]:
	var out: Array[int] = []
	if grid.cells[c]["kind"] != "floor":
		return out
	for side: int in side_walls(grid, c):
		var k: String = CellGrid.key(c, side)
		var e: Dictionary = grid.edge(c, side)
		if e["mark"] == CellGrid.Mark.SOLID and e["slot"] in ["", "edge:recess"] and not grid.pins.has("edge_" + k):
			out.append(side)
	return out


## Facing the corridor from in front of side `side`'s recess, `d` metres out
## from the recess front (prop frame: +X along the wall, -Z into the corridor).
func front_xf(c: Vector3i, side: int, d: float) -> Transform3D:
	var centre: Vector3 = CellGrid.cell_centre(c)
	var out: Vector3 = (CellGrid.cell_centre(CellGrid.neighbour(c, side)) - centre).normalized()
	return Transform3D(Basis.looking_at(-out), centre + out * (RECESS_FRONT - d))


## Part 4 landmarks, one of each per gallery where it fits (seeded): a
## taghcheh wall on a recess where the stacks are still kept or half kept, and
## a reading corner (bench, low table with its lamp, rug) in a kept bay. A
## reading corner's bay is marked "landmark", so no flame stands beside its lamp.
func add_landmarks(grid: CellGrid, seed_value: int) -> void:
	if not landmarks or abandon_over_bays <= 0:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, "landmarks"])
	var tag: Array = []
	var read: Array = []
	for c: Vector3i in grid.run_order():
		var a: float = float(grid.cells[c].get("abandon", 0.0))
		var walls: Array[int] = recess_walls(grid, c)
		if walls.is_empty() or int(grid.cells[c]["bay"]) < 1:
			continue
		for side: int in walls:
			if a <= 0.8:
				tag.append([c, side])
			if a <= 0.45:
				read.append([c, side])
	if not tag.is_empty():
		var t: Array = tag[rng.randi() % tag.size()]
		grid.pins["edge_" + CellGrid.key(t[0], t[1])] = "taghcheh"
		grid.edges[CellGrid.key(t[0], t[1])]["slot"] = "edge:recess"
		grid.cells[t[0]]["landmark"] = "taghcheh"
	read = read.filter(func(r: Array) -> bool: return not grid.cells[r[0]].has("landmark") and not grid.pins.has("edge_" + CellGrid.key(r[0], r[1])))
	if not read.is_empty():
		var r: Array = read[rng.randi() % read.size()]
		grid.props["reading_" + CellGrid.cell_name(r[0])] = {"slot": "dressing:reading_corner", "xf": front_xf(r[0], r[1], 0.36)}
		grid.cells[r[0]]["landmark"] = "reading"


## Keepers' signs in the kept stacks (a book cart, or books and a cushion at a
## shelf's foot) and roots hanging from the vault in the abandoned ones.
func add_keepers(grid: CellGrid, seed_value: int) -> void:
	if abandon_over_bays <= 0:
		return
	for c: Vector3i in grid.run_order():
		if grid.cells[c]["kind"] != "floor" or grid.cells[c].has("landmark"):
			continue
		var a: float = float(grid.cells[c].get("abandon", 0.0))
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([seed_value, "keeper", CellGrid.cell_name(c)])
		if a < keeper_until and rng.randf() < keeper_chance:
			var walls: Array[int] = []
			for side: int in side_walls(grid, c):
				# Only tidy shelves: untidy ones drop books where the cart would
				# stand. The edge is made a recess below (a pin on a plain wall
				# shows nothing, and the cart would face bare masonry).
				var e: Dictionary = grid.edge(c, side)
				if e["mark"] == CellGrid.Mark.SOLID and e.get("slot", "") in ["", "edge:recess"] \
						and grid.pins.get("edge_" + CellGrid.key(c, side), "") == "stack shelves":
					walls.append(side)
			if not walls.is_empty():
				var side: int = walls[rng.randi() % walls.size()]
				grid.edges[CellGrid.key(c, side)]["slot"] = "edge:recess"
				var cart: bool = rng.randf() < 0.4
				grid.props["keeper_" + CellGrid.cell_name(c)] = {"slot": "dressing:keeper_cart" if cart else "dressing:keeper_pile",
					"xf": front_xf(c, side, 0.45 if cart else 0.25)}
				grid.cells[c]["keeper"] = true
		if roots_chance > 0.0 and rng.randf() < roots_chance * smoothstep(0.5, 1.0, a):
			var at: Vector3 = CellGrid.cell_centre(c) + Vector3(rng.randf_range(-0.6, 0.6), ROOTS_Y, rng.randf_range(-0.6, 0.6))
			grid.props["roots_" + CellGrid.cell_name(c)] = {"slot": "dressing:roots", "xf": Transform3D(Basis(Vector3.UP, rng.randf() * TAU), at)}


## Prop key prefixes placed freely, off the module grid (pier-face lights,
## reading corners, keepers, roots, puddles): the grid check leaves them out.
const FREE_PROPS: PackedStringArray = ["light_", "reading_", "keeper_", "roots_", "puddle_"]

## The vault's crown over a straight bay (vault_bay_4m), for hanging roots.
const ROOTS_Y: float = 5.95


## Part 3's water and fog. A straight floor bay past puddle_from may hold a
## puddle (seep water dripping from the vault), off the walked line and clear
## of the pier feet; every run bay past ground_fog_from gets a low fog patch
## (they overlap into one bank along the gallery).
func add_damp(grid: CellGrid, seed_value: int) -> void:
	if abandon_over_bays <= 0:
		return
	for c: Vector3i in grid.run_order():
		var a: float = float(grid.cells[c].get("abandon", 0.0))
		var kind: String = grid.cells[c]["kind"]
		if a >= ground_fog_from and kind != "collapsed":
			grid.props["fog_" + CellGrid.cell_name(c)] = {"slot": "fx:ground_fog",
				"xf": Transform3D(Basis(), CellGrid.cell_centre(c))}
		if kind != "floor" or puddle_chance <= 0.0 or grid.cells[c].has("keeper") or grid.cells[c].has("landmark"):
			continue
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([seed_value, "puddle", CellGrid.cell_name(c)])
		if rng.randf() >= puddle_chance * smoothstep(puddle_from, 1.0, a):
			continue
		var walls: Array[int] = side_walls(grid, c)
		if walls.is_empty():
			continue
		# Toward one wall (off the walked middle), and along the bay but short
		# of the piers' feet where the lights and candles stand.
		var out: Vector3 = (CellGrid.cell_centre(CellGrid.neighbour(c, walls[rng.randi() % walls.size()])) - CellGrid.cell_centre(c)).normalized()
		var along := Vector3(-out.z, 0, out.x)
		var at: Vector3 = CellGrid.cell_centre(c) + out * rng.randf_range(0.3, 0.75) + along * rng.randf_range(-0.8, 0.8)
		grid.props["puddle_" + CellGrid.cell_name(c)] = {"slot": "dressing:puddle",
			"xf": Transform3D(Basis(Vector3.UP, rng.randf() * TAU), at)}


## lamp_lit_by_distance at `bay` bays from the entry.
func lit_chance(bay: int) -> float:
	if lamp_lit_by_distance == null:
		return lerpf(0.9, 0.35, clampf(bay / 12.0, 0.0, 1.0))
	var x: float = clampf(float(bay), lamp_lit_by_distance.min_domain, lamp_lit_by_distance.max_domain)
	return clampf(lamp_lit_by_distance.sample(x), 0.0, 1.0)


## A cool fill on every fill_every_bays-th bay of the run.
func place_fills(grid: CellGrid) -> void:
	if fill_every_bays <= 0:
		return
	for c: Vector3i in grid.run_order():
		var i: int = grid.cells[c]["bay"]
		if i % fill_every_bays == fill_every_bays - 1:
			var a: float = float(grid.cells[c].get("abandon", 0.0)) if wall_lights else 0.0
			var at: Vector3 = CellGrid.cell_centre(c) + Vector3(0, fill_height, 0)
			var caps: Dictionary = grid.props.get("light_" + CellGrid.cell_name(c), {})
			if caps.get("slot", "") == "light:glowcaps":
				# The fill glows off the fungi: a metre out from them, low.
				var xf: Transform3D = caps["xf"]
				at = xf.origin - xf.basis.z * 1.0 + Vector3(0, fill_height, 0)
			grid.fills["fill_" + CellGrid.cell_name(c)] = {"at": at,
				"colour": fill_colour.lerp(fill_colour_far, a), "energy": fill_energy, "range": fill_range}


## Lengths of the straight stretches of a marked grid, in walk order (corners
## end a stretch and are not counted; alcoves are off the run).
static func stretches(grid: CellGrid) -> Array[int]:
	var order: Array[Vector3i] = grid.run_order()
	var out: Array[int] = []
	var run: int = 0
	for c: Vector3i in order:
		if grid.cells[c]["kind"] == "corner":
			out.append(run)
			run = 0
		else:
			run += 1
	out.append(run)
	return out


## "edge:solid_corner" for the walls of path[i] that meet a turn's inner
## corner (the side the run turns toward, on the bay before a corner and the
## bay after it), else "".
static func inner_corner(path: Array, i: int, side: int) -> String:
	if i + 2 < path.size() and path[i + 1][1] != path[i][1] and side == side_of(path[i + 1][1]):
		return "edge:solid_corner"      # the bay before a corner
	if i >= 2 and path[i - 1][1] != path[i - 2][1] and side == side_of(-(path[i - 2][1] as Vector3i)):
		return "edge:solid_corner"      # the bay after a corner
	return ""


static func side_of(dir: Vector3i) -> int:
	if dir.x > 0:
		return CellGrid.Side.E
	if dir.x < 0:
		return CellGrid.Side.W
	return CellGrid.Side.N if dir.z > 0 else CellGrid.Side.S

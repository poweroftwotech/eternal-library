@tool
class_name BazaarGrammar
extends RoomGrammar
## R04 Grand Bazaar (design/room-atlas.html; docs/environment/phase-15-approval.md):
## a 16 m domed crossing with two to four covered shop streets off it. The entry
## street comes in from the S; the others leave N, E and W, each ending in a
## door. A side with no street shows the tall arch of coloured glass.
##
## The street's middle is on the door's cell (0, *, 0), x = 2 m, so a street is
## 8 m between its shop fronts and 16 m with its shops, a little under five
## cells. Each street ends in a 2 m passage, which keeps the crossing's middle
## on a cell's centre so the E and W doors land on a cell too. Nothing is built
## by the cells: every piece is a free shell prop (slots "bz:*",
## gen/rules/r04_bazaar.tres; tools/kit_add_r04.py, kit_bazaar.blend).

const BAY: float = CellGrid.BAY
## The street's line, and half the crossing.
const MID_X: float = 2.0
const HALF: float = 8.0
const PASSAGE: float = 2.0
const STREET_MIN: int = 4
const STREET_MAX: int = 6
## Cells high: a street's vault tops out near 12 m, the crossing's near 20 m.
const STREET_Y: int = 3
const CROSS_Y: int = 5
## An eye in every third bay, starting from the second.
const EYE_EVERY: int = 3
## Open shops: most at the crossing, few at the row ends (the brief's story).
const OPEN_NEAR: float = 0.85
const OPEN_FAR: float = 0.2
const OPEN_DESERTED: float = 0.4
## Where along a row (0 at the crossing, 1 at its end) trade gives out.
const QUIET_FROM: float = 0.5
const AWNING_TO: float = 0.75
const PENNANT_TO: float = 0.7
## The crossing's crowd: how many, and clear of the middle, the board and the
## four ways through it, so you can always walk round.
const CROWD: int = 36
const CROWD_GROUPS: int = 9
const CROWD_NEAR: float = 4.3
const CROWD_FAR: float = 7.3
const CROWD_LANE: float = 1.5
const CROWD_GAP: float = 1.1
const GROUP_REACH: float = 0.8
## How far to each side of a street's middle the audit tries its end wall.
const WALL_PROBE: float = 2.8
## The walk round the middle.
const RING: float = 3.7
const SINGLES: PackedStringArray = ["a", "b", "c", "d", "e", "f", "g", "h"]
const GROUPS: PackedStringArray = ["talk", "ring", "haggle"]
const KEEPERS: PackedStringArray = ["a", "b", "c"]
## The trades, all in every bazaar (the brief's Q4): dealt from a shuffled deck, so
## shops next to each other differ.
const TRADES: PackedStringArray = ["rugs", "copper", "lamps", "books", "spices", "curios", "food"]
const AWNING_CHANCE: float = 0.7
const BAR_CHANCE: float = 0.5
const CRATES_CHANCE: float = 0.3
## Pennants over every third bay, between the eyes.
const PENNANT_EVERY: int = 3
## Goods are only drawn this close (grid.meta "near_only").
const GOODS_REACH: float = 34.0
## What to try, best first; the entry street comes on top of each.
const SETS: Array = [["N", "E", "W"], ["N", "E"], ["N", "W"], ["E", "W"], ["N"], ["E"], ["W"]]

## Nobody trades here any more (the Forgotten City's version; Q6): no people, stalls
## bare, cloth in rags, glass broken in places, the beams still falling.
@export var deserted: bool = false


func state_options() -> PackedStringArray:
	return ["Lived in", "Deserted", "Lived in, crowded at the crossing and quiet at the row ends; or deserted: no people, stalls bare, cloth in rags, glass broken."]


func _abandon() -> void:
	deserted = true


func layout(grid: CellGrid, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, "bazaar"])
	var entry: int = rng.randi_range(STREET_MIN, STREET_MAX)
	var want: Dictionary = {}
	for a: String in ["N", "E", "W"]:
		want[a] = rng.randi_range(STREET_MIN, STREET_MAX)
	# Two to four streets, the entry's among them; fewer if the space says so.
	var most: int = rng.randi_range(1, 3)
	var order: Array = []
	for s: Array in SETS:
		if s.size() <= most:
			order.append(s)
	for s: Array in SETS:
		if s.size() > most:
			order.append(s)
	for s: Array in order:
		for short: bool in [false, true]:
			var n: int = STREET_MIN if short else entry
			var arms: Dictionary = {}
			for a: String in s:
				arms[a] = STREET_MIN if short else int(want[a])
			if _fits(grid, n, arms):
				_lay(grid, n, arms, rng)
				return
	if not grid.quiet:
		push_warning("BazaarGrammar: no room for the bazaar")


## Every cell of the room: position -> cells high.
func _foot(n: int, arms: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for z: int in n:
		for x: int in range(-2, 3):
			out[Vector2i(x, z)] = STREET_Y
	for z: int in range(n, n + 5):
		for x: int in range(-2, 3):
			out[Vector2i(x, z)] = CROSS_Y
	if arms.has("N"):
		for z: int in range(n + 5, n + 5 + int(arms["N"])):
			for x: int in range(-2, 3):
				out[Vector2i(x, z)] = STREET_Y
	for z: int in range(n, n + 5):
		if arms.has("E"):
			for x: int in range(3, 3 + int(arms["E"])):
				out[Vector2i(x, z)] = STREET_Y
		if arms.has("W"):
			for x: int in range(-3 - int(arms["W"]) + 1, -2):
				out[Vector2i(x, z)] = STREET_Y
	return out


## The far doors: arm -> [cell, side].
func _doors(n: int, arms: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	if arms.has("N"):
		out["N"] = [Vector3i(0, 0, n + 4 + int(arms["N"])), CellGrid.Side.N]
	if arms.has("E"):
		out["E"] = [Vector3i(2 + int(arms["E"]), 0, n + 2), CellGrid.Side.E]
	if arms.has("W"):
		out["W"] = [Vector3i(-2 - int(arms["W"]), 0, n + 2), CellGrid.Side.W]
	return out


func _fits(grid: CellGrid, n: int, arms: Dictionary) -> bool:
	var foot: Dictionary = _foot(n, arms)
	for f: Vector2i in foot:
		for y: int in int(foot[f]):
			if not grid.is_free(Vector3i(f.x, y, f.y)):
				return false
	var doors: Dictionary = _doors(n, arms)
	for a: String in doors:
		if not grid.is_free(CellGrid.neighbour(doors[a][0], doors[a][1])):
			return false
	return true


## An arm's frame: its street's middle where it leaves the crossing, the street
## running along local -Z (the kit's +Y).
func _arm_xf(side: String, n: int) -> Transform3D:
	var zc: float = -(PASSAGE + n * BAY + HALF)
	match side:
		"N":
			return Transform3D(Basis(), Vector3(MID_X, 0.0, zc - HALF))
		"E":
			return Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(MID_X + HALF, 0.0, zc))
		"W":
			return Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(MID_X - HALF, 0.0, zc))
	return Transform3D(Basis(Vector3.UP, PI), Vector3(MID_X, 0.0, zc + HALF))


func _lay(grid: CellGrid, n: int, arms: Dictionary, rng: RandomNumberGenerator) -> void:
	var foot: Dictionary = _foot(n, arms)
	var i: int = 0
	for f: Vector2i in foot:
		for y: int in int(foot[f]):
			var c := Vector3i(f.x, y, f.y)
			grid.add_cell(c, "floor", Vector3i(0, 0, 1), i)
			i += 1
			var cell: Dictionary = grid.cells[c]
			cell["floor_slot"] = ""
			cell["ceiling_slot"] = ""
			cell["gables"] = false
			cell["no_floor"] = true
			if y > 0:
				cell["no_map"] = true
	# One space, as the terraces: open between its cells on each storey, a
	# column of links so the grid's check reaches every storey.
	for c: Vector3i in grid.cells:
		for side: int in CellGrid.ALL_SIDES:
			grid.set_edge(c, side, CellGrid.Mark.SOLID, false, "none")
	for c: Vector3i in grid.cells:
		for side: int in CellGrid.ALL_SIDES:
			if grid.cells.has(CellGrid.neighbour(c, side)):
				grid.set_edge(c, side, CellGrid.Mark.OPEN)
	for y: int in CROSS_Y:
		var to: Array = []
		for dy: int in [-1, 1]:
			if y + dy >= 0 and y + dy < CROSS_Y:
				to.append(Vector3i(0, y + dy, n + 2))
		grid.cells[Vector3i(0, y, n + 2)]["links"] = to
	# The doors.
	grid.set_edge(Vector3i.ZERO, CellGrid.Side.S, CellGrid.Mark.DOOR, not grid.root)
	grid.pins["edge_" + CellGrid.key(Vector3i.ZERO, CellGrid.Side.S)] = "nothing"
	var doors: Dictionary = _doors(n, arms)
	for a: String in doors:
		var c: Vector3i = doors[a][0]
		var side: int = doors[a][1]
		var k: String = CellGrid.key(c, side)
		grid.set_edge(c, side, CellGrid.Mark.DOOR)
		grid.props["exit_" + k] = {"slot": "stub:exit", "xf": CellGrid.door_transform(c, side)}
		grid.pins["edge_" + k] = "nothing"
	# The crossing.
	var centre := Vector3(MID_X, 0.0, -(PASSAGE + n * BAY + HALF))
	_shell(grid, "bz_cross", "bz:cross", Transform3D(Basis(), centre))
	var lengths: Dictionary = arms.duplicate()
	lengths["S"] = n
	var fronts: Array = []
	for a: String in ["S", "N", "E", "W"]:
		var xf: Transform3D = _arm_xf(a, n)
		var kit: Transform3D = xf * Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)
		if not lengths.has(a):
			_shell(grid, "bz_side_" + a, "bz:side_closed", kit)
		else:
			_shell(grid, "bz_side_" + a, "bz:side_open", kit)
			_street(grid, a, xf, int(lengths[a]), fronts)
	var steam: Array = []
	var bounds: Array = []
	var shops: Array = _shops(grid, fronts, rng, steam, bounds)
	var jet: bool = _middle(grid, centre, rng)
	var kit_s: Transform3D = _arm_xf("S", n) * Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)
	var board: Vector3 = kit_s * Vector3(-6.0, 0.0, 0.0)
	_shell(grid, "bz_rumours", "bz:rumours_old" if deserted else "bz:rumours", kit_s.translated_local(Vector3(-6.0, 0.0, 0.0)))
	if not deserted:
		_crowd(grid, centre, board, rng)
		_street_people(grid, fronts, rng)
	grid.props["bz_life"] = {"slot": "bz:life", "xf": Transform3D()}
	# The walk (AreaTour, the tests): in along the entry street to the crossing,
	# on along the first other street; arms are the rest, from the crossing.
	var from_s := Vector3(0.0, 0.0, RING)
	var inward: Array[Vector3] = _line(Vector3(MID_X, 0.0, -0.6), centre + from_s)
	var others: Array = []
	for a: String in ["N", "E", "W"]:
		if lengths.has(a):
			var door: Vector3 = _arm_xf(a, n) * Vector3(0.0, 0.0, -(int(lengths[a]) * BAY + PASSAGE - 0.6))
			others.append(_line(centre + (door - centre).normalized() * RING, door))
	var route: Array[Vector3] = inward.duplicate()
	route.append_array(_round_middle(centre, from_s, others[0][0] - centre))
	route.append_array(others[0])
	# Each other way, walked from the street you came in by, as the tour does.
	var ways: Array = []
	for arm: Array[Vector3] in others.slice(1):
		var way: Array[Vector3] = inward.duplicate()
		way.append_array(_round_middle(centre, from_s, arm[0] - centre))
		way.append_array(arm)
		ways.append(way)
	# The walls that matter, for the route audit: its cells don't line up with them,
	# so a cell's middle can be inside a shop's back wall.
	var ends: Array[Vector3] = [Vector3(MID_X, 0.0, -0.6)]
	for arm: Array[Vector3] in others:
		ends.append(arm.back())
	for at: Vector3 in ends:
		var out: Vector3 = (at - centre).normalized()
		var across: Vector3 = out.cross(Vector3.UP)
		for k: float in [-WALL_PROBE, WALL_PROBE]:
			bounds.append([at - out * 1.5 + across * k, out])
	for a: String in ["N", "E", "W", "S"]:
		var out: Vector3 = (_arm_xf(a, n).origin - centre).normalized()
		var across: Vector3 = out.cross(Vector3.UP)
		for k: float in [-6.0, 6.0]:
			bounds.append([centre + out * 6.5 + across * k, out])
		if not lengths.has(a):
			bounds.append([centre + out * 6.5, out])
	grid.meta.merge({"bazaar": true, "bounds": bounds, "streets": lengths, "centre": centre, "route": route, "arms": ways, "shops": shops, "steam": steam, "jet": centre + Vector3(0.0, 2.0, 0.0) if jet else Vector3.ZERO, "board": board, "deserted": deserted, "near_only": ["prop_bz_item_", GOODS_REACH]}, true)
	grid.wear.clear()


## One street: floor, vault, ribs and upper storey for each bay, the end wall and
## passage after them. The shops are placed once all the streets are known.
func _street(grid: CellGrid, a: String, xf: Transform3D, bays: int, fronts: Array) -> void:
	for b: int in bays:
		var at: Transform3D = xf.translated_local(Vector3(0.0, 0.0, -b * BAY))
		var tag: String = "%s_%d" % [a, b]
		_shell(grid, "bz_floor_" + tag, "bz:floor", at)
		_shell(grid, "bz_vault_" + tag, "bz:vault_eye" if b % EYE_EVERY == 1 else "bz:vault", at)
		if b > 0:
			_shell(grid, "bz_rib_" + tag, "bz:rib", at)
		var along: float = float(b) / maxi(bays - 1, 1)
		if b % PENNANT_EVERY == 0 and (deserted or along <= PENNANT_TO):
			_shell(grid, "bz_pennants_" + tag, "bz:pennants_rag" if deserted else "bz:pennants", at)
		for s: int in [1, -1]:
			# The side frame: X along the street, the aisle on +Y.
			var side: Transform3D = xf * Transform3D(Basis(Vector3.UP, PI * 0.5 * s), Vector3(4.0 * s, 0.0, -(b + (0 if s > 0 else 1)) * BAY))
			var cracked: bool = deserted and absi(hash(tag + str(s))) % 2 == 0
			_shell(grid, "bz_upper_%s_%d" % [tag, s], "bz:upper_broken" if cracked else "bz:upper", side)
			fronts.append(["%s_%d" % [tag, s], side, along])
	_shell(grid, "bz_end_" + a, "bz:end", xf.translated_local(Vector3(0.0, 0.0, -bays * BAY)))


## Every shop front gets its shop. Lived in: most open by the crossing, few at the
## row ends, never fewer than the trades, each open one a trade with its keeper;
## the ends shut, with empty hooks and dust. Deserted: all bare. Returns
## [inside, street, trade] for each open one, and adds the food shops' pots to steam.
func _shops(grid: CellGrid, fronts: Array, rng: RandomNumberGenerator, steam: Array, bounds: Array) -> Array:
	var open: Dictionary = {}
	for i: int in fronts.size():
		var along: float = fronts[i][2]
		if rng.randf() < (OPEN_DESERTED if deserted else lerpf(OPEN_NEAR, OPEN_FAR, along)):
			open[i] = true
	if not deserted:
		var order: Array = range(fronts.size())
		order.sort_custom(func(a: int, b: int) -> bool: return fronts[a][2] < fronts[b][2])
		for i: int in order:
			if open.size() >= mini(TRADES.size(), fronts.size()):
				break
			open[i] = true
	var deck: Array = []
	var out: Array = []
	for i: int in fronts.size():
		var tag: String = fronts[i][0]
		var side: Transform3D = fronts[i][1]
		var along: float = fronts[i][2]
		var quiet: bool = deserted or along >= QUIET_FROM
		if not open.has(i):
			bounds.append([side * Vector3(2.0, 0.0, -2.0), side.basis * Vector3.BACK])
			_shell(grid, "bz_shop_" + tag, "bz:shop_shut", side)
			if rng.randf() < BAR_CHANCE:
				_shell(grid, "bz_item_bar_" + tag, "bz:shut_bar", side)
			if rng.randf() < CRATES_CHANCE:
				_shell(grid, "bz_item_crates_" + tag, "bz:shut_crates", side)
			elif quiet and rng.randf() < 0.7:
				_shell(grid, "bz_item_dust_" + tag, "bz:shut_dust", side)
			if quiet and rng.randf() < 0.6:
				_shell(grid, "bz_item_hooks_" + tag, "bz:shut_hooks", side)
			continue
		for way: Vector3 in [Vector3.BACK, Vector3.LEFT, Vector3.RIGHT]:
			bounds.append([side * Vector3(2.0, 0.0, 2.25), side.basis * way])
		_shell(grid, "bz_shop_" + tag, "bz:shop_open", side)
		if deserted:
			_shell(grid, "bz_item_bare_" + tag, "bz:bare", side)
			if rng.randf() < 0.5:
				_shell(grid, "bz_item_awning_" + tag, "bz:awning_rag_a" if rng.randf() < 0.5 else "bz:awning_rag_b", side)
			out.append([side * Vector3(2.0, 0.0, 2.25), side * Vector3(2.0, 0.0, -2.0), "bare"])
			continue
		if deck.is_empty():
			deck = Array(TRADES).duplicate()     # the constant folds to a read-only array
			_shuffle(deck, rng)
		var trade: String = deck.pop_back()
		_shell(grid, "bz_item_trade_" + tag, "bz:trade_" + trade, side)
		_shell(grid, "bz_item_keeper_" + tag, "bz:keeper_" + KEEPERS[rng.randi_range(0, KEEPERS.size() - 1)], side)
		if trade == "food":
			steam.append(side * Vector3(0.68, 1.0, 2.12))
		if along <= AWNING_TO and rng.randf() < AWNING_CHANCE:
			_shell(grid, "bz_item_awning_" + tag, "bz:awning_a" if rng.randf() < 0.5 else "bz:awning_b", side)
		out.append([side * Vector3(2.0, 0.0, 2.25), side * Vector3(2.0, 0.0, -2.0), trade])     # inside, and out in the street
	return out


## The crossing's middle, in the beam: a fountain or a storyteller, by seed. True
## if water runs.
func _middle(grid: CellGrid, centre: Vector3, rng: RandomNumberGenerator) -> bool:
	var water: bool = rng.randf() < 0.5
	var slot: String = "fountain" if water else "story"
	_shell(grid, "bz_middle", "bz:%s%s" % [slot, ("_dry" if water else "_bare") if deserted else ""], Transform3D(Basis(), centre))
	return water and not deserted


## People at the crossing: a loose ring round the middle, turned toward it or each
## other, leaving the four ways through and the board clear.
func _crowd(grid: CellGrid, centre: Vector3, board: Vector3, rng: RandomNumberGenerator) -> void:
	var placed: Array[Vector3] = []
	var groups: int = 0
	var tries: int = 0
	while placed.size() < CROWD and tries < 600:
		tries += 1
		var p := Vector3(rng.randf_range(-CROWD_FAR, CROWD_FAR), 0.0, rng.randf_range(-CROWD_FAR, CROWD_FAR))
		var group: bool = groups < CROWD_GROUPS
		var wide: float = GROUP_REACH if group else 0.0     # a group stands wider than one figure
		if p.length() < CROWD_NEAR + wide or absf(p.x) < CROWD_LANE + wide or absf(p.z) < CROWD_LANE + wide:
			continue
		var at: Vector3 = centre + p
		if at.distance_to(board) < 3.0:
			continue
		var gap: float = CROWD_GAP * (1.8 if group else 1.0)
		if placed.any(func(q: Vector3) -> bool: return q.distance_to(at) < gap):
			continue
		var turn: float = atan2(-p.x, -p.z) + rng.randf_range(-0.7, 0.7)
		var xf := Transform3D(Basis(Vector3.UP, turn), at)
		if group:
			_shell(grid, "bz_item_fig_%d" % placed.size(), "bz:group_" + GROUPS[groups % GROUPS.size()], xf)
			groups += 1
		else:
			_shell(grid, "bz_item_fig_%d" % placed.size(), "bz:fig_" + SINGLES[rng.randi_range(0, SINGLES.size() - 1)], xf)
		placed.append(at)


## People along the rows, thinning toward the ends: some looking in at a shop from
## the aisle's edge, the middle of the street left clear.
func _street_people(grid: CellGrid, fronts: Array, rng: RandomNumberGenerator) -> void:
	for f: Array in fronts:
		var along: float = f[2]
		var side: Transform3D = f[1]
		var want: float = pow(1.0 - along, 2.0) * 1.3
		var n: int = int(want) + (1 if rng.randf() < fmod(want, 1.0) else 0)
		for i: int in n:
			# To one side of the shop's middle, so its way in stays clear.
			var off: float = rng.randf_range(1.0, 1.5) * (1.0 if rng.randf() < 0.5 else -1.0)
			var at := Vector3(2.0 + off, 0.0, -rng.randf_range(1.25, 2.3))
			var xf: Transform3D = side * Transform3D(Basis(Vector3.UP, rng.randf_range(-0.8, 0.8)), at)
			var slot: String = "bz:fig_" + SINGLES[rng.randi_range(0, SINGLES.size() - 1)]
			_shell(grid, "bz_item_row_%s_%d" % [f[0], i], slot, xf)


## The walk round the middle, from one point of the ring to another, the short way.
func _round_middle(centre: Vector3, from: Vector3, to: Vector3) -> Array[Vector3]:
	var a: float = atan2(from.z, from.x)
	var turn: float = wrapf(atan2(to.z, to.x) - a, -PI, PI)
	var out: Array[Vector3] = []
	var steps: int = maxi(2, ceili(absf(turn) / 0.6))
	for i: int in range(1, steps):
		var t: float = a + turn * i / steps
		out.append(centre + Vector3(cos(t), 0.0, sin(t)) * RING)
	return out


## Array.shuffle would take the global seed; this keeps a room to its own.
func _shuffle(list: Array, rng: RandomNumberGenerator) -> void:
	for i: int in range(list.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var t: Variant = list[i]
		list[i] = list[j]
		list[j] = t


func _line(from: Vector3, to: Vector3) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var steps: int = maxi(1, ceili(from.distance_to(to) / BAY))
	for i: int in steps + 1:
		out.append(from.lerp(to, float(i) / steps))
	return out


func _shell(grid: CellGrid, name: String, slot: String, xf: Transform3D) -> void:
	grid.props[name] = {"slot": slot, "xf": xf, "shell": true}


func wear_lanes(_grid: CellGrid, _seed_value: int) -> void:
	pass

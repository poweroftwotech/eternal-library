extends SceneTree
## Seeds the gorge's frontage slots (phase-6-design.md 5.7.3, phase 6 step 4).
##   godot --headless --path . --script res://tools/gorge_frontage.gd
## Writes gen/gorge/frontage.tres (yours to edit afterwards; re-running
## overwrites it): on the near banks (1-4), every straight run of a tier's
## faces across the gorge (toward its middle) at a storey from FLOOR_MIN to
## FLOOR_MAX, cut to the bays with room in front for a ledge one bay deep:
## clear of every tier (their decks' overhangs and balustrades too) from the
## ledge's corbels to its headroom, and of the backdrop's masses
## (GorgeBackdrop). Runs of at least MIN_BAYS bays become slots.

const OUT: String = "res://gen/gorge/frontage.tres"
const LAYOUT: String = "res://gen/gorge/gorge_layout.tres"
const BAY: float = 4.0
## The near banks (the walkable chamber; phase 6 Q3).
const BANKS: Array[int] = [1, 2, 3, 4]
## Ledge floors from 40 m below the balcony to its foot (the Overlook's
## ledge is at -12).
const FLOOR_MIN: float = -40.0
const FLOOR_MAX: float = 0.0
## Only the near chamber: bays whose middle is nearer the balcony than this
## (z; the narrows begin past it, phase 6 Q3).
const NEAR_Z: float = -168.0
const MIN_BAYS: int = 2
## A face is across the gorge if its normal points this much toward x = 0.
const ACROSS: float = .85
## What must be clear in front of a slot's bay, its frame (x along, z out):
## the corbel's foot to the headroom, a little past the ledge's front.
const CLEAR_X: Array[float] = [.3, 2.0, 3.7]
const CLEAR_Z: Array[float] = [-.25, -2.0, -3.75, -4.4]
const CLEAR_Y: Array[float] = [-2.5, -1.2, .3, 1.8, 3.6]
## Under the tier's own deck overhang (its top storey) the back of the walk
## keeps this much headroom (a covered gallery), the front all of it.
const UNDER_DECK_H: float = 2.5
const UNDER_DECK_Z: float = -2.4
## A bay's walk keeps this clear of the backdrop (GorgeBackdrop) along the face.
const BACKDROP_SPARE: float = .5


func _initialize() -> void:
	GorgeBackdrop.load_baked()
	var layout: GorgeLayout = load(LAYOUT)
	var grammar := GorgeGrammar.new()
	var tiers: Array[Dictionary] = grammar.keep_out(layout)
	var frontage := GorgeFrontage.new()
	var faces: int = 0
	for b: int in BANKS:
		var row: PackedFloat32Array = layout.banks[b - 1]
		var local := RandomNumberGenerator.new()
		local.seed = int(row[5]) * 8329
		var bank: Array[Dictionary] = grammar.bank_tiers(Vector2(row[0], row[1]), row[2], row[3], row[4], int(row[5]), local)
		for t: Dictionary in bank:
			var cells: Dictionary = t["cells"]
			var frame: Transform3D = t["frame"]
			for cell: Vector2i in cells:
				for side: int in CellGrid.ALL_SIDES:
					# The first bay of each straight run of exposed faces on this side.
					if not exposed(cells, cell, side) or exposed(cells, GorgeGrammar._before(cell, side), side):
						continue
					var run: Array[Vector2i] = [cell]
					while exposed(cells, GorgeGrammar._after(run[-1], side), side):
						run.append(GorgeGrammar._after(run[-1], side))
					var e: Transform3D = frame * CellGrid.edge_transform(Vector3i(cell.x, 0, cell.y), side)
					var normal: Vector3 = e.basis.z.normalized()
					var mid: Vector3 = e * Vector3(BAY * .5, 0, 0)
					if normal.x * -signf(mid.x) < ACROSS:
						continue
					faces += 1
					for s: int in int(t["storeys"]):
						var y: float = float(t["bottom"]) + s * BAY
						if y < FLOOR_MIN or y > FLOOR_MAX:
							continue
						_slots(frontage, tiers, b, t, run, side, s)
	var err: Error = ResourceSaver.save(frontage, OUT)
	var per_bank: Dictionary = {}
	for s: FrontageSlot in frontage.slots:
		per_bank[s.bank] = int(per_bank.get(s.bank, 0)) + 1
	print("gorge_frontage: %d faces across the gorge, %d slots %s -> %s (%s)" % [faces, frontage.slots.size(), per_bank, OUT, error_string(err)])
	quit(0 if err == OK else 1)


## The slots on one run of faces at storey s: its bays with room in front,
## in runs of MIN_BAYS or more.
func _slots(frontage: GorgeFrontage, tiers: Array[Dictionary], bank: int, t: Dictionary, run: Array[Vector2i], side: int, s: int) -> void:
	var frame: Transform3D = t["frame"]
	var good: Array[bool] = []
	for c: Vector2i in run:
		var ledge: Transform3D = _ledge_frame(frame * CellGrid.edge_transform(Vector3i(c.x, s, c.y), side))
		var ok: bool = GorgeGrammar.solid_at(tiers, ledge * Vector3(2.0, 1.5, .5)) and (ledge * Vector3(2.0, 0, -2.0)).z > NEAR_Z     # the wall behind, in the near chamber
		for x: float in CLEAR_X:
			for z: float in CLEAR_Z:
				for y: float in CLEAR_Y.map(func(v: float) -> float: return minf(v, UNDER_DECK_H) if z > UNDER_DECK_Z else v):
					ok = ok and not GorgeGrammar.solid_at(tiers, ledge * Vector3(x, y, z))
		# And clear of the backdrop's masses, the walk and its headroom with a
		# little to spare along the face.
		ok = ok and not GorgeBackdrop.crosses(ledge, Vector3(-BACKDROP_SPARE, .3, -4.4), Vector3(BAY + BACKDROP_SPARE, 3.6, -.3))
		good.append(ok)
	var i: int = 0
	while i < run.size():
		if not good[i]:
			i += 1
			continue
		var j: int = i
		while j + 1 < run.size() and good[j + 1]:
			j += 1
		if j - i + 1 >= MIN_BAYS:
			# The slot's frame is the ledge frame of the run's last bay: its +X
			# runs back along the run (the faces' own +X runs the other way).
			var slot := FrontageSlot.new()
			slot.id = "b%d_l%d_%s_s%d_%d" % [bank, t["level"], "SNEW"[side], s, i]
			slot.bank = bank
			slot.cliff = "left" if bank % 2 == 1 else "right"
			slot.xf = _ledge_frame(frame * CellGrid.edge_transform(Vector3i(run[j].x, s, run[j].y), side))
			slot.width = j - i + 1
			frontage.slots.append(slot)
		i = j + 1


## A face bay's edge frame (x 0..4 along it, +Z out) as a ledge cell's frame
## (x 0..4 the other way, -Z out, z 0..-4 the ledge).
static func _ledge_frame(edge: Transform3D) -> Transform3D:
	return edge * Transform3D(Basis(Vector3.UP, PI), Vector3(BAY, 0, 0))


static func exposed(cells: Dictionary, cell: Vector2i, side: int) -> bool:
	return cells.has(cell) and not cells.has(GorgeGrammar._beside(cell, side))

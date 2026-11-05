class_name BridgeHallBridge
extends Node3D
## The R21 Bridge Hall's bridges (BridgeHallGrammar puts this at bh:bridge, the
## run's start: the entry mouth's middle, -Z across the hall). Built from the
## room's grid.meta when the room is, with the Chasm Spans' pieces
## (ChasmGrammar.build_room): deck bays, balustrades with newels, the upper
## aqueduct arcade under each 12 m of deck down to the pit, a stepped corbel
## and pier at an end the arcades don't reach, lamps on some newels. Where
## the far door is a storey up or down (meta bridge.rise), the far arcade bay
## carries the span's flight (phase 12 Q3).
##
## Also the older bridge (Q4): scenery in the hall's other column, level, a
## storey over the deck (under it when yours climbs), with a waterfall
## pouring from a trough on one arch toward yours and a sealed ornate door
## in the carved doorway at each end; no lamps.
##
## And the fall catch (Q6): if you get over a balustrade and drop below the
## deck, you're put back at the passage you came in by.

const BAY: float = 4.0
const GROUP: int = 3
## The pit's floor under the deck (tools/kit_add_r21.py PIT_Z).
const PIT: float = -8.0
## How far under the deck counts as fallen.
const FALLEN: float = 3.0
## The carved door's opening (tools/kit_add_persian.py carved_door: half
## width, springing, rise) and how far in its timber door stands.
const DOOR_ARCH: Array = [0.72, 1.65, 0.85]
const DOOR_DEEP: float = 1.1

var _meta: Dictionary = {}
var _room: Node3D
var _player: Node3D
var _came_by: Vector3 = Vector3.INF      # room frame: where to put you back
var _walk: Array = []                     # the run's walk points (plan), for the fall catch


func _ready() -> void:
	# Its spans stand off the room's grid (KitValidateRoom skips them).
	set_meta("off_grid", true)
	_room = _find_room()
	if _room == null or _room.get("grid") == null:
		return
	_meta = (_room.get("grid") as CellGrid).meta
	if not _meta.has("bridge"):
		return
	var b: Dictionary = _meta["bridge"]
	var n: int = b["bays"]
	var rise: int = int(b.get("rise", 0))
	var seed_value: int = int(b.get("seed", 0))
	# The landing's side deck looks across at the older bridge, clear of its
	# waterfall; if every bay is under the water, it stands out the other way
	# (toward the house fronts).
	var side: float = signf((_meta["old_bridge"]["start"] as Transform3D).origin.x - position.x) if _meta.has("old_bridge") else 1.0
	var k: int = landing_bay(n, rise, old_fall_bay(n, seed_value) if _meta.has("old_bridge") else -1)
	if k < 0:
		k = landing_bay(n, rise)
		side = -side
	_build(self, plan(n, rise, PIT, true, -1, 1.0, k, side))
	if _meta.has("old_bridge"):
		_add_old_bridge(n, seed_value)
	_add_mist()
	_add_window_lights()
	_add_life(n, rise, k, side, seed_value)


func _find_room() -> Node3D:
	var n: Node = get_parent()
	while n != null:
		if n is GeneratedRoom:
			return n as Node3D
		n = n.get_parent()
	return null


## Builds a span plan and moves its parts under `into`.
static func _build(into: Node3D, span: Dictionary) -> void:
	var built: RoomTemplate = ChasmGrammar.build_room(span)
	for c: Node in built.get_children():
		built.remove_child(c)
		into.add_child(c)
	built.free()


## The span plan (ChasmGrammar.solve's form, the run's frame) of a bridge `n`
## bays long whose far end is `rise` storeys up (1), down (-1) or level (0).
## Arcade bays of three; bays left over stand on a stepped corbel against the
## end wall, the first at the far end, then the entry end. A climb or drop is
## in the last arcade bay: a landing then the flight up, or the flight down
## then a landing, so the arcade carries the group's lower deck. `pit` is
## the drop's floor in the run's frame; `fall` the arcade bay that pours a
## waterfall (-1 none), from its +X face (fall_side 1) or -X (-1).
static func plan(n: int, rise: int = 0, pit: float = PIT, lamps: bool = true, fall: int = -1, fall_side: float = 1.0,
		landing: int = -1, landing_side: float = 0.0) -> Dictionary:
	var out: Dictionary = {"ok": true, "kind": "bridge", "drop": maxi(0, -rise), "bays": n, "pieces": [], "piers": [],
		"joints": [], "lamps": [], "falls": [], "connectors": {}, "walk": [], "boxes": [], "no_newels": []}
	var lead_far: int = (n % GROUP + 1) / 2
	var lead: int = n % GROUP - lead_far
	var groups: Array[int] = []
	for a: int in range(lead, n - lead_far, GROUP):
		groups.append(a)
	var fa: int = groups[-1] if rise != 0 and not groups.is_empty() else -1
	var high: float = rise * BAY
	# Each bay's deck (NAN on a flight's bays).
	var deck: Array[float] = []
	for k: int in n:
		if fa < 0 or k < fa:
			deck.append(0.0)
		elif rise > 0:
			deck.append(0.0 if k == fa else (NAN if k <= fa + 2 else high))
		else:
			deck.append(NAN if k <= fa + 1 else high)
	for k: int in n:
		if is_nan(deck[k]):
			continue
		var at := Vector3(-2, deck[k], -k * BAY)
		var corbel: bool = k < lead or k >= n - lead_far
		_piece(out, "walls/cliff_ledge_4m" if corbel else "walls/chasm_deck_4m", at)
		var bay_out: bool = k == landing and landing_side != 0.0
		for side: int in [1, 3]:
			var xf: Transform3D = Transform3D(Basis(), at) * ChasmGrammar._cell_edge(side)
			# The landing's side deck opens off the bay (its newels stay).
			if not (bay_out and side == (1 if landing_side > 0 else 3)):
				(out["pieces"] as Array).append({"scene": ChasmGrammar.MOD + "walls/chasm_parapet_4m.tscn", "xf": xf})
			(out["joints"] as Array).append(xf * Vector3(0, 0, -.18))
			(out["joints"] as Array).append(xf * Vector3(4, 0, -.18))
		if bay_out:
			_add_bay_out(out, k, deck[k], landing_side)
		(out["walk"] as Array).append(at + Vector3(2, 0, -2))
		if corbel:
			var top: float = deck[k] - ChasmGrammar.CORBEL_UNDER
			(out["piers"] as Array).append({"at": Vector3(0, (top + pit) * .5, -(k + .5) * BAY),
				"size": Vector3(ChasmGrammar.CORBEL_PIER, top - pit, ChasmGrammar.CORBEL_PIER)})
	if fa >= 0:
		# The flight (tools/kit_add_r10.py: x 0..4, its top at z 0, its foot
		# 8 m on and 4 m down), turned about for a climb.
		var fxf := Transform3D(Basis(), Vector3(-2, 0, -fa * BAY)) if rise < 0 \
			else Transform3D(Basis(Vector3.UP, PI), Vector3(2, high, -(fa + 3) * BAY))
		(out["pieces"] as Array).append({"scene": ChasmGrammar.MOD + "walls/chasm_span_flight.tscn", "xf": fxf})
		for x: float in [.18, 3.82]:
			(out["joints"] as Array).append(fxf * Vector3(x, -.1, 0))
			(out["joints"] as Array).append(fxf * Vector3(x, -BAY, -2 * BAY))
		(out["walk"] as Array).append(fxf * Vector3(2, -1.0, -2))
		(out["walk"] as Array).append(fxf * Vector3(2, -3.0, -6))
	for g: int in groups.size():
		var a: int = groups[g]
		var top: float = (minf(0.0, high) if a == fa else deck[a]) - ChasmGrammar.COURSE
		_piece(out, "walls/aqueduct_upper_12m", Vector3(0, top, -a * BAY), ChasmGrammar.ARC_BASIS)
		var foot: float = top - ChasmGrammar.UPPER_H
		if foot > pit:
			_piece(out, "walls/aqueduct_lower_12m", Vector3(0, foot, -a * BAY), ChasmGrammar.ARC_BASIS)
			foot -= ChasmGrammar.LOWER_H
		(out["boxes"] as Array).append(AABB(Vector3(-ChasmGrammar.ARCADE_HALF, foot, -(a + GROUP) * BAY),
			Vector3(ChasmGrammar.ARCADE_HALF * 2, top - foot, GROUP * BAY)))
		if g == fall:
			var basis: Basis = ChasmGrammar.ARC_BASIS if fall_side > 0 else Basis(Vector3.UP, PI) * ChasmGrammar.ARC_BASIS
			var face := Transform3D(basis, Vector3(fall_side * ChasmGrammar.ARCADE_HALF, top, -(a + GROUP * .5) * BAY))
			var lip: float = (face * ChasmGrammar.FALL_FROM).y
			(out["falls"] as Array).append({"xf": face, "size": Vector2(ChasmGrammar.FALL_WIDTH, lip - pit + .5)})
	if not lamps:
		return out
	# A lamp at each end, on the newel by the mouth (opposite sides), and on
	# every third newel between, alternating sides (walked step 1: too dark);
	# none partway up a flight.
	# The landing's own lamp stands in for a newel lamp near it (light budget).
	for k: int in range(2, n - 1, GROUP):
		var y: float = _end_height(deck, k)
		if landing >= 0 and absf((k + 1) - (landing + 0.5)) < LANDING_CLEAR:
			continue
		if not is_nan(y):
			(out["lamps"] as Array).append(Vector3((1.82 if (k / GROUP) % 2 == 0 else -1.82), y, -(k + 1) * BAY))
	(out["lamps"] as Array).append(Vector3(1.82, 0, -.18))
	(out["lamps"] as Array).append(Vector3(-1.82, high if fa >= 0 else 0.0, -n * BAY + .18))
	return out


## Newel lamps within this many bays of the landing's middle give way to its lamp.
const LANDING_CLEAR: float = 1.6


## The halfway landing's side deck (walked step 3: the keeper's things in the
## middle of the bridge looked wrong): BAY_OUT deep off bay k's side `s`
## (+-1 in x), on deck height y. A deck bay narrowed to its depth, a
## balustrade round its three open sides (the short ones narrowed), newels at
## its corners, stone corbels under it from the arcade's face.
const BAY_OUT: float = 2.0
const CORBEL: String = "res://kit/modules/persian/persian_corbel.tscn"


static func _add_bay_out(out: Dictionary, k: int, y: float, s: float) -> void:
	var o := Vector3(2.0 if s > 0 else -2.0 - BAY_OUT, y, -k * BAY)      # its cell's corner (x 0..BAY_OUT, z -4..0)
	var narrow := Basis().scaled(Vector3(BAY_OUT / BAY, 1, 1))
	(out["pieces"] as Array).append({"scene": ChasmGrammar.MOD + "walls/chasm_deck_4m.tscn", "xf": Transform3D(narrow, o)})
	var rail: String = ChasmGrammar.MOD + "walls/chasm_parapet_4m.tscn"
	var cell := Transform3D(narrow, o)
	var outer: Transform3D = Transform3D(Basis(Vector3.UP, PI * .5), o + Vector3(BAY_OUT, 0, 0)) if s > 0 \
		else Transform3D(Basis(Vector3.UP, -PI * .5), o + Vector3(0, 0, -BAY))
	var ends: Array[Transform3D] = [outer, cell * ChasmGrammar._cell_edge(0), cell * ChasmGrammar._cell_edge(2)]
	for i: int in ends.size():
		(out["pieces"] as Array).append({"scene": rail, "xf": ends[i]})
		(out["joints"] as Array).append(ends[i] * Vector3(0, 0, -.18))
		(out["joints"] as Array).append(ends[i] * Vector3(4, 0, -.18))
	for z: float in [0.55, 2.0, 3.45]:
		(out["pieces"] as Array).append({"scene": CORBEL, "xf": Transform3D(Basis(Vector3.UP, s * PI * .5) * Basis.from_scale(Vector3(1.4, 1.4, 2.2)),
			Vector3(s * ChasmGrammar.ARCADE_HALF, y - 1.0, -(k * BAY + z)))})
	(out["walk"] as Array).append(Vector3(s * (2.0 + BAY_OUT * .5), y, -(k + .5) * BAY))


## The halfway landing's bay (step 3): nearest the middle, on the level deck
## before a flight, not an end bay, and clear of the older bridge's
## waterfall (its arcade group `fall_a`, -1 none) so the side deck isn't
## under the water. -1 if none.
static func landing_bay(n: int, rise: int, fall_a: int = -1) -> int:
	var hi: int = n - 2
	if rise != 0:
		var lead_far: int = (n % GROUP + 1) / 2
		var lead: int = n % GROUP - lead_far
		for a: int in range(lead, n - lead_far, GROUP):
			hi = a - 1
	var best: int = -1
	for k: int in range(1, hi + 1):
		if fall_a >= 0 and k >= fall_a and k < fall_a + GROUP:
			continue
		if best < 0 or absf(k - (n - 1) * .5) < absf(best - (n - 1) * .5):
			best = k
	return best


## The older bridge's waterfall: its arcade group's first bay (as
## _add_old_bridge draws it: the first number from its generator), -1 none.
static func old_fall_bay(n: int, seed_value: int) -> int:
	var groups: Array[int] = []
	var lead_far: int = (n % GROUP + 1) / 2
	var lead: int = n % GROUP - lead_far
	for a: int in range(lead, n - lead_far, GROUP):
		groups.append(a)
	if groups.is_empty():
		return -1
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, "bridge_hall_old"])
	var g: int = rng.randi_range(0, maxi((n - n % GROUP) / GROUP - 1, 0))
	return groups[g] if g < groups.size() else -1


## The deck's height at the far end of bay k (NAN partway up a flight).
static func _end_height(deck: Array[float], k: int) -> float:
	if not is_nan(deck[k]):
		return deck[k]
	if k + 1 < deck.size() and not is_nan(deck[k + 1]):
		return deck[k + 1]
	return NAN


## The deck's height under run point z (the run's frame), for the fall catch:
## the lowest walk point within half a bay.
static func deck_at(walk: Array, z: float) -> float:
	var lo: float = 0.0
	for w: Vector3 in walk:
		if absf(w.z - z) < BAY * .5:
			lo = minf(lo, w.y)
	return lo


static func _piece(out: Dictionary, path: String, at: Vector3, basis: Basis = Basis()) -> void:
	(out["pieces"] as Array).append({"scene": ChasmGrammar.MOD + path + ".tscn", "xf": Transform3D(basis, at)})


## The older bridge (meta old_bridge): level, no lamps, a waterfall from one
## of its arches on the side toward yours, a sealed ornate door in the carved
## doorway at each end.
func _add_old_bridge(n: int, seed_value: int) -> void:
	var ob: Dictionary = _meta["old_bridge"]
	var start: Transform3D = ob["start"]
	var holder := Node3D.new()
	holder.name = "OldBridge"
	holder.position = start.origin - position
	add_child(holder)
	var groups: int = (n - n % GROUP) / GROUP
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, "bridge_hall_old"])
	var toward: float = -signf(holder.position.x)
	var span: Dictionary = plan(n, 0, PIT - start.origin.y, false, rng.randi_range(0, maxi(groups - 1, 0)), toward)
	# Weathered (step 3): fallen parapet bays railed with timber, some gone.
	var patches: Array[Transform3D] = BridgeHallLife.weather(span, seed_value)
	_build(holder, span)
	for i: int in patches.size():
		BridgeHallLife.timber_patch(patches[i], hash([seed_value, i]), holder, "TimberPatch_%d" % i)
	# Moss on its deck; ivy over its edges.
	for k: int in n:
		for _j: int in rng.randi_range(1, 3):
			var at := Vector3(rng.randf_range(-1.5, 1.5), 0.0, -(k + rng.randf()) * BAY)
			BridgeHallLife.scene(BridgeHallLife.D + ("plant_moss_cushion.tscn" if rng.randf() < 0.7 else "plant_crack_tuft.tscn"),
				Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(2.0, 3.5)), at), holder, "OldMoss_%d_%d" % [k, _j])
		for s: float in [-1.0, 1.0]:
			if rng.randf() < 0.55:
				var z: float = -(k + rng.randf_range(0.2, 0.8)) * BAY
				BridgeHallLife.scene(BridgeHallLife.D + "plant_ivy_hang.tscn",
					Transform3D(Basis(Vector3.UP, -s * PI * 0.5).scaled(Vector3(1.8, rng.randf_range(1.5, 2.8), 1.8)), Vector3(s * 2.1, -0.2, z)), holder, "OldIvy_%d_%d" % [k, int(s)])
	for i: int in (ob["doors"] as Array).size():
		var face: Transform3D = ob["doors"][i]
		var door := OrnateDoor.make(DOOR_ARCH[0], DOOR_ARCH[1], DOOR_ARCH[2])
		door.name = "SealedDoor_%d" % i
		# The carved panel's opening is centred on the piece (x 0..4).
		var f: Transform3D = Transform3D(Basis(), -position) * face
		door.transform = f * Transform3D(Basis(), Vector3(2.0, 0.0, -DOOR_DEEP))
		add_child(door)
		BridgeHallLife.soften_door(f, hash([seed_value, "door", i]), self, "SealedDoor_%d" % i)


func _physics_process(_delta: float) -> void:
	if _meta.is_empty():
		return
	if _player == null or not is_instance_valid(_player):
		var cam: Camera3D = get_viewport().get_camera_3d()
		var n: Node = cam
		while n != null and not n.has_method("teleport"):
			n = n.get_parent()
		_player = n as Node3D
		if _player == null:
			return
	var local: Vector3 = _room.to_local(_player.global_position)
	# The passage you're in is the one you came in by.
	for key: String in ["entry_cells", "far_cells"]:
		for c: Vector3i in _meta[key]:
			var q: Vector3 = CellGrid.cell_centre(c)
			if absf(local.x - q.x) < BAY * .5 and absf(local.z - q.z) < BAY * .5 and absf(local.y - q.y) < 2.0:
				_came_by = Vector3(q.x, q.y + 0.2, q.z)
	var hall: AABB = _meta["hall"]
	if not _came_by.is_finite() or local.y < PIT - 4.0 \
			or local.x < hall.position.x or local.x > hall.end.x or local.z < hall.position.z or local.z > hall.end.z:
		return
	var b: Dictionary = _meta["bridge"]
	if _walk.is_empty():
		_walk = plan(int(b["bays"]), int(b.get("rise", 0)), PIT, false)["walk"]
	var under: float = deck_at(_walk, local.z - position.z)
	if local.y < under - FALLEN:
		var back: Vector3 = _room.to_global(_came_by)
		var into: Vector3 = _room.to_global(Vector3(position.x, _came_by.y, position.z)) - back
		_player.call("teleport", back, atan2(-into.x, -into.z), 0.0)


## The mist glow from below (the room's main light, phase 12 brief): a
## luminous mist lying in the drop under the deck (the visible source), and
## cold lights in it, one per 12 m, to either side of the arcade, that light
## the pit's rock and boulders, the lower walls and the deck's underside. No
## shadows. (A glowing pool plane on the pit floor read as a flat white
## sheet from the deck at any setting, so there's none: seed 3, 2026-11-04.)
## The mist stays under the lowest deck (a dropping bridge's far half).
const MIST_COLOUR: Color = Color(0.82, 0.87, 0.92)
const MIST_LIGHT_ENERGY: float = 3.4
const MIST_LIGHT_RANGE: float = 15.0


func _add_mist() -> void:
	var hall: AABB = _meta["hall"]
	var o: Vector3 = position                 # the run's start in the room
	var cx: float = hall.get_center().x - o.x
	var cz: float = hall.get_center().z - o.z
	var w: float = hall.size.x - 3.5          # between the long walls' faces
	var l: float = hall.size.z - 1.0
	var top: float = minf(0.0, int(_meta["bridge"].get("rise", 0)) * BAY) - 2.0
	var fog := FogVolume.new()
	fog.name = "Mist"
	fog.size = Vector3(w, top - PIT, l)
	fog.position = Vector3(cx, (top + PIT) * 0.5, cz)
	var fm := FogMaterial.new()
	fm.density = 0.12
	fm.albedo = MIST_COLOUR
	fm.emission = Color(0.06, 0.068, 0.076)
	fm.height_falloff = 0.5
	fm.edge_fade = 0.3
	fog.material = fm
	add_child(fog)
	var n: int = int(_meta["bridge"]["bays"])
	var k: int = 0
	var z: float = -GROUP * BAY * 0.5
	while z > -n * BAY:
		var l3 := OmniLight3D.new()
		l3.name = "MistLight_%d" % k
		l3.light_color = MIST_COLOUR
		l3.light_energy = MIST_LIGHT_ENERGY
		l3.omni_range = MIST_LIGHT_RANGE
		l3.omni_attenuation = 0.8
		l3.shadow_enabled = false
		l3.light_specular = 0.2
		l3.light_volumetric_fog_energy = 0.2      # lit from inside, the mist read as a white sheet
		l3.position = Vector3(4.0 if k % 2 == 0 else -4.0, minf(-5.5, top - 1.0), z)
		add_child(l3)
		k += 1
		z -= GROUP * BAY


## Step 3's life (BridgeHallLife): the landing on bay k's side deck with its
## lamp, mist wisps; once the room's collision is in, the gardens on the lit
## windows' sills, the passages' herbs and mushrooms, the dark growth.
var _wisps: Array[FogVolume] = []
var _time: float = 0.0
## The pit pool's and the falls' ripples' materials (their simulation_time).
var _water: Array[ShaderMaterial] = []
const WISPS: int = 5
const DARK_GROWTH: int = 70
const SHORE_GLOW: int = 12
const LANDING_LIGHT_ENERGY: float = 0.8


func _add_life(n: int, rise: int, k: int, side: float, seed_value: int) -> void:
	var life := Node3D.new()
	life.name = "Life"
	add_child(life)
	var high: float = rise * BAY
	var lamp_at: Vector3 = BridgeHallLife.landing(k, side, life)
	var l := OmniLight3D.new()
	l.name = "LandingLight"
	l.light_color = Color(1.0, 0.74, 0.45)
	l.light_energy = LANDING_LIGHT_ENERGY
	l.omni_range = 6.0
	l.omni_attenuation = 1.4
	l.shadow_enabled = false
	l.light_specular = 0.15
	l.position = lamp_at
	life.add_child(l)
	_water.append((BridgeHallLife.pool(_meta["hall"], position, life).material_override as ShaderMaterial))
	for f: Node in find_children("waterfall_*", "GreatFall", true, false):
		_water.append(BridgeHallLife.fall_foot(f as GreatFall, life, "FallFoot_%d" % _water.size()))
	var top: float = minf(0.0, high) - 2.0
	_wisps = BridgeHallLife.wisps(_meta["hall"], position, top - 1.0, WISPS, seed_value, life)
	set_process(true)
	_grow_dark.call_deferred(minf(0.0, high) - 1.0, seed_value, life)


## Once the room's collision is in (it's found by rays): the gardens, the
## passages' things to pick, the dark growth under the deck.
func _grow_dark(top: float, seed_value: int, life: Node3D) -> void:
	for _i: int in 2:
		await get_tree().physics_frame
	if not is_inside_tree():
		return
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	BridgeHallLife.gardens(_room, position, _meta.get("lit_windows", []), seed_value, life)
	var i: int = 0
	for f: Dictionary in _meta.get("forage", []):
		var c: Vector3i = f["cell"]
		var mid: Vector3 = CellGrid.cell_centre(c) + (f["shift"] as Vector3)
		mid.y = c.y * BAY + 0.3
		var dir: Vector3 = (f["dir"] as Vector3).normalized()
		var hit: Dictionary = _ray(space, mid, dir * 3.0)
		var spot: Vector3 = (_room.to_local(hit["position"]) - dir * FORAGE_OFF) if not hit.is_empty() else mid + dir * 0.9
		# Onto the cave floor (it curves up into the wall).
		var floor_hit: Dictionary = _ray(space, Vector3(spot.x, c.y * BAY + 1.0, spot.z), Vector3.DOWN * 2.0)
		spot = _room.to_local(floor_hit["position"]) if not floor_hit.is_empty() else Vector3(spot.x, c.y * BAY, spot.z)
		var xf := Transform3D(Basis(Vector3.UP, i * 2.1), spot - position)
		if str(f["kind"]) == "herb":
			BridgeHallLife.herb_patch(xf, hash([seed_value, i]), life, "PassageHerb_%d" % i)
		else:
			BridgeHallLife.pickable("mushroom", BridgeHallLife.MUSHROOM, xf, life, "PassageMushroom_%d" % i)
		i += 1
	BridgeHallLife.dark_growth(self, _meta["hall"], top + position.y, seed_value, DARK_GROWTH)
	BridgeHallLife.shore_glow(self, _meta["hall"], seed_value, SHORE_GLOW)


## How far off the rock a passage's herbs and mushrooms grow.
const FORAGE_OFF: float = 0.35


## A ray in the room's frame, from `from` along `along` (front faces only).
func _ray(space: PhysicsDirectSpaceState3D, from: Vector3, along: Vector3) -> Dictionary:
	var a: Vector3 = _room.to_global(from)
	var q := PhysicsRayQueryParameters3D.create(a, a + _room.global_basis * along)
	q.hit_back_faces = false
	return space.intersect_ray(q)


func _process(delta: float) -> void:
	_time += delta
	BridgeHallLife.drift(_wisps, _time)
	for m: ShaderMaterial in _water:
		m.set_shader_parameter("simulation_time", _time)


## Warm light at a few lit windows (BridgeHallGrammar picks them, spaced).
func _add_window_lights() -> void:
	var o: Vector3 = position
	var i: int = 0
	for q: Vector3 in _meta.get("window_lights", []):
		var l := OmniLight3D.new()
		l.name = "WindowLight_%d" % i
		l.light_color = Color(1.0, 0.72, 0.42)
		l.light_energy = 1.4
		l.omni_range = 7.0
		l.omni_attenuation = 1.2
		l.shadow_enabled = false
		l.light_specular = 0.1
		l.position = q - o
		add_child(l)
		i += 1

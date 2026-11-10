class_name CreatureDef
extends ActorDef
## An animal (phase 19): where it lives and how many, read by Fauna. One file
## per animal in actors/defs/.

## "water" (step 1), "flame" (round a burning flame), "dark_roof" (step 2) or
## "lane" (step 3: the walked lanes and rest spots of a room); later "wall".
@export var habitat: String = "water"
## "swarm", "simple" or "rigged" (the atlas's build tiers).
@export var build: String = "simple"
## Room types it lives in (RoomTypes: R07 …), and places by id ("camp",
## "lake"); "*": anywhere its habitat is (water, a flame, a dark roof), which
## is what every kind uses now.
@export var rooms: PackedStringArray = PackedStringArray()
## Room types and places it never lives in, whatever the habitat. One room
## alone: the Strata Board's Animals checkboxes (AreaPlan.Room.no_animals).
@export var not_rooms: PackedStringArray = PackedStringArray()
## "kept", "abandoned" or "any": the room's State (RoomGrammar.ABANDONED).
@export var state: String = "kept"
## Also in every abandoned room, whatever its type (bats: nobody comes here).
@export var any_abandoned: bool = false
## Rooms where it also wanders loose over the floor, not tied to a flame (the
## Garden Court's moths over the beds), and how many there.
@export var loose_rooms: PackedStringArray = PackedStringArray()
@export var loose_count: int = 0
## Flames: the share of burning flames that have any (the rest have none).
@export_range(0.0, 1.0, 0.01) var flame_share: float = 1.0
## Dark roofs: at least this high over the floor (m), and keeping this far from
## a glowing fungus (m; 0: doesn't mind).
@export var min_height: float = 2.2
@export var glow_gap: float = 0.0
## In a lived-in (kept) room at most this many groups; -1: max_groups (bats
## crowd into abandoned rooms, one roost where people still are).
@export var kept_groups: int = -1
## Dark roofs: no flame, window or daylight within this far (m).
@export var dark_radius: float = 5.0
## Only on natural rock, not a built vault (glowworms).
@export var rock_only: bool = false
## Most animals in one room (swarms of the air).
@export var room_cap: int = 200
## Its glow when the room has no fungus to take a colour from.
@export var glow_colour: Color = Color(0.4, 0.85, 1.0)
## Water: at least this deep where it swims (m), over at least min_area m2.
@export var min_depth: float = 0.12
@export var min_area: float = 1.0
## How far under the surface it swims (m): nearest and furthest.
@export var swim_depth: Vector2 = Vector2(0.06, 0.4)
## Simple: one animal per this many m2, between group_size x and y.
## Lane (cats): one per this many soft places to lie, between group_size x and y.
## Swarm: one school per this many m2 (at least one), up to max_groups, each
## of group_size x to y.
@export var area_each: float = 2.5
@export var group_size: Vector2i = Vector2i(3, 9)
@export var max_groups: int = 1
## The player this close (m) startles it.
@export var startle_radius: float = 2.2
## Startled only by steps in the water (blind fish feel them, can't see you).
@export var feels_water_only: bool = false
## A forgotten pool: the chance of one large pale survivor (and its size, x
## length_m).
@export var survivor_chance: float = 0.0
@export var survivor_scale: float = 2.4
## How strongly it shows in the dark by itself (unshaded share of its
## colour; it lights nothing, phase 19 Q9).
@export_range(0.0, 1.0, 0.01) var self_glow: float = 0.0
## Body: width and height as a share of its length (the fish's mesh).
@export var girth: Vector2 = Vector2(0.22, 0.34)
## How many colour patterns it comes in (rows of its texture).
@export var patterns: int = 4
## 0: drawn under the water like the pool's floor (washes out in a bright
## pool). Above 0: drawn over the water's surface at this opacity, so fish in
## a lit pool read clearly (the goldfish).
@export_range(0.0, 1.0, 0.01) var clarity: float = 0.0
## No eyes (the cave barb).
@export var blind: bool = false
## Pale patches on some patterns (the goldfish's white).
@export_range(0.0, 1.0, 0.01) var patchiness: float = 0.0


## This kind with `amount` times as many (an area's Animals setting,
## AreaRecipe.fauna): moths at more or fewer flames (then more round each
## once every flame has some), more or fewer in each school, pool, colony
## and roost. 1: itself.
func scaled(amount: float) -> CreatureDef:
	if is_equal_approx(amount, 1.0):
		return self
	var d: CreatureDef = duplicate() as CreatureDef
	var m: float = amount
	if habitat == "flame":
		d.flame_share = clampf(flame_share * amount, 0.0, 1.0)
		d.loose_count = roundi(loose_count * amount)
		m = maxf(1.0, flame_share * amount)     # past every flame: more round each
		if m == 1.0:
			return d
	elif habitat == "water" and build == "simple":
		d.area_each = area_each / maxf(amount, 0.01)
	elif habitat == "lane":
		# Cats: fewer soft places to lie for each one, and more at most.
		d.area_each = area_each / maxf(amount, 0.01)
		d.group_size = Vector2i(group_size.x, maxi(1, roundi(group_size.y * amount)))
		return d
	d.group_size = Vector2i(maxi(1, roundi(group_size.x * m)), maxi(1, roundi(group_size.y * m)))
	d.room_cap = maxi(1, roundi(room_cap * m))
	return d

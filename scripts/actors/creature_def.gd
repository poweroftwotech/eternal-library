class_name CreatureDef
extends ActorDef
## An animal (phase 19): where it lives and how many, read by Fauna. One file
## per animal in actors/defs/.

## "water" (step 1); later "flame", "dark_roof", "lane", "wall".
@export var habitat: String = "water"
## "swarm", "simple" or "rigged" (the atlas's build tiers).
@export var build: String = "simple"
## Room types it lives in (RoomTypes: R07 …), and places by id ("camp", "lake").
@export var rooms: PackedStringArray = PackedStringArray()
## "kept", "abandoned" or "any": the room's State (RoomGrammar.ABANDONED).
@export var state: String = "kept"
## Water: at least this deep where it swims (m), over at least min_area m2.
@export var min_depth: float = 0.12
@export var min_area: float = 1.0
## How far under the surface it swims (m): nearest and furthest.
@export var swim_depth: Vector2 = Vector2(0.06, 0.4)
## Simple: one animal per this many m2, between group_size x and y.
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

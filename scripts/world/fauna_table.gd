class_name FaunaTable
extends RefCounted
## How plentiful each animal is in each place of one world (phase 19 step 5).
##
## A place's table has three parts:
##   1. Which animals can live there and how many at most: the animals' own
##      rules (CreatureDef: habitat, rooms, state) and the area's Animals
##      setting (AreaRecipe.fauna, the Strata Board), the same in every world.
##   2. How plentiful each is in this world: one of LEVELS, drawn from the
##      world seed the first time the place is entered (roll), so two worlds
##      differ: one Mahaleh is thick with cats, another has few.
##   3. The save: the levels are written under the save's `fauna` section
##      (WorldState.fauna_levels) and read from there ever after, so a later
##      phase can change them (hunting, a food web) and the change holds.
##
## The animals a place is known by (the creature atlas's "Who lives where",
## KNOWN_BY) are never drawn below common there.

## From most to fewest, and how many of the usual number each means.
const LEVELS: PackedStringArray = ["abundant", "common", "scarce", "very_scarce"]
const AMOUNT: Dictionary = {"abundant": 1.5, "common": 1.0, "scarce": 0.5, "very_scarce": 0.2}
## The chance of each level, in LEVELS' order: for most animals, and for the
## ones a place is known by.
const CHANCE: PackedFloat32Array = [0.2, 0.5, 0.22, 0.08]
const CHANCE_KNOWN: PackedFloat32Array = [0.45, 0.55, 0.0, 0.0]
## Place id -> the animals it is known by (the atlas's first column; only
## phase 19's animals so far).
const KNOWN_BY: Dictionary = {
	"camp": ["goldfish", "cat"],
	"grand_study": ["gecko", "candle_moth", "cat"],
	"gardens": ["cave_barb"],
	"mahaleh": ["cat"],
	"forgotten_city": ["rat", "bat"],
	"lake": ["cave_barb"],
}


## The level kind `kind` has in `place` of the world with `world_seed`.
static func roll(world_seed: int, place: String, kind: String) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([world_seed, "fauna", place, kind])
	var chance: PackedFloat32Array = CHANCE_KNOWN if (KNOWN_BY.get(place, []) as Array).has(kind) else CHANCE
	var x: float = rng.randf()
	for i: int in LEVELS.size():
		x -= chance[i]
		if x < 0.0:
			return LEVELS[i]
	return "common"


## How many of the usual number a level means (1 for a level it doesn't know).
static func amount(level: String) -> float:
	return float(AMOUNT.get(level, 1.0))


## The levels of `kinds` in `place`: the save's where it has them, drawn and
## written to the save where it hasn't. `ws`: the WorldState autoload (null in
## a tool run without it: drawn for world seed 1, nothing written).
static func levels(ws: Node, place: String, kinds: PackedStringArray) -> Dictionary:
	var world_seed: int = int(ws.call("world_seed")) if ws != null else 1
	var saved: Dictionary = ws.call("fauna_levels", place) if ws != null else {}
	var out: Dictionary = {}
	for kind: String in kinds:
		var level: String = str(saved.get(kind, ""))
		if not LEVELS.has(level):
			level = roll(world_seed, place, kind)
			if ws != null:
				ws.call("set_fauna_level", place, kind, level)
		out[kind] = level
	return out

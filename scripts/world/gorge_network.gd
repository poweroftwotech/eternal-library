@tool
class_name GorgeNetwork
extends Resource
## The near gorge's walkable network (phase-6-design.md 5.7.5, phase 6 step
## 4), for an AreaRecipe: after the recipe's slots, AreaPlanner grows ledges
## on frontage slots joined by links (spans across, stairs along the cliffs)
## as a tree, starting with the main span from the Overlook.

@export var frontage: GorgeFrontage
## Every link it could have, solved ahead (tools/gorge_links.gd).
@export var links: GorgeLinks
@export var ledge: CliffLedgeGrammar
@export var chasm: ChasmGrammar
## Ledges reached from the balcony (seeded in range).
@export var ledges: Vector2i = Vector2i(4, 6)
## The main span (step 3): the recipe's slot it replaces (that span found its
## own far end; here it ends on a ledge of the far cliff), the room and
## connector it leaves from, and the cliff it crosses to.
@export var main_slot: String = "span"
@export var main_from: String = "overlook"
@export var main_connector: StringName = &"SNAP_exit_span"
@export var main_cliff: String = "right"
## Spans at least this long before a pair's length counts (shorter pairs are
## all but free; the length orders the joins).
@export var min_link: float = 6.0
## The Gorge area's low mist glows this much brighter than the camp's
## (GorgeScenery.lift_mist): the network's spans stand in front of it in the
## balcony's view, and the box art's mist floor is brighter than the camp's
## even without them.
@export_range(1.0, 3.0, 0.05) var mist_glow: float = 1.8

class_name PlacePieces
extends Resource
## An area's scenery as small scenes (phase 9, one continuous world), written
## by its bake (tools/bake_gorge.gd save_pieces): the generated part's pieces
## and the batched kit's, in order. Area.background builds them one a frame.

@export var generated: PackedStringArray = []
@export var kit: PackedStringArray = []
## The scenery's environment (the whole scene's WorldEnvironment).
@export var environment: Environment
## Each removable kit module's bounds across the whole kit
## (GorgeScenery.module_bounds), so pieces are cleared alike.
@export var module_bounds: Dictionary = {}

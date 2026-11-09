class_name ActorDef
extends Resource
## What one kind of actor is (phase 19, docs/npc/phase-19-design.md section 1):
## the part every creature, person and monster shares. One file per kind.

@export var id: StringName = &""
## English name (the atlas's).
@export var display_name: String = ""
## The Persian name, transliterated (the atlas's).
@export var local_name: String = ""
## The atlas's plate (C01 …).
@export var atlas_id: String = ""
## Nose to tail (m), the usual adult.
@export var length_m: float = 0.1
## Each one's length is length_m times a value in this range.
@export var length_spread: Vector2 = Vector2(0.85, 1.15)
## Cruising and fleeing speed (m/s).
@export var speed: Vector2 = Vector2(0.2, 0.8)
## The three main colours (the atlas's swatches), darkest role first as the
## atlas lists them.
@export var palette: PackedColorArray = PackedColorArray()

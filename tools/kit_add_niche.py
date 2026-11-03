"""Adds the working niches' growing pieces to art_src/kit/kit_dressing.blend
(room rework, step 2: your walk of 2026-11-02 asked for niches in the stacks
where plants and food grow, as in the camp).

  blender --background --factory-startup --python tools/kit_add_niche.py

Additive like kit_add_reading.py; then run tools/export_kit.bat kit_dressing.blend.

Pieces (family "dressing", origin on the floor, long side along X):
  niche_bed  a raised brick planting bed, 2 x 0.8 m, its soil 0.36 m up: the
             hearthleaf and amberroot patches (kit/dressing/forage_*.tscn,
             cut from the camp) stand on the soil.
  niche_log  a fallen, mossy log, 1.5 m long, on two stones: shelf mushrooms
             grow on it.

Wall niches (a shelf bay's recess fill, 3 m wide, back at Godot z +0.3):
  wall_hearth  a raised brick hearth (ocak): firebox, embers, a copper pot on
               a trivet, a brick hood.
  wall_herbs   a floor trough and an upper trough of soil under a small
               hanging lantern.
  wall_pantry  shelves of storage jars, a sack, a small lamp, a damp log.
"""
import math
import os
import sys

import bmesh
import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kit_blender import add_box, add_lathe, add_ngon_prism, add_tube, marker, mesh_object, module, rebuild  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BLEND = os.path.join(ROOT, "art_src", "kit", "kit_dressing.blend")
ROW_Y = 64.0     # past kit_add_reading.py's rows


def props(tags):
    return {"kit_shape": "free", "kit_family": "dressing", "size_cells": [0, 0, 0],
            "edge": "", "tags": tags, "weight": 1.0}


def niche_bed(r):
    bm = bmesh.new()
    add_box(bm, -1.0, 1.0, -0.4, -0.3, 0.0, 0.4)       # long walls
    add_box(bm, -1.0, 1.0, 0.3, 0.4, 0.0, 0.4)
    add_box(bm, -1.0, -0.9, -0.3, 0.3, 0.0, 0.4)       # ends
    add_box(bm, 0.9, 1.0, -0.3, 0.3, 0.0, 0.4)
    add_box(bm, -1.04, 1.04, -0.44, 0.44, 0.4, 0.45)   # coping
    mesh_object("niche_bed__walls-col", bm, ["brick"], r)
    bm = bmesh.new()
    add_box(bm, -0.9, 0.9, -0.3, 0.3, 0.0, 0.36)
    mesh_object("niche_bed__soil", bm, ["soil"], r)


def niche_log(r):
    bm = bmesh.new()
    add_tube(bm, [(-0.75, 0.0, 0.26), (-0.25, 0.02, 0.27), (0.25, -0.02, 0.26), (0.75, 0.0, 0.25)], 0.17, segs=8)
    mesh_object("niche_log__bark-col", bm, ["bark"], r)
    bm = bmesh.new()
    add_box(bm, -0.7, 0.6, -0.1, 0.1, 0.42, 0.45)      # moss along the top
    mesh_object("niche_log__moss", bm, ["moss"], r)
    bm = bmesh.new()
    for x in (-0.5, 0.5):
        add_ngon_prism(bm, 6, 0.16, 0.0, 0.12, cx=x, cy=0.0)
    mesh_object("niche_log__stones", bm, ["hearth_stone"], r)


# --- wall niches: a shelf bay's recess (3 m wide, the room at +Y; the recess
# runs back to y -0.4) given over to a use, as kit/dressing/recess_<use>.tscn
# picks them from recess_library -------------------------------------------------

def to_recess(r):
    """Drawn with the back at y -0.4; a recess ends at y -0.3 (Godot z +0.3,
    recess_library's slot), so everything moves 0.1 m toward the room."""
    for o in r.children:
        if o.type == "MESH":
            for v in o.data.vertices:
                v.co.y += 0.1
        else:
            o.location.y += 0.1


def jar(bm, x, y, z, h, r):
    add_lathe(bm, [(0.0, z), (r * 0.6, z), (r, z + h * 0.35), (r * 0.9, z + h * 0.75), (r * 0.45, z + h * 0.9),
                   (r * 0.5, z + h), (0.0, z + h)], cx=x, cy=y, segs=10)


def wall_hearth(r):
    """An ocak: a raised brick hearth with a soot-black firebox, embers and two
    logs, a copper pot on an iron trivet, and a brick hood above. The fire's
    light is in the fill scene (it flickers)."""
    bm = bmesh.new()
    add_box(bm, -1.2, 1.2, -0.4, 0.18, 0.0, 0.4)             # platform
    for sx in (-1, 1):
        add_box(bm, min(sx * 0.55, sx * 0.75), max(sx * 0.55, sx * 0.75), -0.4, 0.1, 0.4, 1.35)   # cheeks
    add_box(bm, -0.85, 0.85, -0.4, 0.08, 1.35, 1.6)           # hood
    add_box(bm, -0.7, 0.7, -0.4, -0.05, 1.6, 2.2)             # flue
    add_box(bm, -1.45, 1.45, -0.3, -0.28, 0.0, 2.3)           # brick back, in front of the bay's wooden lining
    mesh_object("wall_hearth__brick-col", bm, ["brick"], r)
    bm = bmesh.new()
    add_box(bm, -0.55, 0.55, -0.28, -0.24, 0.4, 1.35)         # soot back
    mesh_object("wall_hearth__soot", bm, ["char"], r)
    bm = bmesh.new()
    add_box(bm, -0.4, 0.4, -0.3, 0.04, 0.4, 0.45)
    mesh_object("wall_hearth__embers", bm, ["emit_ember"], r)
    bm = bmesh.new()
    add_tube(bm, [(-0.35, -0.2, 0.48), (0.3, -0.05, 0.5)], 0.05, segs=6)
    add_tube(bm, [(0.35, -0.22, 0.48), (-0.25, -0.02, 0.51)], 0.045, segs=6)
    mesh_object("wall_hearth__logs", bm, ["char"], r)
    bm = bmesh.new()
    for k in range(3):
        a = -math.pi / 2 + k * 2 * math.pi / 3     # one leg at the back, none in front of the fire
        add_box(bm, math.cos(a) * 0.2 - 0.015, math.cos(a) * 0.2 + 0.015,
                -0.12 + math.sin(a) * 0.2 - 0.015, -0.12 + math.sin(a) * 0.2 + 0.015, 0.4, 0.62)
    mesh_object("wall_hearth__trivet", bm, ["iron"], r)
    bm = bmesh.new()
    add_lathe(bm, [(0.0, 0.6), (0.14, 0.6), (0.22, 0.7), (0.23, 0.82), (0.19, 0.9), (0.2, 0.93), (0.0, 0.93)],
              cx=0.0, cy=-0.12, segs=14)
    mesh_object("wall_hearth__pot", bm, ["camp_copper"], r)
    to_recess(r)


def wall_herbs(r):
    """A tiered herb garden: a deep wooden trough on the floor and a shallow one
    on brackets above, both of soil, with a small lantern hung under the arch
    (plants by light). The forage patches are in the fill scene."""
    bm = bmesh.new()
    add_box(bm, -1.3, 1.3, -0.4, 0.12, 0.0, 0.5)              # floor trough
    add_box(bm, -1.3, 1.3, -0.4, -0.02, 1.1, 1.38)            # upper trough
    for x in (-1.0, 0.0, 1.0):
        add_box(bm, x - 0.04, x + 0.04, -0.4, -0.06, 0.95, 1.1)   # brackets
    mesh_object("wall_herbs__troughs-col", bm, ["wood"], r)
    bm = bmesh.new()
    add_box(bm, -1.25, 1.25, -0.36, 0.07, 0.5, 0.52)
    add_box(bm, -1.25, 1.25, -0.36, -0.06, 1.38, 1.4)
    mesh_object("wall_herbs__soil", bm, ["soil"], r)
    bm = bmesh.new()
    add_box(bm, -0.01, 0.01, -0.2, -0.18, 2.85, 3.3)          # chain
    add_box(bm, -0.08, 0.08, -0.27, -0.11, 2.6, 2.63)         # base
    add_box(bm, -0.08, 0.08, -0.27, -0.11, 2.84, 2.87)        # cap
    mesh_object("wall_herbs__lantern", bm, ["brass"], r)
    bm = bmesh.new()
    add_box(bm, -0.06, 0.06, -0.25, -0.13, 2.63, 2.84)
    mesh_object("wall_herbs__glass", bm, ["emit_lantern"], r)
    marker("LIGHT_desk__herbs", r, (0.0, -0.19, 2.6), {"range": 3.6, "energy": 1.3})
    to_recess(r)


def wall_pantry(r):
    """A pantry: three shelves of storage jars over a damp, mossy log where
    shelf mushrooms grow (the forage patches are in the fill scene), with a
    small oil lamp on the middle shelf."""
    bm = bmesh.new()
    for z in (0.62, 1.22, 1.82):
        add_box(bm, -1.35, 1.35, -0.4, 0.15, z, z + 0.05)
    for x in (-1.35, 1.3):
        add_box(bm, x, x + 0.05, -0.4, 0.15, 0.0, 1.87)
    mesh_object("wall_pantry__shelves-col", bm, ["wood"], r)
    bm = bmesh.new()
    for (x, z, h, rad) in [(-1.05, 0.67, 0.4, 0.13), (-0.7, 0.67, 0.3, 0.1), (0.25, 0.67, 0.42, 0.14), (0.65, 0.67, 0.3, 0.11),
                           (1.0, 0.67, 0.36, 0.12), (-1.0, 1.27, 0.3, 0.1), (-0.6, 1.27, 0.38, 0.13), (0.55, 1.27, 0.32, 0.12),
                           (0.95, 1.27, 0.28, 0.1), (-0.9, 1.87, 0.34, 0.12), (-0.35, 1.87, 0.26, 0.09), (0.3, 1.87, 0.36, 0.12),
                           (0.85, 1.87, 0.3, 0.11)]:
        jar(bm, x, -0.15, z, h, rad)
    mesh_object("wall_pantry__jars", bm, ["earthenware"], r)
    bm = bmesh.new()
    add_box(bm, 0.75, 1.25, -0.38, 0.05, 0.0, 0.42)           # a sack
    mesh_object("wall_pantry__sack", bm, ["linen"], r)
    bm = bmesh.new()
    add_tube(bm, [(-1.25, -0.1, 0.17), (-0.6, -0.08, 0.18), (0.1, -0.12, 0.17), (0.6, -0.1, 0.16)], 0.16, segs=8)
    mesh_object("wall_pantry__log-col", bm, ["bark"], r)
    bm = bmesh.new()
    add_box(bm, -1.2, 0.5, -0.18, -0.02, 0.32, 0.34)
    mesh_object("wall_pantry__moss", bm, ["moss"], r)
    bm = bmesh.new()
    add_lathe(bm, [(0.0, 1.27), (0.07, 1.27), (0.05, 1.31), (0.06, 1.35), (0.0, 1.36)], cx=-0.15, cy=-0.12, segs=10)
    mesh_object("wall_pantry__lamp", bm, ["brass"], r)
    bm = bmesh.new()
    add_lathe(bm, [(0.0, 1.36), (0.03, 1.38), (0.035, 1.43), (0.0, 1.47)], cx=-0.15, cy=-0.12, segs=8)
    mesh_object("wall_pantry__glass", bm, ["emit_lantern"], r)
    marker("LIGHT_desk__pantry", r, (-0.15, -0.12, 1.42))
    to_recess(r)


MODULES = [
    ("M_niche_bed", props("brick,soil,garden,niche"), niche_bed),
    ("M_niche_log", props("wood,moss,garden,niche"), niche_log),
    ("M_wall_hearth", dict(props("brick,fire,niche"), kit_rev=5), wall_hearth),
    ("M_wall_herbs", dict(props("wood,soil,garden,light,niche"), kit_rev=2), wall_herbs),
    ("M_wall_pantry", dict(props("wood,earthenware,storage,light,niche"), kit_rev=2), wall_pantry),
]
REBUILD = [("M_wall_hearth", 5), ("M_wall_herbs", 2), ("M_wall_pantry", 2)]


def main():
    bpy.ops.wm.open_mainfile(filepath=BLEND)
    added = []
    for i, (name, p, build) in enumerate(MODULES):
        if bpy.data.objects.get(name) is None:
            build(module(name, (i * 8.0, ROW_Y, 0.0), p))
            added.append(name)
    added += ["%s (rebuilt rev %d)" % (n, v) for (n, v) in REBUILD if rebuild(n, v, MODULES)]
    if not added:
        print("kit_add_niche: all modules already present; nothing to do.")
        return
    bpy.ops.wm.save_as_mainfile(filepath=BLEND)
    print("kit_add_niche: added %s" % ", ".join(added))


main()

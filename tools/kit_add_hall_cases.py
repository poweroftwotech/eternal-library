"""Adds the Hypostyle Stacks' tall wall bookcases to art_src/kit/kit_hall.blend
(room rework step 4: your Lower Stacks walk of 2026-11-03 asked for the
freestanding cases out of the hall and tall, floor-to-ceiling shelves along
its walls instead, clear of the doorways).

  blender --background --factory-startup --python tools/kit_add_hall_cases.py

Additive like kit_add_r03.py; then run tools/export_kit.bat kit_hall.blend.

Pieces (family "dressing", free, placed on a wall edge's frame: X 0..4 along
the wall, the wall face at Y = T, the hall at +Y):
  case_wall_tall_4m         a bookcase 3.3 m wide and 5.9 m tall against the
                            wall, standing clear of the cornice at 4 m and
                            reaching the tile band under the domes; thirteen
                            shelves of books (a case_tall socket).
  case_wall_tall_ladder_4m  the same with a brass rail at 4.4 m and a
                            library ladder hooked on it.
"""
import os
import sys

import bmesh
import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kit_blender import T, add_box, marker, mesh_object, module, rebuild  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BLEND = os.path.join(ROOT, "art_src", "kit", "kit_hall.blend")
ROW_Y = -56.0     # past kit_add_r03.py's row

X0, X1 = 0.35, 3.65         # the case's ends: clear of a corner's next wall and its recess (rev 2)
Y0 = T + 0.16               # its back, in front of the 4 m cornice
Y1 = Y0 + 0.42              # its front
TOP = 5.9                   # under the tile band (5.9-6.2)
PLINTH = 0.12
BOARDS = [0.54 + 0.42 * k for k in range(12)]     # shelf boards (bottom); books stand at +0.05


def props(tags):
    return {"kit_shape": "free", "kit_family": "dressing", "size_cells": [1, 0, 0],
            "edge": "", "tags": tags, "weight": 1.0}


def carcass(r, name):
    bm = bmesh.new()
    add_box(bm, X0, X0 + 0.06, Y0, Y1, 0.0, TOP)                  # ends
    add_box(bm, X1 - 0.06, X1, Y0, Y1, 0.0, TOP)
    add_box(bm, X0, X1, Y0, Y0 + 0.03, 0.0, TOP)                  # back
    add_box(bm, X0 - 0.04, X1 + 0.04, Y0, Y1 + 0.05, TOP - 0.1, TOP)    # crown
    add_box(bm, X0 + 0.06, X1 - 0.06, Y0, Y1 - 0.02, 0.0, PLINTH)       # plinth
    for z in BOARDS:
        add_box(bm, X0 + 0.06, X1 - 0.06, Y0, Y1, z, z + 0.05)
    add_box(bm, 1.98, 2.02, Y0, Y1 - 0.01, 0.0, TOP - 0.1)        # a middle upright
    mesh_object(name + "__body-col", bm, ["wood"], r)
    marker("SOCKET_case_tall__" + name, r, (2.0, Y0 + 0.03, 0.0), {"socket_set": "case_tall"})


def case_wall_tall(r):
    carcass(r, "case_wall_tall_4m")


def case_wall_tall_ladder(r):
    carcass(r, "case_wall_tall_ladder_4m")
    bm = bmesh.new()
    add_box(bm, X0 + 0.1, X1 - 0.1, Y1 + 0.08, Y1 + 0.11, 4.38, 4.42)    # the rail
    for x in (X0 + 0.15, 2.0, X1 - 0.15):
        add_box(bm, x - 0.02, x + 0.02, Y1 - 0.01, Y1 + 0.11, 4.36, 4.44)   # its brackets
    mesh_object("case_wall_tall_ladder_4m__rail", bm, ["brass"], r)
    # The ladder hooks on the rail at 4.4 m and stands 1.1 m out at its foot.
    bm = bmesh.new()
    xa, foot, top_y = 2.9, Y1 + 1.1, Y1 + 0.12
    for x in (xa - 0.22, xa + 0.22):
        stile = bm.verts
        v = [stile.new(p) for p in ((x - 0.025, foot, 0.0), (x + 0.025, foot, 0.0), (x + 0.025, top_y, 4.45), (x - 0.025, top_y, 4.45))]
        w = [stile.new((p.co.x, p.co.y + 0.05, p.co.z)) for p in v]
        for f in ((v[0], v[1], v[2], v[3]), (w[3], w[2], w[1], w[0]), (v[0], w[0], w[1], v[1]), (v[2], w[2], w[3], v[3]),
                  (v[1], w[1], w[2], v[2]), (v[3], w[3], w[0], v[0])):
            bm.faces.new(f)
    for k in range(1, 14):
        t = k / 14.0
        y = foot + (top_y - foot) * t
        z = 4.45 * t
        add_box(bm, xa - 0.22, xa + 0.22, y, y + 0.04, z - 0.02, z + 0.02)
    mesh_object("case_wall_tall_ladder_4m__ladder", bm, ["wood"], r)


MODULES = [
    ("M_case_wall_tall_4m", dict(props("wood,storage,hall,books"), kit_rev=2), case_wall_tall),
    ("M_case_wall_tall_ladder_4m", dict(props("wood,brass,storage,hall,books"), kit_rev=2), case_wall_tall_ladder),
]
REBUILD = [("M_case_wall_tall_4m", 2), ("M_case_wall_tall_ladder_4m", 2)]


def main():
    bpy.ops.wm.open_mainfile(filepath=BLEND)
    added = []
    for i, (name, p, build) in enumerate(MODULES):
        if bpy.data.objects.get(name) is None:
            build(module(name, (i * 8.0, ROW_Y, 0.0), p))
            added.append(name)
    added += ["%s (rebuilt rev %d)" % (n, v) for (n, v) in REBUILD if rebuild(n, v, MODULES)]
    if not added:
        print("kit_add_hall_cases: all modules already present; nothing to do.")
        return
    bpy.ops.wm.save_as_mainfile(filepath=BLEND)
    print("kit_add_hall_cases: added %s" % ", ".join(added))


main()

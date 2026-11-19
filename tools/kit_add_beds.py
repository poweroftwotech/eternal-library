"""Seeds a home's bed into art_src/kit/kit_quarter.blend (phase 21 step 4,
docs/npc/phase-21-approval.md Q8): the bedding as it is by day and by night.

  blender --background --factory-startup --python tools/kit_add_beds.py

Adds only the modules that are not in the file yet (modules edited by hand
are never touched). Then run tools/export_kit.bat kit_quarter.blend.

  qt_bed_roll   free: the bedding rolled up and tied, small enough to lie out
                of the way against a wall (0.7 m long, 0.26 across). Not solid.
  qt_bed_laid   free: the same bedding laid out, for someone lying on it: a
                thin mattress 1.85 x 0.72 m, a bolster under the head, a
                blanket folded at the foot.
                Not solid. A Resident shows it in place of the roll while
                they sleep (scripts/actors/resident.gd).

Frame (Blender): Z up, origin on the floor at the middle, the long side
along X; the laid bed's head is toward +X.
"""
import math
import os
import sys

import bmesh
import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kit_blender import add_box, add_tube, mesh_object, module, rebuild  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BLEND = os.path.join(ROOT, "art_src", "kit", "kit_quarter.blend")
ROW_Y = -260.0


def props(tags):
    return {"kit_shape": "free", "kit_family": "dressing", "size_cells": [0, 0, 0], "edge": "", "tags": tags, "weight": 1.0}


def solid(name, root, mats, build):
    bm = bmesh.new()
    build(bm)
    return mesh_object(name, bm, mats, root)


def bed_roll(r):
    solid("qt_bed_roll__roll", r, ["linen"], lambda bm: add_tube(bm, [(-0.35, 0.0, 0.13), (0.35, 0.0, 0.13)], 0.13, 12))
    solid("qt_bed_roll__blanket", r, ["cloth"], lambda bm: add_tube(bm, [(-0.3, 0.0, 0.13), (0.3, 0.0, 0.13)], 0.138, 12))
    solid("qt_bed_roll__ties", r, ["camp_leather"], lambda bm: (add_tube(bm, [(-0.22, 0.0, 0.13), (-0.18, 0.0, 0.13)], 0.146, 12),
                                                                add_tube(bm, [(0.18, 0.0, 0.13), (0.22, 0.0, 0.13)], 0.146, 12)))


def bed_laid(r):
    solid("qt_bed_laid__mattress", r, ["linen"], lambda bm: add_box(bm, -0.925, 0.925, -0.36, 0.36, 0.0, 0.06))
    solid("qt_bed_laid__bolster", r, ["cloth"], lambda bm: add_tube(bm, [(0.74, -0.27, 0.11), (0.74, 0.27, 0.11)], 0.07, 10))
    solid("qt_bed_laid__blanket", r, ["cloth"], lambda bm: (add_box(bm, -0.94, -0.5, -0.375, 0.375, 0.06, 0.1),
                                                               add_box(bm, -0.92, -0.56, -0.37, 0.37, 0.1, 0.13)))


MODULES = [
    ("M_qt_bed_roll", props("cloth,quarter"), bed_roll),
    ("M_qt_bed_laid", props("cloth,quarter"), bed_laid),
]

# Script-made modules remade in place at a new revision (hand edits are lost).
REBUILD = [("M_qt_bed_laid", 3)]   # rev 3: the blanket folded at the foot (a hump over the sleeper never covered knees and hands)


def main():
    bpy.ops.wm.open_mainfile(filepath=BLEND)
    added = []
    x = 0.0
    for (name, p, build) in MODULES:
        if bpy.data.objects.get(name) is None:
            build(module(name, (x, ROW_Y, 0.0), p))
            added.append(name)
        x += 6.0
    rebuilt = [n for (n, v) in REBUILD if rebuild(n, v, MODULES)]
    if not added and not rebuilt:
        print("kit_add_beds: everything already present; nothing to do.")
        return
    bpy.ops.wm.save_as_mainfile(filepath=BLEND)
    print("kit_add_beds: added %s; rebuilt %s" % (", ".join(added) or "nothing", ", ".join(rebuilt) or "nothing"))


main()

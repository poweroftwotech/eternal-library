"""Seeds the gorge's walkable pieces into art_src/kit/kit_chasm.blend
(phase-6-design.md 5.7.10, steps 2-4: the Overlook, the Chasm Spans R10,
the cliff ledges).

  blender --background --factory-startup --python tools/kit_add_r10.py

Creates kit_chasm.blend if it doesn't exist, then adds only the modules that
are not in it yet. Modules already in the file (including ones you edited by
hand) are never touched, so re-running is safe. Then run tools/export_kit.bat.

Materials are the gorge's (kit/materials/gorge_*), so the walkways match the
architecture round them. Everything you can reach has a parapet and an
invisible guard to 2 m (phase 6 Q4: you can't fall off).

New modules (laid out on a row at Blender Y = -160 for viewing):
  chasm_parapet_4m   edge: a balustrade on the cell's edge (a sandstone
                     plinth, turned balusters, a gold rail), and a guard
                     (collision only) 2 m high
  cliff_ledge_4m     cell: a walkway slab (paving, a faience fascia) on a
                     stepped pendant corbel
  chasm_stair_flight cell, 2 bays: one storey down over 8 m (20 steps of
                     0.2 m), one masonry mass to a storey under its foot,
                     balustrades on its edges as chasm_parapet_4m's, a
                     ramp over the nosings and guards for walking; it
                     descends toward +Y (the room's -Z)
  chasm_lamp_post    free: a post and lantern on a parapet (a lantern light)
"""
import math
import os
import sys

import bmesh
import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kit_blender import (add_box, add_lathe, add_obox, marker, mesh_object, module, rebuild)  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BLEND = os.path.join(ROOT, "art_src", "kit", "kit_chasm.blend")
ROW_Y = -160.0
GUARD = 2.0        # the invisible guard's height over the walk
RAIL = 1.1         # the balustrade's height


def props(shape, size, edge, tags, family="walls", weight=1.0):
    return {"kit_shape": shape, "kit_family": family, "size_cells": size,
            "edge": edge, "tags": tags, "weight": weight}


def solid(name, root, mats, build):
    bm = bmesh.new()
    build(bm)
    return mesh_object(name, bm, mats, root)


def balustrade(root, name, length=4.0, y0=0.0):
    """A plinth course, turned balusters every half metre, a gold rail; along
    X 0..length on the edge's inner side (Y y0 .. y0 + 0.36)."""
    solid(name + "__plinth", root, ["gorge_sandstone"], lambda bm: add_box(bm, 0.0, length, y0, y0 + 0.36, 0.0, 0.25))

    def balusters(bm):
        n = int(round(length / 0.5))
        for k in range(n):
            add_lathe(bm, [(0.07, 0.25), (0.11, 0.33), (0.06, 0.5), (0.09, 0.75), (0.06, 0.95), (0.08, RAIL - 0.08)],
                      cx=(k + 0.5) * length / n, cy=y0 + 0.18, segs=8)
    solid(name + "__balusters", root, ["gorge_sandstone"], balusters)
    solid(name + "__rail", root, ["gorge_gold"], lambda bm: add_box(bm, 0.0, length, y0 - 0.02, y0 + 0.38, RAIL - 0.08, RAIL))
    solid(name + "__guard-colonly", root, ["gorge_sandstone"], lambda bm: add_box(bm, 0.0, length, y0, y0 + 0.36, 0.0, GUARD))


def parapet(r):
    balustrade(r, "chasm_parapet_4m")


def ledge(r):
    solid("cliff_ledge_4m__walk-col", r, ["gorge_sandstone"], lambda bm: add_box(bm, 0.0, 4.0, 0.0, 4.0, -0.45, 0.0))

    def fascia(bm):
        add_box(bm, -0.02, 4.02, -0.02, 4.02, -0.75, -0.45)
    solid("cliff_ledge_4m__fascia", r, ["gorge_faience"], fascia)

    def corbel(bm):
        for (h, z0, z1) in ((1.3, -1.15, -0.75), (0.8, -1.65, -1.15), (0.4, -2.3, -1.65)):
            add_box(bm, 2.0 - h, 2.0 + h, 2.0 - h, 2.0 + h, z0, z1)
    solid("cliff_ledge_4m__corbel", r, ["gorge_sandstone"], corbel)


def add_yz_prism(bm, outline, x0, x1):
    """Extrude a (y, z) outline along X, x0 .. x1: walls that follow a slope."""
    a = [bm.verts.new((x0, y, z)) for (y, z) in outline]
    b = [bm.verts.new((x1, y, z)) for (y, z) in outline]
    bm.faces.new(list(reversed(a)))
    bm.faces.new(b)
    n = len(outline)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((a[i], a[j], b[j], b[i]))


FLIGHT_FOOT = -8.0   # the flight is one masonry mass down to here (a storey under its foot)
PARAPET = 0.0        # its balustrades stand this far in from the mass's edges


def stair_flight(r):
    """Rev 3: one masonry mass, balustrades on its edges as the landing's
    (chasm_parapet_4m: a stone plinth, turned balusters, a gold rail), ends
    square. (Rev 1's thin tiled cheeks poked into the landing; rev 2's solid
    parapets didn't match the balustrades round them.)"""
    run, drop, steps = 8.0, 4.0, 20
    tread, rise = run / steps, drop / steps

    def treads(bm):
        for k in range(steps):
            add_box(bm, 0.0, 4.0, k * tread, (k + 1) * tread, FLIGHT_FOOT, -(k + 1) * rise)
    solid("chasm_stair_flight__steps", r, ["gorge_sandstone"], treads)

    def line(y):
        return -rise / 2 - rise / tread * y
    inner = (PARAPET, 4.0 - PARAPET - 0.36)      # each balustrade's inner face

    def plinths(bm):
        for x in inner:
            add_yz_prism(bm, [(0.0, line(0.0) - 0.45), (run, line(run) - 0.45), (run, line(run) + 0.25), (0.0, line(0.0) + 0.25)], x, x + 0.36)
    solid("chasm_stair_flight__plinth", r, ["gorge_sandstone"], plinths)

    def balusters(bm):
        n = int(round(run / 0.5))
        for x in inner:
            for k in range(n):
                y = (k + 0.5) * run / n
                base = line(y) + 0.25
                add_lathe(bm, [(0.07, base), (0.11, base + 0.08), (0.06, base + 0.25), (0.09, base + 0.5), (0.06, base + 0.7), (0.08, base + 0.77)],
                          cx=x + 0.18, cy=y, segs=8)
    solid("chasm_stair_flight__balusters", r, ["gorge_sandstone"], balusters)

    def rails(bm):
        for x in inner:
            add_yz_prism(bm, [(0.0, line(0.0) + 1.02), (run, line(run) + 1.02), (run, line(run) + 1.1), (0.0, line(0.0) + 1.1)], x - 0.02, x + 0.38)
    solid("chasm_stair_flight__rail", r, ["gorge_gold"], rails)
    slope = math.atan2(drop, run)
    length = math.hypot(run, drop)
    # The walk: one plane through the step noses (the player climbs slopes).
    walk = 4.0 - 2 * (PARAPET + 0.36)
    solid("chasm_stair_flight__ramp-colonly", r, ["gorge_sandstone"],
          lambda bm: add_obox(bm, (2.0, run / 2, -drop / 2 - 0.15 / math.cos(slope)), (walk, length, 0.3), (-slope, 0.0, 0.0)))

    def guards(bm):
        for x in inner:
            add_yz_prism(bm, [(0.0, line(0.0) - 0.5), (run, line(run) - 0.5), (run, line(run) + GUARD), (0.0, line(0.0) + GUARD)], x, x + 0.36)
    solid("chasm_stair_flight__guards-colonly", r, ["gorge_sandstone"], guards)


def lamp_post(r):
    solid("chasm_lamp_post__post", r, ["gorge_gold"], lambda bm: add_lathe(bm, [(0.12, 0.0), (0.06, 0.15), (0.05, 1.9), (0.09, 2.0)], segs=8))

    def cage(bm):
        add_box(bm, -0.16, 0.16, -0.16, 0.16, 2.0, 2.06)
        add_box(bm, -0.18, 0.18, -0.18, 0.18, 2.5, 2.56)
        for (sx, sy) in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
            add_box(bm, sx * 0.14 - 0.02, sx * 0.14 + 0.02, sy * 0.14 - 0.02, sy * 0.14 + 0.02, 2.06, 2.5)
    solid("chasm_lamp_post__cage", r, ["gorge_gold"], cage)
    solid("chasm_lamp_post__glass", r, ["emit_lantern"], lambda bm: add_box(bm, -0.11, 0.11, -0.11, 0.11, 2.08, 2.48))
    marker("LIGHT_lantern__post", r, (0.0, 0.0, 2.3))


MODULES = [
    ("M_chasm_parapet_4m", props("edge", [1, 1, 0], "none", "gorge,rail"), parapet),
    ("M_cliff_ledge_4m", props("cell", [1, 0, 1], "", "gorge,floor,ledge"), ledge),
    ("M_chasm_stair_flight", props("cell", [1, 1, 2], "", "gorge,vertical"), stair_flight),
    ("M_chasm_lamp_post", props("free", [0, 1, 0], "", "gorge,lamp,light", family="dressing"), lamp_post),
]


def main():
    if os.path.exists(BLEND):
        bpy.ops.wm.open_mainfile(filepath=BLEND)
    else:
        bpy.ops.wm.read_factory_settings(use_empty=True)
    # Script-made modules rebuilt when their revision rises (hand edits to
    # them are lost; nobody has edited these in Blender).
    REVS = {"M_chasm_stair_flight": 3}
    rebuilt = [name for (name, rev) in REVS.items() if rebuild(name, rev, MODULES)]
    added = []
    x = 0.0
    for (name, p, build) in MODULES:
        if bpy.data.objects.get(name) is None:
            build(module(name, (x, ROW_Y, 0.0), p))
            added.append(name)
        x += 12.0
    if not added and not rebuilt:
        print("kit_add_r10: everything already present; nothing to do.")
        return
    os.makedirs(os.path.dirname(BLEND), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=BLEND)
    print("kit_add_r10: added %s; rebuilt %s" % (", ".join(added) or "nothing", ", ".join(rebuilt) or "nothing"))


main()

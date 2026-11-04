"""Seeds the R21 Bridge Hall modules into art_src/kit/kit_bridgehall.blend
(phase 12, docs/environment/phase-12-approval.md).

  blender --background --factory-startup --python tools/kit_add_r21.py

Creates kit_bridgehall.blend if it doesn't exist, then adds only the modules
that are not in it yet (hand edits are kept). Then run tools/export_kit.bat.

The hall (BridgeHallGrammar, scripts/gen/bridge_hall_grammar.gd): 5 bays wide,
6-8 bays long, two storeys of drop under the bridge's deck (Z 0) and three
storeys of wall over it, the rock roof from 12 m. At each end a dark cave
passage, two cells and a bend, leads from the area's door to the hall.

New modules (laid out on a row at Blender Y = -120 for viewing):
  bh_cave_straight   cell: a rough rock passage along Y, open at both ends;
                     its ends are the canonical profile (CAVE), so pieces join.
  bh_cave_bend       cell: the passage turning from its S end (Y 0) to its E
                     end (X 4); turned in Godot for the other bends.
  bh_cave_mouth      edge: where a passage opens into the hall: rock from the
                     4 x 4 m square of the end wall's hole in to the profile.
  bh_end_wall_c<1|3>_<lv|up|dn>_<hi|lo>  edge, 5 bays x 6 storeys: a hall's end wall of rough
                     rock (Z -8..12), its mouth's hole in bay 1 or 3 on the
                     entry's storey or the far door's, an outcrop round
                     the older bridge's carved door in the other bay.
  bh_roof_5x6/7/8    cell: the rock roof over the hall (from 12 m at the walls
                     to about 16 m), with stalactites.
  bh_pit_5x6/7/8     cell: the floor of the drop (Z -8), rock and boulders,
                     walkable (the fall catch puts you back before you land).
"""
import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import noise

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kit_blender import add_box, add_lathe, add_obox, mesh_object, module, rebuild  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BLEND = os.path.join(ROOT, "art_src", "kit", "kit_bridgehall.blend")
ROW_Y = -120.0
ROCK = "cave_rock"
WIDTH = 5            # hall bays across
BELOW = 2            # storeys of drop under the deck (the area envelopes stop 8 m down)
ABOVE = 3            # storeys of wall over it
ROOF_Z = 12.0
PIT_Z = -8.0
CAVE_SEGS = 16       # points round the passage profile
CAVE_HALF = 1.65     # its half width at the floor
CAVE_TOP = 3.3       # its height
CAVE_ROUGH = 0.35    # how far the rock strays from the profile mid-piece


def props(shape, size, edge, tags, family="walls", weight=1.0):
    return {"kit_shape": shape, "kit_family": family, "size_cells": size,
            "edge": edge, "tags": tags, "weight": weight}


def cave_profile():
    """The passage's cross-section (u across, v up), from the right foot over
    the top to the left foot: a squashed arch, open at the floor."""
    pts = []
    for j in range(CAVE_SEGS + 1):
        a = math.pi * j / CAVE_SEGS
        c, s = math.cos(a), math.sin(a)
        u = CAVE_HALF * math.copysign(abs(c) ** 0.8, c)
        v = CAVE_TOP * (abs(s) ** 0.7)
        pts.append((u, v))
    return pts


def rough(p, scale=0.55, seed=0.0):
    return noise.noise((p[0] * scale, p[1] * scale, p[2] * scale + seed)) * 0.75 \
        + noise.noise((p[0] * 1.7, p[1] * 1.7, p[2] * 1.7 + seed + 5.0)) * 0.25


def cave_tube(name, r, path):
    """A rock passage along `path` (n samples of (centre (x, y), forward
    (fx, fy))): the profile at each, pushed out by noise mid-piece; faces
    wound to look in. Its floor is the cell's square, flat."""
    prof = cave_profile()
    n = len(path)
    bm = bmesh.new()
    rings = []
    for i, ((cx, cy), (fx, fy)) in enumerate(path):
        ax, ay = fy, -fx                       # across: u
        taper = math.sin(math.pi * i / (n - 1))
        ring = []
        for (u, v) in prof:
            x, y, z = cx + ax * u, cy + ay * u, v
            k = taper * CAVE_ROUGH * rough((x, y, z), seed=3.1)
            ou, ov = u, v - 1.4               # outward from the passage's middle
            ln = math.hypot(ou, ov) or 1.0
            du, dv = ou / ln * k, ov / ln * k
            if v < 0.05:
                dv = 0.0                       # the feet stay on the floor
            ring.append(bm.verts.new((cx + ax * (u + du), cy + ay * (u + du), v + dv)))
        rings.append(ring)
    for i in range(n - 1):
        for j in range(CAVE_SEGS):
            bm.faces.new((rings[i][j], rings[i][j + 1], rings[i + 1][j + 1], rings[i + 1][j]))
    mesh_object(name + "__rock-col", bm, [ROCK], r, recalc=False)
    fb = bmesh.new()
    vs = [[fb.verts.new((4.0 * i / 8, 4.0 * j / 8, 0.0)) for j in range(9)] for i in range(9)]
    for i in range(8):
        for j in range(8):
            fb.faces.new((vs[i][j], vs[i + 1][j], vs[i + 1][j + 1], vs[i][j + 1]))
    mesh_object(name + "__floor", fb, [ROCK], r, recalc=False)
    cb = bmesh.new()
    add_box(cb, 0.0, 4.0, 0.0, 4.0, -0.3, 0.0)
    mesh_object(name + "__floor-colonly", cb, [ROCK], r)


def cave_straight(r):
    cave_tube("bh_cave_straight", r, [((2.0, 4.0 * i / 8), (0.0, 1.0)) for i in range(9)])


def cave_bend(r):
    """From the S end (2, 0) heading +Y round to the E end (4, 2) heading +X,
    about (4, 0)."""
    path = []
    for i in range(9):
        phi = math.pi - (math.pi / 2) * i / 8
        path.append(((4.0 + 2.0 * math.cos(phi), 2.0 * math.sin(phi)), (math.sin(phi), -math.cos(phi))))
    cave_tube("bh_cave_bend", r, path)


def _along(poly, n):
    """n + 1 points evenly along a polyline by length."""
    seg = [math.dist(poly[i], poly[i + 1]) for i in range(len(poly) - 1)]
    total = sum(seg)
    out = []
    for k in range(n + 1):
        d = total * k / n
        i = 0
        while i < len(seg) - 1 and d > seg[i]:
            d -= seg[i]
            i += 1
        t = d / seg[i] if seg[i] > 0 else 0.0
        a, b = poly[i], poly[i + 1]
        out.append((a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t))
    return out


def cave_mouth(r):
    """Edge module (X 0..4, the hall toward +Y): rock from the end wall's
    square hole (X 0..4, Z 0..4, at Y 0) in to the passage's profile, bulging
    a little into the hall between."""
    n = 32
    outer = _along([(0.0, 0.0), (0.0, 4.0), (4.0, 4.0), (4.0, 0.0)], n)
    prof = [(2.0 + u, v) for (u, v) in reversed(cave_profile())]     # left foot first
    inner = _along(prof, n)
    rows = 4
    bm = bmesh.new()
    grid = []
    for k in range(rows + 1):
        t = k / rows
        row = []
        for j in range(n + 1):
            x = outer[j][0] + (inner[j][0] - outer[j][0]) * t
            z = outer[j][1] + (inner[j][1] - outer[j][1]) * t
            y = math.sin(math.pi * t) * (0.25 + 0.35 * (rough((x, 0.0, z), 0.8, 7.0) + 1.0) * 0.5)
            if z < 0.05:
                y = 0.0
            row.append(bm.verts.new((x, y, z)))
        grid.append(row)
    for k in range(rows):
        for j in range(n):
            bm.faces.new((grid[k][j], grid[k][j + 1], grid[k + 1][j + 1], grid[k + 1][j]))
    mesh_object("bh_cave_mouth__rock-col", bm, [ROCK], r, recalc=False)


STOREY_NAME = {-1: "dn", 0: "lv", 1: "up"}
OLD_NAME = {1: "hi", -1: "lo"}
DOOR_W, DOOR_H = 4.0, 5.0     # persian_carved_door's panel (tools/kit_add_persian.py)
OUTCROP = 1.85               # its back flush with the wall, its face 1.8 m in


def end_wall_name(hole, storey, old):
    return "bh_end_wall_c%d_%s_%s" % (hole, STOREY_NAME[storey], OLD_NAME[old])


def end_wall(hole, storey, old):
    """Edge module X 0..20, Z PIT_Z..ROOF_Z, the hall toward +Y: rough rock
    bulging up to 0.8 m into the hall, flat round the mouth's square hole
    (X 4 hole..4 hole + 4, Z 4 storey..+4) and at its sides. The older
    bridge's door (step 2) is in bay 4 - hole on storey `old`: the wall
    swells out into an outcrop OUTCROP deep round a hole for the carved door's
    panel (BridgeHallGrammar puts persian_carved_door_dark in it)."""
    def build(r):
        step = 0.5
        nx, nz = int(20 / step), int((ROOF_Z - PIT_Z) / step)
        hx0, hx1, hz0, hz1 = 4.0 * hole, 4.0 * hole + 4.0, 4.0 * storey, 4.0 * storey + 4.0
        dc = 4 - hole
        dx0, dx1, dz0, dz1 = 4.0 * dc, 4.0 * dc + DOOR_W, 4.0 * old, 4.0 * old + DOOR_H

        def bulge(x, z):
            d_hole = max(hx0 - x, x - hx1, hz0 - z, z - hz1, 0.0)
            d_side = min(x, 20.0 - x)
            fade = min(1.0, d_hole / 1.2, d_side / 1.0)
            b = max(0.0, fade * (0.45 + 0.4 * rough((x, 0.0, z), 0.35, 11.0)))
            # The outcrop: full depth near the panel, easing out over 2.5 m
            # (below the door the old bridge's deck springs from it).
            d_door = max(dx0 - x, x - dx1, dz0 - z, z - dz1, 0.0)
            t = max(0.0, 1.0 - max(0.0, d_door - 0.5) / 2.5)
            out = OUTCROP * (t * t * (3.0 - 2.0 * t)) + 0.15 * rough((x, 1.0, z), 0.5, 13.0) * min(1.0, d_door / 0.5)
            return max(b, out)

        bm = bmesh.new()
        vs = [[bm.verts.new((i * step, bulge(i * step, PIT_Z + k * step), PIT_Z + k * step)) for k in range(nz + 1)] for i in range(nx + 1)]
        for i in range(nx):
            for k in range(nz):
                cx, cz = (i + 0.5) * step, PIT_Z + (k + 0.5) * step
                if hx0 < cx < hx1 and hz0 < cz < hz1:
                    continue
                if dx0 < cx < dx1 and dz0 < cz < dz1:
                    continue
                bm.faces.new((vs[i][k], vs[i][k + 1], vs[i + 1][k + 1], vs[i + 1][k]))
        mesh_object(end_wall_name(hole, storey, old) + "__rock-col", bm, [ROCK], r, recalc=False)
    return build


def roof(bays):
    """Rock over the hall (X 0..20, Y 0..4 bays): ROOF_Z at the walls, up to
    about 16 m in the middle, facing down; stalactites hanging from it."""
    def build(r):
        sx, sy = 20.0, 4.0 * bays
        nx, ny = 40, bays * 8

        def height(x, y):
            # Level with the walls' tops over the long walls' faces (1.5 m in).
            e = min(max(0.0, min(x, sx - x) - 1.8), y, sy - y)
            h = ROOF_Z + 4.0 * min(1.0, e / 7.0) ** 0.7
            return h + rough((x, y, 0.0), 0.22, 21.0) * 0.9 * min(1.0, e / 1.5)

        bm = bmesh.new()
        vs = [[bm.verts.new((sx * i / nx, sy * j / ny, height(sx * i / nx, sy * j / ny))) for j in range(ny + 1)] for i in range(nx + 1)]
        for i in range(nx):
            for j in range(ny):
                bm.faces.new((vs[i][j], vs[i][j + 1], vs[i + 1][j + 1], vs[i + 1][j]))     # facing down
        mesh_object("bh_roof_5x%d__rock" % bays, bm, [ROCK], r, recalc=False)
        rng = random.Random(bays * 31 + 7)
        sb = bmesh.new()
        for _k in range(bays * 7):
            x, y = rng.uniform(1.5, sx - 1.5), rng.uniform(1.5, sy - 1.5)
            top = height(x, y) + 0.3
            length = rng.uniform(0.8, 3.2)
            rad = rng.uniform(0.18, 0.55)
            add_lathe(sb, [(0.0, top - length), (rad * 0.35, top - length * 0.6), (rad, top - 0.4), (rad * 1.1, top)], x, y, segs=6)
        mesh_object("bh_roof_5x%d__stalactites" % bays, sb, [ROCK], r)
    return build


def pit(bays):
    """The drop's floor (X 0..20, Y 0..4 bays) at PIT_Z, rough, rising 2 m
    toward the walls, boulders on it; collision."""
    def build(r):
        sx, sy = 20.0, 4.0 * bays
        nx, ny = 40, bays * 8

        def height(x, y):
            e = min(x, sx - x, y, sy - y)
            return PIT_Z + 2.0 * max(0.0, 1.0 - e / 3.0) ** 1.5 + rough((x, y, 0.0), 0.3, 31.0) * 0.6

        bm = bmesh.new()
        vs = [[bm.verts.new((sx * i / nx, sy * j / ny, height(sx * i / nx, sy * j / ny))) for j in range(ny + 1)] for i in range(nx + 1)]
        for i in range(nx):
            for j in range(ny):
                bm.faces.new((vs[i][j], vs[i + 1][j], vs[i + 1][j + 1], vs[i][j + 1]))     # facing up
        mesh_object("bh_pit_5x%d__rock-col" % bays, bm, [ROCK], r, recalc=False)
        rng = random.Random(bays * 17 + 3)
        bb = bmesh.new()
        for _k in range(bays * 4):
            x, y = rng.uniform(1.0, sx - 1.0), rng.uniform(1.0, sy - 1.0)
            s = rng.uniform(0.6, 2.2)
            add_obox(bb, (x, y, height(x, y) + s * 0.3), (s, s * rng.uniform(0.6, 1.2), s * rng.uniform(0.5, 0.9)),
                     (rng.uniform(-0.4, 0.4), rng.uniform(-0.4, 0.4), rng.uniform(0, math.pi)))
        mesh_object("bh_pit_5x%d__boulders" % bays, bb, [ROCK], r)
    return build


MODULES = [
    ("M_bh_cave_straight", props("cell", [1, 1, 1], "", "rock,cave,r21,walled"), cave_straight),
    ("M_bh_cave_bend", props("cell", [1, 1, 1], "", "rock,cave,r21,walled"), cave_bend),
    ("M_bh_cave_mouth", props("edge", [1, 1, 0], "", "rock,cave,r21"), cave_mouth),
]
# End walls (step 2): the mouth in bay 1 or 3 on the entry's storey (lv) or
# the far door's (up, dn), the older bridge's door one storey over (hi) or
# under (lo) the deck: the pairs BridgeHallGrammar uses.
for _h in (1, 3):
    for (_s, _o) in ((0, 1), (0, -1), (1, -1), (-1, 1)):
        MODULES.append(("M_" + end_wall_name(_h, _s, _o), props("edge", [5, 6, 0], "", "rock,cavern,r21"), end_wall(_h, _s, _o)))
for _b in (6, 7, 8):
    MODULES.append(("M_bh_roof_5x%d" % _b, props("cell", [5, 1, _b], "", "rock,cavern,r21"), roof(_b)))
    MODULES.append(("M_bh_pit_5x%d" % _b, props("cell", [5, 1, _b], "", "rock,cavern,r21"), pit(_b)))

# Script-made modules remade in place at a new revision (kit_blender.rebuild).
REBUILD = []


def main():
    if os.path.exists(BLEND):
        bpy.ops.wm.open_mainfile(filepath=BLEND)
    else:
        bpy.ops.wm.read_factory_settings(use_empty=True)
    added = []
    x = 0.0
    for (name, p, build) in MODULES:
        if bpy.data.objects.get(name) is None:
            build(module(name, (x, ROW_Y, 0.0), p))
            added.append(name)
        x += 40.0
    rebuilt = ["%s (rev %d)" % (n, v) for (n, v) in REBUILD if rebuild(n, v, MODULES)]
    if not added and not rebuilt:
        print("kit_add_r21: everything already present; nothing to do.")
        return
    os.makedirs(os.path.dirname(BLEND), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=BLEND)
    print("kit_add_r21: added %s; rebuilt %s" % (", ".join(added) or "nothing", ", ".join(rebuilt) or "nothing"))


main()

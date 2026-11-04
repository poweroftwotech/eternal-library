"""Adds the Cistern Archive's water niches and glowing lights to
art_src/kit/kit_dressing.blend (room rework step 5: your Lower Stacks walk of
2026-11-03 asked for the cistern's plank tables gone, its bookshelves turned
into niches of rice paddies growing out of water, nets and fishing spears,
and the room lit by glowing plants and mushrooms instead of lanterns).

  blender --background --factory-startup --python tools/kit_add_cistern_niche.py

Additive like kit_add_niche.py; then run tools/export_kit.bat kit_dressing.blend.

Wall niches (a shelf bay's recess fill, 3 m wide, back at Godot z +0.3; the
cistern pins its shelf bays to them, kit/sockets/recess_library.tres):
  wall_paddy   two stone troughs of water, one on the floor, one on brackets
               above, rice growing out of them with glowing seed heads; a few
               glowing mushrooms on the trough ends.
  wall_nets    a fishing net hung from pegs with its floats, three fishing
               spears leaning in the corner, a coil of rope, a fish basket;
               glowing fungus strands hang from the niche's head.
  wall_traps   wicker eel traps on the floor and on a shelf, a water trough
               the traps soak in, glowing bracket fungi on the back.
  wall_grotto  a mossy log with tall glowing mushrooms growing out of it.

Lamp (free, the cistern's lamp slot, origin on the floor at a bay's centre):
  glow_roots_dome  roots hanging from the dome's crown down to about 3 m,
                   glowing pods along them: the teal "fungus" light.
"""
import math
import os
import random
import sys

import bmesh
import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kit_blender import add_box, add_lathe, add_tube, marker, mesh_object, module, rebuild  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BLEND = os.path.join(ROOT, "art_src", "kit", "kit_dressing.blend")
ROW_Y = 72.0       # past kit_add_niche.py's row
DOME_CROWN = 7.9   # kit_add_r03.py: the dome's intrados crown


def props(tags, family="dressing"):
    return {"kit_shape": "free", "kit_family": family, "size_cells": [0, 0, 0],
            "edge": "", "tags": tags, "weight": 1.0}


def to_recess(r):
    """kit_add_niche.py's to_recess: drawn with the back at y -0.4, moved 0.1 m
    toward the room so the back meets the recess's (y -0.3). Whatever pokes
    into the back wall is pressed flat on it, and above 0.6 m nothing stands
    proud of the wall's face (recess_library's slot; only a low spill may)."""
    for o in r.children:
        if o.type == "MESH":
            for v in o.data.vertices:
                v.co.y = max(v.co.y, -0.399)
                v.co.z = max(v.co.z, 0.0)
                if v.co.z > 0.6:
                    v.co.y = min(v.co.y, 0.199)
                v.co.y += 0.1
        else:
            o.location.y += 0.1


def water(bm, x0, x1, y0, y1, z):
    vs = [bm.verts.new((x, y, z)) for (x, y) in ((x0, y0), (x1, y0), (x1, y1), (x0, y1))]
    bm.faces.new(vs)


def mushroom(bm_cap, bm_gill, bm_stalk, x, y, z, h, lean=(0.0, 0.0)):
    """kit_add_persian.py's mushroom, standing at height z."""
    R = h * 0.42
    top = (x + lean[0] * h, y + lean[1] * h, z + h)
    add_tube(bm_stalk, [(x, y, z), (x + lean[0] * h * 0.4, y + lean[1] * h * 0.4, z + h * 0.5), top],
             [h * 0.08, h * 0.06, h * 0.05], segs=6)
    add_lathe(bm_cap, [(R, z + h), (R * 0.8, z + h + R * 0.25), (R * 0.45, z + h + R * 0.38), (0.0, z + h + R * 0.42)],
              top[0], top[1], segs=10)
    uv = bm_gill.loops.layers.uv.verify()
    add_lathe(bm_gill, [(h * 0.05, z + h - R * 0.3), (R * 0.55, z + h - R * 0.1), (R * 0.97, z + h - 0.01)],
              top[0], top[1], segs=10, uv=uv)


def mushrooms(r, name, specs, squash=1.0):
    """`squash` presses the caps front to back about y -0.1, so a big cap fits
    the 0.6 m deep niche."""
    caps, gills, stalks = bmesh.new(), bmesh.new(), bmesh.new()
    for s in specs:
        mushroom(caps, gills, stalks, *s)
    for bm in (caps, gills):
        for v in bm.verts:
            v.co.y = -0.1 + (v.co.y + 0.1) * squash
    mesh_object(name + "__caps", caps, ["persian_fungus_cap"], r)
    mesh_object(name + "__gills", gills, ["emit_gills"], r)
    mesh_object(name + "__stalks", stalks, ["persian_fungus_stalk"], r)


def blade(bm, base, h, yaw, bend, w=0.018):
    """One leaf blade: a tapering strip curving out from base, two quads and a tip."""
    (x, y, z) = base
    dx, dy = math.cos(yaw), math.sin(yaw)
    px, py = -dy * w, dx * w          # across the blade
    pts = []
    for k in range(4):
        t = k / 3.0
        out = bend * t * t * h
        pts.append((x + dx * out, y + dy * out, z + h * t * (1.0 - 0.25 * bend * t)))
    verts = []
    for k, (cx, cy, cz) in enumerate(pts[:-1]):
        s = 1.0 - k / 3.0
        verts.append((bm.verts.new((cx - px * s, cy - py * s, cz)), bm.verts.new((cx + px * s, cy + py * s, cz))))
    tip = bm.verts.new(pts[-1])
    for (a, b), (c, d) in zip(verts, verts[1:]):
        bm.faces.new((a, b, d, c))
    bm.faces.new((verts[-1][0], verts[-1][1], tip))
    return pts[-1]


def rice_clump(bm_leaf, bm_head, rng, x, y, z):
    """Seven blades from a point, three of them carrying a drooping, glowing
    head of grain."""
    for i in range(7):
        yaw = rng.uniform(0, 2 * math.pi)
        h = rng.uniform(0.38, 0.62)
        tip = blade(bm_leaf, (x + rng.uniform(-0.02, 0.02), y + rng.uniform(-0.02, 0.02), z), h, yaw, rng.uniform(0.2, 0.55))
        if i < 3:
            # The head: a short chain of grains hanging from the tip.
            d = (math.cos(yaw) * 0.05, math.sin(yaw) * 0.05)
            for k in range(4):
                gx, gy, gz = tip[0] + d[0] * k, tip[1] + d[1] * k, tip[2] - 0.035 * k * k * 0.5
                add_box(bm_head, gx - 0.012, gx + 0.012, gy - 0.012, gy + 0.012, gz - 0.03, gz + 0.005)


def wall_paddy(r):
    name = "wall_paddy"
    bm = bmesh.new()
    # The floor trough: stone walls round a water surface 0.38 m up.
    add_box(bm, -1.4, 1.4, -0.4, -0.34, 0.0, 0.46)            # back
    add_box(bm, -1.4, 1.4, 0.14, 0.2, 0.0, 0.46)              # front
    add_box(bm, -1.4, -1.34, -0.34, 0.14, 0.0, 0.46)          # ends
    add_box(bm, 1.34, 1.4, -0.34, 0.14, 0.0, 0.46)
    add_box(bm, -1.34, 1.34, -0.34, 0.14, 0.0, 0.2)           # its bed
    # The upper terrace on brackets, its water 1.27 m up.
    add_box(bm, -1.3, 1.3, -0.4, -0.06, 1.0, 1.06)            # floor
    add_box(bm, -1.3, 1.3, -0.12, -0.06, 1.06, 1.32)          # lip
    add_box(bm, -1.3, -1.24, -0.4, -0.06, 1.06, 1.32)
    add_box(bm, 1.24, 1.3, -0.4, -0.06, 1.06, 1.32)
    for x in (-1.0, 0.0, 1.0):
        add_box(bm, x - 0.05, x + 0.05, -0.4, -0.08, 0.82, 1.0)
    mesh_object(name + "__troughs-col", bm, ["arch_stone"], r)
    bm = bmesh.new()
    add_box(bm, -1.34, 1.34, -0.34, 0.14, 0.2, 0.3)
    add_box(bm, -1.24, 1.24, -0.4, -0.12, 1.06, 1.16)
    mesh_object(name + "__mud", bm, ["soil"], r)
    bm = bmesh.new()
    water(bm, -1.34, 1.34, -0.34, 0.14, 0.38)
    water(bm, -1.24, 1.24, -0.4, -0.12, 1.27)
    mesh_object(name + "__water", bm, ["cistern_water"], r)
    # A brass spout pours from the upper terrace into the floor trough.
    bm = bmesh.new()
    add_tube(bm, [(1.1, -0.1, 1.2), (1.1, 0.0, 1.22), (1.1, 0.04, 1.16)], 0.025, segs=6)
    mesh_object(name + "__spout", bm, ["brass"], r)
    rng = random.Random(41)
    leaf, head = bmesh.new(), bmesh.new()
    for row_y in (-0.2, 0.02):
        for i in range(9):
            rice_clump(leaf, head, rng, -1.15 + i * 0.29 + rng.uniform(-0.04, 0.04), row_y + rng.uniform(-0.03, 0.03), 0.3)
    for i in range(8):
        rice_clump(leaf, head, rng, -1.05 + i * 0.3 + rng.uniform(-0.04, 0.04), -0.26, 1.16)
    mesh_object(name + "__rice", leaf, ["rice_blade"], r)
    mesh_object(name + "__grain", head, ["emit_rice"], r)
    mushrooms(r, name, [(-1.37, 0.05, 0.46, 0.22, (0.05, 0.03)), (-1.37, -0.2, 0.46, 0.14, (0.0, 0.05)),
                        (1.27, -0.3, 1.32, 0.18, (-0.04, 0.05))])
    marker("LIGHT_fungus__paddy", r, (0.0, 0.25, 0.9), {"range": 4.0, "energy": 0.7})
    to_recess(r)


def wall_nets(r):
    name = "wall_nets"
    # The net: cords on a grid, hung from two pegs, sagging between them and
    # bellying out a little, its foot ragged.
    bm = bmesh.new()
    x0, x1, top, drop = -1.3, 0.5, 2.6, 1.7
    cols, rows = 16, 14

    def at(u, v):
        x = x0 + (x1 - x0) * u
        z_top = top - 0.22 * math.sin(math.pi * u)
        length = drop * (0.75 + 0.25 * math.sin(math.pi * u)) + 0.08 * math.sin(u * 23.0)
        z = z_top - length * v
        y = -0.34 + 0.12 * math.sin(math.pi * v) * math.sin(math.pi * u)
        return (x, y, z)

    def cord(path, w=0.008):
        for a, b in zip(path, path[1:]):
            vs = [bm.verts.new((a[0] - w, a[1] + 0.002, a[2] + w)), bm.verts.new((a[0] + w, a[1] + 0.002, a[2] - w)),
                  bm.verts.new((b[0] + w, b[1] + 0.002, b[2] - w)), bm.verts.new((b[0] - w, b[1] + 0.002, b[2] + w))]
            bm.faces.new(vs)
    for j in range(rows + 1):
        cord([at(i / cols, j / rows) for i in range(cols + 1)])
    for i in range(cols + 1):
        cord([at(i / cols, j / rows) for j in range(rows + 1)])
    mesh_object(name + "__net", bm, ["net_cord"], r)
    bm = bmesh.new()
    for x in (x0, x1):
        add_box(bm, x - 0.025, x + 0.025, -0.4, -0.22, top - 0.03, top + 0.03)     # pegs
    for i in range(0, cols + 1, 3):
        (x, y, z) = at(i / cols, 1.0)
        add_box(bm, x - 0.04, x + 0.04, y - 0.025, y + 0.025, z - 0.07, z)        # cork floats
    mesh_object(name + "__pegs", bm, ["wood"], r)
    # Three fishing spears in the east corner, leaning on the back.
    shafts, heads = bmesh.new(), bmesh.new()
    for k, (fx, tx) in enumerate(((0.85, 0.95), (1.05, 1.2), (1.25, 1.12))):
        foot, tip = (fx, 0.05, 0.0), (tx, -0.33, 2.55 + 0.1 * k)
        add_tube(shafts, [foot, tip], 0.018, segs=6)
        dy, dz = tip[1] - foot[1], tip[2] - foot[2]
        n = math.hypot(dy, dz)
        uy, uz = dy / n, dz / n
        for p in (-0.035, 0.0, 0.035):          # a trident's prongs
            base = (tip[0] + p, tip[1], tip[2])
            add_tube(heads, [base, (base[0] + p * 0.3, base[1] + uy * 0.22, base[2] + uz * 0.22)], [0.006, 0.002], segs=4)
        add_box(heads, tip[0] - 0.045, tip[0] + 0.045, tip[1] - 0.012, tip[1] + 0.012, tip[2] - 0.02, tip[2] + 0.01)
    mesh_object(name + "__spears", shafts, ["wood"], r)
    mesh_object(name + "__heads", heads, ["iron"], r)
    # A coil of rope and a fish basket on the floor.
    bm = bmesh.new()
    for k in range(5):
        rad = 0.2 - k * 0.012
        add_tube(bm, [(-0.75 + rad * math.cos(a), -0.12 + rad * math.sin(a), 0.03 + 0.045 * k)
                      for a in [2 * math.pi * i / 14 for i in range(15)]], 0.022, segs=5)
    add_lathe(bm, [(0.0, 0.0), (0.16, 0.0), (0.2, 0.12), (0.17, 0.3), (0.11, 0.38), (0.12, 0.42), (0.0, 0.42)],
              cx=-0.1, cy=-0.16, segs=12)
    mesh_object(name + "__rope", bm, ["hay"], r)
    glow_strands(r, name, [(-1.2, 1.0), (-0.75, 1.4), (-0.3, 0.9), (0.3, 1.2)], 3.55, seed=5)
    marker("LIGHT_fungus__nets", r, (-0.4, 0.2, 2.4), {"range": 3.5, "energy": 0.55})
    to_recess(r)


def glow_strands(r, name, specs, z_top, seed):
    """Fungus strands hanging down the back from z_top, small glowing caps
    along them (kit_add_persian.py's glowmoss, shorter)."""
    rng = random.Random(seed)
    stalks, caps = bmesh.new(), bmesh.new()
    for (x0, length) in specs:
        n = max(3, int(length / 0.3))
        path = [(x0 + 0.04 * math.sin(k * 1.3 + x0), -0.36, z_top - length * k / n) for k in range(n + 1)]
        add_tube(stalks, path, [0.028 * (1.0 - 0.5 * k / n) for k in range(n + 1)], segs=4)
        for k in range(1, n + 1):
            (x, y, z) = path[k]
            R = 0.08 * (1.0 - 0.4 * k / n) + rng.uniform(0.0, 0.025)
            add_lathe(caps, [(R, z), (R * 0.6, z + R * 0.35), (0.0, z + R * 0.45)], x, y + R * 0.5, segs=8)
    mesh_object(name + "__strands", stalks, ["camp_root"], r)
    mesh_object(name + "__glowcaps", caps, ["emit_fungus"], r)


def eel_trap(bm, x, y, z, length, rad, axis):
    """A wicker eel trap lying along X (axis "x") or standing (axis "z"): a long
    tapering basket with a funnel mouth, hoops round it."""
    prof = [(0.0, 0.0), (rad * 0.35, 0.0), (rad, length * 0.1), (rad, length * 0.6), (rad * 0.55, length * 0.95), (0.0, length)]
    start = len(bm.verts)
    add_lathe(bm, prof, 0.0, 0.0, segs=10)
    for k in (0.1, 0.3, 0.5, 0.7, 0.88):     # hoops
        rr = rad * (1.0 - 0.45 * max(0.0, k - 0.6) / 0.35) + 0.012     # the profile's radius there, and proud of it
        add_lathe(bm, [(rr, length * k - 0.018), (rr + 0.006, length * k), (rr, length * k + 0.018)], 0.0, 0.0, segs=10)
    for i in range(12):                       # the withies running its length, proud of the weave
        a = 2 * math.pi * (i + 0.5) / 12
        path = [(math.cos(a) * (rr2 + 0.006), math.sin(a) * (rr2 + 0.006), z2) for (rr2, z2) in prof[1:-1]]
        add_tube(bm, path, 0.007, segs=3)
    for v in list(bm.verts)[start:]:
        (a, b, c) = v.co
        if axis == "x":
            v.co = (x + c - length / 2, y + b, z + rad + a)
        else:
            v.co = (x + a, y + b, z + c)


def wall_traps(r):
    name = "wall_traps"
    bm = bmesh.new()
    add_box(bm, -1.35, 1.35, -0.4, 0.05, 1.45, 1.5)           # shelf
    for x in (-1.0, 1.0):
        add_box(bm, x - 0.04, x + 0.04, -0.4, -0.06, 1.25, 1.45)
    add_box(bm, 0.35, 1.35, -0.4, -0.34, 0.0, 0.4)            # the soaking trough's back
    add_box(bm, 0.35, 1.35, 0.14, 0.2, 0.0, 0.4)              # front
    add_box(bm, 0.35, 0.41, -0.34, 0.14, 0.0, 0.4)            # ends
    add_box(bm, 1.29, 1.35, -0.34, 0.14, 0.0, 0.4)
    add_box(bm, 0.41, 1.29, -0.34, 0.14, 0.0, 0.08)
    mesh_object(name + "__shelf-col", bm, ["wood"], r)
    bm = bmesh.new()
    water(bm, 0.41, 1.29, -0.34, 0.14, 0.32)
    mesh_object(name + "__water", bm, ["cistern_water"], r)
    bm = bmesh.new()
    eel_trap(bm, -0.7, -0.15, 0.0, 1.1, 0.16, "x")            # on the floor
    eel_trap(bm, -0.55, -0.15, 0.32, 0.9, 0.13, "x")          # on top of it
    eel_trap(bm, 0.85, -0.1, 0.12, 0.85, 0.12, "x")           # soaking
    eel_trap(bm, -0.6, -0.2, 1.5, 1.0, 0.14, "x")             # on the shelf
    eel_trap(bm, 0.45, -0.22, 1.5, 0.75, 0.11, "x")
    eel_trap(bm, -1.2, -0.25, 1.5, 0.8, 0.12, "z")            # one standing
    mesh_object(name + "__traps", bm, ["wicker"], r)
    # Bracket fungi up the back, glowing, and a cluster on the trough's end.
    caps = bmesh.new()
    rng = random.Random(17)
    for (x, z) in [(0.9, 2.2), (1.05, 2.45), (0.8, 2.6), (1.15, 1.95), (-0.2, 2.9), (0.0, 3.1)]:
        R = rng.uniform(0.07, 0.13)
        add_lathe(caps, [(R, z), (R * 0.7, z + R * 0.3), (0.0, z + R * 0.4)], x, -0.38, segs=8)
    mesh_object(name + "__brackets", caps, ["emit_fungus"], r)
    mushrooms(r, name, [(1.32, 0.12, 0.4, 0.2, (0.0, 0.05)), (1.25, -0.25, 0.4, 0.13, (-0.04, 0.0))])
    marker("LIGHT_fungus__traps", r, (0.7, 0.25, 2.0), {"range": 3.8, "energy": 0.6})
    to_recess(r)


def wall_grotto(r):
    name = "wall_grotto"
    bm = bmesh.new()
    add_tube(bm, [(-1.3, -0.15, 0.2), (-0.4, -0.12, 0.22), (0.5, -0.18, 0.2), (1.3, -0.14, 0.18)], 0.2, segs=8)
    mesh_object(name + "__log-col", bm, ["bark"], r)
    bm = bmesh.new()
    add_box(bm, -1.2, 1.2, -0.28, -0.02, 0.38, 0.41)
    add_box(bm, -1.4, 1.4, -0.4, -0.37, 0.0, 1.6)             # moss up the back
    mesh_object(name + "__moss", bm, ["moss"], r)
    mushrooms(r, name, [(-0.85, -0.2, 0.36, 1.25, (0.06, 0.04)), (-0.35, -0.1, 0.38, 0.6, (-0.05, 0.06)),
                        (0.3, -0.22, 0.36, 1.6, (-0.04, 0.05)), (0.8, -0.1, 0.36, 0.75, (0.07, 0.04)),
                        (1.15, -0.2, 0.34, 0.4, (0.0, 0.08)), (-1.15, -0.1, 0.34, 0.35, (0.0, 0.06))], squash=0.45)
    glow_strands(r, name, [(-1.1, 0.8), (1.0, 1.1)], 3.55, seed=9)
    marker("LIGHT_fungus__grotto", r, (0.0, 0.3, 1.5), {"range": 4.2, "energy": 0.85})
    to_recess(r)


def glow_roots_dome(r):
    """Roots down from the dome's crown, with glowing pods along their lower
    parts; nothing below 2.8 m, so you walk under them."""
    name = "glow_roots_dome"
    rng = random.Random(29)
    roots, pods = bmesh.new(), bmesh.new()
    for i in range(9):
        a = 2 * math.pi * i / 9 + rng.uniform(-0.2, 0.2)
        rad = rng.uniform(0.15, 0.55)
        bottom = rng.uniform(2.8, 3.8)
        x, y = rad * math.cos(a), rad * math.sin(a)
        n = 8
        path = []
        for k in range(n + 1):
            t = k / n
            z = DOME_CROWN + 0.1 - (DOME_CROWN + 0.1 - bottom) * t
            sway = 0.12 * math.sin(t * 3.0 + i)
            path.append((x * (0.3 + 0.7 * t) + sway * math.cos(a + 1.5), y * (0.3 + 0.7 * t) + sway * math.sin(a + 1.5), z))
        add_tube(roots, path, [0.05 * (1.0 - 0.7 * k / n) + 0.01 for k in range(n + 1)], segs=5)
        for k in range(5, n + 1):
            (px, py, pz) = path[k]
            R = rng.uniform(0.04, 0.08)
            add_lathe(pods, [(0.0, pz - R * 1.6), (R, pz - R * 0.8), (R * 0.8, pz), (0.0, pz + R * 0.3)],
                      px + rng.uniform(-0.03, 0.03), py + rng.uniform(-0.03, 0.03), segs=6)
    mesh_object(name + "__roots", roots, ["camp_root"], r)
    mesh_object(name + "__pods", pods, ["emit_fungus"], r)
    marker("LIGHT_fungus__roots", r, (0.0, 0.0, 3.0), {"range": 4.5, "energy": 0.6})


MODULES = [
    ("M_wall_paddy", dict(props("stone,water,garden,light,niche,cistern"), kit_rev=2), wall_paddy),
    ("M_wall_nets", dict(props("wood,iron,storage,light,niche,cistern"), kit_rev=3), wall_nets),
    ("M_wall_traps", dict(props("wood,water,storage,light,niche,cistern"), kit_rev=3), wall_traps),
    ("M_wall_grotto", dict(props("wood,moss,fungus,light,niche,cistern"), kit_rev=3), wall_grotto),
    ("M_glow_roots_dome", dict(props("fungus,light,cistern"), kit_rev=2), glow_roots_dome),
]
REBUILD = [("M_wall_paddy", 2), ("M_wall_nets", 3), ("M_wall_traps", 3), ("M_wall_grotto", 3), ("M_glow_roots_dome", 2)]


def main():
    bpy.ops.wm.open_mainfile(filepath=BLEND)
    added = []
    for i, (name, p, build) in enumerate(MODULES):
        if bpy.data.objects.get(name) is None:
            build(module(name, (i * 8.0, ROW_Y, 0.0), p))
            added.append(name)
    added += ["%s (rebuilt rev %d)" % (n, v) for (n, v) in REBUILD if rebuild(n, v, MODULES)]
    if not added:
        print("kit_add_cistern_niche: all modules already present; nothing to do.")
        return
    bpy.ops.wm.save_as_mainfile(filepath=BLEND)
    print("kit_add_cistern_niche: added %s" % ", ".join(added))


main()

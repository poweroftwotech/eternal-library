"""Seeds the R07 Garden Court modules into art_src/kit/kit_garden.blend
(phase 13 step 1, docs/environment/phase-13-approval.md).

  blender --background --factory-startup --python tools/kit_add_r07.py

Creates kit_garden.blend if it doesn't exist, then adds only the modules
that are not in it yet (modules edited by hand are never touched). Then run
tools/export_kit.bat kit_garden.blend.

The garden (GardenCourtGrammar, scripts/gen/garden_court_grammar.gd) is the
caravanserai's ring (kit_court.blend: two storeys of arched bays, the
corners, a passage) round a court of 5 x 5 bays laid out as a chahar bagh:
a pool in the middle, rills along the two axes, four planted quarters. These
are the pieces the court doesn't have:

  garden_iwan         edge, 3 cells: the grand iwan closing the far wall. A
                      pointed hood 7 m wide and 3.7 deep, a pishtaq 10 m wide
                      rising to 12.4 m, tile in its frame and spandrels, the
                      kit's 3 m doorway at the back of the hood. Frame: the
                      middle cell's court face (X 0..4), reaching X -4..8.
  garden_shaft_5x5    cell, 7 x 7 bays: the rock over the ring (as
                      cavern_ceiling_5x5) and a broad shaft over the whole
                      court up to a square of daylight 34 m up. The sun (one
                      shadowed spot from the entry side, leaning onto the
                      iwan), a column of haze, and soft fills for the light
                      the sunlit paving throws into the arcades.
  garden_pool         free, centred: an octagonal pool 6 m across, stone rim
                      to sit on, a two-tier fountain in the middle.
  garden_rill_4m      cell: paving with a narrow rill down the run (Y), flush
                      with the floor so you walk over it.
  garden_bed_4m       cell: a planted bed, soil inside a stone edging on a
                      paved border, flowers and ferns. Walkable (no collision
                      but the floor).

Frame (Blender): Z up, a cell X 0..4, Y 0..4; Godot -Z is Blender +Y.
"""
import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import noise

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kit_blender import (add_box, add_card, add_lathe, add_ngon_prism, add_prism, arch_outline, arch_ring, add_tube,  # noqa: E402
                         cut, marker, mesh_object, module, rebuild)

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BLEND = os.path.join(ROOT, "art_src", "kit", "kit_garden.blend")
ROW_Y = -120.0
H = 4.0

# The sun (Blender, the shaft piece's frame): from over the entry side,
# leaning north onto the iwan.
SUN_AT = (14.0, 4.0, 56.0)
SUN_AIM = (14.0, 21.0, 0.0)
SKY_Z = 34.0


def props(shape, size, edge, tags, family="walls", weight=1.0):
    return {"kit_shape": shape, "kit_family": family, "size_cells": size,
            "edge": edge, "tags": tags, "weight": weight}


def solid(name, root, mats, build, recalc=True):
    bm = bmesh.new()
    build(bm)
    return mesh_object(name, bm, mats, root, recalc)


def cutter(root, build, mat="court_plaster"):
    return solid("cutter", root, [mat], build)


def pier(bm, x, y):
    """The kit's door pier at (x, y), as court_passage's."""
    add_box(bm, x - 0.48, x + 0.48, y - 0.48, y + 0.48, 0.0, 0.3)
    add_box(bm, x - 0.4, x + 0.4, y - 0.4, y + 0.4, 0.3, H - 0.3)
    add_box(bm, x - 0.5, x + 0.5, y - 0.5, y + 0.5, H - 0.3, H)


def quad(bm, pts):
    return bm.faces.new([bm.verts.new(p) for p in pts])


# --- the iwan ----------------------------------------------------------------------

HOOD_X, HOOD_SPAN, HOOD_SPRING, HOOD_K = -1.5, 7.0, 3.8, 0.6
HOOD_DEPTH = 3.7
PISH_X0, PISH_X1, PISH_TOP = -3.0, 7.0, 12.1


def garden_iwan(r):
    """The grand iwan: a brick block over three cells (X -4..8, both storeys),
    a pointed hood 7 m wide cut into it to the doorway wall at the cell's edge
    (Y 3.7..4.3, the kit's 3 m doorway between piers, as court_passage), and
    a pishtaq on the court face: 10 m wide, 0.8 m proud, to 12.4 m, a mosaic
    frame, tile spandrels, a stone archivolt, a cornice."""
    name = "garden_iwan"
    hood = arch_outline(HOOD_SPAN, HOOD_SPRING, HOOD_K, 14)
    body = solid(name + "__body-col", r, ["brick"], lambda bm: add_box(bm, -4.0, 8.0, 0.0, HOOD_DEPTH, 0.0, 2 * H + 0.6))
    cut(body, cutter(r, lambda bm: add_prism(bm, hood, HOOD_X, -0.01, -0.1, HOOD_DEPTH + 0.1)))
    # The hood's back: the doorway wall up to 4 m, the wall either side of it,
    # and over it to the vault.
    wall = solid(name + "__door-col", r, ["brick"], lambda bm: add_box(bm, 0.0, 4.0, 3.7, 4.3, 0.0, H))
    cut(wall, cutter(r, lambda bm: add_prism(bm, arch_outline(3.0, 1.8, 0.6, 10), 0.5, -0.01, 3.6, 4.4), mat="brick"))

    def back(bm):
        add_box(bm, HOOD_X, 0.0, 3.7, 4.0, 0.0, H)
        add_box(bm, 4.0, HOOD_X + HOOD_SPAN, 3.7, 4.0, 0.0, H)
        add_box(bm, HOOD_X, HOOD_X + HOOD_SPAN, 3.7, 4.0, H, 2 * H + 0.6)
    solid(name + "__back-col", r, ["court_plaster"], back)
    solid(name + "__piers-col", r, ["arch_stone"], lambda bm: (pier(bm, 0.0, 4.0), pier(bm, 4.0, 4.0)))
    solid(name + "__floor-col", r, ["floor_stone"], lambda bm: add_box(bm, HOOD_X, HOOD_X + HOOD_SPAN, 0.0, 4.0, -0.2, 0.0))

    # Tile dado round the hood, a tiled panel with a mosaic border over the door.
    def dado(bm):
        add_box(bm, HOOD_X, HOOD_X + 0.04, 0.05, 3.7, 0.0, 1.4)
        add_box(bm, HOOD_X + HOOD_SPAN - 0.04, HOOD_X + HOOD_SPAN, 0.05, 3.7, 0.0, 1.4)
        add_box(bm, HOOD_X, -0.48, 3.66, 3.7, 0.0, 1.4)
        add_box(bm, 4.48, HOOD_X + HOOD_SPAN, 3.66, 3.7, 0.0, 1.4)
        add_box(bm, 0.9, 3.1, 3.66, 3.7, 4.5, 6.7)
    solid(name + "__dado", r, ["garden_tile"], dado)

    def border(bm):
        for (x0, x1, z0, z1) in ((0.8, 3.2, 4.4, 4.5), (0.8, 3.2, 6.7, 6.8), (0.8, 0.9, 4.5, 6.7), (3.1, 3.2, 4.5, 6.7)):
            add_box(bm, x0, x1, 3.64, 3.7, z0, z1)
    solid(name + "__border", r, ["garden_band"], border)

    # The pishtaq.
    frame = solid(name + "__pishtaq-col", r, ["brick"], lambda bm: add_box(bm, PISH_X0, PISH_X1, -0.8, 0.0, 0.0, PISH_TOP))
    cut(frame, cutter(r, lambda bm: add_prism(bm, hood, HOOD_X, -0.01, -0.9, 0.1), mat="court_plaster"))
    solid(name + "__crown-col", r, ["brick"], lambda bm: add_box(bm, PISH_X0, PISH_X1, 0.0, 2.0, 2 * H + 0.6, PISH_TOP))
    # Rev 3 (your walk 3: missing cave round the top of the arch, seen from
    # the ground): rock over the iwan's whole block, from its roof up into
    # the shaft's rock, beside the pishtaq and behind its crown, so there's
    # no gap between the pishtaq's sides and the cavern.
    solid(name + "__rock", r, ["cave_rock"], lambda bm: (add_box(bm, -4.0, PISH_X0, -0.3, 4.3, 2 * H + 0.5, 15.6),
                                                         add_box(bm, PISH_X1, 8.0, -0.3, 4.3, 2 * H + 0.5, 15.6),
                                                         add_box(bm, PISH_X0, PISH_X1, 2.0, 4.3, 2 * H + 0.5, 15.6),
                                                         add_box(bm, PISH_X0 - 0.15, PISH_X1 + 0.15, -0.2, 2.0, PISH_TOP + 0.3, 15.6)))

    def mosaic(bm):
        add_box(bm, PISH_X0 + 0.1, PISH_X0 + 0.5, -0.84, -0.8, 0.4, PISH_TOP - 0.3)
        add_box(bm, PISH_X1 - 0.5, PISH_X1 - 0.1, -0.84, -0.8, 0.4, PISH_TOP - 0.3)
        add_box(bm, PISH_X0 + 0.1, PISH_X1 - 0.1, -0.84, -0.8, PISH_TOP - 0.7, PISH_TOP - 0.3)
    solid(name + "__mosaic", r, ["garden_band"], mosaic)
    crown = max(z for (_x, z) in hood)
    # Spandrels: tile in the frame over the arch, cut round its outer ring.
    span = solid(name + "__spandrel", r, ["garden_tile"], lambda bm: add_box(bm, PISH_X0 + 0.5, PISH_X1 - 0.5, -0.83, -0.8, HOOD_SPRING, PISH_TOP - 0.7))
    cut(span, cutter(r, lambda bm: add_prism(bm, arch_outline(HOOD_SPAN + 0.7, HOOD_SPRING, HOOD_K, 14), HOOD_X - 0.35, -0.02, -0.9, -0.7), mat="garden_tile"))
    bm = bmesh.new()
    arch_ring(bm, [(HOOD_X + u, v) for (u, v) in hood],
              [(HOOD_X - 0.35 + u, v) for (u, v) in arch_outline(HOOD_SPAN + 0.7, HOOD_SPRING, HOOD_K, 14)], -0.86, -0.78)
    mesh_object(name + "__archivolt", bm, ["arch_stone"], r)
    solid(name + "__cornice", r, ["arch_stone"], lambda bm: add_box(bm, PISH_X0 - 0.15, PISH_X1 + 0.15, -0.98, 2.0, PISH_TOP, PISH_TOP + 0.3))
    # A band of inscription tile under the cornice, across the frame's top.
    solid(name + "__frieze", r, ["garden_band"], lambda bm: add_box(bm, PISH_X0 + 0.5, PISH_X1 - 0.5, -0.85, -0.83, PISH_TOP - 1.3, PISH_TOP - 0.75))
    # Rev 4 (the route audit): the module's origin at its own south-west
    # corner like every CELL piece, so its three cells are the ones it stands
    # on (it was built about the middle cell's corner, X -4..8).
    from mathutils import Matrix
    for ob in r.children:
        if ob.type == "MESH":
            ob.data.transform(Matrix.Translation((4.0, 0.0, 0.0)))
    print("garden_iwan: hood crown %.2f m" % crown)


# --- the shaft ---------------------------------------------------------------------

def _shaft_height(x, y):
    """The rock's underside over the ring (as cavern_ceiling: 8.05 m at the
    outer edge, 12.4 m at the court face), raised to 13.4 m over the iwan's
    pishtaq."""
    size = 28.0
    e = min(x, size - x, y, size - y)
    base = 12.4 if e >= 4.0 else 12.4 - 3.6 * ((4.0 - e) / 4.0) ** 0.8     # 8.8 at the outer edge: over the talar roof
    rough = noise.noise((x * 0.21, y * 0.21, 3.7)) * 0.9 + noise.noise((x * 0.6, y * 0.6, 9.1)) * 0.3
    h = base + rough * min(1.0, e / 2.5)
    w = max(0.0, min(1.0, min(x - 5.5, 22.5 - x, y - 20.5) / 1.5))
    shelf = 13.4 + abs(rough) * 1.4      # rev 9: over the pishtaq, uneven too (it read as a flat box)
    return h + max(0.0, shelf - h) * w


def _square(lo, hi, per_side):
    """Points round the square [lo, hi]^2, counter-clockwise from above, from (lo, lo)."""
    pts = []
    step = (hi - lo) / per_side
    for k in range(per_side):
        pts.append((lo + k * step, lo))
    for k in range(per_side):
        pts.append((hi, lo + k * step))
    for k in range(per_side):
        pts.append((hi - k * step, hi))
    for k in range(per_side):
        pts.append((lo, hi - k * step))
    return pts


def _hang(bm, uv, rng, x, y, z, yaw, length, w=0.6):
    """A curtain of ivy hanging from (x, y, z) down `length` metres, in the
    plane of `yaw` (along the rock it hangs against)."""
    zz = z
    while zz > z - length:
        for side in (-0.22, 0.22):    # rev 11: two strands side by side, wider leaves (rev 10 read as thin threads)
            ox, oy = math.cos(yaw) * side, math.sin(yaw) * side
            add_card(bm, uv, (x + ox + rng.uniform(-0.1, 0.1), y + oy + rng.uniform(-0.1, 0.1), zz - w + rng.uniform(-0.1, 0.1)), w, w, yaw + rng.uniform(-0.35, 0.35), rng.uniform(-0.3, 0.3))
        zz -= rng.uniform(0.22, 0.3)
        w *= 0.97


def _shaft_plants(r, name, ring0, lip, funnel, top_ring):
    """Rev 10 (your walk 3: vines and plants round the opening and the walls):
    ivy hanging in curtains off the lip over the court face (clear of the
    iwan), shorter ones and fern tufts on the funnel's ledges, and round the
    ragged hole ferns against the sky and ivy trailing down into the light."""
    rng = random.Random(97)
    ivy, fern = bmesh.new(), bmesh.new()
    uv_i = ivy.loops.layers.uv.new("UVMap")
    uv_f = fern.loops.layers.uv.new("UVMap")

    def tangent(ring, i):
        a, b = ring[(i - 1) % len(ring)].co, ring[(i + 1) % len(ring)].co
        return math.atan2(b.y - a.y, b.x - a.x)

    def inward(v, k):
        dx, dy = 14.0 - v.co.x, 13.0 - v.co.y
        d = math.hypot(dx, dy) or 1.0
        return v.co.x + dx / d * k, v.co.y + dy / d * k

    # Off the lip, down over the court face toward the cornice.
    for i, v in enumerate(lip):
        if v.co.y > 22.0 and 7.0 < v.co.x < 21.0:
            continue          # the pishtaq stays clear
        if rng.random() < 0.8:
            x, y = inward(v, 0.15)
            _hang(ivy, uv_i, rng, x, y, v.co.z + 0.2, tangent(lip, i), rng.uniform(1.5, max(1.6, v.co.z - TALAR_TOP - 0.6)))
        if rng.random() < 0.35:
            x, y = inward(v, -0.1)
            for a in (0.0, math.pi / 2):
                add_card(fern, uv_f, (x, y, v.co.z - 0.1), 0.8, 0.7, tangent(lip, i) + a, rng.uniform(-0.4, 0.4))
    # The funnel's ledges.
    for k, ring in enumerate(funnel[:-1]):
        for i, v in enumerate(ring):
            p = rng.random()
            if p < 0.22:
                x, y = inward(v, 0.2)
                _hang(ivy, uv_i, rng, x, y, v.co.z + 0.2, tangent(ring, i), rng.uniform(1.0, 2.6))
            elif p < 0.36:
                x, y = inward(v, 0.1)
                for a in (0.0, math.pi / 2):
                    add_card(fern, uv_f, (x, y, v.co.z - 0.15), 0.7, 0.6, tangent(ring, i) + a, rng.uniform(-0.5, 0.5))
    # Round the hole: ferns standing up against the sky, ivy trailing down.
    for i, v in enumerate(top_ring):
        if rng.random() < 0.6:
            x, y = inward(v, -0.05)
            s = rng.uniform(0.9, 1.5)
            for a in (0.0, math.pi / 2):
                add_card(fern, uv_f, (x, y, v.co.z - 0.2), 0.8 * s, 0.75 * s, tangent(top_ring, i) + a + rng.uniform(-0.3, 0.3), rng.uniform(-0.5, 0.5))
        if rng.random() < 0.6:
            x, y = inward(v, 0.15)
            _hang(ivy, uv_i, rng, x, y, v.co.z, tangent(top_ring, i), rng.uniform(1.5, 4.0))
    mesh_object(name + "__ivy", ivy, ["ivy_leaf"], r, recalc=False)
    mesh_object(name + "__ferns", fern, ["fern"], r, recalc=False)


# Rev 15 (after walk 5, "dappled light", your pick: real leaf shadows): wild figs
# rooted in the court face's rock over the talar roofs, as figs root in old
# walls, their limbs reaching 4 to 5.5 m out over the court at 13 to 14 m, in
# the sun's beam. Their leaves (alpha cut out, swaying) throw moving shade on
# the paving and beds about 4 m north of each (the sun leans onto the iwan).
# (side, along, height): west and east walls at X 4 / 24, the entry wall at Y 4.
SHAFT_FIGS = [("W", 10.5, 13.0), ("W", 19.0, 13.8), ("E", 12.0, 13.4), ("E", 20.5, 12.9),
              ("S", 9.0, 13.2), ("S", 18.5, 13.6)]


def _shaft_figs(r, name):
    rng = random.Random(131)
    wood, leaves = bmesh.new(), bmesh.new()
    uv = leaves.loops.layers.uv.new("UVMap")
    for side, along, h in SHAFT_FIGS:
        # In: the direction into the court; at(d, s, z): d metres in from the wall, s along it.
        ix, iy = {"W": (1.0, 0.0), "E": (-1.0, 0.0), "S": (0.0, 1.0)}[side]
        wx, wy = {"W": (4.0, along), "E": (24.0, along), "S": (along, 4.0)}[side]

        def at(d, s, z):
            return (wx + ix * d + iy * s, wy + iy * d + ix * s, z)
        reach = rng.uniform(4.5, 5.5)
        # Roots clinging down the rock face from where it grows.
        for k in range(3):
            s0 = rng.uniform(-0.6, 0.6)
            add_tube(wood, [at(-0.3, s0, h), at(0.05, s0 + rng.uniform(-0.4, 0.4), h - 1.2), at(0.08, s0 + rng.uniform(-0.6, 0.6), h - rng.uniform(2.5, 3.6))],
                     [0.07, 0.05, 0.02], segs=4)
        # The limb: out of the rock, up a little, then levelling and drooping.
        sway = rng.uniform(-0.8, 0.8)
        limb = [at(-0.4, 0.0, h - 0.2), at(0.6, sway * 0.2, h + 0.3), at(reach * 0.45, sway * 0.6, h + 0.6),
                at(reach * 0.75, sway, h + 0.45), at(reach, sway * 1.3, h + 0.1)]
        add_tube(wood, limb, [0.2, 0.17, 0.12, 0.08, 0.04], segs=6)
        twigs = []
        for p in limb[2:]:
            for _ in range(2):
                d = rng.uniform(0.8, 1.6)
                a = rng.uniform(-1.0, 1.0)
                end = (p[0] + (ix * 0.4 + iy * a) * d, p[1] + (iy * 0.4 + ix * a) * d, p[2] + rng.uniform(-0.3, 0.3))
                add_tube(wood, [p, end], [0.05, 0.02], segs=4)
                twigs.append(end)
        # Fig leaves, broad, in clumps along the outer limb and twigs.
        for p in limb[2:] + twigs:
            for _ in range(9):
                add_card(leaves, uv, (p[0] + rng.uniform(-0.7, 0.7), p[1] + rng.uniform(-0.7, 0.7), p[2] + rng.uniform(-0.45, 0.25)),
                         rng.uniform(0.7, 0.95), rng.uniform(0.65, 0.9), rng.uniform(0, math.pi), rng.uniform(-1.2, 1.2))
    mesh_object(name + "__figs_wood", wood, ["bark"], r)
    mesh_object(name + "__figs_leaves", leaves, ["tree_leaf"], r, recalc=False)


def garden_shaft(r):
    """Rock over the 7 x 7 bay footprint (X, Y 0..28) down to the ring's roofs,
    open over the court (X, Y 4..24) in a shaft: square only where it meets
    the court face, then an uneven funnel of ledges and bulges (your walk 2:
    the square box read as built, not cavern) narrowing to a ragged hole at
    about 34 m, leaning toward the sun, with the sky set back behind a rocky
    collar so the hole's edge stands out against it."""
    name = "garden_shaft_5x5"
    n, size = 28, 28.0
    bm = bmesh.new()
    vs = [[bm.verts.new((float(i), float(j), _shaft_height(float(i), float(j)))) for j in range(n + 1)] for i in range(n + 1)]
    for i in range(n):
        for j in range(n):
            if 4 <= i and i + 1 <= 24 and 4 <= j and j + 1 <= 24:
                continue          # the court: open to the shaft
            bm.faces.new((vs[i][j], vs[i][j + 1], vs[i + 1][j + 1], vs[i + 1][j]))     # facing down
    # A skirt where the rock stands clear of the roofs at the outer edge (over the iwan).
    for (a, b) in [((i, 0), (i + 1, 0)) for i in range(n)] + [((n, j), (n, j + 1)) for j in range(n)] + \
                  [((i + 1, n), (i, n)) for i in range(n)] + [((0, j + 1), (0, j)) for j in range(n)]:
        va, vb = vs[a[0]][a[1]], vs[b[0]][b[1]]
        if va.co.z > 8.4 or vb.co.z > 8.4:
            lo_a = bm.verts.new((va.co.x, va.co.y, 7.9))
            lo_b = bm.verts.new((vb.co.x, vb.co.y, 7.9))
            bm.faces.new((lo_a, lo_b, vb, va))
    # The shaft: ring 0 is the heightfield's edge round the court.
    ring0 = []
    for (x, y) in _square(4.0, 24.0, 20):
        ring0.append(vs[int(round(x))][int(round(y))])
    # The court face: rock from the talar's cornice up to the heightfield's
    # edge (the ring is one storey now, the rock's edge 12.4 m), facing the court.
    for k in range(len(ring0)):
        va, vb = ring0[k], ring0[(k + 1) % len(ring0)]
        if va is vb or (va.co.y > 23.9 and vb.co.y > 23.9 and 8.0 <= min(va.co.x, vb.co.x) and max(va.co.x, vb.co.x) <= 20.0):
            continue          # the iwan fills its three bays
        # Straight only along the cornice; above it the face bulges and
        # recedes (rev 8, your walk 2: no square lines at the top).
        lo_a = bm.verts.new((va.co.x, va.co.y, TALAR_TOP - 0.1))
        lo_b = bm.verts.new((vb.co.x, vb.co.y, TALAR_TOP - 0.1))
        mids = []
        for v in (va, vb):
            nx, ny = (0.0, 1.0) if v.co.y < 4.1 else (0.0, -1.0) if v.co.y > 23.9 else (1.0, 0.0) if v.co.x < 4.1 else (-1.0, 0.0)
            push = noise.noise((v.co.x * 0.45, v.co.y * 0.45, 21.0)) * 0.9 - 0.25        # + into the court, - back into the rock
            push = min(0.35, push)
            z = TALAR_TOP + 1.2 + noise.noise((v.co.x * 0.3, v.co.y * 0.3, 23.0)) * 0.8
            mids.append(bm.verts.new((v.co.x + nx * push, v.co.y + ny * push, min(z, v.co.z - 0.4))))
        bm.faces.new((va, vb, mids[1], mids[0]))
        bm.faces.new((mids[0], mids[1], lo_b, lo_a))
    rings = [ring0]
    # The lip: about 1 m in from the court face and 1.2 m over ring 0, both
    # varied so it reads as a broken ledge, not a frame.
    lip = []
    for idx, (x, y) in enumerate(_square(4.0, 24.0, 20)):
        ux, uy = 14.0 - x, 14.0 - y
        d = math.hypot(ux, uy) or 1.0
        inset = 1.0 + noise.noise((x * 0.35, y * 0.35, 31.0)) * 1.4
        inset = max(0.3, inset)
        lip.append(bm.verts.new((x + ux / d * inset * 1.2, y + uy / d * inset * 1.2, ring0[idx].co.z + 1.2 + noise.noise((x * 0.5, y * 0.5, 33.0)) * 1.0)))
    rings.append(lip)
    # The funnel: each ring blends the square toward an uneven outline round
    # a centre drifting toward the sun, narrowing as it climbs; ledges
    # (rings pushed in and out by noise) and a ragged top edge.
    heights = [15.0, 17.5, 20.0, 22.5, 25.0, 27.5, 30.0, 32.0, SKY_Z]
    square = _square(5.0, 23.0, 20)
    for k, z in enumerate(heights):
        t = (k + 1) / len(heights)
        top = k == len(heights) - 1
        s = min(1.0, t * 2.6)
        s = s * s * (3.0 - 2.0 * s)
        ccx, ccy = 14.0, 14.0 - 1.8 * t
        radius = 9.4 - 3.2 * t ** 0.85
        ledge = noise.noise((k * 0.9, 1.7, 4.4)) * 0.5
        ring = []
        for idx, (x, y) in enumerate(square):
            ang = math.atan2(y - 14.0, x - 14.0)
            ux, uy = math.cos(ang), math.sin(ang)
            wob = noise.noise((ux * 1.3 + 7.0, uy * 1.3, z * 0.12)) * 0.2 + noise.noise((ux * 3.1, uy * 3.1 + 2.0, z * 0.3)) * 0.08
            if top:
                wob = noise.noise((ux * 1.6, uy * 1.6, 11.0)) * 0.3 + noise.noise((ux * 4.0, uy * 4.0, 13.0)) * 0.12
            rad = radius * (1.0 + wob) + ledge
            ox, oy = ccx + ux * rad, ccy + uy * rad
            px = min(23.5, max(4.5, x + (ox - x) * s))
            py = min(23.5, max(4.5, y + (oy - y) * s))
            dz = noise.noise((px * 0.4, py * 0.4, z * 0.2 + 3.0)) * (1.1 if top else 0.6)
            ring.append(bm.verts.new((px, py, z + dz)))
        rings.append(ring)
    for a, b in zip(rings, rings[1:]):
        m = len(a)
        for i in range(m):
            j = (i + 1) % m
            bm.faces.new((a[i], b[i], b[j], a[j]))       # facing into the shaft
    # The collar: rock round the hole, out past the sky's edge, facing down.
    top_ring = rings[-1]
    collar = []
    for v in top_ring:
        dx, dy = v.co.x - 14.0, v.co.y - 12.2
        d = math.hypot(dx, dy) or 1.0
        collar.append(bm.verts.new((v.co.x + dx / d * 5.0, v.co.y + dy / d * 5.0, max(v.co.z, SKY_Z) + 0.4)))
    m = len(top_ring)
    for i in range(m):
        j = (i + 1) % m
        bm.faces.new((top_ring[j], collar[j], collar[i], top_ring[i]))
    _shaft_plants(r, name, ring0, lip, rings[2:], top_ring)
    mesh_object(name + "__rock", bm, ["cave_rock"], r, recalc=False)
    sky = bmesh.new()
    lo_x, hi_x, lo_y, hi_y = 0.5, 27.5, 0.0, 26.0
    zs = SKY_Z + 1.6
    sky.faces.new([sky.verts.new(p) for p in ((lo_x, lo_y, zs), (lo_x, hi_y, zs), (hi_x, hi_y, zs), (hi_x, lo_y, zs))])
    mesh_object(name + "__sky", sky, ["emit_sky_day"], r, recalc=False)
    solid(name + "__lid-colonly", r, ["cave_rock"], lambda bm: add_box(bm, 0.0, size, 0.0, size, SKY_Z + 1.9, SKY_Z + 2.0))
    _shaft_figs(r, name)

    # The sun: one shadowed spot from over the entry side onto the iwan.
    dy, dz = SUN_AIM[1] - SUN_AT[1], SUN_AT[2] - SUN_AIM[2]
    tilt = math.atan2(dy, dz)
    # Rev 13/14 (after walk 5): a leaf projector on the sun left the court unlit by
    # it (any texture, even a plain grid), so the sun has none; rev 14 the haze column.
    sun = marker("LIGHT_sun__shaft", r, SUN_AT, {"range": 2.0 * math.hypot(dy, dz), "energy": 14.0})     # rev 2: range well past the floor (the window had cut it to a third); rev 3: 20, 40 blew the court out; rev 4: 14 (your walk: blinding)
    sun.rotation_euler = (tilt, 0.0, 0.0)
    # Haze down the beam from the sky to the floor.
    t = (SUN_AT[2] - SKY_Z) / dz
    top_y = SUN_AT[1] + dy * t
    haze = marker("FOG_haze__shaft", r, (14.0, (top_y + SUN_AIM[1]) / 2.0, SKY_Z / 2.0),
                  {"fog_size": [11.0, 11.0, SKY_Z / math.cos(tilt)], "density": 0.004, "edge_fade": 0.7,     # rev 13: a soft column you see from the doors (was 0.0012)
                   "albedo": [1.0, 0.97, 0.9], "emission": [0.6, 0.55, 0.48], "emission_energy": 0.02})
    haze.rotation_euler = (tilt, 0.0, 0.0)
    # Fills: the sunlit paving throwing warm light into the arcades and the iwan,
    # the sky's cool light down the shaft into the shade.
    warm, cool = [0.98, 0.95, 0.9], [0.84, 0.9, 1.0]     # rev 3: warm read as firelight in the bays
    # Rev 12 (your walk 3: talar corners near black, the columns black in
    # daylight, bright ivy on black rock): the daylight off the court lights
    # the shade evenly. One fill down the middle of each talar (reaching its
    # corners), the court's bounce onto the columns' faces, the sky's light
    # up the rock; still seven lights with the sun, none shadowed.
    marker("LIGHT_bounce__court", r, (14.0, 16.0, 1.5), {"range": 18.0, "energy": 0.9, "color": warm})
    marker("LIGHT_bounce__west", r, (2.2, 14.0, 4.5), {"range": 17.0, "energy": 1.3, "color": warm})
    marker("LIGHT_bounce__east", r, (25.8, 14.0, 4.5), {"range": 17.0, "energy": 1.3, "color": warm})
    marker("LIGHT_bounce__south", r, (14.0, 2.2, 4.5), {"range": 17.0, "energy": 1.3, "color": warm})
    marker("LIGHT_bounce__iwan", r, (14.0, 25.5, 4.5), {"range": 15.0, "energy": 1.1, "color": warm})
    marker("LIGHT_bounce__sky", r, (14.0, 13.0, 16.0), {"range": 26.0, "energy": 0.9, "color": cool})


# --- the court's floor and water -----------------------------------------------------

POOL_A = 3.0        # the rim's outer apothem (flat to centre)
POOL_RIM = 0.38
POOL_TOP = 0.45
POOL_WATER = 0.36


def _oct(apothem):
    rad = apothem / math.cos(math.pi / 8)
    return [(rad * math.cos(math.pi / 8 + 2 * math.pi * i / 8), rad * math.sin(math.pi / 8 + 2 * math.pi * i / 8)) for i in range(8)]


def garden_pool(r, dry=False):
    """The court's landmark, centred on its origin: an octagonal pool 6 m
    across its flats (they face the rills), a stone rim 0.45 m high to sit
    on with a coping proud of it, tile under clear water, and a fountain of
    two stone bowls in the middle."""
    name = "garden_pool_dry" if dry else "garden_pool"
    outer, inner = _oct(POOL_A), _oct(POOL_A - POOL_RIM)

    def rim(bm):
        for i in range(8):
            j = (i + 1) % 8
            pts = [(inner[i], 0.0), (inner[j], 0.0), (outer[j], 0.0), (outer[i], 0.0)]
            lo = [bm.verts.new((p[0], p[1], 0.0)) for (p, _z) in pts]
            hi = [bm.verts.new((p[0], p[1], POOL_TOP)) for (p, _z) in pts]
            bm.faces.new(list(reversed(lo)))
            bm.faces.new(hi)
            for a in range(4):
                b = (a + 1) % 4
                bm.faces.new((lo[a], lo[b], hi[b], hi[a]))
    solid(name + "__rim-col", r, ["arch_stone"], rim)
    co_o, co_i = _oct(POOL_A + 0.06), _oct(POOL_A - POOL_RIM - 0.05)

    def coping(bm):
        for i in range(8):
            j = (i + 1) % 8
            lo = [bm.verts.new((p[0], p[1], POOL_TOP)) for p in (co_i[i], co_i[j], co_o[j], co_o[i])]
            hi = [bm.verts.new((p[0], p[1], POOL_TOP + 0.07)) for p in (co_i[i], co_i[j], co_o[j], co_o[i])]
            bm.faces.new(list(reversed(lo)))
            bm.faces.new(hi)
            for a in range(4):
                b = (a + 1) % 4
                bm.faces.new((lo[a], lo[b], hi[b], hi[a]))
    solid(name + "__coping", r, ["persian_stone"], coping)
    bm = bmesh.new()
    bm.faces.new([bm.verts.new((x, y, 0.05)) for (x, y) in inner])
    mesh_object(name + "__floor", bm, ["garden_tile"], r, recalc=False)
    solid(name + "__floor-colonly", r, ["garden_tile"], lambda bm: add_ngon_prism(bm, 8, (POOL_A - POOL_RIM) / math.cos(math.pi / 8), -0.2, 0.05))
    if dry:
        # Silt and leaves where the water was; the upper bowl fallen into it.
        rng = random.Random(23)
        bm = bmesh.new()
        bm.faces.new([bm.verts.new((x * 0.99, y * 0.99, 0.09)) for (x, y) in inner])
        mesh_object(name + "__silt", bm, ["soil"], r, recalc=False)
        bm = bmesh.new()
        uv = bm.loops.layers.uv.new("UVMap")
        for _ in range(26):
            a, d = rng.uniform(0, 2 * math.pi), rng.uniform(1.1, POOL_A - POOL_RIM - 0.2)
            add_card(bm, uv, (d * math.cos(a), d * math.sin(a), 0.1), rng.uniform(0.3, 0.6), rng.uniform(0.25, 0.5), rng.uniform(0, math.pi), rng.uniform(-0.5, 0.5))
        mesh_object(name + "__weeds", bm, ["fern"], r, recalc=False)

        def fountain(bm):
            add_lathe(bm, [(0.0, 0.05), (0.55, 0.05), (0.55, 0.2), (0.3, 0.3), (0.18, 0.75), (0.95, 0.85), (1.0, 0.95),
                           (0.9, 0.93), (0.0, 0.9)], segs=12)
            add_lathe(bm, [(0.0, 0.9), (0.14, 0.9), (0.1, 1.25), (0.0, 1.3)], segs=8)      # the stem, snapped
        solid(name + "__fountain-col", r, ["arch_stone"], fountain)
        bowl = bmesh.new()
        add_lathe(bowl, [(0.0, 0.0), (0.1, 0.0), (0.5, 0.07), (0.53, 0.15), (0.45, 0.14), (0.0, 0.12)], segs=10)
        bmesh.ops.rotate(bowl, verts=bowl.verts, cent=(0, 0, 0), matrix=__import__("mathutils").Matrix.Rotation(1.1, 3, "Y"))
        bmesh.ops.translate(bowl, verts=bowl.verts, vec=(1.75, -0.9, 0.42))
        mesh_object(name + "__fallen_bowl", bowl, ["arch_stone"], r)
        return
    bm = bmesh.new()
    bm.faces.new([bm.verts.new((x * 1.002, y * 1.002, POOL_WATER)) for (x, y) in inner])
    mesh_object(name + "__water", bm, ["cistern_water"], r, recalc=False)     # walk 5: the rills' moving water (hauz_water read as ice)

    def fountain(bm):
        add_lathe(bm, [(0.0, 0.05), (0.55, 0.05), (0.55, 0.2), (0.3, 0.3), (0.18, 0.75), (0.95, 0.85), (1.0, 0.95),
                       (0.9, 0.93), (0.0, 0.9)], segs=12)
        add_lathe(bm, [(0.0, 0.9), (0.14, 0.9), (0.1, 1.35), (0.5, 1.42), (0.53, 1.5), (0.45, 1.49), (0.0, 1.47)], segs=10)
        add_lathe(bm, [(0.0, 1.47), (0.08, 1.47), (0.05, 1.7), (0.1, 1.76), (0.0, 1.84)], segs=8)
    solid(name + "__fountain-col", r, ["arch_stone"], fountain)
    bm = bmesh.new()
    add_lathe(bm, [(0.0, 0.92), (0.88, 0.92), (0.88, 0.93), (0.0, 0.93)], segs=12)
    add_lathe(bm, [(0.0, 1.48), (0.44, 1.48), (0.44, 1.49), (0.0, 1.49)], segs=10)
    mesh_object(name + "__bowls", bm, ["cistern_water"], r)
    # Walk 5 (the water at the top was flat faces): no jet mesh; GardenCourtLife
    # throws a spray of drops up off the finial into the top bowl.


def garden_rill(r, dry=False):
    """A paved cell with a stone rill 0.4 m wide down its run (Y), the water a
    few centimetres under the paving; the floor's collision is flush over it."""
    name = "garden_rill_dry_4m" if dry else "garden_rill_4m"
    solid(name + "__floor-colonly", r, ["paving"], lambda bm: add_box(bm, 0.0, 4.0, 0.0, 4.0, -0.2, 0.0))

    def paving(bm):
        add_box(bm, 0.0, 1.7, 0.0, 4.0, -0.2, 0.0)
        add_box(bm, 2.3, 4.0, 0.0, 4.0, -0.2, 0.0)
    solid(name + "__paving", r, ["paving"], paving)

    def stone(bm):
        add_box(bm, 1.7, 1.8, 0.0, 4.0, -0.2, 0.02)
        add_box(bm, 2.2, 2.3, 0.0, 4.0, -0.2, 0.02)
        add_box(bm, 1.8, 2.2, 0.0, 4.0, -0.2, -0.13)
    solid(name + "__stone", r, ["persian_stone"], stone)
    if dry:
        # Dry and cracked: silt, moss and weeds in the channel, a coping stone
        # lifted and one fallen in.
        rng = random.Random(29)
        bm = bmesh.new()
        quad(bm, ((1.8, 0.0, -0.1), (2.2, 0.0, -0.1), (2.2, 4.0, -0.1), (1.8, 4.0, -0.1)))
        mesh_object(name + "__silt", bm, ["moss"], r, recalc=False)
        solid(name + "__broken", r, ["persian_stone"], lambda bm: (add_box(bm, 1.82, 2.18, 1.3, 1.75, -0.12, -0.02),
                                                                   add_box(bm, 2.2, 2.32, 2.6, 3.2, -0.2, 0.06)))
        bm = bmesh.new()
        uv = bm.loops.layers.uv.new("UVMap")
        for _ in range(9):
            y = rng.uniform(0.2, 3.8)
            add_card(bm, uv, (rng.choice((1.75, 2.0, 2.25)), y, -0.1), rng.uniform(0.25, 0.45), rng.uniform(0.2, 0.4), rng.uniform(0, math.pi), 0.0)
        mesh_object(name + "__weeds", bm, ["fern"], r, recalc=False)
        return
    bm = bmesh.new()
    quad(bm, ((1.8, 0.0, -0.05), (2.2, 0.0, -0.05), (2.2, 4.0, -0.05), (1.8, 4.0, -0.05)))
    mesh_object(name + "__water", bm, ["cistern_water"], r, recalc=False)


BED_CLIP = 2.3     # the cut corner's line x + y = BED_CLIP (a path about 1.4 m wide round the pool's coping)


def _poly_prism(bm, pts, z0, z1):
    """A closed prism of the convex polygon `pts` (counter-clockwise from above)."""
    lo = [bm.verts.new((x, y, z0)) for (x, y) in pts]
    hi = [bm.verts.new((x, y, z1)) for (x, y) in pts]
    bm.faces.new(list(reversed(lo)))
    bm.faces.new(hi)
    for i in range(len(pts)):
        j = (i + 1) % len(pts)
        bm.faces.new((lo[i], lo[j], hi[j], hi[i]))


def _cut_square(lo, hi, k):
    """The square [lo, hi]^2 with the corner at (lo, lo) cut off along x + y = k."""
    return [(k - lo, lo), (hi, lo), (hi, hi), (lo, hi), (lo, k - lo)]


def garden_bed(r, wild=False, clip=False):
    """A planted quarter-cell: a paved border 0.35 m wide, soil inside a low
    stone edging, flowers and ferns. Only the floor collides. clip (your walk
    3: no room to walk round the pool): the four beds diagonal to the pool
    have the corner at the origin (the grammar turns it to the pool) cut off
    along a line parallel to the pool's diagonal side, so the bed is five-sided
    and a paved path runs round the pool."""
    name = ("garden_bed_clip_wild_4m" if clip else "garden_bed_wild_4m") if wild else ("garden_bed_clip_4m" if clip else "garden_bed_4m")
    solid(name + "__floor-colonly", r, ["paving"], lambda bm: add_box(bm, 0.0, 4.0, 0.0, 4.0, -0.2, 0.0))
    b = 0.35
    e = 0.08
    k_out, k_in = BED_CLIP, BED_CLIP + e * math.sqrt(2.0)

    def border(bm):
        add_box(bm, 0.0, 4.0, 0.0, b, -0.2, 0.0)
        add_box(bm, 0.0, 4.0, 4.0 - b, 4.0, -0.2, 0.0)
        add_box(bm, 0.0, b, b, 4.0 - b, -0.2, 0.0)
        add_box(bm, 4.0 - b, 4.0, b, 4.0 - b, -0.2, 0.0)
        if clip:          # the cut corner paved
            _poly_prism(bm, [(b, b), (k_out - b, b), (b, k_out - b)], -0.2, 0.0)
    solid(name + "__border", r, ["paving"], border)

    def edging(bm):
        if clip:
            outer, inner = _cut_square(b, 4.0 - b, k_out), _cut_square(b + e, 4.0 - b - e, k_in)
            for i in range(5):
                j = (i + 1) % 5
                _poly_prism(bm, [outer[i], outer[j], inner[j], inner[i]], -0.05, 0.1)
            return
        add_box(bm, b, 4.0 - b, b, b + e, -0.05, 0.1)
        add_box(bm, b, 4.0 - b, 4.0 - b - e, 4.0 - b, -0.05, 0.1)
        add_box(bm, b, b + e, b + e, 4.0 - b - e, -0.05, 0.1)
        add_box(bm, 4.0 - b - e, 4.0 - b, b + e, 4.0 - b - e, -0.05, 0.1)
    solid(name + "__edging", r, ["persian_stone"], edging)
    if clip:
        solid(name + "__soil", r, ["persian_soil"], lambda bm: _poly_prism(bm, _cut_square(b + e, 4.0 - b - e, k_in), -0.2, 0.04))
    else:
        solid(name + "__soil", r, ["persian_soil"], lambda bm: add_box(bm, b + e, 4.0 - b - e, b + e, 4.0 - b - e, -0.2, 0.04))

    def out(nm, bm, mats):
        """The bed's foliage, less any card standing in the cut corner."""
        if clip:
            gone = [f for f in bm.faces if (f.calc_center_median().x + f.calc_center_median().y) < k_in + 0.1]
            bmesh.ops.delete(bm, geom=gone, context="FACES")
            if nm.endswith("__edging_leaf"):
                uv = bm.loops.layers.uv.active
                t = 0.0
                x0, y0 = k_in - (b + e + 0.12) + 0.1, b + e + 0.12
                ln = (x0 - y0) * math.sqrt(2.0)
                while t < ln:        # the edging leaves along the cut
                    x, y = x0 - t / math.sqrt(2.0), y0 + t / math.sqrt(2.0)
                    add_card(bm, uv, (x, y, 0.02), 0.42, 0.34, -math.pi / 4, 0.0)
                    t += 0.3
        mesh_object(nm, bm, mats, r, recalc=False)
    rng = random.Random(11)
    lo, hi = b + e + 0.2, 4.0 - b - e - 0.2
    if wild:
        # Gone wild: tall ferns and weeds over the edging onto the paving, a
        # few flowers left, ivy creeping across the border.
        bm = bmesh.new()
        uv = bm.loops.layers.uv.new("UVMap")
        for _ in range(34):          # rev 2: 22 -> 34 (your walk 3: more lush)
            x, y = rng.uniform(lo - 0.25, hi + 0.25), rng.uniform(lo - 0.25, hi + 0.25)
            s = rng.uniform(0.9, 1.7)
            for a in (0.0, math.pi / 2):
                add_card(bm, uv, (x, y, 0.03), 0.7 * s, 0.65 * s, a + rng.uniform(0, 0.6), rng.uniform(-0.25, 0.25))
        out(name + "__ferns", bm, ["fern"])
        bm = bmesh.new()
        uv = bm.loops.layers.uv.new("UVMap")
        for _ in range(5):
            add_card(bm, uv, (rng.uniform(lo, hi), rng.uniform(lo, hi), 0.03), rng.uniform(0.4, 0.6), rng.uniform(0.3, 0.45), rng.uniform(0, math.pi), 0.0)
        out(name + "__flowers", bm, ["persian_flowers"])
        bm = bmesh.new()
        uv = bm.loops.layers.uv.new("UVMap")
        for _ in range(14):
            edge = rng.randrange(4)
            t = rng.uniform(0.1, 3.9)
            x, y = [(t, 0.15), (t, 3.85), (0.15, t), (3.85, t)][edge]
            add_card(bm, uv, (x, y, 0.005), rng.uniform(0.3, 0.5), rng.uniform(0.3, 0.55), rng.uniform(0, math.pi), -math.pi / 2)
        out(name + "__ivy", bm, ["ivy_leaf"])
        return
    # rev 2 (your walk 3: more lush): the bed packed, low flowers to tall
    # ones, ferns in clumps, a clipped leafy edging along the stone, flowers
    # leaning out over it.
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    for _ in range(46):
        x, y = rng.uniform(lo, hi), rng.uniform(lo, hi)
        tall = rng.random() < 0.25
        h = rng.uniform(0.6, 1.0) if tall else rng.uniform(0.3, 0.5)
        yaw = rng.uniform(0, math.pi)
        add_card(bm, uv, (x, y, 0.03), rng.uniform(0.5, 0.8), h, yaw, rng.uniform(-0.15, 0.15))
        if tall:
            add_card(bm, uv, (x, y, 0.03), rng.uniform(0.5, 0.8), h * 0.9, yaw + math.pi / 2, 0.0)
    for _ in range(10):             # over the edging
        edge = rng.randrange(4)
        t = rng.uniform(lo, hi)
        x, y, yaw = [(t, lo - 0.05, 0.0), (t, hi + 0.05, 0.0), (lo - 0.05, t, math.pi / 2), (hi + 0.05, t, math.pi / 2)][edge]
        lean = 0.5 if edge in (0, 3) else -0.5
        add_card(bm, uv, (x, y, 0.06), rng.uniform(0.5, 0.7), rng.uniform(0.3, 0.45), yaw, lean)
    out(name + "__flowers", bm, ["persian_flowers"])
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    for _ in range(14):
        x, y = rng.uniform(lo, hi), rng.uniform(lo, hi)
        s = rng.uniform(0.8, 1.35)
        a0 = rng.uniform(0, math.pi)
        for a in (0.0, math.pi / 3, 2 * math.pi / 3):
            add_card(bm, uv, (x, y, 0.03), 0.65 * s, 0.6 * s, a0 + a, rng.uniform(-0.2, 0.2))
    out(name + "__ferns", bm, ["fern"])
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    inner = b + e + 0.12
    for (x0, y0, dx, dy, yaw) in ((inner, inner, 1, 0, 0.0), (inner, 4.0 - inner, 1, 0, 0.0),
                                  (inner, inner, 0, 1, math.pi / 2), (4.0 - inner, inner, 0, 1, math.pi / 2)):
        t = 0.0
        while t < 4.0 - 2 * inner:
            x, y = x0 + dx * t, y0 + dy * t
            add_card(bm, uv, (x, y, 0.02), 0.42, rng.uniform(0.3, 0.38), yaw + rng.uniform(-0.2, 0.2), rng.uniform(-0.2, 0.2))
            add_card(bm, uv, (x, y, 0.02), 0.3, rng.uniform(0.28, 0.36), yaw + math.pi / 2, 0.0)
            t += 0.3
    out(name + "__edging_leaf", bm, ["leaf"])


# --- the talar: the court's sides (your walk, after Chehel Sotoun) -----------------
#
# A deep porch round the court: tall slender wooden columns on stone bases,
# stepped capitals, a beam, and a flat painted timber ceiling at 8.3 m; behind
# it one tall plastered wall with two tiers of pointed niches. A bay piece's
# frame is the caravanserai's: X 0..4 along the court face, Y 0 at the face
# into the bay, the back wall at Y 3.5..4.

TALAR_CEIL = 8.3      # the ceiling's underside
TALAR_TOP = 8.6       # the roof's top
COL_Y = 0.4           # the colonnade's line in from the court face
BACK_Y = 3.5          # the back wall's face


def column(bm_wood, bm_stone, x, y):
    """A talar column at (x, y): an octagonal stone base, a slim octagonal
    wooden shaft tapering up, a stepped capital of three corbels."""
    add_ngon_prism(bm_stone, 8, 0.36, 0.0, 0.25, cx=x, cy=y)
    add_ngon_prism(bm_stone, 8, 0.3, 0.25, 0.55, cx=x, cy=y)
    add_lathe(bm_wood, [(0.0, 0.55), (0.17, 0.55), (0.16, 2.0), (0.14, 7.2), (0.0, 7.2)], cx=x, cy=y, segs=8)
    for k, (h, z0) in enumerate(((0.2, 7.2), (0.28, 7.45), (0.36, 7.7))):
        add_box(bm_wood, x - h, x + h, y - h, y + h, z0, z0 + 0.25)


def talar_ceiling(r, name, x0, x1, y0, y1):
    """The flat painted ceiling over (x0..x1, y0..y1): boards, a grid of
    darker battens every metre, painted panels between them; the roof slab
    over it (collision)."""
    solid(name + "__roof-col", r, ["persian_wood"], lambda bm: add_box(bm, x0, x1, y0, y1, TALAR_CEIL, TALAR_TOP))

    def battens(bm):
        x = math.ceil(x0)
        while x < x1 - 0.01:
            add_box(bm, x - 0.05, x + 0.05, y0, y1, TALAR_CEIL - 0.1, TALAR_CEIL)
            x += 1.0
        y = math.ceil(y0)
        while y < y1 - 0.01:
            add_box(bm, x0, x1, y - 0.05, y + 0.05, TALAR_CEIL - 0.1, TALAR_CEIL)
            y += 1.0
    solid(name + "__battens", r, ["wood"], battens)

    def panels(bm):
        x = math.floor(x0)
        while x < x1:
            y = math.floor(y0)
            while y < y1:
                a0, a1, b0, b1 = max(x, x0) + 0.2, min(x + 1.0, x1) - 0.2, max(y, y0) + 0.2, min(y + 1.0, y1) - 0.2
                if a1 > a0 and b1 > b0:
                    quad(bm, ((a0, b0, TALAR_CEIL - 0.01), (a0, b1, TALAR_CEIL - 0.01), (a1, b1, TALAR_CEIL - 0.01), (a1, b0, TALAR_CEIL - 0.01)))
                y += 1.0
            x += 1.0
    solid(name + "__panels", r, ["garden_tile"], panels, recalc=False)


def talar_back(r, name, x0, x1, door=False):
    """The back wall from x0 to x1 (Y BACK_Y..4, to the ceiling): a tile dado,
    a tall pointed niche below and one small one centred over it per 4 m, a painted
    band under the ceiling. door: the kit's 3 m doorway (X 0.5..3.5) in
    place of the lower niche, its wall astride the cell's edge as door walls are."""
    # Walk 5: the door wall's face flush with the bays' (3.5), its piers proud of
    # it (they were half behind the next bay's wall, the caps z-fighting it).
    y0 = BACK_Y
    y1 = 4.0 if not door else 4.3
    body = solid(name + "__back-col", r, ["persian_plaster"], lambda bm: add_box(bm, x0, x1, y0, y1, 0.0, TALAR_CEIL))
    x = x0
    while x < x1 - 0.01:
        if door:
            cut(body, cutter(r, lambda bm, x=x: add_prism(bm, arch_outline(3.0, 1.8, 0.6, 10), x + 0.5, -0.01, y0 - 0.1, y1 + 0.1), mat="brick"))
        else:
            # Walk 5: the tall niche a little lower (crown 5.1 m) so the upper
            # one clears it.
            cut(body, cutter(r, lambda bm, x=x: add_prism(bm, arch_outline(2.2, 2.9, 0.6, 10), x + 0.9, 0.9, y0 - 0.1, y0 + 0.22), mat="persian_plaster_lime"))
        for xx in (x + 1.5,):          # walk 5: one small niche, centred over the tall one (two cut into it)
            cut(body, cutter(r, lambda bm, xx=xx: add_prism(bm, arch_outline(1.0, 0.9, 0.6, 8), xx, 5.7, y0 - 0.1, y0 + 0.18), mat="persian_plaster_lime"))
        x += 4.0
    solid(name + "__dado", r, ["garden_tile"], lambda bm: add_box(bm, x0, x1, y0 - 0.03, y0, 0.0, 0.85 if not door else 0.0))
    solid(name + "__band", r, ["garden_band"], lambda bm: add_box(bm, x0, x1, y0 - 0.03, y0, 7.5, TALAR_CEIL))
    if door:
        solid(name + "__piers-col", r, ["arch_stone"], lambda bm: (pier(bm, 0.0, 3.85), pier(bm, 4.0, 3.85)))


def talar_front(r, name, x0, x1):
    """The beam on the column heads along the court face and the cornice
    over it, proud of the face."""
    solid(name + "__beam", r, ["persian_wood"], lambda bm: add_box(bm, x0, x1, COL_Y - 0.3, COL_Y + 0.3, 7.95, TALAR_CEIL))
    solid(name + "__cornice", r, ["persian_wood"], lambda bm: add_box(bm, x0, x1, -0.45, COL_Y - 0.3, TALAR_CEIL - 0.2, TALAR_TOP + 0.05))
    solid(name + "__fascia", r, ["garden_band"], lambda bm: add_box(bm, x0, x1, -0.47, -0.45, TALAR_CEIL - 0.15, TALAR_TOP))


def talar_bay(door):
    def build(r):
        name = "garden_talar_door" if door else "garden_talar_bay"
        solid(name + "__floor-col", r, ["floor_stone"], lambda bm: add_box(bm, 0.0, 4.0, 0.0, 4.0, -0.2, 0.0))
        # rev 2 (your walk 3: too many columns): no columns in the bay; the
        # grammar stands garden_column along each side, about 3 m apart.
        talar_ceiling(r, name, 0.0, 4.0, COL_Y - 0.3, 4.0)
        talar_front(r, name, 0.0, 4.0)
        talar_back(r, name, 0.0, 4.0, door)
    return build


def talar_corner(r):
    """The talar turning a corner: the court's corner at the origin, the cell
    X, Y 0..4; the colonnade lines at X = 0.4 and Y = 0.4 meet at one column;
    back walls on the two outer sides."""
    name = "garden_talar_corner"
    solid(name + "__floor-col", r, ["floor_stone"], lambda bm: add_box(bm, 0.0, 4.0, 0.0, 4.0, -0.2, 0.0))
    wood, stone = bmesh.new(), bmesh.new()
    column(wood, stone, COL_Y, COL_Y)
    mesh_object(name + "__columns-col", wood, ["persian_wood"], r)
    mesh_object(name + "__bases-col", stone, ["persian_stone"], r)
    talar_ceiling(r, name, COL_Y - 0.3, 4.0, COL_Y - 0.3, 4.0)

    def beams(bm):
        add_box(bm, COL_Y - 0.3, COL_Y + 0.3, 0.0, COL_Y + 0.3, 7.95, TALAR_CEIL)
        add_box(bm, 0.0, COL_Y + 0.3, COL_Y - 0.3, COL_Y + 0.3, 7.95, TALAR_CEIL)
        add_box(bm, -0.45, COL_Y - 0.3, -0.45, COL_Y - 0.3, TALAR_CEIL - 0.2, TALAR_TOP + 0.05)     # the cornice's corner
        add_box(bm, -0.45, COL_Y - 0.3, COL_Y - 0.3, 4.0, TALAR_CEIL - 0.2, TALAR_TOP + 0.05)
        add_box(bm, COL_Y - 0.3, 4.0, -0.45, COL_Y - 0.3, TALAR_CEIL - 0.2, TALAR_TOP + 0.05)
    solid(name + "__beam", r, ["persian_wood"], beams)
    solid(name + "__back-col", r, ["persian_plaster"], lambda bm: (add_box(bm, BACK_Y, 4.0, 0.0, 4.0, 0.0, TALAR_CEIL),
                                                                   add_box(bm, 0.0, BACK_Y, BACK_Y, 4.0, 0.0, TALAR_CEIL)))
    solid(name + "__dado", r, ["garden_tile"], lambda bm: (add_box(bm, BACK_Y - 0.03, BACK_Y, 0.0, BACK_Y, 0.0, 0.85),
                                                    add_box(bm, 0.0, BACK_Y, BACK_Y - 0.03, BACK_Y, 0.0, 0.85)))
    solid(name + "__band", r, ["garden_band"], lambda bm: (add_box(bm, BACK_Y - 0.03, BACK_Y, 0.0, BACK_Y, 7.5, TALAR_CEIL),
                                                      add_box(bm, 0.0, BACK_Y, BACK_Y - 0.03, BACK_Y, 7.5, TALAR_CEIL)))


def corridor(r):
    """A vaulted passage between rooms (your walk: longer ways in and out):
    3 m wide between brick walls, a pointed barrel vault 4.4 m high, run along
    Y; a plaster band and a niche either side, dim (the rooms' light reaches
    in from both ends)."""
    name = "garden_corridor_4m"
    body = solid(name + "__body-col", r, ["brick"], lambda bm: add_box(bm, 0.0, 4.0, 0.0, 4.0, 0.0, 4.8))
    cut(body, cutter(r, lambda bm: add_prism(bm, arch_outline(3.0, 2.6, 0.6, 12), 0.5, -0.01, -0.1, 4.1), mat="brick"))
    solid(name + "__floor-col", r, ["floor_stone"], lambda bm: add_box(bm, 0.0, 4.0, 0.0, 4.0, -0.2, 0.0))
    solid(name + "__dado", r, ["garden_tile"], lambda bm: (add_box(bm, 0.5, 0.53, 0.0, 4.0, 0.0, 0.7), add_box(bm, 3.47, 3.5, 0.0, 4.0, 0.0, 0.7)))


# --- step 2: the garden's life and its wild state ---------------------------------

def garden_bench(r):
    """A stone garden bench, centred, 1.8 m along X, seat 0.45 m high, on two
    carved feet; you sit facing -Y (Godot +Z)."""
    name = "garden_bench"
    solid(name + "__seat-col", r, ["persian_stone"], lambda bm: add_box(bm, -0.9, 0.9, -0.24, 0.24, 0.38, 0.47))
    solid(name + "__feet-col", r, ["arch_stone"], lambda bm: (add_box(bm, -0.78, -0.56, -0.18, 0.18, 0.0, 0.38),
                                                             add_box(bm, 0.56, 0.78, -0.18, 0.18, 0.0, 0.38),
                                                             add_box(bm, -0.82, -0.52, -0.21, 0.21, 0.0, 0.06),
                                                             add_box(bm, 0.52, 0.82, -0.21, 0.21, 0.0, 0.06)))


def garden_niche_shelves(r):
    """Shelves in a talar bay's tall niche (the bay's frame: the niche X
    0.9..3.1 from 0.9 m up, its back at Y 3.72): three boards with books, clay
    pots and a folded cloth, a big jar on the niche's floor."""
    name = "garden_niche_shelves"
    rng = random.Random(41)
    boards = (1.75, 2.6, 3.45)
    solid(name + "__boards", r, ["persian_wood"], lambda bm: [add_box(bm, 0.93, 3.07, 3.4, 3.71, z, z + 0.04) for z in boards])
    books, pots = bmesh.new(), bmesh.new()
    for k, z in enumerate(boards):
        x = 1.0 + rng.uniform(0.0, 0.2)
        while x < 2.95:
            if rng.random() < 0.3 and x < 2.7:
                rad = rng.uniform(0.07, 0.11)
                h = rng.uniform(0.16, 0.26)
                add_lathe(pots, [(0.0, z + 0.04), (rad * 0.7, z + 0.04), (rad, z + 0.04 + h * 0.5), (rad * 0.55, z + 0.04 + h),
                                 (rad * 0.65, z + 0.06 + h), (0.0, z + 0.06 + h)], cx=x + rad, cy=3.56, segs=8)
                x += rad * 2 + 0.06
            else:
                w = rng.uniform(0.04, 0.07)
                h = rng.uniform(0.2, 0.3)
                lean = rng.random() < 0.15
                add_box(books, x, x + w, 3.45, 3.68, z + 0.04, z + 0.04 + h * (0.8 if lean else 1.0))
                x += w + rng.uniform(0.0, 0.015)
            if rng.random() < 0.12:
                x += rng.uniform(0.15, 0.35)      # a gap
    mesh_object(name + "__books", books, ["book_leather"], r)
    add_lathe(pots, [(0.0, 0.9), (0.16, 0.9), (0.26, 1.15), (0.22, 1.45), (0.12, 1.55), (0.14, 1.6), (0.0, 1.6)], cx=2.3, cy=3.5, segs=10)
    mesh_object(name + "__pots", pots, ["earthenware"], r)
    solid(name + "__cloth", r, ["linen"], lambda bm: add_box(bm, 1.1, 1.55, 3.45, 3.68, 0.9, 0.98))


def _basket(bm_wicker, bm_fruit, cx, cy, n_fruit, rng, tipped=False):
    prof = [(0.0, 0.0), (0.2, 0.0), (0.27, 0.22), (0.25, 0.22), (0.18, 0.02), (0.0, 0.02)]
    tmp = bmesh.new()
    add_lathe(tmp, prof, segs=10)
    if tipped:
        from mathutils import Matrix
        bmesh.ops.rotate(tmp, verts=tmp.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(1.35, 3, "X"))
        bmesh.ops.translate(tmp, verts=tmp.verts, vec=(0, 0, 0.25))
    bmesh.ops.translate(tmp, verts=tmp.verts, vec=(cx, cy, 0))
    me = bpy.data.meshes.new("tmp_basket")
    tmp.to_mesh(me)
    bm_wicker.from_mesh(me)
    bpy.data.meshes.remove(me)
    for _ in range(n_fruit):
        a, d = rng.uniform(0, 2 * math.pi), rng.uniform(0.0, 0.13)
        fx, fy = cx + d * math.cos(a), cy + d * math.sin(a)
        fz = 0.12 + rng.uniform(0.0, 0.08)
        if tipped:
            fx, fy, fz = cx + rng.uniform(-0.3, 0.3), cy - 0.25 - rng.uniform(0.0, 0.4), 0.0
        add_lathe(bm_fruit, [(0.0, fz), (0.06, fz + 0.03), (0.075, fz + 0.08), (0.05, fz + 0.13), (0.0, fz + 0.14)], cx=fx, cy=fy, segs=6)


def garden_traces(old):
    """The gardener's things on the paving by a bed, centred: a basket of
    pomegranates, a clay watering jar with a spout, a pruning knife and cut
    twigs. old: the Forgotten Wing's, left long ago: the basket tipped and
    empty but for rotten fruit, the jar broken, the knife rusted."""
    def build(r):
        name = "garden_traces_old" if old else "garden_traces"
        rng = random.Random(53 if old else 47)
        wicker, fruit = bmesh.new(), bmesh.new()
        _basket(wicker, fruit, -0.35, 0.1, 2 if old else 7, rng, tipped=old)
        mesh_object(name + "__basket", wicker, ["wicker"], r)
        mesh_object(name + "__fruit", fruit, ["pomegranate"], r)
        jar = bmesh.new()
        if old:
            add_lathe(jar, [(0.0, 0.0), (0.13, 0.0), (0.2, 0.12), (0.19, 0.17), (0.0, 0.17)], cx=0.45, cy=0.05, segs=9)
            for k in range(4):
                a = rng.uniform(0, 2 * math.pi)
                x, y = 0.45 + 0.35 * math.cos(a), 0.05 + 0.35 * math.sin(a)
                add_box(jar, x - 0.06, x + 0.06, y - 0.04, y + 0.04, 0.0, 0.025)
        else:
            add_lathe(jar, [(0.0, 0.0), (0.13, 0.0), (0.2, 0.12), (0.19, 0.28), (0.09, 0.38), (0.07, 0.44), (0.09, 0.46), (0.0, 0.46)],
                      cx=0.45, cy=0.05, segs=10)
            add_tube(jar, [(0.6, 0.05, 0.2), (0.72, 0.05, 0.3), (0.78, 0.05, 0.38)], [0.035, 0.025, 0.02], segs=5)
            add_tube(jar, [(0.45, -0.1, 0.42), (0.45, -0.2, 0.36), (0.45, -0.19, 0.22)], 0.015, segs=4)
        mesh_object(name + "__jar", jar, ["earthenware"], r)
        knife = bmesh.new()
        add_box(knife, 0.0, 0.11, -0.32, -0.3, 0.0, 0.012)
        mesh_object(name + "__blade", knife, ["iron"], r)
        handle = bmesh.new()
        add_box(handle, -0.11, 0.0, -0.325, -0.295, 0.0, 0.022)
        twigs = bmesh.new()
        for _ in range(6 if not old else 3):
            x, y = rng.uniform(-0.1, 0.4), rng.uniform(-0.55, -0.4)
            a = rng.uniform(-0.6, 0.6)
            l = rng.uniform(0.3, 0.55)
            add_tube(twigs, [(x, y, 0.01), (x + l * math.cos(a), y + l * math.sin(a), 0.015)], 0.008, segs=4)
        bmesh.ops.translate(twigs, verts=twigs.verts, vec=(0, 0, 0))
        me_h = bpy.data.meshes.new("tmp_h")
        handle.to_mesh(me_h)
        twigs.from_mesh(me_h)
        bpy.data.meshes.remove(me_h)
        mesh_object(name + "__wood", twigs, ["bark" if old else "wood"], r)
        if old:
            leaves = bmesh.new()
            uv = leaves.loops.layers.uv.new("UVMap")
            for _ in range(8):
                add_card(leaves, uv, (rng.uniform(-0.6, 0.7), rng.uniform(-0.6, 0.5), 0.004), 0.3, 0.3, rng.uniform(0, math.pi), -math.pi / 2)
            mesh_object(name + "__leaves", leaves, ["ivy_leaf"], r, recalc=False)
    return build


def garden_talar_vines(r):
    """The Forgotten Wing's talar gone wild, in a bay's frame: ivy hanging in
    curtains from the cornice (Y -0.5, 8.6 m down 2 to 5 m), climbing two
    columns, and a mat of it along the cornice's top."""
    name = "garden_talar_vines"
    rng = random.Random(61)
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    for _ in range(rng.randint(5, 7)):         # curtains off the cornice
        x, length = rng.uniform(0.1, 3.9), rng.uniform(2.0, 5.0)
        z = TALAR_TOP
        while z > TALAR_TOP - length:
            add_card(bm, uv, (x + rng.uniform(-0.08, 0.08), -0.52, z - 0.32), 0.32, 0.32, rng.uniform(-0.4, 0.4), rng.uniform(-0.3, 0.3))
            z -= rng.uniform(0.2, 0.3)
    # rev 2: the columns are their own pieces now (garden_column_ivy climbs them).
    for _ in range(16):                         # over the cornice's top
        add_card(bm, uv, (rng.uniform(0.0, 4.0), rng.uniform(-0.4, 0.0), TALAR_TOP + 0.06), 0.4, 0.4, rng.uniform(0, math.pi), -math.pi / 2)
    mesh_object(name + "__ivy", bm, ["ivy_leaf"], r, recalc=False)


# --- your walk 3: fewer columns, a lusher garden -------------------------------------

def garden_column(ivy, seed=0):
    """One talar column, centred (the grammar stands them about 3 m apart
    along the colonnade line; the bay pieces have none now). ivy: climbing
    ivy, or jasmine in the tended garden, up the shaft and a tuft at its head."""
    def build(r):
        name = "garden_column_ivy_%d" % seed if ivy else "garden_column"
        wood, stone = bmesh.new(), bmesh.new()
        column(wood, stone, 0.0, 0.0)
        mesh_object(name + "__shaft-col", wood, ["persian_wood"], r)
        mesh_object(name + "__base-col", stone, ["persian_stone"], r)
        if not ivy:
            return
        rng = random.Random(70 + seed)
        bm = bmesh.new()
        uv = bm.loops.layers.uv.new("UVMap")
        top = rng.uniform(4.5, 7.8)
        for strand in range(2):
            z = 0.3
            a = rng.uniform(0, 2 * math.pi)
            while z < top - strand * 1.2:
                add_card(bm, uv, (0.2 * math.cos(a), 0.2 * math.sin(a), z), 0.34, 0.32, a + math.pi / 2, rng.uniform(-0.2, 0.2))
                a += 0.8
                z += 0.2
        if top > 7.0:
            for _ in range(8):       # spilling off the capital
                a = rng.uniform(0, 2 * math.pi)
                add_card(bm, uv, (0.4 * math.cos(a), 0.4 * math.sin(a), 7.0 - rng.uniform(0.0, 0.8)), 0.4, 0.6, a + math.pi / 2, rng.uniform(-0.4, 0.4))
        mesh_object(name + "__ivy", bm, ["ivy_leaf"], r, recalc=False)
    return build


def garden_planter(wild):
    """A big clay pot on the talar's floor, centred, planted: ferns and
    flowers (the tended garden), or gone wild, cracked, ferns spilling and
    ivy trailing down it."""
    def build(r):
        name = "garden_planter_wild" if wild else "garden_planter"
        rng = random.Random(83 if wild else 79)
        bm = bmesh.new()
        add_lathe(bm, [(0.0, 0.0), (0.22, 0.0), (0.24, 0.06), (0.4, 0.3), (0.42, 0.45), (0.34, 0.66), (0.38, 0.7),
                       (0.4, 0.76), (0.33, 0.76), (0.0, 0.72)], segs=12)
        mesh_object(name + "__pot-col", bm, ["earthenware"], r)
        soil = bmesh.new()
        soil.faces.new([soil.verts.new((0.32 * math.cos(2 * math.pi * k / 10), 0.32 * math.sin(2 * math.pi * k / 10), 0.73)) for k in range(10)])
        mesh_object(name + "__soil", soil, ["persian_soil"], r, recalc=False)
        ferns = bmesh.new()
        uv = ferns.loops.layers.uv.new("UVMap")
        for k in range(7 if wild else 5):
            a = 2 * math.pi * k / (7 if wild else 5) + rng.uniform(-0.3, 0.3)
            s = rng.uniform(1.0, 1.5) if wild else rng.uniform(0.8, 1.1)
            add_card(ferns, uv, (0.12 * math.cos(a), 0.12 * math.sin(a), 0.72), 0.7 * s, 0.7 * s, a + math.pi / 2, 0.45)
        mesh_object(name + "__ferns", ferns, ["fern"], r, recalc=False)
        tops = bmesh.new()
        uv = tops.loops.layers.uv.new("UVMap")
        if wild:
            for k in range(6):        # ivy down the pot's side
                a = rng.uniform(0, 2 * math.pi)
                z = 0.75
                while z > 0.1:
                    add_card(tops, uv, (0.44 * math.cos(a), 0.44 * math.sin(a), z - 0.3), 0.26, 0.3, a + math.pi / 2, 0.0)
                    z -= 0.24
            mesh_object(name + "__ivy", tops, ["ivy_leaf"], r, recalc=False)
        else:
            for k in range(4):
                a = rng.uniform(0, 2 * math.pi)
                add_card(tops, uv, (0.1 * math.cos(a), 0.1 * math.sin(a), 0.72), 0.5, rng.uniform(0.55, 0.8), a, 0.0)
            mesh_object(name + "__flowers", tops, ["persian_flowers"], r, recalc=False)
    return build


def garden_shrub(r):
    """A rounded flowering shrub (myrtle, rose) for a bed's corner, centred,
    about 1.1 m high: leaf cards over a dome, a few flowers through it."""
    name = "garden_shrub"
    rng = random.Random(89)
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    for _ in range(30):
        a = rng.uniform(0, 2 * math.pi)
        el = rng.uniform(0.0, 1.2)
        rad = 0.55 * math.cos(el)
        z = 0.1 + 0.6 * math.sin(el)
        add_card(bm, uv, (rad * math.cos(a), rad * math.sin(a), z - 0.2), rng.uniform(0.45, 0.6), rng.uniform(0.45, 0.6), a + math.pi / 2 + rng.uniform(-0.5, 0.5), rng.uniform(-0.6, 0.6))
    mesh_object(name + "__leaves", bm, ["leaf"], r, recalc=False)
    fl = bmesh.new()
    uv = fl.loops.layers.uv.new("UVMap")
    for _ in range(7):
        a = rng.uniform(0, 2 * math.pi)
        add_card(fl, uv, (0.35 * math.cos(a), 0.35 * math.sin(a), 0.45), 0.4, 0.45, a + math.pi / 2, rng.uniform(-0.3, 0.3))
    mesh_object(name + "__flowers", fl, ["persian_flowers"], r, recalc=False)


# --- the room's one great thing (after walk 5) -----------------------------------------

def _limb(rng, start, yaw, pitch, length, r0, steps=4):
    """A crooked limb from `start`: `steps` points wandering off its yaw and
    pitch. Returns the path and its radii (tapering to a third)."""
    pts, radii = [start], [r0]
    x, y, z = start
    for k in range(1, steps + 1):
        yaw += rng.uniform(-0.35, 0.35)
        pitch = max(-0.1, pitch + rng.uniform(-0.2, 0.15))
        seg = length / steps
        x += seg * math.cos(pitch) * math.cos(yaw)
        y += seg * math.cos(pitch) * math.sin(yaw)
        z += seg * math.sin(pitch)
        pts.append((x, y, z))
        radii.append(r0 * (1.0 - 0.65 * k / steps))
    return pts, radii


def garden_tree_old(wild):
    """The garden's great old pomegranate, centred in a bed by the iwan, in
    the sun's patch: a broad, twisted trunk splitting at 1.6 m into two stems,
    limbs spreading to a crown 6 to 7 m across at about 6 m, heavy with red
    fruit, some on the soil under it. Older than the room's other trees by
    centuries; you can stand under its crown and see it from the doorways.
    wild (the Forgotten Wing): dead limbs bare, suckers round its foot, ivy
    up the trunk, fewer fruit and most of them fallen and split."""
    def build(r):
        name = "garden_tree_old_wild" if wild else "garden_tree_old"
        rng = random.Random(97)
        wood = bmesh.new()
        # Root flares into the soil.
        for k in range(6):
            a = 2 * math.pi * k / 6 + rng.uniform(-0.3, 0.3)
            add_tube(wood, [(0.18 * math.cos(a), 0.18 * math.sin(a), 0.5), (0.5 * math.cos(a), 0.5 * math.sin(a), 0.12),
                            (0.85 * math.cos(a), 0.85 * math.sin(a), -0.05)], [0.16, 0.1, 0.05], segs=5)
        # The trunk, twisting up to the fork.
        trunk = [(0.0, 0.0, -0.05), (0.06, -0.04, 0.6), (-0.04, 0.05, 1.2), (0.05, 0.02, 1.65)]
        add_tube(wood, trunk, [0.66, 0.52, 0.47, 0.44], segs=9)     # rev 2: broad, old (rev 1 read thin)
        ends = []
        dead = []
        for s, (yaw0, lean) in enumerate(((0.4, 0.55), (0.4 + math.pi * 0.95, 0.5))):
            stem, sr = _limb(rng, (0.05, 0.02, 1.6), yaw0, 0.95, 2.4, 0.34, steps=3)
            add_tube(wood, stem, sr, segs=7)
            top = stem[-1]
            for k in range(4):
                yaw = yaw0 + (k - 1.5) * 0.85 + rng.uniform(-0.2, 0.2)
                limb, lr = _limb(rng, top, yaw, lean + rng.uniform(-0.15, 0.2), rng.uniform(2.6, 3.4), 0.17, steps=4)
                bare = wild and (s * 4 + k) in (2, 5)
                add_tube(wood, limb, lr, segs=5)
                (dead if bare else ends).append(limb)
                # Twigs off the limb's last two points.
                for p in limb[-2:]:
                    tw, tr = _limb(rng, p, yaw + rng.uniform(-1.2, 1.2), rng.uniform(0.1, 0.6), rng.uniform(0.6, 1.1), 0.035, steps=2)
                    add_tube(wood, tw, tr, segs=4)
                    (dead if bare else ends).append(tw)
        mesh_object(name + "__wood", wood, ["bark"], r)
        solid(name + "__trunk-colonly", r, ["bark"], lambda bm: add_ngon_prism(bm, 8, 0.62, 0.0, 2.4))
        # The crown: leaf clumps round each live limb's outer points.
        leaves = bmesh.new()
        uv = leaves.loops.layers.uv.new("UVMap")
        fruit = bmesh.new()
        hang = []
        for path in ends:
            for p in path[-3:]:
                n = 13 if not wild else 8      # rev 2: a full crown
                for _ in range(n):
                    ox, oy, oz = rng.uniform(-0.95, 0.95), rng.uniform(-0.95, 0.95), rng.uniform(-0.6, 0.45)
                    add_card(leaves, uv, (p[0] + ox, p[1] + oy, p[2] + oz - 0.3), rng.uniform(0.75, 1.0), rng.uniform(0.7, 0.95),
                             rng.uniform(0, math.pi), rng.uniform(-0.7, 0.7))
                hang.append(p)
        mesh_object(name + "__leaves", leaves, ["tree_leaf"], r, recalc=False)

        def pom(bm, x, y, z, s=1.0):
            add_lathe(bm, [(0.0, z - 0.1 * s), (0.09 * s, z - 0.05 * s), (0.1 * s, z + 0.04 * s), (0.04 * s, z + 0.1 * s),
                           (0.05 * s, z + 0.13 * s), (0.0, z + 0.13 * s)], x, y, segs=6)
        rng.shuffle(hang)
        for p in hang[:(10 if wild else 34)]:
            pom(fruit, p[0] + rng.uniform(-0.4, 0.4), p[1] + rng.uniform(-0.4, 0.4), p[2] - rng.uniform(0.35, 0.7))
        # Fallen fruit on the soil (most of the wild tree's).
        for _ in range(12 if wild else 4):
            a, d = rng.uniform(0, 2 * math.pi), rng.uniform(0.7, 1.7)
            pom(fruit, d * math.cos(a), d * math.sin(a), 0.1, 0.9)
        mesh_object(name + "__fruit", fruit, ["pomegranate"], r)
        # Its blossom: scarlet flowers through the tended crown.
        if not wild:
            fl = bmesh.new()
            uv = fl.loops.layers.uv.new("UVMap")
            for p in hang[34:34 + 26]:
                add_card(fl, uv, (p[0] + rng.uniform(-0.5, 0.5), p[1] + rng.uniform(-0.5, 0.5), p[2] - 0.2), 0.3, 0.3,
                         rng.uniform(0, math.pi), rng.uniform(-0.5, 0.5))
            mesh_object(name + "__flowers", fl, ["persian_flowers"], r, recalc=False)
            return
        # Wild: suckers round its foot, ivy up the trunk.
        sk = bmesh.new()
        for k in range(7):
            a = rng.uniform(0, 2 * math.pi)
            d = rng.uniform(0.5, 0.9)
            x, y = d * math.cos(a), d * math.sin(a)
            add_tube(sk, [(x, y, 0.0), (x * 1.1, y * 1.1, 0.7), (x * 1.2 + rng.uniform(-0.2, 0.2), y * 1.2, 1.4)], [0.025, 0.018, 0.01], segs=4)
        mesh_object(name + "__suckers", sk, ["bark"], r)
        ivy = bmesh.new()
        uv = ivy.loops.layers.uv.new("UVMap")
        a, z = 0.0, 0.1
        while z < 2.6:
            add_card(ivy, uv, (0.34 * math.cos(a), 0.34 * math.sin(a), z), 0.32, 0.3, a + math.pi / 2, rng.uniform(-0.2, 0.2))
            a += 0.9
            z += 0.13
        for k in range(7):
            a = rng.uniform(0, 2 * math.pi)
            d = rng.uniform(0.5, 0.9)
            add_card(ivy, uv, (d * math.cos(a) * 1.15, d * math.sin(a) * 1.15, 0.6 + rng.uniform(0.0, 0.8)), 0.4, 0.4, a, 0.3)
        mesh_object(name + "__ivy", ivy, ["ivy_leaf"], r, recalc=False)
    return build


MODULES = [
    ("M_garden_iwan", props("cell", [3, 3, 1], "", "brick,tile,garden,door,landmark,walled"), garden_iwan),
    ("M_garden_talar_bay", props("cell", [1, 3, 1], "", "wood,plaster,garden,walled"), talar_bay(False)),
    ("M_garden_talar_door", props("cell", [1, 3, 1], "", "wood,plaster,garden,door,walled"), talar_bay(True)),
    ("M_garden_talar_corner", props("cell", [1, 3, 1], "", "wood,plaster,garden,walled"), talar_corner),
    ("M_garden_corridor_4m", props("cell", [1, 2, 1], "", "brick,garden,walled"), corridor),
    ("M_garden_shaft_5x5", props("cell", [7, 9, 7], "", "rock,cavern,garden,light"), garden_shaft),
    ("M_garden_pool", props("free", [2, 0, 2], "", "stone,water,garden,landmark", family="dressing"), garden_pool),
    ("M_garden_rill_4m", props("cell", [1, 0, 1], "", "stone,garden,rill"), garden_rill),     # walk 5: not "water" (that made its whole floor wading water: running slowed to a walk)
    ("M_garden_bed_4m", props("cell", [1, 0, 1], "", "plant,garden,lit"), garden_bed),
    ("M_garden_bed_wild_4m", props("cell", [1, 0, 1], "", "plant,garden,lit,wild"), lambda r: garden_bed(r, wild=True)),
    ("M_garden_bed_clip_4m", props("cell", [1, 0, 1], "", "plant,garden,lit"), lambda r: garden_bed(r, clip=True)),
    ("M_garden_bed_clip_wild_4m", props("cell", [1, 0, 1], "", "plant,garden,lit,wild"), lambda r: garden_bed(r, wild=True, clip=True)),
    ("M_garden_rill_dry_4m", props("cell", [1, 0, 1], "", "stone,garden,wild"), lambda r: garden_rill(r, dry=True)),
    ("M_garden_pool_dry", props("free", [2, 0, 2], "", "stone,garden,landmark,wild", family="dressing"), lambda r: garden_pool(r, dry=True)),
    ("M_garden_bench", props("free", [1, 0, 1], "", "stone,garden,seat", family="dressing"), garden_bench),
    ("M_garden_niche_shelves", props("free", [1, 0, 1], "", "wood,garden,books", family="dressing"), garden_niche_shelves),
    ("M_garden_traces", props("free", [1, 0, 1], "", "garden,clutter", family="dressing"), garden_traces(False)),
    ("M_garden_traces_old", props("free", [1, 0, 1], "", "garden,clutter,wild", family="dressing"), garden_traces(True)),
    ("M_garden_talar_vines", props("free", [1, 0, 1], "", "plant,ivy,garden,wild", family="dressing"), garden_talar_vines),
    ("M_garden_column", props("free", [1, 2, 1], "", "wood,garden,column", family="dressing"), garden_column(False)),
    ("M_garden_column_ivy_0", props("free", [1, 2, 1], "", "wood,plant,ivy,garden,column", family="dressing"), garden_column(True, 0)),
    ("M_garden_column_ivy_1", props("free", [1, 2, 1], "", "wood,plant,ivy,garden,column", family="dressing"), garden_column(True, 1)),
    ("M_garden_planter", props("free", [1, 0, 1], "", "plant,garden,pot", family="dressing"), garden_planter(False)),
    ("M_garden_planter_wild", props("free", [1, 0, 1], "", "plant,garden,pot,wild", family="dressing"), garden_planter(True)),
    ("M_garden_shrub", props("free", [1, 0, 1], "", "plant,garden", family="dressing"), garden_shrub),
    ("M_garden_tree_old", props("free", [2, 2, 2], "", "plant,garden,tree,landmark", family="dressing"), garden_tree_old(False)),
    ("M_garden_tree_old_wild", props("free", [2, 2, 2], "", "plant,garden,tree,landmark,wild", family="dressing"), garden_tree_old(True)),
]

# Script-made modules remade in place at a new revision (kit_blender.rebuild).
REBUILD = [("M_garden_iwan", 4),  # rev 3: rock round the pishtaq's top, floral tile (your walk 3); rev 4: origin at its corner (route audit)
                  # rev 2: the frieze in mosaic (hall_frieze read as a flat orange bar)
           ("M_garden_shaft_5x5", 15), ("M_garden_corridor_4m", 4),
           # Your walk 3 (2026-11-05): the bays without columns (rev 2), the
           # talar vines without their column ivy (rev 2), the beds lusher (rev 2).
           # Walk 3b: the floral tile and leafy band (rev 3 / corner rev 2 / corridor rev 4 / pools rev 2).
           ("M_garden_talar_bay", 4), ("M_garden_talar_door", 4), ("M_garden_talar_vines", 2), ("M_garden_talar_corner", 2),
           ("M_garden_pool", 4), ("M_garden_pool_dry", 2), ("M_garden_rill_4m", 2),     # walk 5: pool rev 3 moving water, round jet; rill rev 2 no wading
           ("M_garden_bed_4m", 2), ("M_garden_bed_wild_4m", 2),
           ("M_garden_tree_old", 2), ("M_garden_tree_old_wild", 2)]     # rev 2: a broad trunk, a full crown
# Shaft rev 10: ivy and ferns hanging round the lip, the funnel's ledges and the hole; rev 11: fuller (two strands, wider leaves, more of them).   # rev 2: the sun reaches the court; rev 3: softer sun, less haze, neutral fills; rev 4: dimmer, little haze (your walk); rev 5: a rock face down to the one-storey talar; rev 6: the near talar fill lifted; rev 7: an uneven funnel and a ragged hole (your walk 2); rev 8: the court face and lip broken up; rev 9: the shelf over the pishtaq uneven. Corridor rev 3: a brick vault (court and talar plaster were coarse up close)


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
        x += 32.0 if "shaft" in name else 16.0
    rebuilt = ["%s (rev %d)" % (n, v) for (n, v) in REBUILD if rebuild(n, v, MODULES)]
    # Walk 5: the rill no longer tagged "water" (rebuild keeps the old root's
    # properties, so set its tags here).
    rill = bpy.data.objects.get("M_garden_rill_4m")
    if rill is not None and "water" in str(rill.get("tags", "")):
        rill["tags"] = "stone,garden,rill"
        rebuilt.append("M_garden_rill_4m tags")
    if not added and not rebuilt:
        print("kit_add_r07: everything already present; nothing to do.")
        return
    os.makedirs(os.path.dirname(BLEND), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=BLEND)
    print("kit_add_r07: added %s; rebuilt %s" % (", ".join(added) or "nothing", ", ".join(rebuilt) or "nothing"))


main()

"""Adds the Light-Well Stair's garden, vines and plant niches to
art_src/kit/kit_hall.blend, where the cone's pieces are (room rework step 6:
your Lower Stacks walk of 2026-11-03 asked for an underground garden round the
well with pools between the plants and seats, vines hanging from the stair's
edge and the oculus, and some shelf niches given to plants and decoration).

  blender --background --factory-startup --python tools/kit_add_lightwell.py

Additive like kit_add_r03.py; then run tools/export_kit.bat kit_hall.blend.

Pieces (free; RingGrammar places them, gen/rules/r09_lightwell.tres):
  cone_garden100, cone_garden120  the floor garden for a cone of floor radius
        10 or 12 m, origin on the cone's axis at the floor. Rev 2 (your walk):
        one full ring round the pool, level with the floor, lush (ferns,
        grasses, flowers, moss, trees, glowing mushrooms), stepping stones in
        on the entry's line and opposite, three clearings with garden chairs
        and a low table. A walk 3.2 m wide stays clear along the wall.
  cone_mushbed_a, cone_mushbed_b  a glowing mushroom bed on the floor under the
        first storey's stair, against the wall (origin at the wall's foot,
        the shaft at Blender +Y, 2.8 m along it); a has a fungus light.
  cone_nook  a sitting nook there: rug, floor mattress, cushions, low table.
  cone_vine_a, cone_vine_b  vines hanging from the stair's parapet into the
        shaft: origin on the parapet's top at its inner face, the shaft at
        Blender +Y. a: three strands, 1.2-2.4 m; b: five, 1.8-3.6 m.
  cone_vines_oculus  a fringe of vines hanging from the oculus's rim (origin
        on the axis at the oculus), 1-4.5 m long.
Shelf niches (family dressing; a cone_niche socket's fill, the same frame as
a recess: 3 m wide, the back at Godot z +0.3):
  niche_planter  a stone trough of ferns with ivy trailing over its lip, a pot
        of flowers each side.
  niche_urn      a tall glazed urn of flowers on a plinth, ivy hanging from the
        niche's head, a small fern each side.
"""
import math
import os
import random
import sys

import bmesh
import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kit_blender import add_box, add_card, add_lathe, add_obox, add_tube, marker, mesh_object, module, rebuild  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BLEND = os.path.join(ROOT, "art_src", "kit", "kit_hall.blend")
ROW_Y = -64.0     # past kit_add_hall_cases.py's row

CONE_RT = 2.5     # kit_add_r03.py: the oculus's radius
WALKWAY = 3.2     # the clear walk along the wall at the floor
CURB = 2.0        # the well's curb, out to (kit_add_r03.py cone_base)
GREEN_GOLD = [0.55, 0.95, 0.4]     # the fungus lights here (your walk: a green-yellow light, not teal)


def props(tags, family="walls"):
    return {"kit_shape": "free", "kit_family": family, "size_cells": [0, 0, 0],
            "edge": "", "tags": tags, "weight": 1.0}


def polar(r, t):
    """kit_add_r03.py's polar: Blender (x, y) at radius r, angle t (0 = Blender -Y, the entry)."""
    return (r * math.sin(t), -r * math.cos(t))


def sector(bm, r0, r1, a0, a1, z0, z1, steps=6):
    """A closed block between radii r0 < r1 and angles a0 < a1."""
    rings = []
    for i in range(steps + 1):
        t = a0 + (a1 - a0) * i / steps
        rings.append([bm.verts.new((*polar(r, t), z)) for (r, z) in ((r0, z0), (r1, z0), (r1, z1), (r0, z1))])
    for i in range(steps):
        a, b = rings[i], rings[i + 1]
        for j in range(4):
            jj = (j + 1) % 4
            bm.faces.new((a[j], b[j], b[jj], a[jj]))
    bm.faces.new(list(reversed(rings[0])))
    bm.faces.new(rings[-1])


def ring(bm, r0, r1, cx, cy, z0, z1, segs=16):
    """A round kerb: a closed ring between radii r0 < r1 at (cx, cy)."""
    for i in range(segs):
        a0, a1 = 2 * math.pi * i / segs, 2 * math.pi * (i + 1) / segs
        a = [bm.verts.new((cx + r * math.cos(a0), cy + r * math.sin(a0), z)) for (r, z) in ((r0, z0), (r1, z0), (r1, z1), (r0, z1))]
        b = [bm.verts.new((cx + r * math.cos(a1), cy + r * math.sin(a1), z)) for (r, z) in ((r0, z0), (r1, z0), (r1, z1), (r0, z1))]
        for j in range(4):
            jj = (j + 1) % 4
            bm.faces.new((a[j], a[jj], b[jj], b[j]))
        bm.faces.new(list(reversed(a)))
        bm.faces.new(b)


def disc(bm, r, cx, cy, z, segs=16):
    vs = [bm.verts.new((cx + r * math.cos(2 * math.pi * i / segs), cy + r * math.sin(2 * math.pi * i / segs), z)) for i in range(segs)]
    bm.faces.new(vs)


def fern(bm, uv, rng, x, y, z, size=1.0):
    for k in range(6):
        add_card(bm, uv, (x, y, z), 0.3 * size, rng.uniform(0.45, 0.7) * size, k * math.tau / 6 + rng.uniform(-0.3, 0.3),
                 math.radians(rng.uniform(35, 60)))


def flowers(bm, uv, rng, x, y, z, size=1.0):
    for k in range(3):
        add_card(bm, uv, (x + rng.uniform(-0.1, 0.1), y + rng.uniform(-0.1, 0.1), z), 0.55 * size, 0.4 * size,
                 rng.uniform(0, math.pi), math.radians(rng.uniform(-10, 10)))


def tree(bark, leaves, uv, rng, x, y, z, h):
    """A small tree (a pomegranate or a citrus in a sunk garden): a leaning
    trunk forking into two, a round crown of leaf cards."""
    top = (x + rng.uniform(-0.2, 0.2), y + rng.uniform(-0.2, 0.2), z + h * 0.65)
    add_tube(bark, [(x, y, z), ((x + top[0]) / 2, (y + top[1]) / 2, z + h * 0.35), top], [0.09, 0.07, 0.05], segs=6)
    for s in (-1, 1):
        add_tube(bark, [top, (top[0] + s * 0.35, top[1] + rng.uniform(-0.2, 0.2), top[2] + 0.45)], [0.05, 0.03], segs=5)
    R = h * 0.33
    for _ in range(70):
        a, e = rng.uniform(0, 2 * math.pi), rng.uniform(-0.4, 1.2)
        rr = R * rng.uniform(0.55, 1.0)
        add_card(leaves, uv, (top[0] + rr * math.cos(a) * math.cos(e), top[1] + rr * math.sin(a) * math.cos(e), top[2] + 0.3 + rr * math.sin(e) * 0.8),
                 0.32, 0.3, rng.uniform(0, math.pi), math.radians(rng.uniform(-40, 40)))


def hang(stems, leaves, uv, rng, top, length, out=(0.0, 1.0)):
    """One hanging strand from `top`, swaying a little, leaves along it facing
    `out` (a horizontal direction) and to either side."""
    n = max(3, int(length / 0.25))
    phase = rng.uniform(0, 2 * math.pi)
    path = []
    for k in range(n + 1):
        t = k / n
        sway = 0.06 * math.sin(phase + t * 4.0)
        path.append((top[0] + sway * out[1] + out[0] * 0.04 * t, top[1] - sway * out[0] + out[1] * 0.04 * t, top[2] - length * t))
    add_tube(stems, path, 0.012, segs=4)
    yaw0 = math.atan2(out[0], -out[1])      # a card faces its local -Y turned by yaw
    for k in range(1, n + 1):
        (x, y, z) = path[k]
        for side in (-1, 1):
            if rng.random() < 0.85:
                add_card(leaves, uv, (x + side * 0.04 * out[1], y - side * 0.04 * out[0], z - 0.13), 0.15, 0.15,
                         yaw0 + side * rng.uniform(0.3, 0.9), math.radians(rng.uniform(-25, 25)))


def mushroom(bm_cap, bm_gill, bm_stalk, x, y, z, h, lean=(0.0, 0.0)):
    """kit_add_cistern_niche.py's mushroom: a stalk, a domed cap, glowing gills."""
    R = h * 0.42
    top = (x + lean[0] * h, y + lean[1] * h, z + h)
    add_tube(bm_stalk, [(x, y, z), (x + lean[0] * h * 0.4, y + lean[1] * h * 0.4, z + h * 0.5), top],
             [h * 0.08, h * 0.06, h * 0.05], segs=6)
    add_lathe(bm_cap, [(R, z + h), (R * 0.8, z + h + R * 0.25), (R * 0.45, z + h + R * 0.38), (0.0, z + h + R * 0.42)],
              top[0], top[1], segs=10)
    uv = bm_gill.loops.layers.uv.verify()
    add_lathe(bm_gill, [(h * 0.05, z + h - R * 0.3), (R * 0.55, z + h - R * 0.1), (R * 0.97, z + h - 0.01)],
              top[0], top[1], segs=10, uv=uv)


def mushroom_cluster(caps, gills, stalks, rng, x, y, big=0.5, n=5, spread=0.3, glow=None):
    """A clump: one tall mushroom (`big` m) and smaller ones round it; the
    small ones (under 0.22 m) with glowing caps when `glow` is given."""
    for k in range(n):
        h = big if k == 0 else big * rng.uniform(0.25, 0.65)
        a = rng.uniform(0, 2 * math.pi)
        d = 0.0 if k == 0 else rng.uniform(0.35, 1.0) * spread
        mushroom(glow if (glow is not None and h < 0.22) else caps, gills, stalks, x + d * math.cos(a), y + d * math.sin(a), 0.0, h,
                 (rng.uniform(-0.08, 0.08), rng.uniform(-0.08, 0.08)))


def grass(bm, uv, rng, x, y, size=1.0):
    """A tuft of tall blades (fern cards, narrow and upright)."""
    for k in range(4):
        add_card(bm, uv, (x, y, 0.0), 0.16 * size, rng.uniform(0.5, 0.85) * size, k * math.pi / 4 + rng.uniform(-0.3, 0.3),
                 math.radians(rng.uniform(5, 20)))


def moss_patch(bm, uv, rng, x, y, size=1.0):
    """Ground cover: cards lying almost flat."""
    for k in range(3):
        add_card(bm, uv, (x + rng.uniform(-0.15, 0.15), y + rng.uniform(-0.15, 0.15), 0.01), 0.55 * size, 0.4 * size,
                 rng.uniform(0, math.pi), math.radians(rng.uniform(78, 86)))


def box_at(bm, cx, cy, yaw, u0, u1, v0, v1, z0, z1):
    """A box in a frame turned by yaw about (cx, cy): u across, v along the
    frame's facing (yaw 0 faces Blender +Y)."""
    c, s = math.cos(yaw), math.sin(yaw)
    def p(u, v):
        return (cx + c * u - s * v, cy + s * u + c * v)
    pts = [p(u0, v0), p(u1, v0), p(u1, v1), p(u0, v1)]
    bot = [bm.verts.new((x, y, z0)) for (x, y) in pts]
    top = [bm.verts.new((x, y, z1)) for (x, y) in pts]
    bm.faces.new(list(reversed(bot)))
    bm.faces.new(top)
    for j in range(4):
        jj = (j + 1) % 4
        bm.faces.new((bot[j], bot[jj], top[jj], top[j]))


def bench(stone, cushion, cx, cy, yaw):
    """A stone garden bench facing yaw (0: Blender +Y): a slab on two blocks,
    a kilim cushion along it. Rev 4 (your walk): in place of the wood chairs.
    No collision: you sit or brush past, as with the plants."""
    for su in (-0.42, 0.42):
        box_at(stone, cx, cy, yaw, su - 0.12, su + 0.12, -0.17, 0.17, 0.0, 0.36)
    box_at(stone, cx, cy, yaw, -0.62, 0.62, -0.22, 0.22, 0.36, 0.46)
    box_at(cushion, cx, cy, yaw, -0.55, 0.55, -0.18, 0.18, 0.46, 0.51)


def cone_garden(R0):
    """Rev 2 (your walk of step 6): one full ring of garden round the pool,
    level with the floor (no kerbs, no small pools), lush: ferns, grasses,
    flowers, moss, trees and glowing mushrooms, stepping stones in from the
    walk on the entry's line and the far side, and three clearings with garden
    chairs and a low table."""
    def build(r):
        name = "cone_garden%d" % round(R0 * 10)
        rng = random.Random(int(R0) * 17)
        r_in, r_out = CURB + 0.35, R0 - WALKWAY
        soil, stones, wood, cushion = (bmesh.new() for _ in range(4))
        fern_bm, flower_bm, moss_bm, grass_bm, bark, leaves = (bmesh.new() for _ in range(6))
        caps, gills, stalks = bmesh.new(), bmesh.new(), bmesh.new()
        uvs = [b.loops.layers.uv.new("UVMap") for b in (fern_bm, flower_bm, moss_bm, grass_bm, leaves)]
        glow = bmesh.new()
        # The bed: a flat ring of soil just over the floor, its outer edge ragged.
        segs = 72
        inner, outer = [], []
        for i in range(segs):
            t = 2 * math.pi * i / segs
            ro = r_out + 0.25 * math.sin(3 * t + 1.0) + rng.uniform(-0.12, 0.12)
            inner.append(soil.verts.new((*polar(r_in, t), 0.012)))
            outer.append(soil.verts.new((*polar(ro, t), 0.012)))
        for i in range(segs):
            j = (i + 1) % segs
            soil.faces.new((inner[i], outer[i], outer[j], inner[j]))
        # Trails: stepping stones in on the entry's line (angle 0) and opposite.
        trails = [0.0, math.pi]
        clearings = [(math.pi * 0.55, (r_in + r_out) / 2 + 0.3), (math.pi * 1.25, (r_in + r_out) / 2 + 0.2),
                     (math.pi * 1.8, (r_in + r_out) / 2 + 0.4)]
        for t in trails:
            rr = r_out + 0.2
            while rr > r_in + 0.1:
                (x, y) = polar(rr, t + rng.uniform(-0.03, 0.03))
                box_at(stones, x, y, t + rng.uniform(-0.25, 0.25), -0.3, 0.3, -0.22, 0.22, 0.0, 0.03)
                rr -= 0.62
        for (t, rc) in clearings:
            (cx, cy) = polar(rc, t)
            for k in range(9):          # a ring of flags round a centre stone
                a = 2 * math.pi * k / 9
                box_at(stones, cx + 0.75 * math.cos(a), cy + 0.75 * math.sin(a), a, -0.24, 0.24, -0.2, 0.2, 0.0, 0.03)
            ring(stones, 0.02, 0.45, cx, cy, 0.0, 0.03, segs=10)
            # Two stone benches facing across a low table, set tangentially.
            for side in (-1, 1):
                (x, y) = polar(rc, t + side * 0.7 / rc)
                bench(stones, cushion, x, y, t + (math.pi / 2 if side < 0 else -math.pi / 2))
            box_at(wood, cx, cy, t, -0.32, 0.32, -0.25, 0.25, 0.36, 0.4)
            for su in (-0.27, 0.27):
                for sv in (-0.2, 0.2):
                    box_at(wood, cx, cy, t, su - 0.03, su + 0.03, sv - 0.03, sv + 0.03, 0.0, 0.36)
            mushroom(glow, gills, stalks, cx, cy, 0.4, 0.14)          # a glowing cap on the table, like a lamp

        def clear(x, y, pad):
            rr = math.hypot(x, y)
            if rr < r_in + 0.15 or rr > r_out - 0.05:
                return False
            t = math.atan2(x, -y) % (2 * math.pi)
            for tt in trails:
                d = abs((t - tt + math.pi) % (2 * math.pi) - math.pi) * rr
                if d < 0.4 + pad:
                    return False
            for (tc, rc) in clearings:
                (cx, cy) = polar(rc, tc)
                if math.hypot(x - cx, y - cy) < 1.15 + pad:
                    return False
            return True

        def spot(pad=0.0):
            for _ in range(40):
                rr = math.sqrt(rng.uniform(r_in ** 2, r_out ** 2))
                (x, y) = polar(rr, rng.uniform(0, 2 * math.pi))
                if clear(x, y, pad):
                    return (x, y)
            return None

        area = math.pi * (r_out ** 2 - r_in ** 2)
        for _ in range(int(area * 1.5)):
            p = spot()
            if p:
                fern(fern_bm, uvs[0], rng, p[0], p[1], 0.0, rng.uniform(0.9, 1.7))
        for _ in range(int(area * 0.5)):
            p = spot()
            if p:
                flowers(flower_bm, uvs[1], rng, p[0], p[1], 0.0, rng.uniform(0.8, 1.3))
        for _ in range(int(area * 0.6)):
            p = spot()
            if p:
                grass(grass_bm, uvs[3], rng, p[0], p[1], rng.uniform(0.9, 1.5))
        for _ in range(int(area * 1.0)):
            p = spot(-0.3)
            if p:
                moss_patch(moss_bm, uvs[2], rng, p[0], p[1], rng.uniform(0.8, 1.3))
        for k in range(int(area / 11)):
            p = spot(0.4)
            if p:
                tree(bark, leaves, uvs[4], rng, p[0], p[1], 0.0, rng.uniform(2.6, 3.8))
        for k in range(int(area / 7)):
            p = spot(0.1)
            if p:
                mushroom_cluster(caps, gills, stalks, rng, p[0], p[1], rng.uniform(0.22, 0.5), rng.randint(4, 8), 0.4, glow)
        # A soft green glow from the mushrooms, three about the ring.
        for k in range(3):
            (x, y) = polar((r_in + r_out) / 2, 2 * math.pi * (k + 0.35) / 3)
            marker("LIGHT_fungus__garden%d" % k, r, (x, y, 0.6), {"range": 4.0, "energy": 0.28, "color": GREEN_GOLD})
        mesh_object(name + "__soil", soil, ["persian_soil"], r)
        mesh_object(name + "__stones", stones, ["arch_stone"], r)
        mesh_object(name + "__wood", wood, ["persian_wood"], r)
        mesh_object(name + "__cushion", cushion, ["cushion_kilim"], r)
        mesh_object(name + "__fern", fern_bm, ["fern"], r, recalc=False)
        mesh_object(name + "__flowers", flower_bm, ["persian_flowers"], r, recalc=False)
        mesh_object(name + "__moss", moss_bm, ["fern"], r, recalc=False)
        mesh_object(name + "__grass", grass_bm, ["fern"], r, recalc=False)
        mesh_object(name + "__bark", bark, ["bark"], r)
        mesh_object(name + "__leaves", leaves, ["tree_leaf"], r, recalc=False)
        mesh_object(name + "__caps", caps, ["persian_fungus_cap"], r)
        mesh_object(name + "__gills", gills, ["emit_gills_bright"], r)
        mesh_object(name + "__glowcaps", glow, ["emit_fungus_bright"], r)
        mesh_object(name + "__stalks", stalks, ["persian_fungus_stalk"], r)
    return build


# --- under the first storey's stair (your walk of step 6): the floor along the
# wall, under the stair's overhang. Origin at the wall's foot, the shaft at
# Blender +Y, 2.8 m along the wall (x). The wall curves toward +Y at the ends
# (x^2 / 2R) and leans over (0.375 m per metre up), so things stand clear of it.

def wall_y(x, z=0.0):
    return 0.05 + x * x / 20.0 + 0.375 * z


def cone_mushbed(seed, lit):
    def build(r):
        name = r.name[2:]
        rng = random.Random(seed)
        soil, log, caps, gills, stalks, glow = (bmesh.new() for _ in range(6))
        fern_bm, moss_bm = bmesh.new(), bmesh.new()
        uvs = [b.loops.layers.uv.new("UVMap") for b in (fern_bm, moss_bm)]
        n = 16
        back = [soil.verts.new((-1.4 + 2.8 * i / n, wall_y(-1.4 + 2.8 * i / n), 0.012)) for i in range(n + 1)]
        front = [soil.verts.new((-1.4 + 2.8 * i / n, 1.25 + 0.12 * math.sin(i * 1.7 + seed) - 0.3 * ((i / n - 0.5) * 2) ** 2, 0.012))
                 for i in range(n + 1)]
        for i in range(n):
            soil.faces.new((back[i], front[i], front[i + 1], back[i + 1]))
        # A rotting log along the bed, shelf fungi on it.
        lx = rng.uniform(-0.3, 0.3)
        add_tube(log, [(lx - 1.0, 0.75, 0.13), (lx, 0.8, 0.15), (lx + 0.9, 0.72, 0.12)], [0.13, 0.15, 0.12], segs=7)
        for k in range(6):
            x = lx - 0.8 + 0.3 * k
            mushroom(caps, gills, stalks, x, 0.62 + rng.uniform(-0.04, 0.04), 0.12 + rng.uniform(0, 0.1), 0.09, (0.0, -0.5))
        # Mushrooms: two or three tall ones well out from the wall, the rest
        # smaller and in clumps.
        for k in range(rng.randint(2, 3)):     # tall ones well out: the wall leans over the bed
            x = rng.uniform(-1.0, 1.0)
            mushroom(caps, gills, stalks, x, rng.uniform(1.1, 1.2), 0.0, rng.uniform(0.55, 0.8),
                     (rng.uniform(-0.05, 0.05), rng.uniform(0.02, 0.08)))
        for k in range(5):
            x = -1.15 + 2.3 * (k + rng.uniform(0.2, 0.8)) / 5
            y = rng.uniform(0.45, 1.05)
            mushroom_cluster(caps, gills, stalks, rng, x, max(y, wall_y(x, 0.5) + 0.2), rng.uniform(0.2, 0.4), 6, 0.3, glow)
        for k in range(8):
            x = rng.uniform(-1.3, 1.3)
            fern(fern_bm, uvs[0], rng, x, rng.uniform(1.0, 1.25), 0.0, rng.uniform(0.7, 1.1))
        for k in range(10):
            x = rng.uniform(-1.3, 1.3)
            moss_patch(moss_bm, uvs[1], rng, x, rng.uniform(wall_y(x) + 0.2, 1.2), rng.uniform(0.7, 1.1))
        if lit:
            marker("LIGHT_fungus__bed", r, (0.0, 0.9, 0.7), {"range": 3.5, "energy": 0.3, "color": GREEN_GOLD})
        mesh_object(name + "__soil", soil, ["persian_soil"], r)
        mesh_object(name + "__log", log, ["bark"], r)
        mesh_object(name + "__caps", caps, ["persian_fungus_cap"], r)
        mesh_object(name + "__gills", gills, ["emit_gills_bright"], r)
        mesh_object(name + "__glowcaps", glow, ["emit_fungus_bright"], r)
        mesh_object(name + "__stalks", stalks, ["persian_fungus_stalk"], r)
        mesh_object(name + "__fern", fern_bm, ["fern"], r, recalc=False)
        mesh_object(name + "__moss", moss_bm, ["fern"], r, recalc=False)
    return build


def cone_nook(r):
    """A sitting nook under the stair: a kilim rug, a floor mattress with back
    cushions against the wall, a low table with a glowing mushroom on it, ferns
    in pots at the ends."""
    name = "cone_nook"
    rng = random.Random(91)
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    long_m, short_m = 80 / 32.0, 56 / 32.0
    x0, y0 = -long_m / 2, 0.3
    vs = [bm.verts.new(p) for p in ((x0, y0, 0.012), (x0 + long_m, y0, 0.012), (x0 + long_m, y0 + short_m, 0.012), (x0, y0 + short_m, 0.012))]
    f = bm.faces.new(vs)
    for loop in f.loops:
        loop[uv].uv = ((loop.vert.co.x - x0) / long_m, (loop.vert.co.y - y0) / short_m)
    mesh_object(name + "__rug", bm, ["rug_kilim_small"], r, recalc=False)
    bm = bmesh.new()
    add_box(bm, -0.85, 0.85, 0.42, 1.0, 0.012, 0.08)
    add_box(bm, -0.82, 0.82, 0.45, 0.97, 0.08, 0.11)
    mesh_object(name + "__toshak", bm, ["cushion_termeh"], r)
    bm = bmesh.new()
    for x in (-0.45, 0.4):
        add_obox(bm, (x, 0.55, 0.34), (0.62, 0.16, 0.46), (math.radians(-14), 0.0, 0.0))
    mesh_object(name + "__poshti", bm, ["cushion_ikat"], r)
    wood = bmesh.new()
    box_at(wood, 0.0, 1.55, 0.0, -0.45, 0.45, -0.3, 0.3, 0.3, 0.34)
    for su in (-0.4, 0.4):
        for sv in (-0.25, 0.25):
            box_at(wood, 0.0, 1.55, 0.0, su - 0.04, su + 0.04, sv - 0.04, sv + 0.04, 0.0, 0.3)
    mesh_object(name + "__table", wood, ["persian_wood"], r)
    caps, gills, stalks, glow = bmesh.new(), bmesh.new(), bmesh.new(), bmesh.new()
    mushroom_cluster(caps, gills, stalks, rng, 0.15, 1.55, 0.18, 3, 0.1, glow)
    for x in (-1.15, 1.15):
        mushroom_cluster(caps, gills, stalks, rng, x, 0.85, 0.35, 5, 0.2, glow)
    mesh_object(name + "__glowcaps", glow, ["emit_fungus_bright"], r)
    mesh_object(name + "__caps", caps, ["persian_fungus_cap"], r)
    mesh_object(name + "__gills", gills, ["emit_gills_bright"], r)
    mesh_object(name + "__stalks", stalks, ["persian_fungus_stalk"], r)
    pots, f_bm = bmesh.new(), bmesh.new()
    fuv = f_bm.loops.layers.uv.new("UVMap")
    for x in (-1.3, 1.3):
        pot(pots, x, 1.35, 0.0, 0.4, 0.2)
        fern(f_bm, fuv, rng, x, 1.35, 0.4, 1.2)
    mesh_object(name + "__pots", pots, ["earthenware"], r)
    mesh_object(name + "__fern", f_bm, ["fern"], r, recalc=False)
    marker("LIGHT_fungus__nook", r, (0.0, 1.2, 0.8), {"range": 3.0, "energy": 0.25, "color": GREEN_GOLD})


def cone_vine(count, lo, hi, seed):
    def build(r):
        name = r.name[2:]
        rng = random.Random(seed)
        stems, leaves = bmesh.new(), bmesh.new()
        uv = leaves.loops.layers.uv.new("UVMap")
        # Over the parapet's top from its outer side, then down its inner face
        # and on past the ledge's underside.
        for i in range(count):
            x = -0.6 + 1.2 * (i + 0.5) / count + rng.uniform(-0.1, 0.1)
            add_tube(stems, [(x, -0.15, 0.03), (x, 0.0, 0.03), (x, 0.04, -0.1)], 0.014, segs=4)
            for k in range(3):
                add_card(leaves, uv, (x + rng.uniform(-0.08, 0.08), -0.15 + 0.07 * k, 0.02), 0.15, 0.15,
                         rng.uniform(0, math.pi), math.radians(85))
            hang(stems, leaves, uv, rng, (x, 0.05, -0.1), rng.uniform(lo, hi))
        mesh_object(name + "__stems", stems, ["vine"], r)
        mesh_object(name + "__leaves", leaves, ["ivy_leaf"], r, recalc=False)
    return build


def cone_vines_oculus(r):
    name = "cone_vines_oculus"
    rng = random.Random(61)
    stems, leaves = bmesh.new(), bmesh.new()
    uv = leaves.loops.layers.uv.new("UVMap")
    for i in range(28):
        a = 2 * math.pi * i / 28 + rng.uniform(-0.05, 0.05)
        (x, y) = polar(CONE_RT + 0.08, a)
        out = (-math.sin(a), math.cos(a))          # toward the axis
        hang(stems, leaves, uv, rng, (x, y, -0.05), rng.uniform(1.0, 4.5) if i % 3 else rng.uniform(0.5, 1.5), out)
    mesh_object(name + "__stems", stems, ["vine"], r)
    mesh_object(name + "__leaves", leaves, ["ivy_leaf"], r, recalc=False)


def cone_glowvines(r):
    """Glowing plants for the stair in place of its lanterns (your walk of step
    6): strands hanging from the stair's ceiling (2.6 m over the tread) with
    glowing pods along them, ivy among them, and a few glowing caps at the foot
    of the cut's back wall. Origin as cone_lantern's: on the tread, 0.5 m
    out from the back wall (Blender -Y), the shaft at +Y. Kept over 2 m up
    where you walk."""
    name = "cone_glowvines"
    rng = random.Random(97)
    stems, pods, leaves = bmesh.new(), bmesh.new(), bmesh.new()
    uv = leaves.loops.layers.uv.new("UVMap")
    for i in range(7):
        x = -0.65 + 1.3 * (i + rng.uniform(0.2, 0.8)) / 7
        y = rng.uniform(-0.45, 0.25)
        length = rng.uniform(0.35, 0.6) if -0.2 < y < 0.4 else rng.uniform(0.5, 1.4)
        n = max(3, int(length / 0.12))
        path = [(x + 0.03 * math.sin(k * 1.4 + i), y, 2.62 - length * k / n) for k in range(n + 1)]
        add_tube(stems, path, [0.02 * (1.0 - 0.5 * k / n) for k in range(n + 1)], segs=4)
        for k in range(1, n + 1):
            (px, py, pz) = path[k]
            if rng.random() < 0.6:
                R = rng.uniform(0.03, 0.055) * (1.4 if k == n else 1.0)
                add_lathe(pods, [(0.0, pz - R), (R, pz - R * 0.2), (R * 0.8, pz + R * 0.5), (0.0, pz + R)], px, py, segs=6)
            if rng.random() < 0.5:
                add_card(leaves, uv, (px, py, pz - 0.1), 0.14, 0.14, rng.uniform(0, math.pi), math.radians(rng.uniform(-25, 25)))
    caps, gills, stalks, glow = bmesh.new(), bmesh.new(), bmesh.new(), bmesh.new()
    for x in (-0.35, 0.3):
        mushroom_cluster(caps, gills, stalks, rng, x, -0.4, 0.2, 4, 0.12, glow)
    mesh_object(name + "__stems", stems, ["vine"], r)
    mesh_object(name + "__pods", pods, ["emit_fungus_bright"], r)
    mesh_object(name + "__leaves", leaves, ["ivy_leaf"], r, recalc=False)
    mesh_object(name + "__caps", caps, ["persian_fungus_cap"], r)
    mesh_object(name + "__gills", gills, ["emit_gills_bright"], r)
    mesh_object(name + "__stalks", stalks, ["persian_fungus_stalk"], r)
    mesh_object(name + "__glowcaps", glow, ["emit_fungus_bright"], r)
    marker("LIGHT_fungus__stair", r, (0.0, 0.0, 2.1), {"range": 4.5, "energy": 0.45, "color": GREEN_GOLD})


# --- shelf niches (a recess's frame: drawn with the back at y -0.4, the room at
# +Y, moved 0.1 m toward the room by to_recess as kit_add_niche.py does) --------

def to_recess(r):
    for o in r.children:
        if o.type == "MESH":
            for v in o.data.vertices:
                v.co.x = min(max(v.co.x, -1.48), 1.48)     # inside the niche's 3 m
                v.co.y = max(v.co.y, -0.399)
                v.co.z = max(v.co.z, 0.0)
                if v.co.z > 0.6:
                    v.co.y = min(v.co.y, 0.199)
                v.co.y += 0.1
        else:
            o.location.y += 0.1


def pot(bm, x, y, z, h, rad):
    add_lathe(bm, [(0.0, z), (rad * 0.6, z), (rad, z + h * 0.6), (rad * 0.85, z + h), (rad * 0.95, z + h * 1.05), (0.0, z + h * 1.02)],
              cx=x, cy=y, segs=10)


def niche_planter(r):
    name = "niche_planter"
    rng = random.Random(71)
    bm = bmesh.new()
    add_box(bm, -1.35, 1.35, -0.4, 0.1, 0.0, 0.5)
    mesh_object(name + "__trough-col", bm, ["arch_stone"], r)
    bm = bmesh.new()
    add_box(bm, -1.28, 1.28, -0.34, 0.04, 0.5, 0.52)
    mesh_object(name + "__soil", bm, ["persian_soil"], r)
    f, fl, ivy, stems = bmesh.new(), bmesh.new(), bmesh.new(), bmesh.new()
    uvs = [b.loops.layers.uv.new("UVMap") for b in (f, fl, ivy)]
    for i in range(7):
        fern(f, uvs[0], rng, -1.1 + i * 0.37, -0.15, 0.52, rng.uniform(1.0, 1.5))
    for i in range(6):
        x = -1.2 + i * 0.48 + rng.uniform(-0.05, 0.05)
        hang(stems, ivy, uvs[2], rng, (x, 0.12, 0.52), rng.uniform(0.25, 0.5))
    bm = bmesh.new()
    for x in (-1.15, 1.15):
        pot(bm, x, 0.05, 0.52, 0.32, 0.14)
        flowers(fl, uvs[1], rng, x, 0.05, 0.82, 0.8)
    mesh_object(name + "__pots", bm, ["earthenware"], r)
    mesh_object(name + "__fern", f, ["fern"], r, recalc=False)
    mesh_object(name + "__flowers", fl, ["persian_flowers"], r, recalc=False)
    mesh_object(name + "__stems", stems, ["vine"], r)
    mesh_object(name + "__ivy", ivy, ["ivy_leaf"], r, recalc=False)
    to_recess(r)


def niche_urn(r):
    name = "niche_urn"
    rng = random.Random(73)
    bm = bmesh.new()
    add_box(bm, -0.45, 0.45, -0.4, 0.05, 0.0, 0.4)
    mesh_object(name + "__plinth-col", bm, ["arch_stone"], r)
    bm = bmesh.new()
    add_lathe(bm, [(0.0, 0.4), (0.16, 0.4), (0.3, 0.7), (0.32, 0.95), (0.2, 1.25), (0.15, 1.35), (0.22, 1.45), (0.0, 1.43)],
              cx=0.0, cy=-0.16, segs=14)
    mesh_object(name + "__urn", bm, ["tile"], r)
    f, fl, ivy, stems = bmesh.new(), bmesh.new(), bmesh.new(), bmesh.new()
    uvs = [b.loops.layers.uv.new("UVMap") for b in (f, fl, ivy)]
    flowers(fl, uvs[1], rng, 0.0, -0.16, 1.42, 1.4)
    flowers(fl, uvs[1], rng, 0.05, -0.12, 1.42, 1.1)
    for x in (-1.0, 1.0):
        fern(f, uvs[0], rng, x, -0.1, 0.0, 1.3)
    for i in range(7):     # ivy from the niche's head (the arch springs at 1.9 m, its crown ~2.9 m)
        x = -0.9 + i * 0.3
        top = 2.75 - 0.5 * (abs(x) / 0.9) ** 2
        hang(stems, ivy, uvs[2], rng, (x, -0.3, top), rng.uniform(0.4, 1.1))
    mesh_object(name + "__fern", f, ["fern"], r, recalc=False)
    mesh_object(name + "__flowers", fl, ["persian_flowers"], r, recalc=False)
    mesh_object(name + "__stems", stems, ["vine"], r)
    mesh_object(name + "__ivy", ivy, ["ivy_leaf"], r, recalc=False)
    to_recess(r)


# --- the stair wall (rev 7 chunks, your walk of step 6): bookcases let into
# the back wall on the reading storeys, taghcheh higher up. Frame: the socket
# at the slot's back, the shaft (the stair) at Blender +Y; kit_add_r03.py
# CASE_* and CUBBY_D give the sizes. -----------------------------------------

CASE_HW, CASE_TOP, CASE_DEP = 0.8, 2.0, 0.45
SHELF_TOPS = (0.04, 0.49, 0.94, 1.39)      # board tops (ShelfFill shelf_levels)


def case_boards(r, name):
    """Shelf boards in a 1.6 x 2 m slot, 0.45 deep, and a stone surround on
    the wall face round the opening."""
    bm = bmesh.new()
    for top in SHELF_TOPS:
        add_box(bm, -CASE_HW + 0.01, CASE_HW - 0.01, 0.01, CASE_DEP - 0.01, top - 0.04, top)
    add_box(bm, -CASE_HW + 0.01, CASE_HW - 0.01, 0.0, 0.03, 0.0, CASE_TOP)        # back boards
    mesh_object(name + "__boards", bm, ["persian_wood"], r)
    bm = bmesh.new()
    add_box(bm, -CASE_HW - 0.12, -CASE_HW, CASE_DEP - 0.01, CASE_DEP + 0.04, -0.04, CASE_TOP + 0.04)   # jambs
    add_box(bm, CASE_HW, CASE_HW + 0.12, CASE_DEP - 0.01, CASE_DEP + 0.04, -0.04, CASE_TOP + 0.04)
    add_box(bm, -CASE_HW - 0.14, CASE_HW + 0.14, CASE_DEP - 0.01, CASE_DEP + 0.05, CASE_TOP, CASE_TOP + 0.14)   # lintel
    add_box(bm, -CASE_HW - 0.12, CASE_HW + 0.12, CASE_DEP - 0.01, CASE_DEP + 0.05, -0.06, 0.02)                 # sill
    mesh_object(name + "__frame", bm, ["arch_stone"], r)


def stair_case_boards(r):
    case_boards(r, "stair_case_boards")


def stair_case_plant(r):
    """The middle shelf given to a trough of ferns, ivy trailing over its edge."""
    name = "stair_case_plant"
    rng = random.Random(111)
    case_boards(r, name)
    bm = bmesh.new()
    add_box(bm, -0.7, 0.7, 0.06, 0.36, SHELF_TOPS[2], SHELF_TOPS[2] + 0.18)
    mesh_object(name + "__trough", bm, ["earthenware"], r)
    f, ivy, stems = bmesh.new(), bmesh.new(), bmesh.new()
    uvs = [b.loops.layers.uv.new("UVMap") for b in (f, ivy)]
    # Rev 2 (the route gate): smaller ferns, kept inside the case's width and depth.
    for i in range(4):
        fern(f, uvs[0], rng, -0.45 + 0.3 * i, 0.21, SHELF_TOPS[2] + 0.17, rng.uniform(0.38, 0.44))
    for i in range(6):
        hang(stems, ivy, uvs[1], rng, (-0.6 + 0.24 * i, 0.3, SHELF_TOPS[2] + 0.17), rng.uniform(0.25, 0.5))
    mesh_object(name + "__fern", f, ["fern"], r, recalc=False)
    mesh_object(name + "__stems", stems, ["vine"], r)
    mesh_object(name + "__ivy", ivy, ["ivy_leaf"], r, recalc=False)


def stair_case_deco(r):
    """The middle shelf: a glazed urn, a bowl, a small stack of books lying flat."""
    name = "stair_case_deco"
    case_boards(r, name)
    z = SHELF_TOPS[2]
    bm = bmesh.new()
    add_lathe(bm, [(0.0, z), (0.09, z), (0.17, z + 0.14), (0.16, z + 0.28), (0.08, z + 0.36), (0.1, z + 0.4), (0.0, z + 0.39)],
              cx=-0.42, cy=0.2, segs=12)
    add_lathe(bm, [(0.0, z), (0.07, z), (0.16, z + 0.07), (0.15, z + 0.08), (0.0, z + 0.03)], cx=0.1, cy=0.22, segs=12)
    mesh_object(name + "__glaze", bm, ["tile"], r)
    bm = bmesh.new()
    for i in range(4):
        add_obox(bm, (0.52, 0.2, z + 0.03 + 0.055 * i), (0.26 - 0.02 * i, 0.19, 0.05), (0.0, 0.0, 0.2 * (i % 2) - 0.1))
    mesh_object(name + "__books", bm, ["book_leather"], r)


def cubby_back(r, name, w=0.27, d=0.36):
    """A glazed tile plate on the taghcheh's floor. Rev 2 (your walk): the
    back is now the chunk's orosi glass, filling the whole arch."""
    bm = bmesh.new()
    add_box(bm, -w, w, 0.0, d, 0.0, 0.012)
    mesh_object(name + "__back", bm, ["tile"], r)


def cubby_tile(r):
    cubby_back(r, "cubby_tile")


def cubby_vase(r):
    name = "cubby_vase"
    rng = random.Random(121)
    cubby_back(r, name)
    bm = bmesh.new()
    add_lathe(bm, [(0.0, 0.0), (0.07, 0.0), (0.12, 0.12), (0.11, 0.24), (0.05, 0.32), (0.07, 0.36), (0.0, 0.35)],
              cx=0.0, cy=0.2, segs=12)
    mesh_object(name + "__vase", bm, ["tile"], r)
    fl = bmesh.new()
    uv = fl.loops.layers.uv.new("UVMap")
    flowers(fl, uv, rng, 0.0, 0.2, 0.34, 0.75)
    mesh_object(name + "__flowers", fl, ["persian_flowers"], r, recalc=False)


def cubby_fern(r):
    name = "cubby_fern"
    rng = random.Random(123)
    cubby_back(r, name)
    bm = bmesh.new()
    pot(bm, 0.0, 0.2, 0.0, 0.2, 0.12)
    mesh_object(name + "__pot", bm, ["earthenware"], r)
    f = bmesh.new()
    uvs = [f.loops.layers.uv.new("UVMap")]
    fern(f, uvs[0], rng, 0.0, 0.21, 0.2, 0.38)     # rev 3 (the route gate): inside the cubby
    for x in (-0.12, 0.1):
        fern(f, uvs[0], rng, x, 0.2, 0.2, 0.26)
    mesh_object(name + "__fern", f, ["fern"], r, recalc=False)


def cubby_glow(r):
    """A shallow bowl of glowing mushrooms: a small lamp of the garden's kind."""
    name = "cubby_glow"
    rng = random.Random(127)
    cubby_back(r, name)
    bm = bmesh.new()
    add_lathe(bm, [(0.0, 0.0), (0.1, 0.0), (0.2, 0.08), (0.19, 0.1), (0.0, 0.05)], cx=0.0, cy=0.2, segs=12)
    mesh_object(name + "__bowl", bm, ["earthenware"], r)
    caps, gills, stalks, glow = bmesh.new(), bmesh.new(), bmesh.new(), bmesh.new()
    mushroom_cluster(caps, gills, stalks, rng, 0.0, 0.2, 0.2, 6, 0.12, glow)
    for b in (caps, gills, stalks, glow):
        for v in b.verts:
            v.co.z += 0.07
    mesh_object(name + "__caps", caps, ["persian_fungus_cap"], r)
    mesh_object(name + "__gills", gills, ["emit_gills_bright"], r)
    mesh_object(name + "__stalks", stalks, ["persian_fungus_stalk"], r)
    mesh_object(name + "__glowcaps", glow, ["emit_fungus_bright"], r)


def cone_rail_planter(r):
    """A stone trough on the stair's parapet between its columns: ferns and
    flowers, ivy trailing over the shaft side (+Y). Origin on the parapet's
    top, on its middle line."""
    name = "cone_rail_planter"
    rng = random.Random(131)
    bm = bmesh.new()
    add_box(bm, -0.55, 0.55, -0.14, 0.14, 0.0, 0.22)
    mesh_object(name + "__trough", bm, ["arch_stone"], r)
    bm = bmesh.new()
    add_box(bm, -0.5, 0.5, -0.1, 0.1, 0.22, 0.23)
    mesh_object(name + "__soil", bm, ["persian_soil"], r)
    f, fl, ivy, stems = bmesh.new(), bmesh.new(), bmesh.new(), bmesh.new()
    uvs = [b.loops.layers.uv.new("UVMap") for b in (f, fl, ivy)]
    for i in range(4):
        fern(f, uvs[0], rng, -0.38 + 0.25 * i, 0.0, 0.22, rng.uniform(0.7, 1.0))
    for x in (-0.25, 0.3):
        flowers(fl, uvs[1], rng, x, 0.0, 0.22, 0.7)
    for i in range(5):
        hang(stems, ivy, uvs[2], rng, (-0.45 + 0.22 * i, 0.16, 0.2), rng.uniform(0.4, 1.0))
    mesh_object(name + "__fern", f, ["fern"], r, recalc=False)
    mesh_object(name + "__flowers", fl, ["persian_flowers"], r, recalc=False)
    mesh_object(name + "__stems", stems, ["vine"], r)
    mesh_object(name + "__ivy", ivy, ["ivy_leaf"], r, recalc=False)


MODULES_STAIR_WALL = [
    ("M_stair_case_boards", props("wood,shelf,book,lightwell", "dressing"), stair_case_boards),
    ("M_stair_case_plant", dict(props("wood,shelf,plant,lightwell", "dressing"), kit_rev=2), stair_case_plant),
    ("M_stair_case_deco", props("wood,shelf,tile,lightwell", "dressing"), stair_case_deco),
    ("M_cubby_tile", dict(props("tile,niche,lightwell", "dressing"), kit_rev=2), cubby_tile),
    ("M_cubby_vase", dict(props("tile,plant,niche,lightwell", "dressing"), kit_rev=2), cubby_vase),
    ("M_cubby_fern", dict(props("plant,niche,lightwell", "dressing"), kit_rev=3), cubby_fern),
    ("M_cubby_glow", dict(props("fungus,niche,lightwell", "dressing"), kit_rev=2), cubby_glow),
    ("M_cone_rail_planter", props("stone,plant,lightwell"), cone_rail_planter),
]


MODULES = [
    ("M_cone_garden100", dict(props("stone,garden,plant,lightwell"), kit_rev=4), cone_garden(10.0)),
    ("M_cone_garden120", dict(props("stone,garden,plant,lightwell"), kit_rev=4), cone_garden(12.0)),
    ("M_cone_vine_a", props("plant,vine,lightwell"), cone_vine(3, 1.2, 2.4, 81)),
    ("M_cone_vine_b", props("plant,vine,lightwell"), cone_vine(5, 1.8, 3.6, 83)),
    ("M_cone_vines_oculus", props("plant,vine,lightwell"), cone_vines_oculus),
    ("M_niche_planter", dict(props("stone,plant,niche,lightwell", "dressing"), kit_rev=2), niche_planter),
    ("M_niche_urn", dict(props("tile,plant,niche,lightwell", "dressing"), kit_rev=2), niche_urn),
    ("M_cone_mushbed_a", dict(props("plant,fungus,light,lightwell"), kit_rev=3), cone_mushbed(101, True)),
    ("M_cone_mushbed_b", dict(props("plant,fungus,lightwell"), kit_rev=3), cone_mushbed(103, False)),
    ("M_cone_nook", dict(props("cloth,furniture,seat,fungus,light,lightwell"), kit_rev=3), cone_nook),
    ("M_cone_glowvines", props("plant,fungus,light,lightwell"), cone_glowvines),
]
MODULES += MODULES_STAIR_WALL
REBUILD = [("M_niche_planter", 2), ("M_niche_urn", 2),      # rev 2: kept inside the niche's width
           ("M_cone_garden100", 4), ("M_cone_garden120", 4),   # rev 2: a full, level ring, no small pools (your walk); rev 3: glowing small caps, dimmer lights; rev 4: stone benches, green-gold light
           ("M_cone_mushbed_a", 3), ("M_cone_mushbed_b", 3), ("M_cone_nook", 3),   # rev 3: green-gold light
           ("M_cubby_tile", 2), ("M_cubby_vase", 2), ("M_cubby_fern", 3), ("M_cubby_glow", 2),   # rev 2: a tile floor plate; the glass back is the chunk's (your walk); fern rev 3: kept inside the cubby
           ("M_stair_case_plant", 2)]   # rev 2: ferns kept inside the case


def main():
    bpy.ops.wm.open_mainfile(filepath=BLEND)
    added = []
    for i, (name, p, build) in enumerate(MODULES):
        if bpy.data.objects.get(name) is None:
            build(module(name, (i * 30.0, ROW_Y, 0.0), p))
            added.append(name)
    added += ["%s (rebuilt rev %d)" % (n, v) for (n, v) in REBUILD if rebuild(n, v, MODULES)]
    if not added:
        print("kit_add_lightwell: all modules already present; nothing to do.")
        return
    bpy.ops.wm.save_as_mainfile(filepath=BLEND)
    print("kit_add_lightwell: added %s" % ", ".join(added))


main()

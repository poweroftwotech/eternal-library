"""Seeds the R20 Lake Landing modules into art_src/kit/kit_lake.blend
(phase 18, docs/environment/phase-18-approval.md).

  blender --background --factory-startup --python tools/kit_add_r20.py

Creates kit_lake.blend if it doesn't exist, then adds only the modules that are
not in it yet (hand edits are kept). Then run tools/export_kit.bat kit_lake.blend.

The lake is a place of its own (tools/build_lake.gd -> rooms/lake/landing.tscn).
Blender X = Godot X, Blender Y = Godot -Z, Blender Z = Godot Y. The water is at
Godot Y -1.2 (WATER), the ferry's stages at -0.9 (STAGE).

Modules placed at the Godot origin (their coordinates are the lake's own):
  lk_cavern      the cavern: an elliptic ring of rough rock from below the
                 water to about 22 m, a roof rising to about 36 m with
                 stalactites, recessed where the far landings stand
                 (LANDINGS); a crack of daylight over the Gardens landing.
  lk_bed         the lake bed (collision), shallower in the harbour.
  lk_headland    the rock spur west of the boathouses (X -80..-18).
Modules placed by the builder:
  lk_back_wall   rock face behind the quay (110 m wide) with the passage
                 mouth's 4 x 4 m hole in the middle (bh_cave_mouth fits it).
  lk_quay        16 x 9 m stone quay with water steps in its second bay.
  lk_shelf       the wading shelf in front of the steps (tag water: you wade).
  lk_pier_4m     a timber pier bay, 2 m wide, on piles.
  lk_pier_head   4 x 5 m: deck, steps down, the ferry's stage.
  lk_boardwalk_4m  timber walk along the back wall to the boathouses.
  lk_boathouse   4 x 8 m shed on piles over the water: a walkway, a slip,
                 a window and a hanging lamp (LIGHT_lake_lamp).
  lk_lantern_post  a post with an arm and a hanging oil lantern (LIGHT_lake_lantern).
  lk_bell        a post with a bell, to call the ferry.
  lk_boat        a rowing boat (origin at the waterline).
  lk_ferry       the ferry: a railed barge with two lanterns and an awning.
  lk_ferryman    a robed figure with a pole.
  lk_nets, lk_traps, lk_crates   the fisher's things.
  lk_landing_quay  a far landing's quay: deck, steps, stage (10 x 6 m).
  lk_rubble      fallen stones for the Forgotten City's landing.
"""
import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector, noise
from mathutils.bvhtree import BVHTree

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kit_blender import (add_box, add_lathe, add_obox, add_plan_prism, add_prism,  # noqa: E402
                         add_tube, marker, mesh_object, module, rebuild)

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BLEND = os.path.join(ROOT, "art_src", "kit", "kit_lake.blend")
ROW_Y = -400.0
ROCK = "cave_rock"
STONE = "persian_stone"
PAVE = "paving"
WOOD = "wood"
PWOOD = "persian_wood"
IRON = "iron"
WATER = -1.2
STAGE = -0.9
BED = -6.0
# The cavern (Blender coords): an ellipse round (CX, CY).
CX, CY = 0.0, 75.0
RX, RY = 85.0, 80.0
WALL_TOP = 22.0
ROOF_TOP = 36.0
WALL_FOOT = -10.0
# Far landings: (name, ellipse angle psi in degrees (Blender), half-width of the
# facade). The same table is in scripts/world/lake_layout.gd.
LANDINGS = [("mahaleh", 60.0, 15.0), ("gardens", 125.0, 11.0), ("forgotten", 15.0, 11.0), ("dark", 160.0, 8.0)]
RECESS = 3.0


def props(shape, size, edge, tags, family="walls", weight=1.0):
    return {"kit_shape": shape, "kit_family": family, "size_cells": size,
            "edge": edge, "tags": tags, "weight": weight}


def solid(name, root, mats, build, recalc=True):
    bm = bmesh.new()
    build(bm)
    return mesh_object(name, bm, mats, root, recalc)


def ramp(r, name, x0, x1, top, thick=0.2):
    """A hidden walkable slab under a flight of steps (the player has no
    step-up): `top` is its upper edge as (Y, Z) points, run through the middle
    of the treads; extruded along X. Collision only."""
    outline = list(top) + [(y, z - thick) for (y, z) in reversed(top)]

    def build(bm):
        a = [bm.verts.new((x0, y, z)) for (y, z) in outline]
        b = [bm.verts.new((x1, y, z)) for (y, z) in outline]
        bm.faces.new(list(reversed(a)))
        bm.faces.new(b)
        n = len(outline)
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new((a[i], b[i], b[j], a[j]))
    solid(name + "__ramp-colonly", r, [STONE], build)


def moved(bm, build, m):
    before = set(bm.verts)
    build(bm)
    bmesh.ops.transform(bm, matrix=m, verts=[v for v in bm.verts if v not in before])


def rough(p, scale=0.55, seed=0.0):
    return noise.noise((p[0] * scale, p[1] * scale, p[2] * scale + seed)) * 0.75 \
        + noise.noise((p[0] * 1.7 * scale, p[1] * 1.7 * scale, p[2] * 1.7 * scale + seed + 5.0)) * 0.25


def smooth01(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3.0 - 2.0 * t)


# ---------------------------------------------------------------- the cavern

def ellipse(psi):
    a = math.radians(psi)
    return Vector((CX + RX * math.cos(a), CY + RY * math.sin(a), 0.0))


def ellipse_normal(psi):
    """Outward normal of the ellipse at psi (plan)."""
    a = math.radians(psi)
    n = Vector((math.cos(a) / RX, math.sin(a) / RY, 0.0))
    return n.normalized()


def landing_frame(psi):
    """(point on the ellipse, outward normal, tangent) for a landing."""
    p = ellipse(psi)
    n = ellipse_normal(psi)
    t = Vector((-n.y, n.x, 0.0))
    return p, n, t


# Landings whose door is in a natural grotto cut into the wall rather than
# behind a built facade (walk 1: "passages can go into cavern-like
# structures"): name -> the grotto's floor height. Same table in lake_layout.gd.
GROTTOS = {"gardens": 0.0, "forgotten": 0.0, "dark": -1.5}
GROTTO_BACK = 12.0      # the grotto's back wall (the door) behind the facade line
GROTTO_HALF = 2.4       # half-width of its flat back
GROTTO_MOUTH = 7.0      # half-width where the inlet meets the cavern wall
GROTTO_HIGH = 4.8       # its roof over the door, above its floor
SEG = 540


def landing_local(q, psi):
    """(along, out) of plan point q in the frame of the landing at psi."""
    p, n, t = landing_frame(psi)
    d = q - p
    d.z = 0.0
    return d.dot(t), d.dot(n)


def landing_weight(q, extra=4.0):
    """1 at a landing (within its half-width + extra), easing to 0 over 8 m past it."""
    w = 0.0
    for (_n, psi, half) in LANDINGS:
        a, _o = landing_local(q, psi)
        w = max(w, 1.0 - smooth01((abs(a) - half - extra) / 8.0))
    return w


def recess_at(q):
    """How far the wall steps back (outward) at plan point q: RECESS behind
    each built facade, easing out past its ends (grottos are cut instead)."""
    out = 0.0
    for (name, psi, half) in LANDINGS:
        if name in GROTTOS:
            continue
        a, _o = landing_local(q, psi)
        out = max(out, RECESS * (1.0 - smooth01((abs(a) - (half - 2.0)) / 3.0)))
    return out


def grotto_push(q, z):
    """How far a grotto cuts back into the wall at plan point q, height z: its
    flat back (GROTTO_BACK) under GROTTO_HIGH, sloping sides out to the mouth,
    a roof rising toward the lake. 0 away from one."""
    best = 0.0
    for (name, psi, _half) in LANDINGS:
        if name not in GROTTOS:
            continue
        a, _o = landing_local(q, psi)
        if abs(a) > GROTTO_MOUTH + 1.0:
            continue
        floor = GROTTOS[name]
        across = 1.0 - smooth01((abs(a) - GROTTO_HALF) / (GROTTO_MOUTH - GROTTO_HALF))
        up = 1.0 - smooth01((z - floor - GROTTO_HIGH) / 3.4)
        best = max(best, GROTTO_BACK * across * up)
    return best


def circ_noise(psi, freq, seed):
    """Smooth noise round the shore (periodic in psi)."""
    a = math.radians(psi)
    return noise.noise((math.cos(a) * freq, math.sin(a) * freq, seed))


def shore_shift(psi):
    """Walk 1 ("a giant square"): lobes and bays round the shore, metres out
    (+) or in (-) from the ellipse; none at the landings, little by the quay."""
    m = 13.0 * circ_noise(psi, 1.6, 11.0) + 4.5 * circ_noise(psi, 4.5, 23.0)
    if 200.0 < psi < 340.0:      # behind the quay: the back wall's ends stay buried
        m = max(-3.0, min(3.0, m))
    return m * (1.0 - landing_weight(ellipse(psi), 6.0))


def wall_top(psi):
    return max(14.0, WALL_TOP + 9.0 * circ_noise(psi, 2.2, 31.0))


def wall_lean(psi):
    """How far the wall leans in (m) by its top."""
    return max(0.0, 5.0 + 11.0 * circ_noise(psi, 1.9, 47.0))


# ---------------------------------------------------------------- the ferry's water

def stop_dock(name):
    """(dock point, out over the water) in Blender plan coordinates, as
    LakeLayout.stop_dock."""
    if name == "quay":
        return Vector((8.0, 41.0, 0.0)), Vector((0.0, 1.0, 0.0))
    for (n, psi, _h) in LANDINGS:
        if n == name:
            p, nn, _t = landing_frame(psi)
            return p - nn * 6.0, -nn
    raise KeyError(name)


def bezier(p0, p1, p2, p3, steps):
    out = []
    for i in range(steps + 1):
        t = i / steps
        u = 1.0 - t
        out.append(p0 * u * u * u + p1 * 3 * u * u * t + p2 * 3 * u * t * t + p3 * t * t * t)
    return out


ROUTE_PTS = []


def routes():
    """Points along every ferry crossing (LakeFerry.depart: back off 7 m, a
    Bezier, a 12 m run in) and the far lantern boat's (LakeLife._far_ferry)."""
    if ROUTE_PTS:
        return ROUTE_PTS
    stops = ["quay", "mahaleh", "gardens", "forgotten"]
    for a in stops:
        for b in stops:
            if a == b:
                continue
            da, oa = stop_dock(a)
            db, ob = stop_dock(b)
            start = da + oa * 11.0
            end = db + ob * 16.0
            reach = min(45.0, max(12.0, (end - start).length * 0.35))
            ROUTE_PTS.extend(bezier(start, start + oa * reach, end + ob * reach, end, 90))
            ROUTE_PTS.extend([da + oa * s for s in range(12)])
            ROUTE_PTS.extend([db + ob * s for s in range(17)])
    pm, nm, tm = landing_frame(60.0)
    pf, nf, tf = landing_frame(15.0)
    pa = pm + tm * 12.0 - nm * 7.0
    pb = pf - tf * 11.0 - nf * 7.0
    ROUTE_PTS.extend(bezier(pa, pa - nm * 25.0, pb - nf * 25.0, pb, 70))
    for p in ROUTE_PTS:
        p.z = 0.0
    return ROUTE_PTS


def route_dist(x, y):
    q = Vector((x, y, 0.0))
    return min((q - p).length for p in routes())


def in_harbour(x, y):
    return -26.0 < x < 20.0 and y < 50.0


def landing_dist(x, y):
    q = Vector((x, y, 0.0))
    return min((q - landing_frame(psi)[0]).length for (_n, psi, _h) in LANDINGS)


def lake_e(x, y):
    return math.hypot((x - CX) / RX, (y - CY) / RY)


def pick_dips():
    """Low parts of the roof (walk 1: formations "dropping from certain low
    areas of the ceiling"): (x, y, radius, roof height there), off the
    ferry's water."""
    rng = random.Random(31)
    dips = []
    for _k in range(600):
        a = rng.uniform(0, 2 * math.pi)
        f = math.sqrt(rng.uniform(0.04, 0.72))
        x, y = CX + RX * f * math.cos(a), CY + RY * f * math.sin(a)
        if in_harbour(x, y) or route_dist(x, y) < 15.0 or landing_dist(x, y) < 24.0:
            continue
        if any(math.hypot(x - d[0], y - d[1]) < 34.0 for d in dips):
            continue
        dips.append((x, y, rng.uniform(12.0, 17.0), rng.uniform(8.5, 12.0)))
        if len(dips) == 5:
            break
    return dips


# ---------------------------------------------------------------- the cavern

def roof_shape(top_z, f, q, dips):
    """The roof over plan point q, fraction f of the way out (1 at the wall
    top, whose height is top_z), lowered over the dips."""
    rise = math.sin(math.pi / 2 * (1.0 - f)) ** 1.3
    h = top_z + (ROOF_TOP - top_z) * rise + (2.6 * rough((q.x, q.y, 0.0), 0.06, 9.0) + 0.8 * rough((q.x, q.y, 0.0), 0.3, 2.0)) * min(1.0, (1.0 - f) * 4.0)
    for (dx, dy, rad, low) in dips:
        g = math.exp(-((q.x - dx) ** 2 + (q.y - dy) ** 2) / (rad * rad))
        if h > low:
            h -= (h - low) * g
    return max(h, 7.5)


def spire(bm, x, y, z0, z1, radii, rng, segs=8, tip=None, lean=0.08):
    """A rough rock spire from z0 to z1 (either way up) through rings of
    `radii`, jittered; capped, or closed to `tip` (x, y, z)."""
    n = len(radii)
    rings = []
    sx, sy = rng.uniform(-1.0, 1.0), rng.uniform(-1.0, 1.0)
    ph = rng.uniform(0.0, 100.0)
    for i, rad in enumerate(radii):
        t = i / (n - 1)
        z = z0 + (z1 - z0) * t
        cx = x + sx * t * abs(z1 - z0) * lean
        cy = y + sy * t * abs(z1 - z0) * lean
        ring = []
        for j in range(segs):
            a = 2 * math.pi * j / segs + ph
            k = 1.0 + 0.38 * noise.noise((math.cos(a) * 1.3 + ph, math.sin(a) * 1.3, z * 0.35))
            ring.append(bm.verts.new((cx + rad * k * math.cos(a), cy + rad * k * math.sin(a), z)))
        rings.append(ring)
    for i in range(n - 1):
        for j in range(segs):
            jj = (j + 1) % segs
            bm.faces.new((rings[i][j], rings[i][jj], rings[i + 1][jj], rings[i + 1][j]))
    bm.faces.new(list(reversed(rings[0])))
    if tip is None:
        bm.faces.new(rings[-1])
    else:
        v = bm.verts.new(tip)
        for j in range(segs):
            bm.faces.new((rings[-1][j], rings[-1][(j + 1) % segs], v))


def roof_hit(bvh, x, y):
    hit = bvh.ray_cast(Vector((x, y, WATER + 0.5)), Vector((0.0, 0.0, 1.0)), 80.0)
    return hit[0].z if hit[0] is not None else None


def surfaces(bm):
    """(centre, normal, area) of each face of bm."""
    bm.normal_update()
    return [(f.calc_center_median(), f.normal.copy(), f.calc_area()) for f in bm.faces]


def upright_mushroom(out, stems, x, y, z, h, lean, rng):
    """A glowing mushroom standing on the ground at (x, y, z), h tall: a
    curved stalk (stems), a domed glowing cap and glowing gills under it (out)."""
    R = h * rng.uniform(0.3, 0.45)
    top = (x + lean[0] * h, y + lean[1] * h, z + h)
    add_tube(stems, [(x, y, z - 0.1), (x + lean[0] * h * 0.4, y + lean[1] * h * 0.4, z + h * 0.5), top],
             [h * 0.09, h * 0.07, h * 0.05], segs=6)
    add_lathe(out, [(R, top[2]), (R * 0.82, top[2] + R * 0.28), (R * 0.45, top[2] + R * 0.42), (0.0, top[2] + R * 0.46)],
              top[0], top[1], segs=10)
    add_lathe(out, [(h * 0.05, top[2] - R * 0.3), (R * 0.6, top[2] - R * 0.1), (R * 0.97, top[2] - 0.01)],
              top[0], top[1], segs=10)


def hanging_strand(out, stalks, p, rng, scale=1.0):
    """A fungus strand hanging from the roof at p (walk 2: "hanging mushrooms
    for ceilings", as the Gorge's glow moss): a thin stalk swaying down,
    small glowing caps along it, a glowing drop at its tip."""
    length = rng.uniform(0.5, 2.2) * scale
    n = max(3, int(length / 0.3))
    ph = rng.uniform(0.0, 2 * math.pi)
    path = [(p.x + 0.06 * math.sin(ph + k * 1.3), p.y + 0.05 * math.cos(ph * 0.7 + k), p.z + 0.1 - length * k / n)
            for k in range(n + 1)]
    add_tube(stalks if stalks is not None else out, path, [0.025 * (1.0 - 0.5 * k / n) for k in range(n + 1)], segs=4)
    for k in range(1, n + 1, 2):
        (x, y, z) = path[k]
        R = (0.11 * (1.0 - 0.45 * k / n) + rng.uniform(0.0, 0.03)) * scale
        side = 0.04 if k % 4 == 1 else -0.04
        add_lathe(out, [(R, z), (R * 0.75, z + R * 0.35), (0.0, z + R * 0.5)], x + side, y, segs=6)
    (x, y, z) = path[-1]
    add_lathe(out, [(0.0, z - 0.08), (0.05, z - 0.03), (0.0, z + 0.03)], x, y, segs=5)


def cap_cluster(out, c, n, rng, size, spread, scale=1.0, stalks=None):
    """A cluster of glowing caps on a surface at c (normal n): shelf brackets
    on a wall, strands hanging from a roof, upright caps on a ledge."""
    n = n.normalized()
    u = n.cross(Vector((0.0, 0.0, 1.0)))
    if u.length < 0.2:
        u = Vector((1.0, 0.0, 0.0))
    u.normalize()
    v = n.cross(u).normalized()
    for _i in range(size):
        p = c + u * rng.uniform(-spread, spread) + v * rng.uniform(-spread, spread) - n * 0.05
        s = scale * rng.uniform(0.6, 1.25)
        if n.z < -0.55 and stalks is not None:  # strands hanging from the roof (walk 2)
            if rng.random() < 0.45:
                hanging_strand(out, stalks, p, rng, s)
            continue
        if n.z < -0.55 or n.z > 0.55:           # hanging under the roof / upright on a ledge
            d = n if n.z > 0.55 else (n + Vector((0.0, 0.0, -1.0))).normalized()
            ln, rad = rng.uniform(0.1, 0.35) * s, rng.uniform(0.08, 0.2) * s
            prof = [(0.025, -0.15), (0.03, ln), (rad, ln), (rad * 0.75, ln + rad * 0.45), (0.0, ln + rad * 0.6)]
            m = Matrix.Translation(p) @ Vector((0.0, 0.0, 1.0)).rotation_difference(d).to_matrix().to_4x4()
            moved(out, lambda bm, prof=prof: add_lathe(bm, prof, 0.0, 0.0, segs=5), m)
        else:                                   # a shelf bracket on a wall
            rad = rng.uniform(0.12, 0.3) * s
            q = p + Vector((n.x, n.y, 0.0)).normalized() * rad * 0.4
            for k in range(rng.randint(1, 3)):
                r2 = rad * rng.uniform(0.6, 1.0)
                prof = [(0.0, 0.0), (r2, 0.0), (r2 * 0.85, 0.05), (0.0, 0.08)]
                moved(out, lambda bm, prof=prof: add_lathe(bm, prof, 0.0, 0.0, segs=6),
                      Matrix.Translation(q + Vector((rng.uniform(-0.1, 0.1), rng.uniform(-0.1, 0.1), 0.18 * k * s))))


def glowcaps(out, faces, colonies, rng, seed, patchy=0.1, reach=4.0, per=(8, 14), avoid=None, stalks=None):
    """Colonies of glowing caps (walk 1: "mushrooms from the ceiling and
    walls"): each a dense heart of big caps thinning out over `reach` m of
    the surface round it, in patches across `faces` (centre, normal, area).
    Returns the colonies' (centre, normal), for lights."""
    ok = [f for f in faces if f[0].z > WATER + 0.35 and f[2] > 0.03]
    pool = [f for f in ok if noise.noise((f[0].x * 0.045, f[0].y * 0.045, f[0].z * 0.06 + seed)) > patchy
            and (avoid is None or not avoid(f[0]))]
    centres = []
    if not pool:
        return centres
    for _k in range(colonies):
        for _t in range(60):
            c, n, _a = pool[rng.randrange(len(pool))]
            if all((c - q[0]).length > reach * 2.5 for q in centres):
                break
        else:
            continue
        near = [f for f in ok if (f[0] - c).length < reach and f[1].dot(n) > 0.2]
        cap_cluster(out, c, n, rng, rng.randint(9, 14), 0.5, 1.35, stalks=stalks)          # the heart
        for _j in range(rng.randint(*per)):
            fc, fn, _a = near[rng.randrange(len(near))]
            d = (fc - c).length / reach
            if rng.random() < d * 0.6:
                continue
            cap_cluster(out, fc, fn, rng, rng.randint(3, 8), 0.45 + 0.4 * d, 1.15 - 0.5 * d, stalks=stalks)
        centres.append((c, n))
    return centres


def cavern(r):
    dips = pick_dips()
    lo = [WALL_FOOT + 1.6 * k for k in range(5)] + [-2.0 + 0.8 * k for k in range(18)]
    up_rows = 6
    bm = bmesh.new()
    ring = []
    tops = []
    for i in range(SEG):
        psi = 360.0 * i / SEG
        n = ellipse_normal(psi)
        base = ellipse(psi) + n * shore_shift(psi)
        top = wall_top(psi)
        lean = wall_lean(psi)
        rows = lo + [lo[-1] + (top - lo[-1]) * j / up_rows for j in range(1, up_rows + 1)]
        rec = recess_at(base)
        near = landing_weight(base, 0.0)
        col = []
        for z in rows:
            k = (rough((base.x, base.y, z), 0.09, 1.0) + 1.0) * 0.5         # 0..1, broad
            k2 = rough((base.x, base.y, z), 0.35, 4.0) * 0.5                 # fine
            wild = 3.6 * k + k2 + 0.6
            calm = rec + 0.8 * k + 0.4 * (k2 + 0.5) + 0.2
            push = wild + (calm - wild) * max(near, 1.0 if rec > 0.1 else 0.0)
            # Leaning in as it rises, but not over a landing's facade.
            keep = near * (1.0 - smooth01((z - 17.0) / 4.0))
            push -= lean * (1.0 - keep) * smooth01((z - 3.0) / (top - 3.0)) ** 1.5
            push = max(push, grotto_push(base, z))
            q = base + n * push
            col.append(bm.verts.new((q.x, q.y, z)))
        ring.append(col)
        tops.append(col[-1])
    nrows = len(ring[0])
    for i in range(SEG):
        a, b = ring[i], ring[(i + 1) % SEG]
        for k in range(nrows - 1):
            bm.faces.new((a[k], a[k + 1], b[k + 1], b[k]))          # facing in
    # The roof: rings from the wall's top in to the middle.
    nr = 16
    prev = tops
    for k in range(1, nr + 1):
        f = 1.0 - k / (nr + 0.5)
        cur = []
        for i in range(SEG):
            t = tops[i].co
            q = Vector((CX + (t.x - CX) * f, CY + (t.y - CY) * f, 0.0))
            cur.append(bm.verts.new((q.x, q.y, roof_shape(t.z, f, q, dips))))
        for i in range(SEG):
            j = (i + 1) % SEG
            bm.faces.new((prev[i], cur[i], cur[j], prev[j]))       # facing down
        prev = cur
    centre = bm.verts.new((CX, CY, roof_shape(WALL_TOP, 0.0, Vector((CX, CY, 0.0)), dips) + 1.0))
    for i in range(SEG):
        bm.faces.new((prev[i], centre, prev[(i + 1) % SEG]))
    bm.normal_update()
    bvh = BVHTree.FromBMesh(bm)
    rock_faces = surfaces(bm)
    mesh_object("lk_cavern__rock-col", bm, [ROCK], r, recalc=False)

    # Each grotto's floor (walked: collision), from the facade line to its back.
    fb = bmesh.new()
    for (name, psi, _half) in LANDINGS:
        if name not in GROTTOS:
            continue
        p, n, t = landing_frame(psi)
        z = GROTTOS[name]
        outline = []
        for (a, o) in [(-GROTTO_MOUTH - 1.0, -0.5), (-GROTTO_MOUTH, 3.0), (-GROTTO_HALF - 0.6, GROTTO_BACK + 0.4),
                       (GROTTO_HALF + 0.6, GROTTO_BACK + 0.4), (GROTTO_MOUTH, 3.0), (GROTTO_MOUTH + 1.0, -0.5)]:
            outline.append(p + t * a + n * o)
        top = [fb.verts.new((q.x, q.y, z)) for q in outline]
        bot = [fb.verts.new((q.x, q.y, z - 0.6)) for q in outline]
        fb.faces.new(top)
        fb.faces.new(list(reversed(bot)))
        for i in range(len(top)):
            j = (i + 1) % len(top)
            fb.faces.new((bot[i], bot[j], top[j], top[i]))
    mesh_object("lk_cavern__grotto_floor-col", fb, [ROCK], r)

    rng = random.Random(20)
    sb = bmesh.new()          # hanging from the roof
    fm = bmesh.new()          # rising from the lake: stacks, columns, stalagmites
    # Stalactites over the whole roof; short where the ferry passes under.
    for _k in range(120):
        a = rng.uniform(0, 2 * math.pi)
        f = math.sqrt(rng.uniform(0.02, 0.9))
        x, y = CX + RX * f * math.cos(a), CY + RY * f * math.sin(a)
        h = roof_hit(bvh, x, y)
        if h is None:
            continue
        ln = rng.uniform(1.5, 7.0)
        w = rng.uniform(0.4, 1.5)
        if h - ln < 8.0 and (route_dist(x, y) < 10.0 or in_harbour(x, y)):
            ln = max(1.0, h - 8.0)
        spire(sb, x, y, h + 1.0, h - ln, [w * 1.2, w, w * 0.6, w * 0.3], rng, segs=6, tip=(x, y, h - ln - 0.4))
    # The low roofs: long stalactites down toward the water, columns where
    # they've met the floor, stalagmites under them.
    for (dx, dy, rad, _low) in dips:
        for _k in range(rng.randint(12, 18)):
            a = rng.uniform(0, 2 * math.pi)
            d = rad * math.sqrt(rng.uniform(0.0, 0.55))
            x, y = dx + d * math.cos(a), dy + d * math.sin(a)
            h = roof_hit(bvh, x, y)
            if h is None or route_dist(x, y) < 8.0:
                continue
            tipz = WATER + rng.uniform(1.2, 6.0)
            w = rng.uniform(0.6, 1.8)
            spire(sb, x, y, h + 1.0, tipz, [w * 1.4, w, w * 0.7, w * 0.45, w * 0.22], rng, segs=7,
                  tip=(x, y, tipz - 0.5))
            if rng.random() < 0.45:      # a stalagmite under it
                g = rng.uniform(0.6, 1.6)
                spire(fm, x + rng.uniform(-0.5, 0.5), y + rng.uniform(-0.5, 0.5), -8.0, WATER + rng.uniform(0.3, 2.5),
                      [g * 1.8, g * 1.2, g * 0.7, g * 0.35], rng, segs=7)
        for _c in range(rng.randint(1, 3)):
            for _try in range(30):
                a = rng.uniform(0, 2 * math.pi)
                d = rad * math.sqrt(rng.uniform(0.0, 0.4))
                x, y = dx + d * math.cos(a), dy + d * math.sin(a)
                if route_dist(x, y) > 10.0:
                    break
            else:
                continue
            h = roof_hit(bvh, x, y)
            if h is None:
                continue
            c = rng.uniform(1.0, 1.8)
            spire(fm, x, y, -8.0, h + 2.0, [c * 3.0, c * 2.4, c * 1.7, c * 1.15, c * 0.85, c * 0.75, c * 0.9, c * 1.3, c * 2.0, c * 2.8],
                  rng, segs=9, lean=0.02)
    # Stacks of rock standing out of the open lake, some in clusters.
    placed = []
    for _k in range(900):
        if len(placed) >= 18:
            break
        a = rng.uniform(0, 2 * math.pi)
        f = math.sqrt(rng.uniform(0.0, 0.93))
        x, y = CX + RX * f * math.cos(a), CY + RY * f * math.sin(a)
        big = rng.uniform(2.0, 5.0)
        if in_harbour(x, y) or route_dist(x, y) < 9.0 + big or landing_dist(x, y) < 18.0:
            continue
        if any(math.hypot(x - p[0], y - p[1]) < 12.0 for p in placed):
            continue
        group = [(x, y, big)]
        for _s in range(rng.randint(0, 3)):
            sa = rng.uniform(0, 2 * math.pi)
            sd = big + rng.uniform(1.5, 5.0)
            sx, sy, sr = x + sd * math.cos(sa), y + sd * math.sin(sa), big * rng.uniform(0.3, 0.6)
            if route_dist(sx, sy) > 8.0 + sr and not in_harbour(sx, sy):
                group.append((sx, sy, sr))
        for (gx, gy, gr) in group:
            hi = WATER + gr * rng.uniform(0.6, 2.6)
            spire(fm, gx, gy, -8.0, hi - 0.6, [gr * 1.5, gr * 1.15, gr, gr * 0.85, gr * 0.65, gr * 0.42], rng, segs=9,
                  tip=(gx + rng.uniform(-0.4, 0.4) * gr, gy + rng.uniform(-0.4, 0.4) * gr, hi), lean=0.12)
        placed.append((x, y, big))
    bmesh.ops.recalc_face_normals(sb, faces=sb.faces)
    bmesh.ops.recalc_face_normals(fm, faces=fm.faces)
    hang_faces = surfaces(sb)
    form_faces = surfaces(fm)
    mesh_object("lk_cavern__stalactites", sb, [ROCK], r, recalc=False)
    mesh_object("lk_cavern__formations-col", fm, [ROCK], r, recalc=False)
    print("kit_add_r20: %d dips, %d stacks" % (len(dips), len(placed)))

    # Glowing caps on the walls, the roof and the formations; the biggest
    # patches near the ferry's water get a faint teal light.
    gb = bmesh.new()
    grng = random.Random(44)
    spots = glowcaps(gb, rock_faces, 46, grng, 3.0)
    spots += glowcaps(gb, form_faces + hang_faces, 20, grng, 7.0, patchy=-1.0, reach=3.0, per=(5, 9))
    for (name, psi, _half) in LANDINGS:     # each grotto has a few inside
        if name not in GROTTOS:
            continue
        p, n, t = landing_frame(psi)
        inside = [f for f in rock_faces if (lambda a_o: abs(a_o[0]) < GROTTO_MOUTH and 2.0 < a_o[1] < GROTTO_BACK - 0.5)(landing_local(f[0], psi))
                  and GROTTOS[name] + 0.5 < f[0].z < GROTTOS[name] + 6.0]
        glowcaps(gb, inside, 2, grng, 0.0, patchy=-2.0, reach=2.5, per=(4, 7))
    mesh_object("lk_cavern__glowcaps", gb, ["emit_lake_glowcap"], r)
    lit = []
    for (c, n) in sorted(spots, key=lambda s: route_dist(s[0].x, s[0].y)):
        if len(lit) >= 18:
            break
        if c.z > 20.0 or in_harbour(c.x, c.y):
            continue
        if any((c - q).length < 18.0 for q in lit):
            continue
        lit.append(c)
        marker("LIGHT_lake_glow__%d" % len(lit), r, tuple(c + n * 1.2))
    print("kit_add_r20: %d glow colonies, %d lit" % (len(spots), len(lit)))

    # The crack of daylight over the Gardens landing (a pale slit in the roof).
    crack = crack_point(bvh)
    cb = bmesh.new()
    add_obox(cb, (crack.x, crack.y, crack.z - 0.6), (9.0, 2.2, 0.2), (0.0, 0.0, math.radians(35.0)))
    mesh_object("lk_cavern__crack", cb, ["emit_sky_day"], r)
    print("kit_add_r20: crack at Godot (%.2f, %.2f, %.2f)" % (crack.x, crack.z, -crack.y))


def crack_point(bvh):
    """Where the crack of daylight is, 6 m out from the Gardens landing's
    facade line, just under the roof (Blender; LightShaft hangs from it)."""
    p, n, _t = landing_frame(125.0)
    q = p - n * 6.0
    h = roof_hit(bvh, q.x, q.y)
    return Vector((q.x, q.y, h if h is not None else WALL_TOP))


def bed(r):
    """The lake bed over the whole ellipse (collision): BED in the open lake,
    shelving up to about -2.6 under the far landings and the shore."""
    bm = bmesh.new()
    step = 2.5
    x0, x1, y0, y1 = CX - RX - 16, CX + RX + 16, CY - RY - 16, CY + RY + 16
    nx, ny = int((x1 - x0) / step), int((y1 - y0) / step)

    def h(x, y):
        e = math.hypot((x - CX) / RX, (y - CY) / RY)        # 1 at the wall
        z = BED - 2.0 * (1.0 - e) + 1.2 * rough((x, y, 0.0), 0.05, 3.0)
        z = max(z, BED - 3.5)
        if e > 0.9:
            z = max(z, -2.8 - 3.0 * (1.0 - (e - 0.9) / 0.1))
        if -22 < x < 14 and y < 45:                         # the harbour: shallower, darker
            z = max(z, -4.8 + 0.4 * rough((x, y, 0.0), 0.2, 6.0))
        return min(z, -2.6)

    vs = [[bm.verts.new((x0 + i * step, y0 + j * step, h(x0 + i * step, y0 + j * step))) for j in range(ny + 1)] for i in range(nx + 1)]
    for i in range(nx):
        for j in range(ny):
            bm.faces.new((vs[i][j], vs[i + 1][j], vs[i + 1][j + 1], vs[i][j + 1]))     # up
    mesh_object("lk_bed__mud-col", bm, [ROCK], r, recalc=False)


def headland(r):
    """The spur west of the boathouses: its east face (X -18, Blender Y 7..36)
    receding behind the boathouses, round a corner to its south face (Y 40)."""
    plan = [(-18.0, 6.0 + 1.5 * k) for k in range(21)]
    for k in range(1, 9):
        a = math.pi / 2 * k / 8
        plan.append((-22.0 + 4.0 * math.cos(a), 36.0 + 4.0 * math.sin(a)))
    plan += [(-22.0 - 1.6 * k, 40.0) for k in range(1, 38)]
    zs = [WALL_FOOT + 1.5 * k for k in range(int((WALL_TOP + 6 - WALL_FOOT) / 1.5) + 1)]
    bm = bmesh.new()
    cols = []
    for idx, (x, y) in enumerate(plan):
        if idx + 1 < len(plan):
            dx, dy = plan[idx + 1][0] - x, plan[idx + 1][1] - y
        else:
            dx, dy = x - plan[idx - 1][0], y - plan[idx - 1][1]
        ln = math.hypot(dx, dy) or 1.0
        nx, ny = dy / ln, -dx / ln                         # out of the rock
        col = []
        for z in zs:
            k = rough((x, y, z), 0.25, 17.0)
            if y < 21.0 and z < 6.0:
                push = -0.3 - 0.5 * (k + 1.0) * 0.5          # behind the boathouses: away
            else:
                push = 1.4 * k + 0.6 * rough((x, y, z), 0.08, 2.0)
            col.append(bm.verts.new((x + nx * push, y + ny * push, z)))
        cols.append(col)
    for i in range(len(cols) - 1):
        for k in range(len(zs) - 1):
            bm.faces.new((cols[i][k], cols[i + 1][k], cols[i + 1][k + 1], cols[i][k + 1]))     # out of the rock
    faces = surfaces(bm)
    mesh_object("lk_headland__rock-col", bm, [ROCK], r, recalc=False)
    gb = bmesh.new()
    glowcaps(gb, faces, 4, random.Random(52), 9.0, patchy=-0.2)
    mesh_object("lk_headland__glowcaps", gb, ["emit_lake_glowcap"], r)


def back_wall(r):
    """X 0..110 (the builder puts it at Godot X -55, Z -8), the lake toward +Y:
    rough rock up to 1.2 m proud, set back behind the quay and the boardwalk
    (X 35..67 below 5 m), flat round the mouth's hole (X 53..57, Z 0..4)."""
    step = 0.5
    w, z0, z1 = 110.0, WALL_FOOT, 26.0
    nx, nz = int(w / step), int((z1 - z0) / step)
    hx0, hx1, hz0, hz1 = 53.0, 57.0, 0.0, 4.0

    def bulge(x, z):
        # Walk 2 ("cut straight, not an organic cavern"): big swells and
        # hollows, ledges where the beds step out, a lean out over the
        # water as the wall rises into the roof; behind the quay and the
        # boardwalk it only goes back, in ledges and hollows.
        d_hole = max(hx0 - x, x - hx1, hz0 - z, z - hz1, 0.0)
        fade = min(1.0, d_hole / 1.6)
        k = (rough((x, 0.0, z), 0.35, 11.0) + 1.0) * 0.5
        big = rough((x, 0.0, z), 0.09, 4.0)
        tilt = 0.06 * x + 0.5 * rough((x, 0.0, 0.0), 0.05, 7.0)
        q = (z + tilt) / 1.7
        ledge = smooth01((q - math.floor(q) - 0.7) / 0.3) * 0.6
        if 35.0 < x < 67.0 and z < 5.0:
            # Below head height it only goes back (the quay runs 1 m into the
            # rock), bumpy and fissured; above, it swells out over the walk.
            near = smooth01((3.2 - z) / 0.8) * smooth01(min(x - 35.0, 67.0 - x) / 2.0)
            fine = (rough((x, 0.0, z), 0.9, 13.0) + 1.0) * 0.5
            fissure = smooth01(1.0 - abs(rough((x, 0.0, 0.0), 0.6, 17.0)) / 0.12) * 0.35
            back = min(0.9, 0.1 + 0.35 * k + 0.3 * fine + 0.25 * max(0.0, big) + fissure + ledge * 0.3)
            out = 0.5 + 1.2 * max(0.0, big) + 0.9 * k + ledge + max(0.0, z - 3.0) * 0.2
            out = min(out, 1.6 + max(0.0, z - 6.0) * 0.5)     # clear of the boathouse roofs 2 m out
            return fade * (-back * near + out * (1.0 - near))
        return fade * (0.3 + 1.6 * big + 1.2 * k + ledge + max(0.0, z - 3.0) * 0.18)

    bm = bmesh.new()
    vs = [[bm.verts.new((i * step, bulge(i * step, z0 + k * step), z0 + k * step)) for k in range(nz + 1)] for i in range(nx + 1)]
    for i in range(nx):
        for k in range(nz):
            cx, cz = (i + 0.5) * step, z0 + (k + 0.5) * step
            if hx0 < cx < hx1 and hz0 < cz < hz1:
                continue
            bm.faces.new((vs[i][k], vs[i][k + 1], vs[i + 1][k + 1], vs[i + 1][k]))
    mesh_object("lk_back_wall__rock-col", bm, ["limestone"], r, recalc=False)     # rev 4: the harbour's limestone, no teal by the quay


# ---------------------------------------------------------------- the quay

def quay(r):
    """X 0..16, Y -1..8 (the builder puts it at Godot (-6, 0, -8)): top at 0;
    water steps in X 4..8 from Y 4.5 down to -1.5 at the front; bollards."""
    def body(bm):
        add_box(bm, 0.0, 4.0, -1.0, 8.0, BED, -0.08)
        add_box(bm, 8.0, 16.0, -1.0, 8.0, BED, -0.08)
        add_box(bm, 4.0, 8.0, -1.0, 4.5, BED, -0.08)
    solid("lk_quay__body-col", r, [STONE], body)

    def paving(bm):      # walk 2: stops short of the coping round the steps (they z-fought)
        add_box(bm, 0.0, 4.0, -1.0, 4.5, -0.08, 0.0)
        add_box(bm, 0.0, 3.7, 4.5, 8.0, -0.08, 0.0)
        add_box(bm, 8.0, 16.0, -1.0, 4.5, -0.08, 0.0)
        add_box(bm, 8.3, 16.0, 4.5, 8.0, -0.08, 0.0)
        add_box(bm, 4.0, 8.0, -1.0, 4.5, -0.08, 0.0)
    solid("lk_quay__paving-col", r, [PAVE], paving)

    def steps(bm):
        tread = 3.5 / 6.0
        for k in range(1, 7):
            add_box(bm, 4.0, 8.0, 4.5 + (k - 1) * tread, 4.5 + k * tread, BED, -0.25 * k)
    solid("lk_quay__steps", r, [STONE], steps)
    t = 3.5 / 6.0
    ramp(r, "lk_quay", 4.0, 8.0, [(4.5, 0.0), (8.0 - t / 2.0, -1.5), (8.0, -1.5), (8.45, -1.67)])

    def coping(bm):      # a dressed edge round the steps' well, flush with the paving
        add_box(bm, 3.7, 4.0, 4.5, 8.0, -0.3, 0.0)
        add_box(bm, 8.0, 8.3, 4.5, 8.0, -0.3, 0.0)
    solid("lk_quay__coping", r, ["persian_rock_dressed"], coping)
    bollards(r, "lk_quay", [(1.4, 7.55), (10.6, 7.55), (15.6, 6.0), (15.6, 2.0)])


def bollards(r, name, spots):
    def build(bm):
        for (x, y) in spots:
            add_lathe(bm, [(0.13, 0.0), (0.13, 0.42), (0.17, 0.48), (0.17, 0.55), (0.0, 0.58)], x, y, segs=8)
    solid(name + "__bollards-col", r, [IRON], build)


def shelf(r):
    """X 0..12, Y 0..2.5, its top 0.45 m under the water: you wade here."""
    solid("lk_shelf__ledge-col", r, [STONE], lambda bm: add_box(bm, 0.0, 12.0, 0.0, 2.5, BED, WATER - 0.45))


# ---------------------------------------------------------------- timber

def planks(bm, x0, x1, y0, y1, z, across=True, width=0.42, gap=0.04):
    """Deck planks between x0..x1, y0..y1, top at z, laid across Y (running
    along X) if `across`."""
    if across:
        y = y0
        while y < y1 - 0.05:
            add_box(bm, x0, x1, y, min(y + width, y1), z - 0.07, z)
            y += width + gap
    else:
        x = x0
        while x < x1 - 0.05:
            add_box(bm, x, min(x + width, x1), y0, y1, z - 0.07, z)
            x += width + gap


def piles(bm, spots, top=0.0, rad=0.13):
    for (x, y) in spots:
        add_lathe(bm, [(rad, BED), (rad, top - 0.02), (rad * 0.85, top + 0.03), (0.0, top + 0.06)], x, y, segs=7)


def pier_bay(r):
    solid("lk_pier_4m__planks", r, [WOOD], lambda bm: planks(bm, 0.0, 2.0, 0.0, 4.0, 0.0))
    solid("lk_pier_4m__deck-colonly", r, [WOOD], lambda bm: add_box(bm, 0.0, 2.0, 0.0, 4.0, -0.25, 0.0))

    def frame(bm):
        add_box(bm, 0.08, 0.26, 0.0, 4.0, -0.38, -0.07)
        add_box(bm, 1.74, 1.92, 0.0, 4.0, -0.38, -0.07)
        add_obox(bm, (1.0, 0.25, -0.75), (2.1, 0.1, 0.16), (0.0, math.radians(18), 0.0))
        add_obox(bm, (1.0, 2.05, -0.75), (2.1, 0.1, 0.16), (0.0, math.radians(-18), 0.0))
    solid("lk_pier_4m__frame", r, [PWOOD], frame)
    solid("lk_pier_4m__piles-col", r, [PWOOD], lambda bm: piles(bm, [(0.17, 0.25), (1.83, 0.25), (0.17, 2.05), (1.83, 2.05)], top=0.0))


def pier_head(r):
    """X 0..4, Y 0..5: deck (Y 0..2), steps down 0.9 m (Y 2..3.5), the stage
    (Y 3.5..5) where the ferry's bow comes in at X 2."""
    def deck(bm):
        add_box(bm, 0.0, 4.0, 0.0, 2.0, -0.25, 0.0)
        add_box(bm, 0.0, 4.0, 3.5, 5.0, STAGE - 0.25, STAGE)
    solid("lk_pier_head__deck-colonly", r, [WOOD], deck)
    t = 1.5 / 4.0          # the steps are walked on a ramp through their treads
    ramp(r, "lk_pier_head", 0.0, 4.0, [(2.0, 0.0), (3.5 - t / 2.0, STAGE)])

    def boards(bm):
        planks(bm, 0.0, 4.0, 0.0, 2.0, 0.0)
        tread = 1.5 / 4.0
        for k in range(1, 5):
            add_box(bm, 0.0, 4.0, 2.0 + (k - 1) * tread + 0.02, 2.0 + k * tread, -0.225 * k - 0.07, -0.225 * k)
        planks(bm, 0.0, 4.0, 3.5, 5.0, STAGE)
    solid("lk_pier_head__planks", r, [WOOD], boards)

    def frame(bm):
        for x0 in (0.08, 3.74):
            add_box(bm, x0, x0 + 0.18, 0.0, 2.0, -0.38, -0.07)
            add_box(bm, x0, x0 + 0.18, 3.5, 5.0, STAGE - 0.38, STAGE - 0.07)
            add_obox(bm, (x0 + 0.09, 2.75, -0.5), (0.18, 1.8, 0.16), (math.radians(-31), 0.0, 0.0))
    solid("lk_pier_head__frame", r, [PWOOD], frame)
    solid("lk_pier_head__piles-col", r, [PWOOD], lambda bm: piles(bm, [(0.17, 0.25), (3.83, 0.25), (0.17, 1.9), (3.83, 1.9)], top=0.0))
    solid("lk_pier_head__stage_piles-col", r, [PWOOD], lambda bm: piles(bm, [(0.17, 3.6), (3.83, 3.6)], top=STAGE + 0.5))
    bollards(r, "lk_pier_head", [(0.35, 4.75), (3.65, 4.75)])


def boardwalk(r):
    """X 0..4, Y -1..2 (Godot Z -7..-10): along the back wall, on piles."""
    solid("lk_boardwalk_4m__planks", r, [WOOD], lambda bm: planks(bm, 0.0, 4.0, -1.0, 2.0, 0.0, across=False))
    solid("lk_boardwalk_4m__deck-colonly", r, [WOOD], lambda bm: add_box(bm, 0.0, 4.0, -1.0, 2.0, -0.25, 0.0))

    def frame(bm):
        add_box(bm, 0.0, 4.0, 1.74, 1.92, -0.38, -0.07)
        add_box(bm, 0.0, 4.0, -0.9, -0.72, -0.38, -0.07)
    solid("lk_boardwalk_4m__frame", r, [PWOOD], frame)
    solid("lk_boardwalk_4m__piles-col", r, [PWOOD], lambda bm: piles(bm, [(0.25, 1.83), (2.25, 1.83)], top=0.0))


def boathouse(r):
    """X 0..4, Y 0..8: the door end (Y 0) on the boardwalk, the lake mouth at
    Y 8. A walkway along X 0..1.1, a back landing, the slip open to the water."""
    def deck(bm):
        add_box(bm, 0.0, 1.1, 0.0, 8.0, -0.25, 0.0)
        add_box(bm, 1.1, 4.0, 0.0, 1.0, -0.25, 0.0)
    solid("lk_boathouse__deck-colonly", r, [WOOD], deck)

    def boards(bm):
        planks(bm, 0.1, 1.1, 1.0, 7.95, 0.0, across=True)
        planks(bm, 0.1, 3.9, 0.06, 1.0, 0.0, across=False)
    solid("lk_boathouse__planks", r, [WOOD], boards)
    solid("lk_boathouse__piles-col", r, [PWOOD],
          lambda bm: piles(bm, [(0.15, 0.15), (3.85, 0.15), (0.15, 4.0), (3.85, 4.0), (0.15, 7.85), (3.85, 7.85), (1.1, 7.85)], top=-0.1))

    def walls(bm):
        add_box(bm, 0.0, 0.1, 0.0, 8.0, -0.6, 2.8)                    # side walls
        add_box(bm, 3.9, 4.0, 0.0, 8.0, -0.6, 2.8)
        add_box(bm, 1.05, 2.2, -0.05, 0.05, -0.6, 2.8)                 # back wall, the door at X 0.1..1.05
        add_box(bm, 3.0, 3.9, -0.05, 0.05, -0.6, 2.8)
        add_box(bm, 2.2, 3.0, -0.05, 0.05, -0.6, 1.1)
        add_box(bm, 2.2, 3.0, -0.05, 0.05, 1.7, 2.8)
        add_box(bm, 0.1, 1.05, -0.05, 0.05, 2.1, 2.8)
        add_box(bm, 0.1, 3.9, 7.95, 8.05, 2.35, 2.8)                   # the lake mouth's lintel
        add_box(bm, 0.1, 1.1, 7.9, 8.0, 0.0, 1.0)                      # a rail at the walkway's end
    solid("lk_boathouse__walls-col", r, [WOOD], walls)

    def gables(bm):   # rev 2 (walk 4): no gables underground; posts and the roof's beams
        for (x, y) in ((0.1, 0.0), (3.9, 0.0), (1.1, 8.0), (3.9, 8.0)):  # corner posts
            add_box(bm, x - 0.09, x + 0.09, y - 0.09, y + 0.09, -0.3, 2.85)
        for y in (0.0, 2.0, 4.0, 6.0, 8.0):                                 # beams across, ends proud
            add_box(bm, -0.12, 4.12, y - 0.07, y + 0.07, 2.8, 2.95)
    solid("lk_boathouse__gables", r, [PWOOD], gables)

    def roof(bm):     # rev 2 (walk 4): a flat store deck with a low rim, goods on it (build_lake)
        add_box(bm, -0.05, 4.05, -0.1, 8.1, 2.95, 3.0)
        add_box(bm, -0.05, 0.03, -0.1, 8.1, 3.0, 3.18)
        add_box(bm, 3.97, 4.05, -0.1, 8.1, 3.0, 3.18)
        add_box(bm, 0.03, 3.97, 8.02, 8.1, 3.0, 3.18)
        add_box(bm, 0.03, 3.97, -0.1, -0.02, 3.0, 3.18)
    solid("lk_boathouse__roof", r, [PWOOD], roof)
    solid("lk_boathouse__roofplanks", r, [WOOD], lambda bm: planks(bm, 0.05, 3.95, 0.0, 8.0, 3.04, across=True))
    # rev 3 (walk 5): no glowing pane; the window is an open hole in the wall.

    def lamp(bm):     # the lamp hanging inside, over the walkway's back
        add_box(bm, 0.58, 0.62, 1.38, 1.42, 2.1, 2.8)
        add_box(bm, 0.5, 0.7, 1.3, 1.5, 1.72, 1.98)
    solid("lk_boathouse__lamp_frame", r, [IRON], lamp)
    solid("lk_boathouse__lamp_glass", r, ["emit_lantern"], lambda bm: add_box(bm, 0.53, 0.67, 1.33, 1.47, 1.74, 1.96))
    marker("LIGHT_lake_lamp__bh", r, (0.6, 1.4, 1.85))

    def gear(bm):
        add_obox(bm, (3.7, 3.0, 1.2), (0.06, 0.06, 2.6), (0.15, 0.0, 0.0))        # oars on the wall
        add_obox(bm, (3.7, 3.5, 1.2), (0.06, 0.06, 2.6), (-0.12, 0.0, 0.0))
        add_box(bm, 3.65, 3.75, 2.75, 2.95, 2.2, 2.3)
        add_box(bm, 2.6, 3.4, 0.2, 0.8, 0.0, 0.45)                                # a crate on the landing
    solid("lk_boathouse__gear", r, [PWOOD], gear)

    def net(bm):
        uv = bm.loops.layers.uv.new("UVMap")
        from kit_blender import add_card
        add_card(bm, uv, (3.86, 5.2, 0.4), 2.2, 1.9, yaw=math.pi / 2)
    solid("lk_boathouse__net", r, ["net_cord"], net, recalc=False)


def lantern(bm_frame, bm_glass, x, y, z):
    """A hanging oil lantern centred at (x, y, z)."""
    add_box(bm_frame, x - 0.12, x + 0.12, y - 0.12, y + 0.12, z - 0.2, z - 0.16)
    add_box(bm_frame, x - 0.12, x + 0.12, y - 0.12, y + 0.12, z + 0.14, z + 0.18)
    for (dx, dy) in ((-0.11, -0.11), (0.11, -0.11), (0.11, 0.11), (-0.11, 0.11)):
        add_box(bm_frame, x + dx - 0.015, x + dx + 0.015, y + dy - 0.015, y + dy + 0.015, z - 0.16, z + 0.14)
    add_lathe(bm_frame, [(0.13, z + 0.18), (0.05, z + 0.3), (0.02, z + 0.36), (0.0, z + 0.38)], x, y, segs=6)
    add_box(bm_glass, x - 0.09, x + 0.09, y - 0.09, y + 0.09, z - 0.16, z + 0.14)


def lantern_post(r):
    """A post 2.7 m high, its arm to +X with the lantern hanging 0.55 m out."""
    solid("lk_lantern_post__post-col", r, [PWOOD], lambda bm: add_box(bm, -0.08, 0.08, -0.08, 0.08, 0.0, 2.75))

    def arm(bm):
        add_box(bm, -0.05, 0.7, -0.04, 0.04, 2.55, 2.65)
        add_obox(bm, (0.2, 0.0, 2.38), (0.05, 0.05, 0.5), (0.0, math.radians(-45), 0.0))
        add_box(bm, 0.54, 0.56, -0.01, 0.01, 2.4, 2.55)
    solid("lk_lantern_post__arm", r, [IRON], arm)
    fb, gb = bmesh.new(), bmesh.new()
    lantern(fb, gb, 0.55, 0.0, 2.2)
    mesh_object("lk_lantern_post__lantern", fb, [IRON], r)
    mesh_object("lk_lantern_post__glass", gb, ["emit_lantern"], r)
    marker("LIGHT_lake_lantern__post", r, (0.55, 0.0, 2.2))


def bell(r):
    solid("lk_bell__post-col", r, [PWOOD], lambda bm: (add_box(bm, -0.08, 0.08, -0.08, 0.08, 0.0, 2.3),
                                                       add_box(bm, -0.06, 0.62, -0.05, 0.05, 2.15, 2.27)))
    solid("lk_bell__bell", r, ["brass"], lambda bm: add_lathe(bm, [(0.0, 1.62), (0.17, 1.64), (0.13, 1.75), (0.09, 1.92),
                                                                 (0.03, 2.0), (0.0, 2.02)], 0.45, 0.0, segs=10))
    solid("lk_bell__rope", r, ["net_cord"], lambda bm: add_box(bm, 0.44, 0.46, -0.01, 0.01, 1.0, 1.64))


# ---------------------------------------------------------------- boats

def hull(bm, length, beam, sheer, keel, rise=0.15, stations=11, around=10, wall=0.05):
    """A closed boat hull along Y (bow at +Y), its waterline at Z 0: outer
    and inner skins joined at the gunwale and the ends."""
    half = length / 2.0
    outer, inner = [], []
    for j in range(stations):
        y = -half + length * j / (stations - 1)
        t = y / half
        b = max(0.02, beam / 2.0 * (1.0 - abs(t) ** 2.2) ** 0.55)
        top = sheer + rise * t * t
        bot = keel * (1.0 - 0.6 * t * t)
        o, i = [], []
        for m in range(around + 1):
            a = math.pi * m / around
            x = -b * math.cos(a)
            z = top - (top - bot) * math.sin(a) ** 0.75
            o.append(bm.verts.new((x, y, z)))
            bi = max(0.0, b - wall)
            zi = top - (top - bot - wall) * math.sin(a) ** 0.75
            i.append(bm.verts.new((-bi * math.cos(a), y, zi)))
        outer.append(o)
        inner.append(i)
    for j in range(stations - 1):
        for m in range(around):
            bm.faces.new((outer[j][m], outer[j + 1][m], outer[j + 1][m + 1], outer[j][m + 1]))
            bm.faces.new((inner[j][m], inner[j][m + 1], inner[j + 1][m + 1], inner[j + 1][m]))
        for m in (0, around):
            bm.faces.new((outer[j][m], inner[j][m], inner[j + 1][m], outer[j + 1][m]))
    for j in (0, stations - 1):
        for m in range(around):
            bm.faces.new((outer[j][m], outer[j][m + 1], inner[j][m + 1], inner[j][m]))
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-4)


def boat(r):
    """A rowing boat 4.4 m long, its waterline at the origin, bow at +Y."""
    solid("lk_boat__hull", r, [WOOD], lambda bm: hull(bm, 4.4, 1.35, 0.32, -0.3))

    def fittings(bm):
        add_box(bm, -0.58, 0.58, -0.25, 0.0, 0.12, 0.17)                      # thwarts
        add_box(bm, -0.5, 0.5, 1.0, 1.22, 0.12, 0.17)
        add_box(bm, -0.42, 0.42, -1.6, -1.25, 0.1, 0.16)                      # stern seat
        add_box(bm, -0.28, 0.28, -1.5, 1.5, -0.2, -0.17)                      # floorboards
        add_obox(bm, (0.15, 0.2, 0.2), (0.07, 3.0, 0.05), (0.0, 0.0, 0.05))   # oars along the boat
        add_obox(bm, (-0.15, 0.1, 0.2), (0.07, 3.0, 0.05), (0.0, 0.0, -0.04))
    solid("lk_boat__fittings", r, [PWOOD], fittings)
    solid("lk_boat__band", r, ["persian_tile"], lambda bm: (add_box(bm, -0.69, -0.66, -1.2, 1.2, 0.2, 0.28),
                                                           add_box(bm, 0.66, 0.69, -1.2, 1.2, 0.2, 0.28)))
    solid("lk_boat__floor-colonly", r, [WOOD], lambda bm: add_box(bm, -0.45, 0.45, -1.6, 1.6, -0.4, -0.17))


def ferry(r):
    """The ferry: 8 m long, 3 m wide, bow at +Y (Godot -Z), its waterline at
    the origin, the deck at 0.3. Railed on the sides and the stern, open at
    the bow (1.4 m), lanterns at the bow and the stern, an awning amidships.
    No collision: LakeFerry gives it its own (it moves)."""
    out = [(-1.5, -3.6), (-1.35, -4.0), (1.35, -4.0), (1.5, -3.6), (1.5, 2.8), (1.0, 4.0), (-1.0, 4.0), (-1.5, 2.8)]
    solid("lk_ferry__hull", r, [WOOD], lambda bm: add_plan_prism(bm, out, -0.45, 0.22))
    solid("lk_ferry__deck", r, [PWOOD], lambda bm: planks(bm, -1.38, 1.38, -3.85, 3.85, 0.3, across=True, width=0.3))

    def rails(bm):
        top = 1.25
        for s in (-1, 1):
            x = 1.42 * s
            for y in (-3.8, -2.6, -1.4, -0.2, 1.0, 2.2):
                add_box(bm, x - 0.05, x + 0.05, y - 0.05, y + 0.05, 0.22, top)
            add_box(bm, x - 0.06, x + 0.06, -3.85, 2.8, top - 0.08, top)
            add_box(bm, x - 0.04, x + 0.04, -3.85, 2.8, 0.7, 0.76)
            add_obox(bm, ((1.42 + 0.95) / 2 * s, 3.4, top - 0.04), (0.08, math.hypot(0.47, 1.2), 0.08),
                     (0.0, 0.0, -math.atan2(0.47, 1.2) * s))
            add_box(bm, 0.7 * s - 0.05, 0.7 * s + 0.05, 3.85, 3.95, 0.22, top)
        add_box(bm, -1.42, 1.42, -3.9, -3.8, top - 0.08, top)
        add_box(bm, -1.42, 1.42, -3.9, -3.8, 0.7, 0.76)
    solid("lk_ferry__rails", r, [PWOOD], rails)

    def benches(bm):
        for s in (-1, 1):
            add_box(bm, 1.0 * s - 0.25, 1.0 * s + 0.25, -2.8, 1.6, 0.6, 0.68)
            for y in (-2.6, -0.6, 1.4):
                add_box(bm, 1.0 * s - 0.2, 1.0 * s + 0.2, y - 0.04, y + 0.04, 0.3, 0.6)
    solid("lk_ferry__benches", r, [PWOOD], benches)

    def awning_posts(bm):
        for x in (-1.3, 1.3):
            for y in (-1.6, 1.4):
                add_box(bm, x - 0.05, x + 0.05, y - 0.05, y + 0.05, 1.25, 2.4)
    solid("lk_ferry__awning_posts", r, [PWOOD], awning_posts)
    solid("lk_ferry__awning", r, ["persian_awning"], lambda bm: add_box(bm, -1.45, 1.45, -1.8, 1.6, 2.4, 2.46))
    fb, gb, pb = bmesh.new(), bmesh.new(), bmesh.new()
    for (x, y, s) in ((1.25, 3.0, -1), (-1.25, -3.55, 1)):
        add_box(pb, x - 0.06, x + 0.06, y - 0.06, y + 0.06, 0.22, 2.75)
        add_box(pb, x - 0.03, x + 0.03 + 0.55 * 0, y - 0.03, y + 0.03, 2.6, 2.66)
        add_box(fb, min(x, x + 0.5 * s) - 0.02, max(x, x + 0.5 * s) + 0.02, y - 0.025, y + 0.025, 2.6, 2.66)
        lantern(fb, gb, x + 0.5 * s, y, 2.25)
    mesh_object("lk_ferry__lantern_posts", pb, [PWOOD], r)
    mesh_object("lk_ferry__lanterns", fb, [IRON], r)
    mesh_object("lk_ferry__glass", gb, ["emit_lantern"], r)
    marker("LIGHT_lake_lantern__bow", r, (0.75, 3.0, 2.25))
    marker("LIGHT_lake_lantern__stern", r, (-0.75, -3.55, 2.25))

    def gear(bm):
        add_lathe(bm, [(0.3, 0.3), (0.32, 0.38), (0.2, 0.42), (0.0, 0.42)], -0.9, -3.3, segs=10)     # a coil of rope
        add_box(bm, 0.5, 1.1, -3.6, -3.1, 0.3, 0.7)                                                  # a chest
    solid("lk_ferry__gear", r, ["net_cord"], gear)


def person(r, name, hip, lean, hands, low=False, robe="gorge_cloth", hood="persian_awning"):
    """A robed figure facing -Y (Godot +Z) (as tools/kit_add_r06.py's)."""
    rb, hd, shade, hb = bmesh.new(), bmesh.new(), bmesh.new(), bmesh.new()
    if low:
        add_lathe(rb, [(0.34, 0.0), (0.36, 0.12), (0.22, hip)], 0.0, 0.1, segs=8)
    else:
        add_lathe(rb, [(0.31, 0.0), (0.27, 0.3), (0.2, hip)], segs=8)
    body = Matrix.Translation((0.0, 0.0, hip)) @ Matrix.Rotation(lean, 4, "X")
    moved(rb, lambda bm: add_lathe(bm, [(0.2, 0.0), (0.21, 0.3), (0.18, 0.48), (0.09, 0.54)], segs=8), body)
    head = body @ Matrix.Translation((0.0, -0.04, 0.48))
    moved(hd, lambda bm: add_lathe(bm, [(0.0, 0.0), (0.18, 0.04), (0.17, 0.2), (0.12, 0.3), (0.0, 0.35)], segs=8), head)
    moved(shade, lambda bm: add_lathe(bm, [(0.0, 0.0), (0.09, 0.02), (0.09, 0.16), (0.0, 0.18)], segs=6),
          head @ Matrix.Translation((0.0, -0.09, 0.16)) @ Matrix.Rotation(math.pi / 2, 4, "X"))
    for k, hx in enumerate((-0.19, 0.19)):
        sh = body @ Vector((hx, 0.0, 0.44))
        hp = Vector(hands[k])
        el = (sh + hp) / 2 + Vector((hx * 0.3, 0.04, -0.02))
        add_tube(rb, [tuple(sh), tuple(el), tuple(hp + Vector((0.0, 0.0, 0.05)))], [0.07, 0.06, 0.055], segs=6)
        moved(hb, lambda bm: add_lathe(bm, [(0.0, -0.045), (0.04, -0.03), (0.036, 0.04), (0.0, 0.045)], segs=5), Matrix.Translation(hp))
    mesh_object(name + "__robe", rb, [robe], r)
    mesh_object(name + "__hood", hd, [hood], r)
    mesh_object(name + "__shade", shade, ["culvert_dark"], r)
    mesh_object(name + "__hands", hb, ["camp_leather"], r)


def ferryman(r):
    """Standing at the stern with his pole, looking ahead."""
    person(r, "lk_ferryman", 0.92, 0.06, [(0.12, -0.3, 1.18), (0.16, -0.26, 0.86)], robe="quarter_cloth", hood="gorge_cloth")
    solid("lk_ferryman__pole", r, [PWOOD], lambda bm: add_obox(bm, (0.15, -0.32, 1.3), (0.05, 0.05, 4.6), (math.radians(-12), math.radians(8), 0.0)))


def nets(r):
    """A drying rack with a net over it and its floats."""
    def rack(bm):
        for x in (0.0, 2.4):
            add_box(bm, x - 0.05, x + 0.05, -0.05, 0.05, 0.0, 1.9)
        add_box(bm, -0.1, 2.5, -0.04, 0.04, 1.82, 1.9)
    solid("lk_nets__rack-col", r, [PWOOD], rack)

    def net(bm):
        uv = bm.loops.layers.uv.new("UVMap")
        from kit_blender import add_card
        add_card(bm, uv, (1.2, 0.06, 0.25), 2.3, 1.6)
        add_card(bm, uv, (1.2, -0.06, 0.45), 2.2, 1.4)
    solid("lk_nets__net", r, ["net_cord"], net, recalc=False)

    def floats(bm):
        for k in range(7):
            moved(bm, lambda b, k=k: add_lathe(b, [(0.0, -0.05), (0.06, -0.03), (0.06, 0.03), (0.0, 0.05)], 0.15 + 0.35 * k, 0.08, segs=6),
                  Matrix.Translation((0.0, 0.0, 1.78)))
    solid("lk_nets__floats", r, ["wicker"], floats)


def traps(r):
    """Three wicker eel traps and a basket."""
    def build(bm):
        for k, (x, y, yaw) in enumerate(((0.0, 0.0, 0.2), (0.7, 0.25, -0.4), (0.25, 0.75, 1.3))):
            prof = [(0.0, 0.0), (0.12, 0.05), (0.2, 0.3), (0.22, 0.6), (0.16, 0.85), (0.07, 0.9)]
            before = set(bm.verts)
            add_lathe(bm, prof, 0.0, 0.0, segs=8)
            vs = [v for v in bm.verts if v not in before]
            m = Matrix.Translation((x, y, 0.22)) @ Matrix.Rotation(yaw, 4, "Z") @ Matrix.Rotation(math.pi / 2, 4, "Y")
            bmesh.ops.transform(bm, matrix=m, verts=vs)
        add_lathe(bm, [(0.0, 0.0), (0.22, 0.0), (0.26, 0.32), (0.0, 0.3)], -0.6, 0.5, segs=8)
    solid("lk_traps__wicker", r, ["wicker"], build)


def crates(r):
    def build(bm):
        add_box(bm, 0.0, 0.7, 0.0, 0.6, 0.0, 0.55)
        add_box(bm, 0.75, 1.35, 0.05, 0.55, 0.0, 0.5)
        add_obox(bm, (0.35, 0.3, 0.8), (0.55, 0.5, 0.5), (0.0, 0.0, 0.3))
    solid("lk_crates__boxes-col", r, [PWOOD], build)
    solid("lk_crates__rope", r, ["net_cord"], lambda bm: add_lathe(bm, [(0.25, 0.0), (0.27, 0.08), (0.16, 0.12), (0.0, 0.12)], 1.0, 0.9, segs=10))
    solid("lk_crates__jar", r, ["earthenware"], lambda bm: add_lathe(bm, [(0.0, 0.0), (0.14, 0.02), (0.2, 0.25), (0.12, 0.48), (0.08, 0.55), (0.0, 0.55)], 1.6, 0.4, segs=8))


def terrace(r):
    """Walk 1 ("a resting/hearth area"): a 6 x 6 m stone terrace off the
    quay's east end, X 0..6, Y 0..6 (the builder puts it at Godot (10, 0, -8)):
    deck at 0, flush with the quay; a hearth, bedrolls and a fishing spot on it."""
    def body(bm):
        add_box(bm, 0.0, 6.0, 0.0, 6.0, BED, -0.08)
    solid("lk_terrace__body-col", r, [STONE], body)
    solid("lk_terrace__paving-col", r, [PAVE], lambda bm: add_box(bm, 0.0, 6.0, 0.0, 6.0, -0.08, 0.0))
    solid("lk_terrace__edge", r, ["persian_rock_dressed"], lambda bm: (add_box(bm, 0.0, 6.25, 6.0, 6.25, BED, 0.06),
                                                                       add_box(bm, 6.0, 6.25, 0.0, 6.0, BED, 0.06)))
    bollards(r, "lk_terrace", [(5.6, 5.6)])


def fishing_spot(r):
    """Walk 1 ("fishing areas"): a stool, a rod on a forked rest with its line
    in the water, a bucket and a tackle box. Origin on a deck's edge, the
    water toward +Y (Godot -Z). Marked for fishing later (group fishing_spot)."""
    def stool(bm):
        add_box(bm, -0.22, 0.22, -0.92, -0.58, 0.36, 0.42)
        for (x, y) in [(-0.16, -0.86), (0.16, -0.86), (0.0, -0.62)]:
            add_lathe(bm, [(0.03, 0.0), (0.03, 0.37)], x, y, segs=5)
    solid("lk_fishing_spot__stool", r, [WOOD], stool)

    def rod(bm):
        add_tube(bm, [Vector((0.28, -0.75, 0.32)), Vector((0.35, 0.1, 0.62)), Vector((0.46, 1.6, 1.35)), Vector((0.55, 3.1, 2.05))],
                 [0.025, 0.02, 0.012, 0.006], segs=5)
        add_tube(bm, [Vector((0.35, 0.05, 0.0)), Vector((0.35, 0.05, 0.5))], 0.025, segs=5)      # the rest
        add_tube(bm, [Vector((0.35, 0.05, 0.5)), Vector((0.29, 0.05, 0.66))], 0.018, segs=4)
        add_tube(bm, [Vector((0.35, 0.05, 0.5)), Vector((0.41, 0.05, 0.66))], 0.018, segs=4)
    solid("lk_fishing_spot__rod", r, [WOOD], rod)
    solid("lk_fishing_spot__line", r, ["net_cord"], lambda bm: add_tube(bm, [Vector((0.55, 3.1, 2.05)), Vector((0.62, 3.25, WATER - 0.2))], 0.006, segs=3))
    solid("lk_fishing_spot__float", r, ["persian_awning"], lambda bm: add_lathe(bm, [(0.0, WATER - 0.05), (0.05, WATER), (0.0, WATER + 0.07)], 0.62, 3.25, segs=6))
    solid("lk_fishing_spot__bucket", r, [PWOOD], lambda bm: add_lathe(bm, [(0.0, 0.0), (0.16, 0.0), (0.19, 0.32), (0.15, 0.32), (0.13, 0.04), (0.0, 0.04)],
                                                                    -0.55, -0.5, segs=10))
    solid("lk_fishing_spot__box", r, [PWOOD], lambda bm: add_obox(bm, (-0.45, -1.05, 0.11), (0.42, 0.26, 0.22), (0.0, 0.0, 0.25)))


def landing_quay(r):
    """A far landing's quay, X 0..10, Y 0..6: deck (Y 0..2.5) at 0, steps down
    0.9 (Y 2.5..4), the stage (Y 4..6) the ferry's bow meets at X 5."""
    def body(bm):
        add_box(bm, 0.0, 10.0, -0.5, 2.5, BED, -0.08)
        add_box(bm, 0.0, 10.0, 4.0, 6.0, BED, STAGE)
    solid("lk_landing_quay__body-col", r, [STONE], body)

    def steps(bm):        # seen, not walked: the ramp under them carries you
        tread = 1.5 / 4.0
        for k in range(1, 5):
            add_box(bm, 0.0, 10.0, 2.5 + (k - 1) * tread, 2.5 + k * tread, BED, -0.225 * k)
    solid("lk_landing_quay__steps", r, [STONE], steps)
    t = 1.5 / 4.0
    ramp(r, "lk_landing_quay", 0.0, 10.0, [(2.5, 0.0), (4.0 - t / 2.0, -0.9)])
    solid("lk_landing_quay__paving-col", r, [PAVE], lambda bm: add_box(bm, 0.0, 10.0, -0.5, 2.5, -0.08, 0.0))
    solid("lk_landing_quay__edge", r, ["persian_rock_dressed"], lambda bm: (add_box(bm, -0.25, 0.0, -0.5, 6.0, BED, 0.0),
                                                                          add_box(bm, 10.0, 10.25, -0.5, 6.0, BED, 0.0)))
    bollards(r, "lk_landing_quay", [(0.6, 5.6), (9.4, 5.6)])


def rubble(r):
    rng = random.Random(7)

    def build(bm):
        for _k in range(26):
            x, y = rng.uniform(0.0, 6.0), rng.uniform(0.0, 3.0)
            s = rng.uniform(0.25, 1.0)
            add_obox(bm, (x, y, s * 0.25), (s, s * rng.uniform(0.6, 1.1), s * rng.uniform(0.4, 0.8)),
                     (rng.uniform(-0.3, 0.3), rng.uniform(-0.3, 0.3), rng.uniform(0, math.pi)))
    solid("lk_rubble__stones", r, [STONE], build)


# ---------------------------------------------------------------- the harbour (revised phase 18)
#
# The home harbour after the Ali-Sadr pictures (design/reference images/caves/):
# a low chamber round the quay, pier and boathouses, roofed in layered
# limestone that steps down in sloping sheets to an undercut waterline, with
# two channels leading out: a lit one (the ferry's, step 2) and a dark one
# whose roof sinks almost to the water. Everything here is in GODOT plan
# coordinates (gx, gz) and converted at the end: Blender (gx, -gz, y).

LIME = "limestone"
H_LIT = [(8.0, -46.0), (9.0, -60.0), (16.0, -76.0), (30.0, -90.0), (44.0, -98.0)]
H_DARK = [(-17.0, -36.0), (-29.0, -43.0), (-38.0, -55.0), (-44.0, -70.0)]
# Walk 2: "any light not on the pier: glowing fungi, a different colour in
# each part". Rock ledges just out of the water with upright glowing
# mushrooms on them, brackets on the rock behind, strands hanging from the
# roof over them, and a light of their colour (Godot gx, gz, glow colour).
# The two at the lit channel's mouth took the old lantern plinths' places.
H_GLOW = [(20.4, -31.0, "amber"), (-11.55, -49.3, "violet"), (-22.45, -23.95, "lime"),
          (2.4, -57.5, "teal"), (15.6, -59.0, "teal")]
GLOW_MAT = {"amber": "emit_lake_glow_amber", "violet": "emit_lake_glow_violet",
            "lime": "emit_lake_glow_lime", "teal": "emit_lake_glowcap"}
GLOW_LIGHT = {"amber": (1.0, 0.56, 0.2), "violet": (0.68, 0.42, 1.0),
              "lime": (0.62, 0.95, 0.36), "teal": (0.3, 0.92, 0.84)}
# What stands in the harbour (Godot x0, x1, z0, z1): the quay, boardwalk,
# boathouses and terrace along the back; the pier out to its head.
H_QUAY = (-20.0, 15.0, -19.0, -1.0)
H_PIER = (3.5, 12.5, -42.0, -12.0)
H_FERRY = [(8.0, -40.0), (8.0, -54.0)] + H_LIT[1:3]


def rect_out(x, z, rc):
    x0, x1, z0, z1 = rc
    return math.hypot(max(x0 - x, 0.0, x - x1), max(z0 - z, 0.0, z - z1))


def seg_dist(px, pz, a, b):
    ax, az = a
    bx, bz = b
    dx, dz = bx - ax, bz - az
    t = max(0.0, min(1.0, ((px - ax) * dx + (pz - az) * dz) / (dx * dx + dz * dz)))
    return math.hypot(px - ax - dx * t, pz - az - dz * t), t


def poly_dist(px, pz, pts):
    """(distance to the polyline, fraction along it 0..1)."""
    best, at, run = 1e9, 0.0, 0.0
    lens = [math.hypot(pts[i + 1][0] - pts[i][0], pts[i + 1][1] - pts[i][1]) for i in range(len(pts) - 1)]
    total = sum(lens)
    for i in range(len(pts) - 1):
        d, t = seg_dist(px, pz, pts[i], pts[i + 1])
        if d < best:
            best, at = d, (run + t * lens[i]) / total
        run += lens[i]
    return best, at


def smax(a, b, k=4.0):
    h = max(0.0, min(1.0, 0.5 + 0.5 * (a - b) / k))
    return b + (a - b) * h + k * h * (1.0 - h)


def h_noise(x, z, f, seed):
    return noise.noise((x * f, z * f, seed))


def h_inside(x, z):
    """How far inside the harbour's water (m; negative in the rock), and the
    roof's height over the water there. While a dock chamber is built
    (SHAPE set, phase 18 step 2), that chamber's shape instead."""
    if SHAPE is not None:
        return SHAPE["inside"](x, z)
    # The main chamber: a lumpy round.
    dx, dz = (x + 1.0) / 25.0, (z + 31.0) / 24.0
    r = math.hypot(dx, dz)
    s_main = (1.0 - r) * 24.0 + 3.5 * h_noise(x, z, 0.06, 3.0) + 1.5 * h_noise(x, z, 0.17, 8.0)
    # The strip along the back wall: the quay, boardwalk, boathouses, terrace.
    bx = min(x - (-25.0), 23.0 - x)
    bz = min(4.0 - z, z - (-25.0))
    s_back = min(bx, bz) + 1.2 * h_noise(x, z, 0.15, 5.0)
    d_lit, _t = poly_dist(x, z, H_LIT)
    s_lit = 6.5 - d_lit + 1.0 * h_noise(x, z, 0.2, 12.0)
    d_dark, t_dark = poly_dist(x, z, H_DARK)
    s_dark = 4.5 - d_dark + 0.8 * h_noise(x, z, 0.2, 14.0)
    s = smax(smax(s_main, s_back), s_lit)

    def roof(sv, top=5.2, fall=3.2):
        if sv >= 0.0:
            return 1.2 + top * (1.0 - math.exp(-sv / fall))
        return 1.2 + 3.2 * sv

    h = roof(s)
    # The dark channel: its roof sinks from about 4 m at its mouth to a
    # metre over the water.
    hd = roof(s_dark, top=4.2 - 3.4 * smooth01(t_dark * 1.6), fall=2.0)
    if s_dark > s:
        h = smax(h, hd, 1.5) if s > -1.0 else hd
    else:
        h = smax(h, hd, 1.5)
    return max(s, s_dark), h


def h_clear(x, z):
    """The lowest the roof may come (over the water) for what stands or moves there."""
    if SHAPE is not None:
        return SHAPE["clear"](x, z)
    # Walk 2 ("still too flat"): the clearance hugs what stands there and
    # falls away round it, so over open water the roof can come down in
    # masses to the water.
    need = 6.2 - 0.9 * max(0.0, rect_out(x, z, H_QUAY) - 1.0)            # quay, boathouses, terrace
    need = max(need, 6.2 - 0.9 * max(0.0, rect_out(x, z, H_PIER) - 1.0))  # the pier and its boats
    d, _t = poly_dist(x, z, H_FERRY)
    need = max(need, 4.8 - 0.9 * max(0.0, d - 5.0))                      # the ferry's water out to the channel
    for (sx, sz, _c) in H_GLOW:
        if math.hypot(x - sx, z - sz) < 2.2:
            need = max(need, 3.2)                     # head room over a glow ledge
    return need


def h_roof(x, z):
    s, h = h_inside(x, z)
    clear = h_clear(x, z)
    if s > 0.6:
        # Pockets rising into the rock between the sheets, so the roof over
        # the quay is never a flat lid at its clearance.
        k = smooth01((s - 0.6) / 4.0)
        h = max(h, clear) + k * (3.8 * max(0.0, h_noise(x, z, 0.07, 26.0) + 0.2)
                                 + 1.6 * max(0.0, h_noise(x, z, 0.16, 27.0)))
        # Layered sheets: the height stepped in tilted bands (sloping bedding
        # planes), flowstone masses hanging below.
        tilt = 0.12 * x + 0.07 * z + 0.9 * h_noise(x, z, 0.05, 21.0)
        q = (h + tilt) / 0.9
        stepped = (math.floor(q) + smooth01((q - math.floor(q) - 0.82) / 0.18)) * 0.9 - tilt
        h = h + (stepped - h) * 0.95
        lump = (max(0.0, h_noise(x, z, 0.11, 30.0) - 0.08) * 5.5 + max(0.0, h_noise(x, z, 0.23, 31.0) - 0.25) * 2.5
                + max(0.0, h_noise(x, z, 0.05, 32.0) + 0.1) * 3.0)
        h -= lump * smooth01((s - 1.0) / 3.0)
        h = max(h, -0.6)                              # a mass may meet the water, not dive through the bed
    if s <= 0.0:
        return h
    # Walk 3 ("still too many flat sections"): where the clearance holds the
    # roof up it is never a flat lid: domes and scallops rise into the rock
    # from the clearance line, and the stepped sheets show through them.
    relief = (0.5 + 2.2 * max(0.0, h_noise(x, z, 0.12, 33.0) + 0.1) + 0.9 * abs(h_noise(x, z, 0.3, 34.0))
              + 0.6 * smooth01((((x * 0.12 + z * 0.07) / 0.9) % 1.0 - 0.75) / 0.25))
    return max(h, clear + relief * smooth01((clear - h + 0.5) / 1.5) * smooth01(clear / 1.5))


def chamber(r, P):
    """A natural chamber's rock (roof, walls, bed), boulders, stalagmites,
    stalactites and glowing fungi, from the current h_inside / h_clear and the
    spec P (HARBOUR_P, or a dock's: phase 18 step 2)."""
    pre = P["prefix"]
    xa, xb, za, zb = P["sample"]
    step = 0.8
    x0, x1, z0, z1 = P["bounds"]
    nx, nz = int((x1 - x0) / step), int((z0 - z1) / step)
    s_at = {}
    bm = bmesh.new()
    verts = {}
    for i in range(nx + 1):
        for j in range(nz + 1):
            x, z = x0 + i * step, z0 - j * step
            s, _h = h_inside(x, z)
            s_at[(i, j)] = s
            y = WATER + h_roof(x, z)
            # The undercut: round the waterline the rock is eaten back into a notch.
            k = smooth01(1.0 - abs(y - (WATER + 0.2)) / 1.4)
            if k > 0.0 and -3.0 < s < 1.0:
                e = 0.4
                sx = (h_inside(x + e, z)[0] - h_inside(x - e, z)[0]) / (2 * e)
                sz = (h_inside(x, z + e)[0] - h_inside(x, z - e)[0]) / (2 * e)
                g = math.hypot(sx, sz) or 1.0
                x, z = x - sx / g * 1.1 * k, z - sz / g * 1.1 * k
            verts[(i, j)] = (x, z, y)
    vs = {}
    for i in range(nx):
        for j in range(nz):
            quad = [(i, j), (i + 1, j), (i + 1, j + 1), (i, j + 1)]
            if max(s_at[q] for q in quad) < -4.5:
                continue                              # deep in the rock
            for q in quad:
                if q not in vs:
                    gx, gz, y = verts[q]
                    vs[q] = bm.verts.new((gx, -gz, y))
            bm.faces.new([vs[quad[0]], vs[quad[3]], vs[quad[2]], vs[quad[1]]])     # facing down
    bm.normal_update()
    # Walk 2 ("sediment layers belong on the walls"): faces looking down
    # take the plain flowstone; the risers between the sheets and the walls
    # keep the bands.
    for f in bm.faces:
        f.material_index = 1 if f.normal.z < -0.72 else 0
    bvh = BVHTree.FromBMesh(bm)
    roof_faces = surfaces(bm)
    mesh_object(pre + "__rock-col", bm, [LIME, "limestone_roof"], r, recalc=False)

    # The bed: shelving rock a metre under the water at the walls, deep in the middle.
    bb = bmesh.new()
    bstep = 1.6
    bv = {}
    mx, mz = int((x1 - x0) / bstep), int((z0 - z1) / bstep)
    for i in range(mx):
        for j in range(mz):
            quad = [(i, j), (i + 1, j), (i + 1, j + 1), (i, j + 1)]
            ss = [h_inside(x0 + a * bstep, z0 - b * bstep)[0] for (a, b) in quad]
            if max(ss) < -3.0:
                continue
            for (a, b) in quad:
                if (a, b) not in bv:
                    x, z = x0 + a * bstep, z0 - b * bstep
                    s = h_inside(x, z)[0]
                    y = WATER - 1.0 - 4.6 * smooth01(s / 7.0) + 0.4 * h_noise(x, z, 0.2, 40.0)
                    bv[(a, b)] = bb.verts.new((x, -z, y))
            bb.faces.new([bv[quad[0]], bv[quad[1]], bv[quad[2]], bv[quad[3]]])      # facing up
    mesh_object(pre + "__bed-col", bb, [LIME], r, recalc=False)

    rng = random.Random(118)
    # Boulders and ledges along the waterline, and a few out in the water;
    # none on the ferry's water or by the quay.
    fm = bmesh.new()
    ferry_path = P["ferry_path"]
    placed = [(gx, gz) for (gx, gz, _c) in P["glow"]]  # boulders keep clear of the glow ledges
    for _k in range(1400):
        if len(placed) >= P["boulders"]:
            break
        x, z = rng.uniform(xa, xb), rng.uniform(za, zb)
        s, _h = h_inside(x, z)
        out_in_water = 4.0 < s < 9.0 and rng.random() < 0.15
        if not (-0.5 < s < 2.5 or out_in_water):
            continue
        if P["skip"](x, z):
            continue
        if poly_dist(x, z, ferry_path)[0] < 7.5 or poly_dist(x, z, P["dark"])[0] < 2.0:
            continue
        if any(math.hypot(x - p[0], z - p[1]) < 3.5 for p in placed):
            continue
        g = rng.uniform(0.8, 2.6) if not out_in_water else rng.uniform(1.6, 3.4)
        top = WATER + rng.uniform(0.15, 1.1)
        spire(fm, x, -z, -7.0, top - 0.3, [g * 1.3, g * 1.15, g, g * 0.8, g * 0.5], rng, segs=8,
              tip=(x + rng.uniform(-0.3, 0.3) * g, -z + rng.uniform(-0.3, 0.3) * g, top), lean=0.05)
        placed.append((x, z))
    n_boulders = len(placed) - len(P["glow"])
    for (x, z, _c) in P["glow"]:                       # the glow ledges, low and nearly flat-topped
        spire(fm, x, -z, -7.0, WATER + 0.45, [1.9, 1.7, 1.55, 1.4], rng, segs=9, lean=0.0)
    # Walk 2 ("some stalagmites in the water"): clusters of pointed rock
    # rising out of the open water, off the ferry's water, the pier and quay.
    n_mites = 0
    for _k in range(3000):
        if n_mites >= P["mites"]:
            break
        cx, cz = rng.uniform(xa + 8.0, xb - 8.0), rng.uniform(za + 10.0, zb - 2.0)
        s, _h = h_inside(cx, cz)
        if not 1.2 < s < 10.0:
            continue
        if (poly_dist(cx, cz, P["ferry"])[0] < 7.5 or rect_out(cx, cz, P["pier"]) < 3.0
                or rect_out(cx, cz, P["quay"]) < 3.0 or poly_dist(cx, cz, P["dark"])[0] < 2.5
                or any(math.hypot(cx - gx, cz - gz) < 4.0 for (gx, gz, _c) in P["glow"])):
            continue
        for _j in range(rng.randint(1, 3)):
            x, z = cx + rng.uniform(-1.6, 1.6), cz + rng.uniform(-1.6, 1.6)
            g = rng.uniform(0.35, 1.0)
            top = WATER + rng.uniform(0.5, 3.2) * (0.6 + g * 0.6)
            roof = WATER + h_roof(x, z)
            top = min(top, roof - 0.6)
            if top < WATER + 0.3:
                continue
            spire(fm, x, -z, -7.0, top, [g * 1.6, g * 1.3, g, g * 0.6, g * 0.3], rng, segs=7,
                  tip=(x + rng.uniform(-0.1, 0.1), -z + rng.uniform(-0.1, 0.1), top + 0.25 * g), lean=0.03)
            n_mites += 1
    bmesh.ops.recalc_face_normals(fm, faces=fm.faces)
    form_faces = surfaces(fm)
    mesh_object(pre + "__boulders-col", fm, [LIME], r, recalc=False)

    # Curtains of short stalactites along the edges of the roof's sheets.
    sb = bmesh.new()
    n_st = 0
    for _k in range(5000):
        if n_st >= P["curtains"]:
            break
        x, z = rng.uniform(xa, xb), rng.uniform(za, zb)
        s, _h = h_inside(x, z)
        if s < 1.5:
            continue
        e = 0.5
        a, b = h_roof(x + e, z), h_roof(x - e, z)
        c, d = h_roof(x, z + e), h_roof(x, z - e)
        if math.hypot(a - b, c - d) / (2 * e) < 0.9:
            continue                                  # not on a sheet's edge
        hit = bvh.ray_cast(Vector((x, -z, WATER + 0.2)), Vector((0.0, 0.0, 1.0)), 40.0)
        if hit[0] is None:
            continue
        h = hit[0].z
        ln = rng.uniform(0.4, 2.2)
        floor_y = WATER + max(h_clear(x, z), 1.5)
        if h - ln < floor_y:
            ln = h - floor_y
        if ln < 0.3:
            continue
        w = rng.uniform(0.12, 0.4)
        for kk in range(rng.randint(1, 4)):
            ox, oz = rng.uniform(-0.6, 0.6), rng.uniform(-0.6, 0.6)
            lk = ln * rng.uniform(0.5, 1.0)
            spire(sb, x + ox, -z + oz, h + 0.6, h - lk, [w * 1.3, w, w * 0.5], rng, segs=5,
                  tip=(x + ox, -z + oz, h - lk - 0.15))
        n_st += 1
    # Walk 2 ("more organic, stalactites"): big ones hanging from the roof,
    # long where there is room (to near the water over open water), each
    # with a few small ones round its root.
    n_big = 0
    for _k in range(6000):
        if n_big >= P["big"]:
            break
        x, z = rng.uniform(xa, xb), rng.uniform(za, zb)
        s, _h = h_inside(x, z)
        if s < 1.5:
            continue
        hit = bvh.ray_cast(Vector((x, -z, WATER + 0.2)), Vector((0.0, 0.0, 1.0)), 40.0)
        if hit[0] is None:
            continue
        h = hit[0].z
        room = h - (WATER + max(h_clear(x, z), 0.6))
        if room < 1.2:
            continue
        ln = min(room, rng.uniform(1.2, 5.5))
        w = rng.uniform(0.3, 0.75) * (0.7 + 0.15 * ln)
        spire(sb, x, -z, h + 0.8, h - ln, [w * 1.7, w * 1.2, w * 0.75, w * 0.45, w * 0.2], rng, segs=7,
              tip=(x + rng.uniform(-0.1, 0.1), -z + rng.uniform(-0.1, 0.1), h - ln - 0.2), lean=0.02)
        for _j in range(rng.randint(2, 5)):
            ox, oz = rng.uniform(-1.2, 1.2), rng.uniform(-1.2, 1.2)
            lk = min(room, ln) * rng.uniform(0.15, 0.5)
            ww = w * rng.uniform(0.25, 0.5)
            spire(sb, x + ox, -z + oz, h + 0.6, h - lk, [ww * 1.3, ww, ww * 0.4], rng, segs=5,
                  tip=(x + ox, -z + oz, h - lk - 0.12))
        n_big += 1
    bmesh.ops.recalc_face_normals(sb, faces=sb.faces)
    hang_faces = surfaces(sb)
    mesh_object(pre + "__stalactites", sb, [LIME], r, recalc=False)

    dark_place = P["dark_place"]
    gb = bmesh.new()
    strands = bmesh.new()
    grng = random.Random(119)
    glowcaps(gb, roof_faces + form_faces + hang_faces, P["colonies"], grng, 5.0, patchy=-1.0, avoid=dark_place, stalks=strands)

    # The glow ledges: upright mushrooms on the ledge, brackets on the rock
    # behind, strands hanging from the roof over them, a light of their colour.
    glows = {c: bmesh.new() for c in GLOW_MAT}
    stems = bmesh.new()
    for i, (gx, gz, colour) in enumerate(P["glow"]):
        out = glows[colour]
        top = WATER + 0.45
        for _j in range(grng.randint(4, 7)):
            a, d = grng.uniform(0.0, 2 * math.pi), grng.uniform(0.0, 1.1)
            upright_mushroom(out, stems, gx + math.cos(a) * d, -gz + math.sin(a) * d, top - 0.05,
                             grng.uniform(0.35, 1.5), (grng.uniform(-0.12, 0.12), grng.uniform(-0.12, 0.12)), grng)
        c = Vector((gx, -gz, top + 1.0))
        near = [f for f in roof_faces + form_faces + hang_faces if (f[0] - c).length < 5.0 and f[0].z > WATER + 0.4]
        for _j in range(12):
            if not near:
                break
            fc, fn, _a = near[grng.randrange(len(near))]
            cap_cluster(out, fc, fn, grng, grng.randint(3, 7), 0.45, 1.0, stalks=stems)
        marker("LIGHT_lake_glow__ledge_%d" % i, r, (gx, -gz, top + 1.4),
               {"color": list(GLOW_LIGHT[colour]), "range": 10.0, "energy": 3.2})
    for c, out in glows.items():
        if len(out.verts) > 0:
            mesh_object(pre + "__glow_" + c, out, [GLOW_MAT[c]], r)
    mesh_object(pre + "__glowcaps", gb, ["emit_lake_glowcap"], r)
    mesh_object(pre + "__strands", strands, ["persian_fungus_stalk"], r)
    mesh_object(pre + "__stems", stems, ["persian_fungus_stalk"], r)
    print("kit_add_r20: %s: " % pre + "%d boulders, %d stalagmites, %d stalactite curtains, %d big stalactites"
          % (n_boulders, n_mites, n_st, n_big))


def _harbour_dark(c):
    """Teal caps only in the dark: the dark channel, the lit channel past its
    bend, and the far west corner, never beside a lantern (True: no caps here)."""
    x, z = c.x, -c.y
    if poly_dist(x, z, H_DARK)[0] < 8.0:
        return False
    lit_d, lit_t = poly_dist(x, z, H_LIT)
    if lit_d < 9.0 and lit_t > 0.5:
        return False
    return True


HARBOUR_P = {
    "prefix": "lk_harbour", "bounds": (-52.0, 52.0, 6.0, -104.0), "sample": (-48.0, 48.0, -100.0, 2.0),
    "skip": lambda x, z: -21.0 < x < 18.0 and -44.0 < z < -4.0,
    "ferry_path": [(8.0, -38.0), (8.0, -56.0)] + H_LIT[1:3], "ferry": H_FERRY,
    "glow": H_GLOW, "dark": H_DARK, "pier": H_PIER, "quay": H_QUAY,
    "boulders": 46, "mites": 26, "curtains": 150, "big": 60, "colonies": 22, "dark_place": _harbour_dark,
}
# The chamber being built when it is not the harbour (h_inside / h_clear ask it).
SHAPE = None


def harbour(r):
    chamber(r, HARBOUR_P)


# ---------------------------------------------------------------- a dock (phase 18 step 2)
#
# A dock chamber, in its own frame (Godot plan coordinates, as the harbour):
# the house front (or a grotto's mouth) along X at Z 0, a stone strip in
# front of it (Z 0.5..-3) with the landing quay in its middle (X -5..5, its
# stage edge at Z -6, the ferry lying off it toward -Z), a small round
# chamber of water, and a channel bending away west out of sight into fog.
# The roof rises into a tall alcove over the house front (its storeys 12, 8
# and 4 m high toward the ends) and comes down low over the water round it.
# build_lake.gd places it far from the harbour; LakeLayout.DOCKS has its frame.

D_CH = [(0.0, -16.0), (-1.0, -27.0), (-7.0, -38.0), (-19.0, -47.0), (-34.0, -52.0)]
D_FERRY = [(0.0, -6.0), (0.0, -16.0)] + D_CH[1:]
D_GLOW = [(-15.5, -15.0, "violet"), (15.0, -16.0, "amber"), (4.2, -28.0, "teal"), (-10.3, -46.1, "teal")]
D_STRIP = (-18.5, 18.5, -9.0, 3.0)


def dock_inside(x, z):
    dx, dz = x / 19.0, (z + 13.0) / 11.0
    s_main = (1.0 - math.hypot(dx, dz)) * 12.0 + 2.5 * h_noise(x, z, 0.06, 53.0) + 1.2 * h_noise(x, z, 0.17, 58.0)
    s_back = min(x + 18.5, 18.5 - x, 7.0 - z, z + 9.0) + 0.8 * h_noise(x, z, 0.15, 55.0)
    d, _t = poly_dist(x, z, D_CH)
    s_ch = 6.0 - d + 1.0 * h_noise(x, z, 0.2, 62.0)
    s = smax(smax(s_main, s_back), s_ch)
    h = 1.2 + 5.2 * (1.0 - math.exp(-s / 3.2)) if s >= 0.0 else 1.2 + 3.2 * s
    return s, h


def dock_clear(x, z):
    need = 6.2 - 0.9 * max(0.0, rect_out(x, z, D_STRIP) - 1.0)          # the strip, quay and stage
    d, _t = poly_dist(x, z, D_FERRY)
    need = max(need, 4.8 - 0.9 * max(0.0, d - 5.0))                     # the ferry's water and channel
    ax = abs(x)
    if ax < 17.5 and z > -9.0:
        # The house front: its storeys reach 12 m (and a dome) in the middle,
        # 8 m then 4 m toward the ends; in front the alcove falls to the quay's.
        vault = 17.5 - 4.0 * smooth01((ax - 8.5) / 1.5) - 4.5 * smooth01((ax - 12.5) / 1.5)
        vault -= (vault - 6.2) * smooth01((-2.0 - z) / 5.0)
        need = max(need, vault)
    for (gx, gz, _c) in D_GLOW:
        if math.hypot(x - gx, z - gz) < 2.2:
            need = max(need, 3.2)
    return need


def _dock_dark(c):
    """Teal caps only down the channel, past its first bend."""
    d, t = poly_dist(c.x, -c.y, D_CH)
    return not (d < 9.0 and t > 0.3)


DOCK_P = {
    "prefix": "lk_dock_a", "bounds": (-46.0, 26.0, 9.0, -62.0), "sample": (-44.0, 24.0, -60.0, 6.0),
    "skip": lambda x, z: abs(x) < 20.0 and z > -20.0,
    "ferry_path": D_FERRY, "ferry": D_FERRY, "glow": D_GLOW,
    "dark": [(900.0, 900.0), (901.0, 901.0)], "pier": (-3.0, 3.0, -16.0, -6.0), "quay": D_STRIP,
    "boulders": 18, "mites": 10, "curtains": 60, "big": 24, "colonies": 9, "dark_place": _dock_dark,
}


def dock_a(r):
    """The first dock chamber (the Mahaleh's in step 2; every dock style's in step 3)."""
    global SHAPE
    SHAPE = {"inside": dock_inside, "clear": dock_clear}
    try:
        for (gx, gz, c) in D_GLOW:
            print("kit_add_r20: dock glow %s at (%.1f, %.1f): inside %.2f" % (c, gx, gz, dock_inside(gx, gz)[0]))
        chamber(r, DOCK_P)
    finally:
        SHAPE = None

    # The stone strip along the house front, either side of the landing quay.
    def strip(bm):
        for (a, b) in ((-18.5, -5.25), (5.25, 18.5)):
            add_box(bm, a, b, -0.5, 3.0, BED, -0.08)
    solid("lk_dock_a__strip-col", r, [STONE], strip)
    solid("lk_dock_a__paving-col", r, [PAVE], lambda bm: [add_box(bm, a, b, -0.5, 2.95, -0.08, 0.0)
                                                           for (a, b) in ((-18.5, -5.25), (5.25, 18.5))])
    solid("lk_dock_a__coping", r, ["persian_rock_dressed"], lambda bm: [add_box(bm, a, b, 2.95, 3.25, BED, 0.02)
                                                                        for (a, b) in ((-18.5, -5.25), (5.25, 18.5))])


MODULES = [
    ("M_lk_cavern", props("free", [0, 0, 0], "", "rock,cavern,r20,scenery"), cavern),
    ("M_lk_bed", props("free", [0, 0, 0], "", "rock,cavern,r20"), bed),
    ("M_lk_headland", props("free", [0, 0, 0], "", "rock,cavern,r20"), headland),
    ("M_lk_back_wall", props("free", [0, 0, 0], "", "rock,cavern,r20"), back_wall),
    ("M_lk_quay", props("free", [4, 1, 2], "", "stone,quay,r20"), quay),
    ("M_lk_shelf", props("free", [3, 0, 1], "", "stone,water,r20"), shelf),
    ("M_lk_pier_4m", props("free", [0, 0, 1], "", "wood,pier,r20"), pier_bay),
    ("M_lk_pier_head", props("free", [1, 0, 1], "", "wood,pier,r20"), pier_head),
    ("M_lk_boardwalk_4m", props("free", [1, 0, 0], "", "wood,pier,r20"), boardwalk),
    ("M_lk_boathouse", props("free", [1, 1, 2], "", "wood,boathouse,r20,light"), boathouse),
    ("M_lk_lantern_post", props("free", [0, 0, 0], "", "light,lantern,r20"), lantern_post),
    ("M_lk_bell", props("free", [0, 0, 0], "", "brass,r20"), bell),
    ("M_lk_boat", props("free", [0, 0, 0], "", "wood,boat,r20"), boat),
    ("M_lk_ferry", props("free", [0, 0, 0], "", "wood,boat,r20,light"), ferry),
    ("M_lk_ferryman", props("free", [0, 0, 0], "", "figure,r20"), ferryman),
    ("M_lk_nets", props("free", [0, 0, 0], "", "dressing,r20"), nets),
    ("M_lk_traps", props("free", [0, 0, 0], "", "dressing,r20"), traps),
    ("M_lk_crates", props("free", [0, 0, 0], "", "dressing,r20"), crates),
    ("M_lk_landing_quay", props("free", [0, 0, 0], "", "stone,quay,r20"), landing_quay),
    ("M_lk_rubble", props("free", [0, 0, 0], "", "dressing,r20"), rubble),
    ("M_lk_terrace", props("free", [0, 0, 0], "", "stone,quay,r20"), terrace),
    ("M_lk_fishing_spot", props("free", [0, 0, 0], "", "dressing,fishing,r20"), fishing_spot),
    ("M_lk_harbour", props("free", [0, 0, 0], "", "rock,cavern,r20"), harbour),
    ("M_lk_dock_a", props("free", [0, 0, 0], "", "rock,cavern,dock,r20"), dock_a),
]
# Modules placed at the Godot origin keep their own coordinates (the export
# moves each module's root to the origin, so these roots stay there).
AT_ORIGIN = {"M_lk_cavern", "M_lk_bed", "M_lk_headland", "M_lk_harbour", "M_lk_dock_a"}

# Script-made modules remade in place at a new revision (kit_blender.rebuild).
# (module, rev): rebuilt when the .blend has an older rev.
REBUILD = [("M_lk_quay", 4), ("M_lk_pier_head", 3), ("M_lk_landing_quay", 3),
           ("M_lk_cavern", 3), ("M_lk_bed", 2), ("M_lk_headland", 3), ("M_lk_back_wall", 6),
           ("M_lk_harbour", 7), ("M_lk_boathouse", 3)]
# quay, pier head, landing quay: rev 2 steps walked on hidden ramps, rev 3 ramps flush with the deck edge.
# quay: rev 4 (walk 2) paving stops short of the steps' coping. back wall: rev 5 (walk 2) swells, ledges, lean.
# cavern, bed, headland, back wall: rev 2 (walk 1) an organic cavern, formations, glowing caps, grottos.
# boathouse: rev 2 (walk 4) flat store roof, no gables; rev 3 (walk 5) open window, no pane.
# harbour: rev 2 a lower roof (5-7 m) in sharp-stepped sheets, caps only in the channels; rev 3 pockets over the clearance; rev 4 far-shore lantern plinths; rev 7 (walk 3) relief above the clearance; rev 5 (walk 2) soft clearance, plain roof undersides, big stalactites, stalagmites, coloured glow ledges, hanging strands.


def main():
    if os.path.exists(BLEND):
        bpy.ops.wm.open_mainfile(filepath=BLEND)
    else:
        bpy.ops.wm.read_factory_settings(use_empty=True)
    added = []
    x = 0.0
    for (name, p, build) in MODULES:
        if bpy.data.objects.get(name) is None:
            loc = (0.0, 0.0, 0.0) if name in AT_ORIGIN else (x, ROW_Y, 0.0)
            build(module(name, loc, p))
            added.append(name)
        x += 30.0
    rebuilt = ["%s (rev %d)" % (n, v) for (n, v) in REBUILD if rebuild(n, v, MODULES)]
    if not added and not rebuilt:
        print("kit_add_r20: everything already present; nothing to do.")
        return
    os.makedirs(os.path.dirname(BLEND), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=BLEND)
    print("kit_add_r20: added %s; rebuilt %s" % (", ".join(added) or "nothing", ", ".join(rebuilt) or "nothing"))


main()

"""Seeds the R04 Grand Bazaar modules into art_src/kit/kit_bazaar.blend
(phase 15, docs/environment/phase-15-approval.md).

  blender --background --factory-startup --python tools/kit_add_r04.py

Creates kit_bazaar.blend if it doesn't exist, then adds only the modules that
are not in it yet (hand edits are kept), and remakes those in REBUILD. Then run
tools/export_kit.bat kit_bazaar.blend.

The room (BazaarGrammar, scripts/gen/bazaar_grammar.gd): a 16 m domed crossing
with shop streets off it. Each street is 8 m between its shop fronts.

Street frame (bz_floor, bz_vault*, bz_rib, bz_end): X across, centred on the
street; Y along it, away from the crossing; Z up.
Side frame (bz_shop_*, bz_upper): X along the street 0..4, the aisle on +Y, the
shop front on Y 0, the shop behind it on -Y.
Crossing frame (bz_cross): centred on the crossing.
Crossing side frame (bz_side_*): X along the side -8..8, the crossing on +Y.

  bz_floor             one bay of street floor
  bz_vault, _eye       one bay of sail vault, plain or with a round eye
  bz_rib               the brick arch between two bays, with its pilasters
  bz_shop_open         a shop front and the 4 x 4 m room behind it
  bz_shop_shut         a shop front closed by timber shutters
  bz_upper             the upper storey of one bay: a blind arch of coloured glass
  bz_end               the street's last 2 m: a thick wall round the kit's doorway
  bz_cross             the crossing's floor and its great vault with the eye
  bz_side_open         a side of the crossing with a street opening off it
  bz_side_closed       a side with no street: the tall arch of coloured glass
"""
import math
import os
import random
import sys

import bmesh
import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kit_blender import add_box, add_prism, arch_outline, marker, mesh_object, module, rebuild

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BLEND = os.path.join(ROOT, "art_src", "kit", "kit_bazaar.blend")
ROW_Y = -200.0
BRICK, DOME, STONE, FLOOR = "bazaar_brick", "bazaar_dome", "persian_stone", "floor_stone"
WOOD, SKY = "persian_wood", "emit_sky_day"
GLASS, BRASS, LAMP = "bazaar_glass", "brass", "emit_lantern"
# The palette bazaar_glass.png (tools/pixel_materials_ext.gd): three shades of each.
RED, BLUE, GOLD, PALE, LEAD, SHADES = 0, 3, 6, 9, 12, 16
HALF = 4.0             # half a street's width
SHOP_TOP = 4.2         # the shop storey
SHOP_VAULT = 3.15      # the corners of a shop's vault
WALL_TOP = 9.7         # the street's side walls, behind the vault's edge
SPRING = 8.1           # the street vault
RIB_TOP = 12.4
X_HALF = 8.0           # half the crossing
X_SPRING = 9.6         # the crossing's vault
X_TOP = 15.7           # its side walls, behind the vault's edge
X_EYE = 1.8
BEAM_UP = 10.0         # how far over an eye its beam starts, in the eye's radii


def props(size=(0, 0, 0), tags="bazaar,r04"):
    return {"kit_shape": "free", "kit_family": "walls", "size_cells": list(size), "edge": "", "tags": tags, "weight": 1.0}


def solid(name, root, mats, build, recalc=True):
    bm = bmesh.new()
    build(bm)
    return mesh_object(name, bm, mats, root, recalc)


def holed_wall(bm, x0, x1, y0, y1, z0, top, ax, foot, span, spring, k=0.6, mat=0):
    """A wall from x0 to x1 and z0 to top with an arch through it, its left foot
    at (ax, foot). Closed pieces, so no boolean: a jamb each side, a sill under
    it if foot > z0, and an upright strip over each step of the arch."""
    add_box(bm, x0, ax, y0, y1, z0, top, mat)
    add_box(bm, ax + span, x1, y0, y1, z0, top, mat)
    if foot > z0:
        add_box(bm, ax, ax + span, y0, y1, z0, foot, mat)
    edge = arch_outline(span, spring, k, 8)[1:-1]
    for (u0, v0), (u1, v1) in zip(edge, edge[1:]):
        if u1 - u0 < 1e-5:
            continue
        add_prism(bm, [(u0, foot + v0), (u0, top), (u1, top), (u1, foot + v1)], ax, 0.0, y0, y1, mat)


def sail(bm, hx, hy, radius, z0, eye=0.0, cx=0.0, cy=0.0, pattern=None, rings=8, segs=32):
    """A sail vault over a 2hx x 2hy rectangle: a sphere cut by its four walls,
    the corners on z0. Faces point down. eye > 0 leaves a round hole at the top."""
    base = math.sqrt(radius * radius - hx * hx - hy * hy)

    def point(i, j):
        a = 2.0 * math.pi * j / segs
        c, s = math.cos(a), math.sin(a)
        reach = min(hx / max(abs(c), 1e-6), hy / max(abs(s), 1e-6))
        r = max(eye, 0.03) + (reach - max(eye, 0.03)) * i / rings
        x, y = r * c, r * s
        return (cx + x, cy + y, z0 + math.sqrt(max(0.0, radius * radius - x * x - y * y)) - base)
    grid = [[bm.verts.new(point(i, j)) for j in range(segs)] for i in range(rings + 1)]
    for i in range(rings):
        for j in range(segs):
            k = (j + 1) % segs
            f = bm.faces.new((grid[i][j], grid[i][k], grid[i + 1][k], grid[i + 1][j]))
            f.material_index = pattern(i, j) if pattern else 0
    if eye <= 0.0:
        bm.faces.new(grid[0]).material_index = 0
    return z0 + math.sqrt(max(0.0, radius * radius - eye * eye)) - base


def dome_uv(bm, radius, half):
    """The dome's painted map (bazaar_dome.png, tools/pixel_materials_ext.gd): its
    middle on the eye, distance from it measured along the curve, 1 at a corner."""
    uv = bm.loops.layers.uv.verify()
    most = math.asin(min(1.0, half * math.sqrt(2.0) / radius))
    for f in bm.faces:
        for loop in f.loops:
            x, y = loop.vert.co.x, loop.vert.co.y
            d = max(math.hypot(x, y), 1e-6)
            t = math.asin(min(1.0, d / radius)) / most
            loop[uv].uv = (0.5 + 0.5 * t * x / d, 0.5 + 0.5 * t * y / d)


def eye_well(r, name, cx, cy, radius, z, depth):
    """The short brick throat over a vault's eye, and the day at its top."""
    def throat(bm):
        n = 24
        low = [bm.verts.new((cx + radius * math.cos(2 * math.pi * i / n), cy + radius * math.sin(2 * math.pi * i / n), z - 0.15)) for i in range(n)]
        high = [bm.verts.new((cx + radius * math.cos(2 * math.pi * i / n), cy + radius * math.sin(2 * math.pi * i / n), z + depth)) for i in range(n)]
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new((high[i], high[j], low[j], low[i]))    # facing in: you see them from below
    solid(name + "__throat", r, [STONE], throat, recalc=False)

    def day(bm):
        n = 24
        bm.faces.new([bm.verts.new((cx + radius * math.cos(-2 * math.pi * i / n), cy + radius * math.sin(-2 * math.pi * i / n), z + depth)) for i in range(n)])
    solid(name + "__day", r, [SKY], day, recalc=False)


def clip(poly, window):
    """Sutherland-Hodgman: poly cut to a convex window, both counter-clockwise."""
    out = poly
    for (ax, ay), (bx, by) in zip(window, window[1:] + window[:1]):
        src, out = out, []
        for (px, py), (qx, qy) in zip(src, src[1:] + src[:1]):
            dp = (bx - ax) * (py - ay) - (by - ay) * (px - ax)
            dq = (bx - ax) * (qy - ay) - (by - ay) * (qx - ax)
            if dp >= 0.0:
                out.append((px, py))
            if dp * dq < 0.0:
                t = dp / (dp - dq)
                out.append((px + (qx - px) * t, py + (qy - py) * t))
        if len(out) < 3:
            return []
    return out


def area(poly):
    return sum(x0 * y1 - x1 * y0 for (x0, y0), (x1, y1) in zip(poly, poly[1:] + poly[:1])) / 2.0


def shrink(poly, d):
    """Each corner pulled toward the middle, so the lead shows between panes."""
    cx = sum(p[0] for p in poly) / len(poly)
    cy = sum(p[1] for p in poly) / len(poly)
    out = []
    for (x, y) in poly:
        n = math.hypot(cx - x, cy - y)
        t = min(0.45, d / max(n, 1e-6))
        out.append((x + (cx - x) * t, y + (cy - y) * t))
    return out


def star_tile(cx, cy, s, i, j):
    """One tile of the star-and-cross: [(colour, polygon)]. The star's heart and
    its eight points, and the quarters of the four crosses round it, which take
    their colour from the cross they belong to."""
    big, small = s / 2.0, s * 0.31
    tips = [(cx + big * math.cos(k * math.pi / 4), cy + big * math.sin(k * math.pi / 4)) for k in range(8)]
    ins = [(cx + small * math.cos((k + 0.5) * math.pi / 4), cy + small * math.sin((k + 0.5) * math.pi / 4)) for k in range(8)]
    out = [(GOLD if (i + j) % 2 == 0 else PALE, ins)]
    for k in range(8):
        out.append((RED, [ins[k - 1], tips[k], ins[k]]))
    for q in range(4):              # the quarter between tips 2q and 2q + 2
        sx, sy = (1 if q in (0, 3) else -1), (1 if q < 2 else -1)
        corner = (cx + big * sx, cy + big * sy)
        ground = BLUE if (i + (sx > 0) + j + (sy > 0)) % 2 == 0 else GOLD
        a, b, c = tips[2 * q], tips[2 * q + 1], tips[(2 * q + 2) % 8]
        out.append((ground, [a, corner, b, ins[2 * q]]))
        out.append((ground, [b, corner, c, ins[2 * q + 1]]))
    return out


def glass_arch(r, name, x, foot, span, spring, y, cell=0.65, broken=0.0):
    """Coloured panes in a dark lattice filling an arch, star-and-cross, centred
    on the arch and cut to it. One mesh, one material: each pane's UV picks a
    shade from the palette bazaar_glass.png, so no two neighbours quite match.
    Faces +Y; y is the plane of the lead behind the panes. `broken`: the share of
    panes gone, daylight in their place (the Forgotten City)."""
    rim = 0.09
    edge = list(reversed(arch_outline(span, spring, 0.6, 8)))
    window = [(u + rim, v + rim) for (u, v) in reversed(arch_outline(span - 2 * rim, spring - rim, 0.6, 8))]
    top = max(v for (_u, v) in edge)
    rng = random.Random(name)

    def build(bm):
        uv = bm.loops.layers.uv.verify()

        def face(poly, plane, shade):
            f = bm.faces.new([bm.verts.new((x + u, plane, foot + v)) for (u, v) in reversed(poly)])
            for loop in f.loops:
                loop[uv].uv = ((shade + 0.5) / SHADES, 0.5)
        face(edge, y, LEAD)
        half = int(math.ceil(span / cell / 2)) + 1
        for i in range(-half, half + 1):
            for j in range(int(math.ceil(top / cell)) + 1):
                for colour, poly in star_tile(span / 2 + i * cell, j * cell + cell * 0.5, cell, i, j):
                    if area(poly) < 0.0:
                        poly = list(reversed(poly))
                    cut = clip(poly, window)
                    if len(cut) >= 3 and area(cut) > 0.0025:
                        day = rng.random() < broken
                        face(shrink(cut, 0.024), y + 0.02, PALE + 2 if day else colour + rng.randrange(3))
    solid(name + "__glass", r, [GLASS], build, recalc=False)


def beam(r, x, y, z, radius, energy):
    """Sun through an eye of this radius with its rim at z: the light stands
    BEAM_UP radii over the eye, and just fills it."""
    up = radius * BEAM_UP
    angle = math.degrees(math.atan(1.0 / BEAM_UP)) * 1.1
    marker("LIGHT_beam__eye", r, (x, y, z + up), {"range": z + up + 2.0, "spot_angle": angle, "energy": energy})


def floor(r):
    solid("bz_floor__stone-col", r, [FLOOR], lambda bm: add_box(bm, -HALF, HALF, 0.0, 4.0, -0.3, 0.0))


def vault(eye):
    def build(r):
        name = r.name[2:]

        top = []

        def shell(bm):
            top.append(sail(bm, HALF + 0.2, 2.0, 4.75, SPRING, eye, 0.0, 2.0))
        solid(name + "__shell", r, [BRICK], shell, recalc=False)
        if eye > 0.0:
            eye_well(r, name, 0.0, 2.0, eye, top[0], 1.0)
            beam(r, 0.0, 2.0, top[0], eye, 7.0)
            marker("LIGHT_bounce__floor", r, (0.0, 2.0, 1.3), {"range": 8.0, "energy": 0.3, "color": [1.0, 0.84, 0.56]})
    return build


def rib(r):
    def body(bm):
        holed_wall(bm, -HALF - 0.4, HALF + 0.4, -0.25, 0.25, 0.0, RIB_TOP, -3.7, 0.0, 7.4, 6.8)
    solid("bz_rib__arch-col", r, [BRICK], body)


def shop_front(r, name):
    """The wall all shops share: an arch, the string course over it."""
    def wall(bm):
        holed_wall(bm, 0.0, 4.0, -0.4, 0.0, 0.0, SHOP_TOP, 0.5, 0.0, 3.0, 2.2)
    solid(name + "__front-col", r, [BRICK], wall)
    solid(name + "__course", r, [STONE], lambda bm: add_box(bm, 0.0, 4.0, -0.1, 0.12, SHOP_TOP, SHOP_TOP + 0.2))


def shop_open(r):
    name = "bz_shop_open"
    shop_front(r, name)
    solid(name + "__floor-col", r, [FLOOR], lambda bm: add_box(bm, 0.0, 4.0, -4.4, 0.0, -0.3, 0.0))

    def walls(bm):
        add_box(bm, 0.0, 0.15, -4.4, -0.4, 0.0, SHOP_TOP + 0.2)
        add_box(bm, 3.85, 4.0, -4.4, -0.4, 0.0, SHOP_TOP + 0.2)
        add_box(bm, 0.0, 4.0, -4.4, -4.1, 0.0, SHOP_TOP + 0.2)
    solid(name + "__walls-col", r, [BRICK], walls)
    # Its edge meets the front wall over the arch's crown (3.98 m), or the arch
    # looks out past the vault (your walk of step 1).
    solid(name + "__vault", r, [BRICK], lambda bm: sail(bm, 1.9, 1.9, 3.1, SHOP_VAULT, 0.0, 2.0, -2.25, None, 5, 20), recalc=False)
    # Its lamp and light come with the trade (tools/kit_add_r04_shops.py).


def shop_shut(r):
    name = "bz_shop_shut"
    shop_front(r, name)
    solid(name + "__sill-col", r, [FLOOR], lambda bm: add_box(bm, 0.0, 4.0, -0.4, 0.0, -0.3, 0.0))
    solid(name + "__leaves-col", r, [WOOD], lambda bm: add_prism(bm, arch_outline(3.0, 2.2, 0.6, 8), 0.5, 0.0, -0.32, -0.24))

    def battens(bm):
        add_box(bm, 1.97, 2.03, -0.24, -0.2, 0.0, 3.9)
        for z in (0.5, 1.25, 2.0):
            add_box(bm, 0.55, 3.45, -0.24, -0.2, z, z + 0.1)
    solid(name + "__battens", r, [WOOD], battens)


def upper(r, name="bz_upper", broken=0.0):
    solid(name + "__wall-col", r, [BRICK], lambda bm: add_box(bm, 0.0, 4.0, -0.4, -0.2, SHOP_TOP, WALL_TOP))
    solid(name + "__face", r, [BRICK], lambda bm: holed_wall(bm, 0.0, 4.0, -0.2, 0.0, SHOP_TOP + 0.2, WALL_TOP, 0.7, 4.8, 2.6, 1.4))
    glass_arch(r, name, 0.7, 4.8, 2.6, 1.4, -0.19, 0.65, broken)


def end(r):
    """The kit's doorway wall stands on Y 2 (+-0.3), X +-2; this closes the street
    round it, a 2 m passage through, and a blind arch on the street's side."""
    name = "bz_end"

    def wall(bm):
        add_box(bm, -HALF - 0.4, -1.5, 0.0, 1.7, 0.0, RIB_TOP)
        add_box(bm, 1.5, HALF + 0.4, 0.0, 1.7, 0.0, RIB_TOP)
        add_box(bm, -1.5, 1.5, 0.0, 1.7, 3.5, RIB_TOP)
        add_box(bm, -HALF - 0.4, -2.0, 1.7, 2.3, 0.0, RIB_TOP)
        add_box(bm, 2.0, HALF + 0.4, 1.7, 2.3, 0.0, RIB_TOP)
    solid(name + "__wall-col", r, [BRICK], wall)
    solid(name + "__floor-col", r, [FLOOR], lambda bm: add_box(bm, -2.0, 2.0, 0.0, 2.0, -0.3, 0.0))
    solid(name + "__frame", r, [BRICK], lambda bm: holed_wall(bm, -3.7, 3.7, -0.3, 0.0, 0.0, RIB_TOP, -2.6, 0.0, 5.2, 4.2))


def cross(r):
    name = "bz_cross"
    h = X_HALF

    def stones(bm):
        add_box(bm, -h, h, -h, h, -0.3, 0.0)
    solid(name + "__floor-col", r, [FLOOR], stones)

    top = []

    def shell(bm):
        top.append(sail(bm, h + 0.2, h + 0.2, 12.0, X_SPRING, X_EYE, 0.0, 0.0, None, 24, 96))
        dome_uv(bm, 12.0, h + 0.2)
    solid(name + "__vault", r, [DOME], shell, recalc=False)
    eye_well(r, name, 0.0, 0.0, X_EYE, top[0], 1.6)
    beam(r, 0.0, 0.0, top[0], X_EYE, 12.0)
    # The beam's light thrown back off the floor: a low pool under the beam. The
    # walls fall away into dimness over it, and the dome stays dim (your walk: one
    # high, wide fill lit the whole crossing evenly). The streets set the balance.
    marker("LIGHT_bounce__floor", r, (0.0, 0.0, 1.5), {"range": 11.0, "energy": 0.9, "color": [1.0, 0.84, 0.56]})


def flanks(r, name):
    """Each end of a crossing side: a blind shop arch, coloured glass over it."""
    for side, x in (("a", -X_HALF), ("b", 4.0)):
        solid("%s__niche_%s-col" % (name, side), r, [BRICK], lambda bm, x=x: holed_wall(bm, x, x + 4.0, 0.0, 0.4, 0.0, SHOP_TOP, x + 0.5, 0.0, 3.0, 2.2))
        solid("%s__course_%s" % (name, side), r, [STONE], lambda bm, x=x: add_box(bm, x, x + 4.0, 0.3, 0.52, SHOP_TOP, SHOP_TOP + 0.2))
        solid("%s__upper_%s" % (name, side), r, [BRICK], lambda bm, x=x: holed_wall(bm, x, x + 4.0, 0.0, 0.3, SHOP_TOP + 0.2, 9.4, x + 0.7, 4.8, 2.6, 1.4))
        glass_arch(r, "%s__panes_%s" % (name, side), x + 0.7, 4.8, 2.6, 1.4, 0.01)


def side_open(r):
    name = "bz_side_open"
    h = X_HALF + 0.4

    def wall(bm):
        # Crown 11.33 m: under the street vault's edge (11.45 m), or a slot shows.
        holed_wall(bm, -4.4, 4.4, -0.4, 0.0, 0.0, X_TOP, -4.0, 0.0, 8.0, 6.6)
        # Thin beside the street: the first shops on each side stand against it.
        for (x0, x1) in ((-h, -4.4), (4.4, h)):
            add_box(bm, x0, x1, -0.15, 0.0, 0.0, 5.0)
            add_box(bm, x0, x1, -0.4, 0.0, 5.0, X_TOP)
    solid(name + "__wall-col", r, [BRICK], wall)
    flanks(r, name)
    solid(name + "__over_frame", r, [BRICK], lambda bm: holed_wall(bm, -2.2, 2.2, 0.0, 0.25, 11.9, X_TOP, -1.5, 12.2, 3.0, 1.0))
    glass_arch(r, name + "__over", -1.5, 12.2, 3.0, 1.0, 0.01)


def side_closed(r):
    name = "bz_side_closed"
    h = X_HALF + 0.4
    solid(name + "__wall-col", r, [BRICK], lambda bm: add_box(bm, -h, h, -0.4, 0.0, 0.0, X_TOP))
    flanks(r, name)

    def middle(bm):
        holed_wall(bm, -4.0, 0.0, 0.0, 0.4, 0.0, SHOP_TOP, -3.5, 0.0, 3.0, 2.2)
        holed_wall(bm, 0.0, 4.0, 0.0, 0.4, 0.0, SHOP_TOP, 0.5, 0.0, 3.0, 2.2)
    solid(name + "__middle-col", r, [BRICK], middle)
    solid(name + "__course", r, [STONE], lambda bm: add_box(bm, -4.0, 4.0, 0.3, 0.52, SHOP_TOP, SHOP_TOP + 0.2))
    solid(name + "__frame", r, [BRICK], lambda bm: holed_wall(bm, -4.0, 4.0, 0.0, 0.3, SHOP_TOP + 0.2, X_TOP, -3.5, 4.8, 7.0, 6.0))
    glass_arch(r, name + "__great", -3.5, 4.8, 7.0, 6.0, 0.01, 0.875)


MODULES = [
    ("M_bz_floor", props(), floor),
    ("M_bz_vault", props(), vault(0.0)),
    ("M_bz_vault_eye", props(), vault(0.8)),
    ("M_bz_rib", props(), rib),
    ("M_bz_shop_open", props(), shop_open),
    ("M_bz_shop_shut", props(), shop_shut),
    ("M_bz_upper", props(), upper),
    ("M_bz_upper_broken", props(), lambda r: upper(r, "bz_upper_broken", 0.28)),
    ("M_bz_end", props(), end),
    ("M_bz_cross", props(), cross),
    ("M_bz_side_open", props(), side_open),
    ("M_bz_side_closed", props(), side_closed),
]

# Script-made modules remade in place at a new revision (kit_blender.rebuild).
REBUILD = [(n, 11) for (n, _p, _b) in MODULES]


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
        x += 24.0
    rebuilt = ["%s (rev %d)" % (n, v) for (n, v) in REBUILD if rebuild(n, v, MODULES)]
    if not added and not rebuilt:
        print("kit_add_r04: everything already present; nothing to do.")
        return
    os.makedirs(os.path.dirname(BLEND), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=BLEND)
    print("kit_add_r04: added %d; rebuilt %s" % (len(added), ", ".join(rebuilt) or "nothing"))


main()

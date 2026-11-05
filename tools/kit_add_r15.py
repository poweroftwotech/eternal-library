"""Seeds the R15 Fungus Terraces modules into art_src/kit/kit_fungus.blend
(phase 13 step 3, docs/environment/phase-13-approval.md).

  blender --background --factory-startup --python tools/kit_add_r15.py

Creates kit_fungus.blend if it doesn't exist, then adds only the modules
that are not in it yet (hand edits are kept), and remakes those in REBUILD.
Then run tools/export_kit.bat kit_fungus.blend.

The room (FungusTerracesGrammar, scripts/gen/fungus_terraces_grammar.gd):
terraces climbing a cavern slope, 5 bays (20 m) wide, one bay (4 m) deep
each, each RISE (4/3 m) over the one below, so three terraces climb a
storey. A foot landing with the entry door, 6, 9 or 12 terraces (2, 3 or 4
storeys), the last one the top landing with the far door. Down the middle
bay the cascade, a stone channel falling a step at each terrace's wall, and
the stair beside it; violet glowing caps in the beds either side.

Frame (Blender): a row piece's origin is its south-west corner on its own
floor (Z 0); X across the room 0..20, Y up the slope 0..4 (Godot -Z); the
terrace's retaining wall at its south edge drops RISE to the row below.
Every row piece carries its own stretch of the cavern: rough rock side walls
(X 0 and 20, from below the row under it up into the roof), and the roof, a
low vault about 7 m over the floor at the walls and 9.5 m in the middle,
with a skirt down RISE at its south edge to meet the roof of the row below.
The roof's and walls' edges at Y 0 and 4 follow one profile, with no
roughness there, so any row variant meets any other.

New modules (laid out on a row at Blender Y = -160 for viewing):
  ft_row_0/1/2    a terrace: its retaining wall with four drain arches, the
                  beds either side of the middle bay (soil, a stone curb,
                  violet caps thickest at the bed's front edge), a path along
                  the back at the foot of the next wall, the channel and its
                  fall, the stair flight (8 steps) and its landing, one violet
                  light over the stair. Variants differ in rock, caps and the
                  odd patch of teal or amber fungus among the violet (Q7).
  ft_foot         the foot landing: a floor, the entry wall (south, the kit's
                  3 m doorway in the middle bay in a carved stone frame), the
                  cascade's basin, rock and roof.
  ft_top          the top terrace: a terrace as the rows, plus the far wall
                  (north) with its doorway, and the spring the cascade starts
                  from, an arch in that wall over the channel.
"""
import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import noise

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kit_blender import add_box, add_lathe, add_obox, add_prism, add_tube, arch_outline, cut, marker, mesh_object, module, rebuild  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BLEND = os.path.join(ROOT, "art_src", "kit", "kit_fungus.blend")
ROW_Y = -160.0
ROCK = "cave_rock"
STONE = "persian_stone"
RISE = 4.0 / 3.0       # each terrace over the one below (three a storey)
W = 20.0               # the room's width (5 bays)
D = 4.0                # a terrace's depth (1 bay)
BED_D = 2.8            # the bed, from the wall's top back
CURB = 0.3             # the beds' stone curb (also the wall's top)
SOIL = 0.25            # the beds' soil over the path
MID0, MID1 = 8.0, 12.0          # the middle bay
# The stair fills the middle bay, in line with both doors; the cascade runs
# beside it in the west bed's edge (walk 1: its spring stood in the far door).
CH0, CH1 = 6.6, 8.0             # the cascade's channel (outside its walls)
ST0, ST1 = 8.0, 12.0            # the stair
STEPS = 8
OUT = 3.4              # each bed's outer end, a patch prop (tended, wild, blighted)
SIDE_LOW = -1.7        # the side walls reach under the row below's floor


def props(shape, size, edge, tags, family="walls", weight=1.0):
    return {"kit_shape": shape, "kit_family": family, "size_cells": size,
            "edge": edge, "tags": tags, "weight": weight}


def solid(name, root, mats, build, recalc=True):
    bm = bmesh.new()
    build(bm)
    return mesh_object(name, bm, mats, root, recalc)


def profile(x):
    """The roof's height over a row's floor across the room: a low vault."""
    return 7.0 + 2.5 * math.sin(math.pi * min(max(x, 0.0), W) / W) ** 0.7


def env(y):
    """0 at a row's edges (Y 0 and 4), 1 in its middle: roughness fades to the
    shared profile where rows meet."""
    return math.sin(math.pi * min(max(y, 0.0), D) / D)


def rough(x, y, z, seed):
    return noise.noise((x * 0.45, y * 0.45, z * 0.45 + seed)) * 0.7 + noise.noise((x * 1.3, y * 1.3, z * 1.3 + seed + 7.0)) * 0.3


def yz_prism(bm, pts, x0, x1):
    """A closed prism of a YZ polygon (counter-clockwise seen from +X) across X."""
    a = [bm.verts.new((x0, y, z)) for (y, z) in pts]
    b = [bm.verts.new((x1, y, z)) for (y, z) in pts]
    bm.faces.new(list(reversed(a)))
    bm.faces.new(b)
    n = len(pts)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((a[i], a[j], b[j], b[i]))


# --- the cavern: roof and side walls ------------------------------------------------

def cavern(r, name, seed, skirt=True, z_low=SIDE_LOW):
    """This row's stretch of roof (facing down) and side walls (facing in)."""
    bm = bmesh.new()
    nx, ny = 20, 8
    vs = []
    for i in range(nx + 1):
        x = W * i / nx
        row = []
        for j in range(ny + 1):
            y = D * j / ny
            z = profile(x) + rough(x, y, 3.0, seed) * 1.1 * env(y)
            row.append(bm.verts.new((x, y, z)))
        vs.append(row)
    for i in range(nx):
        for j in range(ny):
            bm.faces.new((vs[i][j], vs[i][j + 1], vs[i + 1][j + 1], vs[i + 1][j]))       # facing down
    if skirt:
        # Down RISE at the south edge to the roof of the row below (its north edge).
        lo = [bm.verts.new((vs[i][0].co.x, 0.0, vs[i][0].co.z - RISE - 0.05)) for i in range(nx + 1)]
        for i in range(nx):
            bm.faces.new((vs[i][0], vs[i + 1][0], lo[i + 1], lo[i]))
    # The side walls: X 0 and 20, from under the row below up into the roof.
    for side, x0, inward in (("w", 0.0, 1.0), ("e", W, -1.0)):
        nz = 12
        top = profile(x0) + 1.8      # past the roof's roughest rise there
        grid = []
        for j in range(ny + 1):
            y = D * j / ny
            col = []
            for k in range(nz + 1):
                z = z_low + (top - z_low) * k / nz
                push = (0.35 + 0.45 * rough(x0, y, z, seed + 11.0)) * env(y)
                col.append(bm.verts.new((x0 + inward * max(0.0, push), y, z)))
            grid.append(col)
        for j in range(ny):
            for k in range(nz):
                f = (grid[j][k], grid[j][k + 1], grid[j + 1][k + 1], grid[j + 1][k])
                bm.faces.new(tuple(reversed(f)) if inward > 0 else f)      # facing in
    mesh_object(name + "__cavern", bm, [ROCK], r, recalc=False)
    # Step 5 (the route audit: you could walk out through the sides): the side
    # walls' collision, a slab behind each rock face (its least push in is 0.35 m,
    # none at a row's ends), up past a jump.
    solid(name + "__sides-colonly", r, [ROCK], lambda bm: (add_box(bm, -0.6, 0.2, 0.0, D, z_low, 7.0), add_box(bm, W - 0.2, W + 0.6, 0.0, D, z_low, 7.0)))
    wall_fungus(r, name, seed, z_low)


def wall_fungus(r, name, seed, z_low):
    """Walk 3 ("too dark to see the sides"): glowing bracket fungus in clusters
    on both side walls, shelves seated on the wall's rough face (the same push
    as cavern()'s). Walk 4: shades of violet (not teal), sunk into the rock
    with a knot at the root, in tiers of one to three side by side, smaller
    toward the top (not a ladder of plates)."""
    rng = random.Random(int(seed * 13.0) + 7)
    crop = Crop(rng, (0.4, 0.35, 0.25))
    for x0, inward in ((0.0, 1.0), (W, -1.0)):
        for _c in range(3):
            y0 = rng.uniform(0.9, D - 0.9)
            z = max(z_low, 0.0) + rng.uniform(0.5, 2.6)
            sh = crop.shade()
            size = rng.uniform(0.2, 0.32)
            for _t in range(rng.randint(3, 5)):
                n = rng.randint(1, 3)
                for k in range(n):
                    y = min(max(y0 + (k - (n - 1) / 2.0) * size * 1.5 + rng.uniform(-0.06, 0.06), 0.4), D - 0.4)
                    zz = z + rng.uniform(-0.05, 0.05)
                    push = (0.35 + 0.45 * rough(x0, y, zz, seed + 11.0)) * env(y)
                    crop.shelf(x0 + inward * max(0.0, push), y, zz, size * rng.uniform(0.75, 1.1), inward,
                               shade=sh if rng.random() < 0.85 else None)
                z += size * rng.uniform(0.7, 1.1)
                size *= rng.uniform(0.72, 0.88)
                y0 += rng.uniform(-0.12, 0.12)
    crop.write(r, name + "__wall")


# --- the violet crop -----------------------------------------------------------------

class Crop:
    """Walk 4 ("add some variety… shapes and shades of violet… solid colour,
    flat 2d shape"): every cap is one of four shapes, tilted a little, in one
    of three violets (ft_cap_violet, _lilac, _plum: lit and mottled, not flat
    glow), over a dark gill underside (ft_gills), so it reads in the round.
    `mix` weights the shades (violet, lilac, plum)."""
    SHADES = ("violet", "lilac", "plum")
    KINDS = (("flat", 0.45), ("cone", 0.2), ("bell", 0.2), ("button", 0.15))

    def __init__(self, rng, mix=(0.65, 0.2, 0.15)):
        self.rng, self.mix = rng, mix
        self.stalks, self.gills = bmesh.new(), bmesh.new()
        self.tops = {s: bmesh.new() for s in self.SHADES}

    def _pick(self, pairs):
        t, acc = self.rng.random() * sum(w for _, w in pairs), 0.0
        for v, w in pairs:
            acc += w
            if t <= acc:
                return v
        return pairs[-1][0]

    def shade(self):
        return self._pick(list(zip(self.SHADES, self.mix)))

    @staticmethod
    def profiles(kind, h, cr):
        """(top, gills) lathe profiles of a cap whose rim is at height h."""
        if kind == "cone":
            return ([(0.0, h + 0.02), (cr * 0.75, h - 0.02), (cr * 0.55, h + cr * 0.5), (cr * 0.25, h + cr * 0.95), (0.0, h + cr * 1.15)],
                    [(0.0, h - 0.035), (cr * 0.7, h - 0.022), (0.0, h - 0.004)])
        if kind == "bell":
            return ([(0.0, h + 0.03), (cr * 0.8, h - cr * 0.3), (cr * 0.88, h), (cr * 0.7, h + cr * 0.42), (0.0, h + cr * 0.62)],
                    [(0.0, h - cr * 0.18), (cr * 0.76, h - cr * 0.28), (0.0, h - cr * 0.08)])
        if kind == "button":
            return ([(0.0, h + 0.0), (cr, h - 0.01), (cr * 0.8, h + cr * 0.45), (0.0, h + cr * 0.62)],
                    [(0.0, h - 0.03), (cr * 0.92, h - 0.012), (0.0, h - 0.002)])
        return ([(0.0, h + 0.0), (cr, h - 0.02), (cr * 0.88, h + cr * 0.22), (cr * 0.45, h + cr * 0.42), (0.0, h + cr * 0.48)],
                [(0.0, h - 0.04), (cr * 0.93, h - 0.022), (0.0, h - 0.005)])

    def cap(self, cx, cy, base, h, cr, shade=None, kind=None, stalk=0.035):
        """A mushroom on the ground at (cx, cy, base): stalk h tall, cap radius cr."""
        from mathutils import Matrix
        kind = kind or self._pick(self.KINDS)
        if kind == "button":
            h, cr = h * 0.5, cr * 0.6
        top, gl = self.profiles(kind, h, cr)
        m = Matrix.Translation((cx, cy, base)) @ Matrix.Rotation(self.rng.uniform(-0.18, 0.18), 4, "X") \
            @ Matrix.Rotation(self.rng.uniform(-0.18, 0.18), 4, "Y") @ Matrix.Rotation(self.rng.uniform(0.0, 1.0), 4, "Z")
        _moved(self.stalks, lambda bm: add_lathe(bm, [(0.0, -0.02), (stalk, -0.02), (stalk * 0.85, h), (0.0, h)], segs=5), m)
        _moved(self.tops[shade or self.shade()], lambda bm: add_lathe(bm, top, segs=8), m)
        _moved(self.gills, lambda bm: add_lathe(bm, gl, segs=8), m)

    def shelf(self, x, y, z, cr, inward, shade=None, axis="x"):
        """A bracket on a wall whose face is at (x, y) (the face across X, or
        with axis "y" across Y), `inward` pointing out of the rock; sunk about
        a third into it, thick at the root, with a dark knot where it grows."""
        from mathutils import Matrix, Vector
        out = Vector((inward, 0.0, 0.0)) if axis == "x" else Vector((0.0, inward, 0.0))
        tip = self.rng.uniform(0.04, 0.2)
        rot = Matrix.Rotation(-inward * tip, 4, "Y") if axis == "x" else Matrix.Rotation(inward * tip, 4, "X")
        m = Matrix.Translation(Vector((x, y, z)) - out * cr * 0.3) @ rot
        _moved(self.tops[shade or self.shade()], lambda bm: add_lathe(bm, [(0.0, -0.03), (cr, 0.0), (cr * 0.82, 0.04), (cr * 0.35, 0.07), (0.0, 0.08)], segs=8), m)
        _moved(self.gills, lambda bm: add_lathe(bm, [(0.0, -0.06), (cr * 0.94, -0.012), (0.0, -0.01)], segs=8), m)
        k = Matrix.Translation(Vector((x, y, z - 0.02)) - out * 0.04)
        _moved(self.stalks, lambda bm: add_lathe(bm, [(0.0, -0.1), (0.07, -0.06), (0.06, 0.03), (0.0, 0.06)], segs=6), k)

    def write(self, r, name):
        mesh_object(name + "__stalks", self.stalks, ["persian_fungus_stalk"], r)
        mesh_object(name + "__gills", self.gills, ["ft_gills"], r)
        for s, bm in self.tops.items():
            if len(bm.verts):
                mesh_object(name + "__caps_" + s, bm, ["ft_cap_" + s], r)


def caps(r, name, rng, x0, x1, odd=None):
    """Glowing caps over a bed (X x0..x1, Y CURB..BED_D), thickest and
    biggest at its front edge over the drop. `odd` ("teal" or "amber", the
    terrace variant) leans the bed's shades lilac or plum (walk 4: shades of
    violet, not other colours)."""
    crop = Crop(rng, {None: (0.65, 0.2, 0.15), "teal": (0.45, 0.4, 0.15), "amber": (0.45, 0.15, 0.4)}[odd])
    x = x0 + 0.35
    while x < x1 - 0.3:
        for y, big in ((CURB + 0.3, 1.0), (CURB + 0.95, 0.8), (CURB + 1.6, 0.65), (BED_D - 0.45, 0.55)):
            if rng.random() < 0.15 * (1.0 - big):
                continue
            # A clump shares a shade, mostly (a patch of one strain).
            sh = crop.shade()
            for _ in range(rng.randint(2, 4)):
                cx, cy = x + rng.uniform(-0.25, 0.25), y + rng.uniform(-0.2, 0.2)
                crop.cap(cx, cy, SOIL, rng.uniform(0.12, 0.38) * big, rng.uniform(0.08, 0.17) * (0.7 + 0.5 * big),
                         shade=sh if rng.random() < 0.8 else None)
        x += rng.uniform(0.55, 0.8)
    crop.write(r, name)


# --- a terrace -------------------------------------------------------------------------

def terrace(r, name, rng, odd=None):
    """The terrace (see the module list): wall, beds, path, channel, stair."""
    # The retaining wall under each bed's front, with its drain arches, and
    # the beds over it (one solid block: wall face at Y 0, curb on top).
    for (x0, x1) in ((0.0, CH0), (ST1, W)):
        body = solid(name + "__wall_%d" % int(x0), r, [STONE], lambda bm, x0=x0, x1=x1: add_box(bm, x0, x1, 0.0, 0.45, -RISE, CURB))
        for k in range(2):
            ax = x0 + (x1 - x0) * (0.25 + 0.5 * k) - 0.3
            cut(body, solid("cutter", r, [ROCK], lambda bm, ax=ax: add_prism(bm, arch_outline(0.6, 0.22, 0.6, 8), ax, -RISE + 0.04, -0.1, 0.4)))   # walk 5: a sill (from -RISE - 0.01 it cut the bottom away: the void showed through)
        solid(name + "__curb_%d" % int(x0), r, [STONE], lambda bm, x0=x0, x1=x1: add_box(bm, x0, x1, BED_D - 0.2, BED_D, 0.0, CURB))
        solid(name + "__soil_%d" % int(x0), r, ["persian_soil"], lambda bm, x0=x0, x1=x1: add_box(bm, x0 + (0.0 if x0 == 0.0 else 0.15), x1 - (0.15 if x0 == 0.0 else 0.0), 0.45, BED_D - 0.2, -0.3, SOIL))
        # The bed's stone side by the channel or the stair, down to the row
        # below (walk 1: you saw under the soil from the stair).
        sx = x1 - 0.15 if x0 == 0.0 else x0
        solid(name + "__side_%d" % int(x0), r, [STONE], lambda bm, sx=sx: add_box(bm, sx, sx + 0.15, 0.45, BED_D, -RISE, CURB))
        # The terrace's fill under its beds and path: stone, so no gap shows.
        solid(name + "__core_%d" % int(x0), r, [STONE], lambda bm, x0=x0, x1=x1: add_box(bm, x0, x1 if x0 > 0.0 else ST0, 0.3, D, -RISE, -0.45))
        solid(name + "__bed_%d-colonly" % int(x0), r, [STONE], lambda bm, x0=x0, x1=x1: add_box(bm, x0, x1, 0.0, BED_D, -RISE, SOIL))
        # The crop by the stair (always tended); the bed's outer end (OUT) is a
        # patch prop of its own, tended, wild or blighted (step 4, Q8).
        if x0 == 0.0:
            caps(r, name + "_0", rng, OUT + 0.1, CH0 - 0.35, odd)
        else:
            caps(r, name + "_%d" % int(x0), rng, ST1 + 0.35, W - OUT - 0.1)
    # The path along the back, at the foot of the next terrace's wall.
    solid(name + "__path", r, ["floor_stone"], lambda bm: (add_box(bm, 0.0, CH0, BED_D, D, -0.2, 0.0), add_box(bm, ST1, W, BED_D, D, -0.2, 0.0)))
    solid(name + "__path-colonly", r, [STONE], lambda bm: (add_box(bm, 0.0, CH0, BED_D, D, -RISE, 0.0), add_box(bm, ST1, W, BED_D, D, -RISE, 0.0)))
    # The cascade's channel down the middle bay's west side: its walls, bed and
    # water, and its fall over this terrace's wall into the row below's channel.
    def channel(bm):
        add_box(bm, CH0, CH0 + 0.15, 0.0, D, -0.3, 0.12)
        add_box(bm, CH1 - 0.15, CH1, 0.0, D, -0.3, 0.12)
        add_box(bm, CH0, CH1, 0.0, D, -0.45, -0.3)
        add_box(bm, CH0, CH1, -0.02, 0.3, -RISE, -0.3)       # the step the water falls over
    solid(name + "__channel", r, [STONE], channel)
    water = bmesh.new()
    a = [water.verts.new(p) for p in ((CH0 + 0.15, 0.0, -0.12), (CH1 - 0.15, 0.0, -0.12), (CH1 - 0.15, D, -0.12), (CH0 + 0.15, D, -0.12))]
    water.faces.new(a)
    # Walk 4 ("just teal space… doesn't look like any dark water"): dark
    # running water (shaders/well_water.gdshader), the fall its own sheet.
    mesh_object(name + "__water", water, ["channel_water"], r, recalc=False)
    sheet = bmesh.new()
    sheet.faces.new([sheet.verts.new(p) for p in ((CH0 + 0.15, -0.12, -RISE - 0.12), (CH1 - 0.15, -0.12, -RISE - 0.12), (CH1 - 0.15, 0.0, -0.12), (CH0 + 0.15, 0.0, -0.12))])
    mesh_object(name + "__fall", sheet, ["fall_water"], r, recalc=False)
    solid(name + "__channel-colonly", r, [STONE], lambda bm: add_box(bm, CH0, CH1, 0.0, D, -RISE, 0.0))
    # The stair: eight steps up from the row below's landing to this one's.
    def stair(bm):
        tread = BED_D / STEPS
        for s in range(STEPS):
            add_box(bm, ST0, ST1, s * tread, (s + 1) * tread, -RISE, -RISE + (s + 1) * RISE / STEPS)
        add_box(bm, ST0, ST1, BED_D, D, -RISE, 0.0)           # the landing
    solid(name + "__stair", r, [STONE], stair)
    solid(name + "__stair-colonly", r, [STONE], lambda bm: yz_prism(bm, [(0.0, -RISE - 0.01), (BED_D, 0.0), (D, 0.0), (D, -RISE - 0.01)], ST0, ST1))
    # One violet light a terrace, low over the stair: it lights the steps, the
    # falling water and both beds' fronts (the caps glow on their own).
    marker("LIGHT_violet__terrace", r, (10.0, 1.2, 1.1))


def ft_row(v):
    def build(r):
        name = "ft_row_%d" % v
        rng = random.Random(151 + v * 17)
        terrace(r, name, rng, odd=[None, "teal", "amber"][v])
        cavern(r, name, seed=float(v) * 9.0)
        # Walk 3: a dim wash on one side wall (row 1 west, row 2 east), so the
        # room's sides read; the middle light alone left them black.
        if v > 0:
            marker("LIGHT_violet__side", r, (1.8 if v == 1 else W - 1.8, 2.0, 3.6), {"energy": 0.9})
    return build


CAVE_SEGS, CAVE_HALF, CAVE_TOP = 16, 1.65, 3.3    # the Bridge Hall's cave passage (tools/kit_add_r21.py)


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


def door_mouth(r, name, y):
    """Rock filling the doorway (X 8.5..11.5, Z 0..3.5, in the wall's middle
    at Y `y`) in to the cave passage's profile behind it (walk 1: the doors
    open onto a rock passage), seen from both sides."""
    n = 32
    outer = _along([(8.5, 0.0), (8.5, 3.5), (11.5, 3.5), (11.5, 0.0)], n)
    prof = []
    for j in range(CAVE_SEGS, -1, -1):      # left foot first
        a = math.pi * j / CAVE_SEGS
        c, s = math.cos(a), math.sin(a)
        u = max(-1.5, min(1.5, CAVE_HALF * math.copysign(abs(c) ** 0.8, c)))
        prof.append((10.0 + u, CAVE_TOP * (abs(s) ** 0.7)))
    inner = _along(prof, n)
    bm = bmesh.new()
    a = [bm.verts.new((p[0], y, p[1])) for p in outer]
    b = [bm.verts.new((p[0], y, p[1])) for p in inner]
    for j in range(n):
        if max(abs(outer[j][0] - inner[j][0]), abs(outer[j][1] - inner[j][1]), abs(outer[j + 1][0] - inner[j + 1][0]), abs(outer[j + 1][1] - inner[j + 1][1])) < 1e-4:
            continue
        f = (a[j], a[j + 1], b[j + 1], b[j])
        bm.faces.new(f)
        g = [bm.verts.new(v.co) for v in reversed(f)]
        bm.faces.new(g)
    mesh_object(name + "__mouth", bm, [ROCK], r, recalc=False)


def end_wall(r, name, y, facing, seed):
    """An end wall across the room at Y `y`, rough rock facing `facing` (+1:
    toward +Y), from the floor into the roof, with the kit's 3 m doorway in
    the middle bay (X 8.5..11.5) in a carved stone frame; its wall astride
    the edge (Y y-0.3..y+0.3), as door walls are."""
    bm = bmesh.new()
    nx, nz = 40, 22
    grid = []
    for i in range(nx + 1):
        x = W * i / nx
        col = []
        for k in range(nz + 1):
            z = (profile(x) + 0.5) * k / nz
            near = max(0.0, 1.0 - max(0.0, abs(x - 10.0) - 1.5) / 2.5) if z < 5.0 else 0.0
            push = (0.25 + 0.45 * rough(x, y, z, seed)) * (1.0 - near) * min(1.0, x / 1.0, (W - x) / 1.0)
            col.append(bm.verts.new((x, y + facing * (0.3 + max(0.0, push)), z)))
        grid.append(col)
    for i in range(nx):
        for k in range(nz):
            xm = W * (i + 0.5) / nx
            zm = (profile(xm) + 0.5) * (k + 0.5) / nz
            if 8.5 < xm < 11.5 and zm < 3.5:
                continue          # the doorway
            f = (grid[i][k], grid[i + 1][k], grid[i + 1][k + 1], grid[i][k + 1])
            bm.faces.new(tuple(reversed(f)) if facing > 0 else f)      # facing into the room
    mesh_object(name + "__end", bm, [ROCK], r, recalc=False)
    door_mouth(r, name, y)
    solid(name + "__frame", r, [STONE], lambda bm: (add_box(bm, 8.0, 8.5, y - 0.35, y + 0.35, 0.0, 3.5),
                                                     add_box(bm, 11.5, 12.0, y - 0.35, y + 0.35, 0.0, 3.5),
                                                     add_box(bm, 7.9, 12.1, y - 0.4, y + 0.4, 3.5, 4.1)))
    solid(name + "__end-colonly", r, [ROCK], lambda bm: (add_box(bm, 0.0, 8.5, y - 0.3, y + 0.3, 0.0, 10.0),
                                                          add_box(bm, 11.5, W, y - 0.3, y + 0.3, 0.0, 10.0),
                                                          add_box(bm, 8.5, 11.5, y - 0.3, y + 0.3, 3.5, 10.0)))


def ft_foot(r):
    name = "ft_foot"
    B0, B1, DEEP = CH0 - 0.4, CH1 + 0.2, 3.5
    # The floor, round the basin's well (B0..B1, from Y 2.2 to the back).
    solid(name + "__floor", r, ["floor_stone"], lambda bm: (add_box(bm, 0.0, B0, 0.0, D, -0.2, 0.0), add_box(bm, B1, W, 0.0, D, -0.2, 0.0),
                                                            add_box(bm, B0, B1, 0.0, 2.2, -0.2, 0.0)))
    solid(name + "__floor-colonly", r, [STONE], lambda bm: add_box(bm, 0.0, W, 0.0, D, -0.4, 0.0))
    end_wall(r, name, 0.0, 1.0, 21.0)
    # The cascade's basin at the foot of the first fall, west of the stair: a
    # well (walk 2: the water needs a way out), its stone lining going down
    # DEEP into the dark, the water a little under the floor, so the cascade
    # sinks away into the rock under the room.
    def lining(bm, z0, z1):
        add_box(bm, B0, B1, 2.2, 2.4, z0, z1)               # front
        add_box(bm, B0, B0 + 0.2, 2.4, D, z0, z1)           # west
        add_box(bm, B1 - 0.2, B1, 2.4, D, z0, z1)           # east
        add_box(bm, B0 + 0.2, B1 - 0.2, D - 0.08, D, z0, min(z1, 0.0))   # back, behind the fall
    solid(name + "__basin", r, [STONE], lambda bm: lining(bm, -1.2, 0.45))
    solid(name + "__basin_deep", r, ["culvert_dark"], lambda bm: (lining(bm, -DEEP, -1.2), add_box(bm, B0, B1, 2.2, D, -DEEP - 0.2, -DEEP)))
    solid(name + "__basin-colonly", r, [STONE], lambda bm: add_box(bm, B0, B1, 2.2, D, 0.0, 0.45))
    water = bmesh.new()
    water.faces.new([water.verts.new(p) for p in ((B0 + 0.2, 2.4, -0.45), (B1 - 0.2, 2.4, -0.45), (B1 - 0.2, D - 0.08, -0.45), (B0 + 0.2, D - 0.08, -0.45))])
    mesh_object(name + "__water", water, ["well_water"], r, recalc=False)     # walk 3: lighter than the pit's, so it reads as water from above
    # The first fall (row 1's, ending at this floor) carried on down to the water.
    fall = bmesh.new()
    fall.faces.new([fall.verts.new(p) for p in ((CH0 + 0.15, D - 0.12, -0.47), (CH1 - 0.15, D - 0.12, -0.47), (CH1 - 0.15, D - 0.12, -0.1), (CH0 + 0.15, D - 0.12, -0.1))])
    mesh_object(name + "__fall", fall, ["fall_water"], r, recalc=False)
    cavern(r, name, seed=31.0, skirt=False, z_low=-0.3)
    marker("LIGHT_violet__foot", r, (10.0, 2.0, 2.2), {"energy": 0.8})


def ft_top(r):
    name = "ft_top"
    rng = random.Random(197)
    terrace(r, name, rng)
    cavern(r, name, seed=41.0)
    end_wall(r, name, D, -1.0, 43.0)
    # The spring: the cascade comes out of an arch in the far wall over the channel.
    body = solid(name + "__spring", r, [STONE], lambda bm: add_box(bm, CH0 - 0.3, CH1 - 0.1, D - 0.75, D - 0.25, -0.3, 1.6))
    cut(body, solid("cutter", r, [ROCK], lambda bm: add_prism(bm, arch_outline(0.9, 0.5, 0.6, 8), CH0 + 0.25, -0.31, D - 0.8, D - 0.2)))


# --- step 4: the outer patches, the workers and their things -------------------------

def _moved(bm, build, m):
    """Runs `build(bm)` and moves what it added by matrix `m`."""
    # Not bm.verts[n0:]: add_lathe merges its pole vertices, freeing slots
    # that the next build's vertices refill, so they can sit before n0 (walk 3:
    # the blight's caps left at its corner as a fan of shards).
    before = set(bm.verts)
    build(bm)
    bmesh.ops.transform(bm, matrix=m, verts=[v for v in bm.verts if v not in before])


def patch_tended(r):
    """A bed's outer end (X 0..OUT of the bed, origin at its corner on the row's
    floor, as a row piece's), tended: the crop in rows, as by the stair."""
    caps(r, "ft_patch_tended", random.Random(311), 0.25, OUT - 0.1)


def patch_wild(r):
    """Gone wild: caps crowded, bigger and taller, spilling over the curb onto
    the path, and shelf brackets glowing down the retaining wall's face."""
    rng = random.Random(337)
    crop = Crop(rng, (0.5, 0.3, 0.2))
    for _ in range(70):
        cx, cy = rng.uniform(0.2, OUT - 0.1), rng.uniform(CURB + 0.1, BED_D - 0.1)
        big = rng.random() ** 1.5
        crop.cap(cx, cy, SOIL, 0.15 + 0.75 * big, 0.1 + 0.28 * big, stalk=0.04 + 0.03 * big)
    for _ in range(14):                         # over the curb onto the path
        crop.cap(rng.uniform(0.3, OUT - 0.3), rng.uniform(BED_D + 0.05, BED_D + 0.55), 0.0, rng.uniform(0.1, 0.35), rng.uniform(0.08, 0.18))
    for _ in range(16):                         # brackets down the wall's face (Y 0, facing -Y)
        crop.shelf(rng.uniform(0.3, OUT - 0.3), 0.0, rng.uniform(-RISE + 0.25, -0.1), rng.uniform(0.1, 0.24), -1.0, axis="y")
    crop.write(r, "ft_patch_wild")


def patch_blight(r):
    """Blighted: a few caps left, grey-brown and dark, slumped; pale mould on
    the soil; a last few still glowing."""
    from mathutils import Matrix
    rng = random.Random(353)
    dead, mould, live = bmesh.new(), bmesh.new(), bmesh.new()
    for _ in range(26):
        cx, cy = rng.uniform(0.3, OUT - 0.2), rng.uniform(CURB + 0.2, BED_D - 0.2)
        h, cr = rng.uniform(0.04, 0.18), rng.uniform(0.08, 0.2)
        m = Matrix.Translation((cx, cy, SOIL)) @ Matrix.Rotation(rng.uniform(-0.6, 0.6), 4, "X") @ Matrix.Rotation(rng.uniform(-0.6, 0.6), 4, "Y")
        _moved(dead, lambda bm, h=h, cr=cr: add_lathe(bm, [(0.0, 0.0), (cr, h), (cr * 0.8, h + cr * 0.25), (0.0, h + cr * 0.3)], segs=6), m)
    for _ in range(9):
        add_lathe(mould, [(0.0, SOIL - 0.01), (rng.uniform(0.2, 0.45), SOIL + 0.005), (0.0, SOIL + 0.02)], rng.uniform(0.4, OUT - 0.4), rng.uniform(CURB + 0.4, BED_D - 0.4), segs=8)
    crop = Crop(rng, (0.3, 0.1, 0.6))
    for _ in range(5):
        crop.cap(rng.uniform(0.4, OUT - 0.4), rng.uniform(CURB + 0.3, BED_D - 0.3), SOIL, 0.1, rng.uniform(0.06, 0.1))
    mesh_object("ft_patch_blight__dead", dead, ["persian_fungus_cap"], r)
    mesh_object("ft_patch_blight__mould", mould, ["cobweb"], r)
    crop.write(r, "ft_patch_blight")


# The workers (Q9): hooded and robed, the face in the hood's shade, static, at
# work. Origin at the feet, facing -Y (from the path toward the bed's front).

def _figure(r, name, hip, lean, hands, kneel=False):
    """A robed figure: a skirt from the ground to `hip`, the body leaning
    `lean` radians forward (toward -Y) from the hip, a hood with a shadowed
    face, sleeves from the shoulders to `hands` (two points)."""
    from mathutils import Matrix, Vector
    robe, hood, shade, hb = bmesh.new(), bmesh.new(), bmesh.new(), bmesh.new()
    if kneel:
        add_lathe(robe, [(0.3, 0.0), (0.33, 0.12), (0.22, hip)], 0.0, 0.12, segs=8)
    else:
        add_lathe(robe, [(0.33, 0.0), (0.28, 0.25), (0.21, hip)], segs=8)
    body = Matrix.Translation((0.0, 0.0, hip)) @ Matrix.Rotation(lean, 4, "X")
    _moved(robe, lambda bm: add_lathe(bm, [(0.21, 0.0), (0.22, 0.3), (0.19, 0.5), (0.1, 0.56)], segs=8), body)
    head = body @ Matrix.Translation((0.0, -0.04, 0.5))
    _moved(hood, lambda bm: add_lathe(bm, [(0.0, 0.0), (0.2, 0.04), (0.19, 0.2), (0.14, 0.32), (0.0, 0.38)], segs=8), head)
    _moved(shade, lambda bm: add_lathe(bm, [(0.0, 0.0), (0.1, 0.02), (0.1, 0.18), (0.0, 0.2)], segs=6),
           head @ Matrix.Translation((0.0, -0.1, 0.17)) @ Matrix.Rotation(math.pi / 2, 4, "X"))
    for k, hx in enumerate((-0.2, 0.2)):
        sh = body @ Vector((hx, 0.0, 0.46))
        hp = Vector(hands[k])
        el = (sh + hp) / 2 + Vector((hx * 0.3, 0.04, -0.02))
        add_tube(robe, [tuple(sh), tuple(el), tuple(hp + Vector((0.0, 0.0, 0.05)))], [0.075, 0.065, 0.06], segs=6)
        _moved(hb, lambda bm: add_lathe(bm, [(0.0, -0.05), (0.045, -0.03), (0.04, 0.04), (0.0, 0.05)], segs=5), Matrix.Translation(hp))
    mesh_object(name + "__robe", robe, ["gorge_cloth"], r)
    mesh_object(name + "__hood", hood, ["persian_awning"], r)
    mesh_object(name + "__shade", shade, ["culvert_dark"], r)
    mesh_object(name + "__hands", hb, ["camp_leather"], r)
    # You walk into them, not through (a box over the figure, collision only).
    solid(name + "-colonly", r, [STONE], lambda bm: add_box(bm, -0.3, 0.3, -0.45, 0.35, 0.0, 1.4 if not kneel else 1.0))


def _basket(bw, bg, cx, cy, z=0.0, s=1.0, full=True):
    """A wicker basket (into `bw`), heaped with picked caps (into `bg`) if full."""
    add_lathe(bw, [(0.14 * s, z), (0.2 * s, z + 0.06 * s), (0.23 * s, z + 0.24 * s), (0.2 * s, z + 0.26 * s), (0.0, z + 0.2 * s)], cx, cy, segs=9)
    if full:
        rng = random.Random(int(cx * 100 + cy * 37))
        for _ in range(6):
            a, d = rng.uniform(0.0, 6.28), rng.uniform(0.0, 0.12 * s)
            cr = rng.uniform(0.05, 0.08) * s
            px, py, pz = cx + math.cos(a) * d, cy + math.sin(a) * d, z + 0.24 * s
            add_lathe(bg, [(0.0, pz - 0.01), (cr, pz), (cr * 0.8, pz + cr * 0.4), (0.0, pz + cr * 0.5)], px, py, segs=6)


def worker_stoop(r):
    """Bent over the bed, both hands in the crop; a basket at the feet."""
    _figure(r, "ft_worker_stoop", 0.82, 0.75, [(-0.16, -0.62, 0.42), (0.14, -0.66, 0.46)])
    w, g = bmesh.new(), bmesh.new()
    _basket(w, g, 0.45, -0.1)
    mesh_object("ft_worker_stoop__basket", w, ["wicker"], r)
    mesh_object("ft_worker_stoop__picked", g, ["ft_cap_violet"], r)


def worker_kneel(r):
    """Kneeling at the curb, cutting caps into a tray beside them."""
    _figure(r, "ft_worker_kneel", 0.42, 0.35, [(-0.15, -0.5, 0.42), (0.12, -0.52, 0.38)], kneel=True)
    t, g, k = bmesh.new(), bmesh.new(), bmesh.new()
    add_box(t, -0.75, -0.25, -0.2, 0.15, 0.0, 0.07)
    rng = random.Random(5)
    for _ in range(7):
        cx, cy, cr = rng.uniform(-0.68, -0.32), rng.uniform(-0.13, 0.08), rng.uniform(0.04, 0.07)
        add_lathe(g, [(0.0, 0.06), (cr, 0.07), (cr * 0.8, 0.07 + cr * 0.4), (0.0, 0.07 + cr * 0.5)], cx, cy, segs=6)
    add_obox(k, (0.12, -0.6, 0.36), (0.02, 0.16, 0.03), (0.3, 0.0, 0.2))      # the knife
    mesh_object("ft_worker_kneel__tray", t, ["wood"], r)
    mesh_object("ft_worker_kneel__picked", g, ["ft_cap_violet"], r)
    mesh_object("ft_worker_kneel__knife", k, ["iron"], r)


def worker_carry(r):
    """Standing, a full basket on the hip, looking over the bed."""
    _figure(r, "ft_worker_carry", 0.95, 0.08, [(-0.2, -0.12, 0.72), (0.34, -0.05, 0.86)])
    w, g = bmesh.new(), bmesh.new()
    _basket(w, g, 0.38, 0.0, 0.72, 0.9)
    mesh_object("ft_worker_carry__basket", w, ["wicker"], r)
    mesh_object("ft_worker_carry__picked", g, ["ft_cap_violet"], r)


def bed_tools(r):
    """At a bed's end against the next terrace's wall (origin on the path's
    floor at the wall's foot, the wall toward +Y): a hoe and a rake leaning,
    trays stacked, an empty basket and a full one."""
    wood, iron, wk, g = bmesh.new(), bmesh.new(), bmesh.new(), bmesh.new()
    for (x, lean, head) in ((-0.5, 0.25, "hoe"), (-0.25, 0.2, "rake")):
        top = (x + 0.05, -0.05, 1.45)
        foot = (x - 0.05, -0.05 - 1.45 * math.tan(lean), 0.0)
        add_tube(wood, [foot, top], 0.025, segs=5)
        if head == "hoe":
            add_obox(iron, (foot[0], foot[1] - 0.05, 0.06), (0.18, 0.04, 0.12), (0.0, 0.0, 0.0))
        else:
            add_obox(iron, (foot[0], foot[1], 0.04), (0.32, 0.04, 0.04), (0.0, 0.0, 0.0))
            for k in range(6):
                add_obox(iron, (foot[0] - 0.14 + k * 0.056, foot[1] - 0.04, 0.02), (0.015, 0.06, 0.04), (0.0, 0.0, 0.0))
    for k in range(4):                          # trays
        add_box(wood, 0.05, 0.6, -0.5, -0.1, k * 0.08, k * 0.08 + 0.06)
    _basket(wk, g, 0.95, -0.35, 0.0, 1.0, full=False)
    _basket(wk, g, 0.95, -0.85, 0.0, 0.9, full=True)
    mesh_object("ft_bed_tools__wood", wood, ["wood"], r)
    mesh_object("ft_bed_tools__iron", iron, ["iron"], r)
    mesh_object("ft_bed_tools__baskets", wk, ["wicker"], r)
    mesh_object("ft_bed_tools__picked", g, ["ft_cap_violet"], r)


def shelter(r):
    """The shelter at the foot (origin at its back-left corner against the
    entry wall, X 0..6 along the wall, Y 0..2.6 out from it): a lean-to of
    poles and cloth, sacks of the harvest, a drying rack hung with caps, a low
    bench and baskets."""
    wood, cloth, sacks, wk, g, dry = bmesh.new(), bmesh.new(), bmesh.new(), bmesh.new(), bmesh.new(), bmesh.new()
    for (x, y, h) in ((0.2, 0.45, 2.6), (5.8, 0.45, 2.6), (0.2, 2.4, 1.9), (5.8, 2.4, 1.9), (3.0, 2.4, 1.9)):
        add_lathe(wood, [(0.06, 0.0), (0.05, h)], x, y, segs=6)
    add_box(wood, 0.1, 5.9, 0.4, 0.5, 2.5, 2.62)
    add_box(wood, 0.1, 5.9, 2.35, 2.45, 1.82, 1.94)
    nx, ny = 12, 4
    vs = []
    for i in range(nx + 1):
        row = []
        for j in range(ny + 1):
            x, t = 6.0 * i / nx, j / ny
            y = 0.4 + 2.15 * t
            z = 2.62 + (1.95 - 2.62) * t - 0.12 * math.sin(math.pi * t) * (0.6 + 0.4 * math.sin(math.pi * i / nx))
            row.append(cloth.verts.new((x, y, z)))
        vs.append(row)
    for i in range(nx):
        for j in range(ny):
            f = (vs[i][j], vs[i + 1][j], vs[i + 1][j + 1], vs[i][j + 1])
            cloth.faces.new(f)
            cloth.faces.new([cloth.verts.new(v.co) for v in reversed(f)])
    rng = random.Random(71)
    for k in range(7):                          # sacks along the wall
        cx, cy = 0.5 + k * 0.42 + rng.uniform(-0.05, 0.05), 0.75 + rng.uniform(-0.1, 0.15)
        s = rng.uniform(0.85, 1.15)
        add_lathe(sacks, [(0.0, 0.0), (0.2 * s, 0.03), (0.24 * s, 0.25 * s), (0.18 * s, 0.5 * s), (0.07, 0.6 * s), (0.09, 0.66 * s), (0.0, 0.68 * s)], cx, cy, segs=8)
    for x in (3.6, 5.5):                        # the drying rack
        add_lathe(wood, [(0.04, 0.0), (0.035, 1.7)], x, 1.6, segs=5)
    for z in (0.9, 1.25, 1.6):
        add_tube(wood, [(3.6, 1.6, z), (5.5, 1.6, z)], 0.02, segs=5)
        x = 3.75
        while x < 5.4:
            cr = rng.uniform(0.05, 0.08)
            add_lathe(dry, [(0.0, z - 0.14), (cr, z - 0.12), (cr * 0.7, z - 0.12 + cr * 0.4), (0.0, z - 0.02)], x, 1.6, segs=6)
            x += rng.uniform(0.14, 0.2)
    add_box(wood, 0.4, 2.4, 1.6, 1.95, 0.38, 0.45)          # the bench
    for x in (0.55, 2.25):
        add_box(wood, x - 0.05, x + 0.05, 1.65, 1.9, 0.0, 0.38)
    _basket(wk, g, 2.9, 1.2, 0.0, 1.0, True)
    _basket(wk, g, 0.9, 1.75, 0.45, 0.8, True)
    _basket(wk, g, 3.2, 0.8, 0.0, 0.9, False)
    mesh_object("ft_shelter__wood", wood, ["wood"], r)
    mesh_object("ft_shelter__cloth", cloth, ["persian_awning"], r, recalc=False)
    mesh_object("ft_shelter__sacks", sacks, ["camp_linen"], r)
    mesh_object("ft_shelter__baskets", wk, ["wicker"], r)
    mesh_object("ft_shelter__picked", g, ["ft_cap_violet"], r)
    mesh_object("ft_shelter__drying", dry, ["persian_fungus_cap"], r)
    solid("ft_shelter__body-colonly", r, ["wood"], lambda bm: add_box(bm, 0.1, 5.9, 0.4, 2.0, 0.0, 1.8))
    # The workers' lamp (rev 2: the shelter was lost in the dark): no flame, a
    # jar of glowing caps hung from the front beam on a cord, one dim light.
    jar, glow, cord = bmesh.new(), bmesh.new(), bmesh.new()
    for jx in (1.6, 4.4):
        add_tube(cord, [(jx, 2.4, 1.82), (jx, 2.4, 1.45)], 0.01, segs=4)
        add_lathe(jar, [(0.0, 1.12), (0.1, 1.14), (0.13, 1.25), (0.1, 1.4), (0.05, 1.43), (0.06, 1.47), (0.0, 1.47)], jx, 2.4, segs=8)
        add_lathe(glow, [(0.0, 1.15), (0.09, 1.17), (0.08, 1.33), (0.0, 1.36)], jx, 2.4, segs=7)
    mesh_object("ft_shelter__jars", jar, ["emit_glass_cool"], r)
    mesh_object("ft_shelter__jar_caps", glow, ["emit_violet"], r)
    mesh_object("ft_shelter__cords", cord, ["camp_linen"], r)
    marker("LIGHT_violet__shelter", r, (3.0, 2.1, 1.3), {"energy": 0.6})



MODULES = [
    ("M_ft_row_0", props("cell", [5, 3, 1], "", "rock,cavern,fungus,r15,walled"), ft_row(0)),
    ("M_ft_row_1", props("cell", [5, 3, 1], "", "rock,cavern,fungus,r15,walled"), ft_row(1)),
    ("M_ft_row_2", props("cell", [5, 3, 1], "", "rock,cavern,fungus,r15,walled"), ft_row(2)),
    ("M_ft_foot", props("cell", [5, 3, 1], "", "rock,cavern,fungus,r15,walled,door"), ft_foot),
    ("M_ft_top", props("cell", [5, 3, 1], "", "rock,cavern,fungus,r15,walled,door"), ft_top),
    # Step 4: the outer patches, the workers and their things.
    ("M_ft_patch_tended", props("free", [1, 0, 1], "", "fungus,r15", family="dressing"), patch_tended),
    ("M_ft_patch_wild", props("free", [1, 0, 1], "", "fungus,r15", family="dressing"), patch_wild),
    ("M_ft_patch_blight", props("free", [1, 0, 1], "", "fungus,r15", family="dressing"), patch_blight),
    ("M_ft_worker_stoop", props("free", [0, 0, 0], "", "figure,r15", family="dressing"), worker_stoop),
    ("M_ft_worker_kneel", props("free", [0, 0, 0], "", "figure,r15", family="dressing"), worker_kneel),
    ("M_ft_worker_carry", props("free", [0, 0, 0], "", "figure,r15", family="dressing"), worker_carry),
    ("M_ft_bed_tools", props("free", [0, 0, 0], "", "wood,r15", family="dressing"), bed_tools),
    ("M_ft_shelter", props("free", [1, 0, 1], "", "wood,cloth,r15", family="dressing"), shelter),
]

# Script-made modules remade in place at a new revision (kit_blender.rebuild).
REBUILD = [("M_ft_row_0", 9), ("M_ft_row_1", 9), ("M_ft_row_2", 9), ("M_ft_foot", 11), ("M_ft_top", 10), ("M_ft_shelter", 3), ("M_ft_patch_tended", 2), ("M_ft_patch_wild", 2), ("M_ft_patch_blight", 3), ("M_ft_worker_stoop", 3), ("M_ft_worker_kneel", 3), ("M_ft_worker_carry", 3), ("M_ft_bed_tools", 2)]  # rev 2: side walls face in, reach past the roof; rev 3: end walls face in; rev 3/4 (walk 1): cascade beside the stair, bed sides + fill, stone path, rock door mouths


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
        x += 28.0
    rebuilt = ["%s (rev %d)" % (n, v) for (n, v) in REBUILD if rebuild(n, v, MODULES)]
    if not added and not rebuilt:
        print("kit_add_r15: everything already present; nothing to do.")
        return
    os.makedirs(os.path.dirname(BLEND), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=BLEND)
    print("kit_add_r15: added %s; rebuilt %s" % (", ".join(added) or "nothing", ", ".join(rebuilt) or "nothing"))


main()

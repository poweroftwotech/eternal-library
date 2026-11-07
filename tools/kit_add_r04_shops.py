"""Seeds the R04 Grand Bazaar's shops into art_src/kit/kit_bazaar.blend (phase 15
step 3, docs/environment/phase-15-approval.md).

  blender --background --factory-startup --python tools/kit_add_r04_shops.py

Then run tools/export_kit.bat kit_bazaar.blend. Run tools/kit_add_r04.py first:
this adds to its file.

Each trade is one piece, in the shop's side frame (tools/kit_add_r04.py): X along
the street 0..4, the aisle on +Y, the shop front on Y 0, the room behind it on -Y.
The room is X 0.15..3.85, Y -0.4..-4.1. The middle of the arch (X 1.1..2.9) stays
clear so you can walk in; a keeper stands behind the counter (Y about -3.6). What
spills into the street stays within 0.9 m of the wall, off the piers.

A trade is one mesh (one surface per material, so a shop costs a few draw calls)
and one mesh of plain collision boxes: see Shop.

  bz_trade_rugs      stacks, rolls, rugs hung on the walls, one on the floor
  bz_trade_copper    trays on the walls, pots on a rail, cauldrons
  bz_trade_lamps     hanging lamps of coloured glass in brass
  bz_trade_books     shelves of coloured spines, stacks, tables in the street
  bz_trade_spices    open sacks in mounds, tins, strings of dried peppers, a scale
  bz_trade_curios    a jumble: boxes, brass, a chest, a mirror, a globe, a cage
  bz_trade_food      a cauldron on embers, bread, fruit, tables outside
  bz_awning_a, _b    a cloth over a shop's front
  bz_shut_bar        a bar and lock on a shut shop
  bz_shut_crates     crates left against a shut shop
  bz_pennants        a line of pennants across the street (street frame)
  bz_keeper_a.._c    someone behind a counter (side frame)
  bz_fig_a.._h       people, one each; bz_group_* two or three together
  bz_fountain, bz_story   the crossing's middle, by seed
  bz_rumour_board    pinned notes (RumourBoard reads them)
  bz_shut_hooks, bz_shut_dust   the quiet ends of the rows
  bz_bare, bz_awning_rag_*, bz_pennants_rag, bz_fountain_dry, bz_story_bare,
  bz_rumour_board_old   the deserted bazaar
"""
import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kit_blender import add_box, add_lathe, add_obox, add_tube, marker, mesh_object, module, rebuild

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BLEND = os.path.join(ROOT, "art_src", "kit", "kit_bazaar.blend")
ROW_Y = -230.0
WOOD, COPPER, BRASS, LINEN = "persian_wood", "bazaar_copper", "bazaar_brass", "camp_linen"
CERAMIC, GLAZED, STONE, MIRROR = "camp_ceramic", "camp_glazed_ceramic", "persian_stone", "persian_mirror"
GLASS, GOODS, EMBER = "bazaar_glass", "bazaar_goods", "bazaar_embers"
RUGS = ["rug_herati_small", "rug_kilim_small", "rug_medallion_small", "rug_garden_small"]
# The palette bazaar_goods.png (tools/pixel_materials_ext.gd), two shades of each.
SAFFRON, TURMERIC, PAPRIKA, SUMAC, CUMIN, PISTACHIO, ROSE, TEA = 0, 2, 4, 6, 8, 10, 12, 14
BREAD, CRUST, POMEGRANATE, APRICOT, GRAPE, MELON, CHEESE, IRON = 16, 18, 20, 22, 24, 26, 28, 30
BOOK_RED, BOOK_BLUE, BOOK_GREEN, BOOK_BROWN = 32, 34, 36, 38
SHADES = 40
# bazaar_glass.png: each colour's [ends, belly].
GLASS_SHADES = 16
RED, BLUE, AMBER, PALE = (2, 1), (5, 4), (8, 7), (10, 11)
# Each trade has its own mood: the glow of its lamp (a shade of bazaar_glass.png),
# then the colour and strength of its light. Your walk of step 3: the shops were too
# bright, and all one colour.
MOODS = {
    "rugs": (15, [1.0, 0.58, 0.44], 0.55),      # wine: deepens the reds
    "copper": (14, [1.0, 0.5, 0.24], 0.6),      # forge orange, on the metal
    "lamps": (8, [1.0, 0.7, 0.5], 0.28),        # nearly dark, so the glass shines
    "books": (10, [0.96, 0.86, 0.68], 0.42),    # a quiet reading light
    "spices": (7, [1.0, 0.8, 0.28], 0.6),       # saffron
    "curios": (13, [0.4, 0.72, 0.78], 0.55),    # sea-green, a little strange
    "food": (7, [1.0, 0.64, 0.36], 0.55),       # the hearth's colour
}


def props(tags="bazaar,r04,shop"):
    return {"kit_shape": "free", "kit_family": "walls", "size_cells": [0, 0, 0], "edge": "", "tags": tags, "weight": 1.0}


class Shop:
    """One mesh for everything you see and one of boxes for what you bump into."""

    def __init__(self, r, name):
        self.r, self.name, self.bm, self.mats, self.blocks = r, name, bmesh.new(), [], []
        self.uv = self.bm.loops.layers.uv.verify()

    def m(self, material):
        if material not in self.mats:
            self.mats.append(material)
        return self.mats.index(material)

    def mark(self):
        return len(self.bm.faces)

    def since(self, start):
        # Not bm.faces[start:]: that slice drops its first face.
        return list(self.bm.faces)[start:]

    def smooth(self, start):
        for f in self.since(start):
            f.smooth = True

    def tint(self, start, index, count=SHADES):
        """Pick one colour of a palette texture for what was added since start."""
        for f in self.since(start):
            for loop in f.loops:
                loop[self.uv].uv = ((index + 0.5) / count, 0.5)

    def block(self, x0, x1, y0, y1, z0, z1):
        self.blocks.append((x0, x1, y0, y1, z0, z1))

    def finish(self):
        mesh_object(self.name + "__goods", self.bm, self.mats, self.r)
        if self.blocks:
            bm = bmesh.new()
            for b in self.blocks:
                add_box(bm, *b)
            mesh_object(self.name + "__blocks-colonly", bm, [WOOD], self.r)


def shop_lamp(s, trade):
    """A brass lamp on a rod in the middle of the shop, and the shop's light."""
    glow, color, energy = MOODS[trade]
    x, y, z, top = 2.0, -2.25, 2.7, 4.65
    b, g = s.m(BRASS), s.m(GLASS)
    add_box(s.bm, x - 0.012, x + 0.012, y - 0.012, y + 0.012, z + 0.42, top, b)
    add_box(s.bm, x - 0.13, x + 0.13, y - 0.13, y + 0.13, z + 0.36, z + 0.42, b)
    add_box(s.bm, x - 0.13, x + 0.13, y - 0.13, y + 0.13, z, z + 0.05, b)
    for sx in (-1, 1):
        for sy in (-1, 1):
            add_box(s.bm, x + sx * 0.11 - 0.015, x + sx * 0.11 + 0.015, y + sy * 0.11 - 0.015, y + sy * 0.11 + 0.015, z + 0.05, z + 0.36, b)
    start = s.mark()
    add_box(s.bm, x - 0.09, x + 0.09, y - 0.09, y + 0.09, z + 0.05, z + 0.36, g)
    s.tint(start, glow, GLASS_SHADES)
    # No shadows (21 lights), so it shines through walls: its reach stops short of
    # the next shop's arch, or the colour draws a line round it.
    marker("LIGHT_lantern__shop", s.r, (x, -2.5, 2.2), {"range": 3.7, "energy": energy * 1.15, "color": color})


def slab(s, x0, x1, y0, y1, z0, z1, mat, row=0.5):
    """A thin box with a rug's map across its largest face. Its edges show one
    row of the rug: the colours of a folded stack."""
    start = s.mark()
    add_box(s.bm, x0, x1, y0, y1, z0, z1, mat)
    lo, hi = (x0, y0, z0), (x1, y1, z1)
    thin, a, b = sorted(range(3), key=lambda i: hi[i] - lo[i])
    for f in s.since(start):
        cos = [loop.vert.co for loop in f.loops]
        flat = [len({round(c[i], 5) for c in cos}) == 1 for i in range(3)]
        for loop in f.loops:
            co = loop.vert.co
            u, v = (co[a] - lo[a]) / (hi[a] - lo[a]), (co[b] - lo[b]) / (hi[b] - lo[b])
            loop[s.uv].uv = (u, v) if flat[thin] else ((row, v) if flat[a] else (u, row))


def roll(s, x, y, z0, height, radius, mat):
    """A rolled rug standing on its end."""
    add_lathe(s.bm, [(0.0, z0), (radius, z0), (radius, z0 + height), (0.0, z0 + height)], x, y, 10, mat, s.uv)


def tray(s, cx, cy, cz, radius, mat, axis="y"):
    """A beaten dish on a wall, its face to +Y or +X: rim, well, boss."""
    bm, segs = s.bm, 16
    profile = [(1.0, 0.0), (1.0, 0.05), (0.93, 0.07), (0.86, 0.03), (0.45, 0.02), (0.4, 0.05), (0.14, 0.05), (0.1, 0.07)]
    rings = []
    for (fr, d) in profile:
        ring = []
        for i in range(segs):
            a = 2 * math.pi * i / segs
            u, v, off = radius * fr * math.cos(a), radius * fr * math.sin(a), radius * d
            ring.append(bm.verts.new((cx + u, cy + off, cz + v) if axis == "y" else (cx + off, cy + u, cz + v)))
        rings.append(ring)
    for k in range(len(rings) - 1):
        for i in range(segs):
            j = (i + 1) % segs
            bm.faces.new((rings[k][i], rings[k][j], rings[k + 1][j], rings[k + 1][i])).material_index = mat
    bm.faces.new(rings[-1]).material_index = mat


def pot(s, x, y, z, k, mat):
    """A round-bellied pot with a neck."""
    start = s.mark()
    add_lathe(s.bm, [(0.0, z), (0.09 * k, z), (0.17 * k, z + 0.1 * k), (0.19 * k, z + 0.2 * k), (0.13 * k, z + 0.32 * k),
                     (0.07 * k, z + 0.38 * k), (0.09 * k, z + 0.44 * k), (0.0, z + 0.44 * k)], x, y, 12, mat)
    s.smooth(start)


def ewer(s, x, y, z, k, mat):
    """A tall jug with a narrow waist."""
    start = s.mark()
    add_lathe(s.bm, [(0.0, z), (0.1 * k, z), (0.13 * k, z + 0.12 * k), (0.06 * k, z + 0.3 * k), (0.05 * k, z + 0.4 * k),
                     (0.08 * k, z + 0.48 * k), (0.0, z + 0.48 * k)], x, y, 12, mat)
    s.smooth(start)


def cauldron(s, x, y, z, k, mat):
    start = s.mark()
    add_lathe(s.bm, [(0.0, z), (0.2 * k, z), (0.34 * k, z + 0.14 * k), (0.36 * k, z + 0.3 * k), (0.33 * k, z + 0.42 * k),
                     (0.36 * k, z + 0.44 * k), (0.0, z + 0.44 * k)], x, y, 14, mat)
    s.smooth(start)


def ball(s, x, y, z, radius, mat, colour=None, squash=1.0):
    """Fruit, a melon: z is its middle."""
    start = s.mark()
    h = radius * squash
    add_lathe(s.bm, [(0.0, z - h), (radius * 0.7, z - h * 0.72), (radius, z), (radius * 0.7, z + h * 0.72), (0.0, z + h)], x, y, 8, mat)
    s.smooth(start)
    if colour is not None:
        s.tint(start, colour)


def pile(s, x, y, z, radius, n, mat, colour, rng):
    """A heap of fruit on a dish: a ring of them, and more on top."""
    ring = max(n - 3, 3)
    for i in range(ring):
        a = 2 * math.pi * i / ring
        ball(s, x + (0.16 * math.cos(a)), y + (0.16 * math.sin(a)), z + radius, radius, mat, colour + (i % 2))
    for i in range(n - ring):
        a = 2 * math.pi * i / max(n - ring, 1) + 0.5
        ball(s, x + (0.06 * math.cos(a)), y + (0.06 * math.sin(a)), z + radius * 2.5, radius, mat, colour + (i % 2))


def dish(s, x, y, z, radius, mat):
    add_lathe(s.bm, [(0.0, z), (radius * 0.6, z), (radius, z + 0.05), (radius * 0.92, z + 0.06), (0.0, z + 0.03)], x, y, 12, mat)


def mound(s, x, y, z, radius, height, mat, colour):
    """Spice heaped up: its faces in the colour's two shades, for grain."""
    start = s.mark()
    add_lathe(s.bm, [(radius, z), (radius * 0.8, z + height * 0.4), (radius * 0.45, z + height * 0.85), (0.0, z + height)], x, y, 12, mat)
    for i, f in enumerate(s.since(start)):
        for loop in f.loops:
            loop[s.uv].uv = ((colour + (i * 7 % 3 == 0) + 0.5) / SHADES, 0.5)


def sack(s, x, y, radius, height, mat, rng):
    """A sack with its neck rolled down: belly, and a fat roll round the mouth."""
    start, verts = s.mark(), len(s.bm.verts)
    add_lathe(s.bm, [(0.0, 0.0), (radius * 0.9, 0.0), (radius * 1.08, height * 0.35), (radius, height * 0.72), (radius * 1.1, height * 0.82),
                     (radius * 1.14, height * 0.92), (radius * 1.04, height), (radius * 0.86, height * 0.98), (0.0, height * 0.94)], x, y, 12, mat)
    bumps = [rng.uniform(0.94, 1.06) for _ in range(12)]
    s.bm.verts.ensure_lookup_table()
    for v in list(s.bm.verts)[verts:]:
        a = math.atan2(v.co.y - y, v.co.x - x)
        k = bumps[int((a + math.pi) / (2 * math.pi) * 12) % 12]
        v.co.x, v.co.y = x + (v.co.x - x) * k, y + (v.co.y - y) * k
    s.smooth(start)
    s.tint(start, BREAD + rng.randrange(2))


def string_of(s, x, y, top, n, mat, colour, rng, rope):
    """Dried peppers or garlic on a string, hung from a rail."""
    add_tube(s.bm, [(x, y, top), (x, y, top - 0.08 * n - 0.06)], 0.006, 3, rope)
    for i in range(n):
        a = i * 2.4
        ball(s, x + 0.035 * math.cos(a), y + 0.035 * math.sin(a), top - 0.1 - 0.08 * i, 0.04, mat, colour + rng.randrange(2), 1.5)


def wall_rail(s, x, y0, y1, z, mat):
    add_box(s.bm, x - 0.02, x + 0.02, y0, y1, z, z + 0.04, mat)
    for y in (y0, y1 - 0.04):
        wall = 0.15 if x < 2.0 else 3.85
        add_box(s.bm, min(x, wall), max(x, wall), y, y + 0.04, z, z + 0.04, mat)


def counter(s, x0=0.5, x1=3.5):
    """The keeper's counter across the back: panelled, on a plinth."""
    w = s.m(WOOD)
    add_box(s.bm, x0, x1, -3.2, -2.74, 0.0, 0.1, w)
    add_box(s.bm, x0 + 0.02, x1 - 0.02, -3.2, -2.8, 0.1, 0.92, w)
    add_box(s.bm, x0 - 0.04, x1 + 0.04, -3.24, -2.72, 0.92, 0.98, w)
    add_box(s.bm, x0 + 0.02, x1 - 0.02, -2.8, -2.76, 0.82, 0.92, w)
    add_box(s.bm, x0 + 0.02, x1 - 0.02, -2.8, -2.76, 0.1, 0.2, w)
    n = 5
    for i in range(n + 1):
        x = x0 + 0.02 + (x1 - x0 - 0.12) * i / n
        add_box(s.bm, x, x + 0.08, -2.8, -2.76, 0.2, 0.82, w)
    s.block(x0, x1, -3.24, -2.72, 0.0, 0.98)


def side_shelves(s, sides=(0, 1), levels=(0.75, 1.35, 1.95, 2.55), top=None):
    """Shelves up a side wall, with a back of boards. Returns (x0, x1, y0, y1, z)
    for each shelf, z its top."""
    w, boards = s.m(WOOD), []
    for side in sides:
        x0, x1 = (0.15, 0.55) if side == 0 else (3.45, 3.85)
        back = (0.15, 0.19) if side == 0 else (3.81, 3.85)
        add_box(s.bm, back[0], back[1], -2.65, -0.5, 0.0, levels[-1] + 0.06, w)
        for y in (-0.55, -2.6):
            add_box(s.bm, x0, x1, y - 0.05, y + 0.05, 0.0, levels[-1] + 0.06, w)
        for z in levels:
            add_box(s.bm, x0, x1, -2.65, -0.5, z, z + 0.05, w)
            boards.append((x0 + 0.05, x1 - 0.05, -2.52, -0.63, z + 0.05))
        s.block(x0, x1, -2.65, -0.5, 0.0, levels[-1] + 0.06)
    return boards


def back_shelves(s, levels=(1.25, 1.75, 2.25, 2.75)):
    """Shelves on the back wall, over the counter, behind the keeper."""
    w, boards = s.m(WOOD), []
    add_box(s.bm, 0.25, 3.75, -4.1, -4.06, levels[0] - 0.06, levels[-1] + 0.5, w)
    for x in (0.25, 3.7):
        add_box(s.bm, x, x + 0.05, -4.1, -3.8, levels[0] - 0.06, levels[-1] + 0.5, w)
    for z in levels + (levels[-1] + 0.45,):
        add_box(s.bm, 0.25, 3.75, -4.1, -3.8, z, z + 0.05, w)
    for z in levels:
        boards.append((0.34, 3.66, -4.04, -3.83, z + 0.05))
    return boards


def street_table(s, x0, x1):
    """A low table in front of a pier, within the spill."""
    w = s.m(WOOD)
    add_box(s.bm, x0, x1, 0.15, 0.8, 0.62, 0.68, w)
    for x in (x0 + 0.04, x1 - 0.1):
        for y in (0.2, 0.68):
            add_box(s.bm, x, x + 0.06, y, y + 0.06, 0.0, 0.62, w)
    s.block(x0, x1, 0.15, 0.8, 0.0, 0.68)


def street_crate(s, x0, x1, height):
    add_box(s.bm, x0, x1, 0.15, 0.8, 0.0, height, s.m(WOOD))
    s.block(x0, x1, 0.15, 0.8, 0.0, height)


def rugs(r):
    s = Shop(r, "bz_trade_rugs")
    rng = random.Random(s.name)
    shop_lamp(s, "rugs")
    m = [s.m(n) for n in RUGS]
    slab(s, 0.45, 1.65, -4.09, -4.06, 1.1, 3.0, m[0])
    slab(s, 1.75, 2.75, -4.09, -4.06, 1.25, 2.9, m[1])
    slab(s, 2.85, 3.6, -4.09, -4.06, 1.0, 2.6, m[2])
    slab(s, 0.16, 0.19, -2.5, -0.9, 1.3, 3.0, m[3])
    slab(s, 3.81, 3.84, -2.3, -0.9, 1.4, 3.0, m[1])
    slab(s, 1.2, 2.8, -2.6, -0.6, 0.0, 0.012, m[2])

    def stack(x0, x1, y0, y1, top):
        z = 0.0
        while z < top:
            h = rng.uniform(0.05, 0.09)
            o = rng.uniform(-0.03, 0.03)
            slab(s, x0 + o, x1 + o, y0, y1, z, z + h, m[rng.randrange(4)], rng.uniform(0.2, 0.8))
            z += h
        s.block(x0, x1, y0, y1, 0.0, top)
    stack(0.2, 1.05, -2.6, -0.8, 0.95)
    stack(0.6, 3.4, -3.2, -2.75, 0.86)
    for (x, y) in ((3.65, -2.4), (3.4, -2.2), (3.65, -1.95), (3.38, -1.7), (3.65, -1.45), (3.4, -1.15), (3.66, -0.95)):
        roll(s, x, y, 0.0, rng.uniform(1.5, 2.3), rng.uniform(0.09, 0.13), m[rng.randrange(4)])
    s.block(3.25, 3.8, -2.55, -0.82, 0.0, 2.0)
    # In the street: a rail with a rug over it, rolls by the other pier.
    w = s.m(WOOD)
    add_box(s.bm, 0.34, 1.02, 0.42, 0.46, 1.3, 1.34, w)
    for x in (0.34, 0.98):
        add_box(s.bm, x, x + 0.04, 0.42, 0.46, 0.0, 1.3, w)
    slab(s, 0.38, 0.98, 0.46, 0.475, 0.25, 1.36, m[0])
    slab(s, 0.38, 0.98, 0.405, 0.42, 0.45, 1.36, m[0])
    s.block(0.34, 1.02, 0.4, 0.48, 0.0, 1.36)
    for (x, y) in ((3.3, 0.3), (3.55, 0.45), (3.3, 0.6)):
        roll(s, x, y, 0.0, rng.uniform(1.4, 1.9), 0.11, m[rng.randrange(4)])
    s.block(3.18, 3.67, 0.18, 0.72, 0.0, 1.8)
    s.finish()


def copper(r):
    s = Shop(r, "bz_trade_copper")
    rng = random.Random(s.name)
    shop_lamp(s, "copper")
    counter(s)
    c, b, w = s.m(COPPER), s.m(BRASS), s.m(WOOD)
    for (x, z, rad) in ((0.75, 2.2, 0.4), (1.6, 2.5, 0.3), (2.35, 2.15, 0.45), (3.25, 2.5, 0.32), (1.45, 1.7, 0.22), (3.2, 1.75, 0.26)):
        tray(s, x, -4.1, z, rad, c if x < 2.0 else b)
    for (y, z, rad) in ((-1.0, 2.3, 0.38), (-1.85, 2.5, 0.3), (-1.5, 1.7, 0.26)):
        tray(s, 0.15, y, z, rad, c, "x")
    wall_rail(s, 3.7, -2.5, -0.6, 2.46, w)
    for i, y in enumerate((-0.8, -1.2, -1.6, -2.0, -2.35)):
        k = (0.7, 0.9, 0.6, 0.85, 0.65)[i]
        add_box(s.bm, 3.69, 3.71, y - 0.01, y + 0.01, 2.1, 2.46, b)
        pot(s, 3.7, y, 2.1 - 0.44 * k, k, c)
    cauldron(s, 0.52, -2.2, 0.0, 1.0, c)
    cauldron(s, 0.5, -1.45, 0.0, 0.85, c)
    cauldron(s, 0.5, -1.45, 0.38, 0.7, c)
    cauldron(s, 0.48, -0.85, 0.0, 0.7, c)
    cauldron(s, 3.42, -1.2, 0.0, 0.8, c)
    s.block(0.15, 0.88, -2.56, -0.6, 0.0, 0.7)
    s.block(3.13, 3.71, -1.49, -0.91, 0.0, 0.35)
    for x in (0.8, 1.2, 1.7, 2.3, 2.9, 3.25):
        (ewer if rng.random() < 0.6 else pot)(s, x, -3.0, 0.98, rng.uniform(0.6, 0.9), b if rng.random() < 0.5 else c)
    street_crate(s, 3.03, 3.68, 0.6)
    cauldron(s, 3.35, 0.47, 0.6, 0.7, c)
    pot(s, 0.65, 0.45, 0.0, 1.5, c)
    ewer(s, 0.95, 0.3, 0.0, 1.4, b)
    s.block(0.36, 1.12, 0.12, 0.76, 0.0, 0.68)
    tray(s, 0.65, 0.0, 2.6, 0.3, c)
    tray(s, 3.3, 0.0, 2.7, 0.26, b)
    s.finish()


def lamps(r):
    s = Shop(r, "bz_trade_lamps")
    rng = random.Random(s.name)
    shop_lamp(s, "lamps")
    counter(s)
    shelves = side_shelves(s, (0, 1), (0.9, 1.6))
    g, b = s.m(GLASS), s.m(BRASS)
    bodies = (
        [(0.0, 0.0), (0.05, 0.015), (0.11, 0.06), (0.15, 0.14), (0.11, 0.24), (0.05, 0.29), (0.0, 0.3)],      # a globe
        [(0.0, -0.12), (0.04, -0.06), (0.09, 0.03), (0.12, 0.15), (0.08, 0.26), (0.04, 0.31), (0.0, 0.32)],   # a drop
        [(0.0, 0.0), (0.07, 0.01), (0.15, 0.06), (0.2, 0.14), (0.17, 0.2), (0.08, 0.22), (0.0, 0.22)],        # a bowl
    )

    def glass(x, y, z, k, kind):
        """A lamp's body, its belly a brighter shade, in four brass ribs."""
        colour = rng.choice((RED, RED, BLUE, BLUE, AMBER, PALE))
        profile = [(p * k, z + q * k) for (p, q) in bodies[kind]]
        start = s.mark()
        add_lathe(s.bm, profile, x, y, 10, g)
        lo, hi = profile[0][1], profile[-1][1]
        for f in s.since(start):
            t = (f.calc_center_median().z - lo) / (hi - lo)
            index = colour[1] if 0.25 < t < 0.75 else colour[0]
            for loop in f.loops:
                loop[s.uv].uv = ((index + 0.5) / GLASS_SHADES, 0.5)
        for i in range(4):
            a = math.pi * i / 2 + 0.4
            path = [(x + p * 1.04 * math.cos(a), y + p * 1.04 * math.sin(a), q) for (p, q) in profile]
            add_tube(s.bm, path, 0.005 * max(k, 1.0), 3, b)
        add_lathe(s.bm, [(0.0, lo - 0.02), (0.022, lo), (0.0, lo + 0.03)], x, y, 6, b)
        return hi

    def hanging(x, y, z, k, kind, rod_top):
        hi = glass(x, y, z, k, kind)
        add_lathe(s.bm, [(0.075 * k, hi - 0.03), (0.05 * k, hi + 0.03), (0.018, hi + 0.08), (0.0, hi + 0.08)], x, y, 8, b)
        add_tube(s.bm, [(x, y, hi + 0.07), (x, y, rod_top)], 0.006, 4, b)

    for i in range(13):
        x, y = 0.75 + (i % 4) * 0.82 + rng.uniform(-0.12, 0.12), -0.85 - (i // 4) * 0.72 + rng.uniform(-0.12, 0.12)
        if abs(x - 2.0) < 0.25 and abs(y + 2.25) < 0.3:
            continue
        hanging(x, y, rng.uniform(2.15, 2.7), rng.uniform(0.85, 1.3), i % 3, 3.9)
    for (x, y) in ((0.5, 0.4), (0.95, 0.55), (3.05, 0.55), (3.5, 0.4)):
        hanging(x, y, rng.uniform(2.35, 2.75), rng.uniform(0.9, 1.3), rng.randrange(3), 3.1)

    def stood(x, y, z):
        """A table lamp: a brass foot and stem under the glass."""
        add_lathe(s.bm, [(0.0, z), (0.07, z), (0.03, z + 0.03), (0.015, z + 0.1), (0.04, z + 0.12), (0.0, z + 0.12)], x, y, 8, b)
        hi = glass(x, y, z + 0.13, 0.62, 0)
        add_lathe(s.bm, [(0.05, hi - 0.02), (0.015, hi + 0.03), (0.0, hi + 0.05)], x, y, 6, b)
    for (x0, x1, y0, y1, z) in shelves:
        y = y0 + 0.12
        while y < y1 - 0.1:
            stood((x0 + x1) / 2, y, z)
            y += rng.uniform(0.3, 0.42)
    for x in (0.85, 1.35, 1.9, 2.5, 3.1):
        stood(x, -3.0, 0.98)
    add_tube(s.bm, [(0.3, 0.45, 3.1), (1.15, 0.45, 3.1)], 0.015, 4, b)
    add_tube(s.bm, [(2.85, 0.45, 3.1), (3.7, 0.45, 3.1)], 0.015, 4, b)
    add_box(s.bm, 0.3, 0.33, 0.0, 0.47, 3.08, 3.12, b)
    add_box(s.bm, 3.67, 3.7, 0.0, 0.47, 3.08, 3.12, b)
    s.finish()


def book(s, x0, x1, y0, y1, z0, z1, g, rng):
    start = s.mark()
    add_box(s.bm, x0, x1, y0, y1, z0, z1, g)
    s.tint(start, rng.choice((BOOK_RED, BOOK_BLUE, BOOK_GREEN, BOOK_BROWN, BOOK_BROWN, CRUST)) + rng.randrange(2))


def books_on(s, g, rng, x0, x1, y0, y1, z, along):
    """A row of books standing on a board, spines to the room."""
    t, end = (x0, x1) if along == "x" else (y0, y1)
    while t < end - 0.03:
        w = rng.uniform(0.04, 0.08)
        if rng.random() > 0.93:
            t += rng.uniform(0.08, 0.2)
            continue
        h, d = rng.uniform(0.3, 0.42), rng.uniform(0.8, 1.0)
        if along == "x":
            book(s, t, t + w, y0, y0 + (y1 - y0) * d, z, z + h, g, rng)
        else:
            book(s, x1 - (x1 - x0) * d, x1, t, t + w, z, z + h, g, rng) if x0 > 2.0 else book(s, x0, x0 + (x1 - x0) * d, t, t + w, z, z + h, g, rng)
        t += w + 0.004


def book_pile(s, g, rng, x, y, z, n):
    for _ in range(n):
        h = rng.uniform(0.03, 0.06)
        a, b = rng.uniform(0.12, 0.17), rng.uniform(0.17, 0.22)
        o = rng.uniform(-0.03, 0.03)
        book(s, x - a + o, x + a + o, y - b, y + b, z, z + h, g, rng)
        z += h


def books(r):
    s = Shop(r, "bz_trade_books")
    rng = random.Random(s.name)
    shop_lamp(s, "books")
    counter(s)
    side = side_shelves(s, (0, 1), (0.45, 1.0, 1.55, 2.1, 2.65))
    back = back_shelves(s)
    g = s.m(GOODS)
    for (x0, x1, y0, y1, z) in side:
        books_on(s, g, rng, x0 - 0.03, x1 + 0.03, y0, y1, z, "y")
    for (x0, x1, y0, y1, z) in back:
        books_on(s, g, rng, x0, x1, y0, y1, z, "x")
    for x in (0.8, 1.35, 2.6, 3.15):
        book_pile(s, g, rng, x, -3.0, 0.98, rng.randrange(3, 8))
    for (x, y) in ((0.95, -2.3), (3.05, -2.3)):
        book_pile(s, g, rng, x, y, 0.0, rng.randrange(8, 14))
        s.block(x - 0.2, x + 0.2, y - 0.25, y + 0.25, 0.0, 0.6)
    street_table(s, 0.34, 1.02)
    street_table(s, 2.98, 3.66)
    for x in (0.5, 0.82):
        book_pile(s, g, rng, x, 0.48, 0.68, rng.randrange(3, 7))
    book_pile(s, g, rng, 3.2, 0.48, 0.68, rng.randrange(4, 8))
    book_pile(s, g, rng, 3.48, 0.42, 0.68, 3)
    n = s.m(LINEN)
    add_obox(s.bm, (1.87, -3.0, 1.0), (0.24, 0.34, 0.03), (0.0, -0.12, 0.0), n)
    add_obox(s.bm, (2.13, -3.0, 1.0), (0.24, 0.34, 0.03), (0.0, 0.12, 0.0), n)
    w = s.m(WOOD)
    add_lathe(s.bm, [(0.0, 0.0), (0.16, 0.0), (0.19, 0.5), (0.15, 0.5), (0.0, 0.46)], 1.05, -3.45, 10, w)
    for i in range(6):
        a = 2 * math.pi * i / 6
        add_tube(s.bm, [(1.05 + 0.08 * math.cos(a), -3.45 + 0.08 * math.sin(a), 0.4), (1.05 + 0.12 * math.cos(a), -3.45 + 0.12 * math.sin(a), 0.88)], 0.028, 5, n)
    s.finish()


def spices(r):
    s = Shop(r, "bz_trade_spices")
    rng = random.Random(s.name)
    shop_lamp(s, "spices")
    counter(s)
    back = back_shelves(s, (1.3, 1.85, 2.4))
    g, c, gl, b, w = s.m(GOODS), s.m(CERAMIC), s.m(GLAZED), s.m(BRASS), s.m(WOOD)
    sacks = [(0.55, -2.25, 0.3, 0.55, SAFFRON), (0.5, -1.55, 0.27, 0.48, PAPRIKA), (0.55, -0.9, 0.29, 0.52, TURMERIC),
             (3.45, -2.25, 0.3, 0.5, SUMAC), (3.5, -1.55, 0.27, 0.55, CUMIN), (3.45, -0.9, 0.29, 0.48, PISTACHIO),
             (0.62, 0.45, 0.27, 0.5, PAPRIKA), (3.38, 0.45, 0.27, 0.5, SAFFRON), (0.98, 0.42, 0.2, 0.42, ROSE), (3.02, 0.42, 0.2, 0.42, TEA)]
    for (x, y, rad, h, colour) in sacks:
        sack(s, x, y, rad, h, g, rng)
        mound(s, x, y, h - 0.03, rad * 0.9, 0.17, g, colour)
    s.block(0.2, 0.86, -2.58, -0.58, 0.0, 0.6)
    s.block(3.14, 3.8, -2.58, -0.58, 0.0, 0.6)
    s.block(0.33, 1.2, 0.15, 0.75, 0.0, 0.6)
    s.block(2.8, 3.67, 0.15, 0.75, 0.0, 0.6)
    # The dear spices, in tins and lidded jars.
    for (x0, x1, y0, y1, z) in back:
        x = x0 + 0.08
        y = (y0 + y1) / 2
        while x < x1 - 0.1:
            rad, h = rng.uniform(0.06, 0.09), rng.uniform(0.16, 0.3)
            body = (b, c, gl)[rng.randrange(3)]
            add_lathe(s.bm, [(0.0, z), (rad, z), (rad, z + h), (rad * 1.1, z + h), (rad * 1.1, z + h + 0.03), (0.02, z + h + 0.05), (0.02, z + h + 0.08), (0.0, z + h + 0.08)], x, y, 8, body)
            x += rad * 2 + rng.uniform(0.04, 0.14)
    for (x, colour) in ((0.75, SAFFRON), (1.15, PAPRIKA), (1.55, TURMERIC), (2.5, SUMAC), (2.9, CUMIN), (3.3, ROSE)):
        add_lathe(s.bm, [(0.0, 0.98), (0.07, 0.98), (0.13, 1.05), (0.0, 1.05)], x, -3.0, 10, c)
        mound(s, x, -3.0, 1.04, 0.11, 0.06, g, colour)
    add_box(s.bm, 1.97, 2.03, -3.03, -2.97, 0.98, 1.45, b)
    add_box(s.bm, 1.72, 2.28, -3.01, -2.99, 1.43, 1.45, b)
    for x in (1.74, 2.26):
        add_lathe(s.bm, [(0.0, 1.14), (0.09, 1.16), (0.0, 1.17)], x, -3.0, 8, b)
        add_tube(s.bm, [(x, -3.0, 1.17), (x, -3.0, 1.43)], 0.004, 3, b)
    for x in (0.26, 3.74):
        wall_rail(s, x, -2.5, -0.7, 2.8, w)
        for i, y in enumerate((-0.95, -1.3, -1.65, -2.0, -2.3)):
            string_of(s, x, y, 2.8, rng.randrange(7, 11), g, (PAPRIKA, CHEESE, SUMAC)[(i + int(x)) % 3], rng, w)
    s.finish()


def curios(r):
    s = Shop(r, "bz_trade_curios")
    rng = random.Random(s.name)
    shop_lamp(s, "curios")
    counter(s)
    side = side_shelves(s, (0, 1), (0.8, 1.4, 2.0, 2.6))
    back = back_shelves(s, (1.4, 2.0, 2.6))
    c, gl, b, w, rug, mirror = s.m(CERAMIC), s.m(GLAZED), s.m(BRASS), s.m(WOOD), s.m(RUGS[1]), s.m(MIRROR)

    def box(x, y, z):
        h, a = rng.uniform(0.1, 0.2), rng.uniform(0.09, 0.14)
        add_box(s.bm, x - a, x + a, y - 0.09, y + 0.09, z, z + h, w)
        add_box(s.bm, x - a - 0.01, x + a + 0.01, y - 0.1, y + 0.1, z + h, z + h + 0.03, b)

    def candlestick(x, y, z):
        add_lathe(s.bm, [(0.0, z), (0.08, z), (0.03, z + 0.03), (0.018, z + 0.14), (0.03, z + 0.17), (0.018, z + 0.3), (0.045, z + 0.33), (0.0, z + 0.33)], x, y, 8, b)

    def hourglass(x, y, z):
        add_box(s.bm, x - 0.07, x + 0.07, y - 0.07, y + 0.07, z, z + 0.02, b)
        add_box(s.bm, x - 0.07, x + 0.07, y - 0.07, y + 0.07, z + 0.3, z + 0.32, b)
        add_lathe(s.bm, [(0.05, z + 0.02), (0.008, z + 0.16), (0.05, z + 0.3)], x, y, 6, gl)

    def orb(x, y, z):
        add_lathe(s.bm, [(0.0, z), (0.06, z), (0.03, z + 0.05), (0.0, z + 0.06)], x, y, 8, b)
        ball(s, x, y, z + 0.14, 0.09, gl)

    def figure(x, y, z):
        add_lathe(s.bm, [(0.0, z), (0.07, z), (0.05, z + 0.04), (0.06, z + 0.16), (0.03, z + 0.24), (0.045, z + 0.28), (0.03, z + 0.34), (0.0, z + 0.34)], x, y, 8, b)

    def odd_pot(x, y, z):
        (pot if rng.random() < 0.5 else ewer)(s, x, y, z, rng.uniform(0.45, 0.65), (c, gl)[rng.randrange(2)])
    oddities = (box, candlestick, hourglass, orb, figure, odd_pot, odd_pot)
    for (x0, x1, y0, y1, z) in side:
        y = y0 + 0.15
        while y < y1 - 0.1:
            rng.choice(oddities)((x0 + x1) / 2, y, z)
            y += rng.uniform(0.3, 0.46)
    for (x0, x1, y0, y1, z) in back:
        x = x0 + 0.12
        while x < x1 - 0.1:
            rng.choice(oddities)(x, (y0 + y1) / 2, z)
            x += rng.uniform(0.3, 0.46)
    # On the counter: an astrolabe, a globe on a stem, a candlestick, a mirror.
    tray(s, 0.95, -3.02, 1.27, 0.2, b)
    add_box(s.bm, 0.92, 0.98, -3.03, -2.97, 0.98, 1.08, b)
    add_lathe(s.bm, [(0.0, 0.98), (0.08, 0.98), (0.02, 1.04), (0.02, 1.12)], 2.95, -3.0, 8, b)
    ball(s, 2.95, -3.0, 1.26, 0.15, gl)
    add_tube(s.bm, [(2.75, -3.0, 1.26), (2.8, -3.0, 1.4), (2.95, -3.0, 1.46), (3.1, -3.0, 1.4), (3.15, -3.0, 1.26), (3.1, -3.0, 1.12), (2.95, -3.0, 1.06)], 0.008, 4, b)
    candlestick(2.1, -3.0, 0.98)
    add_box(s.bm, 1.45, 1.8, -3.08, -3.04, 0.98, 1.5, w)
    add_box(s.bm, 1.49, 1.76, -3.04, -3.03, 1.02, 1.46, mirror)
    # A chest on the floor, a cage over the street.
    add_box(s.bm, 0.75, 1.55, -2.5, -2.0, 0.0, 0.45, w)
    add_box(s.bm, 0.73, 1.57, -2.52, -1.98, 0.45, 0.58, w)
    for x in (0.85, 1.4):
        add_box(s.bm, x, x + 0.05, -2.53, -1.97, 0.0, 0.59, b)
    s.block(0.73, 1.57, -2.52, -1.98, 0.0, 0.58)
    add_tube(s.bm, [(3.4, 0.4, 3.1), (3.4, 0.4, 2.9)], 0.008, 4, b)
    for i in range(7):
        a = 2 * math.pi * i / 7
        px, py = 3.4 + 0.16 * math.cos(a), 0.4 + 0.16 * math.sin(a)
        add_tube(s.bm, [(3.4, 0.4, 2.9), (px, py, 2.72), (px, py, 2.42), (3.4, 0.4, 2.4)], 0.006, 3, b)
    slab(s, 0.45, 1.3, -4.09, -4.06, 0.95, 1.36, rug)
    street_crate(s, 0.34, 1.02, 0.5)
    pot(s, 0.5, 0.45, 0.5, 0.9, c)
    ewer(s, 0.85, 0.35, 0.5, 0.8, gl)
    pot(s, 3.4, 0.45, 0.0, 2.0, c)
    pot(s, 3.05, 0.35, 0.0, 1.4, gl)
    s.block(2.75, 3.8, 0.05, 0.85, 0.0, 0.85)
    s.finish()


def food(r):
    s = Shop(r, "bz_trade_food")
    rng = random.Random(s.name)
    shop_lamp(s, "food")
    counter(s)
    back = back_shelves(s, (1.4, 2.0))
    st, e, c, g, cer, gl, w = s.m(STONE), s.m(EMBER), s.m(COPPER), s.m(GOODS), s.m(CERAMIC), s.m(GLAZED), s.m(WOOD)
    # The hearth: a stone curb round a bed of coals, a cauldron on three legs.
    add_box(s.bm, 0.2, 1.15, -2.6, -2.5, 0.0, 0.5, st)
    add_box(s.bm, 0.2, 1.15, -1.75, -1.65, 0.0, 0.5, st)
    add_box(s.bm, 0.2, 0.3, -2.5, -1.75, 0.0, 0.5, st)
    add_box(s.bm, 1.05, 1.15, -2.5, -1.75, 0.0, 0.5, st)
    add_box(s.bm, 0.3, 1.05, -2.5, -1.75, 0.0, 0.34, st)
    for _ in range(26):
        x, y, k = rng.uniform(0.34, 1.01), rng.uniform(-2.46, -1.79), rng.uniform(0.04, 0.07)
        add_lathe(s.bm, [(0.0, 0.33), (k, 0.34), (k * 0.7, 0.34 + k), (0.0, 0.34 + k * 1.2)], x, y, 5, e)
    for i in range(3):
        a = 2 * math.pi * i / 3 + 0.5
        start = s.mark()
        add_tube(s.bm, [(0.68 + 0.26 * math.cos(a), -2.12 + 0.26 * math.sin(a), 0.34), (0.68 + 0.22 * math.cos(a), -2.12 + 0.22 * math.sin(a), 0.66)], 0.016, 4, g)
        s.tint(start, IRON)
    cauldron(s, 0.68, -2.12, 0.54, 1.0, c)
    mound(s, 0.68, -2.12, 0.97, 0.32, 0.015, g, CUMIN)
    s.block(0.2, 1.15, -2.6, -1.65, 0.0, 1.0)

    def bread(x, y, z, n):
        for _ in range(n):
            start = s.mark()
            add_lathe(s.bm, [(0.0, z), (0.17, z + 0.002), (0.19, z + 0.014), (0.16, z + 0.026), (0.0, z + 0.032)], x + rng.uniform(-0.02, 0.02), y + rng.uniform(-0.02, 0.02), 12, g)
            s.smooth(start)
            s.tint(start, BREAD + rng.randrange(4))
            z += 0.03
    bread(1.0, -3.0, 0.98, 7)
    bread(1.5, -3.0, 0.98, 5)
    bread(0.68, 0.45, 0.68, 8)
    dish(s, 3.32, 0.46, 0.68, 0.27, cer)
    pile(s, 3.32, 0.46, 0.72, 0.058, 9, g, POMEGRANATE, rng)
    dish(s, 2.5, -3.0, 0.98, 0.25, cer)
    pile(s, 2.5, -3.0, 1.02, 0.045, 10, g, GRAPE, rng)
    dish(s, 3.05, -3.0, 0.98, 0.25, cer)
    pile(s, 3.05, -3.0, 1.02, 0.05, 10, g, APRICOT, rng)
    for (x, y) in ((3.42, -2.3), (3.42, -1.6)):        # melons by the wall
        for (dx, dy, dz) in ((0.0, 0.0, 0.14), (0.14, 0.2, 0.14), (-0.1, 0.24, 0.14), (0.02, 0.12, 0.36)):
            ball(s, x + dx, y + dy, dz, 0.15, g, MELON + rng.randrange(2), 0.92)
    s.block(3.2, 3.68, -2.45, -1.26, 0.0, 0.5)
    for (x0, x1, y0, y1, z) in back:
        x = x0 + 0.15
        while x < x1 - 0.1:
            pot(s, x, (y0 + y1) / 2, z, rng.uniform(0.6, 0.9), (cer, gl)[rng.randrange(2)])
            x += rng.uniform(0.32, 0.5)
    street_table(s, 0.34, 1.02)
    street_table(s, 2.98, 3.66)
    wall_rail(s, 3.74, -2.5, -0.7, 2.8, w)
    for i, y in enumerate((-0.95, -1.35, -1.75, -2.15)):
        string_of(s, 3.74, y, 2.8, rng.randrange(7, 11), g, (CHEESE, PAPRIKA)[i % 2], rng, w)
    s.finish()


def awning(cloth):
    def build(r):
        s = Shop(r, r.name[2:])
        c, w = s.m(cloth), s.m(WOOD)
        add_obox(s.bm, (2.0, 0.62, 3.25), (3.5, 1.3, 0.025), (math.radians(-22.0), 0.0, 0.0), c)
        add_box(s.bm, 0.25, 3.75, 1.2, 1.22, 2.76, 3.0, c)
        for x in (0.3, 3.7):
            add_box(s.bm, x - 0.02, x + 0.02, 0.0, 1.22, 2.98, 3.02, w)
            add_tube(s.bm, [(x, 0.02, 3.5), (x, 1.2, 3.0)], 0.012, 4, w)
        s.finish()
    return build


def shut_bar(r):
    s = Shop(r, "bz_shut_bar")
    b = s.m(BRASS)
    add_box(s.bm, 0.5, 3.5, -0.2, -0.16, 1.2, 1.28, b)
    add_box(s.bm, 1.92, 2.08, -0.2, -0.12, 1.08, 1.32, b)
    s.finish()


def shut_crates(r):
    s = Shop(r, "bz_shut_crates")
    rng = random.Random(s.name)
    w, g = s.m(WOOD), s.m(GOODS)
    add_box(s.bm, 0.45, 1.15, 0.05, 0.75, 0.0, 0.6, w)
    add_box(s.bm, 0.55, 1.05, 0.12, 0.62, 0.6, 1.05, w)
    add_box(s.bm, 1.25, 1.75, 0.05, 0.55, 0.0, 0.42, w)
    sack(s, 2.95, 0.32, 0.25, 0.5, g, rng)
    sack(s, 3.35, 0.3, 0.22, 0.42, g, rng)
    s.block(0.45, 1.75, 0.05, 0.75, 0.0, 1.05)
    s.block(2.68, 3.6, 0.05, 0.6, 0.0, 0.5)
    s.finish()


def part(s, m, colour, build, smooth=True):
    """Builds into the shop's mesh, moves only what was added, and colours it."""
    start, before = s.mark(), set(s.bm.verts)
    build(s.bm)
    bmesh.ops.transform(s.bm, matrix=m, verts=[v for v in s.bm.verts if v not in before])
    s.tint(start, colour)
    if smooth:
        s.smooth(start)


FOLDED = ((-0.08, -0.24, 1.08), (0.1, -0.24, 1.1))
GESTURE = ((-0.1, -0.24, 1.05), (0.34, -0.24, 1.42))
HIPS = ((-0.3, -0.06, 0.95), (0.3, -0.06, 0.95))
BASKET = ((-0.24, -0.04, 1.68), (0.12, -0.24, 1.0))
LOWERED = ((-0.14, -0.3, 0.85), (0.14, -0.3, 0.85))
OFFER = ((-0.12, -0.42, 1.2), (0.12, -0.42, 1.2))
SITTING = ((-0.2, -0.38, 0.36), (0.2, -0.38, 0.36))
COUNTER = ((-0.26, -0.44, 1.02), (0.26, -0.44, 1.02))


def person(s, m, robe, hood, hands=FOLDED, hip=0.92, lean=0.03, low=False, block=True):
    """A robed figure in the quarter's manner, facing -Y (Godot +Z): one material,
    its colours picked from the goods palette, so a figure is one draw call."""
    g = s.m(GOODS)
    if low:
        part(s, m, robe, lambda bm: add_lathe(bm, [(0.34, 0.0), (0.36, 0.12), (0.22, hip)], 0.0, 0.1, 10, g))
    else:
        part(s, m, robe, lambda bm: add_lathe(bm, [(0.31, 0.0), (0.27, 0.3), (0.2, hip)], 0.0, 0.0, 10, g))
    body = Matrix.Translation((0.0, 0.0, hip)) @ Matrix.Rotation(lean, 4, "X")
    part(s, m @ body, robe, lambda bm: add_lathe(bm, [(0.2, 0.0), (0.21, 0.3), (0.18, 0.48), (0.09, 0.54)], 0.0, 0.0, 10, g))
    head = body @ Matrix.Translation((0.0, -0.04, 0.48))
    part(s, m @ head, hood, lambda bm: add_lathe(bm, [(0.0, 0.0), (0.18, 0.04), (0.17, 0.2), (0.12, 0.3), (0.0, 0.35)], 0.0, 0.0, 10, g))
    part(s, m @ head @ Matrix.Translation((0.0, -0.02, 0.15)) @ Matrix.Rotation(math.pi / 2, 4, "X"), IRON + 1,
         lambda bm: add_lathe(bm, [(0.0, 0.0), (0.1, 0.0), (0.1, 0.115), (0.055, 0.15), (0.0, 0.155)], 0.0, 0.0, 8, g), False)
    for k, hx in enumerate((-0.19, 0.19)):
        sh = body @ Vector((hx, 0.0, 0.44))
        hp = Vector(hands[k])
        el = (sh + hp) / 2 + Vector((hx * 0.3, 0.04, -0.02))
        part(s, m, robe + 1, lambda bm, sh=sh, el=el, hp=hp: add_tube(bm, [tuple(sh), tuple(el), tuple(hp + Vector((0.0, 0.0, 0.05)))], [0.07, 0.06, 0.055], 6, g))
        part(s, m @ Matrix.Translation(hp), CRUST, lambda bm: add_lathe(bm, [(0.0, -0.045), (0.04, -0.03), (0.036, 0.04), (0.0, 0.045)], 0.0, 0.0, 5, g))
    if block:
        t = m.translation
        s.block(t.x - 0.28, t.x + 0.28, t.y - 0.28, t.y + 0.28, 0.0, 1.0 if low else 1.65)


def at(x, y, turn=0.0, z=0.0, k=1.0):
    return Matrix.Translation((x, y, z)) @ Matrix.Rotation(turn, 4, "Z") @ Matrix.Scale(k, 4)


def facing_middle(x, y, z=0.0):
    return at(x, y, math.atan2(y, x) - math.pi / 2, z)


def fig(pose, robe, hood, lean=0.03, extra=None, k=1.0):
    def build(r):
        s = Shop(r, r.name[2:])
        m = at(0.0, 0.0, 0.0, 0.0, k)
        person(s, m, robe, hood, pose, lean=lean)
        if extra is not None:
            extra(s, m)
        s.finish()
    return build


def basket_on_head(s, m):
    part(s, m @ Matrix.Translation((0.0, 0.0, 1.72)), CRUST, lambda bm: add_lathe(bm, [(0.0, 0.0), (0.16, 0.0), (0.27, 0.17), (0.25, 0.19), (0.0, 0.11)], 0.0, 0.0, 10, s.m(GOODS)))


def sack_on_back(s, m):
    part(s, m @ Matrix.Translation((0.0, 0.3, 1.2)) @ Matrix.Rotation(0.5, 4, "X"), BREAD,
         lambda bm: add_lathe(bm, [(0.0, -0.32), (0.2, -0.24), (0.26, 0.0), (0.2, 0.24), (0.0, 0.32)], 0.0, 0.0, 10, s.m(GOODS)))


def group_talk(r):
    s = Shop(r, "bz_group_talk")
    person(s, at(-0.48, 0.0, math.pi / 2), BOOK_BLUE, TEA, GESTURE)
    person(s, at(0.48, 0.0, -math.pi / 2), BOOK_BROWN, BOOK_RED, FOLDED)
    s.finish()


def group_ring(r):
    s = Shop(r, "bz_group_ring")
    for i, (robe, hood, pose) in enumerate(((BOOK_GREEN, BREAD, HIPS), (BOOK_RED, IRON, GESTURE), (CRUST, BOOK_BLUE, FOLDED))):
        a = 2 * math.pi * i / 3 + 0.4
        person(s, facing_middle(0.62 * math.cos(a), 0.62 * math.sin(a)), robe, hood, pose)
    s.finish()


def group_haggle(r):
    s = Shop(r, "bz_group_haggle")
    person(s, at(-0.5, 0.0, math.pi / 2), BREAD, BOOK_GREEN, OFFER, lean=0.1)
    person(s, at(0.5, 0.0, -math.pi / 2), BOOK_RED, BREAD, HIPS)
    person(s, at(0.1, 0.72, math.pi, 0.0, 0.66), ROSE, CRUST, LOWERED)
    s.finish()


def keeper(robe, hood):
    """Behind the counter, hands on it, looking out at the street."""
    def build(r):
        s = Shop(r, r.name[2:])
        person(s, at(2.0, -3.68, math.pi), robe, hood, COUNTER, lean=0.1, block=False)
        s.finish()
    return build


def lumps(s, rng, x0, x1, y0, y1, z, n, mat):
    for _ in range(n):
        k = rng.uniform(0.05, 0.14)
        add_lathe(s.bm, [(0.0, z), (k, z + 0.01), (k * 0.6, z + k * 0.8), (0.0, z + k)], rng.uniform(x0, x1), rng.uniform(y0, y1), 5, mat)


def drift(s, x, y, radius, height, mat, colour=CUMIN):
    """A low drift of dust, flattened where it lies."""
    start = s.mark()
    for (dx, dy, k) in ((0.0, 0.0, 0.7), (0.55, 0.2, 0.5), (-0.5, -0.15, 0.55)):
        r, h = radius * k, height * (0.5 + k * 0.5)
        add_lathe(s.bm, [(r, 0.0), (r * 0.7, h * 0.5), (r * 0.3, h * 0.9), (0.0, h)], x + dx * radius, y + dy * radius, 10, mat)
    s.smooth(start)
    s.tint(start, colour + 1)


def fountain(dry):
    def build(r):
        s = Shop(r, r.name[2:])
        rng = random.Random(s.name)
        st, ti = s.m(BRASS), s.m("persian_banai")
        add_lathe(s.bm, [(0.0, 0.0), (2.0, 0.0), (2.04, 0.5), (2.1, 0.5), (2.1, 0.58), (1.82, 0.58), (1.78, 0.12), (0.0, 0.12)], 0.0, 0.0, 16, ti)
        add_lathe(s.bm, [(0.0, 0.1), (0.38, 0.12), (0.2, 0.4), (0.14, 1.2), (0.22, 1.35), (0.75, 1.5), (0.8, 1.6), (0.68, 1.6), (0.0, 1.5)], 0.0, 0.0, 12, st)
        add_lathe(s.bm, [(0.0, 1.5), (0.1, 1.62), (0.05, 1.9), (0.08, 1.96), (0.0, 2.05)], 0.0, 0.0, 8, st)
        if dry:
            g = s.m(GOODS)
            lumps(s, rng, -1.2, 1.2, -1.2, 1.2, 0.12, 12, s.m(STONE))
            for (x, y, k) in ((0.9, 0.5, 0.8), (-1.0, -0.4, 0.7), (-0.2, 1.1, 0.6)):
                start = s.mark()
                add_lathe(s.bm, [(k, 0.12), (k * 0.7, 0.18), (0.0, 0.22)], x, y, 8, g)
                s.tint(start, CUMIN + 1)
        else:
            w = s.m("cistern_water")
            add_lathe(s.bm, [(0.0, 0.38), (1.8, 0.38), (1.8, 0.42), (0.0, 0.42)], 0.0, 0.0, 16, w)
            add_lathe(s.bm, [(0.0, 1.54), (0.68, 1.54), (0.68, 1.57), (0.0, 1.57)], 0.0, 0.0, 12, w)
        s.block(-1.5, 1.5, -1.5, 1.5, 0.0, 2.0)
        s.block(-2.05, 2.05, -0.8, 0.8, 0.0, 0.58)
        s.block(-0.8, 0.8, -2.05, 2.05, 0.0, 0.58)
        s.finish()
    return build


def platform(s, st):
    add_lathe(s.bm, [(0.0, 0.0), (1.55, 0.0), (1.55, 0.3), (1.42, 0.3), (1.42, 0.45), (0.0, 0.45)], 0.0, 0.0, 8, st)
    s.block(-1.25, 1.25, -1.25, 1.25, 0.0, 0.45)
    s.block(-1.5, 1.5, -0.6, 0.6, 0.0, 0.45)
    s.block(-0.6, 0.6, -1.5, 1.5, 0.0, 0.45)


def story(r):
    """A storyteller on a low stage in the beam, the listeners sitting round."""
    s = Shop(r, "bz_story")
    st, rug = s.m(STONE), s.m(RUGS[2])
    platform(s, st)
    slab(s, -0.8, 0.8, -0.8, 0.8, 0.45, 0.462, rug)
    person(s, at(0.0, 0.0, 0.0, 0.45), BOOK_BLUE, CRUST, ((-0.32, -0.26, 1.4), (0.34, -0.24, 1.46)), block=False)
    robes = ((BOOK_RED, BREAD), (BREAD, BOOK_GREEN), (BOOK_BROWN, IRON), (CRUST, BOOK_BLUE), (BOOK_GREEN, BREAD), (TEA, BOOK_RED))
    for i in range(11):
        a = 2 * math.pi * (i + 0.5) / 11
        robe, hood = robes[i % len(robes)]
        person(s, facing_middle(2.5 * math.cos(a), 2.5 * math.sin(a)), robe, hood, SITTING, hip=0.4, lean=0.08, low=True)
    s.finish()


def story_bare(r):
    s = Shop(r, "bz_story_bare")
    rng = random.Random(s.name)
    st, g = s.m(STONE), s.m(GOODS)
    platform(s, st)
    lumps(s, rng, -1.9, 1.9, -1.9, 1.9, 0.0, 8, st)
    drift(s, 0.5, 1.7, 0.8, 0.14, g)
    s.finish()


def rumour_board(old):
    """A board of pinned notes in a blind arch, its face to +Y, a candle over it."""
    def build(r):
        s = Shop(r, r.name[2:])
        rng = random.Random(s.name)
        w, n, b = s.m(WOOD), s.m(GOODS), s.m(BRASS)
        add_box(s.bm, -0.75, 0.75, 0.0, 0.05, 1.0, 2.05, w)
        for (x0, x1, z0, z1) in ((-0.8, 0.8, 2.05, 2.11), (-0.8, 0.8, 0.94, 1.0), (-0.8, -0.74, 1.0, 2.05), (0.74, 0.8, 1.0, 2.05)):
            add_box(s.bm, x0, x1, 0.0, 0.08, z0, z1, w)
        for i in range(5 if old else 16):
            cx, cz = rng.uniform(-0.6, 0.6), rng.uniform(1.15, 1.9)
            wd, ht = rng.uniform(0.09, 0.16), rng.uniform(0.11, 0.2)
            start = s.mark()
            add_obox(s.bm, (cx, 0.056 + i * 0.0006, cz), (wd * 2, 0.002, ht * 2), (0.0, rng.uniform(-0.2, 0.2), 0.0), n)
            s.tint(start, BREAD if old else rng.choice((CHEESE, CHEESE + 1, BREAD)))
            add_box(s.bm, cx - 0.01, cx + 0.01, 0.055, 0.075, cz + ht * 0.8, cz + ht * 0.8 + 0.02, b)
        if not old:
            add_box(s.bm, -0.05, 0.05, 0.0, 0.22, 2.18, 2.2, b)
            add_lathe(s.bm, [(0.0, 2.2), (0.03, 2.2), (0.03, 2.33), (0.0, 2.33)], 0.0, 0.14, 6, s.m(CERAMIC))
            marker("LIGHT_candle__board", r, (0.0, 0.3, 2.3), {"range": 2.6, "energy": 0.3})
        s.finish()
    return build


def bare(r):
    """A shop nobody came back to: half a counter, an empty shelf, dust. Daylight
    finds its way in, just enough to see by."""
    s = Shop(r, "bz_bare")
    rng = random.Random(s.name)
    counter(s, 0.5, 2.3)
    side_shelves(s, (0,), (0.9, 1.6))
    w, c, g = s.m(WOOD), s.m(CERAMIC), s.m(GOODS)
    add_obox(s.bm, (2.9, -2.9, 0.42), (1.3, 0.42, 0.05), (0.0, 0.75, 0.3), w)
    add_obox(s.bm, (3.2, -1.2, 0.03), (1.4, 0.3, 0.05), (0.0, 0.0, 0.5), w)
    lumps(s, rng, 2.6, 3.7, -3.9, -3.3, 0.0, 6, c)
    for (x, y, k) in ((3.3, -3.6, 0.8), (0.9, -1.7, 0.6), (2.6, -0.9, 0.7), (1.6, -3.7, 0.5)):
        drift(s, x, y, k, 0.1, g)
    s.block(2.4, 3.4, -3.15, -2.65, 0.0, 0.8)
    marker("LIGHT_lantern__shop", s.r, (2.0, -2.5, 2.2), {"range": 3.7, "energy": 0.24, "color": [0.62, 0.72, 0.82]})
    s.finish()


def awning_rag(cloth):
    def build(r):
        s = Shop(r, r.name[2:])
        rng = random.Random(s.name)
        c, w = s.m(cloth), s.m(WOOD)
        x = 0.35
        while x < 3.6:
            wd = rng.uniform(0.12, 0.4)
            if rng.random() < 0.7:
                n = rng.uniform(0.3, 1.25)
                add_obox(s.bm, (x + wd / 2, n / 2 * 0.93, 3.5 - n / 2 * 0.37), (wd, n, 0.02), (math.radians(-22.0), 0.0, 0.0), c)
                add_box(s.bm, x, x + wd * 0.7, n * 0.93 - 0.01, n * 0.93 + 0.01, 3.5 - n * 0.37 - rng.uniform(0.2, 0.6), 3.5 - n * 0.37, c)
            x += wd + rng.uniform(0.03, 0.2)
        for xx in (0.3, 3.7):
            add_box(s.bm, xx - 0.02, xx + 0.02, 0.0, 1.22, 2.98, 3.02, w)
        add_tube(s.bm, [(0.3, 0.02, 3.5), (0.3, 1.2, 3.0)], 0.012, 4, w)
        s.finish()
    return build


def shut_hooks(r):
    """A rail of empty hooks across the shutter: the goods have gone."""
    s = Shop(r, "bz_shut_hooks")
    w, g = s.m(WOOD), s.m(GOODS)
    add_box(s.bm, 0.6, 3.4, -0.22, -0.16, 2.2, 2.28, w)
    for i in range(9):
        x = 0.8 + i * 0.3
        start = s.mark()
        add_tube(s.bm, [(x, -0.16, 2.24), (x, -0.1, 2.2), (x, -0.1, 2.08), (x, -0.13, 2.04), (x, -0.16, 2.08)], 0.008, 4, g)
        s.tint(start, IRON)
    s.finish()


def shut_dust(r):
    """Dust drifted against a shut front, with what fell there."""
    s = Shop(r, "bz_shut_dust")
    rng = random.Random(s.name)
    g, w = s.m(GOODS), s.m(WOOD)
    for (x, k) in ((0.7, 0.55), (1.6, 0.7), (2.5, 0.5), (3.3, 0.6)):
        drift(s, x, rng.uniform(0.2, 0.45), k, rng.uniform(0.07, 0.13), g)
    add_obox(s.bm, (1.9, 0.5, 0.05), (1.1, 0.14, 0.03), (0.0, 0.0, 0.5), w)
    add_obox(s.bm, (2.3, 0.75, 0.06), (0.7, 0.14, 0.03), (0.0, 0.0, -0.3), w)
    s.finish()


def pennants(r, name="bz_pennants", keep=1.0):
    """A line of pennants across the street, centred on X, at Y 2, sagging in the
    middle. quarter_cloth: four colours across its map; it sways by itself."""
    rng = random.Random(name)
    top = 6.7

    def z_at(x):
        return top - 0.7 * (1.0 - (x / 3.9) ** 2)
    bm = bmesh.new()
    add_tube(bm, [(x / 4.0 * 3.9, 2.0, z_at(x / 4.0 * 3.9)) for x in range(-4, 5)], 0.012, 4)
    mesh_object(name + "__rope", bm, [WOOD], r)
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    n = 13
    for i in range(n):
        if rng.random() > keep:
            continue
        x = -3.6 + 7.2 * i / (n - 1)
        col = (i * 3) % 4
        a = bm.verts.new((x - 0.2, 2.0, z_at(x - 0.2)))
        b = bm.verts.new((x + 0.2, 2.0, z_at(x + 0.2)))
        c = bm.verts.new((x, 2.0, z_at(x) - 0.62))
        f = bm.faces.new((a, c, b))
        for loop, t in zip(f.loops, (((col + 0.1) / 4.0, 0.05), ((col + 0.5) / 4.0, 0.95), ((col + 0.9) / 4.0, 0.05))):
            loop[uv].uv = t
    mesh_object(name + "__cloth", bm, ["quarter_cloth"], r, recalc=False)


MODULES = [
    ("M_bz_trade_rugs", props(), rugs),
    ("M_bz_trade_copper", props(), copper),
    ("M_bz_trade_lamps", props(), lamps),
    ("M_bz_trade_books", props(), books),
    ("M_bz_trade_spices", props(), spices),
    ("M_bz_trade_curios", props(), curios),
    ("M_bz_trade_food", props(), food),
    ("M_bz_awning_a", props(), awning("persian_awning")),
    ("M_bz_awning_b", props(), awning("cloth")),
    ("M_bz_shut_bar", props(), shut_bar),
    ("M_bz_shut_crates", props(), shut_crates),
    ("M_bz_pennants", props(), pennants),
    ("M_bz_pennants_rag", props(), lambda r: pennants(r, "bz_pennants_rag", 0.35)),
    ("M_bz_keeper_a", props(), keeper(BOOK_BROWN, BREAD)),
    ("M_bz_keeper_b", props(), keeper(BOOK_GREEN, CRUST)),
    ("M_bz_keeper_c", props(), keeper(BOOK_RED, IRON)),
    ("M_bz_fig_a", props(), fig(FOLDED, BOOK_RED, BREAD)),
    ("M_bz_fig_b", props(), fig(GESTURE, BOOK_BLUE, TEA)),
    ("M_bz_fig_c", props(), fig(BASKET, BREAD, CRUST, 0.03, basket_on_head)),
    ("M_bz_fig_d", props(), fig(LOWERED, BOOK_GREEN, IRON, 0.2)),
    ("M_bz_fig_e", props(), fig(HIPS, BOOK_BROWN, BOOK_RED)),
    ("M_bz_fig_f", props(), fig(OFFER, CRUST, BOOK_BLUE, 0.08)),
    ("M_bz_fig_g", props(), fig(FOLDED, ROSE, BREAD, 0.03, None, 0.66)),
    ("M_bz_fig_h", props(), fig(LOWERED, BOOK_BROWN, BREAD, 0.28, sack_on_back)),
    ("M_bz_group_talk", props(), group_talk),
    ("M_bz_group_ring", props(), group_ring),
    ("M_bz_group_haggle", props(), group_haggle),
    ("M_bz_fountain", props(), fountain(False)),
    ("M_bz_fountain_dry", props(), fountain(True)),
    ("M_bz_story", props(), story),
    ("M_bz_story_bare", props(), story_bare),
    ("M_bz_rumour_board", props(), rumour_board(False)),
    ("M_bz_rumour_board_old", props(), rumour_board(True)),
    ("M_bz_shut_hooks", props(), shut_hooks),
    ("M_bz_shut_dust", props(), shut_dust),
    ("M_bz_bare", props(), bare),
    ("M_bz_awning_rag_a", props(), awning_rag("persian_awning")),
    ("M_bz_awning_rag_b", props(), awning_rag("cloth")),
]

# Script-made modules remade in place at a new revision (kit_blender.rebuild).
REBUILD = [(n, 8) for (n, _p, _b) in MODULES]


def main():
    bpy.ops.wm.open_mainfile(filepath=BLEND)
    added = []
    x = 0.0
    for (name, p, build) in MODULES:
        if bpy.data.objects.get(name) is None:
            build(module(name, (x, ROW_Y, 0.0), p))
            added.append(name)
        x += 24.0
    rebuilt = ["%s (rev %d)" % (n, v) for (n, v) in REBUILD if rebuild(n, v, MODULES)]
    if not added and not rebuilt:
        print("kit_add_r04_shops: everything already present; nothing to do.")
        return
    bpy.ops.wm.save_as_mainfile(filepath=BLEND)
    print("kit_add_r04_shops: added %d; rebuilt %s" % (len(added), ", ".join(rebuilt) or "nothing"))


main()

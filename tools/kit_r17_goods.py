"""What lies in the R17 Ossuary of Books' niches (phase 16 step 3): the shrouded
dead, books, wrapped bundles and scrolls. tools/kit_add_r17.py builds these into
kit_ossuary.blend; OssuaryGrammar._dress places them.

A room holds hundreds of niches, so a bay's contents are merged: one mesh for its
long niche (os_item_long_*), one for its four small ones (os_item_upper_*), all
in one palette material (ossuary_goods.png, tools/pixel_materials_ext.gd) picked
by UV. Nothing in a niche collides. Only a bay with a candle in a small niche
uses the single-niche pieces (os_item_nook_*).

Bay frame: the wall's face at X 0, the passage on +X, the niches behind it in -X;
Y 0..2 along the wall, Z up from the floor (the niches of tools/kit_add_r17.py's
bay_niches). A bay is symmetric, so the same piece serves every wall.
Nook frame: X as the bay, the niche's middle at Y 0, its sill at Z 0.
Bier frame: the cell's, as os_bier.
"""
import math
import random

import bmesh
from mathutils import Matrix, Vector, noise

from kit_blender import add_box, add_lathe, marker, mesh_object

GOODS, STONE, WAX, FLAME = "ossuary_goods", "ossuary_stone", "wax", "emit_lantern"

# The palette in ossuary_goods.png, in order.
(LINEN, LINEN_FOLD, LINEN_BAND, GREY, GREY_FOLD, RAG, TWINE, TWINE_OLD, LEATHER, LEATHER_DARK, OXBLOOD, GREEN, BLUE,
 DUSTY, PAGES, PAGES_OLD, OCHRE, GILT, DUST, OXBLOOD_FOLD) = range(20)
SHADES = 20

SPINES = (LEATHER, LEATHER_DARK, OXBLOOD, GREEN, BLUE, LEATHER, LEATHER_DARK)
SPINES_OLD = (DUSTY, GREY_FOLD, RAG, LEATHER_DARK, DUSTY)
WRAPS = (LINEN, LINEN_FOLD, LINEN_BAND, LINEN_FOLD, OCHRE, DUSTY)
WRAPS_OLD = (GREY, GREY_FOLD, RAG, DUSTY)

LONG_SILL = 0.22
LONG_HEIGHT = 0.4
SMALL_HEIGHT = 0.3
# The four small niches in a bay: (middle along the wall, sill).
SMALL = ((0.525, 0.98), (1.475, 0.98), (0.525, 1.5), (1.475, 1.5))

# A body from the feet (0) to the crown (1): (along it, half width, height).
BODY = ((0.0, 0.06, 0.07), (0.04, 0.095, 0.125), (0.1, 0.095, 0.1), (0.16, 0.085, 0.085), (0.3, 0.125, 0.105),
        (0.45, 0.165, 0.12), (0.54, 0.185, 0.135), (0.64, 0.165, 0.125), (0.75, 0.2, 0.15), (0.82, 0.205, 0.135),
        (0.855, 0.1, 0.095), (0.885, 0.085, 0.095), (0.93, 0.1, 0.135), (0.97, 0.09, 0.125), (1.0, 0.04, 0.07))
# Where the shroud is bound.
BANDS = (0.12, 0.33, 0.56, 0.72, 0.87)


def props(tags="ossuary,r17,goods"):
    return {"kit_shape": "free", "kit_family": "walls", "size_cells": [0, 0, 0], "edge": "", "tags": tags, "weight": 1.0}


class Pack:
    """One mesh of palette-coloured shapes."""

    def __init__(self, r, name):
        self.r, self.name, self.bm = r, name, bmesh.new()
        self.uv = self.bm.loops.layers.uv.verify()

    def face(self, verts, colour, smooth=False):
        f = self.bm.faces.new(verts)
        f.smooth = smooth
        for loop in f.loops:
            loop[self.uv].uv = ((colour + 0.5) / SHADES, 0.5)
        return f

    def box(self, m, size, main, top=None, under=None, front=None, back=None):
        """A box through matrix m. `front` is its +X side, `back` its -X."""
        hx, hy, hz = size[0] * 0.5, size[1] * 0.5, size[2] * 0.5
        v = [self.bm.verts.new(m @ Vector((x, y, z))) for z in (-hz, hz) for y in (-hy, hy) for x in (-hx, hx)]
        pick = lambda c: main if c is None else c
        self.face((v[0], v[2], v[3], v[1]), pick(under))
        self.face((v[4], v[5], v[7], v[6]), pick(top))
        self.face((v[0], v[1], v[5], v[4]), main)
        self.face((v[3], v[2], v[6], v[7]), main)
        self.face((v[1], v[3], v[7], v[5]), pick(front))
        self.face((v[2], v[0], v[4], v[6]), pick(back))

    def loft(self, rings, tone, cap, smooth=True):
        """Closed rings of points joined up, capped at both ends. tone(i, j) is
        the colour of the quad from ring i, point j."""
        vs = [[self.bm.verts.new(p) for p in ring] for ring in rings]
        n = len(vs[0])
        for i in range(len(vs) - 1):
            for j in range(n):
                k = (j + 1) % n
                self.face((vs[i][j], vs[i][k], vs[i + 1][k], vs[i + 1][j]), tone(i, j), smooth)
        self.face(list(reversed(vs[0])), cap, smooth)
        self.face(vs[-1], cap, smooth)

    def done(self):
        if self.bm.faces:
            mesh_object(self.name + "__goods", self.bm, [GOODS], self.r)
        else:
            self.bm.free()


def _body_at(t):
    for a, b in zip(BODY, BODY[1:]):
        if t <= b[0]:
            k = (t - a[0]) / (b[0] - a[0])
            k = k * k * (3.0 - 2.0 * k)
            return a[1] + (b[1] - a[1]) * k, a[2] + (b[2] - a[2]) * k
    return BODY[-1][1], BODY[-1][2]


def shroud(p, x, y0, z, length, flip, old, rng, sections=30, around=10, rag=False):
    """A shrouded body lying along Y from y0, feet first (head first if flip).
    Old: greyed, and sunk where the chest and belly have gone. Rag: little left
    but the cloth, collapsed and torn through (the brief's Q1: never bones)."""
    ph = rng.uniform(0.0, 40.0)
    rings, folded = [], {}
    for i in range(sections + 1):
        t = i / sections
        w, h = _body_at(t)
        if old:
            sink = 0.42 + 0.3 * abs(t - 0.62) / 0.38
            h *= min(sink, 0.85) if t < 0.86 else 0.8
            w *= 1.1
        if rag:
            h *= 0.8
        y = y0 + length * ((1.0 - t) if flip else t)
        ring = []
        for j in range(around):
            a = math.pi * j / (around - 1)
            fold = math.sin(t * 34.0 + ph + math.cos(a) * 2.4) * 0.6 + noise.noise(Vector((t * 7.0 + ph, j * 0.55, 1.0))) * 1.2
            folded[(i, j)] = fold
            k = 1.0 + fold * (0.1 if old else 0.055)
            s = math.sin(a) ** 0.75
            ring.append((x + w * k * math.cos(a), y, z + 0.008 + h * k * s))
        rings.append(ring)
    main, dark, band = (GREY, GREY_FOLD, RAG) if old else (LINEN, LINEN_FOLD, LINEN_BAND)
    if rag:
        main, dark, band = GREY_FOLD, RAG, RAG
    start = len(p.bm.faces)

    def tone(i, j):
        t = (i + 0.5) / sections
        if j < around - 1 and any(abs(t - b) < 0.5 / sections for b in BANDS):
            return band
        return dark if folded[(i, min(j, around - 1))] < -0.12 else main
    p.loft(rings, tone, main)
    if rag:
        torn = [f for f in list(p.bm.faces)[start:] if len(f.verts) == 4 and rng.random() < 0.24]
        bmesh.ops.delete(p.bm, geom=torn, context="FACES_ONLY")


def spine(p, m, size, colour, page):
    """A book through m, spine on +X: pages on the top, bottom and back."""
    p.box(m, size, colour, top=page, under=page, back=page)


def upright(p, x, y, z, thick, height, depth, colour, page, lean=0.0, yaw=0.0):
    m = Matrix.Translation((x, y, z)) @ Matrix.Rotation(yaw, 4, "Z") @ Matrix.Rotation(lean, 4, "X") \
        @ Matrix.Translation((-depth * 0.5, 0.0, height * 0.5))
    spine(p, m, (depth, thick, height), colour, page)


def row(p, y0, y1, z, rng, old, top):
    """Books standing along a shelf, spines out; old rows have gaps and lean."""
    spines, page = (SPINES_OLD, PAGES_OLD) if old else (SPINES, PAGES)
    y = y0
    lean = 0.0
    while y < y1:
        thick = rng.uniform(0.028, 0.07)
        if y + thick > y1:
            break
        if rng.random() < (0.22 if old else 0.05):
            y += rng.uniform(0.05, 0.13)
            lean = rng.uniform(0.08, 0.24) * rng.choice((-1.0, 1.0))
            continue
        height = rng.uniform(top * 0.62, top)
        depth = rng.uniform(0.2, 0.3)
        x = -0.12 - rng.uniform(0.0, 0.14 if old else 0.035)
        upright(p, x, y + thick * 0.5, z, thick, height, depth, rng.choice(spines), page, lean, rng.uniform(-0.05, 0.05))
        lean *= 0.5
        y += thick + 0.003


def stack(p, y, z, rng, old, count):
    """Books lying flat, one on another, skewed."""
    spines, page = (SPINES_OLD, PAGES_OLD) if old else (SPINES, PAGES)
    for _i in range(count):
        thick = rng.uniform(0.03, 0.055)
        width = rng.uniform(0.17, 0.25)
        depth = rng.uniform(0.22, 0.3)
        yaw = rng.uniform(-0.14, 0.14) * (2.2 if old else 1.0)
        m = Matrix.Translation((-0.14 - depth * 0.5 - rng.uniform(0.0, 0.04), y + rng.uniform(-0.02, 0.02), z + thick * 0.5)) \
            @ Matrix.Rotation(yaw, 4, "Z")
        c = rng.choice(spines)
        p.box(m, (depth, width, thick), page, top=c, under=c, front=c)
        z += thick


def bundle(p, x, y, z, length, rx, rz, rng, old):
    """A book wrapped in cloth and tied: a soft-cornered packet along Y."""
    wrap = rng.choice(WRAPS_OLD if old else WRAPS)
    twine = TWINE_OLD if old else TWINE
    ph = rng.uniform(0.0, 30.0)
    n, around = 12, 12
    rings = []
    for i in range(n + 1):
        t = i / n
        k = 0.72 + 0.28 * (1.0 - abs(2.0 * t - 1.0) ** 5) ** 0.5
        ring = []
        for j in range(around):
            a = 2.0 * math.pi * (j + 0.5) / around
            c, s = math.cos(a), math.sin(a)
            wob = 1.0 + 0.05 * noise.noise(Vector((t * 4.0 + ph, j * 0.8, 2.0)))
            lift = rz * k * wob
            ring.append((x + rx * k * wob * math.copysign(abs(c) ** 0.5, c), y - length * 0.5 + length * t,
                         z + lift + lift * math.copysign(abs(s) ** 0.5, s) * (0.86 if old else 1.0)))
        rings.append(ring)
    ties = (3, 8)
    p.loft(rings, lambda i, _j: twine if i in ties else wrap, wrap)


def scroll(p, x, y, z, length, r, rng, old):
    """A rolled scroll along Y, its paper ends showing."""
    wrap = rng.choice((PAGES_OLD, GREY) if old else (PAGES, LINEN, OCHRE))
    end = PAGES_OLD if old else LINEN_BAND
    ring = lambda yy: [(x + r * math.cos(2.0 * math.pi * j / 6), yy, z + r + r * math.sin(2.0 * math.pi * j / 6)) for j in range(6)]
    p.loft([ring(y - length * 0.5), ring(y + length * 0.5)], lambda _i, _j: wrap, end, smooth=False)


def scrolls(p, y, z, rng, old):
    r = 0.032
    for layer, (count, x0) in enumerate(((4, -0.2), (3, -0.232))):
        for i in range(count):
            x = x0 - i * r * 2.05
            scroll(p, x, y + rng.uniform(-0.03, 0.03), z + layer * r * 1.75, rng.uniform(0.4, 0.54), r, rng, old)


def nook(p, kind, y, z, rng, old):
    """A small niche's contents, its middle at y, its sill at z."""
    if kind == "row":
        row(p, y - 0.31, y + 0.31, z, rng, old, SMALL_HEIGHT - 0.04)
    elif kind == "stack":
        stack(p, y - 0.14, z, rng, old, rng.randint(3, 5))
        stack(p, y + 0.15, z, rng, old, rng.randint(1, 4))
    elif kind == "half":
        row(p, y - 0.31, y + 0.02, z, rng, old, SMALL_HEIGHT - 0.04)
        stack(p, y + 0.18, z, rng, old, rng.randint(2, 4))
    elif kind == "bundle":
        bundle(p, -0.3, y - 0.14, z, 0.34, 0.12, 0.075, rng, old)
        bundle(p, -0.3, y + 0.17, z, 0.3, 0.11, 0.07, rng, old)
    elif kind == "scrolls":
        scrolls(p, y, z, rng, old)


def goods(fill):
    """A module's build function from a function of (Pack, rng), seeded by its
    name so a rebuild comes out the same."""
    def build(r):
        name = r.name[2:]
        p = Pack(r, name)
        fill(p, random.Random(name))
        p.done()
    return build


def long_body(flip, old):
    return goods(lambda p, rng: shroud(p, -0.33, 0.2, LONG_SILL, 1.6, flip, old, rng))


def long_books(old):
    def fill(p, rng):
        y = 0.24
        for part in ("row", "stack", "row", "stack", "row"):
            if part == "row":
                width = rng.uniform(0.28, 0.42)
                row(p, y, min(y + width, 1.76), LONG_SILL, rng, old, LONG_HEIGHT - 0.05)
                y += width + 0.05
            else:
                stack(p, y + 0.12, LONG_SILL, rng, old, rng.randint(2, 6))
                y += 0.3
    return goods(fill)


def long_bundles(old):
    def fill(p, rng):
        for y, length in ((0.52, 0.5), (1.04, 0.44), (1.5, 0.46)):
            bundle(p, -0.3, y, LONG_SILL, length, 0.15, 0.095, rng, old)
        bundle(p, -0.31, 0.8, LONG_SILL + 0.17, 0.42, 0.12, 0.075, rng, old)
    return goods(fill)


def upper(kinds, old):
    def fill(p, rng):
        for (y, sill), kind in zip(SMALL, kinds):
            nook(p, kind, y, sill, rng, old)
    return goods(fill)


def single(kind):
    return goods(lambda p, rng: nook(p, kind, 0.0, 0.0, rng, False))


def bier(lit, rag=False):
    """A stone bier on the os_bier room's axis, feet toward the door; a lit one
    has a candle at the head (a dark one's fill light is the room's)."""
    def build(r):
        name = r.name[2:]
        sb = bmesh.new()
        add_box(sb, 1.56, 2.44, 0.98, 3.1, 0.0, 0.1)
        add_box(sb, 1.64, 2.36, 1.06, 3.02, 0.1, 0.52)
        add_box(sb, 1.58, 2.42, 1.0, 3.08, 0.52, 0.62)
        mesh_object(name + "__slab-col", sb, [STONE], r)
        p = Pack(r, name)
        shroud(p, 2.0, 1.08, 0.62, 1.66, False, not lit, random.Random(name), rag=rag)
        p.done()
        if lit:
            wb = bmesh.new()
            add_lathe(wb, [(0.03, 0.62), (0.03, 0.76)], cx=2.0, cy=2.95, segs=6)
            mesh_object(name + "__wax", wb, [WAX], r)
            fb = bmesh.new()
            add_lathe(fb, [(0.0, 0.77), (0.016, 0.79), (0.0, 0.84)], cx=2.0, cy=2.95, segs=4)
            mesh_object(name + "__flame", fb, [FLAME], r)
            marker("LIGHT_ossuary_candle__flame", r, (2.0, 2.8, 1.02))
    return build


def shrine_dress(r, old=False):
    """On the shrine's ledges (chamber frame): the wrapped great book on a stone
    block, a red cloth run down the steps, books and bundles at the sides. Old:
    the same left for years, the cloth grey and torn."""
    name = r.name[2:]
    sb = bmesh.new()
    add_box(sb, -0.18, 0.18, 4.7, 5.05, 0.6, 0.74)
    for v in sb.verts:      # its top slopes up to the back, a reading rest
        if v.co.z > 0.7 and v.co.y > 5.0:
            v.co.z = 0.97
    mesh_object(name + "__stand", sb, [STONE], r)
    p = Pack(r, name)
    rng = random.Random("os_shrine")
    # The great book, wrapped and tied, lying on the rest.
    m = Matrix.Translation((0.0, 4.85, 0.9)) @ Matrix.Rotation(-0.99, 4, "X")
    p.box(m, (0.33, 0.1, 0.38), GREY if old else LINEN, top=GREY_FOLD if old else LINEN_FOLD, under=GREY_FOLD if old else LINEN_FOLD)
    tie = TWINE_OLD if old else TWINE
    p.box(m @ Matrix.Translation((0.0, 0.0, 0.1)), (0.34, 0.11, 0.02), tie)
    p.box(m @ Matrix.Translation((0.0, 0.0, -0.1)), (0.34, 0.11, 0.02), tie)
    # The cloth, down the steps to the niche's floor.
    path = ((4.76, 0.606), (4.645, 0.606), (4.64, 0.306), (4.245, 0.306), (4.24, 0.006), (3.72, 0.006))
    cloth = Pack(r, name + "_cloth")
    verts = []
    for y, z in path:
        verts.append([cloth.bm.verts.new((x, y, z)) for x in (-0.3, -0.1, 0.1, 0.3)])
    for i in range(len(path) - 1):
        for j in range(3):
            if old and i > 1 and rng.random() < 0.4:
                continue
            tone = (GREY_FOLD if j == 1 else RAG) if old else (OXBLOOD if j == 1 else OXBLOOD_FOLD)
            cloth.face((verts[i + 1][j], verts[i + 1][j + 1], verts[i][j + 1], verts[i][j]), tone)
    # At the sides: stacks and bundles on the niche's floor and the lower ledge.
    frame = lambda x, y: Matrix.Translation((x, y, 0.0))
    for x, y, z, n in ((-1.14, 3.86, 0.02, 6), (1.12, 3.9, 0.02, 4), (-0.62, 3.8, 0.02, 3)):
        before = len(p.bm.verts)
        stack(p, 0.0, z, rng, old, n)
        moved = list(p.bm.verts)[before:]
        bmesh.ops.transform(p.bm, matrix=frame(x + 0.28, y), verts=moved)
    bundle(p, 0.7, 3.84, 0.02, 0.42, 0.17, 0.05, rng, old)
    bundle(p, 1.05, 4.42, 0.3, 0.34, 0.13, 0.045, rng, old)
    bundle(p, -1.0, 4.84, 0.6, 0.34, 0.12, 0.04, rng, old)
    mesh_object(name + "__cloth", cloth.bm, [GOODS], r, recalc=False)
    p.done()


UPPERS = {
    "upper_a": (("row", "half", "bundle", "stack"), False),
    "upper_b": (("stack", "row", "row", "scrolls"), False),
    "upper_c": (("bundle", "scrolls", "half", "row"), False),
    "upper_old_a": (("half", "", "stack", "bundle"), True),
    "upper_old_b": (("", "row", "bundle", ""), True),
    "upper_old_c": (("stack", "scrolls", "", "half"), True),
}

GOODS_MODULES = [
    ("M_os_item_long_body_a", props(), long_body(False, False)),
    ("M_os_item_long_body_b", props(), long_body(True, False)),
    ("M_os_item_long_old_a", props(), long_body(False, True)),
    ("M_os_item_long_old_b", props(), long_body(True, True)),
    ("M_os_item_long_books", props(), long_books(False)),
    ("M_os_item_long_books_old", props(), long_books(True)),
    ("M_os_item_long_bundles", props(), long_bundles(False)),
    ("M_os_item_long_bundles_old", props(), long_bundles(True)),
    ("M_os_item_nook_row", props(), single("row")),
    ("M_os_item_nook_stack", props(), single("stack")),
    ("M_os_item_nook_bundle", props(), single("bundle")),
    ("M_os_item_bier", props(), bier(True)),
    ("M_os_item_bier_old", props(), bier(False)),
] + [("M_os_item_" + n, props(), upper(k, o)) for n, (k, o) in UPPERS.items()]

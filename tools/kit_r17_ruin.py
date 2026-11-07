"""The R17 Ossuary of Books' story (phase 16 step 4): what the mourners left, what
time has done deep in, and the two things you can touch. tools/kit_add_r17.py
builds these; OssuaryGrammar places them. Frames as tools/kit_r17_goods.py;
os_item_offer_* are centred on their origin, on the floor.

  os_item_long_rag_*    the cloth torn through and collapsed (never bones: Q1)
  os_item_long_slump_*  an old body slid out over the sill to the floor
  os_item_spill_*       books fallen at the foot of the wall; b with a torn cloth
  os_item_rock_*        bare rock broken through a bay (these two collide)
  os_item_offer_*       fresh cloth, a bowl, dried flowers, a tray of spare candles
  os_lore_book          a book to take (gen/modules/ossuary_lore_*.tscn)
  os_vigil              the shrine candle you light (gen/modules/ossuary_vigil.tscn)
"""
import math
import random

import bmesh
from mathutils import Matrix, Vector, noise

from kit_blender import add_box, add_lathe, add_tube, marker, mesh_object
from kit_r17_goods import (DUSTY, FLAME, GILT, GOODS, GREY_FOLD, LEATHER, LEATHER_DARK, LINEN, LINEN_FOLD, LONG_SILL, OCHRE, OXBLOOD,
                           OXBLOOD_FOLD, PAGES, PAGES_OLD, RAG, SPINES_OLD, TWINE, TWINE_OLD, WAX, Pack, bier, goods, props, shroud)

ROCK = "ossuary_floor"      # darker than the walls: cut stone gives way to raw


def long_rag(flip):
    return goods(lambda p, rng: shroud(p, -0.33, 0.2, LONG_SILL, 1.6, flip, True, rng, rag=True))


def long_slump(flip):
    """An old body slid half out of its niche, its head on the passage floor."""
    def fill(p, rng):
        shroud(p, -0.33, 0.2, LONG_SILL, 1.6, flip, True, rng)
        turn = Matrix.Rotation(0.42 if flip else -0.42, 3, "Z")
        pivot = Vector((-0.33, 1.8 if flip else 0.2, 0.0))
        for v in p.bm.verts:
            v.co = pivot + turn @ (v.co - pivot)
            t = min(max(v.co.x / 0.3, 0.0), 1.0)
            v.co.z -= LONG_SILL * t * t * (3.0 - 2.0 * t)
    return goods(fill)


def fallen(p, rng, count):
    """Old books fallen out at the foot of the wall."""
    for _i in range(count):
        c = rng.choice(SPINES_OLD)
        x = 0.05 + abs(rng.gauss(0.0, 0.2))
        t = rng.uniform(0.03, 0.055)
        m = Matrix.Translation((x, rng.uniform(0.25, 1.75), rng.uniform(0.0, 0.05) + t)) @ Matrix.Rotation(rng.uniform(0.0, 6.28), 4, "Z") \
            @ Matrix.Rotation(rng.uniform(-0.25, 0.25), 4, "X")
        p.box(m, (rng.uniform(0.2, 0.28), rng.uniform(0.16, 0.24), t), PAGES_OLD, top=c, under=c, front=c)


def spill(cloth):
    """A heap of fallen books; with a torn cloth hanging out over the sill."""
    def build(r):
        name = r.name[2:]
        rng = random.Random(name)
        p = Pack(r, name)
        fallen(p, rng, 9 if cloth else 15)
        p.done()
        if cloth:
            sheet = Pack(r, name + "_cloth")
            path = ((-0.4, 0.232), (-0.1, 0.235), (0.015, 0.23), (0.04, 0.12), (0.05, 0.012), (0.25, 0.01), (0.46, 0.008))
            ys = (0.5, 0.72, 0.94, 1.16, 1.38)
            vs = [[sheet.bm.verts.new((x + rng.uniform(0.0, 0.05) * (i > 4), y + rng.uniform(-0.04, 0.04), z)) for y in ys]
                  for i, (x, z) in enumerate(path)]
            for i in range(len(path) - 1):
                for j in range(len(ys) - 1):
                    if i < 4 or rng.random() < 0.6 - 0.2 * abs(j - 1.5):
                        sheet.face((vs[i][j], vs[i + 1][j], vs[i + 1][j + 1], vs[i][j + 1]), GREY_FOLD)
            mesh_object(name + "__cloth", sheet.bm, [GOODS], r, recalc=False)
    return build


def lump(bm, centre, radii, seed):
    """A broken lump of rock: few, flat faces."""
    made = bmesh.ops.create_icosphere(bm, subdivisions=2, radius=1.0)["verts"]
    for v in made:
        d = v.co.copy()
        k = 1.0 + 0.5 * noise.noise(d * 1.4 + Vector((seed, 0.0, 0.0))) + 0.22 * noise.noise(d * 3.1 + Vector((0.0, seed, 0.0)))
        v.co = Vector((centre[0] + d.x * radii[0] * k, centre[1] + d.y * radii[1] * k, centre[2] + d.z * radii[2] * k))


# The stones fallen from the rock: (x, y, z, then the radii).
STONES_LOW = ((0.1, 0.5, 0.03, 0.2, 0.28, 0.13), (0.17, 1.5, 0.02, 0.16, 0.22, 0.1))
STONES_HIGH = ((0.12, 0.7, 0.04, 0.2, 0.3, 0.13), (0.3, 1.3, 0.02, 0.13, 0.15, 0.09))
ROCK_STEP = 0.14


def rock_face(bm, middle, seed):
    """One jagged surface rising out of the wall. Most of it lies behind the
    niches' backs, unseen; about `middle` (along the wall, up) it comes forward,
    filling the niches first, then through the wall's face."""
    n, m = int(2.5 / ROCK_STEP), int(2.7 / ROCK_STEP)
    grid = []
    for i in range(n + 1):
        col = []
        for j in range(m + 1):
            y, z = -0.25 + i * ROCK_STEP, -0.1 + j * ROCK_STEP
            d = math.hypot((y - middle[0]) / 1.05, (z - middle[1]) / 0.95)
            wide = noise.noise(Vector((y * 1.6, z * 1.6, seed)))
            t = min(max(1.0 - d + 0.55 * wide, 0.0), 1.0)
            jag = noise.noise(Vector((y * 5.0, z * 5.0, seed + 4.0)))
            x = -0.72 + 1.0 * t * t * (3.0 - 2.0 * t) + 0.11 * jag * min(t * 3.0, 1.0)
            col.append(bm.verts.new((min(x, 0.3), y + 0.05 * jag, z)))
        grid.append(col)
    for i in range(n):
        for j in range(m):
            f = bm.faces.new((grid[i][j], grid[i + 1][j], grid[i + 1][j + 1], grid[i][j + 1]))
            f.normal_update()


def rock(low):
    """Bare rock broken through a bay: over its lower niches, or its upper ones
    with stones fallen at the foot of the wall."""
    def build(r):
        name = r.name[2:]
        bm = bmesh.new()
        rock_face(bm, (1.0, 0.6) if low else (1.0, 1.7), 3.0 if low else 14.0)
        mesh_object(name + "__rock", bm, [ROCK], r, recalc=False)
        sb = bmesh.new()
        for i, (x, y, z, rx, ry, rz) in enumerate(STONES_LOW if low else STONES_HIGH):
            lump(sb, (x, y, z), (rx, ry, rz), 3.0 + i * 2.7)
        mesh_object(name + "__stones", sb, [ROCK], r)
        cb = bmesh.new()
        add_box(cb, -0.1, 0.1, 0.6, 1.4, 0.3 if low else 1.3, 1.0 if low else 2.1)
        mesh_object(name + "__col-colonly", cb, [ROCK], r)
    return build


def circle(radius, z, n):
    return [(radius * math.cos(2.0 * math.pi * j / n), radius * math.sin(2.0 * math.pi * j / n), z) for j in range(n)]


def offer_cloth(p, rng):
    """Fresh cloth, folded and left."""
    z = 0.0
    for i in range(3):
        m = Matrix.Translation((0.0, 0.0, z + 0.014)) @ Matrix.Rotation(rng.uniform(-0.06, 0.06), 4, "Z")
        p.box(m, (0.3, 0.24, 0.028), LINEN if i % 2 else LINEN_FOLD)
        z += 0.028


def offer_bowl(p, _rng):
    """A clay bowl of oil."""
    rings = [circle(r, z, 10) for (r, z) in ((0.045, 0.0), (0.075, 0.015), (0.098, 0.05), (0.105, 0.075), (0.09, 0.07))]
    p.loft(rings, lambda i, _j: OCHRE if i < 3 else DUSTY, LEATHER_DARK)


def offer_flowers(p, rng):
    """A tied bunch of dried flowers, lying down."""
    for i in range(10):
        m = Matrix.Rotation((i - 4.5) * 0.028, 4, "Z")
        lift = (i % 3) * 0.012
        p.box(m @ Matrix.Translation((0.0, 0.06, 0.02 + lift)), (0.007, 0.34, 0.007), TWINE_OLD)
        for _k in range(2):
            head = m @ Matrix.Translation((rng.uniform(-0.03, 0.03), 0.2 + rng.uniform(0.0, 0.1), 0.028 + lift))
            p.box(head, (0.05, 0.05, 0.04), rng.choice((OXBLOOD, OXBLOOD_FOLD, OCHRE, DUSTY)))
    p.box(Matrix.Translation((0.0, -0.01, 0.03)), (0.05, 0.03, 0.05), TWINE)


def offer_tray(p, _rng):
    """A wooden tray of spare candles."""
    p.box(Matrix.Translation((0.0, 0.0, 0.012)), (0.42, 0.24, 0.024), LEATHER_DARK)
    for sx, sy, w, d in ((-0.205, 0.0, 0.016, 0.24), (0.205, 0.0, 0.016, 0.24), (0.0, -0.115, 0.42, 0.016), (0.0, 0.115, 0.42, 0.016)):
        p.box(Matrix.Translation((sx, sy, 0.03)), (w, d, 0.036), LEATHER)
    for i in range(7):
        x, r = -0.15 + i * 0.05, 0.018

        def ring(y):
            return [(x + r * math.cos(2.0 * math.pi * j / 6), y, 0.024 + r + r * math.sin(2.0 * math.pi * j / 6)) for j in range(6)]
        p.loft([ring(-0.095), ring(0.095)], lambda _i, _j: LINEN, PAGES, smooth=False)


def lore_book(r):
    """A book worth taking, by itself in a small niche (nook frame) on a folded
    cloth: dark binding, bands of gilt. Its collision is a hull, made at load."""
    p = Pack(r, "os_lore_book")
    p.box(Matrix.Translation((-0.28, 0.0, 0.012)), (0.34, 0.3, 0.024), LINEN_FOLD)
    m = Matrix.Translation((-0.28, 0.0, 0.058)) @ Matrix.Rotation(0.2, 4, "Z")
    p.box(m, (0.26, 0.2, 0.066), PAGES, top=OXBLOOD_FOLD, under=OXBLOOD_FOLD, front=OXBLOOD_FOLD)
    p.box(m @ Matrix.Translation((0.09, 0.0, 0.0)), (0.03, 0.21, 0.072), GILT)
    p.done()


def vigil(r):
    """The shrine's candle on its dish, for you to light. The wax and flame are
    their own meshes with origins at the floor: ShrineCandle burns the wax down
    by scaling it."""
    p = Pack(r, "os_vigil")
    p.loft([circle(rr, z, 8) for (rr, z) in ((0.05, 0.0), (0.075, 0.012), (0.08, 0.022))], lambda _i, _j: OCHRE, DUSTY)
    p.done()
    wb = bmesh.new()
    add_lathe(wb, [(0.026, 0.016), (0.026, 0.2)], segs=6)
    mesh_object("os_vigil__wax", wb, [WAX], r)
    fb = bmesh.new()
    add_lathe(fb, [(0.0, 0.21), (0.016, 0.23), (0.0, 0.29)], segs=4)
    mesh_object("os_vigil__flame", fb, [FLAME], r)


def lantern(r):
    """An oil lantern hung on a chain from the vault at the cell's middle, so the
    passage light has a source you can see. The chain runs up into the rock."""
    p = Pack(r, "os_lantern")
    z, turn = 2.34, 0.0
    while z < 3.2:
        p.box(Matrix.Translation((0.0, 0.0, z)) @ Matrix.Rotation(turn, 4, "Z"), (0.03, 0.01, 0.055), LEATHER_DARK)
        z, turn = z + 0.05, 1.57 - turn
    p.box(Matrix.Translation((0.0, 0.0, 2.07)), (0.15, 0.15, 0.022), LEATHER_DARK)
    p.box(Matrix.Translation((0.0, 0.0, 2.28)), (0.17, 0.17, 0.022), LEATHER_DARK)
    p.box(Matrix.Translation((0.0, 0.0, 2.31)), (0.08, 0.08, 0.04), LEATHER_DARK)
    for sx in (-0.065, 0.065):
        for sy in (-0.065, 0.065):
            p.box(Matrix.Translation((sx, sy, 2.175)), (0.012, 0.012, 0.2), LEATHER_DARK)
    p.done()
    fb = bmesh.new()
    add_lathe(fb, [(0.0, 2.09), (0.028, 2.13), (0.018, 2.18), (0.0, 2.24)], segs=6)
    mesh_object("os_lantern__flame", fb, [FLAME], r)
    marker("LIGHT_ossuary_lantern__glow", r, (0.0, 0.0, 2.16))


def glowcaps(name, r, caps):
    """Pale mushrooms with cold glowing caps on a pad of moss: the abandoned
    stacks' glowcaps, the same plant, grown here where nobody brings a candle."""
    stems, tops = bmesh.new(), bmesh.new()
    for (x, y, h, cr) in caps:
        add_lathe(stems, [(0.0, 0.0), (cr * 0.35, 0.0), (cr * 0.25, h * 0.5), (cr * 0.22, h), (0.0, h)], cx=x, cy=y, segs=6)
        add_lathe(tops, [(0.0, h - cr * 0.15), (cr, h - cr * 0.05), (cr * 0.9, h + cr * 0.2), (cr * 0.5, h + cr * 0.45), (0.0, h + cr * 0.5)], cx=x, cy=y, segs=8)
    moss = bmesh.new()
    add_lathe(moss, [(0.0, 0.0), (0.36, 0.0), (0.3, 0.025), (0.0, 0.03)], segs=9)
    mesh_object(name + "__stems", stems, ["linen"], r)
    mesh_object(name + "__caps", tops, ["emit_glowcap"], r)
    mesh_object(name + "__moss", moss, ["moss"], r)


def glow(r):
    """The big clump: it carries the cold light, low, so the fog takes it up."""
    glowcaps("os_glow", r, [(-0.1, -0.06, 0.24, 0.11), (0.06, -0.1, 0.33, 0.14), (0.18, 0.04, 0.17, 0.09), (-0.22, 0.08, 0.13, 0.08),
                            (0.02, 0.1, 0.12, 0.07), (0.26, -0.12, 0.13, 0.07), (-0.05, 0.2, 0.08, 0.05)])
    marker("LIGHT_ossuary_glow__cold", r, (0.0, 0.0, 0.6))


def glow_small(r):
    """A few caps by themselves, unlit: they only mark the dark."""
    glowcaps("os_glow_small", r, [(-0.06, 0.0, 0.15, 0.08), (0.1, -0.05, 0.2, 0.09), (0.04, 0.12, 0.09, 0.05)])


def web(bm, a, b, c):
    """A cobweb across a corner: threads, not a sheet (as tools/kit_add_r02.py)."""
    mid = tuple((a[i] + b[i] + c[i]) / 3.0 for i in range(3))
    mid = (mid[0] + 0.03, mid[1], mid[2] - 0.05)
    half = lambda p, q: tuple((p[i] + q[i]) * 0.5 for i in range(3))
    spokes = [a, half(a, b), b, half(b, c), c, half(c, a)]
    for p in spokes:
        add_tube(bm, [mid, p], 0.006, segs=3)
    for ring in (0.3, 0.55, 0.8):
        pts = [tuple(mid[i] + (p[i] - mid[i]) * ring for i in range(3)) for p in spokes]
        add_tube(bm, pts + [pts[0]], 0.0035, segs=3)


def webs(high):
    """Cobwebs across a bay's niche corners; `high` adds a big one from the top
    of the wall up to the vault."""
    def build(r):
        name = r.name[2:]
        bm = bmesh.new()
        if high:
            web(bm, (0.0, 0.3, 2.28), (0.0, 1.5, 2.28), (0.55, 0.95, 2.72))
            web(bm, (0.0, 1.85, 0.42), (0.0, 1.85, 0.72), (0.0, 1.35, 0.8))
            web(bm, (0.0, 1.1, 1.0), (0.0, 1.1, 1.22), (0.0, 1.5, 1.32))
        else:
            web(bm, (0.0, 0.15, 0.42), (0.0, 0.15, 0.72), (0.0, 0.7, 0.81))
            web(bm, (0.0, 0.15, 1.52), (0.0, 0.15, 1.74), (0.0, 0.58, 1.84))
            web(bm, (0.0, 1.85, 1.0), (0.0, 1.85, 1.22), (0.0, 1.42, 1.32))
        mesh_object(name + "__strands", bm, ["cobweb"], r)
    return build


RUIN_MODULES = [
    ("M_os_item_long_rag_a", props(), long_rag(False)),
    ("M_os_item_long_rag_b", props(), long_rag(True)),
    ("M_os_item_long_slump_a", props(), long_slump(False)),
    ("M_os_item_long_slump_b", props(), long_slump(True)),
    ("M_os_item_spill_a", props(), spill(False)),
    ("M_os_item_spill_b", props(), spill(True)),
    ("M_os_item_rock_low", props(), rock(True)),
    ("M_os_item_rock_high", props(), rock(False)),
    ("M_os_item_bier_rag", props(), bier(False, True)),
    ("M_os_item_offer_cloth", props(), goods(offer_cloth)),
    ("M_os_item_offer_bowl", props(), goods(offer_bowl)),
    ("M_os_item_offer_flowers", props(), goods(offer_flowers)),
    ("M_os_item_offer_tray", props(), goods(offer_tray)),
    ("M_os_lore_book", props(), lore_book),
    ("M_os_vigil", props(), vigil),
    ("M_os_lantern", props(), lantern),
    ("M_os_glow", props(), glow),
    ("M_os_glow_small", props(), glow_small),
    ("M_os_item_web_a", props(), webs(False)),
    ("M_os_item_web_b", props(), webs(True)),
]

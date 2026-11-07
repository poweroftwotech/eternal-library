"""Seeds the R17 Ossuary of Books modules into art_src/kit/kit_ossuary.blend
(phase 16, docs/environment/phase-16-approval.md).

  blender --background --factory-startup --python tools/kit_add_r17.py

Creates kit_ossuary.blend if it doesn't exist, then adds only the modules that
are not in it yet (hand edits are kept), and remakes those in REBUILD. Then run
tools/export_kit.bat kit_ossuary.blend.

The room (OssuaryGrammar, scripts/gen/ossuary_grammar.gd): a tree of passages
2.2 m wide, one 4 m cell each, cut into pale stone, with the shrine's chamber
where the passages meet. Every piece comes from one plan polygon: the floor and
vault fill it, and its wall edges are cut with niches. A vault's height depends
only on the distance to the nearest wall, so all the pieces meet.

Cell frame (os_straight .. os_bier, os_throat): the cell's south-west corner,
X 0..4 east, Y 0..4 north, Z up, the passage on the cell's middle.
Chamber frame (os_chamber, os_plug): centred on the 12 x 12 m block.

  os_straight   open S and N: two niche bays a side
  os_bend       open S and E
  os_tee        open S, E and W
  os_cross      open all round
  os_end        open S: a dead end, a niche bay across it
  os_bier       open S: a dead end widened to a small room for a bier
  os_throat     open S and N: from the cave passage (bh_cave_straight) down to
                the low passage
  os_chamber    open S, E and W: an eight-sided chamber, the shrine's great
                niche in its north side
  os_plug       a niche wall across the chamber's east arm, where nothing leads on
  os_candle     a niche's candle and its light
  os_shrine     the great niche's ledges and candles (chamber frame)
  os_fill, os_fill_low  the dim fill light, set low; fainter in the forgotten stretches
  os_item_*     what lies in the niches and on the biers (tools/kit_r17_goods.py)

A bay is 2 m of wall: one long niche for the dead along the bottom, four small
ones over it for books and bundles.
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector, geometry, noise

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kit_blender import add_box, add_lathe, marker, mesh_object, module, rebuild  # noqa: E402
from kit_r17_goods import GOODS_MODULES, shrine_dress  # noqa: E402
from kit_r17_ruin import RUIN_MODULES  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BLEND = os.path.join(ROOT, "art_src", "kit", "kit_ossuary.blend")
ROW_Y = -240.0
STONE, FLOOR = "ossuary_stone", "ossuary_floor"
WAX, FLAME = "wax", "emit_lantern"
L, R = 0.9, 3.1        # the passage's sides in its cell
HALF = 1.1             # half its width
SPRING = 2.3           # where the vault starts
RISE = 0.6             # how far it climbs in a passage
DOME_TOP = 3.8         # the chamber's vault stays in its storey
APOTHEM = 3.6          # the chamber's middle to each side
STEP = 0.275           # mesh spacing on floors, vaults and walls
ROUGH = 0.045          # how far walls stray from flat
SEAM = 0.4             # the roughness fades out this close to a piece's edges
RINGS = (0.05, 0.14, 0.28, 0.5, 0.78)     # how far in the vault's rings of points run
# The Bridge Hall's cave passage (tools/kit_add_r21.py), which the throat joins.
CAVE_SEGS, CAVE_HALF, CAVE_TOP = 16, 1.65, 3.3


def props(size=(1, 1, 1), tags="ossuary,r17"):
    return {"kit_shape": "free", "kit_family": "walls", "size_cells": list(size), "edge": "", "tags": tags, "weight": 1.0}


def face(bm, verts, want, mat=0):
    """A face turned to look along `want`."""
    f = bm.faces.new(verts)
    f.normal_update()
    if f.normal.dot(want) < 0.0:
        f.normal_flip()
    f.material_index = mat
    return f


def rock(p):
    return noise.noise(Vector((p[0] * 1.3, p[1] * 1.3, p[2] * 1.3))) * 0.7 \
        + noise.noise(Vector((p[0] * 3.7, p[1] * 3.7, p[2] * 3.7 + 7.0))) * 0.3


def in_poly(p, poly):
    inside = False
    n = len(poly)
    for i in range(n):
        a, b = poly[i], poly[(i + 1) % n]
        if (a[1] > p[1]) != (b[1] > p[1]) and p[0] < a[0] + (p[1] - a[1]) / (b[1] - a[1]) * (b[0] - a[0]):
            inside = not inside
    return inside


def seg_dist(p, a, b):
    ax, ay = b[0] - a[0], b[1] - a[1]
    t = ((p[0] - a[0]) * ax + (p[1] - a[1]) * ay) / max(ax * ax + ay * ay, 1e-9)
    t = min(1.0, max(0.0, t))
    return math.hypot(p[0] - a[0] - ax * t, p[1] - a[1] - ay * t)


def along(a, b, step=STEP):
    """Points from a up to but not including b."""
    n = max(1, int(round(math.hypot(b[0] - a[0], b[1] - a[1]) / step)))
    return [(a[0] + (b[0] - a[0]) * i / n, a[1] + (b[1] - a[1]) * i / n) for i in range(n)]


def triangulate(outline, holes, extra):
    """Triangles [(a, b, c)] of 2D points inside `outline` and outside `holes`."""
    pts, edges = [], []
    for loop in [outline] + holes:
        base = len(pts)
        pts.extend(loop)
        edges.extend((base + i, base + (i + 1) % len(loop)) for i in range(len(loop)))
    pts.extend(extra)
    v, _e, f, _ov, _oe, _of = geometry.delaunay_2d_cdt([Vector(p) for p in pts], edges, [], 0, 1e-5)
    out = []
    for t in f:
        c = (sum(v[i][0] for i in t) / 3.0, sum(v[i][1] for i in t) / 3.0)
        if in_poly(c, outline) and not any(in_poly(c, h) for h in holes):
            out.append([tuple(v[i]) for i in t])
    return out


def grid_points(outline, holes, step=STEP, keep=0.1):
    """Interior points of an outline, clear of its edges and holes."""
    xs = [p[0] for p in outline]
    ys = [p[1] for p in outline]
    out = []
    x = min(xs) + step * 0.5
    while x < max(xs):
        y = min(ys) + step * 0.5
        while y < max(ys):
            p = (x, y)
            if in_poly(p, outline) and not any(in_poly(p, h) for h in holes):
                near = False
                for loop in [outline] + holes:
                    for i in range(len(loop)):
                        if seg_dist(p, loop[i], loop[(i + 1) % len(loop)]) < keep:
                            near = True
                            break
                    if near:
                        break
                if not near:
                    out.append(p)
            y += step
        x += step
    return out


def mesh_from(bm, tris, to3d, want, mat=0):
    """Triangles of 2D points as shared 3D verts."""
    verts = {}

    def vert(p):
        k = (round(p[0], 4), round(p[1], 4))
        if k not in verts:
            verts[k] = bm.verts.new(to3d(p))
        return verts[k]
    for t in tris:
        vs = [vert(p) for p in t]
        if len(set(vs)) == 3:
            face(bm, vs, want(t), mat)
    return vert


def arch_loop(s0, width, sill, spring, rise, n=6):
    """A niche's mouth, counter-clockwise in (along the wall, up): flat sill,
    straight sides, a shallow arch."""
    pts = [(s0, sill), (s0 + width, sill), (s0 + width, spring)]
    for i in range(1, n):
        t = i / n
        pts.append((s0 + width * (1.0 - t), spring + rise * math.sin(math.pi * t)))
    pts.append((s0, spring))
    return pts


def bay_niches(s0):
    """The five mouths of a 2 m bay starting at s0: [(loop, depth)]."""
    out = [(arch_loop(s0 + 0.15, 1.7, 0.22, 0.68, 0.14), 0.62)]
    for sill in (0.98, 1.5):
        for c in (0.15, 1.1):
            out.append((arch_loop(s0 + c, 0.75, sill, sill + 0.2, 0.15), 0.58))
    return out


class Wall:
    """One wall edge of a plan: from a to b with the room on its left."""

    def __init__(self, a, b, bays=-1, extra_holes=None):
        self.a, self.b = Vector((a[0], a[1], 0.0)), Vector((b[0], b[1], 0.0))
        self.len = (self.b - self.a).length
        self.t = (self.b - self.a).normalized()
        self.n = Vector((-self.t.y, self.t.x, 0.0))
        self.bays = int(self.len / 1.95) if bays < 0 else bays
        self.extra = extra_holes or []

    def at(self, s, z):
        """A point on the wall, strayed into the rock by its noise."""
        p = self.a + self.t * s + Vector((0.0, 0.0, z))
        fade = min(s, self.len - s, SEAM) / SEAM * min(z, SPRING - z, 0.3) / 0.3
        return p + self.n * (ROUGH * rock(p) * max(fade, 0.0))

    def build(self, bm):
        holes = []
        for b in range(self.bays):
            s0 = (self.len - 2.0 * self.bays) * 0.5 + 2.0 * b
            holes.extend(bay_niches(s0))
        holes.extend(self.extra)
        loops = [h[0] for h in holes]
        outline = []
        for a, b in (((0.0, 0.0), (self.len, 0.0)), ((self.len, 0.0), (self.len, SPRING)),
                     ((self.len, SPRING), (0.0, SPRING)), ((0.0, SPRING), (0.0, 0.0))):
            outline.extend(along(a, b, 0.3))
        tris = triangulate(outline, loops, grid_points(outline, loops, 0.22, 0.07))
        vert = mesh_from(bm, tris, lambda p: self.at(p[0], p[1]), lambda _t: self.n)
        for loop, depth in holes:
            self._pocket(bm, loop, depth, vert)

    def _pocket(self, bm, loop, depth, vert):
        mouth = [vert(p) for p in loop]
        cs = sum(p[0] for p in loop) / len(loop)
        cz = sum(p[1] for p in loop) / len(loop)
        mid = self.a + self.t * cs + Vector((0.0, 0.0, cz)) - self.n * (depth * 0.5)
        back = []
        for (s, z) in loop:
            p = self.a + self.t * (s + (cs - s) * 0.08) + Vector((0.0, 0.0, z + (cz - z) * 0.08)) - self.n * depth
            back.append(bm.verts.new(p + self.n * (0.04 * rock(p * 2.0))))
        n = len(loop)
        for i in range(n):
            j = (i + 1) % n
            q = [mouth[i], mouth[j], back[j], back[i]]
            c = sum((v.co for v in q), Vector()) / 4.0
            face(bm, q, mid - c)
        face(bm, back, self.n)


def vault_z(d):
    """The vault over a point d from the nearest wall."""
    u = min(d / HALF, 1.0)
    z = SPRING + RISE * math.sqrt(max(0.0, 1.0 - (1.0 - u) ** 2))
    if d > HALF:
        over = SPRING + RISE + (d - HALF) * 0.62
        cap = DOME_TOP - 0.25
        z = over if over < cap else cap + 0.25 * (1.0 - math.exp(-(over - cap) / 0.25))
    return z


def plan_piece(name, r, poly, opens, walls=None, step=STEP):
    n_edges = len(poly)
    """`poly`: the plan, counter-clockwise. `opens`: indices of its open edges
    (each joins the next piece). `walls`: {edge index: Wall keyword args}."""
    n = len(poly)
    walls = walls or {}
    wall_objs, segs = [], []
    outline = []
    for i in range(n):
        a, b = poly[i], poly[(i + 1) % n]
        # Open edges take a fixed count, so neighbouring pieces match.
        outline.extend(along(a, b, 2.0 * HALF / 8.0) if i in opens else along(a, b, step))
        if i not in opens:
            segs.append((a, b))
            wall_objs.append(Wall(a, b, **walls.get(i, {})))
    # Rings of points following each wall carry the vault's steep rise smoothly;
    # the grid fills the middle.
    fill = []
    for a, b in segs:
        t = (Vector(b) - Vector(a)).normalized()
        nv = Vector((-t.y, t.x))
        for d in RINGS:
            for p in along(a, b, step):
                q = (p[0] + nv.x * d + t.x * step * 0.5, p[1] + nv.y * d + t.y * step * 0.5)
                if in_poly(q, poly) and min(seg_dist(q, u, v) for u, v in segs) > d - 0.01 \
                        and min(seg_dist(q, poly[i], poly[(i + 1) % n_edges]) for i in range(n_edges)) > 0.03 \
                        and all(math.hypot(q[0] - f[0], q[1] - f[1]) > 0.05 for f in fill):
                    fill.append(q)
    fill += [p for p in grid_points(outline, [], step, step * 0.4)
             if min(seg_dist(p, u, v) for u, v in segs) > RINGS[-1] + step * 0.5]
    tris = triangulate(outline, [], fill)

    def height(p):
        d = min(seg_dist(p, a, b) for a, b in segs)
        z = vault_z(d)
        edge = min(seg_dist(p, poly[i], poly[(i + 1) % n]) for i in range(n))
        return z + 0.07 * rock((p[0], p[1], 3.0)) * min(edge / SEAM, 1.0)

    fb = bmesh.new()
    mesh_from(fb, tris, lambda p: (p[0], p[1], 0.0), lambda _t: Vector((0, 0, 1)))
    mesh_object(name + "__floor", fb, [FLOOR], r, recalc=False)
    vb = bmesh.new()
    mesh_from(vb, tris, lambda p: (p[0], p[1], height(p)), lambda _t: Vector((0, 0, -1)))
    for f in vb.faces:
        f.smooth = True
    mesh_object(name + "__vault", vb, [STONE], r, recalc=False)
    wb = bmesh.new()
    for w in wall_objs:
        w.build(wb)
    mesh_object(name + "__walls", wb, [STONE], r, recalc=False)
    # Collision: flat slabs along each wall, the floor and a lid.
    cb = bmesh.new()
    xs, ys = [p[0] for p in poly], [p[1] for p in poly]
    add_box(cb, min(xs), max(xs), min(ys), max(ys), -0.3, 0.0)
    add_box(cb, min(xs), max(xs), min(ys), max(ys), DOME_TOP + 0.1, DOME_TOP + 0.3)
    for a, b in segs:
        add_wall_box(cb, a, b)
    mesh_object(name + "__col-colonly", cb, [STONE], r)


def add_wall_box(bm, a, b, thick=0.3):
    """A box behind wall edge a..b (the room on its left)."""
    t = (Vector(b) - Vector(a)).normalized()
    n = Vector((-t.y, t.x))
    p = [Vector(a), Vector(b), Vector(b) - n * thick, Vector(a) - n * thick]
    lo = [bm.verts.new((q.x, q.y, -0.3)) for q in p]
    hi = [bm.verts.new((q.x, q.y, DOME_TOP + 0.2)) for q in p]
    bm.faces.new(list(reversed(lo)))
    bm.faces.new(hi)
    for i in range(4):
        j = (i + 1) % 4
        bm.faces.new((lo[i], lo[j], hi[j], hi[i]))


def straight(r):
    plan_piece("os_straight", r, [(L, 0), (R, 0), (R, 4), (L, 4)], {0, 2})


def bend(r):
    plan_piece("os_bend", r, [(L, 0), (R, 0), (R, L), (4, L), (4, R), (L, R)], {0, 3}, {1: {"bays": 0}, 2: {"bays": 0}})


def tee(r):
    plan_piece("os_tee", r, [(L, 0), (R, 0), (R, L), (4, L), (4, R), (0, R), (0, L), (L, L)], {0, 3, 5},
               {1: {"bays": 0}, 2: {"bays": 0}, 6: {"bays": 0}, 7: {"bays": 0}})


def cross(r):
    plan_piece("os_cross", r, [(L, 0), (R, 0), (R, L), (4, L), (4, R), (R, R), (R, 4), (L, 4), (L, R), (0, R), (0, L), (L, L)],
               {0, 3, 6, 9}, {i: {"bays": 0} for i in (1, 2, 4, 5, 7, 8, 10, 11)})


def end(r):
    plan_piece("os_end", r, [(L, 0), (R, 0), (R, R), (L, R)], {0}, {2: {"bays": 1}})


def bier(r):
    """A small room for a bier (step 3): 2.8 m wide, with a neck to the passage."""
    a, b, top, neck = 0.6, 3.4, 3.35, 0.6
    plan_piece("os_bier", r, [(L, 0), (R, 0), (R, neck), (b, neck), (b, top), (a, top), (a, neck), (L, neck)], {0},
               {1: {"bays": 0}, 2: {"bays": 0}, 6: {"bays": 0}, 7: {"bays": 0}})


def cave_profile():
    pts = []
    for j in range(CAVE_SEGS + 1):
        a = math.pi * j / CAVE_SEGS
        c, s = math.cos(a), math.sin(a)
        pts.append((CAVE_HALF * math.copysign(abs(c) ** 0.8, c), CAVE_TOP * (abs(s) ** 0.7)))
    return pts


def passage_profile():
    """The low passage's cross-section, in the order of the cave's profile."""
    pts = []
    for j in range(CAVE_SEGS + 1):
        t = j / CAVE_SEGS
        if t < 0.25:
            pts.append((HALF, SPRING * t / 0.25))
        elif t > 0.75:
            pts.append((-HALF, SPRING * (1.0 - t) / 0.25))
        else:
            u = HALF * (1.0 - 2.0 * (t - 0.25) / 0.5)   # as an open edge's points
            # As vault_z: the height at d from the nearest wall.
            pts.append((u, vault_z(HALF - abs(u))))
    return pts


def throat(r):
    """From the cave passage (Y 0) down into the low passage (Y 4)."""
    name = "os_throat"
    a, b = cave_profile(), passage_profile()
    n = 12
    bm = bmesh.new()
    rings = []
    for i in range(n + 1):
        t = i / n
        k = t * t * (3.0 - 2.0 * t)
        ring = []
        for (p, q) in zip(a, b):
            u = p[0] + (q[0] - p[0]) * k
            v = p[1] + (q[1] - p[1]) * k
            y = 4.0 * t
            m = math.sin(math.pi * t) * 0.2 * rock((u, y, v))
            ring.append(bm.verts.new((2.0 + u * (1.0 + m * 0.5), y, v * (1.0 + m * 0.3) if v > 0.05 else 0.0)))
        rings.append(ring)
    for i in range(n):
        for j in range(CAVE_SEGS):
            q = [rings[i][j], rings[i][j + 1], rings[i + 1][j + 1], rings[i + 1][j]]
            c = sum((v.co for v in q), Vector()) / 4.0
            face(bm, q, Vector((2.0, c.y, 1.4)) - c)
    mesh_object(name + "__rock", bm, [STONE], r, recalc=False)
    fb = bmesh.new()
    add_box(fb, 0.0, 4.0, 0.0, 4.0, -0.3, 0.0)
    mesh_object(name + "__floor", fb, [FLOOR], r)
    cb = bmesh.new()
    add_box(cb, 0.0, 4.0, 0.0, 4.0, -0.3, 0.0)
    add_box(cb, 0.0, 4.0, 0.0, 4.0, CAVE_TOP + 0.3, CAVE_TOP + 0.5)
    # Sloped sides: the walls narrow from the cave's to the passage's.
    add_wall_box(cb, (2.0 + CAVE_HALF, 0.0), (2.0 + HALF, 4.0))
    add_wall_box(cb, (2.0 - HALF, 4.0), (2.0 - CAVE_HALF, 0.0))
    mesh_object(name + "__col-colonly", cb, [STONE], r)


def chamber(r):
    """Eight sides, each side's length o; arms to the block's edge in S, E, W."""
    a = APOTHEM
    o = a * math.tan(math.pi / 8.0)
    e = 6.0
    h = HALF
    poly = [(-h, -e), (h, -e), (h, -a), (o, -a), (a, -o), (a, -h), (e, -h), (e, h), (a, h), (a, o), (o, a), (-o, a),
            (-a, o), (-a, h), (-e, h), (-e, -h), (-a, -h), (-a, -o), (-o, -a), (-h, -a)]
    none = {"bays": 0}
    walls = {2: none, 4: none, 8: none, 12: none, 16: none, 18: none,
             # The shrine's great niche, on the north side (2 * o long).
             10: {"bays": 0, "extra_holes": [(arch_loop(o - 1.3, 2.6, 0.02, 1.5, 0.7, 10), 1.5)]}}
    plan_piece("os_chamber", r, poly, {0, 6, 14}, walls, step=0.17)


def plug(r):
    """A wall across the chamber's east arm, at its mouth (chamber frame)."""
    a = APOTHEM
    w = Wall((a, -HALF), (a, HALF), 1)        # its face looks west, into the chamber
    bm = bmesh.new()
    w.build(bm)
    mesh_object("os_plug__wall", bm, [STONE], r, recalc=False)
    # Rock over it, up to the chamber's vault at the mouth.
    vb = bmesh.new()
    top = DOME_TOP
    vs = [vb.verts.new(p) for p in ((a, HALF, SPRING), (a, -HALF, SPRING), (a, -HALF, top), (a, HALF, top))]
    face(vb, vs, Vector((-1, 0, 0)))
    mesh_object("os_plug__over", vb, [STONE], r, recalc=False)
    cb = bmesh.new()
    add_box(cb, a, a + 0.3, -HALF, HALF, 0.0, top)
    mesh_object("os_plug__col-colonly", cb, [STONE], r)


def candle(r):
    """A niche's candle at the origin, the passage on +X. Its light stands out
    of the niche, so it lights the passage and not just the niche's back."""
    bm = bmesh.new()
    add_lathe(bm, [(0.022, 0.0), (0.022, 0.13)], segs=6)
    mesh_object("os_candle__wax", bm, [WAX], r)
    fb = bmesh.new()
    add_lathe(fb, [(0.0, 0.14), (0.014, 0.16), (0.0, 0.21)], segs=4)
    mesh_object("os_candle__flame", fb, [FLAME], r)
    marker("LIGHT_ossuary_candle__flame", r, (0.7, 0.0, 0.3))


# The shrine's candles (chamber frame): (x, y, z of the base, height).
SHRINE_CANDLES = [(-1.0, 4.9, 0.6, 0.2), (-0.62, 4.82, 0.6, 0.16), (-0.2, 4.88, 0.6, 0.24), (0.24, 4.84, 0.6, 0.18),
                  (0.66, 4.9, 0.6, 0.22), (1.02, 4.84, 0.6, 0.15),
                  (-1.1, 4.46, 0.3, 0.14), (-0.72, 4.5, 0.3, 0.2), (-0.3, 4.44, 0.3, 0.13), (0.1, 4.5, 0.3, 0.17),
                  (0.5, 4.46, 0.3, 0.12), (0.92, 4.5, 0.3, 0.19),
                  (-0.9, 4.1, 0.02, 0.11), (-0.42, 4.14, 0.02, 0.15), (0.34, 4.1, 0.02, 0.1), (0.84, 4.14, 0.02, 0.13)]


# The one still burning in the Forgotten version.
LAST_CANDLE = 9


def shrine(r):
    """Two stone ledges at the back of the great niche, and the one place with
    many candles, burning on one shadowed light outside the niche and a small
    glow inside it."""
    sb = bmesh.new()
    add_box(sb, -1.27, 1.27, 4.25, 5.06, 0.0, 0.3)
    add_box(sb, -1.27, 1.27, 4.65, 5.06, 0.3, 0.6)
    mesh_object("os_shrine__ledges-col", sb, [STONE], r)
    wax, fire = bmesh.new(), bmesh.new()
    for (x, y, z, h) in SHRINE_CANDLES:
        add_lathe(wax, [(0.024, z), (0.024, z + h)], cx=x, cy=y, segs=6)
    mesh_object("os_shrine__wax", wax, [WAX], r)
    for i, (x, y, z, h) in enumerate(SHRINE_CANDLES):
        fb = bmesh.new()
        add_lathe(fb, [(0.0, z + h + 0.01), (0.016, z + h + 0.03), (0.0, z + h + 0.09)], cx=x, cy=y, segs=4)
        mesh_object("os_shrine__flame%d" % i, fb, [FLAME], r)
    marker("LIGHT_ossuary_shrine__pool", r, (0.0, 4.1, 0.95))
    marker("LIGHT_candle__glow", r, (0.0, 4.05, 1.1), {"energy": 0.5, "range": 2.2})
    shrine_dress(r)


def shrine_old(r):
    """The Forgotten version: the same ledges, the candles burnt to stubs, and one
    still burning, with nobody to say who lit it. Its one light is small."""
    sb = bmesh.new()
    add_box(sb, -1.27, 1.27, 4.25, 5.06, 0.0, 0.3)
    add_box(sb, -1.27, 1.27, 4.65, 5.06, 0.3, 0.6)
    mesh_object("os_shrine_old__ledges-col", sb, [STONE], r)
    wax = bmesh.new()
    for i, (x, y, z, h) in enumerate(SHRINE_CANDLES):
        add_lathe(wax, [(0.024, z), (0.024, z + (h if i == LAST_CANDLE else h * 0.3))], cx=x, cy=y, segs=6)
    mesh_object("os_shrine_old__wax", wax, [WAX], r)
    x, y, z, h = SHRINE_CANDLES[LAST_CANDLE]
    fb = bmesh.new()
    add_lathe(fb, [(0.0, z + h + 0.01), (0.016, z + h + 0.03), (0.0, z + h + 0.09)], cx=x, cy=y, segs=4)
    mesh_object("os_shrine_old__flame", fb, [FLAME], r)
    marker("LIGHT_ossuary_candle__flame", r, (x, y - 0.5, z + 0.5), {"energy": 1.4, "range": 7.0})
    shrine_dress(r, True)




MODULES = [
    ("M_os_straight", props(), straight),
    ("M_os_bend", props(), bend),
    ("M_os_tee", props(), tee),
    ("M_os_cross", props(), cross),
    ("M_os_end", props(), end),
    ("M_os_bier", props(), bier),
    ("M_os_throat", props(), throat),
    ("M_os_chamber", props((3, 1, 3)), chamber),
    ("M_os_plug", props(), plug),
    ("M_os_candle", props((0, 0, 0)), candle),
    ("M_os_shrine", props((0, 0, 0)), shrine),
    ("M_os_shrine_old", props((0, 0, 0)), shrine_old),
] + GOODS_MODULES + RUIN_MODULES + [
]

# Script-made modules remade in place at a new revision (kit_blender.rebuild).
REBUILD = [(n, 22) for (n, _p, _b) in MODULES]
# Modules that are gone.
STALE = ("M_os_fill", "M_os_fill_low")


def main():
    if os.path.exists(BLEND):
        bpy.ops.wm.open_mainfile(filepath=BLEND)
    else:
        bpy.ops.wm.read_factory_settings(use_empty=True)
    for name in STALE:
        gone = bpy.data.objects.get(name)
        if gone is not None:
            for ob in reversed([gone] + list(gone.children_recursive)):
                bpy.data.objects.remove(ob, do_unlink=True)
    added = []
    x = 0.0
    for (name, p, build) in MODULES:
        if bpy.data.objects.get(name) is None:
            build(module(name, (x, ROW_Y, 0.0), p))
            added.append(name)
        x += 16.0
    rebuilt = ["%s (rev %d)" % (n, v) for (n, v) in REBUILD if rebuild(n, v, MODULES)]
    if not added and not rebuilt:
        print("kit_add_r17: everything already present; nothing to do.")
        return
    os.makedirs(os.path.dirname(BLEND), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=BLEND)
    print("kit_add_r17: added %d; rebuilt %s" % (len(added), ", ".join(rebuilt) or "nothing"))


main()

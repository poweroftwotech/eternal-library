"""Seeds the reusable Persian kit into art_src/kit/kit_persian.blend
(phase-8-design.md 8.2).

  blender --background --factory-startup --python tools/kit_add_persian.py

Creates kit_persian.blend if it doesn't exist, then adds only the modules
that are not in it yet (modules you edited by hand are never touched), then
run tools/export_kit.bat kit_persian.blend. Every module is in the "persian"
family (kit/modules/persian/): general pieces any room or area can use; the
gorge only adds the rules that arrange them (scripts/gen/persian_town.gd).

The look (design/gorge-art-direction.html): plain plaster and brick walls,
pointed four-centred arches set deep in the wall, tile in four places only
(portal, crown frieze, domes, minaret bands), banai brick for texture,
dressed rock where people cut the cliff, gardens that follow the light.

Frame of a face piece (as the gorge's): X 0..4 along the face, the face at
Y = 0, the building behind it (+Y), anything proud of it out at -Y; Z up
from the storey's floor. Free pieces stand on their origin.

  walls (edge, one 4 m storey)
    persian_wall_plaster / _lime          plain kahgel plaster, two tints
    persian_wall_plaster_window[_dark]    a small pointed window with a
    persian_wall_lime_window[_dark]       wooden lattice, lamplit or dark
    persian_wall_plaster_door / _lime_door  a house door: studded timber, step
    persian_wall_brick                    a monument's plain brick
    persian_wall_brick_arcade[_dark]      a hojreh: a deep pointed recess in
                                          a frame, a door and window in it
    persian_wall_brick_orosi              a tall window of coloured glass
    persian_plinth                        a stone base course
    persian_crown / persian_crown_corner  banai band, tile frieze, cornice,
                                          parapet (sits on a storey's top)
    persian_parapet / _corner             a house roof's rounded parapet
    persian_roof                          cell: a flat plaster roof, walkable
  monuments
    persian_portal                        edge, 3 cells: the pishtaq, the one
                                          tiled moment, a lantern in its hood
    persian_dome / persian_minaret / persian_windcatcher   free
  carved
    persian_carved_door[_dark]            edge: a door cut in a dressed panel
    persian_carved_window[_dark]          edge: a window cut in the rock
    persian_iwan_great                    free: a 10 m iwan cut into the cliff,
                                          mirror-lined hood, relief, spring
    persian_rock_path                     edge: a rock-cut ledge path
  garden, light and water (free)
    persian_pool / persian_fountain / persian_channel
    persian_bed / persian_bed_fungal
    persian_pomegranate
    persian_fungus_giant_6 / _9 / persian_fungus_small / persian_fungus_cluster
    persian_fungus_jelly / persian_glowmoss
    persian_lumen_post                    a lumen stone: gem, mirror mosaic,
                                          its warm-white light (LIGHT_lumen)
    persian_lamp_bracket                  a wall lantern (LIGHT_lantern)
    persian_spillway                      edge: a channel mouth for a great fall
"""
import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Matrix

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kit_blender import (add_box, add_card, add_lathe, add_ngon_prism, add_prism, add_tube, arch_ring, marker, mesh_object, module, rebuild)  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BLEND = os.path.join(ROOT, "art_src", "kit", "kit_persian.blend")
ROW_Y = -200.0
H = 4.0           # storey
T = 0.5           # wall thickness (behind the face)

PLASTER, LIME, BRICK, BANAI = "persian_plaster", "persian_plaster_lime", "persian_brick", "persian_banai"
STONE, ROCK, TILE, DOME = "persian_stone", "persian_rock_dressed", "persian_tile", "persian_dome_tile"
WOOD, LATTICE, GLOW, OROSI = "persian_wood", "persian_lattice", "emit_window_warm", "emit_orosi"


def props(shape, size, edge, tags, weight=1.0):
    return {"kit_shape": shape, "kit_family": "persian", "size_cells": size,
            "edge": edge, "tags": tags, "weight": weight}


def solid(name, root, mats, build, recalc=True):
    bm = bmesh.new()
    build(bm)
    return mesh_object(name, bm, mats, root, recalc)


def card_obj(name, root, mat, cards):
    """Alpha cards with UVs: cards = [(base, width, height, yaw, tilt), ...]."""
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    for (base, w, h, yaw, tilt) in cards:
        add_card(bm, uv, base, w, h, yaw, tilt)
    return mesh_object(name, bm, [mat], root, recalc=False)


def pointed(half, spring, rise, n=8):
    """A pointed (four-centred) arch's outline in XZ, centred on X = 0, from
    the left foot round to the right foot (the gorge kit's pointed())."""
    centre = (half * half - rise * rise) / (2 * half)
    cr = half - centre
    angle = math.atan2(rise, -centre)
    pts = [(-half, 0.0), (-half, spring)]
    for i in range(1, n):
        t = 1 - abs(2 * i / n - 1)
        side = -1.0 if i < n / 2 else 1.0
        pts.append((side * (centre + cr * math.cos(angle * t)), spring + cr * math.sin(angle * t)))
    return pts + [(half, spring), (half, 0.0)]


def front_box(bm, x0, x1, y0, y1, z0, z1):
    """A box without its back face (against the wall, never seen)."""
    vs = [bm.verts.new(v) for v in ((x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0),
                                     (x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1))]
    for f in ((0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (3, 0, 4, 7)):
        bm.faces.new([vs[i] for i in f])


def front_prism(bm, outline, x_off, z_off, y0, y1):
    """add_prism without its back cap."""
    a = [bm.verts.new((x_off + u, y0, z_off + v)) for (u, v) in outline]
    b = [bm.verts.new((x_off + u, y1, z_off + v)) for (u, v) in outline]
    bm.faces.new(a)
    n = len(outline)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((a[i], a[j], b[j], b[i]))


def side_prism(bm, outline_yz, x0, x1):
    """Extrude a YZ outline along X (parapets with a rounded top)."""
    a = [bm.verts.new((x0, y, z)) for (y, z) in outline_yz]
    b = [bm.verts.new((x1, y, z)) for (y, z) in outline_yz]
    bm.faces.new(list(reversed(a)))
    bm.faces.new(b)
    n = len(outline_yz)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((a[i], a[j], b[j], b[i]))


def crown_strips(bm, pts, cx, z_off, top, y0, y1, keep_back=False):
    """The solid over an arch's curve up to `top`, one convex quad strip per
    arch segment. (One concave n-gon here exported with a sliver triangle
    across the springing: a bar across every arch.) Only the faces that can
    show: the front, the arch's soffit and the top; the sides between strips
    are inside the crown, and the back (y1) against the building unless
    `keep_back` (phase 8 cost check: about a third of a window's triangles)."""
    for (xa, za), (xb, zb) in zip(pts[:-1], pts[1:]):
        if keep_back:
            add_prism(bm, [(xa, za), (xb, zb), (xb, top), (xa, top)], cx, z_off, y0, y1)
            continue
        q = [(xa, za), (xb, zb), (xb, top), (xa, top)]
        a = [bm.verts.new((cx + u, y0, z_off + v)) for (u, v) in q]
        b = [bm.verts.new((cx + u, y1, z_off + v)) for (u, v) in q]
        bm.faces.new(a)
        bm.faces.new((a[0], a[1], b[1], b[0]))
        bm.faces.new((a[2], a[3], b[3], b[2]))


def arch_band(bm, outer, inner, cx, z_off, y0, y1):
    """A band between two arch outlines with the same point count (a stone
    ring round an opening) as quads, not one concave face."""
    arch_ring(bm, [(cx + x, z_off + z) for (x, z) in inner], [(cx + x, z_off + z) for (x, z) in outer], y0, y1, smooth=False)


def spandrels(bm, e, top, half, spring, rise, cx, z_off, y0, y1, n=8):
    """A frame's field round an arch (alfiz spandrels, a portal's tiled
    field): the jambs either side from the foot to `top` and the strips over
    the arch, all convex."""
    add_box(bm, cx - e, cx - half, y0, y1, z_off, z_off + top)
    add_box(bm, cx + half, cx + e, y0, y1, z_off, z_off + top)
    crown_strips(bm, pointed(half, spring, rise, n)[1:-1], cx, z_off, top, y0, y1)


def opened(bm, half, foot, spring, rise, y0=0.0, y1=T, back=None, x0=0.0, width=4.0, cx=None, height=H, n=8, keep_back=False):
    """A wall slab (X x0..x0+width, Y y0..y1, Z 0..height) with a pointed
    opening through it, built from boxes round the opening (no booleans):
    below its foot, either side, and the crown over its arch; `back` closes
    the opening with a plate from that Y to y1.
    The back (y1) is left open: against the building or the rock, never seen
    (`keep_back` for a piece that stands free above its building, the portal)."""
    cx = x0 + width / 2 if cx is None else cx
    a, b = cx - half, cx + half
    box = add_box if keep_back else front_box
    if foot > 0:
        box(bm, x0, x0 + width, y0, y1, 0.0, foot)
    box(bm, x0, a, y0, y1, foot, height)
    box(bm, b, x0 + width, y0, y1, foot, height)
    crown_strips(bm, pointed(half, spring, rise, n)[1:-1], cx, foot, height - foot, y0, y1, keep_back)
    if back is not None:
        box(bm, a, b, back, y1, foot, foot + spring + rise)


def arch_face(root, name, mat, half, foot, spring, rise, y, cx=2.0, n=8):
    """A flat arch-shaped face filling an opening (a glow, a pane, a door)."""
    bm = bmesh.new()
    pts = pointed(half, spring, rise, n)
    bm.faces.new([bm.verts.new((cx + x, y, foot + z)) for (x, z) in reversed(pts)])
    return mesh_object(name, bm, [mat], root, recalc=False)


# --- walls -----------------------------------------------------------------------------

WIN = (0.5, 1.45, 1.0, 0.6)       # a house window: half width, foot, spring, rise
DOOR = (0.65, 0.0, 1.75, 0.65)    # a house door


def wall_plain(mat):
    def build(r):
        solid(r.name[2:] + "__body-col", r, [mat], lambda bm: add_box(bm, 0.0, 4.0, 0.0, T, 0.0, H))
    return build


def wall_window(mat, lit, x=2.0):
    """A small, high, pointed window, set back in the wall's depth behind a
    wooden lattice screen (shabak), lamplight behind it or dark."""
    def build(r):
        name = r.name[2:]
        half, foot, spring, rise = WIN
        solid(name + "__body-col", r, [mat], lambda bm: opened(bm, half, foot, spring, rise, back=0.36, cx=x))
        arch_face(r, name + "__glow", GLOW if lit else WOOD, half, foot, spring, rise, 0.355, x)
        card_obj(name + "__screen", r, LATTICE, [((x, 0.12, foot), half * 2, spring + rise, 0.0, 0.0)])
        solid(name + "__sill", r, [STONE], lambda bm: front_box(bm, x - half - 0.15, x + half + 0.15, -0.12, 0.0, foot - 0.12, foot))
    return build


def wall_window2(mat, lit):
    """Two small lattice windows in one storey (phase 8, your report: the houses
    read too plain): the same window as wall_window at x = 1.15 and 2.85."""
    def build(r):
        name = r.name[2:]
        half, foot, spring, rise = WIN

        def body(bm):
            # The wall in strips round two openings (no booleans, no concave faces).
            for (x0, x1) in ((0.0, 1.15 - half), (1.15 + half, 2.85 - half), (2.85 + half, 4.0)):
                add_box(bm, x0, x1, 0.0, T, 0.0, H)
            for cx in (1.15, 2.85):
                add_box(bm, cx - half, cx + half, 0.0, T, 0.0, foot)
                crown_strips(bm, pointed(half, spring, rise)[1:-1], cx, foot, H - foot, 0.0, T)
                add_box(bm, cx - half, cx + half, 0.36, T, foot, foot + spring + rise)
        solid(name + "__body-col", r, [mat], body)
        for (i, cx) in enumerate((1.15, 2.85)):
            # lit: both lamplit; dark: one dark, one lit (someone is in)
            arch_face(r, name + "__glow%d" % i, GLOW if (lit or i == 1) else WOOD, half, foot, spring, rise, 0.355, cx)
        card_obj(name + "__screen", r, LATTICE, [((cx, 0.12, foot), half * 2, spring + rise, 0.0, 0.0) for cx in (1.15, 2.85)])
        solid(name + "__sill", r, [STONE], lambda bm: [front_box(bm, cx - half - 0.15, cx + half + 0.15, -0.12, 0.0, foot - 0.12, foot) for cx in (1.15, 2.85)])
    return build


def oriel(r):
    """A shanashil: a wooden box window jutting from an upper storey on carved
    brackets, lattice on its three faces with lamplight behind, a small
    roof. Stands on a plain wall's face (edge, one storey)."""
    name = r.name[2:]
    x0, x1, out, z0, z1 = 0.8, 3.2, -1.0, 0.9, 3.0

    def frame(bm):
        add_box(bm, x0, x1, out, 0.0, z0 - 0.15, z0)                  # floor
        add_box(bm, x0 - 0.1, x1 + 0.1, out - 0.15, 0.0, z1, z1 + 0.12)  # roof
        add_box(bm, x0 - 0.05, x1 + 0.05, out - 0.08, 0.0, z1 + 0.12, z1 + 0.22)
        for x in (x0, x1 - 0.1):
            add_box(bm, x, x + 0.1, out, out + 0.1, z0, z1)              # front posts
        for x in (x0 + 0.25, x1 - 0.4):                                  # brackets
            add_box(bm, x, x + 0.15, out + 0.15, 0.0, z0 - 0.75, z0 - 0.15)
        add_box(bm, x0, x1, out, out + 0.08, z0, z0 + 0.7)               # the closed lower panel
    solid(name + "__frame", r, [WOOD], frame)
    solid(name + "__glow", r, [GLOW], lambda bm: add_box(bm, x0 + 0.1, x1 - 0.1, -0.02, 0.0, z0 + 0.7, z1))
    card_obj(name + "__screen", r, LATTICE, [
        (((x0 + x1) / 2, out + 0.04, z0 + 0.7), x1 - x0 - 0.2, z1 - z0 - 0.7, 0.0, 0.0),
        ((x0 + 0.05, out / 2, z0 + 0.7), -out - 0.1, z1 - z0 - 0.7, math.pi / 2, 0.0),
        ((x1 - 0.05, out / 2, z0 + 0.7), -out - 0.1, z1 - z0 - 0.7, math.pi / 2, 0.0)])


def awning(r):
    """A striped cloth awning over a door, on two thin poles."""
    name = r.name[2:]

    def cloth(bm):
        a = [bm.verts.new(v) for v in ((1.0, -0.05, 2.75), (3.0, -0.05, 2.75), (3.0, -1.3, 2.3), (1.0, -1.3, 2.3))]
        b = [bm.verts.new((v.co.x, v.co.y, v.co.z + 0.04)) for v in a]
        bm.faces.new(a)
        bm.faces.new(list(reversed(b)))
        for i in range(4):
            j = (i + 1) % 4
            bm.faces.new((a[i], a[j], b[j], b[i]))
        add_box(bm, 1.0, 3.0, -1.32, -1.28, 2.05, 2.3)                  # the valance
    solid(name + "__cloth", r, ["persian_awning"], cloth)
    solid(name + "__poles", r, ["persian_wood"], lambda bm: [add_box(bm, x - 0.03, x + 0.03, -1.33, -1.27, 2.0, 2.32) for x in (1.05, 2.95)])


def corbel(r):
    """A carved stone bracket carrying an overhang (your report: large
    overhangs should be visibly supported): a unit piece, 1 m out from the
    wall (-Y) and 1 m down from the soffit, 0.4 m wide, its underside a
    stepped quarter curve; stretched to each overhang when placed. Placed on
    the lower wall's bay edges, which are clear of windows."""
    name = r.name[2:]
    prof = [(0.0, 0.0), (-1.0, 0.0), (-1.0, -0.12)]
    for k in range(1, 9):
        a = k / 8 * math.pi / 2
        prof.append((-1.0 + math.sin(a) * 0.9 + 0.0 * k, -0.12 - (1.0 - math.cos(a)) * 0.88))
    prof[-1] = (-0.1, -1.0)
    prof += [(0.0, -1.0)]
    solid(name + "__stone", r, [STONE], lambda bm: side_prism(bm, list(reversed(prof)), -0.2, 0.2))
    solid(name + "__cap", r, [STONE], lambda bm: add_box(bm, -0.26, 0.26, -1.08, 0.0, -0.1, 0.0))


def cornice(r):
    """A house's corbelled brick cornice under its parapet: three stepped
    courses and a row of small brackets (finishes the wall's top); five
    brackets a bay (ten before the phase 8 cost check: 130 triangles a bay,
    321 bays on bank 1)."""
    name = r.name[2:]

    def brick(bm):
        front_box(bm, 0.0, 4.0, -0.08, 0.0, H - 0.55, H - 0.45)
        front_box(bm, 0.0, 4.0, -0.16, 0.0, H - 0.45, H - 0.35)
        front_box(bm, 0.0, 4.0, -0.24, 0.0, H - 0.12, H)
        for k in range(5):
            x = 0.4 + k * 0.8
            front_box(bm, x - 0.08, x + 0.08, -0.24, 0.0, H - 0.35, H - 0.12)
    solid(name + "__courses", r, [BRICK], brick)


def wall_door(mat):
    """A house door: a plain pointed opening, a studded timber door set back,
    a stone step before it."""
    def build(r):
        name = r.name[2:]
        half, foot, spring, rise = DOOR
        solid(name + "__body-col", r, [mat], lambda bm: opened(bm, half, foot, spring, rise, back=0.34))

        def door(bm):
            add_prism(bm, pointed(half, spring, rise)[1:-1] + [(half, 0.0), (-half, 0.0)], 2.0, 0.0, 0.26, 0.34)
        solid(name + "__door", r, [WOOD], door)

        def studs(bm):
            for z in (0.5, 1.0, 1.5):
                for x in (-0.45, -0.2, 0.2, 0.45):
                    add_box(bm, 2.0 + x - 0.03, 2.0 + x + 0.03, 0.22, 0.26, z - 0.03, z + 0.03)
            add_box(bm, 1.99, 2.01, 0.2, 0.26, 0.0, spring + rise - 0.05)
        solid(name + "__studs", r, ["brass"], studs)
        solid(name + "__step-col", r, [STONE], lambda bm: front_box(bm, 2.0 - half - 0.25, 2.0 + half + 0.25, -0.45, 0.0, 0.0, 0.16))
    return build


ARC = (1.3, 0.3, 1.95, 1.45)      # a hojreh's recess


def wall_arcade(lit):
    """A hojreh: a deep pointed recess in a raised brick frame (alfiz) with
    banai spandrels; a door and a small window at its back."""
    def build(r):
        name = r.name[2:]
        half, foot, spring, rise = ARC
        solid(name + "__body-col", r, [BRICK], lambda bm: opened(bm, half, foot, spring, rise, y1=1.2, back=0.95))
        top = foot + spring + rise + 0.25

        def frame(bm):
            for (a, b) in ((0.35, 0.55), (3.45, 3.65)):
                front_box(bm, a, b, -0.1, 0.0, foot - 0.05, top + 0.2)
            front_box(bm, 0.35, 3.65, -0.1, 0.0, top, top + 0.2)
        solid(name + "__frame", r, [BRICK], frame)
        solid(name + "__spandrel", r, [BANAI], lambda bm: spandrels(bm, 1.45, top - foot, half + 0.05, spring, rise + 0.05, 2.0, foot, -0.05, 0.0))

        def door(bm):
            add_prism(bm, pointed(0.5, 1.45, 0.5)[1:-1] + [(0.5, 0.0), (-0.5, 0.0)], 2.0, foot, 0.9, 0.95)
        solid(name + "__door", r, [WOOD], door)
        solid(name + "__light", r, [GLOW if lit else WOOD],
              lambda bm: add_box(bm, 1.7, 2.3, 0.88, 0.9, foot + 2.3, foot + 2.85))
        solid(name + "__lintel", r, [STONE], lambda bm: add_box(bm, 1.62, 2.38, 0.86, 0.95, foot + 2.2, foot + 2.3))
    return build


def wall_orosi(r):
    """A tall window of coloured glass in a stone ring, for rooms that matter."""
    name = r.name[2:]
    half, foot, spring, rise = 0.7, 0.85, 1.9, 0.9
    solid(name + "__body-col", r, [BRICK], lambda bm: opened(bm, half, foot, spring, rise, back=0.3))
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    pts = pointed(half, spring, rise)
    f = bm.faces.new([bm.verts.new((2.0 + x, 0.29, foot + z)) for (x, z) in reversed(pts)])
    for loop in f.loops:
        co = loop.vert.co
        loop[uv].uv = ((co.x - (2.0 - half)) / (2 * half), (co.z - foot) / (spring + rise))
    mesh_object(name + "__glass", bm, [OROSI], r, recalc=False)
    solid(name + "__ring", r, [STONE], lambda bm: arch_band(bm, pointed(half + 0.18, spring, rise + 0.18), pointed(half, spring, rise), 2.0, foot, -0.08, 0.0))
    solid(name + "__sill", r, [STONE], lambda bm: front_box(bm, 2.0 - half - 0.25, 2.0 + half + 0.25, -0.18, 0.0, foot - 0.14, foot))


def plinth(r):
    solid("persian_plinth__course-col", r, [STONE], lambda bm: front_box(bm, 0.0, 4.0, -0.16, 0.0, 0.0, 1.2))
    solid("persian_plinth__cap", r, [STONE], lambda bm: front_box(bm, 0.0, 4.0, -0.24, 0.0, 1.2, 1.32))


def crown(r):
    """A monument's crown on top of its last storey: banai band, a thin tile
    frieze (one of tile's four places), a corbelled cornice, a parapet."""
    name = r.name[2:]
    solid(name + "__banai", r, [BANAI], lambda bm: add_box(bm, 0.0, 4.0, -0.04, T, 0.0, 1.0))
    solid(name + "__frieze", r, [TILE], lambda bm: add_box(bm, 0.0, 4.0, -0.09, T, 1.0, 1.32))

    def brick(bm):
        add_box(bm, 0.0, 4.0, -0.22, T, 1.32, 1.5)
        add_box(bm, 0.0, 4.0, -0.04, 0.38, 1.5, 2.15)
    solid(name + "__parapet-col", r, [BRICK], brick)


def crown_corner(r):
    name = r.name[2:]
    solid(name + "__banai", r, [BANAI], lambda bm: add_box(bm, -0.04, T, -0.04, T, 0.0, 1.0))
    solid(name + "__frieze", r, [TILE], lambda bm: add_box(bm, -0.09, T, -0.09, T, 1.0, 1.32))
    solid(name + "__parapet", r, [BRICK], lambda bm: (add_box(bm, -0.22, T, -0.22, T, 1.32, 1.5), add_box(bm, -0.04, 0.38, -0.04, 0.38, 1.5, 2.15)))


PARAPET = [(0.0, 0.0), (0.4, 0.0), (0.4, 0.58), (0.35, 0.7), (0.26, 0.76), (0.14, 0.76), (0.05, 0.7), (0.0, 0.58)]


def parapet(mat):
    def build(r):
        solid(r.name[2:] + "__wall-col", r, [mat], lambda bm: side_prism(bm, PARAPET, 0.0, 4.0))
    return build


def parapet_corner(mat):
    def build(r):
        solid(r.name[2:] + "__post", r, [mat], lambda bm: add_lathe(bm, [(0.26, 0.0), (0.26, 0.62), (0.2, 0.76), (0.0, 0.8)], 0.2, 0.2, segs=8))
    return build


def roof(r):
    solid("persian_roof__slab-col", r, [PLASTER], lambda bm: add_box(bm, 0.0, 4.0, 0.0, 4.0, -0.3, 0.0))


# --- monuments -------------------------------------------------------------------------

PH = 16.0          # the portal's height
P_OPEN = (4.2, 0.0, 7.0, 5.6)


def portal_of(width, height, opening, door=(1.5, 3.0, 1.3), glass=(5.2, 9.6)):
    """The pishtaq, `width` x `height`: a brick screen standing 1.5 m proud of
    its building, a tiled border and spandrels and a calligraphy band (the
    tile's place on a monument), a deep pointed hood stepping in with two
    stone ribs, a door and a coloured-glass window at its back, a lantern in
    the hood. persian_portal is 12 x 16 m; persian_portal_grand 16 x 21 m,
    for a monument that dominates its bank (phase 8, after the user's walk)."""
    def build(r):
        name = r.name[2:]
        half, foot, spring, rise = opening
        cx = width / 2
        b = 0.9 if width <= 12 else 1.1
        band = height - b - 1.0
        solid(name + "__body-col", r, [BRICK], lambda bm: opened(bm, half, foot, spring, rise, y0=-1.5, y1=1.5, back=0.9, keep_back=True,
                                                                 width=width, cx=cx, height=height, n=12))

        def border(bm):
            add_box(bm, 0.0, b, -1.56, -1.5, 0.0, height)
            add_box(bm, width - b, width, -1.56, -1.5, 0.0, height)
            add_box(bm, b, width - b, -1.56, -1.5, height - b, height)
            add_box(bm, b, width - b, -1.56, -1.5, band, height - b)          # the calligraphy band
            spandrels(bm, cx - b, band, half + 0.45, spring, rise + 0.45, cx, foot, -1.54, -1.5, 12)
        solid(name + "__tile", r, [TILE], border)
        solid(name + "__ring", r, [STONE], lambda bm: arch_band(bm, pointed(half + 0.45, spring, rise + 0.45, 12), pointed(half, spring, rise, 12), cx, foot, -1.62, -1.5))

        def ribs(bm):
            # Strips of quads (arch_ring), not one concave face: exported as one
            # n-gon the hood's rib filled across under its arch.
            for (y, inset) in ((-0.55, 0.35), (0.25, 0.75)):
                outer = [(cx + x, foot + z) for (x, z) in pointed(half, spring, rise, 12)]
                inner = [(cx + x, foot + z) for (x, z) in pointed(half - inset, spring, rise - inset, 12)]
                arch_ring(bm, inner, outer, y, y + 0.14, smooth=False)
        solid(name + "__ribs", r, [STONE], ribs)
        dh, ds, dr = door

        def door_leaves(bm):
            add_prism(bm, pointed(dh, ds, dr)[1:-1] + [(dh, 0.0), (-dh, 0.0)], cx, 0.0, 0.84, 0.9)
        solid(name + "__door", r, [WOOD], door_leaves)
        solid(name + "__bands", r, ["brass"], lambda bm: [add_box(bm, cx - dh, cx + dh, 0.8, 0.84, z, z + 0.08) for z in (0.8, ds * 0.73)])
        bm = bmesh.new()
        uv = bm.loops.layers.uv.new("UVMap")
        g0, g1 = glass
        gw = (g1 - g0) / 4
        f = bm.faces.new([bm.verts.new(v) for v in ((cx - gw, 0.88, g0), (cx - gw, 0.88, g1), (cx + gw, 0.88, g1), (cx + gw, 0.88, g0))])
        for loop, t in zip(f.loops, ((0, 0), (0, 1), (1, 1), (1, 0))):
            loop[uv].uv = t
        mesh_object(name + "__orosi", bm, [OROSI], r, recalc=False)
        solid(name + "__step-col", r, [STONE], lambda bm: add_box(bm, cx - half + 0.4, cx + half - 0.4, -2.4, -1.5, 0.0, 0.16))
        marker("LIGHT_lantern__hood", r, (cx, -0.6, ds + dr + 1.0), {"range": 10.0 + width * 0.3, "energy": 1.8})
    return build


portal = portal_of(12.0, PH, P_OPEN)


DRUM = 4.0         # the drum rises this far above a portal-height roof line
DOME_PROFILE = [(4.25, 2.5), (4.5, 3.6), (4.3, 4.8), (3.6, 6.0), (2.4, 7.1), (1.0, 8.0), (0.25, 8.6), (0.0, 8.8)]


def dome_of(drum, s=1.0):
    """An onion dome on its drum (the tile's place on a dome), scaled by `s`
    (persian_dome_grand: 1.3, its drum taller, for the bank's monument)."""
    def build(r):
        name = r.name[2:]
        rd = 4.0 * s
        solid(name + "__drum-col", r, [BRICK], lambda bm: add_lathe(bm, [(rd, 0.0), (rd, drum + 2.2 * s)], segs=20))
        solid(name + "__band", r, [TILE], lambda bm: add_lathe(bm, [(rd + 0.08, drum + 2.2 * s), (rd + 0.08, drum + 2.55 * s)], segs=20))
        solid(name + "__windows", r, [GLOW], lambda bm: [add_box(bm, rd * math.cos(a) - 0.3, rd * math.cos(a) + 0.3, rd * math.sin(a) - 0.3, rd * math.sin(a) + 0.3, drum * 0.5, drum * 0.5 + 1.6 * s) for a in [k * math.pi / 6 for k in range(12)]])
        solid(name + "__shell", r, [DOME], lambda bm: add_lathe(bm, [(rr * s, z * s - 2.5 * s + drum + 2.5 * s) for (rr, z) in DOME_PROFILE], segs=20))
        top = drum + 8.8 * s
        solid(name + "__finial", r, ["brass"], lambda bm: add_lathe(bm, [(0.14 * s, top - 0.1), (0.14 * s, top + 0.7 * s), (0.32 * s, top + 0.9 * s), (0.0, top + 1.5 * s)], segs=6))
    return build


dome = dome_of(DRUM)


def minaret_of(k=1.0):
    """A minaret, 25.6 m tall at k = 1 (persian_minaret_tall: k = 1.3, 33 m)."""
    def build(r):
        _minaret(r, k)
    return build


def _minaret(r, k):
    name = r.name[2:]
    solid(name + "__shaft-col", r, [BRICK], lambda bm: add_lathe(bm, [(1.45, 0.0), (1.45, 1.2), (1.1, 1.5), (1.05, 20.0)], segs=12))
    solid(name + "__bands", r, [TILE], lambda bm: [add_lathe(bm, [(1.1, z), (1.1, z + 0.6)], segs=12) for z in (7.0, 14.0)])
    solid(name + "__balcony", r, [STONE], lambda bm: add_lathe(bm, [(1.05, 19.4), (1.8, 20.0), (1.8, 20.45), (1.0, 20.5)], segs=12))
    solid(name + "__lantern", r, [GLOW], lambda bm: add_lathe(bm, [(0.75, 20.45), (0.75, 22.2)], segs=8))
    solid(name + "__cap", r, [DOME], lambda bm: add_lathe(bm, [(0.95, 22.2), (0.9, 22.9), (0.55, 23.7), (0.0, 24.6)], segs=8))
    solid(name + "__finial", r, ["brass"], lambda bm: add_lathe(bm, [(0.08, 24.5), (0.08, 25.3), (0.0, 25.6)], segs=5))
    if k != 1.0:     # taller and a little stouter
        m = Matrix.Diagonal((1.0 + (k - 1.0) * 0.5, 1.0 + (k - 1.0) * 0.5, k, 1.0))
        for o in r.children:
            if o.type == "MESH":
                o.data.transform(m)


def windcatcher(r):
    """A badgir: a plaster tower with slots on all four sides, on a roof."""
    name = r.name[2:]
    solid(name + "__body-col", r, [PLASTER], lambda bm: add_box(bm, -0.9, 0.9, -0.9, 0.9, 0.0, 3.8))

    def slots(bm):
        for k in (-0.5, 0.0, 0.5):
            front_box(bm, k - 0.12, k + 0.12, -0.92, -0.9, 2.2, 3.5)
            front_box(bm, k - 0.12, k + 0.12, 0.9, 0.92, 2.2, 3.5)
            add_box(bm, -0.92, -0.9, k - 0.12, k + 0.12, 2.2, 3.5)
            add_box(bm, 0.9, 0.92, k - 0.12, k + 0.12, 2.2, 3.5)
    solid(name + "__slots", r, [WOOD], slots)
    solid(name + "__cap", r, [PLASTER], lambda bm: add_box(bm, -1.02, 1.02, -1.02, 1.02, 3.8, 4.0))


# --- carved ----------------------------------------------------------------------------

def carved_door(lit):
    """A door cut into the cliff: a dressed panel thick enough to bury in the
    rock, the opening deep and soft-edged, lamplight or a timber door inside."""
    def build(r):
        name = r.name[2:]
        half, foot, spring, rise = 0.72, 0.0, 1.65, 0.85
        solid(name + "__panel-col", r, [ROCK], lambda bm: opened(bm, half, foot, spring, rise, y0=-0.2, y1=1.8, back=1.2,
                                                                 height=5.0, n=10))
        arch_face(r, name + "__inside", "emit_interior" if lit else WOOD, half, foot, spring, rise, 1.19, n=10)
        solid(name + "__step-col", r, [ROCK], lambda bm: front_box(bm, 1.0, 3.0, -0.65, -0.2, 0.0, 0.14))
    return build


def carved_window(lit):
    def build(r):
        name = r.name[2:]
        half, foot, spring, rise = 0.45, 0.7, 0.75, 0.5
        solid(name + "__panel-col", r, [ROCK], lambda bm: opened(bm, half, foot, spring, rise, y0=-0.2, y1=1.4, back=0.95,
                                                                 x0=1.0, width=2.0, height=2.6, n=8))
        arch_face(r, name + "__inside", "emit_interior" if lit else "persian_soil", half, foot, spring, rise, 0.94, n=8)
    return build


def iwan_great(r):
    """A great iwan cut into the cliff (after Taq-e Bostan): a dressed block
    16 m wide, 17 tall and 8 deep to bury in the rock, the hood 10 m wide and
    6.5 deep lined with mirror mosaic, a carved relief at the back, carved
    columns either side, and a spring in a basin feeding a channel out."""
    name = r.name[2:]
    half, foot, spring, rise = 5.0, 0.0, 6.5, 5.5
    solid(name + "__block-col", r, [ROCK], lambda bm: opened(bm, half, foot, spring, rise, y0=0.0, y1=8.0, back=6.5,
                                                             x0=-8.0, width=16.0, cx=0.0, height=17.0, n=14))
    solid(name + "__floor-col", r, [ROCK], lambda bm: add_box(bm, -half, half, 0.0, 6.5, -0.3, 0.0))
    lining = pointed(half - 0.02, spring, rise - 0.02, 14)[1:-1]
    inner = pointed(half - 0.2, spring, rise - 0.2, 14)[1:-1]
    solid(name + "__mirror", r, ["persian_mirror"], lambda bm: add_prism(bm, lining + list(reversed(inner)), 0.0, foot, 0.4, 6.45))
    solid(name + "__relief", r, [STONE], lambda bm: add_box(bm, -3.0, 3.0, 6.32, 6.5, 5.8, 9.6))

    solid(name + "__relief_frame", r, [STONE], lambda bm: (add_box(bm, -3.2, 3.2, 6.25, 6.5, 9.6, 9.85), add_box(bm, -3.2, 3.2, 6.25, 6.5, 5.55, 5.8)))

    def columns(bm):
        for x in (-6.1, 5.3):
            add_box(bm, x, x + 0.8, -0.35, 0.0, 0.0, 10.5)
            add_box(bm, x - 0.15, x + 0.95, -0.5, 0.0, 10.5, 11.0)
    solid(name + "__columns", r, [STONE], columns)
    solid(name + "__basin-col", r, [STONE], lambda bm: add_box(bm, -2.0, 2.0, 4.6, 6.5, 0.0, 0.6))
    bm = bmesh.new()
    for (x0, x1, y0, y1, z) in ((-1.8, 1.8, 4.8, 6.4, 0.52), (-0.3, 0.3, -0.5, 4.6, 0.04)):
        bm.faces.new([bm.verts.new(v) for v in ((x0, y0, z), (x1, y0, z), (x1, y1, z), (x0, y1, z))])
    mesh_object(name + "__water", bm, ["cistern_water"], r, recalc=False)
    solid(name + "__channel", r, [STONE], lambda bm: (add_box(bm, -0.55, -0.3, -0.5, 4.6, 0.0, 0.18), add_box(bm, 0.3, 0.55, -0.5, 4.6, 0.0, 0.18)))


def rock_wall(opening, lit):
    """A storey of a tier cut from the rock (phase 8 step 2): dressed rock,
    and a carved window or door set deep (the wall is 1.4 m thick, so the
    reveal reads as cut rock, not a built wall), lamplight or dark inside."""
    def build(r):
        name = r.name[2:]
        if opening is None:
            solid(name + "__body-col", r, [ROCK], lambda bm: add_box(bm, 0.0, 4.0, 0.0, T, 0.0, H))
            return
        half, foot, spring, rise = (0.5, 1.3, 0.9, 0.6) if opening == "window" else (0.7, 0.0, 1.7, 0.8)
        solid(name + "__body-col", r, [ROCK], lambda bm: opened(bm, half, foot, spring, rise, y1=1.4, back=1.2, n=10))
        inside = ("emit_interior" if opening == "door" else GLOW) if lit else (WOOD if opening == "door" else "persian_soil")
        arch_face(r, name + "__inside", inside, half, foot, spring, rise, 1.19, n=10)
        if opening == "door":
            solid(name + "__step-col", r, [ROCK], lambda bm: front_box(bm, 1.1, 2.9, -0.4, 0.0, 0.0, 0.14))
    return build


STEPS = 10


def stair_flight_of(top):
    return lambda r: stair_flight(r, top)


def stair_flight(r, top=False):
    """A stair climbing one storey along a face (phase 8 step 2: every
    terrace has a way up): X 0..4 rising Z 0..4, 1.8 m out from the face,
    a low parapet on its open side, in the monument's brick with stone
    nosings (your walk: one built mass with the piers under it). Flights in
    consecutive bays climb a tier; persian_stair_pier fills under the upper
    ones."""
    name = r.name[2:]
    rise, run = H / STEPS, 4.0 / STEPS

    def steps(bm):
        for k in range(STEPS):
            add_box(bm, k * run, (k + 1) * run, -1.8, 0.0, 0.0, (k + 1) * rise)
    solid(name + "__steps-col", r, [BRICK], steps)
    solid(name + "__nosings", r, [STONE], lambda bm: [add_box(bm, k * run - 0.03, k * run + 0.08, -1.6, 0.0, (k + 1) * rise - 0.05, (k + 1) * rise + 0.02)
                                                        for k in range(STEPS)])

    def parapet(bm):
        a = [bm.verts.new(v) for v in ((0.0, -1.8, 0.0), (4.0, -1.8, H), (4.0, -1.8, H + 0.85), (0.0, -1.8, 0.85))]
        b = [bm.verts.new(v) for v in ((0.0, -1.6, 0.0), (4.0, -1.6, H), (4.0, -1.6, H + 0.85), (0.0, -1.6, 0.85))]
        bm.faces.new(list(reversed(a)))
        bm.faces.new(b)
        for i in range(4):
            j = (i + 1) % 4
            bm.faces.new((a[i], a[j], b[j], b[i]))
    solid(name + "__parapet", r, [BRICK], parapet)
    if top:
        # The top flight's far end: its parapet turns across it to the face (your
        # walk: the stair ended in a drop). The way off is onto the roof behind.
        solid(name + "__end", r, [BRICK], lambda bm: add_box(bm, 3.8, 4.0, -1.8, 0.0, H, H + 0.85))


def stair_landing(r):
    """The top of a stair that ends at a door (your walk: a stair rammed into
    the building overhanging it): a flat brick landing 4 x 1.8 m along the
    face at a storey's floor, its parapet on the open side and across the
    far end; a persian_stair_pier fills under it, the door is in the wall."""
    name = r.name[2:]
    solid(name + "__deck-col", r, [BRICK], lambda bm: add_box(bm, 0.0, 4.0, -1.8, 0.0, -0.3, 0.0))
    solid(name + "__parapet", r, [BRICK], lambda bm: (add_box(bm, 0.0, 4.0, -1.8, -1.6, 0.0, 0.85), add_box(bm, 3.8, 4.0, -1.6, 0.0, 0.0, 0.85)))


NICHE = (0.95, 0.4, 1.7, 0.95)     # a stair pier's niche: half width, foot, spring, rise


def stair_pier(r):
    """One storey of the solid under an upper stair flight (your walk: the
    flights hung on stepped undersides; "fill the entire support all the way
    down"): a brick block 4 x 1.8 m in front of the face, a pointed niche in
    its outer side with a stone ring and sill."""
    name = r.name[2:]
    half, foot, spring, rise = NICHE
    solid(name + "__body-col", r, [BRICK], lambda bm: opened(bm, half, foot, spring, rise, y0=-1.8, y1=0.0, back=-1.35))
    solid(name + "__ring", r, [STONE], lambda bm: arch_band(bm, pointed(half + 0.22, spring, rise + 0.22), pointed(half, spring, rise), 2.0, foot, -1.86, -1.8))
    solid(name + "__sill", r, [STONE], lambda bm: front_box(bm, 2.0 - half - 0.12, 2.0 + half + 0.12, -1.92, -1.35, foot - 0.1, foot))


def iwan_tier_of(storeys):
    return lambda r: iwan_tier(r, storeys)


# Per storeys: the arch (half, spring, rise), the columns' height, the relief's
# foot and top. Two storeys (bank 2, seen from the walkways where its tiers
# are two storeys tall): the same iwan 8 m tall.
IWAN_SIZES = {3: ((3.0, 4.6, 4.4), 7.6, 4.4, 6.8), 2: ((2.8, 3.0, 3.0), 5.2, 2.9, 4.9)}


def iwan_tier(r, storeys=3):
    """An iwan cut into a tier of rock, 8 m wide and 12 tall (two bays,
    three storeys): the hood 3.5 m deep (inside the bays' own cells), lined
    with mirror mosaic, a relief at the back, carved columns, a spring in a
    basin and a channel out. A lumen stone stands in it (a separate piece).
    Its front is a pishtaq (your walk: it still read as bare rock): a tiled
    field round the arch, a stone ring and frame, a banai band near the top;
    inside, the hood's walls and back are the monument's brick. The
    two-storey one (persian_iwan_tier2) is the same 8 m tall."""
    name = r.name[2:]
    (half, spring, rise), col_h, rel_lo, rel_hi = IWAN_SIZES[storeys]
    foot = 0.0
    top = storeys * H
    solid(name + "__block-col", r, [BRICK], lambda bm: opened(bm, half, foot, spring, rise, y0=0.0, y1=3.9, back=3.5,
                                                              width=8.0, height=top, n=12))
    solid(name + "__tile", r, [TILE], lambda bm: spandrels(bm, 3.65, top - 0.35, half + 0.3, spring, rise + 0.3, 4.0, foot, -0.08, 0.0, 12))

    def frame(bm):
        front_box(bm, 0.0, 0.35, -0.14, 0.0, 0.0, top)
        front_box(bm, 7.65, 8.0, -0.14, 0.0, 0.0, top)
        front_box(bm, 0.35, 7.65, -0.14, 0.0, top - 0.35, top)
    solid(name + "__frame", r, [STONE], frame)
    solid(name + "__band", r, [BANAI], lambda bm: front_box(bm, 0.35, 7.65, -0.12, -0.08, top - 1.35, top - 0.55))
    solid(name + "__ring", r, [STONE], lambda bm: arch_band(bm, pointed(half + 0.3, spring, rise + 0.3, 12), pointed(half, spring, rise, 12), 4.0, foot, -0.14, 0.0))
    lining = pointed(half - 0.02, spring, rise - 0.02, 12)[1:-1]
    inner = pointed(half - 0.18, spring, rise - 0.18, 12)[1:-1]

    def mirror(bm):
        for (pa, pb, qa, qb) in zip(lining[:-1], lining[1:], inner[:-1], inner[1:]):
            add_prism(bm, [pa, pb, qb, qa], 4.0, foot, 0.3, 3.45)
    solid(name + "__mirror", r, ["persian_mirror"], mirror)
    solid(name + "__relief", r, [STONE], lambda bm: add_box(bm, 2.2, 5.8, 3.38, 3.5, rel_lo, rel_hi))
    solid(name + "__relief_frame", r, [STONE], lambda bm: (add_box(bm, 2.0, 6.0, 3.32, 3.5, rel_hi, rel_hi + 0.2), add_box(bm, 2.0, 6.0, 3.32, 3.5, rel_lo - 0.2, rel_lo)))

    def columns(bm):
        for x in (0.25, 7.25):
            add_box(bm, x, x + 0.5, -0.3, 0.0, 0.0, col_h)
            add_box(bm, x - 0.1, x + 0.6, -0.42, 0.0, col_h, col_h + 0.35)
    solid(name + "__columns", r, [STONE], columns)
    solid(name + "__basin-col", r, [STONE], lambda bm: add_box(bm, 2.6, 5.4, 2.3, 3.5, 0.0, 0.5))
    bm = bmesh.new()
    for (x0, x1, y0, y1, z) in ((2.75, 5.25, 2.45, 3.45, 0.44), (3.75, 4.25, -0.6, 2.3, 0.04)):
        bm.faces.new([bm.verts.new(v) for v in ((x0, y0, z), (x1, y0, z), (x1, y1, z), (x0, y1, z))])
    mesh_object(name + "__water", bm, ["cistern_water"], r, recalc=False)
    solid(name + "__channel", r, [STONE], lambda bm: (add_box(bm, 3.5, 3.75, -0.6, 2.3, 0.0, 0.16), add_box(bm, 4.25, 4.5, -0.6, 2.3, 0.0, 0.16)))
    marker("ANCHOR_lumen__spring", r, (4.0, 1.6, 0.0))


def rock_path(r):
    """A path cut along the cliff: a ledge 1.8 m out with a low rough parapet."""
    name = r.name[2:]
    solid(name + "__ledge-col", r, [ROCK], lambda bm: add_box(bm, 0.0, 4.0, -1.8, 0.5, -1.0, 0.0))

    def wall(bm):
        add_box(bm, 0.0, 1.9, -1.8, -1.45, 0.0, 0.55)
        add_box(bm, 1.9, 4.0, -1.8, -1.45, 0.0, 0.48)
    solid(name + "__parapet-col", r, [ROCK], wall)


# --- garden, light and water -------------------------------------------------------------

def pool(r):
    """A garden pool 4 x 8 m: a stone kerb, the Reading Garden's water."""
    name = r.name[2:]

    def kerb(bm):
        add_box(bm, -2.0, 2.0, -4.0, -3.65, 0.0, 0.45)
        add_box(bm, -2.0, 2.0, 3.65, 4.0, 0.0, 0.45)
        add_box(bm, -2.0, -1.65, -3.65, 3.65, 0.0, 0.45)
        add_box(bm, 1.65, 2.0, -3.65, 3.65, 0.0, 0.45)
    solid(name + "__kerb-col", r, [STONE], kerb)
    solid(name + "__bed", r, [STONE], lambda bm: add_box(bm, -1.65, 1.65, -3.65, 3.65, -0.05, 0.02))
    bm = bmesh.new()
    bm.faces.new([bm.verts.new(v) for v in ((-1.65, -3.65, 0.32), (1.65, -3.65, 0.32), (1.65, 3.65, 0.32), (-1.65, 3.65, 0.32))])
    mesh_object(name + "__water", bm, ["cistern_water"], r, recalc=False)


def fountain(r):
    name = r.name[2:]
    solid(name + "__basin", r, [STONE], lambda bm: add_ngon_prism(bm, 8, 0.75, 0.0, 0.55))
    solid(name + "__spout", r, [STONE], lambda bm: add_lathe(bm, [(0.16, 0.55), (0.1, 0.9), (0.2, 1.0), (0.0, 1.05)], segs=6))
    card_obj(name + "__jet", r, "water", [((0.0, 0.0, 0.95), 0.5, 0.9, a, 0.0) for a in (0.0, math.pi / 3, 2 * math.pi / 3)])


def channel(r):
    name = r.name[2:]
    solid(name + "__kerb-col", r, [STONE], lambda bm: (add_box(bm, 0.0, 4.0, -0.5, -0.3, 0.0, 0.2), add_box(bm, 0.0, 4.0, 0.3, 0.5, 0.0, 0.2)))
    bm = bmesh.new()
    bm.faces.new([bm.verts.new(v) for v in ((0.0, -0.3, 0.12), (4.0, -0.3, 0.12), (4.0, 0.3, 0.12), (0.0, 0.3, 0.12))])
    mesh_object(name + "__water", bm, ["cistern_water"], r, recalc=False)


def bed_kerb(r, name):
    def kerb(bm):
        add_box(bm, -2.0, 2.0, -0.8, -0.62, 0.0, 0.45)
        add_box(bm, -2.0, 2.0, 0.62, 0.8, 0.0, 0.45)
        add_box(bm, -2.0, -1.82, -0.62, 0.62, 0.0, 0.45)
        add_box(bm, 1.82, 2.0, -0.62, 0.62, 0.0, 0.45)
    solid(name + "__kerb-col", r, [STONE], kerb)
    solid(name + "__soil", r, ["persian_soil"], lambda bm: add_box(bm, -1.82, 1.82, -0.62, 0.62, 0.0, 0.38))


def bed(r):
    """A planted bed for a lit garden (a shaft of light or a lumen stone)."""
    name = r.name[2:]
    bed_kerb(r, name)
    rng = random.Random(7)
    card_obj(name + "__flowers", r, "persian_flowers",
             [((-1.6 + i * 0.4 + rng.uniform(-0.1, 0.1), rng.uniform(-0.4, 0.4), 0.38), 0.7, 0.42, rng.uniform(0, math.pi), 0.0)
              for i in range(9)])


def mushroom(bm_cap, bm_gill, bm_stalk, x, y, h, lean=(0.0, 0.0)):
    """One mushroom: a curved stalk, a domed cap, glowing gills under it."""
    R = h * 0.42
    top = (x + lean[0] * h, y + lean[1] * h, h)
    add_tube(bm_stalk, [(x, y, 0.0), (x + lean[0] * h * 0.4, y + lean[1] * h * 0.4, h * 0.5), top],
             [h * 0.08, h * 0.06, h * 0.05], segs=8 if h > 3 else 6)
    segs = 16 if h > 3 else 10
    add_lathe(bm_cap, [(R, h), (R * 0.8, h + R * 0.25), (R * 0.45, h + R * 0.38), (0.0, h + R * 0.42)], top[0], top[1], segs=segs)
    # The gills: a shallow cone under the cap, uv mapped (u round, v out to
    # the rim) for emit_gills' lines; deep enough to read as a surface.
    uv = bm_gill.loops.layers.uv.verify()
    add_lathe(bm_gill, [(h * 0.05, h - R * 0.3), (R * 0.55, h - R * 0.1), (R * 0.97, h - 0.01)], top[0], top[1], segs=segs, uv=uv)
    return top, R


def fungi(r, specs, light=None):
    name = r.name[2:]
    caps, gills, stalks = bmesh.new(), bmesh.new(), bmesh.new()
    for (x, y, h, lean) in specs:
        mushroom(caps, gills, stalks, x, y, h, lean)
    mesh_object(name + "__caps", caps, ["persian_fungus_cap"], r)
    mesh_object(name + "__gills", gills, ["emit_gills"], r)
    mesh_object(name + "__stalks", stalks, ["persian_fungus_stalk"], r)
    if light:
        marker("LIGHT_fungus__glow", r, light[0], light[1])


def fungus_giant(h):
    def build(r):
        fungi(r, [(0.0, 0.0, h, (0.06, 0.03))], ((0.06 * h, 0.03 * h, h * 0.8), {"range": h * 1.2, "energy": 1.0}))
    return build


def fungus_small(r):
    fungi(r, [(0.0, 0.0, 2.2, (-0.05, 0.04)), (0.9, 0.3, 1.4, (0.08, 0.0)), (-0.6, -0.5, 1.0, (0.0, -0.06))],
          ((0.0, 0.0, 1.6), {"range": 4.0}))


def fungus_cluster(r):
    rng = random.Random(11)
    fungi(r, [(rng.uniform(-0.6, 0.6), rng.uniform(-0.6, 0.6), rng.uniform(0.25, 0.7), (rng.uniform(-0.1, 0.1), rng.uniform(-0.1, 0.1)))
              for _ in range(6)])


def bed_fungal(r):
    """A bed for a dark garden: glow moss over the soil and a few small
    mushrooms (the same kerb as persian_bed)."""
    name = r.name[2:]
    bed_kerb(r, name)
    rng = random.Random(5)
    fungi_specs = [(rng.uniform(-1.6, 1.6), rng.uniform(-0.45, 0.45), rng.uniform(0.3, 0.75), (0.0, 0.0)) for _ in range(7)]
    caps, gills, stalks = bmesh.new(), bmesh.new(), bmesh.new()
    for (x, y, h, lean) in fungi_specs:
        mushroom(caps, gills, stalks, x, y, h, lean)
    for ob_bm, (part, mat) in zip((caps, gills, stalks), (("caps", "persian_fungus_cap"), ("gills", "emit_gills"), ("stalks", "persian_fungus_stalk"))):
        bmesh.ops.translate(ob_bm, verts=list(ob_bm.verts), vec=(0.0, 0.0, 0.38))     # stand them on the soil
        mesh_object(name + "__" + part, ob_bm, [mat], r)
    card_obj(name + "__moss", r, "emit_glowmoss", [((-1.0 + i * 1.0, 0.0, 0.385), 1.1, 1.1, i * 1.1, math.pi / 2) for i in range(3)])
    marker("LIGHT_fungus__bed", r, (0.0, 0.0, 1.0), {"range": 4.0, "energy": 0.6})


def fungus_jelly(r):
    """A jelly fungus (after Blackreach): a translucent glowing dome on a
    stalk, strands hanging from its rim."""
    name = r.name[2:]
    h, R = 3.2, 1.2
    solid(name + "__stalk", r, ["persian_fungus_stalk"], lambda bm: add_tube(bm, [(0, 0, 0), (0.1, 0, h * 0.5), (0, 0.05, h)], [0.14, 0.1, 0.08], segs=6))
    solid(name + "__dome", r, ["emit_fungus_jelly"], lambda bm: add_lathe(bm, [(R, h), (R * 0.85, h + R * 0.5), (R * 0.5, h + R * 0.8), (0.0, h + R * 0.9)], 0.0, 0.05, segs=12))
    strands = []
    for i in range(8):
        a = 2 * math.pi * i / 8
        L = 1.4 + (i % 3) * 0.4
        strands.append(((R * 0.92 * math.cos(a), 0.05 + R * 0.92 * math.sin(a), h - L), 0.35, L, a + math.pi / 2, 0.0))
    card_obj(name + "__strands", r, "emit_strands", strands)
    marker("LIGHT_fungus__dome", r, (0.0, 0.05, h + 0.2), {"range": 5.0})


def glowmoss(r):
    """Fungal vines (your walk, phase 8: the moss read as a spray, try a
    fungus growing like vines): seven strands hanging from the origin down a
    wall (-Y is out of it), 1.4 to 3.2 m long, swaying a little, small
    glowing bracket caps along them, half sunk in the wall. About 0.6 m
    wide, so it hangs beside a window or door, not across one."""
    rng = random.Random(23)
    stalks, caps = bmesh.new(), bmesh.new()
    for i in range(7):
        x0 = -0.3 + i * 0.1 + rng.uniform(-0.03, 0.03)
        length = rng.uniform(1.4, 3.2)
        n = max(3, int(length / 0.35))
        phase = rng.uniform(0, 2 * math.pi)
        path = []
        for k in range(n + 1):
            z = -length * k / n
            path.append((x0 + 0.06 * math.sin(phase + k * 1.3), -0.04 - 0.02 * math.sin(phase * 0.7 + k), z))
        add_tube(stalks, path, [0.022 * (1.0 - 0.5 * k / n) for k in range(n + 1)], segs=4)
        # Caps along the strand, bigger toward the top where it is older.
        for k in range(1, n + 1, 2):
            (x, y, z) = path[k]
            R = 0.1 * (1.0 - 0.45 * k / n) + rng.uniform(0.0, 0.03)
            side = 0.04 if k % 4 == 1 else -0.04
            add_lathe(caps, [(R, z), (R * 0.75, z + R * 0.35), (0.0, z + R * 0.5)], x + side, -0.01, segs=6)
        (x, y, z) = path[-1]
        add_lathe(caps, [(0.035, z - 0.06), (0.05, z - 0.02), (0.0, z + 0.03)], x, y, segs=5)     # a drop at the tip
    mesh_object("persian_glowmoss__strands", stalks, ["persian_fungus_stalk"], r)
    mesh_object("persian_glowmoss__caps", caps, ["emit_fungus_jelly"], r)


def pomegranate(r):
    """A pomegranate tree for a lit garden: a crooked trunk, a crown of leaf
    cards (the foliage shader sways them), red fruit."""
    name = r.name[2:]
    rng = random.Random(3)

    def wood(bm):
        add_tube(bm, [(0, 0, 0), (0.08, 0.05, 0.9), (0.0, 0.1, 1.6)], [0.11, 0.08, 0.06], segs=6)
        for a in (0.3, 2.4, 4.4):
            add_tube(bm, [(0.0, 0.1, 1.5), (0.5 * math.cos(a), 0.1 + 0.5 * math.sin(a), 2.1)], [0.05, 0.03], segs=4)
    solid(name + "__wood", r, [WOOD], wood)
    cards = []
    for i in range(34):
        a = rng.uniform(0, 2 * math.pi)
        d = rng.uniform(0.2, 0.9)
        cards.append(((d * math.cos(a), 0.1 + d * math.sin(a), rng.uniform(1.55, 2.45)), 0.5, 0.5, rng.uniform(0, math.pi), rng.uniform(-0.6, 0.6)))
    card_obj(name + "__leaves", r, "tree_leaf", cards)

    def fruit(bm):
        for i in range(7):
            a = rng.uniform(0, 2 * math.pi)
            d = rng.uniform(0.4, 0.85)
            z = rng.uniform(1.7, 2.3)
            add_lathe(bm, [(0.0, z - 0.1), (0.09, z - 0.05), (0.09, z + 0.04), (0.0, z + 0.1)], d * math.cos(a), 0.1 + d * math.sin(a), segs=5)
    solid(name + "__fruit", r, ["pomegranate"], fruit)


def lumen_post(r):
    """A lumen stone: a glowing gem on a brass post, a disc of mirror mosaic
    behind it (aineh-kari) to throw its light forward, a stone foot. Its
    warm-white light is the light green gardens grow in (LIGHT_lumen)."""
    name = r.name[2:]
    solid(name + "__foot-col", r, [STONE], lambda bm: add_ngon_prism(bm, 8, 0.45, 0.0, 0.4))
    solid(name + "__post", r, ["brass"], lambda bm: add_lathe(bm, [(0.08, 0.4), (0.06, 2.75), (0.12, 2.85), (0.0, 2.9)], segs=6))
    circle = [(0.65 * math.cos(2 * math.pi * i / 16), 3.15 + 0.65 * math.sin(2 * math.pi * i / 16)) for i in range(16)]
    solid(name + "__mirror", r, ["persian_mirror"], lambda bm: add_prism(bm, circle, 0.0, 0.0, 0.06, 0.12))
    backing = [(0.78 * math.cos(2 * math.pi * i / 16), 3.15 + 0.78 * math.sin(2 * math.pi * i / 16)) for i in range(16)]
    solid(name + "__backing", r, ["brass"], lambda bm: add_prism(bm, backing, 0.0, 0.0, 0.12, 0.17))

    def gem(bm):
        c, s = (0.0, -0.08, 3.15), 0.26
        pts = [bm.verts.new((c[0] + dx, c[1] + dy, c[2] + dz)) for (dx, dy, dz) in
               ((s * 0.6, 0, 0), (-s * 0.6, 0, 0), (0, s * 0.6, 0), (0, -s * 0.6, 0), (0, 0, s), (0, 0, -s))]
        for (a, b) in ((0, 2), (2, 1), (1, 3), (3, 0)):
            bm.faces.new((pts[a], pts[b], pts[4]))
            bm.faces.new((pts[b], pts[a], pts[5]))
    solid(name + "__gem", r, ["emit_lumen"], gem)
    marker("LIGHT_lumen__gem", r, (0.0, -0.45, 3.15))


def lamp_bracket(r):
    name = r.name[2:]
    solid(name + "__arm", r, ["brass"], lambda bm: (add_box(bm, -0.03, 0.03, -0.55, 0.0, -0.03, 0.03), add_box(bm, -0.08, 0.08, -0.02, 0.0, -0.15, 0.15)))
    solid(name + "__cage", r, ["brass"], lambda bm: add_lathe(bm, [(0.0, -0.05), (0.14, -0.12), (0.14, -0.42), (0.0, -0.5)], 0.0, -0.55, segs=6))
    solid(name + "__flame", r, ["emit_lantern"], lambda bm: add_box(bm, -0.07, 0.07, -0.62, -0.48, -0.4, -0.16))
    marker("LIGHT_lantern__bracket", r, (0.0, -0.75, -0.3))


def spillway(cells):
    """A channel mouth in a masonry headwall where a fall starts: the water
    runs out along a stone lip (the fall itself is a GreatFall node at
    ANCHOR_fall). One cell for a garden's fall; three for a great fall, its
    mouth 8 m wide."""
    def build(r):
        name = r.name[2:]
        w = 4.0 * cells
        half, foot, spring, rise = (1.1, 0.6, 0.7, 0.85) if cells == 1 else (4.0, 1.0, 1.4, 2.2)
        top, depth, out = (3.6, 1.2, 1.2) if cells == 1 else (2 * H, 2.5, 2.2)     # a great one: two storeys
        a, b = w / 2 - half - 0.15, w / 2 + half + 0.15
        solid(name + "__head-col", r, [STONE], lambda bm: opened(bm, half, foot, spring, rise, y0=0.0, y1=depth, back=depth - 0.2, keep_back=True,
                                                                 width=w, height=top))
        solid(name + "__lip", r, [STONE], lambda bm: (add_box(bm, a, b, -out, 0.0, foot - 0.3, foot),
                                                      add_box(bm, a, a + 0.15, -out, 0.0, foot, foot + 0.25),
                                                      add_box(bm, b - 0.15, b, -out, 0.0, foot, foot + 0.25)))
        bm = bmesh.new()
        bm.faces.new([bm.verts.new(v) for v in ((a + 0.15, -out, foot + 0.08), (b - 0.15, -out, foot + 0.08),
                                                 (b - 0.15, depth - 0.2, foot + 0.08), (a + 0.15, depth - 0.2, foot + 0.08))])
        mesh_object(name + "__water", bm, ["cistern_water"], r, recalc=False)
        marker("ANCHOR_fall__lip", r, (w / 2, -out, foot))
    return build


WALL_SET = []
# banai (patterned brick) and tile (glazed faience): the houses of the banks
# further from the camp, more ornamental the further (phase 8, your call).
for (key, mat) in (("plaster", PLASTER), ("lime", LIME), ("banai", BANAI), ("tile", TILE)):
    WALL_SET += [
        ("M_persian_wall_%s" % key, props("edge", [1, 1, 0], "solid", "scenery,persian,wall,house"), wall_plain(mat)),
        ("M_persian_wall_%s_window" % key, props("edge", [1, 1, 0], "solid", "scenery,persian,wall,house,window,light"), wall_window(mat, True)),
        ("M_persian_wall_%s_window_dark" % key, props("edge", [1, 1, 0], "solid", "scenery,persian,wall,house,window"), wall_window(mat, False)),
        ("M_persian_wall_%s_door" % key, props("edge", [1, 1, 0], "solid", "scenery,persian,wall,house,door"), wall_door(mat)),
        ("M_persian_wall_%s_window2" % key, props("edge", [1, 1, 0], "solid", "scenery,persian,wall,house,window,light"), wall_window2(mat, True)),
        ("M_persian_wall_%s_window2_dark" % key, props("edge", [1, 1, 0], "solid", "scenery,persian,wall,house,window"), wall_window2(mat, False)),
    ]

MODULES = WALL_SET + [
    ("M_persian_wall_brick", props("edge", [1, 1, 0], "solid", "scenery,persian,wall,monument"), wall_plain(BRICK)),
    ("M_persian_wall_brick_arcade", props("edge", [1, 1, 0], "solid", "scenery,persian,wall,monument,arcade,light"), wall_arcade(True)),
    ("M_persian_wall_brick_arcade_dark", props("edge", [1, 1, 0], "solid", "scenery,persian,wall,monument,arcade"), wall_arcade(False)),
    ("M_persian_wall_brick_orosi", props("edge", [1, 1, 0], "solid", "scenery,persian,wall,monument,window,light"), wall_orosi),
    ("M_persian_plinth", props("edge", [1, 0, 0], "none", "scenery,persian,trim"), plinth),
    ("M_persian_crown", props("edge", [1, 1, 0], "none", "scenery,persian,trim,crown"), crown),
    ("M_persian_crown_corner", props("post", [0, 1, 0], "", "scenery,persian,trim,crown"), crown_corner),
    ("M_persian_parapet", props("edge", [1, 0, 0], "rail", "scenery,persian,rail,house"), parapet(PLASTER)),
    ("M_persian_parapet_lime", props("edge", [1, 0, 0], "rail", "scenery,persian,rail,house"), parapet(LIME)),
    ("M_persian_parapet_banai", props("edge", [1, 0, 0], "rail", "scenery,persian,rail,house"), parapet(BANAI)),     # banai and tile houses
    ("M_persian_parapet_corner", props("post", [0, 0, 0], "", "scenery,persian,rail,house"), parapet_corner(PLASTER)),
    ("M_persian_roof", props("cell", [1, 0, 1], "", "scenery,persian,floor,roof"), roof),
    ("M_persian_portal", props("edge", [3, 4, 0], "solid", "scenery,persian,monument,portal,door,light"), portal),
    ("M_persian_dome", props("free", [2, 3, 2], "", "scenery,persian,monument,dome"), dome),
    ("M_persian_minaret", props("free", [0, 6, 0], "", "scenery,persian,monument,minaret"), minaret_of(1.0)),
    ("M_persian_minaret_tall", props("free", [0, 8, 0], "", "scenery,persian,monument,minaret"), minaret_of(1.3)),
    ("M_persian_portal_grand", props("edge", [4, 5, 0], "solid", "scenery,persian,monument,portal,door,light"),
     portal_of(16.0, 21.0, (5.6, 0.0, 9.4, 7.6), door=(2.0, 4.0, 1.8), glass=(6.4, 12.8))),
    ("M_persian_dome_grand", props("free", [3, 4, 3], "", "scenery,persian,monument,dome"), dome_of(5.0, 1.3)),
    ("M_persian_dome_small", props("free", [1, 2, 1], "", "scenery,persian,monument,dome"), dome_of(1.6, 0.55)),     # on a grand building's roof (bank 5 on)
    ("M_persian_windcatcher", props("free", [0, 1, 0], "", "scenery,persian,house,roof"), windcatcher),
    ("M_persian_carved_door", props("edge", [1, 1, 0], "solid", "scenery,persian,carved,door,light"), carved_door(True)),
    ("M_persian_carved_door_dark", props("edge", [1, 1, 0], "solid", "scenery,persian,carved,door"), carved_door(False)),
    ("M_persian_carved_window", props("edge", [1, 1, 0], "solid", "scenery,persian,carved,window,light"), carved_window(True)),
    ("M_persian_carved_window_dark", props("edge", [1, 1, 0], "solid", "scenery,persian,carved,window"), carved_window(False)),
    ("M_persian_iwan_great", props("free", [4, 4, 2], "", "scenery,persian,carved,iwan,water"), iwan_great),
    ("M_persian_rock_path", props("edge", [1, 0, 0], "none", "scenery,persian,carved,floor,rail"), rock_path),
    ("M_persian_pool", props("free", [1, 0, 2], "", "scenery,persian,garden,water"), pool),
    ("M_persian_fountain", props("free", [0, 0, 0], "", "scenery,persian,garden,water"), fountain),
    ("M_persian_channel", props("edge", [1, 0, 0], "none", "scenery,persian,garden,water"), channel),
    ("M_persian_bed", props("free", [1, 0, 0], "", "scenery,persian,garden,plant,lit"), bed),
    ("M_persian_bed_fungal", props("free", [1, 0, 0], "", "scenery,persian,garden,plant,fungus,dark,light"), bed_fungal),
    ("M_persian_pomegranate", props("free", [0, 1, 0], "", "scenery,persian,garden,plant,lit"), pomegranate),
    ("M_persian_fungus_giant_6", props("free", [1, 2, 1], "", "scenery,persian,fungus,dark,light"), fungus_giant(6.0)),
    ("M_persian_fungus_giant_9", props("free", [1, 3, 1], "", "scenery,persian,fungus,dark,light"), fungus_giant(9.0)),
    ("M_persian_fungus_small", props("free", [0, 1, 0], "", "scenery,persian,fungus,dark,light"), fungus_small),
    ("M_persian_fungus_cluster", props("free", [0, 0, 0], "", "scenery,persian,fungus,dark"), fungus_cluster),
    ("M_persian_fungus_jelly", props("free", [1, 1, 1], "", "scenery,persian,fungus,dark,light"), fungus_jelly),
    ("M_persian_glowmoss", props("free", [0, 0, 0], "", "scenery,persian,fungus,dark"), glowmoss),
    ("M_persian_lumen_post", props("free", [0, 1, 0], "", "scenery,persian,light,lumen"), lumen_post),
    ("M_persian_lamp_bracket", props("free", [0, 0, 0], "", "scenery,persian,lamp,light"), lamp_bracket),
    ("M_persian_spillway", props("edge", [1, 1, 0], "solid", "scenery,persian,water,fall"), spillway(1)),
    ("M_persian_spillway_great", props("edge", [3, 2, 0], "solid", "scenery,persian,water,fall"), spillway(3)),
    ("M_persian_wall_rock", props("edge", [1, 1, 0], "solid", "scenery,persian,wall,carved"), rock_wall(None, False)),
    ("M_persian_wall_rock_window", props("edge", [1, 1, 0], "solid", "scenery,persian,wall,carved,window,light"), rock_wall("window", True)),
    ("M_persian_wall_rock_window_dark", props("edge", [1, 1, 0], "solid", "scenery,persian,wall,carved,window"), rock_wall("window", False)),
    ("M_persian_wall_rock_door", props("edge", [1, 1, 0], "solid", "scenery,persian,wall,carved,door,light"), rock_wall("door", True)),
    ("M_persian_wall_rock_door_dark", props("edge", [1, 1, 0], "solid", "scenery,persian,wall,carved,door"), rock_wall("door", False)),
    ("M_persian_parapet_rock", props("edge", [1, 0, 0], "rail", "scenery,persian,rail,carved"), parapet(ROCK)),
    ("M_persian_oriel", props("edge", [1, 1, 0], "none", "scenery,persian,house,window,light"), oriel),
    ("M_persian_awning", props("edge", [1, 1, 0], "none", "scenery,persian,house,cloth"), awning),
    ("M_persian_corbel", props("free", [0, 0, 0], "", "scenery,persian,trim,support"), corbel),
    ("M_persian_cornice", props("edge", [1, 0, 0], "none", "scenery,persian,house,trim"), cornice),
    ("M_persian_stair_flight", props("edge", [1, 1, 0], "none", "scenery,persian,vertical,stair"), stair_flight_of(False)),
    ("M_persian_stair_flight_top", props("edge", [1, 1, 0], "none", "scenery,persian,vertical,stair"), stair_flight_of(True)),
    ("M_persian_stair_pier", props("edge", [1, 1, 0], "solid", "scenery,persian,vertical,stair,support"), stair_pier),
    ("M_persian_stair_landing", props("edge", [1, 1, 0], "none", "scenery,persian,vertical,stair"), stair_landing),
    ("M_persian_iwan_tier", props("edge", [2, 3, 0], "solid", "scenery,persian,carved,iwan,water"), iwan_tier_of(3)),
    ("M_persian_iwan_tier2", props("edge", [2, 2, 0], "solid", "scenery,persian,carved,iwan,water"), iwan_tier_of(2)),
]

KIT_REV = 7     # rev 7: hidden faces left out of walls and arch crowns, fewer cornice brackets (the cost check; every module rebuilt)
REV_GREAT = 5   # rev 5: the great spillway two storeys tall (bank 1)
REVS = {name: KIT_REV for (name, _p, _b) in MODULES}
REVS["M_persian_spillway_great"] = max(REV_GREAT, KIT_REV)
REV_WALK3 = 6   # rev 6: brick stairs, the tiled iwan front (the third walk of bank 1)
for _n in ("M_persian_stair_flight", "M_persian_iwan_tier"):
    REVS[_n] = max(REV_WALK3, KIT_REV)
REVS["M_persian_glowmoss"] = 8     # rev 8: fungal vines in place of the moss's spray (bank 2's fly-by)
REVS["M_persian_stair_landing"] = 8     # new: a stair ending at a door
REVS["M_persian_iwan_tier2"] = 8     # new: the iwan two storeys tall (bank 2)
REVS["M_persian_dome_small"] = 8     # new: the grand buildings' domes (bank 5)



def main():
    if os.path.exists(BLEND):
        bpy.ops.wm.open_mainfile(filepath=BLEND)
    else:
        bpy.ops.wm.read_factory_settings(use_empty=True)
    added = []
    x = 0.0
    for (name, p, build) in MODULES:
        if bpy.data.objects.get(name) is None:
            root = module(name, (x, ROW_Y, 0.0), p)
            build(root)
            root["kit_rev"] = REVS.get(name, 1)     # built at its current revision
            added.append(name)
        x += 14.0
    rebuilt = [n for (n, v) in REVS.items() if rebuild(n, v, MODULES)]
    if not added and not rebuilt:
        print("kit_add_persian: everything already present; nothing to do.")
        return
    os.makedirs(os.path.dirname(BLEND), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=BLEND)
    print("kit_add_persian: added %d (%s); rebuilt %s" % (len(added), ", ".join(added), ", ".join(rebuilt) or "nothing"))


main()
